"""Engine tables for bank 3 and the ground strip library.
Bank 3 ($4000-$67FF) layout (must match src/defs.asm):
  $4000 SQ    quarter squares n*n//4, n=0..511: pages lo<256, hi<256, lo>=256, hi>=256
  $4400 MASK0 mask for colour-key 0 (11 where a pixel is colour 0)
  $4500 MASK2 / $4600 CLEAN2 (colour-key 2: mask, data with key pixels zeroed)
  $4700 PRJ_MX[224] $4800 PRJ_MY[224] $4900 PRJ_E[224] $4A00 PRJ_LV[224]  (z index, see zidx)
  $4B00 GROW  per ground row d=1..DMAX: dw strip, db stride, db d, db K, db half, dw Zd
  $4C80 strips ..."""
import sys, math
sys.path.insert(0, 'tools')
from geom import *
DMAX = 44
HAZE_D = 10
BANK3 = 0x4000
MASK0, MASK2, CLEAN2 = 0x4000, 0x4100, 0x4200
PMX, PMY, PE, PLV, PGY = 0x4300, 0x4400, 0x4500, 0x4600, 0x4700
GROW = 0x4800
STRIPS = 0x4AC0
SQ = 0xFC00
def zidx_z(i):      # representative z of a z-index entry (centre of its bucket)
    return i * 4 + 2 if i < 128 else 512 + (i - 128) * 16 + 8
NZI = 224
def sq_tables():
    b = bytearray(1024)
    for n in range(512):
        v = n * n // 4
        pg = 0 if n < 256 else 2
        b[pg * 256 + (n & 255)] = v & 255
        b[(pg + 1) * 256 + (n & 255)] = v >> 8
    return b
def mask_tables():
    m0 = bytearray(256); m2 = bytearray(256); c2 = bytearray(256)
    for v in range(256):
        a = b = c = 0
        for i in range(4):
            p = (v >> (6 - 2 * i)) & 3; sh = 6 - 2 * i
            if p == 0: a |= 3 << sh
            if p == 2: b |= 3 << sh
            else: c |= p << sh
        m0[v] = a; m2[v] = b; c2[v] = c
    return m0 + m2 + c2
def proj_tables():
    mx = bytearray(256); my = bytearray(256); e = bytearray(256); lv = bytearray(256); gy = bytearray(256)
    for i in range(NZI):
        z = zidx_z(i)
        q = FX / z                       # px per unit
        E = 0
        while q * 2 ** E < 128: E += 1
        M = round(q * 2 ** E)
        if M > 255: M = 255
        mx[i] = M; e[i] = E
        my[i] = round(FY / z * 2 ** E)
        lv[i] = level_of(z) - 1 if level_of(z) >= 1 else 0   # level index 0..10 (level 1..11)
        gy[i] = min(255, round(CAMH * FY / z))
    for i in range(NZI, 256): mx[i] = mx[NZI - 1]; my[i] = my[NZI - 1]; e[i] = e[NZI - 1]; lv[i] = 10; gy[i] = gy[NZI - 1]
    return mx + my + e + lv + gy
def strip_pixels(d, A, Bc, SKY, nbytes, style='checker', seam=0):
    """pixel sequence for row d (phase-0 coordinates s = 0..)"""
    px = []
    haze = d <= HAZE_D
    for s in range(nbytes * 4 + 4):
        stripe = (2 * s // d) & 1
        if d <= 1: c = Bc if (s & 1) else SKY
        elif d <= 3: c = A if ((s + d) & 1) else Bc
        elif haze: c = (A if ((s + d) & 1) else Bc) if stripe == 0 else Bc
        elif style == 'bands':   # dunes: long sand runs with short dark ripples (staggered by depth)
            c = Bc if (4 * s // d) % 4 == 0 else A
        elif style == 'grid':    # crystal floor: the checker, each tile edged with a green seam
            pos = (2 * s) % d
            c = seam if pos < max(1, d // 5) else (A if stripe == 0 else Bc)
        else: c = A if stripe == 0 else Bc
        px.append(c)
    return px
def ground(A=0, Bc=1, SKY=2, style='checker', seam=0):
    grow = bytearray(); strips = bytearray(); addr = STRIPS
    for d in range(1, DMAX + 1):
        half_ = 0 if d <= HAZE_D else d // 2
        stride = 32 + (d - 1 + half_) // 4 + 1
        haze = d <= HAZE_D
        K = (-64) % d
        half = 0 if haze else d // 2
        zd = round(ground_z(d)) & 0xFFFF
        e = bytes([K, d, half, zd & 255])
        for k in range(4): e += bytes([(addr + k * stride) & 255, (addr + k * stride) >> 8])
        grow += e + bytes(4)
        px = strip_pixels(d, A, Bc, SKY, stride + 1, style, seam)
        for k in range(4):
            for j in range(stride):
                v = 0
                for i in range(4): v |= px[k + 4 * j + i] << (6 - 2 * i)
                strips.append(v)
        addr += 4 * stride
    return grow, strips, addr
if __name__ == '__main__':
    g, s, end = ground()
    print('ground rows', len(g), 'strips', len(s), 'end $%04X' % end, 'limit $6800'); assert end <= 0x6800 and GROW + len(g) <= STRIPS
