"""RUNEDEEP sprites: creatures, items, floor features, wall decorations
and spell effects, drawn in world units and rendered for each depth.

Style ("woodcut and torchlight"): a sprite is a silhouette in one ink
per cell on black, its inner detail cut out in black. A cell the sprite
touches is wholly the sprite's (the background behind it goes dark - the
creature carries its own shadow), so silhouettes are kept solid and
chunky. Colours come from per-material ramps (near, middle, far).

Each sprite is drawn on a supersampled label canvas in screen space at
the depth's scale; every 4 x 4 block becomes one pixel.
"""
import numpy as np
from PIL import Image, ImageDraw
import views as V
from walls import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                   BMAGENTA, BCYAN, WHITE, INKLUM, ANIM_FLAME, ANIM_RUNE, ANIM_WATER, ANIM_PORTAL, hash2)

SS = 4                                   # supersampling
ANIM_GLOW = 5


class Canvas:
    """labels: 0 empty, 1 black (opaque, unlit), 2+ materials"""
    def __init__(self, mode, dz, shiftx=0.0):
        self.W, self.H = V.PW * SS, V.PH * SS
        self.lab = Image.new('L', (self.W, self.H), 0)
        self.lum = Image.new('L', (self.W, self.H), 255)
        self.dl = ImageDraw.Draw(self.lab)
        self.dm = ImageDraw.Draw(self.lum)
        self.mode, self.dz = mode, dz
        if mode == 'billboard':
            z = V.SPR_Z[dz]
            self.sx, self.sy = V.FX / z, V.FY / z
            self.ox, self.oy = V.CX + shiftx * self.sx, V.CY + V.FY * 0.5 / z
        elif mode == 'face':
            z = V.ZB[dz]
            self.sx, self.sy = V.FX / z, V.FY / z
            self.ox, self.oy = V.CX, V.CY
        self.z = z if mode != 'floor' else None

    k = 1.0

    def pt(self, x, y):
        x, y = x * self.k, y * self.k
        return ((self.ox + x * self.sx) * SS, (self.oy - y * self.sy) * SS)

    def floor_pt(self, X, t):
        """a floor point: X across, t 0..1 into the square at depth dz"""
        z0, z1 = V.ZB[self.dz], V.ZB[self.dz + 1] if self.dz + 1 < len(V.ZB) else V.ZB[-1] + 2
        z = z0 + (z1 - z0) * t
        return ((V.CX + X * V.FX / z) * SS, (V.CY + 0.5 * V.FY / z) * SS)

    def _fill(self, shape, lab, lum, fn, *a, **k):
        getattr(self.dl, fn)(shape, fill=lab, *a, **k)
        getattr(self.dm, fn)(shape, fill=int(lum * 255), *a, **k)

    def ell(self, cx, cy, rx, ry, lab, lum=1.0):
        x0, y0 = self.pt(cx - rx, cy + ry)
        x1, y1 = self.pt(cx + rx, cy - ry)
        self._fill([x0, y0, x1, y1], lab, lum, 'ellipse')

    def poly(self, pts, lab, lum=1.0):
        self._fill([self.pt(x, y) for x, y in pts], lab, lum, 'polygon')

    def fpoly(self, pts, lab, lum=1.0):
        self._fill([self.floor_pt(x, t) for x, t in pts], lab, lum, 'polygon')

    def rect(self, x0, y0, x1, y1, lab, lum=1.0):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], lab, lum)

    def line(self, pts, w, lab, lum=1.0):
        P = [self.pt(x, y) for x, y in pts]
        wpx = max(SS, int(w * self.sx * SS))
        self.dl.line(P, fill=lab, width=wpx, joint='curve')
        self.dm.line(P, fill=int(lum * 255), width=wpx, joint='curve')

    def px_line(self, pts, lab, lum=1.0, wpx=1):
        """a line at least wpx screen pixels wide, whatever the depth"""
        P = [self.pt(x, y) for x, y in pts]
        self.dl.line(P, fill=lab, width=wpx * SS)
        self.dm.line(P, fill=int(lum * 255), width=wpx * SS)

    def dot(self, x, y, lab, r=1):
        cx, cy = self.pt(x, y)
        rr = r * SS * 0.5 + SS * 0.5
        self.dl.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=lab)
        self.dm.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=255)


def render(draw, mode, dz, mats, shiftx=0.0, mincov=10, scale=1.0, **kw):
    """-> list of cells (col, row, pattern bytes, colour byte)"""
    c = Canvas(mode, dz, shiftx)
    c.k = scale
    draw(c, **kw)
    lab = np.array(c.lab).reshape(V.PH, SS, V.PW, SS).transpose(0, 2, 1, 3).reshape(V.PH, V.PW, SS * SS)
    lum = np.array(c.lum).reshape(V.PH, SS, V.PW, SS).transpose(0, 2, 1, 3).reshape(V.PH, V.PW, SS * SS) / 255.0
    cov = (lab > 0).mean(-1)
    solid = cov >= 0.5
    # majority material among covered sub-pixels
    nl = int(lab.max()) + 1
    counts = np.stack([(lab == k).sum(-1) for k in range(nl)], -1)
    counts[..., 0] = 0
    major = counts.argmax(-1)
    lit = (major >= 2) & solid
    meanlum = np.where(lab >= 2, lum, 0).sum(-1) / np.maximum((lab >= 2).sum(-1), 1)
    band = min(dz - 1, 2) if mode != 'face' else min(dz - 1, 2)
    out = []
    for cr in range(V.VH):
        for cc in range(V.VW):
            ys, xs = slice(cr * 10, cr * 10 + 10), slice(cc * 8, cc * 8 + 8)
            s = solid[ys, xs]
            if s.sum() < mincov and not lit[ys, xs].any():
                continue
            if not (cov[ys, xs] > 0).any():
                continue
            m = major[ys, xs][lit[ys, xs]]
            if len(m):
                vals, cnt = np.unique(m, return_counts=True)
                mat = int(vals[cnt.argmax()])
            else:
                mat = None
            if mat is None:
                if s.sum() < mincov:
                    continue
                out.append((cc, cr, bytes(10), 0))
                continue
            ramp, anim = mats[mat]
            ink = ramp[band] if isinstance(ramp, (list, tuple)) else ramp
            dens = meanlum[ys, xs] * (1.0 if band == 0 else 0.92 if band == 1 else 0.85)
            th = V.BAYER4[np.arange(cr * 10, cr * 10 + 10)[:, None] % 4, np.arange(cc * 8, cc * 8 + 8)[None, :] % 4]
            on = lit[ys, xs] & (major[ys, xs] == mat) & (dens > th * 0.999)
            # other materials in this cell: drawn in this ink if lit (keeps the shape)
            on |= lit[ys, xs] & (major[ys, xs] != mat) & (dens > th)
            pat = bytes(int(sum(int(on[i, j]) << (7 - j) for j in range(8))) for i in range(10))
            out.append((cc, cr, pat, (anim << 4) | ink))
    return out


# =====================================================================
#  creatures (world units, origin at the feet, y up)
# =====================================================================
def rat(c, pose='idle'):
    lunge = pose == 'attack'
    h = 0.24
    c.ell(0, h * 0.5, 0.26, h * 0.5, 2, 0.9)                 # body
    c.ell(0, h * 0.62, 0.2, h * 0.38, 2, 1.0)
    c.ell(0, h * 0.55 + (0.06 if lunge else 0), 0.13, 0.11, 2, 1.0)  # head (facing us)
    c.poly([(-0.12, 0.33), (-0.2, 0.44), (-0.05, 0.36)], 2)  # ears
    c.poly([(0.12, 0.33), (0.2, 0.44), (0.05, 0.36)], 2)
    c.ell(-0.055, 0.2, 0.03, 0.03, 1)                         # eyes
    c.ell(0.055, 0.2, 0.03, 0.03, 1)
    c.dot(-0.055, 0.2, 3)
    c.dot(0.055, 0.2, 3)
    if lunge:
        c.poly([(-0.07, 0.1), (0.07, 0.1), (0.0, 0.02)], 1)  # open jaws
        c.px_line([(-0.05, 0.1), (-0.04, 0.06)], 2)
        c.px_line([(0.05, 0.1), (0.04, 0.06)], 2)
    c.line([(0.22, 0.05), (0.38, 0.12), (0.45, 0.3)], 0.025, 2)  # tail
    c.ell(-0.18, 0.02, 0.06, 0.03, 2)
    c.ell(0.18, 0.02, 0.06, 0.03, 2)


def skeleton(c, pose='idle'):
    atk = pose == 'attack'
    # legs
    for s in (-1, 1):
        c.line([(s * 0.06, 0.42), (s * 0.08, 0.22), (s * 0.07, 0.02)], 0.035, 2)
        c.ell(s * 0.09, 0.01, 0.05, 0.015, 2)
    c.ell(0, 0.43, 0.1, 0.04, 2)                               # pelvis
    c.line([(0, 0.45), (0, 0.62)], 0.03, 2)                    # spine
    for i, y in enumerate((0.56, 0.62, 0.68)):                 # ribs
        c.ell(0, y, 0.12 - i * 0.005, 0.022, 2)
        c.ell(0, y, 0.08, 0.008, 1)
    c.ell(0, 0.72, 0.13, 0.03, 2)                              # shoulders
    c.ell(0, 0.83, 0.075, 0.085, 2)                            # skull
    c.ell(-0.03, 0.84, 0.022, 0.026, 1)
    c.ell(0.03, 0.84, 0.022, 0.026, 1)
    c.poly([(-0.012, 0.8), (0.012, 0.8), (0, 0.78)], 1)
    c.rect(-0.04, 0.76, 0.04, 0.765, 1)
    # arms; the sword arm raised to strike
    c.line([(-0.13, 0.71), (-0.17, 0.55), (-0.15, 0.42)], 0.028, 2)
    if atk:
        c.line([(0.13, 0.71), (0.2, 0.82), (0.17, 0.95)], 0.028, 2)
        c.line([(0.17, 0.95), (0.0, 1.12)], 0.035, 3)          # sword overhead
        c.rect(0.13, 0.93, 0.22, 0.95, 3)
    else:
        c.line([(0.13, 0.71), (0.18, 0.56), (0.2, 0.45)], 0.028, 2)
        c.line([(0.2, 0.45), (0.27, 0.92)], 0.035, 3)          # sword
        c.rect(0.15, 0.46, 0.26, 0.48, 3)
    c.ell(-0.19, 0.42, 0.05, 0.06, 4)                          # a round shield
    c.ell(-0.19, 0.42, 0.02, 0.025, 1)


def spider(c, pose='idle'):
    atk = pose == 'attack'
    y0 = 0.22
    for s in (-1, 1):
        for i, (a, b) in enumerate(((0.42, 0.42), (0.47, 0.25), (0.44, 0.08), (0.36, -0.02))):
            k = 0.06 if atk and i == 0 else 0
            c.line([(s * 0.1, y0 + 0.04), (s * a * 0.8, y0 + 0.2 + k - i * 0.04), (s * b * 1.0, 0.01 + (0.25 if atk and i == 0 else 0))], 0.025, 2)
    c.ell(0, y0 + 0.13, 0.17, 0.13, 2, 0.85)                  # abdomen behind
    c.ell(0, y0 + 0.02, 0.11, 0.09, 2)                         # head
    for x, y in ((-0.04, 0.27), (0.04, 0.27), (-0.07, 0.24), (0.07, 0.24), (-0.02, 0.22), (0.02, 0.22)):
        c.ell(x, y, 0.018, 0.018, 1)
        c.dot(x, y, 3)
    c.poly([(-0.05, 0.16), (-0.02, 0.16), (-0.04, 0.08 if atk else 0.11)], 2)  # fangs
    c.poly([(0.05, 0.16), (0.02, 0.16), (0.04, 0.08 if atk else 0.11)], 2)
    c.ell(0, y0 + 0.17, 0.06, 0.03, 1)                         # the marking
    c.ell(0, y0 + 0.17, 0.03, 0.015, 2)


def fungoid(c, pose='idle'):
    atk = pose == 'attack'
    c.poly([(-0.1, 0.0), (0.1, 0.0), (0.08, 0.45), (-0.08, 0.45)], 3)    # stalk body
    for s in (-1, 1):
        c.ell(s * 0.06, 0.02, 0.06, 0.025, 3)
        if atk:
            c.line([(s * 0.08, 0.38), (s * 0.2, 0.5), (s * 0.24, 0.66)], 0.04, 3)
        else:
            c.line([(s * 0.08, 0.38), (s * 0.2, 0.28), (s * 0.22, 0.14)], 0.04, 3)
    c.ell(-0.035, 0.33, 0.022, 0.03, 1)
    c.ell(0.035, 0.33, 0.022, 0.03, 1)
    c.ell(0, 0.24, 0.035, 0.02 if not atk else 0.04, 1)
    c.ell(0, 0.6, 0.3, 0.17, 2)                                 # the cap
    c.rect(-0.3, 0.44, 0.3, 0.6, 2)
    c.ell(0, 0.46, 0.3, 0.04, 2)
    for x, y, r in ((-0.15, 0.62, 0.05), (0.08, 0.68, 0.045), (0.19, 0.55, 0.035), (-0.03, 0.54, 0.03), (-0.22, 0.5, 0.025)):
        c.ell(x, y, r, r * 0.8, 1)
    c.rect(-0.3, 0.43, 0.3, 0.445, 1)


def ghoul(c, pose='idle'):
    atk = pose == 'attack'
    for s in (-1, 1):
        c.line([(s * 0.07, 0.4), (s * 0.1, 0.2), (s * 0.08, 0.02)], 0.05, 2)
        c.ell(s * 0.1, 0.02, 0.06, 0.02, 2)
    c.poly([(-0.16, 0.38), (0.16, 0.38), (0.19, 0.68), (-0.19, 0.68)], 2)  # hunched torso
    c.ell(0, 0.68, 0.19, 0.07, 2)
    c.ell(0, 0.74, 0.09, 0.09, 2)                                # head, low
    c.ell(-0.035, 0.75, 0.025, 0.02, 1)
    c.ell(0.035, 0.75, 0.025, 0.02, 1)
    c.dot(-0.035, 0.75, 3)
    c.dot(0.035, 0.75, 3)
    c.poly([(-0.05, 0.7), (0.05, 0.7), (0.0, 0.66 if not atk else 0.62)], 1)
    for s in (-1, 1):
        if atk:
            c.line([(s * 0.17, 0.66), (s * 0.27, 0.78), (s * 0.24, 0.9)], 0.045, 2)
            for k in (-0.03, 0, 0.03):
                c.px_line([(s * 0.24 + k, 0.9), (s * 0.24 + k * 1.5, 0.97)], 2)
        else:
            c.line([(s * 0.17, 0.66), (s * 0.27, 0.45), (s * 0.25, 0.22)], 0.045, 2)
            for k in (-0.03, 0, 0.03):
                c.px_line([(s * 0.25 + k, 0.22), (s * 0.25 + k * 1.5, 0.15)], 2)
    for y in (0.46, 0.53, 0.6):                                  # rags / ribs
        c.px_line([(-0.12, y), (0.12, y + 0.02)], 1)
    c.poly([(-0.16, 0.38), (-0.1, 0.3), (-0.04, 0.38), (0.03, 0.29), (0.09, 0.38), (0.16, 0.31), (0.16, 0.38)], 2)


def wisp(c, pose='idle'):
    atk = pose == 'attack'
    r = 0.2 if not atk else 0.26
    y = 0.55
    for i in range(6):
        a = i * np.pi / 3
        c.line([(0, y), (np.cos(a) * r * 1.6, y + np.sin(a) * r * 1.6)], 0.02, 2, 0.6)
    c.ell(0, y, r, r, 2, 0.6)
    c.ell(0, y, r * 0.7, r * 0.7, 2, 0.85)
    c.ell(0, y, r * 0.4, r * 0.4, 2, 1.0)
    c.ell(-0.06, y + 0.03, 0.035, 0.045, 1)
    c.ell(0.06, y + 0.03, 0.035, 0.045, 1)
    c.ell(0, y - 0.07, 0.05, 0.03 if not atk else 0.06, 1)
    c.poly([(-r * 0.6, y - r * 0.6), (r * 0.6, y - r * 0.6), (0.05, 0.12), (0.0, 0.18), (-0.04, 0.1)], 2, 0.5)


def imp(c, pose='idle'):
    atk = pose == 'attack'
    for s in (-1, 1):
        c.line([(s * 0.05, 0.25), (s * 0.09, 0.12), (s * 0.06, 0.02)], 0.04, 2)
        c.poly([(s * 0.12, 0.42), (s * 0.4, 0.62), (s * 0.34, 0.45), (s * 0.42, 0.38), (s * 0.28, 0.33)], 2, 0.75)  # wings
    c.ell(0, 0.33, 0.1, 0.11, 2)
    c.ell(0, 0.5, 0.09, 0.08, 2)
    c.poly([(-0.07, 0.55), (-0.13, 0.68), (-0.04, 0.58)], 2)       # horns
    c.poly([(0.07, 0.55), (0.13, 0.68), (0.04, 0.58)], 2)
    c.ell(-0.035, 0.51, 0.022, 0.018, 1)
    c.ell(0.035, 0.51, 0.022, 0.018, 1)
    c.dot(-0.035, 0.51, 3)
    c.dot(0.035, 0.51, 3)
    c.poly([(-0.04, 0.46), (0.04, 0.46), (0, 0.43)], 1)
    c.line([(0.08, 0.12), (0.2, 0.08), (0.26, 0.15)], 0.02, 2)      # tail
    # a fireball held (or hurled)
    fx, fy = (0.0, 0.3) if atk else (0.2, 0.38)
    rr = 0.1 if atk else 0.07
    c.line([(0.09, 0.38), (fx, fy)], 0.035, 2)
    c.ell(fx, fy + rr * 0.5, rr, rr * 1.3, 3)
    c.ell(fx, fy + rr * 0.4, rr * 0.5, rr * 0.6, 1)


def hound(c, pose='idle'):
    atk = pose == 'attack'
    c.ell(0, 0.3, 0.2, 0.14, 2, 0.8)                              # body behind
    for s in (-1, 1):
        c.line([(s * 0.1, 0.24), (s * 0.12, 0.1), (s * 0.11, 0.01)], 0.045, 2)
        c.ell(s * 0.12, 0.01, 0.05, 0.02, 2)
    c.ell(0, 0.36, 0.13, 0.12, 2)                                 # chest
    hy = 0.46 if not atk else 0.42
    c.ell(0, hy, 0.12, 0.1, 2)                                    # head
    c.poly([(-0.1, hy + 0.05), (-0.17, hy + 0.18), (-0.04, hy + 0.08)], 2)
    c.poly([(0.1, hy + 0.05), (0.17, hy + 0.18), (0.04, hy + 0.08)], 2)
    c.ell(0, hy - 0.06, 0.07, 0.05, 2)                            # muzzle
    c.ell(-0.045, hy + 0.02, 0.025, 0.018, 1)
    c.ell(0.045, hy + 0.02, 0.025, 0.018, 1)
    c.dot(-0.045, hy + 0.02, 3)
    c.dot(0.045, hy + 0.02, 3)
    if atk:
        c.poly([(-0.06, hy - 0.07), (0.06, hy - 0.07), (0.04, hy - 0.15), (-0.04, hy - 0.15)], 1)
        for k in (-0.04, -0.015, 0.015, 0.04):
            c.px_line([(k, hy - 0.07), (k, hy - 0.1)], 2)
    for k in range(5):                                            # spines of flame
        x = -0.12 + k * 0.06
        c.poly([(x - 0.025, 0.42), (x + 0.025, 0.42), (x + 0.01, 0.52 + 0.03 * (k % 2))], 3)


def king(c, pose='idle'):
    atk = pose == 'attack'
    c.poly([(-0.25, 0.0), (0.25, 0.0), (0.15, 0.7), (-0.15, 0.7)], 2, 0.75)   # robe
    c.poly([(-0.06, 0.0), (0.06, 0.0), (0.03, 0.6), (-0.03, 0.6)], 1)
    c.ell(0, 0.72, 0.2, 0.07, 2)
    c.ell(0, 0.84, 0.09, 0.1, 1)                                  # the hollow face
    c.ell(-0.035, 0.85, 0.022, 0.018, 3)
    c.ell(0.035, 0.85, 0.022, 0.018, 3)
    c.poly([(-0.1, 0.9), (0.1, 0.9), (0.11, 1.02), (0.06, 0.96), (0.03, 1.04), (0, 0.97), (-0.03, 1.04),
            (-0.06, 0.96), (-0.11, 1.02)], 4)                     # crown
    c.poly([(-0.1, 0.9), (-0.12, 0.72), (-0.08, 0.8)], 2)         # hood edges
    c.poly([(0.1, 0.9), (0.12, 0.72), (0.08, 0.8)], 2)
    for s in (-1, 1):
        if atk and s == 1:
            c.line([(0.17, 0.68), (0.28, 0.8), (0.3, 0.95)], 0.05, 2)
            c.ell(0.3, 1.0, 0.07, 0.07, 3)
        else:
            c.line([(s * 0.17, 0.68), (s * 0.27, 0.5), (s * 0.26, 0.35)], 0.05, 2)
    c.line([(-0.28, 0.0), (-0.28, 0.95)], 0.025, 4)               # staff
    c.ell(-0.28, 1.0, 0.05, 0.06, 3)
    for y in (0.2, 0.35, 0.5):
        c.px_line([(-0.2 + y * 0.1, y), (0.2 - y * 0.1, y)], 1)


def trader(c, pose='idle'):
    c.poly([(-0.17, 0.0), (0.17, 0.0), (0.13, 0.35), (-0.13, 0.35)], 2, 0.85)   # coat
    c.ell(0, 0.33, 0.14, 0.06, 2)
    c.ell(0, 0.42, 0.08, 0.075, 3)                                # face
    c.poly([(-0.09, 0.4), (0.09, 0.4), (0.0, 0.2)], 3)            # beard
    c.ell(-0.03, 0.44, 0.015, 0.012, 1)
    c.ell(0.03, 0.44, 0.015, 0.012, 1)
    c.poly([(-0.11, 0.47), (0.11, 0.47), (0.03, 0.72), (0.08, 0.66)], 2)   # pointed hat
    c.ell(0, 0.47, 0.12, 0.02, 2)
    c.ell(0.2, 0.14, 0.09, 0.11, 4)                               # a sack
    c.line([(0.12, 0.3), (0.18, 0.22)], 0.03, 2)
    c.ell(-0.2, 0.32, 0.04, 0.05, 5)                              # a lantern
    c.line([(-0.13, 0.3), (-0.2, 0.36)], 0.02, 2)


CREATURES = {
    'rat': (rat, {2: ([BROWN, BROWN, RED], 0), 3: ([BRED, RED, RED], 0)}),
    'skeleton': (skeleton, {2: ([WHITE, GREY, DGREY], 0), 3: ([BCYAN, CYAN, BLUE], 0), 4: ([BROWN, BROWN, RED], 0)}),
    'spider': (spider, {2: ([BMAGENTA, MAGENTA, MAGENTA], 0), 3: ([BRED, RED, RED], 0)}),
    'fungoid': (fungoid, {2: ([BRED, RED, RED], 0), 3: ([YELLOW, BROWN, BROWN], 0)}),
    'ghoul': (ghoul, {2: ([BGREEN, GREEN, GREEN], 0), 3: ([YELLOW, BROWN, BROWN], 0)}),
    'wisp': (wisp, {2: ([WHITE, BCYAN, CYAN], ANIM_GLOW + 2)}),
    'imp': (imp, {2: ([BMAGENTA, MAGENTA, MAGENTA], 0), 3: ([YELLOW, YELLOW, BRED], ANIM_FLAME)}),
    'hound': (hound, {2: ([WHITE, GREY, DGREY], 0), 3: ([YELLOW, BRED, RED], ANIM_FLAME)}),
    'king': (king, {2: ([BCYAN, CYAN, BLUE], 0), 3: ([BRED, BRED, RED], 0), 4: ([YELLOW, YELLOW, BROWN], 0)}),
    'trader': (trader, {2: ([YELLOW, BROWN, BROWN], 0), 3: ([WHITE, GREY, GREY], 0), 4: ([BROWN, BROWN, RED], 0),
                        5: ([YELLOW, YELLOW, BROWN], ANIM_FLAME)}),
}


# =====================================================================
#  items on the floor (billboards, small)
# =====================================================================
def it_gold(c):
    for x, y, r in ((-0.08, 0.03, 0.06), (0.06, 0.03, 0.06), (0.0, 0.07, 0.06), (-0.03, 0.11, 0.05), (0.04, 0.1, 0.04)):
        c.ell(x, y, r, r * 0.6, 2)
        c.ell(x, y, r * 0.5, r * 0.25, 1)


def it_potion(c):
    c.ell(0, 0.08, 0.08, 0.08, 2)
    c.rect(-0.025, 0.14, 0.025, 0.22, 2)
    c.rect(-0.035, 0.22, 0.035, 0.245, 3)
    c.ell(-0.03, 0.1, 0.015, 0.025, 1)


def it_key(c):
    c.ell(-0.1, 0.06, 0.06, 0.05, 2)
    c.ell(-0.1, 0.06, 0.03, 0.022, 1)
    c.rect(-0.05, 0.05, 0.14, 0.075, 2)
    c.rect(0.08, 0.0, 0.1, 0.05, 2)
    c.rect(0.12, 0.0, 0.14, 0.05, 2)


def it_sword(c):
    c.poly([(-0.22, 0.03), (0.16, 0.06), (0.18, 0.045), (0.16, 0.03)], 2)
    c.rect(-0.24, 0.0, -0.21, 0.09, 3)
    c.rect(-0.31, 0.03, -0.24, 0.055, 3)


def it_armour(c):
    c.poly([(-0.16, 0.0), (0.16, 0.0), (0.14, 0.22), (0.2, 0.3), (0.1, 0.32), (0.0, 0.27), (-0.1, 0.32), (-0.2, 0.3),
            (-0.14, 0.22)], 2)
    for y in (0.06, 0.12, 0.18):
        c.px_line([(-0.13, y), (0.13, y)], 1)


def it_scroll(c):
    c.rect(-0.12, 0.0, 0.12, 0.12, 2)
    c.ell(-0.12, 0.06, 0.03, 0.06, 2)
    c.ell(0.12, 0.06, 0.03, 0.06, 2)
    c.ell(0.0, 0.06, 0.035, 0.035, 3)


def it_tome(c):
    c.poly([(-0.15, 0.0), (0.15, 0.0), (0.13, 0.08), (-0.13, 0.08)], 2)
    c.poly([(-0.13, 0.08), (0.13, 0.08), (0.11, 0.12), (-0.11, 0.12)], 3)
    c.ell(0, 0.04, 0.04, 0.025, 1)


def it_sigil(c):
    c.poly([(0, 0.0), (0.09, 0.12), (0, 0.26), (-0.09, 0.12)], 2)
    c.poly([(0, 0.06), (0.04, 0.12), (0, 0.19), (-0.04, 0.12)], 1)
    c.dot(0, 0.12, 2)


def it_gem(c):
    c.poly([(-0.09, 0.08), (-0.05, 0.13), (0.05, 0.13), (0.09, 0.08), (0, 0.0)], 2)
    c.px_line([(-0.09, 0.08), (0.09, 0.08)], 1)


def it_ring(c):
    c.ell(0, 0.05, 0.07, 0.04, 2)
    c.ell(0, 0.05, 0.045, 0.02, 1)
    c.ell(0, 0.1, 0.03, 0.025, 3)


def it_vial(c):
    c.rect(-0.035, 0.0, 0.035, 0.16, 2)
    c.rect(-0.02, 0.16, 0.02, 0.2, 3)


def it_bones(c):
    c.ell(-0.05, 0.06, 0.07, 0.06, 2)
    c.ell(-0.075, 0.065, 0.018, 0.02, 1)
    c.ell(-0.025, 0.065, 0.018, 0.02, 1)
    c.line([(0.0, 0.01), (0.22, 0.04)], 0.025, 2)
    c.line([(0.05, 0.05), (0.25, 0.0)], 0.025, 2)


ITEMS = [  # item number 1.. : name, draw, materials
    ('gold', it_gold, {2: ([YELLOW, YELLOW, BROWN], 0)}),
    ('potion', it_potion, {2: ([BMAGENTA, MAGENTA, MAGENTA], 0), 3: ([BROWN, BROWN, RED], 0)}),
    ('key1', it_key, {2: ([BROWN, BROWN, RED], 0)}),
    ('key2', it_key, {2: ([WHITE, GREY, GREY], 0)}),
    ('key3', it_key, {2: ([YELLOW, YELLOW, BROWN], 0)}),
    ('sword', it_sword, {2: ([BCYAN, CYAN, CYAN], 0), 3: ([YELLOW, BROWN, BROWN], 0)}),
    ('armour', it_armour, {2: ([WHITE, GREY, GREY], 0)}),
    ('scroll', it_scroll, {2: ([YELLOW, BROWN, BROWN], 0), 3: ([BRED, RED, RED], 0)}),
    ('tome', it_tome, {2: ([BGREEN, GREEN, GREEN], 0), 3: ([WHITE, GREY, GREY], 0)}),
    ('sigil', it_sigil, {2: ([BMAGENTA, MAGENTA, MAGENTA], ANIM_RUNE)}),
    ('gem', it_gem, {2: ([BCYAN, CYAN, CYAN], 0)}),
    ('ring', it_ring, {2: ([YELLOW, YELLOW, BROWN], 0), 3: ([BRED, RED, RED], 0)}),
    ('vial', it_vial, {2: ([BBLUE, BLUE, BLUE], 0), 3: ([WHITE, GREY, GREY], 0)}),
    ('bones', it_bones, {2: ([GREY, DGREY, DGREY], 0)}),
]


# =====================================================================
#  floor features (drawn on the floor of the square, in perspective)
# =====================================================================
def fl_stairs(c, up=False):
    c.fpoly([(-0.4, 0.12), (0.4, 0.12), (0.4, 0.88), (-0.4, 0.88)], 1)
    n = 5
    for i in range(n):
        t0 = 0.12 + (0.76 / n) * i
        t1 = t0 + 0.76 / n * 0.45
        w = 0.4 - (0 if up else i * 0.04)
        c.fpoly([(-w, t0), (w, t0), (w, t1), (-w, t1)], 2, 1.0 - i * 0.12)
    c.fpoly([(-0.42, 0.1), (-0.38, 0.1), (-0.38, 0.9), (-0.42, 0.9)], 2)
    c.fpoly([(0.38, 0.1), (0.42, 0.1), (0.42, 0.9), (0.38, 0.9)], 2)


def fl_upstairs(c):
    fl_stairs(c, up=True)


def fl_pit(c):
    c.fpoly([(-0.36, 0.15), (0.36, 0.15), (0.36, 0.85), (-0.36, 0.85)], 2)
    c.fpoly([(-0.3, 0.22), (0.3, 0.22), (0.3, 0.78), (-0.3, 0.78)], 1)


def fl_plate(c):
    c.fpoly([(-0.25, 0.3), (0.25, 0.3), (0.25, 0.7), (-0.25, 0.7)], 2)
    c.fpoly([(-0.2, 0.36), (0.2, 0.36), (0.2, 0.64), (-0.2, 0.64)], 1)


def fl_portal(c):
    for k, r in enumerate((0.38, 0.3, 0.22, 0.14)):
        c.fpoly([(-r, 0.5 - r), (r, 0.5 - r), (r, 0.5 + r), (-r, 0.5 + r)], 2 if k % 2 == 0 else 1)


FEATURES = [
    ('stairs', fl_stairs, {2: ([GREY, DGREY, DGREY], 0)}),
    ('upstair', fl_upstairs, {2: ([WHITE, GREY, DGREY], 0)}),
    ('pit', fl_pit, {2: ([GREY, DGREY, DGREY], 0)}),
    ('plate', fl_plate, {2: ([GREY, DGREY, DGREY], 0)}),
    ('portal', fl_portal, {2: ([BMAGENTA, MAGENTA, BLUE], ANIM_PORTAL)}),
]


# =====================================================================
#  wall decorations (on the face: x -0.5..0.5, y -0.5 (floor)..0.5)
# =====================================================================
def dc_lever(c, down=False):
    c.rect(-0.07, -0.08, 0.07, 0.08, 2)
    c.rect(-0.04, -0.05, 0.04, 0.05, 1)
    tip = (0.0, -0.26) if down else (0.0, 0.26)
    c.line([(0, 0), tip], 0.03, 3)
    c.ell(tip[0], tip[1], 0.045, 0.04, 3)


def dc_lever_down(c):
    dc_lever(c, True)


def dc_button(c):
    c.rect(-0.08, -0.05, 0.08, 0.09, 2)
    c.ell(0, 0.02, 0.045, 0.045, 1)
    c.ell(0, 0.02, 0.03, 0.03, 3)


def rune_plaque(sym, lit):
    def d(c):
        c.rect(-0.13, -0.1, 0.13, 0.2, 2)
        c.rect(-0.11, -0.08, 0.11, 0.18, 1)
        m = 3
        if sym == 0:     # flame
            c.poly([(0, 0.15), (0.06, 0.04), (0.04, -0.05), (-0.04, -0.05), (-0.06, 0.04)], m)
            c.poly([(0, 0.07), (0.02, 0.0), (-0.02, 0.0)], 1)
        elif sym == 1:   # wave
            for y in (0.09, 0.0):
                c.line([(-0.08, y), (-0.04, y + 0.04), (0.0, y), (0.04, y + 0.04), (0.08, y)], 0.022, m)
        elif sym == 2:   # stone (a mountain)
            c.poly([(-0.08, -0.05), (-0.02, 0.12), (0.02, 0.05), (0.05, 0.1), (0.09, -0.05)], m)
        else:            # star
            pts = []
            for k in range(10):
                a = np.pi / 2 + k * np.pi / 5
                r = 0.09 if k % 2 == 0 else 0.04
                pts.append((np.cos(a) * r, 0.04 + np.sin(a) * r))
            c.poly(pts, m)
    return d


def dc_torch(c):
    c.rect(-0.03, -0.12, 0.03, 0.02, 2)
    c.poly([(-0.06, 0.02), (0.06, 0.02), (0.04, 0.06), (-0.04, 0.06)], 2)
    c.poly([(-0.06, 0.06), (0.06, 0.06), (0.03, 0.16), (0.0, 0.24), (-0.03, 0.16)], 3)
    c.ell(0, 0.1, 0.02, 0.03, 1)


def dc_fountain(c):
    c.ell(0, 0.15, 0.08, 0.08, 2)                    # a lion's head
    c.ell(-0.03, 0.17, 0.015, 0.012, 1)
    c.ell(0.03, 0.17, 0.015, 0.012, 1)
    c.ell(0, 0.11, 0.025, 0.02, 1)
    c.rect(-0.012, -0.3, 0.012, 0.1, 3)              # the water
    c.poly([(-0.22, -0.3), (0.22, -0.3), (0.18, -0.45), (-0.18, -0.45)], 2)   # the basin
    c.rect(-0.2, -0.33, 0.2, -0.3, 3)


def dc_tablet(c):
    c.poly([(-0.16, -0.2), (0.16, -0.2), (0.16, 0.15), (0.0, 0.22), (-0.16, 0.15)], 2)
    for y in (0.1, 0.03, -0.04, -0.11):
        for x in (-0.1, -0.04, 0.02, 0.08):
            if hash2(int(x * 100), int(y * 100), 3) > 0.25:
                c.rect(x, y - 0.012, x + 0.04, y + 0.012, 1)


def dc_alcove(c):
    c.poly([(-0.14, -0.25), (0.14, -0.25), (0.14, 0.1), (0.0, 0.2), (-0.14, 0.1)], 2)
    c.poly([(-0.11, -0.22), (0.11, -0.22), (0.11, 0.08), (0.0, 0.16), (-0.11, 0.08)], 1)


DECORS = [  # name, draw, materials
    ('lever_up', dc_lever, {2: ([GREY, DGREY, DGREY], 0), 3: ([YELLOW, YELLOW, BROWN], 0)}),
    ('lever_dn', dc_lever_down, {2: ([GREY, DGREY, DGREY], 0), 3: ([YELLOW, YELLOW, BROWN], 0)}),
    ('button', dc_button, {2: ([GREY, DGREY, DGREY], 0), 3: ([BRED, RED, RED], 0)}),
    ('button_in', dc_button, {2: ([GREY, DGREY, DGREY], 0), 3: ([RED, RED, RED], 0)}),
]
for s in range(4):
    DECORS.append(('rune%d' % s, rune_plaque(s, False), {2: ([GREY, DGREY, DGREY], 0), 3: ([BLUE, BLUE, BLUE], 0)}))
    DECORS.append(('rune%d_lit' % s, rune_plaque(s, True), {2: ([GREY, DGREY, DGREY], 0), 3: ([BMAGENTA, MAGENTA, MAGENTA], ANIM_RUNE)}))
DECORS += [
    ('torch', dc_torch, {2: ([BROWN, BROWN, RED], 0), 3: ([YELLOW, YELLOW, BRED], ANIM_FLAME)}),
    ('fountain', dc_fountain, {2: ([GREY, DGREY, DGREY], 0), 3: ([BCYAN, CYAN, BLUE], ANIM_WATER)}),
    ('tablet', dc_tablet, {2: ([YELLOW, BROWN, BROWN], 0)}),
    ('alcove', dc_alcove, {2: ([GREY, DGREY, DGREY], 0)}),
]


def fx_fire(c):
    c.ell(0, 0.45, 0.12, 0.1, 2)
    c.ell(0.05, 0.47, 0.06, 0.05, 1)
    c.poly([(-0.1, 0.42), (-0.3, 0.5), (-0.1, 0.5)], 2)


FX = [('fireball', fx_fire, {2: ([YELLOW, YELLOW, BRED], ANIM_FLAME)})]


# =====================================================================
#  the sprite catalogue: global ids
# =====================================================================
def catalogue():
    """-> list of (name, kind, draw, mats); ids are the list index (from 1)"""
    cat = [None]
    for n, f, m in FEATURES:
        cat.append(('F_' + n, 'floor', f, m))
    for n, f, m in ITEMS:
        cat.append(('I_' + n, 'item', f, m))
    for n, f, m in DECORS:
        cat.append(('D_' + n, 'decor', f, m))
    for n, (f, m) in CREATURES.items():
        cat.append(('M_' + n, 'mon', f, m))
        cat.append(('A_' + n, 'atk', f, m))
    for n, f, m in FX:
        cat.append(('X_' + n, 'fx', f, m))
    return cat


CAT = catalogue()
IDS = {e[0]: i for i, e in enumerate(CAT) if e}


def render_sprite(entry, dz):
    name, kind, f, mats = entry
    if kind in ('mon', 'fx'):
        return render(f, 'billboard', dz, mats)
    if kind == 'item':
        return render(f, 'billboard', dz, mats, scale=1.5, mincov=6)
    if kind == 'atk':
        if dz != 1:
            return None
        return render(lambda c: f(c, 'attack'), 'billboard', dz, mats)
    if kind == 'floor':
        if dz > 3:
            return None
        return render(f, 'floor', dz, mats, mincov=6)
    if kind == 'decor':
        return render(f, 'face', dz, mats, mincov=4, scale=1.8)


def mon_draw(name, pose):
    return CREATURES[name][0]
