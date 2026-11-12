"""SKYLARKIN' stage 4: PUB ROCK - a gig at the pub. Lighting truss, amps
that go to 11, notes that play the tune when you shoot them, and the
ONE-MAN BAND. VIBED BY BPM 2026"""
import random
import numpy as np
from gfx import Canvas
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

NAME = 'PUB ROCK'
WAVE_TYPES = ['NOTES', 'PICKS', 'CYMBALS', 'COWBELL', 'SPEAKER', 'RNOTE', 'CHORD']
MW = 600
NEAR_ROWS = [0, 1, 17, 18, 19, 20, 21, 22]
FAR_ROWS = [4, 5]
BACK = BLACK


def sky_rows():
    s = [BACK] * 23
    s[0] = s[1] = BACK
    s[4] = s[5] = MAGENTA
    for r in range(17, 23):
        s[r] = BACK
    return s


def truss(c, x0, x1, rnd):
    """the lighting rig, rows 0-1 (y 0..15)"""
    c.rect(x0, 1, x1 - x0, 1, GREY)
    c.rect(x0, 8, x1 - x0, 1, GREY)
    for x in range(x0, x1, 8):
        c.line(x, 1, x + 4, 8, DGREY)
        c.line(x + 4, 8, x + 8, 1, DGREY)
    x = x0 + 16
    while x < x1 - 16:
        col = rnd.choice([BRED, YELLOW, BBLUE, BGREEN, BMAGENTA])
        c.rect(x, 9, 6, 4, DGREY)
        c.rect(x + 1, 13, 4, 2, col)
        x += rnd.choice([40, 56, 72])


def backdrop(c, x0, x1):
    """far rows 4-5 (y 32..47): the band's banner, over and over"""
    y0 = 32
    c.rect(x0, y0, x1 - x0, 16, MAGENTA)
    x = x0
    while x < x1:
        c.text(x + 4, y0 + 4, 'THE BIN CHOOKS * LIVE!', YELLOW)
        x += 22 * 8 + 16
    c.rect(x0, y0, x1 - x0, 1, BMAGENTA)
    c.rect(x0, y0 + 15, x1 - x0, 1, BMAGENTA)


def floor(c, x0, x1):
    c.rect(x0, 176, x1 - x0, 8, BROWN)
    c.hatch(x0, 177, x1 - x0, 7, RED, period=3)


def amp_stack(c, x, n):
    """n cabinets high (16 px each), with the head on top: dials to 11"""
    top = 176 - 16 * n - 8
    for i in range(n):
        y = 176 - 16 * (i + 1)
        c.rect(x, y, 32, 15, DGREY)
        c.hatch(x + 2, y + 2, 28, 11, GREY, period=2)
    c.rect(x, top, 32, 8, DGREY)
    c.rect(x + 2, top + 2, 4, 3, YELLOW)
    c.text(x + 10, top, '11', WHITE)
    return 40


def drums(c, x):
    c.ellipse(x + 20, 162, 12, 12, BRED)                # the kick drum
    c.ellipse(x + 20, 162, 8, 8, WHITE)
    c.text(x + 13, 158, 'BC', BRED)
    c.ellipse(x + 4, 150, 6, 3, BRED)                   # toms
    c.ellipse(x + 36, 150, 6, 3, BRED)
    c.rect(x + 43, 140, 1, 36, GREY)                    # the cymbal on its stand
    c.ellipse(x + 43, 140, 8, 1, YELLOW)
    return 56


def micstand(c, x):
    c.rect(x + 6, 136, 1, 40, GREY)
    c.line(x + 6, 140, x + 14, 134, GREY)
    c.rect(x + 13, 132, 3, 3, WHITE)
    c.line(x + 1, 176, x + 6, 172, GREY)
    c.line(x + 11, 176, x + 6, 172, GREY)
    return 24


def wedge(c, x):
    for i in range(10):
        c.rect(x + i, 176 - i, 20 - i, 1, DGREY)
    c.hatch(x + 2, 168, 12, 6, GREY, period=2)
    return 28


def build_scenery(seed=4):
    rnd = random.Random(seed)
    W = (MW + 1) * 8
    near = Canvas(W, 184)
    far = Canvas(W, 184)
    truss(near, 0, W, rnd)
    backdrop(far, 0, W)
    floor(near, 0, W)
    x = 48
    end = (MW - 48) * 8
    while x < end:
        k = rnd.random()
        if k < 0.32:
            x += amp_stack(near, x, rnd.choice([1, 2, 2, 3]))
        elif k < 0.46:
            x += drums(near, x)
        elif k < 0.62:
            x += micstand(near, x)
        elif k < 0.76:
            x += wedge(near, x)
        else:
            x += rnd.choice([24, 40, 56])
        x = (x + 7) // 8 * 8
    near.rect(end + 32, 150, 64, 20, WHITE)
    near.text(end + 36, 152, 'ENCORE', BRED)
    near.text(end + 36, 161, 'FREE!', BRED)
    near.rect(end + 62, 170, 2, 6, WHITE)
    return near, far


def heights(near):
    a = near.a
    ceil, floor_ = [], []
    for m in range(MW + 1):
        col = a[:, m * 8:m * 8 + 8]
        top = col[0:16].any(1)
        ys = np.nonzero(top)[0]
        ceil.append(int(ys.max()) + 1 if len(ys) else 0)
        bot = col[120:184].any(1)
        ys = np.nonzero(bot)[0]
        floor_.append(120 + int(ys.min()) if len(ys) else 184)
    return ceil, floor_


SPRITES = {
    'NOTE0': ["....##", "....#.#", "....#..#", "....#...", ".####...", "#####...", "#####...", ".###...."],
    'NOTE1': ["....#.", "....##", "....#.#", "....#..#", ".####...", "#####...", "#####...", ".###...."],
    'PICK0': ["########", ".######.", ".######.", "..####..", "...##..."],
    'PICK1': ["...##...", "..####..", ".######.", ".######.", "########"],
    'CYMBAL0': ["......##......", ".############.", "##############", ".############.", "......##......"],
    'CYMBAL1': ["......##......", "..##########..", ".############.", "..##########..", "......##......"],
    'COWBELL': ["....##....", "...####...", "..######..", "..######..", ".########.", ".########.", "##########", "....##...."],
    'SPEAKER0': ["############", "#..........#", "#..######..#", "#.##....##.#", "#.#..##..#.#", "#.##....##.#", "#..######..#", "############"],
    'SPEAKER1': ["############", "#..######..#", "#.##....##.#", "#.#......#.#", "#.#..##..#.#", "#.#......#.#", "#.##....##.#", "############"],
}
SPRITES = {k: [r.ljust(max(len(x) for x in v), '.') for r in v] for k, v in SPRITES.items()}
SPRITE_ORDER = list(SPRITES.keys())

# ---------------------------------------------------------------- THE ONE-MAN BAND
BC_BODY, BC_DARK, BC_EYE, BC_WARN, BC_DRUM, BC_BRASS, BC_GUIT, BC_HARM = 1, 2, 3, 4, 5, 6, 7, 8
BOSS_PAL = [0, GREY, DGREY, WHITE, BRED, BRED, YELLOW, BCYAN, BCYAN, 0, 0, 0, 0, 0, 0, 0]


def band(variant):
    """0 playing, 1 drum hit (beat 1), 2 harmonica blast (beat 3), 3 taking a bow"""
    c = Canvas(80, 64)
    bow = variant == 3
    hy = 14 if bow else 6
    # the head with a harmonica rack
    c.ellipse(40, hy + 6, 8, 7, BC_BODY)
    c.rect(34, hy + 3, 4, 3, BC_EYE)
    c.rect(43, hy + 3, 4, 3, BC_EYE)
    c.rect(35, hy + 4, 2, 2, BC_DARK)
    c.rect(44, hy + 4, 2, 2, BC_DARK)
    c.rect(32, hy + 11, 16, 3, BC_HARM if variant == 2 else BC_DARK)
    c.ellipse(40, hy - 2, 10, 2, BC_BRASS)              # a hat
    c.rect(36, hy - 8, 8, 6, BC_BRASS)
    # body, arms
    c.rect(30, 20, 20, 30, BC_BODY)
    c.line(30, 24, 14, 36, BC_BODY)
    c.line(50, 24, 66, 30, BC_BODY)
    # the bass drum on the chest (the weak spot when it bows)
    c.ellipse(40, 36, 13 if variant == 1 else 11, 13 if variant == 1 else 11, BC_DRUM)
    c.ellipse(40, 36, 8, 8, BC_EYE)
    c.text(36, 33, '1', BC_DRUM)
    # cymbals on the knees, the guitar
    c.ellipse(26, 52, 8, 2, BC_BRASS)
    c.ellipse(54, 52, 8, 2, BC_BRASS)
    c.line(8, 44, 22, 30, BC_GUIT)
    c.ellipse(16, 40, 7, 5, BC_GUIT)
    c.rect(4, 44, 6, 2, BC_GUIT)
    # legs
    c.rect(32, 50, 5, 14, BC_DARK)
    c.rect(43, 50, 5, 14, BC_DARK)
    return c.a


def boss_frames():
    return [band(v) for v in range(4)]


def waves():
    rnd = random.Random(17)
    W = []
    col = 30
    pattern = ['NOTES', 'PICKS', 'SPEAKER', 'COWBELL', 'CYMBALS', 'NOTES', 'RNOTE', 'CHORD',
               'PICKS', 'SPEAKER', 'NOTES', 'CYMBALS', 'COWBELL', 'RNOTE', 'CHORD', 'NOTES']
    i = 0
    while col < MW - 50:
        W.append((col, pattern[i % len(pattern)], rnd.randrange(24, 110)))
        col += rnd.randrange(13, 20)
        i += 1
    return W
