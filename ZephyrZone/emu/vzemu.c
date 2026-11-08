// VZ300 + BennVenn SD/128K emulator harness for testing.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"

#define LINES 312
#define LINET 228
static int FRAMET = LINES * LINET;   // VZ_SKEW env adds T-states per frame (timing robustness tests)
#define FSLINES 56
#define ACTIVE_START 64   // first active display line (approx)

static uint8_t rom[0x4000];
static uint8_t ram[0x10000];     // internal: 7000-B7FF used (video 7000-77FF)
static uint8_t bv[0x20000];      // BennVenn 128K: dos banks 0x00000/0x08000, exp banks 0x10000/0x18000
unsigned minsp=0xFFFF, minsp_pc;
static uint8_t mapper = 0, vz300mode = 1;
static uint8_t latch = 0;
static uint8_t keys[8];          // active low rows (bits 0-5)
static uint8_t joy[4] = {0xff, 0xff, 0xff, 0xff}; // j1 dir, j2 dir, j1 arm, j2 arm (active low bits)
static z80 cpu;
static unsigned long long tstate = 0;  // global
static unsigned long frames = 0;
static int fs_low = 0;
static uint16_t curpc;
static unsigned long prof[65536]; static int profon = 0;
static uint8_t bpmap[65536]; static FILE *bplog = 0; static int bpmem = -1;
static uint8_t cov[65536]; static int covon = 0;
static uint8_t watchw[65536]; static FILE *wlog = 0;
static int halted_badly = 0;
// speaker capture
static int spk = 0; static FILE *wavf = 0; static unsigned long long wav_t = 0; static long wav_n = 0;
static double wav_acc = 0;
static uint8_t rb(void *u, uint16_t a); static void wb(void *u, uint16_t a, uint8_t v);
static char sddir[256] = "."; static FILE *sdf = 0; static unsigned long sdcalls = 0;
static void dos_trap(void) {
  uint16_t pc = cpu.pc; uint16_t buf = rb(0,0xFB80) | rb(0,0xFB81) << 8;
  if (pc == 0x5F00) {
    char name[64]; int n = 0; uint16_t p = (cpu.h << 8) | cpu.l; if (rb(0,p) == '"') p++;
    while (n < 60) { uint8_t c = rb(0,p++); if (c == '"' || c == 0) break; name[n++] = c; } name[n] = 0;
    char fn[400]; snprintf(fn, sizeof fn, "%s/%s.DAT", sddir, name);
    if (sdf) fclose(sdf); sdf = fopen(fn, "rb");
    wb(0,0xFB03, sdf ? 1 : 0); wb(0,0xFB05, 0);
    if (sdcalls++ < 200) fprintf(stderr, "DOS open %s -> %s (frame %lu)\n", fn, sdf ? "ok" : "MISSING", frames);
  } else {
    uint8_t d[512]; memset(d, 0, 512); if (sdf) fread(d, 1, 512, sdf);
    for (int i = 0; i < 512; i++) wb(0, buf + i, d[i]);
  }
  if (getenv("DOSSTACK")) { int n=atoi(getenv("DOSSTACK")); for (int i=1;i<=n;i++) wb(0,(uint16_t)(cpu.sp-2-i),(uint8_t)(rand()&0xff)); }  // the real DOS's own stack use below the caller's SP
  if (getenv("DOSCLOBBER")) { for (int a = 0x7AF8; a < 0x7C00; a++) wb(0, a, (uint8_t)(rand() & 0xff)); }  // stand-in for the real DOS's RAM use
  uint16_t r = rb(0,cpu.sp) | rb(0,cpu.sp + 1) << 8; cpu.sp += 2; cpu.pc = r;
}
static int trapmode = 0; static unsigned long traps = 0;
#define RING 20000
static uint16_t rpc[RING], rsp[RING], raf[RING], rhl[RING], rde[RING], rbc[RING]; static int rpos = 0; static int crashpc = -1; static int crashed = 0;

static uint8_t *bvptr(uint16_t a) {
  if (a >= 0x4000 && a < 0x6800) return &bv[((mapper & 2) ? 0x8000 : 0) + (a - 0x4000)];
  if (a >= 0x9000) { if (vz300mode && a < 0xb800) return 0; return &bv[((mapper & 4) ? 0x18000 : 0x10000) + (a & 0x7fff)]; }
  return 0;
}
static int protect=0; static unsigned long protviol=0;
static int specpc(uint16_t p){ return (p>=0x7800 && p<0xCA09) || (p>=0x5B00 && p<0x6498) || (p>=0x66B5 && p<0x66DE); }
static int protaddr(uint16_t a){ return (a>=0x4000 && a<0x5B00) || (a>=0x6498 && a<0x66B5) || (a>=0xD800 && a<0xF661) || (a>=0x8800 && a<0x9800 && (a&0xFF)<0xE0) || (a>=0x9800 && a<0x9A00) || (a>=0x6800 && a<0x7800); }
static uint8_t rb(void *u, uint16_t a) {
  if (covon) cov[a] |= 2;
  if (a < 0x4000) { return rom[a]; }
  if (a < 0x6800) { if (mapper & 1) return *bvptr(a); return 0xff; }
  if (a < 0x7000) {
    uint8_t r = 0x3f; uint8_t lo = a & 0xff;
    for (int i = 0; i < 8; i++) if (!(lo & (1 << i))) r &= keys[i];
    r |= 0x40; if (!fs_low) r |= 0x80;
    return r;
  }
  if (a < 0xb800) return ram[a];
  uint8_t *p = bvptr(a); return p ? *p : 0xff;
}
static unsigned long fstart = 0;
static int tmark=-1; static FILE *tmf=0;
static void wb(void *u, uint16_t a, uint8_t v) {
  if (a==tmark && tmf) fprintf(tmf,"%lu %llu %d\n",frames,tstate+(cpu.cyc-fstart),v);
  if (covon) cov[a] |= 4;
  if (watchw[a] && wlog) { fprintf(wlog, "%lu PC=%04X W %04X=%02X\n", frames, curpc, a, v); fflush(wlog); }
  if (a < 0x4000) { if (trapmode) { traps++; if (traps < 20) fprintf(stderr, "ROM write %04X at PC %04X\n", a, curpc); } return; }
  if (a < 0x6800) { *bvptr(a) = v; return; }
  if (a < 0x7000) {
    if (!(v&8) && getenv("LATCHDBG")) { static int n=0; if(n++<10) fprintf(stderr,"latch %04X=%02X pc=%04X frame %lu\n",a,v,curpc,frames);}
    int ns = ((v >> 5) & 1) ^ (v & 1) ? ((v >> 5) & 1) : spk; // speaker level from bit5 (bit0 complement)
    spk = (v >> 5) & 1; (void)ns;
    latch = v; return;
  }
  if (a < 0xb800) { ram[a] = v; return; }
  uint8_t *p = bvptr(a); if (p) *p = v;
}

static void ls_hook(uint16_t pc){ (void)pc; }
static uint8_t pin(z80 *z, uint16_t p) {
  uint8_t lo = p & 0xff;
  if (lo >= 0x20 && lo <= 0x2f) {
    uint8_t r = 0xff;
    if (!(lo & 1)) r &= joy[0];
    if (!(lo & 2)) r &= joy[1];
    if (!(lo & 4)) r &= joy[2];
    if (!(lo & 8)) r &= joy[3];
    return r;
  }
  return 0xff;
}
static void pout(z80 *z, uint16_t p, uint8_t v) {
  uint8_t lo = p & 0xff;
  if (lo == 0x37) mapper = v;
  else if (lo == 0x3a) vz300mode = v & 1;
}

static double wav_hi = 0; static unsigned long long wav_last = 0;
static void wav_advance(unsigned long long t) {
  if (!wavf) return;
  // 44100 Hz, box-filtered (speaker level integrated over each sample)
  const double tps = 3546875.0 / 44100.0;
  if (wav_last < wav_t) wav_last = wav_t;
  while (1) {
    double end = wav_t + tps;
    if ((double)t < end) { if (spk) wav_hi += (double)(t - wav_last); wav_last = t; break; }
    if (spk) wav_hi += end - (double)wav_last;
    double f = wav_hi / tps; int16_t s = (int16_t)((f * 2 - 1) * 12000);
    fwrite(&s, 2, 1, wavf); wav_n++;
    wav_hi = 0; wav_t = (unsigned long long)end; wav_last = wav_t;
  }
}

static unsigned long a360 = 0;
// one emulation step; returns 0 at a frame boundary (nothing executed)
static int emu_step(void) {
  if (cpu.cyc - fstart >= FRAMET) { tstate += cpu.cyc - fstart; frames++; fstart = cpu.cyc; return 0; }
  int line = (cpu.cyc - fstart) / LINET;
  fs_low = line < FSLINES;
  if (fs_low) { if (!cpu.int_pending) z80_gen_int(&cpu, 0xff); } else cpu.int_pending = 0;
  unsigned long c0 = cpu.cyc;
  curpc = cpu.pc;
  if (crashpc >= 0) { rpc[rpos]=curpc; rsp[rpos]=cpu.sp; raf[rpos]=(cpu.a<<8); rhl[rpos]=(cpu.h<<8)|cpu.l; rde[rpos]=(cpu.d<<8)|cpu.e; rbc[rpos]=(cpu.b<<8)|cpu.c; rpos=(rpos+1)%RING;
    if ((curpc == crashpc || (crashpc==1 && ((curpc>=0xAA00 && curpc<0xB800) || curpc>=0xC800 || (cpu.sp>=0x7000 && cpu.sp<0x7D70) || (curpc<0x4000 && curpc!=0x38 && curpc!=0x39 && curpc!=0x3A)))) && !crashed) { crashed=1; FILE *g=fopen("crash.txt","w"); for(int i=0;i<RING;i++){int k=(rpos+i)%RING; fprintf(g,"%04X SP=%04X A=%02X BC=%04X DE=%04X HL=%04X\n",rpc[k],rsp[k],raf[k]>>8,rbc[k],rde[k],rhl[k]);} fclose(g); fprintf(stderr,"crash trace written at frame %lu\n",frames); { FILE *h=fopen("crashmem.bin","wb"); for (int q=0;q<65536;q++) fputc(rb(0,q),h); fclose(h);} } }
  if (covon) cov[curpc] = 1;
  ls_hook(curpc);
  if (!(mapper & 2) && (curpc == 0x5F00 || curpc == 0x5F03 || curpc == 0x5F09)) { dos_trap(); return 1; }
  if (bpmap[curpc] && bplog) {
    fprintf(bplog, "%lu L%d %04X A=%02X BC=%04X DE=%04X HL=%04X IX=%04X IY=%04X SP=%04X |", frames, line, curpc, cpu.a, (cpu.b << 8) | cpu.c, (cpu.d << 8) | cpu.e, (cpu.h << 8) | cpu.l, cpu.ix, cpu.iy, cpu.sp);
    for (int q = 0; q < 8; q++) fprintf(bplog, " %02X", rb(0, cpu.sp + q)); if (bpmem>=0) { fprintf(bplog, " M="); for (int q=0;q<8;q++) fprintf(bplog,"%02X ", rb(0,bpmem+q)); fprintf(bplog," IX28="); for(int q=28;q<32;q++) fprintf(bplog,"%02X ",rb(0,cpu.ix+q)); } fprintf(bplog, "\n");
  }
  if (curpc == 0xA360) a360++;
  { int was=cpu.iff1; z80_step(&cpu); { extern unsigned minsp, minsp_pc; if (cpu.sp>=0x7800 && cpu.sp<0x7E01 && cpu.sp<minsp){minsp=cpu.sp;minsp_pc=curpc;} } static int seen[65536]; if (getenv("IFFDBG") && was && !cpu.iff1 && cpu.pc!=0xB0B0 && curpc!=0x8548 && seen[curpc]++<3) fprintf(stderr,"iff1 off at pc %04X frame %lu sp %04X\n",curpc,frames,cpu.sp); }
  int d = cpu.cyc - c0;
  if (profon) prof[curpc] += d;
  wav_advance(tstate + (cpu.cyc - fstart));
  return 1;
}
static void run_frames(int n) {
  unsigned long target = frames + n; static int dis=0;
  while (frames < target) { unsigned long f=frames; emu_step();
    if (frames!=f && getenv("IFFDBG")) { if (!cpu.iff1) { if (++dis==3) { fprintf(stderr,"IFF off 3 frames at frame %lu pc %04X\n",frames,cpu.pc); if (frames>10 && crashpc>=0) { FILE *g=fopen("crash.txt","w"); for(int i=0;i<RING;i++){int k=(rpos+i)%RING; fprintf(g,"%04X SP=%04X A=%02X BC=%04X DE=%04X HL=%04X\n",rpc[k],rsp[k],raf[k]>>8,rbc[k],rde[k],rhl[k]);} fclose(g);} } } else dis=0; } }
}
// run until A360 has been executed k more times (stops just before the next one)
static void run_iters(int k) {
  unsigned long t = a360 + k;
  while (1) { if (a360 >= t && cpu.pc == 0xA360) break; emu_step(); }
}

static const int pal[16][3] = {
  {0x30,0xd2,0x00},{0xc1,0xe5,0x00},{0x4c,0x3a,0xb4},{0x9a,0x32,0x36},
  {0xbf,0xc8,0xad},{0x41,0xaf,0x71},{0xc8,0x4e,0xf0},{0xd4,0x7f,0x00},
  {0x26,0x30,0x16},{0x00,0x7c,0x00},{0x30,0xd2,0x00},{0x6b,0x27,0x00},{0xff,0xb7,0x00},{0,0,0},{0,0,0},{0,0,0}};
#include "font6847.h"
static int fontbit(int ch,int x,int y){ return (font6847[ch&63][y]>>(4-x))&1; }

static void save_screen(const char *fn) {
  static uint8_t img[192][256][3];
  int mode = (latch >> 3) & 1, css = (latch >> 4) & 1;
  for (int y = 0; y < 192; y++) for (int x = 0; x < 256; x++) {
    int c;
    if (mode) {
      int vy = y / 3, vx = x / 2;
      uint8_t b = ram[0x7000 + vy * 32 + vx / 4];
      int pix = (b >> (6 - 2 * (vx & 3))) & 3;
      c = pix + (css ? 4 : 0);
      img[y][x][0] = pal[c][0]; img[y][x][1] = pal[c][1]; img[y][x][2] = pal[c][2];
    } else {
      int cy = y / 12, cx = x / 8; uint8_t b = ram[0x7000 + cy * 32 + cx];
      int ry = y % 12, rx = x % 8; int on; int fg, bg;
      if (b & 0x80) { // SG4
        int q = (ry < 6 ? 0 : 2) + (rx < 4 ? 0 : 1); on = (b >> (3 - q)) & 1; fg = (b >> 4) & 7; bg = 13;
        if (on) { img[y][x][0] = pal[fg][0]; img[y][x][1] = pal[fg][1]; img[y][x][2] = pal[fg][2]; }
        else { img[y][x][0] = 0x10; img[y][x][1] = 0x10; img[y][x][2] = 0x10; }
        continue;
      }
      int inv = (b >> 6) & 1; int ch = b & 63;
      on = 0; if (ry >= 3 && ry < 10 && rx >= 1 && rx < 6) on = fontbit(ch, rx - 1, ry - 3);
      on ^= inv;
      fg = css ? 12 : 10; bg = css ? 11 : 9;
      c = on ? fg : bg;
      img[y][x][0] = pal[c][0]; img[y][x][1] = pal[c][1]; img[y][x][2] = pal[c][2];
    }
  }
  FILE *f = fopen(fn, "wb"); fprintf(f, "P6\n256 192\n255\n"); fwrite(img, 1, sizeof img, f); fclose(f);
}

static void load_vz(const char *fn, int run) {
  FILE *f = fopen(fn, "rb"); if (!f) { perror(fn); exit(1); }
  static uint8_t d[70000]; int n = fread(d, 1, sizeof d, f); fclose(f);
  int start = d[22] | d[23] << 8;
  for (int i = 24; i < n; i++) wb(0, start + i - 24, d[i]);
  fprintf(stderr, "loaded %s type %02X start %04X len %d end %04X\n", fn, d[21], start, n - 24, start + n - 24);
  if (run) cpu.pc = start;
}

static void setkey(const char *k, int down) {
  static const char *rows[8][6] = {
    {"T","W","","E","Q","R"},{"G","S","CTRL","D","A","F"},{"B","X","SHIFT","C","Z","V"},{"5","2","","3","1","4"},
    {"N",".","",",","SPACE","M"},{"6","9","-","8","0","7"},{"Y","O","RETURN","I","P","U"},{"H","L",":","K",";","J"}};
  for (int r = 0; r < 8; r++) for (int b = 0; b < 6; b++) if (rows[r][b][0] && !strcmp(rows[r][b], k)) { if (down) keys[r] &= ~(1 << b); else keys[r] |= 1 << b; return; }
  fprintf(stderr, "unknown key %s\n", k);
}

static void pr_minsp(void){ fprintf(stderr,"min SP in stack area %04X at pc %04X\n",minsp,minsp_pc); }
int main(int argc, char **argv) {
  atexit(pr_minsp);
  if (getenv("RANDRAM")) { srand(atoi(getenv("RANDRAM"))); for (int i = 0x7800; i < 0x10000; i++) ram[i] = rand(); for (int i = 0; i < 0x20000; i++) bv[i] = rand(); }  // power-on RAM is not zero
  if (getenv("VZ_SKEW")) FRAMET += atoi(getenv("VZ_SKEW"));
  if (argc < 2) { fprintf(stderr, "vzemu script\n"); return 1; }
  memset(keys, 0x3f, 8); memset(rom, 0xff, sizeof rom);
  rom[0x38] = 0xFB; rom[0x39] = 0xED; rom[0x3A] = 0x4D;   // EI / RETI (VZ ROM handler stand-in)
  z80_init(&cpu); cpu.read_byte = rb; cpu.write_byte = wb; cpu.port_in = pin; cpu.port_out = pout;
  cpu.sp = 0xb7f0; cpu.interrupt_mode = 1;
  FILE *s = fopen(argv[1], "r"); char line[256];
  while (fgets(line, sizeof line, s)) {
    char cmd[64], a1[128] = "", a2[128] = ""; if (sscanf(line, "%63s %127s %127s", cmd, a1, a2) < 1 || cmd[0] == ';') continue;
    if (!strcmp(cmd, "vz")) load_vz(a1, 1);
    else if (!strcmp(cmd, "frames")) run_frames(atoi(a1));
    else if (!strcmp(cmd, "iters")) run_iters(atoi(a1));
    else if (!strcmp(cmd, "down")) setkey(a1, 1);
    else if (!strcmp(cmd, "up")) setkey(a1, 0);
    else if (!strcmp(cmd, "tap")) { setkey(a1, 1); run_frames(4); setkey(a1, 0); run_frames(4); }
    else if (!strcmp(cmd, "joy")) { joy[atoi(a1)] = strtol(a2, 0, 16); }
    else if (!strcmp(cmd, "screen")) save_screen(a1);
    else if (!strcmp(cmd, "regs")) { fprintf(stderr, "frame %lu mapper %02X latch %02X ", frames, mapper, latch); fflush(stderr); z80_debug_output(&cpu); fflush(stdout); }
    else if (!strcmp(cmd, "prof")) { profon = atoi(a1); if (profon) memset(prof, 0, sizeof prof); }
    else if (!strcmp(cmd, "profsave")) { FILE *g = fopen(a1, "w"); for (int i = 0; i < 65536; i++) if (prof[i]) fprintf(g, "%04X %lu\n", i, prof[i]); fclose(g); }
    else if (!strcmp(cmd, "bp")) bpmap[strtol(a1, 0, 16)] = 1;
    else if (!strcmp(cmd, "bpmem")) bpmem = strtol(a1, 0, 16);
    else if (!strcmp(cmd, "bplog")) { if (bplog) fclose(bplog); bplog = fopen(a1, "w"); }
    else if (!strcmp(cmd, "watch")) { watchw[strtol(a1, 0, 16)] = 1; if (!wlog) wlog = fopen("watch.txt", "w"); }
    else if (!strcmp(cmd, "wav")) { wavf = fopen(a1, "wb"); char hdr[44] = {0}; fwrite(hdr, 1, 44, wavf); wav_t = tstate; wav_n = 0; }
    else if (!strcmp(cmd, "wavend")) { if (wavf) { long n = wav_n; fseek(wavf, 0, SEEK_SET);
        uint32_t sr = 44100, br = 88200, ds = n * 2, rs = 36 + ds; uint16_t fmt = 1, ch = 1, ba = 2, bps = 16; uint32_t fl = 16;
        fwrite("RIFF", 1, 4, wavf); fwrite(&rs, 4, 1, wavf); fwrite("WAVEfmt ", 1, 8, wavf); fwrite(&fl, 4, 1, wavf); fwrite(&fmt, 2, 1, wavf); fwrite(&ch, 2, 1, wavf);
        fwrite(&sr, 4, 1, wavf); fwrite(&br, 4, 1, wavf); fwrite(&ba, 2, 1, wavf); fwrite(&bps, 2, 1, wavf); fwrite("data", 1, 4, wavf); fwrite(&ds, 4, 1, wavf); fclose(wavf); wavf = 0; } }
    else if (!strcmp(cmd, "dump")) { // dump 64K view
      FILE *g = fopen(a1, "wb"); for (int i = 0; i < 65536; i++) fputc(rb(0, i), g); fclose(g); }
    else if (!strcmp(cmd, "cov")) covon = atoi(a1);
    else if (!strcmp(cmd, "covsave")) { FILE *g = fopen(a1, "wb"); fwrite(cov, 1, 65536, g); fclose(g); }
    else if (!strcmp(cmd, "rand")) { int n=atoi(a1); const char *ks[5]={"SPACE","Q","A","O","P"}; srand(atoi(a2)+frames);
        for(int i=0;i<n;i+=8){ for(int k=0;k<5;k++) setkey(ks[k], (rand()%3)==0 || (k==0 && rand()%2)); run_frames(8);} for(int k=0;k<5;k++) setkey(ks[k],0); }
    else if (!strcmp(cmd, "bvload")) { FILE *g=fopen(a1,"rb"); if(!g){perror(a1);exit(1);} int off=strtol(a2,0,16); int n=fread(bv+off,1,0x20000-off,g); fclose(g); fprintf(stderr,"bvload %s at bv+%05X len %d\n",a1,off,n); }
    else if (!strcmp(cmd, "bvsave")) { FILE *g=fopen(a1,"wb"); fwrite(bv,1,0x20000,g); fclose(g); }
    else if (!strcmp(cmd, "loadbin")) { FILE *g=fopen(a1,"rb"); if(!g){perror(a1);exit(1);} static uint8_t d[70000]; int n=fread(d,1,sizeof d,g); fclose(g); int ad=strtol(a2,0,16); for(int i=0;i<n;i++) wb(0,(ad+i)&0xffff,d[i]); }
    else if (!strcmp(cmd, "setpc")) { cpu.pc=strtol(a1,0,16); }
    else if (!strcmp(cmd, "mapper")) { mapper=strtol(a1,0,16); }
    else if (!strcmp(cmd, "fill")) { int a=strtol(a1,0,16), b=strtol(a2,0,16); for (int i=a;i<=b;i++) wb(0,i,(i*7+3)&255); }
    else if (!strcmp(cmd, "sd")) { strncpy(sddir, a1, 255); }
    else if (!strcmp(cmd, "dosmode")) { mapper = atoi(a1); }
    else if (!strcmp(cmd, "bpclear")) memset(bpmap,0,sizeof bpmap);
    else if (!strcmp(cmd, "poke")) { wb(0, strtol(a1,0,16), strtol(a2,0,16)); }
    else if (!strcmp(cmd, "trap")) trapmode = 1;
    else if (!strcmp(cmd, "tmark")) { tmark=strtol(a1,0,16); tmf=fopen(a2,"w"); }
    else if (!strcmp(cmd, "png")) { save_screen(a1); }
    else if (!strcmp(cmd, "protect")) protect = 1;
    else if (!strcmp(cmd, "crash")) crashpc = strtol(a1,0,16);
    else if (!strcmp(cmd, "untilpc")) { unsigned pc = strtol(a1, 0, 16); int mx = atoi(a2) * FRAMET; unsigned long st = cpu.cyc;
        if (cpu.pc == pc) z80_step(&cpu);
        while (cpu.pc != pc && (long)(cpu.cyc - st) < mx) { curpc = cpu.pc; z80_step(&cpu); } fprintf(stderr, "untilpc %04X reached=%d cyc %lu\n", pc, cpu.pc == pc, (unsigned long)cpu.cyc); }
    else fprintf(stderr, "?? %s\n", cmd);
  }
  return 0;
}
