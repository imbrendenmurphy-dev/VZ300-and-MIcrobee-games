"""SKYLARKIN' stage 5: HEAD OFFICE - up the side of the GLOBAL CONSOLIDATED
PAPERWORK tower at night, through red tape, to THE CEO. VIBED BY BPM 2026"""
import random
import numpy as np
from gfx import Canvas
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

NAME = 'HEAD OFFICE'
WAVE_TYPES = ['MANAGERS', 'BRIEFS', 'MEMOS', 'TAPE', 'SHREDDER', 'RBRIEF', 'BONUS']
MW = 640
NEAR_ROWS = [0, 1, 16, 17, 18, 19, 20, 21, 22]
FAR_ROWS = [12]
NIGHT = BLACK


def sky_rows():
    s = [NIGHT] * 23
    s[0] = s[1] = BLUE
    for r in range(2, 8):
        s[r] = BLUE if r < 5 else NIGHT
    s[12] = NIGHT
    for r in range(16, 23):
        s[r] = NIGHT
    return s


def overhang(c, x0, x1, rnd):
    """rows 0-1: the tower's ledge, with a neon sign now and then"""
    c.rect(x0, 0, x1 - x0, 6, DGREY)
    c.rect(x0, 6, x1 - x0, 1, GREY)
    for x in range(x0, x1, 24):
        c.rect(x, 7, 2, 6, DGREY)
    x = x0 + 200
    while x < x1 - 260:
        t = rnd.choice(['GLOBAL CONSOLIDATED', 'PAPERWORK PTY LTD', 'WE VALUE YOUR TIME'])
        w = len(t) * 8 + 8
        c.rect(x, 0, w, 10, BLACK + 4)
        c.text(x + 4, 1, t, BMAGENTA)
        x += w + rnd.randrange(400, 700)


def lights(c, x0, x1):
    """far row 12 (y 96..103): the city below, far away"""
    rnd = random.Random(9)
    pat = [(rnd.randrange(8), rnd.choice([YELLOW, WHITE, BRED, YELLOW])) if rnd.random() < 0.35 else None for _ in range(64)]
    for i, x in enumerate(range(x0, x1, 2)):
        p = pat[i % 64]                         # the same 128 px of city, over and over
        if p:
            c.px(x, 96 + p[0], p[1])


def windows_block(c, x, w, h, rnd):
    """an office floor block rising from the bottom: lit windows, desk lamps"""
    top = 184 - h
    c.rect(x, top, w, h, BBLUE)
    k = rnd.randrange(3)
    for j, yy in enumerate(range(top + 4, 180, 8)):
        for i, xx in enumerate(range(x + 2, x + w - 6, 8)):
            c.rect(xx, yy, 5, 5, YELLOW if (i + j + k) % 3 else BLUE)
    c.rect(x, top, w, 2, CYAN)
    return w + 8


def trays(c, x, n):
    """IN and OUT trays piled high (the OUT tray much lower)"""
    for i in range(n):
        y = 176 - (i + 1) * 6
        c.rect(x, y, 24, 5, GREY)
        c.rect(x + 1, y + 1, 22, 3, WHITE)
    c.text(x + 4, 176 - n * 6 - 9, 'IN', WHITE)
    c.rect(x + 30, 170, 24, 5, GREY)
    c.text(x + 30, 160, 'OUT', WHITE)
    return 64


def lift(c, x):
    c.rect(x, 120, 20, 64, DGREY)
    c.rect(x + 2, 122, 16, 60, GREY)
    c.rect(x + 9, 122, 1, 60, DGREY)
    c.rect(x + 4, 112, 12, 8, BRED)
    c.text(x + 6, 112, '^', WHITE)
    return 28


def plant(c, x):
    c.rect(x + 2, 168, 10, 8, BROWN)
    for k in range(5):
        c.line(x + 7, 168, x + k * 3, 152 + (k % 2) * 4, BGREEN)
    return 20


def floor(c, x0, x1):
    c.rect(x0, 176, x1 - x0, 8, GREY)
    c.hatch(x0, 177, x1 - x0, 7, DGREY, period=4)


def build_scenery(seed=5):
    rnd = random.Random(seed)
    W = (MW + 1) * 8
    near = Canvas(W, 184)
    far = Canvas(W, 184)
    overhang(near, 0, W, rnd)
    lights(far, 0, W)
    floor(near, 0, W)
    x = 40
    end = (MW - 48) * 8
    while x < end:
        k = rnd.random()
        if k < 0.30:
            x += windows_block(near, x, rnd.choice([40, 56, 72]), rnd.choice([24, 32, 48]), rnd)
        elif k < 0.48:
            x += trays(near, x, rnd.choice([3, 5, 7]))
        elif k < 0.62:
            x += lift(near, x)
        elif k < 0.76:
            x += plant(near, x)
        else:
            x += rnd.choice([24, 40, 56])
        x = (x + 7) // 8 * 8
    near.rect(end + 24, 140, 88, 30, DGREY)
    near.rect(end + 26, 142, 84, 26, BROWN)
    near.text(end + 30, 146, 'BOARDROOM', YELLOW)
    near.text(end + 30, 156, 'KNOCK!', YELLOW)
    return near, far


def heights(near):
    a = near.a
    ceil, floor_ = [], []
    for m in range(MW + 1):
        col = a[:, m * 8:m * 8 + 8]
        top = col[0:16].any(1)
        ys = np.nonzero(top)[0]
        ceil.append(int(ys.max()) + 1 if len(ys) else 0)
        bot = col[112:184].any(1)
        ys = np.nonzero(bot)[0]
        floor_.append(112 + int(ys.min()) if len(ys) else 184)
    return ceil, floor_


SPRITES = {
    'MANAGER0': ["....###.....", "...#####....", "...#.#.#....", "...#####....", "....###.....", "..#######...",
                 ".###.#.###..", "#.#######.##", "..#######.##", "..###.###...", "..##...##...", ".###...###.."],
    'MANAGER1': ["....###.....", "...#####....", "...#.#.#....", "...#####....", "....###.....", "..#######.##",
                 ".###.#.#####", "#.#######...", "..#######...", "..###.###...", "..##...##...", ".###...###.."],
    'BRIEF0': ["....####....", "....#..#....", "############", "#..........#", "############", "#....##....#", "############"],
    'BRIEF1': ["....####....", "....#..#....", "############", "#....##....#", "############", "#..........#", "############"],
    'MEMO0': ["#######.", "#.....##", "#.###..#", "#......#", "#.####.#", "########"],
    'MEMO1': [".#######", "##.....#", "#..###.#", "#......#", "#.####.#", "########"],
    'TAPE': ["########", "#.#..#.#", "##.##.##", "#.#..#.#", "########", "##.##.##", "#.#..#.#", "########"],
    'SHRED0': ["############", "#..........#", "############", "#.#.#.#.#.##", "############", ".#........#."],
    'SHRED1': ["#.#.#.#.#.#.", "############", "#..........#", "############", "############", ".#........#."],
    'ENVELOPE': ["##########", "##......##", "#.#....#.#", "#..#..#..#", "#...##...#", "#........#", "##########"],
    'PIE': ["..####..", ".##.###.", "###.####", "#######.", "########", ".######.", "..####.."],
    'STAMP': ["......############......", "......############......", ".......##########.......", "........########........",
              "........########........", "########################", "########################", "#..#..##..#..##.##.###.#",
              "#.#.#.#.#.#.#.##.#.#..#.", "#.#.#.##..#.#.#..#.##.#.", "#..#..##..#..##.##.###.#", "########################"],
}
SPRITES = {k: [r.ljust(max(len(x) for x in v), '.') for r in v] for k, v in SPRITES.items()}
SPRITE_ORDER = list(SPRITES.keys())

# ---------------------------------------------------------------- THE CEO
BC_BODY, BC_DARK, BC_EYE, BC_WARN, BC_SUIT, BC_TIE, BC_CHAIR, BC_GOLD = 1, 2, 3, 4, 5, 6, 7, 8
BOSS_PAL = [0, GREY, DGREY, WHITE, RED, BBLUE, BRED, BROWN, YELLOW, 0, 0, 0, 0, 0, 0, 0]


def ceo(variant):
    """0 seated, 1 throwing a pie chart, 2 STAMP arm raised, 3 tie unravelled (the last phase)"""
    c = Canvas(80, 64)
    # the chair: a huge golden swivel chair on a mech base
    c.rect(30, 2, 30, 34, BC_CHAIR)
    c.rect(32, 4, 26, 30, BC_GOLD if variant != 3 else BC_CHAIR)
    c.rect(26, 34, 38, 6, BC_CHAIR)
    c.rect(42, 40, 6, 8, BC_DARK)
    c.ellipse(45, 54, 24, 6, BC_DARK)
    c.rect(22, 50, 46, 8, BC_BODY)
    for i in range(5):
        c.ellipse(26 + i * 9, 60, 3, 3, BC_DARK)
    # the CEO: big head, tiny suit
    c.ellipse(40, 14, 9, 9, BC_BODY)
    c.rect(33, 11, 5, 3, BC_EYE)
    c.rect(42, 11, 5, 3, BC_EYE)
    c.rect(34, 12, 2, 2, BC_DARK)
    c.rect(43, 12, 2, 2, BC_DARK)
    c.rect(35, 19, 10, 2, BC_DARK)                      # a thin smile
    c.rect(31, 4, 18, 3, BC_DARK)                       # slicked hair
    c.rect(31, 22, 18, 13, BC_SUIT)
    if variant == 3:
        c.line(40, 23, 30, 30, BC_TIE)
        c.line(40, 24, 18, 34, BC_TIE)
        c.line(41, 24, 6, 40, BC_TIE)
        c.line(41, 25, 0, 44, BC_TIE)
    else:
        c.rect(39, 23, 3, 10, BC_TIE)
    # the arms
    if variant == 1:
        c.line(31, 24, 14, 12, BC_SUIT)
        c.ellipse(11, 10, 6, 5, BC_WARN)                # a pie chart in hand
        c.line(11, 10, 11, 5, BC_EYE)
        c.line(11, 10, 16, 10, BC_EYE)
    elif variant == 2:
        c.line(31, 24, 20, 4, BC_SUIT)
        c.rect(14, 0, 12, 4, BC_CHAIR)                  # the stamp handle, raised
    else:
        c.line(31, 26, 20, 32, BC_SUIT)
        c.rect(14, 30, 8, 5, BC_GOLD)                   # a pen
    c.line(49, 26, 58, 32, BC_SUIT)
    return c.a


def boss_frames():
    return [ceo(v) for v in range(4)]


def waves():
    rnd = random.Random(23)
    W = []
    col = 30
    pattern = ['MEMOS', 'MANAGERS', 'BRIEFS', 'TAPE', 'SHREDDER', 'BONUS', 'MANAGERS', 'RBRIEF',
               'TAPE', 'MEMOS', 'BRIEFS', 'SHREDDER', 'MANAGERS', 'TAPE', 'RBRIEF', 'BONUS', 'MEMOS']
    i = 0
    while col < MW - 50:
        W.append((col, pattern[i % len(pattern)], rnd.randrange(24, 100)))
        col += rnd.randrange(13, 19)
        i += 1
    return W
