#!/usr/bin/env python3
"""GYRUVZ front-end pictures: the title (logo) and three comic-book panels of
game action, plus the border for the text screens.  Drawn on the real mode(1)
grid: 128x64, 4 colours, pixels a third taller than wide (4:3 screen).
Colours: 0 green, 1 yellow, 2 blue, 3 red.  All art original.
Writes pics/<name>.lz for the build and pics/<name>.png previews.
"""
import math
import os
import random
import sys

from PIL import Image

import bigfont
import gfx
import lz
import ship
from font3 import F3

G, Y, B, R = 0, 1, 2, 3
RGB = {0: (40, 200, 40), 1: (240, 240, 60), 2: (40, 40, 220), 3: (220, 40, 40)}
W, H = 128, 64


class Pic:
    def __init__(self, bg=B):
        self.p = [[bg] * W for _ in range(H)]

    def put(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < W and 0 <= y < H and c is not None:
            self.p[y][x] = c

    def get(self, x, y):
        return self.p[y][x] if 0 <= x < W and 0 <= y < H else None

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def line(self, x0, y0, x1, y1, c, w=1):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            for d in range(w):
                self.put(x + d, y, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(max(0, int(min(ys))), min(H, int(max(ys)) + 1)):
            xs = []
            for i in range(len(pts)):
                (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % len(pts)]
                if (y0 <= y + 0.5 < y1) or (y1 <= y + 0.5 < y0):
                    xs.append(x0 + (y + 0.5 - y0) * (x1 - x0) / (y1 - y0))
            xs.sort()
            for a, b in zip(xs[::2], xs[1::2]):
                for x in range(int(math.ceil(a - 0.5)), int(math.floor(b - 0.5)) + 1):
                    self.put(x, y, c)

    def burst(self, cx, cy, r_out, r_in, n, c, wobble=0.0, seed=1):
        rnd = random.Random(seed)
        pts = []
        for i in range(n * 2):
            a = math.pi * i / n
            r = (r_out if i % 2 == 0 else r_in) * (1 + rnd.uniform(-wobble, wobble))
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a) * 2 / 3))
        self.poly(pts, c)

    def ellipse(self, cx, cy, rx, c, fill=True):
        ry = rx * 2 / 3
        for y in range(H):
            for x in range(W):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if (fill and d <= 1) or (not fill and 0.82 <= d <= 1.0):
                    self.put(x, y, c)

    def sprite(self, rows, x0, y0, k=1, ky=None, outline=None):
        ky = ky or k
        if outline is not None:
            cells = set()
            for y, row in enumerate(rows):
                for x, v in enumerate(row):
                    if v is not None:
                        for yy in range(ky):
                            for xx in range(k):
                                cells.add((x0 + x * k + xx, y0 + y * ky + yy))
            for (cx, cy) in cells:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        if (cx + dx, cy + dy) not in cells:
                            self.put(cx + dx, cy + dy, outline)
        for y, row in enumerate(rows):
            for x, v in enumerate(row):
                if v is not None:
                    self.rect(x0 + x * k, y0 + y * ky, x0 + x * k + k - 1, y0 + y * ky + ky - 1, v)

    def text3(self, s, x, y, c):
        for ch in s:
            g = F3.get(ch, F3['?'])
            for yy, row in enumerate(g):
                for xx in range(3):
                    if row[xx] == '#':
                        self.put(x + xx, y + yy, c)
            x += 4

    def text3c(self, s, y, c):
        self.text3(s, (W - len(s) * 4 + 1) // 2, y, c)

    def big(self, s, x, y, k=1, ky=1, top=Y, low=R, outline=G, shade=None, slant=0.0):
        """the big font, k x ky per pixel, outlined, yellow top fading to low"""
        cells = set()
        cx = x
        for ch in s:
            rows = bigfont.G.get(ch, bigfont.G['?'])
            for gy, row in enumerate(rows):
                for gx, cch in enumerate(row):
                    if cch == '#':
                        for dy in range(ky):
                            for dx in range(k):
                                yy = y + gy * ky + dy
                                sh = int(round(slant * (y + 8 * ky - yy)))
                                cells.add((cx + gx * k + dx + sh, yy))
            cx += 8 * k
        hgt = 8 * ky
        if outline is not None:
            for (px, py) in cells:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        if (px + dx, py + dy) not in cells:
                            self.put(px + dx, py + dy, outline)
        for (px, py) in cells:
            t = (py - y) / hgt
            if t < 0.42:
                c = top
            elif t < 0.55:
                c = top if (px + py) % 2 else low
            else:
                c = low
            self.put(px, py, c)
        return cx

    def stars(self, n, seed, avoid=None, cols=(Y, G, G)):
        rnd = random.Random(seed)
        for i in range(n):
            x, y = rnd.randrange(W), rnd.randrange(H)
            if avoid and avoid(x, y):
                continue
            if self.get(x, y) == B:
                self.put(x, y, rnd.choice(cols))

    def halftone(self, x0, y0, x1, y1, c, step=3):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if y % 2 == 0 and (x + (y // 2) * 2) % step == 0 and self.get(x, y) == B:
                    self.put(x, y, c)

    def speedlines(self, cx, cy, n, r0, c, seed=3):
        rnd = random.Random(seed)
        for i in range(n):
            a = 2 * math.pi * i / n + rnd.uniform(-0.05, 0.05)
            r1 = r0 + rnd.uniform(10, 30)
            self.line(cx + r0 * math.cos(a), cy + r0 * math.sin(a) * 2 / 3,
                      cx + 200 * math.cos(a), cy + 200 * math.sin(a) * 2 / 3, c)

    def border(self, c=G):
        for x in range(W):
            self.put(x, 0, c)
            self.put(x, H - 1, c)
        for y in range(H):
            self.put(0, y, c)
            self.put(W - 1, y, c)

    def caption(self, s, x, y, bg=Y, fg=R):
        w = len(s) * 4 + 3
        self.rect(x, y, x + w - 1, y + 7, bg)
        self.rect(x + 1, y + 8, x + w, y + 8, G)
        self.rect(x + w, y + 1, x + w, y + 8, G)
        self.text3(s, x + 2, y + 2, fg)

    def balloon(self, s, x, y, tx, ty):
        w = len(s) * 4 + 5
        self.ellipse(x + w / 2, y + 4, w / 2 + 3, Y)
        self.poly([(x + w / 2 - 3, y + 8), (x + w / 2 + 3, y + 8), (tx, ty)], Y)
        self.text3(s, x + 3, y + 2, R)

    def vz_bytes(self):
        out = []
        for y in range(H):
            for b in range(W // 4):
                v = 0
                for i in range(4):
                    v = (v << 2) | self.p[y][b * 4 + i]
                out.append(v)
        return bytes(out)

    def png(self, path):
        im = Image.new('RGB', (W * 4, H * 6))
        px = im.load()
        for y in range(H):
            for x in range(W):
                c = RGB[self.p[y][x]]
                for dy in range(6):
                    for dx in range(4):
                        px[x * 4 + dx, y * 6 + dy] = c
        im.save(path)


BIGSHIP = gfx.parse("""
......y......
.....yry.....
.....yry.....
....yyryy....
...yyyryyy...
..yyyyyyyyy..
.ryyyyyyyyyr.
rryyyygyyyyrr
rr.yyg.gyy.rr
r..r..g..r..r
....r...r....
""")


def sprite_rows(name):
    for n, px in gfx.FRAMES:
        if n == name:
            return px
    raise KeyError(name)


# ------------------------------------------------------------------ logo
LOGO = {
'G': [".####", "#....", "#.###", "#...#", ".###."],
'Y': ["#...#", "#...#", ".###.", "..#..", "..#.."],
'R': ["####.", "#...#", "####.", "#..#.", "#...#"],
'U': ["#...#", "#...#", "#...#", "#...#", ".###."],
'V': ["#...#", "#...#", "#...#", ".#.#.", "..#.."],
'Z': ["#####", "...#.", "..#..", ".#...", "#####"],
}


def logo(p, word, x0, y0, bw=3, bh=4, gap=3):
    """chunky italic chrome letters: blocks bw x bh, slanted, outlined"""
    cells = set()
    x = x0
    hgt = 5 * bh
    for ch in word:
        for gy, row in enumerate(LOGO[ch]):
            for gx, c in enumerate(row):
                if c != '#':
                    continue
                for dy in range(bh):
                    yy = y0 + gy * bh + dy
                    sh = (hgt - 1 - (yy - y0)) // 5
                    for dx in range(bw):
                        cells.add((x + gx * bw + dx + sh, yy))
        x += 5 * bw + gap
    # a green outline with a deeper shadow down-right, then the chrome
    for (cx, cy) in cells:
        for dx in (-1, 0, 1, 2):
            for dy in (-1, 0, 1, 2):
                if (dx in (-1, 2) or dy in (-1, 2)) and (cx + dx, cy + dy) not in cells:
                    if dx >= 0 and dy >= 0 or (abs(dx) <= 1 and abs(dy) <= 1):
                        p.put(cx + dx, cy + dy, G)
    for (cx, cy) in cells:
        r = cy - y0
        if r < 8:
            c = Y
        elif r < 10:
            c = Y if (cx + cy) % 2 else R
        else:
            c = R
        if r >= 10 and (cx - 1, cy) not in cells:
            c = Y                         # a lit left edge on the red
        p.put(cx, cy, c)
    return x


def title():
    p = Pic()
    # the storm: a dotted orbit ring and stars streaming out of the eye
    cx, cy = 64, 40
    p.stars(80, 7, avoid=lambda x, y: 26 <= y <= 56 and 14 <= x <= 114)
    for i in range(72):
        a = 2 * math.pi * i / 72
        if i % 3:
            p.put(cx + 60 * math.cos(a), cy + 22 * math.sin(a), G)
    logo(p, "GYRUVZ", 8, 3)
    p.text3c("THE STORM AT THE CORE", 26, G)
    # a ship on the orbit, bottom centre, and a swarm either side
    p.sprite(sprite_rows('SHIP0'), 60, 57)
    p.sprite(sprite_rows('MOTH_4'), 2, 36, 2, 2)
    p.sprite(sprite_rows('HORNET_4'), 111, 36, 2, 2)
    p.text3("VIBED BY", 2, 58, G)
    p.text3("BPM 2026", 95, 58, G)
    return p


def comic1():
    """ZAP!  the ship fires up-screen into a moth, which bursts"""
    p = Pic()
    p.speedlines(96, 22, 11, 22, Y, 5)
    p.burst(96, 22, 30, 15, 11, R, 0.15, 3)
    p.burst(96, 22, 19, 10, 9, Y, 0.2, 4)
    # twin beams from the ship's nose to the moth
    p.line(25, 36, 86, 24, R, 2)
    p.line(27, 38, 88, 26, Y, 1)
    p.sprite(sprite_rows('MOTH_4'), 82, 14, 4, 4, outline=B)
    p.sprite(BIGSHIP, 6, 34, 3, 2, outline=B)
    p.big("ZAP!", 4, 3, 2, 2, Y, R, G, slant=0.2)
    p.caption("OUT ON THE RIM...", 58, 53)
    p.border()
    return p


def comic2():
    """KA-BOOM!  a boss goes up"""
    p = Pic()
    p.speedlines(64, 30, 16, 6, G, 9)
    p.burst(64, 30, 54, 30, 13, R, 0.25, 11)
    p.burst(64, 30, 38, 22, 11, Y, 0.25, 12)
    p.burst(64, 30, 22, 14, 9, R, 0.3, 13)
    p.sprite(sprite_rows('BWARDEN_C'), 38, 12, 4, 4, outline=B)
    rnd = random.Random(5)
    for i in range(26):     # debris
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(32, 60)
        x, y = 64 + r * math.cos(a), 30 + r * math.sin(a) * 2 / 3
        p.rect(int(x), int(y), int(x) + 1, int(y), rnd.choice([Y, R, G]))
    p.big("KA-BOOM!", 1, 46, 2, 2, Y, R, G, slant=0.15)
    p.caption("THE WARDEN FALLS!", 2, 2)
    p.border()
    return p


def comic3():
    """INCOMING!  the swarm spirals out of the eye straight at you"""
    p = Pic()
    p.speedlines(64, 30, 12, 12, G, 21)
    p.ellipse(64, 30, 9, R)
    p.ellipse(64, 30, 5, Y)
    kinds = ['GLINT', 'MOTH', 'HORNET', 'SPIN', 'MOTH', 'HORNET', 'GLINT']
    for i in range(7):
        t = i / 6
        a = 2.2 * math.pi * t + 2.2
        r = 12 + 46 * t
        k = 1 if t < 0.2 else (2 if t < 0.6 else 3)
        name = '%s_%d' % (kinds[i], 4)
        rows = sprite_rows(name)
        x = 64 + r * math.cos(a) - len(rows[0]) * k / 2
        y = 30 + r * math.sin(a) * 0.55 - len(rows) * k / 2
        p.sprite(rows, int(x), int(y), k, k, outline=B)
    p.big("INCOMING!", 1, 2, 1, 1, Y, R, G)
    p.sprite(BIGSHIP, 46, 47, 2, 1, outline=B)
    p.caption("HERE THEY COME!", 66, 53)
    p.border()
    return p


def frame():
    """the border for the text screens"""
    p = Pic()
    for x in range(W):
        for y in (0, 63):
            p.put(x, y, R)
        if x % 4 < 2:
            p.put(x, 1, Y)
            p.put(x, 62, Y)
    for y in range(H):
        for x in (0, 127):
            p.put(x, y, R)
        if y % 3 < 1:
            p.put(1, y, Y)
            p.put(126, y, Y)
    for (x, y) in ((3, 3), (124, 3), (3, 60), (124, 60)):
        p.rect(x - 1, y - 1, x + 1, y + 1, G)
        p.put(x, y, Y)
    p.line(10, 12, 117, 12, G)
    return p


PICS = {'title': title, 'comic1': comic1, 'comic2': comic2, 'comic3': comic3, 'frame': frame}


def main(outdir):
    os.makedirs(outdir, exist_ok=True)
    total = 0
    for name, fn in PICS.items():
        p = fn()
        raw = p.vz_bytes()
        packed = lz.pack(raw)
        assert lz.unpack(packed) == raw
        open(os.path.join(outdir, name + '.lz'), 'wb').write(packed)
        p.png(os.path.join(outdir, name + '.png'))
        total += len(packed)
        print('pic %-7s %4d bytes packed' % (name, len(packed)), file=sys.stderr)
    print('pics total %d' % total, file=sys.stderr)


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'pics')
