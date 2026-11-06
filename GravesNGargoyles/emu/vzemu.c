/* vzemu - headless Dick Smith VZ300 emulator for automated testing.
 * Z80 core + VZ300 (PAL) machine: BennVenn SRAM banks, keyboard, joystick,
 * 6847 mode 0/1 rendering with per-row VRAM snapshots, snow counting,
 * speaker capture to WAV.  Build: gcc -O2 -o vzemu vzemu.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>

/* ------------------------------------------------------------------ */
/* Machine constants                                                   */
#define CPU_HZ      3546894
#define LINE_T      228
#define LINES       312
#define FRAME_T     (LINE_T * LINES)   /* 71136 */
#define FS_LINES    56
#define DISP_FIRST  94
#define DISP_LAST   285

/* Flags */
#define FC 0x01
#define FN 0x02
#define FP 0x04
#define F3 0x08
#define FH 0x10
#define F5 0x20
#define FZ 0x40
#define FS 0x80

static uint8_t sz53[256], sz53p[256], partab[256];

/* ------------------------------------------------------------------ */
/* CPU state                                                           */
static uint8_t rA, rF, rB, rC, rD, rE, rH, rL;
static uint8_t aA, aF, aB, aC, aD, aE, aH, aL;   /* alternate set */
static uint16_t rIX, rIY, rSP, rPC, rWZ;
static uint8_t rI, rR;
static int iff1, iff2, imode, halted, ei_just;
static int xmode;              /* 0 = HL, 1 = IX, 2 = IY for current instruction */

#define BC ((uint16_t)((rB << 8) | rC))
#define DE ((uint16_t)((rD << 8) | rE))
#define HL ((uint16_t)((rH << 8) | rL))
#define SETBC(v) do { uint16_t _v = (v); rB = _v >> 8; rC = _v & 0xFF; } while (0)
#define SETDE(v) do { uint16_t _v = (v); rD = _v >> 8; rE = _v & 0xFF; } while (0)
#define SETHL(v) do { uint16_t _v = (v); rH = _v >> 8; rL = _v & 0xFF; } while (0)

/* ------------------------------------------------------------------ */
/* Machine state                                                       */
static uint8_t mem[65536];
static uint8_t sram[2][0x2800];
static uint8_t port37 = 1;
static uint8_t latch = 0;
static uint8_t kbrow[8];       /* active-low rows, bits 0-5 */
static uint8_t joy1 = 0xFF, joy2 = 0xFF, joyarm = 0xFF;

static long ft = 0;            /* T-state within current field */
static unsigned long long total_t = 0;   /* absolute T at start of current field */
static int cur_line = 0;       /* line at start of current instruction */
static int in_display = 0;
static long field = 1;         /* 1-based current field number */

static unsigned long long snow_total = 0;
static long snow_field = 0;

/* audio */
static unsigned long long *spk_t = NULL;
static uint8_t *spk_v = NULL;
static size_t spk_n = 0, spk_cap = 0;
static int spk_level = 0;
static unsigned long long instr_abs_t = 0;

/* video snapshots */
static uint8_t snap[64][32];
static uint8_t snapmode[64];
static uint8_t tsnap[16][32];
static int snap_k = 0;

static int test_mode = 0;      /* flat RAM for self tests */

static void spk_record(int v)
{
    if (v == spk_level) return;
    spk_level = v;
    if (spk_n == spk_cap) {
        spk_cap = spk_cap ? spk_cap * 2 : 65536;
        spk_t = realloc(spk_t, spk_cap * sizeof *spk_t);
        spk_v = realloc(spk_v, spk_cap);
        if (!spk_t || !spk_v) { fprintf(stderr, "out of memory\n"); exit(1); }
    }
    spk_t[spk_n] = instr_abs_t;
    spk_v[spk_n] = (uint8_t)v;
    spk_n++;
}

static uint8_t kbd_read(uint16_t a)
{
    uint8_t r = 0x3F;
    for (int i = 0; i < 8; i++)
        if (!(a & (1 << i))) r &= kbrow[i];
    r = (r & 0x3F) | 0x40;
    if (cur_line >= FS_LINES) r |= 0x80;
    return r;
}

static inline uint8_t rd(uint16_t a)
{
    if (test_mode) return mem[a];
    if (a < 0x4000) return 0xFF;
    if (a < 0x6800) {
        if (port37 & 1) return sram[(port37 >> 1) & 1][a - 0x4000];
        return 0xFF;
    }
    if (a < 0x7000) return kbd_read(a);
    if (a < 0x7800) {
        if (in_display) { snow_total++; snow_field++; }
        return mem[a];
    }
    return mem[a];
}

static int watch_lo=-1, watch_hi=-1, watch_n=0; uint16_t cur_pc_for_watch;
 static unsigned long long prof[65536]; static long prof_from=-1; static const char *prof_file; static uint16_t pcring[256]; static uint8_t pcri; static uint16_t bigring[8192], bigix[8192]; static int bigri; static uint16_t pcdump[256]; static int pcdumped;
static inline void wr(uint16_t a, uint8_t v)
{
    if (a >= watch_lo && a <= watch_hi && watch_n < 400000) { watch_n++; fprintf(stderr, "WATCH write %04X=%02X pc=%04X IX=%04X\n", a, v, cur_pc_for_watch, rIX); if (getenv("VZ_WTRAIL") && cur_pc_for_watch == strtol(getenv("VZ_WTRAIL"), 0, 16)) { fprintf(stderr, "TRAIL"); for (int q = 0; q < 8192; q++) fprintf(stderr, " %04X:%04X", bigring[(bigri + q) & 8191], bigix[(bigri + q) & 8191]); fprintf(stderr, "\n"); } }
    if (test_mode) { mem[a] = v; return; }
    if (a < 0x4000) return;
    if (a < 0x6800) {
        if (port37 & 1) sram[(port37 >> 1) & 1][a - 0x4000] = v;
        return;
    }
    if (a < 0x7000) {
        latch = v;
        spk_record(v & 1);
        return;
    }
    if (a < 0x7800) {
        if (in_display) { snow_total++; snow_field++; }
        mem[a] = v;
        return;
    }
    mem[a] = v;
}

static uint8_t peek(uint16_t a)
{
    if (test_mode) return mem[a];
    if (a < 0x4000) return 0xFF;
    if (a < 0x6800) return (port37 & 1) ? sram[(port37 >> 1) & 1][a - 0x4000] : 0xFF;
    if (a < 0x7000) return 0xFF;
    return mem[a];
}

static uint8_t io_in(uint16_t port)
{
    uint8_t p = port & 0xFF;
    if (test_mode) return (uint8_t)(p ^ 0x5A);
    if ((p & 0xF0) == 0x20) {
        uint8_t r = 0xFF;
        if (!(p & 1)) r &= joy1;
        if (!(p & 4)) r &= joy2;
        if (!(p & 2)) r &= joyarm;
        return r;
    }
    return 0xFF;
}

static uint8_t last_out_port, last_out_val;
static void io_out(uint16_t port, uint8_t v)
{
    last_out_port = port & 0xFF; last_out_val = v;
    if ((port & 0xFF) == 0x37 && !test_mode) port37 = v;
}

/* ------------------------------------------------------------------ */
/* Z80 helpers                                                         */
static void init_tables(void)
{
    for (int i = 0; i < 256; i++) {
        int p = 0;
        for (int b = 0; b < 8; b++) p ^= (i >> b) & 1;
        partab[i] = p ? 0 : FP;
        sz53[i] = (i & (FS | F3 | F5)) | (i == 0 ? FZ : 0);
        sz53p[i] = sz53[i] | partab[i];
    }
}

static inline void inc_r(void) { rR = (rR & 0x80) | ((rR + 1) & 0x7F); }
static inline uint8_t fetch_m1(void) { uint8_t op = rd(rPC++); inc_r(); return op; }
static inline uint8_t fetch8(void) { return rd(rPC++); }
static inline uint16_t fetch16(void) { uint16_t lo = rd(rPC++); return lo | (rd(rPC++) << 8); }
static inline uint16_t rd16(uint16_t a) { uint16_t lo = rd(a); return lo | (rd((uint16_t)(a + 1)) << 8); }
static inline void wr16(uint16_t a, uint16_t v) { wr(a, v & 0xFF); wr((uint16_t)(a + 1), v >> 8); }
static inline void push16(uint16_t v) { rSP--; wr(rSP, v >> 8); rSP--; wr(rSP, v & 0xFF); }
static inline uint16_t pop16(void) { uint16_t lo = rd(rSP++); return lo | (rd(rSP++) << 8); }

/* HL / IX / IY according to xmode */
static inline uint16_t getHX(void) { return xmode == 0 ? HL : xmode == 1 ? rIX : rIY; }
static inline void setHX(uint16_t v) { if (xmode == 0) SETHL(v); else if (xmode == 1) rIX = v; else rIY = v; }

/* 8-bit registers by index (6 not allowed); H/L remapped by xmode */
static uint8_t getr(int r)
{
    switch (r) {
    case 0: return rB; case 1: return rC; case 2: return rD; case 3: return rE;
    case 4: return xmode == 0 ? rH : xmode == 1 ? rIX >> 8 : rIY >> 8;
    case 5: return xmode == 0 ? rL : xmode == 1 ? rIX & 0xFF : rIY & 0xFF;
    default: return rA;
    }
}
static void setr(int r, uint8_t v)
{
    switch (r) {
    case 0: rB = v; break; case 1: rC = v; break; case 2: rD = v; break; case 3: rE = v; break;
    case 4: if (xmode == 0) rH = v; else if (xmode == 1) rIX = (rIX & 0xFF) | (v << 8); else rIY = (rIY & 0xFF) | (v << 8); break;
    case 5: if (xmode == 0) rL = v; else if (xmode == 1) rIX = (rIX & 0xFF00) | v; else rIY = (rIY & 0xFF00) | v; break;
    default: rA = v; break;
    }
}
/* plain (no IXH/IXL remap) */
static uint8_t getr0(int r)
{
    switch (r) {
    case 0: return rB; case 1: return rC; case 2: return rD; case 3: return rE;
    case 4: return rH; case 5: return rL; default: return rA;
    }
}
static void setr0(int r, uint8_t v)
{
    switch (r) {
    case 0: rB = v; break; case 1: rC = v; break; case 2: rD = v; break; case 3: rE = v; break;
    case 4: rH = v; break; case 5: rL = v; break; default: rA = v; break;
    }
}

/* rp table: BC DE HL(X) SP */
static uint16_t getrp(int p)
{
    switch (p) { case 0: return BC; case 1: return DE; case 2: return getHX(); default: return rSP; }
}
static void setrp(int p, uint16_t v)
{
    switch (p) { case 0: SETBC(v); break; case 1: SETDE(v); break; case 2: setHX(v); break; default: rSP = v; break; }
}
/* rp for ED (always HL) */
static uint16_t getrpE(int p)
{
    switch (p) { case 0: return BC; case 1: return DE; case 2: return HL; default: return rSP; }
}
static void setrpE(int p, uint16_t v)
{
    switch (p) { case 0: SETBC(v); break; case 1: SETDE(v); break; case 2: SETHL(v); break; default: rSP = v; break; }
}

/* (HL) or (IX+d) address; adds 8T for indexed */
static uint16_t memaddr(int *t)
{
    if (!xmode) return HL;
    int8_t d = (int8_t)fetch8();
    uint16_t a = (uint16_t)((xmode == 1 ? rIX : rIY) + d);
    rWZ = a;
    *t += 8;
    return a;
}

static inline int cond(int cc)
{
    switch (cc) {
    case 0: return !(rF & FZ); case 1: return rF & FZ;
    case 2: return !(rF & FC); case 3: return rF & FC;
    case 4: return !(rF & FP); case 5: return rF & FP;
    case 6: return !(rF & FS); default: return rF & FS;
    }
}

/* ALU */
static void add8(uint8_t v, int c)
{
    unsigned r = rA + v + c;
    rF = sz53[r & 0xFF] | ((r >> 8) & 1) | ((rA ^ v ^ r) & FH) | ((((rA ^ ~v) & (rA ^ r)) & 0x80) >> 5);
    rA = (uint8_t)r;
}
static uint8_t sub8(uint8_t v, int c)
{
    unsigned r = (unsigned)rA - v - c;
    rF = sz53[r & 0xFF] | ((r >> 8) & 1) | FN | ((rA ^ v ^ r) & FH) | ((((rA ^ v) & (rA ^ r)) & 0x80) >> 5);
    return (uint8_t)r;
}
static void alu(int y, uint8_t v)
{
    switch (y) {
    case 0: add8(v, 0); break;
    case 1: add8(v, rF & FC); break;
    case 2: rA = sub8(v, 0); break;
    case 3: rA = sub8(v, rF & FC); break;
    case 4: rA &= v; rF = sz53p[rA] | FH; break;
    case 5: rA ^= v; rF = sz53p[rA]; break;
    case 6: rA |= v; rF = sz53p[rA]; break;
    default: sub8(v, 0); rF = (rF & ~(F3 | F5)) | (v & (F3 | F5)); break;
    }
}
static uint8_t inc8(uint8_t v)
{
    uint8_t r = v + 1;
    rF = (rF & FC) | sz53[r] | (r == 0x80 ? FP : 0) | ((r & 0x0F) == 0 ? FH : 0);
    return r;
}
static uint8_t dec8(uint8_t v)
{
    uint8_t r = v - 1;
    rF = (rF & FC) | FN | sz53[r] | (r == 0x7F ? FP : 0) | ((r & 0x0F) == 0x0F ? FH : 0);
    return r;
}
static uint16_t add16(uint16_t a, uint16_t b)
{
    uint32_t r = (uint32_t)a + b;
    rF = (rF & (FS | FZ | FP)) | ((r >> 16) & 1) | (((a ^ b ^ r) >> 8) & FH) | ((r >> 8) & (F3 | F5));
    rWZ = a + 1;
    return (uint16_t)r;
}
static void adc16(uint16_t v)
{
    uint16_t h = HL;
    uint32_t r = (uint32_t)h + v + (rF & FC);
    rF = ((r >> 16) & 1) | (((h ^ v ^ r) >> 8) & FH) | ((r >> 8) & (FS | F3 | F5)) |
         ((r & 0xFFFF) ? 0 : FZ) | ((((h ^ ~v) & (h ^ r)) & 0x8000) >> 13);
    rWZ = h + 1;
    SETHL(r);
}
static void sbc16(uint16_t v)
{
    uint16_t h = HL;
    uint32_t r = (uint32_t)h - v - (rF & FC);
    rF = FN | ((r >> 16) & 1) | (((h ^ v ^ r) >> 8) & FH) | ((r >> 8) & (FS | F3 | F5)) |
         ((r & 0xFFFF) ? 0 : FZ) | ((((h ^ v) & (h ^ r)) & 0x8000) >> 13);
    rWZ = h + 1;
    SETHL(r);
}
static uint8_t rot(int y, uint8_t v)
{
    uint8_t r; int c;
    switch (y) {
    case 0: c = v >> 7; r = (v << 1) | c; break;
    case 1: c = v & 1; r = (v >> 1) | (c << 7); break;
    case 2: c = v >> 7; r = (v << 1) | (rF & FC); break;
    case 3: c = v & 1; r = (v >> 1) | ((rF & FC) << 7); break;
    case 4: c = v >> 7; r = v << 1; break;
    case 5: c = v & 1; r = (v >> 1) | (v & 0x80); break;
    case 6: c = v >> 7; r = (v << 1) | 1; break;
    default: c = v & 1; r = v >> 1; break;
    }
    rF = sz53p[r] | c;
    return r;
}
static void bitop(int b, uint8_t v, uint8_t xy)
{
    uint8_t r = v & (1 << b);
    rF = (rF & FC) | FH | (r ? 0 : (FZ | FP)) | (r & FS) | (xy & (F3 | F5));
}
static void daa(void)
{
    uint8_t add = 0, carry = rF & FC, a = rA, h;
    if ((rF & FH) || (a & 0x0F) > 9) add = 6;
    if (carry || a > 0x99) { add |= 0x60; carry = FC; }
    if (rF & FN) { h = ((rF & FH) && (a & 0x0F) < 6) ? FH : 0; rA = a - add; }
    else { h = ((a & 0x0F) > 9) ? FH : 0; rA = a + add; }
    rF = (rF & FN) | carry | h | sz53p[rA];
}

/* ------------------------------------------------------------------ */
/* Instruction execution                                               */
static int exec_cb(void)
{
    uint8_t op = fetch_m1();
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    if (z == 6) {
        uint16_t a = HL;
        uint8_t v = rd(a);
        if (x == 1) { bitop(y, v, rWZ >> 8); return 12; }
        if (x == 0) v = rot(y, v);
        else if (x == 2) v &= ~(1 << y);
        else v |= (1 << y);
        wr(a, v);
        return 15;
    }
    uint8_t v = getr0(z);
    if (x == 1) { bitop(y, v, v); return 8; }
    if (x == 0) v = rot(y, v);
    else if (x == 2) v &= ~(1 << y);
    else v |= (1 << y);
    setr0(z, v);
    return 8;
}

/* DDCB/FDCB: prefix (4T) already counted */
static int exec_xcb(void)
{
    int8_t d = (int8_t)fetch8();
    uint8_t op = fetch8();
    uint16_t a = (uint16_t)((xmode == 1 ? rIX : rIY) + d);
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    rWZ = a;
    uint8_t v = rd(a);
    if (x == 1) { bitop(y, v, a >> 8); return 16; }
    if (x == 0) v = rot(y, v);
    else if (x == 2) v &= ~(1 << y);
    else v |= (1 << y);
    wr(a, v);
    if (z != 6) setr0(z, v);
    return 19;
}

static int exec_ed(void)
{
    uint8_t op = fetch_m1();
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    if (x == 1) {
        switch (z) {
        case 0: {
            uint8_t v = io_in(BC);
            rWZ = BC + 1;
            rF = (rF & FC) | sz53p[v];
            if (y != 6) setr0(y, v);
            return 12;
        }
        case 1:
            io_out(BC, y == 6 ? 0 : getr0(y));
            rWZ = BC + 1;
            return 12;
        case 2:
            if (q == 0) sbc16(getrpE(p)); else adc16(getrpE(p));
            return 15;
        case 3: {
            uint16_t nn = fetch16();
            if (q == 0) wr16(nn, getrpE(p)); else setrpE(p, rd16(nn));
            rWZ = nn + 1;
            return 20;
        }
        case 4: {
            uint8_t v = rA; rA = 0; rA = sub8(v, 0);
            return 8;
        }
        case 5:
            iff1 = iff2;
            rPC = pop16(); rWZ = rPC;
            return 14;
        case 6: {
            static const int imt[8] = {0, 0, 1, 2, 0, 0, 1, 2};
            imode = imt[y];
            return 8;
        }
        default:
            switch (y) {
            case 0: rI = rA; return 9;
            case 1: rR = rA; return 9;
            case 2: rA = rI; rF = (rF & FC) | sz53[rA] | (iff2 ? FP : 0); return 9;
            case 3: rA = rR; rF = (rF & FC) | sz53[rA] | (iff2 ? FP : 0); return 9;
            case 4: {
                uint8_t v = rd(HL);
                wr(HL, (uint8_t)((rA << 4) | (v >> 4)));
                rA = (rA & 0xF0) | (v & 0x0F);
                rF = (rF & FC) | sz53p[rA];
                rWZ = HL + 1;
                return 18;
            }
            case 5: {
                uint8_t v = rd(HL);
                wr(HL, (uint8_t)((v << 4) | (rA & 0x0F)));
                rA = (rA & 0xF0) | (v >> 4);
                rF = (rF & FC) | sz53p[rA];
                rWZ = HL + 1;
                return 18;
            }
            default: return 8;
            }
        }
    }
    if (x == 2 && z <= 3 && y >= 4) {
        int dir = (y & 1) ? -1 : 1;
        int rep = y >= 6;
        switch (z) {
        case 0: { /* LDI/LDD */
            uint8_t v = rd(HL);
            wr(DE, v);
            SETHL(HL + dir); SETDE(DE + dir); SETBC(BC - 1);
            uint8_t n = v + rA;
            rF = (rF & (FS | FZ | FC)) | (BC ? FP : 0) | (n & F3) | ((n << 4) & F5);
            if (rep && BC) { rPC -= 2; rWZ = rPC + 1; return 21; }
            return 16;
        }
        case 1: { /* CPI/CPD */
            uint8_t v = rd(HL);
            uint8_t r = rA - v;
            uint8_t hf = (rA ^ v ^ r) & FH;
            SETHL(HL + dir); SETBC(BC - 1);
            uint8_t n = r - (hf ? 1 : 0);
            rF = (rF & FC) | FN | (sz53[r] & ~(F3 | F5)) | hf | (BC ? FP : 0) | (n & F3) | ((n << 4) & F5);
            rWZ += dir;
            if (rep && BC && r != 0) { rPC -= 2; rWZ = rPC + 1; return 21; }
            return 16;
        }
        case 2: { /* INI/IND */
            uint8_t v = io_in(BC);
            rWZ = BC + dir;
            wr(HL, v);
            rB--;
            SETHL(HL + dir);
            unsigned k = v + ((rC + dir) & 0xFF);
            rF = sz53[rB] | ((v & 0x80) ? FN : 0) | (k > 255 ? (FH | FC) : 0) | partab[(k & 7) ^ rB];
            if (rep && rB) { rPC -= 2; return 21; }
            return 16;
        }
        default: { /* OUTI/OUTD */
            uint8_t v = rd(HL);
            rB--;
            rWZ = BC + dir;
            io_out(BC, v);
            SETHL(HL + dir);
            unsigned k = v + rL;
            rF = sz53[rB] | ((v & 0x80) ? FN : 0) | (k > 255 ? (FH | FC) : 0) | partab[(k & 7) ^ rB];
            if (rep && rB) { rPC -= 2; return 21; }
            return 16;
        }
        }
    }
    return 8;  /* undefined ED: NOP */
}

/* fake BennVenn DOS (calls at $5F00/$5F03/$5F09, see 13 Ghosts loader) */
static const char *sd_dir; static FILE *sd_fp; static long sd_calls;
static int dos_trap(uint16_t pc)
{
    char name[64]; int n = 0;
    uint16_t buf;
    if (pc == 0x5F00) {
        uint16_t p = (rH << 8) | rL;
        if (rd(p) == '"') p++;
        while (n < 12 && rd(p) != '"' && rd(p) >= 32) name[n++] = rd(p++);
        name[n] = 0;
        if (sd_fp) { fclose(sd_fp); sd_fp = 0; }
        char path[512];
        snprintf(path, sizeof path, "%s/%s.DAT", sd_dir, name);
        sd_fp = fopen(path, "rb");
        mem[0xFB03] = sd_fp ? 1 : 0; mem[0xFB05] = 0;
        printf("DOS open \"%s\" -> %s (field %ld)\n", name, sd_fp ? "ok" : "NOT FOUND", field);
        if (sd_fp) fseek(sd_fp, 0, SEEK_SET);
    } else {
        buf = mem[0xFB80] | (mem[0xFB81] << 8);
        uint8_t sec[512]; memset(sec, 0, 512);
        if (sd_fp) fread(sec, 1, 512, sd_fp);
        for (int i = 0; i < 512; i++) wr((uint16_t)(buf + i), sec[i]);
    }
    sd_calls++;
    /* return */
    uint16_t lo = rd(rSP), hi = rd((uint16_t)(rSP + 1)); rSP += 2;
    rPC = lo | (hi << 8);
    return pc == 0x5F00 ? 20000 : 44000;   /* ~32 sectors per 20 fields */
}

static int step(void)
{
    int t = 0;
    uint8_t op;
    xmode = 0;
    for (;;) {
        op = fetch_m1();
        if (op == 0xDD) { xmode = 1; t += 4; continue; }
        if (op == 0xFD) { xmode = 2; t += 4; continue; }
        break;
    }
    if (op == 0xCB) {
        if (xmode) return t + exec_xcb();
        return t + exec_cb();
    }
    if (op == 0xED) { xmode = 0; return t + exec_ed(); }

    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    switch (x) {
    case 0:
        switch (z) {
        case 0:
            switch (y) {
            case 0: return t + 4;
            case 1: {
                uint8_t ta = rA, tf = rF; rA = aA; rF = aF; aA = ta; aF = tf;
                return t + 4;
            }
            case 2: {
                int8_t d = (int8_t)fetch8();
                rB--;
                if (rB) { rPC += d; rWZ = rPC; return t + 13; }
                return t + 8;
            }
            case 3: {
                int8_t d = (int8_t)fetch8();
                rPC += d; rWZ = rPC;
                return t + 12;
            }
            default: {
                int8_t d = (int8_t)fetch8();
                if (cond(y - 4)) { rPC += d; rWZ = rPC; return t + 12; }
                return t + 7;
            }
            }
        case 1:
            if (q == 0) { setrp(p, fetch16()); return t + 10; }
            setHX(add16(getHX(), getrp(p)));
            return t + 11;
        case 2:
            switch (y) {
            case 0: wr(BC, rA); rWZ = ((BC + 1) & 0xFF) | (rA << 8); return t + 7;
            case 1: rA = rd(BC); rWZ = BC + 1; return t + 7;
            case 2: wr(DE, rA); rWZ = ((DE + 1) & 0xFF) | (rA << 8); return t + 7;
            case 3: rA = rd(DE); rWZ = DE + 1; return t + 7;
            case 4: { uint16_t nn = fetch16(); wr16(nn, getHX()); rWZ = nn + 1; return t + 16; }
            case 5: { uint16_t nn = fetch16(); setHX(rd16(nn)); rWZ = nn + 1; return t + 16; }
            case 6: { uint16_t nn = fetch16(); wr(nn, rA); rWZ = ((nn + 1) & 0xFF) | (rA << 8); return t + 13; }
            default: { uint16_t nn = fetch16(); rA = rd(nn); rWZ = nn + 1; return t + 13; }
            }
        case 3:
            setrp(p, getrp(p) + (q ? -1 : 1));
            return t + 6;
        case 4:
        case 5:
            if (y == 6) {
                uint16_t a = memaddr(&t);
                uint8_t v = rd(a);
                wr(a, z == 4 ? inc8(v) : dec8(v));
                return t + 11;
            }
            setr(y, z == 4 ? inc8(getr(y)) : dec8(getr(y)));
            return t + 4;
        case 6:
            if (y == 6) {
                if (xmode) {
                    int8_t d = (int8_t)fetch8();
                    uint16_t a = (uint16_t)((xmode == 1 ? rIX : rIY) + d);
                    rWZ = a;
                    wr(a, fetch8());
                    return t + 15;
                }
                wr(HL, fetch8());
                return t + 10;
            }
            setr(y, fetch8());
            return t + 7;
        default:
            switch (y) {
            case 0: { int c = rA >> 7; rA = (rA << 1) | c; rF = (rF & (FS | FZ | FP)) | c | (rA & (F3 | F5)); break; }
            case 1: { int c = rA & 1; rA = (rA >> 1) | (c << 7); rF = (rF & (FS | FZ | FP)) | c | (rA & (F3 | F5)); break; }
            case 2: { int c = rA >> 7; rA = (rA << 1) | (rF & FC); rF = (rF & (FS | FZ | FP)) | c | (rA & (F3 | F5)); break; }
            case 3: { int c = rA & 1; rA = (rA >> 1) | ((rF & FC) << 7); rF = (rF & (FS | FZ | FP)) | c | (rA & (F3 | F5)); break; }
            case 4: daa(); break;
            case 5: rA = ~rA; rF = (rF & (FS | FZ | FP | FC)) | FH | FN | (rA & (F3 | F5)); break;
            case 6: rF = (rF & (FS | FZ | FP)) | FC | (rA & (F3 | F5)); break;
            default: rF = ((rF & (FS | FZ | FP | FC)) | ((rF & FC) << 4) | (rA & (F3 | F5))) ^ FC; break;
            }
            return t + 4;
        }
    case 1:
        if (op == 0x76) { halted = 1; return t + 4; }
        if (y == 6) { uint16_t a = memaddr(&t); wr(a, getr0(z)); return t + 7; }
        if (z == 6) { uint16_t a = memaddr(&t); setr0(y, rd(a)); return t + 7; }
        setr(y, getr(z));
        return t + 4;
    case 2:
        if (z == 6) { uint16_t a = memaddr(&t); alu(y, rd(a)); return t + 7; }
        alu(y, getr(z));
        return t + 4;
    default:
        switch (z) {
        case 0:
            if (cond(y)) { rPC = pop16(); rWZ = rPC; return t + 11; }
            return t + 5;
        case 1:
            if (q == 0) {
                uint16_t v = pop16();
                if (p == 3) { rA = v >> 8; rF = v & 0xFF; } else setrp(p, v);
                return t + 10;
            }
            switch (p) {
            case 0: rPC = pop16(); rWZ = rPC; return t + 10;
            case 1: {
                uint8_t tmp;
                tmp = rB; rB = aB; aB = tmp; tmp = rC; rC = aC; aC = tmp;
                tmp = rD; rD = aD; aD = tmp; tmp = rE; rE = aE; aE = tmp;
                tmp = rH; rH = aH; aH = tmp; tmp = rL; rL = aL; aL = tmp;
                return t + 4;
            }
            case 2: rPC = getHX(); return t + 4;
            default: rSP = getHX(); return t + 6;
            }
        case 2: {
            uint16_t nn = fetch16();
            rWZ = nn;
            if (cond(y)) rPC = nn;
            return t + 10;
        }
        case 3:
            switch (y) {
            case 0: rPC = fetch16(); rWZ = rPC; return t + 10;
            case 2: { uint8_t n = fetch8(); io_out((rA << 8) | n, rA); rWZ = ((n + 1) & 0xFF) | (rA << 8); return t + 11; }
            case 3: { uint8_t n = fetch8(); uint16_t port = (rA << 8) | n; rA = io_in(port); rWZ = port + 1; return t + 11; }
            case 4: {
                uint16_t v = rd16(rSP);
                wr16(rSP, getHX());
                setHX(v); rWZ = v;
                return t + 19;
            }
            case 5: { uint16_t v = DE; SETDE(HL); SETHL(v); return t + 4; }
            case 6: iff1 = iff2 = 0; return t + 4;
            case 7: iff1 = iff2 = 1; ei_just = 1; return t + 4;
            default: return t + 4; /* CB handled above */
            }
        case 4: {
            uint16_t nn = fetch16();
            rWZ = nn;
            if (cond(y)) { push16(rPC); rPC = nn; return t + 17; }
            return t + 10;
        }
        case 5:
            if (q == 0) {
                push16(p == 3 ? (uint16_t)((rA << 8) | rF) : getrp(p));
                return t + 11;
            }
            {   /* p==0 CALL nn (others are prefixes, handled above) */
                uint16_t nn = fetch16();
                rWZ = nn;
                push16(rPC); rPC = nn;
                return t + 17;
            }
        case 6:
            alu(y, fetch8());
            return t + 7;
        default:
            push16(rPC); rPC = y * 8; rWZ = rPC;
            return t + 11;
        }
    }
}

/* returns T-states */
static int accept_irq(void)
{
    halted = 0;
    iff1 = iff2 = 0;
    inc_r();
    push16(rPC);
    if (imode == 2) {
        uint16_t a = (uint16_t)((rI << 8) | 0xFF);
        rPC = rd16(a);
        rWZ = rPC;
        return 19;
    }
    rPC = 0x38; rWZ = rPC;
    return 13;
}

static void reset_cpu(void)
{
    rA = rF = rB = rC = rD = rE = rH = rL = 0;
    aA = aF = aB = aC = aD = aE = aH = aL = 0;
    rIX = rIY = 0; rSP = 0xF9F0; rPC = 0; rWZ = 0; rI = 0; rR = 0;
    iff1 = iff2 = 0; imode = 0; halted = 0; ei_just = 0;
}

static void print_regs(FILE *o)
{
    fprintf(o, "PC=%04X AF=%02X%02X BC=%02X%02X DE=%02X%02X HL=%02X%02X IX=%04X IY=%04X SP=%04X "
               "AF'=%02X%02X BC'=%02X%02X DE'=%02X%02X HL'=%02X%02X I=%02X R=%02X IFF1=%d IFF2=%d IM=%d%s",
            rPC, rA, rF, rB, rC, rD, rE, rH, rL, rIX, rIY, rSP,
            aA, aF, aB, aC, aD, aE, aH, aL, rI, rR, iff1, iff2, imode, halted ? " HALT" : "");
}

/* ------------------------------------------------------------------ */
/* Self tests (flat RAM).  Writes binary records for external checking. */
#pragma pack(push, 1)
typedef struct { uint8_t op; uint8_t fin; uint16_t x, y; uint16_t out; uint8_t fout; uint8_t pad; } TRec;
#pragma pack(pop)

static void run_one(const uint8_t *code, int n)
{
    memcpy(&mem[0x8000], code, n);
    rPC = 0x8000;
    step();
}

static int selftest_alu(const char *fn)
{
    FILE *o = fopen(fn, "wb");
    if (!o) { perror(fn); return 1; }
    test_mode = 1;
    reset_cpu();
    TRec rec;
    memset(&rec, 0, sizeof rec);
    /* op ids:
       0-7   ALU A,B (ADD ADC SUB SBC AND XOR OR CP), fin in {0x00,0xFF}... we use 0x00/0x01/0xFE/0xFF
       8 INC A, 9 DEC A
       10-17 CB rot on B (RLC RRC RL RR SLA SRA SLL SRL)
       18 RLCA 19 RRCA 20 RLA 21 RRA 22 DAA 23 CPL 24 SCF 25 CCF 26 NEG
       27-34 BIT 0..7,B
       40 ADD HL,BC 41 ADC HL,BC 42 SBC HL,BC */
    static const uint8_t fins[4] = {0x00, 0x01, 0xFE, 0xFF};
    for (int y = 0; y < 8; y++)
        for (int a = 0; a < 256; a++)
            for (int b = 0; b < 256; b++)
                for (int fi = 0; fi < 4; fi++) {
                    uint8_t code[1] = {(uint8_t)(0x80 | (y << 3))};
                    rA = a; rB = b; rF = fins[fi];
                    run_one(code, 1);
                    rec.op = y; rec.fin = fins[fi]; rec.x = a; rec.y = b; rec.out = rA; rec.fout = rF;
                    fwrite(&rec, sizeof rec, 1, o);
                }
    for (int a = 0; a < 256; a++)
        for (int f = 0; f < 256; f++) {
            uint8_t c1[1] = {0x3C}, c2[1] = {0x3D};
            rA = a; rF = f; run_one(c1, 1);
            rec.op = 8; rec.fin = f; rec.x = a; rec.y = 0; rec.out = rA; rec.fout = rF;
            fwrite(&rec, sizeof rec, 1, o);
            rA = a; rF = f; run_one(c2, 1);
            rec.op = 9; rec.fin = f; rec.x = a; rec.y = 0; rec.out = rA; rec.fout = rF;
            fwrite(&rec, sizeof rec, 1, o);
            for (int y = 0; y < 8; y++) {
                uint8_t c[2] = {0xCB, (uint8_t)(y << 3)};
                rB = a; rF = f; run_one(c, 2);
                rec.op = 10 + y; rec.fin = f; rec.x = a; rec.out = rB; rec.fout = rF;
                fwrite(&rec, sizeof rec, 1, o);
            }
            static const uint8_t ops1[9] = {0x07, 0x0F, 0x17, 0x1F, 0x27, 0x2F, 0x37, 0x3F, 0x00};
            for (int k = 0; k < 9; k++) {
                uint8_t c[2];
                int n = 1;
                if (k == 8) { c[0] = 0xED; c[1] = 0x44; n = 2; } else c[0] = ops1[k];
                rA = a; rF = f; run_one(c, n);
                rec.op = 18 + k; rec.fin = f; rec.x = a; rec.out = rA; rec.fout = rF;
                fwrite(&rec, sizeof rec, 1, o);
            }
            for (int b = 0; b < 8; b++) {
                uint8_t c[2] = {0xCB, (uint8_t)(0x40 | (b << 3))};
                rB = a; rF = f; run_one(c, 2);
                rec.op = 27 + b; rec.fin = f; rec.x = a; rec.out = rB; rec.fout = rF;
                fwrite(&rec, sizeof rec, 1, o);
            }
        }
    uint32_t seed = 12345;
    for (int i = 0; i < 300000; i++) {
        seed = seed * 1103515245u + 12345u; uint16_t h = seed >> 8;
        seed = seed * 1103515245u + 12345u; uint16_t v = seed >> 8;
        seed = seed * 1103515245u + 12345u; uint8_t f = seed >> 16;
        /* bias towards edge values */
        if (i % 7 == 0) h = (h & 1) ? 0x7FFF : 0x8000;
        if (i % 11 == 0) v = (v & 1) ? 0xFFFF : 0x0001;
        if (i % 13 == 0) v = h;
        for (int k = 0; k < 3; k++) {
            uint8_t c[2]; int n;
            if (k == 0) { c[0] = 0x09; n = 1; } else { c[0] = 0xED; c[1] = k == 1 ? 0x4A : 0x42; n = 2; }
            SETHL(h); SETBC(v); rF = f; run_one(c, n);
            rec.op = 40 + k; rec.fin = f; rec.x = h; rec.y = v; rec.out = HL; rec.fout = rF;
            fwrite(&rec, sizeof rec, 1, o);
        }
    }
    fclose(o);
    return 0;
}

/* timing self-test: prints "<hex bytes> <cond> T" for selected instructions.
   cond: 0 = flags 0x00, B=1, BC=1 ; 1 = flags 0xFF, B=2, BC=2 (and (HL)!=A for CPIR) */
static int selftest_timing(void)
{
    test_mode = 1;
    char line[256];
    while (fgets(line, sizeof line, stdin)) {
        uint8_t code[8]; int n = 0;
        char *s = line;
        int c = 0;
        if (sscanf(s, "%d", &c) != 1) continue;
        while (*s && !isspace((unsigned char)*s)) s++;
        unsigned v; int k;
        while (sscanf(s, " %x%n", &v, &k) == 1 && n < 8) { code[n++] = v; s += k; }
        reset_cpu();
        memset(&mem[0x8000], 0, 16);
        memcpy(&mem[0x8000], code, n);
        rPC = 0x8000; rSP = 0xF000;
        rF = c ? 0xFF : 0x00;
        /* block ops: BC=1 -> stop, BC=2 -> repeat; DJNZ: B=1 not taken, B=2 taken */
        SETBC(c ? 2 : 1);
        if (code[0] == 0x10 || ((code[0] == 0xDD || code[0] == 0xFD) && code[1] == 0x10)) rB = c ? 2 : 1;
        if (code[0] == 0xED && (code[1] & 0xF2) == 0xB2) rB = c ? 2 : 1;   /* INIR/OTIR/INDR/OTDR */
        SETHL(0x9000); SETDE(0x9100); rIX = 0x9000; rIY = 0x9000;
        mem[0x9000] = 0x11; rA = 0x22;
        mem[0xF000] = 0x00; mem[0xF001] = 0x80;
        int t = step();
        printf("%d %d\n", c, t);
        fflush(stdout);
    }
    return 0;
}

/* ------------------------------------------------------------------ */
/* Keys / input script                                                 */
typedef struct { const char *name; int row; int bit; } KeyDef;
static const KeyDef keydefs[] = {
    {"R", 0, 0}, {"Q", 0, 1}, {"E", 0, 2}, {"W", 0, 4}, {"T", 0, 5},
    {"F", 1, 0}, {"A", 1, 1}, {"D", 1, 2}, {"CTRL", 1, 3}, {"S", 1, 4}, {"G", 1, 5},
    {"V", 2, 0}, {"Z", 2, 1}, {"C", 2, 2}, {"SHIFT", 2, 3}, {"X", 2, 4}, {"B", 2, 5},
    {"4", 3, 0}, {"1", 3, 1}, {"3", 3, 2}, {"2", 3, 4}, {"5", 3, 5},
    {"M", 4, 0}, {"SPACE", 4, 1}, {"COMMA", 4, 2}, {"PERIOD", 4, 4}, {"N", 4, 5},
    {"7", 5, 0}, {"0", 5, 1}, {"8", 5, 2}, {"MINUS", 5, 3}, {"9", 5, 4}, {"6", 5, 5},
    {"U", 6, 0}, {"P", 6, 1}, {"I", 6, 2}, {"RETURN", 6, 3}, {"O", 6, 4}, {"Y", 6, 5},
    {"J", 7, 0}, {"SEMI", 7, 1}, {"K", 7, 2}, {"COLON", 7, 3}, {"L", 7, 4}, {"H", 7, 5},
    /* joystick pseudo-rows: 8 = joy1, 9 = joy2, 10 = arm */
    {"J1UP", 8, 0}, {"J1DOWN", 8, 1}, {"J1LEFT", 8, 2}, {"J1RIGHT", 8, 3}, {"J1FIRE", 8, 4},
    {"J1ARM", 10, 4},
    {"J2UP", 9, 0}, {"J2DOWN", 9, 1}, {"J2LEFT", 9, 2}, {"J2RIGHT", 9, 3}, {"J2FIRE", 9, 4},
    {NULL, 0, 0}
};

typedef struct { long field; uint8_t rows[11]; } InputEv;
static InputEv *inputs = NULL;
static int ninputs = 0;

static int cmp_input(const void *a, const void *b)
{
    long fa = ((const InputEv *)a)->field, fb = ((const InputEv *)b)->field;
    return fa < fb ? -1 : fa > fb;
}

static void load_script(const char *fn)
{
    FILE *f = fopen(fn, "r");
    if (!f) { perror(fn); exit(1); }
    char line[1024];
    int ln = 0;
    while (fgets(line, sizeof line, f)) {
        ln++;
        char *hash = strchr(line, '#'); if (hash) *hash = 0;
        char *tok = strtok(line, " \t\r\n,");
        if (!tok) continue;
        InputEv ev;
        ev.field = strtol(tok, NULL, 10);
        memset(ev.rows, 0xFF, sizeof ev.rows);
        while ((tok = strtok(NULL, " \t\r\n,"))) {
            int found = 0;
            for (char *c = tok; *c; c++) *c = toupper((unsigned char)*c);
            for (const KeyDef *k = keydefs; k->name; k++)
                if (!strcmp(k->name, tok)) { ev.rows[k->row] &= ~(1 << k->bit); found = 1; break; }
            if (!found) fprintf(stderr, "warning: %s:%d unknown key '%s'\n", fn, ln, tok);
        }
        inputs = realloc(inputs, (ninputs + 1) * sizeof *inputs);
        inputs[ninputs++] = ev;
    }
    fclose(f);
    qsort(inputs, ninputs, sizeof *inputs, cmp_input);
}

static void apply_inputs(long fld)
{
    const InputEv *cur = NULL;
    for (int i = 0; i < ninputs; i++)
        if (inputs[i].field <= fld) cur = &inputs[i];
    if (!cur) {
        memset(kbrow, 0xFF, sizeof kbrow); joy1 = joy2 = joyarm = 0xFF;
        return;
    }
    for (int i = 0; i < 8; i++) kbrow[i] = cur->rows[i] | 0xC0;
    joy1 = cur->rows[8]; joy2 = cur->rows[9]; joyarm = cur->rows[10];
}

/* ------------------------------------------------------------------ */
/* Video                                                               */
static const uint8_t pal[8][3] = {
    {0x00, 0xFF, 0x00}, {0xFF, 0xFF, 0x00}, {0x00, 0x00, 0xFF}, {0xFF, 0x00, 0x00},
    {0xFF, 0xFF, 0xFF}, {0x00, 0xFF, 0xFF}, {0xFF, 0x00, 0xFF}, {0xFF, 0x80, 0x00},
};
static const double lum[8] = {0.54, 0.65, 0.42, 0.42, 0.65, 0.54, 0.54, 0.54};
static int mono = 0;

static void video_catchup(void)
{
    while (snap_k < 64 && ft >= (long)(DISP_FIRST + 3 * snap_k) * LINE_T) {
        memcpy(snap[snap_k], &mem[0x7000 + snap_k * 32], 32);
        snapmode[snap_k] = latch;
        if ((snap_k & 3) == 0) memcpy(tsnap[snap_k >> 2], &mem[0x7000 + (snap_k >> 2) * 32], 32);
        snap_k++;
    }
}

static void put_px(uint8_t *img, int x, int y, int ci, int black)
{
    uint8_t *p = img + (y * 512 + x) * 3;
    if (black) { p[0] = p[1] = p[2] = 0; return; }
    if (mono) {
        int v = (int)((lum[ci] - 0.38) / 0.30 * 255 + 0.5); if (v > 255) v = 255; if (v < 0) v = 0;
        p[0] = p[1] = p[2] = v;
    } else { p[0] = pal[ci][0]; p[1] = pal[ci][1]; p[2] = pal[ci][2]; }
}

static void render(const char *fn)
{
    static uint8_t img[512 * 192 * 3];
    for (int k = 0; k < 64; k++) {
        int m = snapmode[k];
        int css = (m >> 4) & 1;
        for (int sl = 0; sl < 3; sl++) {
            int y = k * 3 + sl;
            if (m & 0x08) {
                for (int xb = 0; xb < 32; xb++) {
                    uint8_t b = snap[k][xb];
                    for (int px = 0; px < 4; px++) {
                        int ci = ((b >> (6 - 2 * px)) & 3) + css * 4;
                        for (int sx = 0; sx < 4; sx++) put_px(img, (xb * 4 + px) * 4 + sx, y, ci, 0);
                    }
                }
            } else {
                /* text: char row k/4, cell line (k%4)*3+sl of 12 */
                int cl = (k & 3) * 3 + sl;
                for (int cx = 0; cx < 32; cx++) {
                    uint8_t ch = tsnap[k >> 2][cx];
                    for (int sx = 0; sx < 16; sx++) {
                        int X = cx * 16 + sx;
                        if (ch & 0x80) {         /* SG4 semigraphics */
                            int ci = (ch >> 4) & 7;
                            int qbit = (cl < 6 ? (sx < 8 ? 3 : 2) : (sx < 8 ? 1 : 0));
                            put_px(img, X, y, ci, !(ch & (1 << qbit)));
                        } else {
                            int inv = (ch & 0x40) != 0;
                            int glyph = ((ch & 0x3F) != 0x20) && sx >= 4 && sx < 12 && cl >= 2 && cl < 10;
                            int on = inv ^ glyph;   /* on = dark */
                            if (css && !on) put_px(img, X, y, 7, 0);
                            else put_px(img, X, y, 0, on);
                        }
                    }
                }
            }
        }
    }
    FILE *f = fopen(fn, "wb");
    if (!f) { perror(fn); return; }
    fprintf(f, "P6\n512 192\n255\n");
    fwrite(img, 1, sizeof img, f);
    fclose(f);
}

/* ------------------------------------------------------------------ */
/* WAV                                                                 */
static void wput16(FILE *f, unsigned v) { fputc(v & 0xFF, f); fputc((v >> 8) & 0xFF, f); }
static void wput32(FILE *f, unsigned v) { wput16(f, v & 0xFFFF); wput16(f, v >> 16); }

static void write_wav(const char *fn, unsigned long long tend)
{
    const int SR = 44100;
    unsigned long long ns = tend * SR / CPU_HZ;
    FILE *f = fopen(fn, "wb");
    if (!f) { perror(fn); return; }
    fwrite("RIFF", 1, 4, f); wput32(f, 36 + ns * 2); fwrite("WAVEfmt ", 1, 8, f);
    wput32(f, 16); wput16(f, 1); wput16(f, 1); wput32(f, SR); wput32(f, SR * 2); wput16(f, 2); wput16(f, 16);
    fwrite("data", 1, 4, f); wput32(f, ns * 2);
    double tps = (double)CPU_HZ / SR;
    size_t ti = 0;
    int level = 0;
    for (unsigned long long i = 0; i < ns; i++) {
        double t0 = i * tps, t1 = (i + 1) * tps, hi = 0, pos = t0;
        while (ti < spk_n && (double)spk_t[ti] <= t1) {
            double tt = (double)spk_t[ti];
            if (tt > pos) { if (level) hi += tt - pos; pos = tt; }
            level = spk_v[ti];
            ti++;
        }
        if (level) hi += t1 - pos;
        double frac = hi / tps;
        int s = (int)((frac - 0.5) * 32767.0);
        wput16(f, (unsigned)(s & 0xFFFF));
    }
    fclose(f);
}

/* ------------------------------------------------------------------ */
/* Main                                                                */
static void usage(void)
{
    fprintf(stderr,
        "usage: vzemu file.vz [-f N] [-s f1,f2,..] [-p prefix] [-m] [-w out.wav] [-i script]\n"
        "             [-t N] [-b ADDR]... [-d START:LEN:file]...\n"
        "       vzemu --selftest-alu out.bin | --selftest-timing < list\n");
    exit(1);
}

int main(int argc, char **argv)
{
    init_tables();
    if (argc >= 3 && !strcmp(argv[1], "--selftest-alu")) return selftest_alu(argv[2]);
    if (argc >= 2 && !strcmp(argv[1], "--selftest-timing")) return selftest_timing();
    if (argc < 2) usage();

    const char *vzfile = NULL, *prefix = "shot", *wavfile = NULL, *script = NULL;
    long nfields = 200, trace_n = 0;
    long shots[1024]; int nshots = 0;
    unsigned bps[32]; int bphit[32]; int nbps = 0;
    struct { unsigned start, len; const char *fn; } dumps[32]; int ndumps = 0;

    for (int i = 1; i < argc; i++) {
        const char *a = argv[i];
        if (!strcmp(a, "-f") && i + 1 < argc) nfields = strtol(argv[++i], NULL, 10);
        else if (!strcmp(a, "-s") && i + 1 < argc) {
            char *s = argv[++i];
            while (*s && nshots < 1024) {
                shots[nshots++] = strtol(s, &s, 10);
                while (*s == ',' || *s == ' ') s++;
            }
        }
        else if (!strcmp(a, "-p") && i + 1 < argc) prefix = argv[++i];
        else if (!strcmp(a, "-m")) mono = 1;
        else if (!strcmp(a, "-w") && i + 1 < argc) wavfile = argv[++i];
        else if (!strcmp(a, "-i") && i + 1 < argc) script = argv[++i];
        else if (!strcmp(a, "-t") && i + 1 < argc) trace_n = strtol(argv[++i], NULL, 10);
        else if (!strcmp(a, "-S") && i + 1 < argc) { sd_dir = argv[++i]; }
        else if (!strcmp(a, "-P") && i + 2 < argc) { prof_from = atol(argv[++i]); prof_file = argv[++i]; }
        else if (!strcmp(a, "-W") && i + 1 < argc) { sscanf(argv[++i], "%x:%x", &watch_lo, &watch_hi); }
        else if (!strcmp(a, "-b") && i + 1 < argc && nbps < 32) { bps[nbps] = strtoul(argv[++i], NULL, 16); bphit[nbps++] = 0; }
        else if (!strcmp(a, "-d") && i + 1 < argc && ndumps < 32) {
            char *s = argv[++i], *e;
            dumps[ndumps].start = strtoul(s, &e, 16);
            if (*e != ':') usage();
            dumps[ndumps].len = strtoul(e + 1, &e, 16);
            if (*e != ':') usage();
            dumps[ndumps].fn = e + 1;
            ndumps++;
        }
        else if (a[0] == '-') usage();
        else vzfile = a;
    }
    if (!vzfile) usage();
    if (script) load_script(script);

    /* load .VZ */
    FILE *f = fopen(vzfile, "rb");
    if (!f) { perror(vzfile); return 1; }
    static uint8_t buf[65536 + 64];
    size_t n = fread(buf, 1, sizeof buf, f);
    fclose(f);
    if (n < 24) { fprintf(stderr, "%s: too short for .VZ\n", vzfile); return 1; }
    char name[18]; memcpy(name, buf + 4, 17); name[17] = 0;
    for (int i = 0; i < 17; i++) if (name[i] && !isprint((unsigned char)name[i])) name[i] = '?';
    uint8_t type = buf[21];
    uint16_t start = buf[22] | (buf[23] << 8);
    size_t dlen = n - 24;
    if (type != 0xF1) fprintf(stderr, "warning: .VZ type %02X (not F1 binary)\n", type);
    memset(mem, 0, sizeof mem);
    memset(sram, 0, sizeof sram);
    port37 = 1; latch = 0;
    for (size_t i = 0; i < dlen; i++) {
        uint16_t ad = (uint16_t)(start + i);
        if (ad < 0x4000 || (ad >= 0x6800 && ad < 0x7000)) continue;
        if (ad < 0x6800) sram[0][ad - 0x4000] = buf[24 + i];
        else mem[ad] = buf[24 + i];
    }
    printf("loaded '%s' type %02X at %04X-%04X (%zu bytes)\n", name, type, start,
           (unsigned)(start + dlen - 1) & 0xFFFF, dlen);

    reset_cpu();
    rPC = start;
    memset(kbrow, 0xFF, sizeof kbrow);
    apply_inputs(1);

    long *busy = calloc(nfields + 1, sizeof(long));
    long fields_with_snow = 0, max_snow = 0, max_snow_field = 0, irq_fields = 0;
    int irq_acked = 0;
    long busy_field = 0;
    long instr_count = 0;
    int rom_hit = 0; uint16_t rom_pc = 0, rom_prev = 0; long rom_field = 0; int rom_line = 0;
    unsigned long long rom_count = 0;
    long dihalt_field = 0;
    uint16_t prev_pc = rPC;

    while (field <= nfields) {
        int t;
        cur_line = ft / LINE_T;
        in_display = cur_line >= DISP_FIRST && cur_line <= DISP_LAST;
        instr_abs_t = total_t + ft;
        int irq_ok = !ei_just;
        ei_just = 0;
        if (irq_ok && iff1 && cur_line < FS_LINES && !irq_acked) {
            t = accept_irq();
            irq_acked = 1;
            irq_fields++;
            busy_field += t;
        } else if (halted) {
            inc_r();
            t = 4;
            if (!iff1 && !dihalt_field) dihalt_field = field;
        } else {
            uint16_t pc = rPC; cur_pc_for_watch = pc; pcring[pcri++] = pc; bigring[bigri & 8191] = pc; bigix[bigri & 8191] = rIX; bigri++;
            { static int ixchk_pc = -2, ixchk_base, ixchk_done; if (ixchk_pc == -2) { const char *e = getenv("VZ_IXCHK"); ixchk_pc = -1; if (e) sscanf(e, "%x:%x", &ixchk_pc, &ixchk_base); }
              if (pc == ixchk_pc && !ixchk_done && ((rIX - ixchk_base) & 15)) { ixchk_done = 1; fprintf(stderr, "IXCHK field %d IX=%04X trail:", field, rIX); for (int q = 0; q < 256; q++) fprintf(stderr, " %04X", pcring[(uint8_t)(pcri + q)]); fprintf(stderr, "\n"); } }
            if (pc < 0x4000 && !pcdumped) { pcdumped = 1; for (int q = 0; q < 256; q++) pcdump[q] = pcring[(uint8_t)(pcri + q)]; }
            if (pc < 0x4000) {
                rom_count++;
                if (!rom_hit) { rom_hit = 1; rom_pc = pc; rom_prev = prev_pc; rom_field = field; rom_line = cur_line; }
            }
            for (int b = 0; b < nbps; b++)
                if (!bphit[b] && bps[b] == pc) {
                    bphit[b] = 1;
                    printf("BREAK %04X field %ld line %d: ", pc, field, cur_line);
                    print_regs(stdout); printf("\n");
                }
            if (instr_count < trace_n) {
                printf("[%ld:%3d] %04X  %02X %02X %02X %02X  ", field, cur_line, pc,
                       peek(pc), peek(pc + 1), peek(pc + 2), peek(pc + 3));
                print_regs(stdout); printf("\n");
            }
            instr_count++;
            prev_pc = pc;
            if (sd_dir && (pc == 0x5F00 || pc == 0x5F03 || pc == 0x5F09) && (port37 & 3) == 1) t = dos_trap(pc); else
            t = step(); if (prof_from >= 0 && field >= prof_from) prof[pc] += t;
            busy_field += t;
        }
        ft += t;
        video_catchup();
        if (ft >= FRAME_T) {
            for (int s = 0; s < nshots; s++)
                if (shots[s] == field) {
                    char fn[1024];
                    snprintf(fn, sizeof fn, "%s_%04ld.ppm", prefix, field);
                    render(fn);
                }
            busy[field] = busy_field;
            if (snow_field) fields_with_snow++;
            if (snow_field > max_snow) { max_snow = snow_field; max_snow_field = field; }
            snow_field = 0;
            busy_field = 0;
            ft -= FRAME_T;
            total_t += FRAME_T;
            snap_k = 0;
            irq_acked = 0;
            field++;
            if (field <= nfields) apply_inputs(field);
            video_catchup();
        }
    }

    unsigned long long tend = total_t + ft;
    for (int d = 0; d < ndumps; d++) {
        FILE *o = fopen(dumps[d].fn, "wb");
        if (!o) { perror(dumps[d].fn); continue; }
        for (unsigned i = 0; i < dumps[d].len; i++) fputc(peek((uint16_t)(dumps[d].start + i)), o);
        fclose(o);
    }
    if (wavfile) write_wav(wavfile, tend);

    long bmin = -1, bmax = 0; double bsum = 0;
    for (long i = 1; i <= nfields; i++) {
        if (bmin < 0 || busy[i] < bmin) bmin = busy[i];
        if (busy[i] > bmax) bmax = busy[i];
        bsum += busy[i];
    }
    printf("fields: %ld  T-states: %llu  instructions: %ld\n", nfields, tend, instr_count);
    printf("snow: total %llu, max %ld in one field (field %ld), fields with snow %ld\n",
           snow_total, max_snow, max_snow_field, fields_with_snow);
    printf("interrupts accepted in %ld fields\n", irq_fields);
    printf("busy T/field: min %ld avg %.0f max %ld (of %d, %.1f%% max)\n",
           bmin < 0 ? 0 : bmin, nfields ? bsum / nfields : 0.0, bmax, FRAME_T, 100.0 * bmax / FRAME_T);
    printf("speaker transitions: %zu\n", spk_n);
    if (rom_hit) {
        printf("ROM EXECUTION: first at PC=%04X (from PC=%04X) field %ld line %d; %llu instrs in ROM area",
               rom_pc, rom_prev, rom_field, rom_line, rom_count);
        if ((rom_pc & 0xFFC7) == 0 && rom_pc <= 0x38)
            printf(" [RST %02Xh vector%s]", rom_pc, rom_pc == 0x38 ? " / IM0-IM1 interrupt" : "");
        printf("\n");
    if (pcdumped) { fprintf(stdout, "PC trail:"); for (int q = 192; q < 256; q++) fprintf(stdout, " %04X", pcdump[q]); fprintf(stdout, "\n"); }
    } else printf("ROM execution: none\n");
    if (prof_file) { FILE *pf = fopen(prof_file, "wb"); fwrite(prof, sizeof prof, 1, pf); fclose(pf); }
    printf("final: "); print_regs(stdout); printf("\n");
    if (halted && !iff1) printf("HANG: CPU halted with interrupts disabled (first DI-HALT in field %ld)\n", dihalt_field);
    else if (dihalt_field) printf("note: DI+HALT seen in field %ld\n", dihalt_field);
    free(busy);
    return 0;
}
