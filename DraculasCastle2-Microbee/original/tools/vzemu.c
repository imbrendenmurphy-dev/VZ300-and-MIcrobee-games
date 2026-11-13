/* vzemu - headless VZ300 test harness (Z80 + BennVenn SRAM model)
 * For automated testing of Dracula's Castle II.
 *   vzemu file.vz [options]
 *   -f N        run N frames
 *   -k F:KEY:LEN[,..]  press KEY at frame F for LEN frames (KEY = A..Z 0..9 SPACE RET CTRL SHIFT , . - ; :)
 *   -j F:BITS:LEN  joystick bits (active-high mask: 1 up 2 down 4 left 8 right 16 fire)
 *   -d F[,F..]  dump VRAM+latch at frames into outdir/fNNNNN.bin
 *   -o DIR      output dir
 *   -w FILE     write speaker audio as WAV (22050 Hz)
 *   -q          quiet
 * Reports: VRAM accesses during active display ("snow"), debug port $F0 markers.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef uint8_t u8; typedef uint16_t u16; typedef uint32_t u32; typedef int8_t s8;

/* ---------------- machine ---------------- */
static u8 ram[65536];
static unsigned short PC; static unsigned short SP;
static u8 sram[4][0x2800];   /* banks for $4000-$67FF */
static int mapping = 1;      /* port $37 value */
static u8 latch = 0;
static u8 keymat[8];          /* bit set = key down (row by address bit) */
static u8 joy = 0;
static long long T = 0;       /* total T states */
static const int TLINE = 227, LINES = 312;
#define TFRAME (TLINE*LINES)
static const int FS_LINES = 56, ACT_START = 80, ACT_LINES = 192;
static long snow_count = 0, snow_frame = 0, border_writes = 0;
static int frame_no = 0;
static int dos_clobbered = 0;
static int quiet = 0;
static long rom_exec = 0;
static unsigned long long prof[65536]; static int profiling = 0;
static const char *sddir = NULL; static FILE *sdf = NULL; static long dos_calls = 0, dos_ram_writes = 0, sys_writes = 0;
static int started = 0;
static u16 pchist[256]; static int pch = 0; static int watch = -1;

static int cur_line(void) { return (int)((T % TFRAME) / TLINE); }

static int sram_bank(void) { return (mapping & 2) ? 3 : 1; }

static void vram_access(int w) {
    int l = cur_line();
    if (l >= ACT_START && l < ACT_START + ACT_LINES) { if (!snow_frame && !quiet) { printf("[snow] frame %d line %d pc %04X stack", frame_no, l, PC); for (int q = 0; q < 12; q += 2) printf(" %04X", ram[(u16)(SP+q)] | (ram[(u16)(SP+q+1)] << 8)); printf("\n"); } snow_count++; snow_frame++; }
    else if (w && l >= FS_LINES) border_writes++;
}

static u8 rd(u16 a) {
    if (a < 0x4000) return 0xFF;
    if (a < 0x6800) {
        if (!(mapping & 1)) return 0xFF;
        return sram[sram_bank()][a - 0x4000];
    }
    if (a < 0x7000) {
        u8 v = 0x7F; /* bits 0-5 keys (active low), bit6 cassette in */
        for (int r = 0; r < 8; r++) if (!(a & (1 << r))) v &= ~keymat[r];
        int l = cur_line();
        if (l >= FS_LINES) v |= 0x80; /* FS high outside vsync */
        return v;
    }
    if (a < 0x7800) vram_access(0);
    return ram[a];
}
static void wr(u16 a, u8 v) {
    if (started && a >= 0xFA00 && a != 0xFB80 && a != 0xFB81) { if (!dos_ram_writes++ && !quiet) printf("!! write to DOS RAM %04X pc %04X\n", a, PC); }
    if (started && a >= 0x7800 && a < 0x7AE8) { if (!sys_writes++ && !quiet) printf("!! write to system area %04X pc %04X\n", a, PC); }
    if (a == watch) printf("[watch %04X] = %02X  frame %d pc %04X ret %04X\n", a, v, frame_no, PC, ram[SP] | (ram[(u16)(SP+1)] << 8)); if (a == watch) printf("   ret2 %04X ret3 %04X\n", ram[(u16)(SP+2)] | (ram[(u16)(SP+3)] << 8), ram[(u16)(SP+4)] | (ram[(u16)(SP+5)] << 8));
    if (a < 0x4000) return;
    if (a < 0x6800) {
        if (!(mapping & 1)) return;
        if (sram_bank() == 1) dos_clobbered++;
        sram[sram_bank()][a - 0x4000] = v; return;
    }
    if (a < 0x7000) { latch = v; return; }
    if (a < 0x7800) vram_access(1);
    ram[a] = v;
}

/* audio */
static FILE *wavf = NULL; static long long next_sample_T = 0; static long wav_samples = 0;
static const double CPU_HZ = 3546900.0; static const int SRATE = 22050;
static double spk_acc = 0; static long long spk_lastT = 0;
static int spk_level(void) { int p = (latch >> 5) & 1, m = latch & 1; return p - m; }
static void audio_advance(void) {
    if (!wavf) return;
    while (T >= next_sample_T) {
        short s = (short)(spk_level() * 8000);
        fwrite(&s, 2, 1, wavf); wav_samples++;
        next_sample_T = (long long)((wav_samples + 1) * CPU_HZ / SRATE);
    }
}

static u8 in_port(u16 p) {
    u8 lo = p & 0xFF;
    if (lo >= 0x20 && lo <= 0x2F) { /* joystick: active low */
        u8 v = 0xFF;
        if (!(lo & 1)) v &= ~(joy & 0x1F); /* treat as J1 */
        return v;
    }
    return 0xFF;
}
static void out_port(u16 p, u8 v) {
    u8 lo = p & 0xFF;
    if (lo == 0x37) { mapping = v; return; }
    if (lo == 0xF0) { if (!quiet) printf("[mark %02X] frame %d line %d T=%lld\n", v, frame_no, cur_line(), T); return; }
    if (lo == 0xF1) { printf("[dbg %02X] frame %d\n", v, frame_no); return; }
}

/* ---------------- Z80 ---------------- */
static u8 A, F, B, C, D, E, H, L, A_, F_, B_, C_, D_, E_, H_, L_, I, R;
static u16 IX, IY; static int IFF1, IFF2, IMODE, halted;
#define FC 1
#define FN 2
#define FP 4
#define F3 8
#define FH 16
#define F5 32
#define FZ 64
#define FS 128
static u8 sz53p[256], sz53[256], parity[256];
static void init_tables(void) {
    for (int i = 0; i < 256; i++) {
        int p = 0; for (int b = 0; b < 8; b++) p ^= (i >> b) & 1;
        parity[i] = p ? 0 : FP;
        sz53[i] = (i & (FS | F3 | F5)) | (i ? 0 : FZ);
        sz53p[i] = sz53[i] | parity[i];
    }
}
#define BC_ ((B<<8)|C)
#define DE_ ((D<<8)|E)
#define HL_ ((H<<8)|L)
static inline u8 fetch(void) { u8 v = rd(PC); PC++; return v; }
static inline u16 fetch16(void) { u8 l = fetch(); u8 h = fetch(); return l | (h << 8); }
static inline u16 rd16(u16 a) { return rd(a) | (rd(a + 1) << 8); }
static inline void wr16(u16 a, u16 v) { wr(a, v & 255); wr(a + 1, v >> 8); }
static inline void push(u16 v) { SP -= 2; wr16(SP, v); }
static inline u16 pop(void) { u16 v = rd16(SP); SP += 2; return v; }

static void add8(u8 v, int c) { int r = A + v + c; F = ((r >> 8) & FC) | sz53[r & 255] | ((A ^ v ^ r) & FH) | ((((A ^ ~v) & (A ^ r)) & 0x80) ? FP : 0); A = r; }
static void sub8(u8 v, int c) { int r = A - v - c; F = ((r >> 8) & FC) | FN | sz53[r & 255] | ((A ^ v ^ r) & FH) | ((((A ^ v) & (A ^ r)) & 0x80) ? FP : 0); A = r; }
static void cp8(u8 v) { int r = A - v; F = ((r >> 8) & FC) | FN | (sz53[r & 255] & ~(F3 | F5)) | (v & (F3 | F5)) | ((A ^ v ^ r) & FH) | ((((A ^ v) & (A ^ r)) & 0x80) ? FP : 0); }
static void and8(u8 v) { A &= v; F = sz53p[A] | FH; }
static void or8(u8 v) { A |= v; F = sz53p[A]; }
static void xor8(u8 v) { A ^= v; F = sz53p[A]; }
static void alu(int op, u8 v) {
    switch (op) { case 0: add8(v, 0); break; case 1: add8(v, F & FC); break; case 2: sub8(v, 0); break; case 3: sub8(v, F & FC); break;
    case 4: and8(v); break; case 5: xor8(v); break; case 6: or8(v); break; case 7: cp8(v); break; }
}
static u8 inc8(u8 v) { u8 r = v + 1; F = (F & FC) | sz53[r] | ((v & 0xF) == 0xF ? FH : 0) | (v == 0x7F ? FP : 0); return r; }
static u8 dec8(u8 v) { u8 r = v - 1; F = (F & FC) | FN | sz53[r] | ((v & 0xF) == 0 ? FH : 0) | (v == 0x80 ? FP : 0); return r; }
static u16 add16(u16 a, u16 b) { u32 r = a + b; F = (F & (FS | FZ | FP)) | ((r >> 16) & FC) | (((a ^ b ^ r) >> 8) & FH) | ((r >> 8) & (F3 | F5)); return r; }
static u16 adc16(u16 a, u16 b) { u32 r = a + b + (F & FC); F = ((r >> 16) & FC) | (((a ^ b ^ r) >> 8) & FH) | ((r >> 8) & (FS | F3 | F5)) | ((r & 0xFFFF) ? 0 : FZ) | ((((a ^ ~b) & (a ^ r)) & 0x8000) ? FP : 0); return r; }
static u16 sbc16(u16 a, u16 b) { u32 r = a - b - (F & FC); F = FN | ((r >> 16) & FC) | (((a ^ b ^ r) >> 8) & FH) | ((r >> 8) & (FS | F3 | F5)) | ((r & 0xFFFF) ? 0 : FZ) | ((((a ^ b) & (a ^ r)) & 0x8000) ? FP : 0); return r; }
static u8 rot(int op, u8 v) {
    u8 r; int c;
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
    F = sz53p[r] | c; return r;
}
static u8 getr(int r) { switch (r) { case 0: return B; case 1: return C; case 2: return D; case 3: return E; case 4: return H; case 5: return L; case 6: return rd(HL_); default: return A; } }
static void setr(int r, u8 v) { switch (r) { case 0: B = v; break; case 1: C = v; break; case 2: D = v; break; case 3: E = v; break; case 4: H = v; break; case 5: L = v; break; case 6: wr(HL_, v); break; default: A = v; } }
static int cond(int c) { switch (c) { case 0: return !(F & FZ); case 1: return F & FZ; case 2: return !(F & FC); case 3: return F & FC; case 4: return !(F & FP); case 5: return F & FP; case 6: return !(F & FS); default: return F & FS; } }
static u16 getrp(int p) { switch (p) { case 0: return BC_; case 1: return DE_; case 2: return HL_; default: return SP; } }
static void setrp(int p, u16 v) { switch (p) { case 0: B = v >> 8; C = v; break; case 1: D = v >> 8; E = v; break; case 2: H = v >> 8; L = v; break; default: SP = v; } }

static const u8 cyc_main[256] = {
 4,10,7,6,4,4,7,4,4,11,7,6,4,4,7,4, 8,10,7,6,4,4,7,4,12,11,7,6,4,4,7,4,
 7,10,16,6,4,4,7,4,7,11,16,6,4,4,7,4, 7,10,13,6,11,11,10,4,7,11,13,6,4,4,7,4,
 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4,
 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 7,7,7,7,7,7,4,7,4,4,4,4,4,4,7,4,
 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4,
 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4, 4,4,4,4,4,4,7,4,4,4,4,4,4,4,7,4,
 5,10,10,10,10,11,7,11,5,10,10,0,10,17,7,11, 5,10,10,11,10,11,7,11,5,4,10,11,10,0,7,11,
 5,10,10,19,10,11,7,11,5,4,10,4,10,0,7,11, 5,10,10,4,10,11,7,11,5,6,10,4,10,0,7,11 };

static int step_ed(void) {
    u8 op = fetch(); R = (R & 0x80) | ((R + 1) & 0x7F);
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    if (x == 1) {
        switch (z) {
        case 0: { u8 v = in_port(BC_); if (y != 6) setr(y, v); F = (F & FC) | sz53p[v]; return 12; }
        case 1: out_port(BC_, y == 6 ? 0 : getr(y)); return 12;
        case 2: { u16 h = HL_; u16 r = q ? adc16(h, getrp(p)) : sbc16(h, getrp(p)); H = r >> 8; L = r; return 15; }
        case 3: { u16 a = fetch16(); if (q) setrp(p, rd16(a)); else wr16(a, getrp(p)); return 20; }
        case 4: { u8 v = A; A = 0; sub8(v, 0); return 8; }
        case 5: PC = pop(); IFF1 = IFF2; return 14;
        case 6: IMODE = (y & 3) == 0 ? 0 : ((y & 3) == 2 ? 1 : 2); return 8;
        case 7:
            switch (y) {
            case 0: I = A; return 9;
            case 1: R = A; return 9;
            case 2: A = I; F = (F & FC) | sz53[A] | (IFF2 ? FP : 0); return 9;
            case 3: A = R; F = (F & FC) | sz53[A] | (IFF2 ? FP : 0); return 9;
            case 4: { u8 m = rd(HL_); wr(HL_, (A << 4) | (m >> 4)); A = (A & 0xF0) | (m & 0xF); F = (F & FC) | sz53p[A]; return 18; }
            case 5: { u8 m = rd(HL_); wr(HL_, (m << 4) | (A & 0xF)); A = (A & 0xF0) | (m >> 4); F = (F & FC) | sz53p[A]; return 18; }
            default: return 8;
            }
        }
    }
    if (x == 2 && y >= 4 && z <= 3) {
        int inc = (y & 1) ? -1 : 1, rep = y >= 6;
        u16 hl = HL_, de = DE_, bc = BC_;
        switch (z) {
        case 0: { u8 v = rd(hl); wr(de, v); hl += inc; de += inc; bc--; F = (F & (FS | FZ | FC)) | (bc ? FP : 0);
            H = hl >> 8; L = hl; D = de >> 8; E = de; B = bc >> 8; C = bc;
            if (rep && bc) { PC -= 2; return 21; } return 16; }
        case 1: { u8 v = rd(hl); u8 r = A - v; hl += inc; bc--; F = (F & FC) | FN | (sz53[r] & ~(F3 | F5)) | ((A ^ v ^ r) & FH) | (bc ? FP : 0);
            H = hl >> 8; L = hl; B = bc >> 8; C = bc;
            if (rep && bc && r) { PC -= 2; return 21; } return 16; }
        case 2: { u8 v = in_port(BC_); wr(hl, v); hl += inc; B--; F = (B ? 0 : FZ) | FN; H = hl >> 8; L = hl;
            if (rep && B) { PC -= 2; return 21; } return 16; }
        case 3: { u8 v = rd(hl); B--; out_port(BC_, v); hl += inc; F = (B ? 0 : FZ) | FN; H = hl >> 8; L = hl;
            if (rep && B) { PC -= 2; return 21; } return 16; }
        }
    }
    return 8;
}

/* handle CB with optional index */
static int step_cb(int idx, u16 addr) {
    u8 op;
    if (idx) { op = fetch(); } else { op = fetch(); R = (R & 0x80) | ((R + 1) & 0x7F); }
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    u8 v = idx ? rd(addr) : getr(z);
    u8 r = v;
    switch (x) {
    case 0: r = rot(y, v); break;
    case 1: F = (F & FC) | FH | (sz53p[v & (1 << y)] & ~(F3 | F5)) | (v & (F3 | F5)); if (y == 7 && (v & 0x80)) F |= FS;
        return idx ? 20 : (z == 6 ? 12 : 8);
    case 2: r = v & ~(1 << y); break;
    case 3: r = v | (1 << y); break;
    }
    if (idx) { wr(addr, r); if (z != 6) setr(z, r); return 23; }
    setr(z, r); return z == 6 ? 15 : 8;
}

static int step(void);
static int step_idx(u16 *ix) {
    /* DD/FD prefixed: H/L -> IXH/IXL; (HL) -> (IX+d) */
    u8 op = fetch(); R = (R & 0x80) | ((R + 1) & 0x7F);
    u16 v = *ix;
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7;
    #define IXH (v >> 8)
    #define IXL (v & 255)
    switch (op) {
    case 0x21: *ix = fetch16(); return 14;
    case 0x22: wr16(fetch16(), v); return 20;
    case 0x2A: *ix = rd16(fetch16()); return 20;
    case 0x23: *ix = v + 1; return 10;
    case 0x2B: *ix = v - 1; return 10;
    case 0x09: *ix = add16(v, BC_); return 15;
    case 0x19: *ix = add16(v, DE_); return 15;
    case 0x29: *ix = add16(v, v); return 15;
    case 0x39: *ix = add16(v, SP); return 15;
    case 0xE1: *ix = pop(); return 14;
    case 0xE5: push(v); return 15;
    case 0xE9: PC = v; return 8;
    case 0xF9: SP = v; return 10;
    case 0xE3: { u16 t = rd16(SP); wr16(SP, v); *ix = t; return 23; }
    case 0x34: { s8 d = fetch(); u16 a = v + d; wr(a, inc8(rd(a))); return 23; }
    case 0x35: { s8 d = fetch(); u16 a = v + d; wr(a, dec8(rd(a))); return 23; }
    case 0x36: { s8 d = fetch(); u8 n = fetch(); wr(v + d, n); return 19; }
    case 0x24: *ix = (inc8(IXH) << 8) | IXL; return 8;
    case 0x25: *ix = (dec8(IXH) << 8) | IXL; return 8;
    case 0x2C: *ix = (v & 0xFF00) | inc8(IXL); return 8;
    case 0x2D: *ix = (v & 0xFF00) | dec8(IXL); return 8;
    case 0x26: *ix = (fetch() << 8) | IXL; return 11;
    case 0x2E: *ix = (v & 0xFF00) | fetch(); return 11;
    case 0xCB: { s8 d = fetch(); return step_cb(1, v + d); }
    }
    if (x == 1 && op != 0x76) {
        if (y == 6) { s8 d = fetch(); wr(v + d, getr(z)); return 19; }
        if (z == 6) { s8 d = fetch(); setr(y, rd(v + d)); return 19; }
        /* register moves with IXH/IXL */
        u8 src;
        if (z == 4) src = IXH; else if (z == 5) src = IXL; else src = getr(z);
        if (y == 4) *ix = (src << 8) | (*ix & 255);
        else if (y == 5) *ix = (*ix & 0xFF00) | src;
        else setr(y, src);
        return 8;
    }
    if (x == 2) {
        if (z == 6) { s8 d = fetch(); alu(y, rd(v + d)); return 19; }
        if (z == 4) { alu(y, IXH); return 8; }
        if (z == 5) { alu(y, IXL); return 8; }
    }
    /* otherwise prefix is ignored: execute as normal opcode */
    PC--; R = (R & 0x80) | ((R - 1) & 0x7F);
    return 4 + step();
}

static int step(void) {
    u8 op = fetch(); R = (R & 0x80) | ((R + 1) & 0x7F);
    int x = op >> 6, y = (op >> 3) & 7, z = op & 7, p = y >> 1, q = y & 1;
    int cyc = cyc_main[op];
    switch (x) {
    case 0:
        switch (z) {
        case 0:
            switch (y) {
            case 0: break;
            case 1: { u8 t = A; A = A_; A_ = t; t = F; F = F_; F_ = t; break; }
            case 2: { s8 d = fetch(); B--; if (B) { PC += d; cyc = 13; } break; }
            case 3: { s8 d = fetch(); PC += d; break; }
            default: { s8 d = fetch(); if (cond(y - 4)) { PC += d; cyc = 12; } else cyc = 7; break; }
            }
            break;
        case 1: if (!q) setrp(p, fetch16()); else { u16 r = add16(HL_, getrp(p)); H = r >> 8; L = r; } break;
        case 2:
            switch (y) {
            case 0: wr(BC_, A); break; case 1: A = rd(BC_); break;
            case 2: wr(DE_, A); break; case 3: A = rd(DE_); break;
            case 4: wr16(fetch16(), HL_); break; case 5: { u16 a = fetch16(); L = rd(a); H = rd(a + 1); break; }
            case 6: wr(fetch16(), A); break; case 7: A = rd(fetch16()); break;
            }
            break;
        case 3: setrp(p, getrp(p) + (q ? -1 : 1)); break;
        case 4: setr(y, inc8(getr(y))); if (y == 6) cyc = 11; break;
        case 5: setr(y, dec8(getr(y))); if (y == 6) cyc = 11; break;
        case 6: setr(y, fetch()); if (y == 6) cyc = 10; break;
        case 7:
            switch (y) {
            case 0: { int c = A >> 7; A = (A << 1) | c; F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 1: { int c = A & 1; A = (A >> 1) | (c << 7); F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 2: { int c = A >> 7; A = (A << 1) | (F & FC); F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 3: { int c = A & 1; A = (A >> 1) | ((F & FC) << 7); F = (F & (FS | FZ | FP)) | c | (A & (F3 | F5)); break; }
            case 4: { /* DAA */
                u8 a = A, corr = 0; int c = F & FC;
                if ((F & FH) || (a & 15) > 9) corr |= 6;
                if (c || a > 0x99) { corr |= 0x60; c = 1; }
                if (F & FN) { int h = (F & FH) && (a & 15) < 6; A = a - corr; F = FN | (h ? FH : 0); }
                else { int h = (a & 15) > 9; A = a + corr; F = h ? FH : 0; }
                F |= sz53p[A] | (c ? FC : 0); break; }
            case 5: A = ~A; F = (F & (FS | FZ | FP | FC)) | FH | FN | (A & (F3 | F5)); break;
            case 6: F = (F & (FS | FZ | FP)) | FC | (A & (F3 | F5)); break;
            case 7: F = (F & (FS | FZ | FP)) | ((F & FC) ? FH : FC) | (A & (F3 | F5)); break;
            }
            break;
        }
        break;
    case 1:
        if (op == 0x76) { halted = 1; PC--; break; }
        setr(y, getr(z)); break;
    case 2: alu(y, getr(z)); break;
    case 3:
        switch (z) {
        case 0: if (cond(y)) { PC = pop(); cyc = 11; } break;
        case 1:
            if (!q) { u16 v = pop(); if (p == 3) { A = v >> 8; F = v; } else setrp(p, v); }
            else switch (p) {
                case 0: PC = pop(); break;
                case 1: { u8 t; t = B; B = B_; B_ = t; t = C; C = C_; C_ = t; t = D; D = D_; D_ = t; t = E; E = E_; E_ = t; t = H; H = H_; H_ = t; t = L; L = L_; L_ = t; break; }
                case 2: PC = HL_; break;
                case 3: SP = HL_; break;
            }
            break;
        case 2: { u16 a = fetch16(); if (cond(y)) PC = a; break; }
        case 3:
            switch (y) {
            case 0: PC = fetch16(); break;
            case 1: return step_cb(0, 0);
            case 2: { u8 n = fetch(); out_port((A << 8) | n, A); break; }
            case 3: { u8 n = fetch(); A = in_port((A << 8) | n); break; }
            case 4: { u16 t = rd16(SP); wr16(SP, HL_); H = t >> 8; L = t; break; }
            case 5: { u8 t = D; D = H; H = t; t = E; E = L; L = t; break; }
            case 6: IFF1 = IFF2 = 0; break;
            case 7: IFF1 = IFF2 = 1; break;
            }
            break;
        case 4: { u16 a = fetch16(); if (cond(y)) { push(PC); PC = a; cyc = 17; } break; }
        case 5:
            if (!q) { push(p == 3 ? ((A << 8) | F) : getrp(p)); }
            else switch (p) {
                case 0: { u16 a = fetch16(); push(PC); PC = a; break; }
                case 1: return step_idx(&IX);
                case 2: return step_ed();
                case 3: return step_idx(&IY);
            }
            break;
        case 6: alu(y, fetch()); break;
        case 7: push(PC); PC = y * 8; break;
        }
        break;
    }
    return cyc;
}

static int interrupt_pending(void) { return cur_line() < FS_LINES; }


static int dos_stack = 0;
/* BennVenn DOS model: $5F00 open "NAME" (HL), $5F03 first sector, $5F09 next sector -> (FB80) */
static void dos_read_sector(void) {
    u16 buf = ram[0xFB80] | (ram[0xFB81] << 8);
    u8 sec[512]; memset(sec, 0, 512);
    if (sdf) fread(sec, 1, 512, sdf);
    for (int i = 0; i < 512; i++) { u16 a = buf + i; if (a >= 0x7000 && a < 0x7800) vram_access(1); ram[a] = sec[i]; }
    T += 44000;   /* ~0.6 field per sector, as measured on real hardware */
}
static int dos_trap(void) {
    if (!sddir || !(mapping & 1) || (mapping & 2)) return 0;
    if (PC != 0x5F00 && PC != 0x5F03 && PC != 0x5F09) return 0;
    dos_calls++;
    /* model a DOS that uses lots of stack: trash dos_stack bytes below SP (after the return address) */
    for (int q = 1; q <= dos_stack; q++) ram[(u16)(SP - q)] = 0;
    if (PC == 0x5F00) {
        char name[32]; int n = 0; u16 a = (H << 8) | L;
        if (ram[a] == '"') a++;
        while (ram[a] != '"' && ram[a] && n < 20) name[n++] = ram[a++];
        name[n] = 0;
        char path[512]; snprintf(path, sizeof path, "%s/%s.DAT", sddir, name);
        if (sdf) fclose(sdf);
        sdf = fopen(path, "rb");
        ram[0xFB03] = sdf ? 1 : 0; ram[0xFB05] = 0;
        if (!quiet) printf("[dos] open %s %s frame %d sp %04X\n", name, sdf ? "ok" : "MISSING", frame_no, SP);
        T += 20000;
    } else dos_read_sector();
    PC = pop();
    T += 10;
    return 1;
}

/* ---------------- main ---------------- */
typedef struct { int frame, row, bit, len; } KeyEv;
static KeyEv kev[4096]; static int nkev = 0;
typedef struct { int frame, bits, len; } JoyEv;
static JoyEv jev[1024]; static int njev = 0;

static int keyname(const char *s, int *row, int *bit) {
    static const char *names[8][6] = {
        /* real VZ matrix: index = data bit (bit0 is the LAST key of each row) */
        {"T","W","","E","Q","R"}, {"G","S","CTRL","D","A","F"}, {"B","X","SHIFT","C","Z","V"}, {"5","2","","3","1","4"},
        {"N",".","",",","SPACE","M"}, {"6","9","-","8","0","7"}, {"Y","O","RET","I","P","U"}, {"H","L",":","K",";","J"} };
    for (int r = 0; r < 8; r++) for (int b = 0; b < 6; b++) if (names[r][b][0] && !strcmp(names[r][b], s)) { *row = r; *bit = b; return 1; }
    return 0;
}

int main(int argc, char **argv) {
    const char *memdump = NULL; const char *file = NULL, *outdir = ".", *wavname = NULL; int frames = 100;
    int dumps[4096]; int ndump = 0; int dumpall = 0;
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-f")) frames = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-o")) outdir = argv[++i];
        else if (!strcmp(argv[i], "-w")) wavname = argv[++i];
        else if (!strcmp(argv[i], "-q")) quiet = 1;
        else if (!strcmp(argv[i], "-P")) profiling = 1;
        else if (!strcmp(argv[i], "-s")) sddir = argv[++i];
        else if (!strcmp(argv[i], "-X")) dos_stack = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-W")) watch = strtol(argv[++i], NULL, 16);
        else if (!strcmp(argv[i], "-M")) memdump = argv[++i];
        else if (!strcmp(argv[i], "-D")) dumpall = atoi(argv[++i]);
        else if (!strcmp(argv[i], "-d")) { char *s = strdup(argv[++i]); for (char *t = strtok(s, ","); t; t = strtok(NULL, ",")) dumps[ndump++] = atoi(t); }
        else if (!strcmp(argv[i], "-k")) {
            char *s = strdup(argv[++i]);
            for (char *t = strtok(s, ","); t; t = strtok(NULL, ",")) {
                int f, len; char kn[16];
                if (sscanf(t, "%d:%15[^:]:%d", &f, kn, &len) != 3) { fprintf(stderr, "bad key %s\n", t); return 1; }
                int r, b; if (!keyname(kn, &r, &b)) { fprintf(stderr, "unknown key %s\n", kn); return 1; }
                kev[nkev++] = (KeyEv){f, r, b, len};
            }
        }
        else if (!strcmp(argv[i], "-j")) {
            char *s = strdup(argv[++i]);
            for (char *t = strtok(s, ","); t; t = strtok(NULL, ",")) { int f, bt, len; sscanf(t, "%d:%d:%d", &f, &bt, &len); jev[njev++] = (JoyEv){f, bt, len}; }
        }
        else file = argv[i];
    }
    if (!file) { fprintf(stderr, "usage\n"); return 1; }
    FILE *f = fopen(file, "rb"); if (!f) { perror(file); return 1; }
    u8 hdr[24]; fread(hdr, 1, 24, f);
    u16 start = hdr[22] | (hdr[23] << 8);
    int n = fread(ram + start, 1, 65536 - start, f); fclose(f);
    if (!quiet) printf("loaded %d bytes at %04X type %02X\n", n, start, hdr[21]);
    /* fake DOS in SRAM bank 1 */
    memset(sram[1], 0xC9, sizeof sram[1]);
    memset(sram[3], 0x5A, sizeof sram[3]);
    init_tables();
    PC = start; SP = 0x7FF0; IFF1 = IFF2 = 0; IMODE = 1; latch = 0;
    ram[0x7FF0] = 0;
    started = 1;
    if (wavname) { wavf = fopen(wavname, "wb"); fseek(wavf, 44, SEEK_SET); }
    long long frame_end = TFRAME;
    long snow_total_frames = 0;
    for (frame_no = 0; frame_no < frames; frame_no++) {
        memset(keymat, 0, 8); joy = 0;
        for (int k = 0; k < nkev; k++) if (frame_no >= kev[k].frame && frame_no < kev[k].frame + kev[k].len) keymat[kev[k].row] |= 1 << kev[k].bit;
        for (int k = 0; k < njev; k++) if (frame_no >= jev[k].frame && frame_no < jev[k].frame + jev[k].len) joy |= jev[k].bits;
        snow_frame = 0;
        while (T < frame_end) {
            if (IFF1 && cur_line() < FS_LINES) {
                IFF1 = IFF2 = 0;
                if (halted) { PC++; halted = 0; }
                push(PC);
                if (IMODE == 2) { PC = rd16((I << 8) | 0xFF); T += 19; } else { PC = 0x38; T += 13; }
            }
            if (dos_trap()) continue;
            if (PC < 0x4000) { rom_exec++; if (rom_exec < 2) { printf("!! executing ROM area at %04X frame %d\nhist:", PC, frame_no); for (int q = 0; q < 64; q++) printf(" %04X", pchist[(pch - 64 + q) & 255]); printf("\n"); } if (rom_exec > 1000) { printf("abort: runaway\n"); frame_no = frames; break; } }
            u16 pc0 = PC; pchist[pch++ & 255] = PC;
            int c = step();
            T += c;
            if (profiling) prof[pc0] += c;
            audio_advance();
        }
        frame_end += TFRAME;
        if (snow_frame) snow_total_frames++;
        int dodump = dumpall && (frame_no % dumpall == 0);
        for (int d = 0; d < ndump; d++) if (dumps[d] == frame_no) dodump = 1;
        if (dodump) {
            char fn[512]; snprintf(fn, sizeof fn, "%s/f%05d.bin", outdir, frame_no);
            FILE *o = fopen(fn, "wb"); fwrite(ram + 0x7000, 1, 2048, o); fputc(latch, o); fclose(o);
        }
    }
    if (wavf) {
        long dl = wav_samples * 2; fseek(wavf, 0, SEEK_SET);
        u8 h[44] = {'R','I','F','F',0,0,0,0,'W','A','V','E','f','m','t',' ',16,0,0,0,1,0,1,0,0,0,0,0,0,0,0,0,2,0,16,0,'d','a','t','a'};
        u32 v = 36 + dl; memcpy(h + 4, &v, 4); v = SRATE; memcpy(h + 24, &v, 4); v = SRATE * 2; memcpy(h + 28, &v, 4); v = dl; memcpy(h + 40, &v, 4);
        fwrite(h, 1, 44, wavf); fclose(wavf);
    }
    if (profiling) { FILE *o = fopen("prof.bin", "wb"); fwrite(prof, 8, 65536, o); fclose(o); }
    if (memdump) { FILE *o = fopen(memdump, "wb"); fwrite(ram, 1, 65536, o); fwrite(sram[3], 1, 0x2800, o); fclose(o); }
    printf("frames %d  PC=%04X SP=%04X  snow %ld (in %ld frames)  border-writes %ld  DOS-SRAM writes %d  DOS-RAM writes %ld  sysarea writes %ld  dos calls %ld  mapping %d\n",
        frames, PC, SP, snow_count, snow_total_frames, border_writes, dos_clobbered, dos_ram_writes, sys_writes, dos_calls, mapping);
    return 0;
}
