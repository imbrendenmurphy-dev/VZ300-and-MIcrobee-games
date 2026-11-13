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


import stage


def backdrop(cam=32):
    """the 128-wide view of the stage at camera position cam (pixels);
    rows 10-16 (the still sky) always come from cam 32"""
    S = stage.build()
    P = Pic()
    for y in range(H):
        for x in range(W):
            P.p[y][x] = S.p[y][x + (cam if y >= stage.SKYROWS else 32)]
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
    save(backdrop(32), 'mockup_bg_x6', out)
    # the whole stage
    S = stage.build()
    im = Image.new('RGB', (stage.SW, H))
    for y in range(H):
        for x in range(stage.SW):
            im.putpixel((x, y), PAL[S.p[y][x]])
    im.resize((stage.SW * 6, H * 9), Image.NEAREST).save(os.path.join(out, 'stage_x6.png'))
    # squaring off in the middle
    P = backdrop(32)
    hud(P)
    shadow(P, 40, 0)
    shadow(P, 86, 0)
    sprite(P, fl['IDLE'], 40, False, B)
    sprite(P, du['IDLE'], 86, True, R)
    save(P, 'mockup_x6', out)
    save(P, 'mockup_1x', out)
    # pushed to the left end
    P = backdrop(0)
    hud(P, hp=(52, 30), time=37, wins=(1, 1))
    shadow(P, 30, 0)
    shadow(P, 66, 14)
    sprite(P, du['CBLOCK'], 30, False, R)
    sprite(P, fl['JB'], 66, True, B, y_air=14)
    save(P, 'mockup_left_x6', out)
    # pushed to the right end
    P = backdrop(64)
    hud(P, hp=(20, 0), time=12, wins=(1, 1))
    shadow(P, 70, 0)
    shadow(P, 100, 0)
    sprite(P, du['DOWN'], 100, True, R)
    sprite(P, fl['WIN'], 70, False, B)
    save(P, 'mockup_right_x6', out)


if __name__ == '__main__':
    main()
