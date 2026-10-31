// vzemu.c - headless VZ300 + BennVenn SD loader test emulator (for development only)
// - superzazu z80 core (cycle counted)
// - 228 T/line, configurable lines/frame, FS low period, display start
// - MC6847 model: per-byte-column latch sampling, A/G toggle within a line = line-counter reset (line hold)
// - speaker (latch bits 0/5) -> WAV, video -> raw RGB stream for ffmpeg / PPM snapshots
// - BennVenn DOS calls trapped: $5F00 OpenFile, $5F03 SelectHandle, $5F09 NextSector
// - guards: writes to $FA00-$FFFF (DOS RAM), DOS calls with DOS bank unmapped
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "z80.h"

#define TPL 228
static int LINES = 312;      // lines per frame
static int FS_LINES = 56;    // measured on the real VZ300 (RASTEST)
static int DISP_START = 120; // FS end + 64 (measured)
static int H0 = 93;          // matches real-hardware write phase photos

static uint8_t rom[0x4000];
static uint8_t mem[0x10000];         // main map (RAM $6800.. etc)
static uint8_t sram[2][0x2800];      // $4000-$67FF banks (bank0 = DOS)
static uint8_t hibank[0x10000];      // high bank 1 ($B800-$FFFF) shadow
static int map37 = 1;                // port $37
static int nobank1 = 0;
static uint8_t latch = 0;
static z80 cpu;
static unsigned long long T = 0;     // global T
static int fs_low = 0;

// latch events
typedef struct { unsigned long long t; uint8_t v; } ev_t;
static ev_t *evs; static int nev, evcap;
static uint8_t latch_at_frame_start;
static unsigned long long frame_t0;

// audio
static FILE *wavf; static double audacc=0; static double audt=0; static long nsamp=0;
static int spklevel=0; static unsigned long long spk_lastt=0;
static double clk = 3546900.0; static double samp_rate = 44100.0;
static double hp_prev_in=0, hp_prev_out=0;

// video
static FILE *vidf; static uint8_t rgb[240][320][3];
static int frameno=0;
static uint8_t font[3072];

// SD
typedef struct { char name[16]; uint8_t *data; long len; } sdfile_t;
static sdfile_t files[16]; static int nfiles=0;
static int cur_file=-1; static long cur_sector=0;
static long dos_tcost = 120000; // T per sector (approx 30 sectors/s)

static long guard_fa = 0, guard_dos = 0, bad_dos=0;
static unsigned long long maxT = 0;
static int trace_pc = -1; static unsigned long long last_pc_t=0; static long pc_hist[4096]; static long pc_hits=0;
static int snap_every = 0;
static char snapbase[256] = "snap";
static int keyrow[8]; // keyboard matrix (bit cleared = pressed)
static struct { long frame; int row, bit, dur; } keyscript[4096]; static int nkeys=0;

static char loadsnap[256]="", savesnap[256]=""; static int until_frame=-1; static unsigned minsp=0xFFFF;
static int dumpmem_frame=-1; static char dumpmem_file[256];
static int lineat_pc=-1; static long line_hist[400]; static long lineat_max=0;
static int dump_frame=-1; static int regpc=-1; static int regn=0; static int regfrom=140; static int vram_frame=-1; static int watch_addr=-1; static long phase_hist[228]; static int phase_on=0;
static void wr_latch(uint8_t v, unsigned long long t) {
  if (phase_on) phase_hist[(t - frame_t0) % 228]++;
  if (frameno==dump_frame) fprintf(stderr,"W line %llu ph %llu v %02X pc %04X\n",(t-frame_t0)/228,(t-frame_t0)%228,v,cpu.pc);
  // speaker
  int lvl = (v & 1) - ((v >> 5) & 1);
  if (lvl != spklevel) {
    // integrate audio up to t
    spklevel = lvl;
  }
  if (nev >= evcap) { evcap = evcap ? evcap*2 : 65536; evs = realloc(evs, evcap*sizeof(ev_t)); }
  evs[nev].t = t; evs[nev].v = v; nev++;
  latch = v;
}

static uint8_t rd(void *u, uint16_t a) {
  if (a < 0x4000) return rom[a];
  if (a < 0x6800) {
    if (map37 & 1) return sram[(map37>>1)&1][a-0x4000];
    return 0xFF; // EPROM area (not modelled)
  }
  if (a < 0x7000) {
    uint8_t k = 0x3F;
    for (int r=0;r<8;r++) if (!(a & (1<<r))) k &= keyrow[r];
    k |= 0x40;
    if (!fs_low) k |= 0x80;
    return k;
  }
  if (a >= 0xB800 && (map37 & 4)) return hibank[a];
  return mem[a];
}
static int pending_writes; static uint16_t pw_addr[4]; static uint8_t pw_val[4];
static void wrb(void *u, uint16_t a, uint8_t v) {
  if (a < 0x4000) return;
  if (a < 0x6800) { if (map37 & 1) { int b=(map37>>1)&1; if (b==0 && a<0x6000) { guard_dos++; if (guard_dos<5) fprintf(stderr,"bank0 write %04X at PC~%04X\n",a,cpu.pc); } sram[b][a-0x4000]=v; } return; }
  if (a < 0x7000) { if (pending_writes<4) { pw_addr[pending_writes]=a; pw_val[pending_writes]=v; pending_writes++; } return; }
  if (a >= 0xFA00 && !(map37&4) && a != 0xFB80 && a != 0xFB81) { guard_fa++; if (guard_fa<5) fprintf(stderr,"DOS RAM write %04X at PC~%04X\n",a,cpu.pc); }
  if (a >= 0xB800 && (map37 & 4)) { hibank[a]=v; return; }
  mem[a] = v;
}
static uint8_t joyv=0xFF, firev=0xFF;
static uint8_t pin(z80 *z, uint8_t p) { if (p==0x2C) return joyv&firev; if (p==0x2E) return firev; return 0xFF; }
static void pout(z80 *z, uint8_t p, uint8_t v) { if (p == 0x37) map37 = nobank1 ? (v & ~2) : v; }

// ---------------- video -----------------
static const uint8_t pal[16][3] = {
  {0x07,0xFF,0x00},{0xFF,0xFF,0x00},{0x3B,0x08,0xFF},{0xCC,0x00,0x3B},
  {0xFF,0xFF,0xFF},{0x07,0xE3,0x99},{0xFF,0x1C,0xFF},{0xFF,0x81,0x00},
  {0,0,0},{0x00,0x3A,0x00},{0x48,0x1A,0x00},{0xFF,0xA0,0x30}
};
#define C_BLACK 8
#define C_DKGREEN 9
#define C_DKORANGE 10
#define C_BRORANGE 11

static int lineholds_in_frame = 0;
// incremental renderer state
static int r_addr = 0, r_linectr = 0, r_ei = 0, r_line = 0; static uint8_t r_cur;
static void render_begin(void) { r_addr = 0; r_linectr = 0; r_ei = 0; r_line = 0; r_cur = latch_at_frame_start; }
static void render_line(int L) {
    unsigned long long ls = frame_t0 + (unsigned long long)L * TPL;
    unsigned long long le = ls + TPL;
    int y = L - (DISP_START - 24);
    int toggled = 0;
    #define ADV_TO(tt) while (r_ei < nev && evs[r_ei].t <= (tt)) { if ((evs[r_ei].v ^ r_cur) & 0x08) { if (evs[r_ei].t >= ls) toggled = 1; } r_cur = evs[r_ei].v; r_ei++; }
    if (y >= 0 && y < 240) {
      int disp = (L >= DISP_START && L < DISP_START + 192);
      for (int px = 0; px < 320; px += 4) {
        long tt = (long)H0 + (px - 32) / 2;
        ADV_TO(ls + tt);
        int ag = (r_cur >> 3) & 1, css = (r_cur >> 4) & 1;
        for (int q = 0; q < 4; q++) {
          int x = px + q; int c;
          if (!disp || x < 32 || x >= 288) {
            c = ag ? (css ? 4 : 0) : C_BLACK;
          } else {
            int col = (x - 32) >> 3; int bx = (x - 32) & 7;
            uint8_t b = mem[0x7000 + ((r_addr + col) & 0x7FF)];
            if (ag) {
              int pxl = (b >> (6 - ((bx >> 1) << 1))) & 3;
              c = (css ? 4 : 0) + pxl;
            } else {
              if (b & 0x80) {
                int top = r_linectr < 6;
                int bit = top ? (bx < 4 ? 3 : 2) : (bx < 4 ? 1 : 0);
                c = (b & (1 << bit)) ? ((b >> 4) & 7) : C_BLACK;
              } else {
                uint8_t f = font[(b & 0x7F) * 12 + (r_linectr % 12)];
                int on = (f >> (7 - bx)) & 1;
                c = on ? (css ? C_BRORANGE : 0) : (css ? C_DKORANGE : C_DKGREEN);
              }
            }
          }
          rgb[y][x][0] = pal[c][0]; rgb[y][x][1] = pal[c][1]; rgb[y][x][2] = pal[c][2];
        }
      }
    }
    ADV_TO(le - 1);
    if (L >= DISP_START && L < DISP_START + 192) {
      int ag = (r_cur >> 3) & 1;
      if (toggled) { r_linectr = 0; lineholds_in_frame++; }
      else { r_linectr++; if (r_linectr >= (ag ? 3 : 12)) { r_linectr = 0; r_addr += 32; } }
    }
}
static void render_end(void) {
  int k = 0; for (int i = r_ei; i < nev; i++) evs[k++] = evs[i]; nev = k;
}

static double au_acc = 0, au_last = 0;   // box-filtered speaker (average level per sample)
static void audio_advance(unsigned long long t) {
  double tsec = (double)t / clk;
  double dt = 1.0 / samp_rate;
  while (audt + dt <= tsec) {
    au_acc += spklevel * (audt + dt - au_last);
    audt += dt; au_last = audt;
    double in = au_acc / dt * 0.6; au_acc = 0;
    double out = 0.995 * (hp_prev_out + in - hp_prev_in); // DC block
    hp_prev_in = in; hp_prev_out = out;
    int16_t s = (int16_t)(out * 30000);
    fwrite(&s, 2, 1, wavf); nsamp++;
  }
  au_acc += spklevel * (tsec - au_last); au_last = tsec;
}

static void wav_header(FILE *f, long n) {
  uint32_t sr = 44100, br = sr*2, ds = n*2, cs = 36+ds; uint16_t ch=1, bps=16, ba=2, fmt=1; uint32_t fl=16;
  fseek(f,0,SEEK_SET);
  fwrite("RIFF",1,4,f); fwrite(&cs,4,1,f); fwrite("WAVEfmt ",1,8,f); fwrite(&fl,4,1,f);
  fwrite(&fmt,2,1,f); fwrite(&ch,2,1,f); fwrite(&sr,4,1,f); fwrite(&br,4,1,f); fwrite(&ba,2,1,f); fwrite(&bps,2,1,f);
  fwrite("data",1,4,f); fwrite(&ds,4,1,f);
}

static int find_file(const char *n) {
  for (int i=0;i<nfiles;i++) if (!strcasecmp(files[i].name,n)) return i;
  return -1;
}
static void sd_copy_sector(void) {
  uint16_t dst = mem[0xFB80] | (mem[0xFB81] << 8);
  for (int i=0;i<512;i++) {
    long o = cur_sector*512 + i;
    uint8_t v = (cur_file>=0 && o < files[cur_file].len) ? files[cur_file].data[o] : 0;
    uint16_t a = dst + i;
    if (a >= 0xFA00) { bad_dos++; continue; }
    if (a >= 0x7000 || (a>=0x4000 && a<0x6800)) {
      if (a < 0x6800) { if (map37&1) sram[(map37>>1)&1][a-0x4000]=v; }
      else mem[a] = v;
    }
  }
  cur_sector++;
}

static int dos_trap(void) {
  uint16_t pc = cpu.pc;
  if (pc != 0x5F00 && pc != 0x5F03 && pc != 0x5F09 && pc != 0x5FF0) return 0;
  if ((map37 & 3) != 1) { fprintf(stderr,"!! DOS call at %04X with map37=%d (T=%llu)\n",pc,map37,T); bad_dos++; }
  long cost = 300;
  if (pc == 0x5F00 || pc == 0x5FF0) {
    uint16_t p = (cpu.h<<8)|cpu.l; char nm[32]; int n=0;
    if (mem[p]=='"') p++;
    while (n<16 && mem[p] && mem[p] != '"' && mem[p] != 13) nm[n++] = mem[p++];
    nm[n]=0;
    int f = find_file(nm);
    if (f < 0) { char nm2[40]; snprintf(nm2,40,"%s.DAT",nm); f = find_file(nm2); }
    fprintf(stderr,"DOS OpenFile \"%s\" handle %d -> %s\n", nm, cpu.a, f>=0?"OK":"NOT FOUND");
    mem[0xFB03] = f >= 0 ? 1 : 0; mem[0xFB05] = 0;
    cur_file = f; cur_sector = 0; cost = 400000;
  } else if (pc == 0x5F03) {
    cur_sector = 0; sd_copy_sector(); cost = dos_tcost;
  } else if (pc == 0x5F09) {
    sd_copy_sector(); cost = dos_tcost;
  }
  // scramble registers like a real call might
  cpu.a = 0x5A; cpu.b = cpu.c = cpu.d = cpu.e = 0xA5; cpu.h = cpu.l = 0x33; cpu.ix=0x1234; cpu.iy=0x4321;
  // ret
  uint16_t ra = rd(0, cpu.sp) | (rd(0, cpu.sp+1) << 8); cpu.sp += 2; cpu.pc = ra;
  cpu.cyc += cost;
  return 1;
}

static uint8_t *load_file(const char *fn, long *len) {
  FILE *f = fopen(fn, "rb"); if (!f) { perror(fn); exit(1); }
  fseek(f,0,SEEK_END); *len = ftell(f); fseek(f,0,SEEK_SET);
  uint8_t *d = malloc(*len+1); if (fread(d,1,*len,f)!=*len) {} fclose(f); return d;
}

int main(int argc, char **argv) {
  const char *vz = NULL, *wavname = NULL, *vidname = NULL; double seconds = 10; int pngframes[64]; int npng=0;
  for (int i=1;i<argc;i++) {
    if (!strcmp(argv[i],"-t")) seconds = atof(argv[++i]);
    else if (!strcmp(argv[i],"-wav")) wavname = argv[++i];
    else if (!strcmp(argv[i],"-vid")) vidname = argv[++i];
    else if (!strcmp(argv[i],"-sd")) { const char *p = argv[++i]; const char *b = strrchr(p,'/'); b = b? b+1: p;
        strncpy(files[nfiles].name, b, 15); files[nfiles].data = load_file(p, &files[nfiles].len); nfiles++; }
    else if (!strcmp(argv[i],"-snap")) pngframes[npng++] = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-snapbase")) strncpy(snapbase, argv[++i], 255);
    else if (!strcmp(argv[i],"-lines")) LINES = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-fs")) FS_LINES = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-disp")) DISP_START = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-h0")) H0 = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-sdcost")) dos_tcost = atol(argv[++i]);
    else if (!strcmp(argv[i],"-watch")) watch_addr = strtol(argv[++i],0,16);
    else if (!strcmp(argv[i],"-vram")) vram_frame = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-regs")) { regpc = strtol(argv[++i],0,16); regn = atoi(argv[++i]); }
    else if (!strcmp(argv[i],"-regfrom")) regfrom = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-nobank1")) nobank1 = 1;
    else if (!strcmp(argv[i],"-until")) until_frame = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-load")) strncpy(loadsnap, argv[++i], 255);
    else if (!strcmp(argv[i],"-save")) strncpy(savesnap, argv[++i], 255);
    else if (!strcmp(argv[i],"-dumpmem")) { dumpmem_frame = atoi(argv[++i]); strncpy(dumpmem_file, argv[++i], 255); }
    else if (!strcmp(argv[i],"-lineat")) lineat_pc = strtol(argv[++i],0,16);
    else if (!strcmp(argv[i],"-dump")) dump_frame = atoi(argv[++i]);
    else if (!strcmp(argv[i],"-tracepc")) trace_pc = strtol(argv[++i],0,16);
    else if (!strcmp(argv[i],"-keys")) { FILE *kf=fopen(argv[++i],"r"); long fr; int rr,bb,dd; while (kf && fscanf(kf,"%ld %d %d %d",&fr,&rr,&bb,&dd)==4 && nkeys<4096) { keyscript[nkeys].frame=fr; keyscript[nkeys].row=rr; keyscript[nkeys].bit=bb; keyscript[nkeys].dur=dd; nkeys++; } if(kf) fclose(kf); }
    else if (!strcmp(argv[i],"-key")) { keyscript[nkeys].frame=atol(argv[++i]); keyscript[nkeys].row=atoi(argv[++i]); keyscript[nkeys].bit=atoi(argv[++i]); keyscript[nkeys].dur=atoi(argv[++i]); nkeys++; }
    else vz = argv[i];
  }
  long len; memset(rom,0xC9,sizeof rom);
  { FILE *f=fopen(getenv("VZFONT")?getenv("VZFONT"):"tools/font.txt","r"); for (int i=0;i<3072;i++){unsigned v; if(fscanf(f,"%x,",&v)!=1){} font[i]=v;} fclose(f); }
  for (int i=0;i<8;i++) keyrow[i]=0x3F;
  memset(mem, 0, sizeof mem);
  // DOS present: jump table in bank0 (trapped)
  memset(sram, 0xFF, sizeof sram);
  for (int i=0x1F00;i<0x2000;i++) sram[0][i]=0xC9;
  uint8_t *v = load_file(vz, &len);
  uint16_t start = v[22] | (v[23]<<8);
  memcpy(mem + start, v + 24, len - 24);
  fprintf(stderr,"Loaded %s at %04X-%04lX\n", vz, start, start+len-24-1);
  z80_init(&cpu); cpu.read_byte = rd; cpu.write_byte = wrb; cpu.port_in = pin; cpu.port_out = pout;
  cpu.pc = start; cpu.sp = 0x7A00; cpu.iff1 = cpu.iff2 = 0; cpu.interrupt_mode = 1;
  if (loadsnap[0]) { FILE *f=fopen(loadsnap,"rb"); if(f){ z80 tmp; if(fread(&tmp,sizeof tmp,1,f)){} tmp.read_byte=rd; tmp.write_byte=wrb; tmp.port_in=pin; tmp.port_out=pout; cpu=tmp;
      if(fread(mem,1,sizeof mem,f)){} if(fread(sram,1,sizeof sram,f)){} if(fread(hibank,1,sizeof hibank,f)){}
      if(fread(&map37,sizeof map37,1,f)){} if(fread(&latch,1,1,f)){} if(fread(&T,sizeof T,1,f)){} if(fread(&frame_t0,sizeof frame_t0,1,f)){}
      if(fread(&frameno,sizeof frameno,1,f)){} if(fread(keyrow,sizeof keyrow,1,f)){} if(fread(&joyv,1,1,f)){} if(fread(&firev,1,1,f)){}
      if(fread(&cur_file,sizeof cur_file,1,f)){} if(fread(&cur_sector,sizeof cur_sector,1,f)){} fclose(f); } }
  // mimic DOS leaving latch at 0
  if (wavname) { wavf = fopen(wavname,"wb"); wav_header(wavf,0); }
  if (vidname) { vidf = fopen(vidname,"wb"); }
  unsigned long long frameT = (unsigned long long)LINES*TPL;
  maxT = (unsigned long long)(seconds * clk);
  if (!loadsnap[0]) frame_t0 = 0; latch_at_frame_start = latch; render_begin(); r_line = (T - frame_t0) / TPL; if (r_line > LINES) r_line = LINES;
  int npngdone = 0;
  while (T < maxT) {
    // FS state
    unsigned long long inframe = T - frame_t0;
    int line = inframe / TPL;
    fs_low = line < FS_LINES;
    cpu.int_pending = fs_low; cpu.int_data = 0xFF;
    if (dos_trap()) { T = cpu.cyc; goto after; }
    {
      uint16_t pc0 = cpu.pc;
      if (pc0 == regpc && regn > 0 && frameno > regfrom) { regn--; fprintf(stderr,"R f%d l%llu A=%02X BC=%02X%02X DE=%02X%02X HL=%02X%02X SP=%04X IX=%04X IY=%04X BC'=%02X%02X\n",frameno,(T-frame_t0)/228,cpu.a,cpu.b,cpu.c,cpu.d,cpu.e,cpu.h,cpu.l,cpu.sp,cpu.ix,cpu.iy,cpu.b_,cpu.c_); }
      if (lineat_pc >= 0 && pc0 == lineat_pc && frameno > 2) { long ln = (T - frame_t0) / 228; if (ln<400) line_hist[ln]++; }
      if (trace_pc >= 0 && pc0 == trace_pc) { if (last_pc_t) { long d = T - last_pc_t; if (d >= 4096) { d = 4095; if (frameno>0) { static int shown=0; long ln=(T-last_pc_t)/228; if (ln > 400 && ln < 700 && shown < 100000) { shown++; fprintf(stderr,"  long gap %ld lines at frame %d\n", ln, frameno); } } } pc_hist[d]++; } last_pc_t = T; pc_hits++; }
      pending_writes = 0;
      if (frameno > 2 && cpu.sp < minsp && cpu.sp > 0x7000) minsp = cpu.sp;
      unsigned long c0 = cpu.cyc;
      z80_step(&cpu);
      unsigned long c1 = cpu.cyc;
      for (int w=0; w<pending_writes; w++) {
        // approximate: writes happen at the end of the instruction, 3T apart
        unsigned long long wt = c1 - 3*(pending_writes-1-w) - 1;
        if (wavf) audio_advance(wt);
        wr_latch(pw_val[w], wt);
        int lvl = (pw_val[w]&1) - ((pw_val[w]>>5)&1); spklevel = lvl;
      }
      (void)c0;
    }
    T = cpu.cyc;
  after:
    if (wavf) audio_advance(T);
    while (r_line < LINES && T >= frame_t0 + (unsigned long long)(r_line + 1) * TPL) { render_line(r_line); r_line++; }
    while (T >= frame_t0 + frameT) {
      while (r_line < LINES) { render_line(r_line); r_line++; }
      // frame complete
      for (int k=0;k<nkeys;k++) { int rw=keyscript[k].row; uint8_t *tg = rw<8? (uint8_t*)0 : (rw==8? &joyv : &firev); if (frameno==keyscript[k].frame) { if(tg) *tg &= ~(1<<keyscript[k].bit); else keyrow[rw] &= ~(1<<keyscript[k].bit);} if (frameno==keyscript[k].frame+keyscript[k].dur) { if(tg) *tg |= (1<<keyscript[k].bit); else keyrow[rw] |= (1<<keyscript[k].bit);} }
      if (watch_addr>=0) fprintf(stderr,"F%d %04X\n",frameno,mem[watch_addr]|(mem[watch_addr+1]<<8));
      render_end();
      if (frameno==dumpmem_frame) { FILE *f=fopen(dumpmem_file,"wb"); fwrite(mem,1,65536,f); fwrite(sram[1],1,0x2800,f); fwrite(hibank,1,0x10000,f); fclose(f); }
      if (frameno==vram_frame) { for (int r=0;r<8;r++){ fprintf(stderr,"%04X:",0x7000+r*32); for(int c=0;c<32;c++) fprintf(stderr," %02X",mem[0x7000+r*32+c]); fprintf(stderr,"\n"); } }
      if (vidf) fwrite(rgb, 1, sizeof rgb, vidf);
      for (int p=0;p<npng;p++) if (pngframes[p]==frameno) {
        char fn[300]; snprintf(fn,300,"%s_%05d.ppm",snapbase,frameno); FILE *f=fopen(fn,"wb"); fprintf(f,"P6 320 240 255\n"); fwrite(rgb,1,sizeof rgb,f); fclose(f); npngdone++; }
      frame_t0 += frameT; frameno++; if (frameno==60) phase_on=1;
      if (until_frame >= 0 && frameno >= until_frame) { maxT = T; }
      latch_at_frame_start = latch;
      render_begin();
    }
  }
  if (savesnap[0]) { FILE *f=fopen(savesnap,"wb"); fwrite(&cpu,sizeof cpu,1,f); fwrite(mem,1,sizeof mem,f); fwrite(sram,1,sizeof sram,f); fwrite(hibank,1,sizeof hibank,f);
      fwrite(&map37,sizeof map37,1,f); fwrite(&latch,1,1,f); fwrite(&T,sizeof T,1,f); fwrite(&frame_t0,sizeof frame_t0,1,f);
      fwrite(&frameno,sizeof frameno,1,f); fwrite(keyrow,sizeof keyrow,1,f); fwrite(&joyv,1,1,f); fwrite(&firev,1,1,f);
      fwrite(&cur_file,sizeof cur_file,1,f); fwrite(&cur_sector,sizeof cur_sector,1,f); fclose(f); }
  if (wavf) { wav_header(wavf, nsamp); fclose(wavf); }
  if (vidf) fclose(vidf);
  fprintf(stderr,"minSP %04X\n",minsp);
  fprintf(stderr,"Frames %d  PC=%04X  map37=%d  writes>=FA00: %ld  DOS-bank0 writes: %ld  badDOS: %ld\n", frameno, cpu.pc, map37, guard_fa, guard_dos, bad_dos);
  { long tot=0; for(int i=0;i<228;i++) tot+=phase_hist[i]; if (tot) { fprintf(stderr,"latch write phases (mod 228):"); for(int i=0;i<228;i++) if (phase_hist[i]*200>tot) fprintf(stderr," %d:%.1f%%",i,100.0*phase_hist[i]/tot); fprintf(stderr,"\n"); } }
  if (lineat_pc >= 0) { long tot=0; for (int i=0;i<400;i++) tot+=line_hist[i]; long acc=0; fprintf(stderr,"line at PC %04X (n=%ld):",lineat_pc,tot); for (int i=0;i<400;i++){ acc+=line_hist[i]; if (line_hist[i]) {} } long c=0; int p50=-1,p90=-1,p99=-1,mx=0; for(int i=0;i<400;i++){c+=line_hist[i]; if(p50<0&&c*2>=tot)p50=i; if(p90<0&&c*10>=tot*9)p90=i; if(p99<0&&c*100>=tot*99)p99=i; if(line_hist[i])mx=i;} fprintf(stderr," p50 %d p90 %d p99 %d max %d (of %d)\n",p50,p90,p99,mx,LINES); }
  if (trace_pc >= 0) { fprintf(stderr,"PC %04X hits %ld; period histogram:\n", trace_pc, pc_hits); for (int i=0;i<4096;i++) if (pc_hist[i]) fprintf(stderr,"  %d T: %ld\n", i, pc_hist[i]); }
  return 0;
}
