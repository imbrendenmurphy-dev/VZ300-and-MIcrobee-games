// beemu - Microbee Premium Plus test model as a shared library (driven from
// Python via ctypes).  Ported from the Codex ppmodel.py hardware description
// (itself derived from ubee512) onto the cycle-counting z80core.
//
//  * RAM: 32 blocks x 32K.  8000-FFFF is block 0; 0000-7FFF is the block
//    selected by port 50h: ((v & E0h) >> 3) | (v & 3), b1 inverted when b2
//    (ROMs off) is set.  b3 = no video window, b4 = window at 8000 not F000.
//    Boot ROM at 8000-BFFF while b2 = 0.
//  * Video window: F000-F7FF screen RAM (attribute RAM when port 1Ch b4,
//    char ROM when port 0Bh b0); F800-FFFF PCG bank (1Ch b0-3) or colour RAM
//    (port 08h b6).  Screen code >= 80h -> PCG, bank = attribute b0-3.
//  * 6545: registers, status b7 strobe, b6 light pen, b5 vertical blanking.
//    Display is captured scan line by scan line as the beam passes, using the
//    live start address, so tearing and flicker show up in captures.
//  * Keyboard: light pen test via R18/R19 + R31; PIO A joystick; PIO B b6
//    speaker (logged).  WD2793 FDC at 40h-48h (enough for boot ROM/CP/M).
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include "z80.h"

#define FRAME_T 67500
#define LINES 312

static z80 cpu;
static uint8_t ram[32][32768];
static uint8_t rom[16384];
static uint8_t charrom[4096];
static uint8_t scr[2048], attr[2048], col[2048], pcg[32768];
static uint8_t p50, p1c, p08, p0b, creg, crtc[32];
static uint8_t keys[128];
static uint8_t joy = 0xFF;
static int lp_pending; static int lp_addr;
static int lower = 1;
static unsigned long long frames_done;      // completed 67500-T frames
static long long frame_start;               // cpu.cyc at start of current frame
static int spk_level;
// speaker log
static unsigned long long *spk_t; static uint8_t *spk_v; static long nspk, capspk;
// beam capture: 256 visible lines x 512 px, palette index; keep last full frame
static uint8_t fb_work[300][640];
static uint8_t fb_done[300][640];
static int fb_w = 512, fb_h = 256, fb_w_done = 512, fb_h_done = 256;
static int last_line = -1;
static int mono_capture = 0;
// FDC
static uint8_t *disk; static long disk_len;
static int fdc_track, fdc_sector = 1, fdc_side, fdc_data, fdc_cmd, fdc_idx;
static uint8_t *fdc_buf; static long fdc_buflen, fdc_pos;
static uint8_t fdc_wbuf[512]; static int fdc_wlen; static int fdc_writes;
// profiling
static unsigned long long *prof;          // per PC in current mapping (64K)
static int profiling;
static unsigned long long cyc_sim, cyc_art;
unsigned long long bee_cyc_sim(void){return cyc_sim;}
unsigned long long bee_cyc_art(void){return cyc_art;}
static int rom_writes;
// stats
static long long vblank_waits_t;          // T spent with PC in user-flagged wait range
static int wait_lo = -1, wait_hi = -1;
static int irq_vec = -1;

static int block_of(int v) {
  int b = ((v & 0xE0) >> 3) | (v & 3);
  if (v & 4) b ^= 2;
  return b;
}
static int video_at(uint16_t a) {
  if (p50 & 8) return 0;
  int base = (p50 & 0x10) ? 0x8000 : 0xF000;
  return a >= base && a < base + 0x1000;
}
static uint8_t vread(int o) {
  if (o < 0x800) {
    if (p0b & 1) return charrom[o & 0xFFF];
    return ((p1c & 0x90) == 0x90) ? attr[o] : scr[o];
  }
  o -= 0x800;
  if (p0b & 1) return charrom[0x800 + o];
  if (p08 & 0x40) return col[o];
  return pcg[(p1c & 15) * 2048 + o];
}
static void vwrite(int o, uint8_t v) {
  if (o < 0x800) {
    if (p1c & 0x10) { if (p1c & 0x80) attr[o] = v; }
    else scr[o] = v;
    return;
  }
  o -= 0x800;
  if ((p08 & 0x40) && !(p0b & 1)) col[o] = v;
  else pcg[(p1c & 15) * 2048 + o] = v;
}
static uint8_t rb(void *u, uint16_t a) {
  (void)u;
  if (video_at(a)) return vread(a & 0xFFF);
  if (a >= 0x8000) {
    if (!(p50 & 4)) return a < 0xC000 ? rom[a - 0x8000] : 0xFF;
    return ram[0][a - 0x8000];
  }
  return ram[lower][a];
}
static void wb(void *u, uint16_t a, uint8_t v) {
  (void)u;
  if (video_at(a)) { vwrite(a & 0xFFF, v); return; }
  if (a >= 0x8000) {
    if (!(p50 & 4)) { rom_writes++; return; }
    ram[0][a - 0x8000] = v; return;
  }
  ram[lower][a] = v;
}

static long long now(void) { return (long long)cpu.cyc; }
static int cur_line(void) {
  long long t = now() - frame_start;
  if (t < 0) t = 0;
  return (int)(t * LINES / FRAME_T);
}
static int vblank(void) {
  int lr = (crtc[9] & 31) + 1;
  int rows = crtc[6] ? crtc[6] : 16;
  int l = cur_line();
  return l >= rows * lr && l < LINES;
}

static void spk_log(int v) {
  if (nspk == capspk) {
    capspk = capspk ? capspk * 2 : (1 << 16);
    spk_t = realloc(spk_t, capspk * sizeof *spk_t);
    spk_v = realloc(spk_v, capspk);
  }
  spk_t[nspk] = frames_done * FRAME_T + (now() - frame_start);
  spk_v[nspk] = v; nspk++;
}

static void fdc_out(int p, uint8_t v) {
  if (p >= 0x44 && p <= 0x47) p -= 4;
  if (p == 0x41) fdc_track = v;
  else if (p == 0x42) fdc_sector = v;
  else if (p == 0x43) {
    fdc_data = v;
    if ((fdc_cmd & 0xE0) == 0xA0 && fdc_wlen < 512) {
      fdc_wbuf[fdc_wlen++] = v;
      if (fdc_wlen == 512 && disk) {
        int s = fdc_sector >= 21 ? fdc_sector - 21 : fdc_sector - 1;
        long o = (long)(fdc_track * 2 + fdc_side) * 5120 + s * 512;
        if (o + 512 <= disk_len) memcpy(disk + o, fdc_wbuf, 512);
        fdc_writes++;
      }
    }
  } else if (p == 0x48) fdc_side = (v >> 2) & 1;
  else if (p == 0x40) {
    fdc_cmd = v; fdc_buf = 0; fdc_buflen = 0; fdc_pos = 0; fdc_wlen = 0;
    static uint8_t idbuf[6];
    if ((v & 0xF0) == 0) fdc_track = 0;
    else if ((v & 0xF0) == 0x10) fdc_track = fdc_data;
    else if ((v & 0xE0) == 0x40) { if (fdc_track < 79) fdc_track++; }
    else if ((v & 0xE0) == 0x60) { if (fdc_track > 0) fdc_track--; }
    else if ((v & 0xE0) == 0x80) {
      int s = fdc_sector >= 21 ? fdc_sector - 21 : fdc_sector - 1;
      long o = (long)(fdc_track * 2 + fdc_side) * 5120 + s * 512;
      long len = (v & 16) ? (10 - s) * 512 : 512;
      if (disk && o + len <= disk_len) { fdc_buf = disk + o; fdc_buflen = len; }
    } else if ((v & 0xF0) == 0xC0) {
      idbuf[0] = fdc_track; idbuf[1] = 0; idbuf[2] = fdc_track < 2 ? 1 : 21; idbuf[3] = 2; idbuf[4] = idbuf[5] = 0;
      fdc_buf = idbuf; fdc_buflen = 6;
    }
  }
}
static uint8_t fdc_in(int p) {
  if (p >= 0x44 && p <= 0x47) p -= 4;
  if (p == 0x40) {
    if ((fdc_cmd & 0xE0) == 0xA0) return fdc_wlen < 512 ? 0x03 : 0x00;
    if ((fdc_cmd & 0xF0) == 0xC0 && fdc_pos >= 4) return 0;
    if (fdc_pos < fdc_buflen) return 0x03;
    if (fdc_cmd < 0x80) { fdc_idx++; return (fdc_track == 0 ? 4 : 0) | ((fdc_idx & 1) ? 2 : 0); }
    return 0;
  }
  if (p == 0x41) return fdc_track;
  if (p == 0x42) return fdc_sector;
  if (p == 0x43) { if (fdc_pos >= fdc_buflen) return 0; return fdc_buf[fdc_pos++]; }
  if (p == 0x48) return 0x80;
  return 0xFF;
}

static int any_key(void) { for (int i = 0; i < 64; i++) if (keys[i]) return i; return -1; }

static uint8_t pin(z80 *z, uint8_t port) {
  (void)z;
  int p = port;
  if (p == 0x0C) {
    uint8_t st = 0x80;
    int k = any_key();
    if (!lp_pending && k >= 0 && !(p0b & 1)) { lp_pending = 1; lp_addr = k << 4; }
    if (lp_pending) st |= 0x40;
    if (vblank()) st |= 0x20;
    return st;
  }
  if (p == 0x0D) {
    if (creg == 16 || creg == 17) {
      lp_pending = 0;
      return creg == 16 ? (lp_addr >> 8) & 0x3F : lp_addr & 0xFF;
    }
    return crtc[creg];
  }
  if (p == 0x00) return joy;
  if (p == 0x02) return 0xFF;
  if (p == 0x09) return 0;
  if (p == 0x1C) return p1c;
  if (p == 0x08) return p08;
  if (p >= 0x40 && p <= 0x48) return fdc_in(p);
  return 0xFF;
}
static void pout(z80 *z, uint8_t port, uint8_t v) {
  (void)z;
  int p = port;
  if (p == 0x50) { p50 = v; lower = block_of(v); }
  else if (p == 0x1C) p1c = v;
  else if (p == 0x08) p08 = v;
  else if (p == 0x0B) p0b = v;
  else if (p == 0x0C) creg = v & 31;
  else if (p == 0x0D) {
    crtc[creg] = v;
    if (creg == 31) {
      int addr = ((crtc[18] & 0x3F) << 8) | crtc[19];
      int key = ((crtc[18] & 3) << 4) | (crtc[19] >> 4);
      if (keys[key]) { lp_pending = 1; lp_addr = addr; }
    }
  } else if (p == 0x02) {
    int b = (v & 0x40) ? 1 : 0;
    if (b != spk_level) { spk_level = b; spk_log(b); }
  } else if (p >= 0x40 && p <= 0x48) fdc_out(p, v);
}

// ---------------------------------------------------------------- display
static void render_line(int l) {
  int lr = (crtc[9] & 31) + 1;
  int cols = crtc[1] ? crtc[1] : 64;
  int rows = crtc[6] ? crtc[6] : 16;
  if (l >= rows * lr || l >= 300) return;
  int start = ((crtc[12] & 0x3F) << 8) | crtc[13];
  int r = l / lr, sl = l % lr;
  int w = cols * 8; if (w > 640) w = 640;
  for (int c = 0; c < cols && c * 8 < 640; c++) {
    int a = (start + r * cols + c) & 0x7FF;
    int ch = scr[a];
    int co = col[a];
    int fg = co & 15, bg = co >> 4;
    int bits;
    if (ch & 0x80) bits = pcg[(attr[a] & 15) * 2048 + (ch & 0x7F) * 16 + (sl & 15)];
    else bits = charrom[ch * 16 + (sl & 15)];
    for (int x = 0; x < 8; x++) {
      int on = (bits >> (7 - x)) & 1;
      fb_work[l][c * 8 + x] = mono_capture ? (on ? 16 : 0) : (on ? fg : bg);
    }
  }
  fb_w = w; fb_h = rows * lr;
}
static void capture_upto(int line) {
  while (last_line < line) {
    last_line++;
    if (last_line < 300) render_line(last_line);
  }
}

// ---------------------------------------------------------------- API
void bee_init(void) {
  memset(&cpu, 0, sizeof cpu);
  z80_init(&cpu);
  cpu.read_byte = rb; cpu.write_byte = wb; cpu.port_in = pin; cpu.port_out = pout;
  memset(ram, 0, sizeof ram); memset(scr, 0, sizeof scr); memset(attr, 0, sizeof attr);
  memset(col, 0, sizeof col); memset(pcg, 0, sizeof pcg); memset(crtc, 0, sizeof crtc);
  crtc[1] = 64; crtc[6] = 16; crtc[9] = 15;
  p50 = 0; lower = block_of(0); p1c = p08 = p0b = 0; joy = 0xFF;
  memset(keys, 0, sizeof keys);
  frames_done = 0; frame_start = 0; last_line = -1; nspk = 0; spk_level = 0;
  if (!prof) prof = calloc(65536, sizeof *prof);
  rom_writes = 0; fdc_writes = 0;
}
void bee_load_rom(const uint8_t *d, int n) { memset(rom, 0xFF, sizeof rom); memcpy(rom, d, n > 16384 ? 16384 : n); }
void bee_load_charrom(const uint8_t *d, int n) { memcpy(charrom, d, n > 4096 ? 4096 : n); }
void bee_load_disk(uint8_t *d, long n) { disk = d; disk_len = n; }
uint8_t *bee_block(int b) { return ram[b & 31]; }
uint8_t *bee_video(int which) { return which == 0 ? scr : which == 1 ? attr : which == 2 ? col : pcg; }
uint8_t *bee_crtc(void) { return crtc; }
void bee_set_key(int k, int down) { keys[k & 127] = down ? 1 : 0; }
void bee_set_joy(int v) { joy = v; }
void bee_set_mono(int m) { mono_capture = m; }
int bee_get_port(int p) { return p == 0x50 ? p50 : p == 0x1C ? p1c : p == 0x08 ? p08 : p == 0x0B ? p0b : -1; }
void bee_set_port(int p, int v) { pout(&cpu, p, v); }
uint8_t bee_peek(int a) { return rb(0, a); }
void bee_poke(int a, int v) { wb(0, a, v); }
int bee_reg(int which) {
  switch (which) {
  case 0: return cpu.pc; case 1: return cpu.sp; case 2: return cpu.a; case 3: return (cpu.h << 8) | cpu.l;
  case 4: return (cpu.d << 8) | cpu.e; case 5: return (cpu.b << 8) | cpu.c; case 6: return cpu.ix; case 7: return cpu.iy;
  case 8: return cpu.iff1; case 9: return cpu.interrupt_mode;
  }
  return 0;
}
void bee_set_pc(int pc, int sp) { cpu.pc = pc; cpu.sp = sp; }
long long bee_cycles(void) { return (long long)(frames_done * FRAME_T) + (now() - frame_start); }
void bee_profile(int on) { profiling = on; if (on) { memset(prof, 0, 65536 * sizeof *prof); cyc_sim = cyc_art = 0; } }
unsigned long long *bee_prof(void) { return prof; }
int bee_rom_writes(void) { return rom_writes; }
int bee_fdc_writes(void) { return fdc_writes; }
void bee_wait_range(int lo, int hi) { wait_lo = lo; wait_hi = hi; vblank_waits_t = 0; }
long long bee_wait_t(void) { return vblank_waits_t; }

static void step(void) {
  unsigned long c0 = cpu.cyc;
  uint16_t pc = cpu.pc;
  z80_step(&cpu);
  unsigned long d = cpu.cyc - c0;
  if (profiling) { if (pc < 0x8000 && lower != 1) { cyc_art += d; prof[0] += 0; } else { prof[pc] += d; if (pc < 0x8000) cyc_sim += d; } }
  if (wait_lo >= 0 && pc >= wait_lo && pc <= wait_hi) vblank_waits_t += d;
}
// run until frame boundary; returns 1 if breakpoint hit
static int bp = -1;
void bee_set_bp(int a) { bp = a; }
int bee_run_frames(int n) {
  for (int f = 0; f < n; f++) {
    while (now() - frame_start < FRAME_T) {
      capture_upto(cur_line());
      step();
      if (bp >= 0 && cpu.pc == bp) { return 1; }
    }
    capture_upto(LINES);
    memcpy(fb_done, fb_work, sizeof fb_done);
    fb_w_done = fb_w; fb_h_done = fb_h;
    frame_start += FRAME_T; frames_done++; last_line = -1;
  }
  return 0;
}
long long bee_frames(void) { return frames_done; }
uint8_t *bee_frame(int *w, int *h) { *w = fb_w_done; *h = fb_h_done; return &fb_done[0][0]; }
int bee_frame_stride(void) { return 640; }
long bee_spk(unsigned long long **t, uint8_t **v) { *t = spk_t; *v = spk_v; return nspk; }
void bee_spk_clear(void) { nspk = 0; }
// run until the current frame reaches T-state t (0..FRAME_T)
void bee_run_to(long t) {
  while (now() - frame_start < t) { capture_upto(cur_line()); step(); }
}
