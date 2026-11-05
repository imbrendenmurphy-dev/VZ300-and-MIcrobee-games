"""uB-TYPE sprite artwork, drawn for the Premium's 8x16 PCG cells.

Every sprite keeps the VZ sprite's box (4x its VZ size) so anchors and hit
boxes are unchanged. Player-side graphics, bullets, capsules and
explosions are drawn from scratch; enemies and boss parts start from the
VZ silhouettes (smoothed to 4x) and are re-shaded and re-coloured."""
import math
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'vz'))
import art as VA
from mbdraw import Canvas
import mbart as A
import mbfont

W_, R_, G_, Y_, C_, M_ = A.WHITE, A.BRED, A.BGREEN, A.YELLOW, A.BCYAN, A.BMAGENTA


def size_of(name):
    rows = VA.SPR[name]
    return 4 * max(len(r) for r in rows), 4 * len(rows)


# ------------------------------------------------------------------ player ship
def ship(tilt):
    """tilt -2 (climbing hard) .. +2 (diving hard)"""
    c = Canvas(32, 28)
    cy = 14
    k = -0.11 * tilt                       # nose up when climbing
    def T(x, y):
        return (x, y + k * (x - 16))
    top = 1.0 - 0.28 * max(0, -tilt) + 0.18 * max(0, tilt)     # visible wing sizes
    bot = 1.0 - 0.28 * max(0, tilt) + 0.18 * max(0, -tilt)
    # wings (behind the hull)
    c.poly([T(9, cy - 3), T(1, cy - 3 - 10 * top), T(5, cy - 3 - 10 * top), T(18, cy - 3)], C_)
    c.poly([T(9, cy + 3), T(1, cy + 3 + 10 * bot), T(5, cy + 3 + 10 * bot), T(18, cy + 3)], C_)
    # wing tip lights
    tx, ty = T(2, cy - 3 - 10 * top)
    c.put(tx, ty, R_, 3)
    tx, ty = T(2, cy + 3 + 10 * bot)
    c.put(tx, ty, R_, 3)
    # hull
    c.poly([T(31.5, cy), T(22, cy - 4.5), T(6, cy - 4.5), T(3, cy - 3), T(3, cy + 3), T(6, cy + 4.5), T(22, cy + 4.5)], W_)
    # panel line and nose cone
    for x in range(8, 22, 2):
        px, py = T(x, cy + 2)
        c.put(px, py, W_, 1)
    # canopy
    for y in range(-3, 1):
        for x in range(15, 25):
            if ((x - 20) / 5.0) ** 2 + ((y + 1) / 2.2) ** 2 <= 1:
                px, py = T(x, cy + y)
                c.put(px, py, C_, 3 if (x < 19 and y < -1) else 2)
    # engine block
    c.rect(0, cy - 3 + k * -16, 4, cy + 4 + k * -16, A.GREY, 2)
    return c


def exhaust(kind, f):
    """kind 0 slow, 1 cruise, 2 boost; f flicker frame. Box 16 x 12, flame
    leaves the ship's engine (right edge) towards the left."""
    c = Canvas(16, 12)
    L = (5, 10, 15)[kind] - (2 if f else 0)
    h = (2.0, 3.0, 4.5)[kind] + (0.6 if f else 0)
    for x in range(16):
        d = 15 - x                         # distance from the engine
        if d > L:
            continue
        w = h * (1 - d / (L + 1)) ** 0.7
        for y in range(12):
            dy = abs(y + 0.5 - 6)
            if dy <= w:
                inner = dy < w * 0.45 and d < L * 0.6
                c.put(x, y, Y_ if inner else R_, 3 if inner else (2 if (x + f) % 3 else 1))
    return c


# ------------------------------------------------------------------ pod, helpers
def pod(f):
    c = Canvas(16, 16)
    c.ellipse(8, 8, 8, 8, C_, hollow=0.45)
    # rotating lights on the ring
    for i in range(4):
        a = (i / 4 + f / 8) * 2 * math.pi
        c.put(8 + 6.5 * math.cos(a), 8 + 6.5 * math.sin(a), W_, 3)
    c.ellipse(8, 8, 3.6, 3.4, W_)
    c.put(7, 6, W_, 3)
    return c


def sat(f):
    c = Canvas(16, 12)
    c.poly([(8, 0), (16, 6), (8, 12), (0, 6)], Y_)
    c.ellipse(8, 6, 3, 2.6, W_ if f else R_)
    return c


# ------------------------------------------------------------------ player shots
def shot():
    c = Canvas(12, 4)
    for x in range(12):
        lv = 3 if x > 3 else (2 if x > 1 else 1)
        c.put(x, 1, W_, lv)
        c.put(x, 2, W_, lv)
    c.put(11, 0, W_, 1)
    c.put(11, 3, W_, 1)
    return c


def sprd():
    c = Canvas(8, 8)
    c.ellipse(4, 4, 4, 4, R_)
    c.put(3, 2, W_, 3)
    return c


def lance():
    c = Canvas(32, 4)
    for x in range(32):
        c.put(x, 1, C_, 3)
        c.put(x, 2, C_, 3)
        if x % 4 == 0:
            c.put(x, 0, C_, 2)
            c.put(x, 3, C_, 2)
    return c


def cross():
    c = Canvas(4, 12)
    for y in range(12):
        c.put(1, y, Y_, 3)
        c.put(2, y, Y_, 3 if y % 3 else 2)
    return c


def beam(n):
    """charged beam: a white-hot core with expanding wave rings"""
    w, h = {1: (32, 12), 2: (48, 20), 3: (64, 28)}[n]
    c = Canvas(w, h)
    cy = h / 2
    # wave rings behind the head
    for i in range(n + 1):
        x0 = w * (0.18 + 0.2 * i)
        rx = 3 + 2 * i
        ry = h / 2 * (0.55 + 0.45 * i / max(1, n))
        c.ellipse(x0, cy, rx, ry, C_, shade=False, lev=2, hollow=0.55)
    # core
    for x in range(w):
        t = x / w
        r = (h / 2 - 1) * (0.25 + 0.55 * min(1, t * 1.6)) * (1 if t < 0.85 else (1 - t) / 0.15)
        for y in range(h):
            d = abs(y + 0.5 - cy)
            if d <= r:
                c.put(x, y, W_ if d < r * 0.5 else C_, 3 if d < r * 0.7 else 2)
    return c


# ------------------------------------------------------------------ enemy bullet
def ebul(f):
    c = Canvas(8, 8)
    c.ellipse(4, 4, 4, 4, M_)
    if f:
        c.put(4, 0, W_, 3); c.put(4, 7, W_, 3); c.put(0, 4, W_, 3); c.put(7, 4, W_, 3)
    c.put(3, 3, W_, 3)
    c.put(4, 3, W_, 3)
    return c


# ------------------------------------------------------------------ capsules (power-ups)
def capsule(letter, col):
    c = Canvas(28, 28)
    c.ellipse(14, 14, 14, 14, col, hollow=0.62)
    g = mbfont.glyph57(letter, bold=True, top=0)
    for y in range(16):
        for x in range(8):
            if g[y, x] and y < 12:
                c.put(10 + x, 8 + y, W_, 3)
    return c


# ------------------------------------------------------------------ explosion
def explosion(stage):
    c = Canvas(32, 20)
    rng = np.random.RandomState(7 + stage)
    if stage == 0:
        c.ellipse(16, 10, 7, 5, Y_)
        c.ellipse(16, 10, 3, 2, W_, shade=False)
    elif stage == 1:
        c.ellipse(16, 10, 12, 8, R_, shade=False, lev=2)
        c.ellipse(16, 10, 8, 5, Y_)
        c.ellipse(15, 9, 3, 2, W_, shade=False)
    elif stage == 2:
        c.ellipse(16, 10, 15, 10, R_, shade=False, lev=1, hollow=0.3)
        for i in range(10):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(0.4, 0.95)
            c.ellipse(16 + 14 * r * math.cos(a), 10 + 9 * r * math.sin(a), 2.2, 1.6, Y_, shade=False)
    else:
        for i in range(14):
            a = rng.uniform(0, 2 * math.pi)
            r = rng.uniform(0.6, 1.0)
            c.put(16 + 15 * r * math.cos(a), 10 + 9.5 * r * math.sin(a), R_ if i % 3 else Y_, 3)
    return c


# ------------------------------------------------------------------ enemies: re-shaded VZ silhouettes
def epx(img):
    h, w = img.shape
    out = np.zeros((h * 2, w * 2), img.dtype)
    p = np.pad(img, 1)
    for y in range(h):
        for x in range(w):
            P = p[y + 1, x + 1]
            Au, Cl, Dr, Bd = p[y, x + 1], p[y + 1, x], p[y + 1, x + 2], p[y + 2, x + 1]
            o = [P, P, P, P]
            if Cl == Au and Cl != Dr and Au != Bd: o[0] = Au
            if Au == Dr and Au != Cl and Dr != Bd: o[1] = Dr
            if Bd == Cl and Bd != Au and Cl != Dr: o[2] = Cl
            if Dr == Bd and Dr != Au and Bd != Cl: o[3] = Bd
            out[2 * y, 2 * x], out[2 * y, 2 * x + 1], out[2 * y + 1, 2 * x], out[2 * y + 1, 2 * x + 1] = o
    return out


# material per VZ logical colour: (Premium colour, level)
SCHEMES = {
    'swim': {1: (Y_, 3), 2: (R_, 3), 3: (G_, 2)},
    'dart': {1: (W_, 3), 2: (M_, 3), 3: (M_, 2)},
    'tur': {1: (Y_, 3), 2: (R_, 3), 3: (A.GREY, 2)},
    'hop': {1: (W_, 3), 2: (R_, 3), 3: (G_, 2)},
    'carr': {1: (W_, 3), 2: (C_, 3), 3: (A.GREY, 2)},
    'spin': {1: (W_, 3), 2: (M_, 3)},
    'guns': {1: (W_, 3), 2: (R_, 3), 3: (A.GREY, 2)},
    'spore': {1: (W_, 3), 2: (G_, 3), 3: (Y_, 3)},
    'frag': {2: (G_, 3)},
    'borb': {1: (W_, 3), 2: (M_, 3)},
    'life': {1: (W_, 3), 3: (C_, 3)},
    'core': {1: (W_, 3), 2: (R_, 3), 3: (Y_, 2)},
    'bgun': {1: (W_, 3), 2: (R_, 3), 3: (A.GREY, 2)},
    'hatch': {1: (W_, 3), 2: (R_, 3), 3: (A.GREY, 2)},
    'serp': {1: (W_, 3), 2: (R_, 3), 3: (G_, 2)},
}


def reshaded(name):
    rows = VA.SPR[name]
    w = max(len(r) for r in rows)
    small = np.array([[0 if ch == '.' else int(ch) for ch in r.ljust(w, '.')] for r in rows], np.uint8)
    big = epx(epx(small))
    scheme = next(v for k, v in SCHEMES.items() if name.startswith(k))
    c = Canvas(big.shape[1], big.shape[0])
    solid = big > 0
    for y in range(c.h):
        for x in range(c.w):
            v = int(big[y, x])
            if not v:
                continue
            col, lev = scheme.get(v, (W_, 3))
            # lighting: rims facing up/left solid, facing down/right darker
            up = y == 0 or not solid[y - 1, x]
            left = x == 0 or not solid[y, x - 1]
            down = y == c.h - 1 or not solid[y + 1, x]
            right = x == c.w - 1 or not solid[y, x + 1]
            if up or left:
                lev = 3
            elif down or right:
                lev = max(1, lev - 1)
            c.put(x, y, col, lev)
    return c


# ------------------------------------------------------------------ all sprites
def build():
    out = {}
    tilt = {'shipu2': -2, 'shipu1': -1, 'ship0': 0, 'shipd1': 1, 'shipd2': 2}
    for name in VA.SPR:
        w, h = size_of(name)
        if name in tilt:
            c = ship(tilt[name])
        elif name.startswith('exh'):
            c = exhaust('snb'.index(name[3]), int(name[4]))
        elif name.startswith('pod'):
            c = pod(int(name[3]))
        elif name.startswith('sat'):
            c = sat(int(name[3]))
        elif name == 'shot':
            c = shot()
        elif name == 'sprd':
            c = sprd()
        elif name == 'lance':
            c = lance()
        elif name == 'cross':
            c = cross()
        elif name.startswith('beam'):
            c = beam(int(name[4]))
        elif name.startswith('ebul'):
            c = ebul(int(name[4]))
        elif name == 'capw0':
            c = capsule('S', R_)
        elif name == 'capw1':
            c = capsule('L', A.BBLUE)
        elif name == 'capw2':
            c = capsule('C', Y_)
        elif name == 'caps':
            c = capsule('+', G_)
        elif name == 'caph':
            c = capsule('H', M_)
        elif name.startswith('expl'):
            c = explosion(int(name[4]))
        else:
            c = reshaded(name)
        assert (c.w, c.h) == (w, h), (name, c.w, c.h, w, h)
        out[name] = c
    return out


def sheet(path, scale=3):
    from PIL import Image
    from mbee import PALETTE
    spr = build()
    cells = []
    for n, c in spr.items():
        on = c.bits()
        img = np.zeros((c.h, c.w, 3), np.uint8)
        pal = np.array(PALETTE, np.uint8)
        img[on] = pal[c.col[on]]
        cells.append((n, img))
    W = 8
    cw, ch = 72, 40
    out = np.full(((len(cells) + W - 1) // W * ch, W * cw, 3), 30, np.uint8)
    for i, (n, img) in enumerate(cells):
        y0, x0 = (i // W) * ch + 2, (i % W) * cw + 2
        out[y0:y0 + img.shape[0], x0:x0 + img.shape[1]] = img
    Image.fromarray(out).resize((out.shape[1] * scale, int(out.shape[0] * scale * 1.8)), Image.NEAREST).save(path)
