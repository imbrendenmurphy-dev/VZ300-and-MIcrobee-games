// Minimal headless VZ200/VZ300 emulator for testing (no ROM needed for
// self-contained machine-code games). Scanline-level video, keyboard matrix,
// joystick ports, speaker -> WAV, field-sync interrupt (level, held while FS low).
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "z80.h"
#include "font.h"

#define CPF_LINE 228
#define LINES 312
#define FS_LEN 56
#define TOPB 25
#define W 320
#define H 240
static uint8_t mem[65536];
static uint8_t latch = 0;
static uint8_t keys[8];            // active-high pressed bits per row
static uint8_t joy[16];            // port low nibble -> active-high bits
static int fs_low = 0;
static uint32_t img[H][W];
static int frame = 0;
static long long totalcyc = 0;
static FILE *wav = NULL; static long wavsamples = 0; static double wavacc = 0;
static int romwrite_warn = 0;
static int npk=0; static int pkf[64], pka[64], pkv[64];
static int watch_pc = -1; static int watch_hits = 0; static long long watch_last = 0;
static int watch_over = 0; static unsigned long long prof[65536]; static const char *proffile=0; static int prof_from=0;
static long long watch_min = 1LL<<60, watch_max = 0, watch_sum = 0; static int watch_n = 0;

static uint8_t rd(void *u, uint16_t a) {
  if (a >= 0x6800 && a < 0x7000) {
    uint8_t r = 0x3f;
    for (int i = 0; i < 8; i++) if (!(a & (1 << i))) r &= ~keys[i];
    r &= 0x3f;
    r |= 0x40;
    if (!fs_low) r |= 0x80;
    return r;
  }
  if (a < 0x4000) return 0xff;
  return mem[a];
}
static void wr(void *u, uint16_t a, uint8_t v) {
  if (a < 0x4000) { if (romwrite_warn < 5) { fprintf(stderr, "ROM write %04X\n", a); romwrite_warn++; } return; }
  if (a >= 0x6800 && a < 0x7000) { latch = v; return; }
  mem[a] = v;
}
static uint8_t pin(z80 *z, uint8_t p) {
  if ((p & 0xf0) == 0x20) {
    uint8_t r = 0xff;
    for (int i = 0; i < 4; i++) if (!(p & (1 << i))) r &= ~joy[1 << i];
    return r;
  }
  return 0xff;
}
static void pout(z80 *z, uint8_t p, uint8_t v) { (void)z; (void)p; (void)v; }

static const uint32_t pal[8] = {0x07ff00, 0xffff00, 0x3b08ff, 0xcc003b, 0xffffff, 0x07e399, 0xff1cff, 0xff8100};

static void render_line(int line) {
  int y = line - FS_LEN - TOPB + 24; // image row
  if (y < 0 || y >= H) return;
  int r = line - FS_LEN - TOPB;      // active row
  int ag = (latch >> 3) & 1, css = (latch >> 4) & 1;
  uint32_t border = ag ? (css ? pal[4] : pal[0]) : 0;
  for (int x = 0; x < W; x++) img[y][x] = border;
  if (r < 0 || r >= 192) return;
  for (int x = 0; x < 256; x++) {
    uint32_t c;
    if (ag) {
      uint8_t b = mem[0x7000 + (r / 3) * 32 + (x >> 3)];
      int px = (b >> (6 - ((x >> 1) & 3) * 2)) & 3;
      c = pal[px + css * 4];
    } else {
      uint8_t b = mem[0x7000 + (r / 12) * 32 + (x >> 3)];
      int ly = r % 12, lx = x & 7;
      if (b & 0x80) {
        int q = (ly < 6 ? 2 : 0) + (lx < 4 ? 1 : 0); // bit3 TL, bit2 TR, bit1 BL, bit0 BR
        int bit = q == 3 ? 3 : q == 2 ? 2 : q == 1 ? 1 : 0;
        c = (b >> bit) & 1 ? pal[(b >> 4) & 7] : 0;
      } else {
        int on = (font6847[b & 0x3f][ly] >> (7 - lx)) & 1;
        if (b & 0x40) on = !on;
        uint32_t fg = css ? 0xff8100 : 0x07ff00, bg = css ? 0x5a1800 : 0x003000;
        c = on ? bg : fg; // normal = dark char on bright bg
      }
    }
    img[y][x + 32] = c;
  }
}
static void save_png(const char *fn) {
  FILE *f = fopen(fn, "wb");
  fprintf(f, "P6\n%d %d\n255\n", W, H);
  for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
    uint32_t c = img[y][x]; fputc(c >> 16, f); fputc((c >> 8) & 255, f); fputc(c & 255, f);
  }
  fclose(f);
}
// key names
struct kn { const char *n; int row, bit; };
static struct kn KN[] = {
  {"R",0,5},{"Q",0,4},{"E",0,3},{"W",0,1},{"T",0,0},
  {"F",1,5},{"A",1,4},{"D",1,3},{"CTRL",1,2},{"S",1,1},{"G",1,0},
  {"V",2,5},{"Z",2,4},{"C",2,3},{"SHIFT",2,2},{"X",2,1},{"B",2,0},
  {"4",3,5},{"1",3,4},{"3",3,3},{"2",3,1},{"5",3,0},
  {"M",4,5},{"SPACE",4,4},{"COMMA",4,3},{"DOT",4,1},{"N",4,0},
  {"7",5,5},{"0",5,4},{"8",5,3},{"MINUS",5,2},{"9",5,1},{"6",5,0},
  {"U",6,5},{"P",6,4},{"I",6,3},{"RETURN",6,2},{"O",6,1},{"Y",6,0},
  {"J",7,5},{"SEMI",7,4},{"K",7,3},{"COLON",7,2},{"L",7,1},{"H",7,0},{0,0,0}};
struct ev { int f0, f1; int row, bit; int joyport; };
static struct ev evs[4096]; static int nev = 0;
static void load_script(const char *fn) {
  FILE *f = fopen(fn, "r"); if (!f) { perror(fn); exit(1); }
  char name[32]; int a, b;
  char line[256];
  while (fgets(line, sizeof line, f)) {
    if (line[0] == '#') continue;
    if (sscanf(line, "%d %d %31s", &a, &b, name) != 3) continue;
    struct ev *e = &evs[nev++]; e->f0 = a; e->f1 = b; e->joyport = 0;
    if (!strncmp(name, "J1", 2) || !strncmp(name, "J2", 2)) { // J1U J1D J1L J1R J1F
      int p = name[1] == '1' ? 1 : 4; char d = name[2];
      e->joyport = p; e->bit = d == 'U' ? 0 : d == 'D' ? 1 : d == 'L' ? 2 : d == 'R' ? 3 : 4;
      if (d == 'F') e->joyport = p; // fire on same port
      continue;
    }
    int ok = 0;
    for (int i = 0; KN[i].n; i++) if (!strcmp(KN[i].n, name)) { e->row = KN[i].row; e->bit = KN[i].bit; ok = 1; }
    if (!ok) { fprintf(stderr, "bad key %s\n", name); exit(1); }
  }
  fclose(f);
}
static void apply_keys(void) {
  memset(keys, 0, 8); memset(joy, 0, 16);
  for (int i = 0; i < nev; i++) if (frame >= evs[i].f0 && frame <= evs[i].f1) {
    if (evs[i].joyport) joy[evs[i].joyport] |= 1 << evs[i].bit;
    else keys[evs[i].row] |= 1 << evs[i].bit;
  }
}
static void wav_hdr(FILE *f, long n) {
  fseek(f, 0, SEEK_SET);
  uint32_t sr = 44100; uint32_t ds = n * 2;
  fwrite("RIFF", 1, 4, f); uint32_t x = 36 + ds; fwrite(&x, 4, 1, f); fwrite("WAVEfmt ", 1, 8, f);
  x = 16; fwrite(&x, 4, 1, f); uint16_t s = 1; fwrite(&s, 2, 1, f); fwrite(&s, 2, 1, f);
  fwrite(&sr, 4, 1, f); x = sr * 2; fwrite(&x, 4, 1, f); s = 2; fwrite(&s, 2, 1, f); s = 16; fwrite(&s, 2, 1, f);
  fwrite("data", 1, 4, f); fwrite(&ds, 4, 1, f);
}

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: vzemu file.vz [-pc hex] [-frames n] [-shots f,f,..] [-every n] [-out prefix] [-keys file] [-wav file] [-watch hex] [-dump hex:len:file]\n"); return 1; }
  int pcov = -1, frames = 300, every = 0; char shots[1024] = ""; const char *out = "shot";
  const char *dumpspec = NULL;
  for (int i = 2; i < argc; i++) {
    if (!strcmp(argv[i], "-pc")) pcov = strtol(argv[++i], 0, 16);
    else if (!strcmp(argv[i], "-frames")) frames = atoi(argv[++i]);
    else if (!strcmp(argv[i], "-shots")) strncpy(shots, argv[++i], 1000);
    else if (!strcmp(argv[i], "-every")) every = atoi(argv[++i]);
    else if (!strcmp(argv[i], "-out")) out = argv[++i];
    else if (!strcmp(argv[i], "-keys")) load_script(argv[++i]);
    else if (!strcmp(argv[i], "-wav")) { wav = fopen(argv[++i], "wb"); wav_hdr(wav, 0); }
    else if (!strcmp(argv[i], "-watch")) watch_pc = strtol(argv[++i], 0, 16);
    else if (!strcmp(argv[i], "-prof")) { proffile = argv[++i]; prof_from = atoi(argv[++i]); }
    else if (!strcmp(argv[i], "-dump")) dumpspec = argv[++i];
    else if (!strcmp(argv[i], "-poke")) { sscanf(argv[++i], "%d:%x:%x", &pkf[npk], &pka[npk], &pkv[npk]); npk++; }
  }
  FILE *f = fopen(argv[1], "rb"); if (!f) { perror(argv[1]); return 1; }
  uint8_t buf[70000]; int n = fread(buf, 1, sizeof buf, f); fclose(f);
  int type = buf[21]; int start = buf[22] | buf[23] << 8;
  memcpy(mem + start, buf + 24, n - 24);
  fprintf(stderr, "loaded type %02X at %04X-%04X\n", type, start, start + n - 25);
  for (int i = 0x7000; i < 0x7800; i++) mem[i] = 0x20 ^ (rand() & 0); // blank
  z80 z; z80_init(&z);
  z.read_byte = rd; z.write_byte = wr; z.port_in = pin; z.port_out = pout;
  z.pc = pcov >= 0 ? pcov : start; z.sp = 0x7fff;
  latch = 0;
  int wantshot[100000] = {0};
  { char *p = shots; while (*p) { int v = atoi(p); if (v < 100000) wantshot[v] = 1; while (*p && *p != ',') p++; if (*p) p++; } }
  double cyc_per_sample = 3546900.0 / 44100.0;
  for (frame = 0; frame < frames; frame++) {
    apply_keys();
    for (int k = 0; k < npk; k++) if (pkf[k] == frame) mem[pka[k]] = pkv[k];
    for (int line = 0; line < LINES; line++) {
      fs_low = line < FS_LEN;
      long long target = totalcyc + CPF_LINE;
      while ((long long)z.cyc < target) {
        if (fs_low) { if (z.iff1) { z.int_pending = 1; z.int_data = 0xff; } }
        else z.int_pending = 0;
        unsigned long c0 = z.cyc;
        if (watch_pc >= 0 && z.pc == watch_pc) {
          long long now = z.cyc;
          if (watch_hits) { long long d = now - watch_last; if (d < watch_min) watch_min = d; if (d > watch_max) watch_max = d; watch_sum += d; watch_n++; if (d > 75000 && d < 1000000) { watch_over++; if (getenv("OVLOG")) fprintf(stderr,"ov f%d %lld\n",frame,d);} }
          watch_hits++; watch_last = now;
        }
        uint16_t pc0 = z.pc;
        z80_step(&z);
        if (proffile && frame >= prof_from) prof[pc0] += z.cyc - c0;
        if (wav) {
          double lv = (((latch >> 5) & 1) - (latch & 1)) * 9000.0;
          wavacc += (z.cyc - c0);
          while (wavacc >= cyc_per_sample) { int16_t s = (int16_t)lv; fwrite(&s, 2, 1, wav); wavsamples++; wavacc -= cyc_per_sample; }
        }
      }
      totalcyc = target;
      render_line(line);
    }
    if (wantshot[frame] || (every && frame % every == 0)) {
      char fn[256]; sprintf(fn, "%s_%05d.ppm", out, frame); save_png(fn);
    }
  }
  if (proffile) { FILE *pf = fopen(proffile, "wb"); fwrite(prof, 8, 65536, pf); fclose(pf); }
  if (wav) { wav_hdr(wav, wavsamples); fclose(wav); }
  if (watch_pc >= 0 && watch_n) { fprintf(stderr, "overruns %d\n", watch_over); } if (watch_pc >= 0 && watch_n) fprintf(stderr, "watch %04X hits %d: min %lld max %lld avg %lld cycles (frame=71136)\n", watch_pc, watch_hits, watch_min, watch_max, watch_sum / watch_n);
  fprintf(stderr, "end PC=%04X SP=%04X frames=%d\n", z.pc, z.sp, frames);
  if (dumpspec) { int a, l; char fn[200]; sscanf(dumpspec, "%x:%x:%199s", &a, &l, fn); FILE *d = fopen(fn, "wb"); fwrite(mem + a, 1, l, d); fclose(d); }
  return 0;
}
