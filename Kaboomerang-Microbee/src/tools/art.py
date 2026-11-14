"""KABOOMERANG artwork: tiles, sprites, font, HUD icons (ViBED by BPM 2026).

Everything is drawn here in Python and packed into Microbee PCG glyphs of
8 x 8 pixels (stored as 16-byte PCG slots, rows 8-15 unused in the
8-line mode). Tiles are 16 x 16 pixels = 2 x 2 cells; each cell has its own
ink and paper. Colours are the Premium Plus numbers:
0 black 1 red 2 green 3 brown 4 blue 5 magenta 6 cyan 7 grey
8 dark grey 9 bright red 10 bright green 11 yellow 12 bright blue
13 bright magenta 14 bright cyan 15 white
"""
import math
import numpy as np

BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)
LUM = [0, 57, 113, 85, 22, 79, 135, 192, 96, 140, 190, 235, 90, 170, 215, 255]


def imul(a, b):
    return (a * b) & 0xFFFFFFFF


def hsh(x, y, s):
    n = (imul(x & 0xFFFFFFFF, 374761393) + imul(y & 0xFFFFFFFF, 668265263) + imul(s & 0xFFFFFFFF, 1442695041)) & 0xFFFFFFFF
    n = imul(n ^ (n >> 13), 1274126177)
    return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967296.0


TW, TH = 16, 20            # a tile: 16 x 20 pixels = 2 x 2 cells of 8 x 10
ASPECT = 1.09              # a 40-column pixel is about 1.09 times wider than tall


def resample(bits, mode):
    """16-row art -> 20 rows. 'fill' stretches it over the whole tile (flames,
    mounds); 'round' keeps it round on screen, centred; 'stand' keeps it round
    and stands it on the floor (creatures)"""
    bits = np.asarray(bits, bool)
    h, w = bits.shape
    out = np.zeros((TH, w), bool)
    top = 0 if mode == 'fill' else (TH - h * ASPECT) / (2 if mode == 'round' else 1)
    for r in range(TH):
        if mode == 'fill':
            sy = int((r + 0.5) * h / TH)
        else:
            sy = int((r + 0.5 - top) / ASPECT)
        if 0 <= sy < h:
            out[r] = bits[sy]
    return out


def mk(fn, w=16, h=16):
    return np.array([[bool(fn(x, y)) for x in range(w)] for y in range(h)], bool)


def art(rows):
    return np.array([[c == '#' for c in r] for r in rows], bool)


def mirror(a):
    return a[:, ::-1].copy()


# ---------------------------------------------------------------- tiles
# a tile: bits (16,16) and four (ink, paper) pairs: TL, TR, BL, BR
class Tile:
    def __init__(self, name, bits, cols, floor=False, mode='fill'):
        bits = np.asarray(bits, bool)
        if bits.shape[0] != TH:
            bits = resample(bits, mode)
        self.name, self.bits, self.cols, self.floor = name, bits, cols, floor


def q4(a, b):
    return [a, a, b, b]


def floor_tile(v, shadow):
    def fn(x, y):
        if shadow and y < 4 and ((x + y) & 1) == 0 and (y < 2 or x & 2):
            return True
        r = hsh(x + v * 37, y + v * 11, 7)
        if r < 0.045:
            return True
        if r < 0.07 and x < 15 and hsh(x + 1 + v * 37, y + v * 11, 7) < 0.4:
            return True
        return False
    cols = [(DGREY, BLACK), (DGREY, BLACK), (RED, BLACK), (RED, BLACK)] if shadow else q4((RED, BLACK), (RED, BLACK))
    return Tile('FLOOR%d%s' % (v, 'S' if shadow else ''), mk(fn, TW, TH), cols, floor=True)


def pillar():
    """a sandstone block: sunlit top and left edge, layered strata, a shaded foot"""
    def fn(x, y):
        if y < 10:
            if y <= 1 or x == 0:
                return True
            if y == 2 and x < 3:
                return True
            return (y in (5, 8)) and hsh(x, y, 11) < 0.6 and 1 < x < 15
        if y >= 18 or x == 15:
            return True
        return (y in (12, 15)) and hsh(x, y, 12) < 0.55
    return Tile('PILLAR', mk(fn, TW, TH), [(YELLOW, RED), (YELLOW, RED), (BLACK, RED), (BLACK, RED)])


def border():
    """the outback fence: weathered posts"""
    def fn(x, y):
        if y in (0, 10):
            return True
        if y in (4, 15) and x % 4 == 1:
            return False
        return (x % 4) < 2
    return Tile('BORDER', mk(fn, TW, TH), q4((GREY, DGREY), (GREY, DGREY)))


def mound(k):
    def fn(x, y):
        if k and hsh(x, y, 99) < k / 8:
            return False
        if y < 8:
            hw = 1.5 + y * 0.85
            if abs(x - 7.5) > hw:
                return False
            return ((x + y) & 1) == 0 or hsh(x, y, 5) < 0.25
        if y == 15:
            return False
        return ((x + y) & 1) == 0 or hsh(x, y, 6) < 0.22
    cols = q4((DGREY, BLACK), (DGREY, RED)) if k > 5 else [(YELLOW, BLACK), (YELLOW, BLACK), (YELLOW, RED), (YELLOW, RED)]
    return Tile('MOUND%d' % k, mk(fn), cols)


def bomb_bits(pulse, flick):
    r = 6.8 if pulse else 6.1

    def fn(x, y):
        if y < 8:
            if (x == 8 and 2 <= y <= 3) or (x == 9 and y == 1) or (x == 10 and y == 0):
                return True
            if flick and ((x == 11 and y in (0, 1)) or (x == 12 and y == 0)):
                return True
            if y >= 4:
                hw = 3 if y == 4 else 4.5 if y == 5 else 5.5
                if abs(x - 7.5) <= hw:
                    return not (y == 5 and x % 3 == 0)
            return False
        dx, dy = x - 7.5, y - 8.5
        if dx * dx + dy * dy * 1.1 > r * r:
            return False
        if (x == 5 and y in (9, 10)) or (x == 4 and y == 10):
            return False
        return True
    return mk(fn)


def bomb_tile(pulse, flick, warn):
    body = (BRED if pulse else RED) if warn else (BGREEN if pulse else GREEN)
    top = WHITE if flick else YELLOW
    return Tile('BOMB%d%d%d' % (pulse, flick, warn), bomb_bits(pulse, flick), [(top, BLACK), (top, BLACK), (body, BLACK), (body, BLACK)], mode='round')


FLAMECOL = [(WHITE, YELLOW), (YELLOW, BRED), (BRED, RED), (RED, BLACK)]


def flame_tile(kind, ph):
    if ph >= 3:
        return Tile('SMOKE', mk(lambda x, y: hsh(x, y, 40 + 3) < 0.28), q4((DGREY, BLACK), (DGREY, BLACK)))

    def j(a, b):
        return hsh(a, b, ph + 3) * 1.6

    def cx(x):
        return abs(x - 7.5)

    def cy(y):
        return abs(y - 7.5)
    full = True
    if kind == 'c':
        fn = lambda x, y: cx(x) < 2.6 + j(y, 1) or cy(y) < 2.6 + j(x, 2) or (cx(x) ** 2 + cy(y) ** 2 < 22)
    elif kind == 'h':
        fn = lambda x, y: cy(y) < 2.4 + j(x, 3)
    elif kind == 'v':
        fn = lambda x, y: cx(x) < 2.4 + j(y, 4)
    else:
        full = False
        fn = {'r': lambda x, y: cy(y) < 6.5 - x * 0.42 + j(x, 5) and x < 14,
              'l': lambda x, y: cy(y) < 6.5 - (15 - x) * 0.42 + j(x, 5) and x > 1,
              'd': lambda x, y: cx(x) < 6.5 - y * 0.42 + j(y, 6) and y < 14,
              'u': lambda x, y: cx(x) < 6.5 - (15 - y) * 0.42 + j(y, 6) and y > 1}[kind]
    col = FLAMECOL[ph] if full else (FLAMECOL[ph][1], BLACK)
    return Tile('FL_%s%d' % (kind, ph), mk(fn), q4(col, col))


def item_tiles():
    def fire(x, y):
        if y < 2 or y > 14:
            return False
        hw = (y - 2) * 0.62 + 0.4 if y < 9 else 4.7 - (y - 9) * 0.55
        if y < 6 and x in (5, 10) and y > 3:
            return True
        return abs(x - 7.5) <= hw

    def nut(x, y):
        dx, dy = x - 7.5, y - 8.5
        if y < 5:
            return (x == 10 and y >= 2) or (x == 11 and y == 1)
        if y < 7:
            return abs(dx) < (2.5 if y == 5 else 4)
        return dx * dx + dy * dy < 20 and not (x == 6 and y == 9)

    def heart(x, y):
        X, Y = (x - 7.5) / 6.2, (7 - y) / 6.2
        a = X * X + Y * Y - 1
        return a * a * a - X * X * Y * Y * Y < 0

    def thong(x, y):
        dx, dy = (x - 7.5) / 4.6, (y - 8) / 7
        e = dx * dx + dy * dy
        return (0.45 < e < 1) or (4 <= y <= 8 and abs(x - 7.5) < 0.8) or (y == 4 and x in (5, 10)) or (y == 5 and x in (4, 11))

    def log(x, y):
        dx, dy = (x - 7.5) / 7, (y - 8) / 6.5
        e = dx * dx + dy * dy
        return e < 1 and (e > 0.42 or hsh(x, y, 77) < 0.08)
    return [Tile('IT_FIRE', mk(fire), [(YELLOW, BLACK), (YELLOW, BLACK), (BRED, BLACK), (BRED, BLACK)], mode='round'),
            Tile('IT_NUT', mk(nut), [(BROWN, BLACK), (BROWN, BLACK), (BGREEN, BLACK), (BGREEN, BLACK)], mode='round'),
            Tile('IT_HEART', mk(heart), q4((BRED, BLACK), (BRED, BLACK)), mode='round'),
            Tile('IT_THONG', mk(thong), q4((BCYAN, BLACK), (BCYAN, BLACK)), mode='round'),
            Tile('EXIT', mk(log), [(YELLOW, BLACK), (YELLOW, BLACK), (BROWN, BLACK), (BROWN, BLACK)], mode='round')]


def burrow():
    def fn(x, y):
        dx, dy = (x - 7.5) / 7, (y - 8) / 6
        e = dx * dx + dy * dy
        return (0.55 < e < 1 and ((x + y) & 1 or e > 0.75)) or (e >= 1 and hsh(x, y, 31) < 0.06)
    return Tile('BURROW', mk(fn), q4((RED, BLACK), (RED, BLACK)), mode='round')


HATCH = mk(lambda x, y: ((x + y) & 3) == 0, TW, TH)


def all_tiles():
    T = []
    for v in range(4):
        T.append(floor_tile(v, False))
    for v in range(4):
        T.append(floor_tile(v, True))
    # blast preview: floor hatched in red (easy mode warning)
    T.append(Tile('WARN', HATCH | floor_tile(0, False).bits, q4((BRED, BLACK), (BRED, BLACK)), floor=True))
    T.append(Tile('WARN2', HATCH | floor_tile(0, False).bits, q4((RED, BLACK), (RED, BLACK)), floor=True))
    T += [border(), pillar(), burrow()]
    for k in range(9):
        T.append(mound(k))
    for warn in (0, 1):
        for pulse in (0, 1):
            for flick in (0, 1):
                T.append(bomb_tile(pulse, flick, warn))
    for kind in 'chvlrud':
        for ph in range(3):
            T.append(flame_tile(kind, ph))
    T.append(flame_tile('c', 3))
    T += item_tiles()
    return T


# ---------------------------------------------------------------- sprites
import wally as W

TOAD = ["................", "................", "...###....###...", "..##.##..##.##..", "..#####..#####..", ".##############.", "################", "#.############.#",
        "################", "###.###..###.###", "################", ".######..######.", ".##.##....##.##.", "##..##....##..##", "#....#....#....#", "................"]
TOAD_SQ = ["................", "................", "................", "................", "...###....###...", "..##.##..##.##..", ".##############.", "################",
           "################", "################", "###.###..###.###", "################", ".##############.", "###.##....##.###", "................", "................"]
FR_TOP = ["................", "..#.#.#..#.#.#..", ".##############.", "####........####", "###..##..##..###", "###.#..##..#.###", ".###.######.###.", "...##########..."]
FR_TOP_DOWN = ["................", "................", "................", "......####......", ".....##..##.....", "....#.#..#.#....", "....########....", "...##########..."]
FR_LEGS_A = [".....######.....", "...##########...", "..#.########.#..", ".#..########..#.", "....########....", "...##.####.##...", "..##...##...##..", "........##......"]
FR_LEGS_B = [".....######.....", "...##########...", "..#.########.#..", ".#..########..#.", "....########....", "....#.####.#....", "...##..##..##...", ".......##......."]
IBIS = [["................", ".....###........", "....#####.......", "....##.##.......", "....#####.......", "...##.###.......", "..##...###......", ".#.....####.....",
         "......########..", ".....##########.", "....###########.", ".....#########..", "......#######...", "........#..#....", "........#..#....", ".......##.##...."],
        ["................", ".....###........", "....#####.......", "....##.##.......", "....#####.......", "...##.###.......", "..##...###......", ".#.....####.....",
         "......########..", ".....##########.", "....###########.", ".....#########..", "......#######...", "........#..#....", ".......#....#...", "......##...##..."]]


def grow(bits):
    m = bits.copy()
    m[:, 1:] |= bits[:, :-1]
    m[:, :-1] |= bits[:, 1:]
    m[1:, :] |= bits[:-1, :]
    m[:-1, :] |= bits[1:, :]
    return m


def split(full, at=10):
    """sprite -> (top part bits, mask), (bottom bits, mask): the mask grows
    from the whole sprite so the two parts don't erase each other. The parts
    meet at a cell boundary (row 10 for 20-row art, 4 for Wally's hat)."""
    full = np.asarray(full, bool)
    m = grow(full)
    tb, tm = full.copy(), m.copy()
    tb[at:] = False
    tm[at:] = False
    bb, bm = full.copy(), m.copy()
    bb[:at] = False
    bm[:at] = False
    return (tb, tm), (bb, bm)


def boom_frames():
    base = set()

    def line(x0, y0, x1, y1):
        n = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(n + 1):
            x = round(x0 + (x1 - x0) * i / n)
            y = round(y0 + (y1 - y0) * i / n)
            for a, b in ((0, 0), (1, 0), (0, 1), (1, 1)):
                base.add((x + a, y + b))
    line(2, 3, 7, 11)
    line(7, 11, 13, 4)
    pts = list(base)
    out = []
    for r in range(4):
        st = set(pts)
        out.append(resample(mk(lambda x, y: (x, y) in st), 'round'))
        pts = [(15 - y, x) for x, y in pts]
    return out


WALLY_FACES = ('norm', 'back', 'blink', 'lookL', 'lookR', 'wide', 'dizzy', 'happy')
WALLY_FEET = ('a', 'b', 'c', 'wide', 'up')
# the face + feet pairs the game actually draws (the rest map to norm_a)
WALLY_USED = [('norm', 'a'), ('norm', 'b'), ('norm', 'c'), ('back', 'a'), ('back', 'b'), ('back', 'c'),
              ('blink', 'a'), ('blink', 'b'), ('blink', 'wide'), ('lookL', 'a'), ('lookL', 'b'),
              ('lookR', 'a'), ('lookR', 'b'), ('wide', 'up'), ('happy', 'a'), ('happy', 'wide'),
              ('dizzy', 'a'), ('dizzy', 'wide')]


def wally_combo():
    """face * 5 + feet -> index into WALLY_USED"""
    out = []
    for face in WALLY_FACES:
        for feet in WALLY_FEET:
            out.append(WALLY_USED.index((face, feet)) if (face, feet) in WALLY_USED else 0)
    return out


def sprites():
    """-> list of (name, bits, mask). Two-ink sprites come as NAME_T / NAME_B."""
    S = []

    def two(name, full, at=10):
        (tb, tm), (bb, bm) = split(full, at)
        S.append((name + '_T', tb, tm))
        S.append((name + '_B', bb, bm))

    # Wally: 16 x 24. The hat (rows 0-3) is one part, the wombat (4-23) another
    hats = (('HAT_F', W.HAT), ('HAT_B', W.HAT_BACK), ('HAT_R', W.HAT_SIDE))
    for n, h in hats:
        full = art(h + ['.' * 16] * 20)
        (tb, tm), _ = split(full, 4)
        S.append((n, tb, tm))
    S.append(('HAT_L', mirror(S[-1][1]), mirror(S[-1][2])))
    for face, feet in WALLY_USED:
        full = art(W.front(face, feet, back=(face == 'back')))
        _, (bb, bm) = split(full, 4)
        S.append(('W_%s_%s' % (face, feet), bb, bm))
    for i in range(2):
        full = art(W.side(i))
        _, (bb, bm) = split(full, 4)
        S.append(('W_SIDE%d' % i, bb, bm))
        S.append(('W_SIDEL%d' % i, mirror(bb), mirror(bm)))
    full = art(['.' * 16] * 4 + W.SQUASH)
    _, (bb, bm) = split(full, 4)
    S.append(('W_SQUASH', bb, bm))
    # the wildlife: 16 x 20, standing on the floor
    two('TOAD', resample(art(TOAD), 'stand'))
    two('TOADSQ', resample(art(TOAD_SQ), 'stand'))
    two('FRS0', resample(art(FR_TOP_DOWN + FR_LEGS_A), 'stand'))
    two('FRS1', resample(art(FR_TOP_DOWN + FR_LEGS_B), 'stand'))
    two('FRO0', resample(art(FR_TOP + FR_LEGS_A), 'stand'))
    two('FRO1', resample(art(FR_TOP + FR_LEGS_B), 'stand'))
    for i in range(2):
        two('IBL%d' % i, resample(art(IBIS[i]), 'stand'))
        two('IBR%d' % i, resample(mirror(art(IBIS[i])), 'stand'))
    for i, b in enumerate(boom_frames()):
        S.append(('BOOM%d' % i, b, grow(b)))
    puff0 = resample(mk(lambda x, y: math.hypot(x - 7.5, y - 7.5) < 4 and hsh(x, y, 1) < 0.7), 'round')
    puff1 = resample(mk(lambda x, y: 3 < math.hypot(x - 7.5, y - 7.5) < 7 and hsh(x, y, 2) < 0.5), 'round')
    S.append(('PUFF0', puff0, puff0))
    S.append(('PUFF1', puff1, puff1))
    dot = mk(lambda x, y: x < 2 and y < 2, 2, 2)
    S.append(('DOT', dot, dot))
    spark = mk(lambda x, y: (x == 1 and y < 3) or (y == 1 and x < 3), 3, 3)
    S.append(('SPARK', spark, spark))
    star = mk(lambda x, y: (abs(x - 3) == 0 or abs(y - 3) == 0 or (abs(x - 3) == abs(y - 3) and abs(x - 3) < 2)), 7, 7)
    S.append(('STAR', star, star))
    two('CBOMB', resample(bomb_bits(0, 0), 'round'))
    return S


# ---------------------------------------------------------------- font
FD = {'A': "01110 10001 10001 11111 10001 10001 10001", 'B': "11110 10001 10001 11110 10001 10001 11110", 'C': "01110 10001 10000 10000 10000 10001 01110",
      'D': "11110 10001 10001 10001 10001 10001 11110", 'E': "11111 10000 10000 11110 10000 10000 11111", 'F': "11111 10000 10000 11110 10000 10000 10000",
      'G': "01110 10001 10000 10111 10001 10001 01111", 'H': "10001 10001 10001 11111 10001 10001 10001", 'I': "01110 00100 00100 00100 00100 00100 01110",
      'J': "00111 00010 00010 00010 00010 10010 01100", 'K': "10001 10010 10100 11000 10100 10010 10001", 'L': "10000 10000 10000 10000 10000 10000 11111",
      'M': "10001 11011 10101 10101 10001 10001 10001", 'N': "10001 10001 11001 10101 10011 10001 10001", 'O': "01110 10001 10001 10001 10001 10001 01110",
      'P': "11110 10001 10001 11110 10000 10000 10000", 'Q': "01110 10001 10001 10001 10101 10010 01101", 'R': "11110 10001 10001 11110 10100 10010 10001",
      'S': "01111 10000 10000 01110 00001 00001 11110", 'T': "11111 00100 00100 00100 00100 00100 00100", 'U': "10001 10001 10001 10001 10001 10001 01110",
      'V': "10001 10001 10001 10001 10001 01010 00100", 'W': "10001 10001 10001 10101 10101 10101 01010", 'X': "10001 10001 01010 00100 01010 10001 10001",
      'Y': "10001 10001 10001 01010 00100 00100 00100", 'Z': "11111 00001 00010 00100 01000 10000 11111",
      '0': "01110 10001 10011 10101 11001 10001 01110", '1': "00100 01100 00100 00100 00100 00100 01110", '2': "01110 10001 00001 00010 00100 01000 11111",
      '3': "11111 00010 00100 00010 00001 10001 01110", '4': "00010 00110 01010 10010 11111 00010 00010", '5': "11111 10000 11110 00001 00001 10001 01110",
      '6': "00110 01000 10000 11110 10001 10001 01110", '7': "11111 00001 00010 00100 01000 01000 01000", '8': "01110 10001 10001 01110 10001 10001 01110",
      '9': "01110 10001 10001 01111 00001 00010 01100", '-': "00000 00000 00000 11111 00000 00000 00000", ':': "00000 01100 01100 00000 01100 01100 00000",
      '.': "00000 00000 00000 00000 00000 01100 01100", '!': "00100 00100 00100 00100 00100 00000 00100", "'": "00100 00100 01000 00000 00000 00000 00000",
      ',': "00000 00000 00000 00000 01100 00100 01000", '?': "01110 10001 00001 00010 00100 00000 00100", '/': "00001 00010 00010 00100 01000 01000 10000",
      '(': "00010 00100 01000 01000 01000 00100 00010", ')': "01000 00100 00010 00010 00010 00100 01000", '+': "00000 00100 00100 11111 00100 00100 00000",
      '*': "00000 10101 01110 11111 01110 10101 00000", ' ': "00000 00000 00000 00000 00000 00000 00000"}
CHARS = ' !"#$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ'


def font_glyphs():
    """64 rounded glyphs for chars 32..95 (8 x 10)"""
    import fontgen
    return fontgen.font_bytes()


def g8(rows):
    """an 8 x 8 icon centred in an 8 x 10 cell"""
    return bytes([0] + [int(r, 2) for r in rows] + [0])


ICONS = {
    'heart': g8(["01101100", "11111110", "11111110", "11111110", "01111100", "00111000", "00010000", "00000000"]),
    'nut': g8(["00000110", "00001000", "00111100", "01111110", "11111111", "01111110", "00111100", "00000000"]),
    'flame': g8(["00010000", "00011000", "00111000", "00111100", "01111110", "01111110", "00111100", "00000000"]),
    'boom': g8(["01100000", "01110000", "00111000", "00011100", "00001111", "00000111", "00000000", "00000000"]),
    'thong': g8(["00111100", "01111110", "01100110", "01100110", "01111110", "00111100", "00011000", "00000000"]),
    'solid': bytes([255] * 10),
    'heart_e': g8(["01101100", "10010010", "10000010", "10000010", "01000100", "00101000", "00010000", "00000000"]),
}
