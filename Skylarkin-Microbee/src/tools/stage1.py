"""SKYLARKIN' stage 1: OPEN PLAN - an office floating in the night sky.
Scenery (strip rows), enemies and the COPYTRON 9000 (VIBED BY BPM 2026)."""
import random
import numpy as np
from gfx import Canvas, grid
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

NAME = 'OPEN PLAN'
MW = 600                    # map columns (8 px); the scroll stops at MW - 40
NEAR_ROWS = [0, 1, 17, 18, 19, 20, 21, 22]
FAR_ROWS = [4, 5]
WALL = BLUE


def sky_rows():
    """paper colour of every playfield row (0..22)"""
    s = [WALL] * 23
    s[0] = s[1] = DGREY
    s[4] = s[5] = BLACK
    for r in range(17, 23):
        s[r] = WALL
    return s


# ---------------------------------------------------------------- scenery
def ceiling(c, x0, x1, rnd):
    # ceiling tiles: grey with a dark grid every 32 px
    c.rect(x0, 0, x1 - x0, 12, GREY)
    for x in range(x0 - x0 % 32, x1, 32):
        c.rect(x, 0, 1, 12, DGREY)
    c.rect(x0, 11, x1 - x0, 1, DGREY)
    x = x0 + 24
    while x < x1 - 48:
        k = rnd.random()
        if k < 0.55:        # fluorescent tube fitting
            c.rect(x, 12, 40, 3, DGREY)
            c.rect(x + 2, 13, 36, 2, WHITE)
            x += 72 + rnd.randrange(3) * 16
        elif k < 0.75:      # air vent
            c.rect(x, 3, 24, 7, DGREY)
            for i in range(0, 24, 2):
                c.rect(x + i, 4, 1, 5, BLACK)
            x += 56
        else:               # a sprinkler head and a smoke detector
            c.rect(x + 3, 12, 2, 2, WHITE)
            c.ellipse(x + 20, 12, 4, 2, WHITE)
            x += 48


BANNERS = ['TEAMWROK', 'SYNERGY!', 'THINK OUTSIDE', 'NO FUN', 'WORK HARDR', 'DEADLINE']


def banner(c, x, text, ink, paper):
    w = len(text) * 8 + 8
    c.rect(x, 8, w, 8, paper)
    c.rect(x, 7, 1, 1, DGREY)
    c.text(x + 4, 8, text, ink)
    return w


def windows(c, x0, x1, rnd):
    """far layer rows 4-5 (y 32..47): windows on the night city"""
    y0 = 32
    c.rect(x0, y0, x1 - x0, 16, BLACK)
    # skyline: one 256-px stretch, repeated
    x = x0
    sky_rnd = rnd
    rnd = __import__('random').Random(5)
    x1_real, x1 = x1, x0 + 256
    while x < x1:
        w = rnd.choice([8, 12, 16, 16, 24])
        h = rnd.randrange(4, 15)
        c.rect(x, y0 + 16 - h, w, h, DGREY)
        for yy in range(y0 + 16 - h + 2, y0 + 15, 3):
            for xx in range(x + 1, x + w - 1, 3):
                if rnd.random() < 0.35:
                    c.px(xx, yy, YELLOW)
        x += w
    x1 = x1_real
    for xx in range(x0 + 256, x1, 256):
        w_ = min(256, x1 - xx)
        c.a[y0:y0 + 16, xx:xx + w_] = c.a[y0:y0 + 16, x0:x0 + w_]
    rnd = sky_rnd
    # the moon now and then
    for mx in range(x0 + 104, x1, 768):
        c.ellipse(mx, y0 + 5, 4, 3, WHITE)
    # window frames: a mullion every 48 px, the wall between window pairs
    for x in range(x0 - x0 % 48, x1, 48):
        c.rect(x, y0, 2, 16, GREY)
    for x in range(x0 - x0 % 192, x1, 192):
        c.rect(x, y0, 16, 16, WALL)
        c.rect(x + 16, y0, 2, 16, GREY)


def carpet(c, x0, x1):
    c.rect(x0, 176, x1 - x0, 8, BROWN)
    c.hatch(x0, 177, x1 - x0, 7, RED, period=2)


def cubicle(c, x, w, h=36):
    top = 176 - h
    c.rect(x, top, w, h, GREY)
    c.hatch(x, top + 3, w, h - 3, DGREY, period=2)
    c.rect(x, top, w, 2, WHITE)
    c.rect(x, top, 2, h, WHITE)
    return w


def desk(c, x, rnd):
    c.rect(x, 158, 40, 3, BROWN)
    c.rect(x + 2, 161, 3, 15, BROWN)
    c.rect(x + 35, 161, 3, 15, BROWN)
    # a Microbee on the desk: grey case, green screen
    c.rect(x + 8, 146, 18, 12, GREY)
    c.rect(x + 10, 148, 14, 8, BGREEN)
    for yy, ln in zip(range(149, 156, 2), (10, 6, 11, 4)):
        c.rect(x + 11, yy, ln, 1, GREEN)
    c.rect(x + 6, 156, 22, 2, GREY)
    if rnd.random() < 0.5:   # a mug
        c.rect(x + 30, 152, 5, 6, WHITE)
        c.px(x + 35, 154, WHITE)
    return 44


def cabinet(c, x, h=40):
    top = 176 - h
    c.rect(x, top, 18, h, GREY)
    for yy in range(top + 9, 176, 10):
        c.rect(x, yy, 18, 1, DGREY)
        c.rect(x + 7, yy - 5, 4, 1, WHITE)
    return 22


def plant(c, x):
    c.rect(x + 3, 166, 10, 10, BROWN)
    c.ellipse(x + 8, 158, 7, 6, BGREEN)
    c.ellipse(x + 4, 152, 3, 4, GREEN)
    c.ellipse(x + 12, 151, 3, 5, GREEN)
    return 18


def cooler(c, x):
    c.rect(x + 2, 160, 14, 16, WHITE)
    c.rect(x + 4, 143, 10, 17, BCYAN)
    c.rect(x + 6, 141, 6, 2, BCYAN)
    c.rect(x + 5, 146, 2, 10, WHITE)
    return 20


def chair(c, x):
    c.rect(x + 2, 150, 4, 14, DGREY)
    c.rect(x + 2, 162, 14, 3, DGREY)
    c.rect(x + 8, 165, 2, 7, DGREY)
    c.rect(x + 3, 172, 12, 2, DGREY)
    c.px(x + 3, 175, GREY)
    c.px(x + 14, 175, GREY)
    return 20


def printer(c, x):
    c.rect(x, 162, 24, 14, GREY)
    c.rect(x + 2, 158, 20, 4, DGREY)
    c.rect(x + 4, 156, 16, 2, WHITE)
    c.rect(x + 18, 165, 3, 2, BGREEN)
    return 28


def build_scenery(seed=1):
    rnd = random.Random(seed)
    W = (MW + 1) * 8
    near = Canvas(W, 184)
    far = Canvas(W, 184)
    ceiling(near, 0, W, rnd)
    # motivational banners hang from the ceiling now and then (the visual gag)
    x = 200
    while x < (MW - 50) * 8:
        t = BANNERS[rnd.randrange(len(BANNERS))]
        banner(near, x, t, WHITE, RED if rnd.random() < 0.6 else MAGENTA)
        x += rnd.randrange(500, 800) // 8 * 8
    windows(far, 0, W, rnd)
    carpet(near, 0, W)
    # the floor: cubicles, desks, cabinets ... with clear stretches
    x = 64
    end = (MW - 48) * 8
    while x < end:
        k = rnd.random()
        if k < 0.22:
            x += cubicle(near, x, rnd.choice([40, 56, 72]), rnd.choice([24, 32, 40])) + 8
        elif k < 0.42:
            x += desk(near, x, rnd)
        elif k < 0.52:
            x += cabinet(near, x, rnd.choice([32, 40, 48]))
        elif k < 0.62:
            x += plant(near, x)
        elif k < 0.68:
            x += cooler(near, x)
        elif k < 0.76:
            x += chair(near, x)
        elif k < 0.82:
            x += printer(near, x)
        else:
            x += rnd.choice([24, 40, 64])
        x = (x + 7) // 8 * 8
    # the copy room: a door sign before the arena
    near.rect(end + 40, 140, 40, 36, DGREY)
    near.rect(end + 42, 142, 36, 34, BROWN)
    near.text(end + 44, 146, 'COPY', WHITE)
    near.text(end + 44, 156, 'ROOM', WHITE)
    return near, far


def heights(near):
    """per map column: lowest ceiling pixel + 1 and highest floor pixel (y)"""
    a = near.a
    ceil = []
    floor = []
    for m in range(MW + 1):
        col = a[:, m * 8:m * 8 + 8]
        top = col[0:24].any(1)
        ys = np.nonzero(top)[0]
        ceil.append(int(ys.max()) + 1 if len(ys) else 0)
        bot = col[136:184].any(1)
        ys = np.nonzero(bot)[0]
        floor.append(136 + int(ys.min()) if len(ys) else 184)
    return ceil, floor


# ---------------------------------------------------------------- enemies (stage sprite frames)
SPRITES = {
    'PLANE0': ["#...........", "###.........", ".#####......", "..#########.", ".#####......", "###........."],
    'PLANE1': ["............", "##..........", ".#####......", "..#########.", ".######.....", "####........"],
    'STAPLER0': ["....#######.", "..##########", ".##.........", "############", "############", "#.#.......#.", "............", "............"],
    'STAPLER1': ["..........##", ".......####.", "....#####...", ".#######....", "..##........", "############", "############", "#.#.......#."],
    'MUG0': ["..#..#....", "...#..#...", "..#..#....", "#######...", "#.....###.", "#.....#.#.", "#.....###.", "#.....#...", "#######...", ".#####...."],
    'MUG1': ["...#..#...", "..#..#....", "...#..#...", "#######...", "#.....###.", "#.....#.#.", "#.....###.", "#.....#...", "#######...", ".#####...."],
    'CHAIR0': ["......####....", "......#..#....", "......#..#....", "......####....", "......#.......", "...#######....", "...#######....", "......#.......",
               "......#.......", "..#########...", ".#....#....#..", "#.....#.....#."],
    'CHAIR1': ["......####....", "......#..#....", "......#..#....", "......####....", "......#.......", "...#######....", "...#######....", "......#.......",
               "......#.......", "..#########...", "..#...#...#...", ".#....#....#.."],
    'SHEET0': ["#######.", "#.....##", "#.###..#", "#......#", "#.####.#", "#......#", "########"],
    'SHEET1': [".######.", "##.....#", "#..###.#", "#......#", "#.####.#", "##.....#", ".#######"],
    'BALLOON': ["..####....", ".######...", "########..", "####.###..", "###.####..", "########..", ".######...", "..####....", "...##.....",
                "....#.....", "...#......", "....#.....", ".....#...."],
    'BUBBLE': [".###.", "#..##", "#...#", "#...#", ".###."],
    'PRINTER0': ["..##########..", "..#........#..", "##############", "#............#", "#.####.....#.#", "#............#", "##############", ".#..........#.",
                 "..............", ".............."],
    'PRINTER1': ["..##########..", "..#........#..", "##############", "#............#", "#.####.....#.#", "#............#", "##############", ".#..........#.",
                 "#######.......", ".#####........"],
    'CRUMPLE': [".###.", "##.##", "#.#.#", "##.##", ".###."],
}
SPRITE_ORDER = list(SPRITES.keys())


# ---------------------------------------------------------------- the boss: COPYTRON 9000
# logical colours (the boss palette, boss_pal in the game)
BC_BODY, BC_DARK, BC_EYE, BC_WARN, BC_TRAY, BC_BTN, BC_TONER, BC_JAM = 1, 2, 3, 4, 5, 6, 7, 8
BOSS_PAL = [0, GREY, DGREY, WHITE, RED, BROWN, BGREEN, BMAGENTA, YELLOW, 0, 0, 0, 0, 0, 0, 0]
BW, BH = 80, 64


def copytron(variant):
    """variants: 0 idle, 1 spitting (lid up, tray out), 2 toner beam (mouth open), 3 jammed (drawer out)"""
    c = Canvas(BW, BH)
    # warning light on top (a dome)
    c.ellipse(64, 5, 6, 4, BC_WARN)
    c.rect(58, 6, 13, 3, BC_WARN)
    # the lid
    if variant == 1:
        c.line(28, 15, 76, 2, BC_DARK)
        c.line(28, 14, 76, 1, BC_DARK)
        for i in range(3):
            c.line(28, 13 - i, 76, 0 - i, BC_DARK)
        c.rect(30, 12, 44, 3, BC_EYE)          # the scanning light
    else:
        c.rect(26, 10, 52, 6, BC_DARK)
        c.rect(26, 10, 52, 1, BC_BODY)
    # body
    c.rect(16, 16, 64, 48, BC_BODY)
    c.rect(16, 16, 64, 1, 0)
    # control panel with buttons
    c.rect(56, 20, 20, 6, BC_BTN)
    for i in range(4):
        c.rect(58 + i * 4, 22, 2, 2, 0)
    # the face: two angry eyes (white cells), heavy brows
    for ex in (24, 40):
        c.rect(ex, 24, 8, 8, BC_EYE)
        c.rect(ex + 1, 27, 3, 3, 0)           # pupils looking left at you
    c.line(23, 22, 32, 24, BC_DARK)
    c.line(48, 22, 39, 24, BC_DARK)
    c.rect(23, 21, 10, 1, BC_DARK)
    # mouth / toner slot
    if variant == 2:
        c.rect(20, 36, 32, 8, BC_TONER)
        c.rect(22, 38, 28, 4, 0)
    else:
        c.rect(24, 38, 24, 2, BC_DARK)
        c.line(24, 40, 20, 42, BC_DARK)
    # the output tray (paper comes out here)
    if variant == 1:
        c.rect(0, 34, 16, 2, BC_TRAY)
        c.rect(2, 30, 14, 4, BC_EYE)
    else:
        c.rect(6, 34, 10, 2, BC_TRAY)
    # the paper drawer
    if variant == 3:
        c.rect(0, 48, 40, 10, BC_TRAY)
        c.rect(2, 44, 30, 5, BC_JAM)          # the jam: crumpled paper sticking out
        for i in range(0, 30, 3):
            c.px(2 + i, 43, BC_JAM)
        c.rect(40, 48, 36, 10, 0)
    else:
        c.rect(18, 48, 58, 10, BC_TRAY)
        c.rect(44, 52, 8, 2, 0)               # handle
    # feet
    c.rect(18, 60, 6, 4, BC_DARK)
    c.rect(70, 60, 6, 4, BC_DARK)
    return c.a


def boss_frames():
    return [copytron(v) for v in range(4)]


# ---------------------------------------------------------------- waves
# (map column, wave type, y, count, gap, param)
def waves():
    rnd = random.Random(7)
    W = []
    col = 30
    pattern = ['VPLANES', 'STAPLERS', 'BALLOON', 'MUGS', 'SNAKE', 'CHAIRS', 'VPLANES', 'PRINTER',
               'SNAKE', 'BALLOON', 'STAPLERS', 'BUBBLES', 'MUGS', 'VPLANES', 'CHAIRS', 'SNAKE']
    i = 0
    while col < MW - 50:
        W.append((col, pattern[i % len(pattern)], rnd.randrange(24, 120)))
        col += rnd.randrange(14, 22)
        i += 1
    return W
