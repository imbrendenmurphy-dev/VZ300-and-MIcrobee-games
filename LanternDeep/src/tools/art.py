"""THE LANTERN DEEP - PCG artwork.

Every glyph is 8x8 pixels (8 bytes, MSB = leftmost pixel). On the Premium the
80x24 / 8-scanline mode shows each pixel about 1.8x taller than wide, so the
art is drawn for tall cells and previews are rendered 1:2.

Three kinds of art live here:
  * procedural textures (masonry, paving, mosaics, rock caps) generated as
    large seamless strips and cut into cells,
  * painted set pieces (statue, crystal, pillars, braziers, arch) drawn in
    greyscale with PIL and ordered-dithered to 1 bit,
  * hand-drawn sprites and the font, written as text.
"""
import math
import random
import numpy as np
from PIL import Image, ImageDraw

BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32


# ----------------------------------------------------------------- helpers
def g_from_rows(rows):
    assert len(rows) == 8, rows
    out = []
    for r in rows:
        assert len(r) == 8, r
        v = 0
        for ch in r:
            v = (v << 1) | (1 if ch in '#X@' else 0)
        out.append(v)
    return tuple(out)


def g_from_array(a):
    """a: 8x8 bool/int array -> glyph tuple"""
    out = []
    for y in range(8):
        v = 0
        for x in range(8):
            v = (v << 1) | (1 if a[y][x] else 0)
        out.append(v)
    return tuple(out)


def g_to_array(g):
    return np.array([[(g[y] >> (7 - x)) & 1 for x in range(8)] for y in range(8)], dtype=np.uint8)


def cut(bitmap, cw, ch):
    """Cut a (ch*8) x (cw*8) bitmap into a ch x cw grid of glyphs."""
    return [[g_from_array(bitmap[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]) for cx in range(cw)] for cy in range(ch)]


def dither(gray, bias=0.0):
    """gray: float array 0..1 (1 = foreground ink). Ordered dither."""
    h, w = gray.shape
    th = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    return (gray + bias > th).astype(np.uint8)


EMPTY = (0,) * 8
SOLID = (255,) * 8

# Light variants: v0 = full art, v1 = dimmed (75% of ink kept, regular
# grid holes give a soft dithered shadow), v2 = remembered (sparse 25%
# lattice: explored areas drawn like a faint blueprint).
MASK_V1 = (0xFF, 0xAA, 0xFF, 0x55, 0xFF, 0xAA, 0xFF, 0x55)   # dimmed: 75% of ink
MASK_V2 = (0xAA, 0x00, 0x55, 0x00, 0xAA, 0x00, 0x55, 0x00)   # remembered: 25% lattice
MASK_V3 = (0x88, 0x00, 0x00, 0x00, 0x22, 0x00, 0x00, 0x00)   # faint: 6%
MASKS = (None, MASK_V1, MASK_V2, MASK_V3)


def variant(g, v):
    if v == 0:
        return g
    return tuple(a & b for a, b in zip(g, MASKS[v]))


def g_or(a, b):
    return tuple(x | y for x, y in zip(a, b))


def g_and(a, b):
    return tuple(x & y for x, y in zip(a, b))


def g_inv(a):
    return tuple(x ^ 0xFF for x in a)


def g_flip_h(g):
    return tuple(int('{:08b}'.format(r)[::-1], 2) for r in g)


def g_flip_v(g):
    return tuple(reversed(g))


# ----------------------------------------------------------------- masonry
CHECK = np.array([[1, 0], [0, 1]], dtype=np.uint8)


def checker(h, w, phase=0):
    yy, xx = np.indices((h, w))
    return ((xx + yy + phase) % 2 == 0).astype(np.uint8)


def masonry_strip(seed, width_cells, rows_cells, course_h=(3, 3, 4), stone_w=(5, 12), crack=0.15, holes=0.0):
    """Coursed ashlar with irregular joints. ink = stone face, paper =
    mortar. Each stone: solid face, a half-tone lower edge (shadow) and the
    occasional chip or crack. Clean shapes - no random grain."""
    rnd = random.Random(seed)
    W, H = width_cells * 8, rows_cells * 8
    bm = np.zeros((H, W), dtype=np.uint8)
    y = 0
    while y < H:
        h = rnd.choice(course_h)
        if y + h + 1 > H:
            h = H - y - 1
        if h < 2:
            break
        x = -rnd.randint(0, 8)
        while x < W:
            w = rnd.randint(*stone_w)
            x0, x1 = max(0, x), min(W, x + w)
            bm[y:y + h, x0:x1] = 1
            # shadowed bottom row (half tone)
            bm[y + h - 1, x0:x1] &= checker(1, x1 - x0, y + x0)[0]
            # chipped corners
            if rnd.random() < 0.5 and x1 - x0 > 3:
                bm[y, x1 - 1] = 0
            if rnd.random() < 0.3 and x1 - x0 > 3:
                bm[y, x0] = 0
            if rnd.random() < crack and x1 - x0 > 5:
                cx = rnd.randrange(x0 + 2, x1 - 2)
                for yy in range(y, y + h):
                    bm[yy, cx] = 0
                    cx += rnd.choice((-1, 0, 1))
                    cx = max(x0 + 1, min(x1 - 2, cx))
            if rnd.random() < holes and x1 - x0 > 4:
                hx = rnd.randrange(x0 + 1, x1 - 2)
                bm[y:y + 2, hx:hx + 2] = 0
            x += w + 1
        y += h + 1
    return bm


# ----------------------------------------------------------------- paving
def paving_patch(seed, cw=4, ch=2, cracked=0.3, density=None):
    """A seamless patch of flagstones: half-tone slab faces (reads as a
    darker surface than the solid wall faces), lit top/left bevels, black
    joints, a few cracks and pebbles. Joints run along the patch border so
    patches combine seamlessly."""
    rnd = random.Random(seed)
    W, H = cw * 8, ch * 8
    bm = np.zeros((H, W), dtype=np.uint8)
    ys = [0]
    while ys[-1] < H:
        ys.append(min(H, ys[-1] + rnd.choice((6, 8, 8, 10))))
    if H - ys[-2] < 5 and len(ys) > 2:
        ys.pop(-2)
    for i in range(len(ys) - 1):
        xs = [0]
        while xs[-1] < W:
            xs.append(min(W, xs[-1] + rnd.choice((8, 10, 12, 14, 16))))
        if W - xs[-2] < 6 and len(xs) > 2:
            xs.pop(-2)
        for j in range(len(xs) - 1):
            x0, y0, x1, y1 = xs[j], ys[i], xs[j + 1], ys[i + 1]
            face = checker(y1 - y0 - 1, x1 - x0 - 1, x0 + y0)
            bm[y0:y1 - 1, x0:x1 - 1] = face
            bm[y0, x0:x1 - 1] = 1                 # lit top bevel
            bm[y0:y1 - 1, x0] = 1                 # lit left bevel
            if rnd.random() < cracked and (x1 - x0) > 8:
                cx, cy = rnd.randrange(x0 + 3, x1 - 3), y0 + 1
                while cy < y1 - 1:
                    bm[cy, cx] = 0
                    bm[cy, cx + 1] = 0
                    cx = min(x1 - 3, max(x0 + 2, cx + rnd.choice((-1, 0, 1))))
                    cy += 1
            if rnd.random() < 0.35:
                px, py = rnd.randrange(x0 + 2, x1 - 3), rnd.randrange(y0 + 2, y1 - 2)
                bm[py, px:px + 2] = 1
                bm[py - 1, px:px + 2] = 0
    return bm


def mosaic_patch():
    """Temple floor: 2x2-cell lattice of gold diamonds with a rosette
    (16x16 px). ink = gold tesserae."""
    W = H = 16
    bm = np.zeros((H, W), dtype=np.uint8)
    for y in range(H):
        for x in range(W):
            dx, dy = abs(x - 7.5), abs(y - 7.5)
            d = dx + dy * 1.0
            if 7.0 <= d <= 8.0 and (x % 2 == 0 or y % 4 == 0):
                bm[y, x] = 1                       # diamond lattice line (dotted)
            if d <= 1.0:
                bm[y, x] = 1                       # centre stud
            if 3.0 <= d <= 4.0 and (x + y) % 2 == 0:
                bm[y, x] = 1                       # dotted inner ring
    # tiny corner studs where the lattice lines cross
    for (cx, cy) in ((0, 0), (15, 0), (0, 15), (15, 15)):
        bm[cy, cx] = 1
    return bm


def meander_strip(vertical=False):
    """Greek-key border band, one cell thick, 2-cell repeat."""
    rows = [
        "################",
        "................",
        ".#####...#####..",
        ".#...#...#...#..",
        ".#.#.#####.#.###",
        ".#.#.......#....",
        "................",
        "################",
    ]
    bm = np.array([[1 if c == '#' else 0 for c in r] for r in rows], dtype=np.uint8)
    if vertical:
        bm = np.rot90(bm, -1).copy()
    return bm


def rock_cap(seed, edges):
    """Top of a wall mass: black rock with a carved lip on every side that
    faces open floor (edges = set of 'N','E','S','W') and a faint seam."""
    rnd = random.Random(seed)
    a = np.zeros((8, 8), dtype=np.uint8)
    if seed % 3 == 0:
        x = rnd.randrange(2, 6)
        a[3, x] = a[4, x + 1] = 1
    if 'N' in edges:
        a[0, :] = 1
        a[1, ::2] = 1
    if 'S' in edges:
        a[7, :] = 1
        a[6, 1::2] = 1
    if 'W' in edges:
        a[:, 0] = 1
    if 'E' in edges:
        a[:, 7] = 1
    return g_from_array(a)


# ----------------------------------------------------------------- painted set pieces
def paint(w_cells, h_cells, fn, scale=4):
    """Paint at high resolution in greyscale with PIL (fn(draw, W, H)), then
    reduce to cell resolution (pixels tall 2:1 -> drawn at x scale, 2x y) and
    dither. Returns a bitmap (h_cells*8, w_cells*8)."""
    W, H = w_cells * 8 * scale, h_cells * 8 * scale * 2
    im = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(im)
    fn(d, W, H)
    small = im.resize((w_cells * 8, h_cells * 8), Image.BOX)
    gray = np.asarray(small, dtype=np.float32) / 255.0
    return dither(gray)


def statue_paint(d, W, H):
    # Robed guardian (4x5 cells) raising a lantern in her right hand.
    def P(x, y):
        return (x * W, y * H)
    # plinth: two steps, lit top edges
    d.rectangle([*P(0.04, 0.88), *P(0.96, 1.0)], fill=150)
    d.rectangle([*P(0.04, 0.88), *P(0.96, 0.90)], fill=255)
    d.rectangle([*P(0.12, 0.81), *P(0.88, 0.88)], fill=200)
    d.rectangle([*P(0.12, 0.81), *P(0.88, 0.83)], fill=255)
    # robe: flared, folds as dark grooves, shadowed right flank
    d.polygon([P(0.36, 0.30), P(0.64, 0.30), P(0.80, 0.81), P(0.20, 0.81)], fill=215)
    d.polygon([P(0.56, 0.30), P(0.64, 0.30), P(0.80, 0.81), P(0.62, 0.81)], fill=120)
    for k in (0.33, 0.44, 0.55):
        d.line([P(0.47 + (k - 0.44) * 0.3, 0.40), P(k, 0.80)], fill=60, width=max(2, int(W * 0.025)))
    # belt
    d.rectangle([*P(0.36, 0.44), *P(0.62, 0.46)], fill=60)
    # hood and head
    d.ellipse([*P(0.36, 0.17), *P(0.62, 0.33)], fill=225)
    d.ellipse([*P(0.42, 0.21), *P(0.56, 0.31)], fill=35)
    d.polygon([P(0.36, 0.26), P(0.62, 0.26), P(0.66, 0.36), P(0.33, 0.36)], fill=200)
    # left arm folded over the chest
    d.line([P(0.60, 0.34), P(0.44, 0.47)], fill=240, width=int(W * 0.07))
    # right arm raised, holding a lantern up and out
    d.line([P(0.38, 0.33), P(0.22, 0.24), P(0.19, 0.11)], fill=230, width=int(W * 0.075))
    d.rectangle([*P(0.08, 0.00), *P(0.30, 0.03)], fill=255)        # lantern cap
    d.rectangle([*P(0.10, 0.03), *P(0.28, 0.11)], fill=255)        # lantern body
    d.rectangle([*P(0.14, 0.045), *P(0.24, 0.095)], fill=70)       # glass (dark: unlit)
    d.line([P(0.19, 0.045), P(0.19, 0.095)], fill=255, width=2)


def crystal_paint(d, W, H):
    # Cluster of luminous crystals growing from rubble. 3x4 cells.
    shards = [
        # (base x, base y, top x, top y, half width, brightness)
        (0.50, 0.95, 0.52, 0.05, 0.13, 1.0),
        (0.30, 0.95, 0.18, 0.35, 0.10, 0.8),
        (0.72, 0.95, 0.86, 0.30, 0.10, 0.85),
        (0.40, 0.95, 0.34, 0.55, 0.07, 0.6),
        (0.62, 0.97, 0.66, 0.60, 0.07, 0.65),
    ]
    for bx, by, tx, ty, hw, br in shards:
        bx, by, tx, ty, hw = bx * W, by * H, tx * W, ty * H, hw * W
        left = [(bx - hw, by), (tx - hw * 0.8, ty + (by - ty) * 0.2), (tx, ty), (bx, by)]
        right = [(bx, by), (tx, ty), (tx + hw * 0.8, ty + (by - ty) * 0.2), (bx + hw, by)]
        d.polygon(left, fill=int(255 * br))
        d.polygon(right, fill=int(150 * br))
        d.line([(bx, by), (tx, ty)], fill=255, width=2)
    # rubble base
    for i in range(7):
        x = W * (0.08 + i * 0.13)
        d.ellipse([x - W * 0.08, H * 0.90, x + W * 0.08, H * 1.0], fill=70 + 20 * (i % 3))


def pillar_paint(d, W, H):
    # 2x3 cell column: square abacus, echinus, fluted shaft, torus, plinth
    def P(x, y):
        return (x * W, y * H)
    d.rectangle([*P(0.0, 0.0), *P(1.0, 0.10)], fill=230)
    d.rectangle([*P(0.0, 0.08), *P(1.0, 0.10)], fill=90)
    d.polygon([P(0.04, 0.10), P(0.96, 0.10), P(0.86, 0.18), P(0.14, 0.18)], fill=200)
    d.rectangle([*P(0.14, 0.18), *P(0.86, 0.84)], fill=210)
    for k in range(4):
        x = 0.24 + k * 0.16
        d.line([P(x, 0.20), P(x, 0.82)], fill=80, width=max(2, int(W * 0.04)))
    d.rectangle([*P(0.62, 0.18), *P(0.86, 0.84)], fill=110)
    d.rectangle([*P(0.08, 0.84), *P(0.92, 0.90)], fill=240)
    d.rectangle([*P(0.0, 0.90), *P(1.0, 1.0)], fill=170)
    d.rectangle([*P(0.0, 0.90), *P(1.0, 0.92)], fill=255)


def brazier_paint(d, W, H):
    # 1x2 cells: bowl on a tripod (flame is a separate animated glyph above)
    d.polygon([(W * 0.0, H * 0.05), (W * 1.0, H * 0.05), (W * 0.8, H * 0.35), (W * 0.2, H * 0.35)], fill=230)
    d.rectangle([0, H * 0.03, W, H * 0.08], fill=255)
    d.line([(W * 0.5, H * 0.35), (W * 0.5, H * 0.92)], fill=200, width=max(1, int(W * 0.18)))
    d.line([(W * 0.5, H * 0.6), (W * 0.1, H * 0.95)], fill=200, width=max(1, int(W * 0.12)))
    d.line([(W * 0.5, H * 0.6), (W * 0.9, H * 0.95)], fill=200, width=max(1, int(W * 0.12)))


def arch_paint(d, W, H):
    # Doorway jamb stone with a carved rune: 1 x 1 cells, drawn per rune
    pass


# ----------------------------------------------------------------- hand art
def G(*rows):
    return g_from_rows(list(rows))


# Animated flame for braziers and wall torches (4 frames)
FLAME = [
    G("...#....",
      "...##...",
      "..###...",
      "..####..",
      ".#####..",
      ".##.###.",
      "..#.##..",
      "........"),
    G("....#...",
      "...##...",
      "...###..",
      "..####..",
      "..#####.",
      ".###.##.",
      "..##.#..",
      "........"),
    G("...#....",
      "..##....",
      "..###...",
      ".####...",
      ".####.#.",
      ".##.###.",
      "..####..",
      "........"),
    G("....#...",
      "....##..",
      "...###..",
      "..####..",
      ".#####..",
      ".###.##.",
      "..#.##..",
      "........"),
]

# Wall sconce (iron bracket) under a flame, drawn on a wall face
SCONCE = G("........",
           "..####..",
           "...##...",
           "...##...",
           "...#....",
           "..##....",
           ".##.....",
           "........")

RUNES = [
    G("##....##",
      "#..#...#",
      "...##...",
      "..#.#...",
      "...#.#..",
      "....##..",
      "#...#..#",
      "##....##"),
    G("##....##",
      "#..##..#",
      "..#..#..",
      "...##...",
      "..####..",
      "...##...",
      "#..##..#",
      "##....##"),
    G("##....##",
      "#.#..#.#",
      "..#..#..",
      "..####..",
      "..#..#..",
      "..#..#..",
      "#......#",
      "##....##"),
]

BONES = G("........",
          ".##.....",
          "#..#....",
          "#.##..#.",
          ".##..#.#",
          "....#.#.",
          "...#.#..",
          "....#...")
SKULL = G("........",
          "..####..",
          ".######.",
          ".#.##.#.",
          ".######.",
          "..#..#..",
          "..####..",
          "........")
RUBBLE = G("........",
           "........",
           "..##....",
           ".####...",
           ".####.#.",
           "..##.###",
           "......##",
           "........")
COBWEB = G("#.#.#.#.",
           "##.#.#..",
           "#.#.#...",
           "##.##...",
           "#.#.....",
           "###.....",
           "#.......",
           "#.......")
URN = G("..####..",
        "...##...",
        "..####..",
        ".######.",
        ".#.####.",
        ".######.",
        "..####..",
        "........")
CHEST_SHUT = G("........",
               ".######.",
               "#......#",
               "########",
               "#..##..#",
               "#..##..#",
               "########",
               "........")
CHEST_OPEN = G("######..",
               "#....#..",
               ".######.",
               "#.#..#.#",
               "########",
               "#..##..#",
               "########",
               "........")

# Water: 4 animation frames of gently moving ripples (one seamless 2-cell strip
# per frame so neighbouring cells interlock)
def water_frames():
    frames = []
    for f in range(4):
        bm = np.zeros((8, 16), dtype=np.uint8)
        for y in range(8):
            for x in range(16):
                ph = (x + f * 4 + (3 if y % 4 >= 2 else 0)) % 16
                if y % 4 == 1 and ph in (2, 3, 4, 5):
                    bm[y, x] = 1
                if y % 4 == 3 and ph in (10, 11, 12):
                    bm[y, x] = 1
        # sparkles
        sx = (f * 5 + 3) % 16
        bm[(f * 3) % 8, sx] = 1
        frames.append([g_from_array(bm[:, 0:8]), g_from_array(bm[:, 8:16])])
    return frames


# Puddle: a shallow pool on the flagstones; a drip lands every so often
def puddle_frames():
    def ring(r):
        bm = np.zeros((8, 8), dtype=np.uint8)
        for y in range(8):
            for x in range(8):
                d = math.hypot((x - 3.5) / 3.6, (y - 4.5) / 2.2)
                if d <= 1.0:
                    bm[y, x] = 0
                if 0.96 <= d <= 1.12:
                    bm[y, x] = 1                     # puddle edge
                if r is not None and abs(math.hypot((x - 3.5) / 1.0, (y - 4.5) / 0.6) - r) < 0.55 and d < 0.95:
                    bm[y, x] = 1                     # ripple ring
        return g_from_array(bm)
    calm = ring(None)
    glint = list(calm)
    glint[3] |= 0x10
    return [calm, calm, tuple(glint), calm, calm, ring(0.6), ring(1.6), ring(2.6)]


BEETLE = [G("........",
            "........",
            "........",
            "..#..#..",
            "...##...",
            "..####..",
            ".#.##.#.",
            "........"),
          G("........",
            "........",
            "........",
            ".#....#.",
            "...##...",
            ".######.",
            "...##...",
            "........")]


# ----------------------------------------------------------------- sprites
PLAYER = {
    'down0': G("..###...",
               ".#####..",
               "..#.#..#",
               "..###.##",
               ".#####.#",
               "#.###...",
               "..#.#...",
               ".##.##.."),
    'down1': G("..###...",
               ".#####..",
               "..#.#..#",
               "..###.##",
               ".#####.#",
               "#.###...",
               "..#.#...",
               "..#..##."),
    'up0': G("...###..",
             "..#####.",
             "#.#####.",
             "##.###..",
             "#.#####.",
             "...###.#",
             "...#.#..",
             "..##.##."),
    'up1': G("...###..",
             "..#####.",
             "#.#####.",
             "##.###..",
             "#.#####.",
             "...###.#",
             "...#.#..",
             "..##..#."),
    'right0': G("..###...",
                ".####...",
                "..#.#..#",
                "..##..##",
                ".####.#.",
                ".###.#..",
                "..#.#...",
                ".##.##.."),
    'right1': G("..###...",
                ".####...",
                "..#.#..#",
                "..##..##",
                ".####.#.",
                ".###.#..",
                "..##....",
                "..#.#..."),
    'atk_down': G("..###...",
                  ".#####..",
                  "..#.#...",
                  "..###...",
                  ".######.",
                  "#.###..#",
                  "..#.#..#",
                  ".##.##.#"),
    'atk_up': G("#..###..",
                "#.#####.",
                "#.#####.",
                ".#.###..",
                "..#####.",
                "...###..",
                "...#.#..",
                "..##.##."),
    'atk_right': G("..###...",
                   ".####...",
                   "..#.#...",
                   "..##....",
                   ".#######",
                   ".###....",
                   "..#.#...",
                   ".##.##.."),
    'cast': G("#.###.#.",
              "#####.#.",
              ".##.##..",
              "..###...",
              "..###...",
              ".#####..",
              "..#.#...",
              ".##.##.."),
    'hurt': G("..###...",
              ".#.#.#..",
              "..###...",
              ".#.#.#..",
              "#.###.#.",
              "..###...",
              ".#...#..",
              "#.....#."),
    'die0': G("........",
              "..###...",
              ".#.#.#..",
              "..###...",
              ".#####..",
              "..###...",
              ".##.##..",
              "........"),
    'die1': G("........",
              "........",
              "........",
              "..###...",
              ".#.#.#..",
              "#######.",
              ".#####..",
              "........"),
    'die2': G("........",
              "........",
              "........",
              "........",
              "........",
              ".##.....",
              "######..",
              ".######."),
    'cheer': G("#.###.#.",
               "##.#.##.",
               ".#####..",
               "..###...",
               "..###...",
               ".#####..",
               "..#.#...",
               ".#...#.."),
    'idle1': G("........",
               "..###...",
               ".#####..",
               "..#.#..#",
               "..###.##",
               ".#####.#",
               "#.###...",
               ".##.##.."),
}
PLAYER['left0'] = g_flip_h(PLAYER['right0'])
PLAYER['left1'] = g_flip_h(PLAYER['right1'])
PLAYER['atk_left'] = g_flip_h(PLAYER['atk_right'])

BAT = [G("........",
         "#......#",
         "##.##.##",
         "########",
         ".##..##.",
         "...##...",
         "........",
         "........"),
       G("........",
         "........",
         "...##...",
         ".######.",
         "##.##.##",
         "#..##..#",
         "........",
         "........")]

SKELETON = [G("..###...",
              "..#.#...",
              "..###...",
              "#.#.#.#.",
              ".#####..",
              "..#.#...",
              "..###...",
              ".##.##.."),
            G("..###...",
              "..#.#...",
              "..###...",
              ".##.#..#",
              ".#####.#",
              "..#.#...",
              "..###...",
              "..#..##."),
            G("..###..#",
              "..#.#.#.",
              "..###.#.",
              ".######.",
              "..###...",
              "..#.#...",
              "..###...",
              ".##.##..")]

SLASH = {  # sword arcs: 3 cells across the facing direction, 2 frames
    'h': [G("....##..",
            "......#.",
            ".......#",
            ".......#",
            ".......#",
            ".......#",
            "......#.",
            "....##.."),
          G("..##....",
            "....##..",
            "......#.",
            "......#.",
            "......#.",
            "......#.",
            "....##..",
            "..##....")],
    'v': [G("........",
            "........",
            "........",
            "........",
            "........",
            "#......#",
            ".##..##.",
            "...##..."),
          G("........",
            "........",
            "#......#",
            ".#....#.",
            "..####..",
            "........",
            "........",
            "........")],
}

FX = {
    'fire0': G("........",
               "...##...",
               "..####..",
               ".##.###.",
               ".######.",
               "..####..",
               "...##...",
               "........"),
    'fire1': G("........",
               "..#.#...",
               "...###..",
               "..#####.",
               ".##.##..",
               "..####..",
               "...#....",
               "........"),
    'boom0': G("........",
               "...#....",
               ".#.#.#..",
               "..###...",
               "#######.",
               "..###...",
               ".#.#.#..",
               "...#...."),
    'boom1': G("#..#..#.",
               ".#.#.#..",
               "..#.#...",
               "##...##.",
               "..#.#...",
               ".#.#.#..",
               "#..#..#.",
               "........"),
    'boom2': G("#.....#.",
               "........",
               "..#.#...",
               "........",
               "..#.#...",
               "........",
               "#.....#.",
               "........"),
    'spark': G("........",
               "...#....",
               "...#....",
               ".##.##..",
               "...#....",
               "...#....",
               "........",
               "........"),
    'mote': G("........",
              "........",
              "........",
              "....#...",
              "........",
              "........",
              "........",
              "........"),
    'mote2': G("........",
               "........",
               "...#....",
               "..###...",
               "...#....",
               "........",
               "........",
               "........"),
    'dust0': G("........",
               "..#..#..",
               "#..##..#",
               ".#.##.#.",
               "..####..",
               ".#.##.#.",
               "#..#...#",
               "........"),
    'dust1': G("#......#",
               "...#....",
               ".#....#.",
               "....#...",
               "..#....#",
               "#....#..",
               "...#....",
               ".#....#."),
    'potion': G("...##...",
                "..#..#..",
                "...##...",
                "..####..",
                ".######.",
                ".######.",
                "..####..",
                "........"),
    'coin': G("........",
              "..####..",
              ".##..##.",
              ".#.##.#.",
              ".#.##.#.",
              ".##..##.",
              "..####..",
              "........"),
}

HUD = {
    'heart': G("........",
               ".##.##..",
               "#######.",
               "#######.",
               ".#####..",
               "..###...",
               "...#....",
               "........"),
    'heart_e': G("........",
                 ".##.##..",
                 "#..#..#.",
                 "#.....#.",
                 ".#...#..",
                 "..#.#...",
                 "...#....",
                 "........"),
    'orb': G("........",
             "..###...",
             ".##.##..",
             "#.####.#",
             "#######.",
             ".#####..",
             "..###...",
             "........"),
    'orb_e': G("........",
               "..###...",
               ".#...#..",
               "#.....#.",
               "#.....#.",
               ".#...#..",
               "..###...",
               "........"),
    'sword': G("......##",
               ".....###",
               "....###.",
               "#..###..",
               ".####...",
               "..##....",
               ".#.##...",
               "#...#..."),
    'flame': G("...#....",
               "..##....",
               "..###...",
               ".####.#.",
               ".######.",
               "##.####.",
               ".#####..",
               "..###..."),
    'gem': G("........",
             "..####..",
             ".#.##.#.",
             "########",
             ".#.##.#.",
             "..#..#..",
             "...##...",
             "........"),
    'bar_l': G("########",
               "#.......",
               "#.#.#.#.",
               "#.......",
               "#.#.#.#.",
               "#.......",
               "#.......",
               "########"),
    'bar_m': G("########",
               "........",
               ".#.#.#.#",
               "........",
               ".#.#.#.#",
               "........",
               "........",
               "########"),
    'bar_r': G("########",
               ".......#",
               "#.#.#.##",
               ".......#",
               "#.#.#.##",
               ".......#",
               ".......#",
               "########"),
    'rule': G("........",
              "........",
              "........",
              "##.##.##",
              "........",
              "........",
              "........",
              "........"),
    'rule_x': G("........",
                "...#....",
                "..#.#...",
                "##.#.###",
                "..#.#...",
                "...#....",
                "........",
                "........"),
}


# ----------------------------------------------------------------- font
# Chiselled 8x8 capitals with small serifs; cell space used 7x7.
FONT_ROWS = {
    'A': ["..##...", ".#..#..", "#....#.", "#....#.", "######.", "#....#.", "#....#."],
    'B': ["#####..", ".#...#.", ".####..", ".#...#.", ".#...#.", ".#...#.", "#####.."],
    'C': [".####..", "#....#.", "#......", "#......", "#......", "#....#.", ".####.."],
    'D': ["####...", ".#..#..", ".#...#.", ".#...#.", ".#...#.", ".#..#..", "####..."],
    'E': ["######.", ".#.....", ".#.....", ".####..", ".#.....", ".#.....", "######."],
    'F': ["######.", ".#.....", ".#.....", ".####..", ".#.....", ".#.....", "###...."],
    'G': [".####..", "#....#.", "#......", "#..###.", "#....#.", "#....#.", ".#####."],
    'H': ["##..##.", "#....#.", "#....#.", "######.", "#....#.", "#....#.", "##..##."],
    'I': [".###...", "..#....", "..#....", "..#....", "..#....", "..#....", ".###..."],
    'J': ["..####.", "....#..", "....#..", "....#..", "#...#..", "#...#..", ".###..."],
    'K': ["##..##.", ".#..#..", ".#.#...", ".##....", ".#.#...", ".#..#..", "##..##."],
    'L': ["###....", ".#.....", ".#.....", ".#.....", ".#.....", ".#...#.", "######."],
    'M': ["#....#.", "##..##.", "#.##.#.", "#.##.#.", "#....#.", "#....#.", "##..##."],
    'N': ["#....#.", "##...#.", "#.#..#.", "#..#.#.", "#...##.", "#....#.", "##...#."],
    'O': [".####..", "#....#.", "#....#.", "#....#.", "#....#.", "#....#.", ".####.."],
    'P': ["#####..", ".#...#.", ".#...#.", ".####..", ".#.....", ".#.....", "###...."],
    'Q': [".####..", "#....#.", "#....#.", "#....#.", "#..#.#.", "#...#..", ".###.#."],
    'R': ["#####..", ".#...#.", ".#...#.", ".####..", ".#..#..", ".#...#.", "##...##"],
    'S': [".####..", "#....#.", "#......", ".####..", ".....#.", "#....#.", ".####.."],
    'T': ["#######", "#..#..#", "...#...", "...#...", "...#...", "...#...", "..###.."],
    'U': ["##..##.", "#....#.", "#....#.", "#....#.", "#....#.", "#....#.", ".####.."],
    'V': ["##..##.", "#....#.", "#....#.", ".#..#..", ".#..#..", "..##...", "..##..."],
    'W': ["##..##.", "#....#.", "#....#.", "#.##.#.", "#.##.#.", "##..##.", "#....#."],
    'X': ["##..##.", ".#..#..", "..##...", "..##...", "..##...", ".#..#..", "##..##."],
    'Y': ["##..##.", ".#..#..", "..##...", "..##...", "...#...", "...#...", "..###.."],
    'Z': ["######.", "#...#..", "...#...", "..#....", ".#.....", "#....#.", "######."],
    '0': [".####..", "#...##.", "#..#.#.", "#.#..#.", "##...#.", "#....#.", ".####.."],
    '1': ["..#....", ".##....", "..#....", "..#....", "..#....", "..#....", ".###..."],
    '2': [".####..", "#....#.", ".....#.", "...##..", "..#....", ".#.....", "######."],
    '3': [".####..", "#....#.", ".....#.", "..###..", ".....#.", "#....#.", ".####.."],
    '4': ["...##..", "..#.#..", ".#..#..", "#...#..", "######.", "....#..", "...###."],
    '5': ["######.", "#......", "#####..", ".....#.", ".....#.", "#....#.", ".####.."],
    '6': ["..###..", ".#.....", "#......", "#####..", "#....#.", "#....#.", ".####.."],
    '7': ["######.", "#....#.", "....#..", "...#...", "..#....", "..#....", "..#...."],
    '8': [".####..", "#....#.", "#....#.", ".####..", "#....#.", "#....#.", ".####.."],
    '9': [".####..", "#....#.", "#....#.", ".#####.", ".....#.", "....#..", ".###..."],
    ' ': ["......."] * 7,
    '.': [".......", ".......", ".......", ".......", ".......", "..##...", "..##..."],
    ',': [".......", ".......", ".......", ".......", "..##...", "..##...", ".#....."],
    ':': [".......", "..##...", "..##...", ".......", "..##...", "..##...", "......."],
    '!': ["..##...", "..##...", "..##...", "..##...", "..##...", ".......", "..##..."],
    '?': [".####..", "#....#.", "....#..", "...#...", "...#...", ".......", "...#..."],
    '-': [".......", ".......", ".......", ".#####.", ".......", ".......", "......."],
    "'": ["..##...", "..##...", "..#....", ".......", ".......", ".......", "......."],
    '/': [".....#.", "....#..", "....#..", "...#...", "..#....", "..#....", ".#....."],
    '(': ["...##..", "..#....", ".#.....", ".#.....", ".#.....", "..#....", "...##.."],
    ')': [".##....", "...#...", "....#..", "....#..", "....#..", "...#...", ".##...."],
    '+': [".......", "...#...", "...#...", ".#####.", "...#...", "...#...", "......."],
    '=': [".......", ".......", ".#####.", ".......", ".#####.", ".......", "......."],
    '*': [".......", ".#.#.#.", "..###..", ".#####.", "..###..", ".#.#.#.", "......."],  # used as middle dot
    '>': [".#.....", "..#....", "...#...", "....#..", "...#...", "..#....", ".#....."],
    '<': ["....#..", "...#...", "..#....", ".#.....", "..#....", "...#...", "....#.."],
    '#': [".......", ".......", "...#...", "..###..", "...#...", ".......", "......."],  # centre dot (middle dot)
}


def font_glyph(ch):
    rows = FONT_ROWS[ch]
    rows = [r + '.' * (8 - len(r)) for r in rows] + ['........']
    return g_from_rows(rows)
