"""BELLARIUS stage 2: CANDY CASTLE - cake underfoot, lollipop trees, and a
birthday cake that fights back. VIBED BY BPM 2026"""
import random
import numpy as np
from gfx import Canvas
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

NAME = 'CANDY CASTLE'
WAVE_TYPES = ['SWEETS', 'FAIRIES', 'POPCORN', 'GUM', 'GUMMIES', 'LOLLY', 'SWEETV']
MW = 600
NEAR_ROWS = [16, 17, 18, 19, 20, 21, 22]
FAR_ROWS = [13, 14, 15]
CAKE = BROWN
HAZE = MAGENTA


def sky_rows():
    return [BLUE] * 6 + [HAZE] * 13 + [CAKE] * 4


# ---------------------------------------------------------------- scenery
def castles(c, x0, x1):
    """far rows 13-15 (y 104..127): candy castles and gumdrop hills"""
    rnd = random.Random(3)
    x = x0
    while x < x1:
        k = rnd.random()
        if k < 0.35:                                    # a gumdrop hill
            w = rnd.choice([32, 48])
            c.ellipse(x + w // 2, 127, w // 2, 12, BMAGENTA)
            x += w + 8
        elif k < 0.55:                                  # a candy castle
            c.rect(x, 112, 40, 16, BMAGENTA)
            for t in (0, 16, 32):
                c.rect(x + t, 106, 8, 8, BMAGENTA)
                for i in range(5):
                    c.rect(x + t + 4 - i, 100 + i, 2 * i, 1, WHITE)
            c.rect(x + 16, 118, 8, 10, MAGENTA)
            x += 56
        else:
            x += rnd.choice([16, 32])


def icing(c, x0, x1):
    """row 16 (y 128..135): the cake's icing, dripping"""
    c.rect(x0, 128, x1 - x0, 4, WHITE)
    for x in range(x0, x1, 12):
        c.rect(x + 3, 132, 3, 2 + (x // 12) % 3, WHITE)


def sprinkles(c, x0, x1, rnd):
    for x in range(x0, x1, 4):
        if rnd.random() < 0.25:
            c.rect(x, 140 + rnd.randrange(44), 2, 1, rnd.choice([YELLOW, BGREEN, BCYAN, WHITE]))


def lollipop(c, x, rnd):
    h = rnd.choice([12, 16, 20])
    top = 136 - h
    c.rect(x + 8, top + 8, 2, h, WHITE)
    col = rnd.choice([BRED, BGREEN, YELLOW])
    c.ellipse(x + 9, top + 4, 9, 7, col)
    c.ellipse(x + 9, top + 4, 5, 4, WHITE)
    c.ellipse(x + 9, top + 4, 2, 1, col)
    return 24


def cane(c, x):
    for y in range(104, 136):
        c.rect(x + 4, y, 3, 1, BRED if (y // 3) % 2 else WHITE)
    for i in range(8):
        c.rect(x + 4 + i, 102 - (i * (8 - i)) // 6, 3, 2, BRED if i % 2 else WHITE)
    return 20


def cupcake(c, x):
    c.ellipse(x + 10, 118, 10, 7, BMAGENTA)
    c.rect(x + 9, 108, 2, 3, BRED)
    for i in range(7):
        c.rect(x + 2 + i, 124 + i // 2, 16 - 2 * i // 2, 1, YELLOW)
    c.rect(x + 3, 124, 14, 12, YELLOW)
    c.hatch(x + 3, 124, 14, 12, BROWN, period=3)
    return 28


def gumdrop(c, x, rnd):
    col = rnd.choice([BGREEN, YELLOW, BCYAN, BRED])
    c.ellipse(x + 7, 132, 7, 8, col)
    c.rect(x, 132, 15, 4, col)
    return 20


def sign(c, x):
    """the visual gag: a warning sign"""
    c.rect(x, 104, 104, 24, YELLOW)
    c.rect(x + 2, 106, 100, 20, BLACK + 1)
    c.text(x + 4, 107, 'WARNING:', YELLOW)
    c.text(x + 4, 117, 'SUGAR RUSH', YELLOW)
    c.rect(x + 50, 128, 3, 8, WHITE)
    return 120


def build_scenery(seed=2):
    rnd = random.Random(seed)
    W = (MW + 1) * 8
    near = Canvas(W, 184)
    far = Canvas(W, 184)
    castles(far, 0, W)
    icing(near, 0, W)
    sprinkles(near, 0, W, rnd)
    x = 64
    end = (MW - 48) * 8
    nsign = 900
    while x < end:
        if x >= nsign:
            x += sign(near, x)
            nsign = x + rnd.randrange(1500, 2100)
            continue
        k = rnd.random()
        if k < 0.30:
            x += lollipop(near, x, rnd)
        elif k < 0.45:
            x += cane(near, x)
        elif k < 0.62:
            x += cupcake(near, x)
        elif k < 0.80:
            x += gumdrop(near, x, rnd)
        else:
            x += rnd.choice([24, 40, 56])
        x = (x + 7) // 8 * 8
    near.rect(end + 40, 108, 72, 20, WHITE)
    near.text(end + 44, 110, 'PARTY', BMAGENTA)
    near.text(end + 44, 119, '>>>>', BMAGENTA)
    near.rect(end + 74, 128, 2, 8, WHITE)
    # all of it 24 px lower: the cake's top is at y 152, things stand on it
    near.a[:] = np.roll(near.a, 24, axis=0)
    near.a[:128] = 0
    return near, far


def heights(near):
    a = near.a
    ceil, floor = [], []
    for m in range(MW + 1):
        col = a[:, m * 8:m * 8 + 8]
        ceil.append(0)
        bot = col[128:160] != 0
        ys = np.nonzero(bot.any(1))[0]
        floor.append(128 + int(ys.min()) if len(ys) else 152)
    return ceil, floor


# ---------------------------------------------------------------- enemies
SPRITES = {
    'SWEET0': ["#.........#.", "##.######.##", "############", "##.######.##", "#.........#."],
    'SWEET1': [".#.......#..", "##.######.##", "############", "##.######.##", ".#.......#.."],
    'FAIRY0': ["##....##......", "###..###......", ".##..##.......", "..#####.......", "..##o##..#....", "...###..###...", "...#.#...#....", ".............."],
    'FAIRY1': ["..............", "..............", "##..##........", "#######.......", "..##o##..#....", "...###..###...", "...#.#...#....", ".............."],
    'POP0': [".##.##.....", "##########.", "##.####.##.", ".########..", "..######..."],
    'POP1': ["..#.#.#....", ".########..", "##########.", "##.####.##.", ".########.."],
    'GUM': ["...####...", ".########.", "####.#####", "###.######", "##########", ".########.", "...####..."],
    'GUMMY0': [".##....##.", "##########", ".#.####.#.", ".########.", "##########", "#.######.#", "..##..##..", ".###..###."],
    'GUMMY1': [".##....##.", "##########", ".#.####.#.", ".########.", "##########", "#.######.#", ".##....##.", ".##....##."],
    'LOLLY': ["...####.........", "..######........", ".##.##.##.......", ".#.####.#.......", ".##.##.##.......", "..######........", "...############.", "..............."],
    'SMOKE0': ["...####.....", "..######.##.", ".##########.", "############", ".##########.", "..########..", "....####....", "............"],
    'SMOKE1': ["............", "....####....", "..########..", ".##########.", "############", ".#########..", "..##.####...", "............"],
    'CHERRY': ["....#.", "...#..", "..#...", ".###..", "#####.", "#####.", ".###.."],
}
SPRITES = {k: [r.replace('o', '.').ljust(max(len(x) for x in v), '.') for r in v] for k, v in SPRITES.items()}
SPRITE_ORDER = list(SPRITES.keys())

# ---------------------------------------------------------------- THE BIRTHDAY CAKE
BC_BODY, BC_DARK, BC_EYE, BC_WARN, BC_ICING, BC_CANDLE, BC_GAS, BC_FLAME = 1, 2, 3, 4, 5, 6, 7, 8
BOSS_PAL = [0, BMAGENTA, MAGENTA, WHITE, RED, WHITE, BCYAN, BCYAN, YELLOW, 0, 0, 0, 0, 0, 0, 0]
BW, BH = 80, 64


def cake(variant):
    """0 candles lit, 1 tilting (flinging cherries), 2 the cake knife out, 3 FLAMES OUT"""
    c = Canvas(BW, BH)
    tilt = 2 if variant == 1 else 0
    # three tiers
    for (y, x0, x1) in ((16, 30, 66), (30, 22, 74), (44, 14, 80)):
        c.rect(x0 - tilt, y, x1 - x0, 14, BC_BODY)
        c.rect(x0 - tilt, y, x1 - x0, 3, BC_ICING)
        for x in range(x0 + 2, x1 - 2, 6):
            c.rect(x - tilt, y + 3, 2, 2 + (x // 6) % 3, BC_ICING)
    # the face, on the middle tier
    for ex in (40, 56):
        c.ellipse(ex - tilt, 36, 4, 3, BC_EYE)
        c.rect(ex - 1 - tilt, 35, 2, 2, BC_DARK)
    c.rect(42 - tilt, 50, 14, 2, BC_DARK)
    # the candles (the weak spot): lit, or out and smoking
    for i in range(5):
        cx = 32 + i * 7 - tilt
        c.rect(cx, 6, 3, 10, BC_GAS)
        if variant != 3:
            c.rect(cx, 2, 3, 3, BC_FLAME)
            c.px(cx + 1, 1, BC_FLAME)
        else:
            c.px(cx + 1, 3, BC_DARK)
            c.px(cx + 2, 1, BC_DARK)
    # the cake knife, or a spoon of cherries
    if variant == 2:
        c.rect(0, 30, 22, 4, BC_EYE)
        c.rect(0, 34, 22, 2, BC_EYE)
        c.rect(22, 30, 6, 6, BC_DARK)
    elif variant == 1:
        c.line(20, 30, 4, 10, BC_DARK)
        c.ellipse(4, 8, 4, 3, BC_WARN)
    # the plate
    c.rect(8, 58, 72, 3, BC_ICING)
    return c.a


def boss_frames():
    return [cake(v) for v in range(4)]


def waves():
    rnd = random.Random(11)
    W = []
    col = 30
    pattern = ['SWEETS', 'GUMMIES', 'GUM', 'POPCORN', 'FAIRIES', 'SWEETS', 'LOLLY', 'GUMMIES',
               'POPCORN', 'GUM', 'FAIRIES', 'SWEETV', 'POPCORN', 'LOLLY', 'GUMMIES', 'FAIRIES']
    i = 0
    while col < MW - 50:
        W.append((col, pattern[i % len(pattern)], rnd.randrange(16, 80)))
        col += rnd.randrange(13, 20)
        i += 1
    return W
