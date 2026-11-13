"""Shared geometry of the perspective engine (used by the asset tools and the mock)."""
import math
FX, FY, CAMH = 96, 64, 96      # focal lengths (horizontal px, vertical px), camera height
TX, TZ = 32, 64                # ground tile width (x) and depth (z) in world units
ZP = 160                       # the hero's depth: sprites are drawn at scale 1.0 there
NLEV = 12
LEV_S = [1.45 * 0.78 ** k for k in range(NLEV)]     # scale of each precomputed level
def level_of(z):
    s = ZP / max(z, 1)
    best = min(range(NLEV), key=lambda k: abs(math.log(LEV_S[k] / s)))
    return best
def proj(x, y, z, camx, hz):
    return 64 + (x - camx) * FX / z, hz + FY * (CAMH - y) / z
def ground_z(d):               # world z seen by the row d rows below the horizon (d >= 1)
    return FY * CAMH / d
