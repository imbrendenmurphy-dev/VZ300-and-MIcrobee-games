# Dawn Patrol 2 - all original pixel art, generated/declared here.
# Colour codes: 0..3 = VDG colour index (CSS0: G Y B R ; CSS1: buff cyan magenta orange), None = transparent
import random, math

CMAP = {'G': 0, 'Y': 1, 'B': 2, 'R': 3, '.': None, ' ': None,
        '0': 0, '1': 1, '2': 2, '3': 3}


def grid(txt):
    rows = [r for r in txt.strip('\n').split('\n')]
    rows = [r.rstrip() for r in rows]
    w = max(len(r) for r in rows)
    return [[CMAP[c] for c in r.ljust(w, '.')] for r in rows]


def mirror(g):
    return [list(reversed(r)) for r in g]


def remap(g, m):
    return [[(m.get(c, c) if c is not None else None) for c in r] for r in g]


# ---------------------------------------------------------------- sprites
HELI_L = grid("""
.....RRR........
...GGYYYY.....R.
..GGGYYYYYYYYYRR
.YYYYYYYYY....R.
..YYYYYYY.......
...R...R........
.RRRRRRRRR......
""")

def tilt(g, amount):
    # amount > 0: nose (left) dips; amount < 0: tail dips (nose-up flare)
    h = len(g); w = len(g[0])
    extra = int(abs(amount) + 0.99)
    out = [[None] * w for _ in range(h + extra)]
    for x in range(w):
        if amount >= 0:
            d = int(round(amount * (w - 1 - x) / (w - 1)))
        else:
            d = int(round(-amount * x / (w - 1)))
        for y in range(h):
            if g[y][x] is not None:
                out[y + d][x] = g[y][x]
    while out and all(c is None for c in out[-1]):
        out.pop()
    return out

# hand-drawn poses, nose to the left: flare (nose up), level, cruise, dive
HELI_LS = [grid("""
....RRR.........
..GGYYYY........
.GGGYYYYYY......
.YYYYYYYYYYY..R.
..YYYYYYYY..YYRR
...R....R.....R.
..RRRRRR........
.......RRRR.....
"""), HELI_L, grid("""
..............R.
.....RRR....YYRR
...GGYYYYYYY..R.
..GGGYYYYYY.....
.YYYYYYYYY......
..YYYYYYY.......
....R...RRRRR...
.RRRRRRR........
"""), grid("""
...............R
............YYRR
......RRR.YYY.R.
....GGYYYYYY....
...GGGYYYYY.....
..YYYYYYYYY.....
.YYYYYYYY.......
...R...RRRR.....
.RRRRRR.........
""")]

# three-quarter view (turning)
HELI_LQ = grid("""
.....RRRR.....
...GGGGYYY..R.
..GGGGGGYYYYRR
.YYYYYYYYYY.R.
..YYYYYYYYY...
...R....R.....
.RRRRR.RRRRR..
""")

HELI_F = grid("""
....RRRR....
..YYGGGGYY..
.YYGGGGGGYY.
.YYYYYYYYYY.
..YYYYYYYY..
...R....R...
.RRRR..RRRR.
""")

GUNSHIP_L = grid("""
....RRRR....
.BBRRRRRRRRR
RRRRRRR..RRB
.RRRRRR.....
.B...B......
BBBBBBB.....
""")

PRIS = {
 'stand': grid(".Y.\nRRR\n.R.\n.B.\nB.B"),
 'run1':  grid(".Y.\n.RR\nRR.\n.B.\nB.B"),
 'run2':  grid(".Y.\nRR.\n.RR\n.B.\n.B."),
 'run3':  grid(".Y.\n.R.\n.RR\nBB.\n..B"),
 'wave1': grid("RYR\n.R.\n.R.\n.B.\nB.B"),
 'wave2': grid(".YR\nRR.\n.R.\n.B.\nB.B"),
 'dead':  grid("...\n...\n...\n...\nRRY"),
}

TANK_L1 = grid("""
.....RRRR...
RRRRRRRRRR..
..RRRRRRRRR.
.BBBBBBBBBB.
B.Y.Y.Y.Y.B.
.BBBBBBBBBB.
""")
TANK_L2 = grid("""
.....RRRR...
RRRRRRRRRR..
..RRRRRRRRR.
.BBBBBBBBBB.
BY.Y.Y.Y.YB.
.BBBBBBBBBB.
""")

JET_L = grid("""
...........RR...
..........RRR...
RRRRRRRRRRRRRRRR
.YYRRRRRRRRRRRR.
.....RRRRR......
""")

TRANSPORT_L = grid("""
............GG..
...........GGG..
.GGGGGGGGGGGGGGG
GYGYGYGYGGGGGGG.
.GGGGGGGGGGGG...
......GGGG......
""")

# planes seen head-on (coming towards / going away) - homage to the original
PLANE_S = grid("""
...G...
GGGYGGG
...G...
""")
PLANE_M = grid("""
.....G.....
.....G.....
GGGGGYGGGGG
....GGG....
""")
PLANE_L = grid("""
.......G.......
.......G.......
GGGGGGGYGGGGGGG
.G...GGGGG...G.
......G.G......
""")

EXPLO = [grid("""
........
...YY...
..YRRY..
..YRRY..
...YY...
........
"""), grid("""
.Y....Y.
..YRRY..
.YRYYRY.
.YRYYRY.
..YRRY..
.Y....Y.
"""), grid("""
R..R..R.
.R.YY.R.
..YRRY..
RYR..RYR
..YRRY..
.R.YY.R.
"""), grid("""
R......R
...RR...
.R....R.
.R....R.
...RR...
R......R
""")]

AAGUN = grid("""
.....RR.
....RR..
..RRR...
.RRRRRR.
BBBBBBBB
""")
AAWRECK = grid("""
........
........
...R.R..
.RBRRBR.
BBBBBBBB
""")
SAM = grid("""
..YYYY..
.RRRRRR.
..R..R..
.RRRRRR.
BBBBBBBB
""")
MISSILE_L = grid("""
.R...
YRRRR
.R...
""")
BALLOON = grid("""
.RRR.
RRYRR
RRRRR
.RRR.
..Y..
..Y..
.BBB.
""")
CRATE = grid("""
.YYYYY.
YYYYYYY
Y..Y..Y
.Y.Y.Y.
..YYY..
..RRR..
..RRR..
""")
BOAT_L = grid("""
......RR........
.....RRRR.......
RRRRRRRRRRRRRRR.
.BBBBBBBBBBBBB..
""")
FLAK = grid("""
.R.R.
R.Y.R
.YRY.
R.Y.R
.R.R.
""")
ARROW_L = grid("""
.R.
RRR
.R.
""")

SPRITES = []   # (name, grid)
def add(name, g):
    SPRITES.append((name, g))

# helicopter frames must stay first and consecutive (recolouring walks them)
for i, g in enumerate(HELI_LS):
    add('HELI_L%d' % i, g)
for i, g in enumerate(HELI_LS):
    add('HELI_R%d' % i, mirror(g))
add('HELI_LQ', HELI_LQ)
add('HELI_F', HELI_F)
add('HELI_RQ', mirror(HELI_LQ))
HELI_FRAMES = ['HELI_L0', 'HELI_L1', 'HELI_L2', 'HELI_L3', 'HELI_R0', 'HELI_R1', 'HELI_R2', 'HELI_R3',
               'HELI_LQ', 'HELI_F', 'HELI_RQ']
add('GUN_L', GUNSHIP_L); add('GUN_R', mirror(GUNSHIP_L))
for k in ('wave1', 'wave2', 'dead'):
    add('P_' + k.upper(), PRIS[k])
for k in ('run1', 'run2', 'run3'):
    add('P_R' + k[-1], PRIS[k]); add('P_L' + k[-1], mirror(PRIS[k]))
add('TANK_L1', TANK_L1); add('TANK_L2', TANK_L2)
add('TANK_R1', mirror(TANK_L1)); add('TANK_R2', mirror(TANK_L2))
add('JET_L', JET_L); add('JET_R', mirror(JET_L))
add('TRN_L', TRANSPORT_L); add('TRN_R', mirror(TRANSPORT_L))
add('PLANE_S', PLANE_S); add('PLANE_M', PLANE_M); add('PLANE_L', PLANE_L)
for i, e in enumerate(EXPLO):
    add('EXP%d' % i, e)
add('AAGUN', AAGUN); add('AAWRECK', AAWRECK); add('SAM', SAM)
add('MIS_L', MISSILE_L); add('MIS_R', mirror(MISSILE_L))
add('BALLOON', BALLOON); add('CRATE', CRATE)
add('FLAK', FLAK)
add('ARROW_L', ARROW_L)


# ---------------------------------------------------------------- font 3x5
FONT_SRC = {
' ': "...|...|...|...|...",
'0': "###|#.#|#.#|#.#|###", '1': ".#.|##.|.#.|.#.|###", '2': "##.|..#|.#.|#..|###",
'3': "##.|..#|.#.|..#|##.", '4': "#.#|#.#|###|..#|..#", '5': "###|#..|##.|..#|##.",
'6': ".##|#..|###|#.#|###", '7': "###|..#|.#.|.#.|.#.", '8': "###|#.#|###|#.#|###",
'9': "###|#.#|###|..#|##.",
'A': ".#.|#.#|###|#.#|#.#", 'B': "##.|#.#|##.|#.#|##.", 'C': ".##|#..|#..|#..|.##",
'D': "##.|#.#|#.#|#.#|##.", 'E': "###|#..|##.|#..|###", 'F': "###|#..|##.|#..|#..",
'G': ".##|#..|#.#|#.#|.##", 'H': "#.#|#.#|###|#.#|#.#", 'I': "###|.#.|.#.|.#.|###",
'J': "..#|..#|..#|#.#|.#.", 'K': "#.#|#.#|##.|#.#|#.#", 'L': "#..|#..|#..|#..|###",
'M': "#.#|###|###|#.#|#.#", 'N': "##.|#.#|#.#|#.#|#.#", 'O': ".#.|#.#|#.#|#.#|.#.",
'P': "##.|#.#|##.|#..|#..", 'Q': ".#.|#.#|#.#|##.|.##", 'R': "##.|#.#|##.|#.#|#.#",
'S': ".##|#..|.#.|..#|##.", 'T': "###|.#.|.#.|.#.|.#.", 'U': "#.#|#.#|#.#|#.#|###",
'V': "#.#|#.#|#.#|#.#|.#.", 'W': "#.#|#.#|###|###|#.#", 'X': "#.#|#.#|.#.|#.#|#.#",
'Y': "#.#|#.#|.#.|.#.|.#.", 'Z': "###|..#|.#.|#..|###",
'.': "...|...|...|...|.#.", ',': "...|...|...|.#.|#..", ':': "...|.#.|...|.#.|...",
'-': "...|...|###|...|...", '!': ".#.|.#.|.#.|...|.#.", '?': "##.|..#|.#.|...|.#.",
"'": ".#.|.#.|...|...|...", '/': "..#|..#|.#.|#..|#..", '+': "...|.#.|###|.#.|...",
'(': ".#.|#..|#..|#..|.#.", ')': ".#.|..#|..#|..#|.#.", '=': "...|###|...|###|...",
'*': "#.#|.#.|###|.#.|#.#", '#': "###|###|###|###|###",
'<': "..#|.#.|#..|.#.|..#", '>': "#..|.#.|..#|.#.|#..", '_': "...|...|...|...|###",
'@': ".#.|###|.#.|#.#|#.#",   # little man icon
'^': "###|.#.|###|###|#.#",   # heli icon
'%': ".#.|###|#.#|###|###",   # fuel can icon
'&': "###|###|###|###|.#.",   # armour/shield icon
}
FONT_CHARS = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"


def font_bytes():
    out = []
    for ch in FONT_CHARS:
        src = FONT_SRC.get(ch, "...|...|...|...|...")
        rows = src.split('|')
        nib = []
        for r in rows:
            v = 0
            for i, c in enumerate(r):
                if c == '#':
                    v |= 8 >> i
            nib.append(v)
        # pack 5 nibbles into 3 bytes: n0<<4|n1, n2<<4|n3, n4<<4
        out += [(nib[0] << 4) | nib[1], (nib[2] << 4) | nib[3], nib[4] << 4]
    return out


# ---------------------------------------------------------------- scenery helpers
def canvas(w, h, c=None):
    return [[c] * w for _ in range(h)]


def blit(dst, g, x, y, wrap=False):
    W = len(dst[0]); H = len(dst)
    for j, row in enumerate(g):
        for i, c in enumerate(row):
            if c is None:
                continue
            xx = x + i
            if wrap:
                xx %= W
            if 0 <= xx < W and 0 <= y + j < H:
                dst[y + j][xx] = c


def smooth_noise(n, period, rnd, octaves=((32, 1.0), (16, 0.5), (8, 0.25), (4, 0.12))):
    # periodic 1-D value noise
    vals = [0.0] * period
    for (wl, amp) in octaves:
        pts = [rnd.random() for _ in range(max(1, period // wl))]
        m = len(pts)
        for x in range(period):
            f = x / wl
            i = int(f) % m; j = (i + 1) % m
            t = f - int(f); t = t * t * (3 - 2 * t)
            vals[x] += amp * (pts[i] * (1 - t) + pts[j] * t)
    lo = min(vals); hi = max(vals)
    return [(v - lo) / (hi - lo + 1e-9) for v in vals]


def dither(x, y, a, b, pattern='check'):
    if pattern == 'check':
        return a if (x + y) & 1 else b
    if pattern == 'sparse':
        return b if (x % 4 == 0 and y % 2 == 0) or (x % 4 == 2 and y % 2 == 1) else a
    return a


# ---------------------------------------------------------------- decor (world band pieces)
DECOR = {}
DECOR['palm'] = grid("""
..YY.YY.....
.YYGYYGYY...
YG..YRGY.GY.
Y...RG..Y..Y
....R.......
....R.......
.....R......
.....R......
.....R......
....RRR.....
""")
DECOR['bush'] = grid("""
..GYG...
.GGGGGY.
GGYGGGGG
""")
DECOR['hut'] = grid("""
....RRRRRRRR....
...RRRRRRRRRR...
..RRRRRRRRRRRR..
.RRRRRRRRRRRRRR.
...YYYYYYYYYY...
...YBYYBBYYBY...
...YYYYBBYYYY...
...YYYYBBYYYY...
""")
DECOR['hut_locked'] = grid("""
....RRRRRRRR....
...RRRRRRRRRR...
..RRRRRRRRRRRR..
.RRRRRRRRRRRRRR.
...YYYYYYYYYY...
...YBYYRRYYBY...
...YYYYRRYYYY...
...YYYYRRYYYY...
""")
DECOR['fence'] = grid("""
R...
RYYY
R...
RYYY
""")
DECOR['tower'] = grid("""
RRRRRR
RYYYYR
RRRRRR
.R..R.
.RR.R.
.R.RR.
.R..R.
.RR.R.
.R.RR.
.R..R.
RR..RR
""")
DECOR['hangar'] = grid("""
......RRRRRRRRRRRR......
....RRRRRRRRRRRRRRRR....
..RRRRRRRRRRRRRRRRRRRR..
.YYYYYYYYYYYYYYYYYYYYYY.
.YBBBBBBBBBBBBBBBBBBBBY.
.YBBBBBBBBBBBBBBBBBBBBY.
.YBBBBBBBBBBBBBBBBBBBBY.
.YBBBBBBBBBBBBBBBBBBBBY.
""")
DECOR['ctower'] = grid("""
.BBBBBB.
.YYYYYY.
..YYYY..
..YRRY..
..YYYY..
..YRRY..
..YYYY..
..YYYY..
..YRRY..
..YYYY..
""")
DECOR['pad'] = grid("""
RRRRRRRRRRRRRRRRRRRR
YYRYYRYYYYYYRYYRYYYY
""")
DECOR['flagpole'] = grid("""
Y...
YRRR
YRRR
Y...
Y...
Y...
Y...
Y...
Y...
Y...
""")
DECOR['cactus'] = grid("""
..G..
G.G..
G.G.G
GGGGG
..G..
..G..
..G..
""")
DECOR['rock'] = grid("""
...RRR..
..RRYRR.
.RRRRRRR
RRRRRRRR
""")
DECOR['ruin'] = grid("""
.R..........R...
.R.......RR.R...
RRR..R...RRRR...
RYR..RR..RYRR..R
RRRRRRR..RRRRR.R
RYRRYRRRRRRYRRRR
""")
DECOR['drums'] = grid("""
RR.RR.RR
RY.RY.RY
RR.RR.RR
""")
DECOR['bunker'] = grid("""
...YYYYYY...
..YYYYYYYY..
.YYBBBBBBYY.
YYYYYYYYYYYY
""")
DECOR['pine'] = grid("""
...BB...
...BB...
..BBBB..
..BBBB..
.BBBBBB.
..BBBB..
.BBBBBB.
BBBBBBBB
...RR...
...RR...
""")
DECOR['pine_snow'] = grid("""
...00...
...BB...
..0BB0..
..BBBB..
.00BB00.
..BBBB..
.0BBBB0.
BBBBBBBB
...RR...
...RR...
""")
DECOR['cabin'] = grid("""
....00000000....
...0000000000...
..000000000000..
.00000000000000.
...RRRRRRRRRR...
...RRRBBRRBRR...
...RRRBBRRRRR...
...RRRBBRRRRR...
""")
DECOR['dish'] = grid("""
.RR.....
R..R....
R...R...
.R..R...
..RRR...
...R....
...R....
..RRR...
""")
DECOR['factory'] = grid("""
.RR.........
.RR.........
.RR..R..R..R
.RR.RR.RR.RR
RRRRRRRRRRRR
RYRRYRRYRRYR
RRRRRRRRRRRR
RYRRYRRYRRYR
RRRRRRRRRRRR
""")
DECOR['tank_fuel'] = grid("""
..YYYYYYYY..
.YYYYYYYYYY.
YYYRYYYYRYYY
YYYYYYYYYYYY
.YYYYYYYYYY.
.R..R..R..R.
""")
DECOR['lamp'] = grid("""
YYY.
.R..
.R..
.R..
.R..
.R..
.R..
.R..
RRR.
""")
DECOR['crane'] = grid("""
RRRRRRRRRRRR
.R..R.....Y.
..RR......Y.
..RR......Y.
..RR......YY
..RR........
..RR........
..RR........
..RR........
.RRRR.......
""")
DECOR['wreck'] = grid("""
.....R..
..RR.RR.
.RRRRRR.
RRBRRBRR
""")


def find_decor_width(name):
    return len(DECOR[name][0])


# ---------------------------------------------------------------- themes / levels
# band sizes: clouds 10 rows x 256px, mount 10 x 128px, hills 6 x 256px,
# world 12 x 768px, ground 3 x 64px, fg 3 x 128px
CLOUD_W, MOUNT_W, HILL_W, WORLD_W, GROUND_W, FG_W = 256, 128, 256, 768, 64, 128
CLOUD_H, MOUNT_H, HILL_H, WORLD_H, GROUND_H, FG_H = 10, 10, 6, 12, 3, 3

CAMP_X = [72, 232, 392, 544]   # camp 1 (far) .. camp 4 (near)
BASE_X = 664                   # base region start


def make_clouds(sky, light, shade, seed, density=1.0, edge=None):
    rnd = random.Random(seed)
    c = canvas(CLOUD_W, CLOUD_H, sky)
    blobs = []
    n = int(7 * density)
    for i in range(n):
        cx = rnd.randrange(CLOUD_W); cy = rnd.uniform(3, 7)
        for k in range(rnd.randint(3, 5)):
            blobs.append((cx + rnd.uniform(-10, 10), cy + rnd.uniform(-1.5, 1.2),
                          rnd.uniform(5, 11), rnd.uniform(1.6, 2.8)))
    for y in range(CLOUD_H):
        for x in range(CLOUD_W):
            v = 0
            for (bx, by, rx, ry) in blobs:
                dx = min(abs(x - bx), CLOUD_W - abs(x - bx)) / rx
                dy = (y - by) / ry
                v = max(v, 1 - (dx * dx + dy * dy))
            if v > 0.25:
                below = 0
                for (bx, by, rx, ry) in blobs:
                    dx = min(abs(x - bx), CLOUD_W - abs(x - bx)) / rx
                    dy = (y + 1.6 - by) / ry
                    below = max(below, 1 - (dx * dx + dy * dy))
                col = light
                if below < 0.25:
                    col = shade
                elif v < 0.4:
                    col = dither(x, y, light, sky)
                c[y][x] = col
    return c


def make_mountains(sky, fill_a, fill_b, rim, seed, lo=1, hi=8, kind='peaks'):
    rnd = random.Random(seed)
    nz = smooth_noise(0, MOUNT_W, rnd, ((64, 1.0), (32, 0.6), (16, 0.3), (8, 0.15)))
    c = canvas(MOUNT_W, MOUNT_H, sky)
    for x in range(MOUNT_W):
        top = int(round(MOUNT_H - (lo + nz[x] * (hi - lo))))
        if kind == 'mesa':
            top = MOUNT_H - (hi if nz[x] > 0.55 else (lo + 2 if nz[x] > 0.3 else lo))
        for y in range(MOUNT_H):
            if y >= top:
                c[y][x] = dither(x, y, fill_a, fill_b)
        if 0 <= top < MOUNT_H and rim is not None:
            c[top][x] = rim
            if kind == 'snow' and top < 5 and top + 1 < MOUNT_H:
                c[top + 1][x] = rim
    return c


def make_city_skyline(sky, fill, win, seed):
    rnd = random.Random(seed)
    c = canvas(MOUNT_W, MOUNT_H, sky)
    x = 0
    while x < MOUNT_W:
        w = rnd.randint(5, 12); h = rnd.randint(3, 9)
        for xx in range(x, min(MOUNT_W, x + w)):
            for y in range(MOUNT_H - h, MOUNT_H):
                c[y][xx] = fill
        for y in range(MOUNT_H - h + 1, MOUNT_H - 1, 2):
            for xx in range(x + 1, min(MOUNT_W, x + w - 1), 2):
                if rnd.random() < 0.35:
                    c[y][xx] = win
        if rnd.random() < 0.3 and x + 2 < MOUNT_W:   # antenna
            for y in range(max(0, MOUNT_H - h - 2), MOUNT_H - h):
                c[y][x + 2] = fill
        x += w + rnd.randint(0, 2)
    for xx in range(MOUNT_W):
        c[MOUNT_H - 1][xx] = fill
    return c


def make_hills(bg, body, light, seed, kind='trees'):
    rnd = random.Random(seed)
    c = canvas(HILL_W, HILL_H, None)
    for y in range(HILL_H):
        for x in range(HILL_W):
            c[y][x] = dither(x, y, bg[0], bg[1]) if isinstance(bg, tuple) else bg
    nz = smooth_noise(0, HILL_W, rnd, ((64, 1.0), (16, 0.3)))
    for x in range(HILL_W):
        top = int(round(4 - nz[x] * 3))
        for y in range(top, HILL_H):
            c[y][x] = body
    if kind in ('trees', 'pines'):
        x = 0
        while x < HILL_W:
            r = rnd.randint(2, 4)
            top = int(round(4 - nz[x % HILL_W] * 3))
            cy = top
            for dy in range(-r, r + 1):
                for dx in range(-r - 1, r + 2):
                    if kind == 'trees':
                        inside = (dx * dx) / ((r + 1) ** 2) + (dy * dy) / (r * r) <= 1
                    else:
                        inside = dy >= -r and abs(dx) <= (dy + r) // 2
                    yy = cy + dy; xx = (x + dx) % HILL_W
                    if inside and 0 <= yy < HILL_H:
                        c[yy][xx] = body
                        if dy < -r // 2 and dx < 0 and light is not None:
                            c[yy][xx] = light
            x += rnd.randint(4, 8)
    elif kind == 'dunes':
        for x in range(HILL_W):
            top = int(round(4 - nz[x] * 3))
            slope = nz[(x + 1) % HILL_W] - nz[x]
            for y in range(top, HILL_H):
                if slope < 0 and y < top + 3:
                    c[y][x] = dither(x, y, light, body)
    elif kind == 'industry':
        x = 0
        while x < HILL_W:
            w = rnd.randint(6, 14); h = rnd.randint(2, 5)
            for xx in range(x, min(HILL_W, x + w)):
                for y in range(HILL_H - h, HILL_H):
                    c[y][xx] = body
            if rnd.random() < 0.5:
                cx = x + w // 2
                for y in range(0, HILL_H - h):
                    if cx < HILL_W:
                        c[y][cx] = body
            x += w + rnd.randint(1, 5)
    return c


def dither_band(c, col, other):
    # break up a solid colour with a checkerboard of another
    for y, row in enumerate(c):
        for x, v in enumerate(row):
            if v == col and (x + y) & 1:
                row[x] = other
    return c


def make_ground(top, a, b, speck, seed):
    rnd = random.Random(seed)
    c = canvas(GROUND_W, GROUND_H, a)
    for x in range(GROUND_W):
        c[0][x] = top if x % 3 else a
        for y in (1, 2):
            c[y][x] = dither(x, y, a, b) if (x // 4 + y) % 3 == 0 else a
    for i in range(6):
        c[rnd.randint(1, 2)][rnd.randrange(GROUND_W)] = speck
    return c


def make_fg(base, tuft, rock, seed):
    rnd = random.Random(seed)
    c = canvas(FG_W, FG_H, base)
    x = 0
    while x < FG_W:
        k = rnd.random()
        if k < 0.5:
            c[0][x] = tuft; c[1][x] = tuft; c[1][(x + 1) % FG_W] = tuft; c[0][(x + 2) % FG_W] = tuft
        else:
            for dx in range(3):
                c[1][(x + dx) % FG_W] = rock
            c[2][(x + 1) % FG_W] = rock
        x += rnd.randint(5, 12)
    return c


def make_world(theme, rnd):
    t = theme
    W = WORLD_W
    c = canvas(W, WORLD_H)
    for y in range(WORLD_H):
        for x in range(W):
            c[y][x] = t['world_bg'](x, y)
    # base
    bx = BASE_X
    blit(c, DECOR['hangar'], bx + 64, WORLD_H - 8 - 2)
    blit(c, DECOR['ctower'], bx + 4, WORLD_H - 10 - 2)
    blit(c, DECOR['flagpole'], bx + 16, WORLD_H - 10 - 2)
    blit(c, DECOR['pad'], bx + 28, WORLD_H - 2)
    # camps
    camps = t['camps']
    for i, cx in enumerate(CAMP_X):
        hut = 'hut_locked' if camps[i][1] else t.get('hut', 'hut')
        if t.get('hut') == 'cabin' and not camps[i][1]:
            hut = 'cabin'
        # fence posts from cx-28 .. cx+28
        for fx in range(cx - 28, cx + 32, 4):
            if cx - 10 <= fx < cx + 10:
                continue
            blit(c, DECOR['fence'], fx, WORLD_H - 4 - 2)
        blit(c, DECOR[hut], cx - 8, WORLD_H - 8 - 2)
        blit(c, DECOR['tower'], cx - 36, WORLD_H - 11 - 1)
    # scenery
    occupied = []
    for i, cx in enumerate(CAMP_X):
        occupied.append((cx - 40, cx + 34))
    occupied.append((BASE_X - 4, W))
    def free(x, w):
        for a, b in occupied:
            if x + w > a and x < b:
                return False
        return True
    x = 4
    deco = t['decor']
    while x < W - 16:
        name = rnd.choice(deco)
        g = DECOR[name]
        w = len(g[0]); h = len(g)
        x &= ~3
        if free(x, w):
            blit(c, g, x, WORLD_H - h - 2)
            x += w + rnd.randint(2, 14)
        else:
            x += 8
    # ground surface rows
    for x in range(W):
        for y in (WORLD_H - 2, WORLD_H - 1):
            if c[y][x] == t['world_bg'](x, y):
                c[y][x] = t['surface'](x, y)
    blit(c, DECOR['pad'], bx + 28, WORLD_H - 2)
    return c


def themes():
    T = []
    # 1 JUNGLE -----------------------------------------------------------
    T.append(dict(
        name='JUNGLE', op='OPERATION SUNRISE', css=0, sky=2, star=1,
        clouds=lambda: make_clouds(2, 1, 3, 11, 1.0),
        mount=lambda: make_mountains(2, 3, 2, 1, 21, 2, 9),
        hills=lambda: make_hills((3, 2), 0, 1, 31, 'trees'),
        world_bg=lambda x, y: (dither(x, y, 0, 2) if y < 2 else (2 if (x % 13 == 0 and y % 3 == 1) else 0)),
        surface=lambda x, y: 1 if y == WORLD_H - 2 and x % 5 else 0,
        ground=lambda: make_ground(0, 1, 3, 2, 41),
        fg=lambda: make_fg(2, 0, 3, 51),
        decor=['palm', 'palm', 'bush', 'palm', 'bush', 'drums'],
        camps=[(8, 0), (8, 0), (10, 0), (10, 0)],
        hud_bg=2, hud_fg=1, map_bg=0,
    ))
    # 2 DESERT -----------------------------------------------------------
    T.append(dict(
        name='DESERT', op='OPERATION SANDSTORM', css=0, sky=2, star=1,
        clouds=lambda: make_clouds(2, 1, 3, 12, 0.5),
        mount=lambda: make_mountains(2, 3, 3, 1, 22, 2, 8, 'mesa'),
        hills=lambda: make_hills(3, 1, 3, 32, 'dunes'),
        world_bg=lambda x, y: (dither(x, y, 1, 3) if y < 2 else (3 if ((x // 2 + y * 3) % 17 == 0) else 1)),
        surface=lambda x, y: (0 if (y == WORLD_H - 2 and x % 9 == 0) else 3 if y == WORLD_H - 1 and x % 3 == 0 else 1),
        ground=lambda: make_ground(1, 1, 3, 0, 42),
        fg=lambda: make_fg(3, 1, 0, 52),
        decor=['cactus', 'rock', 'ruin', 'cactus', 'drums', 'bunker', 'wreck'],
        camps=[(8, 1), (10, 0), (10, 1), (10, 0)],
        hud_bg=2, hud_fg=1, map_bg=1,
    ))
    # 3 HIGHLANDS (CSS1: 0 buff, 1 cyan, 2 magenta, 3 orange) -------------
    T.append(dict(
        name='HIGHLANDS', op='OPERATION AVALANCHE', css=1, sky=1, star=0,
        clouds=lambda: make_clouds(1, 0, 2, 13, 1.2),
        mount=lambda: make_mountains(1, 2, 2, 0, 23, 2, 10, 'snow'),
        hills=lambda: dither_band(make_hills(2, 3, 0, 33, 'pines'), 3, 2),
        world_bg=lambda x, y: (1 if (x % 9 == 4 and y % 3 == 0) else 0),
        surface=lambda x, y: 0,
        ground=lambda: make_ground(0, 0, 1, 2, 43),
        fg=lambda: make_fg(1, 0, 2, 53),
        decor=['pine_snow', 'pine_snow', 'rock', 'dish', 'pine', 'wreck'],
        hut='cabin',
        camps=[(10, 1), (10, 0), (10, 1), (10, 0)],
        hud_bg=2, hud_fg=0, map_bg=0,
    ))
    # 4 CITY ---------------------------------------------------------------
    T.append(dict(
        name='CITY', op='OPERATION DAYBREAK', css=0, sky=2, star=1,
        clouds=lambda: make_clouds(2, 1, 3, 14, 0.8),
        mount=lambda: make_city_skyline(2, 3, 1, 24),
        hills=lambda: make_hills(3, 2, None, 34, 'industry'),
        world_bg=lambda x, y: (dither(x, y, 2, 0) if y < 2 else 0),
        surface=lambda x, y: 1 if (x // 2) % 4 == 0 and y == WORLD_H - 1 else 0,
        ground=lambda: make_ground(1, 0, 2, 3, 44),
        fg=lambda: make_fg(2, 1, 3, 54),
        decor=['factory', 'tank_fuel', 'lamp', 'crane', 'ruin', 'wreck', 'lamp'],
        camps=[(10, 1), (12, 1), (10, 0), (12, 1)],
        hud_bg=2, hud_fg=1, map_bg=0,
    ))
    return T


def build_theme(t, idx):
    rnd = random.Random(100 + idx)
    return dict(
        clouds=t['clouds'](), mount=t['mount'](), hills=t['hills'](),
        world=make_world(t, rnd), ground=t['ground'](), fg=t['fg'](),
    )


SUN = """
....YYYY....
..YYYYYYYY..
.YYYYYYYYYY.
.YYYYYYYYYY.
YYYYYYYYYYYY
YYYYYYYYYYYY
YYYYYYYYYYYY
YYYYYYYYYYYY
.YYYYYYYYYY.
.YYYYYYYYYY.
..YYYYYYYY..
....YYYY....
"""
