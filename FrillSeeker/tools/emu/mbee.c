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

#define FRAME_T 67608
#define FB_W 720
#define FB_H 320
#define TOP 25      /* display line 0 is TOP lines after the vsync start (standard 64x16) */

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
    int vwait;                      /* wait T-states owed by this instruction */
    int clk40;                      /* the 40-column dot clock (IN (09h) with A = 1): a character every 4 T */
    int ven_prev; uint64_t ven_tick;
    uint32_t vwait_total;
    uint16_t last_pc;
    /* PIO B control (mode 3 bit control, interrupts) */
    int pb_next;                 /* 0 normal, 1 direction byte follows, 2 mask follows */
    uint8_t pb_mode, pb_dir, pb_mask, pb_vec, pb_ictl;
    /* Microbee mouse interface (uBee512 model): bit 2 = DTR clock, bit 3 = CTS data (inverted) */
    uint8_t mq[256][3]; int mq_head, mq_tail;
    uint8_t mpk[3]; int m_active, m_byte, m_bit, m_mask;
    uint64_t m_next;
    uint8_t m_dtr, m_cts;
    int irq_pending;
    uint32_t mouse_irqs, mouse_overruns, mouse_packets;
    /* ---- raster-accurate 6545 (6845 type 0 counters, MAME r6545 semantics) */
    uint64_t ctick;              /* T-state the 6545 has been run to */
    int hc, ra, row, adj, adjc, venable, vs_lines, hs;
    uint16_t ma_row;
    int pl;                      /* physical line since the last vsync start */
    int line_len_bad;
    uint64_t frame_no;           /* vsyncs seen */
    int last_frame_lines;        /* lines between the last two vsyncs */
    uint8_t fb[2][FB_H][FB_W];   /* colour index per pixel, [0] drawing, [1] last complete */
    int fbw;                     /* which is drawing */
    uint16_t fl_lines[4096]; int fl_n;   /* frame lengths log */
    /* CRTC write log: frame, physical line, char, reg, value */
    uint32_t *cw; int cw_n, cw_cap; int cw_on;
} M;

static int block_of(uint8_t v) {
    int b = ((v & 0xE0) >> 3) | (v & 3);
    if (v & 4) b ^= 2;
    return b;
}

static inline int vblank(M *m) { return !m->venable; }

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

/* The Premium holds the CPU when it touches video RAM while a line is
   being displayed, until the horizontal (or vertical) blanking: seen on
   the real machine (Nov 2026: a plasma writing colour RAM mid-line rolled). */
static void crtc_sync(M *m, uint64_t t);
int g_vwait_mode = 1, g_vwait_t = 4;
int g_b5_lag = 0;              /* chars the status bit lags the display enable */   /* 1: until the blanking, 2: g_vwait_t a access */
static void vram_wait(M *m) {
    crtc_sync(m, m->tick + m->vwait + 6);
    if (g_vwait_mode == 3) { m->vwait += g_vwait_t; m->vwait_total += g_vwait_t; return; }
    if (m->venable && m->hc < m->crtc[1]) {
        int w = g_vwait_mode == 2 ? g_vwait_t : (m->crtc[1] - m->hc) * (m->clk40 ? 4 : 2);
        m->vwait += w;
        m->vwait_total += w;
        crtc_sync(m, m->tick + m->vwait + 6);
    }
}
static uint8_t mrd(void *ctx, uint16_t a) {
    M *m = ctx;
    if (a >= 0x8000) {
        if (video_at(m, a)) { vram_wait(m); return vread(m, a & 0xFFF); }
        if (!(m->p50 & 4)) return a < 0xC000 ? m->rom[a - 0x8000] : 0xFF;
        return m->blocks[0][a - 0x8000];
    }
    if (video_at(m, a)) { vram_wait(m); return vread(m, a & 0xFFF); }
    return m->blocks[m->lower][a];
}
static void mwr(void *ctx, uint16_t a, uint8_t v) {
    M *m = ctx;
    if (video_at(m, a)) {
        vram_wait(m);
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


/* ---------------- 6545 raster model
   Counters as a 6845 type 0 / MAME's r6545: a character every 2 T (13.5 MHz
   / 8); a line is R0+1 characters; RA counts to R9, then the row counter
   to R4, then R5 adjust lines, then a new frame (MA = R12/R13, display on).
   The vertical display turns off when a row starting equals R6 (status b5
   is set while it is off). VSYNC starts on a row start equal to R7 and
   lasts R3 b7-4 lines (0 = 16); the physical picture restarts there. */
static void ven_set(M *m, int v) { if (v != m->venable) { m->ven_prev = m->venable; m->ven_tick = m->ctick; } m->venable = v; }
static void crtc_frame(M *m) {
    m->row = 0; m->ra = 0; m->adj = 0; m->adjc = 0;
    m->ma_row = (((m->crtc[12] & 0x3F) << 8) | m->crtc[13]);
    ven_set(m, 1);
}
static void crtc_rowstart(M *m) {
    if (m->row == (m->crtc[7] & 127) && !m->vs_lines) {
        int w = m->crtc[3] >> 4; if (!w) w = 16;
        m->vs_lines = w;
        /* the monitor's beam returns: a picture is complete */
        if (m->fl_n < 4096) m->fl_lines[m->fl_n++] = m->pl;
        m->last_frame_lines = m->pl;
        m->frame_no++;
        m->fbw ^= 1;
        memset(m->fb[m->fbw], 0, sizeof m->fb[0]);
        m->pl = 0;
    }
}
static void crtc_endline2(M *m);
static void crtc_endline(M *m) {
    crtc_endline2(m);
    /* the real 6545 compares the row counter with R6 continually (seen on
       hardware: R6 = 0 written mid-frame blanked the rest of it at once) */
    ven_set(m, m->row < (m->crtc[6] & 127));
    /* the real Premium Plus 6545 (seen on hardware, Nov 2026): while the
       row counter is 0, every scanline starts from R12/R13 again */
    if (m->row == 0 && !m->adj)
        m->ma_row = (((m->crtc[12] & 0x3F) << 8) | m->crtc[13]);
}
static void crtc_endline2(M *m) {
    uint8_t *R = m->crtc;
    m->pl++;
    if (m->vs_lines) m->vs_lines--;
    if (m->adj) {
        m->adjc = (m->adjc + 1) & 31;
        if (m->adjc == (R[5] & 31)) { crtc_frame(m); crtc_rowstart(m); }
        return;
    }
    if (m->ra == (R[9] & 31)) {
        m->ra = 0;
        if (m->row == (R[4] & 127)) {
            if (R[5] & 31) { m->adj = 1; m->adjc = 0; m->row = (m->row + 1) & 127; m->ma_row += R[1]; }
            else { crtc_frame(m); crtc_rowstart(m); }
        } else {
            m->row = (m->row + 1) & 127; m->ma_row += R[1];
            crtc_rowstart(m);
        }
    } else m->ra = (m->ra + 1) & 31;
}
static void crtc_char(M *m) {
    uint8_t *R = m->crtc;
    int y = m->pl - (TOP - 16);
    if (m->venable && m->hc < R[1] && y >= 0 && y < FB_H) {
        int cwid = m->clk40 ? 16 : 8;
        int x = 40 + m->hc * cwid;
        if (x + cwid <= FB_W) {
            int a = (m->ma_row + m->hc) & 0x7FF;
            uint8_t code = m->scr[a], at = m->attr[a], c = m->col[a];
            int rl = (m->adj ? m->adjc : m->ra) & 15;
            uint8_t g = 0;
            if (code & 0x80) g = m->pcg[(at & 15) * 2048 + (code & 0x7F) * 16 + rl];
            else if (code != 0x20 && code) g = (rl > 2 && rl < 12) ? 0x7E : 0;   /* ROM font stand-in */
            uint8_t ink = c & 15, paper = c >> 4;
            uint8_t *p = &m->fb[m->fbw][y][x];
            if (m->clk40) for (int i = 0; i < 8; i++) p[2 * i] = p[2 * i + 1] = (g & (0x80 >> i)) ? ink : paper;
            else for (int i = 0; i < 8; i++) p[i] = (g & (0x80 >> i)) ? ink : paper;
        }
    }
    if (m->hc == R[0]) { m->hc = 0; crtc_endline(m); }
    else m->hc = (m->hc + 1) & 255;
}
static void crtc_sync(M *m, uint64_t t) {
    int step = m->clk40 ? 4 : 2;
    while (m->ctick + step <= t) { crtc_char(m); m->ctick += step; }
}

/* ---------------- FDC */
static int sec_index(M *m) { return m->fdc_sector >= 21 ? m->fdc_sector - 21 : m->fdc_sector - 1; }
static uint8_t fdc_in(M *m, int p) {
    if (p >= 0x44 && p <= 0x47) p -= 4;
    if (p == 0x40) {
        if ((m->fdc_cmd & 0xE0) == 0xA0) {
            if (m->write_protect) return 0x40;   /* the WD279x stops at once */
            return m->fdc_wn < 512 ? 0x03 : 0x00;
        }
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
        crtc_sync(m, m->tick + 8);
        uint8_t st = 0x80;
        if (!m->lp_pending && m->keys && !(m->p0b & 1) && m->autoscan) {
            int k = 0; while (!((m->keys >> k) & 1)) k++;
            m->lp_pending = 1; m->lp_addr = k << 4;
        }
        if (m->lp_pending) st |= 0x40;
        { int v = m->venable; if (m->ctick - m->ven_tick < (uint64_t)g_b5_lag * 2) v = m->ven_prev; if (!v) st |= 0x20; }
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
    if (p == 0x02) return (uint8_t)(0x80 | m->m_dtr | m->m_cts | (m->spk ? 0x40 : 0));
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
        crtc_sync(m, m->tick + 9);
        if (m->cw_on) {
            if (m->cw_n + 2 > m->cw_cap) { m->cw_cap = m->cw_cap ? m->cw_cap * 2 : 65536; m->cw = realloc(m->cw, m->cw_cap * 4); }
            m->cw[m->cw_n++] = (uint32_t)m->frame_no;
            m->cw[m->cw_n++] = ((uint32_t)(m->pl & 0x3FF) << 22) | ((uint32_t)(m->hc & 0xFF) << 14) | ((m->creg & 31) << 8) | v;
        }
        m->crtc[m->creg] = v;
        /* the 40-column tables (R0 = 35h, as BPM's MODES.COM, proven on the
           Premium Plus) run at half the dot clock: a character every 4 T */
        if (m->creg == 0) m->clk40 = v < 0x40;
        if (m->creg == 31) {
            uint16_t addr = ((m->crtc[18] & 0x3F) << 8) | m->crtc[19];
            int key = ((m->crtc[18] & 3) << 4) | (m->crtc[19] >> 4);
            if ((m->keys >> key) & 1) { m->lp_pending = 1; m->lp_addr = addr; }
        }
    } else if (p == 0x02) {
        if (m->cw_on) {
            crtc_sync(m, m->tick + 9);
            if (m->cw_n + 2 > m->cw_cap) { m->cw_cap = m->cw_cap ? m->cw_cap * 2 : 65536; m->cw = realloc(m->cw, m->cw_cap * 4); }
            m->cw[m->cw_n++] = (uint32_t)m->frame_no;
            m->cw[m->cw_n++] = ((uint32_t)(m->pl & 0x3FF) << 22) | ((uint32_t)(m->hc & 0xFF) << 14) | (30 << 8) | v;
        }
        uint8_t b = (v & 0x40) ? 1 : 0;
        if (b != m->spk) { m->spk = b; spk_log(m, b); }
    } else if (p == 0x03) {
        if (m->pb_next == 1) { m->pb_dir = v; m->pb_next = 0; }
        else if (m->pb_next == 2) { m->pb_mask = v; m->pb_next = 0; }
        else if ((v & 1) == 0) m->pb_vec = v;
        else if ((v & 0x0F) == 0x0F) { m->pb_mode = v >> 6; if (m->pb_mode == 3) m->pb_next = 1; }
        else if ((v & 0x0F) == 0x07) { m->pb_ictl = v; if (v & 0x10) m->pb_next = 2; }
        else if ((v & 0x0F) == 0x03) { m->pb_ictl = (m->pb_ictl & 0x7F) | (v & 0x80); }
    } else if (p >= 0x40 && p <= 0x48) fdc_out(m, p, v);
}

/* mouse interrupts are enabled: PIO B mode 3, interrupts on, DTR (bit 2) not masked, active high */
static int mouse_armed(M *m) {
    return m->pb_mode == 3 && (m->pb_ictl & 0x80) && !(m->pb_mask & 4) && (m->pb_ictl & 0x20) && (m->pb_dir & 4);
}
static void mouse_update(M *m) {
    if (!m->m_active) {
        if (m->mq_head == m->mq_tail || !mouse_armed(m)) { m->m_dtr = 0; m->m_cts = 0; return; }
        memcpy(m->mpk, m->mq[m->mq_tail], 3);
        m->mq_tail = (m->mq_tail + 1) & 255;
        m->m_active = 1; m->m_byte = 0; m->m_bit = 0; m->m_next = m->tick;
        m->mouse_packets++;
    }
    if (m->tick < m->m_next) return;
    m->m_next = m->tick + 2812;
    if (m->m_bit == 0) {
        if (m->m_byte == 3) { m->m_active = 0; m->m_dtr = 0; m->m_cts = 0; return; }
        m->m_mask = 1; m->m_bit = 1; m->m_cts = 8; m->m_dtr = 4;
    } else if (m->m_bit == 8) {
        m->m_bit = 0; m->m_byte++; m->m_cts = 0; m->m_dtr = 4;
    } else {
        m->m_cts = (m->mpk[m->m_byte] & m->m_mask) ? 0 : 8;
        m->m_dtr = 4; m->m_bit++; m->m_mask <<= 1;
    }
    if (mouse_armed(m)) {
        if (m->irq_pending) m->mouse_overruns++;
        m->irq_pending = 1;
    }
}

/* ---------------- API */
M *mb_new(void) {
    M *m = calloc(1, sizeof(M));
    m->z.ctx = m; m->z.rd = mrd; m->z.wr = mwr; m->z.in = pin; m->z.out = pout;
    z80_reset(&m->z);
    memset(m->rom, 0xFF, sizeof m->rom);
    m->autoscan = 1; m->joy = 0xFF;
    m->lower = block_of(0);
    { static const uint8_t t[16] = {0x6B,0x40,0x51,0x37,0x12,0x09,0x10,0x12,0x48,0x0F,0x20,0x0F,0,0,0,0}; memcpy(m->crtc, t, 16); }
    m->venable = 1;
    return m;
}
void mb_free(M *m) { free(m->cw); free(m->spk_t); free(m->spk_v); free(m->ev_t); free(m->ev_pc); free(m->disk); free(m); }
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
uint8_t *mb_fb(M *m) { return &m->fb[m->fbw ^ 1][0][0]; }
uint8_t *mb_fb_cur(M *m) { return &m->fb[m->fbw][0][0]; }
uint64_t mb_frame_no(M *m) { return m->frame_no; }
uint32_t mb_vwait(M *m) { return m->vwait_total; }
void mb_vwait_mode(int mode, int t) { g_vwait_mode = mode; g_vwait_t = t; }
void mb_b5_lag(int n) { g_b5_lag = n; }
int mb_frame_lines(M *m, uint16_t **p) { *p = m->fl_lines; return m->fl_n; }
void mb_clear_frame_lines(M *m) { m->fl_n = 0; }
void mb_cw_on(M *m, int on) { m->cw_on = on; if (!on) m->cw_n = 0; }
int mb_cw(M *m, uint32_t **p) { *p = m->cw; return m->cw_n; }
void mb_cw_clear(M *m) { m->cw_n = 0; }
int mb_beam(M *m, int *out) { out[0] = m->pl; out[1] = m->hc; out[2] = m->row; out[3] = m->ra; out[4] = m->venable; return 0; }

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
        m->tick += t + m->vwait;
        m->vwait = 0;
        crtc_sync(m, m->tick);
        if (m->m_active || m->mq_head != m->mq_tail) mouse_update(m);
        if (m->irq_pending) {
            int ti = z80_irq(z, m->pb_vec);
            if (ti) { m->irq_pending = 0; m->m_dtr = 0; m->mouse_irqs++; m->tick += ti; crtc_sync(m, m->tick); }
        }
        if (m->profiling) m->prof[pc] += t;
        if (m->bp[z->pc]) return 1;
        if (m->ww_hit == 1) { m->ww_hit = 2; return 2; }
    }
    return 0;
}

void mb_set_ww(M *m, int blk, int lo, int hi) { m->ww_blk = blk; m->ww_lo = lo; m->ww_hi = hi; m->ww_hit = 0; }
int mb_ww(M *m, int *a) { *a = m->ww_a; return m->ww_hit ? m->ww_pc : -1; }

/* queue a Microsoft mouse packet: dx, dy (-128..127), buttons b0 left b1 right */
void mb_mouse(M *m, int dx, int dy, int btn) {
    int8_t x = (int8_t)dx, y = (int8_t)dy;
    uint8_t *p = m->mq[m->mq_head];
    p[0] = 0x40 | ((btn & 1) << 5) | ((btn & 2) << 3) | ((y & 0xC0) >> 4) | ((x & 0xC0) >> 6);
    p[1] = x & 0x3F; p[2] = y & 0x3F;
    m->mq_head = (m->mq_head + 1) & 255;
}
int mb_mouse_busy(M *m) { return m->m_active || m->mq_head != m->mq_tail; }
uint32_t mb_mouse_stat(M *m, int k) { return k == 0 ? m->mouse_irqs : k == 1 ? m->mouse_overruns : m->mouse_packets; }
