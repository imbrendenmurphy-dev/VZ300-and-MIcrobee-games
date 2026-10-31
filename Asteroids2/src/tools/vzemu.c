// vzemu - minimal cycle-counting VZ200/VZ300 test harness (no ROM needed)
// Models: Z80 @3.546894MHz, 312-line PAL field (70938 T), MC6847 field sync on
// bit 7 of $68xx reads (low for 56 lines after the 192 active lines), keyboard
// matrix at $6800-$6FFF, output latch (speaker bits 0/5, AG bit 3, CSS bit 4),
// joystick interface ports $20-$2F, RAM size options.  Captures the display
// line-by-line as the beam scans it (so tearing is visible), speaker to WAV,
// profiling of label hits, guards against stray writes / stack / PC.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "z80core/z80.h"

#define FIELD_T 70938
#define LINES 312
#define ACTIVE 192
#define FS_LINES 56

static uint8_t mem[65536];
static int ram_top = 0xF7FF;
static uint8_t latch = 0;
static int bennvenn = 0; static uint8_t mapper = 1;
static uint8_t sram[2][0x2800]; static uint8_t hibank[0x4800]; static int dos_reports = 0;
static z80 cpu;
static unsigned long long total_cyc = 0; // cumulative T
static long field_no = 0;
static uint8_t keyrow[8]; // active-low bits
static uint8_t joy0 = 0xFF, joy0arm = 0xFF, joy1 = 0xFF, joy1arm = 0xFF;
static int joymode = 0; // 0=interface present, 1=absent reads 0x00, 2=absent reads 0xFF
static int trap2ef4 = -1;
// beam capture
static uint8_t scr[ACTIVE][32];
static uint8_t scrmode[ACTIVE];
static int last_line = -1;
// speaker log
typedef struct { unsigned long long t; int8_t lv; } spk_ev;
static spk_ev *spk = 0; static long nspk = 0, capspk = 0;
// guards
static int npoke = 0; static long poke_f[32]; static int poke_a[32], poke_v[32];
static int allow_n = 0; static long guard_from = 0; static int allow_a[64]; static char allow_names[64][64]; static int spskip_lo = -1, spskip_hi = -1;
static int guard_lo = -1, guard_hi = -1, guard_reports = 0;
static int sp_lo = 0, sp_hi = 0xFFFF, sp_reports = 0;
static int code_lo = 0x7800, code_hi = 0xFFFF, pc_reports = 0;
// profiling
#define MAXPROF 64
static int nprof = 0; static int prof_addr[MAXPROF]; static char prof_name[MAXPROF][64];
static FILE *proflog = 0;
static FILE *videof = 0;
static int shot_list[256]; static int nshots = 0; static const char *shotdir = ".";
static long frames_to_run = 500;
// script
typedef struct { long f0, f1; char keys[256]; } scr_ent;
static scr_ent script[4096]; static int nscript = 0;
static int verbose_writes = 0; static unsigned long long pccyc[65536]; static int flatprof = 0;
static long vram_writes_active = 0; // writes to VRAM during active display (info)

static int in_fs(void) {
  long t = (long)(total_cyc % FIELD_T);
  int line = (int)((long long)t * LINES / FIELD_T);
  return line >= ACTIVE && line < ACTIVE + FS_LINES;
}
static int cur_line(void) {
  long t = (long)(total_cyc % FIELD_T);
  return (int)((long long)t * LINES / FIELD_T);
}

static uint8_t rb(void *u, uint16_t a) {
  (void)u;
  if (a >= 0x6800 && a < 0x7000) {
    uint8_t r = 0x3F;
    for (int i = 0; i < 8; i++) if (!(a & (1 << i))) r &= keyrow[i];
    r |= 0x40; // no tape
    if (!in_fs()) r |= 0x80;
    return r;
  }
  if (bennvenn && a >= 0x4000 && a < 0x6800) return sram[(mapper >> 1) & 1][a - 0x4000];
  if (bennvenn && a >= 0xB800 && (mapper & 4)) return hibank[a - 0xB800];
  if (a < 0x6800) return 0xFF; // ROM / cart space (no ROM loaded)
  if (a >= 0x7000 && a < 0x7800) return mem[a];
  if (a > ram_top) return 0xFF;
  return mem[a];
}
static void wb(void *u, uint16_t a, uint8_t v) {
  (void)u;
  if (a >= 0x6800 && a < 0x7000) {
    latch = v;
    int lv = ((v & 0x21) == 0x01) ? 1 : ((v & 0x21) == 0x20) ? -1 : 0;
    if (nspk == capspk) { capspk = capspk ? capspk * 2 : 1 << 20; spk = realloc(spk, capspk * sizeof(spk_ev)); }
    spk[nspk].t = total_cyc + cpu.cyc; spk[nspk].lv = lv; nspk++;
    return;
  }
  if (bennvenn && a >= 0x4000 && a < 0x6800) {
    int b = (mapper >> 1) & 1;
    if (b == 0 && dos_reports < 10) { dos_reports++; fprintf(stderr, "DOS BANK WRITE %02X to %04X at PC=%04X\n", v, a, cpu.pc); }
    sram[b][a - 0x4000] = v; return;
  }
  if (bennvenn && a >= 0xB800 && (mapper & 4)) { hibank[a - 0xB800] = v; return; }
  if (a < 0x7000) return;
  if (a >= 0x7000 && a < 0x7800 && !(guard_lo >= 0x7000 && guard_lo < 0x7800)) { mem[a] = v; return; }
  if (a > ram_top) return;
  int allowed = 0; for (int i = 0; i < allow_n; i++) if (a >= allow_a[i] && a <= allow_a[i] + 3) allowed = 1;
  if (!allowed && field_no >= guard_from && guard_lo >= 0 && a >= guard_lo && a <= guard_hi && guard_reports < 400) {
    guard_reports++;
    fprintf(stderr, "GUARD: write %02X to %04X at PC=%04X field %ld\n", v, a, cpu.pc, field_no);
  }
  mem[a] = v;
}
static uint8_t pin(z80 *z, uint8_t port) {
  (void)z;
  uint8_t p = port; // VZ decodes low byte
  if (p >= 0x20 && p <= 0x2F) {
    if (joymode == 1) return 0x00;
    if (joymode == 2) return 0xFF;
    uint8_t d = 0xFF;
    if (!(p & 1)) d &= joy0; if (!(p & 2)) d &= joy0arm;
    if (!(p & 4)) d &= joy1; if (!(p & 8)) d &= joy1arm;
    return d;
  }
  return 0xFF;
}
static void pout(z80 *z, uint8_t port, uint8_t v) { (void)z;
  if (port == 0x37) { mapper = v; if (!(v & 1) && bennvenn) fprintf(stderr, "mapper write %02X (DOS ROM view)\n", v); }
  else fprintf(stderr, "OUT %02X,%02X at PC=%04X\n", port, v, cpu.pc);
}

// key names -> matrix (row, bit) per MAME vtech1.cpp
typedef struct { const char *n; int row, bit; } keydef;
static keydef keys[] = {
  {"R",0,5},{"Q",0,4},{"E",0,3},{"W",0,1},{"T",0,0},
  {"F",1,5},{"A",1,4},{"D",1,3},{"CTRL",1,2},{"S",1,1},{"G",1,0},
  {"V",2,5},{"Z",2,4},{"C",2,3},{"SHIFT",2,2},{"X",2,1},{"B",2,0},
  {"4",3,5},{"1",3,4},{"3",3,3},{"2",3,1},{"5",3,0},
  {"M",4,5},{"SPACE",4,4},{",",4,3},{".",4,1},{"N",4,0},
  {"7",5,5},{"0",5,4},{"8",5,3},{"-",5,2},{"9",5,1},{"6",5,0},
  {"U",6,5},{"P",6,4},{"I",6,3},{"RETURN",6,2},{"O",6,1},{"Y",6,0},
  {"J",7,5},{";",7,4},{"K",7,3},{":",7,2},{"L",7,1},{"H",7,0},
  {0,0,0}};

static void apply_inputs(void) {
  memset(keyrow, 0x3F, 8);
  joy0 = joy0arm = joy1 = joy1arm = 0xFF;
  for (int i = 0; i < nscript; i++) {
    if (field_no < script[i].f0 || field_no > script[i].f1) continue;
    char buf[256]; strcpy(buf, script[i].keys);
    for (char *tok = strtok(buf, ","); tok; tok = strtok(0, ",")) {
      if (!strcmp(tok, "J1UP")) joy0 &= ~1; else if (!strcmp(tok, "J1DOWN")) joy0 &= ~2;
      else if (!strcmp(tok, "J1LEFT")) joy0 &= ~4; else if (!strcmp(tok, "J1RIGHT")) joy0 &= ~8;
      else if (!strcmp(tok, "J1FIRE")) joy0 &= ~16; else if (!strcmp(tok, "J1ARM")) joy0arm &= ~16;
      else if (!strcmp(tok, "-")) ;
      else {
        int f = 0;
        for (keydef *k = keys; k->n; k++) if (!strcmp(k->n, tok)) { keyrow[k->row] &= ~(1 << k->bit); f = 1; }
        if (!f) fprintf(stderr, "unknown key %s\n", tok);
      }
    }
  }
}

static const uint8_t pal[8][3] = {
  {0x07,0xff,0x00},{0xff,0xff,0x00},{0x3b,0x08,0xff},{0xcc,0x00,0x3b},
  {0xff,0xff,0xff},{0x07,0xe3,0x99},{0xff,0x1c,0xff},{0xff,0x81,0x00}};
static void render_rgb(uint8_t *out /*256*192*3*/) {
  for (int y = 0; y < ACTIVE; y++) {
    int m = scrmode[y];
    for (int x = 0; x < 256; x++) {
      uint8_t *o = out + (y * 256 + x) * 3;
      if (m & 8) { // CG2: 128x64, 2bpp, byte has 4 px, msb first
        int b = scr[y][x >> 3]; int px = (x >> 1) & 3;
        int c = (b >> (6 - 2 * px)) & 3; if (m & 16) c += 4;
        memcpy(o, pal[c], 3);
      } else { // text mode: crude - show chars as blocks
        int b = scr[y][x >> 3];
        int on = (b & 0x80) ? ((b >> (((y % 12) < 6 ? 2 : 0) + (((x & 7) < 4) ? 1 : 0))) & 1) : (b != 0x20 && b != 0x60 && ((x & 7) > 0) && ((y % 12) > 1) && ((y % 12) < 10) && ((x & 7) < 7) && ((x + y) & 1));
        if (b & 0x80) { int c = (b >> 4) & 7; const uint8_t *pc = on ? pal[c] : (const uint8_t[]){0, 0, 0}; memcpy(o, pc, 3); }
        else { uint8_t v = on ? 0x10 : 0x00; uint8_t g[3] = {v, on ? 0x40 : 0xA0, v}; if (on) { g[0] = 0; g[1] = 0x30; g[2] = 0; } else { g[0] = 0x07; g[1] = 0xC0; g[2] = 0x00; } memcpy(o, g, 3); }
      }
    }
  }
}
static void capture_lines(void) {
  int line = cur_line();
  if (line == last_line) return;
  // capture every line passed since last_line (handle wrap)
  int l = last_line;
  while (l != line) {
    l = (l + 1) % LINES;
    if (l < ACTIVE) {
      int m = latch & 0x18;
      int row = (m & 8) ? (l / 3) : (l / 12);
      memcpy(scr[l], mem + 0x7000 + row * 32, 32);
      scrmode[l] = m;
    }
    if (l == ACTIVE) { // end of active display -> field complete
      for (int i = 0; i < nshots; i++) if (shot_list[i] == field_no) {
        char fn[512]; snprintf(fn, sizeof fn, "%s/shot_%05ld.ppm", shotdir, field_no);
        FILE *f = fopen(fn, "wb"); uint8_t img[256 * 192 * 3]; render_rgb(img);
        fprintf(f, "P6 256 192 255\n"); fwrite(img, 1, sizeof img, f); fclose(f);
      }
      if (videof) { uint8_t img[256 * 192 * 3]; render_rgb(img); fwrite(img, 1, sizeof img, videof); }
    }
  }
  last_line = line;
}

static void write_wav(const char *fn, unsigned long long endt) {
  const int SR = 44100; double tps = 3546894.0;
  long n = (long)(endt / tps * SR);
  FILE *f = fopen(fn, "wb"); if (!f) return;
  int32_t sz = 36 + n * 2;
  fwrite("RIFF", 1, 4, f); fwrite(&sz, 4, 1, f); fwrite("WAVEfmt ", 1, 8, f);
  int32_t v32 = 16; fwrite(&v32, 4, 1, f); int16_t v16 = 1; fwrite(&v16, 2, 1, f); fwrite(&v16, 2, 1, f);
  v32 = SR; fwrite(&v32, 4, 1, f); v32 = SR * 2; fwrite(&v32, 4, 1, f); v16 = 2; fwrite(&v16, 2, 1, f); v16 = 16; fwrite(&v16, 2, 1, f);
  fwrite("data", 1, 4, f); v32 = n * 2; fwrite(&v32, 4, 1, f);
  long ei = 0; int lv = 0; double hp = 0, prev = 0;
  for (long s = 0; s < n; s++) {
    double t0 = s * tps / SR, t1 = (s + 1) * tps / SR; double acc = 0, t = t0;
    while (ei < nspk && spk[ei].t <= t0) { lv = spk[ei].lv; ei++; }
    while (ei < nspk && spk[ei].t < t1) { acc += lv * (spk[ei].t - t); t = spk[ei].t; lv = spk[ei].lv; ei++; }
    acc += lv * (t1 - t); double x = acc / (t1 - t0);
    hp = 0.995 * (hp + x - prev); prev = x; // DC block
    int v = (int)(hp * 12000); if (v > 32767) v = 32767; if (v < -32767) v = -32767;
    int16_t o = v; fwrite(&o, 2, 1, f);
  }
  fclose(f);
}

static void load_sym(const char *fn) {
  FILE *f = fopen(fn, "r"); if (!f) { perror(fn); exit(1); }
  char line[512];
  // sjasmplus --sym format: "label: EQU 0x00001234"
  static char names[4096][64]; static int addrs[4096]; int n = 0;
  while (fgets(line, sizeof line, f) && n < 4096) {
    char nm[256]; unsigned v;
    if (sscanf(line, "%255[^:]: EQU 0x%x", nm, &v) == 2) { strncpy(names[n], nm, 63); addrs[n] = v; n++; }
  }
  fclose(f);
  for (int i = 0; i < allow_n; i++) { allow_a[i] = -100; for (int j = 0; j < n; j++) if (!strcmp(names[j], allow_names[i])) allow_a[i] = addrs[j]; }
  for (int i = 0; i < nprof; i++) {
    int found = 0;
    for (int j = 0; j < n; j++) if (!strcmp(names[j], prof_name[i])) { prof_addr[i] = addrs[j]; found = 1; }
    if (!found) { fprintf(stderr, "symbol %s not found\n", prof_name[i]); prof_addr[i] = -1; }
  }
}

static void load_script(const char *fn) {
  FILE *f = fopen(fn, "r"); if (!f) { perror(fn); exit(1); }
  char line[512];
  while (fgets(line, sizeof line, f)) {
    if (line[0] == '#' || line[0] == '\n') continue;
    long a, b; char k[256];
    if (sscanf(line, "%ld %ld %255s", &a, &b, k) == 3) { script[nscript].f0 = a; script[nscript].f1 = b; strcpy(script[nscript].keys, k); nscript++; }
  }
  fclose(f);
}

int main(int argc, char **argv) {
  const char *vzfile = 0, *wav = 0, *sym = 0, *video = 0, *dump = 0;
  for (int i = 1; i < argc; i++) {
    char *a = argv[i];
    if (!strcmp(a, "--ram")) { char *r = argv[++i]; bennvenn = !strcmp(r, "bennvenn"); ram_top = !strcmp(r, "bennvenn") ? 0xFFFF : !strcmp(r, "stock") ? 0xB7FF : !strcmp(r, "vz200") ? 0x8FFF : !strcmp(r, "vz200exp") ? 0xCFFF : !strcmp(r, "full") ? 0xFFFF : 0xF7FF; }
    else if (!strcmp(a, "--frames")) frames_to_run = atol(argv[++i]);
    else if (!strcmp(a, "--script")) load_script(argv[++i]);
    else if (!strcmp(a, "--keys")) { // inline: f0:f1:KEYS;...
      char *s = strdup(argv[++i]);
      for (char *t = strtok(s, ";"); t; t = strtok(0, ";")) { long x, y; char k[256]; if (sscanf(t, "%ld:%ld:%255s", &x, &y, k) == 3) { script[nscript].f0 = x; script[nscript].f1 = y; strcpy(script[nscript].keys, k); nscript++; } }
    }
    else if (!strcmp(a, "--shots")) { char *s = strdup(argv[++i]); for (char *t = strtok(s, ","); t; t = strtok(0, ",")) shot_list[nshots++] = atoi(t); }
    else if (!strcmp(a, "--shotdir")) shotdir = argv[++i];
    else if (!strcmp(a, "--wav")) wav = argv[++i];
    else if (!strcmp(a, "--video")) video = argv[++i];
    else if (!strcmp(a, "--sym")) sym = argv[++i];
    else if (!strcmp(a, "--prof")) { char *s = strdup(argv[++i]); for (char *t = strtok(s, ","); t; t = strtok(0, ",")) strcpy(prof_name[nprof++], t); }
    else if (!strcmp(a, "--proflog")) proflog = fopen(argv[++i], "w");
    else if (!strcmp(a, "--joy")) joymode = atoi(argv[++i]);
    else if (!strcmp(a, "--trap2ef4")) trap2ef4 = argv[++i][0];
    else if (!strcmp(a, "--guard")) sscanf(argv[++i], "%x-%x", (unsigned *)&guard_lo, (unsigned *)&guard_hi);
    else if (!strcmp(a, "--sp")) sscanf(argv[++i], "%x-%x", (unsigned *)&sp_lo, (unsigned *)&sp_hi);
    else if (!strcmp(a, "--code")) sscanf(argv[++i], "%x-%x", (unsigned *)&code_lo, (unsigned *)&code_hi);
    else if (!strcmp(a, "--allow")) { char *q = strdup(argv[++i]); for (char *t = strtok(q, ","); t; t = strtok(0, ",")) strcpy(allow_names[allow_n++], t); }
    else if (!strcmp(a, "--spskip")) sscanf(argv[++i], "%x-%x", (unsigned *)&spskip_lo, (unsigned *)&spskip_hi);
    else if (!strcmp(a, "--flat")) flatprof = 1;
    else if (!strcmp(a, "--poke")) { char *q = strdup(argv[++i]); for (char *t = strtok(q, ","); t; t = strtok(0, ",")) { sscanf(t, "%ld:%x:%x", &poke_f[npoke], (unsigned *)&poke_a[npoke], (unsigned *)&poke_v[npoke]); npoke++; } }
    else if (!strcmp(a, "--guardfrom")) guard_from = atol(argv[++i]);
    else if (!strcmp(a, "--dump")) dump = argv[++i];
    else vzfile = a;
  }
  if (!vzfile) { fprintf(stderr, "usage: vzemu file.vz [opts]\n"); return 1; }
  FILE *f = fopen(vzfile, "rb"); if (!f) { perror(vzfile); return 1; }
  uint8_t hdr[24]; fread(hdr, 1, 24, f);
  int type = hdr[21], start = hdr[22] | (hdr[23] << 8);
  int n = fread(mem + start, 1, 65536 - start, f); fclose(f);
  int end = start + n - 1;
  fprintf(stderr, "loaded %s type %02X at %04X-%04X (%d bytes)\n", vzfile, type, start, end, n);
  if (end > ram_top) fprintf(stderr, "WARNING: file extends past RAM top %04X\n", ram_top);
  for (int i = ram_top + 1; i < 65536; i++) if (i >= 0x7800) mem[i] = 0xFF;
  memset(mem + 0x7000, 0x00, 0x800);
  if (sym) load_sym(sym);
  if (video) videof = fopen(video, "wb");
  z80_init(&cpu);
  cpu.read_byte = rb; cpu.write_byte = wb; cpu.port_in = pin; cpu.port_out = pout;
  cpu.sp = 0x7FF0;
  if (type == 0xF0) { // BASIC: emulate "RUN" of a USR stub by finding the USR target poked at 30862/3
    // read USR vector poke values from the tokenised line if present
    int lo = -1, hi = -1;
    for (int p = start; p < start + 64; p++) {
      if (!memcmp(mem + p, "30862,", 6)) lo = atoi((char *)mem + p + 6);
      if (!memcmp(mem + p, "30863,", 6)) hi = atoi((char *)mem + p + 6);
    }
    if (lo < 0 || hi < 0) { fprintf(stderr, "BASIC program without USR stub\n"); return 1; }
    cpu.pc = lo | (hi << 8);
    fprintf(stderr, "BASIC stub -> USR at %04X\n", cpu.pc);
  } else cpu.pc = start;
  cpu.iff1 = cpu.iff2 = 0; cpu.interrupt_mode = 1;
  memset(keyrow, 0x3F, 8);
  apply_inputs();
  long prev_field = 0; long long prof_hits = 0;
  while (field_no < frames_to_run) {
    if (trap2ef4 >= 0 && cpu.pc == 0x2EF4) { // ROM key scan stub: return key, then RET
      cpu.a = (uint8_t)trap2ef4;
      uint16_t r = rb(0, cpu.sp) | (rb(0, cpu.sp + 1) << 8); cpu.sp += 2; cpu.pc = r; cpu.cyc += 200;
    }
    if (nprof) for (int i = 0; i < nprof; i++) if (cpu.pc == prof_addr[i] && proflog) {
      unsigned long long t = total_cyc + cpu.cyc;
      fprintf(proflog, "%ld %ld %s\n", (long)(t / FIELD_T), (long)(t % FIELD_T), prof_name[i]); prof_hits++;
    }
    if ((cpu.pc < code_lo || cpu.pc > code_hi) && pc_reports < 5) {
      if (!(trap2ef4 >= 0 && cpu.pc < 0x4000)) {
        pc_reports++; fprintf(stderr, "PC out of range: %04X at field %ld (SP=%04X)\n", cpu.pc, field_no, cpu.sp);
      }
    }
    unsigned long c0 = cpu.cyc; uint16_t pcb = cpu.pc;
    z80_step(&cpu);
    if ((cpu.sp < sp_lo || cpu.sp > sp_hi) && sp_reports < 5 && !(cpu.pc >= spskip_lo && cpu.pc <= spskip_hi)) {
      // ignore deliberate SP hijacks inside copy routines: only report if PC in code and SP way off
      sp_reports++; fprintf(stderr, "SP out of range: %04X at PC=%04X field %ld\n", cpu.sp, cpu.pc, field_no);
    }
    if (flatprof) pccyc[pcb] += cpu.cyc - c0;
    total_cyc += cpu.cyc - c0; cpu.cyc = c0; // keep cpu.cyc small; we track total
    capture_lines();
    // IM1 interrupt while FS low (level-triggered) if enabled
    if (cpu.iff1 && in_fs()) z80_gen_int(&cpu, 0xFF);
    long fno = (long)(total_cyc / FIELD_T);
    if (fno != prev_field) { field_no = fno; prev_field = fno; apply_inputs(); for (int k = 0; k < npoke; k++) if (poke_f[k] == fno) mem[poke_a[k]] = poke_v[k]; }
    if (cpu.halted && !cpu.iff1) { fprintf(stderr, "HALT with DI at %04X field %ld\n", cpu.pc, field_no); break; }
  }
  fprintf(stderr, "ran %ld fields, %llu T, PC=%04X SP=%04X latch=%02X\n", field_no, total_cyc, cpu.pc, cpu.sp, latch);
  if (wav) { write_wav(wav, total_cyc);
    char fn[600]; snprintf(fn, sizeof fn, "%s.spk", wav); FILE *sf = fopen(fn, "wb");
    for (long i = 0; i < nspk; i++) { fwrite(&spk[i].t, 8, 1, sf); fwrite(&spk[i].lv, 1, 1, sf); } fclose(sf); }
  if (videof) fclose(videof);
  if (proflog) fclose(proflog);
  fprintf(stderr, "mapper=%02X\n", mapper);
  if (flatprof) { FILE *fp = fopen("flat.txt", "w"); for (int i = 0; i < 65536; i++) if (pccyc[i]) fprintf(fp, "%04X %llu\n", i, pccyc[i]); fclose(fp); }
  if (dump) { FILE *d = fopen(dump, "wb"); fwrite(mem, 1, 65536, d); fclose(d); }
  return 0;
}
