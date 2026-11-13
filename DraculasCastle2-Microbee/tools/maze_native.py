"""Native 208x192 first-person art for all six areas (Premium Plus, 8x8 PCG).

Every wall, floor, decoration and object is evaluated per native pixel from
the game's own procedural materials, then cut into whole character cells.
The perspective is laid out so that every vertical edge and every facing wall
sits on a cell boundary; only the sloping floor/ceiling edges of side walls
cut through cells, and those cells are stored already composed over the fixed
floor/ceiling. A scene is therefore pixel-exact when stamped a cell at a time,
which is what makes the Z80 side fast. Floor objects are the exception: they
carry a mask and are merged with whatever is behind them at run time.
"""
from pathlib import Path
import sys, math, json, pickle, hashlib
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'original/tools'))
import area as AR
import materials as MT
from objects import OBJ
from tone import fogstep

VW, VH, CX = 208, 192, 104
CW, CH = 26, 24
WP = [208, 160, 96, 64, 32]          # facing-wall width at boundary d
TP = [-16, 0, 40, 64, 80]            # ceiling line at boundary d
BT = [216, 192, 160, 136, 120]       # floor line at boundary d
ZB = [0.77, 1.0, 2.0, 3.0, 4.0]
HOR = 100
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0
G, Y, B, R = 0, 1, 2, 3
DARK = {15: 7, 11: 3, 9: 1, 10: 2, 14: 6, 13: 5, 12: 4, 7: 8, 3: 3, 1: 1, 2: 2, 6: 6, 5: 5, 4: 4, 8: 8, 0: 0}

# ---- colour roles: area -> ramp -> {vz colour: Microbee ink}. '*' is the default.
INK = [
    {'*': {G: 10, Y: 11, R: 9}, 'stone': {Y: 15, G: 10, R: 9}, 'moss': {G: 2, Y: 10}, 'hedge': {G: 10, Y: 11},
     'grass': {G: 2}, 'brick': {R: 1, Y: 9}},
    {'*': {G: 10, Y: 11, R: 9}, 'stone': {Y: 15}, 'hi': {Y: 15}, 'tileA': {Y: 7}, 'wood': {R: 3, Y: 11},
     'beam': {R: 3}, 'paper': {R: 9}, 'carpet': {R: 9}},
    {'*': {G: 10, Y: 11, R: 9}, 'wood': {R: 3, Y: 11}, 'stone': {Y: 7}, 'hi': {Y: 15}, 'floor': {R: 3},
     'beam': {R: 3}, 'rug': {G: 2}, 'bk0': {R: 9}, 'bk1': {G: 10}, 'bk2': {Y: 14}, 'bk3': {Y: 13, R: 5}},
    {'*': {G: 10, Y: 14, R: 9}, 'stone': {Y: 7}, 'hi': {Y: 15}, 'moss': {G: 2, Y: 10}, 'slime': {G: 10, Y: 10},
     'bar': {Y: 14, R: 6, G: 6}, 'floor': {Y: 8, R: 8, G: 8}, 'water': {Y: 12, G: 12, R: 12}, 'beam': {R: 3, Y: 3}},
    {'*': {G: 10, Y: 11, R: 9}, 'plaster': {Y: 15, R: 7, G: 7}, 'wood': {R: 3, Y: 11}, 'brass': {Y: 11, R: 3},
     'iron': {Y: 7, R: 8, G: 8}, 'floor': {R: 3, Y: 3}, 'beam': {R: 3, Y: 3}},
    {'*': {G: 10, Y: 11, R: 9}, 'marble': {Y: 5, R: 5, G: 5}, 'vein': {R: 9, Y: 13}, 'gold': {Y: 11, R: 3},
     'velvet': {R: 9, Y: 13}, 'floor': {Y: 13, R: 5, G: 5}, 'hi': {Y: 15}},
]
SIDE_SIMPLE = {'d_door': {'woodd': ('wood', 0), 'iron': ('wood', 0)},
               'd_portrait': {k: ('void', 0) for k in ('skin', 'eyes', 'cloth', 'hair')},
               'd_window': {'glass': ('glass', 1)}}
DECOR_INK = {'frame': {Y: 11, R: 3}, 'iron': {Y: 7}, 'wood': {R: 3, Y: 11}, 'woodd': {R: 3}, 'flame': {Y: 11, R: 9},
             'skin': {Y: 15}, 'eyes': {R: 9}, 'cloth': {R: 5}, 'glass': {G: 10, R: 9, Y: 14}, 'plaque': {Y: 11, R: 3},
             'wax': {Y: 15}, 'brass': {Y: 11, R: 3}}
OBJ_INK = {'*': {'g': 10, 'y': 15, 'r': 9}, 'chest': {'r': 3, 'y': 11}, 'chest_open': {'r': 3, 'y': 11},
           'bones': {'y': 15}, 'grave': {'y': 7, 'g': 2}, 'angel': {'y': 15}, 'armour': {'y': 14, 'r': 9},
           'gargoyle': {'y': 7, 'r': 9}, 'lectern': {'r': 3, 'y': 11}, 'orb': {'y': 14, 'g': 10, 'r': 13},
           'throne': {'r': 9, 'y': 11}, 'throne2': {'r': 9, 'y': 11}, 'bench': {'r': 3, 'y': 11},
           'bell': {'y': 11, 'r': 3}, 'batlord': {'r': 13, 'y': 11}, 'coffin': {'r': 3, 'y': 11},
           'easel': {'r': 3, 'y': 15}, 'keeper': {'y': 15, 'r': 9}, 'vesper': {'y': 15, 'r': 13, 'g': 10},
           'bookseller': {'y': 15, 'r': 3, 'g': 10}, 'kaspar': {'y': 15, 'r': 7, 'g': 10}, 'otto': {'y': 15, 'r': 14, 'g': 10}}


def lerp(a, b, t):
    return a + (b - a) * t


# ---- native wall materials: (u, v, screen x, screen y, side?) -> (ink, level) ----
# level is a dither density; 2 means solid line work that never fades to dither.
LEAF = [".##.......##....", "####.....####..#", "#####...######.#", ".###.##..####...", "..#.####..##....",
        "....#####.......", ".....###....##..", "#.....#....####.", "##.........#####", "##...##.....###.",
        "#...####.....#..", "...######.......", "....####....#...", ".#...##....###..", "###.......#####.",
        ".#.........###.."]


def blocks(u, v, nu, nv, stagger=.5):
    row = math.floor(v / 1.5 * nv)
    bu = u * nu + (stagger if row & 1 else 0)
    col = math.floor(bu)
    return bu - col, v / 1.5 * nv - row, col, row


def masonry(u, v, nu, nv, ink, hi, body=.5, joint=.06, rough=0):
    fu, fv, col, row = blocks(u, v, nu, nv)
    if fu < joint or fv < joint * 1.6:
        return 0, 0
    if fv > .86 or fu < joint * 2.2:
        return hi, 2
    if rough and MT.h2(col, row, rough) < .3:
        return ink, body * .6
    return ink, body


def hedge(u, v, x, y, side):
    if v > 1.44:
        return 10, 2
    if v < .07:
        return 0, 0
    if LEAF[y & 15][x & 15] == '#':
        return 10, 1.0 if not side else .9
    return 2, .34


def grave_wall(u, v, x, y, side):
    if v > 1.4:
        return 15, 2 if v > 1.45 else .5
    ink, level = masonry(u, v, 4, 8, 7, 15, .5, .06, 3)
    if v < .1875 * 2 and ink:                     # two mossy courses at the foot
        return 10 if level == 2 else 2, level if level == 2 else .7
    return ink, level


def hall_stone(u, v, x, y, side):
    return masonry(u, v, 4, 8, 7, 15, .55, .05)


def damask(u, v, x, y, side):
    if v < .375:                                  # panelled dado
        pu = (u * 4) % 1
        if v > .33:
            return 11, 2
        if pu < .06 or pu > .94 or v < .04:
            return 0, 0
        if .16 < pu < .84 and .08 < v < .29 and not (.2 < pu < .8 and .11 < v < .26):
            return 3, 2
        return 3, .55
    if v > 1.41:
        return 11, 2 if v < 1.45 else .6
    pu, pv = (u * 4) % 1, ((v - .375) * 5.33) % 1
    d = abs(pu - .5) + abs(pv - .5)
    if .36 < d < .46 or d < .09:
        return 9, 2
    return 9, .3


def bookshelf(u, v, x, y, side):
    if u < .05 or u > .95 or v > 1.41 or v < .06:
        return 3, 2 if (u < .04 or u > .96 or v > 1.44) else .6
    sh = v / .375
    row = math.floor(sh)
    fv = sh - row
    if fv < .13:
        return 3, 2 if fv > .05 else .5           # shelf board with a shadowed lip
    col = math.floor(u * 20)
    fu = u * 20 - col
    n = MT.h2(col, row, 11)
    if n < .1 or fv > .62 + MT.h2(col, row, 5) * .34 or fu < .14:
        return 0, 0
    ink = (9, 10, 14, 13, 11, 12, 15)[int(n * 97) % 7]
    if .3 < fv < .37 or .52 < fv < .55:
        return ink, .35                           # bands on the spine
    return ink, 1.0 if fu < .8 else .6


def panel_stone(u, v, x, y, side):
    if v < .5:
        pu = (u * 3) % 1
        if v > .44:
            return 11, 2
        if pu < .06 or pu > .94 or v < .05:
            return 0, 0
        return 3, 2 if (.14 < pu < .2 or .8 < pu < .86 or .1 < v < .13 or .37 < v < .4) else .5
    return masonry(u, v - .5, 4, 6, 7, 15, .45, .06)


def dungeon_stone(u, v, x, y, side):
    fu, fv, col, row = blocks(u, v, 2.6667, 6, .37)
    n = MT.h2(col, row, 21)
    if fu < .045 or fv < .1:
        return 0, 0
    drip = MT.h2(int(u * 10), 0, 22)
    if drip > .78 and (u * 10) % 1 < .22 and v > 1.42 - drip * .9:
        return 10, 2
    if v < .25 + n * .22:
        return 2, .75 if fv > .5 else .5
    if fv > .86:
        return 7, 2
    return 7, .42 if n > .3 else .28


def cell_bars(u, v, x, y, side):
    if v > 1.38 or v < .07:
        return 14, 2
    if abs(v - 1.1) < .03 or abs(v - .45) < .03:
        return 14, 2
    bu = (u * 8) % 1
    if bu < .26:
        return 14, 2 if bu < .13 else .5
    return 0, 0


def timber(u, v, x, y, side):
    if u < .05 or u > .95 or v > 1.4375 or v < .0625 or .6875 <= v < .75:
        return 3, 2
    if (abs((u - .05) - (v - .0625) * .66) < .035 and v < .6875) or (abs((.95 - u) - (v - .75) * .7) < .035 and v > .75):
        return 3, 2
    return 15, .62 if MT.h2(int(u * 13), int(v * 11), 31) > .16 else .4


def clockwork(u, v, x, y, side):
    for gx, gy, r, phase in ((.27, .46, .3, 0), (.76, 1.03, .27, .26), (.3, 1.24, .17, .1)):
        dx, dy = u - gx, (v - gy) * .8
        d = math.hypot(dx, dy)
        if d < r:
            ang = math.atan2(dy, dx) + phase
            if d > r * (.86 + .14 * (math.sin(ang * 12) > 0)):
                continue
            if d < r * .16:
                return 7, 2
            if d < r * .28 or r * .62 < d < r * .74 or (abs(math.sin(ang * 3)) < .13 and d < r * .7):
                return 11, 2
            if d > r * .74:
                return 11, .7
            return 3, .35
    if abs(v - .8) < .03 or u < .04 or u > .96 or v > 1.43 or v < .05:
        return 7, 2
    return 0, 0


def marble(u, v, x, y, side):
    pu = (u * 2) % 1
    if pu < .045 or pu > .955 or v < .07 or abs(v - .75) < .028 or v > 1.42:
        return 11, 2 if (pu < .02 or pu > .98 or abs(v - .75) < .012 or v > 1.455 or v < .035) else .5
    vein = math.sin(u * 13 + v * 7 + math.sin(v * 5) * 2)
    if abs(vein) < .09:
        return 9, 2 if abs(vein) < .045 else .5
    vein2 = math.sin(u * 7 - v * 11 + 2)
    if abs(vein2) < .03:
        return 13, .6
    return 5, .16


def velvet(u, v, x, y, side):
    if v > 1.3:
        sc = abs(((u * 6) % 1) - .5)
        if v < 1.3 + sc * .12:
            return 9, .9
        return 11, 2 if v < 1.36 + sc * .12 or v > 1.45 else .6
    fold = (u * 6) % 1
    if fold < .07:
        return 0, 0
    if v < .1 and fold > .5:
        return 11, 2
    return 9, (1.0, .85, .62, .4, .28, .5)[min(5, int(fold * 6.5))]


FAR_INK = [(10, 7), (7, 9), (3, 7), (7, 14), (15, 11), (5, 9)]
WALLS = [(hedge, grave_wall), (hall_stone, damask), (bookshelf, panel_stone), (dungeon_stone, cell_bars),
         (timber, clockwork), (marble, velvet)]


class Painter:
    """Evaluates one area's materials into ink-index pixel maps (-1 = untouched)."""

    def __init__(self, region):
        self.region = region
        self.ad = AR.AREAS[region]
        self.mat = self.ad.mat
        self.mat.ramps = dict(self.mat.ramps)
        self.mat.ramps.update(AR.DECOR_RAMPS)
        self.ink = INK[region]

    def tone(self, name, idx, z, x, y, extra=0, decor=False):
        r = self.mat.ramps[name]
        i = min(len(r) - 1, max(0, idx + fogstep(z) * (1 if decor else self.mat.fogk) + extra))
        c1, c2, f = r[i]
        c = c2 if f > BAYER[y & 3][x & 3] else c1
        if c == B:
            return 0
        table = DECOR_INK.get(name) if decor else None
        ink = (table or {}).get(c)
        if ink is None:
            ink = self.ink.get(name, {}).get(c)
        if ink is None:
            ink = self.ink['*'][c]
        return DARK[ink] if z >= 2.6 else ink

    def surface(self, kind, decor, u, v, z, face, x, y):
        if decor is not None:
            ul = u - face[1] if face[0] == 'side' else u
            t = decor(ul, v, z, face)
            if t is not None:
                if face[0] == 'side':
                    # seen edge-on along a corridor: keep the outline, lose the fiddly detail
                    t = SIDE_SIMPLE.get(decor.__name__, {}).get(t[0], t)
                    if decor.__name__ == 'd_stairs' and .25 <= ul <= .75 and v < .6:
                        t = ('void', 0)
                return self.tone(t[0], t[1], z, x, y, decor=True)
        side = face[0] == 'side'
        if side and (abs(face[2]) == 2 or face[1] == 3):
            # outer walls glimpsed across a side passage: tone only, with a lit top edge
            return self.shade(FAR_INK[self.region][0 if kind == 'A' else 1], 2 if v > 1.38 else .45, z, x, y, True)
        ink, level = WALLS[self.region][0 if kind == 'A' else 1](u - face[1] if side else u, v, x, y, side)
        return self.shade(ink, level, z, x, y, side)

    @staticmethod
    def shade(ink, level, z, x, y, side=False):
        """distance and side-wall shading as dither density; far inks go dark"""
        if level <= 0:
            return 0
        f = fogstep(z)
        if level < 2:                                   # level 2 = always solid line work
            level *= (1.0, .8, .62, .45)[f] * (.8 if side else 1.0)
        if z >= 2.6:
            ink = DARK[ink]
        return ink if level > BAYER[y & 3][x & 3] else 0

    def front(self, img, kind, decor, d, l):
        w = WP[d]
        x0 = CX + (l - 0.5) * w
        for y in range(max(0, TP[d]), min(VH, BT[d])):
            v = 1.5 * (BT[d] - (y + .5)) / (BT[d] - TP[d])
            for x in range(max(0, int(x0)), min(VW, int(x0 + w))):
                u = (x + .5 - x0) / w
                img[y, x] = self.surface(kind, decor, u, v, ZB[d], ('front', d, l), x, y)

    def side(self, img, kind, decor, d, l):
        k = abs(l) - .5
        xa, xb = CX - k * WP[d], CX - k * WP[d + 1]
        for x in range(max(0, int(xa)), min(VW, int(xb))):
            f = (x + .5 - xa) / (xb - xa)
            top, bot = lerp(TP[d], TP[d + 1], f), lerp(BT[d], BT[d + 1], f)
            # perspective-correct distance along the wall
            z = 1 / lerp(1 / ZB[d], 1 / ZB[d + 1], f)
            u = d + (z - ZB[d]) / (ZB[d + 1] - ZB[d])
            for y in range(max(0, math.ceil(top - .5)), min(VH, math.ceil(bot - .5))):
                v = 1.5 * (bot - (y + .5)) / (bot - top)
                xx = x if l < 0 else VW - 1 - x
                img[y, xx] = self.surface(kind, decor, u, v, z, ('side', d, l), xx, y)

    def piece(self, kind, decor, d, l):
        img = np.full((VH, VW), -1, np.int16)
        if d >= 1:
            self.front(img, kind, decor, d, l)
        if l:
            self.side(img, kind, decor if d < 2 else None, d, l)
        return img

    # ---- floor, ceiling and sky ------------------------------------------------
    def plane(self, y, edges):
        """screen row -> (z, facing width in pixels) on the floor or ceiling plane"""
        for d in range(4):
            a, b = edges[d], edges[d + 1]
            if min(a, b) <= y <= max(a, b):
                t = (y - a) / (b - a)
                return 1 / lerp(1 / ZB[d], 1 / ZB[d + 1], t), lerp(WP[d], WP[d + 1], t)
        t = abs(y - HOR) / 20.0
        return (4.0 / max(t, .02)), 32 * max(t, .02)

    def background(self, variant=0):
        img = np.zeros((VH, VW), np.int16)
        for y in range(VH):
            ceiling = y < HOR
            z, w = self.plane(y + .5, TP if ceiling else BT)
            for x in range(VW):
                wx = (x + .5 - CX) / w
                img[y, x] = self.ground(wx, z, x, y, ceiling)
        return img

    def ground(self, wx, z, x, y, ceiling):
        r = self.region
        t = lambda name, i, dz=0.4: self.tone(name, i, max(z - dz, 0), x, y)
        if z > 4.6:
            return 0
        if ceiling:
            if r == 0:
                return 0
            if r == 1:
                return t('beam', 0, .5) if (z * 2) % 1 < .2 else 0
            if r == 2:
                return t('beam', 0, .5) if (z * 2) % 1 < .22 else 0
            if r == 3:
                return t('beam', 1, .3) if (z * 1.5) % 1 < .15 and z < 3.5 else 0
            if r == 4:
                if (z * 1.3) % 1 < .14:
                    return t('beam', 0, .3)
                return t('beam', 1, .3) if abs(wx - .3) < .012 or abs(wx + .45) < .012 else 0
            return t('vein', 0, .5) if (z * 2) % 1 < .12 else 0
        if r == 0:
            if abs(wx) < .2:
                return t('stone', 2 if (z * 3) % 1 > .2 else 4, .3)
            return t('grass', 0 if MT.h2(int(wx * 14 + 99), int(z * 12), 4) > .3 else 1, .3)
        if r == 1:
            if abs(wx) < .24:
                return t('gold', 0) if abs(wx) > .2 else t('carpet', 0)
            chk = (math.floor(wx * 3) + math.floor(z * 3)) & 1
            return t('tileA', 0) if chk else 0
        if r == 2:
            if abs(wx) < .3:
                if abs(wx) > .26:
                    return t('gold', 1)
                return t('rug', 0 if (int(z * 6) & 1) else 1)
            return t('floor', 2) if (z * 5) % 1 < .15 or (wx * 4) % 1 < .06 else t('floor', 0)
        if r == 3:
            n = MT.h2(int(wx * 3 + 50), int(z * 3), 23)
            if n > .82:
                return t('water', 0)
            if (wx * 2.5) % 1 < .06 or (z * 2.5) % 1 < .08:
                return 0
            return t('floor', 0) if n > .25 else t('moss', 2)
        if r == 4:
            return 0 if (wx * 3) % 1 < .06 or (z * 1.5) % 1 < .04 else t('floor', 0)
        if abs(wx) < .26:
            return t('gold', 1) if abs(wx) > .22 else t('velvet', 0)
        chk = (math.floor(wx * 2) + math.floor(z * 2)) & 1
        return t('floor', 0) if chk else 0


# ---- cells -------------------------------------------------------------------
def cell_bits(block):
    """8x8 ink block -> (rows, fg, bg). Two colours exact; otherwise the busiest
    ink is kept and other inks are drawn in it, so no detail is dropped."""
    vals, counts = np.unique(block, return_counts=True)
    order = [int(v) for v, _ in sorted(zip(vals, counts), key=lambda t: -t[1])]
    if len(order) == 1:
        c = order[0]
        return (bytes(8), 0, 0) if c == 0 else (b'\xff' * 8, c, 0)
    if 0 in order:
        inks = [c for c in order if c]
        fg = inks[0]
        on = block == fg
        lit = (block != 0).sum()
        for c in inks[1:]:
            # a strong second ink keeps its pixels (drawn in the main ink);
            # a few stray pixels are dropped, which reads as a dark keyline
            if (block == c).sum() * 3 >= lit:
                on = on | (block == c)
        bg = 0
    else:
        bg, fg = order[0], order[1]
        on = block != bg
    rows = bytes(int(''.join('1' if b else '0' for b in row), 2) for row in on)
    return rows, fg, bg


def cut(img, base, cells_only=None):
    """ink map (-1 outside the piece) over background -> {cell: (rows, fg, bg)}"""
    out = {}
    for cy in range(CH):
        for cx in range(CW):
            blk = img[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            if (blk < 0).all():
                continue
            merged = np.where(blk < 0, base[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8], blk)
            out[cy * 40 + cx] = cell_bits(merged)
    return out


def partial_cells(img):
    s = set()
    for cy in range(CH):
        for cx in range(CW):
            blk = img[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            if (blk < 0).any() and (blk >= 0).any():
                s.add(cy * 40 + cx)
    return s


# ---- floor objects -------------------------------------------------------------
OBJ_FLOOR = {1: 176, 2: 148, 3: 127}
OBJ_SCALE = {1: (2.6, 3.69), 2: (1.33, 1.9), 3: (1.0, 1.36)}
OBJ_TONE = {'y': 1.0, 'r': .75, 'g': .5}


def object_image(name, d):
    import maze_objects
    return maze_objects.object_image(name, d, PALETTE)


def object_image_vz(name, d):
    """Smoothly enlarged sprite: (ink map, opaque mask). 'b' is solid black."""
    art = OBJ[name]
    h, w = len(art), len(art[0])
    sx, sy = OBJ_SCALE[d]
    nw, nh = round(w * sx), round(h * sy)
    from PIL import Image
    layers = {}
    for ch in 'ybrg':
        m = np.array([[255 if c == ch else 0 for c in row] for row in art], np.uint8)
        layers[ch] = np.asarray(Image.fromarray(m).resize((nw, nh), Image.Resampling.BICUBIC), np.int32)
    solid = np.array([[0 if c == '.' else 255 for c in row] for row in art], np.uint8)
    cover = np.asarray(Image.fromarray(solid).resize((nw, nh), Image.Resampling.BICUBIC), np.int32) >= 128
    stack = np.stack([layers[c] for c in 'ybrg'])
    best = stack.argmax(0)
    inks = OBJ_INK.get(name, {})
    img = np.full((VH, VW), -1, np.int16)
    x0, y0 = CX - nw // 2, OBJ_FLOOR[d] - nh
    for y in range(nh):
        for x in range(nw):
            if not cover[y, x]:
                continue
            ch = 'ybrg'[best[y, x]]
            px, py = x0 + x, y0 + y
            if not (0 <= px < VW and 0 <= py < VH):
                continue
            if ch == 'b':
                img[py, px] = 0
                continue
            ink = inks.get(ch, OBJ_INK['*'][ch])
            level = OBJ_TONE[ch] * (1.0 if d == 1 else .85 if d == 2 else .7)
            img[py, px] = (DARK[ink] if d == 3 else ink) if level > BAYER[py & 3][px & 3] else 0
    # one-pixel dark keyline so the figure separates from any wall behind it
    solid = img >= 0
    halo = solid.copy()
    halo[1:, :] |= solid[:-1, :]; halo[:-1, :] |= solid[1:, :]
    halo[:, 1:] |= solid[:, :-1]; halo[:, :-1] |= solid[:, 1:]
    img[halo & ~solid] = 0
    return img


def object_cells(img):
    """-> list of (cell, opaque?, rows, mask, fg). mask bit set = keep background."""
    out = []
    for cy in range(CH):
        for cx in range(CW):
            blk = img[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            if (blk < 0).all():
                continue
            lit = blk > 0
            # an all-black cell still gets an ink, so the merge writes a black
            # background instead of keeping the colours underneath
            fg = 15
            if lit.any():
                vals, counts = np.unique(blk[lit], return_counts=True)
                fg = int(vals[counts.argmax()])
            rows = bytes(int(''.join('1' if b else '0' for b in row), 2) for row in lit)
            mask = bytes(int(''.join('1' if b else '0' for b in row), 2) for row in (blk < 0))
            out.append((cy * 40 + cx, not any(mask), rows, mask, fg))
    return out


# ---- whole area -----------------------------------------------------------------
POSITIONS = [(d, l) for d in range(4) for l in range(-2, 3)]
# (wall kind, decoration) pairs present in each area's map, including its doors
USED = [{(2, 1), (2, 2), (2, 3), (1, 2)},
        {(2, 1), (2, 5), (2, 3), (2, 2), (1, 4), (1, 1)},
        {(2, 3), (2, 2), (2, 1), (1, 1)},
        {(1, 3), (1, 2), (1, 1)},
        {(1, 2), (1, 3), (1, 1)},
        {(2, 1), (1, 1), (2, 3)}]


def castle(base):
    """North-facing skyline for the Grounds; lives only in cells no wall edge crosses."""
    img = np.full((VH, VW), -1, np.int16)
    def box(x0, y0, x1, y1, ink=1):
        for y in range(y0, y1):
            for x in range(x0, x1):
                lit = MT.h2(x // 2, y // 3, 9) > .9 and y > y0 + 4
                img[y, x] = 11 if lit else (ink if (x + y) & 1 or (x ^ y) & 2 else 0)
    box(88, 66, 120, 100)
    for x0, y0, w in ((88, 50, 8), (99, 30, 9), (112, 44, 8)):
        box(x0, y0, x0 + w, 100)
        for i in range(w // 2 + 1):          # spire
            for x in range(x0 + i, x0 + w - i):
                img[y0 - 2 - i * 3:y0 + 1 - i * 3, x] = 1
    for x in range(88, 120, 4):
        img[63:66, x:x + 2] = 1
    return img


def build_area(region, verbose=False):
    cache = ROOT / 'build/maze-native'
    cache.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha256(b''.join((ROOT / p).read_bytes() for p in (
        'tools/maze_native.py', 'original/tools/materials.py', 'original/tools/area.py',
        'original/tools/objects.py', 'tools/maze_objects.py', 'tools/ghoulies.py'))).hexdigest()[:16]
    f = cache / f'area{region}-{key}.pickle'
    if f.exists():
        return pickle.loads(f.read_bytes())
    P = Painter(region)
    ad = P.ad
    base = P.background()
    walls = {}
    crossing = set()
    for ki, kind in enumerate('AB'):
        P.mat.kind = kind
        for pos, (d, l) in enumerate(POSITIONS):
            img = P.piece(kind, None, d, l)
            crossing |= partial_cells(img)
            walls[ki, pos] = img
    if region == 0:
        # stars and a crescent moon, kept clear of every sloping wall edge
        for cy in range(0, 12):
            for cx in range(CW):
                if cy * 40 + cx in crossing:
                    continue
                for n in range(2):
                    if MT.h2(cx, cy, 70 + n) > .55:
                        x = cx * 8 + int(MT.h2(cx, cy, 80 + n) * 7)
                        y = cy * 8 + int(MT.h2(cx, cy, 90 + n) * 7)
                        if y < 92:
                            base[y, x] = 15 if MT.h2(cx, cy, 60 + n) > .5 else 7
        for y in range(8, 32):
            for x in range(120, 144):
                dx, dy = (x - 132) / 11.5, (y - 20) / 11.5
                if dx * dx + dy * dy < 1 and (dx + .45) ** 2 + (dy + .25) ** 2 > .72:
                    base[y, x] = 11
        for cy in range(1, 4):
            for cx in range(15, 18):
                assert cy * 40 + cx not in crossing
    result = {'base': cut(base.copy(), base), 'walls': {}, 'decor': {}, 'objects': {}, 'crossing': sorted(crossing)}
    for (ki, pos), img in walls.items():
        result['walls'][ki, pos] = cut(img, base)
    for di, name in enumerate(ad.decors):
        fn = AR.DECORS[name]
        for ki, kind in enumerate('AB'):
            if (ki + 1, di + 1) not in USED[region]:
                continue
            P.mat.kind = kind
            for pos, (d, l) in enumerate(POSITIONS):
                if abs(l) == 2:
                    continue
                plain = walls[ki, pos]
                if (plain < 0).all():
                    continue
                img = P.piece(kind, fn, d, l)
                changed = (img != plain)
                if not changed.any():
                    continue
                cells = cut(img, base)
                touched = {cy * 40 + cx for cy in range(CH) for cx in range(CW)
                           if changed[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8].any()}
                result['decor'][di, ki, pos] = {c: cells[c] for c in touched}
    for oi, name in enumerate(ad.objects):
        for d in (1, 2, 3):
            result['objects'][oi, d * 5 + 2] = object_cells(object_image(name, d))
    if region == 0:
        img = castle(base)
        assert not (partial_cells(img) | {c for c in cut(img, base)}) & crossing, 'skyline crosses a wall edge'
        result['skyline'] = cut(img, base)
    f.write_bytes(pickle.dumps(result))
    if verbose:
        print('maze art', ad.name, flush=True)
    return result


# ---- reference compositor (what the Z80 must reproduce) ---------------------------
def merge(under, cell):
    _, opaque, rows, mask, fg = cell
    if opaque:
        return (rows, fg, 0)
    urows = under[0]
    return (bytes((u & m) | r for u, m, r in zip(urows, mask, rows)), fg if fg else under[1], 0 if fg else under[2])


def compose(art, view, objs=None, facing=1, decor_count=0):
    """view: {(d,l): (kind 1/2, decor)}; objs: {d: object number}. -> {cell: (rows,fg,bg)}"""
    screen = dict(art['base'])
    if facing == 0 and 'skyline' in art:
        screen.update(art['skyline'])
    solid = lambda d, l: (d, l) in view
    depth = 1 if solid(1, 0) and (solid(0, -1) or solid(1, -1)) and (solid(0, 1) or solid(1, 1)) else \
        2 if solid(2, 0) and (solid(1, -1) or solid(2, -1)) and (solid(1, 1) or solid(2, 1)) else 3
    for d in range(depth, -1, -1):
        for l in (-2, 2, -1, 1, 0):
            pos = d * 5 + l + 2
            if (d, l) in view:
                kind, dec = view[d, l]
                screen.update(art['walls'][kind - 1, pos])
                if dec:
                    screen.update(art['decor'].get((dec - 1, kind - 1, pos), {}))
            elif l == 0 and objs and objs.get(d):
                for cell in art['objects'].get((objs[d] - 1, pos), []):
                    screen[cell[0]] = merge(screen[cell[0]], cell)
    return screen


PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]


def picture(screen, mono=False):
    from PIL import Image
    im = Image.new('RGB', (VW, VH))
    px = im.load()
    for cell, (rows, fg, bg) in screen.items():
        cx, cy = cell % 40, cell // 40
        if mono:
            f, b = ((255, 176, 0), (0, 0, 0)) if fg else ((0, 0, 0), (0, 0, 0))
        else:
            f, b = PALETTE[fg], PALETTE[bg]
        for y in range(8):
            for x in range(8):
                px[cx * 8 + x, cy * 8 + y] = f if rows[y] & (128 >> x) else b
    return im


VIEWS = [
    ({(0, -1): (1, 0), (0, 1): (1, 0), (1, -1): (1, 0), (1, 1): (2, 0), (2, -1): (1, 0), (2, 1): (1, 0), (3, 0): (2, 1)}, {2: 1}),
    ({(0, -1): (2, 0), (0, 1): (1, 0), (1, 0): (2, 2)}, {}),
    ({(0, -1): (1, 0), (0, 1): (1, 0), (1, -1): (1, 2), (1, 1): (1, 0), (2, -1): (2, 0), (2, 1): (2, 0), (3, 0): (1, 1)}, {1: 3}),
    ({(0, -1): (1, 0), (1, -1): (1, 0), (2, -1): (1, 0), (3, -1): (1, 0), (3, -2): (1, 0), (2, -2): (1, 0), (0, 1): (1, 0), (2, 1): (2, 0), (3, 1): (2, 0)}, {3: 2, 1: 4}),
]

if __name__ == '__main__':
    from PIL import Image
    regions = [int(a) for a in sys.argv[1:]] or range(6)
    out = ROOT / 'build/maze-native'
    for region in regions:
        art = build_area(region, True)
        ims = [picture(compose(art, v, o, facing=0 if i == 3 else 1)) for i, (v, o) in enumerate(VIEWS)]
        sheet = Image.new('RGB', (VW * 2 + 6, VH * 2 + 6), (60, 60, 60))
        for i, im in enumerate(ims):
            sheet.paste(im, ((i % 2) * (VW + 6), (i // 2) * (VH + 6)))
        sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(out / f'preview{region}.png')
        glyphs = set()
        for group in ('walls', 'decor'):
            for cells in art[group].values():
                glyphs |= {c[0] for c in cells.values()}
        glyphs |= {c[0] for c in art['base'].values()}
        print(region, 'unique glyphs', len(glyphs), 'crossing cells', len(art['crossing']))
