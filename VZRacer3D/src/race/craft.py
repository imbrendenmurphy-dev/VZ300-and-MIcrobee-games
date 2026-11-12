#!/usr/bin/env python3
"""
craft.py - hovercraft sprite frames for the VZ300 3D racer (VIBED BY BPM 2026)

Five viewing angles (-2 hard left .. +2 hard right), 24 x 10 pixels, built
from simple 3D-ish rules so the nose, canopy, side panel, tail lights and
hover pads all shift with the craft's yaw: you see its flank come round as it
turns, rather than the whole sprite sliding or shearing.

Colour set 0: 0 green, 1 yellow, 2 blue (dark body), 3 red. '.' = transparent.
Dithered areas (side panels, hover pads, skirt) alternate two colours per
pixel, like the dithered wheels in the reference shots.
"""
W, H = 24, 10

def frame(yaw):
    g = [['.'] * W for _ in range(H)]
    cx = 12
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H: g[y][x] = c
    def dith(x, y, a, b):
        put(x, y, a if (x + y) & 1 == 0 else b)
    # hull: wide trapezoid, rows 2..7 ; turning shifts the top (rear deck) toward the turn
    for y in range(2, 8):
        half = 7 + min(y - 2, 3)                 # 7..10
        shift = (yaw * (7 - y)) // 3             # upper rows lean further into the turn
        for x in range(cx - half + shift, cx + half + shift):
            put(x, y, '2')
    # side panel we can see as it yaws: dithered blue/green flank on the outside of the turn
    if yaw:
        side = -1 if yaw > 0 else 1              # turning right shows the left flank
        width = 2 * abs(yaw)
        for y in range(3, 8):
            half = 7 + min(y - 2, 3)
            shift = (yaw * (7 - y)) // 3
            edge = cx - half + shift if side < 0 else cx + half + shift - 1
            for k in range(width):
                dith(edge + side * (k + 1) * 1 - (side < 0 and 0), y, '2', '0')
    # canopy: narrow dome on rows 0..2, displaced furthest (it is highest)
    cs = yaw * 2
    for y, half in ((0, 3), (1, 5), (2, 6)):
        for x in range(cx - half + cs, cx + half + cs):
            put(x, y, '2')
    for x in range(cx - 3 + cs, cx + 3 + cs):     # canopy glint
        dith(x, 1, '2', '0')
    # tail lights: the near light keeps its width, the far one narrows with yaw
    ls = (yaw * 3) // 2
    lw_left = 4 - (1 if yaw < 0 else 0) * min(2, -yaw)
    lw_right = 4 - (1 if yaw > 0 else 0) * min(2, yaw)
    for y in (4, 5):
        for k in range(lw_left): put(cx - 8 + ls + k, y, '3')
        for k in range(lw_right): put(cx + 4 + ls + (4 - lw_right) + k, y, '3')
    # thruster glow
    for x in range(cx - 3 + ls, cx + 3 + ls): put(x, 6, '1')
    # hover pads (dithered, like wheels) and skirt between them
    ps = yaw
    for y in (8, 9):
        for x in range(cx - 10 + ps, cx - 5 + ps): dith(x, y, '2', '0')
        for x in range(cx + 5 + ps, cx + 10 + ps): dith(x, y, '2', '0')
    for x in range(cx - 5 + ps, cx + 5 + ps): dith(x, 8, '2', '3' if yaw == 0 else '2')
    return [''.join(r) for r in g]

FRAMES = [frame(y) for y in (-2, -1, 0, 1, 2)]

def sprite_bytes():
    """For each frame and each pre-shift 0..3: 10 rows x 7 bytes of (mask, data)."""
    out = []
    for fr in FRAMES:
        for sh in range(4):
            for row in fr:
                px = ['.'] * sh + list(row) + ['.'] * (28 - sh - len(row))
                for b in range(7):
                    mask = data = 0
                    for q in range(4):
                        ch = px[b * 4 + q]; s = 6 - 2 * q
                        if ch == '.': mask |= 3 << s
                        else: data |= int(ch) << s
                    out += [mask, data]
    return out          # 5 frames x 4 shifts x 140 bytes

if __name__ == '__main__':
    from PIL import Image
    CSS0 = [(40, 205, 40), (235, 235, 70), (45, 35, 205), (205, 30, 60)]
    sheet = Image.new('RGB', (5 * 30, 12), (120, 120, 120))
    for i, fr in enumerate(FRAMES):
        for y, row in enumerate(fr):
            for x, ch in enumerate(row):
                if ch != '.': sheet.putpixel((i * 30 + 3 + x, 1 + y), CSS0[int(ch)])
    sheet.resize((5 * 30 * 8, 12 * 12), Image.NEAREST).save('craft_frames.png')
    for fr in FRAMES:
        print('\n'.join(fr)); print()
