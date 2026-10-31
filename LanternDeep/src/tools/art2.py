"""THE LANTERN DEEP - region art: the Ossuary, the Crystal Caverns, the
Ember Halls and the Heart of the Deep (the Drowned Temple lives in art.py).

Every generator returns 1-bit bitmaps (ink = 1) that are cut into 8x8
cells; painted pieces are drawn in greyscale and ordered-dithered, as in
art.py. Remember the cells are tall on screen (about 1:1.8).
"""
import math
import random
import numpy as np
from PIL import ImageDraw

import art
from art import G, g_from_array, cut, paint, checker, BAYER4


# ================================================================== walls
def bone_wall_strip(seed, wcells=8, hcells=2):
    """Ossuary: walls of stacked skulls between courses of long bones."""
    rnd = random.Random(seed)
    W, H = wcells * 8, hcells * 8
    bm = np.zeros((H, W), dtype=np.uint8)
    skull = [".####.", "######", "#.##.#", "######", ".#..#."]
    # row 0-4 skulls, row 5-6 bones, row 8-12 skulls (offset), row 13-14 bones
    for band, y0, off in ((0, 0, 0), (1, 8, 3)):
        x = -off
        while x < W:
            for yy, row in enumerate(skull):
                for xx, ch in enumerate(row):
                    if ch == '#' and 0 <= x + xx < W:
                        bm[y0 + yy, x + xx] = 1
            if rnd.random() < 0.25:                    # a missing jaw
                bm[y0 + 4, max(0, x):max(0, x + 6)] = 0
            x += 7
        # long bones with knobbed ends
        yb = y0 + 6
        x = -rnd.randint(0, 6)
        while x < W:
            ln = rnd.randint(9, 14)
            for xx in range(max(0, x + 1), min(W, x + ln - 1)):
                bm[yb, xx] = 1
            for e in (x, x + ln - 1):
                if 0 <= e < W:
                    bm[yb - 1, e] = bm[yb + 1, e] = 1
                    bm[yb, e] = 0
            x += ln + 1
    return bm


def cave_wall_strip(seed, wcells=8, hcells=2):
    """Caverns: lumpy natural rock - smooth blobs, deep crevices, flecks."""
    rnd = random.Random(seed)
    W, H = wcells * 8, hcells * 8
    f = np.zeros((H, W))
    for _ in range(16):
        cx, cy = rnd.uniform(0, W), rnd.uniform(0, H)
        rx, ry = rnd.uniform(4, 10), rnd.uniform(3, 6)
        yy, xx = np.indices((H, W))
        d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
        f = np.maximum(f, np.clip(1.2 - d, 0, 1))
    # lit from above: brighter top of each lump
    grad = np.zeros_like(f)
    grad[1:, :] = f[1:, :] - f[:-1, :]
    tone = f * 0.55 + np.clip(-grad * 3.0, 0, 0.6)
    bm = (tone > BAYER4[np.indices((H, W))[0] % 4, np.indices((H, W))[1] % 4] * 0.9 + 0.08).astype(np.uint8)
    for _ in range(6):
        bm[rnd.randrange(H), rnd.randrange(W)] = 1
    return bm


def basalt_strip(seed, wcells=8, hcells=2):
    """Ember Halls: columnar basalt - tall prisms, sharp joints, ember cracks."""
    rnd = random.Random(seed)
    W, H = wcells * 8, hcells * 8
    bm = np.zeros((H, W), dtype=np.uint8)
    x = 0
    while x < W:
        w = rnd.choice((4, 5, 6))
        top = rnd.randint(0, 3)
        for yy in range(top, H):
            for xx in range(x, min(W, x + w - 1)):
                bm[yy, xx] = 1
        # facet highlight: left edge solid, right half half-tone
        for yy in range(top, H):
            for xx in range(x + w // 2, min(W, x + w - 1)):
                bm[yy, xx] = (xx + yy) % 2
        # horizontal joints
        for j in range(rnd.randint(1, 2)):
            jy = rnd.randint(top + 2, H - 2)
            bm[jy, x:min(W, x + w - 1)] = 0
        x += w
    return bm


def obsidian_strip(seed, wcells=8, hcells=2):
    """Heart of the Deep: polished black stone in long slabs, faint seams."""
    rnd = random.Random(seed)
    W, H = wcells * 8, hcells * 8
    bm = np.zeros((H, W), dtype=np.uint8)
    y = 0
    while y < H:
        h = rnd.choice((7, 8, 9))
        x = -rnd.randint(0, 20)
        while x < W:
            w = rnd.randint(18, 30)
            for yy in range(y, min(H, y + h - 1)):
                for xx in range(max(0, x), min(W, x + w - 1)):
                    # a gleam sweeping diagonally across each slab
                    g = ((xx - x) + (yy - y) * 2) % 24
                    bm[yy, xx] = 1 if g in (0, 1) or (yy == y) else 0
            x += w
        y += h
    return bm


def rune_band(seed):
    """a row of carved glyphs for obsidian walls (cycled colours)"""
    rnd = random.Random(seed)
    glyphs = []
    for k in range(4):
        a = np.zeros((8, 8), dtype=np.uint8)
        a[0, :] = a[7, :] = 1
        strokes = [((1, 2), (6, 2)), ((1, 5), (6, 5)), ((2, 1), (2, 6)), ((5, 1), (5, 6)), ((1, 1), (6, 6)), ((6, 1), (1, 6))]
        for (y0, x0), (y1, x1) in rnd.sample(strokes, 3):
            n = max(abs(y1 - y0), abs(x1 - x0))
            for t in range(n + 1):
                a[round(y0 + (y1 - y0) * t / n), round(x0 + (x1 - x0) * t / n)] = 1
        glyphs.append(g_from_array(a))
    return glyphs


# ================================================================== floors
def speckle_patch(seed, density=0.12, cracks=2, cw=4, ch=2, pebbles=6):
    """rough natural ground: sparse grit, pebbles and hairline cracks"""
    rnd = random.Random(seed)
    W, H = cw * 8, ch * 8
    bm = np.zeros((H, W), dtype=np.uint8)
    for y in range(H):
        for x in range(W):
            if rnd.random() < density:
                bm[y, x] = 1
    for _ in range(pebbles):
        x, y = rnd.randrange(1, W - 3), rnd.randrange(1, H - 2)
        bm[y, x:x + 2] = 1
        bm[y + 1, x:x + 3] = 1
        bm[y - 1, x:x + 2] = 0
    for _ in range(cracks):
        x, y = rnd.randrange(W), rnd.randrange(H)
        for _ in range(rnd.randint(5, 12)):
            bm[y % H, x % W] = 1
            x += rnd.choice((1, 1, 2))
            y += rnd.choice((-1, 0, 0, 1))
    return bm


def slab_patch(seed, cw=4, ch=2):
    """large polished slabs with star-like flecks (Heart floor)"""
    rnd = random.Random(seed)
    W, H = cw * 8, ch * 8
    bm = np.zeros((H, W), dtype=np.uint8)
    bm[0, :] = 1
    bm[:, 0] = 1
    bm[H // 2, :W // 2] = 1
    bm[:, W // 2 + rnd.randint(-3, 3)] |= np.r_[np.zeros(H // 2, dtype=np.uint8), np.ones(H - H // 2, dtype=np.uint8)]
    for _ in range(5):
        x, y = rnd.randrange(2, W - 2), rnd.randrange(2, H - 2)
        bm[y, x] = 1
    return bm


def hot_floor_frames():
    """fissured hot rock: glowing cracks pulse (4 frames, 1 cell)"""
    base = np.zeros((8, 8), dtype=np.uint8)
    path = [(0, 2), (1, 2), (2, 3), (3, 3), (4, 4), (5, 4), (6, 5), (7, 5), (3, 4), (3, 5), (2, 6), (2, 7)]
    frames = []
    for f in range(4):
        a = base.copy()
        for i, (y, x) in enumerate(path):
            if (i + f) % 4 != 0:
                a[y, x] = 1
        a[(f * 3) % 8, (f * 5 + 1) % 8] = 1
        frames.append(g_from_array(a))
    return frames


def lava_frames():
    """molten rock: bubbles rise and burst, crust drifts (4 frames x 2 cells)"""
    frames = []
    for f in range(4):
        bm = np.zeros((8, 16), dtype=np.uint8)
        for y in range(8):
            for x in range(16):
                v = math.sin((x + f * 2) * 0.8) + math.sin((y * 1.7 + x * 0.3 - f) * 0.9)
                bm[y, x] = 1 if v > 0.4 else 0
        # bubbles
        bx = (f * 5 + 3) % 14
        by = 6 - (f * 2) % 7
        bm[max(0, by - 1):by + 1, bx:bx + 2] = 0
        bm[max(0, by - 1), bx:bx + 2] = 1
        frames.append([g_from_array(bm[:, 0:8]), g_from_array(bm[:, 8:16])])
    return frames


# ================================================================== painted pieces
def sarcophagus_paint(d, W, H):
    # 3x2 cells: a stone coffin seen from above-front, carved effigy lid
    def P(x, y):
        return (x * W, y * H)
    d.rectangle([*P(0.02, 0.10), *P(0.98, 0.98)], fill=150)
    d.rectangle([*P(0.02, 0.10), *P(0.98, 0.16)], fill=240)
    d.rectangle([*P(0.02, 0.62), *P(0.98, 0.98)], fill=110)          # front face
    for k in range(5):
        x = 0.1 + k * 0.2
        d.rectangle([*P(x, 0.70), *P(x + 0.08, 0.92)], fill=60)       # carved panels
    # effigy on the lid: hands folded, head on a cushion
    d.ellipse([*P(0.06, 0.20), *P(0.22, 0.50)], fill=230)
    d.rectangle([*P(0.20, 0.25), *P(0.86, 0.48)], fill=210)
    d.polygon([P(0.86, 0.25), P(0.96, 0.30), P(0.96, 0.44), P(0.86, 0.48)], fill=190)
    d.line([P(0.45, 0.25), P(0.55, 0.48)], fill=90, width=2)


def candle_frames():
    """a fat candle on the floor: flame flickers (4 frames)"""
    out = []
    for f in range(4):
        rows = ["........", "........", "........", "...##...", "...##...", "..####..", "..####..", ".######."]
        flame = [("...#....", "..###..."), ("....#...", "...###.."), ("...#....", "...##..."), ("..#.....", "..###...")][f]
        rows[0], rows[1] = flame
        rows[2] = "...#...."
        out.append(art.g_from_rows(rows))
    return out


GATE_SHUT = G("#.#.#.#.",
              "########",
              "#.#.#.#.",
              "#.#.#.#.",
              "#.#.#.#.",
              "########",
              "#.#.#.#.",
              "#.#.#.#.")
GATE_OPEN = G("########",
              "........",
              "........",
              "........",
              "........",
              "........",
              "........",
              "........")
CRACKED_WALL_MARK = G("........",
                      "...#....",
                      "..#.#...",
                      "..#..#..",
                      ".#...#..",
                      ".#..#...",
                      "..#.....",
                      "........")
BARRIER = G("#..#..#.",
            ".#.#.#..",
            "..###...",
            "#######.",
            "..###...",
            ".#.#.#..",
            "#..#..#.",
            "........")
SHARDS = G("........",
           "........",
           "....#...",
           "........",
           ".#....#.",
           "...#....",
           "#.....#.",
           "..#.#...")
MUSHROOM = [G("........",
              "..###...",
              ".#####..",
              "#######.",
              "...#....",
              "...#..#.",
              "..##.###",
              ".....##."),
            G("........",
              "..###...",
              ".##.##..",
              "#######.",
              "...#....",
              "...#..#.",
              "..##.###",
              ".....##.")]
STALAGMITE = G("...#....",
               "...#....",
               "..##....",
               "..##....",
               "..###...",
               ".####...",
               ".#####..",
               "#######.")
ANVIL = G("........",
          "........",
          "#######.",
          ".######.",
          "...##...",
          "...##...",
          "..####..",
          ".######.")
PEDESTAL = G("........",
             "........",
             ".######.",
             "..####..",
             "...##...",
             "...##...",
             "..####..",
             ".######.")


def stairs_paint(d, W, H):
    """2x2 cells: a stair well dropping away into darkness"""
    n = 6
    for k in range(n):
        t = k / n
        y0 = H * (0.08 + t * 0.9)
        y1 = H * (0.08 + (k + 1) / n * 0.9)
        inset = W * (0.04 + 0.06 * k)
        shade = int(230 * (1 - t) ** 1.4)
        d.rectangle([inset, y0, W - inset, y1 - 2], fill=shade)
        d.rectangle([inset, y0, W - inset, y0 + 2], fill=min(255, shade + 40))
    d.rectangle([0, 0, W * 0.06, H], fill=170)
    d.rectangle([W * 0.94, 0, W, H], fill=170)


def altar_paint(d, W, H):
    """3x2: an altar block with steps and a carved sun"""
    d.rectangle([W * 0.05, H * 0.25, W * 0.95, H * 0.80], fill=200)
    d.rectangle([W * 0.05, H * 0.25, W * 0.95, H * 0.31], fill=255)
    d.rectangle([0, H * 0.80, W, H], fill=130)
    d.rectangle([0, H * 0.80, W, H * 0.84], fill=220)
    cx, cy = W * 0.5, H * 0.55
    d.ellipse([cx - W * 0.09, cy - H * 0.16, cx + W * 0.09, cy + H * 0.16], fill=60)
    for k in range(8):
        a = k * math.pi / 4
        d.line([(cx + math.cos(a) * W * 0.11, cy + math.sin(a) * H * 0.2),
                (cx + math.cos(a) * W * 0.16, cy + math.sin(a) * H * 0.28)], fill=70, width=2)


def forge_paint(d, W, H):
    """3x2: a stone forge with a glowing mouth (animated separately)"""
    d.rectangle([0, H * 0.05, W, H], fill=170)
    d.rectangle([0, H * 0.05, W, H * 0.11], fill=240)
    d.ellipse([W * 0.22, H * 0.30, W * 0.78, H * 1.15], fill=40)
    for k in range(4):
        d.rectangle([W * (0.05 + k * 0.25), H * 0.12, W * (0.05 + k * 0.25) + W * 0.17, H * 0.26], fill=120)


def forge_glow_frames():
    out = []
    for f in range(4):
        a = np.zeros((8, 8), dtype=np.uint8)
        for y in range(8):
            for x in range(8):
                v = math.sin(x * 1.3 + f * 1.7) + math.sin(y * 1.1 - f) + (y / 4.0)
                a[y, x] = 1 if v > 1.2 else 0
        out.append(g_from_array(a))
    return out


def portal_frames():
    """3x3 swirling gate - 4 frames of a rotating spiral, returns [f][cy][cx]"""
    out = []
    for f in range(4):
        bm = np.zeros((24, 24), dtype=np.uint8)
        for y in range(24):
            for x in range(24):
                dx, dy = (x - 11.5) / 11.5, (y - 11.5) / 11.5 * 1.0
                r = math.hypot(dx, dy)
                if r > 1.0:
                    continue
                a = math.atan2(dy, dx)
                v = math.sin(a * 3 + r * 9 - f * math.pi / 2)
                bm[y, x] = 1 if (v > 0.2 or r > 0.92) else 0
        out.append(cut(bm, 3, 3))
    return out


def colossus_paint(eyes_open):
    """Bone Colossus, 4x5 cells: a giant of fused skeletons"""
    def fn(d, W, H):
        def P(x, y):
            return (x * W, y * H)
        d.ellipse([*P(0.25, 0.00), *P(0.75, 0.24)], fill=230)              # skull
        if eyes_open:
            d.ellipse([*P(0.33, 0.08), *P(0.45, 0.15)], fill=255)
            d.ellipse([*P(0.55, 0.08), *P(0.67, 0.15)], fill=255)
        else:
            d.ellipse([*P(0.33, 0.08), *P(0.45, 0.15)], fill=20)
            d.ellipse([*P(0.55, 0.08), *P(0.67, 0.15)], fill=20)
        d.rectangle([*P(0.38, 0.18), *P(0.62, 0.23)], fill=40)              # teeth gap
        for k in range(4):                                                  # ribcage
            y = 0.30 + k * 0.08
            d.arc([*P(0.18, y), *P(0.82, y + 0.12)], 200, 340, fill=220, width=4)
        d.rectangle([*P(0.47, 0.26), *P(0.53, 0.70)], fill=200)            # spine
        d.line([P(0.20, 0.30), P(0.02, 0.62)], fill=220, width=8)          # arms
        d.line([P(0.80, 0.30), P(0.98, 0.62)], fill=220, width=8)
        d.ellipse([*P(0.30, 0.66), *P(0.70, 0.78)], fill=190)               # pelvis
        d.line([P(0.38, 0.76), P(0.30, 1.0)], fill=220, width=8)           # legs
        d.line([P(0.62, 0.76), P(0.70, 1.0)], fill=220, width=8)
    return fn


def king_paint(phase):
    """The Hollow King, 5x5 cells: a crowned void in a cloak of shadow.
    phase: 0 idle, 1 eyes flare, 2 mouth open"""
    def fn(d, W, H):
        def P(x, y):
            return (x * W, y * H)
        d.polygon([P(0.5, 0.10), P(0.98, 1.0), P(0.02, 1.0)], fill=90)         # cloak
        for k in range(5):
            x = 0.1 + k * 0.2
            d.line([P(0.5, 0.25), P(x, 1.0)], fill=50, width=3)                  # folds
        d.ellipse([*P(0.30, 0.08), *P(0.70, 0.38)], fill=30)                     # hood void
        d.polygon([P(0.30, 0.10), P(0.36, 0.0), P(0.42, 0.08), P(0.50, 0.0), P(0.58, 0.08),
                   P(0.64, 0.0), P(0.70, 0.10)], fill=255)                       # crown
        e = 255 if phase == 1 else 200
        d.ellipse([*P(0.38, 0.17), *P(0.46, 0.23)], fill=e)
        d.ellipse([*P(0.54, 0.17), *P(0.62, 0.23)], fill=e)
        if phase == 2:
            d.ellipse([*P(0.44, 0.27), *P(0.56, 0.35)], fill=230)
        d.line([P(0.28, 0.45), P(0.08, 0.30)], fill=170, width=6)               # raised hand
        d.ellipse([*P(0.02, 0.20), *P(0.14, 0.32)], fill=255 if phase else 140)  # dark flame
    return fn


def heart_paint(lit):
    """3x3: the Heart Lantern on its altar - dark, or rekindled"""
    def fn(d, W, H):
        def P(x, y):
            return (x * W, y * H)
        d.rectangle([*P(0.05, 0.78), *P(0.95, 1.0)], fill=170)
        d.rectangle([*P(0.05, 0.78), *P(0.95, 0.82)], fill=255)
        d.rectangle([*P(0.25, 0.20), *P(0.75, 0.78)], fill=200)
        d.rectangle([*P(0.18, 0.12), *P(0.82, 0.22)], fill=230)
        d.rectangle([*P(0.32, 0.28), *P(0.68, 0.70)], fill=255 if lit else 40)
        if lit:
            d.polygon([P(0.5, 0.32), P(0.62, 0.62), P(0.38, 0.62)], fill=90)
        d.line([P(0.5, 0.0), P(0.5, 0.12)], fill=200, width=3)
    return fn


# ================================================================== sprites
GHOST = [G("..###...",
           ".#####..",
           "#.#.###.",
           "#######.",
           "#######.",
           "#######.",
           "#.#.#.#.",
           "........"),
         G("..###...",
           ".#####..",
           "#.#.###.",
           "#######.",
           "#######.",
           "#######.",
           ".#.#.#.#",
           "........")]
SPIDER = [G("........",
            "#..##..#",
            ".#.##.#.",
            "..####..",
            "########",
            "..####..",
            ".#....#.",
            "#......#"),
          G("........",
            ".#.##.#.",
            "#..##..#",
            "..####..",
            "########",
            "..####..",
            "#......#",
            ".#....#.")]
SLIME = [G("........",
           "........",
           "........",
           "..###...",
           ".#####..",
           "##.#.##.",
           "#######.",
           ".#####.."),
         G("........",
           "........",
           "...##...",
           "..####..",
           ".##.#.#.",
           ".######.",
           "########",
           "........")]
IMP = [G("#.....#.",
         "##.#.##.",
         ".#####..",
         ".#.#.#..",
         "..###...",
         ".#####..",
         "#.###.#.",
         "..#.#..."),
       G(".#...#..",
         "##.#.##.",
         ".#####..",
         ".#.#.#..",
         "..###...",
         "#######.",
         "..###...",
         ".#...#..")]
SHADE = [G("...#....",
           "..###...",
           ".#.#.#..",
           ".#####..",
           "#######.",
           ".#####..",
           "#.#.#.#.",
           ".#.#.#.."),
         G("...#....",
           "..###...",
           ".#.#.#..",
           ".#####..",
           ".#####..",
           "#######.",
           ".#.#.#.#",
           "#.#.#.#.")]
EBOLT = [G("........",
           "...#....",
           "..###...",
           ".##.##..",
           "..###...",
           "...#....",
           "........",
           "........"),
         G("........",
           "........",
           "..#.#...",
           "...#....",
           "..#.#...",
           "........",
           "........",
           "........")]

ITEMS = {
    'key': G("........",
             ".##.....",
             "#..#####",
             "#..#.#.#",
             ".##.....",
             "........",
             "........",
             "........"),
    'lantern': G("...##...",
                 "..#..#..",
                 ".######.",
                 ".#.##.#.",
                 ".##..##.",
                 ".#.##.#.",
                 ".######.",
                 "..####.."),
    'blade': G(".......#",
               "......##",
               ".....##.",
               "....##..",
               "#..##...",
               ".###....",
               "..##....",
               ".#..#..."),
    'ring': G("...#....",
              "..###...",
              ".#...#..",
              "#.....#.",
              "#.....#.",
              ".#...#..",
              "..###...",
              "........"),
    'potion': art.FX['potion'],
}
