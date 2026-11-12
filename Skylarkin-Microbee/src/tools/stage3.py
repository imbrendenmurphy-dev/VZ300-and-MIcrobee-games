"""SKYLARKIN' stage 3: BIG THINGS HIGHWAY - the outback, a long straight
road, the Big Things on the horizon and THE BIG PRAWN. VIBED BY BPM 2026"""
import random
import numpy as np
from gfx import Canvas
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

NAME = 'BIG THINGS HWY'
WAVE_TYPES = ['FLIES', 'ROOS', 'EMUS', 'WEED', 'GALAHS', 'TRUCK', 'RGALAH']
MW = 600
NEAR_ROWS = [15, 16, 17, 18, 19, 20, 21, 22]
FAR_ROWS = [12, 13]
DIRT = RED


def sky_rows():
    return [BLUE] * 6 + [CYAN] * 6 + [CYAN] * 2 + [DIRT] * 9


# ---------------------------------------------------------------- scenery
def horizon(c, x0, x1):
    """far rows 12-13 (y 96..111): mesas and the Big Things"""
    y0 = 96
    rnd = random.Random(4)
    x = x0
    while x < x1:
        w = rnd.choice([24, 40, 56])
        h = rnd.randrange(4, 12)
        c.rect(x, y0 + 16 - h, w, h, BROWN)
        c.rect(x + 2, y0 + 16 - h, w - 4, 1, YELLOW)
        x += w + rnd.choice([16, 32, 48])
    # the Big Things (the visual gag), each once
    bx = x0 + 300
    c.ellipse(bx, y0 + 6, 3, 7, YELLOW)                 # the Big Banana (standing up)
    c.ellipse(bx + 3, y0 + 6, 3, 7, 0)
    c.rect(bx - 1, y0 - 1, 2, 2, BROWN)
    px_ = x0 + 760
    c.ellipse(px_, y0 + 9, 5, 6, YELLOW)                # the Big Pineapple
    c.hatch(px_ - 5, y0 + 3, 11, 12, BROWN, period=3)
    for k in (-3, 0, 3):
        c.line(px_, y0 + 3, px_ + k, y0 - 3, BGREEN)
    mx = x0 + 1250
    c.ellipse(mx, y0 + 7, 9, 5, WHITE)                  # the Big Merino
    c.ellipse(mx - 9, y0 + 5, 3, 3, WHITE)
    c.rect(mx - 6, y0 + 11, 2, 5, GREY)
    c.rect(mx + 5, y0 + 11, 2, 5, GREY)


def road(c, x0, x1):
    """the highway: rows 20-21 (y 160..175), red dirt below"""
    c.rect(x0, 160, x1 - x0, 16, DGREY)
    c.rect(x0, 160, x1 - x0, 1, GREY)
    c.rect(x0, 175, x1 - x0, 1, GREY)
    for x in range(x0, x1, 32):
        c.rect(x, 167, 16, 2, WHITE)
    c.rect(x0, 176, x1 - x0, 8, DIRT)


def dirt(c, x0, x1, rnd):
    for x in range(x0, x1, 4):
        if rnd.random() < 0.3:
            c.px(x, 152 + rnd.randrange(8), BROWN)
        if rnd.random() < 0.3:
            c.px(x, 177 + rnd.randrange(7), BROWN)


def gum(c, x, rnd):
    h = rnd.choice([28, 36, 44])
    c.rect(x + 9, 160 - h, 3, h, WHITE)
    c.line(x + 10, 160 - h + 8, x + 2, 160 - h, WHITE)
    c.line(x + 11, 160 - h + 6, x + 19, 160 - h - 2, WHITE)
    for cx, cy in ((x + 3, 160 - h - 3), (x + 18, 160 - h - 5), (x + 10, 160 - h - 9)):
        c.ellipse(cx, cy, 6, 4, GREEN)
    return 28


def mound(c, x):
    c.ellipse(x + 6, 152, 6, 12, BROWN)
    c.rect(x, 152, 13, 8, BROWN)
    c.hatch(x + 1, 142, 11, 18, YELLOW, period=5)
    return 20


def sign(c, x, kind):
    c.rect(x + 7, 140, 2, 20, GREY)
    if kind == 0:   # kangaroo crossing: a yellow diamond
        for i in range(8):
            c.rect(x + 8 - i, 124 + i, 2 * i, 1, YELLOW)
            c.rect(x + 8 - i, 139 - i, 2 * i, 1, YELLOW)
        c.rect(x + 6, 129, 4, 5, BROWN)
        c.rect(x + 4, 133, 2, 3, BROWN)
        return 24
    w = 72
    c.rect(x, 124, w, 18, GREEN)
    c.rect(x + w // 2, 140, 2, 20, GREY)
    c.text(x + 4, 125, 'NXT SERVO', WHITE)
    c.text(x + 4, 133, ' 900 KM', WHITE)
    return w + 8


def dunny(c, x):
    c.rect(x, 136, 18, 24, BROWN)
    c.rect(x - 2, 134, 22, 3, GREY)
    c.rect(x + 7, 140, 4, 2, YELLOW)                    # the crescent moon window
    c.rect(x + 3, 144, 12, 16, YELLOW)
    c.hatch(x + 3, 144, 12, 16, BROWN, period=3)
    return 28


def fence(c, x0, x1):
    for x in range(x0, x1, 16):
        c.rect(x, 150, 2, 10, BROWN)
    c.rect(x0, 152, x1 - x0, 1, GREY)
    c.rect(x0, 156, x1 - x0, 1, GREY)


def build_scenery(seed=3):
    rnd = random.Random(seed)
    W = (MW + 1) * 8
    near = Canvas(W, 184)
    far = Canvas(W, 184)
    horizon(far, 0, W)
    near.rect(0, 120, W, 40, 0)
    road(near, 0, W)
    dirt(near, 0, W, rnd)
    x = 48
    end = (MW - 48) * 8
    nsign = 600
    while x < end:
        if x >= nsign:
            x += sign(near, x, 1) + 8
            nsign = x + rnd.randrange(1200, 1800)
            continue
        k = rnd.random()
        if k < 0.30:
            x += gum(near, x, rnd)
        elif k < 0.48:
            x += mound(near, x)
        elif k < 0.58:
            x += sign(near, x, 0)
        elif k < 0.66:
            x += dunny(near, x)
        elif k < 0.80:
            fx = rnd.choice([48, 64, 96])
            fence(near, x, x + fx)
            x += fx
        else:
            x += rnd.choice([24, 40, 64])
        x = (x + 7) // 8 * 8
    near.rect(end + 24, 128, 80, 22, YELLOW)
    near.text(end + 28, 130, 'BIG PRAWN', BRED)
    near.text(end + 28, 140, ' NEXT', BRED)
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
    'FLY0': ["#.#.", ".##.", "####", ".##."],
    'FLY1': [".#.#", ".##.", "####", ".##."],
    'ROO0': ["........##..", ".......####.", "......####..", ".....####...", "...######...", "..########..", ".#########..",
             ".##.######..", "#....####...", ".....##.##..", "....##...##.", "...##....###"],
    'ROO1': ["........##..", ".......####.", "......####..", ".....####...", "...######...", "..########..", ".#########..",
             "##..######..", ".....####...", ".....####...", ".....##.##..", "....####.###"],
    'EMU0': ["....##....", "...####...", "....##....", "....##....", "....##....", ".######...", "########..", ".######...", "..#..#....",
             "..#..#....", ".##.##...."],
    'EMU1': ["..........", "....##....", "...####...", "....##....", "....##....", ".######...", "########..", ".######...", "...##.....",
             "..#..#....", "##...##..."],
    'WEED': ["..#.##.#..", ".#.#..#.#.", "#.#.##.#.#", ".#.#..#.#.", "#.##..##.#", ".#.#..#.#.", "..#.##.#.."],
    'GALAH0': ["...##.......", "..####......", ".##.####....", "##########..", "..########..", "....##..##..", "..........#.", "............"],
    'GALAH1': ["...##.......", "..####..##..", ".##.######..", "##########..", "..######....", "....##......", "............", "............"],
    'CAB': ["..######..............", ".########.............", "##.####.##............", "##.####.##.###########",
            "######################", "######################", "######################", "###.##.########.##.###",
            ".#....#..........#..#.", "..####............##.."],
    'GLOB': [".##.", "####", "####", ".##."],
    'TRAILER': ["######################", "#....................#", "#....................#", "#....................#",
                "######################", "######################", "######################", "##.##.#########.##.###",
                "#....#..........#....#", ".####............####."],
}
SPRITE_ORDER = list(SPRITES.keys())

# ---------------------------------------------------------------- THE BIG PRAWN
BC_BODY, BC_DARK, BC_EYE, BC_WARN, BC_LEG, BC_ANT, BC_SAUCE, BC_STAR = 1, 2, 3, 4, 5, 6, 7, 8
BOSS_PAL = [0, BRED, RED, WHITE, YELLOW, BMAGENTA, BMAGENTA, BMAGENTA, YELLOW, 0, 0, 0, 0, 0, 0, 0]
BW, BH = 80, 64


def prawn(variant):
    """0 idle, 1 antennae glowing (sweep), 2 curled for the dash, 3 dizzy (stars)"""
    c = Canvas(BW, BH)
    if variant == 2:
        c.ellipse(44, 34, 26, 22, BC_BODY)
        c.ellipse(44, 34, 14, 11, BC_DARK)
        c.ellipse(44, 34, 10, 7, 0)
        for i in range(4):
            c.rect(30 + i * 8, 12, 2, 4, BC_DARK)
        c.ellipse(26, 26, 4, 3, BC_EYE)
        c.rect(25, 25, 2, 2, BC_DARK)
        return c.a
    # the body: a curved fibreglass prawn on its tummy, head to the left
    for i in range(7):
        cx = 22 + i * 8
        cy = 32 - int(10 * np.sin(i / 6.0 * np.pi))
        c.ellipse(cx, cy, 7, 11 - i // 2, BC_BODY)
        c.rect(cx - 1, cy - 9 + i // 2, 1, 18 - i, BC_DARK)
    c.ellipse(72, 40, 6, 8, BC_BODY)                    # the tail fan
    c.line(66, 36, 79, 30, BC_DARK)
    c.line(66, 44, 79, 50, BC_DARK)
    # legs
    for i in range(6):
        c.line(20 + i * 7, 42, 16 + i * 7, 54, BC_LEG)
    # head and eye
    c.ellipse(14, 30, 10, 9, BC_BODY)
    c.ellipse(10, 24, 5, 4, BC_EYE)
    c.rect(8, 23, 3, 3, BC_DARK)
    if variant == 3:
        c.line(5, 21, 13, 27, BC_DARK)
        c.line(5, 27, 13, 21, BC_DARK)
        for sx, sy in ((4, 10), (16, 6), (26, 12)):     # dizzy stars
            c.rect(sx, sy, 3, 1, BC_STAR)
            c.rect(sx + 1, sy - 1, 1, 3, BC_STAR)
    # the antennae: long whips forward
    col = BC_WARN if variant == 1 else BC_ANT
    c.line(8, 22, 0, 4, col)
    c.line(9, 22, 2, 2, col)
    c.line(6, 28, 0, 38, col)
    c.line(7, 29, 1, 40, col)
    # the pole it stands on
    c.rect(44, 52, 4, 12, BC_DARK)
    return c.a


def boss_frames():
    return [prawn(v) for v in range(4)]


def waves():
    rnd = random.Random(13)
    W = []
    col = 30
    pattern = ['GALAHS', 'ROOS', 'FLIES', 'WEED', 'EMUS', 'TRUCK', 'GALAHS', 'RGALAH',
               'FLIES', 'ROOS', 'WEED', 'EMUS', 'TRUCK', 'FLIES', 'RGALAH', 'ROOS']
    i = 0
    while col < MW - 50:
        W.append((col, pattern[i % len(pattern)], rnd.randrange(16, 100)))
        col += rnd.randrange(13, 20)
        i += 1
    return W
