#!/usr/bin/env python3
"""Real-pixel mock-ups of every world-tour stage: the 128x64 view at the
middle of the stage with the HUD and both fighters, in that stage's VZ
palette.  Also the whole 192-pixel stage.  Nearest-neighbour, x6 across x9
down (the 4:3 shape).  Usage: tourmock.py outdir"""
import os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import worldtour as wt
import mockup as mk

CSS = {
    0: {0: (0x07, 0xFF, 0x00), 1: (0xFF, 0xFF, 0x00), 2: (0x3B, 0x08, 0xFF), 3: (0xCC, 0x00, 0x3B)},
    1: {0: (0xFF, 0xFF, 0xFF), 1: (0x07, 0xE3, 0x99), 2: (0xFF, 0x1C, 0xFF), 3: (0xFF, 0x81, 0x00)},
}


def view(S, cam):
    P = mk.Pic()
    for y in range(64):
        for x in range(128):
            P.p[y][x] = S.p[y][x + (cam if y >= 17 else 32)]
    return P


def save(P, w, pal, fn, sx=6, sy=9):
    im = Image.new('RGB', (w, 64))
    for y in range(64):
        for x in range(w):
            im.putpixel((x, y), pal[P.p[y][x]])
    im.resize((w * sx, 64 * sy), Image.NEAREST).save(fn)
    return im


def shadow(P, x, y_air, colour):
    w = 9 - min(6, y_air // 4)
    for (dy, ww) in ((1, w - 2), (2, w), (3, w - 3)):
        for dx in range(-ww, ww + 1):
            P.put(x + dx, mk.GROUND + dy, colour)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    fl, du = mk.frames()
    tiles = []
    for (key, name, country, css, build, home) in wt.STAGES:
        S = build()
        pal = CSS[css]
        save(S, 192, pal, os.path.join(out, 'stage_%s_x6.png' % key))
        P = view(S, 32)
        mk.hud(P, names=('FLICK', 'DUSTY'), hp=(70, 40), time=54, wins=(1, 0))
        # shadows: index 0 on a yellow street (CSS0), index 1 on a pale one (CSS1)
        sc = 0 if css == 0 else 1
        shadow(P, 40, 0, sc)
        shadow(P, 86, 0, sc)
        mk.sprite(P, fl['IDLE'], 40, False, 2)
        mk.sprite(P, du['IDLE'], 86, True, 3)
        im = save(P, 128, pal, os.path.join(out, 'tour_%s_x6.png' % key))
        tiles.append((name, country, im))
    # a contact sheet: 4 x 2 at x3 / x4.5
    tw, th = 128 * 3, int(64 * 4.5)
    sheet = Image.new('RGB', (tw * 4 + 30, (th + 20) * 2 + 10), (24, 24, 24))
    for i, (name, country, im) in enumerate(tiles):
        x = (i % 4) * (tw + 10)
        y = (i // 4) * (th + 20)
        sheet.paste(im.resize((tw, th), Image.NEAREST), (x, y))
    sheet.save(os.path.join(out, 'world_tour_sheet.png'))


if __name__ == '__main__':
    main()
