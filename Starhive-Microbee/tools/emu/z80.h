/* Compact Z80 core for the uB-TYPE test model.
   Documented + common undocumented behaviour (IXH/IXL, SLL, DDCB register
   copies, X/Y flags from results). Exact T-states per instruction. */
#ifndef Z80_H
#define Z80_H
#include <stdint.h>

typedef struct Z80 {
    uint8_t a, f, b, c, d, e, h, l;
    uint8_t a_, f_, b_, c_, d_, e_, h_, l_;
    uint16_t ix, iy, sp, pc;
    uint8_t i, r, iff1, iff2, im, halted;
    uint8_t ei_pending;
    void *ctx;
    uint8_t (*rd)(void *ctx, uint16_t a);
    void (*wr)(void *ctx, uint16_t a, uint8_t v);
    uint8_t (*in)(void *ctx, uint16_t p);
    void (*out)(void *ctx, uint16_t p, uint8_t v);
} Z80;

int z80_step(Z80 *z);          /* execute one instruction; returns T-states */
void z80_reset(Z80 *z);
#endif
