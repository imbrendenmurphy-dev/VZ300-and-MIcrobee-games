#!/usr/bin/env python3
"""Main Street: the scrolling arena, 192 x 64 pixels (1.5 screens).

Rows 0-9 are the HUD band, rows 10-16 the still sky (it does not scroll),
rows 17-63 scroll with the camera.  Colours: 0 green 1 yellow 2 blue 3 red.

Composition rules (see mockups/README.md):
- the fighters are blue or red with yellow detail, so behind their bodies
  (rows 28-46) the town fronts are green with yellow structure;
- hat height (rows 17-26) is yellow glow; strong blue/red sit above head
  height or at the edges; texture is bands, ruled lines and a few clusters.
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))

G, Y, B, R = 0, 1, 2, 3
SW, H = 192, 64
SKYROWS = 17          # rows 0-16 never scroll
BOARDWALK = 46


class Pic:
    def __init__(self, w=SW):
        self.w = w
        self.p = [[G] * w for _ in range(H)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < H:
            self.p[y][x] = c

    def get(self, x, y):
        return self.p[y][x] if 0 <= x < self.w and 0 <= y < H else None

    def h(self, x0, x1, y, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, c)

    def v(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.h(x0, x1, y, c)


def font():
    import art
    return art.FONT


def build():
    F = font()
    P = Pic()
    P.rect(0, 0, SW - 1, 9, B)                   # HUD band

    # ---------------------------------------------------------------- sky
    # rows 10-16 are still (the stars stay put while the town scrolls)
    bands = {10: B, 11: B, 12: B, 13: R, 14: B, 15: R, 16: R, 17: Y, 18: R}
    for y in range(19, 27):
        bands[y] = Y
    for y, c in bands.items():
        P.h(0, SW - 1, y, c)
    for (x, y) in ((10, 11), (40, 12), (72, 11), (109, 10), (131, 12), (150, 11), (183, 12), (55, 10)):
        P.put(x, y, Y)

    # the vista between the store and the bank: the sun setting onto a long
    # flat-topped mesa (green, red sunlit rim)
    cx = 96
    for y in range(SKYROWS, 24):
        for x in range(cx - 14, cx + 15):
            if (x + 0.5 - cx) ** 2 + ((y + 0.5 - 23.5) * 1.5) ** 2 < 100:
                P.put(x, y, Y if y == 21 else R)
    for y in range(23, 28):
        k = y - 23
        P.h(cx - 20 - k * 3, cx + 20 + k * 3, y, G)
        P.put(cx - 20 - k * 3, y, R)
        P.put(cx + 20 + k * 3, y, R)
    P.h(cx - 20, cx + 20, 23, R)
    for x in range(cx - 17, cx + 18, 4):
        P.put(x, 25, R)
    P.h(cx - 40, cx + 40, 28, Y)                 # the plain beyond the mesa

    # windmill behind the hotel (only its wheel shows above the roofs)
    wx, wy = 150, 20
    for a in range(0, 360, 45):
        r = math.radians(a + 22.5)
        for t in range(1, 4):
            P.put(wx + int(round(math.cos(r) * t)), wy + int(round(math.sin(r) * t / 1.5)), B)
    P.put(wx, wy, R)
    P.v(wx - 1, 22, 24, B); P.v(wx + 1, 22, 24, B)

    # water tower at the right end: blue tank on yellow legs, above head height
    tx = 176
    P.rect(tx - 6, 13 + 4, tx + 6, 22, B)
    P.h(tx - 7, tx + 7, 17, R)                   # roof rim
    P.h(tx - 5, tx + 5, 20, Y)                   # hoop
    for x in (tx - 5, tx + 5):
        P.v(x, 23, 30, Y)
    P.h(tx - 5, tx + 5, 26, Y)

    # ---------------------------------------------------------------- town
    # Rule: rows 28-46 (the fighters' heads to waists) carry only green and
    # thin yellow lines.  Signs, dark windows and colour live in rows 17-27.
    town = [(0, 29, 22, 'stable'), (30, 59, 18, 'saloon'), (60, 77, 22, 'store'),
            (78, 86, 30, 'shack'), (106, 114, 30, 'shack'), (115, 133, 21, 'bank'),
            (134, 163, 21, 'hotel'), (164, 191, 20, 'jail')]
    for (x0, x1, top, kind) in town:
        P.rect(x0, top, x1, BOARDWALK - 1, G)
        P.h(x0, x1, top, R)                      # cornice, dark against the glow
        P.h(x0, x1, top + 1, Y)
        P.v(x1, top, BOARDWALK - 1, Y)
    # the gap: the street runs off between the shacks
    P.h(87, 105, 40, Y)
    for x in (88, 94, 100, 105):
        P.v(x, 38, BOARDWALK - 1, Y)

    def pane(x, y, w=5, h=5):
        """a window in the fighters' band: just a yellow frame and mullion"""
        P.h(x, x + w - 1, y, Y)
        P.h(x, x + w - 1, y + h - 1, Y)
        P.v(x, y, y + h - 1, Y)
        P.v(x + w - 1, y, y + h - 1, Y)
        P.v(x + w // 2, y, y + h - 1, Y)

    def dark(x, y, w=4, h=4):
        """a dark window, above head height"""
        P.rect(x, y, x + w - 1, y + h - 1, B)
        P.h(x - 1, x + w, y + h, Y)

    def door(x0, x1, y0):
        P.v(x0, y0, BOARDWALK - 1, Y)
        P.v(x1, y0, BOARDWALK - 1, Y)
        P.h(x0, x1, y0, Y)

    def word(s2, x, y, c):
        for i, ch in enumerate(s2):
            for ry, row in enumerate(F[ch]):
                for rx, cc in enumerate(row):
                    if cc == '#':
                        P.put(x + i * 4 + rx, y + ry, c)

    def sign(x0, x1, y):
        P.rect(x0, y, x1, y + 4, Y)
        for x in range(x0 + 2, x1 - 1, 2):
            if (x // 2) % 3:
                P.put(x, y + 2, R)

    # livery stable: barn roofline, dark hay-loft door, big X-braced doors
    for k in range(5):
        P.h(4 + k * 2, 25 - k * 2, 22 - k, R)
    P.h(8, 21, 17, R)
    P.rect(11, 20, 18, 26, B)
    P.h(10, 19, 19, Y)
    door(5, 24, 32)
    P.v(15, 32, BOARDWALK - 1, Y)
    for k in range(9):
        P.put(6 + k, 33 + k * 12 // 9, Y); P.put(14 - k, 33 + k * 12 // 9, Y)
        P.put(16 + k * 7 // 8, 33 + k * 12 // 9, Y); P.put(23 - k * 7 // 8, 33 + k * 12 // 9, Y)

    # saloon: dark false front with its name; awning is one line and a fringe
    P.rect(30, 18, 57, 27, B)
    P.h(30, 57, 18, R)
    P.rect(31, 20, 56, 26, Y)
    word('SALOON', 32, 21, R)
    P.h(30, 59, 33, Y)
    for x in range(31, 60, 4):
        P.put(x, 34, R)
    for x in (31, 58):
        P.v(x, 34, BOARDWALK - 1, Y)
    pane(34, 37); pane(52, 37, 5, 5)
    door(42, 49, 37)                             # batwing doors
    P.h(43, 45, 39, Y); P.h(46, 48, 39, Y)
    P.h(43, 45, 42, Y); P.h(46, 48, 42, Y)
    # general store: false front with a sign
    sign(62, 75, 23)
    pane(63, 34); pane(71, 34)
    door(67, 69, 38)
    # shacks either side of the gap
    pane(80, 34, 4, 4); pane(108, 34, 4, 4)
    # bank: blue pediment, sign, columns
    for k in range(3):
        P.h(119 + k * 2, 129 - k * 2, 20 - k, B)
    sign(118, 130, 24)
    for x in (118, 122, 126, 130):
        P.v(x, 31, BOARDWALK - 1, Y)
    P.h(117, 131, 31, Y)
    # hotel: dark upper windows above head height, balcony, plain lower floor
    dark(137, 23); dark(144, 23); dark(151, 23); dark(158, 23)
    P.h(134, 163, 29, Y)
    for x in range(135, 163, 3):
        P.v(x, 29, 30, Y)
    P.h(134, 163, 31, Y)
    P.v(134, 32, BOARDWALK - 1, Y)
    # jail: tall false front with its name, barred window, door
    P.rect(166, 22, 189, 27, Y)
    word('JAIL', 170, 22, R)
    P.rect(169, 36, 176, 41, G)
    P.h(169, 176, 36, Y); P.h(169, 176, 41, Y)
    for x in (169, 171, 173, 175, 176):
        P.v(x, 36, 41, Y)
    door(181, 186, 36)
    # the far boardwalk
    P.h(0, SW - 1, BOARDWALK, Y)
    P.h(0, SW - 1, BOARDWALK + 1, R)

    # ---------------------------------------------------------------- street
    for y in range(BOARDWALK + 2, H):
        P.h(0, SW - 1, y, Y)
    for y in (BOARDWALK + 2, BOARDWALK + 4):     # the buildings' long shadow
        for x in range(SW):
            if not (y == BOARDWALK + 4 and x % 4 == 3):
                P.put(x, y, G)
    vx, vy = 96, BOARDWALK                       # ruts toward the gap
    for bx in (-62, 2, 66, 126, 190, 254):
        for y in range(BOARDWALK + 6, H):
            t = (y - vy) / (H - vy)
            x = int(round(vx + (bx - vx) * t))
            if y % 4 != 0:
                P.put(x, y, R)
    for (cx2, cy2) in ((22, 53), (52, 54), (82, 52), (114, 53), (140, 51), (170, 54),
                       (92, 62), (130, 61), (60, 61), (12, 60), (180, 61)):
        for (dx, dy) in ((0, 0), (1, 0), (0, 1)):
            P.put(cx2 + dx, cy2 + dy, R)
    for x in range(0, SW, 2):
        P.put(x, 63, R)

    # ---------------------------------------------------------------- horse and props
    hx, hy = 140, 38
    for dx in range(0, 14):
        for dy in range(0, 5):
            if not (dx in (0, 13) and dy in (0, 4)):
                P.put(hx + dx, hy + dy, Y)
    for k in range(6):
        for o in (-1, 0, 1):
            P.put(hx + o - k // 2, hy - k, Y)
    for dx in range(-7, -2):
        P.put(hx + dx, hy - 6, Y); P.put(hx + dx, hy - 5, Y)
    P.put(hx - 7, hy - 4, Y)
    P.put(hx - 3, hy - 8, Y); P.put(hx - 3, hy - 7, Y)
    for k in range(6):
        P.put(hx + 1 + k // 2, hy - 6 + k, R)
    for lx in (1, 3, 10, 12):
        P.v(hx + lx, hy + 5, BOARDWALK + 4, Y)
    for k in range(7):
        P.put(hx + 14 + k // 3, hy + 1 + k, R)
    P.rect(hx + 5, hy, hx + 8, hy + 2, R)
    P.put(hx - 6, hy - 6, G)

    def barrel(x0, y0):
        for y in range(y0, y0 + 11):
            P.h(x0, x0 + 8, y, R)
        for y in (y0 + 2, y0 + 8):
            P.h(x0, x0 + 8, y, Y)
        P.h(x0 + 1, x0 + 7, y0, Y)
        P.v(x0 + 4, y0 + 3, y0 + 7, Y)
    barrel(32, 52)
    barrel(0, 50)
    # water trough below the hotel
    P.rect(150, 57, 167, 62, R)
    P.h(150, 167, 57, Y)
    P.h(152, 165, 58, B)
    P.v(152, 59, 62, Y); P.v(165, 59, 62, Y)
    # a wagon wheel leaning at the right end
    wx, wy = 184, 56
    for a in range(0, 360, 15):
        r = math.radians(a)
        P.put(wx + int(round(math.cos(r) * 6)), wy + int(round(math.sin(r) * 4)), R)
    for a in range(0, 180, 45):
        r = math.radians(a)
        for t in range(-5, 6):
            P.put(wx + int(round(math.cos(r) * t)), wy + int(round(math.sin(r) * t * 0.66)), R)
    return P


def to_bytes(P, rows):
    out = []
    for y in rows:
        for i in range(0, P.w, 4):
            b = 0
            for j in range(4):
                b = (b << 2) | P.p[y][i + j]
            out.append(b)
    return out


def asm(P):
    """stage.asm: rows 10-63, 48 bytes each"""
    d = to_bytes(P, range(10, 64))
    L = ['; generated by tools/stage.py - Main Street, 192 x 54 rows (10-63), 48 bytes a row',
         'STAGEW equ %d' % (SW // 4), 'SKYROWS equ %d' % SKYROWS, 'stage0:']
    for i in range(0, len(d), 16):
        L.append('        db ' + ','.join('$%02X' % b for b in d[i:i + 16]))
    return '\n'.join(L) + '\n'


if __name__ == '__main__':
    open(os.path.join(sys.argv[1], 'stage.asm'), 'w').write(asm(build()))
