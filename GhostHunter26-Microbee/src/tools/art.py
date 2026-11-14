"""GHOST HUNTER '26 artwork (VIBED BY BPM 2026).

Everything is drawn here in Python and packed by build.py into Microbee PCG
glyphs of 8 x 8 pixels. Colours are the Premium Plus numbers:
0 black 1 red 2 green 3 brown 4 blue 5 magenta 6 cyan 7 grey
8 dark grey 9 bright red 10 bright green 11 yellow 12 bright blue
13 bright magenta 14 bright cyan 15 white
"""
import math
import numpy as np
from font import FD, CHARS, font_glyphs

BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)
LUM = [0, 57, 113, 85, 22, 79, 135, 192, 96, 140, 190, 235, 90, 170, 215, 255]


def imul(a, b):
    return (a * b) & 0xFFFFFFFF


def hsh(x, y, s):
    n = (imul(x & 0xFFFFFFFF, 374761393) + imul(y & 0xFFFFFFFF, 668265263) + imul(s & 0xFFFFFFFF, 1442695041)) & 0xFFFFFFFF
    n = imul(n ^ (n >> 13), 1274126177)
    return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967296.0


def mk(fn, w=16, h=16):
    return np.array([[bool(fn(x, y)) for x in range(w)] for y in range(h)], bool)


def art(rows):
    return np.array([[c == '#' for c in r] for r in rows], bool)


def mirror(a):
    return a[:, ::-1].copy()


def grow(bits):
    b = np.asarray(bits, bool)
    g = b.copy()
    g[1:, :] |= b[:-1, :]
    g[:-1, :] |= b[1:, :]
    g[:, 1:] |= b[:, :-1]
    g[:, :-1] |= b[:, 1:]
    return g


CH = 10         # lines in a cell (cells are 8 x 10)


def pat8(bits):
    """8 x CH booleans -> CH bytes"""
    return bytes(sum((128 >> x) for x in range(8) if bits[y][x]) for y in range(len(bits)))


# ---------------------------------------------------------------- walls
# mask bits: which neighbours are wall too
MU, MD, ML, MR = 1, 2, 4, 8
STYLE_NAMES = ['CRYPT', 'HEDGE', 'BOILER', 'BRICK', 'NEON', 'PALACE']
#               ink     paper
STYLE_COL = [(GREY, DGREY), (BGREEN, GREEN), (BROWN, BLACK), (BLACK, RED), (BBLUE, BLACK), (BCYAN, BLUE)]
WALL_FLASH = [WHITE, YELLOW, WHITE, YELLOW, WHITE, WHITE]


def tube(mask, lo, hi, ylo, yhi):
    """filled tube shape: a centre block with arms to the joined sides"""
    def inside(x, y):
        if lo <= x <= hi and ylo <= y <= yhi:
            return True
        if lo <= x <= hi and ((y < ylo and mask & MU) or (y > yhi and mask & MD)):
            return True
        if ylo <= y <= yhi and ((x < lo and mask & ML) or (x > hi and mask & MR)):
            return True
        return False
    return inside


def tube_ext(mask, lo, hi, ylo, yhi):
    """the tube, continued into the neighbouring cells (for outlines)"""
    t = tube(mask, lo, hi, ylo, yhi)

    def inside(x, y):
        xx, yy = min(max(x, 0), 7), min(max(y, 0), CH - 1)
        if (xx, yy) != (x, y):
            if y < 0 and not mask & MU or y > CH - 1 and not mask & MD or x < 0 and not mask & ML or x > 7 and not mask & MR:
                return False
        return t(xx, yy)
    return inside


def wall_bits(style, mask, c, r):
    v = (c + r) & 1
    B = CH - 1
    if style == 0:          # crypt: bevelled stone blocks
        def fn(x, y):
            if y == 0 and not mask & MU:
                return True
            if x == 0 and not mask & ML:
                return True
            if y == 1 and not mask & MU and x % 2 == v:
                return True
            if (x, y) in (((2, 7), (5, 4)) if v else ((5, 7), (3, 4))):
                return True
            return False
    elif style == 1:        # hedge: leaves
        def fn(x, y):
            if y == 0 and not mask & MU:
                return (x + v) % 2 == 0
            if y == B and not mask & MD:
                return False
            return ((x + 2 * y + 3 * v) % 5 == 0) or ((2 * x - y + v) % 7 == 0)
    elif style == 2:        # boiler room: copper pipes
        t = tube(mask, 1, 6, 1, B - 1)
        n = bin(mask).count('1')
        straight = mask in (MU | MD, ML | MR)

        def fn(x, y):
            if not t(x, y):
                return False
            if straight:
                if mask == ML | MR:
                    return y != 3 and not (v and x == 3)
                return x != 2 and not (v and y == 4)
            if (x, y) in ((1, 1), (6, 1), (1, B - 1), (6, B - 1)):
                return False
            if n != 2 and 3 <= x <= 4 and 4 <= y <= 5:
                return False
            return True
    elif style == 3:        # brick: mortar lines (ink black on red)
        def fn(x, y):
            if y % 5 == 4:
                return True
            return x == (3 if (y // 5) % 2 else 7)
    elif style == 4:        # neon: the arcade's double line
        t = tube_ext(mask, 2, 5, 3, B - 3)

        def fn(x, y):
            if not t(x, y):
                return False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                if not t(x + dx, y + dy):
                    return True
            return False
    else:                   # palace: diamond lattice with lit edges
        def fn(x, y):
            if y == 0 and not mask & MU:
                return True
            if y == B and not mask & MD:
                return True
            if x == 0 and not mask & ML:
                return True
            if x == 7 and not mask & MR:
                return True
            return (x + y) % 10 == 3 or (x - y) % 10 == 4
    return [[bool(fn(x, y)) for x in range(8)] for y in range(CH)]


DOOR = pat8([[4 <= y <= 5 for x in range(8)] for y in range(CH)])
DOOR_COL = (BMAGENTA, BLACK)


def dot_glyph(mask, ecorner):
    """corner dots: bit 0 TL, 1 TR, 2 BL, 3 BR; ecorner = corner holding an
    energiser quarter (or None)"""
    b = [[False] * 8 for _ in range(CH)]
    for k in range(4):
        fx, fy = k & 1, k >> 1
        if ecorner == k:
            for y in range(3):
                for x in range(3):
                    if (x, y) != (2, 2):
                        b[CH - 1 - y if fy else y][7 - x if fx else x] = True
        elif mask & (1 << k):
            b[CH - 1 if fy else 0][7 if fx else 0] = True
    return pat8(b)


# ---------------------------------------------------------------- items (16 x 16, two inks: top cells, bottom cells)
ITEMS = [
    ('SPEED', YELLOW, YELLOW, [
        "................", ".........####...", "........####....", ".......####.....", "......####......", ".....####.......",
        "....#########...", "...#########....", "......####......", ".....####.......", "....####........", "...####.........",
        "..####..........", "..###...........", "..#.............", "................"]),
    ('FREEZE', BCYAN, BCYAN, [
        "................", ".......##.......", "....#..##..#....", ".....#.##.#.....", "..#...####...#..", "...#...##...#...",
        ".##############.", ".##############.", "...#...##...#...", "..#...####...#..", ".....#.##.#.....", "....#..##..#....",
        ".......##.......", "................", "................", "................"]),
    ('DOUBLE', WHITE, BMAGENTA, [
        "................", "..........####..", ".........##..##.", ".............##.", "............##..", "...........##...",
        "..........##....", ".........######.", ".##...##........", "..##.##.........", "...###..........", "...###..........",
        "..##.##.........", ".##...##........", "................", "................"]),
    ('SHIELD', BBLUE, BCYAN, [
        "................", ".##############.", ".##############.", ".##..........##.", ".##..######..##.", ".##..######..##.",
        ".##..######..##.", ".##..######..##.", ".##..######..##.", "..##..####..##..", "..##..####..##..", "...##..##..##...",
        "....##....##....", ".....######.....", ".......##.......", "................"]),
    ('HEART', BRED, RED, [
        "................", "..####....####..", ".######..######.", "################", "################", "################",
        "################", "################", ".##############.", "..############..", "...##########...", "....########....",
        ".....######.....", "......####......", ".......##.......", "................"]),
    ('STAR', WHITE, YELLOW, [
        ".......##.......", ".......##.......", "......####......", "......####......", ".....######.....", "################",
        ".##############.", "..############..", "...##########...", "...##########...", "..#####..#####..", "..####....####..",
        ".####......####.", ".##..........##.", "................", "................"]),
    # treasures
    ('CANDY', BMAGENTA, WHITE, [
        "................", "................", "................", "##............##", "###..######..###", "####.##..##.####",
        ".#####....#####.", "..###..##..###..", "..###..##..###..", ".#####....#####.", "####.##..##.####", "###..######..###",
        "##............##", "................", "................", "................"]),
    ('PUMPKIN', BGREEN, BROWN, [
        "................", ".......###......", "......###.......", "......##........", "...##########...", "..############..",
        ".##############.", ".##############.", "################", "###.##.##.##.###", "###..#.##.#..###", "################",
        ".##..#....#..##.", ".###..####..###.", "..############..", "....########...."]),
    ('POTION', WHITE, BGREEN, [
        "................", ".....######.....", "......####......", "......#..#......", "......#..#......", ".....##..##.....",
        "....##....##....", "...##......##...", "..############..", "..############..", "..####.#######..", "..###.########..",
        "..############..", "...##########...", "....########....", "................"]),
    ('SKULL', WHITE, WHITE, [
        "................", "....########....", "..############..", ".##############.", ".##############.", ".###..####..###.",
        ".##....##....##.", ".##....##....##.", ".###..####..###.", ".######..######.", "..############..", "...##########...",
        "...#.##.##.#.#..", "...#.##.##.#.#..", "....########....", "................"]),
    ('GEM', WHITE, BCYAN, [
        "................", "................", "...##########...", "..##.######.##..", ".##...####...##.", "################",
        "################", ".##..######..##.", "..##..####..##..", "...##.####.##...", "....##.##.##....", ".....######.....",
        "......####......", ".......##.......", "................", "................"]),
    ('CROWN', YELLOW, YELLOW, [
        "................", ".##....##....##.", ".##....##....##.", ".#.#..####..#.#.", ".#.#..####..#.#.", ".#..##.##.##..#.",
        ".#..##.##.##..#.", ".#...##..##...#.", ".##############.", ".##############.", ".##.##.##.##.##.", ".##############.",
        ".##############.", "................", "................", "................"]),
]
NPOWER = 6      # the first six are power-ups


# ---------------------------------------------------------------- sprites
def ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


HAT = art([
    "................",
    "................",
    ".....######.....",
    "....########....",
    "....########....",
    "....#......#....",
    "..############..",
    ".##############.",
])
HAT_R = art([
    "................",
    "................",
    "....######......",
    "...########.....",
    "...########.....",
    "...#......#.....",
    ".#############..",
    ".###############",
])


def face(direction, mouth, scale=1.0):
    """the hunter's head: rows 8..15 of the 16 x 16 box"""
    e = ellipse(7.5, 11.6, 6.9 * scale, 4.3 * scale)
    k = (0.0, 0.45, 0.95)[mouth]

    def fn(x, y):
        if y < 8 or not e(x, y):
            return False
        if direction == 'R':
            if (x, y) in ((8, 9), (9, 9)):
                return False
            if mouth and x > 6.5 and abs(y - 12.0) < (x - 6.5) * k:
                return False
        elif direction == 'D':
            if (x, y) in ((4, 10), (5, 10), (10, 10), (11, 10)):
                return False
            if mouth and y > 11.5 and abs(x - 7.5) < (y - 11.2) * (k + 0.3):
                return False
            if not mouth and y == 13 and 5 <= x <= 10:
                return False
        elif direction == 'U':
            if mouth and y == 15:
                return False
        return True
    return mk(fn)


def split(full):
    """16 x 16 -> (top bits, top mask), (bottom bits, bottom mask) with the
    outline kept inside each half"""
    m = grow(full)
    t, tm, b, bm = full.copy(), m.copy(), full.copy(), m.copy()
    t[8:] = False
    tm[8:] = False
    b[:8] = False
    bm[:8] = False
    return (t, tm), (b, bm)


GHOST_BODY = [
    "................",
    ".....######.....",
    "...##########...",
    "..############..",
    ".##############.",
    ".##############.",
    ".##############.",
    ".##############.",
    ".##############.",
    ".##############.",
    ".##############.",
    ".##############.",
    ".##############.",
]
GHOST_FEET = [
    [".##############.", ".###.####.####..", "..#...##...##..."],
    [".##############.", "..####.####.###.", "...##...##...#.."],
]


def ghost(kind, direction, anim):
    """kind 0 GRUMBLE 1 SNEAKY 2 DIZZY 3 PEEKABOO; direction R L U D"""
    b = art(GHOST_BODY + GHOST_FEET[anim])
    ox, oy = {'R': (1, 0), 'L': (-1, 0), 'U': (0, -1), 'D': (0, 1)}[direction]
    if kind == 3:           # hollow
        inner = b.copy()
        for _ in range(2):
            n = inner.copy()
            n[1:, :] &= inner[:-1, :]
            n[:-1, :] &= inner[1:, :]
            n[:, 1:] &= inner[:, :-1]
            n[:, :-1] &= inner[:, 1:]
            n[0, :] = n[-1, :] = False
            inner = n
        b &= ~inner
        for ex in (4, 9):
            for y in range(3):
                for x in range(3):
                    b[5 + y + oy, ex + x + ox] = True
        return b
    eh = 4
    ey = 4
    if kind == 1:
        eh, ey = 2, 6
    for ex in (3, 9):
        for y in range(eh):
            for x in range(4):
                b[ey + y + (oy if kind != 1 else 0), ex + x + ox] = False
        # pupils
        px = ex + ox + 1 + ox
        py = ey + (oy if kind != 1 else 0) + (eh - 2) // 2 + (oy if eh > 2 else 0)
        for y in range(2):
            for x in range(2):
                yy, xx = py + y, px + x
                if 0 <= yy < 16 and 0 <= xx < 16:
                    b[yy, xx] = True
    if kind == 0:           # angry brows
        for ex, s in ((3, 1), (9, -1)):
            for x in range(4):
                xx = ex + ox + x
                d = x if s == 1 else 3 - x
                if d < 2:
                    b[ey + oy, xx] = True
                if d < 1:
                    b[ey + oy + 1, xx] = True
    if kind == 2:           # stripes
        for y in range(9, 13):
            for x in (4, 7, 10):
                b[y, x] = False
    return b


def fright(anim):
    b = art(GHOST_BODY + GHOST_FEET[anim])
    for ex in (4, 10):
        b[5:7, ex:ex + 2] = False
    for x in range(3, 13):
        y = 10 if (x // 2) % 2 == 0 else 9
        b[y, x] = False
    return b


def eyes(direction):
    ox, oy = {'R': (1, 0), 'L': (-1, 0), 'U': (0, -1), 'D': (0, 1)}[direction]
    b = np.zeros((16, 16), bool)
    for ex in (3, 9):
        for y in range(5):
            for x in range(4):
                if (x in (0, 3)) and (y in (0, 4)):
                    continue
                b[4 + y, ex + x] = True
        for y in range(2):
            for x in range(2):
                b[5 + oy + y + (1 if oy == 0 else 0), ex + 1 + ox + x] = False
    return b


DIG = {'0': "111 101 101 101 111", '1': "010 110 010 010 111", '2': "111 001 111 100 111", '4': "101 101 111 001 001",
       '6': "111 100 111 101 111", '8': "111 101 111 101 111"}


def number(txt):
    w = len(txt) * 4 - 1
    b = np.zeros((5, w), bool)
    for i, ch in enumerate(txt):
        for y, row in enumerate(DIG[ch].split()):
            for x, c in enumerate(row):
                b[y, i * 4 + x] = c == '1'
    return b


def sprites():
    """-> list of (name, bits, mask)"""
    S = []

    def add(name, b, outline=True):
        b = np.asarray(b, bool)
        S.append((name, b, grow(b) if outline else b.copy()))

    def half(name, full, top):
        (t, tm), (b, bm) = split(full)
        S.append((name, t, tm) if top else (name, b, bm))
    blank8 = np.zeros((8, 16), bool)
    half('HAT_F', np.vstack([HAT, blank8]), True)
    half('HAT_R', np.vstack([HAT_R, blank8]), True)
    half('HAT_L', mirror(np.vstack([HAT_R, blank8])), True)
    for m in range(3):
        f = face('R', m)
        half('FACE_R%d' % m, f, False)
        half('FACE_L%d' % m, mirror(f), False)
    for m in range(2):
        half('FACE_U%d' % m, face('U', m), False)
        half('FACE_D%d' % m, face('D', m * 2), False)
    for i, sc in enumerate((0.85, 0.65, 0.42, 0.2)):
        half('DIE%d' % i, face('D', 0, sc), False)
    for k in range(4):
        for d in 'RLUD':
            for a in range(2):
                add('G%d%s%d' % (k, d, a), ghost(k, d, a))
    for a in range(2):
        add('FR%d' % a, fright(a))
    for d in 'RLUD':
        add('EYES_%s' % d, eyes(d))
    for t in ('200', '400', '800', '1600', '1000'):
        add('N%s' % t, number(t))
    sp0 = mk(lambda x, y: (x == 3 or y == 3) and abs(x - 3) + abs(y - 3) < 4, 7, 7)
    sp1 = mk(lambda x, y: abs(x - 3) == abs(y - 3) and abs(x - 3) < 3, 7, 7)
    add('SPARK0', sp0, False)
    add('SPARK1', sp1, False)
    ring = mk(lambda x, y: 6.6 <= math.hypot(x - 7.5, (y - 7.5)) <= 7.9 and (x + y) % 2 == 0)
    add('RING0', ring, False)
    ring1 = mk(lambda x, y: 6.6 <= math.hypot(x - 7.5, (y - 7.5)) <= 7.9 and (x + y) % 2 == 1)
    add('RING1', ring1, False)
    # the giant hunter of the intermissions (32 x 32, facing left)
    hat = np.kron(mirror(np.vstack([HAT_R, blank8])), np.ones((2, 2), bool))
    S.append(('BIGHAT', hat[:16], hat[:16].copy()))
    for m in (0, 2):
        f = np.kron(mirror(face('R', m)), np.ones((2, 2), bool))
        S.append(('BIGFACE%d' % (m // 2), f[16:], f[16:].copy()))
    return S


# ---------------------------------------------------------------- HUD icons
def g8(rows):
    return bytes([0] + [int(r, 2) for r in rows] + [0])


ICONS = [
    ('heart', g8(["01101100", "11111110", "11111110", "11111110", "01111100", "00111000", "00010000", "00000000"])),
    ('heart_e', g8(["01101100", "10010010", "10000010", "10000010", "01000100", "00101000", "00010000", "00000000"])),
    ('life', g8(["00111000", "01111100", "11111110", "00000000", "01111100", "11101110", "11111000", "01111100"])),
    ('solid', bytes([255] * CH)),
    ('ghost', g8(["00111100", "01111110", "11011011", "11011011", "11111111", "11111111", "11111111", "10110101"])),
] + [('bar%d' % k, bytes([0, 0, 0] + [(0xFF00 >> k) & 0xFF] * 4 + [0, 0, 0])) for k in range(9)]


# ---------------------------------------------------------------- the title picture
def scale_text(text, sx, sy):
    rows = []
    for r in range(7):
        line = []
        for ch in text:
            bits = FD.get(ch, FD[' ']).split()[r]
            for b in bits:
                line += [b == '1'] * sx
            line += [False] * sx
        rows += [line] * sy
    return np.array(rows, bool)


def title_picture():
    W, H = 320, 250
    bits = np.zeros((H, W), bool)
    ink = np.full((25, 40), WHITE, np.uint8)
    paper = np.zeros((25, 40), np.uint8)

    def put(b, x0, y0):
        h, w = b.shape
        bits[y0:y0 + h, x0:x0 + w] |= b

    def colour(r0, r1, c0, c1, col):
        ink[r0:r1, c0:c1] = col
    # stars
    for i in range(46):
        x = int(hsh(i, 1, 5) * 320)
        y = 120 + int(hsh(i, 2, 5) * 44)
        bits[y, x] = True
        ink[y // CH, x // 8] = (WHITE, BCYAN, GREY, YELLOW)[i % 4]
    # the logo: fat wavy letters with an inline stripe and a hatched shadow
    def logo(text, x0, y0, sx, sy, fat, amp, phase, cols, c0, c1):
        raw = scale_text(text, sx, sy)[:, :-sx]
        h, w = raw.shape
        pad = fat + amp + 6
        big = np.zeros((h + 2 * pad, w + 2 * pad), bool)
        big[pad:pad + h, pad:pad + w] = raw
        yy, xx = np.nonzero(big)
        fatb = np.zeros_like(big)
        for dy in range(-fat, fat + 1):
            for dx in range(-fat - 1, fat + 2):
                if (dx / (fat + 1.3)) ** 2 + (dy / (fat + 0.3)) ** 2 <= 1.0:
                    fatb[np.clip(yy + dy, 0, big.shape[0] - 1), np.clip(xx + dx, 0, big.shape[1] - 1)] = True
        # the wave: each column slides up or down
        wav = np.zeros_like(fatb)
        for x in range(fatb.shape[1]):
            o = int(round(amp * math.sin(x / 17.0 + phase)))
            col = fatb[:, x]
            wav[:, x] = np.roll(col, o)
        # inline stripe: the edge of the shape shrunk by two pixels
        er = wav.copy()
        for _ in range(2):
            n = er.copy()
            n[1:, :] &= er[:-1, :]
            n[:-1, :] &= er[1:, :]
            n[:, 1:] &= er[:, :-1]
            n[:, :-1] &= er[:, 1:]
            er = n
        inner = er.copy()
        inner[1:, :] &= er[:-1, :]
        inner[:-1, :] &= er[1:, :]
        inner[:, 1:] &= er[:, :-1]
        inner[:, :-1] &= er[:, 1:]
        stripe = er & ~inner
        shape = wav & ~stripe
        # hatched shadow down and right, with a gap round the letters
        sh = np.zeros_like(wav)
        sh[4:, 4:] = wav[:-4, :-4]
        near = grow(grow(wav))
        hy, hx = np.indices(wav.shape)
        sh &= ~near & ((hx + hy) % 2 == 0)
        out = shape | sh
        H2, W2 = out.shape
        ys, xs = y0 - pad, x0 - pad
        for y in range(H2):
            for x in range(W2):
                if out[y, x] and 0 <= ys + y < H and 0 <= xs + x < 320:
                    bits[ys + y, xs + x] = True
        r0, r1 = max(0, (ys + pad - fat - amp) // CH), min(25, (ys + pad + h + fat + amp + 4) // CH + 1)
        for i, r in enumerate(range(r0, r1)):
            colour(r, r + 1, c0, c1, cols[min(i * len(cols) // max(1, r1 - r0), len(cols) - 1)])
    logo('GHOST', 10, 8, 6, 6, 1, 2, 0.0, (WHITE, BCYAN, BCYAN, CYAN, BBLUE, BBLUE), 0, 24)
    logo("'26", 214, 8, 5, 6, 1, 2, 2.0, (WHITE, BGREEN, BGREEN, BGREEN, GREEN, GREEN), 24, 40)
    logo('HUNTER', 54, 66, 6, 6, 1, 2, 1.6, (YELLOW, YELLOW, BRED, BRED, RED, RED), 0, 40)
    # the moon
    mx, my, mr = 30, 138, 14
    for y in range(my - mr, my + mr + 1):
        for x in range(mx - mr - 3, mx + mr + 4):
            d = math.hypot((x - mx) / 1.1, y - my)
            if d <= mr and not (math.hypot(x - mx + 5, y - my + 4) < 3 or math.hypot(x - mx - 6, y - my - 5) < 4 or math.hypot(x - mx - 3, y - my + 8) < 2):
                bits[y, x] = True
    colour(12, 16, 0, 7, YELLOW)
    # the graveyard
    for x in range(W):
        top = 203 + int(round(2 * math.sin(x / 31.0) + math.sin(x / 13.0 + 1)))
        for y in range(top, 220):
            bits[y, x] = ((x + y) % 2 == 0) or y == top or hsh(x, y, 3) < 0.3
    colour(20, 22, 0, 40, GREEN)
    stone = art([
        "....########....", "..############..", ".##############.", ".######..######.", ".######..######.", ".###........###.",
        ".###........###.", ".######..######.", ".######..######.", ".######..######.", ".##############.", ".##############.",
        ".#.############.", ".##########.###.", ".##############.", ".##############.", ".######.#######.", ".##############.",
        ".##############.", ".##############.", ".##############.", ".##############.", ".##############.", ".##############."])
    for sxp in (24, 88, 184, 240):
        put(stone, sxp, 180)
        colour(18, 20, sxp // 8, sxp // 8 + 2, GREY)
    cross = art([
        "......####......", "......####......", "......####......", "..############..", "..############..", "......####......",
        "......####......", "......####......", "......####......", "......####......", "......####......", "......####......",
        "......####......", "......####......", "......####......", "......####......"])
    for sxp in (56, 136):
        put(cross, sxp, 188)
        colour(18, 20, sxp // 8, sxp // 8 + 2, DGREY)
    # a dead tree
    tree = np.zeros((56, 32), bool)
    for y in range(56):
        wdt = 2 + (y // 20)
        for x in range(15 - wdt, 15 + wdt):
            tree[y, x] = True
    for (x0, y0, dx, n) in ((15, 30, -1, 12), (15, 22, 1, 13), (15, 12, -1, 9), (15, 6, 1, 7), (8, 22, -1, 5), (24, 12, 1, 5)):
        for k in range(n):
            xx, yy = x0 + dx * k, y0 - k // 2
            if 0 <= xx < 32 and 0 <= yy < 56:
                tree[yy, xx] = True
                tree[yy + 1, xx] = True
    put(tree, 280, 148)
    colour(14, 20, 35, 39, BROWN)
    return bits, ink, paper
