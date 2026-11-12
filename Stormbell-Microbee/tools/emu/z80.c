/* Compact Z80 core (see z80.h). Written for the uB-TYPE test model. */
#include "z80.h"

#define FS 0x80
#define FZ 0x40
#define FY 0x20
#define FH 0x10
#define FX 0x08
#define FP 0x04
#define FN 0x02
#define FC 0x01

static uint8_t sz53[256], sz53p[256];
static int tables_done;

static void mk_tables(void) {
    for (int i = 0; i < 256; i++) {
        uint8_t f = (i & (FS | FY | FX)) | (i ? 0 : FZ);
        int p = 0;
        for (int b = 0; b < 8; b++) p ^= (i >> b) & 1;
        sz53[i] = f;
        sz53p[i] = f | (p ? 0 : FP);
    }
    tables_done = 1;
}

#define RD(a) z->rd(z->ctx, (uint16_t)(a))
#define WR(a, v) z->wr(z->ctx, (uint16_t)(a), (uint8_t)(v))
#define BC ((uint16_t)((z->b << 8) | z->c))
#define DE ((uint16_t)((z->d << 8) | z->e))
#define HL ((uint16_t)((z->h << 8) | z->l))
#define SETBC(v) do { uint16_t _v = (v); z->b = _v >> 8; z->c = (uint8_t)_v; } while (0)
#define SETDE(v) do { uint16_t _v = (v); z->d = _v >> 8; z->e = (uint8_t)_v; } while (0)
#define SETHL(v) do { uint16_t _v = (v); z->h = _v >> 8; z->l = (uint8_t)_v; } while (0)

static inline uint8_t fetch(Z80 *z) { return RD(z->pc++); }
static inline uint16_t fetch16(Z80 *z) { uint8_t lo = RD(z->pc++); return lo | (RD(z->pc++) << 8); }
static inline void push16(Z80 *z, uint16_t v) { z->sp--; WR(z->sp, v >> 8); z->sp--; WR(z->sp, v & 0xFF); }
static inline uint16_t pop16(Z80 *z) { uint8_t lo = RD(z->sp++); return lo | (RD(z->sp++) << 8); }
static inline void inc_r(Z80 *z) { z->r = (z->r & 0x80) | ((z->r + 1) & 0x7F); }

void z80_reset(Z80 *z) {
    if (!tables_done) mk_tables();
    z->pc = 0; z->sp = 0xFFFF; z->a = z->f = 0xFF; z->i = z->r = 0;
    z->iff1 = z->iff2 = 0; z->im = 0; z->halted = 0; z->ix = z->iy = 0xFFFF;
}

/* ---------- ALU */
static inline void add8(Z80 *z, uint8_t v, int cy) {
    int r = z->a + v + cy;
    uint8_t res = (uint8_t)r;
    z->f = sz53[res] | (r > 0xFF ? FC : 0) | ((z->a ^ v ^ res) & FH) |
           (((z->a ^ ~v) & (z->a ^ res) & 0x80) ? FP : 0);
    z->a = res;
}
static inline void sub8(Z80 *z, uint8_t v, int cy, int store) {
    int r = z->a - v - cy;
    uint8_t res = (uint8_t)r;
    uint8_t f = (res ? 0 : FZ) | (res & FS) | FN | (r < 0 ? FC : 0) | ((z->a ^ v ^ res) & FH) |
                (((z->a ^ v) & (z->a ^ res) & 0x80) ? FP : 0);
    if (store) { f |= res & (FX | FY); z->a = res; }
    else f |= v & (FX | FY);
    z->f = f;
}
static inline void and8(Z80 *z, uint8_t v) { z->a &= v; z->f = sz53p[z->a] | FH; }
static inline void xor8(Z80 *z, uint8_t v) { z->a ^= v; z->f = sz53p[z->a]; }
static inline void or8(Z80 *z, uint8_t v) { z->a |= v; z->f = sz53p[z->a]; }
static void alu(Z80 *z, int op, uint8_t v) {
    switch (op) {
    case 0: add8(z, v, 0); break;
    case 1: add8(z, v, z->f & FC); break;
    case 2: sub8(z, v, 0, 1); break;
    case 3: sub8(z, v, z->f & FC, 1); break;
    case 4: and8(z, v); break;
    case 5: xor8(z, v); break;
    case 6: or8(z, v); break;
    case 7: sub8(z, v, 0, 0); break;
    }
}
static inline uint8_t inc8(Z80 *z, uint8_t v) {
    uint8_t r = v + 1;
    z->f = (z->f & FC) | sz53[r] | ((v & 0x0F) == 0x0F ? FH : 0) | (v == 0x7F ? FP : 0);
    return r;
}
static inline uint8_t dec8(Z80 *z, uint8_t v) {
    uint8_t r = v - 1;
    z->f = (z->f & FC) | sz53[r] | FN | ((v & 0x0F) == 0 ? FH : 0) | (v == 0x80 ? FP : 0);
    return r;
}
static uint16_t add16(Z80 *z, uint16_t a, uint16_t b) {
    uint32_t r = a + b;
    z->f = (z->f & (FS | FZ | FP)) | ((r >> 8) & (FX | FY)) | (r > 0xFFFF ? FC : 0) |
           (((a ^ b ^ r) >> 8) & FH);
    return (uint16_t)r;
}
static uint16_t adc16(Z80 *z, uint16_t a, uint16_t b) {
    uint32_t r = a + b + (z->f & FC);
    uint16_t res = (uint16_t)r;
    z->f = ((res >> 8) & (FS | FX | FY)) | (res ? 0 : FZ) | (r > 0xFFFF ? FC : 0) |
           (((a ^ b ^ r) >> 8) & FH) | ((((a ^ ~b) & (a ^ res)) & 0x8000) ? FP : 0);
    return res;
}
static uint16_t sbc16(Z80 *z, uint16_t a, uint16_t b) {
    int32_t r = (int32_t)a - b - (z->f & FC);
    uint16_t res = (uint16_t)r;
    z->f = ((res >> 8) & (FS | FX | FY)) | (res ? 0 : FZ) | (r < 0 ? FC : 0) | FN |
           (((a ^ b ^ res) >> 8) & FH) | ((((a ^ b) & (a ^ res)) & 0x8000) ? FP : 0);
    return res;
}
static uint8_t rot(Z80 *z, int op, uint8_t v) {
    uint8_t c;
    switch (op) {
    case 0: c = v >> 7; v = (v << 1) | c; break;                 /* RLC */
    case 1: c = v & 1; v = (v >> 1) | (c << 7); break;           /* RRC */
    case 2: c = v >> 7; v = (v << 1) | (z->f & FC); break;       /* RL */
    case 3: c = v & 1; v = (v >> 1) | ((z->f & FC) << 7); break; /* RR */
    case 4: c = v >> 7; v = v << 1; break;                       /* SLA */
    case 5: c = v & 1; v = (v >> 1) | (v & 0x80); break;         /* SRA */
    case 6: c = v >> 7; v = (v << 1) | 1; break;                 /* SLL */
    default: c = v & 1; v = v >> 1; break;                       /* SRL */
    }
    z->f = sz53p[v] | c;
    return v;
}
static void bit_(Z80 *z, int b, uint8_t v, uint8_t xy) {
    uint8_t r = v & (1 << b);
    z->f = (z->f & FC) | FH | (xy & (FX | FY)) | (r ? 0 : (FZ | FP)) | (r & FS);
}
static void daa(Z80 *z) {
    uint8_t a = z->a, corr = 0, c = z->f & FC;
    if ((z->f & FH) || (a & 0x0F) > 9) corr |= 0x06;
    if (c || a > 0x99) { corr |= 0x60; c = FC; }
    uint8_t res, h;
    if (z->f & FN) { res = a - corr; h = ((z->f & FH) && (a & 0x0F) < 6) ? FH : 0; }
    else { res = a + corr; h = ((a & 0x0F) > 9) ? FH : 0; }
    z->a = res;
    z->f = sz53p[res] | (z->f & FN) | c | h;
}

/* ---------- register access with index prefix: idx 0 = HL, 1 = IX, 2 = IY */
static inline uint8_t get_r(Z80 *z, int r, int idx) {
    switch (r) {
    case 0: return z->b; case 1: return z->c; case 2: return z->d; case 3: return z->e;
    case 4: return idx == 0 ? z->h : idx == 1 ? (z->ix >> 8) : (z->iy >> 8);
    case 5: return idx == 0 ? z->l : idx == 1 ? (z->ix & 0xFF) : (z->iy & 0xFF);
    case 7: return z->a;
    }
    return 0;
}
static inline void set_r(Z80 *z, int r, int idx, uint8_t v) {
    switch (r) {
    case 0: z->b = v; break; case 1: z->c = v; break; case 2: z->d = v; break; case 3: z->e = v; break;
    case 4: if (idx == 0) z->h = v; else if (idx == 1) z->ix = (z->ix & 0xFF) | (v << 8); else z->iy = (z->iy & 0xFF) | (v << 8); break;
    case 5: if (idx == 0) z->l = v; else if (idx == 1) z->ix = (z->ix & 0xFF00) | v; else z->iy = (z->iy & 0xFF00) | v; break;
    case 7: z->a = v; break;
    }
}
static inline uint16_t get_rp(Z80 *z, int p, int idx) {
    switch (p) {
    case 0: return BC; case 1: return DE;
    case 2: return idx == 0 ? HL : idx == 1 ? z->ix : z->iy;
    default: return z->sp;
    }
}
static inline void set_rp(Z80 *z, int p, int idx, uint16_t v) {
    switch (p) {
    case 0: SETBC(v); break; case 1: SETDE(v); break;
    case 2: if (idx == 0) SETHL(v); else if (idx == 1) z->ix = v; else z->iy = v; break;
    default: z->sp = v;
    }
}
static inline int cond(Z80 *z, int y) {
    switch (y) {
    case 0: return !(z->f & FZ); case 1: return z->f & FZ;
    case 2: return !(z->f & FC); case 3: return z->f & FC;
    case 4: return !(z->f & FP); case 5: return z->f & FP;
    case 6: return !(z->f & FS); default: return z->f & FS;
    }
}

static int exec_cb(Z80 *z, int idx, uint16_t addr) {
    /* idx != 0: addr = IX/IY + d already computed, opcode fetched after d */
    uint8_t op = fetch(z);
    int x = op >> 6, y = (op >> 3) & 7, r = op & 7;
    if (idx == 0) inc_r(z);
    if (idx) {
        uint8_t v = RD(addr);
        if (x == 1) { bit_(z, y, v, addr >> 8); return 20; }
        if (x == 0) v = rot(z, y, v);
        else if (x == 2) v &= ~(1 << y);
        else v |= (1 << y);
        WR(addr, v);
        if (r != 6) set_r(z, r, 0, v);
        return 23;
    }
    if (r == 6) {
        uint8_t v = RD(HL);
        if (x == 1) { bit_(z, y, v, z->h); return 12; } /* XY from internal reg approximated */
        if (x == 0) v = rot(z, y, v);
        else if (x == 2) v &= ~(1 << y);
        else v |= (1 << y);
        WR(HL, v);
        return 15;
    }
    uint8_t v = get_r(z, r, 0);
    if (x == 1) { bit_(z, y, v, v); return 8; }
    if (x == 0) v = rot(z, y, v);
    else if (x == 2) v &= ~(1 << y);
    else v |= (1 << y);
    set_r(z, r, 0, v);
    return 8;
}

static int exec_ed(Z80 *z) {
    uint8_t op = fetch(z);
    inc_r(z);
    int x = op >> 6, y = (op >> 3) & 7, zz = op & 7, p = y >> 1, q = y & 1;
    if (x == 1) {
        switch (zz) {
        case 0: { uint8_t v = z->in(z->ctx, BC); if (y != 6) set_r(z, y, 0, v); z->f = (z->f & FC) | sz53p[v]; return 12; }
        case 1: z->out(z->ctx, BC, y == 6 ? 0 : get_r(z, y, 0)); return 12;
        case 2: { uint16_t v = get_rp(z, p, 0); SETHL(q ? adc16(z, HL, v) : sbc16(z, HL, v)); return 15; }
        case 3: { uint16_t a = fetch16(z);
            if (q) { uint8_t lo = RD(a); set_rp(z, p, 0, lo | (RD(a + 1) << 8)); }
            else { uint16_t v = get_rp(z, p, 0); WR(a, v & 0xFF); WR(a + 1, v >> 8); }
            return 20; }
        case 4: { uint8_t v = z->a; z->a = 0; sub8(z, v, 0, 1); return 8; }
        case 5: z->pc = pop16(z); z->iff1 = z->iff2; return 14;
        case 6: z->im = (y & 3) == 0 ? 0 : ((y & 3) == 2 ? 1 : 2); if ((y & 3) == 1) z->im = 0; return 8;
        case 7:
            switch (y) {
            case 0: z->i = z->a; return 9;
            case 1: z->r = z->a; return 9;
            case 2: z->a = z->i; z->f = (z->f & FC) | sz53[z->a] | (z->iff2 ? FP : 0); return 9;
            case 3: z->a = z->r; z->f = (z->f & FC) | sz53[z->a] | (z->iff2 ? FP : 0); return 9;
            case 4: { uint8_t m = RD(HL); WR(HL, (z->a << 4) | (m >> 4)); z->a = (z->a & 0xF0) | (m & 0x0F); z->f = (z->f & FC) | sz53p[z->a]; return 18; }
            case 5: { uint8_t m = RD(HL); WR(HL, (m << 4) | (z->a & 0x0F)); z->a = (z->a & 0xF0) | (m >> 4); z->f = (z->f & FC) | sz53p[z->a]; return 18; }
            default: return 8;
            }
        }
    }
    if (x == 2 && y >= 4 && zz <= 3) {
        int dec = y & 1, rep = y >= 6;
        int t = 16;
        switch (zz) {
        case 0: { /* LDI/LDD */
            uint8_t v = RD(HL); WR(DE, v);
            SETHL(HL + (dec ? -1 : 1)); SETDE(DE + (dec ? -1 : 1)); SETBC(BC - 1);
            uint8_t n = v + z->a;
            z->f = (z->f & (FS | FZ | FC)) | (BC ? FP : 0) | (n & FX) | ((n << 4) & FY);
            if (rep && BC) { z->pc -= 2; t = 21; }
            return t; }
        case 1: { /* CPI/CPD */
            uint8_t v = RD(HL); uint8_t res = z->a - v;
            uint8_t h = (z->a ^ v ^ res) & FH;
            SETHL(HL + (dec ? -1 : 1)); SETBC(BC - 1);
            uint8_t n = res - (h ? 1 : 0);
            z->f = (z->f & FC) | (res & FS) | (res ? 0 : FZ) | h | FN | (BC ? FP : 0) | (n & FX) | ((n << 4) & FY);
            if (rep && BC && res) { z->pc -= 2; t = 21; }
            return t; }
        case 2: { /* INI/IND */
            uint8_t v = z->in(z->ctx, BC); WR(HL, v); z->b--; SETHL(HL + (dec ? -1 : 1));
            z->f = sz53[z->b] | FN;
            if (rep && z->b) { z->pc -= 2; t = 21; }
            return t; }
        case 3: { /* OUTI/OUTD */
            uint8_t v = RD(HL); z->b--; z->out(z->ctx, BC, v); SETHL(HL + (dec ? -1 : 1));
            z->f = sz53[z->b] | FN;
            if (rep && z->b) { z->pc -= 2; t = 21; }
            return t; }
        }
    }
    return 8; /* NONI */
}

int z80_step(Z80 *z) {
    z->ei_pending = 0;
    if (z->halted) { inc_r(z); return 4; }
    int idx = 0, t = 0;
    uint8_t op;
    for (;;) {
        op = fetch(z);
        inc_r(z);
        if (op == 0xDD) { idx = 1; t += 4; continue; }
        if (op == 0xFD) { idx = 2; t += 4; continue; }
        break;
    }
    if (op == 0xED) return t + exec_ed(z);
    if (op == 0xCB) {
        if (idx) {
            int8_t d = (int8_t)fetch(z);
            uint16_t a = (idx == 1 ? z->ix : z->iy) + d;
            return t - 4 + exec_cb(z, idx, a) ;
        }
        return exec_cb(z, 0, 0);
    }
    int x = op >> 6, y = (op >> 3) & 7, zz = op & 7, p = y >> 1, q = y & 1;
    uint16_t ireg = idx == 1 ? z->ix : z->iy;

    if (x == 1) {
        if (op == 0x76) { z->halted = 1; return t + 4; }
        if (y == 6) { /* LD (HL),r */
            if (idx) { int8_t d = (int8_t)fetch(z); WR(ireg + d, get_r(z, zz, 0)); return t + 15; }
            WR(HL, get_r(z, zz, 0)); return 7;
        }
        if (zz == 6) {
            if (idx) { int8_t d = (int8_t)fetch(z); set_r(z, y, 0, RD(ireg + d)); return t + 15; }
            set_r(z, y, 0, RD(HL)); return 7;
        }
        set_r(z, y, idx, get_r(z, zz, idx));
        return t + 4;
    }
    if (x == 2) {
        if (zz == 6) {
            if (idx) { int8_t d = (int8_t)fetch(z); alu(z, y, RD(ireg + d)); return t + 15; }
            alu(z, y, RD(HL)); return 7;
        }
        alu(z, y, get_r(z, zz, idx));
        return t + 4;
    }
    if (x == 0) {
        switch (zz) {
        case 0:
            switch (y) {
            case 0: return t + 4;
            case 1: { uint8_t ta = z->a, tf = z->f; z->a = z->a_; z->f = z->f_; z->a_ = ta; z->f_ = tf; return t + 4; }
            case 2: { int8_t d = (int8_t)fetch(z); if (--z->b) { z->pc += d; return t + 13; } return t + 8; }
            case 3: { int8_t d = (int8_t)fetch(z); z->pc += d; return t + 12; }
            default: { int8_t d = (int8_t)fetch(z); if (cond(z, y - 4)) { z->pc += d; return t + 12; } return t + 7; }
            }
        case 1:
            if (!q) { set_rp(z, p, idx, fetch16(z)); return t + 10; }
            set_rp(z, 2, idx, add16(z, get_rp(z, 2, idx), get_rp(z, p, idx))); return t + 11;
        case 2:
            switch (y) {
            case 0: WR(BC, z->a); return 7;
            case 1: z->a = RD(BC); return 7;
            case 2: WR(DE, z->a); return 7;
            case 3: z->a = RD(DE); return 7;
            case 4: { uint16_t a = fetch16(z); uint16_t v = get_rp(z, 2, idx); WR(a, v & 0xFF); WR(a + 1, v >> 8); return t + 16; }
            case 5: { uint16_t a = fetch16(z); uint8_t lo = RD(a); set_rp(z, 2, idx, lo | (RD(a + 1) << 8)); return t + 16; }
            case 6: { uint16_t a = fetch16(z); WR(a, z->a); return 13; }
            default: { uint16_t a = fetch16(z); z->a = RD(a); return 13; }
            }
        case 3:
            set_rp(z, p, idx, get_rp(z, p, idx) + (q ? -1 : 1)); return t + 6;
        case 4: case 5:
            if (y == 6) {
                uint16_t a; int tt = 11;
                if (idx) { int8_t d = (int8_t)fetch(z); a = ireg + d; tt = 19; } else a = HL;
                uint8_t v = RD(a);
                WR(a, zz == 4 ? inc8(z, v) : dec8(z, v));
                return t + tt;
            }
            set_r(z, y, idx, zz == 4 ? inc8(z, get_r(z, y, idx)) : dec8(z, get_r(z, y, idx)));
            return t + 4;
        case 6:
            if (y == 6) {
                if (idx) { int8_t d = (int8_t)fetch(z); uint8_t n = fetch(z); WR(ireg + d, n); return t + 15; }
                WR(HL, fetch(z)); return 10;
            }
            set_r(z, y, idx, fetch(z)); return t + 7;
        case 7:
            switch (y) {
            case 0: { uint8_t c = z->a >> 7; z->a = (z->a << 1) | c; z->f = (z->f & (FS | FZ | FP)) | (z->a & (FX | FY)) | c; return 4; }
            case 1: { uint8_t c = z->a & 1; z->a = (z->a >> 1) | (c << 7); z->f = (z->f & (FS | FZ | FP)) | (z->a & (FX | FY)) | c; return 4; }
            case 2: { uint8_t c = z->a >> 7; z->a = (z->a << 1) | (z->f & FC); z->f = (z->f & (FS | FZ | FP)) | (z->a & (FX | FY)) | c; return 4; }
            case 3: { uint8_t c = z->a & 1; z->a = (z->a >> 1) | ((z->f & FC) << 7); z->f = (z->f & (FS | FZ | FP)) | (z->a & (FX | FY)) | c; return 4; }
            case 4: daa(z); return 4;
            case 5: z->a = ~z->a; z->f = (z->f & (FS | FZ | FP | FC)) | FH | FN | (z->a & (FX | FY)); return 4;
            case 6: z->f = (z->f & (FS | FZ | FP)) | (z->a & (FX | FY)) | FC; return 4;
            default: z->f = ((z->f & (FS | FZ | FP | FC)) | ((z->f & FC) ? FH : 0) | (z->a & (FX | FY))) ^ FC; return 4;
            }
        }
    }
    /* x == 3 */
    switch (zz) {
    case 0: if (cond(z, y)) { z->pc = pop16(z); return t + 11; } return t + 5;
    case 1:
        if (!q) { uint16_t v = pop16(z); if (p == 3) { z->a = v >> 8; z->f = v & 0xFF; } else set_rp(z, p, idx, v); return t + 10; }
        switch (p) {
        case 0: z->pc = pop16(z); return 10;
        case 1: { uint8_t tb = z->b, tc = z->c, td = z->d, te = z->e, th = z->h, tl = z->l;
            z->b = z->b_; z->c = z->c_; z->d = z->d_; z->e = z->e_; z->h = z->h_; z->l = z->l_;
            z->b_ = tb; z->c_ = tc; z->d_ = td; z->e_ = te; z->h_ = th; z->l_ = tl; return 4; }
        case 2: z->pc = get_rp(z, 2, idx); return t + 4;
        default: z->sp = get_rp(z, 2, idx); return t + 6;
        }
    case 2: { uint16_t a = fetch16(z); if (cond(z, y)) z->pc = a; return 10; }
    case 3:
        switch (y) {
        case 0: z->pc = fetch16(z); return 10;
        case 2: { uint8_t n = fetch(z); z->out(z->ctx, (z->a << 8) | n, z->a); return 11; }
        case 3: { uint8_t n = fetch(z); z->a = z->in(z->ctx, (z->a << 8) | n); return 11; }
        case 4: { uint16_t v = get_rp(z, 2, idx); uint8_t lo = RD(z->sp), hi = RD(z->sp + 1);
            WR(z->sp, v & 0xFF); WR(z->sp + 1, v >> 8); set_rp(z, 2, idx, lo | (hi << 8)); return t + 19; }
        case 5: { uint16_t v = DE; SETDE(HL); SETHL(v); return 4; }
        case 6: z->iff1 = z->iff2 = 0; return 4;
        default: z->iff1 = z->iff2 = 1; z->ei_pending = 1; return 4;
        }
    case 4: { uint16_t a = fetch16(z); if (cond(z, y)) { push16(z, z->pc); z->pc = a; return 17; } return 10; }
    case 5:
        if (!q) { uint16_t v = p == 3 ? ((z->a << 8) | z->f) : get_rp(z, p, idx); push16(z, v); return t + 11; }
        if (p == 0) { uint16_t a = fetch16(z); push16(z, z->pc); z->pc = a; return 17; }
        return t + 4; /* DD/ED/FD handled above */
    case 6: alu(z, y, fetch(z)); return 7;
    default: push16(z, z->pc); z->pc = y * 8; return 11;
    }
}

/* maskable interrupt: returns T-states taken, 0 if not accepted */
int z80_irq(Z80 *z, uint8_t vec) {
    if (!z->iff1 || z->ei_pending) return 0;
    z->halted = 0;
    z->iff1 = z->iff2 = 0;
    inc_r(z);
    z->sp -= 2;
    z->wr(z->ctx, z->sp, z->pc & 255);
    z->wr(z->ctx, (uint16_t)(z->sp + 1), z->pc >> 8);
    if (z->im == 2) {
        uint16_t a = (uint16_t)((z->i << 8) | (vec & 0xFE));
        z->pc = z->rd(z->ctx, a) | (z->rd(z->ctx, (uint16_t)(a + 1)) << 8);
        return 19;
    }
    z->pc = 0x38;
    return 13;
}
