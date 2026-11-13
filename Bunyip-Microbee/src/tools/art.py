#!/usr/bin/env python3
"""art.py - sprite masters and the title logo for BUNYIP
VIBED BY BPM 2026

Every sprite is a small 1-bit picture with a mask: transparent, ink (drawn in
the creature's colour) or black (opaque).  Each is drawn here with simple
shapes, then given a one-pixel black outline so it stands out from walls.

The game shrinks every master to 16 sizes at start-up (src/prescale.asm);
this file also works out, for each size, the width and which source column
each output dot comes from, so the Z80 only copies bits.

  build/ART.BIN    RAM block 3
  build/artsym.inc image numbers and the directory layout
  build/art_*.png  previews
"""
import math, sys
from pathlib import Path
from PIL import Image, ImageDraw

T, K, I = 0, 1, 2          # transparent, black, ink
NS = 16
HS = [round(8 * 1.2 ** s) for s in range(NS)]     # heights of the 16 sizes (scanlines)
ASPECT = 0.75              # dots per scanline for a square shape


def canvas(w, h):
    return [[T] * w for _ in range(h)]


def from_draw(w, h, fn, ss=4):
    """draw at ss x size with PIL: fill 255 = ink, 128 = black; downsample"""
    im = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(im)
    fn(d, ss)
    c = canvas(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            ink = blk = 0
            for yy in range(ss):
                for xx in range(ss):
                    v = px[x * ss + xx, y * ss + yy]
                    if v >= 200:
                        ink += 1
                    elif v >= 64:
                        blk += 1
            n = ss * ss
            if ink * 2 >= n:
                c[y][x] = I
            elif (ink + blk) * 2 >= n:
                c[y][x] = K
    return c


def outline(c):
    h, w = len(c), len(c[0])
    o = [r[:] for r in c]
    for y in range(h):
        for x in range(w):
            if c[y][x] == T:
                for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and c[yy][xx] == I:
                        o[y][x] = K
                        break
    return o


def dither(c, box, every=2, phase=0, val=K):
    """turn ink in box to a checker of ink and val (shading)"""
    x0, y0, x1, y1 = box
    for y in range(max(0, y0), min(len(c), y1)):
        for x in range(max(0, x0), min(len(c[0]), x1)):
            if c[y][x] == I and (x + y + phase) % every == 0:
                c[y][x] = val


def S(v, ss):
    return [p * ss for p in v] if isinstance(v, (list, tuple)) else v * ss


# ------------------------------------------------------------------ creatures
def redback(frame):
    W, H = 32, 22

    def fn(d, ss):
        # legs: four each side, knees up, feet down
        for i in range(4):
            sw = 2 if (i + frame) % 2 else -1
            for side in (-1, 1):
                hx, hy = 16 + side * 3, 11 + i * 1.2
                kx, ky = 16 + side * (8 + i * 1.5), 3 + i * 2 + sw
                fx, fy = 16 + side * (12 + i * 1.2), 21 - abs(i - 1.5) * 1.5 + (sw if i % 2 else 0) * 0.5
                d.line(S([hx, hy, kx, ky], ss), fill=255, width=int(1.4 * ss))
                d.line(S([kx, ky, fx, fy], ss), fill=255, width=int(1.2 * ss))
        # abdomen behind, head in front
        d.ellipse(S([8.5, 3, 23.5, 15], ss), fill=255)
        d.ellipse(S([11.5, 10, 20.5, 18.5], ss), fill=255)
    c = from_draw(W, H, fn)
    dither(c, (8, 3, 24, 11))                  # dark abdomen ...
    for y, (a, b) in enumerate([(15, 17), (14, 18), (15, 17), (15, 17), (14, 18), (15, 17)]):
        for x in range(a, b):                   # ... with the bright hourglass
            c[4 + y][x] = I
    for x, y in ((13, 13), (18, 13), (14, 12), (17, 12)):
        c[y][x] = K                             # eyes
    for x in range(14, 18):
        c[16][x] = K                            # fangs line
    return outline(c)


def flyingfox(frame):
    W, H = 32, 22

    def fn(d, ss):
        if frame == 0:      # wings up and out
            wing = [(16, 9), (9, 2), (3, 5), (0, 12), (4, 10), (7, 14), (11, 11), (14, 15)]
        else:               # wings down
            wing = [(16, 9), (10, 11), (4, 13), (1, 20), (5, 17), (8, 20), (11, 16), (14, 17)]
        d.polygon([S(p, ss) for p in wing], fill=255)
        d.polygon([S((32 - x, y), ss) for x, y in wing], fill=255)
        d.ellipse(S([12.5, 6, 19.5, 18], ss), fill=255)        # body
        d.ellipse(S([12.5, 3, 19.5, 9.5], ss), fill=255)       # head
        d.polygon([S(p, ss) for p in ((12.5, 5), (13, 0.5), (15, 4))], fill=255)   # ears
        d.polygon([S(p, ss) for p in ((19.5, 5), (19, 0.5), (17, 4))], fill=255)
    c = from_draw(W, H, fn)
    for y in range(H):                          # wing membranes shaded, bones bright
        for x in range(W):
            if c[y][x] == I and not 12 <= x <= 19 and (x + y) % 2 == 0 and x % 5 != 2:
                c[y][x] = K
    for x, y in ((14, 6), (17, 6)):
        c[y][x] = K                             # eyes
    return outline(c)


def yowie(frame):
    W, H = 24, 32

    def fn(d, ss):
        d.ellipse(S([8.5, 1, 15.5, 8], ss), fill=255)          # head
        d.polygon([S(p, ss) for p in ((5, 9), (19, 9), (21, 20), (17, 22), (7, 22), (3, 20))], fill=255)  # torso
        d.rectangle(S([7, 21, 11, 31], ss), fill=255)          # legs
        d.rectangle(S([13, 21, 17, 31], ss), fill=255)
        d.ellipse(S([5, 29, 11.5, 32], ss), fill=255)           # feet
        d.ellipse(S([12.5, 29, 19, 32], ss), fill=255)
        d.line(S([5, 10, 2, 24], ss), fill=255, width=3 * ss)    # left arm
        if frame == 0:
            d.line(S([19, 10, 22, 24], ss), fill=255, width=3 * ss)
            d.ellipse(S([20, 22, 24, 26], ss), fill=255)
        else:                                                   # right arm up with a rock
            d.line(S([19, 10, 22, 1], ss), fill=255, width=3 * ss)
            d.ellipse(S([19, -1, 24, 4], ss), fill=128)
        d.ellipse(S([0, 22, 4, 26], ss), fill=255)
    c = from_draw(W, H, fn)
    import random
    rnd = random.Random(7)
    for y in range(9, H):                        # shaggy fur
        for x in range(W):
            if c[y][x] == I and rnd.random() < 0.18:
                c[y][x] = K
    for x, y in ((10, 4), (13, 4)):
        c[y][x] = K                              # eyes
    for x in range(10, 14):
        c[6][x] = K                              # mouth
    return outline(c)


def bunyip(frame):
    W, H = 40, 32

    def fn(d, ss):
        d.ellipse(S([3, 10, 37, 31], ss), fill=255)             # body
        d.ellipse(S([1, 26, 11, 32], ss), fill=255)             # flippers
        d.ellipse(S([29, 26, 39, 32], ss), fill=255)
        d.ellipse(S([10, 1, 30, 20], ss), fill=255)             # head
        d.polygon([S(p, ss) for p in ((11, 6), (6, 0), (14, 3))], fill=255)    # ears
        d.polygon([S(p, ss) for p in ((29, 6), (34, 0), (26, 3))], fill=255)
        if frame == 1:
            d.ellipse(S([14, 12, 26, 20], ss), fill=128)        # mouth open
    c = from_draw(W, H, fn)
    dither(c, (0, 21, 40, 32), every=2)          # dark belly
    for y in range(11, 21):
        for x in range(3, 37):
            if c[y][x] == I and (x * 3 + y * 5) % 7 == 0:
                c[y][x] = K                      # mottled hide
    for ex in (15, 24):                          # glowing eyes in dark sockets
        for y in range(6, 10):
            for x in range(ex - 2, ex + 3):
                c[y][x] = K
        c[7][ex] = c[8][ex] = I
        c[7][ex + 1] = I
    for tx in (16, 23):                          # tusks
        for y in range(13, 18 if frame else 16):
            c[y][tx] = I
            c[y][tx + 1] = I
    if frame == 1:
        for x in range(15, 26, 2):
            c[13][x] = I                         # teeth
    return outline(c)


# ------------------------------------------------------------------ items
def key(frame):
    c = from_draw(16, 16, lambda d, ss: (
        d.ellipse(S([1, 1, 9, 9], ss), fill=255),
        d.ellipse(S([3.5, 3.5, 6.5, 6.5], ss), fill=0),
        d.line(S([7, 7, 14, 14], ss), fill=255, width=2 * ss),
        d.line(S([10, 13, 12, 11], ss), fill=255, width=2 * ss),
        d.line(S([12, 15, 14.5, 12.5], ss), fill=255, width=2 * ss)))
    return outline(c)


def pie(frame):
    def fn(d, ss):
        d.ellipse(S([0, 5, 16, 15], ss), fill=255)
        d.ellipse(S([1, 3, 15, 11], ss), fill=255)
    c = from_draw(16, 16, fn)
    dither(c, (0, 4, 16, 9), every=3)           # flaky top
    for x in range(1, 15):
        if c[11][x] == I:
            c[11][x] = K                         # crust line
    for x, y in ((6, 6), (8, 5), (10, 6)):
        c[y][x] = K                              # steam holes
    return outline(c)


def charges(frame):
    def fn(d, ss):
        for i, x in enumerate((2, 6.5, 11)):
            top = 2 if i == 1 else 4
            d.polygon([S(p, ss) for p in ((x, top + 3), (x + 1.5, top), (x + 3, top + 3), (x + 3, 15), (x, 15))], fill=255)
    c = from_draw(16, 16, fn)
    for y in range(9, 16, 2):
        for x in range(16):
            if c[y][x] == I:
                c[y][x] = K                      # bands
    return outline(c)


def opal(frame):
    def fn(d, ss):
        d.polygon([S(p, ss) for p in ((8, 1), (15, 7), (8, 15), (1, 7))], fill=255)
    c = from_draw(16, 16, fn)
    dither(c, (0, 8, 16, 16), every=2)           # facets
    for x, y in ((6, 4), (5, 5), (7, 5), (6, 6)):
        if c[y][x] != T:
            c[y][x] = K
    c[5][6] = I                                   # sparkle
    return outline(c)


def rock(frame):
    c = from_draw(16, 16, lambda d, ss: d.ellipse(S([3, 3, 13, 13], ss), fill=255))
    dither(c, (0, 8, 16, 16), every=2)
    return outline(c)


def fireball(frame):
    def fn(d, ss):
        d.ellipse(S([2, 4, 14, 16], ss), fill=255)
        d.polygon([S(p, ss) for p in ((3, 9), (5, 0), (8, 6), (10, 1), (13, 9))], fill=255)
    c = from_draw(16, 16, fn)
    for y in range(16):
        for x in range(16):
            if c[y][x] == I and 6 <= x <= 9 and 8 <= y <= 12:
                c[y][x] = K                      # hot core (shown dark against the ink)
    return outline(c)


def weapon(frame):
    """the player's opal zapper, seen from behind, bottom centre of the view"""
    W, H = 32, 24

    def fn(d, ss):
        d.polygon([S(p, ss) for p in ((11, 24), (13, 9), (19, 9), (21, 24))], fill=255)   # barrel
        d.rectangle(S([12, 6, 20, 10], ss), fill=255)                                     # muzzle
        d.ellipse(S([6, 16, 26, 26], ss), fill=255)                                       # hands
        if frame:
            d.polygon([S(p, ss) for p in ((16, 0), (18.5, 4), (24, 3), (20, 7), (12, 7), (8, 3), (13.5, 4))], fill=255)
    c = from_draw(W, H, fn)
    for y in range(16, H):
        for x in range(W):
            if c[y][x] == I and (x + y) % 2:
                c[y][x] = K                      # gloves darker
    for y in range(10, 16):
        c[y][16] = K                             # barrel line
    c[7][16] = K if not frame else I
    return outline(c)


# ------------------------------------------------------------------ more creatures
def canetoad(frame):
    W, H = 32, 20

    def fn(d, ss):
        if frame == 0:      # squatting
            d.ellipse(S([4, 6, 28, 19], ss), fill=255)              # body
            d.ellipse(S([1, 14, 9, 20], ss), fill=255)              # back feet
            d.ellipse(S([23, 14, 31, 20], ss), fill=255)
        else:               # mid-hop: body up, legs stretched below
            d.ellipse(S([5, 2, 27, 14], ss), fill=255)
            d.line(S([9, 12, 4, 19], ss), fill=255, width=2 * ss)
            d.line(S([23, 12, 28, 19], ss), fill=255, width=2 * ss)
            d.ellipse(S([1, 17, 8, 20], ss), fill=255)
            d.ellipse(S([24, 17, 31, 20], ss), fill=255)
        top = 4 if frame == 0 else 0
        d.ellipse(S([7, top, 14, top + 7], ss), fill=255)          # bulging eyes
        d.ellipse(S([18, top, 25, top + 7], ss), fill=255)
    c = from_draw(W, H, fn)
    import random
    rnd = random.Random(3)
    for y in range(H):                           # warts
        for x in range(W):
            if c[y][x] == I and rnd.random() < 0.16:
                c[y][x] = K
    top = 4 if frame == 0 else 0
    for ex in (10, 21):                          # dark pupils with a glint
        for y in range(top + 2, top + 5):
            for x in range(ex - 1, ex + 2):
                c[y][x] = K
        c[top + 3][ex] = I
    my = 13 if frame == 0 else 9                 # wide mouth
    for x in range(9, 23):
        c[my][x] = K
    return outline(c)


def dropbear(frame):
    W, H = 32, 32

    def fn(d, ss):
        d.ellipse(S([0, 0, 10, 10], ss), fill=255)               # big round ears
        d.ellipse(S([22, 0, 32, 10], ss), fill=255)
        d.ellipse(S([6, 2, 26, 18], ss), fill=255)               # head
        d.ellipse(S([7, 14, 25, 31], ss), fill=255)              # body
        if frame == 0:                                          # arms out, claws spread
            d.line(S([8, 18, 1, 24], ss), fill=255, width=3 * ss)
            d.line(S([24, 18, 31, 24], ss), fill=255, width=3 * ss)
        else:                                                   # arms up, pouncing
            d.line(S([8, 17, 2, 9], ss), fill=255, width=3 * ss)
            d.line(S([24, 17, 30, 9], ss), fill=255, width=3 * ss)
    c = from_draw(W, H, fn)
    dither(c, (1, 1, 9, 9), every=2)             # fluffy ear insides
    dither(c, (23, 1, 31, 9), every=2)
    dither(c, (8, 22, 24, 31), every=3)          # belly fur
    for y in range(9, 14):                       # the big dark nose
        for x in range(14, 18):
            c[y][x] = K
    for x, y in ((11, 7), (12, 7), (20, 7), (21, 7)):
        c[y][x] = K                              # mean little eyes
    for x in (14, 17):                           # fangs
        c[15][x] = c[16][x] = I
    for x in range(13, 19):
        c[14][x] = K
    if frame == 0:
        claws = [(0, 25), (1, 26), (31, 25), (30, 26)]
    else:
        claws = [(1, 7), (3, 7), (30, 7), (28, 7)]
    for x, y in claws:
        if 0 <= y < H:
            c[y][x] = I
    return outline(c)


def minmin(frame):
    W, H = 24, 24

    def fn(d, ss):
        d.ellipse(S([7, 7, 17, 17], ss), fill=255)              # the glowing heart
        import math as m
        for i in range(8):                                     # rays, turning
            a = (i / 8 + frame / 16) * 2 * m.pi
            r0, r1 = 7, 11.5 if i % 2 == 0 else 9.5
            d.line(S([12 + r0 * m.cos(a), 12 + r0 * m.sin(a), 12 + r1 * m.cos(a), 12 + r1 * m.sin(a)], ss),
                   fill=255, width=int(1.6 * ss))
    c = from_draw(W, H, fn)
    for y in range(9, 15):                       # a dark ring inside the glow
        for x in range(9, 15):
            r = (x - 11.5) ** 2 + (y - 11.5) ** 2
            if 4.5 < r < 8 and c[y][x] == I:
                c[y][x] = K
    return outline(c)


def croc(frame):
    W, H = 40, 24

    def fn(d, ss):
        d.ellipse(S([2, 10, 38, 24], ss), fill=255)              # the body behind
        if frame == 0:                                          # jaws a little open
            d.polygon([S(p, ss) for p in ((8, 8), (32, 8), (28, 14), (12, 14))], fill=255)
            d.polygon([S(p, ss) for p in ((9, 15), (31, 15), (28, 21), (12, 21))], fill=255)
        else:                                                   # jaws gaping
            d.polygon([S(p, ss) for p in ((6, 4), (34, 4), (29, 11), (11, 11))], fill=255)
            d.polygon([S(p, ss) for p in ((9, 16), (31, 16), (28, 23), (12, 23))], fill=255)
        d.ellipse(S([10, 3, 17, 10], ss), fill=255)              # eye bumps
        d.ellipse(S([23, 3, 30, 10], ss), fill=255)
    c = from_draw(W, H, fn)
    gap = (14, 15) if frame == 0 else (11, 16)
    for y in range(gap[0], gap[1]):              # the dark mouth
        for x in range(11, 29):
            if c[y][x] != T:
                c[y][x] = K
    for x in range(12, 28, 3):                   # teeth along both jaws
        c[gap[0]][x] = I
        c[gap[1] - 1][x + 1] = I
    for ex in (13, 26):                          # slit eyes
        c[5][ex] = c[6][ex] = K
    for y in range(17, H):                       # scaly sides
        for x in range(W):
            if c[y][x] == I and (x // 2 + y) % 3 == 0:
                c[y][x] = K
    return outline(c)


# ------------------------------------------------------------------ effects and power
def puff(frame):
    W, H = 32, 24

    def fn(d, ss):
        if frame == 0:      # a tight burst
            for cx, cy, r in ((16, 13, 7), (10, 15, 4.5), (22, 15, 4.5), (16, 8, 4.5)):
                d.ellipse(S([cx - r, cy - r, cx + r, cy + r], ss), fill=255)
            for a in range(0, 360, 45):
                x, y = 16 + 14 * math.cos(math.radians(a)), 13 + 10 * math.sin(math.radians(a))
                d.ellipse(S([x - 1.2, y - 1.2, x + 1.2, y + 1.2], ss), fill=255)
        else:               # drifting wisps
            for cx, cy, r in ((9, 9, 5), (22, 7, 4), (16, 16, 6), (5, 18, 3), (27, 17, 3.5)):
                d.ellipse(S([cx - r, cy - r, cx + r, cy + r], ss), fill=255)
                d.ellipse(S([cx - r + 2, cy - r + 2, cx + r - 2, cy + r - 2], ss), fill=0)
    c = from_draw(W, H, fn)
    if frame == 0:
        dither(c, (0, 0, 32, 24), every=3)
    return outline(c)


def power(frame):
    """the Southern Cross: five stars in a ring of light"""
    W, H = 16, 16

    def fn(d, ss):
        d.ellipse(S([0.5, 0.5, 15.5, 15.5], ss), fill=255)
        d.ellipse(S([2.5, 2.5, 13.5, 13.5], ss), fill=128)
        for x, y, r in ((8, 4, 1.6), (8, 12, 1.8), (4.5, 8, 1.4), (11.5, 7, 1.5), (10, 10, 0.9)):
            d.ellipse(S([x - r, y - r, x + r, y + r], ss), fill=255)
    return outline(from_draw(W, H, fn))


# ------------------------------------------------------------------ scenery
def urn(frame):
    def fn(d, ss):
        d.rectangle(S([10, 0, 22, 3], ss), fill=255)             # lip
        d.polygon([S(p, ss) for p in ((12, 3), (20, 3), (21, 7), (11, 7))], fill=255)   # neck
        d.ellipse(S([3, 6, 29, 30], ss), fill=255)               # belly
        d.rectangle(S([10, 28, 22, 32], ss), fill=255)           # foot
        d.line(S([4, 10, 1, 16], ss), fill=255, width=2 * ss)    # handles
        d.line(S([28, 10, 31, 16], ss), fill=255, width=2 * ss)
    c = from_draw(32, 32, fn)
    for y in (12, 13, 22, 23):                   # painted bands
        for x in range(32):
            if c[y][x] == I:
                c[y][x] = K
    for y in range(15, 21):                      # a zigzag between them
        for x in range(4, 28):
            if c[y][x] == I and (x + (y - 15) * 2) % 6 == 0:
                c[y][x] = K
    dither(c, (18, 6, 29, 30), every=2)          # shadowed side
    return outline(c)


def brazier(frame):
    def fn(d, ss):
        d.polygon([S(p, ss) for p in ((4, 12), (20, 12), (17, 19), (7, 19))], fill=255)   # bowl
        d.rectangle(S([10, 19, 14, 31], ss), fill=255)           # stem
        d.rectangle(S([6, 29, 18, 32], ss), fill=255)            # foot
        if frame == 0:
            fl = ((5, 12), (7, 4), (9, 8), (12, 0), (15, 7), (17, 3), (19, 12))
        else:
            fl = ((5, 12), (6, 6), (9, 9), (11, 2), (14, 8), (18, 1), (19, 12))
        d.polygon([S(p, ss) for p in fl], fill=255)
    c = from_draw(24, 32, fn)
    for y in range(12, 19):                      # the bowl dark, the flames bright
        for x in range(24):
            if c[y][x] == I and (x + y) % 2:
                c[y][x] = K
    for x in range(4, 21):
        if c[12][x] == I:
            c[12][x] = K
    return outline(c)


def stump(frame):
    def fn(d, ss):
        d.rectangle(S([7, 8, 25, 28], ss), fill=255)
        d.ellipse(S([7, 4, 25, 12], ss), fill=255)               # cut top
        for p in (((7, 24), (0, 32), (9, 30)), ((25, 24), (32, 32), (23, 30)),
                  ((12, 27), (11, 32), (17, 30)), ((19, 27), (22, 32), (16, 30))):
            d.polygon([S(q, ss) for q in p], fill=255)          # roots
    c = from_draw(32, 32, fn)
    for x in range(8, 25):                       # rings on the cut top
        c[8][x] = K if x % 3 else c[8][x]
    for y in range(12, 27):                      # bark
        for x in range(8, 25):
            if c[y][x] == I and x % 4 == (y // 5) % 4:
                c[y][x] = K
    return outline(c)


def shroom(frame):
    def fn(d, ss):
        for cx, cy, r, sh in ((8, 18, 7, 6), (22, 12, 9, 8), (27, 24, 4, 4)):
            d.rectangle(S([cx - 1.5, cy, cx + 1.5, 32], ss), fill=255)   # stalk
            d.pieslice(S([cx - r, cy - sh, cx + r, cy + sh], ss), 180, 360, fill=255)  # cap
    c = from_draw(32, 32, fn)
    for x, y in ((6, 15), (10, 16), (19, 8), (24, 6), (22, 10), (27, 22)):
        c[y][x] = K                              # spots
    return outline(c)


def antnest(frame):
    def fn(d, ss):
        d.polygon([S(p, ss) for p in ((1, 32), (8, 12), (13, 4), (19, 2), (24, 10), (31, 32))], fill=255)
    c = from_draw(32, 32, fn)
    import random
    rnd = random.Random(11)
    for y in range(32):                          # gritty mound with holes
        for x in range(32):
            if c[y][x] == I and rnd.random() < 0.2:
                c[y][x] = K
    for hx, hy in ((14, 12), (19, 20), (10, 24)):
        for y in range(hy, hy + 2):
            for x in range(hx, hx + 3):
                c[y][x] = K
    for x, y in ((5, 30), (25, 29), (16, 31), (28, 25)):
        c[y][x] = I                              # ants about
    return outline(c)


def cart(frame):
    def fn(d, ss):
        d.polygon([S(p, ss) for p in ((0, 6), (32, 6), (29, 22), (3, 22))], fill=255)   # tub
        d.ellipse(S([3, 18, 12, 27], ss), fill=255)              # wheels
        d.ellipse(S([20, 18, 29, 27], ss), fill=255)
        d.rectangle(S([0, 30, 32, 32], ss), fill=255)            # rails
        d.polygon([S(p, ss) for p in ((4, 6), (9, 1), (14, 4), (19, 0), (25, 3), (29, 6))], fill=255)  # ore
    c = from_draw(32, 32, fn)
    for y in (10, 16):                           # riveted bands
        for x in range(32):
            if c[y][x] == I:
                c[y][x] = K
    for y in range(0, 7):                        # the ore heap speckled
        for x in range(32):
            if c[y][x] == I and (x * 7 + y * 3) % 4 == 0:
                c[y][x] = K
    for cx in (7, 24):                           # hubs
        c[22][cx] = c[22][cx + 1] = K
    return outline(c)


def lantern(frame):
    def fn(d, ss):
        d.line(S([8, 0, 8, 4], ss), fill=255, width=ss)         # the hook
        d.rectangle(S([4, 4, 12, 6], ss), fill=255)
        d.polygon([S(p, ss) for p in ((3, 6), (13, 6), (14, 19), (2, 19))], fill=255)
        d.rectangle(S([3, 19, 13, 22], ss), fill=255)
    c = from_draw(16, 24, fn)
    for y in range(7, 19):                       # the frame bars
        for x in (2, 3, 8, 12, 13):
            if c[y][x] == I:
                c[y][x] = K
    for x in range(2, 15):
        c[12][x] = K if c[12][x] == I else c[12][x]
    return outline(c)


def tnt(frame):
    def fn(d, ss):
        d.rectangle(S([1, 8, 31, 32], ss), fill=255)
        d.line(S([16, 8, 18, 2], ss), fill=255, width=ss)       # fuse
        d.ellipse(S([16, 0, 21, 4], ss), fill=255)
    c = from_draw(32, 32, fn)
    for y in (12, 28):
        for x in range(1, 31):
            c[y][x] = K                          # planks
    # the letters TNT, 3 x 5 each, in black on the crate
    L = {'T': ['###', '.#.', '.#.', '.#.', '.#.'], 'N': ['#..#', '##.#', '#.##', '#..#', '#..#']}
    x0 = 5
    for ch in 'TNT':
        for r, row in enumerate(L[ch]):
            for k, v in enumerate(row):
                if v == '#':
                    for yy in range(2):
                        for xx in range(2):
                            c[15 + r * 2 + yy][x0 + k * 2 + xx] = K
        x0 += len(L[ch][0]) * 2 + 1
    return outline(c)


def bones(frame):
    def fn(d, ss):
        d.ellipse(S([2, 2, 14, 12], ss), fill=255)               # skull
        d.rectangle(S([5, 10, 11, 15], ss), fill=255)
        for a, b in (((16, 13), (30, 7)), ((17, 6), (29, 14)), ((3, 15), (15, 15))):
            d.line(S([*a, *b], ss), fill=255, width=2 * ss)     # crossed bones
            for p in (a, b):
                d.ellipse(S([p[0] - 1.8, p[1] - 1.8, p[0] + 1.8, p[1] + 1.8], ss), fill=255)
    c = from_draw(32, 16, fn)
    for x, y in ((5, 6), (6, 6), (5, 7), (6, 7), (10, 6), (11, 6), (10, 7), (11, 7)):
        c[y][x] = K                              # eye holes
    for x in (6, 8, 10):
        c[12][x] = K                             # teeth
    return outline(c)


def reeds(frame):
    def fn(d, ss):
        for x0, top, lean in ((4, 6, -2), (9, 0, 1), (14, 4, -1), (19, 2, 2), (24, 7, 1), (28, 10, -2)):
            d.line(S([x0, 32, x0 + lean, top], ss), fill=255, width=int(1.3 * ss))
        for x0, top, lean in ((9, 0, 1), (19, 2, 2)):
            d.ellipse(S([x0 + lean - 1.6, top, x0 + lean + 1.6, top + 7], ss), fill=255)   # bulrush heads
    c = from_draw(32, 32, fn)
    return outline(c)


def tar(frame):
    def fn(d, ss):
        d.ellipse(S([0, 2, 32, 16], ss), fill=255)
        d.ellipse(S([10, 0, 15, 5], ss), fill=255)               # a bubble
    c = from_draw(32, 16, fn)
    dither(c, (0, 4, 32, 16), every=2)
    for x, y in ((12, 2), (6, 9), (22, 7), (18, 12)):
        c[y][x] = K
    return outline(c)


IMAGES = [   # name, function, frame
    ('KEY', key, 0), ('PIE', pie, 0), ('CHARGES', charges, 0), ('OPAL', opal, 0),
    ('ROCK', rock, 0), ('FIRE', fireball, 0), ('POWER', power, 0), ('PUFF_A', puff, 0), ('PUFF_B', puff, 1),
    ('RB_A', redback, 0), ('RB_B', redback, 1), ('FF_A', flyingfox, 0), ('FF_B', flyingfox, 1),
    ('YW_A', yowie, 0), ('YW_B', yowie, 1), ('BN_A', bunyip, 0), ('BN_B', bunyip, 1),
    ('CT_A', canetoad, 0), ('CT_B', canetoad, 1), ('DB_A', dropbear, 0), ('DB_B', dropbear, 1),
    ('MM_A', minmin, 0), ('MM_B', minmin, 1), ('CR_A', croc, 0), ('CR_B', croc, 1),
    ('URN', urn, 0), ('BRAZ_A', brazier, 0), ('BRAZ_B', brazier, 1), ('STUMP', stump, 0),
    ('SHROOM', shroom, 0), ('NEST', antnest, 0), ('CART', cart, 0), ('LANTERN', lantern, 0),
    ('TNT', tnt, 0), ('BONES', bones, 0), ('REEDS', reeds, 0), ('TAR', tar, 0),
]
MAXIMG = 48
WEAPON_H = 30          # the zapper's glyphs (gen.py) are drawn at this height
DIRBASE = 0x5000       # the sprite directory, in RAM block 4 after the glyphs
BLK_SPR = 6            # sprite blocks 6..31


def sizes_for(name, W0, H0):
    """widths in dots of the 16 sizes"""
    return [max(1, round(W0 * h / H0 * ASPECT)) for h in HS]


def layout(widths, colsz):
    """per size: (shares the size before?, unshifted base, bytes, shifted base) relative
    to the image's start; returns them and the bytes used.  The shifted copy is one
    byte wider.  Columns are whole column sizes, so a row is base + 2 * row."""
    out, cur = [], 0
    for s, w in enumerate(widths):
        bw = (w + 7) // 8
        if s and w == widths[s - 1]:
            out.append((1,) + out[-1][1:])
            continue
        b0 = cur
        cur += bw * colsz
        b1 = cur
        cur += (bw + 1) * colsz
        out.append((0, b0, bw, b1))
    return out, cur


def build(out):
    """ART.BIN layout (block 3)
       0000  directory, up to 48 images x 8 bytes:
             master offset (w), W0 bytes per row, H0 rows, spare (w),
             column size shift (6 = 64-byte columns, 7 = 128), spare
       0180  widths: 48 images x 16 sizes (bytes, dots)
       0480  masters: H0 rows of [mask bytes][data bytes]
       The Z80 makes each size's column map itself (which source column each
       output dot comes from).

       The sprite directory (image x size x 8 bytes: block, unshifted base,
       bytes, shifted base, column shift, shares-the-size-before) is worked
       out here and goes into PCG.BIN at DIRBASE (block 4).
    """
    assert len(IMAGES) <= MAXIMG
    blob = bytearray(0x480)
    previews = []
    dirb = bytearray()
    blk, used = BLK_SPR, 0
    for i, (name, fn, fr) in enumerate(IMAGES):
        c = fn(fr)
        H0, W0 = len(c), len(c[0])
        assert W0 % 8 == 0 and H0 <= 64 and W0 <= 64, name
        nb = W0 // 8
        off = len(blob)
        for y in range(H0):
            m = [0] * nb
            d = [0] * nb
            for x in range(W0):
                if c[y][x] != T:
                    m[x >> 3] |= 0x80 >> (x & 7)
                if c[y][x] == I:
                    d[x >> 3] |= 0x80 >> (x & 7)
            blob += bytes(m) + bytes(d)
        ws = sizes_for(name, W0, H0)
        assert max(ws) <= 255
        blob[0x180 + i * 16:0x180 + i * 16 + 16] = bytes(ws)
        colsh = 6 if H0 <= 32 else 7
        blob[i * 8:i * 8 + 8] = off.to_bytes(2, 'little') + bytes([nb, H0, 0, 0, colsh, 0])
        lay, size = layout(ws, 1 << colsh)
        used = (used + (1 << colsh) - 1) & -(1 << colsh)
        if used + size > 0x8000:
            blk, used = blk + 1, 0
        assert blk <= 31, 'out of RAM blocks'
        for share, b0, bw, b1 in lay:
            dirb += bytes([blk]) + (used + b0).to_bytes(2, 'little') + bytes([bw]) + \
                (used + b1).to_bytes(2, 'little') + bytes([colsh, share])
        used += size
        previews.append((name, c))
    assert len(blob) <= 0x8000
    (out / 'ART.BIN').write_bytes(blob)
    pcg = (out / 'PCG.BIN').read_bytes()[:DIRBASE]
    assert len(pcg) == DIRBASE, 'gen.py must run first'
    (out / 'PCG.BIN').write_bytes(pcg + bytes(dirb))
    S = ['; generated by tools/art.py']
    for i, (name, _, _) in enumerate(IMAGES):
        S.append('IMG_%-8s equ %d' % (name, i))
    S.append('NIMAGES      equ %d' % len(IMAGES))
    S.append('NSIZES       equ %d' % NS)
    S.append('WEAPON_H     equ %d' % WEAPON_H)
    S.append('ARTDIR       equ 0')
    S.append('ARTW         equ 180h')
    S.append('SPRDIR       equ %04Xh' % DIRBASE)
    S.append('SPRBLK_LAST  equ %d' % blk)
    S.append('HSIZES:      db ' + ','.join(str(h) for h in HS))
    # h (scanlines, 0..255) / 2 -> nearest size
    hts = []
    for h2 in range(128):
        h = max(1, h2 * 2)
        s = min(range(NS), key=lambda k: abs(math.log(HS[k] / h)))
        hts.append(s)
    S.append('HTOS:')
    for i in range(0, 128, 32):
        S.append('        db ' + ','.join(str(v) for v in hts[i:i + 32]))
    (out / 'artsym.inc').write_text('\n'.join(S) + '\n')
    # previews
    cols = {T: (40, 40, 60), K: (0, 0, 0), I: (255, 200, 60)}
    per = 13
    rows = (len(previews) + per - 1) // per
    sheet = Image.new('RGB', (per * (40 * 4 + 8), rows * (32 * 4 + 8)), (40, 40, 60))
    for k, (name, c) in enumerate(previews):
        im = Image.new('RGB', (len(c[0]), len(c)))
        im.putdata([cols[v] for r in c for v in r])
        im = im.resize((len(c[0]) * 4, len(c) * 4), Image.NEAREST)
        sheet.paste(im, ((k % per) * (40 * 4 + 8), (k // per) * (32 * 4 + 8) + 4))
    sheet.save(out / 'art_sheet.png')
    print('ART.BIN: %d bytes, %d images, sprite blocks %d-%d' % (len(blob), len(IMAGES), BLK_SPR, blk))


# ------------------------------------------------------------------ title logo
LOGO_W, LOGO_H = 40, 15        # cells (rows 1..15 of the title screen)

BIG = {
 'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
 'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
 'N': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
 'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
 'I': ['###', '.#.', '.#.', '.#.', '.#.', '.#.', '###'],
 'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
}


def title_logo(CH):
    """The word BUNYIP in big bevelled block letters over a large Bunyip.
    Returns (glyphs, map): up to 384 unique 8 x CH glyphs, and per cell
    (code, bank) pairs for LOGO_W x LOGO_H cells."""
    W, H = LOGO_W * 8, LOGO_H * CH
    pix = [[0] * W for _ in range(H)]
    # letters: each font pixel is a 7 x 7 block with a bright top-left bevel
    word = 'BUNYIP'
    widths = [len(BIG[ch][0]) for ch in word]
    bw, bh = 7, 7
    total = sum(w * bw for w in widths) + (len(word) - 1) * bw
    x0 = (W - total) // 2
    y0 = 4
    x = x0
    for ch, w in zip(word, widths):
        for r, row in enumerate(BIG[ch]):
            for cidx, v in enumerate(row):
                if v != '#':
                    continue
                for yy in range(bh):
                    for xx in range(bw):
                        px, py = x + cidx * bw + xx, y0 + r * bh + yy
                        edge = yy == 0 or xx == 0
                        shade = yy >= bh - 2 or xx >= bw - 2
                        if edge:
                            on = 1
                        elif shade:
                            on = (px + py) % 2
                        else:
                            on = 1 if (px // 2 + py) % 4 else 0
                        pix[py][px] = on
        x += (w + 1) * bw
    # the Bunyip below, scaled up 2 x 2 (dots), centred
    c = bunyip(1)
    bx0 = (W - len(c[0]) * 2) // 2
    by0 = y0 + 7 * bh + 12
    for y, row in enumerate(c):
        for xx, v in enumerate(row):
            for dy in range(2):
                for dx in range(2):
                    py, px = by0 + y * 2 + dy, bx0 + xx * 2 + dx
                    if py < H:
                        pix[py][px] = 1 if v == I else 0
    glyphs, idx, cmap = [], {}, []
    for cy in range(LOGO_H):
        for cx in range(LOGO_W):
            g = tuple(sum(pix[cy * CH + y][cx * 8 + b] << (7 - b) for b in range(8)) for y in range(CH))
            if not any(g):
                cmap += [0, 255]          # blank: use a space
                continue
            if g not in idx:
                idx[g] = len(glyphs)
                glyphs.append(list(g))
            n = idx[g]
            cmap += [0x80 + (n & 127), 13 + (n >> 7)]
    assert len(glyphs) <= 384, len(glyphs)
    while len(glyphs) < 384:
        glyphs.append([0] * CH)
    return glyphs, cmap


if __name__ == '__main__':
    build(Path(sys.argv[1] if len(sys.argv) > 1 else 'build'))
