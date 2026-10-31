"""Engine lookup tables -> build/tables.bin, loaded into SRAM bank 3 at $4000.
Multiplication is done with logarithms: L(v) = round(64*log2 v); a product
v*s is EXP[L(v) + LS] where LS = 64*log2(s) (+ bias).  1% accuracy."""
import math, os
B = os.path.join(os.path.dirname(__file__), '..', 'build')
K = 64
NZ = 1024                  # zi = z >> 3
KY = 64.0                  # y_off = dY * KY / z
ZMIN = 80
W = 192; KX = 96.0
EXPN = 1024
BIAS = 64                  # index = L(v) + LS (LS includes the bias); value 2^((i-BIAS)/64)

def L(v): return int(round(K * math.log2(v)))

EXPL = bytearray(EXPN); EXPH = bytearray(EXPN)
for i in range(EXPN):
    v = 2 ** ((i - BIAS) / K)          # value for biased sum i
    v = min(65535, int(round(v)))
    EXPL[i] = v & 255; EXPH[i] = v >> 8
LOGL = bytearray(256); LOGH = bytearray(256)
for v in range(256):
    l = L(v) if v else 0
    LOGL[v] = l & 255; LOGH[v] = l >> 8
LSL = bytearray(NZ); LSH = bytearray(NZ); WT = bytearray(NZ)
for zi in range(NZ):
    z = max(ZMIN, zi * 8 + 4)
    ls = int(round(K * math.log2(KY / z))) + BIAS     # biased, signed
    LSL[zi] = ls & 255; LSH[zi] = (ls >> 8) & 255
    WT[zi] = min(255, int(round(W * KX / z)))
RW = bytearray(256); LW = bytearray(256)
for w in range(256):
    RW[w] = 0 if w < 4 else max(1, int(round(w / 7)))
    LW[w] = 0 if w < 14 else max(1, int(round(w / 40)))
MK = bytearray(256)
for o in range(4): MK[o] = (0xFF >> (2 * o)) & 0xFF
# 64*log2(n) for line counts, so step = EXP[L(d) - LN[n] + 8*64 + BIAS]
# step(8.8) = EXP[L(d) + LNS[n]],  LNS[n] = 512 - L(n) + BIAS  (signed 16)
LNL = bytearray(256); LNH = bytearray(256)
for n in range(256):
    v = 512 - (L(n) if n else 0) + BIAS
    LNL[n] = v & 255; LNH[n] = (v >> 8) & 255
# pixel x (0..128) -> byte index, mask of pixels >= x in that byte, mask of pixels < x
PIX = bytearray(256); PML = bytearray(256); PMR = bytearray(256)
for x in range(256):
    xx = min(x, 128)
    PIX[x] = xx >> 2
    PML[x] = (0xFF >> (2 * (xx & 3))) & 0xFF
    PMR[x] = (~PML[x]) & 0xFF if xx & 3 else 0
# MASK2[b]: keep-background mask for pixels equal to 2; DATA2[b]: b with those pixels cleared
MASK2 = bytearray(256); DATA2 = bytearray(256)
for b in range(256):
    m = 0; d = 0
    for i in range(4):
        p = (b >> (6 - 2 * i)) & 3
        m <<= 2; d <<= 2
        if p == 2: m |= 3
        else: d |= p
    MASK2[b] = m; DATA2[b] = d
LEVEL = bytearray(256)
for w in range(256):
    if w < 3: LEVEL[w] = 255
    else: LEVEL[w] = max(0, min(11, int(round(math.log(w / 96.0) / math.log(0.7)))))
out = EXPL + EXPH + LOGL + LOGH + LSL + LSH + WT + RW + LW + MK + LNL + LNH + PIX + PML + PMR + MASK2 + DATA2 + LEVEL
open(os.path.join(B, 'tables.bin'), 'wb').write(out)
print('tables', len(out), hex(0x4000 + len(out)))
