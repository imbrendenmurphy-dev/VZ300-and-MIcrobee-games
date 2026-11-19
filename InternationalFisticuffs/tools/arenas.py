#!/usr/bin/env python3
"""INTERNATIONAL FISTICUFFS! arena art: nine painted backdrops, 192 x 64,
four colours each, drawn in code.

The fighters carry an outline in the screen's background colour, so the
backdrops are free to use big fields of every colour.  House rules:
  * rows 10-16 never scroll (they show columns 32-159 whatever the camera
    does), so they hold only flat sky and small things that sit wholly inside
    them: a sun, a moon, clouds, stars.  That gives a little parallax.
  * dither patterns repeat every 2 pixels across, so they do not shimmer when
    the camera moves in its 2-pixel steps.
  * no ruled line across the whole stage where the wall meets the floor.
  * each builder takes the animation phase (0 or 1); only small things move.
"""
import math, random, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import worldtour as wt

SW = 192
FLOOR = 47                      # first floor row (fighters stand on row 58)


def on(x, y, lv):
    """ordered dither, 0 (none) to 4 (all), period 2 across"""
    if lv <= 0: return False
    if lv == 1: return x % 2 == 0 and y % 2 == 0
    if lv == 2: return (x + y) % 2 == 0
    if lv == 3: return not (x % 2 == 1 and y % 2 == 1)
    return True


class Art(wt.Pic):
    def dith(s, x0, y0, x1, y1, a, b, lv):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                s.put(x, y, b if on(x, y, lv) else a)

    def shade(s, x0, y0, x1, y1, b, lv, only=None):
        """dither colour b over what is there (optionally only over one colour)"""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if on(x, y, lv) and (only is None or s.get(x, y) == only):
                    s.put(x, y, b)

    def sky(s, bands):
        """bands: (y0, y1, colour a, colour b, level)"""
        for (y0, y1, a, b, lv) in bands:
            s.dith(0, y0, SW - 1, y1, a, b, lv)

    def disc(s, cx, cy, r, c, y0=0, y1=63):
        s.ellipse(cx, cy, r, r / 1.5, c, y0, y1)

    def tri(s, cx, top, base, hw, c, sh=None, lv=2, cap=None, capc=None):
        """a peak or pyramid: lit left face, dithered right face"""
        for y in range(top, base + 1):
            t = (y - top) / max(1, base - top)
            w = int(round(hw * t))
            for x in range(cx - w, cx + w + 1):
                col = c
                if sh is not None and x > cx + (y - top) * 0.15 and on(x, y, lv):
                    col = sh
                if cap is not None and y < top + cap + (1 if (x // 2) % 2 else 0):
                    col = capc
                s.put(x, y, col)

    def ridge(s, y0, amp, c, seed=1, base=46, f=(11.0, 4.3), sh=None, lv=1):
        for x in range(SW):
            y = y0 - amp * (0.6 * math.sin(x / f[0] + seed) + 0.4 * math.sin(x / f[1] + seed * 2))
            for yy in range(int(round(y)), base + 1):
                s.put(x, yy, sh if (sh is not None and on(x, yy, lv) and yy > y + 2) else c)

    def cloud(s, x, y, w, c):
        s.h(x, x + w, y + 1, c)
        s.h(x + 2, x + w - 2, y, c)
        s.h(x + w // 3, x + w // 3 + w // 3, y - 1, c)

    def stars(s, pts, c):
        for (x, y) in pts:
            s.put(x, y, c)

    def floor(s, a, b, kind, c=None, y0=FLOOR, cx=96):
        """a perspective ground plane: colour a, texture b"""
        vy = y0 - 9.0
        seams = [y0 + d for d in (0, 2, 5, 9, 14)]
        s.rect(0, y0, SW - 1, 63, a)
        for y in range(y0, 64):
            k = (y - vy) / (63 - vy)
            band = sum(1 for q in seams if y >= q)
            for x in range(SW):
                u = (x - cx) / k
                if kind == 'checker':
                    if (int(math.floor(u / 16.0)) + band) % 2 == 0:
                        s.put(x, y, b)
                elif kind == 'tiles':
                    if y in seams[2:] or abs(u / 20.0 - round(u / 20.0)) * 20.0 * k < 0.5:
                        s.put(x, y, b)
                elif kind == 'planks':
                    off = 9.0 if band % 2 else 0.0
                    if y in seams[1:] or abs((u + off) / 18.0 - round((u + off) / 18.0)) * 18.0 * k < 0.5:
                        s.put(x, y, b)
                elif kind == 'sand':
                    if y in seams[2:] and (x // 2 + band * 3) % 7 < 2:
                        s.put(x, y, b)
        if kind == 'sand':
            rnd = random.Random(7)
            for i in range(46):
                x, y = rnd.randrange(SW - 2), rnd.randrange(y0 + 1, 64)
                s.put(x, y, b); s.put(x + 1, y, b)
                if c is not None and i % 3 == 0:
                    s.put(x + 1, y + 1 if y < 63 else y, c)
        # a soft shadow where the wall meets the ground, instead of a ruled line
        if c is not None:
            for x in range(SW):
                if (x // 2) % 3 == 0 and s.get(x, y0 - 1) != c:
                    s.put(x, y0, c)

    def column(s, x, y0, y1, w, c, sh, capc=None):
        s.rect(x, y0, x + w - 1, y1, c)
        s.shade(x + w - 2, y0, x + w - 1, y1, sh, 2)
        if capc is not None:
            s.rect(x - 1, y0, x + w, y0 + 1, capc)
            s.rect(x - 1, y1 - 1, x + w, y1, capc)

    def palm(s, x, base, h, trunk, leaf):
        for i in range(h):
            s.put(x + int(round(math.sin(i / 5.0) * 1.5)), base - i, trunk)
            s.put(x + 1 + int(round(math.sin(i / 5.0) * 1.5)), base - i, trunk)
        tx, ty = x + int(round(math.sin(h / 5.0) * 1.5)), base - h
        for (dx, dy) in ((-7, 2), (-5, -1), (-2, -2), (3, -2), (6, -1), (8, 2)):
            s.line(tx, ty, tx + dx, ty + dy, leaf)
            s.line(tx, ty + 1, tx + dx, ty + dy + 1, leaf)

    def flag(s, x, y, c, ph, n=6, pole=None, plen=6):
        if pole is not None:
            s.v(x, y, y + plen, pole)
        for i in range(1, n + 1):
            dy = 1 if ((i + ph * 2) // 2) % 2 else 0
            s.put(x + i, y + dy, c); s.put(x + i, y + dy + 1, c)
            if i < n - 1:
                s.put(x + i, y + dy + 2, c)


def new(c):
    P = Art(SW)
    P.rect(0, 0, SW - 1, 63, c)
    return P


G, Y, B, R = 0, 1, 2, 3         # palette 0: green, yellow, blue, red
W, C, M, O = 0, 1, 2, 3         # palette 1: buff, cyan, magenta, orange


# ------------------------------------------------------------------ 1 AUSTRALIA
def station(ph=0):
    """NEVER NEVER STATION: the red centre at sundown"""
    P = new(B)
    P.sky([(10, 16, B, B, 0), (17, 21, B, R, 1), (22, 26, B, R, 2), (27, 31, R, B, 1), (32, 46, R, Y, 1)])
    P.cloud(44, 12, 16, Y); P.cloud(118, 14, 12, Y); P.cloud(84, 11, 9, R)
    P.disc(118, 40, 17, Y, 17, 46)                       # the sun going down
    for y in (33, 37, 41, 44):
        P.h(101, 135, y, R)
    # the great rock, with strata and a dithered shadow side
    for x in range(8, 92):
        t = (x - 8) / 84.0
        top = 30 - 9 * math.sin(math.pi * t) ** 0.6 + (1 if (x // 5) % 2 else 0)
        for y in range(int(top), 47):
            P.put(x, y, R)
    P.shade(52, 20, 92, 46, B, 2, only=R)
    for y in (27, 32, 38, 43):
        P.shade(8, y, 92, y, Y, 2, only=R)
    # scrub along the horizon
    for x in range(0, SW, 3):
        hh = 2 + (x * 7 % 4)
        P.v(x, 46 - hh, 46, G if x % 2 else B)
    # the homestead: tin roof, verandah, water tank
    P.rect(150, 30, 191, 46, Y)
    for x in range(150, 192, 3):
        P.v(x, 30, 46, R)
    P.poly([(146, 30), (191, 30), (191, 24), (154, 24)], B)
    for x in range(148, 192, 4):
        P.line(x + 4, 24, x, 30, Y)
    P.rect(160, 35, 168, 46, B); P.rect(174, 34, 184, 40, B); P.h(174, 184, 37, Y); P.v(179, 34, 40, Y)
    # the windmill turns
    cx, cy = 136, 21
    P.line(cx, cy, cx - 4, 46, Y); P.line(cx, cy, cx + 4, 46, Y); P.h(cx - 2, cx + 2, 34, Y); P.h(cx - 3, cx + 3, 41, Y)
    for a in ((0, 90, 180, 270) if ph == 0 else (45, 135, 225, 315)):
        r = math.radians(a)
        for t in (1, 2, 3, 4, 5):
            P.put(cx + int(round(math.cos(r) * t)), cy + int(round(math.sin(r) * t * 0.7)), Y)
    P.h(cx + 1, cx + 6, cy + (0 if ph else 1), R)
    # a ghost gum on the left edge
    P.line(4, 46, 7, 28, Y); P.line(5, 46, 8, 28, Y); P.line(7, 30, 14, 22, Y); P.line(7, 33, 1, 25, Y)
    for (x, y, r) in ((8, 21, 6), (15, 19, 5), (2, 22, 4)):
        P.ellipse(x, y, r, 3, G, 17, 30)
        P.shade(x - r, y, x + r, y + 3, B, 1, only=G)
    P.floor(Y, R, 'sand', B)
    return P


# ------------------------------------------------------------------ 2 USA
def mainst(ph=0):
    """MAIN STREET: a frontier town under the buttes"""
    P = new(B)
    P.sky([(10, 16, B, B, 0), (17, 24, B, Y, 1), (25, 30, B, Y, 2), (31, 46, Y, B, 1)])
    P.disc(60, 13, 4, Y, 10, 16)
    P.cloud(96, 12, 14, Y); P.cloud(132, 15, 10, Y)
    # buttes on the skyline
    for (x0, x1, top) in ((70, 96, 26), (100, 112, 30), (118, 150, 23)):
        P.poly([(x0 - 6, 46), (x0, top + 6), (x0 + 2, top), (x1 - 2, top), (x1, top + 6), (x1 + 6, 46)], R)
        P.shade((x0 + x1) // 2, top, x1 + 6, 46, B, 2, only=R)
        for y in range(top + 4, 46, 5):
            P.shade(x0 - 6, y, x1 + 6, y, Y, 2, only=R)
    # the saloon: false front, sign, swing doors, lit windows
    P.rect(4, 22, 62, 46, Y)
    for y in range(24, 46, 4):
        P.h(4, 62, y, R)
    P.rect(2, 19, 64, 22, R); P.poly([(20, 19), (46, 19), (40, 17), (26, 17)], R)
    P.rect(12, 24, 54, 31, B); P.text('SALOON', 22, 25, Y)
    P.rect(27, 34, 39, 46, B); P.rect(28, 38, 32, 44, R); P.rect(34, 38, 38, 44, R)
    for x0 in (8, 46):
        P.rect(x0, 34, x0 + 10, 43, B)
        P.rect(x0 + 1, 35, x0 + 9, 42, Y if (ph + x0) % 2 else R)
        P.v(x0 + 5, 35, 42, B); P.h(x0 + 1, x0 + 9, 38, B)
    P.shade(56, 22, 62, 46, B, 2)
    # the bank and the jail
    P.rect(150, 26, 191, 46, R)
    for y in range(28, 46, 3):
        P.shade(150, y, 191, y, Y, 2)
    P.rect(148, 23, 191, 26, Y); P.rect(156, 28, 184, 33, Y); P.text('BANK', 162, 28, R)
    P.rect(158, 36, 166, 46, B); P.rect(172, 36, 184, 42, B)
    for x in range(174, 184, 3):
        P.v(x, 36, 42, Y)
    P.flag(170, 17, R, ph, n=7, pole=Y, plen=6)
    # hitching rail, trough and a water tower
    P.h(70, 92, 41, Y); P.v(71, 41, 46, Y); P.v(91, 41, 46, Y); P.v(81, 41, 46, Y)
    P.rect(100, 42, 114, 46, R); P.h(100, 114, 42, Y)
    P.rect(126, 30, 138, 37, Y); P.shade(133, 30, 138, 37, R, 2); P.poly([(124, 30), (140, 30), (132, 26)], R)
    P.line(127, 37, 124, 46, Y); P.line(137, 37, 140, 46, Y); P.line(127, 40, 137, 44, Y)
    P.floor(Y, R, 'sand', B)
    # wagon ruts
    for (x0, x1) in ((30, 10), (160, 182)):
        P.line(96 + (x0 - 96) // 3, 48, x0, 63, R)
    return P


# ------------------------------------------------------------------ 3 GREECE
def oia(ph=0):
    """OIA CLIFFS: white houses above the caldera at sunset"""
    P = new(M)
    P.sky([(10, 16, M, M, 0), (17, 21, M, O, 1), (22, 26, M, O, 2), (27, 30, O, M, 1), (31, 33, O, O, 0)])
    P.disc(96, 13, 4, O, 10, 16)
    P.cloud(50, 12, 12, O); P.cloud(128, 14, 10, O)
    # the sea, with the sun's road on it
    P.rect(0, 34, SW - 1, 46, C)
    for i, y in enumerate(range(35, 46, 2)):
        w = 5 + i * 3 - (2 if (i + ph) % 2 else 0)
        P.h(96 - w, 96 + w, y, O)
        P.shade(0, y + 1, SW - 1, y + 1, M, 1, only=C)
    # an island on the horizon
    P.poly([(120, 34), (132, 29), (146, 31), (158, 34)], M)
    P.poly([(30, 34), (40, 31), (52, 34)], M)
    # the village, stepping down the cliff on the left
    def house(x, y, w, h, dome=False):
        P.rect(x, y, x + w, y + h, W)
        P.shade(x + w - 3, y, x + w, y + h, C, 2)
        P.rect(x + 2, y + h - 5, x + 4, y + h, M)
        P.rect(x + w - 7, y + 3, x + w - 5, y + 5, C)
        if dome:
            P.ellipse(x + w // 2, y, w // 2 - 1, 3, C, y - 4, y)
            P.v(x + w // 2, y - 6, y - 4, W); P.h(x + w // 2 - 1, x + w // 2 + 1, y - 5, W)
    house(0, 30, 16, 16); house(14, 24, 18, 22, True); house(30, 33, 14, 13); house(42, 27, 12, 19)
    house(150, 31, 14, 15); house(162, 24, 20, 22, True); house(180, 34, 12, 12)
    # a windmill on the far point
    P.rect(72, 28, 78, 34, W); P.poly([(71, 28), (79, 28), (75, 25)], M)
    for a in ((20, 110, 200, 290) if ph == 0 else (65, 155, 245, 335)):
        r = math.radians(a)
        P.line(75, 27, 75 + int(round(math.cos(r) * 5)), 27 + int(round(math.sin(r) * 3.5)), W)
    # the terrace wall, with pots of geraniums
    P.rect(0, 43, SW - 1, 46, W)
    P.shade(0, 45, SW - 1, 46, C, 2)
    for x in (58, 100, 138):
        P.rect(x, 40, x + 4, 43, O); P.h(x - 1, x + 5, 39, M); P.h(x, x + 4, 38, M)
    P.floor(C, W, 'tiles', M)
    return P


# ------------------------------------------------------------------ 4 JAPAN
def kyoto(ph=0):
    """SNOW TEMPLE: the mountain, the gate and the pagoda in winter"""
    P = new(M)
    P.sky([(10, 16, M, M, 0), (17, 21, M, W, 1), (22, 26, M, W, 2), (27, 31, W, M, 1), (32, 46, W, W, 0)])
    P.disc(132, 13, 4, O, 10, 16)
    P.cloud(60, 13, 12, W)
    # the mountain, snow-capped
    P.tri(96, 18, 46, 44, C, M, 1, cap=7, capc=W)
    for x in range(52, 141, 2):
        P.put(x, 46, C)
    # pines on the lower slopes
    for (x, h) in ((60, 9), (67, 7), (122, 8), (130, 10), (138, 7)):
        for i in range(h):
            P.h(x - i // 2, x + i // 2, 46 - h + i, M)
        P.put(x, 46 - h, W); P.h(x - 1, x + 1, 46 - h + 3, W)
    # the pagoda
    def tier(cx, y, w):
        P.poly([(cx - w, y + 3), (cx + w, y + 3), (cx + w - 3, y), (cx - w + 3, y)], M)
        P.h(cx - w + 2, cx + w - 2, y, C)
        P.put(cx - w - 1, y + 2, M); P.put(cx + w + 1, y + 2, M)
        P.rect(cx - w + 4, y + 4, cx + w - 4, y + 8, O)
        P.shade(cx + 2, y + 4, cx + w - 4, y + 8, M, 2)
        P.v(cx, y + 4, y + 8, M)
    tier(24, 17, 9); tier(24, 26, 11); tier(24, 35, 13)
    P.rect(13, 44, 35, 46, O); P.rect(21, 40, 27, 46, M)
    # the gate
    P.rect(156, 22, 190, 24, O); P.rect(153, 19, 191, 21, O); P.h(153, 191, 18, M)
    P.rect(160, 27, 186, 28, O)
    P.rect(161, 22, 164, 46, O); P.rect(182, 22, 185, 46, O)
    P.shade(163, 24, 164, 46, M, 2); P.shade(184, 24, 185, 46, M, 2)
    # stone lanterns
    for x in (78, 114):
        P.rect(x, 43, x + 4, 46, C); P.rect(x + 1, 38, x + 3, 42, C); P.rect(x - 1, 36, x + 5, 37, C)
        P.put(x + 2, 40, O if ph == 0 else W); P.h(x, x + 4, 35, W)
    # drifting snow
    for i, (x, y) in enumerate(((7, 26), (40, 30), (52, 22), (70, 33), (88, 40), (103, 24), (118, 36),
                                (146, 28), (150, 40), (172, 34), (100, 44), (44, 42))):
        P.put(x, y + (2 if ph else 0), W)
    P.floor(W, C, 'tiles', None)
    for x in range(0, SW, 2):
        P.put(x, FLOOR, C)
    return P


# ------------------------------------------------------------------ 5 EGYPT
def nile(ph=0):
    """NILE BY NIGHT: pyramids, the river and a torch-lit temple"""
    P = new(B)
    P.sky([(10, 30, B, B, 0), (31, 36, B, R, 1)])
    P.stars(((40, 11), (52, 14), (70, 12), (86, 15), (101, 11), (118, 13), (140, 15), (152, 11), (64, 16), (128, 10)), Y)
    P.disc(110, 13, 4, Y, 10, 16); P.disc(112, 12, 3, B, 10, 16)       # a crescent moon
    P.stars(((20, 19), (60, 22), (84, 18), (150, 21), (176, 18), (132, 24), (100, 21)), Y)
    # the pyramids
    P.tri(120, 19, 40, 30, Y, R, 2)
    P.tri(78, 27, 40, 19, Y, R, 2)
    P.tri(158, 30, 40, 14, Y, R, 2)
    # the far bank, palms, and the river with the moon on it
    P.rect(0, 40, SW - 1, 41, G)
    P.palm(58, 41, 9, Y, G); P.palm(102, 41, 7, Y, G); P.palm(176, 41, 10, Y, G)
    P.rect(0, 42, SW - 1, 46, B)
    for i, y in enumerate((42, 44, 46)):
        for x in range(60 + (i * 5), 186, 14):
            if (x // 14 + (ph if i == 1 else 0) + i) % 2:
                P.h(x, x + 4 + i, y, Y)
    # a felucca
    P.h(138, 150, 43, R); P.poly([(142, 43), (142, 35), (149, 42)], Y)
    # the temple colonnade on the left
    P.rect(0, 20, 50, 23, Y); P.shade(0, 22, 50, 23, R, 2)
    for i, x in enumerate((2, 18, 34)):
        P.column(x, 24, 46, 8, Y, R, capc=R)
        for y in range(27, 44, 4):
            P.put(x + 2, y, R); P.put(x + 4, y + 1, R); P.put(x + 3, y + 2, B)
    # torches flare between the columns
    for x in (13, 29, 45):
        P.v(x, 36, 46, R)
        P.put(x, 35 - ph, Y); P.put(x - 1 + 2 * ph, 34, R); P.put(x, 34, Y); P.put(x + 1 - 2 * ph, 35, R)
    P.floor(Y, R, 'tiles', B)
    return P


# ------------------------------------------------------------------ 6 ICELAND
def harbour(ph=0):
    """HARBOUR LIGHTS: the northern lights over a fishing port"""
    P = new(B)
    P.sky([(10, 46, B, B, 0)])
    P.stars(((38, 11), (58, 15), (90, 10), (126, 12), (150, 16), (104, 15), (70, 12)), Y)
    # the aurora: curtains of light
    for i, (x0, w, top) in enumerate(((10, 30, 17), (46, 22, 19), (76, 40, 17), (124, 26, 20), (156, 30, 17))):
        for x in range(x0, x0 + w):
            y0 = top + int(round(2 * math.sin(x / 5.0 + i)))
            ln = 6 + int(round(3 * math.sin(x / 3.0 + i * 2)))
            for y in range(y0, y0 + ln):
                if on(x, y, 3 if y < y0 + 2 else (2 if y < y0 + 4 else 1)):
                    P.put(x, y, G)
    # snow mountains across the fjord
    P.tri(40, 26, 42, 36, Y, B, 2); P.tri(92, 22, 42, 44, Y, B, 2); P.tri(150, 27, 42, 34, Y, B, 2)
    P.ridge(41, 1.5, G, seed=3, base=42, sh=B, lv=1)
    # the water
    P.rect(0, 43, SW - 1, 46, B)
    for i, x in enumerate(range(4, SW, 12)):
        if (i + ph) % 2:
            P.h(x, x + 4, 44 + (i % 2), Y)
    # painted houses along the quay
    for i, (x, w, h, c) in enumerate(((0, 16, 14, R), (18, 14, 11, Y), (34, 16, 15, R), (150, 14, 12, Y), (166, 18, 15, R))):
        y = 46 - h
        P.rect(x, y, x + w, 46, c)
        P.poly([(x - 1, y), (x + w + 1, y), (x + w // 2, y - 5)], B if c == Y else Y)
        P.shade(x + w - 3, y, x + w, 46, B, 2)
        P.rect(x + 3, y + 3, x + 6, y + 6, Y if c == R else B)
        P.rect(x + w - 8, y + 3, x + w - 5, y + 6, Y if c == R else B)
        P.rect(x + 5, 41, x + 8, 46, B)
    # the lighthouse, lamp turning
    P.rect(184, 22, 190, 46, Y)
    for y in (27, 33, 39):
        P.rect(184, y, 190, y + 2, R)
    P.rect(183, 19, 191, 21, R)
    if ph == 0:
        P.line(182, 20, 168, 23, Y); P.line(182, 20, 170, 18, Y)
    else:
        P.rect(185, 19, 189, 21, Y)
    # a trawler at the quay
    P.poly([(74, 46), (112, 46), (116, 41), (70, 41)], R); P.h(70, 116, 41, Y)
    P.rect(84, 35, 98, 40, Y); P.rect(86, 36, 89, 38, B); P.rect(92, 36, 95, 38, B)
    P.v(104, 26, 40, Y); P.line(104, 27, 116, 40, Y); P.flag(104, 26, R, ph, n=4)
    P.floor(Y, R, 'planks', B)
    return P


# ------------------------------------------------------------------ 7 MEXICO
def mercado(ph=0):
    """MERCADO: market day in the plaza"""
    P = new(C)
    P.sky([(10, 30, C, C, 0), (31, 46, C, W, 1)])
    P.disc(64, 13, 4, O, 10, 16)
    P.cloud(110, 12, 14, W); P.cloud(138, 15, 9, W)
    # far hills and tall cactus
    P.ridge(38, 4, M, seed=2, base=46, f=(17.0, 6.0), sh=C, lv=1)
    for x in (70, 124):
        P.rect(x, 30, x + 2, 46, C); P.rect(x - 4, 34, x - 3, 39, C); P.h(x - 4, x, 39, C)
        P.rect(x + 5, 32, x + 6, 37, C); P.h(x + 2, x + 6, 37, C)
        P.v(x + 2, 30, 46, M)
    # the mission church
    P.rect(84, 28, 112, 46, W); P.shade(106, 28, 112, 46, O, 1)
    P.poly([(84, 28), (112, 28), (98, 21)], O)
    P.rect(86, 18, 92, 28, W); P.poly([(85, 18), (93, 18), (89, 15)], O); P.rect(88, 21, 90, 24, M)
    P.rect(104, 18, 110, 28, W); P.poly([(103, 18), (111, 18), (107, 15)], O); P.rect(106, 21, 108, 24, M)
    P.ellipse(98, 40, 4, 3, M, 36, 40); P.rect(94, 40, 102, 46, M); P.ellipse(98, 32, 2, 2, C)
    # market stalls with striped awnings
    for (x0, c1, c2) in ((2, M, O), (34, O, W), (132, M, W), (162, O, M)):
        for x in range(x0, x0 + 28):
            col = c1 if ((x - x0) // 4) % 2 == 0 else c2
            P.v(x, 28, 32, col)
            P.put(x, 33 if ((x - x0) // 2) % 2 else 32, col)
        P.v(x0 + 1, 33, 46, M); P.v(x0 + 26, 33, 46, M)
        P.rect(x0 + 2, 40, x0 + 25, 46, O); P.shade(x0 + 2, 43, x0 + 25, 46, M, 2)
        for k in range(4):
            P.ellipse(x0 + 6 + k * 5, 39, 2, 1.5, (C, W, M, O)[(k + x0) % 4], 37, 40)
    # paper flags strung across the sky flutter
    for i, x in enumerate(range(6, 190, 8)):
        y = 18 + int(round(2 * math.sin(i / 3.5)))
        c = (M, O, W)[i % 3]
        d = (i + ph) % 2 if i % 3 == 0 else i % 2
        P.h(x, x + 4, y, c); P.h(x + d, x + 3 + d, y + 1, c); P.h(x + 1, x + 2 + d, y + 2, c)
        P.put(x - 2, y - 1, M); P.put(x + 6, y - 1, M)
    P.floor(O, M, 'tiles', W)
    return P


# ------------------------------------------------------------------ 8 INDIA
def jaipur(ph=0):
    """PALACE OF WINDS: a honeycomb of pink windows"""
    P = new(C)
    P.sky([(10, 30, C, C, 0), (31, 37, C, W, 1)])
    P.disc(150, 13, 4, O, 10, 16)
    P.cloud(52, 13, 12, W)
    # the palace: stepped tiers of little domed bays
    def bay(x, y, w=10, h=9):
        P.rect(x, y, x + w - 1, y + h, M)
        P.ellipse(x + w // 2, y, w // 2, 2.5, O, y - 3, y)
        P.put(x + w // 2, y - 4, W)
        P.rect(x + 3, y + 2, x + w - 4, y + h - 2, O)
        P.ellipse(x + w // 2, y + 2, 2, 1.5, O, y + 1, y + 2)
        P.h(x, x + w - 1, y + h, W)
        P.shade(x + w - 2, y, x + w - 1, y + h, O, 2)
    for row, (y, n) in enumerate(((20, 3), (29, 5), (38, 7))):
        x0 = 96 - n * 5
        for i in range(n):
            bay(x0 + i * 10, y)
    P.rect(60, 46, 132, 46, M)
    # garden walls and cypress trees either side
    for (x0, x1) in ((0, 58), (134, 191)):
        P.rect(x0, 38, x1, 46, O)
        for x in range(x0 + 2, x1 - 3, 8):
            P.ellipse(x + 2, 42, 2, 2.5, M, 40, 46); P.rect(x, 43, x + 4, 46, M)
        P.h(x0, x1, 38, W)
        for x in range(x0, x1, 4):
            P.put(x, 37, O); P.put(x + 1, 37, O)
    for x in (10, 30, 48, 144, 162, 182):
        for i in range(14):
            w = min(2, i // 3, (14 - i) // 2 + 1)
            P.h(x - w, x + w, 24 + i, C)
        P.shade(x, 24, x + 2, 37, M, 2, only=C)
    # flags and kites
    P.flag(96, 17, O, ph, n=6, pole=W, plen=3)
    for (x, y, c) in ((34, 18, M), (160, 19, O)):
        yy = y + ph
        P.put(x, yy, c); P.h(x - 1, x + 1, yy + 1, c); P.put(x, yy + 2, c); P.put(x + 1 - 2 * ph, yy + 3, W)
    P.floor(C, O, 'checker', M)
    return P


# ------------------------------------------------------------------ 9 THE BIG TOP
def bigtop(ph=0):
    """SABLE'S BIG TOP: under the striped canvas"""
    P = new(B)
    # rows 10-16 are still: the name on a band
    P.rect(0, 10, SW - 1, 16, R); P.rect(0, 11, SW - 1, 15, Y)
    P.text("SABLE'S BIG TOP", 66, 11, R)
    # the canvas: stripes fanning down from the king pole
    for y in range(17, 34):
        for x in range(SW):
            u = (x - 96) / (0.35 + (y - 17) / 9.0)
            P.put(x, y, R if int(math.floor(u / 9.0)) % 2 == 0 else Y)
    for x in range(SW):                                  # scalloped edge with a lamp under each point
        d = (x % 12)
        for y in range(34, 34 + (3 - abs(d - 6) // 2)):
            u = (x - 96) / (0.35 + 17 / 9.0)
            P.put(x, y, R if int(math.floor(u / 9.0)) % 2 == 0 else Y)
    for i, x in enumerate(range(6, SW, 12)):
        P.put(x, 37, Y if (i + ph) % 2 else R); P.put(x, 38, Y if (i + ph) % 2 else R)
    # the crowd in the dark: rows of faces
    for row, y in enumerate((39, 42, 45)):
        for x in range(2 + (row % 2) * 3, SW - 2, 6):
            if 78 < x < 114 and row > 0:
                continue
            c = (Y, R, Y, G)[(x // 6 + row) % 4]
            P.put(x, y, c); P.put(x + 1, y, c); P.h(x - 1, x + 2, y + 1, c if c != G else Y)
    # the ring doors, with curtains
    P.rect(80, 39, 112, 46, R); P.rect(82, 39, 110, 46, Y)
    for x in range(83, 110, 3):
        P.v(x, 40, 46, R)
    P.poly([(90, 46), (96, 40), (102, 46)], B)
    # a spotlight and a trapeze
    d = -2 if ph else 2
    P.line(88, 17, 88 + d, 24, B); P.line(104, 17, 104 + d, 24, B); P.h(88 + d, 104 + d, 24, B); P.h(88 + d, 104 + d, 25, B)
    # the ring: sawdust and the curb
    P.floor(Y, R, 'sand', B)
    for x in range(SW):
        y = 49 + int(round(((x - 96) / 96.0) ** 2 * 3))
        if (x // 8) % 2 == 0:
            P.put(x, y, R); P.put(x, y + 1, R)
        else:
            P.put(x, y, B); P.put(x, y + 1, Y)
    for x0 in (4, 176):
        P.poly([(x0, 62), (x0 + 11, 62), (x0 + 9, 54), (x0 + 2, 54)], R)
        P.rect(x0 + 1, 52, x0 + 10, 53, B); P.h(x0 + 1, x0 + 10, 58, Y)
        P.put(x0 + 5, 56, Y); P.put(x0 + 6, 56, Y)
    return P


#          key        name                   country     css  builder   shadow  map x, y
STAGES = [
    ('station', 'NEVER NEVER STATION', 'AUSTRALIA', 0, station, 0xAA, (109, 44)),
    ('mainst',  'MAIN STREET',         'USA',       0, mainst,  0xAA, (24, 23)),
    ('oia',     'OIA CLIFFS',          'GREECE',    1, oia,     0xAA, (70, 23)),
    ('kyoto',   'SNOW TEMPLE',         'JAPAN',     1, kyoto,   0xAA, (110, 24)),
    ('nile',    'NILE BY NIGHT',       'EGYPT',     0, nile,    0xAA, (72, 27)),
    ('harbour', 'HARBOUR LIGHTS',      'ICELAND',   0, harbour, 0xAA, (54, 13)),
    ('mercado', 'MERCADO',             'MEXICO',    1, mercado, 0xAA, (25, 29)),
    ('jaipur',  'PALACE OF WINDS',     'INDIA',     1, jaipur,  0xAA, (88, 27)),
    ('bigtop',  "SABLE'S BIG TOP",     '???',       0, bigtop,  0xAA, (47, 40)),
]

PAL = {0: {0: (0x07, 0xFF, 0x00), 1: (0xFF, 0xFF, 0x00), 2: (0x3B, 0x08, 0xFF), 3: (0xCC, 0x00, 0x3B)},
       1: {0: (0xFF, 0xFF, 0xFF), 1: (0x07, 0xE3, 0x99), 2: (0xFF, 0x1C, 0xFF), 3: (0xFF, 0x81, 0x00)}}


def preview(fn, idx, with_fighters=True, sx=4, sy=6):
    """real pixels: each stage whole (192 wide), fighters standing in"""
    from PIL import Image
    built = None
    if with_fighters:
        import fighters as F
        built = F.build_all()
    tiles = []
    for i in idx:
        st = STAGES[i]
        P = st[4](0)
        if built:
            for (who, x, flip, body) in ((i, 70, False, 2), ((i + 1) % 9, 122, True, 3)):
                fr = built[who][1][0]
                for r, row in enumerate(fr['rows']):
                    for c, v in enumerate(row):
                        if not v:
                            continue
                        xx = x + (fr['ax'] - c if flip else c - fr['ax'])
                        yy = 58 + fr['below'] - fr['h'] + 1 + r
                        P.put(xx, yy, {1: 1, 2: body, 3: 0}[v])
        im = Image.new('RGB', (SW, 54))
        for y in range(10, 64):
            for x in range(SW):
                im.putpixel((x, y - 10), PAL[st[3]][P.p[y][x]])
        tiles.append(im.resize((SW * sx, 54 * sy), Image.NEAREST))
    cols = 2 if len(tiles) > 1 else 1
    rows = (len(tiles) + cols - 1) // cols
    sh = Image.new('RGB', (cols * (SW * sx + 8), rows * (54 * sy + 8)), (20, 20, 20))
    for k, t in enumerate(tiles):
        sh.paste(t, ((k % cols) * (SW * sx + 8), (k // cols) * (54 * sy + 8)))
    sh.save(fn)


if __name__ == '__main__':
    preview(sys.argv[1], [int(a) for a in sys.argv[2:]] or list(range(9)))
