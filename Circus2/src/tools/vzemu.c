// vzemu - minimal VZ200/VZ300 test harness for Circus 2 development
// Z80 core: superzazu/z80 (MIT).  Models: 64K map, keyboard matrix at $6800,
// output latch (speaker bits 0/5, mode bit 3, CSS bit 4), 6847 VRAM $7000-$77FF,
// field sync on $6800 bit 7 (low for 56 of 312 lines) driving a level INT,
// joystick ports $20-$2F (active low), speaker capture to WAV.
#include "../../z80core/z80.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static uint8_t mem[65536];
static uint8_t latch = 0;
static int fs_low = 0;
static int ramtop = 0xFFFF;   // -stock => 0xB7FF
static uint8_t keyrow[8];     // active low bits
static uint8_t joy1 = 0x1F, joy2 = 0x1F, joyarm1 = 0x1F;
static int romstub = 1;
static unsigned long long pchist[65536]; static int markpc=-1; static unsigned long markthr=0; static uint16_t ubuf_pc[400000]; static uint8_t ubuf_c[400000]; static int ubn=0; static unsigned long lastmark=0; static int nslow=0; static int histon=0; static long writes_rom = 0, writes_dos = 0, writes_hi = 0, reads_bad = 0;

static uint8_t rd(void *u, uint16_t a) {
  if (a >= 0x6800 && a < 0x7000) {
    uint8_t v = 0xFF;
    uint8_t lo = a & 0xFF;
    for (int r = 0; r < 8; r++) if (!(lo & (1 << r))) v &= keyrow[r] | 0xC0;
    v &= 0x7F; if (!fs_low) v |= 0x80;
    return v;
  }
  if (a > ramtop) { reads_bad++; return 0xFF; }
  return mem[a];
}
static void wr(void *u, uint16_t a, uint8_t v) {
  if (a < 0x4000) { writes_rom++; return; }
  if (a < 0x6800) { writes_dos++; mem[a] = v; return; }
  if (a < 0x7000) { latch = v; return; }
  if (a >= 0xFA00) writes_hi++;
  if (a > ramtop) return;
  mem[a] = v;
}
static uint8_t pin(z80 *z, uint8_t p) {
  if ((p & 0xF0) == 0x20) {
    uint8_t v = 0xFF;
    // A0..A3 select (active low): $2E = joy1 dirs/fire (A0 low), $2D = joy1 arm (A1 low)
    // $2B = joy2 (A2 low), $27 = joy2 arm (A3 low)
    if (!(p & 1)) v &= 0xE0 | joy1;
    if (!(p & 2)) v &= 0xE0 | joyarm1;
    if (!(p & 4)) v &= 0xE0 | joy2;
    return v;
  }
  return 0xFF;
}
static void pout(z80 *z, uint8_t p, uint8_t v) {}

// key names -> row,bit  (MAME vtech1 matrix)
struct K { const char *n; int r, b; } keys[] = {
  {"T",0,0},{"W",0,1},{"E",0,3},{"Q",0,4},{"R",0,5},
  {"G",1,0},{"S",1,1},{"CTRL",1,2},{"D",1,3},{"A",1,4},{"F",1,5},
  {"B",2,0},{"X",2,1},{"SHIFT",2,2},{"C",2,3},{"Z",2,4},{"V",2,5},
  {"5",3,0},{"2",3,1},{"3",3,3},{"1",3,4},{"4",3,5},
  {"N",4,0},{".",4,1},{",",4,3},{"SPACE",4,4},{"M",4,5},
  {"6",5,0},{"9",5,1},{"-",5,2},{"8",5,3},{"0",5,4},{"7",5,5},
  {"Y",6,0},{"O",6,1},{"RET",6,2},{"I",6,3},{"P",6,4},{"U",6,5},
  {"H",7,0},{"L",7,1},{":",7,2},{"K",7,3},{";",7,4},{"J",7,5},
  {0,0,0}};

struct Ev { int f0, f1; char key[16]; } evs[4096]; int nev = 0;
int pk_a[2048], pk_v[2048], pk_f[2048], npk = 0;

int main(int argc, char **argv) {
  const char *file = 0, *keyf = 0, *shotdir = "shots", *wavf = 0, *memf = 0;
  int frames = 500, startpc = -1, shotevery = 0; int shots[512], nshots = 0;
  int traceaddr = -1, tracelen = 0, tracefrom = 0; int pr0=-1,pr1=-1,prfrom=0; unsigned long long prin=0,prtot=0;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "-f")) frames = atoi(argv[++i]);
    else if (!strcmp(argv[i], "-k")) keyf = argv[++i];
    else if (!strcmp(argv[i], "-o")) shotdir = argv[++i];
    else if (!strcmp(argv[i], "-w")) wavf = argv[++i];
    else if (!strcmp(argv[i], "-m")) memf = argv[++i];
    else if (!strcmp(argv[i], "-pc")) startpc = strtol(argv[++i], 0, 16);
    else if (!strcmp(argv[i], "-stock")) ramtop = 0xB7FF;
    else if (!strcmp(argv[i], "-every")) shotevery = atoi(argv[++i]);
    else if (!strcmp(argv[i], "-s")) { char *s = argv[++i]; char *t = strtok(s, ","); while (t) { shots[nshots++] = atoi(t); t = strtok(0, ","); } }
    else if (!strcmp(argv[i], "-prof")) { pr0 = strtol(argv[++i],0,16); pr1 = strtol(argv[++i],0,16); prfrom = atoi(argv[++i]); }
    else if (!strcmp(argv[i], "-slow")) { markpc = strtol(argv[++i],0,16); markthr = atol(argv[++i]); }
    else if (!strcmp(argv[i], "-poke")) { pk_a[npk] = strtol(argv[++i],0,16); pk_v[npk] = strtol(argv[++i],0,16); pk_f[npk] = atoi(argv[++i]); npk++; }
    else if (!strcmp(argv[i], "-hist")) { histon = atoi(argv[++i]); }
    else if (!strcmp(argv[i], "-t")) { traceaddr = strtol(argv[++i], 0, 16); tracelen = atoi(argv[++i]); tracefrom = atoi(argv[++i]); }
    else file = argv[i];
  }
  if (!file) { fprintf(stderr, "usage: vzemu file.vz [-f frames] [-k keys] [-s f1,f2] [-o dir] [-w wav] [-pc hex] [-stock]\n"); return 1; }
  FILE *fp = fopen(file, "rb"); uint8_t buf[65536]; int n = fread(buf, 1, sizeof buf, fp); fclose(fp);
  int load = buf[22] | buf[23] << 8; int type = buf[21];
  memset(mem, 0, sizeof mem);
  memcpy(mem + load, buf + 24, n - 24);
  fprintf(stderr, "loaded type %02X at %04X-%04X (%d bytes)\n", type, load, load + n - 25, n - 24);
  // ROM stub: IM1 handler emulating VZ ROM user hook at $787D
  static const uint8_t stub[] = {0xF5,0xC5,0xD5,0xE5,0xCD,0x7D,0x78,
    0xE1,0xD1,0xC1, 0x3A,0x00,0x68,0x07,0x30,0xFA, 0xF1,0xFB,0xED,0x4D};
  memcpy(mem + 0x38, stub, sizeof stub);
  mem[0x787D] = 0xC9;
  if (keyf) { FILE *k = fopen(keyf, "r"); char line[128];
    while (fgets(line, sizeof line, k)) { if (line[0] == '#') continue; struct Ev e; if (sscanf(line, "%d %d %15s", &e.f0, &e.f1, e.key) == 3) evs[nev++] = e; } fclose(k); }
  z80 z; z80_init(&z); z.read_byte = rd; z.write_byte = wr; z.port_in = pin; z.port_out = pout;
  z.pc = startpc >= 0 ? startpc : load; z.sp = 0x8FFF;
  FILE *wav = 0; FILE *w2 = 0; long nsamp = 0; double sacc = 0;
  if (wavf) { char fn2[300]; sprintf(fn2, "%s.ch", wavf); w2 = fopen(fn2, "wb"); wav = fopen(wavf, "wb"); uint8_t h[44] = {0}; fwrite(h, 1, 44, wav); }
  const int LINE = 228, LINES = 312, FSL = 56;
  unsigned long cyc0 = 0;
  for (int f = 0; f < frames; f++) {
    // keys for this frame
    memset(keyrow, 0x3F, sizeof keyrow); joy1 = joy2 = joyarm1 = 0x1F;
    for (int i = 0; i < nev; i++) if (f >= evs[i].f0 && f <= evs[i].f1) {
      const char *kn = evs[i].key;
      if (!strcmp(kn, "J_UP")) joy1 &= ~1; else if (!strcmp(kn, "J_DOWN")) joy1 &= ~2;
      else if (!strcmp(kn, "J_LEFT")) joy1 &= ~4; else if (!strcmp(kn, "J_RIGHT")) joy1 &= ~8;
      else if (!strcmp(kn, "J_FIRE")) joy1 &= ~16; else if (!strcmp(kn, "J_ARM")) joyarm1 &= ~16;
      else for (int j = 0; keys[j].n; j++) if (!strcmp(keys[j].n, kn)) keyrow[keys[j].r] &= ~(1 << keys[j].b);
    }
    for (int k = 0; k < npk; k++) if (pk_f[k] == f) mem[pk_a[k]] = pk_v[k];
    for (int ln = 0; ln < LINES; ln++) {
      fs_low = ln < FSL;
      unsigned long end = cyc0 + LINE;
      while (z.cyc < end) {
        if (fs_low) z80_gen_int(&z, 0xFF); else z.int_pending = 0;
        unsigned long c0 = z.cyc;
        uint16_t pc0 = z.pc;
        z80_step(&z);
        if (histon && f >= histon && markpc < 0) pchist[pc0] += z.cyc - c0;
        if (markpc >= 0 && f >= histon) {
          if (pc0 == markpc) {
            unsigned long d = 0; for (int k = 0; k < ubn; k++) if (!(ubuf_pc[k] >= pr0 && ubuf_pc[k] < pr1)) d += ubuf_c[k];
            if (lastmark) fprintf(stderr, "U %lu\n", d);
            if (lastmark && d > markthr) { nslow++; for (int k = 0; k < ubn; k++) pchist[ubuf_pc[k]] += ubuf_c[k];  }
            lastmark = z.cyc; ubn = 0;
          }
          if (ubn < 400000) { ubuf_pc[ubn] = pc0; ubuf_c[ubn] = z.cyc - c0; ubn++; }
        }
        if (pr0 >= 0 && f >= prfrom && markpc < 0) { prtot += z.cyc - c0; if (pc0 >= pr0 && pc0 < pr1) prin += z.cyc - c0; }
        if (wav) { sacc += (z.cyc - c0); while (sacc >= 80.43) { sacc -= 80.43; int lv = ((latch >> 5) & 1) - (latch & 1); int16_t s = lv * 8000; fwrite(&s, 2, 1, wav); nsamp++; if (w2) { fputc(latch & 1, w2); fputc((latch>>5)&1, w2); } } }
      }
      cyc0 = end;
    }
    int doshot = 0; for (int i = 0; i < nshots; i++) if (shots[i] == f) doshot = 1;
    if (shotevery && f % shotevery == 0) doshot = 1;
    if (doshot) { char fn[256]; sprintf(fn, "%s/f%05d.bin", shotdir, f); FILE *o = fopen(fn, "wb"); fputc(latch, o); fwrite(mem + 0x7000, 1, 2048, o); fclose(o); }
    if (traceaddr >= 0 && f >= tracefrom) { printf("%5d PC=%04X SP=%04X:", f, z.pc, z.sp); for (int i = 0; i < tracelen; i++) printf(" %02X", mem[traceaddr + i]); printf("\n"); }
  }
  if (wav) { uint32_t ds = nsamp * 2; uint8_t h[44] = {'R','I','F','F'}; uint32_t v = 36 + ds; memcpy(h + 4, &v, 4); memcpy(h + 8, "WAVEfmt ", 8);
    v = 16; memcpy(h + 16, &v, 4); uint16_t s = 1; memcpy(h + 20, &s, 2); memcpy(h + 22, &s, 2); v = 44100; memcpy(h + 24, &v, 4); v = 88200; memcpy(h + 28, &v, 4);
    s = 2; memcpy(h + 32, &s, 2); s = 16; memcpy(h + 34, &s, 2); memcpy(h + 36, "data", 4); memcpy(h + 40, &ds, 4); fseek(wav, 0, SEEK_SET); fwrite(h, 1, 44, wav); fclose(wav); }
  if (histon) { FILE *o = fopen("pchist.bin", "wb"); fwrite(pchist, 8, 65536, o); fclose(o); }
  if (w2) fclose(w2);
  if (memf) { FILE *o = fopen(memf, "wb"); fwrite(mem, 1, 65536, o); fclose(o); }
  if (pr0 >= 0) fprintf(stderr, "profile: %.1f%% of cycles in %04X-%04X\n", 100.0*prin/(prtot?prtot:1), pr0, pr1);
  fprintf(stderr, "end PC=%04X SP=%04X IFF=%d IM=%d romwrites=%ld doswrites=%ld hiwrites=%ld badreads=%ld\n", z.pc, z.sp, z.iff1, z.interrupt_mode, writes_rom, writes_dos, writes_hi, reads_bad);
  return 0;
}
