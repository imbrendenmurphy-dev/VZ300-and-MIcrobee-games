"""uB-TYPE artwork for the Microbee Premium Plus.

Terrain tiles are drawn at 16 x 16 pixels (4x the VZ tiles) as LEVEL images:
0 = open space, 1 = dark, 2 = mid, 3 = light, plus optional accent classes.
A level image becomes 8 x 16 PCG cells through quantise(): every cell gets
its own ink/paper pair (Premium RGBI colours) and the levels become solid,
dithered or empty pixels. The same quantiser builds the half-cell-shifted
'pair' glyphs used for the fine scroll, so shifted cells match exactly.
"""
import math
import random
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'vz'))
import tiles as VT   # tile ids

# Premium colours
BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)

# ---------------------------------------------------------------- stage palettes
# per stage: dark (interior paper), light (ink), rim (edge-cell ink), accent colours
STAGE_PAL = [
    dict(name='OUTER HULL', theme='hull', dark=BLUE, light=GREY, rim=WHITE, acc=[BCYAN, BRED, YELLOW], band=BLUE, star=WHITE),
    dict(name='THE HIVE', theme='flesh', dark=RED, light=YELLOW, rim=YELLOW, acc=[BRED, BGREEN, WHITE], band=RED, star=YELLOW),
    dict(name='ROCK BELT', theme='rock', dark=DGREY, light=GREY, rim=WHITE, acc=[BRED, YELLOW, BCYAN], band=DGREY, star=GREY),
    dict(name='CRYSTAL VEIN', theme='cryst', dark=BLUE, light=BCYAN, rim=WHITE, acc=[BMAGENTA, YELLOW, WHITE], band=BLUE, star=BCYAN),
    dict(name='DREADNOUGHT', theme='ship', dark=DGREY, light=GREY, rim=WHITE, acc=[YELLOW, BRED, BCYAN], band=DGREY, star=WHITE),
    dict(name='GUT CAVERNS', theme='flesh', dark=RED, light=BMAGENTA, rim=BMAGENTA, acc=[YELLOW, BGREEN, WHITE], band=MAGENTA, star=BMAGENTA),
    dict(name='DEEP FIELD', theme='rock', dark=GREEN, light=BGREEN, rim=WHITE, acc=[BRED, YELLOW, BCYAN], band=GREEN, star=WHITE),
    dict(name='THE CORE', theme='cryst', dark=MAGENTA, light=BMAGENTA, rim=WHITE, acc=[BCYAN, YELLOW, WHITE], band=MAGENTA, star=BMAGENTA),
]


# ---------------------------------------------------------------- textures (64 x 64 levels)
def tex_hull():
    """riveted hull plates: dark plate faces, bright bevels, vents, rivets"""
    t = np.ones((64, 64), np.uint8)
    for y in range(64):
        for x in range(64):
            row = y // 16
            px = (x + (16 if row % 2 else 0)) % 32
            py = y % 16
            v = 1
            if py == 0 or px == 0:
                v = 3                                  # lit bevel
            elif py == 1 and px < 30:
                v = 2
            elif px == 1 and py < 15:
                v = 2
            elif (px in (3, 28)) and (py in (3, 12)):
                v = 3                                  # rivets
            elif ((row + (x + (16 if row % 2 else 0)) // 32) % 3 == 0) and 6 <= py <= 9 and 8 <= px <= 23:
                v = 3 if py in (6, 9) else (2 if px % 2 else 1)     # vent grille
            elif ((row + (x + (16 if row % 2 else 0)) // 32) % 3 == 1) and py == 8 and 6 <= px <= 25:
                v = 2                                  # panel seam
            t[y, x] = v
    return t


def tex_flesh():
    """hive tissue: dark flesh, glistening veins with a dithered halo, pores"""
    R = random.Random(7)
    t = np.ones((64, 64), np.uint8)
    for (y0, ph, amp) in ((6, 0.0, 3.0), (27, 2.1, 3.5), (47, 4.0, 3.0)):
        for x in range(64):
            y = y0 + amp * math.sin(x / 64 * 2 * math.pi * 2 + ph) + 1.2 * math.sin(x / 64 * 2 * math.pi * 5 + ph * 2)
            yi = int(round(y))
            t[(yi - 2) % 64, x] = max(t[(yi - 2) % 64, x], 2)
            t[(yi - 1) % 64, x] = 3
            t[yi % 64, x] = 3
            t[(yi + 1) % 64, x] = max(t[(yi + 1) % 64, x], 2)
    for x0 in (13, 45):
        x = x0
        for y in range(64):
            t[y, x % 64] = max(t[y, x % 64], 2)
            if R.random() < 0.3:
                x += R.choice((-1, 1))
    for (x, y) in ((6, 18), (36, 16), (56, 40), (22, 56), (48, 2), (28, 37)):
        for dy in range(-2, 3):
            for dx in range(-3, 4):
                d = dx * dx / 9 + dy * dy / 4
                if d <= 1:
                    t[(y + dy) % 64, (x + dx) % 64] = 3 if d > 0.6 and dy < 0 else 1
    return t


def tex_rock():
    """boulders: lit upper-left faces, dark crevices"""
    R = random.Random(11)
    pts = [(R.uniform(0, 64), R.uniform(0, 64)) for _ in range(10)]
    t = np.zeros((64, 64), np.uint8)
    for y in range(64):
        for x in range(64):
            ds = []
            for (px, py) in pts:
                for ox in (-64, 0, 64):
                    for oy in (-64, 0, 64):
                        dx = x - (px + ox)
                        dy = (y - (py + oy)) * 1.8
                        ds.append((dx * dx + dy * dy, dx, dy))
            ds.sort()
            d0, dx, dy = ds[0]
            edge = math.sqrt(ds[1][0]) - math.sqrt(d0)
            if edge < 1.5:
                v = 1
            else:
                r = math.sqrt(d0) + 0.01
                lit = -(dx + dy) / r
                v = 3 if lit > 0.75 else (2 if lit > 0.1 else 1)
                if edge < 3 and lit > 0:
                    v = 3
            t[y, x] = v
    return t


def tex_cryst():
    """crystal: dark facets crossed by bright cleavage lines and sparkles"""
    t = np.ones((64, 64), np.uint8)
    for y in range(64):
        for x in range(64):
            u = (x + y * 1.1) % 32
            w = (x - y * 1.1) % 32
            if min(u, 32 - u) < 1.0 or min(w, 32 - w) < 1.0:
                t[y, x] = 3
            elif min(u, 32 - u) < 2.2:
                t[y, x] = 2
            elif ((u < 16) ^ (w < 16)) and (x + y) % 5 == 0:
                t[y, x] = 2
    for (x, y) in ((10, 20), (40, 8), (52, 44), (22, 50)):
        t[y, x] = 3
        t[y - 1, x] = 3
        t[y + 1, x] = 3
        t[y, x - 1] = 3
        t[y, x + 1] = 3
    return t


def tex_ship():
    """dreadnought armour: big panels, seams, louvres"""
    t = np.ones((64, 64), np.uint8)
    for y in range(64):
        for x in range(64):
            px = x % 32
            py = y % 32
            v = 1
            if py == 0 or px == 0:
                v = 3
            elif py == 1 or px == 1:
                v = 2
            elif py in (15, 16) and 3 <= px <= 28:
                v = 2 if py == 15 else 3          # mid seam
            elif 20 <= py <= 27 and 4 <= px <= 27 and py % 2 == 0 and (x // 32 + y // 32) % 2 == 0:
                v = 3                              # louvres
            elif (px, py) in ((4, 4), (27, 4), (4, 11), (27, 11)):
                v = 3
            t[y, x] = v
    return t


TEX = {'hull': tex_hull(), 'flesh': tex_flesh(), 'rock': tex_rock(), 'cryst': tex_cryst(), 'ship': tex_ship()}


# ---------------------------------------------------------------- tiles (16 x 16 levels + accent map)
def sub(theme, tx, ty):
    t = TEX[theme]
    return t[(ty * 16) % 64:(ty * 16) % 64 + 16, (tx * 16) % 64:(tx * 16) % 64 + 16].copy()


def bevel(img, mask, open_dirs):
    """light the rims of a solid mask: edges facing open space up/left are
    light, down/right dark. open_dirs: sides of the tile that face space."""
    out = img.copy()
    H, W = mask.shape

    def solid(x, y):
        if 0 <= x < W and 0 <= y < H:
            return mask[y, x]
        side = 'U' if y < 0 else 'D' if y >= H else 'L' if x < 0 else 'R'
        return side not in open_dirs
    for y in range(H):
        for x in range(W):
            if not mask[y, x]:
                out[y, x] = 0
                continue
            up = not solid(x, y - 1) or not solid(x, y - 2)
            left = not solid(x - 1, y)
            down = not solid(x, y + 1) or not solid(x, y + 2)
            right = not solid(x + 1, y)
            if not solid(x, y - 1) or not solid(x - 1, y):
                out[y, x] = 3
            elif up or left:
                out[y, x] = 3 if (x + y) % 2 else 2
            elif not solid(x, y + 1) or not solid(x + 1, y):
                out[y, x] = 2
            elif down or right:
                out[y, x] = 1
    return out


def feature(theme, which):
    """F0 pillar segment and F1 inset feature: both solid tiles"""
    img = np.ones((16, 16), np.uint8)
    if which == 0:
        for y in range(16):
            for x in range(16):
                if x in (2, 3):
                    img[y, x] = 3
                elif x in (12, 13):
                    img[y, x] = 2
                elif 4 <= x <= 11 and y % 8 == 0:
                    img[y, x] = 3
                elif theme == 'cryst' and (x - y) % 7 == 0:
                    img[y, x] = 3
                elif theme == 'flesh' and (x + y // 2) % 6 == 0:
                    img[y, x] = 2
        return img
    # F1: an inset hatch / pod / vein node
    for y in range(16):
        for x in range(16):
            e = ((x - 7.5) / 6.5) ** 2 + ((y - 7.5) / 6.5) ** 2
            if theme in ('hull', 'ship', 'rock'):
                if 2 <= x <= 13 and 2 <= y <= 13:
                    img[y, x] = 3 if (x == 2 or y == 2) else (2 if (x == 13 or y == 13) else (3 if (x + y) % 4 == 0 else 1))
            else:
                if e <= 1:
                    img[y, x] = 3 if e > 0.65 and y < 8 else (2 if e > 0.65 else 1)
    return img


def ship_tile(k):
    """dreadnought special tiles (35..47) and flame/socket"""
    img = np.zeros((16, 16), np.uint8)
    acc = np.zeros((16, 16), np.uint8)
    full = sub('ship', 1, 1)
    if k == VT.WIN:                 # lit window row
        img = full.copy()
        img[5:11, 2:14] = 1
        img[6:10, 3:13] = 3
        acc[6:10, 3:13] = 1
    elif k == VT.VENT:
        img = full.copy()
        for y in range(3, 13):
            img[y, 2:14] = 1 if y % 3 else 3
    elif k == VT.ENG:               # engine bell, hot core
        img[:, :] = 2
        for y in range(16):
            w = 3 + abs(y - 7.5) / 2.5
            for x in range(16):
                if x > 16 - w * 1.8:
                    img[y, x] = 1
        img[5:11, 11:16] = 3
        acc[5:11, 11:16] = 2
    elif k == VT.ARM:               # heavy armour block
        img = full.copy()
        img = bevel(np.where(full > 0, full, 2), np.ones((16, 16), bool), 'ULDR')
    elif k == VT.MAST:
        for y in range(16):
            img[y, 6:10] = 2
            img[y, 6] = 3
            img[y, 9] = 1
            if y % 4 == 0:
                img[y, 4:12] = 3
    elif k == VT.BEACON:
        img[8:16, 6:10] = 2
        for y in range(8):
            for x in range(16):
                if (x - 7.5) ** 2 / 12 + (y - 5) ** 2 / 9 < 1:
                    img[y, x] = 3
                    acc[y, x] = 2
    elif k == VT.PIPEH:
        img[4:12, :] = 2
        img[4, :] = 3
        img[5, :] = 3
        img[11, :] = 1
        img[4:12, 7] = 1
    elif k == VT.PIPEV:
        img[:, 4:12] = 2
        img[:, 4:6] = 3
        img[:, 11] = 1
        img[7, 4:12] = 1
    elif k == VT.GRATE:
        for y in range(16):
            for x in range(16):
                img[y, x] = 3 if (x % 4 == 0 or y % 4 == 0) else 1
    elif k == VT.HATCH:
        img = full.copy()
        img[2:14, 2:14] = 1
        img[3:13, 3:13] = 2
        img[7:9, 3:13] = 3
    elif k == VT.DARK:
        img[:, :] = 1
        for y in range(0, 16, 2):
            img[y, (y * 3) % 16] = 2
    elif k == VT.NOSEU:            # nose wedge, solid below the diagonal (rising)
        m = np.array([[x >= 15 - y for x in range(16)] for y in range(16)])
        img = bevel(full, m, 'UL')
    elif k == VT.NOSED:
        m = np.array([[x >= y for x in range(16)] for y in range(16)])
        img = bevel(full, m, 'DL')
    return img, acc


def decor(theme, k):
    """non-solid specks in open space (DEC0..DEC3)"""
    img = np.zeros((16, 16), np.uint8)
    R = random.Random(theme.__hash__() % 1000 + k)
    if theme in ('hull', 'ship'):
        if k == 0:
            img[7, 6:10] = 2; img[6:10, 7] = 2; img[7, 7] = 3
        elif k == 1:
            img[4, 3] = 3; img[11, 11] = 2
        elif k == 2:
            img[8, 2:14:3] = 2
        else:
            img[5:7, 9:11] = 3
    elif theme == 'flesh':
        for (x, y) in [(5, 6), (10, 9), (7, 12)][:k + 1]:
            img[y - 1:y + 2, x - 1:x + 2] = 2
            img[y, x] = 3
    else:
        for i in range(k + 2):
            img[R.randrange(2, 14), R.randrange(2, 14)] = 3 if i == 0 else 2
    return img


def flame_tile():
    img = np.zeros((16, 16), np.uint8)
    acc = np.zeros((16, 16), np.uint8)
    for y in range(16):
        for x in range(16):
            d = abs(y - 7.5) / 8 + x / 18
            if d < 0.55:
                img[y, x] = 3
            elif d < 0.8:
                img[y, x] = 2
            elif d < 1.0 and (x + y) % 2:
                img[y, x] = 1
    acc[img > 0] = 2
    return img, acc


def tile_image(theme, k):
    """-> (levels 16x16, accent 16x16). accent 0 = theme colours, n = acc[n-1]"""
    acc = np.zeros((16, 16), np.uint8)
    T = VT
    if k == T.EMPTY:
        return np.zeros((16, 16), np.uint8), acc
    if T.FULL <= k < T.FULL + 16:
        i = k - T.FULL
        return sub(theme, i & 3, i >> 2), acc
    allm = np.ones((16, 16), bool)
    if k in (T.FTOP, T.FTOP + 1):
        return bevel(sub(theme, k - T.FTOP, 0), allm, 'U'), acc
    if k in (T.CBOT, T.CBOT + 1):
        return bevel(sub(theme, k - T.CBOT, 3), allm, 'D'), acc
    tri = lambda f: np.array([[f(x, y) for x in range(16)] for y in range(16)])
    if k == T.FSU:
        return bevel(sub(theme, 0, 0), tri(lambda x, y: x >= 15 - y), 'UL'), acc
    if k == T.FSD:
        return bevel(sub(theme, 1, 0), tri(lambda x, y: x <= y), 'UR'), acc
    if k == T.CSD:
        return bevel(sub(theme, 0, 3), tri(lambda x, y: x >= y), 'DL'), acc
    if k == T.CSU:
        return bevel(sub(theme, 1, 3), tri(lambda x, y: x <= 15 - y), 'DR'), acc

    def rnd(cx, cy):
        # a quarter circle on a 4:3 screen, where a pixel is about 1.5x
        # taller than wide: 16 pixels across, 16 / 1.5 down
        cy = 16 / 1.5 if cy == 16 else 16 - 16 / 1.5 if cy == 0 else cy
        return tri(lambda x, y: ((x + 0.5 - cx) / 16) ** 2 + ((y + 0.5 - cy) / (16 / 1.5)) ** 2 <= 1.0
                   or (cy > 8 and y + 0.5 >= cy) or (cy < 8 and y + 0.5 <= cy))
    if k == T.BTL:
        return bevel(sub(theme, 0, 0), rnd(16, 16), 'UL'), acc
    if k == T.BTR:
        return bevel(sub(theme, 1, 0), rnd(0, 16), 'UR'), acc
    if k == T.BBL:
        return bevel(sub(theme, 0, 1), rnd(16, 0), 'DL'), acc
    if k == T.BBR:
        return bevel(sub(theme, 1, 1), rnd(0, 0), 'DR'), acc
    if k == T.BT:
        return bevel(sub(theme, 2, 0), allm, 'U'), acc
    if k == T.BB:
        return bevel(sub(theme, 1, 1), allm, 'D'), acc
    if k == T.BL:
        return bevel(sub(theme, 0, 1), allm, 'L'), acc
    if k == T.BR:
        return bevel(sub(theme, 3, 2), allm, 'R'), acc
    if k == T.F0:
        return feature(theme, 0), acc
    if k == T.F1:
        return feature(theme, 1), acc
    if T.WIN <= k <= T.NOSED:
        return ship_tile(k)
    if T.DEC0 <= k < T.DEC0 + 4:
        return decor(theme, k - T.DEC0), acc
    if k == T.FLAME:
        return flame_tile()
    if k == T.SOCKET:
        img = np.zeros((16, 16), np.uint8)
        img[0:3, 0:4] = 2; img[0:3, 12:16] = 2; img[13:16, 0:4] = 2; img[13:16, 12:16] = 2
        img[0, 0:4] = 3; img[13, 12:16] = 1
        return img, acc
    return np.zeros((16, 16), np.uint8), acc


# ---------------------------------------------------------------- quantiser
def dither(level, x, y, edge):
    if level >= 3:
        return 1
    if level == 2:
        return (x + y) & 1
    if level == 1:
        return 1 if (edge and (x & 1) == 0 and (y & 3) == 1) else 0
    return 0


def quantise_mono(lv, ac):
    """the glyph for a monochrome monitor, which lights every set pixel
    whatever its colour: brightness has to come from the pattern alone.
    Light = solid, mid = 50%, dark = sparse dots, accents solid, and the
    rock's outline against open space solid so shapes read clearly."""
    g = []
    H, W = lv.shape
    for y in range(H):
        b = 0
        for x in range(W):
            v = int(lv[y, x])
            if v == 0:
                continue
            on = v >= 3 or (v == 2 and (x + y) & 1 == 0) or (v == 1 and (x & 1) == 0 and (y & 3) == 1)
            if ac[y, x] > 0 and v >= 2:
                on = True
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < W and 0 <= yy < H and lv[yy, xx] == 0:
                    on = True
            if on:
                b |= 0x80 >> x
        g.append(b)
    return bytes(g)


def quantise(lv, ac, pal, mono=False):
    """lv, ac: 16 x 8 arrays (rows x cols). -> (16 glyph bytes, colour byte).
    Inside the rock: paper = dark colour, light/dithered detail in ink.
    A cell touching open space: black paper, the rock solid in its dark
    colour (accent tiles keep their accent ink), so outlines stay solid."""
    edge = bool((lv == 0).any())
    lit = lv >= 2
    has_acc = bool((ac > 0).any())
    if has_acc:
        sel = ac[(ac > 0) & lit] if ((ac > 0) & lit).any() else ac[ac > 0]
        cls, cnt = np.unique(sel, return_counts=True)
        accent = pal['acc'][int(cls[np.argmax(cnt)]) - 1]
    g = []
    if edge:
        ink = accent if has_acc else pal['dark_edge'] if 'dark_edge' in pal else pal['dark']
        paper = BLACK
        for y in range(16):
            b = 0
            for x in range(8):
                v = int(lv[y, x])
                on = v >= 1 if not has_acc else v >= 2 or (v == 1 and (x + y) % 2 == 0)
                if on:
                    b |= 0x80 >> x
            g.append(b)
    else:
        ink = accent if has_acc else pal['light']
        paper = pal['dark']
        for y in range(16):
            b = 0
            for x in range(8):
                if dither(int(lv[y, x]), x, y, False):
                    b |= 0x80 >> x
            g.append(b)
    if not (lv > 0).any():
        paper = BLACK
    if mono:
        paper, ink = BLACK, WHITE
    return bytes(g), (paper << 4) | ink


def preview_tiles(theme, pal, path):
    from PIL import Image
    PALRGB = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 192, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
              (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
    im = np.zeros((4 * 18, 16 * 18, 3), np.uint8)
    for k in range(64):
        lv, ac = tile_image(theme, k)
        for half in range(2):
            g, c = quantise(lv[:, half * 8:half * 8 + 8], ac[:, half * 8:half * 8 + 8], pal)
            for y in range(16):
                for x in range(8):
                    on = (g[y] >> (7 - x)) & 1
                    im[(k // 16) * 18 + y, (k % 16) * 18 + half * 8 + x] = PALRGB[c & 15] if on else PALRGB[c >> 4]
    Image.fromarray(im).resize((im.shape[1] * 3, int(im.shape[0] * 3 * 1.8)), Image.NEAREST).save(path)
