/*
 * vzemu.c - cycle-counting Z80 emulator with minimal VZ300 hardware
 * (ViBED by BPM toolchain). Documented Z80 instruction set, exact T-states.
 *
 * VZ300 model:
 *   $0000-$3FFF  ROM (reads $FF here: programs must not call ROM)
 *   $6800-$6FFF  read : bit7 = field sync (0 during sync), bits0-5 keyboard (1 = no key)
 *                write: output latch (bit3 mode(1), bit4 CSS, bit0/5 speaker)
 *   $7000-$77FF  video RAM
 *   312 lines x 227 T per field; field sync low for the first 56 lines.
 *   Latch writes are logged with their T-state so a CSS split row can be rendered.
 *
 * Usage: vzemu file.vz [maxT] [--dump out.raw] [--trace]
 *   Runs until HALT (with DI) or maxT T-states. Writes video RAM + latch log to out.raw.
 *   A program can report a value by writing to port $FF (OUT ($FF),A): printed with T.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef uint8_t u8; typedef uint16_t u16; typedef int8_t s8;

static u8 mem[65536];
static u8 A, F, B, C, D, E, H, L, A_, F_, B_, C_, D_, E_, H_, L_, I, R;
static u16 IX, IY, SP, PC;
static int iff1, iff2, im, halted;
static uint64_t T;
static uint64_t pchist[65536];
static u8 latch;
#define LINES 312
#define FIELD_T 70630           /* measured on the user's VZ300 */
#define FS_LINES 56

static struct { uint64_t t; u8 v; } latchlog[200000]; static int nlatch;

static int fs_low(void) { return (int)(((T % FIELD_T) * LINES) / FIELD_T) < FS_LINES; }

/* scripted key presses: --key F0 F1 ROWADDR BIT (fields F0..F1, row address low byte, bit) */
static struct { long f0, f1; int row, bit; } keys[32]; static int nkeys;
static u8 rd(u16 a) {
    if (a < 0x4000) return 0xFF;
    if (a >= 0x6800 && a < 0x7000) {
        u8 v = (fs_low() ? 0x00 : 0x80) | 0x7F;
        long f = (long)(T / FIELD_T);
        for (int k = 0; k < nkeys; k++)
            if (f >= keys[k].f0 && f <= keys[k].f1 && !(a & ~keys[k].row & 0xFF) ) v &= ~(1 << keys[k].bit);
        return v;
    }
    return mem[a];
}
static void wr(u16 a, u8 v) {
    if (a < 0x4000) return;
    if (a >= 0x6800 && a < 0x7000) {
        latch = v;
        if (nlatch < 200000) { latchlog[nlatch].t = T; latchlog[nlatch].v = v; nlatch++; }
        return;
    }
    mem[a] = v;
}
static u16 rd16(u16 a) { return rd(a) | (rd((u16)(a + 1)) << 8); }
static void wr16(u16 a, u16 v) { wr(a, v & 0xFF); wr((u16)(a + 1), v >> 8); }
static u8 fetch(void) { return rd(PC++); }
static u16 fetch16(void) { u16 v = rd16(PC); PC += 2; return v; }

/* flags */
#define FC 0x01
#define FN 0x02
#define FP 0x04
#define F3 0x08
#define FH 0x10
#define F5 0x20
#define FZ 0x40
#define FS 0x80
static u8 sz[256], szp[256];
static void init_tables(void) {
    for (int i = 0; i < 256; i++) {
        int p = 0; for (int b = 0; b < 8; b++) p ^= (i >> b) & 1;
        sz[i] = (i & 0x80) | (i ? 0 : FZ) | (i & (F3 | F5));
        szp[i] = sz[i] | (p ? 0 : FP);
    }
}

static void add8(u8 v, int cy) {
    int r = A + v + cy;
    F = sz[r & 0xFF] | ((r >> 8) & FC) | ((A ^ v ^ r) & FH) | ((((A ^ ~v) & (A ^ r)) & 0x80) ? FP : 0);
    A = (u8)r;
}
static void sub8(u8 v, int cy, int store) {
    int r = A - v - cy;
    u8 f = sz[r & 0xFF] | FN | ((r >> 8) & FC) | ((A ^ v ^ r) & FH) | ((((A ^ v) & (A ^ r)) & 0x80) ? FP : 0);
    if (!store) f = (f & ~(F3 | F5)) | (v & (F3 | F5));
    F = f;
    if (store) A = (u8)r;
}
static void alu(int op, u8 v) {
    switch (op) {
    case 0: add8(v, 0); break;
    case 1: add8(v, F & FC); break;
    case 2: sub8(v, 0, 1); break;
    case 3: sub8(v, F & FC, 1); break;
    case 4: A &= v; F = szp[A] | FH; break;
    case 5: A ^= v; F = szp[A]; break;
    case 6: A |= v; F = szp[A]; break;
    case 7: sub8(v, 0, 0); break;
    }
}
static u8 inc8(u8 v) { u8 r = v + 1; F = (F & FC) | sz[r] | ((r & 0x0F) == 0 ? FH : 0) | (v == 0x7F ? FP : 0); return r; }
static u8 dec8(u8 v) { u8 r = v - 1; F = (F & FC) | sz[r] | FN | ((v & 0x0F) == 0 ? FH : 0) | (v == 0x80 ? FP : 0); return r; }
static u16 add16(u16 a, u16 b) {
    uint32_t r = a + b;
    F = (F & (FS | FZ | FP)) | ((r >> 16) & FC) | (((a ^ b ^ r) >> 8) & FH) | ((r >> 8) & (F3 | F5));
    return (u16)r;
}
static u16 adc16(u16 a, u16 b) {
    uint32_t r = a + b + (F & FC);
    F = ((r >> 8) & FS) | ((r & 0xFFFF) ? 0 : FZ) | ((r >> 16) & FC) | (((a ^ b ^ r) >> 8) & FH)
        | ((((a ^ ~b) & (a ^ r)) & 0x8000) ? FP : 0) | ((r >> 8) & (F3 | F5));
    return (u16)r;
}
static u16 sbc16(u16 a, u16 b) {
    uint32_t r = a - b - (F & FC);
    F = ((r >> 8) & FS) | ((r & 0xFFFF) ? 0 : FZ) | ((r >> 16) & FC) | (((a ^ b ^ r) >> 8) & FH) | FN
        | ((((a ^ b) & (a ^ r)) & 0x8000) ? FP : 0) | ((r >> 8) & (F3 | F5));
    return (u16)r;
}
static u8 rot(int op, u8 v) {
    u8 r, c;
    switch (op) {
    case 0: c = v >> 7; r = (v << 1) | c; break;
    case 1: c = v & 1; r = (v >> 1) | (c << 7); break;
    case 2: c = v >> 7; r = (v << 1) | (F & FC); break;
    case 3: c = v & 1; r = (v >> 1) | ((F & FC) << 7); break;
    case 4: c = v >> 7; r = v << 1; break;
    case 5: c = v & 1; r = (v >> 1) | (v & 0x80); break;
    case 6: c = v >> 7; r = (v << 1) | 1; break;
    default: c = v & 1; r = v >> 1; break;
    }
    F = szp[r] | c; return r;
}

/* register access with index substitution */
static u8 *r8p(int r, int pre) {
    switch (r) {
    case 0: return &B; case 1: return &C; case 2: return &D; case 3: return &E;
    case 4: return pre == 0xDD ? ((u8 *)&IX) + 1 : pre == 0xFD ? ((u8 *)&IY) + 1 : &H;
    case 5: return pre == 0xDD ? ((u8 *)&IX) : pre == 0xFD ? ((u8 *)&IY) : &L;
    case 7: return &A;
    }
    return NULL;
}
static u16 HL(void) { return (H << 8) | L; }
static void setHL(u16 v) { H = v >> 8; L = (u8)v; }
static u16 getrr(int p, int pre) {
    switch (p) {
    case 0: return (B << 8) | C; case 1: return (D << 8) | E;
    case 2: return pre == 0xDD ? IX : pre == 0xFD ? IY : HL();
    default: return SP;
    }
}
static void setrr(int p, int pre, u16 v) {
    switch (p) {
    case 0: B = v >> 8; C = (u8)v; break; case 1: D = v >> 8; E = (u8)v; break;
    case 2: if (pre == 0xDD) IX = v; else if (pre == 0xFD) IY = v; else setHL(v); break;
    default: SP = v;
    }
}
static int cond(int c) {
    switch (c) {
    case 0: return !(F & FZ); case 1: return F & FZ; case 2: return !(F & FC); case 3: return F & FC;
    case 4: return !(F & FP); case 5: return F & FP; case 6: return !(F & FS); default: return F & FS;
    }
}
static void push(u16 v) { SP -= 2; wr16(SP, v); }
static u16 pop(void) { u16 v = rd16(SP); SP += 2; return v; }

static int port_out_count;
static void port_out(u8 port, u8 v) {
    if (port == 0xFF) { printf("OUT $FF <- %3d ($%02X) at T=%llu\n", v, v, (unsigned long long)T); port_out_count++; }
}

/* T-states, unprefixed (not-taken values for conditionals) */
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

static void exec_cb(int pre, s8 d) {
    u8 op; u8 v; u16 ea = 0;
    if (pre) { ea = (pre == 0xDD ? IX : IY) + d; op = fetch(); }
    else op = fetch();
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    if (pre) v = rd(ea);
    else v = (z == 6) ? rd(HL()) : *r8p(z, 0);
    if (x == 1) { /* BIT */
        u8 r = v & (1 << y);
        F = (F & FC) | FH | (r ? (r & FS) : (FZ | FP)) | (v & (F3 | F5));
        T += pre ? 16 : (z == 6 ? 12 : 8);   /* DD/FD prefix already counted 4 */
        return;
    }
    u8 r;
    if (x == 0) r = rot(y, v);
    else if (x == 2) r = v & ~(1 << y);
    else r = v | (1 << y);
    if (pre) { wr(ea, r); if (z != 6) *r8p(z, 0) = r; T += 19; }
    else if (z == 6) { wr(HL(), r); T += 15; }
    else { *r8p(z, 0) = r; T += 8; }
}

static void exec_ed(void) {
    u8 op = fetch();
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    if (x == 1) {
        switch (z) {
        case 0: { u8 v = 0xFF; if (y != 6) *r8p(y, 0) = v; F = (F & FC) | szp[v]; T += 12; return; }
        case 1: port_out(C, y == 6 ? 0 : *r8p(y, 0)); T += 12; return;
        case 2: { u16 hl = HL(); setHL(q ? adc16(hl, getrr(p, 0)) : sbc16(hl, getrr(p, 0))); T += 15; return; }
        case 3: { u16 a = fetch16(); if (q) setrr(p, 0, rd16(a)); else wr16(a, getrr(p, 0)); T += 20; return; }
        case 4: { u8 v = A; A = 0; sub8(v, 0, 1); T += 8; return; }
        case 5: PC = pop(); iff1 = iff2; T += 14; return;
        case 6: im = (y & 3) == 0 ? 0 : (y & 3) == 2 ? 1 : 2; T += 8; return;
        case 7:
            switch (y) {
            case 0: I = A; T += 9; return;
            case 1: R = A; T += 9; return;
            case 2: A = I; F = (F & FC) | sz[A] | (iff2 ? FP : 0); T += 9; return;
            case 3: A = R; F = (F & FC) | sz[A] | (iff2 ? FP : 0); T += 9; return;
            case 4: { u8 m = rd(HL()); u8 nm = (A << 4) | (m >> 4); A = (A & 0xF0) | (m & 0x0F); wr(HL(), nm); F = (F & FC) | szp[A]; T += 18; return; }
            case 5: { u8 m = rd(HL()); u8 nm = (m << 4) | (A & 0x0F); A = (A & 0xF0) | (m >> 4); wr(HL(), nm); F = (F & FC) | szp[A]; T += 18; return; }
            default: T += 8; return;
            }
        }
    }
    if (x == 2 && z <= 3 && y >= 4) {
        int inc = (y & 1) ? -1 : 1, rep = y >= 6;
        u16 bc = (B << 8) | C;
        if (z == 0) { /* LDI/LDD */
            u8 v = rd(HL()); wr((D << 8) | E, v);
            setHL(HL() + inc); u16 de = ((D << 8) | E) + inc; D = de >> 8; E = (u8)de;
            bc--; B = bc >> 8; C = (u8)bc;
            F = (F & (FS | FZ | FC)) | (bc ? FP : 0);
        } else if (z == 1) { /* CPI/CPD */
            u8 v = rd(HL()); u8 r = A - v;
            setHL(HL() + inc); bc--; B = bc >> 8; C = (u8)bc;
            F = (F & FC) | FN | (r & FS) | (r ? 0 : FZ) | ((A ^ v ^ r) & FH) | (bc ? FP : 0);
            if (rep && !(F & FZ) && bc) { PC -= 2; T += 21; return; }
            T += 16; return;
        } else { /* INI/OUTI etc: not used on VZ; treat as block I/O no-op data */
            if (z == 2) { wr(HL(), 0xFF); } else port_out(C, rd(HL()));
            setHL(HL() + inc); B--; F = (F & FC) | FN | (B ? 0 : FZ);
            if (rep && B) { PC -= 2; T += 21; return; }
            T += 16; return;
        }
        if (rep && bc) { PC -= 2; T += 21; return; }
        T += 16; return;
    }
    T += 8; /* undefined ED: NOP */
}

static void step(void) {
    if (halted) { T += 4; return; }
    int pre = 0;
    u8 op = fetch();
    R = (R & 0x80) | ((R + 1) & 0x7F);
    while (op == 0xDD || op == 0xFD) { pre = op; T += 4; op = fetch(); R = (R & 0x80) | ((R + 1) & 0x7F); }
    if (op == 0xCB) {
        if (pre) { s8 d = (s8)fetch(); exec_cb(pre, d); }
        else { R = (R & 0x80) | ((R + 1) & 0x7F); exec_cb(0, 0); }
        return;
    }
    if (op == 0xED) { if (pre) T -= 4; exec_ed(); return; }

    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    T += cyc[op];

    /* memory operand (HL) or (IX+d) */
    #define MEMADDR() (pre ? (u16)((pre == 0xDD ? IX : IY) + (s8)fetch()) : HL())

    switch (x) {
    case 0:
        switch (z) {
        case 0:
            switch (y) {
            case 0: break;
            case 1: { u8 t = A; A = A_; A_ = t; t = F; F = F_; F_ = t; break; }
            case 2: { s8 d = (s8)fetch(); if (--B) { PC += d; T += 5; } break; }
            case 3: { s8 d = (s8)fetch(); PC += d; break; }
            default: { s8 d = (s8)fetch(); if (cond(y - 4)) { PC += d; T += 5; } break; }
            }
            break;
        case 1:
            if (!q) setrr(p, pre, fetch16());
            else setrr(2, pre, add16(getrr(2, pre), getrr(p, pre)));
            break;
        case 2:
            switch (y) {
            case 0: wr((B << 8) | C, A); break;
            case 1: A = rd((B << 8) | C); break;
            case 2: wr((D << 8) | E, A); break;
            case 3: A = rd((D << 8) | E); break;
            case 4: wr16(fetch16(), getrr(2, pre)); break;
            case 5: setrr(2, pre, rd16(fetch16())); break;
            case 6: wr(fetch16(), A); break;
            case 7: A = rd(fetch16()); break;
            }
            break;
        case 3: setrr(p, pre, getrr(p, pre) + (q ? -1 : 1)); break;
        case 4: case 5:
            if (y == 6) {
                u16 a = MEMADDR(); if (pre) T += 8;
                wr(a, z == 4 ? inc8(rd(a)) : dec8(rd(a)));
            } else { u8 *r = r8p(y, pre); *r = z == 4 ? inc8(*r) : dec8(*r); }
            break;
        case 6:
            if (y == 6) { u16 a = MEMADDR(); if (pre) T += 5; wr(a, fetch()); }
            else *r8p(y, pre) = fetch();
            break;
        case 7:
            switch (y) {
            case 0: { u8 c = A >> 7; A = (A << 1) | c; F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 1: { u8 c = A & 1; A = (A >> 1) | (c << 7); F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 2: { u8 c = A >> 7; A = (A << 1) | (F & FC); F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 3: { u8 c = A & 1; A = (A >> 1) | ((F & FC) << 7); F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 4: { /* DAA */
                u8 a = A, cf = F & FC, hf = F & FH, nf = F & FN, corr = 0, c2 = cf;
                if (hf || (a & 0x0F) > 9) corr |= 0x06;
                if (cf || a > 0x99) { corr |= 0x60; c2 = FC; }
                A = nf ? a - corr : a + corr;
                F = szp[A] | c2 | nf | ((a ^ A) & FH);
                break; }
            case 5: A = ~A; F = (F & (FS | FZ | FP | FC)) | FH | FN | (A & (F3 | F5)); break;
            case 6: F = (F & (FS | FZ | FP)) | FC | (A & (F3 | F5)); break;
            case 7: F = ((F & (FS | FZ | FP | FC)) | ((F & FC) ? FH : 0) | (A & (F3 | F5))) ^ FC; break;
            }
            break;
        }
        break;
    case 1:
        if (y == 6 && z == 6) { halted = 1; PC--; break; }
        if (y == 6) { u16 a = MEMADDR(); if (pre) T += 8; wr(a, *r8p(z, 0)); }
        else if (z == 6) { u16 a = MEMADDR(); if (pre) T += 8; *r8p(y, 0) = rd(a); }
        else *r8p(y, pre) = *r8p(z, pre);
        break;
    case 2:
        if (z == 6) { u16 a = MEMADDR(); if (pre) T += 8; alu(y, rd(a)); }
        else alu(y, *r8p(z, pre));
        break;
    case 3:
        switch (z) {
        case 0: if (cond(y)) { PC = pop(); T += 6; } break;
        case 1:
            if (!q) { u16 v = pop(); if (p == 3) { A = v >> 8; F = (u8)v; } else setrr(p, pre, v); }
            else switch (p) {
                case 0: PC = pop(); break;
                case 1: { u8 t; t = B; B = B_; B_ = t; t = C; C = C_; C_ = t; t = D; D = D_; D_ = t;
                          t = E; E = E_; E_ = t; t = H; H = H_; H_ = t; t = L; L = L_; L_ = t; break; }
                case 2: PC = getrr(2, pre); break;
                case 3: SP = getrr(2, pre); break;
            }
            break;
        case 2: { u16 a = fetch16(); if (cond(y)) PC = a; break; }
        case 3:
            switch (y) {
            case 0: PC = fetch16(); break;
            case 2: port_out(fetch(), A); break;
            case 3: fetch(); A = 0xFF; break;
            case 4: { u16 v = rd16(SP); wr16(SP, getrr(2, pre)); setrr(2, pre, v); break; }
            case 5: { u8 t = D; D = H; H = t; t = E; E = L; L = t; break; }
            case 6: iff1 = iff2 = 0; break;
            case 7: iff1 = iff2 = 1; break;
            }
            break;
        case 4: { u16 a = fetch16(); if (cond(y)) { push(PC); PC = a; T += 7; } break; }
        case 5:
            if (!q) { u16 v = p == 3 ? (A << 8) | F : getrr(p, pre); push(v); }
            else if (p == 0) { u16 a = fetch16(); push(PC); PC = a; }
            break;
        case 6: alu(y, fetch()); break;
        case 7: push(PC); PC = y * 8; break;
        }
        break;
    }
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: vzemu file.vz [maxT] [--dump out.raw]\n"); return 1; }
    init_tables();
    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror(argv[1]); return 1; }
    u8 hdr[24]; if (fread(hdr, 1, 24, f) != 24 || memcmp(hdr, "VZF0", 4)) { fprintf(stderr, "not a .VZ file\n"); return 1; }
    u16 start = hdr[22] | (hdr[23] << 8);
    size_t n = fread(mem + start, 1, 65536 - start, f); fclose(f);
    if (hdr[21] != 0xF1) fprintf(stderr, "warning: type byte $%02X (expected $F1)\n", hdr[21]);
    printf("loaded %zu bytes at $%04X-$%04X\n", n, start, (unsigned)(start + n - 1));
    uint64_t maxT = argc > 2 && argv[2][0] != '-' ? strtoull(argv[2], 0, 10) : 400000000ULL;
    const char *dump = NULL, *memdump = NULL;
    int snapaddr[8], nsnap = 0, snapdone[8] = {0}; const char *snapfile[8];
    /* --prof ADDR NAME : exact T-states per call (entry to return) */
    int profaddr[16], nprof = 0; const char *profname[16];
    uint64_t pstart[16], pcount[16] = {0}, psum[16] = {0}, pmin[16], pmax[16] = {0};
    u16 pret[16], psp[16]; int pactive[16] = {0};
    for (int i = 2; i < argc; i++) {
        if (!strcmp(argv[i], "--dump") && i + 1 < argc) dump = argv[i + 1];
        if (!strcmp(argv[i], "--memdump") && i + 1 < argc) memdump = argv[i + 1];
        if (!strcmp(argv[i], "--key") && i + 4 < argc && nkeys < 32) {
            keys[nkeys].f0 = atol(argv[i + 1]); keys[nkeys].f1 = atol(argv[i + 2]);
            keys[nkeys].row = (int)strtol(argv[i + 3], 0, 16); keys[nkeys].bit = atoi(argv[i + 4]); nkeys++; }
        if (!strcmp(argv[i], "--prof") && i + 2 < argc && nprof < 16) {
            profaddr[nprof] = (int)strtol(argv[i + 1], 0, 16); profname[nprof] = argv[i + 2]; pmin[nprof] = ~0ULL; nprof++; }
        if (!strcmp(argv[i], "--snap") && i + 2 < argc && nsnap < 8) {
            snapaddr[nsnap] = (int)strtol(argv[i + 1], 0, 16); snapfile[nsnap] = argv[i + 2]; nsnap++; }
    }
    PC = start; SP = 0xF9F0; iff1 = 0; im = 1;
    /* random-ish start phase within the field, like a real machine */
    T = 12345;
    const char *vlog = NULL; int vevery = 3; FILE *vf = NULL; uint64_t lastfield = T / FIELD_T;
    for (int i = 2; i < argc; i++) if (!strcmp(argv[i], "--vramlog") && i + 2 < argc) { vlog = argv[i + 1]; vevery = atoi(argv[i + 2]); }
    if (vlog) vf = fopen(vlog, "wb");
    while (T < maxT) {
        if (vf && T / FIELD_T != lastfield) {
            lastfield = T / FIELD_T;
            if (lastfield % vevery == 0) { fwrite(mem + 0x7000, 1, 2048, vf); fputc(latch, vf); }
        }
        if (iff1 && fs_low()) {          /* VZ: field sync drives /INT (level) */
            iff1 = iff2 = 0;
            if (halted) { halted = 0; PC++; }
            push(PC);
            if (im == 2) { PC = rd16((u16)((I << 8) | 0xFF)); T += 19; }
            else { PC = 0x38; T += 13; }
        }
        for (int k = 0; k < nsnap; k++)
            if (!snapdone[k] && PC == snapaddr[k]) {
                FILE *o = fopen(snapfile[k], "wb"); fwrite(mem + 0x7000, 1, 2048, o); fputc(latch, o); fclose(o);
                snapdone[k] = 1;
                printf("snapshot %s at T=%llu (field %.2f)\n", snapfile[k], (unsigned long long)T, (double)T / FIELD_T);
            }
        for (int k = 0; k < nprof; k++) {
            if (pactive[k] && PC == pret[k] && SP == (u16)(psp[k] + 2)) {
                uint64_t d = T - pstart[k]; pactive[k] = 0;
                pcount[k]++; psum[k] += d; if (d < pmin[k]) pmin[k] = d; if (d > pmax[k]) pmax[k] = d;
            } else if (!pactive[k] && PC == profaddr[k]) {
                pactive[k] = 1; pstart[k] = T; psp[k] = SP; pret[k] = rd16(SP);
            }
        }
        { u16 pc0 = PC; uint64_t t0 = T; step(); pchist[pc0] += T - t0; }
        if (halted && !iff1) break;
    }
    for (int i = 2; i < argc; i++) if (!strcmp(argv[i], "--pchist") && i + 1 < argc) {
        FILE *o = fopen(argv[i + 1], "wb"); fwrite(pchist, sizeof(pchist[0]), 65536, o); fclose(o); }
    for (int k = 0; k < nprof; k++)
        if (pcount[k]) printf("PROF %-10s calls %6llu  avg %8.1f  min %6llu  max %6llu  (incl. RET, excl. CALL)\n", profname[k],
            (unsigned long long)pcount[k], (double)psum[k] / pcount[k], (unsigned long long)pmin[k], (unsigned long long)pmax[k]);
    if (vf) fclose(vf);
    if (memdump) { FILE *o = fopen(memdump, "wb"); fwrite(mem, 1, 65536, o); fclose(o); }
    printf("regs A=%02X F=%02X BC=%02X%02X DE=%02X%02X HL=%02X%02X IX=%04X IY=%04X SP=%04X\n", A, F, B, C, D, E, H, L, IX, IY, SP);
    printf("stopped at PC=$%04X T=%llu (%.2f fields) %s\n", PC, (unsigned long long)T, (double)T / FIELD_T, halted ? "HALT" : "maxT");
    if (dump) {
        FILE *o = fopen(dump, "wb");
        fwrite(mem + 0x7000, 1, 2048, o);
        fputc(latch, o);
        fclose(o);
    }
    return 0;
}
