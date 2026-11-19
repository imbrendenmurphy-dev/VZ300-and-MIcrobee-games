"""STARHIVE's five levels (pictures for the software-scroll builder).
Map row 0 is the start (bottom); rows count upwards."""
import math
import numpy as np
import gfx
from gfx import *
import space
from space import Space, NEAR_STARS, station_block, girder, asteroid, h32, COLS, CL

ROWS = 400


def near_stars(sp, rng, density=1.5, avoid=None):
    for i in range(int(sp.rows * density)):
        row = int(rng.integers(0, sp.rows))
        col = int(rng.integers(0, COLS))
        s, c = NEAR_STARS[int(rng.integers(0, len(NEAR_STARS)))]
        a = gfx.parse_art(s, {'W': WHITE, 'C': BCYAN, 'Y': YELLOW, 'c': CYAN, 'w': GREY})
        sp.stamp(a, col * 8 + 2, row, 4)


def comb(h, w, line=YELLOW, fill=BROWN, glow=None, glow_p=0.0, seed=0):
    """honeycomb: hex cells 16 pixels apart (a 16 x 22 pattern, so it
    repeats every 2 x 2 characters), outlines in 'line'. Worked out for
    440 lines and repeated."""
    full = h
    h = min(h, 440)
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:h, 0:w]
    best = np.full((h, w), 1e9)
    second = np.full((h, w), 1e9)
    owner = np.zeros((h, w), np.int32)
    k = 0
    for j in range(-1, h // 22 + 2):
        for i in range(-1, w // 16 + 2):
            for (cx, cy) in ((16 * i, 22 * j), (16 * i + 8, 22 * j + 11)):
                if not (-24 <= cy <= h + 24 and -24 <= cx <= w + 24):
                    continue
                d = np.hypot(xx - cx, (yy - cy) / 1.33)
                k += 1
                closer = d < best
                second = np.where(closer, best, np.minimum(second, d))
                owner = np.where(closer, k, owner)
                best = np.where(closer, d, best)
    a = np.where(second - best < 1.6, line, fill).astype(np.int16)
    if glow is not None:
        for o in np.unique(owner):
            if rng.random() < glow_p:
                a[(owner == o) & (a == fill)] = glow
    reps = -(-full // h)
    return np.tile(a, (reps, 1))[:full]


def level1():
    """THE OUTER HIVE: space stations and asteroids"""
    sp = Space(ROWS)
    rng = np.random.default_rng(3)
    near_stars(sp, rng)
    for k, row in enumerate(range(40, ROWS - 50, 110)):
        side = k & 1
        w = 120 + (h32('w', row) % 5) * 16
        x = 0 if side == 0 else COLS * 8 - w
        sp.stamp(station_block(w, 44, row), x, row)
        g = girder(COLS * 8 - w)
        sp.stamp(g, w if side == 0 else 0, row - 1)
    for k in range(ROWS // 12):
        row = int(rng.integers(70, ROWS - 40))
        if (row - 40) % 110 < 12 or (row - 40) % 110 > 100:
            continue
        r = float(rng.uniform(4, 14))
        x = int(rng.integers(0, COLS * 8 - 2 * r))
        sp.stamp(asteroid(r, k), x, row)
    return sp


def level2():
    """THE ROCK BELT: asteroids everywhere, a few big ones"""
    sp = Space(ROWS)
    rng = np.random.default_rng(11)
    near_stars(sp, rng, 1.0)
    shapes = [asteroid(r, 100 + i) for i, r in enumerate((5, 6, 8, 9, 11, 12, 18, 22))]
    for k in range(ROWS // 6):
        row = int(rng.integers(30, ROWS - 40))
        a = shapes[int(rng.integers(0, 6)) if rng.random() > 0.1 else int(rng.integers(6, 8))]
        x = int(rng.integers(0, COLS - a.shape[1] // 8 - 1)) * 8      # on character columns,
        sp.stamp(a, x, row)                                            # so cells repeat
    return sp


def level3():
    """THE HIVE WALL: honeycomb walls on both sides, closing in"""
    sp = Space(ROWS)
    rng = np.random.default_rng(23)
    near_stars(sp, rng, 1.0)
    wall = comb(ROWS * CL, COLS * 8, YELLOW, BROWN)
    for row in range(20, ROWS - 40):
        t = (row - 20) / 60.0
        lw = int(5 + 3 * math.sin(t) + 2 * math.sin(t * 0.37))
        rw = int(5 + 3 * math.sin(t + 2.1) + 2 * math.sin(t * 0.29 + 1))
        lw, rw = max(2, lw), max(2, rw)
        y0 = sp.y_of(row)
        sp.img[y0:y0 + CL, 0:lw * 8] = wall[y0:y0 + CL, 0:lw * 8]
        sp.img[y0:y0 + CL, (COLS - rw) * 8:] = wall[y0:y0 + CL, (COLS - rw) * 8:]
    # loose comb chunks in the middle
    for k in range(10):
        row = int(rng.integers(60, ROWS - 60))
        c0 = int(rng.integers(14, 24)) & ~1
        y0 = sp.y_of(row)
        sp.img[y0:y0 + 2 * CL, c0 * 8:(c0 + 4) * 8] = wall[y0:y0 + 2 * CL, c0 * 8:(c0 + 4) * 8]
    return sp


def wreck(w, h, seed):
    """a broken hull: holes torn out, red emergency lights"""
    rng = np.random.default_rng(seed)
    a = station_block(w, h, seed)
    a[a == YELLOW] = BRED
    for i in range(3):
        cx = int(rng.integers(8, w - 8))
        cy = int(rng.integers(4, h - 4))
        r = float(rng.uniform(6, 14))
        yy, xx = np.mgrid[0:h, 0:w]
        a[np.hypot(xx - cx, (yy - cy) * 1.33) < r] = -1
    return a


def level4():
    """THE DEAD FLEET: wrecked stations and drifting girders"""
    sp = Space(ROWS)
    rng = np.random.default_rng(31)
    near_stars(sp, rng, 1.2)
    for k, row in enumerate(range(35, ROWS - 50, 55)):
        w = 96 + int(rng.integers(0, 4)) * 16
        x = int(rng.integers(0, COLS * 8 - w)) & ~7
        sp.stamp(wreck(w, 44, k), x, row)
    for k in range(14):
        row = int(rng.integers(30, ROWS - 40))
        w = 48 + int(rng.integers(0, 6)) * 16
        x = int(rng.integers(0, COLS * 8 - w)) & ~7
        sp.stamp(girder(w), x, row)
    return sp


def level5():
    """THE HIVE CORE: a winding channel through glowing honeycomb"""
    sp = Space(ROWS)
    rng = np.random.default_rng(47)
    near_stars(sp, rng, 0.6)
    core = comb(ROWS * CL, COLS * 8, YELLOW, BROWN, BMAGENTA, 0.12, seed=5)
    for row in range(20, ROWS - 40):
        t = (row - 20) / 45.0
        mid = 20 + int(7 * math.sin(t) + 3 * math.sin(t * 2.3))
        half = 12 + int(2 * math.sin(t * 0.7 + 1))
        lo, hi = max(0, mid - half), min(COLS, mid + half)
        y0 = sp.y_of(row)
        sp.img[y0:y0 + CL, 0:lo * 8] = core[y0:y0 + CL, 0:lo * 8]
        sp.img[y0:y0 + CL, hi * 8:] = core[y0:y0 + CL, hi * 8:]
    return sp


LEVELS = [
    (level1, 'THE OUTER HIVE'),
    (level2, 'THE ROCK BELT'),
    (level3, 'THE HIVE WALL'),
    (level4, 'THE DEAD FLEET'),
    (level5, 'THE HIVE CORE'),
]
