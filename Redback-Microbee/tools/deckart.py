"""REDBACK deck art: the first capital ship.

Drawn as 1-bit pixels plus an explicit (paper, ink) colour for every 8 x 10
cell, so a cell can never need a third colour. Hull paper is dark grey
throughout, so the colour of a cell only ever changes at a structure's own
border (where a scrolling pair glyph shows one colour for both halves).
"""
import math
import numpy as np

CW, CH = 8, 10
PR = 23                     # playfield rows (screen rows 1..23)
H = PR * CH                 # 230 lines
PW, PH = 16, 30             # a plate: 2 x 3 cells

BLACK, BLUE, RED, GREEN, BROWN, MAG = 0, 4, 1, 2, 3, 5
CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAG, BCYAN, WHITE = 6, 7, 8, 9, 10, 11, 12, 13, 14, 15

DITH = {
    'chk': lambda x, y: (x + y) & 1,
    'sp':  lambda x, y: 1 if (x & 1) == 0 and (y & 1) == 0 else 0,
    'sp2': lambda x, y: 1 if ((x + (y & 1) * 2) & 3) == 0 else 0,
    'dn':  lambda x, y: 1 if (x & 1) == 1 and (y & 1) == 1 else 0,
    'hz':  lambda x, y: y & 1,
    'hz2': lambda x, y: (y >> 1) & 1,
}


class Canvas:
    def __init__(self, wcols):
        self.WC = wcols
        self.W = wcols * CW
        self.bits = np.zeros((H, self.W), np.uint8)
        self.pap = np.zeros((PR, wcols), np.uint8)
        self.ink = np.zeros((PR, wcols), np.uint8)

    def cells(self, cx, cy, w, h, paper, ink):
        self.pap[cy:cy + h, cx:cx + w] = paper
        self.ink[cy:cy + h, cx:cx + w] = ink

    def px(self, x, y, v=1):
        if 0 <= x < self.W and 0 <= y < H:
            self.bits[y, x] = v

    def rect(self, x0, y0, w, h, v=1):
        self.bits[max(y0, 0):min(y0 + h, H), max(x0, 0):min(x0 + w, self.W)] = v

    def hline(self, x0, y, w, v=1):
        self.rect(x0, y, w, 1, v)

    def vline(self, x, y0, h, v=1):
        self.rect(x, y0, 1, h, v)

    def dither(self, x0, y0, w, h, kind, flip=False):
        f = DITH[kind]
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                v = f(x, y)
                self.px(x, y, (1 - v) if flip else v)

    def disc(self, cx, cy, r, v=1, ry=None):
        ry = ry or r
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if ((x + .5 - cx) / r) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, v)

    def disc_dither(self, cx, cy, r, kind, ry=None):
        ry = ry or r
        f = DITH[kind]
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if ((x + .5 - cx) / r) ** 2 + ((y + .5 - cy) / ry) ** 2 <= 1.0:
                    self.px(x, y, f(x, y))


# ---------------------------------------------------------------- plates
def plate(c, pxx, pyy, variant):
    """a 16 x 30 plate at plate position (pxx, pyy) below the top space row"""
    cx, cy = pxx * 2, 1 + pyy * 3
    x0, y0 = cx * CW, cy * CH
    c.cells(cx, cy, 2, 3, DGREY, GREY)
    c.rect(x0, y0, PW, PH, 0)
    c.hline(x0, y0, PW, 1)                  # lit top and left edges
    c.vline(x0, y0, PH, 1)
    for rx, ry in ((3, 3), (PW - 4, 3), (3, PH - 4), (PW - 4, PH - 4)):
        c.px(x0 + rx, y0 + ry, 1)
    if variant == 1:                        # ridges
        for ry in (9, 20):
            c.hline(x0 + 2, y0 + ry, PW - 4, 1)
    elif variant == 2:                      # inspection hatch
        c.rect(x0 + 3, y0 + 8, PW - 6, 14, 1)
        c.rect(x0 + 4, y0 + 9, PW - 8, 12, 0)
        c.rect(x0 + 6, y0 + 13, 4, 4, 1)
    elif variant == 3:                      # chevrons
        for k in range(5):
            c.hline(x0 + 3 + (k & 1), y0 + 6 + k * 4, 9, 1)
            c.hline(x0 + 4 + (k & 1), y0 + 7 + k * 4, 7, 1)


def shade_cells(c, cx, cy, w, h):
    """a shadow block: black paper, dark grey dither"""
    c.cells(cx, cy, w, h, BLACK, DGREY)
    c.rect(cx * CW, cy * CH, w * CW, h * CH, 0)
    c.dither(cx * CW, cy * CH, w * CW, h * CH, 'sp')


# ------------------------------------------------------------ structures
# each takes the plate position (a 2 x 3 cell plate pair spans 4 x 3 cells)
def turret(c, ppx, ppy):
    plate(c, ppx, ppy, 0)
    plate(c, ppx + 1, ppy, 0)
    cx, cy = ppx * 2, 1 + ppy * 3
    # shadow: the bottom row and right column of the 4 x 3 footprint
    shade_cells(c, cx, cy + 2, 4, 1)
    shade_cells(c, cx + 3, cy, 1, 3)
    c.cells(cx, cy, 3, 2, DGREY, WHITE)
    x0, y0 = cx * CW, cy * CH
    c.rect(x0, y0, 24, 20, 0)
    c.disc(x0 + 12, y0 + 10, 10, 1, 9)          # round base
    c.disc(x0 + 12, y0 + 10, 8, 0, 7)
    c.disc_dither(x0 + 12, y0 + 10, 8, 'chk', 7)
    c.disc(x0 + 12, y0 + 10, 5, 1, 4)
    c.disc(x0 + 12, y0 + 10, 3, 0, 2)
    c.rect(x0 + 14, y0 + 8, 18, 4, 1)           # barrel into the shadow column
    c.hline(x0 + 14, y0 + 9, 18, 0)
    c.rect(x0 + 29, y0 + 7, 3, 6, 1)


def silo(c, ppx, ppy):
    plate(c, ppx, ppy, 0)
    plate(c, ppx + 1, ppy, 0)
    cx, cy = ppx * 2, 1 + ppy * 3
    shade_cells(c, cx, cy + 2, 4, 1)
    shade_cells(c, cx + 3, cy, 1, 3)
    x0, y0 = cx * CW, cy * CH
    c.cells(cx, cy, 3, 2, BLACK, YELLOW)
    c.rect(x0, y0, 24, 20, 0)
    c.rect(x0 + 1, y0 + 1, 22, 18, 1)           # hazard frame
    c.rect(x0 + 3, y0 + 3, 18, 14, 0)
    for k in range(0, 22, 4):                   # hazard stripes on the frame
        for y in (1, 2, 17, 18):
            c.px(x0 + 1 + k, y0 + y, 0)
            c.px(x0 + 2 + k, y0 + y, 0)
    c.rect(x0 + 5, y0 + 5, 6, 10, 1)            # open door leaf
    c.rect(x0 + 6, y0 + 6, 4, 8, 0)
    c.dither(x0 + 12, y0 + 5, 7, 10, 'chk')      # silo mouth, dark
    c.rect(x0 + 15, y0 + 7, 3, 6, 1)            # the missile tip
    c.px(x0 + 16, y0 + 6, 1)


def radar(c, ppx, ppy):
    plate(c, ppx, ppy, 1)
    plate(c, ppx + 1, ppy, 1)
    cx, cy = ppx * 2, 1 + ppy * 3
    shade_cells(c, cx, cy + 2, 4, 1)
    shade_cells(c, cx + 3, cy, 1, 3)
    c.cells(cx, cy, 3, 2, DGREY, BCYAN)
    x0, y0 = cx * CW, cy * CH
    c.rect(x0, y0, 24, 20, 0)
    c.disc(x0 + 12, y0 + 10, 11, 1, 9)
    c.disc(x0 + 12, y0 + 10, 10, 0, 8)
    c.disc_dither(x0 + 10, y0 + 8, 9, 'chk', 7)      # dish
    c.disc_dither(x0 + 9, y0 + 7, 4, 'dn', 3)
    c.disc(x0 + 8, y0 + 6, 1, 1)
    c.vline(x0 + 13, y0 + 1, 9, 1)                   # feed arm
    c.px(x0 + 13, y0, 1)


def vent(c, ppx, ppy):
    plate(c, ppx, ppy, 2)
    plate(c, ppx + 1, ppy, 2)
    cx, cy = ppx * 2, 1 + ppy * 3
    shade_cells(c, cx, cy + 2, 4, 1)
    shade_cells(c, cx + 3, cy, 1, 3)
    x0, y0 = cx * CW, cy * CH
    c.cells(cx, cy, 3, 2, BLACK, BRED)
    c.rect(x0, y0, 24, 20, 0)
    for k in range(5):                              # glowing slats
        c.rect(x0 + 2, y0 + 2 + k * 3, 20, 2, 1)
    c.hline(x0 + 2, y0 + 1, 20, 1)
    c.vline(x0 + 1, y0 + 1, 18, 1)
    c.dither(x0 + 2, y0 + 3 + 3, 20, 1, 'chk')


def engine(c, ppx, ppy):
    plate(c, ppx, ppy, 0)
    plate(c, ppx + 1, ppy, 0)
    cx, cy = ppx * 2, 1 + ppy * 3
    shade_cells(c, cx, cy + 2, 4, 1)
    shade_cells(c, cx + 3, cy, 1, 3)
    x0, y0 = cx * CW, cy * CH
    c.cells(cx, cy, 3, 2, BLACK, YELLOW)
    c.rect(x0, y0, 24, 20, 0)
    c.disc(x0 + 12, y0 + 10, 11, 1, 9)
    c.disc(x0 + 12, y0 + 10, 9, 0, 7)
    c.disc_dither(x0 + 12, y0 + 10, 7, 'chk', 6)
    c.disc(x0 + 12, y0 + 10, 3, 1, 3)


STRUCT = {'turret': turret, 'silo': silo, 'radar': radar, 'vent': vent, 'engine': engine}


def conduit(c, ppx, ppy, wp):
    """a pipe along the middle cell row of a plate row, wp plates long"""
    cx, cy = ppx * 2, 1 + ppy * 3 + 1
    c.cells(cx, cy, wp * 2, 1, BLACK, BCYAN)
    x0, y0 = cx * CW, cy * CH
    c.rect(x0, y0, wp * PW, CH, 0)
    c.rect(x0, y0 + 1, wp * PW, 6, 1)
    c.dither(x0, y0 + 5, wp * PW, 1, 'hz2', True)
    c.dither(x0, y0 + 6, wp * PW, 1, 'chk')
    c.hline(x0, y0 + 8, wp * PW, 1)
    c.dither(x0, y0 + 9, wp * PW, 1, 'sp')


def bay(c, ppx, ppy, wp, hp=1):
    cx, cy = ppx * 2, 1 + ppy * 3
    for xx in range(wp):
        for yy in range(hp):
            plate(c, ppx + xx, ppy + yy, 0)
    w, h = wp * 2, hp * 3
    c.cells(cx, cy, w, h, BLACK, GREEN)
    c.cells(cx, cy, w, 1, DGREY, YELLOW)         # hazard bands
    c.cells(cx, cy + h - 1, w, 1, DGREY, YELLOW)
    x0, y0 = cx * CW, cy * CH
    c.rect(x0, y0, w * CW, h * CH, 0)
    for x in range(x0 + 2, x0 + w * CW - 2):
        for y in list(range(y0 + 2, y0 + 8)) + list(range(y0 + h * CH - 8, y0 + h * CH - 2)):
            c.px(x, y, ((x + y) // 3) & 1)
    for k in range(2, w * CW - 6, 12):           # runway guide lights
        c.rect(x0 + k, y0 + (h * CH) // 2 - 1, 3, 2, 1)
    c.rect(x0 + 6, y0 + CH + 1, 1, h * CH - 2 * CH - 2, 1)


def stars(c, rng):
    variants = [(2, 3), (5, 7), (6, 1), (1, 8), (4, 5), (7, 4)]
    for row in (0, PR - 1):
        c.cells(0, row, c.WC, 1, BLACK, WHITE)
        last = -2
        for col in range(c.WC):
            if col - last > 1 and rng.random() < 0.16:
                sx, sy = variants[int(rng.integers(0, len(variants)))]
                c.px(col * CW + sx, row * CH + sy, 1)
                last = col


def build_deck(wcols=200, seed=7):
    rng = np.random.default_rng(seed)
    c = Canvas(wcols)
    c.cells(0, 0, wcols, PR, BLACK, WHITE)
    NPL = wcols // 2
    stars(c, rng)
    first, last = 4, NPL - 7
    cycle = [0, 1, 0, 2, 0, 1, 0, 2]
    for py in range(7):
        for pxx in range(first, last):
            v = cycle[(pxx + 3 * py) % len(cycle)] if (pxx + py) % 3 else 0
            plate(c, pxx, py, v)
    # edge lights on the first and last hull rows
    for pxx in range(first, last):
        x0 = pxx * PW
        if pxx % 4 == 0:
            c.rect(x0 + 6, CH + 2, 3, 2, 1)
            c.rect(x0 + 6, CH + 7 * PH - 5, 3, 2, 1)
    plan = []

    def sect(a, b, kinds, rows, gap=4, prob=0.4):
        px = a
        while px + 2 <= b:
            for py in rows:
                if rng.random() < prob:
                    plan.append((px, py, kinds[int(rng.integers(0, len(kinds)))]))
            px += gap
    sect(8, 32, ['turret', 'vent'], (0, 2, 4, 6), gap=5)
    sect(34, 58, ['silo', 'radar'], (1, 3, 5), gap=5)
    sect(64, 90, ['turret', 'silo'], (0, 2, 4, 6), gap=6)
    occupied = set()
    for px, py, kind in plan:
        if (px, py) in occupied or (px + 1, py) in occupied:
            continue
        occupied.add((px, py))
        occupied.add((px + 1, py))
        STRUCT[kind](c, px, py)
    # the landing bay (3 plate rows tall) in the middle
    for xx in range(44, 52):
        for yy in range(2, 5):
            occupied.add((xx, yy))
    bay(c, 44, 2, 8, 3)
    # conduits across the middle plate rows
    for py in (1, 5):
        px = first
        while px < last:
            if (px, py) in occupied:
                px += 1
                continue
            run = 0
            while px + run < last and (px + run, py) not in occupied and run < 14:
                run += 1
            if run >= 3 and (px * 3 + py) % 2 == 0:
                conduit(c, px, py, run)
            px += run + 1
    for py in (1, 3, 5):
        engine(c, last - 4, py)
    return c


# ---------------------------------------------------------------- cells
def cells_of(c):
    wc = c.WC
    blank = (bytes(10), 0x00)
    table = {blank: 0}
    order = [blank]
    grid = np.zeros((PR, wc), np.int32)
    for r in range(PR):
        for x in range(wc):
            seg = c.bits[r * CH:(r + 1) * CH, x * CW:(x + 1) * CW]
            data = bytes(int(sum(int(seg[y, k]) << (7 - k) for k in range(CW))) for y in range(CH))
            p, i = int(c.pap[r, x]), int(c.ink[r, x])
            if not any(data):
                key = (data, (p << 4) | p)
            elif all(b == 0xFF for b in data):
                key = (bytes(10), (i << 4) | i)
            else:
                key = (data, (p << 4) | i)
            if key not in table:
                table[key] = len(order)
                order.append(key)
            grid[r, x] = table[key]
    return grid, order


def render_cells(grid, order, x0=0, ncols=None):
    from mbee import PALETTE
    pal = np.array(PALETTE, np.uint8)
    R, WC = grid.shape
    ncols = ncols or WC
    img = np.zeros((R * CH, ncols * CW, 3), np.uint8)
    for r in range(R):
        for x in range(ncols):
            gx = x0 + x
            b, col = order[grid[r, gx]] if 0 <= gx < WC else order[0]
            for y in range(CH):
                for k in range(CW):
                    img[r * CH + y, x * CW + k] = pal[(col & 15) if (b[y] >> (7 - k)) & 1 else (col >> 4)]
    return img
