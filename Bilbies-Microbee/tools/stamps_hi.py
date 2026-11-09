"""BILBIES! for the Microbee: the Australiana pictures, redrawn.

Each picture of the original (tools/orig/stamps.py, VZ pixels) is drawn
again here at the Microbee's resolution: twice the size each way, the same
footprint, standing on the same ground row.  Microbee pixels are about 1.8
times taller than wide, so round things are squashed vertically here.

They are drawn for 8 x 16 cells of two colours: one main colour with the
sky showing through for detail, a second colour only in big areas.
get(name, theme) -> int16 array (rows, cols): a palette index or -1 (clear).
"""
import os
import sys
import math
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'orig'))
_cwd = os.getcwd()
os.chdir(os.path.join(HERE, 'orig'))
import stamps as _vz          # noqa: E402
os.chdir(_cwd)

BLK, RED, GRN, BRN, BLU, MAG, CYN, LGR, DGR, LRED, LGRN, YEL, LBLU, LMAG, LCYN, WHT = range(16)
ASP = 1.8


class Cv:
    """a canvas of palette indices (-1 = clear) with PIL's drawing"""
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.im = Image.new('L', (w, h), 0)
        self.d = ImageDraw.Draw(self.im)

    def rect(self, x0, y0, x1, y1, c):              # inclusive
        self.d.rectangle([x0, y0, x1, y1], fill=c + 1)

    def line(self, pts, c, w=1):
        self.d.line([tuple(p) for p in pts], fill=c + 1, width=w)

    def poly(self, pts, c):
        self.d.polygon([tuple(p) for p in pts], fill=c + 1)

    def ell(self, cx, cy, rx, ry, c):
        self.d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=c + 1)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((int(x), int(y)), c + 1)

    def clear(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.im.putpixel((int(x), int(y)), 0)

    def art(self, rows, legend, x0=0, y0=0):
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch in legend:
                    v = legend[ch]
                    if v is None:
                        self.clear(x0 + i, y0 + j)
                    else:
                        self.px(x0 + i, y0 + j, v)

    def arr(self):
        return np.array(self.im, np.int16) - 1


def size(name):
    rows = _vz.S[name]
    return len(rows[0]) * 2, len(rows) * 2


def canvas(name):
    w, h = size(name)
    return Cv(w, h)


def from_art(name, rows, legend):
    c = canvas(name)
    h = len(rows)
    c.art(rows, legend, 0, c.h - h)        # stand on the bottom row
    return c


DRAW = {}


def pic(fn):
    DRAW[fn.__name__] = fn
    return fn


# ===========================================================================
# out bush
# ===========================================================================
@pic
def windmill(th):
    """a windpump: lattice tower, the many-bladed wheel, the tail vane"""
    c = canvas('windmill')          # 32 x 34
    m = LGR if th != 'night' else DGR
    cx, cy = 10, 6
    R = 9.5
    for k in range(12):                     # the blades: wedges with gaps
        a0 = k * math.pi / 6
        a1 = a0 + math.pi / 6 * 0.55
        pts = [(cx + 3 * math.cos(a0), cy + 3 * math.sin(a0) / ASP),
               (cx + R * math.cos(a0), cy + R * math.sin(a0) / ASP),
               (cx + R * math.cos(a1), cy + R * math.sin(a1) / ASP)]
        c.poly(pts, m)
    c.ell(cx, cy, 1.5, 1, m)
    c.line([(cx, cy), (27, cy - 1)], m)     # the tail vane on its boom
    c.poly([(21, cy - 5), (30, cy - 5), (30, cy + 1), (21, cy - 1)], m)
    c.line([(22, cy - 3), (29, cy - 3)], RED)
    top, bot = 12, 33
    lx0, rx0 = cx - 2, cx + 2
    lx1, rx1 = 2, 18
    c.line([(lx0, top), (lx1, bot)], m)
    c.line([(rx0, top), (rx1, bot)], m)
    ys = [top, 16, 21, 27, bot]
    for i in range(len(ys) - 1):
        ya, yb = ys[i], ys[i + 1]
        f = lambda y, a, b: a + (b - a) * (y - top) / (bot - top)
        la, ra, lb, rb = f(ya, lx0, lx1), f(ya, rx0, rx1), f(yb, lx0, lx1), f(yb, rx0, rx1)
        c.line([(la, ya), (ra, ya)], m)
        c.line([(la, ya), (rb, yb)], m)
        c.line([(ra, ya), (lb, yb)], m)
    c.rect(cx - 1, cy + 1, cx + 1, top, m)
    c.rect(cx - 2, bot - 2, cx + 2, bot, m)
    return c

@pic
def tank(th):
    """a corrugated iron water tank up on its timber stand"""
    c = canvas('tank')              # 24 x 20
    c.poly([(5, 2), (18, 2), (21, 4), (2, 4)], LGR)          # the conical lid
    c.rect(11, 0, 12, 2, LGR)
    c.rect(2, 4, 21, 11, LGR)
    for y in (5, 7, 9, 11):
        c.line([(2, y), (21, y)], DGR)
    c.line([(3, 12), (20, 12)], DGR)
    for x in (3, 20):
        c.line([(x, 13), (x, 19)], BRN, 2 if False else 1)
    c.line([(4, 13), (4, 19)], BRN)
    c.line([(19, 13), (19, 19)], BRN)
    c.line([(5, 13), (18, 18)], BRN)
    c.line([(18, 13), (5, 18)], BRN)
    c.line([(3, 13), (20, 13)], BRN)
    return c


@pic
def shed(th):
    """a corrugated iron shed with a lean-to"""
    c = canvas('shed')              # 40 x 16
    c.poly([(12, 0), (34, 0), (39, 5), (6, 5)], LGR)       # the roof
    c.poly([(2, 5), (8, 4), (8, 7), (2, 8)], LGR)           # the lean-to roof
    for x in range(9, 38, 2):
        c.line([(x, 1), (x - 1, 5)], DGR)
    c.line([(6, 5), (39, 5)], DGR)
    c.rect(8, 6, 37, 15, LGR)
    c.rect(3, 8, 7, 15, LGR)
    for x in range(9, 37, 2):
        c.line([(x, 7), (x, 15)], DGR)
    c.rect(18, 9, 25, 15, BLK)                              # the open doors
    c.rect(4, 10, 6, 15, DGR)
    c.line([(3, 8), (7, 8)], DGR)
    return c


@pic
def grasstree(th):
    """a grass tree: black trunk, a fountain of fine leaves, the flower spike"""
    c = canvas('grasstree')         # 16 x 22
    c.rect(7, 0, 8, 7, BRN)                         # the spike
    c.rect(6, 2, 9, 7, BRN)
    c.px(7, 0, YEL)
    c.rect(6, 15, 9, 21, BLK if th not in ('night', 'cave') else DGR)       # the trunk
    c.rect(5, 20, 10, 21, BLK if th not in ('night', 'cave') else DGR)
    g = GRN
    for k in range(13):
        a = math.pi * (0.05 + 0.9 * k / 12.0)
        ln = 8 - abs(k - 6) * 0.3
        x1 = 7.5 - math.cos(a) * ln
        y1 = 12 - math.sin(a) * ln / ASP * 1.2
        c.line([(7.5, 13), (x1, y1)], g)
        if k % 2 == 0:
            c.line([(x1, y1), (x1 - math.cos(a) * 1.5, y1 + 2.5)], g)
    for k in range(7):                              # the skirt of dry leaves
        x = 4 + k * 1.3
        c.line([(7.5, 13), (x, 16)], g)
    return c


@pic
def roo(th):
    """a kangaroo, up on its tail, facing right"""
    rows = [
        "..........b.b...",
        "..........bbb...",
        "..........bbbb..",
        ".........bb.bbbb",
        ".........bbbbbbb",
        ".........bbbb...",
        "........bbbb....",
        ".......bbbbbb...",
        "......bbbbbb.b..",
        ".....bbbbbbb.b..",
        ".....bbbbbbb....",
        "....bbbbbbbb....",
        "....bbbbbbbb....",
        "...bbb.bbbbb....",
        "..bb...bbbb.....",
        ".bb.....bbb.....",
        "bb......bbbbbb..",
        "b......bbbbbbbb.",
    ]
    col = BRN if th not in ('night',) else RED
    return from_art('roo', rows, {'b': col})


@pic
def emu(th):
    """an emu striding along"""
    rows = [
        ".........bb.....",
        "........bbbbb...",
        ".........bb.....",
        ".........bb.....",
        "........bb......",
        "........bb......",
        "........bb......",
        ".......bbb......",
        "....bbbbbb......",
        "..bbbbbbbbbb....",
        ".bbbbbbbbbbbb...",
        "bbbbbbbbbbbbb...",
        "bbbbbbbbbbbb....",
        "bbbbbbbbbbb.....",
        "b.b.bbbbbb......",
        "......b..b......",
        ".....b....b.....",
        ".....b....b.....",
        "....b......b....",
        "....b......b....",
        "...b........b...",
        "..bb........bb..",
    ]
    col = DGR if th in ('sky',) else BRN
    if th == 'dusk':
        col = BLK
    return from_art('emu', rows, {'b': col})

@pic
def galahs(th):
    """three galahs wheeling over: pink fronts, grey wings"""
    rows = [
        "ww....ww................",
        ".www.www........ww....ww",
        "...ppp...........www.ww.",
        "....p..............ppp..",
        "..........ww...ww...p...",
        "...........ww.ww........",
        ".............pp.........",
        ".............p..........",
        "........................",
        "........................",
    ]
    return from_art('galahs', rows, {'w': LGR, 'p': LMAG})

@pic
def wattle(th):
    """a golden wattle in flower"""
    c = canvas('wattle')            # 24 x 12
    c.ell(11, 5, 10, 4.6, GRN)
    c.ell(6, 7, 5, 3.4, GRN)
    c.ell(16, 7, 6, 3.4, GRN)
    c.rect(10, 9, 11, 11, BRN)
    r = np.random.default_rng(5)
    for k in range(26):
        x, y = r.integers(2, 21), r.integers(1, 10)
        if c.im.getpixel((int(x), int(y))) == GRN + 1:
            c.px(x, y, YEL)
            if k % 3 == 0:
                c.px(x + 1, y, YEL)
    return c


@pic
def banksia(th):
    """a banksia shrub with its upright cones"""
    c = canvas('banksia')           # 24 x 12
    c.ell(10, 6, 9, 4, GRN)
    c.ell(16, 7, 5, 3, GRN)
    for x in range(2, 20, 3):                       # serrated edge
        c.clear(x, 2)
    for x, y in ((5, 2), (10, 1), (15, 3), (8, 5)):
        c.rect(x, y, x + 1, y + 3, BRN)
        c.px(x, y - 1, BRN)
    c.rect(9, 10, 10, 11, BRN)
    return c


@pic
def boab(th):
    """a boab: a fat bottle of a trunk, a tangle of branches"""
    c = canvas('boab')              # 32 x 20
    b = BRN
    c.ell(10, 15, 6.5, 5.5, b)
    c.poly([(6, 6), (14, 6), (16, 13), (4, 13)], b)
    c.rect(3, 18, 17, 19, b)
    for x0, x1, y1 in ((7, 2, 2), (9, 7, 0), (11, 14, 1), (13, 19, 3), (8, 4, 4), (12, 17, 5)):
        c.line([(x0, 7), (x1, y1)], b)
    for x, y in ((2, 2), (7, 0), (14, 1), (19, 3), (4, 4), (17, 5)):
        c.ell(x, y, 2.5, 1.2, GRN)
    c.line([(9, 11), (9, 17)], RED)
    return c


@pic
def sign(th):
    """BILBY CROSSING: a yellow diamond with a bilby on it"""
    c = canvas('sign')              # 16 x 18
    c.poly([(8, 0), (15, 5), (8, 10), (1, 5)], YEL)
    rows = [
        "......k..",
        "......kk.",
        "...kkkkkk",
        "..kkkkkk.",
        ".k.k..k..",
    ]
    c.art(rows, {'k': BLK}, 3, 3)
    c.rect(7, 11, 8, 17, LGR)
    return c


@pic
def mailbox(th):
    """a forty-four gallon drum letterbox on a post"""
    c = canvas('mailbox')           # 16 x 14
    c.ell(6, 3.5, 5.5, 3.5, RED)
    c.rect(1, 1, 6, 6, RED)
    c.ell(1.5, 3.5, 1.5, 3, LRED)
    c.line([(3, 3), (5, 3)], BLK)
    c.line([(8, 0), (8, 7)], DGR)
    c.rect(5, 7, 6, 13, BRN)
    return c


@pic
def fence(th):
    """posts and wire"""
    c = canvas('fence')             # 32 x 10
    for x in (0, 16):
        c.rect(x, 0, x + 1, 9, BRN)
    for y in (2, 6):
        c.line([(0, y), (31, y + (1 if y == 6 else 0))], LGR)
    return c


@pic
def hoist(th):
    """a rotary clothes line with the washing out"""
    c = canvas('hoist')             # 24 x 16
    c.line([(1, 2), (22, 2)], LGR)
    c.line([(5, 0), (18, 4)], LGR)
    c.line([(11, 1), (11, 15)], LGR)
    c.line([(9, 15), (13, 15)], LGR)
    c.rect(2, 3, 6, 8, WHT)                         # a sheet
    c.rect(15, 3, 19, 6, RED)                       # a shirt
    c.rect(16, 6, 18, 7, RED)
    c.rect(8, 3, 9, 6, LBLU if th != 'sky' else BLU)  # socks
    return c


# ===========================================================================
# at night
# ===========================================================================
@pic
def moon(th):
    c = canvas('moon')              # 16 x 8
    c.ell(6, 4, 6, 3.6, YEL)
    c.ell(9, 3.2, 5.2, 3.4, -1)
    return c


@pic
def cross(th):
    """the Southern Cross and the two pointers"""
    c = canvas('cross')             # 32 x 20
    stars = [(13, 1, 2), (5, 5, 2), (19, 7, 1), (15, 9, 1), (13, 13, 2), (30, 17, 2), (24, 19, 1)]
    for x, y, s in stars:
        c.px(x, y, WHT)
        if s == 2:
            c.px(x - 1, y, LGR)
            c.px(x + 1, y, LGR)
            c.px(x, y - 1, LGR)
            c.px(x, y + 1, LGR)
    return c


@pic
def mound(th):
    """a termite mound: knobbly red spires"""
    c = canvas('mound')             # 16 x 12
    b = BRN if th != 'dusk' else RED
    c.poly([(4, 0), (6, 0), (8, 5), (11, 3), (12, 4), (13, 11), (0, 11), (2, 5)], b)
    c.px(5, 0, b)
    c.line([(5, 3), (5, 9)], RED if b != RED else BRN)
    c.line([(10, 6), (10, 10)], RED if b != RED else BRN)
    return c


@pic
def chimney(th):
    """the stone chimney of a burnt-out homestead"""
    c = canvas('chimney')           # 16 x 20
    s = LGR
    c.rect(5, 0, 10, 8, s)
    c.rect(4, 0, 11, 1, s)
    c.poly([(5, 8), (10, 8), (13, 12), (2, 12)], s)
    c.rect(1, 12, 14, 19, s)
    for y in (3, 6, 10, 14, 17):
        c.line([(0, y), (15, y)], DGR)
    for y0, xs in ((0, (8,)), (3, (7,)), (6, (9,)), (10, (5, 11)), (14, (3, 8, 12)), (17, (6, 10))):
        for x in xs:
            c.line([(x, y0), (x, y0 + 2)], DGR)
    c.rect(5, 14, 10, 19, BLK)                      # the fireplace
    c.ell(7.5, 14, 2.5, 1.5, BLK)
    c.clear(13, 12)
    c.clear(14, 12)
    c.clear(14, 13)
    return c


@pic
def campfire(th):
    """a campfire with the billy on"""
    c = canvas('campfire')          # 16 x 10
    c.line([(1, 0), (4, 9)], DGR)                   # the tripod
    c.line([(8, 0), (6, 9)], DGR)
    c.line([(1, 0), (8, 0)], DGR)
    c.rect(3, 2, 6, 4, LGR)                         # the billy
    c.line([(4, 1), (5, 1)], LGR)
    c.poly([(2, 9), (4, 5), (5, 7), (7, 4), (8, 7), (9, 6), (11, 9)], RED)
    c.poly([(4, 9), (5, 7), (6, 8), (7, 6), (8, 9)], YEL)
    c.line([(0, 9), (13, 8)], BRN)
    c.line([(1, 8), (12, 9)], BRN)
    return c


@pic
def tent(th):
    """a swag tent, the lamp lit inside"""
    c = canvas('tent')              # 24 x 10
    c.poly([(8, 0), (18, 9), (0, 9)], BRN)
    c.poly([(8, 0), (21, 0), (23, 9), (18, 9)], BRN)
    c.line([(9, 1), (20, 1)], DGR)
    c.poly([(8, 3), (12, 9), (4, 9)], YEL)
    c.line([(8, 0), (8, 9)], DGR)
    return c


# ===========================================================================
# below
# ===========================================================================
@pic
def prop(th):
    """goldfields mine timbers: two legs and a cap, wedged"""
    c = canvas('prop')              # 24 x 24
    w = BRN
    c.rect(0, 0, 23, 3, w)
    c.line([(0, 4), (23, 4)], RED)
    c.rect(2, 4, 4, 23, w)
    c.rect(19, 4, 21, 23, w)
    c.poly([(5, 4), (9, 4), (5, 8)], w)
    c.poly([(18, 4), (14, 4), (18, 8)], w)
    for x in range(1, 23, 5):
        c.px(x, 1, RED)
    c.line([(3, 9), (3, 13)], RED)
    c.line([(20, 15), (20, 19)], RED)
    return c


@pic
def cart(th):
    """an ore cart on its rails"""
    c = canvas('cart')              # 24 x 10
    c.poly([(1, 0), (16, 0), (14, 6), (3, 6)], LGR)
    for x in (4, 9, 13):
        c.line([(x, 1), (x, 5)], DGR)
    c.ell(4, 2 - 1, 2, 1, YEL)
    c.ell(9, 0, 3, 1, YEL)
    c.ell(5, 7.5, 1.6, 1, DGR)
    c.ell(12, 7.5, 1.6, 1, DGR)
    c.line([(0, 9), (23, 9)], LGR)
    for x in range(1, 24, 4):
        c.px(x, 9, BRN)
    return c


@pic
def lantern(th):
    """a miner's lamp hanging from a hook"""
    c = canvas('lantern')           # 16 x 10
    c.line([(4, 0), (4, 1)], DGR)
    c.ell(4, 2.5, 2.5, 1, DGR)
    c.rect(2, 3, 6, 7, YEL)
    c.line([(4, 3), (4, 7)], WHT)
    c.rect(2, 8, 6, 9, DGR)
    return c


@pic
def pick(th):
    """a pick and a shovel leant on the wall"""
    c = canvas('pick')              # 16 x 12
    c.line([(0, 2), (2, 0), (5, 0), (8, 2)], LGR)
    c.line([(4, 0), (6, 11)], BRN)
    c.line([(12, 0), (10, 8)], BRN)
    c.line([(11, 0), (13, 0)], BRN)
    c.poly([(8, 8), (12, 8), (11, 11), (9, 11)], LGR)
    return c


@pic
def nugget(th):
    """a glint of gold in the rock"""
    c = canvas('nugget')            # 16 x 10
    c.poly([(3, 5), (5, 3), (8, 3), (10, 5), (8, 7), (4, 7)], YEL)
    c.px(5, 4, WHT)
    c.line([(6, 0), (6, 2)], WHT)
    c.line([(6, 8), (6, 9)], WHT)
    c.line([(0, 5), (1, 5)], WHT)
    c.line([(12, 5), (13, 5)], WHT)
    return c


@pic
def bats(th):
    """fruit bats asleep upside down"""
    rows = [
        "..k.......k.......k.....",
        ".kkk.....kkk.....kkk....",
        ".kkk.....kkk.....kkk....",
        "kkkkk...kkkkk...kkkkk...",
        ".kkk.....kkk.....kkk....",
        "..k.......k.......k.....",
        "..k.......k.......k.....",
        "........................",
    ]
    c = canvas('bats')
    c.art(rows, {'k': DGR}, 0, 0)
    for x in (2, 10, 18):
        c.px(x, 6, LRED)                            # little eyes
    return c


@pic
def heron(th):
    """a white-faced heron wading"""
    rows = [
        "...www..........",
        "...gggggg.......",
        "...gg...........",
        "...g............",
        "....g...........",
        "....gg..........",
        "...gggg.........",
        ".ggggggg........",
        "ggggggg.........",
        ".ggggg..........",
        "....g...........",
        "....g...........",
        "....g...........",
        "....g...........",
        "...g.g..........",
        "...g..g.........",
    ]
    return from_art('heron', rows, {'g': LGR, 'w': WHT})


# ===========================================================================
# the set pieces
# ===========================================================================
@pic
def uluru(th):
    """the great red rock on the horizon"""
    c = canvas('uluru')             # 160 x 24
    body = BRN
    shade = RED
    prof = []
    r = np.random.default_rng(3)
    for x in range(160):
        if x < 6 or x > 153:
            prof.append(99)
            continue
        d = min(x - 6, 153 - x)
        if d < 14:
            top = 23 - d * 1.5
        else:
            top = 2.5 + 1.8 * abs((x - 80) / 74.0) ** 2 * 4
        top = max(0.0, top + 0.6 * math.sin(x * 0.4))
        prof.append(top)
    for x in range(160):
        if prof[x] < 24:
            c.rect(x, int(round(prof[x])), x, 23, body)
    # gullies down its face, a few caves near the foot
    for x in (18, 30, 41, 52, 66, 79, 92, 104, 117, 129, 140):
        x = x + int(r.integers(-2, 3))
        y0 = int(prof[x] + 2)
        c.line([(x, y0), (x + 1, 14), (x, 21)], shade)
    for x in (36, 88, 122):
        c.ell(x, 19, 3, 1.5, shade)
    c.line([(8, 23), (151, 23)], shade)
    return c


@pic
def harbour(th):
    """the sails of the opera house on their podium, across the water"""
    c = canvas('harbour')           # 96 x 28
    s = WHT
    base = 20
    # each shell: a convex back curving up from its foot to a point, then
    # a steep cut face down again.  (foot, tip x, tip row, cut foot, facing)
    shells = [(6, 24, 6, 26, 1), (18, 38, 0, 40, 1), (34, 47, 8, 48, 1),
              (88, 70, 4, 68, -1), (72, 57, 8, 55, -1), (58, 51, 13, 50, -1)]
    for x0, ax, ay, x1, f in shells:
        pts = []
        for i in range(17):
            t = i / 16.0
            # the back: rises from its foot and arches over to the tip
            x = x0 + (ax - x0) * t
            y = base - (base - ay) * math.sin(t * math.pi * 0.36) / math.sin(math.pi * 0.36)
            pts.append((x, y))
        pts.append((x1, base))
        c.poly(pts, s)
        # the ribs show as a shadow line along the cut face
        c.line([(ax - f, ay + 1), (x1 - f, base - 1)], LGR)
    c.rect(4, base, 90, base + 2, LGR)
    c.rect(2, base + 3, 93, base + 4, BRN)
    for x in range(4, 92, 6):
        c.line([(x, base + 3), (x + 2, base + 3)], LGR)
    c.rect(0, base + 5, 95, 27, BRN)
    for x in range(1, 95, 4):
        c.px(x, base + 6, DGR)
    return c

@pic
def homestead(th):
    """a station homestead: hip roof of red iron, a verandah all round"""
    c = canvas('homestead')         # 80 x 28
    roof, rf2 = RED, DGR
    c.rect(22, 0, 25, 7, RED)                       # the chimney
    c.rect(21, 0, 26, 1, DGR)
    c.poly([(18, 3), (62, 3), (72, 12), (8, 12)], roof)       # the main roof
    for x in range(10, 72, 3):
        c.line([(x + (40 - x) * 0.25, 4), (x, 11)], rf2)
    c.line([(18, 3), (62, 3)], LRED)
    # the bullnose verandah roof, striped
    c.poly([(5, 12), (75, 12), (78, 15), (2, 15)], WHT)
    for x in range(4, 78, 4):
        c.poly([(x, 12), (x + 2, 12), (x + 2, 15), (x, 15)], roof)
    # under the verandah: weatherboards, windows, the door
    c.rect(3, 16, 77, 25, WHT)
    for x0 in (8, 22, 50, 64):
        c.rect(x0, 17, x0 + 7, 22, BLK)
        c.line([(x0 + 3, 17), (x0 + 3, 22)], LGR)
        c.line([(x0, 19), (x0 + 7, 19)], LGR)
    c.rect(36, 17, 43, 25, BRN)                     # the front door
    c.rect(38, 18, 41, 20, BLK)
    for x in range(3, 78, 11):                      # posts
        c.rect(x, 16, x + 1, 25, BLK)
    c.line([(3, 23), (77, 23)], BLK)               # the rail
    c.line([(3, 26), (77, 26)], BRN)               # the floor
    for x in range(4, 78, 8):
        c.line([(x, 27), (x, 27)], BLK)            # the stumps
    c.rect(34, 26, 45, 27, BRN)                     # the steps
    return c


@pic
def pine(th):
    """a Norfolk Island pine on the foreshore: tiers of branches"""
    c = canvas('pine')              # 24 x 28
    g = GRN
    c.rect(11, 0, 12, 27, BRN)
    for i, y in enumerate(range(1, 24, 3)):
        hw = 1.5 + i * 1.25
        c.poly([(11.5 - hw, y + 2), (11.5, y), (11.5 + hw, y + 2), (11.5 + hw - 1, y + 3), (11.5 - hw + 1, y + 3)], g)
    c.rect(10, 25, 13, 27, BRN)
    return c


@pic
def flags(th):
    """swim between the flags: red over yellow"""
    c = canvas('flags')             # 16 x 12
    c.rect(1, 0, 6, 2, RED)
    c.rect(1, 3, 6, 4, YEL)
    c.line([(7, 0), (7, 11)], LGR)
    return c


@pic
def umbrella(th):
    """a beach umbrella over a towel"""
    c = canvas('umbrella')          # 24 x 12
    c.poly([(1, 4), (6, 1), (12, 0), (18, 1), (22, 4)], WHT)
    for x0 in (3, 11, 17):
        c.poly([(x0, 4), (x0 + 3, 4), (x0 + 3, 1), (x0 + 1, 1)], RED)
    c.line([(11, 4), (12, 11)], LGR)
    c.rect(3, 11, 19, 11, LRED)
    return c


@pic
def surfboards(th):
    """boards stood up in the sand"""
    c = canvas('surfboards')        # 16 x 12
    c.ell(3.5, 5.5, 2.5, 6, YEL)
    c.ell(9.5, 5.5, 2.5, 6, WHT)
    c.line([(3, 1), (3, 10)], RED)
    c.line([(9, 2), (9, 9)], LBLU)
    return c


@pic
def tower(th):
    """the lifesavers' tower"""
    c = canvas('tower')             # 24 x 20
    c.poly([(0, 2), (2, 0), (15, 0), (17, 2)], RED)
    c.rect(1, 3, 16, 8, YEL)
    c.rect(4, 4, 7, 6, BLK)
    c.rect(10, 4, 13, 6, BLK)
    c.rect(1, 3, 16, 3, RED)
    for x0, x1 in ((3, 1), (14, 16)):
        c.line([(x0, 9), (x1, 19)], LGR)
    c.line([(3, 9), (14, 19)], LGR)
    c.line([(14, 9), (3, 19)], LGR)
    c.line([(2, 9), (15, 9)], LGR)
    return c


@pic
def bridge(th):
    """a great steel arch bridge, granite pylons at each end"""
    c = canvas('bridge')            # 128 x 28
    st = DGR if th != 'night' else LGR
    deck = 18
    x0, x1 = 15, 113
    mid = (x0 + x1) / 2.0
    half = (x1 - x0) / 2.0
    top = lambda x: 1 + 16 * ((x - mid) / half) ** 2
    bot = lambda x: 6 + 13 * ((x - mid) / half) ** 2
    c.line([(x, top(x)) for x in range(x0, x1 + 1)], st)
    c.line([(x, min(bot(x), deck)) for x in range(x0, x1 + 1)], st)
    for i, x in enumerate(range(x0 + 2, x1, 4)):
        yb = min(bot(x), deck)
        c.line([(x, top(x)), (x, yb)], st)
        x2 = x + 4
        if x2 < x1:
            c.line([(x, top(x)) if i % 2 else (x, yb), (x2, min(bot(x2), deck)) if i % 2 else (x2, top(x2))], st)
        if yb < deck:
            c.line([(x, yb), (x, deck)], st)
    c.rect(0, deck, 127, deck + 1, st)
    c.line([(0, deck + 2), (127, deck + 2)], st)
    for xp in (4, 114):                     # the pylons
        c.rect(xp, 3, xp + 9, 27, LGR)
        c.rect(xp + 1, 1, xp + 8, 3, LGR)
        for y in range(5, 27, 4):
            c.line([(xp, y), (xp + 9, y)], DGR)
        c.rect(xp + 3, 8, xp + 6, 13, DGR)
    for x in (30, 48, 80, 98):
        c.rect(x, deck + 3, x + 1, 27, st)
    return c


@pic
def lighthouse(th):
    """a lighthouse on the headland"""
    c = canvas('lighthouse')        # 24 x 28
    c.poly([(9, 2), (12, 0), (15, 2)], RED)                 # the cap
    c.rect(9, 3, 15, 6, YEL)                                # the light
    c.line([(12, 3), (12, 6)], WHT)
    c.rect(8, 7, 16, 7, DGR)                                # the gallery
    c.poly([(9, 8), (15, 8), (17, 25), (7, 25)], WHT)       # the tower
    c.poly([(8.4, 14), (15.6, 14), (16, 17), (8, 17)], RED)
    c.poly([(7.6, 21), (16.4, 21), (16.8, 24), (7.2, 24)], RED)
    c.rect(11, 10, 12, 12, BLK)
    c.rect(2, 25, 22, 27, LGR)
    if th == 'night':                               # the beams
        c.poly([(9, 4), (0, 2), (0, 6)], YEL)
        c.poly([(15, 4), (23, 1), (23, 7)], YEL)
    return c


@pic
def pub(th):
    """a two-storey country pub, iron lace on both verandahs"""
    c = canvas('pub')               # 80 x 28
    wall = BRN
    lace = WHT
    c.rect(12, 0, 67, 4, wall)                              # the parapet
    c.rect(36, 0, 43, 0, wall)
    word = {'H': ["k.k", "k.k", "kkk", "k.k", "k.k"], 'O': ["kkk", "k.k", "k.k", "k.k", "kkk"],
            'T': ["kkk", ".k.", ".k.", ".k.", ".k."], 'E': ["kkk", "k..", "kk.", "k..", "kkk"],
            'L': ["k..", "k..", "k..", "k..", "kkk"]}
    x = 30
    for ch in 'HOTEL':
        c.art(word[ch], {'k': YEL}, x, 0)
        x += 4
    for yv in (5, 16):                                      # the two verandahs
        c.rect(8, yv, 71, yv + 1, LGR)                      # roof
        c.rect(8, yv + 2, 71, yv + 10, BLK)                 # the shade
        for x in range(10, 71, 4):                          # lace frieze
            c.px(x, yv + 2, lace)
            c.px(x + 1, yv + 3, lace)
            c.px(x - 1, yv + 3, lace)
        c.line([(8, yv + 2), (71, yv + 2)], lace)
        for x0 in (14, 26, 38, 50, 62):                     # doors and windows behind
            c.rect(x0, yv + 5, x0 + 4, yv + 10, wall)
            c.rect(x0 + 1, yv + 6, x0 + 3, yv + 10, BLK)
        for x in range(8, 72, 9):                           # posts
            c.line([(x, yv + 2), (x, yv + 10)], lace)
    for x in range(9, 71, 2):                               # balcony railing
        c.px(x, 14, lace)
    c.line([(8, 13), (71, 13)], lace)
    c.line([(8, 15), (71, 15)], lace)
    c.rect(36, 22, 43, 27, wall)                            # the bar door
    c.rect(37, 23, 42, 27, BLK)
    c.line([(6, 27), (73, 27)], LGR)
    return c


@pic
def headframe(th):
    """a goldfields poppet head: the winding wheel up on its timber frame"""
    c = canvas('headframe')         # 40 x 36
    t = BRN
    wx, wy = 16, 5
    c.d.ellipse([wx - 6, wy - 3.6, wx + 6, wy + 3.6], outline=LGR + 1)
    for k in range(6):
        a = k * math.pi / 3
        c.line([(wx, wy), (wx + 6 * math.cos(a), wy + 3.6 * math.sin(a))], LGR)
    c.line([(wx, wy), (wx, 26)], DGR)                       # the cable
    c.line([(wx - 6, wy + 1), (wx - 6, 26)], DGR)
    # the legs: an A frame and a back leg towards the winder
    c.line([(wx - 3, wy + 4), (8, 27)], t)
    c.line([(wx + 3, wy + 4), (24, 27)], t)
    c.line([(wx + 2, wy + 3), (37, 27)], t)
    c.line([(wx - 2, wy + 4), (wx + 2, wy + 4)], t)
    for y in (12, 19):
        a = (y - wy - 4) / (27 - wy - 4)
        xl = wx - 3 + (8 - wx + 3) * a
        xr = wx + 3 + (24 - wx - 3) * a
        c.line([(xl, y), (xr, y)], t)
    c.line([(wx - 3, wy + 4), (24, 27)], t)
    c.line([(wx + 3, wy + 4), (8, 27)], t)
    # the brace shed at the foot
    c.rect(4, 27, 28, 35, LGR)
    c.poly([(3, 27), (29, 27), (27, 25), (5, 25)], DGR)
    for x in range(5, 28, 2):
        c.line([(x, 28), (x, 35)], DGR)
    c.rect(13, 29, 18, 35, BLK)
    return c


@pic
def roadtrain(th):
    """a road train: a prime mover and three cattle crates"""
    c = canvas('roadtrain')         # 80 x 12
    # prime mover, facing left
    c.rect(2, 4, 9, 8, RED)                                 # bonnet
    c.rect(6, 1, 13, 8, RED)                                # cab
    c.rect(7, 2, 10, 4, BLK)                                # window
    c.rect(0, 5, 1, 8, LGR)                                 # roo bar
    c.line([(14, 0), (14, 7)], LGR)                         # the stack
    c.rect(2, 9, 14, 9, DGR)
    for i, x0 in enumerate((20, 40, 60)):
        c.rect(x0, 0, x0 + 17, 8, LGR)
        for x in range(x0 + 2, x0 + 17, 3):
            c.rect(x, 2, x + 1, 6, DGR)
        c.line([(x0 - 4 if i == 0 else x0 - 3, 8), (x0, 8)], DGR)
    for x in (4, 11, 23, 27, 34, 43, 47, 54, 63, 67, 74):
        c.ell(x, 10, 1.6, 1.2, BLK)
    return c


@pic
def steamer(th):
    """a paddle steamer on the river"""
    c = canvas('steamer')           # 64 x 18
    c.rect(16, 0, 19, 8, BLK)                               # the funnel
    c.rect(16, 0, 19, 1, RED)
    c.rect(34, 2, 35, 6, BLK)                               # whistle mast
    c.rect(8, 6, 52, 7, LGR)                                # top deck
    c.rect(10, 8, 50, 11, WHT)
    for x in range(12, 50, 4):
        c.rect(x, 9, x + 1, 10, BLK)
    c.rect(44, 3, 50, 7, WHT)                               # the wheelhouse
    c.rect(46, 4, 49, 5, BLK)
    c.rect(4, 12, 59, 12, LGR)
    c.poly([(2, 13), (62, 13), (58, 16), (6, 16)], WHT)     # the hull
    c.line([(5, 15), (59, 15)], RED)
    c.ell(28, 12, 7, 4.5, RED)                              # the paddle box
    c.ell(28, 12, 5, 3, BLK)
    for k in range(6):
        a = k * math.pi / 3
        c.line([(28, 12), (28 + 5 * math.cos(a), 12 + 3 * math.sin(a))], RED)
    return c


@pic
def waverock(th):
    """a great granite wave, streaked down its face"""
    c = canvas('waverock')          # 96 x 20
    b = BRN
    for y in range(20):
        t = y / 19.0
        # the face: the lip curls out over a hollow, then sweeps out to the foot
        xl = 10 + 10 * math.sin(math.pi * min(1.0, t * 1.3)) - 12 * t
        if y < 2:
            xl = 4 + (2 - y) * 4
        xr = 95 if y > 6 else 95 - (6 - y) * 3
        c.rect(int(xl), y, int(xr), y, b)
    for x in range(14, 96, 5):                              # the streaks
        y0 = 2 + (x % 4)
        c.line([(x, y0), (x - 2, 19)], DGR)
        if x % 3 == 0:
            c.line([(x + 2, y0 + 3), (x + 1, 19)], DGR)
    c.line([(4, 1), (14, 0), (80, 0), (95, 4)], LGR)        # the lit lip
    c.poly([(6, 2), (14, 1), (12, 3), (8, 4)], LGR)
    return c

@pic
def stacks(th):
    """limestone stacks standing off the cliffs, cut in at the waterline"""
    c = canvas('stacks')            # 64 x 20
    b = YEL
    for x0, x1, top in ((3, 15, 0), (24, 32, 7), (41, 52, 3), (57, 61, 14)):
        cx = (x0 + x1) / 2.0
        hw = (x1 - x0) / 2.0
        for y in range(top, 20):
            t = (y - top) / max(1.0, 19 - top)
            w = hw * (0.75 + 0.25 * math.sin(t * 2.6)) - (1.8 if t > 0.85 else 0)
            if y == top:
                w *= 0.6
            off = 0.8 * math.sin(y * 0.9 + x0)
            c.rect(int(round(cx - w + off)), y, int(round(cx + w + off)), y, b)
        for y in range(top + 2, 18, 3):
            c.line([(x0, y), (x1, y)], BRN)
        c.line([(int(cx + hw * 0.5), top + 1), (int(cx + hw * 0.6), 19)], BRN)
    for k in range(64):                               # surf round their feet
        if (k * 5) % 7 < 3:
            c.px(k, 19, WHT)
    return c

@pic
def dunny(th):
    """the outback dunny, the moon cut in its door"""
    c = canvas('dunny')             # 16 x 18
    c.poly([(1, 2), (14, 0), (15, 2), (0, 3)], LGR)
    c.rect(2, 3, 13, 17, BRN)
    c.rect(4, 5, 11, 17, BRN)
    c.line([(3, 4), (3, 17)], BLK)
    c.line([(12, 4), (12, 17)], BLK)
    for x, y in ((7, 6), (6, 7), (6, 8), (7, 9)):            # the moon
        c.px(x, y, BLK)
    c.px(10, 11, YEL)
    return c


@pic
def croc(th):
    """a saltie: eyes, snout and the ridges of its back"""
    rows = [
        "..................g..g..g..g..g..g......",
        "..gg.o.......gg..ggggggggggggggggggg....",
        "gggggggggggg..gggggggggggggggggggggggg..",
        "gggggggggggggggggggggggggggggggggggggggg",
        "........................................",
        "........................................",
    ]
    c = canvas('croc')              # 48 x 6
    c.art(rows, {'g': GRN, 'o': YEL}, 4, 0)
    return c


@pic
def woolshed(th):
    """a shearing shed on its stumps, the sheep yards beside it"""
    c = canvas('woolshed')          # 80 x 20
    c.poly([(18, 0), (58, 0), (70, 7), (6, 7)], LGR)        # the roof
    for x in range(10, 68, 3):
        c.line([(x + (38 - x) * 0.3, 1), (x, 6)], DGR)
    c.rect(9, 8, 67, 15, BRN)                               # weathered boards
    for x in range(10, 67, 2):
        c.line([(x, 8), (x, 15)], RED)
    c.rect(22, 9, 29, 14, BLK)
    c.rect(46, 9, 53, 14, BLK)
    c.line([(8, 16), (68, 16)], BRN)
    for x in range(9, 68, 6):
        c.line([(x, 17), (x, 19)], BLK)                     # the stumps
    for x in (70, 74, 78):                                  # the yards
        c.line([(x, 12), (x, 19)], BRN)
    c.line([(68, 13), (79, 13)], BRN)
    c.line([(68, 16), (79, 16)], BRN)
    for x in (71, 75):
        c.ell(x + 1, 17.5, 1.6, 1.2, WHT)
    return c


@pic
def silos(th):
    """grain silos by the railway"""
    c = canvas('silos')             # 48 x 24
    for x0 in (2, 17, 32):
        c.poly([(x0, 3), (x0 + 5, 0), (x0 + 7, 0), (x0 + 12, 3)], LGR)
        c.rect(x0, 3, x0 + 12, 20, LGR)
        c.rect(x0 + 2, 4, x0 + 3, 19, WHT)
        c.line([(x0 + 10, 4), (x0 + 10, 19)], DGR)
        c.line([(x0, 20), (x0 + 12, 20)], DGR)
    c.line([(8, 0), (39, 0)], DGR)                           # the gantry
    for x in range(0, 48, 3):
        c.px(x, 23, BRN)
    c.line([(0, 22), (47, 22)], DGR)
    return c


@pic
def church(th):
    """a little bush church of stone, roofless now"""
    c = canvas('church')            # 48 x 26
    s = LGR
    c.rect(20, 0, 21, 4, s)                                 # the cross
    c.line([(18, 1), (23, 1)], s)
    c.rect(17, 5, 24, 9, s)                                 # the bell cote
    c.rect(19, 6, 22, 8, BLK)
    c.poly([(20.5, 7), (31, 13), (10, 13)], s)              # the gable
    c.rect(12, 13, 29, 25, s)
    for y in (16, 19, 22):
        c.line([(12, y), (29, y)], DGR)
    for y, xs in ((13, (16, 24)), (16, (14, 20, 27)), (19, (17, 23)), (22, (14, 26))):
        for x in xs:
            c.line([(x, y), (x, y + 2)], DGR)
    c.rect(18, 19, 23, 25, BLK)                             # the door
    c.ell(20.5, 19, 2.5, 1.6, BLK)
    c.rect(14, 14, 15, 17, BLK)                             # lancet windows
    c.rect(26, 14, 27, 17, BLK)
    # the nave going back, broken
    c.rect(30, 16, 44, 25, s)
    for x, h in ((33, 18), (36, 21), (40, 17), (43, 22)):
        c.rect(x, 16, x + 1, h, -1)
    c.line([(30, 21), (44, 21)], DGR)
    c.rect(32, 22, 33, 24, BLK)
    c.rect(38, 22, 39, 24, BLK)
    return c


@pic
def camels(th):
    """a camel string plodding through the heat"""
    rows = [
        "............................................................",
        "..bb...........................bb...........................",
        ".bbb.......bb.................bbb.......bb..................",
        "bb.b......bbbb...............bb.b......bbbb.................",
        "...b.....bbbbbb.................b.....bbbbbb................",
        "...bb..bbbbbbbbbb...............bb..bbbbbbbbbb..............",
        "....bbbbbbbbbbbbbb...............bbbbbbbbbbbbbb.............",
        ".....bbbbbbbbbbbbb..rrrrrrrrrrrr..bbbbbbbbbbbbb.............",
        "......bbbbbbbbbbb.r...............bbbbbbbbbbb...............",
        "......b..b...b..b..................b..b...b..b..............",
        "......b..b...b..b..................b..b...b..b..............",
        ".....b...b...b...b................b...b...b...b.............",
        ".....b...b...b...b................b...b...b...b.............",
        "....b....b...b....b..............b....b...b....b............",
        "....b....b...b....b..............b....b...b....b............",
        "...bb...bb..bb...bb.............bb...bb..bb...bb............",
    ]
    rows = [r[::-1] for r in rows]                          # walking left, as the original
    rows = [r[-64:] if len(r) >= 64 else r.rjust(64, '.') for r in rows]
    col = BRN if th != 'dusk' else RED
    return from_art('camels', rows, {'b': col, 'r': DGR})


@pic
def ute(th):
    """the farm ute"""
    c = canvas('ute')               # 32 x 10
    w = WHT
    c.poly([(4, 1), (11, 1), (13, 4), (4, 4)], w)           # the cab
    c.rect(5, 2, 7, 3, BLK)
    c.rect(9, 2, 10, 3, BLK)
    c.rect(1, 4, 28, 7, w)                                  # the body and tray
    c.rect(0, 5, 1, 7, LGR)
    c.line([(14, 4), (28, 4)], LGR)
    c.line([(14, 2), (27, 2)], LGR)                         # the tray rail
    c.line([(14, 2), (14, 4)], LGR)
    c.line([(27, 2), (27, 4)], LGR)
    c.ell(6, 8, 2.2, 1.5, BLK)
    c.ell(23, 8, 2.2, 1.5, BLK)
    c.line([(2, 6), (28, 6)], RED)
    return c


# ---------------------------------------------------------------------------
_cache = {}


def get(name, theme='sky'):
    key = (name, theme)
    if key not in _cache:
        w, h = size(name)
        if name in DRAW:
            a = DRAW[name](theme).arr()
        else:
            raise KeyError(name)
        assert a.shape == (h, w), (name, a.shape, (h, w))
        _cache[key] = a
    return _cache[key]


def sheet(path, theme='sky', scale=3):
    """every picture on its theme's sky, for looking at"""
    import world
    names = list(_vz.S)
    bgc = {'sky': world.LBLU, 'dusk': world.LRED, 'night': world.BLK, 'cave': world.BLK, 'mist': world.DGR}[theme]
    pad = 6
    rows = []
    row = []
    wsum = 0
    for n in names:
        a = get(n, theme)
        if wsum + a.shape[1] + pad > 360 and row:
            rows.append(row)
            row, wsum = [], 0
        row.append((n, a))
        wsum += a.shape[1] + pad
    rows.append(row)
    H = sum(max(a.shape[0] for _, a in r) + pad for r in rows)
    img = np.full((H, 360), bgc, np.int16)
    y = 0
    for r in rows:
        x = pad
        hh = max(a.shape[0] for _, a in r)
        for n, a in r:
            yy = y + hh - a.shape[0]
            sub = img[yy:yy + a.shape[0], x:x + a.shape[1]]
            sub[a >= 0] = a[a >= 0]
            x += a.shape[1] + pad
        y += hh + pad
    from PIL import Image as I
    im = I.fromarray(world.PAL[img].astype(np.uint8))
    im = im.resize((im.width * scale, int(im.height * scale * ASP)), I.NEAREST)
    im.save(path)


if __name__ == '__main__':
    th = sys.argv[2] if len(sys.argv) > 2 else 'sky'
    sheet(sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/stamps.png', th)
