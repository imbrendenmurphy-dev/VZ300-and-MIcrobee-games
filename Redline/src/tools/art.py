"""REDLINE pixel art.  Colour letters: G=0 Y=1 B=2 R=3 ('.' transparent).
In colour set 1 the same indices show buff / cyan / magenta / orange.
Scenery sprites may not use B (index 2 is their transparent colour)."""
import math
from PIL import Image

def grid(rows):
    return [list(r) for r in rows]

def mirror(half):           # left half rows -> full symmetric rows
    out = []
    for r in half:
        out.append(list(r + r[::-1]))
    return out

CV = {'G': 0, 'Y': 1, 'B': 2, 'R': 3}

# ------------------------------------------------------------------ player car (32 x 14)
CAR_HALF = [
    ".........RRRRRRR",
    "........RYBBBBBB",
    ".......RBBBBBBBB",
    "......RRRRRRRRRR",
    ".YYYYYYYYYYYYYYY",
    ".RRRRRRRRRRRRRRR",
    "RRYYYYRRRRRRRRRR",
    "RRYYYYRRRRRGGGGG",
    "RRRRRRRRRRRGGGGG",
    "RRRRRRRRRRRRRRRR",
    "RRRRRRRRRRRRRRRR",
    "RRRRRBBBBBBBBBBB",
    "RYRYR...........",
    ".RRR............",
]
def player_base():
    return mirror(CAR_HALF)

def shear(img, amount, rows_affected):
    """shift the upper rows sideways: amount px at the top, fading to 0"""
    h = len(img); w = len(img[0])
    out = [list('.' * w) for _ in range(h)]
    for y in range(h):
        k = 0
        if y < rows_affected:
            k = int(round(amount * (rows_affected - y) / rows_affected))
        for x in range(w):
            sx = x - k
            if 0 <= sx < w: out[y][x] = img[y][sx]
    return out

def wheel_phase(img, ph):
    out = [r[:] for r in img]
    for y in range(10, 14):
        for x in range(len(out[0])):
            if out[y][x] == 'B' and ((y + x // 2 + ph) % 2 == 0) and y > 10:
                out[y][x] = 'R' if (x < 3 or x > 28) and y == 12 else 'B'
    # tread streaks: alternate a yellow-ish glint on the tyre tops
    if ph:
        for x in (1, 3, 28, 30):
            if out[11][x] == 'B': out[11][x] = 'G'
    else:
        for x in (2, 4, 27, 29):
            if out[12][x] == 'B': out[12][x] = 'G'
    return out

CAR_SIDE = [
    "..........RRRRRRRRRR............",
    ".........RBBBBBRBBBBR...........",
    "........RBBBBBBRBBBBBR..........",
    "..RRRRRRRRRRRRRRRRRRRRRRRRRR....",
    ".RYRRRRRRRRRRRRRRRRRRRRRRRRRRRY.",
    "RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR",
    "RRRRRBBBRRRRRRRRRRRRRRRRBBBRRRRR",
    "RRRRBBBBBRRRRRRRRRRRRRRBBBBBRRR.",
    "....BBGBB..............BBGBB....",
    ".....BBB................BBB.....",
]
CAR_FRONT_HALF = [
    "................",
    ".........RRRRRRR",
    "........RBBBBBBB",
    ".......RBBBBBBBB",
    "......RRRRRRRRRR",
    ".RRRRRRRRRRRRRRR",
    "RYYYRRRRRRRRRRRR",
    "RYYYRRRBBBBBBBBB",
    "RRRRRRRBBBBBBBBB",
    "RRRRRRRRRRRRRRRR",
    "BBBBB.........BB",
    "BBBBB...........",
    ".BBB............",
]

def pad(img, w, h):
    out = [list('.' * w) for _ in range(h)]
    oy = h - len(img); ox = (w - len(img[0])) // 2
    for y, r in enumerate(img):
        for x, c in enumerate(r):
            if 0 <= x + ox < w: out[y + oy][x + ox] = c
    return out

def player_frames():
    base = player_base()
    frames = []
    for ang in (-2, -1, 0, 1, 2):
        s = shear(base, ang * 1.5, 10) if ang else base
        if abs(ang) == 2: s = shear(s, ang * 0.5, 14)
        for ph in (0, 1):
            frames.append(wheel_phase(s, ph))
    # spin: rear, 3/4, side, 3/4 front, front, 3/4, side mirrored, 3/4
    side = pad(grid(CAR_SIDE), 32, 14)
    sidem = [r[::-1] for r in side]
    front = pad(mirror(CAR_FRONT_HALF), 32, 14)
    q1 = shear(base, 4, 14); q2 = shear(front, -4, 14)
    q3 = shear(front, 4, 14); q4 = shear(base, -4, 14)
    frames += [base, q1, side, q2, front, q3, sidem, q4]       # 10..17
    return frames

def brake_overlay():
    img = [list('.' * 32) for _ in range(14)]
    for y in (5, 6, 7, 8):
        for x in (1, 2, 3, 4, 5, 6, 25, 26, 27, 28, 29, 30):
            if y in (6, 7) or x in (2, 3, 4, 5, 26, 27, 28, 29):
                img[y][x] = 'Y'
    for y in (6, 7):
        for x in (3, 4, 27, 28):
            img[y][x] = 'R'
    return img

def dust_overlays():
    out = []
    pats = [
        ["....", "....", ".GG.", "GGYG", ".GG."],
        ["....", ".GG.", "GYGG", "GGYG", ".GG."],
        [".G..", "GGG.", "GYGG", ".GGG", "..G."],
        ["....", "..G.", ".GGG", "GGYG", ".GG."],
    ]
    for k, p in enumerate(pats):
        img = [list('.' * 32) for _ in range(14)]
        for y, r in enumerate(p):
            for x, c in enumerate(r):
                if c != '.':
                    img[9 + y][x] = c
                    img[9 + y][31 - x - (k & 1)] = c
        out.append(img)
    return out

# ------------------------------------------------------------------ traffic cars (28 x 12)
TRAFFIC = [
    ("YELLOW SEDAN", [
        "........YYYYYY",
        ".......YBBBBBB",
        "......YBBBBBBB",
        "....YYYYYYYYYY",
        "..YYYYYYYYYYYY",
        ".YRRYYYYYYYYYY",
        ".YRRYYYYYGGGGG",
        ".YYYYYYYYGGGGG",
        ".YYYYYYYYYYYYY",
        ".BBBBYYYYYYYYY",
        ".BBBB.........",
        "..BB..........",
    ]),
    ("GREEN HATCH", [
        ".......GGGGGGG",
        "......GBBBBBBB",
        ".....GBBBBBBBB",
        "....GGGGGGGGGG",
        "...GGGGGGGGGGG",
        "..GRRGGGGGGGGG",
        "..GRRGGGGGYYYY",
        "..GGGGGGGGYYYY",
        "..GGGGGGGGGGGG",
        "..BBBBGGGGGGGG",
        "..BBBB........",
        "...BB.........",
    ]),
    ("RED VAN", [
        "..RRRRRRRRRRRR",
        "..RYYYYYYYYYYY",
        "..RYBBBBBBBBBB",
        "..RYBBBBBBBBBB",
        "..RYYYYYYYYYYY",
        "..RRRRRRRRRRRR",
        "..RYYRRRRRRRRR",
        "..RYYRRRRRGGGG",
        "..RRRRRRRRRRRR",
        "..BBBBRRRRRRRR",
        "..BBBB........",
        "...BB.........",
    ]),
]
def traffic_frames(k):
    base = mirror(TRAFFIC[k][1])
    f2 = [r[:] for r in base]
    # exhaust puff / tail light flicker for the second frame
    for x in (5, 6, 21, 22):
        if f2[11][x] == '.': f2[11][x] = 'Y' if k != 1 else 'G'
    return base, f2

# ------------------------------------------------------------------ scenery (no 'B')
SCEN = {}
SCEN['palm'] = (150, [
    "....GG......GG......",
    "...GYGG...GGYGG.....",
    "..GG..GGGGG...GGG...",
    ".G...GGYYGGG.....G..",
    "....GG.GRGGYG.......",
    "...G...GR..GGG......",
    "..G.....R....GG.....",
    "........RR.....G....",
    "........RR..........",
    ".........R..........",
    ".........RR.........",
    ".........RR.........",
    "..........R.........",
    "..........RR........",
    "..........RR........",
    "..........RR........",
    "..........RY........",
    "..........RR........",
    "..........YR........",
    "..........RR........",
    "..........RR........",
    ".........RRR........",
    "........RRRRR.......",
])
SCEN['gum'] = (170, [
    ".......GGGG.GGG.........",
    ".....GGGYGGGGYGGG.......",
    "...GGGYGGGGGGGGGYGG.....",
    "..GGYGGGGGYGGGGGGGGG....",
    ".GGGGGGGGGGGGGYGGGGGG...",
    "GGYGGG.GGGGGGGGGGGYGGG..",
    "GGGGG...GGYGGGG..GGGGG..",
    ".GGG.....GGRGG....GGG...",
    "..........YR.GGG........",
    "....GGG...YRGGYG........",
    "..GGYGGG..YR..G.........",
    ".GGGGGGGGYRR............",
    "...GG..GGYR.............",
    ".........YR.............",
    ".........YRR............",
    ".........YRR............",
    "..........YR............",
    "..........YR............",
    "..........YR............",
    ".........YYRR...........",
    "........YYRRRR..........",
])
SCEN['bush'] = (40, [
    "....GGGG........",
    "..GGYGGGGGG.....",
    ".GGGGGGGYGGGG...",
    "GGYGGGGGGGGGGG..",
    "GGGGGRGGGGYGGGG.",
    ".GGGGGGGGGGGGGG.",
    "..RRR.GGG.RRR...",
])
SCEN['rock'] = (60, [
    ".......RRRRR..........",
    ".....RRYYRRRRR........",
    "...RRYYYRRRRRRRR......",
    "..RRYYRRRRRRRRRRRR....",
    ".RRYRRRRRRRGRRRRRRRR..",
    "RRRRRRRRRRRRRRRRRRRRR.",
    "RRRRRRGRRRRRRRRRRRRRRR",
    "RRRRRRRRRRRRRRRGRRRRRR",
    ".GGRRRRRRRRRRRRRRRRRG.",
])
SCEN['chevl'] = (55, [
    "YYYYYYYYYYYY",
    "YYYYRRYYYRRY",
    "YYYRRYYYRRYY",
    "YYRRYYYRRYYY",
    "YYYRRYYYRRYY",
    "YYYYRRYYYRRY",
    "YYYYYYYYYYYY",
    "..R......R..",
    "..R......R..",
    "..R......R..",
    "..R......R..",
    "..R......R..",
])
SCEN['chevr'] = (55, [r[::-1] for r in SCEN['chevl'][1]])
SCEN['lighthouse'] = (230, [
    "....RRRR....",
    "...RYYYYR...",
    "...RYYYYR...",
    "..RRRRRRRR..",
    "...YYYYYY...",
    "...RRRRRR...",
    "...RRRRRR...",
    "...YYYYYY...",
    "...YYYYYY...",
    "..RRRRRRRR..",
    "..RRRRRRRR..",
    "..YYYYYYYY..",
    "..YYYYYYYY..",
    "..RRRRRRRR..",
    "..RRRRRRRR..",
    ".YYYYYYYYYY.",
    ".YYYYYYYYYY.",
    ".RRRRRRRRRR.",
    ".RRRRRRRRRR.",
    "YYYYYYYYYYYY",
    "GGGGGGGGGGGG",
])
SCEN['pine'] = (170, [   # snowy range (set 1: G=buff snow, Y=cyan, R=orange)
    ".......G........",
    "......GYG.......",
    ".....GYYYG......",
    "......YYY.......",
    "....GYYYYYG.....",
    "...GYYYYYYYG....",
    ".....YYYYY......",
    "...GYYYYYYYG....",
    "..GYYYYYYYYYG...",
    ".GYYYYYYYYYYYG..",
    "....YYYYYYY.....",
    "..GYYYYYYYYYG...",
    ".GYYYYYYYYYYYG..",
    "GYYYYYYYYYYYYYG.",
    "......RRR.......",
    "......RRR.......",
    ".....GGGGG......",
])
SCEN['snowrock'] = (70, [
    "......GGGGG.......",
    "....GGGGGGGGG.....",
    "..GGGRGGGGGRGGG...",
    ".GGRRRRGGGRRRRGG..",
    "GRRRRRRRRRRRRRRRG.",
    "RRRRRRRRRRRRRRRRRR",
    "RRRRYRRRRRRRRRYRRR",
])
SCEN['lamp'] = (200, [
    "RRRRRRRR....",
    "R......RR...",
    "........RR..",
    ".........RYY",
    ".........RYY",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    ".........R..",
    "........RRR.",
    "........RRR.",
])
SCEN['lampr'] = (200, [r[::-1] for r in SCEN['lamp'][1]])
SCEN['tower'] = (320, [
    "...RRRRRRRRRR...",
    "...RYRYRRYRYR...",
    "...RRRRRRRRRR...",
    "...RYRRYRRYRR...",
    "..RRRRRRRRRRRR..",
    "..RYRYRRYRYRYR..",
    "..RRRRRRRRRRRR..",
    "..RYRRYRYRRYRR..",
    "..RRRRRRRRRRRR..",
    ".RRRRRRRRRRRRRR.",
    ".RYRYRYRRYRYRYR.",
    ".RRRRRRRRRRRRRR.",
    ".RYRRYRYRYRRYRR.",
    ".RRRRRRRRRRRRRR.",
    "RRRRRRRRRRRRRRRR",
    "RYRYRYRYRYRYRYRR",
    "RRRRRRRRRRRRRRRR",
    "RYRRYRYRRYRYRYRR",
    "RRRRRRRRRRRRRRRR",
    "RRRRRYYYYYYRRRRR",
    "RRRRRYYYYYYRRRRR",
])
def _sign(txt):
    import font as fnt
    w = len(txt) * 4 + 3
    rows = [['R'] * w] + [['R'] + ['Y'] * (w - 2) + ['R'] for _ in range(7)] + [['R'] * w]
    for k, ch in enumerate(txt):
        g = fnt.F.get(ch, "... ... ... ... ...").split()
        for y, r in enumerate(g):
            for x, c in enumerate(r):
                if c == '#': rows[2 + y][2 + k * 4 + x] = 'R'
    post = ['.'] * w
    post[3] = post[4] = 'R'; post[w - 5] = post[w - 4] = 'R'
    rows += [post[:] for _ in range(5)]
    return [''.join(r) for r in rows]
SCEN['sign'] = (120, _sign("REDLINE"))
SCEN['grass'] = (25, [
    "..G...G..G..",
    ".GYG.GG.GYG.",
    "GGGGGYGGGGGG",
])
SCEN['cactus'] = (90, [
    "....GG....",
    "...GGGG...",
    "...GGGG...",
    "G..GGGG...",
    "GG.GGGG..G",
    "GG.GGGG.GG",
    "GGGGGGG.GG",
    ".GGGGGGGGG",
    "...GGGGGG.",
    "...GGGG...",
    "...GGGG...",
    "..RGGGGR..",
])

def to_img(rows):
    h = len(rows); w = max(len(r) for r in rows)
    im = Image.new('P', (w, h), 4)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            im.putpixel((x, y), CV.get(c, 4))
    return im

def scale_rows(rows, f):
    im = to_img(rows)
    w = max(1, int(round(im.width * f))); h = max(1, int(round(im.height * f)))
    if (w, h) == im.size: s = im
    else: s = im.resize((w, h), Image.NEAREST)
    inv = {0: 'G', 1: 'Y', 2: 'B', 3: 'R', 4: '.'}
    return [''.join(inv[s.getpixel((x, y))] for x in range(w)) for y in range(h)]
