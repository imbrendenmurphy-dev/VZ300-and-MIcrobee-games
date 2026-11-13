"""BIX THE BILBY for the Microbee Premium Plus: the art.

The VZ300 game's tiles (8 x 8, four colours) and sprites are the source.
Here each VZ pixel becomes 2 x 2 Microbee pixels (EPX-smoothed), and every
16 x 16 tile is cut into four 8 x 8 PCG cells of one ink on black paper.
The tiles that fill most of the screen (earth, grass, tunnels, water, the
stars) are redrawn at the Microbee's own resolution.
"""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / 'vz'))
import art as vz            # the VZ game's pixel art

BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(16)
PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
MONO_LUM = [0, 60, 90, 110, 40, 90, 120, 170, 85, 150, 200, 230, 130, 180, 210, 255]


def chars(rows):
    return np.array([list(r) for r in rows])


def epx(a, void):
    """scale2x on an array of colour characters; 'void' is what lies beyond the edge"""
    h, w = a.shape
    p = np.full((h + 2, w + 2), void)
    p[1:-1, 1:-1] = a
    out = np.empty((h * 2, w * 2), dtype=a.dtype)
    for y in range(h):
        for x in range(w):
            P = p[y + 1, x + 1]
            A, B, C, D = p[y, x + 1], p[y + 1, x + 2], p[y + 1, x], p[y + 2, x + 1]
            e1 = e2 = e3 = e4 = P
            if C == A and C != D and A != B: e1 = A
            if A == B and A != C and B != D: e2 = B
            if D == C and D != B and C != A: e3 = C
            if B == D and B != A and D != C: e4 = D
            out[2 * y, 2 * x], out[2 * y, 2 * x + 1] = e1, e2
            out[2 * y + 1, 2 * x], out[2 * y + 1, 2 * x + 1] = e3, e4
    return out


def rnd(seed):
    s = [seed * 2654435761 % 2 ** 32 or 1]

    def r(n):
        s[0] ^= (s[0] << 13) & 0xFFFFFFFF
        s[0] ^= s[0] >> 17
        s[0] ^= (s[0] << 5) & 0xFFFFFFFF
        return s[0] % n
    return r


# ------------------------------------------------------------------ tiles
# name -> how its VZ colours are shown: colour char -> Microbee ink, or
# None for "dark" (a hole in the ink). 'b' (the VZ's sky) is always dark.
DEF = {'g': BGREEN, 'y': YELLOW, 'r': RED}
STYLE = {
    'sky_tw': {'y': GREY}, 'sky_tw2': {'y': GREY},
    'cloudL': {'y': DGREY}, 'cloudM': {'y': DGREY}, 'cloudR': {'y': DGREY},
    'moonTL': {'y': WHITE, 'r': None}, 'moonTR': {'y': WHITE, 'r': None},
    'moonBL': {'y': WHITE, 'r': None}, 'moonBR': {'y': WHITE, 'r': None},
    'hillL': {'g': BLUE}, 'hillM': {'g': BLUE}, 'hillR': {'g': BLUE}, 'hillB': {'g': BLUE}, 'hillBT': {'g': BLUE},
    'rocktop': {'g': GREY, 'y': GREY}, 'rock': {'g': GREY, 'y': GREY},
    'log': {'y': BROWN, 'r': BROWN},
    'trunk': {'r': BROWN, 'y': None}, 'trunkB': {'r': BROWN, 'y': None},
    'leafT': {'g': GREEN, 'y': None}, 'leaf': {'g': GREEN, 'y': None}, 'leafB': {'g': GREEN, 'y': None},
    'bush': {'g': GREEN, 'y': None},
    'flower': {'y': BMAGENTA, 'r': BMAGENTA, 'g': BGREEN},
    'thorn': {'y': BRED, 'r': BRED, 'g': None},
    'shroom': {'r': BRED, 'y': WHITE},
    'check': {'r': BRED, 'y': GREY}, 'checkon': {'y': YELLOW, 'r': YELLOW},
    'exitT': {'y': YELLOW, 'r': YELLOW}, 'exitB': {'r': BROWN, 'y': BROWN},
    'termite': {'y': BROWN, 'r': None}, 'bonus': {'y': YELLOW, 'r': None},
    'used': {'r': BROWN},
    'star': {'y': YELLOW, 'r': YELLOW},
    'rockS': {'g': GREY, 'y': GREY},
    'lantern': {'y': YELLOW, 'r': None},
    'fern': {'g': GREEN}, 'tuft': {'g': BGREEN},
}
# what a monochrome monitor gets: three brightnesses
MONO = {WHITE: WHITE, YELLOW: WHITE, BGREEN: WHITE, RED: WHITE, BRED: WHITE, BMAGENTA: WHITE, BCYAN: WHITE,
        GREEN: GREY, BROWN: GREY, GREY: GREY, BBLUE: GREY, CYAN: GREY,
        DGREY: DGREY, BLUE: DGREY}
# when two different inks meet in one cell while scrolling, the higher wins
PRIO = {'star': 9, 'bstar': 9, 'check': 8, 'checkon': 8, 'bonus': 7, 'termite': 7, 'shroom': 7, 'thorn': 6,
        'grass': 5, 'grassD': 5, 'soil': 5, 'soil2': 5, 'soilD': 4, 'rock': 5, 'rocktop': 5, 'log': 6,
        'slopeL': 5, 'slopeR': 5, 'exitT': 8, 'exitB': 8, 'used': 7, 'lantern': 6, 'flower': 3}


def cells_of(img, void='b', style=None):
    """16 x 16 colour characters -> (bits 16x16 bool, ink 2x2)"""
    st = dict(DEF)
    st.update(style or {})
    bits = np.zeros((16, 16), bool)
    ink = np.zeros((2, 2), int)
    for cy in range(2):
        for cx in range(2):
            q = img[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            cnt = {}
            for ch in q.flat:
                if ch != void and st.get(ch) is not None:
                    cnt[ch] = cnt.get(ch, 0) + 1
            if not cnt:
                continue
            # the commonest ink colour of the cell; everything lit takes it
            best = max(cnt, key=lambda c: (cnt[c], c))
            ink[cy, cx] = st[best]
            for y in range(8):
                for x in range(8):
                    ch = q[y, x]
                    bits[cy * 8 + y, cx * 8 + x] = ch != void and st.get(ch) is not None
    return bits, ink


def pic(rows):
    return np.array([[c == '#' for c in r] for r in rows])


def soil(seed):
    """red earth: solid, with a scatter of dark grit"""
    b = np.ones((16, 16), bool)
    r = rnd(seed)
    for i in range(7):
        x, y = r(16), r(16)
        b[y, x] = False
        if i % 3 == 0:
            b[y, (x + 1) % 16] = False
    return b


def tunnel():
    """a dug tunnel: dark, with a little loose earth"""
    b = np.zeros((16, 16), bool)
    for (x, y) in [(2, 3), (9, 1), (13, 6), (5, 9), (11, 12), (1, 13), (7, 5), (14, 14)]:
        b[y, x] = True
    return b


GRASS_TOP = [
    "..#.....#.....#.",
    ".##..#..#..#.##.",
    ".##.##.##.##.##.",
    "###.##.##.#####.",
    "################",
    "################",
    "#.###.####.###.#",
    "################",
]
STAR = [
    "................",
    ".......##.......",
    ".......##.......",
    "......####......",
    "......####......",
    ".##############.",
    "..############..",
    "...##########...",
    "....########....",
    "....########....",
    "...####..####...",
    "...###....###...",
    "..###......###..",
    "..#..........#..",
    "................",
    "................",
]
WATER_T = [
    "................",
    "................",
    "................",
    "..####....####..",
    "##....####....##",
    "................",
    "......##........",
    "#..............#",
    "................",
    "...###..........",
    "..........###...",
    "................",
    "................",
    ".##.............",
    ".........##.....",
    "................",
]
WATER = [
    "................",
    ".....###........",
    "............##..",
    "................",
    "................",
    "..##............",
    ".........###....",
    "................",
    "................",
    "................",
    "....###.........",
    "...........##...",
    "................",
    "................",
    "#.......##.....#",
    "................",
]


def build_tiles():
    """-> {name: (bits 16x16, ink 2x2, prio)}"""
    T = {}
    for name, rows, _attr in vz.TILES:
        img = epx(chars(rows), 'b')
        bits, ink = cells_of(img, 'b', STYLE.get(name))
        T[name] = [bits, ink, PRIO.get(name, 2)]
    s1, s2 = soil(11), soil(29)
    T['soil'][0] = s1
    T['soil2'][0] = s2
    T['soil'][1] = T['soil2'][1] = np.full((2, 2), RED)
    T['soilD'] = [tunnel(), np.full((2, 2), RED), PRIO['soilD']]
    g = s1.copy()
    g[:8] = pic(GRASS_TOP)
    T['grass'] = [g, np.array([[BGREEN, BGREEN], [RED, RED]]), PRIO['grass']]
    g = tunnel()
    g[:8] = pic(GRASS_TOP)
    T['grassD'] = [g, np.array([[BGREEN, BGREEN], [RED, RED]]), PRIO['grassD']]
    T['star'] = [pic(STAR), np.full((2, 2), YELLOW), PRIO['star']]
    # a buried star: the star glowing in a pocket of the earth
    b = pic(STAR)
    b[0, :] = b[15, :] = True
    b[0, 5] = b[15, 11] = False
    T['bstar'] = [b, np.full((2, 2), YELLOW), PRIO['bstar']]
    T['watert'] = [pic(WATER_T), np.full((2, 2), BCYAN), 3]
    T['water'] = [pic(WATER), np.full((2, 2), BBLUE), 3]
    # the 45 degree ramps: earth below the diagonal, a grassy edge on it
    for name, right in (('slopeR', True), ('slopeL', False)):
        b = np.zeros((16, 16), bool)
        for y in range(16):
            for x in range(16):
                xx = x if right else 15 - x
                edge = 15 - xx
                if y >= edge:
                    b[y, x] = s1[y, x] if y >= edge + 4 else True
        b2 = b.copy()
        for y in range(16):                      # a dark seam under the turf
            for x in range(16):
                xx = x if right else 15 - x
                if y == 15 - xx + 4 and x % 4 != 1:
                    b2[y, x] = False
        ink = np.full((2, 2), RED)
        if right:
            ink[0, 1] = BGREEN; ink[1, 0] = BGREEN
        else:
            ink[0, 0] = BGREEN; ink[1, 1] = BGREEN
        T[name] = [b2, ink, PRIO[name]]
    return T


# ------------------------------------------------------------------ sprites
def sprite_from(rows, red_dark_rows=()):
    """VZ sprite rows ('.' transparent) -> (ink, cut) bool arrays, doubled.
    Yellow and red are lit; blue (the eye, the stripes) is cut dark."""
    a = epx(chars(rows), '.')
    ink = (a == 'y') | (a == 'r') | (a == 'g')
    cut = (a == 'b')
    return ink, cut


def bix_frames():
    F = {}
    for name in vz.BIX_ORDER:
        rows = vz.BIX[name]
        a = epx(chars(rows), '.')
        ink = (a == 'y') | (a == 'r')
        cut = (a == 'b')
        # the red inner ear becomes a dark line down the ear, so the ears read
        src = chars(rows)
        for y in range(len(rows)):
            for x in range(len(rows[0])):
                if src[y, x] == 'r' and y <= 3 and name not in ('dig',):
                    # an ear pixel: keep its outer column lit, cut the inner
                    ink[2 * y:2 * y + 2, 2 * x] = False
                    cut[2 * y:2 * y + 2, 2 * x] = True
        F[name] = (ink, cut)
    return F


def enemy_frames():
    F = {}
    for name in vz.ENEMY_ORDER:
        F[name] = sprite_from(vz.ENEMY[name])
    F['worm1'] = sprite_from(WORM1)
    F['worm2'] = sprite_from(WORM2)
    return F


WORM1 = ["........", "........", "........", "..yyy...", ".ybyby..", ".yyyyy..", "..yry...", ".rrrrr.."]
WORM2 = ["..yyy...", ".ybyby..", ".yyyyy..", "..yry...", "..yyy...", ".yy.y...", "..yyy...", ".rrrrr.."]


def platform_bits():
    """the floating log, 48 x 8"""
    a = epx(chars(vz.PLATFORM), '.')
    return (a != '.')


def variants(ink, cut, halo=True):
    """8 pre-shifted variants: [ncols, then for each cell column: first
    line, lines n, n x (mask, image)]; mask bits 1 = keep the background"""
    h, w = ink.shape
    solid = ink | cut
    if halo:
        s = solid.copy()
        s[1:, :] |= solid[:-1, :]; s[:-1, :] |= solid[1:, :]
        s[:, 1:] |= solid[:, :-1]; s[:, :-1] |= solid[:, 1:]
        solid = s
    out = []
    for sh in range(8):
        wp = ((w + sh + 7) // 8) * 8
        i2 = np.zeros((h, wp), bool)
        s2 = np.zeros((h, wp), bool)
        i2[:, sh:sh + w] = ink
        s2[:, sh:sh + w] = solid
        img = np.packbits(i2, axis=1)
        msk = np.packbits(~s2, axis=1)
        ncols = wp // 8
        while ncols > 1 and (msk[:, ncols - 1] == 0xFF).all():
            ncols -= 1
        d = bytearray([ncols])
        for c in range(ncols):
            used = np.where(msk[:, c] != 0xFF)[0]
            if len(used) == 0:
                d += bytes([0, 0])
                continue
            y0, y1 = int(used[0]), int(used[-1]) + 1
            d += bytes([y0, y1 - y0])
            for y in range(y0, y1):
                d.append(int(msk[y, c]))
                d.append(int(img[y, c]))
        out.append(bytes(d))
    return out


# ------------------------------------------------------------------ previews
def tile_rgb(t, mono=False):
    bits, ink, _ = t
    out = np.zeros((16, 16, 3), np.uint8)
    for y in range(16):
        for x in range(16):
            if bits[y, x]:
                c = ink[y // 8, x // 8]
                if mono:
                    l = MONO_LUM[MONO.get(c, WHITE)]
                    out[y, x] = (l, l * 176 // 255, 0)
                else:
                    out[y, x] = PALETTE[c]
    return out


def save(rgb, path, scale=3, aspect=0.8):
    from PIL import Image
    im = Image.fromarray(rgb)
    im = im.resize((im.width * scale, int(round(im.height * scale * aspect))), Image.NEAREST)
    im.save(path)


if __name__ == '__main__':
    import level1
    out = Path(sys.argv[1])
    T = build_tiles()
    for mono in (False, True):
        for k, x0 in enumerate((0, 60, 92, 160)):
            W = 20
            rgb = np.zeros((12 * 16, W * 16, 3), np.uint8)
            for x in range(W):
                for y in range(12):
                    rgb[y * 16:y * 16 + 16, x * 16:x * 16 + 16] = tile_rgb(T[level1.g[x0 + x][y]], mono)
            save(rgb, out / ('lvl%d%s.png' % (k, 'm' if mono else '')))
    # sprite sheet
    F = bix_frames()
    F.update(enemy_frames())
    n = len(F)
    sheet = np.zeros((24, n * 20, 3), np.uint8)
    sheet[:] = (0, 0, 96)
    for i, (name, (ink, cut)) in enumerate(F.items()):
        h, w = ink.shape
        sub = sheet[2:2 + h, i * 20 + 2:i * 20 + 2 + w]
        sub[cut] = (0, 0, 0)
        sub[ink] = (255, 255, 64)
    save(sheet, out / 'sprites.png', 4)
