#!/usr/bin/env python3
"""RED DUST RUMBLE world tour: the stages, 192 x 64 each.

Every stage follows the Main Street rules, by palette index, so they hold in
either VZ palette:
  index 0  the ground behind the fighters (rows 28-45): plain, with index-1 lines
  index 1  line work, the sky/glow band at hat height (rows 17-27), the street
  index 2  player 1's body colour: only above head height or at the edges
  index 3  player 2's body colour: the same
Rows 10-16 never scroll (horizontal bands and stars only); rows 17-63 do.
CSS0 = green, yellow, blue, red.  CSS1 = buff, cyan, magenta, orange.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import stage as mainst

SW, H = 192, 64
I0, I1, I2, I3 = 0, 1, 2, 3


class Pic(mainst.Pic):
    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for t in range(n + 1):
            self.put(int(round(x0 + (x1 - x0) * t / n)), int(round(y0 + (y1 - y0) * t / n)), c)

    def ellipse(self, cx, cy, rx, ry, c, y0=0, y1=63):
        for y in range(max(0, int(cy - ry) - 1), min(H, int(cy + ry) + 2)):
            if not (y0 <= y <= y1):
                continue
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 < 1:
                    self.put(x, y, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(max(0, min(ys)), min(H, max(ys) + 1)):
            xs = []
            n = len(pts)
            for i in range(n):
                (xa, ya), (xb, yb) = pts[i], pts[(i + 1) % n]
                if (ya <= y < yb) or (yb <= y < ya):
                    xs.append(xa + (y - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                self.h(int(math.ceil(xs[i])), int(math.floor(xs[i + 1])), y, c)

    def text(self, s, x, y, c):
        F = mainst.font()
        for i, ch in enumerate(s):
            for ry, row in enumerate(F[ch]):
                for rx, cc in enumerate(row):
                    if cc == '#':
                        self.put(x + i * 4 + rx, y + ry, c)

    def outline(self, x0, y0, x1, y1, c):
        self.h(x0, x1, y0, c); self.h(x0, x1, y1, c)
        self.v(x0, y0, y1, c); self.v(x1, y0, y1, c)


def base(bands, ground=I1, edge=(I1, I3), stars=()):
    """sky bands (rows 10-27), the far edge of the ground at row 46-47, the
    ground from row 48; HUD band in index 2"""
    P = Pic()
    P.rect(0, 0, SW - 1, 9, I2)
    for y, c in bands.items():
        P.h(0, SW - 1, y, c)
    for (x, y) in stars:
        P.put(x, y, I1)
    P.rect(0, 28, SW - 1, 45, I0)
    P.h(0, SW - 1, 46, edge[0])
    P.h(0, SW - 1, 47, edge[1])
    P.rect(0, 48, SW - 1, 63, ground)
    return P


STARS = ((10, 11), (40, 12), (72, 11), (109, 10), (131, 12), (150, 11), (183, 12), (55, 10), (24, 13), (165, 14))


# ============================================================ 2  AUSTRALIA
def australia():
    """NEVER NEVER STATION - a woolshed at sunrise, Uluru on the horizon.
    CSS0: green / yellow / blue / red"""
    G, Y, B, R = 0, 1, 2, 3
    bands = {10: B, 11: B, 12: B, 13: R, 14: B, 15: R, 16: R}
    for y in range(17, 28):
        bands[y] = Y
    P = base(bands, ground=Y, edge=(Y, R), stars=STARS[:6])
    # ------- Uluru, right of the middle: one long smooth rock, a few gullies
    P.poly([(126, 27), (130, 23), (136, 21), (166, 21), (172, 23), (176, 27)], R)
    P.h(137, 165, 21, Y)                         # sunlit top
    for (x, y0) in ((141, 23), (149, 22), (157, 23), (163, 22)):
        P.v(x, y0, y0 + 2, Y)
    P.h(98, 191, 27, R)
    # the sun, half up behind the rock's left shoulder
    P.ellipse(124, 27, 7, 5, R, 17, 26)
    P.h(118, 130, 24, Y)
    # beyond: plain green spinifex country with a far fence
    P.h(96, 162, 37, Y)
    for x in range(98, 162, 8):
        P.v(x, 35, 37, Y)
    # ------- woolshed: rusty iron gable, green walls, big sliding door
    x0, x1 = 22, 94
    apex = (x0 + x1) // 2
    P.poly([(x0, 27), (apex, 17), (x1, 27)], R)
    for x in range(x0 + 2, x1 - 1, 3):
        for y in range(18, 27):
            if P.get(x, y) == R and P.get(x, y - 1) == R:
                P.put(x, y, Y)
    P.line(x0, 27, apex, 17, Y); P.line(apex, 17, x1, 27, Y)
    P.rect(apex - 17, 21, apex + 17, 26, Y)
    P.text('WOOLSHED', apex - 15, 21, R)
    P.h(x0 - 2, x1 + 2, 28, Y)                   # eaves
    for x in (x0, x1):
        P.v(x, 28, 45, Y)
    P.outline(apex - 14, 32, apex + 14, 45, Y)   # sliding door
    P.line(apex - 14, 32, apex + 14, 45, Y); P.line(apex + 14, 32, apex - 14, 45, Y)
    P.h(apex - 18, apex + 18, 31, Y)
    for (wx) in (x0 + 4, x1 - 10):
        P.outline(wx, 33, wx + 6, 38, Y); P.v(wx + 3, 33, 38, Y)
    # ------- left end: a rainwater tank on its stand
    P.rect(2, 19, 16, 27, B)
    for y in (20, 22, 24, 26):
        P.h(2, 16, y, Y)
    P.h(1, 17, 18, R)
    for x in (3, 15):
        P.v(x, 28, 34, Y)
    P.h(2, 16, 34, Y)
    # ------- a ghost gum: its green crown frames the fight against the glow
    P.v(112, 22, 45, Y); P.v(113, 22, 45, Y)
    P.line(112, 30, 106, 24, Y); P.line(113, 28, 120, 22, Y)
    for (cx, cy, rx, ry) in ((106, 21, 7, 3), (118, 19, 8, 3), (112, 23, 6, 2), (124, 22, 4, 2)):
        P.ellipse(cx, cy, rx, ry, G, 17, 27)
    # ------- the yards: rails, posts and sheep
    for y in (34, 39):
        P.h(164, 191, y, Y)
    for x in range(165, 192, 9):
        P.v(x, 33, 45, Y)
    for sx in (174, 186):
        P.ellipse(sx, 41, 4, 2.6, Y, 28, 45)
        P.rect(sx - 6, 40, sx - 4, 42, R)
        P.v(sx - 2, 43, 45, R); P.v(sx + 2, 43, 45, R)
    # ------- the ground: a stock track, a few red-dirt patches, spinifex
    vx, vy = 96, 46
    for bx in (40, 152):
        for y in range(50, 64):
            t = (y - vy) / (63 - vy)
            if y % 3:
                P.put(int(round(vx + (bx - vx) * t)), y, R)
    for (cx2, cy2) in ((20, 53), (126, 52), (170, 55), (70, 61), (110, 62)):
        for (dx, dy) in ((0, 0), (1, 0), (2, 0), (1, 1), (3, 1)):
            P.put(cx2 + dx, cy2 + dy, R)
    for (tx, ty) in ((10, 50), (84, 50), (138, 49), (184, 50)):
        for (dx, dy) in ((0, 0), (2, 0), (1, -1), (-1, -1), (3, -1)):
            P.put(tx + dx, ty + dy, G)
    # ------- foreground: a wool bale (left), a fuel drum (right)
    P.rect(0, 50, 13, 61, Y)
    P.outline(0, 50, 13, 61, R)
    for y in (53, 58):
        P.h(0, 13, y, R)
    P.rect(180, 51, 189, 62, R)
    for y in (53, 59):
        P.h(180, 189, y, Y)
    P.h(181, 188, 51, Y)
    return P


# ============================================================ 3  GREECE
def greece():
    """OIA CLIFFS - whitewashed chapels over the Aegean at sunset.
    CSS1: buff / cyan / magenta / orange"""
    W_, C, M, O = 0, 1, 2, 3
    bands = {10: M, 11: M, 12: M, 13: O, 14: M, 15: O, 16: O, 17: O, 18: O}
    for y in range(19, 28):
        bands[y] = C                             # the sea
    P = base(bands, ground=W_, edge=(C, C))
    # the sun touching the horizon, two glints of its path on the water
    P.ellipse(96, 19.5, 6, 2.5, W_, 17, 18)
    P.h(92, 100, 21, O); P.h(94, 98, 23, O); P.h(95, 97, 25, O)
    # distant island (Thirassia) and a few wave glints
    P.poly([(126, 22), (134, 19), (150, 19), (160, 22)], M)
    P.poly([(20, 22), (30, 20), (44, 21), (52, 22)], M)
    for (x, y) in ((60, 24), (64, 26), (140, 25), (170, 23), (12, 25), (180, 26)):
        P.h(x, x + 3, y, W_)
    # ------- white cubes stepping along the cliff; outlines only in the band
    def cube(x0, x1, top):
        P.rect(x0, top, x1, 45, W_)
        P.h(x0, x1, top, C)
        P.v(x0, top, 45, C); P.v(x1, top, 45, C)
    def dome(cx, top, r, colour=C):
        P.ellipse(cx, top, r, r / 1.5, W_, 17, top)
        for a in range(0, 181, 6):
            rr = math.radians(a)
            P.put(cx + int(round(math.cos(rr) * r)), top - int(round(math.sin(rr) * r / 1.5)), colour)
        P.v(cx, top - int(r / 1.5) - 3, top - int(r / 1.5) - 1, C)   # cross
        P.h(cx - 1, cx + 1, top - int(r / 1.5) - 2, C)
    cube(0, 30, 24); dome(15, 24, 9)
    cube(31, 52, 27)
    cube(140, 168, 25); dome(154, 25, 8)
    cube(169, 191, 23)
    # the bell tower (campanile): arches with bells, above head height
    P.rect(56, 17, 74, 45, W_)
    P.outline(56, 17, 74, 45, C)
    for bx in (60, 69):
        P.outline(bx - 2, 19, bx + 2, 25, C)
        P.ellipse(bx, 23, 1.6, 1.6, O, 17, 27)
    P.h(56, 74, 27, C)
    P.v(65, 15 + 2, 18, C)
    # doors and windows in the band: cyan outlines (a door can be filled
    # below the waist line)
    for (x0, x1, y0) in ((8, 14, 33), (36, 44, 36), (146, 152, 34), (176, 184, 33)):
        P.outline(x0, y0, x1, 45, C)
        P.v((x0 + x1) // 2, y0, 45, C)
    for (x, y) in ((20, 31), (60, 32), (68, 32), (160, 31), (186, 30)):
        P.outline(x, y, x + 3, y + 4, C)
    # bougainvillea spilling over the walls (magenta), above head height
    for (cx, cy, rx, ry) in ((30, 25, 6, 2.5), (52, 26, 5, 2), (140, 24, 5, 2.4), (168, 23, 6, 2.4), (3, 23, 4, 2)):
        P.ellipse(cx, cy, rx, ry, M, 17, 27)
    # a low parapet in the open middle, with the sea beyond
    P.h(75, 139, 37, C)
    for x in range(76, 139, 9):
        P.v(x, 37, 45, C)
    # ------- the terrace: two tile courses and a few joints in perspective
    for y in (50, 57):
        for x in range(SW):
            if x % 4 != 3:
                P.put(x, y, C)
    vx = 96
    for bx in (-60, 40, 152, 252):
        for y in range(51, 64):
            if y != 57:
                t = (y - 46) / 17
                P.put(int(round(vx + (bx - vx) * t)), y, C)
    # ------- foreground: terracotta pots with flowers
    def pot(x0, y0):
        P.poly([(x0, y0), (x0 + 10, y0), (x0 + 8, y0 + 9), (x0 + 2, y0 + 9)], O)
        P.h(x0 - 1, x0 + 11, y0, O)
        P.ellipse(x0 + 5, y0 - 2, 6, 2.5, M, 40, 63)
        P.put(x0 + 3, y0 - 3, W_); P.put(x0 + 7, y0 - 2, W_)
    pot(2, 52)
    pot(178, 53)
    return P


# ============================================================ 4  JAPAN
def japan():
    """SNOW TEMPLE, KYOTO - a temple yard at dusk in falling snow.
    CSS1: buff / cyan / magenta / orange"""
    W_, C, M, O = 0, 1, 2, 3
    bands = {10: M, 11: M, 12: M, 13: O, 14: M, 15: O, 16: O}
    for y in range(17, 28):
        bands[y] = W_                            # pale snowy sky
    P = base(bands, ground=W_, edge=(C, C))
    # the snow: sparse cyan flakes in the pale sky
    for (x, y) in ((8, 19), (30, 24), (47, 18), (88, 21), (103, 26), (118, 18), (150, 22), (176, 19), (189, 25), (64, 25), (128, 25)):
        P.put(x, y, C)
    # a pagoda far off in the middle
    for k, (w, y) in enumerate(((7, 19), (9, 22), (11, 25))):
        P.h(98 - w, 98 + w, y, M)
        P.h(98 - w + 2, 98 + w - 2, y + 1, M)
        P.put(98 - w - 1, y - 1, M); P.put(98 + w + 1, y - 1, M)
    P.v(98, 17, 18, M)
    P.rect(95, 26, 101, 27, M)
    # ------- the hall: a sweeping roof (magenta tiles, snow on the ridge)
    P.poly([(4, 27), (14, 21), (66, 21), (76, 27)], M)
    P.line(0, 25, 4, 27, M); P.line(76, 27, 80, 25, M)
    P.h(14, 66, 20, C)                           # snow on the ridge, outlined
    P.h(12, 68, 19, C)
    for x in range(8, 74, 4):
        P.put(x, 26, C)
    P.h(4, 76, 28, C)
    for x in (8, 24, 40, 56, 72):                # pillars
        P.v(x, 28, 45, C)
    for x0 in (11, 43, 59):                      # shoji screens: a sparse grid
        P.outline(x0, 31, x0 + 10, 41, C)
        P.v(x0 + 5, 31, 41, C)
        P.h(x0, x0 + 10, 36, C)
    P.h(4, 76, 44, C)                            # the hall's raised floor
    # ------- the torii gate: vermilion beams up high, slim pillars
    P.h(120, 166, 18, O); P.h(118, 168, 19, O)
    P.put(117, 18, O); P.put(169, 18, O)
    P.h(124, 162, 22, O)
    P.rect(141, 19, 145, 21, O)                  # name plaque
    for x in (128, 157):
        P.v(x, 20, 45, O); P.v(x + 1, 20, 45, O)
    P.h(120, 166, 17, C)                         # snow on the beam, outlined
    # stone lanterns
    def toro(cx):
        P.rect(cx - 3, 31, cx + 3, 32, C)
        P.outline(cx - 2, 33, cx + 2, 36, C)
        P.put(cx, 34, O); P.put(cx, 35, O)       # the flame
        P.h(cx - 3, cx + 3, 37, C)
        P.v(cx, 38, 43, C)
        P.h(cx - 3, cx + 3, 44, C)
    toro(108); toro(178)
    # a bare plum tree with snow along its branches
    P.line(190, 45, 186, 30, C); P.line(186, 30, 180, 22, C)
    P.line(186, 33, 191, 24, C); P.line(183, 26, 176, 21, C)
    for (x, y) in ((180, 21), (176, 20), (190, 23), (184, 24)):
        P.put(x, y, M)                           # plum blossom
    # ------- snow on the ground: three flat stepping stones, a few prints
    for (cx, cy, rx) in ((96, 51, 5), (92, 56, 6), (99, 61, 7)):
        P.h(cx - rx + 1, cx + rx - 1, cy - 1, C)
        P.h(cx - rx, cx + rx, cy, C)
    for (x, y) in ((40, 52), (44, 55), (39, 58), (150, 50), (146, 54), (151, 58)):
        P.h(x, x + 1, y, C)
    for x in range(0, SW, 4):
        P.put(x, 48, C)
    # foreground: a snow-capped stone basin (left), a wooden bucket (right)
    P.rect(2, 52, 14, 61, C)
    P.rect(4, 54, 12, 59, W_)
    P.h(1, 15, 51, C)
    P.rect(178, 54, 186, 61, O)
    P.h(177, 187, 54, M); P.h(178, 186, 58, M)
    return P


# ============================================================ 5  EGYPT
def egypt():
    """NILE BY NIGHT - temple columns, palms and the pyramids under the moon.
    CSS0: green / yellow / blue / red"""
    G, Y, B, R = 0, 1, 2, 3
    bands = {10: B, 11: B, 12: B, 13: B, 14: B, 15: B, 16: B}
    for y in range(17, 28):
        bands[y] = G                             # night haze over the desert
    P = base(bands, ground=Y, edge=(Y, R), stars=STARS)
    # the moon, big and low
    P.ellipse(150, 21, 7, 4.6, Y, 17, 27)
    for (x, y) in ((147, 20), (152, 22), (149, 23)):
        P.put(x, y, R)
    # pyramids: stone courses as ruled yellow lines on the lit faces
    def pyramid(cx, top, half):
        for y in range(top, 28):
            k = (y - top) * half // (27 - top + 1)
            P.put(cx - k, y, Y)
            P.put(cx + k, y, Y)
            if (y - top) % 2 == 1:
                P.h(cx, cx + k, y, Y)            # the moonlit face
    pyramid(86, 18, 16)
    pyramid(110, 21, 10)
    P.h(60, 132, 27, Y)
    # ------- temple: columns with lotus capitals, a lintel, carvings up high
    def column(x):
        P.v(x, 24, 45, Y); P.v(x + 5, 24, 45, Y)
        P.poly([(x - 2, 21), (x + 7, 21), (x + 5, 24), (x, 24)], Y)
    for x in (6, 30, 54):
        column(x)
    P.rect(0, 17, 64, 20, Y)                     # lintel
    for x in range(3, 62, 6):                    # hieroglyphs
        P.put(x, 18, R); P.put(x + 2, 19, B); P.put(x + 1, 18, B)
    P.v(64, 17, 45, Y)
    # ------- palms against the haze
    def palm(x, top):
        for y in range(top, 46):
            P.put(x + (y - top) // 9, y, Y)
            if y % 3 == 0:
                P.put(x + 1 + (y - top) // 9, y, Y)
        for (dx, dy) in ((-8, 3), (-6, -1), (0, -2), (6, -1), (8, 3), (4, 4), (-4, 4)):
            P.line(x, top, x + dx, top + dy, G if False else Y)
        P.put(x - 1, top + 1, R); P.put(x + 1, top + 1, R)   # dates
    palm(132, 20)
    palm(170, 18)
    # reeds along the river bank, low
    for x in range(72, 190, 6):
        P.v(x, 42, 45, Y)
        P.put(x - 1, 42, Y)
    # a felucca's sail on the river
    P.poly([(184, 30), (184, 40), (176, 40)], Y)
    P.v(184, 28, 41, Y)
    # ------- sand: ripples as clean curves, not speckle
    for (x0, y0, w) in ((10, 51, 22), (60, 54, 26), (120, 50, 20), (150, 57, 30), (30, 60, 24), (96, 62, 28)):
        for x in range(w):
            P.put(x0 + x, y0 + int(round(math.sin(x / w * math.pi) * -1.2)), R)
    # foreground: a water jar (left), a brass lantern (right)
    P.ellipse(7, 56, 6, 5, R, 48, 63)
    P.h(4, 10, 50, R); P.h(3, 11, 54, Y)
    P.rect(181, 52, 187, 61, Y)
    P.outline(181, 52, 187, 61, R)
    P.put(184, 56, R)
    return P


# ============================================================ 6  ICELAND
def iceland():
    """HARBOUR LIGHTS, REYKJAVIK - the northern lights over the harbour.
    CSS0: green / yellow / blue / red"""
    G, Y, B, R = 0, 1, 2, 3
    bands = {10: B, 11: B, 12: B, 13: B, 14: G, 15: B, 16: G}
    for y in range(17, 28):
        bands[y] = G                             # the aurora's glow
    P = base(bands, ground=Y, edge=(Y, R), stars=STARS[2:])
    # aurora: two long ribbons rippling across the glow, with short folds
    for x in range(SW):
        y1 = 18 + int(round(1.5 + 1.5 * math.sin(x / 17.0)))
        y2 = 22 + int(round(1.2 * math.sin(x / 11.0 + 1.3)))
        P.put(x, y1, Y)
        if x % 3 == 0:
            P.put(x, y1 + 1, Y)
        if 20 < x < 170:
            P.put(x, y2, Y)
    P.h(0, SW - 1, 17, B)
    # Esja: a long snow-streaked mountain, low behind the houses
    P.poly([(56, 27), (72, 22), (90, 21), (112, 23), (132, 27)], B)
    for (x0, x1, y) in ((72, 84, 22), (90, 104, 21), (95, 100, 22), (76, 80, 23), (106, 112, 23)):
        P.h(x0, x1, y, Y)
    # ------- coloured houses: red and blue roofs up high, green walls below
    def house(x0, x1, roof):
        mid = (x0 + x1) // 2
        P.poly([(x0 - 1, 27), (mid, 27 - (x1 - x0) // 3), (x1 + 1, 27)], roof)
        P.line(x0 - 1, 27, mid, 27 - (x1 - x0) // 3, Y)
        P.line(mid, 27 - (x1 - x0) // 3, x1 + 1, 27, Y)
        P.v(x0, 28, 45, Y); P.v(x1, 28, 45, Y)
        P.h(x0, x1, 28, Y)
        for wx in range(x0 + 3, x1 - 3, 7):
            P.outline(wx, 31, wx + 3, 35, Y)
            P.put(wx + 1, 33, Y); P.put(wx + 2, 33, Y)   # lamp-lit
    house(2, 22, R)
    house(25, 43, B)
    house(46, 58, R)
    # ------- fish-drying racks in the open middle
    for x0 in (66, 96):
        P.line(x0, 45, x0 + 4, 30, Y); P.line(x0 + 8, 45, x0 + 4, 30, Y)
        P.line(x0 + 24, 45, x0 + 28, 30, Y); P.line(x0 + 32, 45, x0 + 28, 30, Y)
        P.h(x0 + 4, x0 + 28, 30, Y)
        for fx in range(x0 + 8, x0 + 26, 6):
            P.v(fx, 31, 34, Y)
    # ------- the lighthouse: striped lantern tower, lamp lit
    P.rect(160, 18, 170, 27, R)
    for y in (20, 24):
        P.h(160, 170, y, Y)
    P.rect(162, 14 + 3, 168, 17, Y)              # lamp room
    P.v(165, 17, 17, R)
    P.v(160, 28, 45, Y); P.v(170, 28, 45, Y)
    for y in (32, 38):
        P.h(160, 170, y, Y)
    # beams of light
    P.line(159, 17, 146, 20, Y); P.line(171, 17, 184, 20, Y)
    # a trawler's masts and rigging behind the quay
    for (x, top) in ((132, 20), (146, 23)):
        P.v(x, top, 45, Y)
        P.h(x - 4, x + 4, top + 4, Y)
    P.line(132, 20, 146, 23, Y)
    P.rect(176, 40, 191, 45, R)                  # a hull just showing
    P.h(176, 191, 40, Y)
    # ------- the quay: two plank seams, bollards
    for y in (52, 60):
        for x in range(SW):
            if x % 24 != 12:
                P.put(x, y, R)
    for (x, y) in ((40, 50), (120, 50), (160, 50)):
        P.rect(x, y - 2, x + 3, y + 1, R)
        P.h(x - 1, x + 4, y - 2, Y)
    P.ellipse(8, 57, 7, 3, R, 48, 63)            # coiled rope
    P.ellipse(8, 57, 4, 1.6, Y, 48, 63)
    P.rect(176, 52, 189, 61, R)                  # a fish crate
    P.outline(176, 52, 189, 61, Y)
    P.h(176, 189, 56, Y)
    return P


# ============================================================ 7  MEXICO
def mexico():
    """MERCADO, OAXACA - market day under papel picado.
    CSS1: buff / cyan / magenta / orange"""
    W_, C, M, O = 0, 1, 2, 3
    bands = {}
    for y in range(10, 28):
        bands[y] = C                             # clear blue (cyan) sky
    P = base(bands, ground=W_, edge=(O, O))
    for (x, y) in ((20, 12), (70, 14), (140, 11), (172, 13)):
        P.h(x, x + 5, y, W_)
    # papel picado: strings sagging across, flags alternating colours
    for (x0, x1, y0) in ((0, 96, 17), (96, 191, 17)):
        for x in range(x0, x1 + 1):
            t = (x - x0) / (x1 - x0)
            y = int(round(y0 + 5 * math.sin(t * math.pi)))
            P.put(x, y, O)
            if (x - x0) % 6 == 2:
                col = (M, O, W_)[(x // 6) % 3]
                P.rect(x, y + 1, x + 3, y + 3, col)
                P.put(x + 1, y + 2, C)           # cut-out
    # the church: a pale baroque front, bell towers up high
    P.rect(64, 20, 128, 45, W_)
    for x in (64, 128):
        P.v(x, 20, 45, C)
    for tx in (64, 118):
        P.rect(tx, 17 + 1, tx + 10, 27, W_)
        P.outline(tx, 18, tx + 10, 27, C)
        P.ellipse(tx + 5, 18, 4, 2, W_, 17, 18)
        P.put(tx + 5, 17, C)
        P.outline(tx + 3, 21, tx + 7, 26, C)
        P.ellipse(tx + 5, 24, 1.2, 1.4, O, 17, 27)   # bell
    P.poly([(80, 27), (96, 19), (112, 27)], W_)   # pediment
    P.line(80, 27, 96, 19, C); P.line(96, 19, 112, 27, C)
    P.ellipse(96, 24, 2.5, 1.6, C, 17, 27)       # round window
    P.ellipse(96, 24, 1.2, 0.8, M, 17, 27)
    P.h(64, 128, 28, C)
    # the great doorway: an arch outlined, doors below the waist line
    for a in range(0, 181, 8):
        r = math.radians(a)
        P.put(96 + int(round(math.cos(r) * 8)), 36 - int(round(math.sin(r) * 6)), C)
    P.v(88, 36, 45, C); P.v(104, 36, 45, C)
    P.v(96, 36, 45, C)
    for x in (72, 120):
        P.outline(x - 2, 31, x + 2, 36, C)
    # market stalls: striped awnings up high, counters low
    def stall(x0, x1, a, b):
        for x in range(x0, x1 + 1):
            P.v(x, 22, 26, a if (x // 3) % 2 == 0 else b)
        for x in range(x0, x1 + 1, 3):
            P.put(x, 27, a)
        P.v(x0 + 1, 27, 45, C); P.v(x1 - 1, 27, 45, C)
        P.h(x0, x1, 38, C)
        for fx in range(x0 + 3, x1 - 2, 3):     # fruit on the counter
            P.put(fx, 37, O); P.put(fx + 1, 37, O)
    stall(2, 30, M, W_)
    stall(33, 60, O, W_)
    stall(132, 160, O, W_)
    stall(163, 190, M, W_)
    # a piñata hanging from the bunting
    P.v(150, 19, 21, O)
    P.poly([(150, 21), (154, 24), (150, 27), (146, 24)], M)
    for (dx, dy) in ((-5, 24), (5, 24), (0, 19)):
        P.line(150, 24, 150 + dx, dy, O)
    # ------- the plaza: cobble arcs, sparse
    for (cx, cy, r) in ((40, 58, 12), (96, 61, 16), (152, 58, 12)):
        for a in range(200, 341, 8):
            rr = math.radians(a)
            P.put(cx + int(round(math.cos(rr) * r)), cy + int(round(math.sin(rr) * r / 2.5)), C)
    for x in range(0, SW, 2):
        P.put(x, 63, C)
    # foreground: potted cacti
    def cactus(x0):
        P.poly([(x0, 55), (x0 + 10, 55), (x0 + 8, 62), (x0 + 2, 62)], O)
        P.rect(x0 + 4, 45, x0 + 6, 54, C)
        P.rect(x0 + 1, 48, x0 + 3, 50, C); P.v(x0 + 1, 46, 48, C)
        P.rect(x0 + 7, 49, x0 + 9, 51, C); P.v(x0 + 9, 47, 49, C)
        P.put(x0 + 5, 44, M)
    cactus(1)
    cactus(180)
    return P


# ============================================================ 8  INDIA
def india():
    """PALACE OF WINDS, JAIPUR - the pink city at kite time.
    CSS1: buff / cyan / magenta / orange"""
    W_, C, M, O = 0, 1, 2, 3
    bands = {}
    for y in range(10, 28):
        bands[y] = C
    P = base(bands, ground=W_, edge=(M, M))
    # kites riding the wind
    for (x, y, col) in ((30, 18, O), (88, 20, M), (140, 18, O), (176, 21, M)):
        P.poly([(x, y - 2), (x + 2, y), (x, y + 2), (x - 2, y)], col)
        P.line(x, y + 2, x - 3, y + 6, W_)
    P.ellipse(112, 19, 4, 2.4, O, 17, 27)        # the morning sun
    # the palace front: a honeycomb of little windows, pink (magenta), up high
    def tier(x0, x1, y0, y1):
        P.rect(x0, y0, x1, y1, M)
        for y in range(y0 + 1, y1, 3):
            for x in range(x0 + 1 + (y // 3) % 2, x1 - 1, 3):
                P.put(x, y, W_)
                P.put(x, y + 1, W_)
        P.h(x0, x1, y0, O)
    tier(0, 60, 22, 27)
    tier(8, 52, 18, 21)
    tier(18, 42, 17, 17)
    tier(132, 191, 21, 27)
    tier(140, 184, 18, 20)
    for cx in (12, 30, 48, 144, 164, 184):       # domed kiosks (chhatris)
        P.ellipse(cx, 21 if cx < 60 else 20, 3, 2, O, 17, 27)
    # below: pale arches, outlined, a marigold garland swag
    def arches(x0, x1):
        P.rect(x0, 28, x1, 45, W_)
        P.h(x0, x1, 28, C)
        for ax in range(x0 + 2, x1 - 6, 10):
            for a in range(0, 181, 15):
                r = math.radians(a)
                P.put(ax + 4 + int(round(math.cos(r) * 4)), 34 - int(round(math.sin(r) * 3)), C)
            P.v(ax, 34, 45, C); P.v(ax + 8, 34, 45, C)
    arches(0, 60)
    arches(132, 191)
    for (x0, x1) in ((0, 60), (132, 191)):
        for x in range(x0, x1 + 1):
            t = (x - x0) / 12.0
            y = 28 + int(round(abs(math.sin(t * math.pi)) * 2))
            if x % 2 == 0:
                P.put(x, y, O)
    # the open courtyard in the middle: a low jali screen
    P.h(61, 131, 36, C); P.h(61, 131, 40, C)
    for x in range(64, 130, 6):
        P.line(x, 36, x + 3, 40, C); P.line(x + 3, 36, x, 40, C)
    # a domed pavilion (chhatri) across the courtyard, its dome up high
    P.ellipse(96, 23, 9, 4, M, 17, 26)
    P.v(96, 17, 18, O)
    P.h(84, 108, 27, O)
    P.h(85, 107, 26, M)
    for x in (86, 94, 98, 106):
        P.v(x, 28, 35, C)
    P.h(84, 108, 28, C)
    # ------- the courtyard: a star pattern in the paving, sparse
    for (cx, cy) in ((32, 55), (96, 58), (160, 55)):
        for a in range(0, 360, 45):
            r = math.radians(a)
            P.line(cx, cy, cx + int(round(math.cos(r) * 7)), cy + int(round(math.sin(r) * 2.5)), C)
        P.put(cx, cy, O)
    for x in range(0, SW, 2):
        P.put(x, 63, C)
    # foreground: brass water pots
    for x0 in (2, 178):
        P.ellipse(x0 + 6, 57, 6, 4, O, 48, 63)
        P.rect(x0 + 4, 51, x0 + 8, 53, O)
        P.h(x0 + 2, x0 + 10, 57, M)
    return P


STAGES = [
    # (key, name, country, css, builder, home fighter)
    ('mainst', 'MAIN STREET', 'USA', 0, mainst.build, 'DUSTY'),
    ('station', 'NEVER NEVER STATION', 'AUSTRALIA', 0, australia, 'FLICK'),
    ('oia', 'OIA CLIFFS', 'GREECE', 1, greece, 'NIKOS'),
    ('kyoto', 'SNOW TEMPLE', 'JAPAN', 1, japan, 'HANA'),
    ('nile', 'NILE BY NIGHT', 'EGYPT', 0, egypt, 'AMUN'),
    ('harbour', 'HARBOUR LIGHTS', 'ICELAND', 0, iceland, 'SIGRUN'),
    ('mercado', 'MERCADO', 'MEXICO', 1, mexico, 'LUPE'),
    ('jaipur', 'PALACE OF WINDS', 'INDIA', 1, india, 'RAVI'),
]
