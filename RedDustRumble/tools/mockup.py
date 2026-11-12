#!/usr/bin/env python3
"""RED DUST RUMBLE arena mock-up: the exact 128x64 Mode 1 picture.

Builds the Main Street backdrop, then composites the HUD, the fighters' real
frames and their shadows the way the game draws them.  Writes:
  mockup_1x.png        128x64, one pixel per VZ pixel
  mockup_x6.png        768x576 (x6 across, x9 down: the 4:3 screen shape),
                       nearest-neighbour, no other colours
  mockup_bg_x6.png     the backdrop alone
  mockup_ko_x6.png     a second moment: a knock-down near the saloon
Palette: the MC6847 CSS0 colours as MAME renders them.
"""
import sys, os, math
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import art

G, Y, B, R = 0, 1, 2, 3
PAL = {G: (0x07, 0xFF, 0x00), Y: (0xFF, 0xFF, 0x00), B: (0x3B, 0x08, 0xFF), R: (0xCC, 0x00, 0x3B)}
W, H = 128, 64
GROUND = 58


class Pic:
    def __init__(self):
        self.p = [[G] * W for _ in range(H)]

    def put(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.p[y][x] = c

    def get(self, x, y):
        return self.p[y][x] if 0 <= x < W and 0 <= y < H else None

    def h(self, x0, x1, y, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, c)

    def v(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            self.h(x0, x1, y, c)


BOARDWALK = 46      # front edge of the far boardwalk; the street starts below


def backdrop():
    """Layers, back to front: dusk sky and sun; blue mesas; the windmill;
    the far side of Main Street (green false fronts with yellow structure,
    which is what sits behind the fighters' bodies); the street; props.
    Blue and red masses stay above head height (the sky) or at the edges."""
    P = Pic()
    P.rect(0, 0, 127, 9, B)                      # HUD band

    # ------------------------------------------------------------ sky
    # blue dusk -> red -> yellow glow in clean horizontal bands
    bands = {10: B, 11: B, 12: B, 13: R, 14: B, 15: R, 16: R, 17: Y, 18: R}
    for y in range(19, 27):
        bands[y] = Y
    for y, c in bands.items():
        P.h(0, 127, y, c)
    for (x, y) in ((40, 11), (77, 10), (99, 12), (23, 12), (60, 11), (118, 11)):
        P.put(x, y, Y)                           # first stars
    # the vista between the store and the bank: the sun setting onto one
    # long flat-topped mesa
    for y in range(15, 24):
        for x in range(50, 79):
            if (x + 0.5 - 64) ** 2 + ((y + 0.5 - 23) * 1.5) ** 2 < 110:
                P.put(x, y, Y if y in (19, 21) else R)
    for y in range(23, 28):
        k = y - 23
        P.h(44 - k * 3, 84 + k * 3, y, G)
        P.put(44 - k * 3, y, R)
        P.put(84 + k * 3, y, R)
    P.h(44, 84, 23, R)                           # sunset on the cap rock
    for x in range(47, 82, 4):
        P.put(x, 25, R)                          # one ledge of strata
    # windmill behind the town, on the right
    for y in range(16, 27):
        P.put(108 - (y - 16) // 6, y, B)
        P.put(112 + (y - 16) // 6, y, B)
    cx, cy = 110, 13
    for a in range(0, 360, 45):
        r = math.radians(a + 22.5)
        for t in range(2, 5):
            P.put(cx + int(round(math.cos(r) * t)), cy + int(round(math.sin(r) * t / 1.5)), Y)
    P.put(cx, cy, R)

    # ------------------------------------------------------------ the far side of Main Street
    # (x0, x1, roof row, kind)
    town = [(0, 27, 18, 'saloon'), (28, 45, 27, 'store'), (46, 54, 30, 'shack'),
            (74, 82, 30, 'shack'), (83, 101, 24, 'bank'), (102, 127, 21, 'hotel')]
    for (x0, x1, top, kind) in town:
        P.rect(x0, top, x1, BOARDWALK - 1, G)
        P.h(x0, x1, top, R)                      # cornice, dark against the glow
        P.h(x0, x1, top + 1, Y)
        P.v(x1, top, BOARDWALK - 1, Y if kind != 'shack' else G)
    # gap in the middle: the street runs away between the buildings, so the
    # sun and sky show through; a low fence closes it off
    P.h(55, 73, 40, Y)
    for x in (56, 62, 68, 73):
        P.v(x, 38, BOARDWALK - 1, Y)

    def window(x, y, w=4, h=5):
        P.rect(x, y, x + w - 1, y + h - 1, B)
        P.h(x - 1, x + w, y - 1, Y)
        P.h(x - 1, x + w, y + h, Y)
    def sign(x0, x1, y):
        P.rect(x0, y, x1, y + 4, Y)
        for x in range(x0 + 2, x1 - 1, 2):
            if (x // 2) % 3:
                P.put(x, y + 2, R)

    # saloon: tall false front, the name, awning, batwing doors
    P.rect(0, 18, 27, 27, B)                     # false front
    P.h(0, 27, 18, R)
    P.rect(1, 20, 26, 26, Y)
    for i, ch in enumerate('SALOON'):
        for ry, row in enumerate(art.FONT[ch]):
            for rx, c in enumerate(row):
                if c == '#':
                    P.put(2 + i * 4 + rx, 21 + ry, R)
    window(3, 28, 4, 4); window(11, 28, 4, 4); window(19, 28, 4, 4)
    for y in (33, 34):
        for x in range(0, 28):
            P.put(x, y, R if (x // 2) % 2 == 0 else Y)
    for x in range(0, 28, 4):
        P.put(x, 35, R)
    for x in (1, 13, 26):
        P.v(x, 35, BOARDWALK - 1, Y)
    P.rect(16, 38, 23, BOARDWALK - 1, B)
    P.rect(16, 39, 18, 43, Y); P.rect(21, 39, 23, 43, Y)
    # general store
    sign(30, 43, 28)
    window(32, 36); window(39, 36)
    P.h(28, 45, 34, Y)
    # shacks either side of the gap
    window(48, 34, 3, 4); window(76, 34, 3, 4)
    # bank: pediment, columns
    for k in range(3):
        P.h(87 + k * 2, 97 - k * 2, 23 - k, B)
    sign(86, 98, 26)
    for x in (86, 90, 94, 98):
        P.v(x, 33, BOARDWALK - 1, Y)
    P.rect(91, 37, 93, BOARDWALK - 1, B)
    # hotel: two storeys, balcony
    window(105, 25); window(112, 25); window(119, 25)
    P.h(102, 127, 32, Y)
    for x in range(103, 127, 3):
        P.v(x, 32, 33, Y)
    P.h(102, 127, 34, Y)
    P.v(102, 35, BOARDWALK - 1, Y)
    # the far boardwalk
    P.h(0, 127, BOARDWALK, Y)
    P.h(0, 127, BOARDWALK + 1, R)

    # ------------------------------------------------------------ the street
    for y in range(BOARDWALK + 2, H):
        P.h(0, 127, y, Y)
    # the buildings' long shadow, ruled
    for y in (BOARDWALK + 2, BOARDWALK + 4):
        for x in range(W):
            if not (y == BOARDWALK + 4 and x % 4 == 3):
                P.put(x, y, G)
    # ruts converging toward the gap in the middle
    vx, vy = 64, BOARDWALK
    for bx in (-30, 34, 94, 158):
        for y in range(BOARDWALK + 6, H):
            t = (y - vy) / (H - vy)
            x = int(round(vx + (bx - vx) * t))
            if y % 4 != 0:
                P.put(x, y, R)
    for (cx, cy) in ((20, 54), (50, 52), (82, 53), (108, 51), (60, 62), (98, 61)):
        for (dx, dy) in ((0, 0), (1, 0), (0, 1)):
            P.put(cx + dx, cy + dy, R)
    for x in range(0, W, 2):
        P.put(x, 63, R)

    # ------------------------------------------------------------ horse and props
    hx, hy = 108, 38
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
    # foreground: barrel at the left, trough at the right
    for y in range(52, 63):
        P.h(0, 8, y, R)
    for y in (54, 60):
        P.h(0, 8, y, Y)
    P.h(1, 7, 52, Y)
    P.v(4, 55, 59, Y)
    P.rect(110, 57, 127, 62, R)
    P.h(110, 127, 57, Y)
    P.h(112, 127, 58, B)
    P.v(112, 59, 62, Y); P.v(125, 59, 62, Y)
    return P


# ---------------------------------------------------------------- HUD
def hud(P, names=('FLICK', 'DUSTY'), hp=(70, 40), time=54, wins=(1, 0)):
    def text(s, x, y, c, scale=1):
        for i, ch in enumerate(s):
            g = art.FONT.get(ch, art.FONT['?'])
            for ry, row in enumerate(g):
                for rx, cc in enumerate(row):
                    if cc == '#':
                        for sy in range(scale):
                            for sx in range(scale):
                                P.put(x + (i * 4 + rx) * scale + sx, y + ry * scale + sy, c)
    text(names[0], 4, 0, Y)
    text(names[1], 124 - len(names[1]) * 4, 0, Y)
    # round pips: yellow when won, a green slot when not
    for k, x in enumerate((32, 36)):
        P.rect(x, 1, x + 2, 3, Y if wins[0] > k else G)
    for k, x in enumerate((92, 88)):
        P.rect(x, 1, x + 2, 3, Y if wins[1] > k else G)
    # bars: rows 6-9, yellow frame, yellow health anchored at the centre, red lost
    def bar(x0, health, centre_right):
        P.h(x0, x0 + 47, 6, Y)
        P.h(x0, x0 + 47, 9, Y)
        L = (health + 1) // 2
        for i in range(48):
            filled = (i >= 48 - L) if centre_right else (i < L)
            c = Y if (filled or i in (0, 47)) else R
            P.put(x0 + i, 7, c)
            P.put(x0 + i, 8, c)
    bar(4, hp[0], True)
    bar(76, hp[1], False)
    text('%02d' % time, 56, 0, Y, 2)


# ---------------------------------------------------------------- fighters
def frames():
    fl = art.fighter_frames(art.FLICK, art.flick_poses(), art.draw_flick)
    du = art.fighter_frames(art.DUSTY, art.dusty_poses(), art.draw_dusty)
    return {f['name']: f for f in fl}, {f['name']: f for f in du}


def shadow(P, x, y_air):
    """a small green ellipse on the street, narrower when airborne"""
    w = 9 - min(6, y_air // 3)
    for (dy, ww) in ((1, w - 2), (2, w), (3, w - 3)):
        for dx in range(-ww, ww + 1):
            if P.get(x + dx, GROUND + dy) in (Y, R):
                P.put(x + dx, GROUND + dy, G)


def sprite(P, fr, x, face_left, colour, y_air=0):
    rows, ax, wb = fr['rows'], fr['ax'], fr['wb']
    bottom = GROUND + fr['below'] - y_air
    top = bottom - fr['h'] + 1
    for r, row in enumerate(rows):
        for c, v in enumerate(row):
            if not v:
                continue
            if v == 2:
                v = colour
            sx = x - ax + c if not face_left else x + ax - c
            P.put(sx, top + r, v)


def save(P, name, out):
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W):
            im.putpixel((x, y), PAL[P.p[y][x]])
    if name.endswith('_1x'):
        im.save(os.path.join(out, name + '.png'))
    else:
        im.resize((W * 6, H * 9), Image.NEAREST).save(os.path.join(out, name + '.png'))
    return im


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else '.'
    fl, du = frames()
    bg = backdrop()
    save(bg, 'mockup_bg_x6', out)
    # moment 1: squaring off
    P = backdrop()
    hud(P)
    shadow(P, 40, 0)
    shadow(P, 86, 0)
    sprite(P, fl['IDLE'], 40, False, B)
    sprite(P, du['IDLE'], 86, True, R)
    save(P, 'mockup_x6', out)
    save(P, 'mockup_1x', out)
    # moment 2: Flick's jump kick over Dusty's crouch
    P = backdrop()
    hud(P, hp=(52, 30), time=37, wins=(1, 1))
    shadow(P, 58, 14)
    shadow(P, 78, 0)
    sprite(P, du['CBLOCK'], 78, True, R)
    sprite(P, fl['JB'], 58, False, B, y_air=14)
    save(P, 'mockup_air_x6', out)
    # moment 3: Dusty knocked down by the saloon, Flick near the trough
    P = backdrop()
    hud(P, hp=(20, 0), time=12, wins=(1, 1))
    shadow(P, 30, 0)
    shadow(P, 60, 0)
    sprite(P, du['DOWN'], 30, False, R)
    sprite(P, fl['WIN'], 60, True, B)
    save(P, 'mockup_ko_x6', out)


if __name__ == '__main__':
    main()
