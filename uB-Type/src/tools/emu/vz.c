/* VZ300 + BennVenn SRAM test model, enough to run VZ-TYPE as a reference
   (frame timing, gameplay traces and sound for the fidelity comparison).
   * 3.5469 MHz, 312 x 227 T per field; the 6847 field sync (latch bit 7)
     reads 0 for the first 26 lines of each field.
   * 4000-67FF BennVenn SRAM, bank by port 37h (10K banks).
   * 6800-6FFF latch: read = keyboard rows (address bits A0-A7 low select
     rows, data bits 0-5 active low) + bit 7 field sync; write = latch
     (bits 0/5 speaker, 3 mode, 4 colour set).
   * 7000-77FF video RAM; 7800-FFFF RAM. Ports 2Ch-2Eh joystick (absent). */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "z80.h"

#define VZ_FIELD 70824
#define VZ_SYNC 5902   /* 26 lines */

typedef struct {
    Z80 z;
    uint8_t mem[65536];
    uint8_t sram[8][0x2800];
    int bank;
    uint8_t latch;
    uint8_t rows[8];        /* key bits held per row (bit set = held) */
    uint64_t tick;
    uint64_t *spk_t; uint8_t *spk_v; int spk_n, spk_cap;
    uint8_t spk;
    uint8_t bp[65536], watch[65536];
    uint64_t *ev_t; uint16_t *ev_pc; int ev_n, ev_cap;
    int profiling; uint32_t prof[65536];
} V;

static uint8_t vrd(void *c, uint16_t a) {
    V *v = c;
    if (a >= 0x4000 && a < 0x6800) return v->sram[v->bank][a - 0x4000];
    if (a >= 0x6800 && a < 0x7000) {
        uint8_t r = 0x7F;
        for (int i = 0; i < 8; i++) if (!(a & (1 << i))) r &= ~v->rows[i];
        if ((v->tick % VZ_FIELD) >= VZ_SYNC) r |= 0x80;
        return r;
    }
    return v->mem[a];
}
static void vwr(void *c, uint16_t a, uint8_t x) {
    V *v = c;
    if (a < 0x4000) return;
    if (a < 0x6800) { v->sram[v->bank][a - 0x4000] = x; return; }
    if (a < 0x7000) {
        v->latch = x;
        uint8_t s = (x & 1) ? 1 : 0;
        if (s != v->spk) {
            v->spk = s;
            if (v->spk_n >= v->spk_cap) {
                v->spk_cap = v->spk_cap ? v->spk_cap * 2 : 65536;
                v->spk_t = realloc(v->spk_t, v->spk_cap * 8); v->spk_v = realloc(v->spk_v, v->spk_cap);
            }
            v->spk_t[v->spk_n] = v->tick; v->spk_v[v->spk_n++] = s;
        }
        return;
    }
    v->mem[a] = x;
}
static uint8_t vin(void *c, uint16_t p) { (void)c; (void)p; return 0xFF; }
static void vout(void *c, uint16_t p, uint8_t x) {
    V *v = c;
    if ((p & 0xFF) == 0x37) v->bank = x & 7;
}

V *vz_new(void) {
    V *v = calloc(1, sizeof(V));
    v->z.ctx = v; v->z.rd = vrd; v->z.wr = vwr; v->z.in = vin; v->z.out = vout;
    z80_reset(&v->z);
    return v;
}
void vz_free(V *v) { free(v->spk_t); free(v->spk_v); free(v->ev_t); free(v->ev_pc); free(v); }
uint8_t *vz_mem(V *v) { return v->mem; }
uint8_t *vz_sram(V *v, int b) { return v->sram[b]; }
uint8_t vz_latch(V *v) { return v->latch; }
int vz_bank(V *v) { return v->bank; }
Z80 *vz_cpu(V *v) { return &v->z; }
uint64_t vz_tick(V *v) { return v->tick; }
void vz_set_rows(V *v, const uint8_t *r) { memcpy(v->rows, r, 8); }
uint8_t vz_peek(V *v, uint16_t a) { return vrd(v, a); }
void vz_set_bp(V *v, uint16_t a, int on) { v->bp[a] = on; }
void vz_set_watch(V *v, uint16_t a, int on) { v->watch[a] = on; }
int vz_events(V *v, uint64_t **t, uint16_t **pc) { *t = v->ev_t; *pc = v->ev_pc; return v->ev_n; }
void vz_clear_events(V *v) { v->ev_n = 0; }
int vz_spk(V *v, uint64_t **t, uint8_t **s) { *t = v->spk_t; *s = v->spk_v; return v->spk_n; }
void vz_profile(V *v, int on) { v->profiling = on; if (on) memset(v->prof, 0, sizeof v->prof); }
uint32_t *vz_prof(V *v) { return v->prof; }
int vz_run(V *v, uint64_t target) {
    Z80 *z = &v->z;
    while (v->tick < target) {
        uint16_t pc = z->pc;
        if (v->watch[pc]) {
            if (v->ev_n >= v->ev_cap) {
                v->ev_cap = v->ev_cap ? v->ev_cap * 2 : 4096;
                v->ev_t = realloc(v->ev_t, v->ev_cap * 8); v->ev_pc = realloc(v->ev_pc, v->ev_cap * 2);
            }
            v->ev_t[v->ev_n] = v->tick; v->ev_pc[v->ev_n++] = pc;
        }
        int t = z80_step(z);
        v->tick += t;
        if (v->profiling) v->prof[pc] += t;
        if (v->bp[z->pc]) return 1;
    }
    return 0;
}
