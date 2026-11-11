/*
 * beemu.c - cycle-counting Z80 + Microbee Premium (Plus) video model
 *           for benchmarking and screenshotting the racing-engine experiments.
 *
 * ViBED by BPM 2026 project tooling.
 *
 * What is modelled (from MAME's mbee driver behaviour + 6545 datasheet):
 *  - Z80 at 3.375 MHz, documented instruction set with standard T-states.
 *  - 64K flat RAM (CP/M view), video always mapped at F000-FFFF:
 *      F000-F7FF  screen RAM, or attribute RAM when port 1C bit4=1 (bit7=1 to write)
 *      F800-FFFF  PCG bank (port 1C bits 0-3), or colour RAM when port 08 bit6=1
 *  - Premium extended graphics (port 1C bit7): attribute low nibble adds bank*128
 *    to character codes >= 0x80; attribute bit6 inverts.
 *  - Premium colour byte: low nibble foreground, high nibble background.
 *  - SY6545 registers incl. display start (R12/R13), MA wraps at 2K,
 *    PCG fetch = char*16 + raster line.
 *  - Status register (port 0C): bit5 = vertical blanking, bit7 = update strobe,
 *    bit6 = light-pen (keyboard) hit.  Keyboard via R18/R19 + R31 strobe.
 *  - Speaker on port 02 bit6 (logged for WAV output).
 *  - Beam timing from CRTC registers: T/line = (R0+1)*2, lines/frame from R4/R5/R9.
 *
 * NOT modelled: real Premium bus contention (if any), interrupts, disk, ColdFire.
 * Frames are rendered at the start of vertical blank (no mid-frame raster effects).
 *
 * usage: beemu prog.com [options]
 *   -sym file      symbol file from zasm (labels starting P_ become profile markers)
 *   -frames N      run N video frames (default 100)
 *   -dump dir      write frame PPMs into dir
 *   -every k       dump every k-th frame (default 1)
 *   -first f       first frame to dump
 *   -keys file     lines: "startframe endframe keycode" (key held for that range)
 *   -prof file     write profile marker hits (frame,T,name)
 *   -wav file      write speaker output as 22050 Hz WAV
 *   -mono          render as amber monochrome (fg amber, bg black)
 *   -peek a,n      dump n bytes of memory from address a at exit
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef uint8_t u8; typedef uint16_t u16; typedef uint32_t u32; typedef uint64_t u64;

/* ------------------------------------------------------------------ machine */
static u8 ram[65536];
static u8 vram[2048], aram[2048], cram[2048];
static u8 pram[0x8800];          /* 2K font + 32K PCG */
static u8 port08, port1c, crtc_idx, crtc[32];
static u8 crtc_status_bits;      /* bit7 update, bit6 lpen */
static u8 keys[64];
static int mono = 0;
static u64 T = 0;
static u64 frame_start_T = 0;
static int frame_no = 0;
static int stopped = 0;
static long true_vb = 0;
static int vwait = 0;   /* extra T per screen/colour/PCG access (real-hardware wait states) */
static u64 wait_extra = 0;

/* speaker log */
static u64 *spk_t = NULL; static u8 *spk_v = NULL; static size_t spk_n = 0, spk_cap = 0;
static u8 spk_level = 0;

static int tline(void) { return (crtc[0] + 1) * 2; }   /* 13.5MHz/8 char clock vs 3.375MHz CPU */
static int lines_per_frame(void) { return (crtc[4] + 1) * (crtc[9] + 1) + crtc[5]; }
static int disp_lines(void) { return crtc[6] * (crtc[9] + 1); }

static u8 lowblk[32][0x8000];
static int curblk = 2;        /* CP/M's lower block */
static int vidpos = 0;        /* 0 = F000, 1 = off, 2 = 8000 */
static inline int vid_at(u16 a, u16 *o)
{
    if (vidpos == 0 && a >= 0xF000) { *o = a - 0xF000; return 1; }
    if (vidpos == 2 && a >= 0x8000 && a < 0x9000) { *o = a - 0x8000; return 1; }
    return 0;
}
static inline u8 mem_rd(u16 a)
{
    u16 vo;
    if (a < 0x8000) return lowblk[curblk][a];
    if (!vid_at(a, &vo)) return ram[a];
    a = 0xF000 + vo;
    if (!(a < 0xF800 && (port1c & 0x10))) wait_extra += vwait;
    if (a >= 0xF800) {
        u16 o = a - 0xF800;
        if (port08 & 0x40) return cram[o];
        return pram[(((port1c & 15) + 1) << 11) | o];
    }
    if (a >= 0xF000) {
        u16 o = a - 0xF000;
        if ((port1c & 0x9f) == 0x90) return aram[o];
        return vram[o];
    }
    return ram[a];
}
static inline void mem_wr(u16 a, u8 v)
{
    u16 vo;
    if (a < 0x8000) { lowblk[curblk][a] = v; return; }
    if (!vid_at(a, &vo)) { ram[a] = v; return; }
    a = 0xF000 + vo;
    if (!(a < 0xF800 && (port1c & 0x10))) wait_extra += vwait;
    if (a >= 0xF800) {
        u16 o = a - 0xF800;
        if (port08 & 0x40) cram[o] = v;
        else pram[(((port1c & 15) + 1) << 11) | o] = v;
        return;
    }
    if (a >= 0xF000) {
        u16 o = a - 0xF000;
        if (port1c & 0x10) { if (port1c & 0x80) aram[o] = v; }
        else vram[o] = v;
        return;
    }
    ram[a] = v;
}

static int cur_line(void)
{
    return (int)((T - frame_start_T) / tline());
}

static u8 io_rd(u8 port)
{
    switch (port) {
    case 0x0C: {
        u8 s = crtc_status_bits;
        if (cur_line() >= disp_lines()) s |= 0x20;
        return s;
    }
    case 0x0D:
        if (crtc_idx == 16 || crtc_idx == 17) { crtc_status_bits &= ~0x40; return crtc[crtc_idx]; }
        if (crtc_idx == 14 || crtc_idx == 15) return crtc[crtc_idx];
        if (crtc_idx == 31) goto strobe;
        return 0;
    case 0x02:
        return 0xFF & ~0x80;    /* PIO B: nothing interesting */
    case 0x00:
        return 0xFF;            /* PIO A: no joystick buttons pressed */
    case 0x1C:
        return port1c;
    }
    return 0xFF;
strobe:
    {
        u16 addr = (crtc[18] << 8) | crtc[19];
        crtc_status_bits |= 0x80;
        if (keys[(addr >> 4) & 63]) crtc_status_bits |= 0x40;
        return 0;
    }
}

static void spk_log(u8 v)
{
    if (v == spk_level) return;
    spk_level = v;
    if (spk_n == spk_cap) {
        spk_cap = spk_cap ? spk_cap * 2 : 65536;
        spk_t = realloc(spk_t, spk_cap * sizeof(u64));
        spk_v = realloc(spk_v, spk_cap);
    }
    spk_t[spk_n] = T; spk_v[spk_n] = v; spk_n++;
}

static void io_wr(u8 port, u8 v)
{
    switch (port) {
    case 0x02: spk_log((v >> 6) & 1); break;
    case 0x50:
        curblk = (((v >> 5) & 7) << 2) | ((v & 3) ^ 2);
        vidpos = (v & 8) ? 1 : ((v & 16) ? 2 : 0);
        break;
    case 0x08: port08 = v & 0x4e; break;
    case 0x1C: port1c = v; break;
    case 0x0C: crtc_idx = v & 0x1f; break;
    case 0x0D:
        crtc[crtc_idx] = v;
        if (crtc_idx == 31) {
            u16 addr = (crtc[18] << 8) | crtc[19];
            crtc_status_bits |= 0x80;
            if (keys[(addr >> 4) & 63]) crtc_status_bits |= 0x40;
        }
        break;
    }
}

/* ------------------------------------------------------------------ Z80 */
enum { FC=1, FN=2, FP=4, FX=8, FH=16, FY=32, FZ=64, FS=128 };
static u8 A, F, B, C, D, E, H, L, A_, F_, B_, C_, D_, E_, H_, L_, I, Rr, IFF1, IFF2, IM;
static u16 IX, IY, SP, PC;
static u8 szp[256], sz[256];

static void init_tables(void)
{
    for (int i = 0; i < 256; i++) {
        int p = 0; for (int b = 0; b < 8; b++) p ^= (i >> b) & 1;
        sz[i] = (i & 0x80) | (i == 0 ? FZ : 0) | (i & (FX | FY));
        szp[i] = sz[i] | (p ? 0 : FP);
    }
}

static const u8 cyc[256] = {
 4,10, 7, 6, 4, 4, 7, 4, 4,11, 7, 6, 4, 4, 7, 4,
 8,10, 7, 6, 4, 4, 7, 4,12,11, 7, 6, 4, 4, 7, 4,
 7,10,16, 6, 4, 4, 7, 4, 7,11,16, 6, 4, 4, 7, 4,
 7,10,13, 6,11,11,10, 4, 7,11,13, 6, 4, 4, 7, 4,
 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
 7, 7, 7, 7, 7, 7, 4, 7, 4, 4, 4, 4, 4, 4, 7, 4,
 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
 4, 4, 4, 4, 4, 4, 7, 4, 4, 4, 4, 4, 4, 4, 7, 4,
 5,10,10,10,10,11, 7,11, 5,10,10, 0,10,17, 7,11,
 5,10,10,11,10,11, 7,11, 5, 4,10,11,10, 0, 7,11,
 5,10,10,19,10,11, 7,11, 5, 4,10, 4,10, 0, 7,11,
 5,10,10, 4,10,11, 7,11, 5, 6,10, 4,10, 0, 7,11 };

static inline u8 fetch(void) { return mem_rd(PC++); }
static inline u16 fetch16(void) { u8 l = fetch(); return l | (fetch() << 8); }
static inline u16 rd16(u16 a) { return mem_rd(a) | (mem_rd(a + 1) << 8); }
static inline void wr16(u16 a, u16 v) { mem_wr(a, v & 255); mem_wr(a + 1, v >> 8); }
static inline void push(u16 v) { SP -= 2; wr16(SP, v); }
static inline u16 pop(void) { u16 v = rd16(SP); SP += 2; return v; }

#define BC ((B << 8) | C)
#define DE ((D << 8) | E)
#define HL ((H << 8) | L)

/* index mode for current instruction: 0=HL, 1=IX, 2=IY */
static int xm;
static u16 xaddr;     /* computed (IX+d) */

static inline u16 getHLx(void) { return xm == 0 ? HL : xm == 1 ? IX : IY; }
static inline void setHLx(u16 v) { if (xm == 0) { H = v >> 8; L = v; } else if (xm == 1) IX = v; else IY = v; }

static inline u16 getrp(int p) {
    switch (p) { case 0: return BC; case 1: return DE; case 2: return getHLx(); default: return SP; }
}
static inline void setrp(int p, u16 v) {
    switch (p) { case 0: B = v >> 8; C = v; break; case 1: D = v >> 8; E = v; break;
                 case 2: setHLx(v); break; default: SP = v; }
}
static inline u16 getrp2(int p) { return p == 3 ? (A << 8) | F : getrp(p); }
static inline void setrp2(int p, u16 v) { if (p == 3) { A = v >> 8; F = v; } else setrp(p, v); }

/* register by index; idx 6 = memory. 'useidx' allows H/L -> IXH/IXL */
static inline u8 getr(int r, int useidx)
{
    switch (r) {
    case 0: return B; case 1: return C; case 2: return D; case 3: return E;
    case 4: return (useidx && xm) ? (xm == 1 ? IX >> 8 : IY >> 8) : H;
    case 5: return (useidx && xm) ? (xm == 1 ? IX & 255 : IY & 255) : L;
    case 6: return mem_rd(xm ? xaddr : HL);
    default: return A;
    }
}
static inline void setr(int r, u8 v, int useidx)
{
    switch (r) {
    case 0: B = v; break; case 1: C = v; break; case 2: D = v; break; case 3: E = v; break;
    case 4: if (useidx && xm) { if (xm == 1) IX = (IX & 255) | (v << 8); else IY = (IY & 255) | (v << 8); } else H = v; break;
    case 5: if (useidx && xm) { if (xm == 1) IX = (IX & 0xff00) | v; else IY = (IY & 0xff00) | v; } else L = v; break;
    case 6: mem_wr(xm ? xaddr : HL, v); break;
    default: A = v;
    }
}

static inline int cond(int y)
{
    switch (y) {
    case 0: return !(F & FZ); case 1: return F & FZ; case 2: return !(F & FC); case 3: return F & FC;
    case 4: return !(F & FP); case 5: return F & FP; case 6: return !(F & FS); default: return F & FS;
    }
}

static inline void alu(int op, u8 v)
{
    int r;
    switch (op) {
    case 0: case 1: { int c = (op == 1) ? (F & FC) : 0; r = A + v + c;
        F = sz[r & 255] | ((r >> 8) & 1) | ((A ^ v ^ r) & FH) | ((((A ^ ~v) & (A ^ r)) & 0x80) >> 5);
        A = r; break; }
    case 2: case 3: { int c = (op == 3) ? (F & FC) : 0; r = A - v - c;
        F = sz[r & 255] | FN | ((r >> 8) & 1) | ((A ^ v ^ r) & FH) | ((((A ^ v) & (A ^ r)) & 0x80) >> 5);
        A = r; break; }
    case 4: A &= v; F = szp[A] | FH; break;
    case 5: A ^= v; F = szp[A]; break;
    case 6: A |= v; F = szp[A]; break;
    case 7: r = A - v;
        F = (sz[r & 255] & ~(FX | FY)) | (v & (FX | FY)) | FN | ((r >> 8) & 1) | ((A ^ v ^ r) & FH) |
            ((((A ^ v) & (A ^ r)) & 0x80) >> 5);
        break;
    }
}

static inline u8 inc8(u8 v) { u8 r = v + 1; F = (F & FC) | sz[r] | (r == 0x80 ? FP : 0) | ((r & 15) == 0 ? FH : 0); return r; }
static inline u8 dec8(u8 v) { u8 r = v - 1; F = (F & FC) | FN | sz[r] | (r == 0x7f ? FP : 0) | ((r & 15) == 15 ? FH : 0); return r; }

static inline u8 rot(int y, u8 v)
{
    u8 r, c;
    switch (y) {
    case 0: c = v >> 7; r = (v << 1) | c; break;
    case 1: c = v & 1; r = (v >> 1) | (c << 7); break;
    case 2: c = v >> 7; r = (v << 1) | (F & FC); break;
    case 3: c = v & 1; r = (v >> 1) | ((F & FC) << 7); break;
    case 4: c = v >> 7; r = v << 1; break;
    case 5: c = v & 1; r = (v >> 1) | (v & 0x80); break;
    case 6: c = v >> 7; r = (v << 1) | 1; break;
    default: c = v & 1; r = v >> 1; break;
    }
    F = szp[r] | c;
    return r;
}

static inline void add16(u16 v)
{
    u16 a = getHLx(); u32 r = a + v;
    F = (F & (FS | FZ | FP)) | ((r >> 16) & 1) | (((a ^ v ^ r) >> 8) & FH) | ((r >> 8) & (FX | FY));
    setHLx(r);
}
static inline void adc16(u16 v)
{
    u16 a = HL; u32 r = a + v + (F & FC);
    F = ((r >> 8) & (FS | FX | FY)) | ((r & 0xffff) ? 0 : FZ) | ((r >> 16) & 1) |
        (((a ^ v ^ r) >> 8) & FH) | ((((a ^ ~v) & (a ^ r)) & 0x8000) >> 13);
    H = r >> 8; L = r;
}
static inline void sbc16(u16 v)
{
    u16 a = HL; u32 r = a - v - (F & FC);
    F = ((r >> 8) & (FS | FX | FY)) | ((r & 0xffff) ? 0 : FZ) | ((r >> 16) & 1) | FN |
        (((a ^ v ^ r) >> 8) & FH) | ((((a ^ v) & (a ^ r)) & 0x8000) >> 13);
    H = r >> 8; L = r;
}

static void daa(void)
{
    u8 a = A, c = 0, d = 0;
    if ((F & FH) || (A & 15) > 9) d = 6;
    if ((F & FC) || A > 0x99) { d |= 0x60; c = 1; }
    if (F & FN) a -= d; else a += d;
    F = (F & FN) | szp[a] | c | ((A ^ a) & FH);
    A = a;
}

static int exec_cb(void)
{
    u8 op = fetch();
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    if (x == 0) { setr(z, rot(y, getr(z, 0)), 0); return z == 6 ? 15 : 8; }
    if (x == 1) {
        u8 v = getr(z, 0);
        u8 r = v & (1 << y);
        F = (F & FC) | FH | (r ? (r & FS) : (FZ | FP)) | (v & (FX | FY));
        return z == 6 ? 12 : 8;
    }
    u8 v = getr(z, 0);
    if (x == 2) v &= ~(1 << y); else v |= (1 << y);
    setr(z, v, 0);
    return z == 6 ? 15 : 8;
}

static int exec_xcb(void)   /* DD CB d op / FD CB d op */
{
    int8_t d = (int8_t)fetch();
    u8 op = fetch();
    xaddr = getHLx() + d;
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    u8 v = mem_rd(xaddr);
    if (x == 1) {
        u8 r = v & (1 << y);
        F = (F & FC) | FH | (r ? (r & FS) : (FZ | FP)) | ((xaddr >> 8) & (FX | FY));
        return 20;
    }
    if (x == 0) v = rot(y, v);
    else if (x == 2) v &= ~(1 << y);
    else v |= (1 << y);
    mem_wr(xaddr, v);
    if (z != 6) { int sx = xm; xm = 0; setr(z, v, 0); xm = sx; }
    return 23;
}

static int exec_ed(void)
{
    u8 op = fetch();
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    if (x == 1) {
        switch (z) {
        case 0: { u8 v = io_rd(C); if (y != 6) setr(y, v, 0); F = (F & FC) | szp[v]; return 12; }
        case 1: io_wr(C, y == 6 ? 0 : getr(y, 0)); return 12;
        case 2: { int sx = xm; xm = 0; u16 v = getrp(p); if (q == 0) sbc16(v); else adc16(v); xm = sx; return 15; }
        case 3: { u16 a = fetch16(); int sx = xm; xm = 0;
            if (q == 0) wr16(a, getrp(p)); else setrp(p, rd16(a)); xm = sx; return 20; }
        case 4: { u8 v = A; A = 0; alu(2, v); return 8; }
        case 5: PC = pop(); IFF1 = IFF2; return 14;
        case 6: IM = (y & 3) == 0 ? 0 : (y & 3) == 2 ? 1 : 2; return 8;
        case 7:
            switch (y) {
            case 0: I = A; return 9;
            case 1: Rr = A; return 9;
            case 2: A = I; F = (F & FC) | sz[A] | (IFF2 ? FP : 0); return 9;
            case 3: A = Rr; F = (F & FC) | sz[A] | (IFF2 ? FP : 0); return 9;
            case 4: { u8 m = mem_rd(HL); mem_wr(HL, (A << 4) | (m >> 4)); A = (A & 0xf0) | (m & 15); F = (F & FC) | szp[A]; return 18; }
            case 5: { u8 m = mem_rd(HL); mem_wr(HL, (m << 4) | (A & 15)); A = (A & 0xf0) | (m >> 4); F = (F & FC) | szp[A]; return 18; }
            default: return 8;
            }
        }
    }
    if (x == 2 && z <= 3 && y >= 4) {
        int dir = (y & 1) ? -1 : 1, rep = y >= 6;
        u16 hl = HL, de = DE, bc = BC;
        switch (z) {
        case 0: { u8 v = mem_rd(hl); mem_wr(de, v); hl += dir; de += dir; bc--;
            u8 n = v + A;
            F = (F & (FS | FZ | FC)) | (bc ? FP : 0) | (n & FX) | ((n << 4) & FY);
            H = hl >> 8; L = hl; D = de >> 8; E = de; B = bc >> 8; C = bc;
            if (rep && bc) { PC -= 2; return 21; } return 16; }
        case 1: { u8 v = mem_rd(hl); u8 r = A - v; hl += dir; bc--;
            F = (F & FC) | FN | (sz[r] & ~(FX | FY)) | ((A ^ v ^ r) & FH) | (bc ? FP : 0);
            H = hl >> 8; L = hl; B = bc >> 8; C = bc;
            if (rep && bc && r) { PC -= 2; return 21; } return 16; }
        case 2: { u8 v = io_rd(C); mem_wr(hl, v); hl += dir; B--; F = (B ? 0 : FZ) | FN;
            H = hl >> 8; L = hl; if (rep && B) { PC -= 2; return 21; } return 16; }
        case 3: { u8 v = mem_rd(hl); B--; io_wr(C, v); hl += dir; F = (B ? 0 : FZ) | FN;
            H = hl >> 8; L = hl; if (rep && B) { PC -= 2; return 21; } return 16; }
        }
    }
    return 8;  /* NOP-like */
}

static int step(void)
{
    u8 op;
    int extra = 0;
    xm = 0;
    Rr = (Rr & 0x80) | ((Rr + 1) & 0x7f);
    op = fetch();
    while (op == 0xDD || op == 0xFD) {
        xm = (op == 0xDD) ? 1 : 2;
        extra += 4;
        Rr = (Rr & 0x80) | ((Rr + 1) & 0x7f);
        op = fetch();
    }
    if (op == 0xED) { xm = 0; return extra + exec_ed(); }
    if (op == 0xCB) {
        if (xm) return extra - 4 + exec_xcb();
        return exec_cb();
    }
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    int t = cyc[op];
    /* does this opcode use (HL)? then compute (IX+d) */
    int usesmem = (x == 1 && (y == 6 || z == 6) && op != 0x76) || (x == 2 && z == 6) ||
                  (x == 0 && (z == 4 || z == 5 || z == 6) && y == 6);
    if (xm) {
        if (usesmem) {
            int8_t d = (int8_t)fetch();
            xaddr = getHLx() + d;
            extra += (op == 0x36) ? 5 : 8;   /* 4 already added: total +9 / +12 */
        }
    }
    switch (x) {
    case 0:
        switch (z) {
        case 0:
            switch (y) {
            case 0: break;
            case 1: { u8 t1 = A; A = A_; A_ = t1; t1 = F; F = F_; F_ = t1; break; }
            case 2: { int8_t e = (int8_t)fetch(); if (--B) { PC += e; t += 5; } break; }
            case 3: { int8_t e = (int8_t)fetch(); PC += e; break; }
            default: { int8_t e = (int8_t)fetch(); if (cond(y - 4)) { PC += e; t += 5; } break; }
            }
            break;
        case 1:
            if (q == 0) setrp(p, fetch16()); else add16(getrp(p));
            break;
        case 2:
            if (q == 0) {
                switch (p) { case 0: mem_wr(BC, A); break; case 1: mem_wr(DE, A); break;
                             case 2: wr16(fetch16(), getHLx()); break; case 3: mem_wr(fetch16(), A); break; }
            } else {
                switch (p) { case 0: A = mem_rd(BC); break; case 1: A = mem_rd(DE); break;
                             case 2: setHLx(rd16(fetch16())); break; case 3: A = mem_rd(fetch16()); break; }
            }
            break;
        case 3: setrp(p, getrp(p) + (q ? -1 : 1)); break;
        case 4: setr(y, inc8(getr(y, 1)), 1); break;
        case 5: setr(y, dec8(getr(y, 1)), 1); break;
        case 6: { u8 n = fetch(); setr(y, n, 1); break; }
        case 7:
            switch (y) {
            case 0: { u8 c = A >> 7; A = (A << 1) | c; F = (F & (FS | FZ | FP)) | c | (A & (FX | FY)); break; }
            case 1: { u8 c = A & 1; A = (A >> 1) | (c << 7); F = (F & (FS | FZ | FP)) | c | (A & (FX | FY)); break; }
            case 2: { u8 c = A >> 7; A = (A << 1) | (F & FC); F = (F & (FS | FZ | FP)) | c | (A & (FX | FY)); break; }
            case 3: { u8 c = A & 1; A = (A >> 1) | ((F & FC) << 7); F = (F & (FS | FZ | FP)) | c | (A & (FX | FY)); break; }
            case 4: daa(); break;
            case 5: A = ~A; F = (F & (FS | FZ | FP | FC)) | FH | FN | (A & (FX | FY)); break;
            case 6: F = (F & (FS | FZ | FP)) | FC | (A & (FX | FY)); break;
            case 7: F = ((F & (FS | FZ | FP | FC)) | ((F & FC) ? FH : 0) | (A & (FX | FY))) ^ FC; break;
            }
            break;
        }
        break;
    case 1:
        if (op == 0x76) { PC--; stopped = 2; break; }   /* HALT: treat as stop */
        if (y == 6) setr(6, getr(z, 0), 0);
        else if (z == 6) setr(y, getr(6, 0), 0);
        else setr(y, getr(z, 1), 1);
        break;
    case 2:
        alu(y, getr(z, 1));
        break;
    case 3:
        switch (z) {
        case 0: if (cond(y)) { PC = pop(); t += 6; } break;
        case 1:
            if (q == 0) setrp2(p, pop());
            else switch (p) {
                case 0: PC = pop(); break;
                case 1: { u8 t1;
                    t1 = B; B = B_; B_ = t1; t1 = C; C = C_; C_ = t1;
                    t1 = D; D = D_; D_ = t1; t1 = E; E = E_; E_ = t1;
                    t1 = H; H = H_; H_ = t1; t1 = L; L = L_; L_ = t1; break; }
                case 2: PC = getHLx(); break;
                case 3: SP = getHLx(); break;
            }
            break;
        case 2: { u16 a = fetch16(); if (cond(y)) PC = a; break; }
        case 3:
            switch (y) {
            case 0: PC = fetch16(); break;
            case 2: { u8 n = fetch(); io_wr(n, A); break; }
            case 3: { u8 n = fetch(); A = io_rd(n); break; }
            case 4: { u16 v = rd16(SP); wr16(SP, getHLx()); setHLx(v); break; }
            case 5: { u8 t1 = D; D = H; H = t1; t1 = E; E = L; L = t1; break; }
            case 6: IFF1 = IFF2 = 0; break;
            case 7: IFF1 = IFF2 = 1; break;
            }
            break;
        case 4: { u16 a = fetch16(); if (cond(y)) { push(PC); PC = a; t += 7; } break; }
        case 5:
            if (q == 0) push(getrp2(p));
            else { u16 a = fetch16(); push(PC); PC = a; }
            break;
        case 6: alu(y, fetch()); break;
        case 7: push(PC); PC = y * 8; break;
        }
        break;
    }
    return t + extra;
}

/* ------------------------------------------------------------------ video render */
static u8 font_ok = 0;
static void make_font(void)
{
    /* placeholder ROM font: blank space, other glyphs a hollow box (we use PCG for all art) */
    for (int c = 0; c < 128; c++)
        for (int r = 0; r < 16; r++) {
            u8 v = 0;
            if (c != 0x20 && c != 0) {
                if (r == 2 || r == 12) v = 0x7e; else if (r > 2 && r < 12) v = 0x42;
            }
            pram[c * 16 + r] = v;
        }
    font_ok = 1;
}

static const u8 pal[16][3] = {
    {0,0,0},{0xc0,0,0},{0,0xc0,0},{0xc0,0xc0,0},{0,0,0xc0},{0xc0,0,0xc0},{0,0xc0,0xc0},{0xc0,0xc0,0xc0},
    {0x60,0x60,0x60},{0xff,0,0},{0,0xff,0},{0xff,0xff,0},{0,0,0xff},{0xff,0,0xff},{0,0xff,0xff},{0xff,0xff,0xff}};

static int render_frame(const char *path)
{
    int cols = crtc[1], rows = crtc[6], rh = crtc[9] + 1;
    int w = cols * 8, h = rows * rh;
    if (w <= 0 || h <= 0) return -1;
    FILE *f = fopen(path, "wb");
    if (!f) return -1;
    fprintf(f, "P6\n%d %d\n255\n", w, h);
    u16 start = ((crtc[12] & 0x3f) << 8) | crtc[13];
    u8 *line = malloc(w * 3);
    for (int row = 0; row < rows; row++) {
        for (int ra = 0; ra < rh; ra++) {
            for (int x = 0; x < cols; x++) {
                u16 mem = (start + row * cols + x) & 0x7ff;
                u16 chr = vram[mem];
                u8 inv = 0;
                if (port1c & 0x80) {
                    u8 attr = aram[mem];
                    if (chr & 0x80) chr += (attr & 15) << 7;
                    if (attr & 0x40) inv = 0xff;
                }
                u8 gfx = pram[((chr << 4) | ra) % sizeof(pram)] ^ inv;
                u8 col = cram[mem];
                const u8 *fg, *bg;
                static const u8 amber[3] = {0xf7, 0xaa, 0x00}, black[3] = {0, 0, 0};
                if (mono) { fg = amber; bg = black; }
                else { fg = pal[col & 15]; bg = pal[col >> 4]; }
                for (int b = 0; b < 8; b++) {
                    const u8 *c = (gfx & (0x80 >> b)) ? fg : bg;
                    memcpy(line + (x * 8 + b) * 3, c, 3);
                }
            }
            fwrite(line, 1, w * 3, f);
        }
    }
    free(line);
    fclose(f);
    return 0;
}

/* ------------------------------------------------------------------ symbols / profile */
typedef struct { u16 addr; char name[48]; } Sym;
static Sym *marks = NULL; static int nmarks = 0;
static u8 markmap[65536];   /* index+1 into marks */
static u64 hist[65536];      /* T-states spent per PC (instruction start) */
static int do_hist = 0;
static int dumpflips = 0;

static void load_syms(const char *fn)
{
    FILE *f = fopen(fn, "r"); if (!f) { perror(fn); exit(1); }
    char line[256];
    while (fgets(line, sizeof line, f)) {
        unsigned a; char name[200];
        if (sscanf(line, "%x %199s", &a, name) == 2 && strncmp(name, "P_", 2) == 0) {
            marks = realloc(marks, (nmarks + 1) * sizeof(Sym));
            marks[nmarks].addr = a; strncpy(marks[nmarks].name, name, 47); marks[nmarks].name[47] = 0;
            if (nmarks < 255) markmap[a] = nmarks + 1;
            nmarks++;
        }
    }
    fclose(f);
}

/* ------------------------------------------------------------------ main */
typedef struct { int f0, f1, key; } KeyEv;

static void write_wav(const char *fn, u64 totalT)
{
    const int rate = 22050;
    double secs = totalT / 3375000.0;
    int n = (int)(secs * rate);
    FILE *f = fopen(fn, "wb"); if (!f) return;
    int datasz = n * 2;
    u32 v32; uint16_t v16;
    fwrite("RIFF", 1, 4, f); v32 = 36 + datasz; fwrite(&v32, 4, 1, f);
    fwrite("WAVEfmt ", 1, 8, f); v32 = 16; fwrite(&v32, 4, 1, f);
    v16 = 1; fwrite(&v16, 2, 1, f); v16 = 1; fwrite(&v16, 2, 1, f);
    v32 = rate; fwrite(&v32, 4, 1, f); v32 = rate * 2; fwrite(&v32, 4, 1, f);
    v16 = 2; fwrite(&v16, 2, 1, f); v16 = 16; fwrite(&v16, 2, 1, f);
    fwrite("data", 1, 4, f); v32 = datasz; fwrite(&v32, 4, 1, f);
    size_t k = 0; u8 lvl = 0;
    double tper = 3375000.0 / rate;
    for (int i = 0; i < n; i++) {
        /* box-filter: fraction of the sample period the speaker was high */
        double t0 = i * tper, t1 = t0 + tper, hi = 0, t = t0;
        while (k < spk_n && spk_t[k] < t1) {
            if (spk_t[k] > t) { if (lvl) hi += spk_t[k] - t; t = spk_t[k]; }
            lvl = spk_v[k]; k++;
        }
        if (lvl) hi += t1 - t;
        int16_t s = (int16_t)((hi / tper - 0.5) * 2 * 12000);
        fwrite(&s, 2, 1, f);
    }
    fclose(f);
}

int main(int argc, char **argv)
{
    const char *prog = NULL, *symf = NULL, *dumpdir = NULL, *keyf = NULL, *proff = NULL, *wavf = NULL;
    int frames = 100, every = 1, first = 0;
    int peek_a = -1, peek_n = 0;
    const char *vdumpf = NULL;
    static unsigned pokes[16][2]; int npokes = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-sym")) symf = argv[++i];
        else if (!strcmp(argv[i], "-frames")) frames = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-dump")) dumpdir = argv[++i];
        else if (!strcmp(argv[i], "-every")) every = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-first")) first = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-keys")) keyf = argv[++i];
        else if (!strcmp(argv[i], "-prof")) proff = argv[++i];
        else if (!strcmp(argv[i], "-wav")) wavf = argv[++i];
        else if (!strcmp(argv[i], "-mono")) mono = 1;
        else if (!strcmp(argv[i], "-hist")) do_hist = 1;
        else if (!strcmp(argv[i], "-dumpflips")) dumpflips = 1;
        else if (!strcmp(argv[i], "-cpmvid")) vidpos = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-vwait")) vwait = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-poke")) { unsigned a, v; sscanf(argv[++i], "%i,%i", &a, &v); pokes[npokes][0] = a; pokes[npokes++][1] = v; }
        else if (!strcmp(argv[i], "-cpmblk")) curblk = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-vdump")) vdumpf = argv[++i];
        else if (!strcmp(argv[i], "-peek")) { sscanf(argv[++i], "%i,%i", &peek_a, &peek_n); }
        else prog = argv[i];
    }
    if (!prog) { fprintf(stderr, "usage: beemu prog.com [opts]\n"); return 1; }
    init_tables();
    make_font();
    /* power-on CRTC: standard Microbee 64x16 */
    static const u8 init_crtc[16] = {0x6b,0x40,0x51,0x37,0x12,0x09,0x10,0x12,0x48,0x0f,0x2f,0x0f,0,0,0,0};
    memcpy(crtc, init_crtc, 16);
    FILE *f = fopen(prog, "rb"); if (!f) { perror(prog); return 1; }
    for (int b = 0; b < 32; b++) memset(lowblk[b], 0xE5, 0x8000);
    size_t n = fread(ram + 0x100, 1, 0xEF00, f); fclose(f);
    memcpy(lowblk[curblk], ram, 0x8000);   /* program lives in CP/M's lower block */
    lowblk[curblk][0] = 0x76;  /* warm boot -> HALT (stop) */
    lowblk[curblk][5] = 0xC9;  /* BDOS -> RET */
    for (int k = 0; k < npokes; k++) { if (pokes[k][0] < 0x8000) lowblk[curblk][pokes[k][0]] = pokes[k][1]; else ram[pokes[k][0]] = pokes[k][1]; }
    PC = 0x100; SP = 0xEFF0; push(0x0000);
    if (symf) load_syms(symf);
    KeyEv *kev = NULL; int nkev = 0;
    if (keyf) {
        FILE *kf = fopen(keyf, "r"); if (!kf) { perror(keyf); return 1; }
        int a, b, c;
        while (fscanf(kf, "%i %i %i", &a, &b, &c) == 3) {
            kev = realloc(kev, (nkev + 1) * sizeof(KeyEv)); kev[nkev].f0 = a; kev[nkev].f1 = b; kev[nkev].key = c; nkev++;
        }
        fclose(kf);
    }
    FILE *pf = proff ? fopen(proff, "w") : NULL;
    fprintf(stderr, "loaded %zu bytes\n", n);
    u64 next_frame_T = frame_start_T + (u64)lines_per_frame() * tline();
    int in_vblank = 0;
    while (frame_no < frames && !stopped) {
        if (pf && markmap[PC]) fprintf(pf, "%d,%llu,%s\n", frame_no, (unsigned long long)T, marks[markmap[PC] - 1].name);
        { u16 pc0 = PC; int t = step(); t += (int)wait_extra; wait_extra = 0; T += t; if (do_hist) hist[pc0] += t; }
        int ln = cur_line();
        if (!in_vblank && ln >= disp_lines()) {
            in_vblank = 1;
            true_vb++;
            static int last_r12 = -1, nflip = 0;
            if (dumpflips) {
                if (crtc[12] != last_r12) {
                    last_r12 = crtc[12];
                    if (dumpdir && nflip >= first && ((nflip - first) % every) == 0) {
                        char path[512]; snprintf(path, sizeof path, "%s/f%05d.ppm", dumpdir, nflip);
                        render_frame(path);
                    }
                    nflip++;
                }
            } else if (dumpdir && frame_no >= first && ((frame_no - first) % every) == 0) {
                char path[512]; snprintf(path, sizeof path, "%s/f%05d.ppm", dumpdir, frame_no);
                render_frame(path);
            }
        }
        if (T >= next_frame_T) {
            frame_start_T = next_frame_T;
            next_frame_T = frame_start_T + (u64)lines_per_frame() * tline();
            frame_no++;
            in_vblank = 0;
            memset(keys, 0, sizeof keys);
            for (int k = 0; k < nkev; k++) if (frame_no >= kev[k].f0 && frame_no <= kev[k].f1) keys[kev[k].key & 63] = 1;
        }
    }
    if (pf) fclose(pf);
    if (do_hist) {
        FILE *hf = fopen("hist.bin", "wb");
        fwrite(hist, sizeof(u64), 65536, hf);
        fclose(hf);
    }
    if (wavf) write_wav(wavf, T);
    fprintf(stderr, "stopped=%d frames=%d T=%llu PC=%04X true_vblanks=%ld\n", stopped, frame_no, (unsigned long long)T, PC, true_vb);
    if (vdumpf) {
        FILE *vf = fopen(vdumpf, "wb");
        fwrite(vram, 1, 2048, vf); fwrite(aram, 1, 2048, vf); fwrite(cram, 1, 2048, vf);
        fwrite(pram, 1, sizeof pram, vf); fwrite(lowblk[curblk], 1, 0x8000, vf); fwrite(ram + 0x8000, 1, 0x8000, vf); fwrite(crtc, 1, 32, vf);
        fclose(vf);
    }
    if (peek_a >= 0) {
        for (int i = 0; i < peek_n; i++) printf("%02X%s", mem_rd(peek_a + i), (i % 16 == 15) ? "\n" : " ");
        printf("\n");
    }
    return 0;
}
