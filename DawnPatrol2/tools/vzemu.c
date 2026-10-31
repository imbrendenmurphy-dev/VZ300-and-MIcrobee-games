// Minimal VZ300 + BennVenn 128K test harness for Dawn Patrol 2 development.
// - Z80 core: superzazu/z80
// - VDG mode(1) 128x64x4 rendering to PPM screenshots
// - Field sync: 312 lines x 228T, FS low for 56 lines -> level-triggered INT
// - Keyboard matrix at $68xx, latch writes (mode/CSS/speaker), joystick ports read $FF
// - BennVenn SRAM window $4000-$67FF banked by OUT ($37)
// - Speaker captured to a WAV file; OUT ($FF) markers for profiling; OUT ($FE) debug char
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"

#define LINE_T 228
#define LINES 312
#define FRAME_T (LINE_T*LINES)
#define FS_LINES 56

static uint8_t mem[65536];
static uint8_t banks[4][0x2800];
static int bank = 0;
static int hipage = 0;
static uint8_t mem2[65536];
static uint8_t latch = 0;
static uint8_t keymat[8]; // bit set = pressed
static unsigned long frame_start = 0;
static long frame_no = 0;
static z80 cpu;
static FILE *wav = NULL;
static long wav_samples = 0;
static unsigned long last_spk_cyc = 0;
static double spk_acc = 0;
static int spk_level = 0;
static int fail = 0;
static int markers_on = 0;
static int lastcss = 0, lastmode = 0;
static unsigned long joy_bits = 0xFF;
static unsigned long prof[65536];
static int prof_on = 0;
static long watch_addr = -1;

static int in_fs(void) {
  unsigned long t = cpu.cyc - frame_start;
  return t < (unsigned long)FS_LINES * LINE_T;
}

static void spk_advance(unsigned long now) {
  // 44100 Hz from 3546900 Hz
  const double tps = 3546900.0 / 44100.0;
  while (last_spk_cyc + tps <= now) {
    last_spk_cyc += (unsigned long)tps;
    if (wav) {
      int16_t s = (int16_t)(spk_level * 9000);
      fwrite(&s, 2, 1, wav);
      wav_samples++;
    }
  }
}

static uint8_t rb(void *u, uint16_t a) {
  (void)u;
  if (a < 0x4000) return 0xFF;
  if (a < 0x6800) return banks[bank][a - 0x4000];
  if (a < 0x7000) {
    uint8_t low = a & 0xFF, r = 0;
    for (int i = 0; i < 8; i++)
      if (!(low & (1 << i))) r |= keymat[i];
    uint8_t v = (~r) & 0x3F;
    v |= 0x40;
    if (!in_fs()) v |= 0x80;
    return v;
  }
  if (hipage && a >= 0xB800) return mem2[a];
  return mem[a];
}

static void wb(void *u, uint16_t a, uint8_t v) {
  (void)u;
  if (a < 0x4000) { return; }
  if (a < 0x6800) { banks[bank][a - 0x4000] = v; return; }
  if (a < 0x7000) {
    spk_advance(cpu.cyc);
    latch = v;
    spk_level = ((v >> 5) & 1) - (v & 1);
    return;
  }
  if (hipage && a >= 0xB800) { mem2[a] = v; return; }
  if (a == watch_addr) fprintf(stderr, "WATCH %04x <- %02x at PC=%04x SP=%04x f%ld\n", a, v, cpu.pc, cpu.sp, frame_no);
  mem[a] = v;
}

static uint8_t pin(z80 *z, uint8_t p) {
  (void)z;
  if ((p & 0xF0) == 0x20) return (uint8_t)joy_bits;
  return 0xFF;
}

static unsigned long mark_t[64];
static int mark_id[64];
static int nmark = 0;

static void pout(z80 *z, uint8_t p, uint8_t v) {
  (void)z;
  if (p == 0x37) {
    /* bit0 SRAM in window, bit1 window bank, bit2 expansion page for $B800-$FFFF */
    bank = (v & 1) ? ((v >> 1) & 1) : 2;
    hipage = (v >> 2) & 1;
  } else if (p == 0xFF) {
    if (nmark < 64) { mark_t[nmark] = cpu.cyc - frame_start; mark_id[nmark++] = v; }
  } else if (p == 0xFE) {
    fputc(v, stderr);
  }
}

static const uint8_t pal[2][4][3] = {
  {{0x07,0xff,0x00},{0xff,0xff,0x00},{0x3b,0x08,0xff},{0xcc,0x00,0x3b}},
  {{0xff,0xff,0xff},{0x07,0xe3,0x99},{0xff,0x1c,0xff},{0xff,0x81,0x00}}};

static void shot(const char *fn) {
  FILE *f = fopen(fn, "wb");
  int css = (latch >> 4) & 1;
  int W = 128 * 4, H = 64 * 6;
  fprintf(f, "P6 %d %d 255\n", W, H);
  for (int y = 0; y < H; y++)
    for (int x = 0; x < W; x++) {
      int px = x / 4, py = y / 6;
      uint8_t b = mem[0x7000 + py * 32 + px / 4];
      int c = (b >> (6 - 2 * (px & 3))) & 3;
      if (!(latch & 8)) c = 0; // text mode: just show green
      fwrite(pal[css][c], 3, 1, f);
    }
  fclose(f);
}

static int keyrc(const char *k, int *row, int *bit) {
  static const char *tab[8][6] = {
    {"T","W","-0","E","Q","R"},
    {"G","S","CTRL","D","A","F"},
    {"B","X","SHIFT","C","Z","V"},
    {"5","2","-3","3","1","4"},
    {"N",".","-4",",","SPACE","M"},
    {"6","9","-","8","0","7"},
    {"Y","O","RETURN","I","P","U"},
    {"H","L",":","K",";","J"}};
  for (int r = 0; r < 8; r++)
    for (int b = 0; b < 6; b++)
      if (!strcmp(tab[r][b], k)) { *row = r; *bit = b; return 1; }
  return 0;
}

int main(int argc, char **argv) {
  if (argc < 4) {
    fprintf(stderr, "vzemu file.vz frames script [outprefix] [wav]\n");
    return 1;
  }
  FILE *f = fopen(argv[1], "rb");
  static uint8_t buf[70000];
  int n = fread(buf, 1, sizeof buf, f);
  fclose(f);
  int start = buf[22] | (buf[23] << 8);
  for (int i = 24; i < n; i++) mem[(start + i - 24) & 0xFFFF] = buf[i];
  long frames = atol(argv[2]);
  const char *prefix = argc > 4 ? argv[4] : "shot";
  if (argc > 5) {
    wav = fopen(argv[5], "wb");
    uint8_t hdr[44] = {0};
    fwrite(hdr, 44, 1, wav);
  }
  // script: lines "frame cmd arg"  cmd: down/up KEY, shot NAME, marks, joy VALUE, dump ADDR LEN
  FILE *sf = fopen(argv[3], "r");
  struct { long fr; char cmd[16]; char arg[32]; char arg2[32]; } sc[4096];
  int ns = 0;
  char line[256];
  while (sf && fgets(line, sizeof line, sf)) {
    if (line[0] == '#' || line[0] == '\n') continue;
    sc[ns].arg[0] = sc[ns].arg2[0] = 0;
    if (sscanf(line, "%ld %15s %31s %31s", &sc[ns].fr, sc[ns].cmd, sc[ns].arg, sc[ns].arg2) >= 2) ns++;
  }
  if (sf) fclose(sf);
  for (int i = 1; i < ns; i++)        /* stable sort by frame */
    for (int j = i; j > 0 && sc[j - 1].fr > sc[j].fr; j--) {
      __typeof__(sc[0]) t = sc[j]; sc[j] = sc[j - 1]; sc[j - 1] = t;
    }
  // Fill RAM with garbage like real hardware
  srand(1);
  for (int i = 0x7800; i < 0x10000; i++) if (i < start || i >= start + n - 24) mem[i] = rand();
  for (int b = 0; b < 4; b++) for (int i = 0; i < 0x2800; i++) banks[b][i] = rand();
  for (int i = 0; i < 65536; i++) mem2[i] = rand();
  z80_init(&cpu);
  cpu.read_byte = rb; cpu.write_byte = wb; cpu.port_in = pin; cpu.port_out = pout;
  cpu.pc = start; cpu.sp = 0x7FF0;
  int si = 0;
  unsigned long maxcyc_frame = 0;
  for (frame_no = 0; frame_no < frames; frame_no++) {
    frame_start = cpu.cyc;
    nmark = 0;
    while (si < ns && sc[si].fr <= frame_no) {
      int r, b;
      if (!strcmp(sc[si].cmd, "down") && keyrc(sc[si].arg, &r, &b)) keymat[r] |= 1 << b;
      else if (!strcmp(sc[si].cmd, "up") && keyrc(sc[si].arg, &r, &b)) keymat[r] &= ~(1 << b);
      else if (!strcmp(sc[si].cmd, "joy")) joy_bits = strtoul(sc[si].arg, 0, 0);
      else if (!strcmp(sc[si].cmd, "marks")) markers_on = atoi(sc[si].arg);
      else if (!strcmp(sc[si].cmd, "prof")) prof_on = atoi(sc[si].arg);
      else if (!strcmp(sc[si].cmd, "watch")) watch_addr = strtol(sc[si].arg, 0, 0);
      else if (!strcmp(sc[si].cmd, "dump")) {
        unsigned a = strtoul(sc[si].arg, 0, 0), l = strtoul(sc[si].arg2, 0, 0);
        fprintf(stderr, "dump %04x:", a);
        for (unsigned i = 0; i < l; i++) fprintf(stderr, " %02x", rb(0, a + i));
        fprintf(stderr, "\n");
      } else if (!strcmp(sc[si].cmd, "regs")) {
        fprintf(stderr, "f%ld PC=%04x SP=%04x IX=%04x IY=%04x bank=%d latch=%02x iff=%d\n", frame_no, cpu.pc, cpu.sp, cpu.ix, cpu.iy, bank, latch, cpu.iff1);
      }
      si++;
    }
    while (cpu.cyc - frame_start < FRAME_T) {
      if (in_fs() && cpu.iff1) z80_gen_int(&cpu, 0xFF);
      { uint16_t pc0 = cpu.pc; unsigned long c0 = cpu.cyc;
      z80_step(&cpu);
      if (prof_on) prof[pc0] += cpu.cyc - c0; }
      if (cpu.pc < 0x4000 || (cpu.pc >= 0x6800 && cpu.pc < 0x7800) || (hipage && cpu.pc >= 0xB800)) {
        fprintf(stderr, "PC out of range %04x at frame %ld SP=%04x\n", cpu.pc, frame_no, cpu.sp);
        fail = 1; break;
      }
      if (cpu.sp < 0x7800 && cpu.sp > 0x100) {
        fprintf(stderr, "SP out of range %04x at frame %ld PC=%04x\n", cpu.sp, frame_no, cpu.pc);
        fail = 1; break;
      }
    }
    if (fail) break;
    spk_advance(cpu.cyc);
    // screenshot commands for this frame (after the frame ran)
    for (int k = 0; k < ns; k++)
      if (sc[k].fr == frame_no && !strcmp(sc[k].cmd, "shot")) {
        char fn[256]; snprintf(fn, sizeof fn, "%s_%s.ppm", prefix, sc[k].arg); shot(fn);
      }
    if (markers_on && nmark) {
      fprintf(stderr, "f%ld:", frame_no);
      for (int i = 0; i < nmark; i++) fprintf(stderr, " %d@%lu", mark_id[i], mark_t[i] / LINE_T);
      fprintf(stderr, "\n");
    }
    (void)maxcyc_frame; (void)lastcss; (void)lastmode;
  }
  if (wav) {
    long bytes = wav_samples * 2;
    fseek(wav, 0, SEEK_SET);
    uint8_t h[44];
    memcpy(h, "RIFF", 4); uint32_t v = 36 + bytes; memcpy(h + 4, &v, 4);
    memcpy(h + 8, "WAVEfmt ", 8); v = 16; memcpy(h + 16, &v, 4);
    uint16_t s = 1; memcpy(h + 20, &s, 2); s = 1; memcpy(h + 22, &s, 2);
    v = 44100; memcpy(h + 24, &v, 4); v = 88200; memcpy(h + 28, &v, 4);
    s = 2; memcpy(h + 32, &s, 2); s = 16; memcpy(h + 34, &s, 2);
    memcpy(h + 36, "data", 4); v = bytes; memcpy(h + 40, &v, 4);
    fwrite(h, 44, 1, wav); fclose(wav);
  }
  { FILE *pf = fopen("prof.bin", "wb"); fwrite(prof, sizeof prof, 1, pf); fclose(pf); }
  fprintf(stderr, "ran %ld frames, PC=%04x SP=%04x latch=%02x bank=%d\n", frame_no, cpu.pc, cpu.sp, latch, bank);
  return fail;
}
