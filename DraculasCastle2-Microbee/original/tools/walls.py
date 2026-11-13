# walls.py - perspective wall-piece generator for the first-person view
import math, random
from gfx import PAL
from tone import pick

VW, VH, CX, HOR = 80, 52, 40, 25
WB = {0: 80, 1: 64, 2: 32, 3: 24, 4: 16}          # face widths at boundary d (pixels)
EYE, CEIL = 0.6, 0.9                               # world units below / above eye
def S(w): return w * 2.0 / 3.0                     # vertical px per world unit for width w
def top_y(w): return HOR - CEIL * S(w)
def bot_y(w): return HOR + EYE * S(w)

def hw_to_z(hw):
    """screen half-width (px) of the 1-unit face -> depth z, consistent with WB boundaries"""
    hws = [(WB[d] / 2.0, float(d)) for d in (1, 2, 3, 4)]
    if hw >= hws[0][0]: return 32.0 / hw
    for i in range(3):
        a, za = hws[i]; b, zb = hws[i + 1]
        if b <= hw <= a:
            t = (a - hw) / (a - b)
            return 1.0 / (1.0 / za * (1 - t) + 1.0 / zb * t)
    return 32.0 / hw

# ----- piece geometry -----
SIDE_SLOTS = [(0, -1), (1, -1), (2, -1), (3, -1), (2, -2), (3, -2)]
def side_x(d, l):
    k = abs(l) - 0.5
    xa = CX - k * WB[d]; xb = CX - k * WB[d + 1]
    return max(0, int(round(xa))), int(round(xb))

def face_rows(d):
    return max(0, int(math.ceil(top_y(WB[d]) - 0.5))), min(VH, int(math.floor(bot_y(WB[d]) - 0.5)) + 1)

class Material:
    """subclass: colour(u, v, z, face, ctx) -> rgb ; u along wall (world), v height above floor"""
    dark = (0, 0, 0)
    def fog(self, z):
        return max(0.0, min(1.0, (z - 1.2) / 3.2))

def render_side(mat, q, d, l, decor=None, ss=3, only_decor=False):
    """returns (x0_byte, y0, wbytes, h, pix rows (with -1 transparent))"""
    xa, xb = side_x(d, l)
    k = abs(l) - 0.5
    rows = []
    ys = []
    out = {}
    for sy in range(VH):
        for sx in range(xa, xb):
            acc = {}; cov = 0
            for jy in range(ss):
                for jx in range(ss):
                    px = sx + (jx + 0.5) / ss; py = sy + (jy + 0.5) / ss
                    w = (CX - px) / k              # width of a unit face at this depth
                    if w <= 0: continue
                    ty, by = top_y(w), bot_y(w)
                    if py < ty or py >= by: continue
                    z = hw_to_z(w / 2)
                    v = EYE - (py - HOR) / S(w)
                    u = z                          # along wall
                    c = mat.colour(u, v, z, ('side', d, l), decor, only_decor)
                    if c is None: continue
                    k_ = pick(c, sx, sy); acc[k_] = acc.get(k_, 0) + 1; cov += 1
            if cov * 2 >= ss * ss:
                out[(sx, sy)] = max(acc, key=acc.get)
    return out

def render_front(mat, q, d, decor=None, ss=3, lateral=0, only_decor=False):
    """front face of cell at depth d, lateral 0; returns dict (x,y)->c for x in face span"""
    w = WB[d]; xa = CX - w // 2; xb = CX + w // 2
    y0, y1 = face_rows(d)
    out = {}
    z = float(d)
    for sy in range(y0, y1):
        for sx in range(xa, xb):
            acc = {}; cov = 0
            for jy in range(ss):
                for jx in range(ss):
                    px = sx + (jx + 0.5) / ss; py = sy + (jy + 0.5) / ss
                    if py < top_y(w) or py >= bot_y(w): continue
                    u = (px - CX) / w + 0.5        # 0..1 across face
                    v = EYE - (py - HOR) / S(w)
                    c = mat.colour(u, v, z, ('front', d, lateral), decor, only_decor)
                    if c is None: continue
                    k_ = pick(c, sx, sy); acc[k_] = acc.get(k_, 0) + 1; cov += 1
            if cov * 2 >= ss * ss:
                out[(sx, sy)] = max(acc, key=acc.get)
    return out

def render_background(mat, q, ss=3, variant=0):
    """floor + ceiling + far darkness for an open corridor (80 x 52)"""
    pix = [[0] * VW for _ in range(VH)]
    for sy in range(VH):
        for sx in range(VW):
            acc = {}
            for jy in range(ss):
                for jx in range(ss):
                    px = sx + (jx + 0.5) / ss; py = sy + (jy + 0.5) / ss
                    c = mat.bg(px, py, variant)
                    k_ = pick(c, sx, sy); acc[k_] = acc.get(k_, 0) + 1
            pix[sy][sx] = max(acc, key=acc.get)
    return pix

def floor_z(py, below=True):
    """depth of floor (below) or ceiling (above) point at screen row py"""
    dy = (py - HOR) if below else (HOR - py)
    if dy <= 0.01: return 99.0
    s = dy / (EYE if below else CEIL)     # S(w)
    w = s * 1.5
    return hw_to_z(w / 2)
