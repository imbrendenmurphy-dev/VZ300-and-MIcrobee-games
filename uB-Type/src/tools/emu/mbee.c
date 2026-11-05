/* Microbee Premium Plus test model (not cycle exact for video, exact Z80
   T-states). Ported from the Python model used for The Lantern Deep:
   * 1MB = 32 blocks of 32K. 8000-FFFF is block 0; 0000-7FFF is the block
     selected by port 50h: block = (b7 b6 b5 >> 3) | (b1 b0), b1 inverted
     while b2 (ROMs off) is set (ubee512's Premium Plus model). b3 = 1
     removes the video window, b4 moves it from F000 to 8000. Boot ROM at
     8000-BFFF while b2 = 0.
   * Video window F000-F7FF screen / attribute RAM (port 1Ch b4, b7),
     F800-FFFF PCG bank (1Ch b0-3) or colour RAM (port 08h b6).
   * 6545 registers, status b7 ready, b6 light pen, b5 vertical blanking.
   * Keyboard via light pen (R18/R19 + R31 dummy write; autoscan).
   * PIO B b6 speaker (transitions logged), PIO A joystick.
   * WD2793 at 40h-47h + 48h, enough for the boot ROM and CP/M BIOS. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"

#define FRAME_T 67500

typedef struct {
    Z80 z;
    uint8_t blocks[32][32768];
    uint8_t rom[16384];
    int lower;
    uint8_t p50, p1c, p08, p0b;
    uint8_t scr[2048], attr[2048], col[2048];
    uint8_t pcg[16 * 2048];
    uint8_t crtc[32];
    uint8_t creg;
    uint64_t keys;          /* bit k = key k held */
    uint8_t joy;
    uint8_t spk;
    uint64_t tick;
    int lp_pending;
    uint16_t lp_addr;
    int autoscan;
    /* speaker log */
    uint64_t *spk_t; uint8_t *spk_v; int spk_n, spk_cap;
    /* breakpoints / pc watch */
    uint8_t bp[65536];
    int ww_blk, ww_lo, ww_hi, ww_hit; uint16_t ww_pc, ww_a, curpc;
    uint8_t watch[65536];
    uint64_t *ev_t; uint16_t *ev_pc; int ev_n, ev_cap;
    int profiling;
    uint32_t prof[65536];
    /* disk */
    uint8_t *disk; int disk_len;
    uint8_t fdc_track, fdc_sector, fdc_side, fdc_data, fdc_cmd;
    int fdc_pos, fdc_len, fdc_idx;
    uint8_t fdc_buf[5120];
    uint8_t fdc_wbuf[512]; int fdc_wn;
    int write_protect;
    int fdc_writes;
    int rom_writes;
    uint32_t vram_writes_display;   /* writes to video RAM while not in vblank */
    uint16_t last_pc;
} M;

static int block_of(uint8_t v) {
    int b = ((v & 0xE0) >> 3) | (v & 3);
    if (v & 4) b ^= 2;
    return b;
}

static inline int vblank(M *m) {
    int lines_row = (m->crtc[9] & 31) + 1;
    int rows = m->crtc[6] ? m->crtc[6] : 24;
    int line = (int)((m->tick % FRAME_T) * 312 / FRAME_T);
    return line >= rows * lines_row;
}

static inline int video_at(M *m, uint16_t a) {
    if (m->p50 & 8) return 0;
    uint16_t base = (m->p50 & 0x10) ? 0x8000 : 0xF000;
    return a >= base && a < base + 0x1000;
}

static uint8_t vread(M *m, uint16_t o) {
    if (o < 0x800) {
        if (m->p0b & 1) return 0;
        return ((m->p1c & 0x90) == 0x90) ? m->attr[o] : m->scr[o];
    }
    o -= 0x800;
    if (m->p08 & 0x40) return m->col[o];
    return m->pcg[(m->p1c & 15) * 2048 + o];
}
static void vwrite(M *m, uint16_t o, uint8_t v) {
    if (o < 0x800) {
        if (m->p1c & 0x10) { if (m->p1c & 0x80) m->attr[o] = v; }
        else m->scr[o] = v;
        return;
    }
    o -= 0x800;
    if ((m->p08 & 0x40) && !(m->p0b & 1)) m->col[o] = v;
    else m->pcg[(m->p1c & 15) * 2048 + o] = v;
}

static uint8_t mrd(void *ctx, uint16_t a) {
    M *m = ctx;
    if (a >= 0x8000) {
        if (video_at(m, a)) return vread(m, a & 0xFFF);
        if (!(m->p50 & 4)) return a < 0xC000 ? m->rom[a - 0x8000] : 0xFF;
        return m->blocks[0][a - 0x8000];
    }
    if (video_at(m, a)) return vread(m, a & 0xFFF);
    return m->blocks[m->lower][a];
}
static void mwr(void *ctx, uint16_t a, uint8_t v) {
    M *m = ctx;
    if (video_at(m, a)) {
        if (!vblank(m)) m->vram_writes_display++;
        vwrite(m, a & 0xFFF, v);
        return;
    }
    if (a >= 0x8000) {
        if (!(m->p50 & 4)) { m->rom_writes++; return; }
        if (m->ww_blk == 100 && a >= m->ww_lo && a < m->ww_hi && !m->ww_hit) { m->ww_hit = 1; m->ww_pc = m->curpc; m->ww_a = a; }
        m->blocks[0][a - 0x8000] = v;
        return;
    }
    if (m->lower == m->ww_blk && a >= m->ww_lo && a < m->ww_hi && !m->ww_hit) { m->ww_hit = 1; m->ww_pc = m->curpc; m->ww_a = a; }
    m->blocks[m->lower][a] = v;
}

static void spk_log(M *m, uint8_t b) {
    if (m->spk_n >= m->spk_cap) {
        m->spk_cap = m->spk_cap ? m->spk_cap * 2 : 65536;
        m->spk_t = realloc(m->spk_t, m->spk_cap * sizeof(uint64_t));
        m->spk_v = realloc(m->spk_v, m->spk_cap);
    }
    m->spk_t[m->spk_n] = m->tick;
    m->spk_v[m->spk_n++] = b;
}

/* ---------------- FDC */
static int sec_index(M *m) { return m->fdc_sector >= 21 ? m->fdc_sector - 21 : m->fdc_sector - 1; }
static uint8_t fdc_in(M *m, int p) {
    if (p >= 0x44 && p <= 0x47) p -= 4;
    if (p == 0x40) {
        if ((m->fdc_cmd & 0xE0) == 0xA0)
            return m->fdc_wn < 512 ? 0x03 : (m->write_protect ? 0x40 : 0x00);
        if ((m->fdc_cmd & 0xF0) == 0xC0 && m->fdc_pos >= 4) return 0;
        if (m->fdc_pos < m->fdc_len) return 0x03;
        if (m->fdc_cmd < 0x80) {
            m->fdc_idx++;
            return (m->fdc_track == 0 ? 0x04 : 0) | ((m->fdc_idx & 1) ? 0x02 : 0);
        }
        return 0;
    }
    if (p == 0x41) return m->fdc_track;
    if (p == 0x42) return m->fdc_sector;
    if (p == 0x43) {
        if (m->fdc_pos >= m->fdc_len) return 0;
        return m->fdc_buf[m->fdc_pos++];
    }
    if (p == 0x48) return 0x80;
    return 0xFF;
}
static void fdc_out(M *m, int p, uint8_t v) {
    if (p >= 0x44 && p <= 0x47) p -= 4;
    if (p == 0x41) m->fdc_track = v;
    else if (p == 0x42) m->fdc_sector = v;
    else if (p == 0x43) {
        m->fdc_data = v;
        if ((m->fdc_cmd & 0xE0) == 0xA0 && m->fdc_wn < 512) {
            m->fdc_wbuf[m->fdc_wn++] = v;
            if (m->fdc_wn == 512 && !m->write_protect && m->disk) {
                int o = (m->fdc_track * 2 + m->fdc_side) * 5120 + sec_index(m) * 512;
                if (o >= 0 && o + 512 <= m->disk_len) memcpy(m->disk + o, m->fdc_wbuf, 512);
                m->fdc_writes++;
            }
        }
    } else if (p == 0x48) m->fdc_side = (v >> 2) & 1;
    else if (p == 0x40) {
        m->fdc_cmd = v; m->fdc_len = 0; m->fdc_pos = 0; m->fdc_wn = 0;
        if ((v & 0xF0) == 0) m->fdc_track = 0;
        else if ((v & 0xF0) == 0x10) m->fdc_track = m->fdc_data;
        else if ((v & 0xE0) == 0x40) { if (m->fdc_track < 79) m->fdc_track++; }
        else if ((v & 0xE0) == 0x60) { if (m->fdc_track > 0) m->fdc_track--; }
        else if ((v & 0xE0) == 0x80) {
            int s = sec_index(m);
            int o = (m->fdc_track * 2 + m->fdc_side) * 5120 + s * 512;
            int len = (v & 16) ? (10 - s) * 512 : 512;
            if (m->disk && o >= 0 && s >= 0 && s < 10 && o + len <= m->disk_len) {
                memcpy(m->fdc_buf, m->disk + o, len); m->fdc_len = len;
            }
        } else if ((v & 0xF0) == 0xC0) {
            uint8_t id[6] = { m->fdc_track, 0, m->fdc_track < 2 ? 1 : 21, 2, 0, 0 };
            memcpy(m->fdc_buf, id, 6); m->fdc_len = 6;
        }
    }
}

static uint8_t pin(void *ctx, uint16_t port) {
    M *m = ctx;
    int p = port & 0xFF;
    if (p == 0x0C) {
        uint8_t st = 0x80;
        if (!m->lp_pending && m->keys && !(m->p0b & 1) && m->autoscan) {
            int k = 0; while (!((m->keys >> k) & 1)) k++;
            m->lp_pending = 1; m->lp_addr = k << 4;
        }
        if (m->lp_pending) st |= 0x40;
        if (vblank(m)) st |= 0x20;
        return st;
    }
    if (p == 0x0D) {
        if (m->creg == 16 || m->creg == 17) {
            m->lp_pending = 0;
            return m->creg == 16 ? (m->lp_addr >> 8) & 0x3F : m->lp_addr & 0xFF;
        }
        return m->crtc[m->creg];
    }
    if (p == 0x00) return m->joy;
    if (p == 0x09) return 0;
    if (p == 0x02) return 0xFF;
    if (p == 0x1C) return m->p1c;
    if (p == 0x08) return m->p08;
    if (p >= 0x40 && p <= 0x48) return fdc_in(m, p);
    return 0xFF;
}
static void pout(void *ctx, uint16_t port, uint8_t v) {
    M *m = ctx;
    int p = port & 0xFF;
    if (p == 0x50) { m->p50 = v; m->lower = block_of(v); }
    else if (p == 0x1C) m->p1c = v;
    else if (p == 0x08) m->p08 = v;
    else if (p == 0x0B) m->p0b = v;
    else if (p == 0x0C) m->creg = v & 31;
    else if (p == 0x0D) {
        m->crtc[m->creg] = v;
        if (m->creg == 31) {
            uint16_t addr = ((m->crtc[18] & 0x3F) << 8) | m->crtc[19];
            int key = ((m->crtc[18] & 3) << 4) | (m->crtc[19] >> 4);
            if ((m->keys >> key) & 1) { m->lp_pending = 1; m->lp_addr = addr; }
        }
    } else if (p == 0x02) {
        uint8_t b = (v & 0x40) ? 1 : 0;
        if (b != m->spk) { m->spk = b; spk_log(m, b); }
    } else if (p >= 0x40 && p <= 0x48) fdc_out(m, p, v);
}

/* ---------------- API */
M *mb_new(void) {
    M *m = calloc(1, sizeof(M));
    m->z.ctx = m; m->z.rd = mrd; m->z.wr = mwr; m->z.in = pin; m->z.out = pout;
    z80_reset(&m->z);
    memset(m->rom, 0xFF, sizeof m->rom);
    m->autoscan = 1; m->joy = 0xFF;
    m->lower = block_of(0);
    return m;
}
void mb_free(M *m) { free(m->spk_t); free(m->spk_v); free(m->ev_t); free(m->ev_pc); free(m->disk); free(m); }
void mb_set_rom(M *m, const uint8_t *d, int n) { memset(m->rom, 0xFF, sizeof m->rom); memcpy(m->rom, d, n > 16384 ? 16384 : n); }
void mb_set_disk(M *m, const uint8_t *d, int n) { free(m->disk); m->disk = malloc(n); memcpy(m->disk, d, n); m->disk_len = n; }
uint8_t *mb_disk(M *m) { return m->disk; }
void mb_out(M *m, int p, int v) { pout(m, p, v); }
Z80 *mb_cpu(M *m) { return &m->z; }
uint8_t *mb_block(M *m, int b) { return m->blocks[b]; }
uint8_t *mb_scr(M *m) { return m->scr; }
uint8_t *mb_attr(M *m) { return m->attr; }
uint8_t *mb_col(M *m) { return m->col; }
uint8_t *mb_pcg(M *m) { return m->pcg; }
uint8_t *mb_crtc(M *m) { return m->crtc; }
uint8_t *mb_regs(M *m) { static uint8_t r[8]; r[0] = m->p50; r[1] = m->p1c; r[2] = m->p08; r[3] = m->p0b; r[4] = m->lower; return r; }
uint64_t mb_tick(M *m) { return m->tick; }
void mb_set_keys(M *m, uint64_t k) { m->keys = k; }
void mb_set_joy(M *m, int j) { m->joy = j; }
uint8_t mb_peek(M *m, uint16_t a) {
    if (a >= 0x8000) {
        if (video_at(m, a)) return vread(m, a & 0xFFF);
        if (!(m->p50 & 4)) return a < 0xC000 ? m->rom[a - 0x8000] : 0xFF;
        return m->blocks[0][a - 0x8000];
    }
    return m->blocks[m->lower][a];
}
void mb_poke(M *m, uint16_t a, uint8_t v) { mwr(m, a, v); }
void mb_set_bp(M *m, uint16_t a, int on) { m->bp[a] = on; }
void mb_set_watch(M *m, uint16_t a, int on) { m->watch[a] = on; }
int mb_events(M *m, uint64_t **t, uint16_t **pc) { *t = m->ev_t; *pc = m->ev_pc; return m->ev_n; }
void mb_clear_events(M *m) { m->ev_n = 0; }
int mb_spk(M *m, uint64_t **t, uint8_t **v) { *t = m->spk_t; *v = m->spk_v; return m->spk_n; }
void mb_clear_spk(M *m) { m->spk_n = 0; }
void mb_profile(M *m, int on) { m->profiling = on; if (on) memset(m->prof, 0, sizeof m->prof); }
uint32_t *mb_prof(M *m) { return m->prof; }
uint32_t mb_vram_disp_writes(M *m, int reset) { uint32_t v = m->vram_writes_display; if (reset) m->vram_writes_display = 0; return v; }
int mb_fdc_writes(M *m) { return m->fdc_writes; }
void mb_set_wp(M *m, int on) { m->write_protect = on; }

/* run until tick >= target or a breakpoint; returns 1 if a breakpoint hit */
int mb_run(M *m, uint64_t target) {
    Z80 *z = &m->z;
    while (m->tick < target) {
        uint16_t pc = z->pc;
        m->curpc = pc;
        if (m->watch[pc]) {
            if (m->ev_n >= m->ev_cap) {
                m->ev_cap = m->ev_cap ? m->ev_cap * 2 : 4096;
                m->ev_t = realloc(m->ev_t, m->ev_cap * sizeof(uint64_t));
                m->ev_pc = realloc(m->ev_pc, m->ev_cap * sizeof(uint16_t));
            }
            m->ev_t[m->ev_n] = m->tick; m->ev_pc[m->ev_n++] = pc;
        }
        int t = z80_step(z);
        m->tick += t;
        if (m->profiling) m->prof[pc] += t;
        if (m->bp[z->pc]) return 1;
        if (m->ww_hit == 1) { m->ww_hit = 2; return 2; }
    }
    return 0;
}

void mb_set_ww(M *m, int blk, int lo, int hi) { m->ww_blk = blk; m->ww_lo = lo; m->ww_hi = hi; m->ww_hit = 0; }
int mb_ww(M *m, int *a) { *a = m->ww_a; return m->ww_hit ? m->ww_pc : -1; }
