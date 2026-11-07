"""BILBIES! for the Microbee: level worlds.

Replays the original level designs (tools/orig, the VZ300 game's own level
kit) at their native 512 x 80 resolution to get the exact collision mask the
game rules use, plus which material / scenery made each pixel, then paints a
new 1024 x 160 picture (2 Microbee pixels per VZ pixel each way) in the
Premium's 16 colours, and compiles it to 8 x 16 cells of two colours each.
"""
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'orig'))
_cwd = os.getcwd()
os.chdir(os.path.join(HERE, 'orig'))
import lvlkit                      # noqa: E402
import levels                      # noqa: E402
import stamps                      # noqa: E402
from art import TEXNAMES, COL      # noqa: E402
os.chdir(_cwd)

W, H = 512, 80          # VZ level
MW, MH = 1024, 160      # Microbee world
CW, CH = 8, 16          # cell

# Premium RGBI palette (uBee512's CGA-style table)
PAL = np.array([(0, 0, 0), (170, 0, 0), (0, 170, 0), (170, 85, 0), (0, 0, 170), (170, 0, 170), (0, 170, 170),
                (170, 170, 170), (85, 85, 85), (255, 85, 85), (85, 255, 85), (255, 255, 85), (85, 85, 255),
                (255, 85, 255), (85, 255, 255), (255, 255, 255)], dtype=np.int32)
BLK, RED, GRN, BRN, BLU, MAG, CYN, LGR, DGR, LRED, LGRN, YEL, LBLU, LMAG, LCYN, WHT = range(16)
LUM = (PAL * np.array([30, 59, 11])).sum(1) / 100.0

T = {n: i for i, n in enumerate(TEXNAMES)}


# ---------------------------------------------------------------------------
# replay the design at VZ resolution
# ---------------------------------------------------------------------------
def replay(lv):
    lv.check()
    mask = np.zeros((H, W), bool)
    mat = np.full((H, W), -1, np.int16)       # material of solid pixels
    dec = np.full((H, W), -1, np.int16)       # last scenery shape on air
    logo = np.full((H, W), -1, np.int16)      # title logo colours
    strata = np.zeros((H, W), np.uint8)       # the builder's two layer bands
    stl = []
    layers = {}                               # every scenery shape's own air pixels
    stt = [None, None]

    def span(mode, t, y, xl, xr):
        if not (0 <= y < H):
            return
        xl = max(0, xl)
        xr = min(xr, W - 1)
        if xr < xl:
            return
        s = slice(xl, xr + 1)
        if mode == 0:
            mask[y, s] = True
            mat[y, s] = t
            dec[y, s] = -1
            for a in layers.values():
                a[y, s] = False
        elif mode == 1:
            air = ~mask[y, s]
            dec[y, s] = np.where(air, t, dec[y, s])
            if t not in layers:
                layers[t] = np.zeros((H, W), bool)
            layers[t][y, s] |= air
        elif mode == 2:
            sol = mask[y, s]
            mat[y, s] = np.where(sol, t, mat[y, s])
        else:
            mask[y, s] = False
            mat[y, s] = -1
            dec[y, s] = -1
            for a in layers.values():
                a[y, s] = False

    lf = [0]

    def lfsr():
        v = lf[0]
        c = v & 1
        v >>= 1
        if c:
            v ^= 0xB400
        lf[0] = v
        return v

    for op in lv.ops:
        k = op[0]
        if k == 1:
            _, mode, t, xl, xh, y, wl, wh, h = op
            x = xl | xh << 8
            w = wl | wh << 8
            for r in range(h):
                span(mode, t, y + r, x, x + w - 1)
        elif k == 3:
            mode, t, y, n = op[1], op[2], op[3], op[4]
            for i in range(n):
                xl = op[5 + 4 * i] | op[6 + 4 * i] << 8
                xr = op[7 + 4 * i] | op[8 + 4 * i] << 8
                span(mode, t, y + i, xl, xr)
        elif k == 9:
            _, mode, t, cl, ch, cy, rx, ry = op
            cx = cl | ch << 8
            for dy in range(-ry, ry + 1):
                tt = min(64, (abs(dy) * 128) // (2 * ry + 1))
                hw = (rx * lvlkit.SQT[tt]) >> 8
                row = (cy + dy) & 255
                if row >= H:
                    continue
                span(mode, t, row, max(0, cx - hw), cx + hw)
        elif k == 10:
            _, mode, t, al, ah, bl, bh, y, rough, seed = op
            x0 = al | ah << 8
            x1 = bl | bh << 8
            lf[0] = seed | 0xA5 << 8
            hs = []
            h = y
            for x in range(x0, x1 + 1):
                hs.append(h)
                v = lfsr()
                lo = v & 255
                if rough and (lo & 3) == 0:
                    cand = h + 1 if (lo & 4) else h - 1
                    if y - rough <= cand <= y + rough:
                        h = cand
            r = max(0, y - rough)
            while r < lv.height:
                if r > y + rough:
                    span(mode, t, r, x0, x1)
                else:
                    run = None
                    for i, hh in enumerate(hs):
                        if hh <= r:
                            if run is None:
                                run = i
                        elif run is not None:
                            span(mode, t, r, x0 + run, x0 + i - 1)
                            run = None
                    if run is not None:
                        span(mode, t, r, x0 + run, x0 + len(hs) - 1)
                r += 1
        elif k == 12:
            mode, t, xl, xh, top, n = op[1:7]
            x = xl | xh << 8
            for i, hw in enumerate(op[7:7 + n]):
                span(mode, t, top + i, max(0, x - hw), x + hw)
        elif k == 11:
            _, sid, xl, xh, y = op
            stl.append((stamps.NAMES[sid & 127], xl | xh << 8, y, bool(sid & 128), mask.copy()))
        elif k == 8:
            _, ta, tb = op
            stt[:] = [ta, tb]
            # bands 6-7 and 11-12 rows below the surface (as the builder)
            run = np.zeros((H, W), np.int16)
            for y in range(H):
                run[y] = np.where(mask[y], (run[y - 1] + 1) if y else 1, 0)
            b1 = (run >= 6) & (run < 8)
            b2 = (run >= 11) & (run < 13)
            strata[b1 & mask] = 1
            strata[b2 & mask] = 2
        elif k == 'img':
            _, xb, y, wb, h, data = op
            for r in range(h):
                for i in range(wb):
                    v = data[r * wb + i]
                    for p in range(4):
                        c = (v >> (6 - 2 * p)) & 3
                        if c != 2:
                            mask[y + r, (xb + i) * 4 + p] = True
                            logo[y + r, (xb + i) * 4 + p] = c
    etop = ebot = None
    if lv.edge:
        _, top, bot = lv.edge
        up = np.zeros_like(mask)
        up[1:] = mask[:-1]
        dn = np.zeros_like(mask)
        dn[:-1] = mask[1:]
        if top != 0xAA:
            etop = (mask & ~up, top & 3)
        if bot != 0xAA:
            ebot = (mask & ~dn, bot & 3)
    if lv.height < H:
        mask[lv.height:] = False
    for a in layers.values():
        a &= ~mask
    return dict(mask=mask, mat=mat, dec=dec, logo=logo, strata=strata, stamps=stl, etop=etop, ebot=ebot,
                bg=lv.bg, lv=lv, layers=layers, strata_t=tuple(stt))


def check_mask(lv, mask):
    """the replay must give exactly the original builder's mask"""
    g, m = lvlkit.raster(lv)
    return np.array_equal(np.array(m, bool), mask)


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------
def up2(a):
    return np.repeat(np.repeat(a, 2, 0), 2, 1)


def scale2x(a):
    """EPX / Scale2x on a label image (smooths diagonals of scenery)"""
    h, w = a.shape
    p = np.pad(a, 1, mode='edge')
    B = p[0:h, 1:w + 1]
    D = p[1:h + 1, 0:w]
    E = p[1:h + 1, 1:w + 1]
    F = p[1:h + 1, 2:w + 2]
    Hh = p[2:h + 2, 1:w + 1]
    out = np.empty((h * 2, w * 2), a.dtype)
    c = (B != Hh) & (D != F)
    out[0::2, 0::2] = np.where(c & (D == B), D, E)
    out[0::2, 1::2] = np.where(c & (B == F), F, E)
    out[1::2, 0::2] = np.where(c & (D == Hh), D, E)
    out[1::2, 1::2] = np.where(c & (Hh == F), F, E)
    return out


def rng(seed):
    return np.random.default_rng(seed)


BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def bayer(h, w):
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def dither(c0, c1, frac, h=MH, w=MW, y0=0):
    """per-pixel c1 where the ordered threshold < frac"""
    th = np.tile(BAYER4, ((h + y0) // 4 + 2, w // 4 + 1))[y0:y0 + h, :w]
    return np.where(th < frac, c1, c0)


def noise(seed, h=MH, w=MW, scale=1):
    r = rng(seed)
    if scale == 1:
        return r.random((h, w))
    small = r.random((h // scale + 2, w // scale + 2))
    # bilinear upsample
    ys = np.arange(h) / scale
    xs = np.arange(w) / scale
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = (ys - y0)[:, None]
    fx = (xs - x0)[None, :]
    a = small[y0][:, x0]
    b = small[y0][:, x0 + 1]
    c = small[y0 + 1][:, x0]
    d = small[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


# ---------------------------------------------------------------------------
# painting (palette indices, 160 x 1024)
#
# Everything ends up as 8 x 16 cells of two colours, so the picture is
# designed for that: flat sky bands one cell row tall, each piece of scenery
# in one main colour on its band, terrain in one light / dark pair per
# material, details cut out of shapes rather than drawn in a third colour.
# ---------------------------------------------------------------------------
from scipy import ndimage as _ndi      # noqa: E402

YY = np.arange(MH)[:, None] * np.ones((1, MW), int)
XX = np.ones((MH, 1), int) * np.arange(MW)[None, :]

# per theme: sky bands (one per 16-row cell row, top to bottom) and the
# colours of each kind of scenery
THEMES = {
    'sky': dict(bands=[BLU, BLU, LBLU, LBLU, LBLU, LBLU, LBLU, LBLU, LBLU, LBLU],
                far=CYN, hill=GRN, red=BRN, canopy=GRN, trunk=WHT, cloud=WHT, reed=GRN, ruin=DGR,
                stone=LGR, col=DGR, cryst=CYN, stars=None),
    'dusk': dict(bands=[BLU, BLU, MAG, MAG, LRED, LRED, LRED, LRED, LRED, LRED],
                 far=MAG, hill=MAG, red=RED, canopy=GRN, trunk=LGR, cloud=LMAG, reed=GRN, ruin=DGR,
                 stone=LGR, col=DGR, cryst=CYN, stars=None),
    'night': dict(bands=[BLK] * 10,
                  far=BLU, hill=DGR, red=RED, canopy=GRN, trunk=LGR, cloud=DGR, reed=GRN, ruin=DGR,
                  stone=LGR, col=DGR, cryst=CYN, stars=(WHT, LGR)),
    'cave': dict(bands=[BLK] * 10,
                 far=DGR, hill=DGR, red=DGR, canopy=GRN, trunk=LGR, cloud=DGR, reed=GRN, ruin=DGR,
                 stone=LGR, col=DGR, cryst=CYN, stars=None),
    'mist': dict(bands=[BLK, DGR, DGR, DGR, DGR, DGR, DGR, DGR, DGR, DGR],
                 far=BLK, hill=BLK, red=BLK, canopy=GRN, trunk=LGR, cloud=LGR, reed=GRN, ruin=DGR,
                 stone=LGR, col=DGR, cryst=CYN, stars=None),
}


def smooth2(m, r=1):
    """VZ-resolution shape -> Microbee resolution with rounded corners"""
    a = up2(m).astype(np.float32)
    k = 2 * r + 1
    b = _ndi.uniform_filter(a, size=k, mode='nearest')
    return b > 0.5


def outside_of(mask):
    """air connected to the top of the map, or only shut in under something
    thin (under a jetty): the rest is underground"""
    air = ~mask
    lab, n = _ndi.label(air)
    out = np.zeros_like(mask)
    top = set(np.unique(lab[0][air[0]])) - {0}
    for i, sl in enumerate(_ndi.find_objects(lab)):
        k = i + 1
        m = lab[sl] == k
        if k in top:
            out[sl] |= m
            continue
        # how deep is the ground over it?
        y0, x0 = sl[0].start, sl[1].start
        th = []
        for j in range(m.shape[1]):
            col = np.nonzero(m[:, j])[0]
            if not len(col):
                continue
            y = y0 + col[0] - 1
            d = 0
            while y >= 0 and mask[y, x0 + j]:
                d += 1
                y -= 1
            th.append(d if y >= 0 else 99)
        if th and np.mean(th) < 6:
            out[sl] |= m
    return out


def comps(m):
    lab, n = _ndi.label(m)
    out = []
    for i, sl in enumerate(_ndi.find_objects(lab)):
        out.append((lab[sl] == i + 1, sl))
    return out


def ellipse_mask(cx, cy, rx, ry, h=MH, w=MW):
    return ((XX - cx) / max(rx, 0.5)) ** 2 + ((YY - cy) / max(ry, 0.5)) ** 2 <= 1.0


def thick_line(m, x0, y0, x1, y1, w):
    """draw into bool array m a line of width w (pixels, horizontal)"""
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    r = w / 2.0
    hh, ww = m.shape
    for i in range(n + 1):
        t = i / n
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        ya, yb = int(np.floor(y - r / 1.8)), int(np.ceil(y + r / 1.8))
        xa, xb = int(np.floor(x - r)), int(np.ceil(x + r))
        for yy in range(max(0, ya), min(hh, yb + 1)):
            for xx in range(max(0, xa), min(ww, xb + 1)):
                if ((xx + 0.5 - x) / r) ** 2 + ((yy + 0.5 - y) * 1.8 / r) ** 2 <= 1.0:
                    m[yy, xx] = True


def backdrop(rep, seed):
    """the sky bands (or the cave dark underground)"""
    th = THEMES[rep['bg']]
    img = np.zeros((MH, MW), np.uint8)
    for r in range(MH // CH):
        img[r * CH:(r + 1) * CH] = th['bands'][r]
    if rep['bg'] != 'cave':
        inside = ~up2(rep['outside'])
        img[inside] = BLK
    return img


class Painter:
    def __init__(self, rep, seed):
        self.rep = rep
        self.seed = seed
        self.solid = up2(rep['mask'])
        self.th = THEMES[rep['bg']]
        self.out = up2(rep['outside']) if rep['bg'] != 'cave' else np.zeros((MH, MW), bool)
        self.img = backdrop(rep, seed)
        self.r = rng(seed)
        self.cloud = np.zeros((MH, MW), bool)
        self.later = []                 # cave columns: behind, not paper

    def colour(self, key, m=None):
        """scenery colour: underground (or in a cave level) the cave theme"""
        return self.th[key], THEMES['cave'][key]

    def put(self, m, c_out, c_in=None, img=None):
        img = self.img if img is None else img
        m = m & ~self.solid
        if c_in is None:
            c_in = c_out
        img[m & self.out] = c_out
        img[m & ~self.out] = c_in

    def layer(self, name):
        L = self.rep['layers']
        if name in T and T[name] in L:
            return L[T[name]]
        return np.zeros((H, W), bool)

    # ----- the big scenery (also part of the paper colours) -----
    def hills(self):
        far = smooth2(self.layer('farhill'), 2)
        self.put(far, self.th['far'], DGR)
        near = smooth2(self.layer('hill'), 1)
        self.put(near, self.th['hill'], DGR)
        rh = self.layer('redhill')
        for m, sl in comps(rh):
            big = np.zeros((H, W), bool)
            big[sl] = m
            mm = smooth2(big, 1)
            area = m.sum()
            outside = self.rep['outside'][sl][m].mean() > 0.5 and self.rep['bg'] != 'cave'
            if outside:
                # a red dust haze about the mounds
                dots = ((XX + 2 * YY) % 5 == 0) & (YY % 2 == 0)
                self.put(mm & dots, self.th['red'])
            else:
                self.later.append((sl, DGR, BLK, None))

    def column(self, sl, body, line, glint=None):
        """flowstone at the back of a cave: a stalactite meeting a stalagmite"""
        x0, x1 = sl[1].start * 2, sl[1].stop * 2
        y0, y1 = sl[0].start * 2, sl[0].stop * 2
        cx = (x0 + x1) / 2.0
        w = (x1 - x0) / 2.0
        r = rng(self.seed + x0)
        m = np.zeros((MH, MW), bool)
        ph = r.uniform(0, 6)
        waist = r.uniform(0.18, 0.35)
        for yy in range(y0, y1):
            t = (yy - y0) / float(max(1, y1 - y0 - 1))
            hw = w * (waist + (1 - waist) * (abs(t - 0.5) * 2) ** 2.2)
            hw += 0.8 * np.sin(yy * 0.7 + ph)
            xc = cx + 1.2 * np.sin(t * 3 + ph)
            m[yy, int(round(xc - hw)):int(round(xc + hw)) + 1] = True
        fl = (((XX - x0) % 4) == 1) & ((YY + (XX * 7) % 5) % 9 > 1)
        self.put(m, body)
        self.put(m & fl, line)
        if glint is not None:
            self.put(m & fl & ((YY + XX) % 11 == 0), glint)

    def crystals(self):
        cr = self.layer('cryst')
        for m, sl in comps(cr):
            big = np.zeros((H, W), bool)
            big[sl] = m
            ys, xs = np.nonzero(big)
            if m.sum() > 200:           # a crystal column
                self.later.append((sl, BLU, BLK, CYN))
                continue
            # a cluster of shards growing out of one point
            x0, x1 = xs.min() * 2, xs.max() * 2 + 1
            y0, y1 = ys.min() * 2, ys.max() * 2 + 1
            cx, base = (x0 + x1) / 2.0, y1 - 2
            sh = np.zeros((MH, MW), bool)
            hl = np.zeros((MH, MW), bool)
            r = rng(self.seed + int(cx))
            n = 3 + int(r.integers(0, 2))
            for k in range(n):
                u = (k - (n - 1) / 2.0)
                ang = u * 0.5 + r.normal(0, 0.07)          # radians from upright
                ln = (y1 - y0) * (0.95 - 0.22 * abs(u)) * r.uniform(0.85, 1.05)
                hw = 3.2 - 0.5 * abs(u)
                bx = cx + u * 3
                dx, dy = np.sin(ang) * 1.8, -np.cos(ang)        # display space -> pixels
                nx, ny = np.cos(ang), np.sin(ang) / 1.8
                for i in range(int(ln * 3) + 1):
                    t = i / (ln * 3)
                    half = hw if t < 0.72 else hw * (1 - (t - 0.72) / 0.28)
                    px, py = bx + dx * ln * t, base + dy * ln * t
                    for s in np.linspace(-half, half, int(half * 4) + 2):
                        xx, yy = int(round(px + nx * s)), int(round(py + ny * s))
                        if 0 <= xx < MW and 0 <= yy < MH:
                            sh[yy, xx] = True
                            if s < -0.3:
                                hl[yy, xx] = True
            hl &= sh
            self.put(sh, CYN)
            self.put(hl, LCYN)

    def clouds(self):
        cl = self.layer('cloud')
        r = rng(self.seed + 9)
        c = self.th['cloud']
        for m, sl in comps(cl):
            x0, x1 = sl[1].start * 2, sl[1].stop * 2
            y0, y1 = sl[0].start * 2, sl[0].stop * 2
            w = x1 - x0
            base = y1 - 3
            cm = ellipse_mask((x0 + x1) / 2.0, base - 2, w / 2.0, 3.2) & (YY <= base)
            k = 3 + int(w > 70)
            for i in range(k):
                px = x0 + w * (i + 0.6 + r.uniform(-0.2, 0.2)) / (k + 0.2)
                rr = w * r.uniform(0.13, 0.2)
                cm |= ellipse_mask(px, base - rr / 1.8 * 0.9, rr, rr / 1.8) & (YY <= base)
            self.put(cm, c)
            self.cloud |= cm & ~self.solid

    def ruins(self):
        ru = self.layer('ruin')
        for m, sl in comps(ru):
            big = np.zeros((H, W), bool)
            big[sl] = m
            mm = up2(big)
            ys, xs = np.nonzero(mm)
            y0, x0 = ys.min(), xs.min()
            r = rng(self.seed + x0)
            # masonry, with the top knocked about and blocks fallen out
            bh, bw = 6, 12
            row = (YY - y0) // bh
            off = (row % 2) * (bw // 2)
            colb = (XX - x0 + off) // bw
            keep = np.ones((MH, MW), bool)
            hts = {}
            for c in np.unique(colb[mm]):
                hts[c] = int(r.integers(0, 3)) if r.random() < 0.7 else int(r.integers(2, 5))
            for c, k in hts.items():
                keep &= ~((colb == c) & (row < k))
            for _ in range(int(mm.sum() // 500)):
                rr, cc = int(r.integers(0, row[mm].max() + 1)), int(r.choice(list(hts)))
                keep &= ~((row == rr) & (colb == cc))
            wall = mm & keep
            mortar = ((YY - y0) % bh == bh - 1) | (((XX - x0 + off) % bw) == bw - 1)
            self.put(wall, self.th['ruin'])
            self.put(wall & mortar, BLK)

    def pillars(self):
        st = self.layer('stone') | self.layer('rock')
        if not st.any():
            return
        mm = up2(st)
        c = self.th['stone']
        self.put(mm, c)
        # fluting and joints
        for m, sl in comps(st):
            x0, x1 = sl[1].start * 2, sl[1].stop * 2
            y0, y1 = sl[0].start * 2, sl[0].stop * 2
            box = np.zeros((MH, MW), bool)
            box[y0:y1, x0:x1] = True
            box &= mm
            fl = ((XX - x0) % 4 == 3) & (YY > y0 + 6) & (XX < x1 - 1)
            joint = ((YY - y0) % 14 == 6)
            self.put(box & (fl | joint), DGR)
            r = rng(self.seed + x0)
            # a broken top
            for xx in range(x0, x1):
                k = int(r.integers(0, 3)) if r.random() < 0.5 else 0
                if k:
                    self.put((XX == xx) & (YY >= y0) & (YY < y0 + k), self.img[0, 0])

    # ----- trees and scrub (not part of the paper colours) -----
    def trees(self):
        can = self.layer('canopy')
        trunk = self.layer('trunk')
        if not (can.any() or trunk.any()):
            return
        cc = self.th['canopy']
        tc = self.th['trunk']
        if self.rep['bg'] == 'dusk':
            cc, tc = GRN, LGR
        # trunks first (the canopy hides their tops)
        tm = np.zeros((MH, MW), bool)
        branches = []
        for m, sl in comps(trunk):
            x0, x1 = sl[1].start * 2, sl[1].stop * 2
            y0, y1 = sl[0].start * 2, sl[0].stop * 2
            cx = (x0 + x1) / 2.0
            r = rng(self.seed + x0)
            lean = r.uniform(-2.5, 2.5)
            hgt = y1 - y0
            for yy in range(y0, y1):
                t = (y1 - yy) / float(hgt)          # 0 at the ground, 1 at the top
                w = 3.0 + 4.5 * (1 - t) ** 3 + 1.5 * (1 - t)
                xc = cx + lean * t * t + 0.8 * np.sin(t * 5 + x0)
                tm[yy, int(round(xc - w / 2)):int(round(xc + w / 2))] = True
            # two or three limbs up into the crown
            fy = y0 + hgt * 0.35
            fx = cx + lean * 0.4
            for dx, dy, w in ((-9, -12, 2.4), (8, -14, 2.4), (-1, -16, 2.0)):
                ex, ey = fx + dx + r.uniform(-2, 2), fy + dy
                thick_line(tm, fx, fy, ex, ey, w)
                branches.append((ex, ey))
        tm &= ~self.solid
        # the crown: clumps of leaves with sky through them
        cm = smooth2(can, 1)
        d = _ndi.distance_transform_edt(cm)
        n1 = noise(self.seed + 7, scale=4)
        n2 = noise(self.seed + 8, scale=2)
        n3 = noise(self.seed + 6, scale=6)
        leaf = cm & ((n1 * 0.45 + n3 * 0.35 + n2 * 0.2) + np.minimum(d, 6) / 14.0 > 0.66)
        # gum leaves hang in clumps: ragged bottoms
        drop = np.zeros_like(leaf)
        drop[2:] = leaf[:-2]
        leaf |= drop & cm & (n2 > 0.5)
        # no cloud behind a crown in the same cell (three colours)
        occ = (tm | leaf).reshape(MH // CH, CH, MW // CW, CW).any(axis=(1, 3))
        occ = np.repeat(np.repeat(occ, CH, 0), CW, 1)
        kill = occ & self.cloud
        self.img[kill] = backdrop(self.rep, 0)[kill]
        self.put(tm, tc)
        self.put(leaf, cc)

    def reeds(self):
        rd = self.layer('reed')
        for m, sl in comps(rd):
            x0, x1 = sl[1].start * 2, sl[1].stop * 2
            y0, y1 = sl[0].start * 2, sl[0].stop * 2
            r = rng(self.seed + x0)
            bl = np.zeros((MH, MW), bool)
            hd = np.zeros((MH, MW), bool)
            x = x0 + 1
            while x < x1 - 1:
                h = (y1 - y0) * r.uniform(0.45, 1.0)
                bend = r.uniform(-3, 3)
                thick_line(bl, x, y1 + 2, x + bend, y1 - h, 1.0)
                if r.random() < 0.3:
                    thick_line(hd, x + bend * 0.9, y1 - h + 1, x + bend * 0.85, y1 - h + 5, 2.2)
                x += int(r.integers(2, 5))
            self.put(bl, self.th['reed'])
            self.put(hd, BRN)

    def stars(self):
        st = self.th['stars']
        if not st:
            return
        r = rng(self.seed + 3)
        for cy in range(MH // CH):
            for cx in range(MW // CW):
                ys, xs = slice(cy * CH, cy * CH + CH), slice(cx * CW, cx * CW + CW)
                if self.solid[ys, xs].any() or not self.out[ys, xs].all():
                    continue
                if (self.img[ys, xs] != BLK).any():
                    continue
                v = r.random()
                p = 0.55 - cy * 0.06
                if v < p:
                    y = cy * CH + int(r.integers(1, CH - 1))
                    x = cx * CW + int(r.integers(0, CW))
                    self.img[y, x] = st[0] if v < p * 0.3 else st[1]
                    if v < p * 0.08 and 0 < x < MW - 1:
                        self.img[y, x - 1] = self.img[y, x + 1] = LGR


# ---------------------------------------------------------------------------
# the ground
# ---------------------------------------------------------------------------
# material: (light, dark, pattern); the dark one is the cell paper when dug
MATS = {
    'dirt':    (BRN, RED, 'pebble'),
    'earth':   (BRN, RED, 'pebble2'),
    'rock':    (DGR, BLK, 'cobble'),
    'brick':   (RED, DGR, 'brick'),
    'moss':    (GRN, LGRN, 'pebble'),
    'stone':   (LGR, DGR, 'blocks'),
    'steel':   (LGR, WHT, 'plates'),
    'wood':    (BRN, BLK, 'planks'),
    'crystal': (CYN, LCYN, 'facets'),
    'red':     (RED, BRN, 'layers'),
    'yellow':  (YEL, BRN, 'pebble'),
    'green':   (GRN, LGRN, 'pebble'),
    'sand':    (YEL, BRN, 'sand'),
    'leaves':  (GRN, LGRN, 'pebble'),
    'checker': (RED, YEL, 'checker'),
    'gstone':  (GRN, LGRN, 'blocks'),
    'redhill': (RED, BRN, 'layers'),
    'ruin':    (LGR, DGR, 'blocks'),
    'farhill': (BRN, RED, 'pebble'),
}
NATURAL = ('dirt', 'earth', 'rock', 'red', 'redhill', 'sand', 'moss', 'green', 'yellow', 'leaves', 'farhill')


def _pebbles(seed, dens, rx=(1.5, 3.0), ry=(0.8, 1.6)):
    """scattered little stones (bool)"""
    r = rng(seed)
    out = np.zeros((MH, MW), bool)
    n = int(MH * MW * dens)
    xs = r.uniform(0, MW, n)
    ys = r.uniform(0, MH, n)
    ax = r.uniform(*rx, n)
    ay = r.uniform(*ry, n)
    for x, y, a, b in zip(xs, ys, ax, ay):
        ya, yb = int(y - b), int(y + b) + 1
        xa, xb = int(x - a), int(x + a) + 1
        for yy in range(max(0, ya), min(MH, yb + 1)):
            for xx in range(max(0, xa), min(MW, xb + 1)):
                if ((xx + 0.5 - x) / a) ** 2 + ((yy + 0.5 - y) / b) ** 2 <= 1.0:
                    out[yy, xx] = True
    return out


def _voronoi_edges(seed, sx, sy):
    """cracks between jittered cells (cobbles)"""
    r = rng(seed)
    gy, gx = MH // sy + 3, MW // sx + 3
    px = (np.arange(gx)[None, :] - 1 + r.uniform(0.15, 0.85, (gy, gx))) * sx
    py = (np.arange(gy)[:, None] - 1 + r.uniform(0.15, 0.85, (gy, gx))) * sy
    cy = YY // sy + 1
    cx = XX // sx + 1
    d1 = np.full((MH, MW), 1e9)
    d2 = np.full((MH, MW), 1e9)
    for oy in (-1, 0, 1):
        for ox in (-1, 0, 1):
            qx = px[np.clip(cy + oy, 0, gy - 1), np.clip(cx + ox, 0, gx - 1)]
            qy = py[np.clip(cy + oy, 0, gy - 1), np.clip(cx + ox, 0, gx - 1)]
            d = (XX - qx) ** 2 + ((YY - qy) * 1.6) ** 2
            d2 = np.where(d < d1, d1, np.minimum(d2, d))
            d1 = np.minimum(d1, d)
    return np.sqrt(d2) - np.sqrt(d1) < 1.6


def texture(name, seed, solid_lab=None):
    """-> (pattern: True = dark colour) for a material over the whole map"""
    light, dark, pat = MATS[name]
    if pat == 'pebble':
        a = _pebbles(seed, 0.0035, (1.5, 3.2), (0.7, 1.4))
        sp = rng(seed + 1).random((MH, MW)) < 0.012
        sp[:, 1:] |= sp[:, :-1] & (rng(seed + 2).random((MH, MW - 1)) < 0.5)
        return a | sp
    if pat == 'pebble2':
        # deeper, redder soil: clots of red clay through it
        n = noise(seed + 4, scale=5)
        a = (n > 0.70) & (rng(seed + 2).random((MH, MW)) < 0.45)
        a |= _pebbles(seed, 0.004, (1.5, 2.8), (0.7, 1.2))
        a |= rng(seed + 1).random((MH, MW)) < 0.02
        return a
    if pat == 'cobble':
        return _voronoi_edges(seed, 14, 9)
    if pat == 'blocks':
        row = YY // 8
        r = rng(seed)
        offs = r.integers(0, 16, MH // 8 + 1)
        jn = ((XX + offs[row]) % 16) == 15
        hor = (YY % 8) == 7
        return hor | jn
    if pat == 'brick':
        row = YY // 6
        return ((YY % 6) == 5) | (((XX + (row % 2) * 6) % 12) == 11)
    if pat == 'plates':
        # light plates with bright bevels and rivets ('dark' here is the WHITE)
        bev = (YY % 12 == 0) | (XX % 16 == 0)
        riv = ((YY % 12 == 3) | (YY % 12 == 9)) & ((XX % 16 == 3) | (XX % 16 == 12))
        return bev | riv
    if pat == 'planks':
        return None
    if pat == 'facets':
        f = (((XX + YY // 2) % 12) == 0) | (((XX - YY // 2) % 12) == 0)
        return f
    if pat == 'layers':
        # bedded sandstone: long level seams, a few cross-cracks
        n = noise(seed + 2, scale=40)
        wav = ((YY + (n * 4).astype(int)) % 7 == 0) & (noise(seed + 5, scale=6) > 0.3)
        return wav | (rng(seed + 1).random((MH, MW)) < 0.015)
    if pat == 'sand':
        n = noise(seed + 2, scale=8)
        rip = ((YY + (n * 6).astype(int)) % 7 == 0) & (((XX + YY * 3) % 11) < 4)
        return rip | (rng(seed + 1).random((MH, MW)) < 0.012)
    if pat == 'checker':
        return ((XX // 2) + (YY // 2)) % 2 == 0
    return np.zeros((MH, MW), bool)


def paint_ground(img, solid, rep, seed):
    lab = up2(rep['mat'])
    mats = dict(MATS)
    if rep['bg'] == 'dusk':
        mats['earth'] = (RED, BRN, 'pebble2')          # the red centre
    th = rep['bg']
    st = up2(rep['strata'])
    ta, tb = rep.get('strata_t', (None, None))
    for name, (light, dark, pat) in mats.items():
        if name not in T:
            continue
        k = solid & (lab == T[name])
        if not k.any():
            continue
        if pat == 'planks':
            out = np.full((MH, MW), light, np.uint8)
            for m, sl in comps(k):
                hh = sl[0].stop - sl[0].start
                ww = sl[1].stop - sl[1].start
                y0, x0 = sl[0].start, sl[1].start
                if hh > ww * 1.2:        # a post: vertical grain
                    gap = (XX - x0) % 6 == 5
                    grain = ((YY * 3 + XX * 7) % 23 == 0)
                else:                    # boards
                    gap = ((YY - y0) % 4 == 3) | ((((XX + ((YY - y0) // 4) * 13) % 29) == 0))
                    grain = ((XX * 5 + YY * 11) % 37 == 0)
                box = np.zeros((MH, MW), bool)
                box[sl] = m
                out[box & (gap | grain)] = dark
            img[k] = out[k]
            continue
        pt = texture(name, seed + 31 * T[name])
        out = np.where(pt, dark, light).astype(np.uint8)
        img[k] = out[k]
    k = solid & (lab < 0)
    img[k] = RED
    # the strata bands: pebbles of the band's material through the body
    for band, t in ((1, ta), (2, tb)):
        if t is None:
            continue
        kb = solid & (st == band)
        if not kb.any():
            continue
        nm = TEXNAMES[t]
        bl = MATS.get(nm, (DGR, BLK, ''))[0]
        if bl in (YEL, WHT, LCYN):
            peb = rng(seed + 70 + band).random((MH, MW)) < 0.05
        else:
            peb = _pebbles(seed + 70 + band, 0.03, (2.0, 4.0), (0.8, 1.6))
        body = lab
        for name, (light, dark, pat) in MATS.items():
            if name in T and pat in ('pebble', 'pebble2', 'layers', 'sand'):
                kk = kb & (body == T[name])
                if bl == light:
                    continue
                # calm the body's own speckle round the band, then the stones
                near = _ndi.binary_dilation(kk, iterations=3) & solid & (body == T[name])
                img[near] = light
                img[kk & peb] = bl
    return img


def paint_lips(img, solid, rep):
    """turf / sun-baked crusts on the tops the design marks, dark undersides"""
    lab = up2(rep['mat'])
    run = np.zeros((MH, MW), np.int16)
    for y in range(MH):
        run[y] = np.where(solid[y], (run[y - 1] + 1) if y else 1, 0)
    th = rep['bg']
    if rep['etop']:
        m, c = rep['etop']
        top = up2(m) & (run == 1)
        # only on the flat-ish tops, not down the sides of things
        near = _ndi.binary_dilation(top, structure=np.ones((7, 1), bool))
        ok = np.zeros_like(top)
        for d in (3,):
            l = np.zeros_like(top)
            rr = np.zeros_like(top)
            l[:, d:] = near[:, :-d]
            rr[:, :-d] = near[:, d:]
            ok = l & rr
        top &= ok
        nat = np.zeros((MH, MW), bool)
        for n in NATURAL:
            if n in T:
                nat |= lab == T[n]
        nz = noise(rep['lv'].n * 13 + 5, scale=3)
        depth = (4 + (nz * 3.99).astype(int))            # 4-7 rows
        lip = np.zeros((MH, MW), bool)
        sh = top.copy()
        for k in range(8):
            lip |= sh & (k < depth)
            sh = np.roll(sh, 1, 0)
            sh[0] = False
            sh &= solid
        lip &= nat
        # which lips are out under the sky (grass) and which underground
        outs = up2(rep['outside'])
        osh = np.zeros_like(outs)
        osh[1:] = outs[:-1]
        from_out = top & osh
        sh = from_out.copy()
        lipout = np.zeros_like(lip)
        for k in range(8):
            lipout |= sh
            sh = np.roll(sh, 1, 0)
            sh[0] = False
            sh &= solid
        cave = th == 'cave'
        for name, (light, dark, pat) in MATS.items():
            if name not in T:
                continue
            for outside in (True, False):
                kk = lip & (lab == T[name]) & (lipout if outside and not cave else ~lipout if not cave else lip)
                if not kk.any():
                    continue
                cc = c
                if cc == 0 and not (outside and not cave):
                    cc = 1                      # no grass underground
                if cc == 0:
                    col = GRN
                elif cc == 1:
                    if light == DGR:
                        col = LGR               # a lit rock ledge
                    elif name in ('red', 'redhill'):
                        col = BRN
                    elif outside and not cave:
                        col = YEL               # dry grass, sun-baked
                    else:
                        continue
                elif cc == 3:
                    col = dark
                else:
                    continue
                img[kk] = col
                if cave:
                    break
    if rep['ebot']:
        m, c = rep['ebot']
        dn = np.zeros((MH, MW), np.int16)
        for y in range(MH - 1, -1, -1):
            dn[y] = np.where(solid[y], (dn[y + 1] + 1) if y < MH - 1 else 1, 0)
        bot = up2(m) & (dn == 1) & (YY < MH - 2)          # not the floor of the map
        und = bot.copy()
        und[:-1] |= bot[1:] & solid[:-1]
        for name, (light, dark, pat) in MATS.items():
            if name not in T or pat in ('plates',):
                continue
            kk = und & (lab == T[name])
            col = dark if c == 3 else (GRN if c == 0 else light)
            if col == WHT:
                continue
            img[kk] = col
    return img


# ---------------------------------------------------------------------------
# the hatch and the burrow
# ---------------------------------------------------------------------------
HATCH_ART = [          # a hollow log; its trapdoor (the middle cell) hangs open
    "..bBBBBBBBBBBBBBBBBBYYY.",
    ".bBBbBBBBBbBBBBBbBBYyyyY",
    "bBBBBBBbBBBBBBBBBBYyKKyY",
    "BBbBBBBBBBBbBBBBBBYKKKKY",
    "BBBBBbBBBBBBBBBbBBYyKKyY",
    "bBBBBBBBBBBBBBBBBBBYyyyY",
    ".bBBBBbBBBBBBbBBBBBBYYY.",
    "..bBBBBBKKKKKKKKBBBBb...",
    ".......B........B.......",
    "......B..........B......",
    "......B..........B......",
    "........................",
]
BURROW_ART = [         # a mound of fresh earth, the hole (the middle cell), a little flag
    "..................rRRR..",
    ".................WrRRRR.",
    ".................WrRR...",
    ".................Wr.....",
    ".................W......",
    ".........bBBBBB..W......",
    "......BBBBBBBBBBBW......",
    "....BBBbBBBBBBBbBBBB....",
    "...BBBBBBBKKKKBBBBbBB...",
    "..BBbBBBKKKKKKKKBBBBBB..",
    "..BBBBBBKKKKKKKKBBBbBB..",
    ".BBBBBBBKKKKKKKKBBBBBBB.",
    ".BbBBBBBKKKKKKKKBBBBbBB.",
    "BBBBBBBBKKKKKKKKBBBBBBBB",
    "BBBBbBBBKKKKKKKKBBBBBBBB",
    "BBBBBBBBKKKKKKKKBbBBBBBB",
]
ART_COL = {'B': BRN, 'b': RED, 'Y': YEL, 'y': BRN, 'K': BLK, 'W': LGR, 'r': RED, 'R': LRED, 'G': GRN}


def art_array(rows, cmap=ART_COL):
    a = np.full((len(rows), len(rows[0])), -1, np.int16)
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch != '.':
                a[j, i] = cmap[ch]
    return a


def blit(img, solid, a, x0, y0, also=None):
    h, w = a.shape
    for j in range(h):
        yy = y0 + j
        if not (0 <= yy < MH):
            continue
        for i in range(w):
            xx = x0 + i
            v = a[j, i]
            if v >= 0 and 0 <= xx < MW and not solid[yy, xx]:
                img[yy, xx] = v
                if also is not None:
                    also[yy, xx] = v


def hatch_art():
    """a hollow log in one colour (the cells give it only the one), its
    open end a ring the sky shows through, the trapdoor in its belly open"""
    a = np.full((12, 24), -1, np.int16)
    yy, xx = np.mgrid[0:12, 0:24]
    body = (yy >= 1) & (yy <= 6) & (xx >= 1) & (xx <= 20)
    body |= ((xx - 1.5) / 1.6) ** 2 + ((yy - 3.6) / 2.9) ** 2 <= 1
    ring = ((xx - 20.5) / 3.2) ** 2 + ((yy - 3.6) / 3.3) ** 2 <= 1
    hole = ((xx - 20.6) / 1.7) ** 2 + ((yy - 3.6) / 1.8) ** 2 <= 1
    m = (body | ring) & ~hole
    for x, y in ((5, 2), (6, 2), (12, 4), (13, 4), (16, 2), (9, 5), (3, 4)):
        m[y, x] = False                                     # cracks in the bark
    m[6:8, 8:16] = False                                    # the open trapdoor
    m[7, 2:20] &= ~((xx[7, 2:20] >= 8) & (xx[7, 2:20] < 16))
    for k in range(4):                                      # the doors hanging
        m[7 + k, 7 - k // 2] = True
        m[7 + k, 16 + k // 2] = True
    a[m] = BRN
    return a


def paint_hatch_exit(img, solid, lv, bd=None):
    hx, hy = lv.hatch
    blit(img, solid, hatch_art(), hx * 2, hy * 2)
    ex, ey = lv.exit
    a = art_array(BURROW_ART)
    blit(img, solid, a, ex * 2 - 12, ey * 2 + 2 - a.shape[0])
    if bd is not None:
        # the cells that hold ground can only show one air colour: the
        # mound's sides take its earth colour, the middle cell the hole
        x0 = ex * 2 - 12
        cy = (ey * 2 + 1) // CH
        ys = slice(cy * CH, cy * CH + CH)
        for k, c in ((0, BRN), (1, BLK), (2, BRN)):
            xs = slice(x0 + k * CW, x0 + k * CW + CW)
            if 0 <= x0 + k * CW < MW:
                sub = bd[ys, xs]
                sub[~solid[ys, xs]] = c
        if cy > 0:
            # and the cell above, when the mound reaches into it
            ys = slice((cy - 1) * CH, cy * CH)
            b = a.copy()
            b[b == LGR] = -1
            b[(b == RED) | (b == LRED)] = -1
            blit(bd, solid, np.where(b == BLK, BLK, np.where(b >= 0, BRN, -1)).astype(np.int16), x0, ey * 2 + 2 - a.shape[0])
    return img


# ---------------------------------------------------------------------------
# the pictures
# ---------------------------------------------------------------------------
def paint_stamps(img, solid, rep, bd=None):
    import stamps_hi
    for name, x0, y0, flip, mask_then in rep['stamps']:
        a = stamps_hi.get(name, rep['bg'])
        if flip:
            a = a[:, ::-1]
        h, w = a.shape
        for j in range(h):
            yy = y0 * 2 + j
            if not (0 <= yy < MH):
                continue
            for i in range(w):
                xx = x0 * 2 + i
                v = a[j, i]
                if v >= 0 and 0 <= xx < MW and not solid[yy, xx] and not mask_then[yy // 2, xx // 2]:
                    img[yy, xx] = v
                    if bd is not None:
                        bd[yy, xx] = v
    return img


def paint_logo(img, logo):
    big = up2(logo)
    # one colour: each 8 x 16 cell can only give the letters one
    cm = {0: YEL, 1: YEL, 3: YEL}
    for k, c in cm.items():
        img[big == k] = c
    return img


def paint_water(img, solid, lv, bd=None):
    if not lv.water:
        return img
    wy, x0, x1 = lv.water
    r = rng(wy * 7 + x0)
    for target in ([img] + ([bd] if bd is not None else [])):
        for yy in range(wy * 2, MH):
            d = yy - wy * 2
            for xx in range(x0 * 2, min(MW, x1 * 2)):
                if solid[yy, xx]:
                    continue
                if target is bd:
                    target[yy, xx] = BLU
                    continue
                if d == 0:
                    target[yy, xx] = LCYN if (xx // 2) % 5 else BLU
                elif d == 1:
                    target[yy, xx] = LCYN if (xx // 2 + 2) % 5 == 0 else BLU
                else:
                    ph = (xx + (yy // 3) * 5) % 19
                    target[yy, xx] = CYN if (yy % 3 == 0 and ph < 4 and d < 14) else BLU
    return img


def paint_level(lv, seed=None):
    rep = replay(lv)
    seed = seed if seed is not None else (sum(map(ord, lv.name)) * 7919) & 0xFFFF
    solid = up2(rep['mask'])
    rep['outside'] = outside_of(rep['mask'])
    p = Painter(rep, seed)
    # the far things: these also decide the paper of the cells that hold ground
    p.hills()
    p.clouds()
    p.ruins()
    p.pillars()
    bd = p.img.copy()
    p.crystals()
    shards = p.img != bd
    keep = p.img.copy()
    for args in p.later:
        p.column(*args)
    p.img[shards] = keep[shards]
    p.trees()
    p.reeds()
    img = p.img
    tr = (img == p.th['trunk']) & (bd != img)
    bd[tr] = img[tr]
    img = paint_stamps(img, solid, rep, bd)
    img = paint_hatch_exit(img, solid, lv, bd)
    img = paint_water(img, solid, lv, bd)
    p.img = img
    p.stars()
    img = paint_ground(img, solid, rep, seed)
    img = paint_lips(img, solid, rep)
    if (rep['logo'] >= 0).any():
        img = paint_logo(img, rep['logo'])
    bd[solid] = img[solid]
    rep['backdrop'] = bd
    return img, solid, rep


def to_rgb(img):
    return PAL[img].astype(np.uint8)


# ---------------------------------------------------------------------------
# two colours a cell
# ---------------------------------------------------------------------------
def _dist(a, b):
    d = PAL[a] - PAL[b]
    return (d * d * np.array([3, 4, 2])).sum(-1)


DIST = np.array([[_dist(i, j) for j in range(16)] for i in range(16)])


def _mode(v, exclude=None):
    c = np.bincount(v, minlength=16)
    if exclude is not None:
        c[exclude] = -1
    return int(c.argmax()), c


NOPAPER = {YEL: BRN, WHT: LGR, LCYN: CYN}


def compile_cells(img, solid, mono=False, bgimg=None):
    """-> bits (160 x 1024 bool), colour (10 x 128: paper<<4 | ink), dug (10 x 128)"""
    bits = np.zeros((MH, MW), bool)
    col = np.zeros((MH // CH, MW // CW), np.uint8)
    dug = np.zeros_like(col)
    # the ground's top few rows count for more when a cell's ground gets one colour
    run = np.zeros((MH, MW), np.int16)
    for y in range(MH):
        run[y] = np.where(solid[y], (run[y - 1] + 1) if y else 1, 0)
    wgt = np.where(solid & (run <= 7), 4, 1)
    lit = _mono_lit(img, solid) if mono else None
    for cy in range(MH // CH):
        for cx in range(MW // CW):
            ys, xs = slice(cy * CH, cy * CH + CH), slice(cx * CW, cx * CW + CW)
            p = img[ys, xs].ravel().astype(int)
            s = solid[ys, xs].ravel()
            ns = int(s.sum())
            if mono:
                if 0 < ns < len(p):
                    ink, paper, b = WHT, DGR, s.copy()            # ground bright, air dim
                elif ns == len(p):
                    # lit but for the dark texture (cracks, pebbles, bevels)
                    maj = int(np.bincount(p, minlength=16).argmax())
                    b = (p == maj) | ((LUM[p] > LUM[maj] + 40) & (p != WHT))
                    b |= (wgt[ys, xs].ravel() > 1) & (LUM[p] >= 75)
                    ink, paper = WHT, BLK
                else:
                    ink, paper, b = LGR, DGR, lit[ys, xs].ravel()
            elif 0 < ns < len(p):
                # the top rows (the turf) win only when the cell is mostly
                # air: a cell that is mostly ground stays the ground's colour
                wv = wgt[ys, xs].ravel()[s]
                if ns > 0.6 * len(p):
                    wv = np.where(wv > 1, 0.3, 1.0)
                cnt = np.bincount(p[s], weights=wv, minlength=16)
                ink = int(cnt.argmax())
                bg = (bgimg[ys, xs] if bgimg is not None else img[ys, xs]).ravel().astype(int)[~s]
                pc = np.bincount(bg, minlength=16).astype(float)
                for k, v in NOPAPER.items():
                    pc[v] += pc[k] * 0.9
                    pc[k] = -1
                paper = int(pc.argmax())
                if ink == paper:
                    # the ground is the air's colour here: show it in the
                    # most contrasting colour it has much of
                    cnt[paper] = -1
                    tot = cnt[cnt > 0].sum()
                    cands = [c for c in range(16) if cnt[c] >= 0.1 * tot]
                    if cands:
                        ink = max(cands, key=lambda c: abs(LUM[c] - LUM[paper]))
                    else:
                        ink = BLK if LUM[paper] > 100 else LGR
                b = s.copy()
            else:
                ink, paper, b = _best_pair(p, solid_cell=ns > 0,
                                           w=wgt[ys, xs].ravel() if ns == len(p) else None)
                if paper in NOPAPER:                 # bright colours only as ink
                    if ink not in NOPAPER:
                        ink, paper, b = paper, ink, ~b
                    else:
                        paper = NOPAPER[paper]
            bits[ys, xs] = b.reshape(CH, CW)
            col[cy, cx] = (paper << 4) | ink
            if ns == len(p):
                dp = BLK if ink != BLK else DGR
                if mono:
                    dp = BLK
                dug[cy, cx] = (dp << 4) | ink
            else:
                dug[cy, cx] = col[cy, cx]
    return bits, col, dug


def _best_pair(p, solid_cell, w=None):
    if w is None:
        w = np.ones(len(p))
    cols = np.unique(p)
    cnt = np.array([w[p == c].sum() for c in cols])
    if len(cols) == 1:
        c = int(cols[0])
        other = BLK if c != BLK else DGR
        if solid_cell:
            return c, other, np.ones(len(p), bool)
        return other, c, np.zeros(len(p), bool)
    order = cols[np.argsort(-cnt)][:5]
    best = None
    for i in range(len(order)):
        for j in range(i + 1, len(order)):
            a, b = int(order[i]), int(order[j])
            e = (np.minimum(DIST[p, a], DIST[p, b]) * w).sum()
            if best is None or e < best[0]:
                best = (e, a, b)
    _, a, b = best
    near_b = DIST[p, b] < DIST[p, a]
    # paper: darker for solid (digging shows it), commonest for air
    if solid_cell:
        paper, ink = (a, b) if LUM[a] <= LUM[b] else (b, a)
    else:
        na = int((~near_b).sum())
        paper, ink = (a, b) if na >= len(p) - na else (b, a)
        if paper in (YEL, WHT, LCYN):
            paper, ink = ink, paper
    bits = (near_b if ink == b else ~near_b)
    return ink, paper, bits


def _mono_lit(img, solid):
    """amber monitor, the air: the sky bands and the far hills stay dim (with
    the hills' outlines lit), scenery is lit - dark colours on every other
    pixel, so they read as shade"""
    lit = np.zeros((MH, MW), bool)
    for r in range(MH // CH):
        ys = slice(r * CH, r * CH + CH)
        p = img[ys]
        air = ~solid[ys]
        cnt = np.bincount(p[air].ravel(), minlength=16)
        tot = max(1, air.sum())
        bg = np.where(cnt >= 0.22 * tot)[0]
        if len(bg) == 0:
            bg = [int(cnt.argmax())]
        isbg = np.isin(p, bg)
        sc = ~isbg & air
        dark = LUM[p] < 70
        chk = ((np.arange(CH)[:, None] + np.arange(MW)[None, :]) % 2) == 0
        l = sc & (~dark | chk)
        # outlines between two background colours (a hill on the sky)
        up = np.zeros_like(p)
        up[1:] = p[:-1]
        up[0] = p[0]
        lf = np.zeros_like(p)
        lf[:, 1:] = p[:, :-1]
        lf[:, 0] = p[:, 0]
        edge = isbg & air & (((up != p) & np.isin(up, bg)) | ((lf != p) & np.isin(lf, bg)))
        lit[ys] = l | edge
    return lit


def render_cells(bits, col):
    """-> RGB of the compiled picture"""
    ink = np.repeat(np.repeat(col & 15, CH, 0), CW, 1)
    paper = np.repeat(np.repeat(col >> 4, CH, 0), CW, 1)
    return PAL[np.where(bits, ink, paper)].astype(np.uint8)


def save_preview(path, rgb, aspect=1.8, scale=2):
    from PIL import Image
    im = Image.fromarray(rgb)
    im = im.resize((im.width * scale, int(im.height * scale * aspect)), Image.NEAREST)
    im.save(path)
