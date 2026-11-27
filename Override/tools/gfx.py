"""OVERRIDE graphics: deck tiles, droid sprites, explosion, 3x5 font.
Colour set 0: g = green (0), y = yellow (1), b = blue (2), r = red (3).
"""
from vzpal import pack_row, pix_image

C = {'g': 0, 'y': 1, 'b': 2, 'r': 3, '.': 0}


def art(lines):
    return [[C[ch] for ch in ln] for ln in lines]


# ---------------------------------------------------------------- tiles
NT = 64
T_VOID = 0          # 0-3 void (space) variants
T_FLOOR = 4         # 4-7 deck plates (A top-left, B top-right, C bottom-left, D plain)
T_GRATE = 8
T_HAZ = 9
T_WALL = 12         # 12-27 wall, +mask (1 N open, 2 E open, 4 S open, 8 W open)
T_DHT = 28          # door in a vertical wall, top half: closed / half / open
T_DHB = 31          #   bottom half
T_DVL = 34          # door in a horizontal wall, left half
T_DVR = 37          #   right half
T_LIFT = 40         # 2x2 lift pad TL TR BL BR
T_ENER = 44         # 2x2 energizer TL TR BL BR
T_CONL = 48         # console (solid) left, right
T_CRATE = 50
T_BARREL = 51
T_BANKA = 52
T_BANKB = 53
T_PIPE = 54
T_REACT = 55

# attribute bits
A_SOLID = 1         # blocks droids
A_SHOT = 2          # stops shots
A_DOOR = 4
A_LIFT = 8
A_CONSOLE = 16
A_ENERGY = 32
A_VOID = 64

tiles = [None] * NT
attr = [0] * NT


def setT(i, lines, a=0):
    assert len(lines) == 6 and all(len(l) == 8 for l in lines), (i, lines)
    tiles[i] = art(lines)
    attr[i] = a


# void / space: deep blue with the odd star
setT(0, ["bbbbbbbb"] * 6, A_SOLID | A_SHOT | A_VOID)
setT(1, ["bbbbbbbb", "bbbbbbbb", "bbbbbybb", "bbbbbbbb", "bbbbbbbb", "bbbbbbbb"], A_SOLID | A_SHOT | A_VOID)
setT(2, ["bbbbbbbb", "bbbbbbbb", "bbbbbbbb", "bbbbbbbb", "bgbbbbbb", "bbbbbbbb"], A_SOLID | A_SHOT | A_VOID)
setT(3, ["bbbbbbbb", "bbbbbbyb", "bbbbbbbb", "bbbbbbbb", "bbbbbbbb", "bbbbbbbb"], A_SOLID | A_SHOT | A_VOID)

# deck plates 16x12: a dotted seam on the top and left edges of each plate
setT(4, ["bgbgbgbg", "gggggggg", "bggggggg", "gggggggg", "bggggggg", "gggggggg"])
setT(5, ["bgbgbgbg", "gggggggg", "gggggggg", "gggggggg", "gggggggg", "gggggggg"])
setT(6, ["bggggggg", "gggggggg", "bggggggg", "gggggggg", "bggggggg", "gggggggg"])
setT(7, ["gggggggg"] * 6)
setT(8, ["bgbgbgbg", "gggggggg", "gbgbgbgb", "gggggggg", "bgbgbgbg", "gggggggg"])       # grate
setT(9, ["yybbyybb", "ybbyybby", "bbyybbyy", "byybbyyb", "yybbyybb", "ybbyybby"])       # hazard floor
setT(10, ["gggggggg", "gyggggyg", "gggggggg", "gggggggg", "gyggggyg", "gggggggg"])      # studded floor
setT(11, ["gggggggg"] * 6)


def wall(mask):
    px = [['b'] * 8 for _ in range(6)]
    # rivets on the plate
    px[2][3] = 'g'
    if mask & 1:
        for x in range(8): px[0][x] = 'y'
    if mask & 8:
        for y in range(6): px[y][0] = 'y'
    if mask & 4:
        for x in range(8): px[5][x] = 'r'
    if mask & 2:
        for y in range(6): px[y][7] = 'r'
    if (mask & 1) and (mask & 2): px[0][7] = 'y'
    if (mask & 4) and (mask & 8): px[5][0] = 'r'
    return [''.join(r) for r in px]


for m in range(16):
    setT(T_WALL + m, wall(m), A_SOLID | A_SHOT)

# doors in a vertical wall (passage runs east-west): a slab that parts up / down
DH_CL = ["ggbyybgg", "ggbrrbgg", "ggbyybgg", "ggbrrbgg", "ggbyybgg", "ggbrrbgg"]
setT(T_DHT + 0, DH_CL, A_SOLID | A_SHOT | A_DOOR)
setT(T_DHT + 1, ["ggbyybgg", "ggbrrbgg", "ggbyybgg", "ggbbbbgg", "gggggggg", "gggggggg"], A_SOLID | A_SHOT | A_DOOR)
setT(T_DHT + 2, ["ggbbbbgg", "gggggggg", "gggggggg", "gggggggg", "gggggggg", "gggggggg"], A_DOOR)
setT(T_DHB + 0, ["ggbyybgg", "ggbrrbgg", "ggbyybgg", "ggbrrbgg", "ggbyybgg", "ggbbbbgg"], A_SOLID | A_SHOT | A_DOOR)
setT(T_DHB + 1, ["gggggggg", "gggggggg", "ggbbbbgg", "ggbyybgg", "ggbrrbgg", "ggbbbbgg"], A_SOLID | A_SHOT | A_DOOR)
setT(T_DHB + 2, ["gggggggg", "gggggggg", "gggggggg", "gggggggg", "gggggggg", "ggbbbbgg"], A_DOOR)
# doors in a horizontal wall (passage runs north-south): a slab that parts left / right
setT(T_DVL + 0, ["gggggggg", "bbbbbbbb", "byrybyry", "bryrbryr", "bbbbbbbb", "gggggggg"], A_SOLID | A_SHOT | A_DOOR)
setT(T_DVL + 1, ["gggggggg", "bbbbbggg", "byrybggg", "bryrbggg", "bbbbbggg", "gggggggg"], A_SOLID | A_SHOT | A_DOOR)
setT(T_DVL + 2, ["gggggggg", "bggggggg", "bggggggg", "bggggggg", "bggggggg", "gggggggg"], A_DOOR)
setT(T_DVR + 0, ["gggggggg", "bbbbbbbb", "byrybyrb", "bryrbryb", "bbbbbbbb", "gggggggg"], A_SOLID | A_SHOT | A_DOOR)
setT(T_DVR + 1, ["gggggggg", "gggbbbbb", "gggbyryb", "gggbryrb", "gggbbbbb", "gggggggg"], A_SOLID | A_SHOT | A_DOOR)
setT(T_DVR + 2, ["gggggggg", "gggggggb", "gggggggb", "gggggggb", "gggggggb", "gggggggg"], A_DOOR)

# lift pad 16x12
setT(T_LIFT + 0, ["bbbbbbbb", "byyyyyyy", "bybbbbbb", "bybyyyyy", "bybybbbb", "bybyb..."[:5] + "rrr"], A_LIFT)
setT(T_LIFT + 1, ["bbbbbbbb", "yyyyyyyb", "bbbbbbyb", "yyyyybyb", "bbbbybyb", "rrrbybyb"], A_LIFT)
setT(T_LIFT + 2, ["bybybrrr", "bybybbbb", "bybyyyyy", "bybbbbbb", "byyyyyyy", "bbbbbbbb"], A_LIFT)
setT(T_LIFT + 3, ["rrrbybyb", "bbbbybyb", "yyyyybyb", "bbbbbbyb", "yyyyyyyb", "bbbbbbbb"], A_LIFT)
# energizer 16x12: a glowing red/yellow coil
setT(T_ENER + 0, ["rrrrrrrr", "ryyyyyyy", "ryrrrrrr", "ryrybyby", "ryrbybyb", "ryrybyby"], A_ENERGY)
setT(T_ENER + 1, ["rrrrrrrr", "yyyyyyyr", "rrrrrryr", "ybybyryr", "bybybryr", "ybybyryr"], A_ENERGY)
setT(T_ENER + 2, ["ryrbybyb", "ryrybyby", "ryrrrrrr", "ryyyyyyy", "rrrrrrrr", "gggggggg"], A_ENERGY)
setT(T_ENER + 3, ["bybybryr", "ybybyryr", "rrrrrryr", "yyyyyyyr", "rrrrrrrr", "gggggggg"], A_ENERGY)
# console: a terminal desk with a screen (solid; push into it to use it)
setT(T_CONL + 0, ["bbbbbbbb", "byyyyyyy", "bybgbgbg", "bygbgbgb", "byyyyyyy", "brrbrrbb"], A_SOLID | A_SHOT | A_CONSOLE)
setT(T_CONL + 1, ["bbbbbbbb", "yyyyyyyb", "bgbgrgyb", "gbgbgbyb", "yyyyyyyb", "brrbrrbb"], A_SOLID | A_SHOT | A_CONSOLE)
# props
setT(T_CRATE, ["bbbbbbbb", "byyyyyyb", "byrrrryb", "byrrrryb", "byyyyyyb", "bbbbbbbb"], A_SOLID | A_SHOT)
setT(T_BARREL, ["gbbbbbbg", "byyyyyyb", "brrrrrrb", "byyyyyyb", "brrrrrrb", "gbbbbbbg"], A_SOLID | A_SHOT)
setT(T_BANKA, ["bbbbbbbb", "bgbybrbb", "bbbbbbbb", "bybgbybb", "bbbbbbbb", "byyyyyyb"], A_SOLID | A_SHOT)
setT(T_BANKB, ["bbbbbbbb", "bbrbgbyb", "bbbbbbbb", "bbgbybrb", "bbbbbbbb", "byyyyyyb"], A_SOLID | A_SHOT)
setT(T_PIPE, ["gggggggg", "bbbbbbbb", "yyyyyyyy", "bbrbbbrb", "bbbbbbbb", "gggggggg"], A_SOLID)
setT(T_REACT, ["gbbbbbbg", "byyrryyb", "byrrrryb", "byrrrryb", "byyrryyb", "gbbbbbbg"], A_SOLID | A_SHOT)

for i in range(NT):
    if tiles[i] is None:
        tiles[i] = art(["gggggggg"] * 6)

FLOORS = (4, 5, 6, 7, 8, 10, 11)


def dim_tile(t):
    """lights-out version of a floor tile: blue plates with green seams"""
    sw = {0: 2, 2: 0, 1: 1, 3: 3}
    return [[sw[c] for c in row] for row in t]


# ---------------------------------------------------------------- ship themes
# Each ship carries its own floors and wall plating (OVn.DAT loads them over
# tiles_norm / tiles_dim). Theme 0 is the base set above.
DIAMOND = ["gggbgggg", "ggbgbggg", "gbgggbgg", "ggbgbggg", "gggbgggg", "gggggggg"]
GRID = ["bgbgbgbg", "bggggggg", "gggggggg", "bggggggg", "gggggggg", "bggggggg"]
TREAD = ["gbgggbgg", "gggggggg", "gggbgggb", "gggggggg", "gbgggbgg", "gggggggg"]
PLATE_A = ["bbbbbbbb", "bggggggg", "bggggggg", "bggggggg", "bggggggg", "bggggggg"]
PLATE_B = ["bbbbbbbb", "gggggggg", "gggggggg", "gggggggg", "gggggggg", "gggggggg"]
PLATE_C = ["bggggggg", "bggggggg", "bgggyggg", "bggggggg", "bggggggg", "bggggggg"]

THEMES = [
    dict(name='freighter'),
    dict(name='liner', floor=[DIAMOND] * 4, plain=DIAMOND,
         wall=dict(plate='b', mark=((2, 0), (2, 1), (2, 2), (2, 3), (2, 4), (2, 5), (2, 6), (2, 7)),
                   mark_c='g', n='y', w='y', s='y', e='y')),
    dict(name='science', floor=[GRID] * 4, plain=GRID,
         wall=dict(plate='b', mark=((1, 3), (2, 3), (3, 3), (1, 4), (2, 4), (3, 4)), mark_c='g',
                   n='y', w='y', s='r', e='r')),
    dict(name='mining', floor=[TREAD] * 4, plain=TREAD,
         wall=dict(plate='r', mark=((1, 1), (1, 6), (4, 1), (4, 6)), mark_c='y',
                   n='y', w='y', s='b', e='b')),
    dict(name='warship', floor=[PLATE_A, PLATE_B, PLATE_C, ["g" * 8] * 6], plain=["g" * 8] * 6,
         wall=dict(plate='b', mark=((2, 2), (2, 5)), mark_c='y', n='r', w='r', s='y', e='y')),
]


def themed_wall(mask, w):
    px = [[w['plate']] * 8 for _ in range(6)]
    for (y, x) in w['mark']: px[y][x] = w['mark_c']
    if mask & 1:
        for x in range(8): px[0][x] = w['n']
    if mask & 8:
        for y in range(6): px[y][0] = w['w']
    if mask & 4:
        for x in range(8): px[5][x] = w['s']
    if mask & 2:
        for y in range(6): px[y][7] = w['e']
    return [''.join(r) for r in px]


def theme_tiles(theme):
    th = THEMES[theme]
    ts = list(tiles)
    if 'floor' in th:
        for k, t in enumerate(th['floor']): ts[T_FLOOR + k] = art(t)
        ts[11] = art(th['plain'])
    if 'wall' in th:
        for m in range(16): ts[T_WALL + m] = art(themed_wall(m, th['wall']))
    return ts


def tileset_bytes(dim=False, theme=0):
    """layout [sub-row 0..5][tile 0..63][2 bytes] (128 bytes a sub-row)"""
    out = bytearray()
    ts = theme_tiles(theme)
    for sr in range(6):
        for t in range(NT):
            px = ts[t]
            if dim and t in FLOORS:
                px = dim_tile(px)
            out += pack_row(px[sr])
    return bytes(out)


# ---------------------------------------------------------------- font 3x5
FONT = {
    ' ': ["...", "...", "...", "...", "..."],
    '0': ["###", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", "###"],
    '2': ["###", "..#", "###", "#..", "###"], '3': ["###", "..#", ".##", "..#", "###"],
    '4': ["#.#", "#.#", "###", "..#", "..#"], '5': ["###", "#..", "###", "..#", "###"],
    '6': ["###", "#..", "###", "#.#", "###"], '7': ["###", "..#", ".#.", ".#.", ".#."],
    '8': ["###", "#.#", "###", "#.#", "###"], '9': ["###", "#.#", "###", "..#", "###"],
    'A': [".#.", "#.#", "###", "#.#", "#.#"], 'B': ["##.", "#.#", "##.", "#.#", "##."],
    'C': [".##", "#..", "#..", "#..", ".##"], 'D': ["##.", "#.#", "#.#", "#.#", "##."],
    'E': ["###", "#..", "##.", "#..", "###"], 'F': ["###", "#..", "##.", "#..", "#.."],
    'G': [".##", "#..", "#.#", "#.#", ".##"], 'H': ["#.#", "#.#", "###", "#.#", "#.#"],
    'I': ["###", ".#.", ".#.", ".#.", "###"], 'J': ["..#", "..#", "..#", "#.#", ".#."],
    'K': ["#.#", "#.#", "##.", "#.#", "#.#"], 'L': ["#..", "#..", "#..", "#..", "###"],
    'M': ["#.#", "###", "###", "#.#", "#.#"], 'N': ["##.", "#.#", "#.#", "#.#", "#.#"],
    'O': [".#.", "#.#", "#.#", "#.#", ".#."], 'P': ["##.", "#.#", "##.", "#..", "#.."],
    'Q': [".#.", "#.#", "#.#", "##.", ".##"], 'R': ["##.", "#.#", "##.", "#.#", "#.#"],
    'S': [".##", "#..", ".#.", "..#", "##."], 'T': ["###", ".#.", ".#.", ".#.", ".#."],
    'U': ["#.#", "#.#", "#.#", "#.#", "###"], 'V': ["#.#", "#.#", "#.#", "#.#", ".#."],
    'W': ["#.#", "#.#", "###", "###", "#.#"], 'X': ["#.#", "#.#", ".#.", "#.#", "#.#"],
    'Y': ["#.#", "#.#", ".#.", ".#.", ".#."], 'Z': ["###", "..#", ".#.", "#..", "###"],
    '.': ["...", "...", "...", "...", ".#."], ',': ["...", "...", "...", ".#.", "#.."],
    ':': ["...", ".#.", "...", ".#.", "..."], '-': ["...", "...", "###", "...", "..."],
    '!': [".#.", ".#.", ".#.", "...", ".#."], '?': ["##.", "..#", ".#.", "...", ".#."],
    "'": [".#.", ".#.", "...", "...", "..."], '/': ["..#", "..#", ".#.", "#..", "#.."],
    '+': ["...", ".#.", "###", ".#.", "..."], '(': [".#.", "#..", "#..", "#..", ".#."],
    ')': [".#.", "..#", "..#", "..#", ".#."], '=': ["...", "###", "...", "###", "..."],
    '%': ["#.#", "..#", ".#.", "#..", "#.#"], '*': ["#.#", ".#.", "###", ".#.", "#.#"],
    '>': ["#..", ".#.", "..#", ".#.", "#.."], '<': ["..#", ".#.", "#..", ".#.", "..#"],
    '#': ["#.#", "###", "#.#", "###", "#.#"], '_': ["...", "...", "...", "...", "###"],
    '"': ["#.#", "#.#", "...", "...", "..."],
    # 64-ff: specials
    '@': ["###", "###", "###", "###", "###"],     # solid block (bars)
}
FONT_FIRST = 32
FONT_LAST = 95


def font_bytes():
    """64 glyphs (ASCII 32-95) x 5 rows, each row a 3-bit pattern in bits 2-0 (bit 2 = left)"""
    out = bytearray()
    for code in range(FONT_FIRST, FONT_LAST + 1):
        ch = chr(code)
        g = FONT.get(ch, FONT['?'] if ch not in FONT else FONT[ch])
        for r in g:
            v = 0
            for k in range(3):
                v = (v << 1) | (1 if r[k] == '#' else 0)
            out.append(v)
    return bytes(out)


def glyph_rows(ch):
    return FONT.get(ch, FONT['?'])


# ---------------------------------------------------------------- droids
# 13 x 8: a dome over a number band; '.' transparent (green is never used)
DROID_TPL = [
    "....bbbbb....",
    "..bbLLLLLbb..",
    "bLLLLLLLLLLLb",
    "bLLLLLLLLLLLb",
    "bLLLLLLLLLLLb",
    "bLLLLLLLLLLLb",
    "bLLLLLLLLLLLb",
    "..bbbbbbbbb..",
]


# each class has its own head (rows 0-1) and running gear (row 7)
CLASS_SHAPE = {
    1: (("....bbbbb....", "..bbLLLLLbb.."), "..bbbbbbbbb.."),     # low dome, skirt
    2: (("......b......", "...bbLLLbb..."), ".bb.bbbbb.bb."),     # aerial, two wheels
    3: (("..bb.....bb..", ".bLLbbbbbLLb."), "bbb.......bbb"),     # twin lamps, heavy feet
    4: (("...bbbbbbb...", ".bLLLLLLLLLb."), "..b.b.b.b.b.."),     # broad dome, many legs
    5: (("....bLLLb....", "..bbLbbbLbb.."), ".bbbbbbbbbbb."),     # sensor eye, skid
    6: (("b..bbbbbbb..b", "bbbLLLLLLLbbb"), "bb..bbbbb..bb"),     # shoulder spikes
    7: ((".b..bbbbb..b.", ".bbbLLLLLbbb."), "bbbb.....bbbb"),     # antlers, tracks
    8: (("bb.bbbbbbb.bb", "bbbLLLLLLLbbb"), "b.bbbbbbbbb.b"),     # armoured cowl
    9: (("b.b.bbbbb.b.b", ".bbbLLLLLbbb."), "bbbbbbbbbbbbb"),     # crown, full tread
}

PROBE_TPL = [
    "b...bbbbb...b",
    ".bbbLLLLLbbb.",
    ".bLLLbbbLLLb.",
    "bLLLbEEEbLLLb",
    "bLLLbEEEbLLLb",
    ".bLLLbbbLLLb.",
    ".bbbLLLLLbbb.",
    "b...bbbbb...b",
]


def droid_image(num, band, digit, dome_light=None):
    """3-digit droid: band colour, digit colour -> 13x8 colour rows (-1 transparent)"""
    if num == 0:      # the link probe: a ringed eye with four feelers
        return [[-1 if ch == '.' else band if ch == 'L' else 3 if ch == 'E' else C[ch] for ch in ln]
                for ln in PROBE_TPL]
    rows = []
    top, base = CLASS_SHAPE[num // 100]
    tpl = [top[0], top[1]] + DROID_TPL[2:7] + [base]
    for y, ln in enumerate(tpl):
        r = []
        for ch in ln:
            if ch == '.': r.append(-1)
            elif ch == 'L': r.append(band)
            else: r.append(C[ch])
        rows.append(r)
    s = '%03d' % num
    for k, d in enumerate(s):
        g = FONT[d]
        for gy in range(5):
            for gx in range(3):
                if g[gy][gx] == '#':
                    rows[2 + gy][1 + k * 4 + gx] = digit
    if dome_light is not None:
        rows[1][6] = dome_light
    return rows


def sprite_phase0(rows, w_bytes=4):
    """colour rows (-1 transparent) -> (data bytes, mask bytes), phase 0, 4 bytes a row"""
    data = bytearray(); mask = bytearray()
    for r in rows:
        r = r + [-1] * (w_bytes * 4 - len(r))
        data += pack_row([0 if c < 0 else c for c in r])
        mask += pack_row([3 if c < 0 else 0 for c in r])
    return bytes(data), bytes(mask)


def preshift(rows, h, w_bytes=4):
    """4 phases x (h rows x w_bytes data, then h rows x w_bytes mask)"""
    out = bytearray()
    for p in range(4):
        sh = [[-1] * p + r for r in rows]
        sh = [r[:w_bytes * 4] + [-1] * (w_bytes * 4 - len(r[:w_bytes * 4])) for r in sh]
        d, m = sprite_phase0(sh, w_bytes)
        out += d + m
    return bytes(out)


# explosion: 4 frames 13x8, red/yellow fire with blue smoke
EXPL = [
    [".............", ".............", ".....yyy.....", "....yrryy....", "....yrrry....", ".....yyy.....", ".............", "............."],
    [".............", "...y..y..y...", "....yyryy....", "..yyrrrrryy..", "..yrrryrrry..", "....yyryy....", "...y..y..y...", "............."],
    ["..y...r...y..", "....rr.rr....", ".r.rrbbbrr.r.", "..rbbyyybbr..", "..rbbyyybbr..", ".r.rrbbbrr.r.", "....rr.rr....", "..y...r...y.."],
    ["..b.......b..", ".....b.b.....", "..b.b...b.b..", "....b...b....", "...b.....b...", "..b.b...b.b..", ".....b.b.....", "..b.......b.."],
]


def expl_frames():
    out = bytearray()
    for f in EXPL:
        rows = [[-1 if ch == '.' else C[ch] for ch in ln] for ln in f]
        out += preshift(rows, 8)
    return bytes(out)


def preview_tiles(path):
    rows = []
    for ty in range(8):
        for sr in range(6):
            r = []
            for tx in range(8):
                r += tiles[ty * 8 + tx][sr] + [0]
            rows.append(r)
        rows.append([0] * 72)
    pix_image(rows, sx=4, sy=6).save(path)
