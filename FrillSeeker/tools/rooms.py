"""FRILLSEEKER rooms. A room is a 16 x 10 map of 16 x 18 pixel tiles, but it
is not drawn from a tile library: each room is *painted* as one 256 x 180
picture (every dirt tile, mound and branch gets its own random texture),
then cut into 4 x 6 cells with their two colours and the patterns
de-duplicated. The game loads a room's own glyph set (up to 1024) when you
walk in, so no two rooms need share art.

Each picture is painted twice: in colour, and for a monochrome monitor
(which shows ink pixels only, so fills become outlines and stipple).
"""
import math
import numpy as np
from art import *

TW, TH = 16, 18
MW, MH = 16, 10
PW, PH = 256, 180

# tile flags
T_EMPTY, T_SOLID, T_ONEWAY, T_WATER = 0, 1, 2, 3
# object types
O_BUG, O_TOAD, O_START = 1, 2, 3

SKY_BANDS = [(7, BLACK), (6, BLUE), (5, MAGENTA), (4, RED), (8, BROWN)]   # cell rows, top to bottom

ROOMS = [
    dict(name='THE RED DIRT', left=-1, right=1, sun=(196, 147, 30), moon=None,
         mesa=[(0, 128), (30, 128), (36, 118), (70, 118), (78, 132), (120, 132), (128, 124), (150, 124), (158, 136), (256, 136)],
         trees=[(40, 144, 78)], map=[
             "................",
             "................",
             "..B.........B...",
             ".---.......==...",
             "................",
             ".......B........",
             ".....====.....B.",
             "S.........T..M..",
             "################",
             "################"]),
    dict(name='BILLABONG', left=0, right=2, sun=None, moon=(40, 26),
         mesa=[(0, 136), (60, 136), (70, 122), (118, 122), (126, 130), (200, 130), (210, 116), (256, 116)],
         trees=[(232, 108, 74)], map=[
             "................",
             "...........B....",
             "....B......--...",
             "...---..........",
             "..........B.....",
             "......=.........",
             "................",
             ".............T..",
             "##~~~o~~~o~~####",
             "################"]),
    dict(name='MOUND CITY', left=1, right=-1, sun=None, moon=(200, 22),
         mesa=[(0, 116), (40, 116), (50, 130), (140, 130), (150, 120), (256, 120)],
         trees=[(20, 144, 70)], map=[
             "................",
             ".............B..",
             "......B....M....",
             "...........M....",
             "........==.M..B.",
             "...........M....",
             ".B.........M....",
             "....M..T..MM.T..",
             "################",
             "################"]),
]


class Paint:
    def __init__(self, seed, ph=0):
        self.ph = ph
        self.c = np.zeros((PH, PW), np.uint8)
        self.m = np.zeros((PH, PW), np.uint8)       # monochrome: 0 dark, 15 lit
        self.rng = np.random.RandomState(seed)
        self.yy, self.xx = np.mgrid[0:PH, 0:PW]

    def put(self, mask, col, mono=None):
        """mono: None = leave, 0 = dark, 1 = lit"""
        self.c[mask] = col
        if mono is not None:
            self.m[mask] = 15 if mono else 0

    def rect(self, x0, y0, x1, y1):
        return (self.xx >= x0) & (self.xx < x1) & (self.yy >= y0) & (self.yy < y1)

    def edge_top(self, mask):
        up = np.zeros_like(mask)
        up[1:] = mask[:-1]
        return mask & ~up

    def outline(self, mask):
        return mask & ~(np.roll(mask, 1, 0) & np.roll(mask, -1, 0) & np.roll(mask, 1, 1) & np.roll(mask, -1, 1))


def sky(p, room):
    y = 0
    for rows, col in SKY_BANDS:
        p.put(p.rect(0, y, PW, y + rows * CH), col, 0)
        y += rows * CH
    # stars in the dark bands; every fourth one twinkles
    for n in range(46):
        x, yy = p.rng.randint(3, PW - 3), p.rng.randint(3, 74)
        col = WHITE if yy < 42 else BCYAN
        big = n % 4 == 0 and (p.ph + n // 4) % 4 == 0
        if big:
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                p.c[yy + dy, x + dx] = col
                p.m[yy + dy, x + dx] = 15
        elif not (n % 4 == 0 and (p.ph + n // 4) % 4 == 2):
            p.c[yy, x] = col
            p.m[yy, x] = 15
    # thin cloud streaks low in the sky
    for i in range(5):
        x0 = p.rng.randint(0, PW - 60)
        yy = 80 + p.rng.randint(0, 5) * 6 + 2
        L = p.rng.randint(24, 60)
        band = p.c[yy, x0]
        lite = {BLUE: BBLUE, MAGENTA: BMAGENTA, RED: BRED, BROWN: YELLOW}.get(int(band), GREY)
        msk = p.rect(x0, yy, x0 + L, yy + 1)
        p.put(msk, lite, None)
        p.put(p.rect(x0, yy, x0 + L, yy + 1) & (p.xx % 2 == 0), lite, 1)
    if room.get('moon'):
        mx, my = room['moon']
        d = (p.xx - mx) ** 2 + ((p.yy - my) * 1.1) ** 2
        d2 = (p.xx - mx - 5) ** 2 + ((p.yy - my + 2) * 1.1) ** 2
        p.put((d < 100) & (d2 > 80), WHITE, 1)
    if room.get('sun'):
        sx, sy, r = room['sun']
        d = (p.xx - sx) ** 2 + ((p.yy - sy) * 1.12) ** 2
        disc = d < r * r
        stripes = np.zeros((PH, PW), bool)
        for k, yy in enumerate(range(sy - 2, sy - r, -5)):
            stripes |= p.rect(0, yy - (1 if k < 3 else 0), PW, yy + 1)
        p.put(disc & ~stripes, YELLOW, None)
        # mono: the sun is a ring and its stripes, not a floodlight
        ring = disc & ~(d < (r - 1.4) ** 2)
        p.put(ring | (disc & stripes & (p.xx % 2 == 0)), YELLOW if False else p.c[0, 0], None)
        p.m[ring] = 15
        p.m[disc & (p.yy % 5 == sy % 5) & (p.xx % 2 == 0)] = 15
        p.c[disc & ~stripes] = YELLOW


def mesa(p, room):
    """the far range: a silhouette stepped on the cell grid (4 x 6), so no
    cell mixes rock and sky and a sprite in front of it never clashes"""
    pts = room['mesa']
    h = np.interp(np.arange(PW), [q[0] for q in pts], [q[1] for q in pts])
    h = (np.round(h[::CW] / CH) * CH).astype(int)
    h = np.repeat(h, CW)
    m = p.yy >= h[None, :]
    p.put(m, BLACK, 0)
    ridge = m & ~np.roll(m, 1, 0)
    p.m[ridge & (p.xx % 2 == 0)] = 15
    # strata: sparse dotted lines in the rock face
    for k in range(3):
        line = m & (p.yy == (h[None, :] + 4 + 6 * k)) & ((p.xx + 3 * k) % 4 == 1)
        p.put(line, RED, 1 if k == 0 else None)


def gum_tree(p, bx, by, hgt):
    """a ghost gum: pale trunk, bare forks, bunches of leaves"""
    trunk = np.zeros((PH, PW), bool)
    leaves = np.zeros((PH, PW), bool)

    def limb(x0, y0, x1, y1, w0, w1, depth):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            x = x0 + (x1 - x0) * t + math.sin(t * 5 + x0) * 0.8
            y = y0 + (y1 - y0) * t
            w = w0 + (w1 - w0) * t
            trunk[max(0, int(y)):int(y) + 1, max(0, int(round(x - w / 2))):int(round(x + w / 2)) + 1] = True
        if depth > 0:
            for s in (-1, 1):
                L = (y0 - y1) * (0.55 + 0.2 * p.rng.rand())
                ang = s * (0.5 + 0.5 * p.rng.rand())
                limb(x1, y1, x1 + math.sin(ang) * L * 1.2, y1 - math.cos(ang) * L * 0.8, w1, max(1, w1 * 0.55), depth - 1)
        else:
            for k in range(3):
                cx = x1 + p.rng.randint(-6, 7)
                cy = y1 + p.rng.randint(-5, 3)
                d = ((p.xx - cx) / 7.0) ** 2 + ((p.yy - cy) / 4.0) ** 2
                leaves[(d < 1) & (((p.xx * 3 + p.yy * 5) % 7 < 4) | (d < 0.3))] = True

    limb(bx, by, bx + 3, by - hgt * 0.45, 5, 3.4, 2)
    p.put(leaves, GREEN, None)
    p.m[leaves & ((p.xx + p.yy) % 2 == 0)] = 15
    p.m[leaves & ((p.xx + p.yy) % 2 == 1)] = 0
    p.put(trunk, WHITE, 0)
    p.m[p.outline(trunk)] = 15
    knots = trunk & ((p.xx * 7 + p.yy * 3) % 23 == 0)
    p.put(knots, GREY, None)


def solid_at(mp, tx, ty):
    if ty < 0:
        return False
    if ty >= MH:
        return True
    if tx < 0 or tx >= MW:
        return mp[ty][max(0, min(MW - 1, tx))] == '#'
    return mp[ty][tx] in '#M='


def dirt(p, mp, tx, ty):
    x0, y0 = tx * TW, ty * TH
    r = p.rect(x0, y0, x0 + TW, y0 + TH)
    top = not solid_at(mp, tx, ty - 1) and mp[ty - 1][tx] not in '~' if ty > 0 else False
    deep = solid_at(mp, tx, ty - 1) and mp[ty - 1][tx] == '#'
    p.put(r, RED, 0)
    # pebbles and grit
    n = 10 if not deep else 6
    for i in range(n):
        x = x0 + p.rng.randint(0, TW)
        y = y0 + p.rng.randint(3 if top else 0, TH)
        col = BROWN if p.rng.rand() < 0.7 else BRED
        p.c[y, x] = col
        if p.rng.rand() < 0.5:
            p.c[y, min(PW - 1, x + 1)] = col
        if p.rng.rand() < 0.45:
            p.m[y, x] = 15
    if deep:
        # darker with depth: black hatching
        hatch = r & ((p.xx + p.yy * 2) % 4 == 0) & (p.yy >= y0 + 6)
        p.put(hatch, BLACK, None)
        cr = r & ((p.xx * 5 + p.yy * 3) % 31 == 0)
        p.m[cr] = 15
    if top:
        # the crust: a bright lip that wanders a pixel
        for x in range(x0, x0 + TW):
            d = int(p.rng.rand() < 0.3)
            p.c[y0 + d, x] = YELLOW
            p.m[y0 + d, x] = 15
            p.c[y0 + d + 1, x] = BROWN
            if d:
                p.c[y0, x] = BROWN
        # spinifex: tufts of blades standing in the tile above; the tall
        # ones sway
        for i in range(p.rng.randint(1, 4)):
            gx = x0 + p.rng.randint(1, TW - 1)
            hgt = p.rng.randint(3, 8)
            lean = p.rng.randint(-1, 2)
            sway = 1 if (hgt >= 6 and (p.ph + gx) % 4 < 2) else 0
            for k in range(hgt):
                x = gx + (lean * k) // 3 + (sway if k >= hgt - 3 else 0)
                y = y0 - 1 - k
                if 0 <= x < PW and y >= 0:
                    p.c[y, x] = BGREEN if k > 1 else GREEN
                    p.m[y, x] = 15
    # cliff faces where the dirt ends sideways
    for sx, nb in ((x0, tx - 1), (x0 + TW - 1, tx + 1)):
        if 0 <= nb < MW and not solid_at(mp, nb, ty) :
            col = p.rect(sx, y0, sx + 1, y0 + TH)
            p.put(col & (p.yy % 3 != 0), BROWN, 1)


def ledge(p, mp, tx, ty):
    """sandstone shelf: a slab in the top two thirds of the tile"""
    x0, y0 = tx * TW, ty * TH
    left = tx > 0 and mp[ty][tx - 1] == '='
    right = tx < MW - 1 and mp[ty][tx + 1] == '='
    xa = x0 + (0 if left else 1)
    xb = x0 + TW - (0 if right else 1)
    slab = p.rect(xa, y0, xb, y0 + 12)
    p.put(slab, BROWN, 0)
    p.put(p.rect(xa, y0, xb, y0 + 1), YELLOW, 1)
    p.put(p.rect(xa, y0 + 11, xb, y0 + 12), BLACK, 1)
    p.put(p.rect(xa, y0 + 9, xb, y0 + 11) & ((p.xx + p.yy) % 2 == 0), BLACK, None)
    if not left:
        p.put(p.rect(xa, y0, xa + 1, y0 + 12), YELLOW, 1)
    if not right:
        p.put(p.rect(xb - 1, y0, xb, y0 + 12), BLACK, 1)
    # strata lines and a crack
    yy = y0 + 4 + p.rng.randint(0, 3)
    p.put(p.rect(xa + 1, yy, xb - 1, yy + 1) & ((p.xx + p.rng.randint(0, 5)) % 7 != 0), RED, None)
    p.m[p.rect(xa + 1, yy, xb - 1, yy + 1) & (p.xx % 3 == 0)] = 15
    cx = x0 + p.rng.randint(3, 12)
    for k in range(p.rng.randint(2, 5)):
        p.c[y0 + 1 + k, cx + (k // 2) % 2] = BLACK
    # roots / drips hanging under the shelf
    for i in range(p.rng.randint(0, 3)):
        hx = x0 + p.rng.randint(1, TW - 1)
        for k in range(p.rng.randint(2, 6)):
            p.c[y0 + 12 + k, hx] = YELLOW if k % 2 == 0 else BROWN
            if k % 2 == 0:
                p.m[y0 + 12 + k, hx] = 15


def mound(p, mp, tx, ty):
    """termite mound: stacks into towers; the top tile is a rounded spire"""
    x0, y0 = tx * TW, ty * TH
    top = ty == 0 or mp[ty - 1][tx] != 'M'
    prof = np.zeros(TH, int)
    for y in range(TH):
        if top:
            t = y / (TH - 1)
            prof[y] = int(round(2 + 5.2 * math.sqrt(t) + 0.8 * math.sin(y * 1.3 + tx)))
        else:
            prof[y] = int(round(7 + 0.9 * math.sin(y * 0.9 + tx * 2 + ty)))
    prof = np.clip(prof, 1, 8)
    body = np.zeros((PH, PW), bool)
    for y in range(TH):
        body[y0 + y, x0 + 8 - prof[y]:x0 + 8 + prof[y]] = True
    p.put(body, BROWN, 0)
    # flutes: vertical grooves, lit on the sun side
    for gx in range(x0 + 2, x0 + TW - 1, 3):
        g = body & (p.xx == gx + ((p.yy // 5) % 2))
        p.put(g, RED, None)
    lit = body & ~np.roll(body, -1, 1)          # right edge
    p.put(lit, YELLOW, 1)
    lit2 = np.roll(lit, -1, 1) & body & (p.yy % 2 == 0)
    p.put(lit2, YELLOW, None)
    dark = body & ~np.roll(body, 1, 1)
    p.put(dark, BLACK, 1)
    if top:
        cap = body & ~np.roll(body, 1, 0)
        p.put(cap, YELLOW, 1)
    holes = body & ((p.xx * 11 + p.yy * 7) % 37 == 0)
    p.put(holes, BLACK, None)
    p.m[body & ((p.xx * 5 + p.yy * 9) % 29 == 0)] = 15


def branch(p, mp, tx, ty):
    """a gum branch you can jump up through"""
    x0, y0 = tx * TW, ty * TH
    left = tx > 0 and mp[ty][tx - 1] == '-'
    right = tx < MW - 1 and mp[ty][tx + 1] == '-'
    for x in range(x0, x0 + TW):
        t = (x - x0) / TW
        wob = int(round(math.sin((x + tx) * 0.45) * 0.8))
        th = 4
        if not left and x - x0 < 4:
            th = 2 + (x - x0) // 2
        if not right and x0 + TW - 1 - x < 4:
            th = 2 + (x0 + TW - 1 - x) // 2
        ya = y0 + wob * 0
        p.c[ya, x] = WHITE
        p.m[ya, x] = 15
        for k in range(1, th):
            p.c[ya + k, x] = GREY if (x + k) % 5 else WHITE
            p.m[ya + k, x] = 0
        p.c[ya + th, x] = DGREY
        p.m[ya + th, x] = 15 if x % 2 == 0 else 0
    for i in range(p.rng.randint(1, 3)):
        cx = x0 + p.rng.randint(2, TW - 2)
        cy = y0 + 8 + p.rng.randint(0, 4)
        d = ((p.xx - cx) / 5.0) ** 2 + ((p.yy - cy) / 3.2) ** 2
        lv = (d < 1) & ((p.xx * 3 + p.yy * 5) % 7 < 4)
        p.put(lv, GREEN, None)
        p.m[lv & ((p.xx + p.yy) % 2 == 0)] = 15


def water(p, mp, tx, ty):
    """the ripples drift a pixel a phase"""
    x0, y0 = tx * TW, ty * TH
    r = p.rect(x0, y0 + 4, x0 + TW, y0 + TH)
    p.put(r, BLUE, 0)
    surf = p.rect(x0, y0 + 4, x0 + TW, y0 + 5)
    p.put(surf & ((p.xx + p.ph) % 8 != 0), BCYAN, 1)
    glint = p.rect(x0, y0 + 5, x0 + TW, y0 + 6) & ((p.xx + p.ph) % 8 == 3)
    p.put(glint, WHITE, 1)
    for k, yy in enumerate((8, 11, 15)):
        d = p.ph if k != 1 else -p.ph
        rp = p.rect(x0, y0 + yy, x0 + TW, y0 + yy + 1) & (((p.xx + k * 3 + d) % 8) < 3)
        p.put(rp, BBLUE if k else BCYAN, 1 if k == 0 else None)


def lily(p, mp, tx, ty):
    water(p, mp, tx, ty)
    x0, y0 = tx * TW, ty * TH
    d = ((p.xx - (x0 + 7.5)) / 7.5) ** 2 + ((p.yy - (y0 + 3.5)) / 2.6) ** 2
    pad = d < 1
    notch = (p.xx > x0 + 9) & (abs(p.yy - (y0 + 3)) < (p.xx - x0 - 9) * 0.5)
    pad &= ~notch
    p.put(pad, GREEN, 0)
    p.put(pad & ~np.roll(pad, 1, 0), BGREEN, 1)
    p.put(pad & ~np.roll(pad, -1, 0), BLACK, 1)
    # a flower
    fx, fy = x0 + 4, y0 - 1
    for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, -1), (0, 1)):
        p.c[fy + dy, fx + dx] = WHITE
        p.m[fy + dy, fx + dx] = 15
    p.c[fy, fx] = YELLOW


def reeds(p, x, y, n):
    for i in range(n):
        gx = x + i * 3 + p.rng.randint(0, 2)
        hgt = p.rng.randint(10, 22)
        sway = 1 if (p.ph + i) % 4 < 2 else 0
        for k in range(hgt):
            xx = gx + (k * k) // 90 + (sway if k > hgt * 2 // 3 else 0)
            p.c[y - k, xx] = BGREEN if k % 4 else GREEN
            p.m[y - k, xx] = 15 if k % 2 == 0 else 0
        top = gx + hgt * hgt // 90 + sway
        p.put(p.rect(top - 1, y - hgt - 4, top + 1, y - hgt), BROWN, 1)


def paint_room(idx, ph=0):
    room = ROOMS[idx]
    mp = room['map']
    p = Paint(1000 + idx * 77, ph)
    sky(p, room)
    mesa(p, room)
    for bx, by, hgt in room.get('trees', []):
        gum_tree(p, bx, by, hgt)
    tm = np.zeros((MH, MW), np.uint8)
    objs = []
    for ty in range(MH):
        for tx in range(MW):
            ch = mp[ty][tx]
            if ch == '#':
                tm[ty, tx] = T_SOLID
            elif ch == '=':
                tm[ty, tx] = T_SOLID
            elif ch == 'M':
                tm[ty, tx] = T_SOLID
            elif ch == '-':
                tm[ty, tx] = T_ONEWAY
            elif ch == '~':
                tm[ty, tx] = T_WATER
            elif ch == 'o':
                tm[ty, tx] = T_ONEWAY
            elif ch == 'B':
                objs.append((O_BUG, tx * TW + 8, ty * TH + 10))
            elif ch == 'T':
                objs.append((O_TOAD, tx * TW + 8, ty * TH + 18))
            elif ch == 'S':
                objs.append((O_START, tx * TW + 8, ty * TH + 18))
    # water first, then land over it
    for ty in range(MH):
        for tx in range(MW):
            ch = mp[ty][tx]
            if ch == '~':
                water(p, mp, tx, ty)
            elif ch == 'o':
                lily(p, mp, tx, ty)
    if idx == 1:
        reeds(p, 36, 150, 4)
        reeds(p, 170, 150, 3)
    for ty in range(MH):
        for tx in range(MW):
            ch = mp[ty][tx]
            if ch == 'M':
                mound(p, mp, tx, ty)
            elif ch == '=':
                ledge(p, mp, tx, ty)
            elif ch == '-':
                branch(p, mp, tx, ty)
    for ty in range(MH - 1, -1, -1):
        for tx in range(MW):
            if mp[ty][tx] == '#':
                dirt(p, mp, tx, ty)
    return p, tm, objs


NPH = 4
DYN_BASE = 768           # glyphs 768..1023 (PCG banks 6, 7) are rewritten as the room runs
CHUNK = 10               # scenery glyphs rewritten in one vertical blanking
A_LOOP, A_BUG = 1, 2
import critters as _cr


def busy(pat):
    return sum(bin(v).count('1') for v in pat) > 12


def compile_room(idx, mono):
    """-> the room record's parts. Cells whose pattern is the same in every
    phase share static glyphs; the rest get glyphs of their own that the
    game rewrites (scenery in chunks, and each bug: a bug is not a sprite
    but a few cells of living background)."""
    ps = [paint_room(idx, ph) for ph in range(NPH)]
    p, tm, objs = ps[0]
    pats, ink, pap = cells_from_images([(q[0].m if mono else q[0].c) for q in ps])
    static = {bytes(6): 0}
    dyn = {}                 # tuple of patterns -> dyn index
    scr = np.full(2048, 0x80, np.uint8)
    attr = np.zeros(2048, np.uint8)
    col = np.full(2048, 0x0F, np.uint8)

    def setcell(i, g, pat0, c):
        scr[i] = 0x80 | (g & 0x7F)
        attr[i] = (g >> 7) | (0x10 if busy(pat0) else 0)
        col[i] = 0x0F if mono else c

    for r in range(PF_ROWS):
        for c in range(COLS):
            tup = tuple(bytes(pats[k][r, c]) for k in range(NPH))
            i = (r + PF_ROW0) * COLS + c
            cc = (int(pap[r, c]) << 4) | int(ink[r, c])
            if all(t == tup[0] for t in tup):
                if tup[0] not in static:
                    static[tup[0]] = len(static)
                setcell(i, static[tup[0]], tup[0], cc)
            else:
                if tup not in dyn:
                    dyn[tup] = len(dyn)
                setcell(i, DYN_BASE + dyn[tup], tup[0], cc)
    anims = []
    tups = sorted(dyn, key=lambda t: dyn[t])
    for k in range(0, len(tups), CHUNK):
        part = tups[k:k + CHUNK]
        anims.append(dict(type=A_LOOP, ids=[DYN_BASE + dyn[t] for t in part], frames=[[t[f] for t in part] for f in range(NPH)],
                          period=12, tail=b''))
    ndyn = len(dyn)
    # the bugs
    F = _cr.frames()
    seq = [('BUG0', 0), ('BUG1', -1), ('BUG0', -2), ('BUG1', -1)]
    nobj = 0
    out_objs = []
    for oi, (t, x, y) in enumerate(objs):
        if t != O_BUG:
            out_objs.append((t, x, y))
            continue
        cells = {}
        for f, (name, dy) in enumerate(seq):
            bi, bc, ox, oy = F[name]
            solid = dilate(bi | bc, diag=False)
            h, w = bi.shape
            for yy in range(h):
                for xx in range(w):
                    if not solid[yy, xx]:
                        continue
                    px, py = x - ox + xx, y - oy + yy + dy
                    if not (0 <= px < PW and 0 <= py < PH):
                        continue
                    key = (py // CH, px // CW)
                    cells.setdefault(key, [[None] * (CH * CW) for _ in range(NPH)])
                    cells[key][f][(py % CH) * CW + px % CW] = bool(bi[yy, xx])
        ids, frames, tail_cells = [], [[] for _ in range(NPH)], []
        for (r, c), fr in sorted(cells.items()):
            i = (r + PF_ROW0) * COLS + c
            g0 = (int(attr[i] & 15) << 7) | int(scr[i] & 0x7F)
            base = None
            for key, g in static.items():
                if g == g0:
                    base = key
            if base is None:                    # an animated cell: freeze it at phase 0
                base = tups[g0 - DYN_BASE][0]
            for f in range(NPH):
                bits = [[(base[yy] >> (7 - 2 * xx)) & 1 for xx in range(CW)] for yy in range(CH)]
                for k, v in enumerate(fr[f]):
                    if v is not None:
                        bits[k // CW][k % CW] = 1 if v else 0
                frames[f].append(bytes(byte_rows(np.array(bits, bool))[:, 0]))
            tail_cells.append((i, int(scr[i]), int(attr[i]), int(col[i])))
            g = DYN_BASE + ndyn
            ndyn += 1
            ids.append(g)
            keep = busy(base)
            cc = int(col[i]) if (keep or mono) else ((int(col[i]) & 0xF0) | WHITE)
            scr[i] = 0x80 | (g & 0x7F)
            attr[i] = (g >> 7) | (0x10 if keep else 0)
            col[i] = cc
        tail = bytes([oi, x & 255, y & 255, len(tail_cells)])
        for i, s, a, cc in tail_cells:
            tail += bytes([i & 255, i >> 8, s, a, cc])
        anims.append(dict(type=A_BUG, ids=ids, frames=frames, period=7, tail=tail))
        out_objs.append((0x80 | t, x, y))       # placeholder keeps object indexes stable
    n = len(static)
    assert n <= DYN_BASE, 'room %d: %d static glyphs' % (idx, n)
    assert ndyn <= 256, 'room %d: %d living glyphs' % (idx, ndyn)
    pb = bytearray(n * 6)
    for k, g in static.items():
        pb[g * 6:g * 6 + 6] = k
    ab = bytearray()
    for a in anims:
        ng, nf = len(a['ids']), len(a['frames'])
        body = bytearray()
        for g in a['ids']:
            body += bytes([g & 255, g >> 8])
        for f in range(nf):
            for q in a['frames'][f]:
                body += q
        body += a['tail']
        ln = 6 + len(body)
        ab += bytes([a['type'], ng, nf, a['period'], ln & 255, ln >> 8]) + body
    ab.append(0)
    rgb = image_from_cells(pats[0], ink, pap, mono)
    return dict(scr=scr, attr=attr, col=col, tmap=tm.reshape(-1), objs=out_objs, pat=bytes(pb), n=n, ndyn=ndyn,
                anim=bytes(ab), rgb=rgb, room=ROOMS[idx])


R_SCR, R_ATTR, R_COL, R_TMAP, R_OBJ, R_NPAT, R_NAME, R_PAT, R_ANIM = 0, 0x800, 0x1000, 0x1800, 0x18A0, 0x1940, 0x1950, 0x1A00, 0x2C00
R_SIZE = 0x4000


def room_bytes(rc):
    d = bytearray(R_SIZE)
    d[R_SCR:R_SCR + 2048] = rc['scr'].tobytes()
    d[R_ATTR:R_ATTR + 2048] = rc['attr'].tobytes()
    d[R_COL:R_COL + 2048] = rc['col'].tobytes()
    d[R_TMAP:R_TMAP + 160] = rc['tmap'].tobytes()
    o = R_OBJ
    for t, x, y in rc['objs']:
        d[o:o + 4] = bytes([t, x & 255, y & 255, 0])
        o += 4
    d[o] = 0
    d[R_NPAT] = rc['n'] & 255
    d[R_NPAT + 1] = rc['n'] >> 8
    d[R_NPAT + 2] = rc['room']['left'] & 255
    d[R_NPAT + 3] = rc['room']['right'] & 255
    nm = rc['room']['name'].encode('ascii')[:20]
    d[R_NAME:R_NAME + len(nm)] = nm
    assert R_PAT + len(rc['pat']) <= R_ANIM, len(rc['pat'])
    d[R_PAT:R_PAT + len(rc['pat'])] = rc['pat']
    assert R_ANIM + len(rc['anim']) <= R_SIZE, len(rc['anim'])
    d[R_ANIM:R_ANIM + len(rc['anim'])] = rc['anim']
    return bytes(d)


if __name__ == '__main__':
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    for i in range(len(ROOMS)):
        for mono in (False, True):
            rc = compile_room(i, mono)
            save_png(rc['rgb'], '%s/room%d%s.png' % (out, i, 'm' if mono else ''), 2, 1.8)
            print(i, mono, rc['n'], 'static', rc['ndyn'], 'living', len(rc['anim']), 'bytes of animation')
