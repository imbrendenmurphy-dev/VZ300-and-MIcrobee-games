"""Floor objects for the first-person view, drawn fresh in the GROOVY GHOULIES style.

Each object is designed on a box 24 units wide and `h` units tall, standing on
the floor at the depth's floor line. Units become pixels through the depth's
scale (OBJ_SCALE in maze_native), so the same drawing serves all three
distances. The run-time merge gives every 8x8 cell one ink plus black, so the
last step reduces each cell to exactly that, with a black halo in the cells
the object touches.
"""
import math
import numpy as np
import ghoulies as G

VW, VH = 208, 192
FLOOR = {1: 176, 2: 148, 3: 127}
SCALE = {1: (2.35, 3.3), 2: (1.33, 1.9), 3: (0.9, 1.3)}
DARK = {15: 7, 11: 3, 9: 1, 10: 2, 14: 6, 13: 5, 12: 4, 7: 8, 3: 3, 1: 1, 2: 2, 6: 6, 5: 5, 4: 4, 8: 8, 0: 0}


class Box:
    def __init__(self, t, d, h):
        self.t = t
        self.sx, self.sy = SCALE[d]
        w = 24 * self.sx
        self.x0 = 8 * round((104 - w / 2) / 8)
        self.y0 = FLOOR[d] - h * self.sy
        self.d = d

    def p(self, u, v):
        return (self.x0 + u * self.sx, self.y0 + v * self.sy)

    def pts(self, q):
        return [self.p(u, v) for u, v in q]

    def box(self, u0, v0, u1, v1):
        a, b = self.p(u0, v0), self.p(u1, v1)
        return (a[0], a[1], b[0], b[1])

    def w(self, k):
        return max(1, round(k * self.sx))

    # shorthands that scale everything
    def ell(self, b, ink, **kw):
        return self.t.part('ellipse', self.box(*b), ink, **kw)

    def poly(self, q, ink, **kw):
        return self.t.part('polygon', self.pts(q), ink, **kw)

    def rect(self, b, ink, **kw):
        return self.t.part('rectangle', self.box(*b), ink, **kw)

    def line(self, q, ink, width=1, **kw):
        return self.t.part('line', self.pts(q), ink, width=self.w(width), **kw)

    def dline(self, q, ink, width=1):
        self.t.decal('line', self.pts(q), ink, self.w(width))

    def dell(self, b, ink):
        self.t.decal('ellipse', self.box(*b), ink)

    def drect(self, b, ink):
        self.t.decal('rectangle', self.box(*b), ink)

    def dpoly(self, q, ink):
        self.t.decal('polygon', self.pts(q), ink)


# ---- the objects (u across 0..24, v down 0..h; v = h is the floor) -----------------

def bones(b):
    b.line([(3, 9), (14, 7)], 15, 1.6, shade=7)
    b.line([(9, 10), (20, 6)], 15, 1.6, shade=7)
    for u, v in ((3, 9), (14, 7), (9, 10), (20, 6)):
        b.ell((u - 1.3, v - 1.2, u + 1.3, v + 1.2), 15, shade=7)
    b.ell((11, 1, 20, 9), 15, shade=7)                         # skull on top
    b.dell((12.6, 3.5, 14.8, 6), 0)
    b.dell((16, 3.5, 18.2, 6), 0)
    b.drect((14, 7.4, 17, 8), 0)
bones.h = 11


def grave(b):
    b.poly([(3, 17), (21, 17), (22, 19), (2, 19)], 10, shade=2)          # grass mound
    b.poly(G.smooth([(5, 18), (5, 6), (8, 2), (12, 1), (16, 2), (19, 6), (19, 18)], 3), 7, shade=8, tex='stone',
           gloss=15)
    b.drect((11, 4, 13, 13), 0)
    b.drect((8, 6.5, 16, 8.5), 0)
    for u in (6, 9, 17):
        b.dline([(u, 18), (u + .6, 15.5)], 10, .6)
    b.dline([(15, 3), (14, 6), (16, 8)], 8, .5)
grave.h = 19


def keeper(b):
    # Grigor: hunched old groundskeeper with a lantern and a spade
    b.line([(19, 4), (20, 26)], 3, 1.2, shade=0)                         # spade handle
    b.poly([(18, 22), (22, 22), (21.5, 26), (18.5, 26)], 7, shade=8)
    b.poly(G.smooth([(7, 9), (16, 8), (18, 16), (17, 25), (6, 25), (5, 16)], 3), 9, shade=1, tex='cloth')
    b.line([(7, 13), (4, 18)], 9, 2.2, shade=1)
    b.ell((2, 17, 6, 21), 15, shade=7)                                   # hand
    b.line([(4, 19), (4, 21)], 0, .4, shade=False)
    b.rect((2.5, 21, 5.5, 25), 11, shade=3, gloss=15)                    # lantern
    b.line([(15, 13), (19, 15)], 9, 2.2, shade=1)
    for u in (8, 15):
        b.rect((u - 2, 24.6, u + 2, 26), 3, shade=0)                     # boots
    b.ell((7, 2, 16, 11), 15, shade=7)                                   # face
    b.poly([(7, 7), (16, 7), (15, 11), (11.5, 13), (8, 11)], 7, shade=8, tex='fur')   # beard
    b.poly([(6, 4), (11, 0), (17, 4)], 3, shade=0)                       # floppy hat
    b.rect((5, 3.5, 18, 5), 3, shade=0)
    b.dell((9, 5.5, 10.4, 7), 0)
    b.dell((12.6, 5.5, 14, 7), 0)
    b.dell((10.6, 7, 12.4, 8.6), 9)                                      # red nose
keeper.h = 26


def chest(b, open_=False):
    if open_:
        b.poly([(2, 1), (22, 1), (21, 6), (3, 6)], 3, shade=0, tex='cloth')     # lid thrown back
        b.rect((2, 1, 22, 2), 11, shade=3)
        b.ell((4, 5, 20, 10), 11, shade=3, gloss=15)                    # heap of gold
        for u, v in ((7, 6.5), (12, 5.6), (16, 6.8), (10, 8)):
            b.dell((u - .8, v - .6, u + .8, v + .6), 15)
        b.poly([(2, 8), (22, 8), (21, 15), (3, 15)], 3, shade=0, tex='cloth')
    else:
        b.poly(G.smooth([(2, 7), (3, 2), (12, 0.5), (21, 2), (22, 7)], 3), 3, shade=0, tex='cloth')
        b.poly([(2, 7), (22, 7), (21, 15), (3, 15)], 3, shade=0, tex='cloth')
    for u in (5, 19):
        b.rect((u - 1, 1 if not open_ else 8, u + 1, 15), 11, shade=3, gloss=15)
    b.rect((2, 7, 22, 8.6), 11, shade=3)
    b.rect((10, 7.5, 14, 12), 11, shade=3, gloss=15)                     # lock
    b.dell((11.4, 9, 12.6, 10.4), 0)
    b.drect((11.8, 10, 12.2, 11.4), 0)
chest.h = 15


def chest_open(b):
    chest(b, True)
chest_open.h = 15


def angel(b):
    # stone angel save point: kneeling, wings up, a glowing halo
    b.rect((5, 20, 19, 23), 8, shade=0, tex='stone')
    b.rect((7, 17, 17, 20), 7, shade=8, tex='stone')
    for side in (-1, 1):
        b.poly([(12 + side * 2, 9), (12 + side * 10, 2), (12 + side * 11, 8), (12 + side * 8, 15)], 15, shade=7)
    b.poly(G.smooth([(9, 8), (15, 8), (17, 17), (7, 17)], 3), 15, shade=7, tex='cloth')
    b.ell((9.2, 3, 14.8, 8.4), 15, shade=7)
    b.ell((8, 0, 16, 2.4), 11, shade=False)                              # halo
    b.ell((10, 0.6, 14, 1.8), 0, shade=False, line=False)
    b.poly([(10.5, 10), (13.5, 10), (12, 13)], 15, shade=7)               # praying hands
    b.dline([(10.4, 5.8), (11.4, 6.2)], 0, .4)
    b.dline([(12.6, 6.2), (13.6, 5.8)], 0, .4)
    b.dline([(11.2, 6.6), (11.2, 8)], 14, .4)                            # a stone tear
angel.h = 23


def armour(b):
    b.line([(20, 0), (20, 24)], 3, .9, shade=0)                          # halberd
    b.poly([(20, 1), (23, 3), (23, 7), (20, 6)], 7, shade=8, gloss=15)
    for u in (9, 15):
        b.rect((u - 2, 16, u + 2, 24), 7, shade=8, gloss=15)
    b.poly(G.smooth([(6, 7), (18, 7), (17, 16), (7, 16)], 3), 7, shade=8, gloss=15)
    b.rect((9, 9, 15, 15), 12, shade=4)
    b.drect((11.5, 9.5, 12.5, 14.5), 11)
    for u in (5, 19):
        b.ell((u - 3, 6, u + 3, 10), 7, shade=8, gloss=15)
        b.line([(u, 9), (u + (1 if u < 12 else -1), 15)], 7, 1.6, shade=8)
    b.poly(G.smooth([(8, 1), (12, 0), (16, 1), (16, 7), (8, 7)], 3), 7, shade=8, gloss=15)
    b.drect((9, 3, 15, 4.2), 0)
    b.drect((9.6, 3.4, 10.8, 3.8), 14)
    b.drect((13.2, 3.4, 14.4, 3.8), 14)
    b.poly([(12, 0), (14, -2), (17, -1), (15, 1)], 9, shade=1)           # plume
armour.h = 24


def gargoyle_statue(b):
    b.rect((5, 16, 19, 20), 8, shade=0, tex='stone')
    for side in (-1, 1):
        b.poly([(12 + side * 3, 7), (12 + side * 8, 1), (12 + side * 9, 8), (12 + side * 7, 13)], 8, shade=0,
               tex='membrane')
    b.ell((6, 9, 18, 17), 7, shade=8, tex='stone', gloss=15)
    b.ell((7.5, 3, 16.5, 10), 7, shade=8, tex='stone', gloss=15)
    for side in (-1, 1):
        b.poly([(12 + side * 3, 4), (12 + side * 6, -1), (12 + side * 5, 4)], 15, shade=7)
    b.drect((9, 5.5, 11, 6.6), 0)
    b.drect((13, 5.5, 15, 6.6), 0)
    b.drect((10, 8, 14, 8.8), 0)
    for u in (8, 16):
        b.poly([(u - 1.5, 15), (u + 1.5, 15), (u, 17)], 15, shade=7)
gargoyle_statue.h = 20


def lectern(b):
    b.rect((6, 15, 18, 16.5), 3, shade=0)
    b.rect((10.5, 6, 13.5, 15), 3, shade=0, tex='cloth')
    b.poly([(2, 4), (22, 4), (20, 8), (4, 8)], 3, shade=0, tex='cloth')
    for side in (-1, 1):                                                 # open book
        b.poly([(12, 4.5), (12 + side * 9, 3), (12 + side * 9, 0.5), (12, 1.6)], 15, shade=7)
    for k in range(3):
        b.dline([(5, 1.6 + k * .6), (10, 2.2 + k * .6)], 8, .3)
        b.dline([(14, 2.2 + k * .6), (19, 1.6 + k * .6)], 8, .3)
    b.rect((19.5, -2.5, 21, 1), 15, shade=7)                             # candle
    b.ell((19.4, -4.5, 21.1, -2.4), 11, shade=False)
lectern.h = 17


def vesper(b):
    # pale librarian ghost with long dark hair, holding a book
    b.poly(G.smooth([(6, 8), (18, 8), (21, 24), (17, 22), (12, 24.5), (7, 22), (3, 24)], 3), 14, shade=6,
           tex='membrane')
    b.poly(G.smooth([(6, 4), (8, 0.6), (12, 0), (16, 0.6), (18, 4), (19, 13), (16, 10), (8, 10), (5, 13)], 3), 5,
           shade=0, tex='fur')
    b.ell((8.4, 1.8, 15.6, 9), 15, shade=7)
    b.dell((9.6, 4.6, 11, 6), 0)
    b.dell((13, 4.6, 14.4, 6), 0)
    b.dline([(11, 7.6), (13, 7.6)], 9, .4)
    b.rect((8, 13, 16, 17), 9, shade=1)                                  # red book
    b.drect((8.6, 13.4, 9.2, 16.6), 11)
    for u in (8, 16):
        b.ell((u - 1.4, 14, u + 1.4, 16.4), 15, shade=7)
vesper.h = 25


def orb(b):
    # the eye-orb: a glass ball with a winking eye, on a brass claw stand
    b.poly([(6, 17), (18, 17), (16, 13), (8, 13)], 11, shade=3, gloss=15)
    b.rect((4, 17, 20, 19), 3, shade=0)
    for side in (-1, 1):
        b.line([(12 + side * 3, 13), (12 + side * 7, 9)], 11, .9, shade=3)
    b.ell((4, 0, 20, 14.5), 14, shade=6, gloss=15)
    b.ell((7, 3, 17, 11.5), 15, shade=7)
    b.ell((9.5, 4.2, 14.5, 10.2), 9, shade=1)
    b.dell((11.2, 5.4, 12.8, 9), 0)
    b.dell((9.8, 4.6, 10.8, 5.6), 15)
orb.h = 19


def bookseller(b):
    # hunched, grinning, a tottering stack of books on his back
    for k, (c, w) in enumerate(((12, 9), (10, 8), (13, 9), (11, 7))):
        b.rect((14 - w / 2 + k % 2, 2 + k * 2.6, 14 + w / 2 + k % 2, 4.6 + k * 2.6), c, shade=0)
    b.poly(G.smooth([(4, 10), (14, 8), (19, 14), (18, 22), (5, 22), (3, 15)], 3), 9, shade=1, tex='cloth')
    b.ell((3, 7, 11, 14), 15, shade=7)
    b.poly([(3, 9), (4, 6), (8, 5), (11, 7), (11, 9)], 8, shade=0)        # cap
    b.dell((4.6, 9.4, 5.8, 10.6), 0)
    b.dell((7.6, 9.4, 8.8, 10.6), 0)
    b.t.decal('chord', (b.box(4.5, 10.6, 9.6, 13.4), 0, 180), 0)
    b.drect((5.4, 11.1, 8.6, 11.7), 15)
    b.ell((1.5, 15, 5.5, 18.5), 15, shade=7)                             # hand holding a potion
    b.ell((0, 16, 3, 20), 13, shade=5, gloss=15)
    for u in (8, 15):
        b.rect((u - 2, 21.4, u + 2, 23), 3, shade=0)
bookseller.h = 23


def kaspar(b):
    # a thin old man grinning through the bars of his cell
    b.poly(G.smooth([(7, 10), (17, 10), (18, 24), (6, 24)], 3), 10, shade=2, tex='cloth')
    b.ell((7.5, 2, 16.5, 11), 15, shade=7)
    b.poly([(7, 6), (8, 2), (12, 1), (16, 2), (17, 6), (15, 3.6), (9, 3.6)], 7, shade=8)
    b.dell((9.2, 5, 10.6, 6.4), 0)
    b.dell((13.4, 5, 14.8, 6.4), 0)
    b.t.decal('chord', (b.box(9, 7, 15, 10), 0, 180), 0)
    b.drect((10, 7.4, 14, 8), 15)
    b.drect((11.6, 7.4, 12.2, 8), 0)                                     # missing tooth
    for u in (4.5, 8.5, 12.5, 16.5, 20):
        b.line([(u, 1), (u, 25)], 7, .8, shade=8)
    b.line([(4, 1), (20.5, 1)], 8, 1, shade=0)
    b.line([(4, 14), (20.5, 14)], 8, .8, shade=0)
    for u in (8.5, 14.5):                                                # hands on the bars
        b.ell((u - 1.6, 12.4, u + 1.6, 15.4), 15, shade=7)
kaspar.h = 25


def throne(b):
    # the ghoul king's throne of bones
    b.rect((3, 20, 21, 22), 8, shade=0, tex='stone')
    b.poly(G.smooth([(5, 20), (5, 4), (8, 0.5), (12, -0.5), (16, 0.5), (19, 4), (19, 20)], 3), 15, shade=7)
    b.rect((7, 4, 17, 13), 5, shade=0, tex='cloth')
    b.rect((4, 13, 20, 16), 5, shade=0)
    for u in (4, 20):
        b.ell((u - 2.4, 9, u + 2.4, 13.4), 15, shade=7)                   # skull armrests
        b.dell((u - 1.4, 10.4, u - .3, 11.6), 0)
        b.dell((u + .3, 10.4, u + 1.4, 11.6), 0)
    b.ell((9.2, -2, 14.8, 3), 15, shade=7)
    b.dell((10.4, -0.6, 11.8, 0.8), 0)
    b.dell((12.2, -0.6, 13.6, 0.8), 0)
    for u in (6, 18):
        b.line([(u, 16), (u, 20)], 15, 1.2, shade=7)
throne.h = 22


def bench(b):
    # the clockmaker's workbench, cogs and a tiny hammer
    for u in (4, 20):
        b.rect((u - 1, 6, u + 1, 12), 3, shade=0)
    b.rect((1, 4, 23, 6.5), 3, shade=0, tex='cloth')
    for cx, cy, r in ((8, 2, 2.6), (14, 2.6, 1.8)):
        pts = []
        for a in range(16):
            ang = a * math.pi / 8
            rr = r * (1 if a % 2 else .78)
            pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * .9))
        b.poly(pts, 11, shade=3, gloss=15)
        b.dell((cx - .6, cy - .5, cx + .6, cy + .5), 0)
    b.line([(17, 3.6), (21, 1)], 7, .6, shade=8)
    b.rect((20, 0, 22, 1.6), 7, shade=8)
bench.h = 12


def otto(b):
    # a little ghost with a monocle, polishing a cog
    b.poly(G.smooth([(7, 3), (12, 0), (17, 3), (18, 13), (16, 18), (13, 16), (11, 18.5), (8, 16), (5, 18), (6, 12)], 3),
           15, shade=14)
    b.dell((9, 5, 11, 8), 0)
    b.dell((13.2, 4.2, 16.4, 8.4), 0)                                   # monocle: a black ring
    b.dell((13.8, 4.8, 15.8, 7.8), 15)
    b.dell((14.4, 5.4, 15.4, 7), 0)
    b.dline([(16.2, 7.8), (17.4, 12)], 0, .3)
    b.t.decal('chord', (b.box(10, 9, 14, 11.4), 0, 180), 0)
    pts = []
    for a in range(16):
        ang = a * math.pi / 8
        rr = 2.6 * (1 if a % 2 else .76)
        pts.append((19 + math.cos(ang) * rr, 13 + math.sin(ang) * rr * .9))
    b.poly(pts, 11, shade=3, gloss=15)
    b.dell((18.4, 12.5, 19.6, 13.5), 0)
otto.h = 19


def bell(b):
    b.rect((2, -1, 22, 1), 3, shade=0)                                   # beam
    b.line([(12, 1), (12, 3)], 8, .8, shade=0)
    b.poly(G.smooth([(8, 4), (12, 2.6), (16, 4), (18, 14), (21, 18), (3, 18), (6, 14)], 3), 11, shade=3, gloss=15)
    b.rect((3, 17, 21, 19), 11, shade=3)
    b.ell((10.6, 18.4, 13.4, 21.4), 8, shade=0)                          # clapper
    b.dline([(7, 10), (17, 10)], 3, .4)
bell.h = 22


def batlord_statue(b):
    # the Bat Lord asleep on his perch, wings wrapped round him
    b.rect((3, 0, 21, 1.6), 3, shade=0)
    for u in (10, 14):
        b.line([(u, 1.4), (u, 3)], 11, .6, shade=3)
    b.poly(G.smooth([(6, 2.6), (18, 2.6), (19, 10), (15, 15), (12, 16), (9, 15), (5, 10)], 3), 5, shade=0,
           tex='membrane')
    b.dline([(12, 3), (12, 14)], 13, .4)
    b.dline([(9, 3), (8, 12)], 13, .3)
    b.dline([(15, 3), (16, 12)], 13, .3)
    # upside down: head at the bottom with closed eyes and a crown
    b.ell((8.6, 10, 15.4, 15.6), 13, shade=5)
    b.poly([(9, 15), (9.6, 17), (11, 16), (12, 17.6), (13, 16), (14.4, 17), (15, 15)], 11, shade=3)
    b.dline([(9.6, 12.2), (11, 12.8)], 0, .4)
    b.dline([(13, 12.8), (14.4, 12.2)], 0, .4)
    b.dpoly([(10.6, 11), (11.2, 10), (11.8, 11)], 15)
    b.dpoly([(12.2, 11), (12.8, 10), (13.4, 11)], 15)
batlord_statue.h = 18


def coffin(b):
    hexa = [(8, 0), (16, 0), (20, 5), (17, 24), (7, 24), (4, 5)]
    b.poly(hexa, 1, shade=0, tex='cloth', gloss=9)
    b.poly([(9, 1.6), (15, 1.6), (18, 5.6), (15.6, 22.4), (8.4, 22.4), (6, 5.6)], 3, shade=0, line=True)
    b.rect((11.2, 4, 12.8, 17), 11, shade=3, gloss=15)
    b.rect((8.4, 7.2, 15.6, 8.8), 11, shade=3, gloss=15)
coffin.h = 24


def easel(b):
    b.line([(6, 22), (12, 0)], 3, .9, shade=0)
    b.line([(18, 22), (12, 0)], 3, .9, shade=0)
    b.line([(12, 4), (13, 22)], 3, .8, shade=0)
    b.rect((3, 2, 21, 16), 11, shade=3, gloss=15)                        # gilt frame
    b.rect((5, 3.8, 19, 14.2), 4, shade=0)
    b.poly([(8, 14.2), (9, 10), (12, 9), (15, 10), (16, 14.2)], 0, shade=False)     # the count's portrait
    b.ell((10, 5, 14, 10), 15, shade=7)
    b.poly([(9.6, 7), (10.4, 4.4), (12, 5.6), (13.6, 4.4), (14.4, 7), (12, 6)], 0, shade=False)
    b.dell((10.8, 7.2, 11.6, 7.9), 9)
    b.dell((12.4, 7.2, 13.2, 7.9), 9)
    b.rect((2, 15.6, 22, 17), 3, shade=0)
easel.h = 22


def throne2(b):
    # Dracula's throne: tall red velvet, gilt frame, a bat crest
    b.rect((4, 21, 20, 23.5), 8, shade=0, tex='stone')
    b.poly(G.smooth([(5, 21), (5, 4), (8, 1), (12, 0), (16, 1), (19, 4), (19, 21)], 3), 11, shade=3, gloss=15)
    b.poly(G.smooth([(6.5, 15), (6.5, 5), (9, 2.6), (12, 1.6), (15, 2.6), (17.5, 5), (17.5, 15)], 3), 9, shade=1,
           tex='cloth')
    b.rect((4.5, 14, 19.5, 17.5), 9, shade=1)
    for u in (5, 19):
        b.rect((u - 1.4, 11, u + 1.4, 21), 11, shade=3, gloss=15)
    # bat crest
    b.dpoly([(12, 6), (8, 4), (9, 6.6), (7, 7.4), (10, 8), (12, 9.4), (14, 8), (17, 7.4), (15, 6.6), (16, 4)], 0)
    b.dell((11.6, 6.4, 12.4, 7.2), 11)
throne2.h = 24


OBJECTS = {'bones': bones, 'grave': grave, 'keeper': keeper, 'chest': chest, 'chest_open': chest_open, 'angel': angel,
           'armour': armour, 'gargoyle': gargoyle_statue, 'lectern': lectern, 'vesper': vesper, 'orb': orb,
           'bookseller': bookseller, 'kaspar': kaspar, 'throne': throne, 'bench': bench, 'otto': otto, 'bell': bell,
           'batlord': batlord_statue, 'coffin': coffin, 'easel': easel, 'throne2': throne2}


def object_image(name, d, pal):
    """-> 192x208 ink map (-1 = see-through), one ink plus black in every cell."""
    keep = G.W, G.H
    G.W, G.H = VW, VH
    try:
        t = G.Toon()
        fn = OBJECTS[name]
        fn(Box(t, d, fn.h))
        ink = t.finish(outline=2 if d == 1 else 1)
        ink = t.cells(ink, pal, top=0)
    finally:
        G.W, G.H = keep
    # one ink per cell: the commonest non-black ink wins, the rest go to black
    out = ink.copy()
    for cy in range(0, VH, 8):
        for cx in range(0, VW, 8):
            blk = out[cy:cy + 8, cx:cx + 8]
            lit = blk[blk > 0]
            if len(lit) == 0:
                continue
            vals, counts = np.unique(lit, return_counts=True)
            if len(vals) > 1:
                main = vals[counts.argmax()]
                blk[(blk > 0) & (blk != main)] = 0
    if d == 3:
        m = out > 0
        out[m] = np.vectorize(DARK.get)(out[m])
    return out


if __name__ == '__main__':
    import sys
    from PIL import Image
    sys.path.insert(0, __import__('os').path.dirname(__file__))
    import native_art as NA
    names = sys.argv[1:] or list(OBJECTS)
    S = Image.new('RGB', (len(names) * 70, 110), (60, 60, 72))
    for i, n in enumerate(names):
        ink = object_image(n, 1, NA.HW)
        ys, xs = np.nonzero(ink >= 0)
        crop = ink[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        rgb = np.zeros(crop.shape + (3,), np.uint8)
        rgb[:] = (60, 60, 72)
        m = crop >= 0
        rgb[m] = NA.HW[crop[m]]
        S.paste(Image.fromarray(rgb), (i * 70, 0))
    S.resize((S.width * 2, S.height * 2), Image.NEAREST).save('/home/claude/dc2mb/shots/rev/objs.png')
