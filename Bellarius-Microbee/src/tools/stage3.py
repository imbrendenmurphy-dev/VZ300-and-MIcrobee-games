"""BELLARIUS stage 3: TOY BOX - the nursery floor, block towers, a toy
train, and the JACK-IN-THE-BOX. VIBED BY BPM 2026"""
import random
import numpy as np
from gfx import Canvas
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

NAME = 'TOY BOX'
WAVE_TYPES = ['BEES', 'FROGS', 'MICE', 'BALL', 'PLANES', 'TRAIN', 'RPLANE']
MW = 600
NEAR_ROWS = [15, 16, 17, 18, 19, 20, 21, 22]
FAR_ROWS = [12, 13]
DIRT = RED


def sky_rows():
    return [BLUE] * 12 + [BLUE] * 2 + [BLUE] * 1 + [BLUE] * 5 + [DIRT] * 3


# ---------------------------------------------------------------- scenery
def shelf(c, x0, x1):
    """far rows 12-13 (y 96..111): a shelf of toys, books and teddies"""
    rnd = random.Random(4)
    c.rect(x0, 108, x1 - x0, 4, BROWN)
    x = x0
    while x < x1:
        k = rnd.random()
        if k < 0.4:                                     # books
            for b in range(rnd.randrange(3, 6)):
                c.rect(x + b * 4, 96 + rnd.randrange(3), 3, 12, rnd.choice([BRED, BGREEN, YELLOW, BCYAN]))
            x += 28
        elif k < 0.6:                                   # a teddy
            c.ellipse(x + 6, 103, 5, 5, BROWN)
            c.ellipse(x + 6, 97, 3, 3, BROWN)
            c.px(x + 3, 95, BROWN)
            c.px(x + 9, 95, BROWN)
            x += 20
        else:
            x += rnd.choice([16, 24, 40])


def track(c, x0, x1):
    """the toy train's track: rows 20-21 (y 160..175), carpet below"""
    c.rect(x0, 160, x1 - x0, 16, DGREY)
    for x in range(x0, x1, 8):
        c.rect(x, 162, 4, 12, BROWN)
    c.rect(x0, 164, x1 - x0, 2, GREY)
    c.rect(x0, 170, x1 - x0, 2, GREY)
    c.rect(x0, 176, x1 - x0, 8, DIRT)
    c.hatch(x0, 177, x1 - x0, 7, BRED, period=4)


def blocks(c, x, word, rnd):
    """alphabet blocks side by side on the floor, spelling something
    (16 x 16, on whole cells: two colours each, no clash)"""
    for i, ch in enumerate(word):
        col = [BRED, BGREEN, BBLUE, BMAGENTA][i % 4]
        c.rect(x + i * 16, 144, 16, 16, col)
        c.text(x + i * 16 + 4, 148, ch, WHITE)
    if len(word) > 2:
        c.rect(x + 8, 128, 16, 16, YELLOW)
        c.text(x + 12, 132, '*', BRED)
    return 16 * len(word) + 8


def top(c, x):
    for i in range(7):
        c.rect(x + 7 - i, 146 + i, 2 * i + 1, 1, BMAGENTA if i % 2 else YELLOW)
        c.rect(x + 7 - i, 158 - i, 2 * i + 1, 1, BMAGENTA if i % 2 else YELLOW)
    c.rect(x + 7, 142, 1, 4, WHITE)
    return 20


def horse(c, x):
    c.ellipse(x + 16, 156, 16, 3, BROWN)
    c.rect(x + 6, 138, 18, 8, WHITE)
    c.rect(x + 22, 130, 6, 10, WHITE)
    c.rect(x + 26, 132, 4, 3, WHITE)
    c.rect(x + 20, 129, 3, 6, BRED)
    for lx in (7, 20):
        c.line(x + lx, 146, x + lx - 2, 155, WHITE)
        c.line(x + lx + 2, 146, x + lx + 4, 155, WHITE)
    return 36


def crayons(c, x, rnd):
    for i in range(4):
        col = rnd.choice([BRED, BGREEN, BBLUE, YELLOW, BMAGENTA])
        c.rect(x + i * 5, 140 + i, 4, 20 - i, col)
        c.rect(x + i * 5 + 1, 137 + i, 2, 3, col)
    return 28


def note(c, x):
    """the visual gag: Mum's note (on whole cells)"""
    c.rect(x, 128, 88, 24, WHITE)
    c.text(x + 4, 131, 'TIDY YOUR', BRED)
    c.text(x + 4, 141, 'ROOM! MUM', BRED)
    c.rect(x + 40, 152, 8, 8, GREY)
    return 104


def build_scenery(seed=3):
    rnd = random.Random(seed)
    W = (MW + 1) * 8
    near = Canvas(W, 184)
    far = Canvas(W, 184)
    shelf(far, 0, W)
    track(near, 0, W)
    x = 48
    end = (MW - 48) * 8
    nnote = 600
    words = ['BELL', 'TOY', 'ABC', 'FUN', 'DING', 'BOX']
    while x < end:
        if x >= nnote:
            x += note(near, x) + 8
            nnote = x + rnd.randrange(1300, 1900)
            continue
        k = rnd.random()
        if k < 0.30:
            x += blocks(near, x, rnd.choice(words), rnd)
        elif k < 0.48:
            x += top(near, x)
        elif k < 0.60:
            x += horse(near, x)
        elif k < 0.75:
            x += crayons(near, x, rnd)
        else:
            x += rnd.choice([24, 40, 64])
        x = (x + 7) // 8 * 8
    near.rect(end + 24, 128, 80, 22, YELLOW)
    near.text(end + 28, 130, 'DO NOT', BRED)
    near.text(end + 28, 140, ' OPEN', BRED)
    near.rect(end + 62, 150, 3, 10, GREY)
    return near, far


def heights(near):
    a = near.a
    ceil, floor = [], []
    for m in range(MW + 1):
        col = a[:, m * 8:m * 8 + 8]
        ceil.append(0)
        bot = col[112:160] != 0
        ys = np.nonzero(bot.any(1))[0]
        floor.append(112 + int(ys.min()) if len(ys) else 160)
    return ceil, floor


# ---------------------------------------------------------------- enemies
SPRITES = {
    'BEE0': ["#.#.", "####", "#.##", ".##."],
    'BEE1': [".#.#", "####", "#.##", ".##."],
    'FROG0': ["............", "..##....##..", ".####..####.", "############", "##.######.##", ".##########.", "..########..",
              "...######...", "...#....#...", "..#......#..", ".#........#.", "##........##"],
    'FROG1': ["............", "............", "..##....##..", ".####..####.", "############", "##.######.##", ".##########.",
              "..########..", "...######...", "...##..##...", "..##....##..", ".###....###."],
    'MOUSE0': ["..........", "......##..", ".....####.", "..#######.", ".########.", "#########.", ".#######..", "..#...#...",
               "....##....", "...#..#...", "..........."],
    'MOUSE1': ["..........", "......##..", ".....####.", "..#######.", ".########.", "#########.", ".#######..", "...#.#....",
               "....##....", "....##....", "..........."],
    'BALL': ["...####...", ".##.##.##.", "##..##..##", "##########", "##..##..##", ".##.##.##.", "...####..."],
    'PLANE0': ["....#.......", "############", "....#.......", "..######..#.", "############", "....#.......", "............", "............"],
    'PLANE1': ["....#.......", "############", "....#....#..", "..######.#..", "############", "....#.......", "............", "............"],
    'CAB': ["..##..............####", "..##..............####", ".####.....############", "######################",
            "######################", "######################", "##.######..######.####", "#.#.###..##..###.#.###",
            ".#.#.....##.....#.#...", "..........##.........."],
    'GLOB': [".##.", "####", "####", ".##."],
    'TRAILER': ["######################", "#....##....##....##..#", "#....##....##....##..#", "######################",
                "######################", "######################", "######################", "##.##.#########.##.###",
                "#....#..........#....#", ".####............####."],
}
SPRITES = {k: [r.ljust(max(len(x) for x in v), '.')[:max(len(x) for x in v)] for r in v] for k, v in SPRITES.items()}
SPRITE_ORDER = list(SPRITES.keys())

# ---------------------------------------------------------------- THE JACK-IN-THE-BOX
BC_BODY, BC_DARK, BC_EYE, BC_WARN, BC_LEG, BC_ANT, BC_SAUCE, BC_STAR = 1, 2, 3, 4, 5, 6, 7, 8
BOSS_PAL = [0, BRED, RED, WHITE, YELLOW, GREY, BMAGENTA, BCYAN, YELLOW, 0, 0, 0, 0, 0, 0, 0]
BW, BH = 80, 64


def jack(variant):
    """0 bobbing on its spring, 1 the boxing glove wound back (the punch), 2 squashed down in
    its box (the BOING dash), 3 dizzy (stars)"""
    c = Canvas(BW, BH)
    # the box: a cube with stripes and a crank handle
    c.rect(36, 40, 36, 24, BC_BODY)
    c.hatch(36, 40, 36, 24, BC_SAUCE, period=6)
    c.rect(36, 40, 36, 2, BC_WARN)
    c.rect(72, 48, 6, 2, BC_LEG)
    c.rect(77, 44, 2, 8, BC_LEG)
    if variant == 2:
        # squashed: the lid half shut, two eyes peeping out
        c.rect(36, 34, 36, 6, BC_DARK)
        c.ellipse(48, 37, 3, 2, BC_EYE)
        c.ellipse(60, 37, 3, 2, BC_EYE)
        return c.a
    # the spring
    for k in range(5):
        c.ellipse(54, 36 - k * 4, 6, 1, BC_LEG)
    # the head: a clown with a pointed hat
    c.ellipse(54, 12, 11, 10, BC_EYE)
    for i in range(10):
        c.rect(54 - i // 2, 2 + i - 10 + 1, i, 1, BC_WARN) if False else None
    for i in range(9):
        c.rect(54 - i, -6 + i + 6, 2 * i + 1, 1, BC_SAUCE) if i > 3 else None
    c.ellipse(48, 10, 2, 2, BC_DARK)
    c.ellipse(60, 10, 2, 2, BC_DARK)
    c.ellipse(54, 15, 3, 2, BC_BODY)                    # the nose
    c.rect(48, 19, 12, 2, BC_DARK)
    if variant == 3:
        c.line(46, 8, 50, 12, BC_DARK)
        c.line(46, 12, 50, 8, BC_DARK)
        c.line(58, 8, 62, 12, BC_DARK)
        c.line(58, 12, 62, 8, BC_DARK)
        for sx, sy in ((38, 2), (70, 4), (54, 0)):
            c.rect(sx, sy, 3, 1, BC_STAR)
            c.rect(sx + 1, sy - 1, 1, 3, BC_STAR)
    # the arm with a boxing glove (wound back, glowing, for the punch)
    col = BC_WARN if variant == 1 else BC_ANT
    c.line(44, 26, 18, 34, col)
    c.line(44, 27, 18, 35, col)
    c.ellipse(12, 36, 7, 5, BC_BODY)
    c.rect(4, 34, 4, 4, BC_BODY)
    return c.a


def boss_frames():
    return [jack(v) for v in range(4)]


def waves():
    rnd = random.Random(13)
    W = []
    col = 30
    pattern = ['PLANES', 'FROGS', 'BEES', 'BALL', 'MICE', 'TRAIN', 'PLANES', 'RPLANE',
               'BEES', 'FROGS', 'BALL', 'MICE', 'TRAIN', 'BEES', 'RPLANE', 'FROGS']
    i = 0
    while col < MW - 50:
        W.append((col, pattern[i % len(pattern)], rnd.randrange(16, 100)))
        col += rnd.randrange(13, 20)
        i += 1
    return W
