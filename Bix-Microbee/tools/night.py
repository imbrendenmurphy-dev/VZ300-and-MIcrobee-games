"""BIX THE BILBY for the Microbee Premium Plus: the night look, in 8 x 10 cells.

The screen is 40 x 25 cells of 8 x 10 pixels (320 x 250, a full PAL picture).
A tile is 16 x 20 pixels (2 x 2 cells): a VZ pixel becomes 2 pixels across
and 2.5 lines down, which is about the shape it had on the VZ.

The background is the night: black, with the far scenery (hills, clouds,
trees, the moon...) painted in faint dots. Big fills (earth, rock, water,
leaves) repeat every cell, so the whole level is built from few cell glyphs.

THE SCROLL. Every screen cell shows a "quad": the 2 x 2 world cells it can
overlap, as a glyph at one of 12 phases (4 horizontal steps of 2 pixels x 3
vertical steps of 0, 3 and 7 lines). Phase k of a quad slot is in PCG bank k,
so a scroll step rewrites only the cells' bank. Here the quads of every stage
are listed with their inks at each phase; the glyphs themselves are worked
out by the Z80 when a quad is loaded into a slot.
"""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / 'vz'))
import gfx
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE, PALETTE, epx, chars, rnd, PRIO)
import art as vz

CW, CH = 8, 10
TW, TH = 16, 20
VOFF = (0, 3, 7)
NPH = 12
NQ = 1024                       # quad table entries (a hash)
SLOTS = 128
BUDGET = 116                    # quads on show at once, leaving slots for digging and logs

BG_TILES = ('sky_tw', 'sky_tw2', 'cloudL', 'cloudM', 'cloudR', 'moonTL', 'moonTR', 'moonBL', 'moonBR',
            'hillL', 'hillM', 'hillR', 'hillB', 'hillBT')
ALT = {'soil': 'soilD', 'soil2': 'soilD', 'bstar': 'soilD', 'grass': 'grassD', 'star': 'sky',
       'bonus': 'used', 'termite': 'sky', 'check': 'checkon'}


def stretch20(b):
    """16 rows -> 20 (rows 0, 4, 8 and 12 twice)"""
    idx = [r * 16 // 20 for r in range(20)]
    return b[idx]


def cells10(img, void, st):
    """20 x 16 colour characters -> (bits 20 x 16, ink 2 x 2): each 8 x 10
    cell takes its commonest colour, everything lit in it takes that ink"""
    bits = np.zeros((TH, TW), bool)
    ink = np.zeros((2, 2), int)
    for cy in range(2):
        for cx in range(2):
            q = img[cy * CH:cy * CH + CH, cx * CW:cx * CW + CW]
            cnt = {}
            for ch in q.flat:
                if ch != void and st.get(ch) is not None:
                    cnt[ch] = cnt.get(ch, 0) + 1
            if not cnt:
                continue
            best = max(cnt, key=lambda c: (cnt[c], c))
            ink[cy, cx] = st[best]
            for y in range(CH):
                for x in range(CW):
                    ch = q[y, x]
                    bits[cy * CH + y, cx * CW + x] = ch != void and st.get(ch) is not None
    return bits, ink


def pic(rows):
    return np.array([[c == '#' for c in r] for r in rows])


# ---- cell textures that repeat every cell (8 x 10)
SOIL = pic([
    "########",
    "##.#####",
    "########",
    "######.#",
    "########",
    "########",
    "#.######",
    "########",
    "####.###",
    "########",
])
TUNNEL = pic([
    "........",
    "..#.....",
    "........",
    "......#.",
    "........",
    "........",
    "...#....",
    "........",
    "#.......",
    "........",
])
ROCK = pic([
    "#######.",
    "#######.",
    "##.####.",
    "#######.",
    "........",
    "###.####",
    "###.####",
    "###.#.##",
    "###.####",
    "........",
])
WATER = pic([
    "........",
    "..###...",
    "........",
    ".......#",
    "........",
    "........",
    "......##",
    "#.......",
    "........",
    "...#....",
])
WATERT = pic([
    "........",
    "........",
    "........",
    ".##...##",
    "#..###..",
    "........",
    "..#.....",
    "........",
    "......#.",
    "........",
])
LEAF = pic([
    "####.###",
    "########",
    "##.#####",
    "#####.##",
    "########",
    ".#######",
    "########",
    "###.##.#",
    "########",
    "######.#",
])
# turf: the cell row on top of the earth (a grass tile is turf over soil)
TURF = {
    1: ["..#...#.", ".##.#.##", ".######.", "########", "########", "########", "#.##.###", "########", "########", "###.####"],
    2: ["...#....", "..###..#", "..###.##", ".#######", "########", "########", "##.##.##", "########", "########", "##.#####"],
    3: ["########", "##..##..", ".##..##.", "########", "........", "########", "#.######", "########", "########", "####.###"],
    4: ["........", "..##....", ".####.##", "########", "########", "########", "###.####", "########", "########", "######.#"],
    5: ["........", ".#....#.", "###..###", "########", "########", "#.##.###", "########", "########", "###.####", "########"],
}
STAR = [
    "................",
    "................",
    ".......##.......",
    ".......##.......",
    "......####......",
    "......####......",
    "......####......",
    ".##############.",
    "..############..",
    "...##########...",
    "....########....",
    "....########....",
    "....########....",
    "...####..####...",
    "...###....###...",
    "..###......###..",
    "..##........##..",
    "..#..........#..",
    "................",
    "................",
]

# per world: the void character in the VZ art, inks, and each tile's style
W1_STYLE = dict(gfx.STYLE)
WORLDS = {
    1: dict(void='b', default=dict(gfx.DEF), style=W1_STYLE, earth=RED, turf=BGREEN, water=(BCYAN, BBLUE),
            rock=GREY, leaf=GREEN, paint=BLUE, moon=WHITE),
}
for w in (2, 3, 4, 5):
    Wd = gfx.WORLD[w]
    WORLDS[w] = dict(void=Wd['void'], default=Wd['default'], style=Wd['style'], earth=Wd['earth'], turf=Wd['turf'],
                     water=Wd['water'], rock={2: GREY, 3: DGREY, 4: GREY, 5: GREY}[w],
                     leaf={2: BLUE, 3: DGREY, 4: CYAN, 5: DGREY}[w],
                     paint={2: BLUE, 3: DGREY, 4: DGREY, 5: RED}[w],
                     moon={2: BCYAN, 3: CYAN, 4: YELLOW, 5: RED}[w])


def uniform(cellbits, ink):
    bits = np.zeros((TH, TW), bool)
    for cy in range(2):
        for cx in range(2):
            bits[cy * CH:cy * CH + CH, cx * CW:cx * CW + CW] = cellbits
    return bits, np.full((2, 2), ink)


def tiles(world):
    """-> {name: [bits 20 x 16, ink 2 x 2, prio]}"""
    Wd = WORLDS[world]
    src = {n: rows for n, rows, _ in vz.TILES} if world == 1 else __import__('art2').__dict__['W%d_TILES' % world]
    void = Wd['void']
    T = {}
    for name, _rows, _attr in vz.TILES:
        rows = src.get(name)
        if rows is None or name in BG_TILES:
            T[name] = [np.zeros((TH, TW), bool), np.zeros((2, 2), int), 2]
            continue
        st = {'g': None, 'y': None, 'r': None, 'b': None} if world > 1 else {}
        st.update(Wd['default'])
        st.update(Wd['style'].get(name, {}))
        img = stretch20(epx(chars(rows), void))
        bits, ink = cells10(img, void, st)
        T[name] = [bits, ink, PRIO.get(name, 2)]
    earth, turf = Wd['earth'], Wd['turf']
    b, i = uniform(SOIL, earth)
    T['soil'] = [b, i, PRIO['soil']]
    T['soil2'] = [b.copy(), i.copy(), PRIO['soil']]
    b, i = uniform(TUNNEL, earth)
    T['soilD'] = [b, i, PRIO['soilD']]
    turfc = pic(TURF[world])
    b, i = uniform(SOIL, earth)
    b[:CH, :CW] = turfc
    b[:CH, CW:] = turfc
    i[0, :] = turf
    T['grass'] = [b, i, PRIO['grass']]
    b, i = uniform(TUNNEL, earth)
    b[:CH, :CW] = turfc
    b[:CH, CW:] = turfc
    i[0, :] = turf
    T['grassD'] = [b, i, PRIO['grassD']]
    b, i = uniform(ROCK, Wd['rock'])
    T['rock'] = [b, i, PRIO['rock']]
    b2, i2 = uniform(ROCK, Wd['rock'])
    b2[0, :] = True
    T['rocktop'] = [b2, i2, PRIO['rocktop']]
    b, i = uniform(LEAF, Wd['leaf'])
    T['leaf'] = [b, i, 2]
    star = pic(STAR)
    T['star'] = [star, np.full((2, 2), YELLOW), PRIO['star']]
    bs = star.copy()
    bs[0, :] = bs[TH - 1, :] = True
    T['bstar'] = [bs, np.full((2, 2), YELLOW), PRIO['bstar']]
    if Wd['water']:
        b, i = uniform(WATER, Wd['water'][1])
        T['water'] = [b, i, 3]
        bt, it = uniform(WATER, Wd['water'][1])
        bt[:CH, :CW] = WATERT
        bt[:CH, CW:] = WATERT
        it[0, :] = Wd['water'][0]
        T['watert'] = [bt, it, 3]
    else:
        T['water'] = [np.zeros((TH, TW), bool), np.zeros((2, 2), int), 2]
        T['watert'] = [np.zeros((TH, TW), bool), np.zeros((2, 2), int), 2]
    # the 45 degree ramps
    for name, right in (('slopeR', True), ('slopeL', False)):
        b = np.zeros((TH, TW), bool)
        for y in range(TH):
            for x in range(TW):
                xx = x if right else TW - 1 - x
                edge = (TW - 1 - xx) * TH / TW
                if y >= edge:
                    b[y, x] = True if y < edge + 4 else SOIL[y % CH, x % CW]
        ink = np.full((2, 2), earth)
        if right:
            ink[0, 1] = turf; ink[1, 0] = turf
        else:
            ink[0, 0] = turf; ink[1, 1] = turf
        T[name] = [b, ink, PRIO[name]]
    return T


def platform_cells():
    """the floating log: 48 x 10, six cells; the VZ's 4 rows at 2.5 lines each"""
    a = epx(chars(vz.PLATFORM), '.')          # 8 x 48
    rows = [0, 0, 1, 2, 3, 4, 4, 5, 6, 7]
    return (a != '.')[rows]


# ------------------------------------------------------------------ the painting
# faint dots, the same in every cell of a level of density (nested)
DOTS = [(0, 0), (4, 5), (2, 3), (6, 8), (6, 1), (2, 7), (0, 4), (4, 9), (3, 1), (7, 6), (1, 8), (5, 2),
        (5, 6), (1, 2), (3, 7), (7, 3), (0, 6), (4, 1), (2, 9), (6, 4)]
LEVELS = (0, 4, 9)
QUANT = (0, 1, 1, 1, 2, 2)


def dot_cell(level):
    b = np.zeros((CH, CW), bool)
    for (x, y) in DOTS[:LEVELS[level]]:
        b[y, x] = True
    return b


def sky_twinkle():
    b = np.zeros((CH, CW), bool)
    b[4, 3] = True
    b[5, 3] = b[4, 4] = True
    return b


def painting(L):
    """the far scenery for a stage: a map of painted cells, (W*2) x (H*2):
    0 nothing, 1..5 a density of dots, 'tw' a twinkling star, ('moon', i)
    a cell of the moon"""
    g, W = L['g'], L['W']
    H = len(g[0])
    CWn, CHn = W * 2, H * 2
    world = L['world']
    dens = np.zeros((CWn, CHn))
    r = rnd(world * 131 + W)

    def blob(cx, cy, rx, ry, d):
        for x in range(max(0, int(cx - rx - 1)), min(CWn, int(cx + rx + 2))):
            for y in range(max(0, int(cy - ry - 1)), min(CHn, int(cy + ry + 2))):
                e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if e < 1:
                    dens[x, y] = max(dens[x, y], d * min(1.0, (1 - e) * 2.2))

    def ridge(x0, x1, base, amp, d, seed, wl=9.0):
        rr = rnd(seed)
        ph = rr(100) / 15.0
        for x in range(max(0, x0), min(CWn, x1)):
            hgt = base - amp * (0.55 + 0.25 * np.sin(x / wl + ph) + 0.2 * np.sin(x / (wl * 0.37) + ph * 2))
            for y in range(int(hgt), CHn):
                t = min(1.0, (y - hgt + 1) / 2.5)
                dens[x, y] = max(dens[x, y], d * t)

    # the VZ level's own background, painted
    seen_moon = []
    for x in range(W):
        for y in range(H):
            t = g[x][y]
            if t in ('cloudL', 'cloudM', 'cloudR'):
                blob(2 * x + 1, 2 * y + 1, 2.6, 1.6, 2.4)
            elif t.startswith('hill'):
                for dx in (0, 1):
                    for dy in (0, 1):
                        dens[2 * x + dx, 2 * y + dy] = max(dens[2 * x + dx, 2 * y + dy], 2.2)
            elif t == 'moonTL':
                seen_moon.append((x, y))
    # each world's own far scenery
    if world == 1:      # the gully at night: ranges and gum trees
        ridge(0, CWn, CHn * 0.62, 7, 1.6, 7, 11)
        for i in range(W // 9):
            tx = i * 18 + r(10)
            base = int(CHn * 0.66)
            h = 6 + r(5)
            for y in range(base - h, base + 2):
                for dx in (0,):
                    if 0 <= tx + dx < CWn:
                        dens[tx + dx, y] = max(dens[tx + dx, y], 2.6)
            blob(tx + 0.5, base - h - 1, 3.2 + r(2), 2.4, 3.0)
            blob(tx - 2, base - h + 1, 2.2, 1.6, 2.6)
            blob(tx + 3, base - h + 1.5, 2.2, 1.6, 2.6)
    elif world == 2:    # caverns: stalactites from the roof, crystal clusters
        for i in range(W // 3):
            tx = i * 6 + r(5)
            ln = 2 + r(6)
            for y in range(ln):
                w = (ln - y) / ln * 1.6
                for x in range(int(tx - w), int(tx + w) + 1):
                    if 0 <= x < CWn:
                        dens[x, 4 + y] = max(dens[x, 4 + y], 2.5 * (1 - y / (ln + 1)) + 0.5)
        for i in range(W // 10):
            tx = i * 20 + r(12)
            base = int(CHn * 0.66)
            for k in range(3):
                h = 3 + r(5)
                cx = tx + k * 2 - 2
                for y in range(h):
                    w = 1.2 * (1 - y / h)
                    for x in range(int(cx - w), int(cx + w) + 1):
                        if 0 <= x < CWn and base - y >= 0:
                            dens[x, base - y] = max(dens[x, base - y], 3.4 - y * 0.25)
    elif world == 3:    # the works: gears, pipes, chimneys
        for i in range(W // 8):
            cx, cy = i * 16 + r(8), 7 + r(10)
            rad = 2.5 + r(3)
            for x in range(int(cx - rad - 2), int(cx + rad + 3)):
                for y in range(int(cy - rad - 2), int(cy + rad + 3)):
                    if 0 <= x < CWn and 0 <= y < CHn:
                        dd = np.hypot((x - cx), (y - cy) * 1.25)
                        ang = np.arctan2(y - cy, x - cx)
                        tooth = rad + (0.9 if np.cos(ang * 8) > 0.3 else 0)
                        if dd < tooth and dd > rad * 0.35:
                            dens[x, y] = max(dens[x, y], 2.8)
        for i in range(W // 12):
            tx = i * 24 + r(14)
            base = int(CHn * 0.7)
            h = 10 + r(8)
            for y in range(base - h, base + 1):
                for x in (tx, tx + 1):
                    if 0 <= x < CWn:
                        dens[x, y] = max(dens[x, y], 2.2)
            blob(tx + 2, base - h - 2, 2.5, 1.5, 1.6)
            blob(tx + 4, base - h - 4, 3.0, 1.6, 1.2)
        ridge(0, CWn, CHn * 0.68, 3, 1.4, 5, 3)
    elif world == 4:    # above the clouds: big soft clouds, far islands
        for i in range(W // 6):
            cx, cy = i * 12 + r(9), 6 + r(14)
            blob(cx, cy, 4 + r(4), 1.8 + r(2), 2.0 + r(2) * 0.5)
            blob(cx + 3, cy - 1, 3, 1.6, 2.4)
        for i in range(W // 16):
            cx, cy = i * 32 + r(20), 10 + r(10)
            blob(cx, cy, 3.5, 1.2, 2.8)
            for y in range(int(cy), int(cy) + 3):
                for x in range(int(cx - 2 + (y - cy)), int(cx + 3 - (y - cy))):
                    if 0 <= x < CWn and y < CHn:
                        dens[x, y] = max(dens[x, y], 2.6)
    elif world == 5:    # the peaks: volcanoes and their smoke
        for i in range(W // 14):
            cx = i * 28 + r(16)
            base = int(CHn * 0.72)
            h = 9 + r(6)
            for y in range(base - h, base + 3):
                w = (y - (base - h)) * 1.4 + 1
                for x in range(int(cx - w), int(cx + w) + 1):
                    if 0 <= x < CWn and 0 <= y < CHn:
                        dens[x, y] = max(dens[x, y], 2.3)
            for k in range(4):
                blob(cx + k * 2 + r(2), base - h - 2 - k * 2.5, 1.8 + k * 0.7, 1.4, 2.6 - k * 0.4)
        ridge(0, CWn, CHn * 0.74, 4, 1.4, 3, 6)
    # the stars of the night sky: a few twinkles high up
    P = [[0] * CHn for _ in range(CWn)]
    for x in range(CWn):
        for y in range(CHn):
            P[x][y] = QUANT[int(round(min(5, dens[x, y])))]
    if world in (1, 4, 5):
        for i in range(W // 2):
            x, y = r(CWn), r(int(CHn * 0.45))
            if P[x][y] == 0:
                P[x][y] = 'tw'
    for (x, y) in seen_moon:
        for dx in range(3):
            for dy in range(3):
                if 2 * x + dx < CWn and 2 * y + dy < CHn:
                    P[2 * x + dx][2 * y + dy] = ('moon', dy * 3 + dx)
    return P


def moon_cells(world):
    """the moon: 24 x 30, nine cells"""
    b = np.zeros((30, 24), bool)
    for y in range(30):
        for x in range(24):
            if ((x - 11.5) / 11.5) ** 2 + ((y - 14.5) / 14) ** 2 < 1:
                b[y, x] = True
    for (cx, cy, rr) in ((8, 9, 2.5), (15, 19, 3), (9, 21, 1.6)):
        for y in range(30):
            for x in range(24):
                if ((x - cx) / rr) ** 2 + ((y - cy) / (rr * 1.2)) ** 2 < 1 and (x + y) % 2:
                    b[y, x] = False
    return [b[cy * CH:cy * CH + CH, cx * CW:cx * CW + CW] for cy in range(3) for cx in range(3)]


# ------------------------------------------------------------------ cell glyphs and quads
class Cells:
    """the cell glyphs of a stage: (10 rows, ink, prio); 0 is empty"""

    def __init__(self):
        self.ids = {}
        self.list = [(bytes(CH), 0, 0)]

    def add(self, bits, ink, prio):
        pat = bytes(np.packbits(bits, axis=1)[:, 0].tolist())
        if pat == bytes(CH):
            return 0
        k = (pat, int(ink), int(prio))
        if k not in self.ids:
            self.ids[k] = len(self.list)
            self.list.append(k)
        return self.ids[k]


def tile_cells(T, C):
    tc = {}
    for name in T:
        bits, ink, prio = T[name]
        tc[name] = [C.add(bits[cy * CH:cy * CH + CH, cx * CW:cx * CW + CW], ink[cy, cx], prio)
                    for cy in (0, 1) for cx in (0, 1)]        # TL TR BL BR
    return tc


def quad_glyph(C, q, h, vi):
    a, b, c, d = (C.list[i][0] for i in q)
    out = []
    for y in range(CH):
        s = y + VOFF[vi]
        L, R = (a[s], b[s]) if s < CH else (c[s - CH], d[s - CH])
        out.append(((L << (2 * h)) | (R >> (8 - 2 * h))) & 255 if h else L)
    return bytes(out)


def quad_inks(C, q):
    """the quad's ink at each phase: the ink of whichever cell shows the most
    lit pixels in the window (on a tie, the higher priority)"""
    cells = [C.list[i] for i in q]
    inks = []
    for vi in range(3):
        for h in range(4):
            cnt = {}
            for y in range(CH):
                s = y + VOFF[vi]
                top = s < CH
                li, ri = (0, 1) if top else (2, 3)
                row = s if top else s - CH
                L = cells[li][0][row]
                R = cells[ri][0][row]
                lbits = bin((L << (2 * h)) & 255).count('1')
                rbits = bin(R >> (8 - 2 * h)).count('1') if h else 0
                for k, nb in ((li, lbits), (ri, rbits)):
                    if nb and q[k]:
                        cnt[k] = cnt.get(k, 0) + nb
            if not cnt:
                inks.append(None)
                continue
            k = max(cnt, key=lambda k: (cnt[k], cells[k][2]))
            inks.append(cells[k][1])
    first = next((i for i in inks if i is not None), 0)
    return [first if i is None else i for i in inks]


def dense(C, i):
    return sum(bin(b).count('1') for b in C.list[i][0]) >= 56


E_PLATH, E_PLATV = 5, 6


def build(L):
    """a stage -> its cell glyphs, cell map, quads"""
    world = L['world']
    T = tiles(world)
    C = Cells()
    tc = tile_cells(T, C)
    Wd = WORLDS[world]
    g, W = L['g'], L['W']
    H = len(g[0])
    CWn, CHn = W * 2, H * 2
    P = painting(L)
    paint_ids = [0] + [C.add(dot_cell(k), Wd['paint'], 1) for k in range(1, len(LEVELS))]
    tw_id = C.add(sky_twinkle(), GREY if world != 5 else YELLOW, 1)
    moon_ids = [C.add(m, Wd['moon'], 2) for m in moon_cells(world)]
    log_bits = platform_cells()
    log_ids = [C.add(log_bits[:, c * CW:c * CW + CW], {1: BROWN, 2: BROWN, 3: BGREEN, 4: WHITE, 5: GREY}[world], 6)
               for c in range(6)]
    # where the floating logs and lifts go: nothing painted there
    clear = np.zeros((CWn, CHn), bool)
    plats = []
    for (x, y, t, p) in L['ents']:
        if t == E_PLATH:
            plats.append(('h', 2 * x, 2 * y, 2 * p))
            clear[max(0, 2 * x - 2):min(CWn, 2 * (x + p) + 8), max(0, 2 * y - 2):min(CHn, 2 * y + 3)] = True
        elif t == E_PLATV:
            plats.append(('v', 2 * x, 2 * y, 2 * p))
            clear[max(0, 2 * x - 2):min(CWn, 2 * x + 8), max(0, 2 * (y - p) - 2):min(CHn, 2 * y + 3)] = True

    def paint_cell(X, R):
        if clear[X, R]:
            return 0
        v = P[X][R]
        if v == 0:
            return 0
        if v == 'tw':
            return tw_id
        if isinstance(v, tuple):
            return moon_ids[v[1]]
        return paint_ids[v]

    # the painting stays a cell clear of anything solid: the scenery stands out
    near = np.zeros((CWn, CHn), bool)
    for x in range(W):
        for y in range(H):
            if g[x][y] not in ('sky',) and g[x][y] not in BG_TILES:
                near[max(0, 2 * x - 1):2 * x + 3, max(0, 2 * y - 1):2 * y + 3] = True

    def cell(tiles_at, X, R):
        if X >= CWn or R >= CHn:
            return 0
        t = tiles_at(X // 2, R // 2)
        i = tc[t][(R & 1) * 2 + (X & 1)]
        if i == 0 and t in ('sky',) + BG_TILES and not near[X, R]:
            return paint_cell(X, R)
        return i

    base = lambda tx, ty: g[tx][ty]
    cg = np.zeros((CWn + 1, CHn + 1), int)
    for X in range(CWn):
        for R in range(CHn):
            cg[X, R] = cell(base, X, R)
    painted = set(paint_ids[1:]) | {tw_id} | set(moon_ids)
    fit_painting(cg, CWn, CHn, painted, moon_ids)
    # the quads: every 2 x 2 neighbourhood, with each tile as it is and as it
    # can become (dug, collected...), and the logs at every place they go
    quads = {}

    def addq(q):
        if q != (0, 0, 0, 0) and q not in quads:
            quads[q] = len(quads)

    def tile_opts(tx, ty):
        if tx >= W or ty >= H:
            return ['sky']
        t = g[tx][ty]
        return [t, ALT[t]] if t in ALT else [t]
    for X in range(CWn):
        for R in range(CHn):
            tps = sorted({(X // 2, R // 2), ((X + 1) // 2, R // 2), (X // 2, (R + 1) // 2), ((X + 1) // 2, (R + 1) // 2)})
            opts = [tile_opts(*tp) for tp in tps]
            import itertools
            for combo in itertools.product(*opts):
                m = dict(zip(tps, combo))
                at = lambda tx, ty: m.get((tx, ty), 'sky')
                addq((cell(at, X, R), cell(at, X + 1, R), cell(at, X, R + 1), cell(at, X + 1, R + 1)))
    # the logs and lifts, a cell at a time along their way
    for (kind, x0, y0, p) in plats:
        positions = [(x0 + k, y0) for k in range(p + 1)] if kind == 'h' else [(x0, y0 - k) for k in range(p + 1)]
        for (lc, lr) in positions:
            def at(X, R, lc=lc, lr=lr):
                if R == lr and lc <= X < lc + 6:
                    return log_ids[X - lc]
                return cg[X, R] if X < CWn and R < CHn else 0
            for X in range(lc - 1, lc + 6):
                for R in (lr - 1, lr):
                    if X >= 0 and R >= 0:
                        addq((at(X, R), at(X + 1, R), at(X, R + 1), at(X + 1, R + 1)))
    return dict(T=T, C=C, tc=tc, cg=cg, W=W, H=H, quads=quads, plats=plats, log_ids=log_ids,
                paint_ids=paint_ids, moon_ids=moon_ids, tw_id=tw_id, world=world)


def quad_ids(cg, CWn, CHn):
    Q = np.zeros((CWn, CHn), np.int32)
    ids = {}
    for X in range(CWn):
        for R in range(CHn):
            q = (cg[X, R], cg[X + 1, R], cg[X, R + 1], cg[X + 1, R + 1])
            Q[X, R] = -1 if q == (0, 0, 0, 0) else ids.setdefault(q, len(ids))
    return Q


def worst_window(Q, CWn, CHn):
    best, where = 0, (0, 0)
    for x0 in range(0, max(1, CWn - 40)):
        for y0 in range(0, CHn - 24 + 1):
            s = np.unique(Q[x0:x0 + 41, y0:y0 + 25])
            n = len(s) - (1 if s[0] == -1 else 0)
            if n > best:
                best, where = n, (x0, y0)
    return best, where


def fit_painting(cg, CWn, CHn, painted, moon_ids, budget=BUDGET):
    """thin the painting wherever too many different quads would be on show:
    first the dots at the edges of the painted shapes (the moon goes last)"""
    for it in range(200):
        Q = quad_ids(cg, CWn, CHn)
        best, (x0, y0) = worst_window(Q, CWn, CHn)
        if best <= budget:
            return it
        cand = []
        for X in range(x0, min(CWn, x0 + 41)):
            for R in range(y0, min(CHn, y0 + 25)):
                if cg[X, R] in painted:
                    nb = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                             if 0 <= X + dx < CWn and 0 <= R + dy < CHn and cg[X + dx, R + dy] in painted)
                    cand.append((cg[X, R] in moon_ids, nb, X, R))
        if not cand:
            return it
        cand.sort()
        for (_m, _nb, X, R) in cand[:max(4, len(cand) // 8)]:
            cg[X, R] = 0
    return it


def window_counts(D):
    """the most quads on show at once (41 x 25 cells), at any camera place"""
    CWn, CHn = D['W'] * 2, D['H'] * 2
    return worst_window(quad_ids(D['cg'], CWn, CHn), CWn, CHn)


def hfun(q):
    a, b, c, d = q
    return ((a * 3) ^ (b * 5) ^ (c * 7) ^ (d * 11) ^ (a >> 3) ^ (c << 2)) & (NQ - 1)


def preview(D, x0, path, scale=2):
    """the stage's picture at phase 0 from cell x0, 40 x 32 cells"""
    from PIL import Image
    C, cg = D['C'], D['cg']
    out = np.zeros((32 * CH, 40 * CW, 3), np.uint8)
    for cx in range(40):
        for cy in range(32):
            i = cg[x0 + cx, cy]
            if not i:
                continue
            pat, ink, _ = C.list[i]
            for y in range(CH):
                for x in range(CW):
                    if (pat[y] >> (7 - x)) & 1:
                        out[cy * CH + y, cx * CW + x] = PALETTE[ink]
    im = Image.fromarray(out)
    im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(path)


# ------------------------------------------------------------------ the stage's data for the Z80
def zhash(q):
    """the Z80's hash of a quad: 1024 entries"""
    a, b, c, d = q
    rl = lambda v, n: ((v << n) | (v >> (8 - n))) & 255
    lo = a ^ rl(b, 1) ^ rl(c, 2) ^ rl(d, 3)
    hi = (a + b + c + d) & 3
    return hi * 256 + lo


def rle(data, back=32):
    """0xxxxxxx: x+1 bytes follow; 10xxxxxx: the next byte x+2 times;
    11xxxxxx: x+2 bytes from 'back' bytes before"""
    out = bytearray()
    i, n = 0, len(data)
    lit = bytearray()

    def flush():
        while lit:
            k = min(128, len(lit))
            out.append(k - 1)
            out.extend(lit[:k])
            del lit[:k]
    while i < n:
        # a copy from the column before
        k = 0
        while i + k < n and i + k - back >= 0 and data[i + k] == data[i + k - back] and k < 65:
            k += 1
        r = 1
        while i + r < n and data[i + r] == data[i] and r < 65:
            r += 1
        if k >= 3 and k >= r:
            flush()
            out.append(0xC0 | (k - 2))
            i += k
        elif r >= 3:
            flush()
            out.append(0x80 | (r - 2))
            out.append(data[i])
            i += r
        else:
            lit.append(data[i])
            i += 1
    flush()
    return bytes(out)


def unrle(enc, back=32):
    out = bytearray()
    i = 0
    while i < len(enc):
        c = enc[i]
        i += 1
        if c < 0x80:
            out += enc[i:i + c + 1]
            i += c + 1
        elif c < 0xC0:
            out += bytes([enc[i]]) * ((c & 63) + 2)
            i += 1
        else:
            for _ in range((c & 63) + 2):
                out.append(out[-back])
    return bytes(out)


def stage_blob(L, D):
    """-> bytes: header, cell glyphs, tile cells, quads, mixed inks, the cell map
    (compressed), the tile map, the spawn list"""
    C = D['C']
    ncg = len(C.list)
    assert ncg <= 255, ncg
    W, H = D['W'], D['H']
    CWn, CHn = W * 2, H * 2
    quads = sorted(D['quads'], key=lambda q: D['quads'][q])
    assert len(quads) <= 700, len(quads)
    cgrow = bytearray()
    for (pat, ink, prio) in C.list:
        cgrow += pat
    names = [n for n, _, _ in vz.TILES]
    tcell = bytearray()
    for n in names:
        tcell += bytes(D['tc'][n])
    tcell = tcell.ljust(256, b'\0')
    mix = []
    qrec = bytearray()
    for q in quads:
        inks = quad_inks(C, q)
        busy = all(dense(C, i) for i in q)
        fl = 0x20 if busy else 0
        if any(len(set(inks[4 * v:4 * v + 4])) > 1 for v in range(3)):
            fl |= 0x10                      # its ink changes across
        if any(len(set(inks[h::4])) > 1 for h in range(4)):
            fl |= 0x08                      # and/or down
        if len(set(inks)) == 1:
            ink = inks[0]
        else:
            ink = len(mix)
            fl |= 0x40
            mix.append(inks)
        qrec += bytes(q) + bytes([ink, fl])
    assert len(mix) <= 256, len(mix)
    mixb = bytearray()
    for inks in mix:
        mixb += bytes(inks)
    cgm = bytearray()
    cg = D['cg']
    for X in range(CWn):
        for R in range(CHn):
            cgm.append(int(cg[X, R]))
    cgm += bytes(CHn)                       # an empty column past the end
    cgz = rle(bytes(cgm))
    assert unrle(cgz) == bytes(cgm)
    g = L['g']
    tm = bytearray()
    for x in range(W):
        for y in range(H):
            tm.append(vz.TID[g[x][y]])
    tm += bytes([vz.TID['sky']]) * H
    e = bytearray()
    for (x, y, t, p) in sorted(L['ents']):
        e += bytes([x & 255, x >> 8, y, t, p])
    e += b'\xff\xff'
    secs = [cgrow, tcell, qrec, mixb, cgz, tm, e]
    off = 40
    offs = []
    for sct in secs:
        offs.append(off)
        off += len(sct)
    hdr = bytearray(40)
    hdr[0:2] = W.to_bytes(2, 'little')
    hdr[2:4] = L['start'][0].to_bytes(2, 'little')
    hdr[4] = L['start'][1]
    hdr[5] = L['boss']
    hdr[6] = L['world']
    hdr[7] = L['act']
    hdr[8] = ncg
    hdr[9:11] = len(quads).to_bytes(2, 'little')
    hdr[11] = len(mix)
    for i, o in enumerate(offs):
        hdr[12 + 2 * i:14 + 2 * i] = o.to_bytes(2, 'little')
    hdr[26:28] = off.to_bytes(2, 'little')
    hdr[32:38] = bytes(D['log_ids'])
    blob = bytes(hdr) + b''.join(bytes(s) for s in secs)
    return blob, dict(ncg=ncg, nq=len(quads), nmix=len(mix), cgz=len(cgz), size=len(blob))
