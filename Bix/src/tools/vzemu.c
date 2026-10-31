// Minimal VZ300 test harness for BIX development.
// Flat 64K RAM, no ROM. Emulates: $6800 latch (mode/CSS/speaker), keyboard
// matrix reads, field-sync bit 7 (low for 56 of 312 lines), level-triggered
// INT during field sync, 3.5469 MHz / 228 T per line.
// usage: vzemu game.vz fields outdir [keyscript] [watchaddr_hex]
// keyscript lines: <field> <keys...>   (keys: L R U D J or none)
#include "z80.h"
#include <stdlib.h>
#include <string.h>

static uint8_t mem[65536];
static int alias5=0, aliasall=0, usercard=0, evenbank=0, romsel=0;
// BennVenn SD loader, per MAME sdloader.cpp: port $37 bit0 = DOS ROM/RAM view
// at $4000-$67FF, bit1 = which 10K RAM bank, bit2 = which bank at $B800-$FFFF
static uint8_t dosram[2][0x2800];
static uint8_t extram[2][0x4800];
static int mapper=1;
static int wlo=-1,whi=-1,wcnt=0; static z80 *gcpu;
static unsigned long long pchist[65536];
static int prof_from=-1;
static int slow3=0,ok2=0,fast1=0;
static uint8_t latch = 0;
static int line = 0;
static unsigned keys = 0; // bit0 L,1 R,2 U,3 D,4 J
static long spk_toggles = 0;
static FILE *wavf=0; static unsigned long wav_next=0; static int spk_level=0; static long wav_n=0;
static int WAV_RATE=22050;
#define CPU_HZ 3546900UL
static uint8_t last_spk = 0;

#define TPL 228
#define LINES 312
#define SYNC 56

static uint8_t kbd_read(uint16_t a) {
  uint8_t lo = a & 0xff, v = 0x3f;
  if (getenv("JOYONLY")) { return v | ((line < SYNC) ? 0 : 0x80) | 0x40; }
  // matrix: row A0..A7 low selects. we map: O(L) P(R) Q(U) A(D) SPACE(J)
  // also Z/X as left/right? keep O,P,Q,A,SPACE,M
  if (!(lo & 0x40)) { // row6: U P I RET O Y  -> P bit4, O bit1
    if (keys & 1) v &= ~0x02;
    if (keys & 2) v &= ~0x10;
  }
  if (!(lo & 0x01)) { if (keys & 4) v &= ~0x10; } // Q bit4 row0
  if (!(lo & 0x02)) { if (keys & 8) v &= ~0x10; if (keys & 64) v &= ~0x02; } // A bit4, S bit1 row1
  if (!(lo & 0x10)) { if (keys & 16) v &= ~0x10; } // SPACE bit4 row4
  if (!(lo & 0x04)) { if (keys & 32) v &= ~0x10; } // Z row2 bit4
  uint8_t fs = (line < SYNC) ? 0 : 0x80;
  return v | fs | 0x40;
}
static uint8_t rd(void *u, uint16_t a) {
  (void)u;
  if (a >= 0x6800 && a < 0x7000) return kbd_read(a);
  if (a >= 0x4000 && a < 0x6800) return (mapper&1) ? dosram[(mapper>>1)&1][a-0x4000] : 0xFF;
  if (a >= 0xB800) return extram[(mapper>>2)&1][a-0xB800];
  return mem[a];
}
static long latch_writes = 0; long spkpc[65536];
static void wr(void *u, uint16_t a, uint8_t v) {
  (void)u;
  if (a >= 0x6800 && a < 0x7000) {
    uint8_t s = v & 0x21;
    if (s != last_spk) { spk_toggles++; last_spk = s; }
    spk_level = (v & 0x01) ? 1 : 0;
    latch = v; latch_writes++; { extern long spkpc[65536]; if (s!=0xFF) spkpc[gcpu->pc]++; }
    return;
  }
  if (a < 0x4000) return; // ROM
  if (a < 0x6800) { dosram[(mapper>>1)&1][a-0x4000]=v; return; }
  if (a >= 0xB800) { if (a>=wlo && a<=whi && !(mapper&4)) fprintf(stderr,"W %04x=%02x pc=%04x\n",a,v,gcpu->pc); extram[(mapper>>2)&1][a-0xB800]=v; return; }
  if (a>=wlo && a<=whi && wcnt<1000000) { fprintf(stderr,"W %04x=%02x pc=%04x\n",a,v,gcpu->pc); wcnt++; }
  mem[a] = v;
}
static int joydir=-1, joyfire=-1;
static FILE *tracef=0;
static uint8_t pin(z80 *z, uint8_t p) { (void)z;
  uint8_t v = 0xff;
  if (p == joydir) { if (keys&4) v&=~1; if (keys&8) v&=~2; if (keys&1) v&=~4; if (keys&2) v&=~8; }
  if (p == joyfire && (keys&16)) v&=~0x10;
  return v; }
static void pout(z80 *z, uint8_t p, uint8_t v) { (void)z; if (p==0x37) mapper=v; }

static const uint8_t pal[2][4][3] = {
  {{0x30, 0xd0, 0x30}, {0xf0, 0xf0, 0x50}, {0x30, 0x40, 0xd8}, {0xd8, 0x30, 0x30}},
  {{0xe8, 0xe8, 0xd0}, {0x40, 0xd0, 0xd0}, {0xd0, 0x40, 0xd0}, {0xf0, 0x90, 0x30}}};

static void dump(const char *dir, int f) {
  char fn[512];
  sprintf(fn, "%s/f%05d.ppm", dir, f);
  FILE *o = fopen(fn, "wb");
  fprintf(o, "P6\n128 64\n255\n");
  int css = (latch >> 4) & 1;
  for (int y = 0; y < 64; y++)
    for (int x = 0; x < 128; x++) {
      uint8_t b = mem[0x7000 + y * 32 + x / 4];
      int c = (b >> (6 - 2 * (x & 3))) & 3;
      if (!(latch & 8)) { // mode 0: just render bytes greyish so we see something
        uint8_t ch = mem[0x7000 + (y / 4) * 32 + x / 4];
        uint8_t g = ch ? 0xc0 : 0x10;
        fputc(g, o); fputc(g, o); fputc(g, o); continue;
      }
      fwrite(pal[css][c], 1, 3, o);
    }
  fclose(o);
}

int main(int argc, char **argv) {
  if (argc < 4) { fprintf(stderr, "usage\n"); return 1; }
  FILE *f = fopen(argv[1], "rb");
  uint8_t hdr[24];
  fread(hdr, 1, 24, f);
  uint16_t start = hdr[22] | (hdr[23] << 8);
  static uint8_t img[65536];
  size_t n = fread(img, 1, 65536 - start, f);
  for (size_t i = 0; i < n; i++) {
    unsigned ad = start + i;
    if (ad >= 0xB800) extram[0][ad-0xB800] = img[i];
    else if (ad >= 0x4000 && ad < 0x6800) dosram[0][ad-0x4000] = img[i];
    else mem[ad] = img[i];
  }
  fclose(f);
  fprintf(stderr, "loaded %zu bytes at %04x-%04x\n", n, start, (unsigned)(start + n - 1));
  int fields = atoi(argv[2]);
  const char *dir = argv[3];
  // key script
  int kf[4096]; unsigned kv[4096]; int nk = 0;
  int dumpf[4096]; int nd = 0;
  if (argc > 4 && strcmp(argv[4], "-")) {
    FILE *k = fopen(argv[4], "r");
    char ln[256];
    while (fgets(ln, sizeof ln, k)) {
      int fr; char ks[64] = "";
      if (ln[0] == 'S') { dumpf[nd++] = atoi(ln + 1); continue; }
      if (sscanf(ln, "%d %63s", &fr, ks) < 1) continue;
      unsigned m = 0;
      for (char *c = ks; *c; c++) {
        if (*c == 'L') m |= 1; if (*c == 'R') m |= 2; if (*c == 'U') m |= 4;
        if (*c == 'D') m |= 8; if (*c == 'J') m |= 16; if (*c == 'Z') m |= 32; if (*c == 'S') m |= 64;
      }
      kf[nk] = fr; kv[nk++] = m;
    }
    fclose(k);
  }
  int watch = argc > 5 ? (int)strtol(argv[5], 0, 16) : -1;
  if (argc > 6) prof_from = atoi(argv[6]);
  z80 cpu;
  if (getenv("WAVRATE")) WAV_RATE=atoi(getenv("WAVRATE"));
  if (getenv("WAV")) { wavf=fopen(getenv("WAV"),"wb"); fseek(wavf,44,SEEK_SET); }
  if (getenv("JOYDIR")) joydir=strtol(getenv("JOYDIR"),0,16); if (getenv("JOYFIRE")) joyfire=strtol(getenv("JOYFIRE"),0,16);
  if (getenv("TRACE")) tracef=fopen(getenv("TRACE"),"w");
  alias5=getenv("ALIAS5")!=0; usercard=getenv("USERCARD")!=0; evenbank=getenv("EVENBANK")?atoi(getenv("EVENBANK")):0; aliasall=getenv("ALIASALL")!=0;
  z80_init(&cpu); gcpu=&cpu; if(getenv("WLO")){wlo=strtol(getenv("WLO"),0,16);whi=strtol(getenv("WHI"),0,16);}
  cpu.read_byte = rd; cpu.write_byte = wr; cpu.port_in = pin; cpu.port_out = pout;
  cpu.pc = start;
  // pick up the entry from a VZ machine code file: start address is load addr
  unsigned long t = 0;
  uint8_t lastw = watch >= 0 ? mem[watch] : 0;
  int ki = 0;
  unsigned long lastwt = 0, maxgap = 0; int wcount = 0;
  for (int fld = 0; fld < fields; fld++) {
    while (ki < nk && kf[ki] <= fld) keys = kv[ki++];
    for (line = 0; line < LINES; line++) {
      unsigned long end = t + TPL;
      while (cpu.cyc < end) {
        cpu.int_pending = (line < SYNC);
        cpu.int_data = 0xff;
        if (wavf) while (cpu.cyc >= wav_next) { short smp = spk_level ? 6000 : -6000; fwrite(&smp,2,1,wavf); wav_n++; wav_next = (unsigned long)((double)wav_n * CPU_HZ / WAV_RATE); }
        { uint16_t pc0=cpu.pc; unsigned long c0=cpu.cyc; z80_step(&cpu); if (prof_from>=0 && fld>=prof_from) pchist[pc0]+=cpu.cyc-c0; }
        if (watch >= 0 && mem[watch] != lastw) {
          lastw = mem[watch]; wcount++;
          unsigned long g = cpu.cyc - lastwt; lastwt = cpu.cyc;
          if (wcount > 3 && g > maxgap) maxgap = g; if (wcount>3 && fld>=prof_from) { if (g>150000) slow3++; else if (g>78000) ok2++; else fast1++; }
        }
      }
      t = end;
    }
    if (tracef) { fprintf(tracef, "%d %d %d %d %d %d %d %d %d %d\n", fld, mem[0x7829]|mem[0x782a]<<8, (signed char)mem[0x782b], mem[0x7819], mem[0x7806]|mem[0x7807]<<8, mem[0x7808], mem[0x782d], mem[0x7852], mem[0x7821], keys); }
    if (getenv("ENTLOG")) { static FILE *ef=0; if(!ef) ef=fopen(getenv("ENTLOG"),"w");
      fprintf(ef,"%d %d %d",fld,mem[0x7806]|mem[0x7807]<<8,mem[0x7852]);
      for(int i=0;i<10;i++){uint8_t*e=&dosram[0][0x2000+i*16]; fprintf(ef," %d:%d:%d:%d",e[0],e[2]|e[3]<<8,e[10],e[4]);} fprintf(ef," | sa%d lo%d hi%d st%d,%d,%d rec",mem[0x93AE],mem[0x93AA],mem[0x93AC],dosram[0][0x2120],dosram[0][0x2121],dosram[0][0x2122]); for(int i=0;i<4;i++){uint8_t*r=&dosram[0][0x2300+i*5]; fprintf(ef," %d,%d,%d,%d",r[0]|r[1]<<8,r[2],r[3],r[4]);} fprintf(ef,"\n"); }
    int dd = 0;
    for (int i = 0; i < nd; i++) if (dumpf[i] == fld) dd = 1;
    if (dd) dump(dir, fld);
  }
  fprintf(stderr, "fields=%d pc=%04x latch=%02x spk_toggles=%ld", fields, cpu.pc, latch, spk_toggles);
  if (watch >= 0) fprintf(stderr, " watch_changes=%d (%.2f fps) maxgap=%lu T", wcount, wcount * 50.0 / fields, maxgap);
  fprintf(stderr, " frames: 1fld=%d 2fld=%d 3+fld=%d\n",fast1,ok2,slow3);
  if (tracef) fclose(tracef);
  if (getenv("MEMDUMP")) { FILE*q=fopen(getenv("MEMDUMP"),"wb"); uint8_t b[65536]; for(int i=0;i<65536;i++) b[i]=rd(0,i); fwrite(b,1,65536,q); fclose(q);} 
  if (getenv("SPKPC")) { FILE*q=fopen(getenv("SPKPC"),"w"); for(int i=0;i<65536;i++) if(spkpc[i]) fprintf(q,"%04x %ld\n",i,spkpc[i]); fclose(q);} 
  if (wavf) { unsigned int dl=wav_n*2, rl=36+dl; unsigned char h[44]={'R','I','F','F',0,0,0,0,'W','A','V','E','f','m','t',' ',16,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,2,0,16,0,'d','a','t','a',0,0,0,0};
    memcpy(h+4,&rl,4); unsigned int sr=WAV_RATE, br=WAV_RATE*2; memcpy(h+24,&sr,4); memcpy(h+28,&br,4); memcpy(h+40,&dl,4);
    fseek(wavf,0,SEEK_SET); fwrite(h,1,44,wavf); fclose(wavf); }
  if (prof_from>=0){ FILE *p=fopen("/tmp/vzprof.bin","wb"); fwrite(pchist,8,65536,p); fclose(p);}
  memcpy(mem+0x4000, dosram[(mapper>>1)&1], 0x2800);
  memcpy(mem+0xB800, extram[(mapper>>2)&1], 0x4800);
  FILE *m = fopen("/tmp/vzmem.bin", "wb"); fwrite(mem, 1, 65536, m); fclose(m);
  return 0;
}
