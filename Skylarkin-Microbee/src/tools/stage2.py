"""SKYLARKIN' stage 2: BARBIE BEACH - sunset over the sand, a barbecue that
fights back. Scenery (strip rows), enemies and THE GREAT AUSTRALIAN BARBIE.
VIBED BY BPM 2026"""
import random
import numpy as np
from gfx import Canvas
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

NAME = 'BARBIE BEACH'
WAVE_TYPES = ['THONGS', 'GULLS', 'SNAGS', 'BALL', 'CRABS', 'LILO', 'FLAGS']
MW = 600
NEAR_ROWS = [16, 17, 18, 19, 20, 21, 22]
FAR_ROWS = [13, 14, 15]
SAND = BROWN
SEA = BLUE


def sky_rows():
    """paper colour of every playfield row (0..22): a sunset"""
    s = [BLUE] * 4 + [MAGENTA] * 4 + [RED] * 5 + [SEA] * 3 + [SAND] * 7
    return s


# ---------------------------------------------------------------- scenery
def sea(c, x0, x1):
    """far rows 13-15 (y 104..127): the sea, the setting sun, a yacht"""
    y0 = 104
    c.rect(x0, y0, x1 - x0, 24, SEA)
    rnd = random.Random(3)
    # the sun sinking into the sea, once
    for sx in (x0 + 180,):
        c.ellipse(sx, y0 + 6, 18, 9, YELLOW)
        c.rect(sx - 20, y0 + 6, 40, 10, SEA)
        for k in range(3):
            c.rect(sx - 14 + k * 4, y0 + 8 + k * 3, 28 - k * 8, 1, YELLOW)
    # glints on the water
    for i in range(0, x1 - x0, 6):
        if rnd.random() < 0.5:
            c.rect(x0 + i, y0 + 10 + rnd.randrange(12), rnd.choice([2, 3, 4]), 1, BCYAN)
    # a yacht now and then
    for yx in range(x0 + 420, x1, 700):
        c.rect(yx, y0 + 14, 14, 3, WHITE)
        c.line(yx + 7, y0 + 1, yx + 7, y0 + 13, GREY)
        for k in range(10):
            c.rect(yx + 8, y0 + 3 + k, max(1, k - 2), 1, WHITE)


def waterline(c, x0, x1):
    """row 16 (y 128..135): foam on the shore"""
    y = 128
    c.rect(x0, y, x1 - x0, 8, SAND)
    for x in range(x0, x1, 16):
        c.ellipse(x + 8, y + 1, 9, 2, WHITE)
    c.rect(x0, y, x1 - x0, 1, BCYAN)


def sand(c, x0, x1, rnd):
    for x in range(x0, x1, 3):
        if rnd.random() < 0.18:
            c.px(x, 136 + rnd.randrange(48), YELLOW)


def sandcastle(c, x, h):
    top = 184 - h
    c.rect(x, top + 8, 24, h - 8, YELLOW)
    for i in range(0, 24, 6):
        c.rect(x + i, top + 4, 3, 4, YELLOW)
    c.rect(x + 8, top, 8, 8, YELLOW)
    c.rect(x + 10, top - 4, 1, 4, WHITE)
    c.rect(x + 11, top - 4, 4, 2, BRED)
    c.rect(x + 10, top + 14, 4, 6, SAND)
    return 32


def umbrella(c, x, rnd):
    col = rnd.choice([BRED, BMAGENTA, BBLUE])
    for i in range(16):
        w = 2 * i + 4
        y = 144 + i // 2
        c.rect(x + 18 - w // 2, y, w, 1, col if (i // 4) % 2 == 0 else WHITE)
    c.rect(x + 17, 152, 2, 32, WHITE)
    return 40


def esky(c, x):
    c.rect(x, 170, 22, 14, BBLUE)
    c.rect(x, 168, 22, 3, WHITE)
    c.rect(x + 8, 166, 6, 2, WHITE)
    c.text(x + 3, 174, 'ES', WHITE)
    return 28


def towel(c, x, rnd):
    col = rnd.choice([BRED, BGREEN, BMAGENTA, BCYAN])
    c.rect(x, 180, 32, 4, col)
    c.hatch(x, 180, 32, 4, WHITE, period=4)
    return 36


def surfboard(c, x):
    c.ellipse(x + 3, 160, 3, 22, WHITE)
    c.rect(x + 2, 150, 2, 20, BRED)
    return 12


def flags(c, x):
    """the visual gag: the lifeguards' sign between two flags"""
    for fx in (x, x + 112):
        c.rect(fx, 140, 2, 44, WHITE)
        c.rect(fx + 2, 140, 12, 4, BRED)
        c.rect(fx + 2, 144, 12, 4, YELLOW)
    c.rect(x + 18, 144, 88, 24, WHITE)
    c.text(x + 20, 146, 'NO SHOOT', BRED)
    c.text(x + 20, 158, 'EM UPS!', BRED)
    c.rect(x + 60, 168, 2, 16, WHITE)
    return 136


def bbq_stall(c, x):
    """a little barbecue, a hint of things to come"""
    c.rect(x, 164, 24, 4, DGREY)
    c.rect(x + 2, 168, 2, 16, DGREY)
    c.rect(x + 20, 168, 2, 16, DGREY)
    for i in range(3):
        c.rect(x + 3 + i * 7, 162, 5, 2, BRED)
    return 32


def build_scenery(seed=2):
    rnd = random.Random(seed)
    W = (MW + 1) * 8
    near = Canvas(W, 184)
    far = Canvas(W, 184)
    sea(far, 0, W)
    waterline(near, 0, W)
    near.rect(0, 136, W, 48, SAND)
    sand(near, 0, W, rnd)
    x = 64
    end = (MW - 48) * 8
    nflag = 900
    while x < end:
        if x >= nflag:
            x += flags(near, x) + 16
            nflag = x + rnd.randrange(1400, 2000)
            continue
        k = rnd.random()
        if k < 0.20:
            x += sandcastle(near, x, rnd.choice([24, 32, 40]))
        elif k < 0.40:
            x += umbrella(near, x, rnd)
        elif k < 0.52:
            x += esky(near, x)
        elif k < 0.64:
            x += towel(near, x, rnd)
        elif k < 0.72:
            x += surfboard(near, x)
        elif k < 0.80:
            x += bbq_stall(near, x)
        else:
            x += rnd.choice([24, 40, 56])
        x = (x + 7) // 8 * 8
    # a sign before the arena
    near.rect(end + 40, 148, 64, 20, WHITE)
    near.text(end + 44, 150, 'SNAGS', BRED)
    near.text(end + 44, 159, '$2 EA', BRED)
    near.rect(end + 70, 168, 2, 16, WHITE)
    return near, far


def heights(near):
    a = near.a
    ceil, floor = [], []
    for m in range(MW + 1):
        col = a[:, m * 8:m * 8 + 8]
        ceil.append(0)
        # the sand itself is not an obstacle: things standing on it are
        bot = (col[136:184] != 0) & (col[136:184] != SAND) & (col[136:184] != YELLOW)
        bot[:, :] &= True
        ys = np.nonzero(bot.any(1))[0]
        floor.append(136 + int(ys.min()) if len(ys) else 184)
    return ceil, floor


# ---------------------------------------------------------------- enemies
SPRITES = {
    'THONG0': ["...#........", "..###..###..", "############", "############", ".##########.", "..##....##.."],
    'THONG1': ["..##....##..", ".##########.", "############", "############", "..###..###..", "...#........"],
    'GULL0': ["##..........##", ".###......###.", "..###.##.###..", "...########...", "....######....", ".....####.##..", "......##......", ".............."],
    'GULL1': ["..............", "..............", ".......##.....", "..##########..", ".############.", "##...####..###", "......##......", ".............."],
    'SNAG0': ["..#.#.#.....", ".##########.", "############", "############", ".##########."],
    'SNAG1': ["...#.#.#....", ".##########.", "############", "############", ".##########."],
    'BALL': ["...####...", ".##.##.##.", "##..##..##", "##.####.##", "##..##..##", ".##.##.##.", "...####..."],
    'CRAB0': ["#........#", "##......##", ".#.#..#.#.", "..######..", ".########.", "#.######.#", "#.#....#.#", ".#......#."],
    'CRAB1': ["##......##", ".#......#.", "..#.##.#..", "..######..", ".########.", "#.######.#", ".#.#..#.#.", "#........#"],
    'LILO': ["################", "#.#.#.#.#.#.#.##", "################", ".##############."],
    'SMOKE0': ["...####.....", "..######.##.", ".##########.", "############", ".##########.", "..########..", "....####....", "............"],
    'SMOKE1': ["............", "....####....", "..########..", ".##########.", "############", ".#########..", "..##.####...", "............"],
}
SPRITE_ORDER = list(SPRITES.keys())

# ---------------------------------------------------------------- the boss: THE GREAT AUSTRALIAN BARBIE
BC_BODY, BC_DARK, BC_EYE, BC_WARN, BC_HOT, BC_SNAG, BC_GAS, BC_FLAME = 1, 2, 3, 4, 5, 6, 7, 8
BOSS_PAL = [0, DGREY, GREY, WHITE, RED, BRED, BROWN, YELLOW, YELLOW, 0, 0, 0, 0, 0, 0, 0]
BW, BH = 80, 64


def barbie(variant):
    """0 idle, 1 flipping (hood up, spatula up), 2 tongs out, 3 GAS LOW (flames out, gas bottle open)"""
    c = Canvas(BW, BH)
    # the hood with its googly eyes
    if variant == 1:
        c.line(24, 20, 70, 2, BC_DARK)
        for i in range(4):
            c.line(24, 20 - i, 70, 2 - i, BC_BODY)
    else:
        c.ellipse(46, 22, 24, 12, BC_BODY)
        c.rect(20, 22, 54, 12, 0)
    for ex in (36, 52):
        c.ellipse(ex, 14 if variant != 1 else 10, 5, 4, BC_EYE)
        c.rect(ex - 3, (14 if variant != 1 else 10) - 1, 3, 3, BC_DARK)
    # the hotplate and its snags
    c.rect(20, 32, 54, 4, BC_HOT)
    if variant != 1:
        for i in range(5):
            c.rect(24 + i * 10, 29, 8, 3, BC_SNAG)
    # flames under the plate (gone when the gas runs out)
    if variant != 3:
        for i in range(6):
            c.rect(24 + i * 8, 36, 3, 3, BC_FLAME)
            c.px(25 + i * 8, 35, BC_FLAME)
    # the body (a trolley) and wheels
    c.rect(22, 39, 50, 14, BC_BODY)
    c.rect(22, 39, 50, 1, BC_DARK)
    c.rect(26, 43, 18, 6, BC_DARK)                  # knobs panel
    for i in range(3):
        c.rect(28 + i * 6, 45, 2, 2, BC_EYE)
    c.rect(24, 53, 3, 7, BC_DARK)
    c.rect(66, 53, 3, 7, BC_DARK)
    c.ellipse(25, 60, 4, 3, BC_DARK)
    c.ellipse(67, 60, 4, 3, BC_DARK)
    # the gas bottle on the side (the weak spot): the valve glows when it's open
    c.ellipse(12, 48, 6, 8, BC_GAS)
    c.rect(10, 38, 4, 3, BC_WARN if variant == 3 else BC_DARK)
    c.line(14, 40, 22, 40, BC_DARK)
    # the spatula or the tongs
    if variant == 1:
        c.line(16, 26, 4, 6, BC_DARK)
        c.rect(0, 2, 10, 5, BC_EYE)
    elif variant == 2:
        c.rect(0, 30, 22, 2, BC_EYE)
        c.rect(0, 34, 22, 2, BC_EYE)
        c.line(0, 28, 4, 30, BC_EYE)
        c.line(0, 37, 4, 35, BC_EYE)
    else:
        c.line(18, 30, 12, 22, BC_DARK)
    return c.a


def boss_frames():
    return [barbie(v) for v in range(4)]


# ---------------------------------------------------------------- waves
def waves():
    rnd = random.Random(11)
    W = []
    col = 30
    pattern = ['THONGS', 'CRABS', 'BALL', 'SNAGS', 'GULLS', 'THONGS', 'LILO', 'CRABS',
               'SNAGS', 'BALL', 'GULLS', 'THONGS', 'SNAGS', 'LILO', 'CRABS', 'GULLS']
    i = 0
    while col < MW - 50:
        W.append((col, pattern[i % len(pattern)], rnd.randrange(16, 96)))
        col += rnd.randrange(13, 20)
        i += 1
    return W
