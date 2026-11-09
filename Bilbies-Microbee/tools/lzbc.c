/* lzbc: fast packer for the LZB format of tools/lzb.py (unpacked on the
   Z80 by unlzb in src/core.asm). Optimal parse over hash-chained matches.
     16-byte table of frequent literals, 16-bit length, bitstream (MSB first):
       0 0 nnnn         literal = table[nnnn]
       0 1 bbbbbbbb     literal byte
       1 <gamma len-1> 0 ooooooo        match, offset 1..128
       1 <gamma len-1> 1 oooooooooooo   match, offset 1..4096
   usage: lzbc in out */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int glen(int v) { int k = 0; while ((1 << k) <= v) k++; return 2 * k - 1; }

static unsigned char out[1 << 20];
static int on, cur, nb;
static void bit(int b) { cur = (cur << 1) | b; if (++nb == 8) { out[on++] = cur; cur = nb = 0; } }
static void bits(int v, int k) { for (int i = k - 1; i >= 0; i--) bit((v >> i) & 1); }
static void gamma_(int v) { int k = 0; while ((1 << k) <= v) k++; bits(0, k - 1); bits(v, k); }

int main(int argc, char **argv) {
    FILE *f = fopen(argv[1], "rb");
    static unsigned char d[1 << 17];
    int n = fread(d, 1, sizeof d, f);
    fclose(f);
    int cnt[256] = {0};
    for (int i = 0; i < n; i++) cnt[d[i]]++;
    int tab[16], tpos[256];
    for (int i = 0; i < 256; i++) tpos[i] = -1;
    for (int k = 0; k < 16; k++) {
        int best = -1;
        for (int b = 0; b < 256; b++) if (tpos[b] < 0 && (best < 0 || cnt[b] > cnt[best])) best = b;
        tab[k] = best; tpos[best] = k;
    }
    /* hash chains of 2-byte prefixes */
    int *head = malloc(65536 * sizeof(int)), *prev = malloc(n * sizeof(int));
    for (int i = 0; i < 65536; i++) head[i] = -1;
    int *cost = malloc((n + 1) * sizeof(int)), *clen = malloc(n * sizeof(int)), *coff = malloc(n * sizeof(int));
    for (int i = 0; i + 1 < n; i++) { int h = d[i] | d[i + 1] << 8; prev[i] = head[h]; head[h] = i; }
    /* positions are chained newest-first; walk backwards for the parse */
    cost[n] = 0;
    for (int i = n - 1; i >= 0; i--) {
        cost[i] = (tpos[d[i]] >= 0 ? 6 : 10) + cost[i + 1]; clen[i] = 0; coff[i] = 0;
        if (i + 1 >= n) continue;
        int steps = 0;
        /* candidates j < i with the same prefix: follow prev from the most recent j before i */
        int h = d[i] | d[i + 1] << 8;
        int j = head[h];
        while (j >= i) j = prev[j];
        for (; j >= 0 && steps < 256; j = prev[j], steps++) {
            int dd = i - j;
            if (dd > 4096) break;
            int l = 0;
            while (i + l < n && d[j + l] == d[i + l] && l < 255) l++;
            int ob = dd <= 128 ? 8 : 13;
            for (int L = 2; L <= l; L = (L < 16 || L == l) ? L + 1 : (L * 2 > l ? l : L * 2)) {
                int c = 1 + glen(L - 1) + ob + cost[i + L];
                if (c < cost[i]) { cost[i] = c; clen[i] = L; coff[i] = dd; }
            }
            if (l == 255 && steps > 8) break;
        }
    }
    for (int k = 0; k < 16; k++) out[on++] = tab[k];
    out[on++] = n & 255; out[on++] = n >> 8;
    for (int i = 0; i < n;) {
        if (!clen[i]) {
            int b = d[i];
            if (tpos[b] >= 0) { bit(0); bit(0); bits(tpos[b], 4); }
            else { bit(0); bit(1); bits(b, 8); }
            i++;
        } else {
            int L = clen[i], dd = coff[i];
            bit(1); gamma_(L - 1);
            if (dd <= 128) { bit(0); bits(dd - 1, 7); } else { bit(1); bits(dd - 1, 12); }
            i += L;
        }
    }
    while (nb) bit(0);
    f = fopen(argv[2], "wb");
    fwrite(out, 1, on, f);
    fclose(f);
    return 0;
}
