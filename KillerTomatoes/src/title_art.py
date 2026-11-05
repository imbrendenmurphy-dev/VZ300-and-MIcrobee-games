#!/usr/bin/env python3
# Pre-renders the title screen's giant tomato + face variants (CSS0: 0 green 1 yellow 2 blue 3 red)
import os, math
W, H = 128, 64
def blank():
    return [[2] * W for _ in range(H)]
def body(img):
    cx, cy, rx, ry = 64, 66, 32, 25
    for y in range(38, 64):
        for x in range(W):
            d = ((x - cx + 0.5) / rx) ** 2 + ((y - cy + 0.5) / ry) ** 2
            if d <= 1.0:
                img[y][x] = 3
    # lobes: slight dents at top
    for x in (52, 76):
        for y in range(41, 44):
            if img[y][x] == 3 and img[y - 1][x] == 2: img[y][x] = 2
    # shine
    for (x, y) in [(44, 46), (45, 46), (43, 47), (44, 47), (42, 48), (43, 49), (41, 51)]:
        img[y][x] = 1
    # calyx / leaves (green)
    leaves = ["....g.......g....",
              ".gg.gg..g..gg.gg.",
              "..ggggggggggggg..",
              "....gg.ggg.gg....",]
    for r, row in enumerate(leaves):
        for c, p in enumerate(row):
            if p == 'g': img[39 + r][56 + c] = 0
    for y in range(38, 40):
        img[y][64] = 0; img[y][65] = 0
def eyes(img, look, blink):
    for ex in (44, 75):
        # brow (angry, slanting toward centre)
        for i in range(9):
            yy = 46 + (i * 2) // 9 if ex < 64 else 47 - (i * 2) // 9
            img[yy][ex + i] = 2
        for y in range(48, 53):
            for x in range(ex, ex + 9):
                edge = (y in (48, 52)) and (x in (ex, ex + 8))
                img[y][x] = 3 if edge else (3 if blink else 1)
        if blink:
            for x in range(ex + 1, ex + 8): img[50][x] = 2
        else:
            px = ex + 1 + look * 2
            for y in range(49, 52):
                for x in range(px, px + 3):
                    img[y][x] = 2
            img[49][px] = 1   # glint
def mouth(img, openm):
    for y in range(55, 62):
        for x in range(49, 79):
            img[y][x] = 3
    top, bot = (56, 61) if openm else (57, 60)
    for y in range(top, bot):
        for x in range(51, 77):
            img[y][x] = 2
    # teeth: jagged yellow
    for x in range(51, 77):
        if (x // 2) % 2 == 0:
            img[top][x] = 1
            if openm: img[top + 1][x] = 1 if (x % 2 == 0) else img[top + 1][x]
        if (x // 2) % 2 == 1:
            img[bot - 1][x] = 1
    if openm:
        for x in range(60, 68): img[59][x] = 3; img[60][x] = 3   # tongue
def tobytes(img, bx, by, bw, bh):
    out = []
    for y in range(by, by + bh):
        for b in range(bx, bx + bw):
            v = 0
            for p in range(4):
                v = (v << 2) | img[y][b * 4 + p]
            out.append(v)
    return out
def db(lab, data):
    s = [lab + ':']
    for i in range(0, len(data), 16):
        s.append('        db ' + ','.join('$%02X' % v for v in data[i:i + 16]))
    return s
L = []
base = blank(); body(base); eyes(base, 1, False); mouth(base, False)
TOMX, TOMY, TOMW, TOMH = 8, 38, 16, 26
L += ['TOMX equ %d' % TOMX, 'TOMY equ %d' % TOMY, 'TOMW equ %d' % TOMW, 'TOMH equ %d' % TOMH]
L += db('tom_base', tobytes(base, TOMX, TOMY, TOMW, TOMH))
EX, EY, EW, EH = 11, 46, 11, 7
L += ['EYEX equ %d' % EX, 'EYEY equ %d' % EY, 'EYEW equ %d' % EW, 'EYEH equ %d' % EH]
ev = []
for look, blink in [(0, False), (1, False), (2, False), (1, True)]:
    img = blank(); body(img); eyes(img, look, blink)
    ev += tobytes(img, EX, EY, EW, EH)
L += db('tom_eyes', ev)
MX, MY, MW, MH = 12, 55, 8, 7
L += ['MOUX equ %d' % MX, 'MOUY equ %d' % MY, 'MOUW equ %d' % MW, 'MOUH equ %d' % MH]
for i, o in enumerate([False, True]):
    img = blank(); body(img); mouth(img, o)
    L += db('tom_mouth%d' % i, tobytes(img, MX, MY, MW, MH))
open(os.path.join(os.path.dirname(__file__), '..', 'src', 'gen_title.inc'), 'w').write('\n'.join(L) + '\n')
# preview
from PIL import Image
pal = [(0, 200, 0), (255, 255, 0), (0, 0, 255), (255, 0, 0)]
im = Image.new('RGB', (W * 2, H * 3))
for y in range(H):
    for x in range(W):
        for dy in range(3):
            for dx in range(2): im.putpixel((x * 2 + dx, y * 3 + dy), pal[base[y][x]])
pv = os.path.join(os.path.dirname(__file__), 'build')
os.makedirs(pv, exist_ok=True)
im.save(os.path.join(pv, 'title_tomato_preview.png'))
print('ok')
