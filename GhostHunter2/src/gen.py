#!/usr/bin/env python3
"""Ghost Hunter 2 data generator: font, sprites, mazes, title art -> data.inc
Also writes preview PNGs into ../build/preview/ ."""
import os, sys
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "data.inc")
PREV = os.path.join(HERE, "..", "build", "preview")
os.makedirs(PREV, exist_ok=True)
CSS0 = [(7, 255, 0), (255, 255, 0), (59, 8, 255), (204, 0, 59)]
CSS1 = [(255, 255, 255), (7, 227, 153), (255, 28, 255), (255, 129, 0)]
L = []  # output lines


def db(vals, per=16):
    vals = list(vals)
    for i in range(0, len(vals), per):
        L.append("    db " + ",".join("$%02X" % (v & 255) for v in vals[i:i + per]))


def packbits(data):
    """control n: 0..127 -> n+1 literals; 129..255 -> repeat next byte 257-n times; 128 = end"""
    out = []
    i = 0
    n = len(data)
    while i < n:
        j = i
        while j < n and j - i < 128 and data[j] == data[i]:
            j += 1
        run = j - i
        if run >= 3:
            out += [257 - run, data[i]]
            i = j
            continue
        lit = []
        while i < n and len(lit) < 128:
            if i + 2 < n and data[i] == data[i + 1] == data[i + 2]:
                break
            lit.append(data[i])
            i += 1
        out += [len(lit) - 1] + lit
    out.append(128)
    return out


def unpack_check(p, ln):
    out = []
    i = 0
    while True:
        c = p[i]; i += 1
        if c == 128:
            break
        if c < 128:
            out += p[i:i + c + 1]; i += c + 1
        else:
            out += [p[i]] * (257 - c); i += 1
    assert len(out) == ln, (len(out), ln)
    return out


def bitmap_to_bytes(pix):  # pix[y][x] colour 0..3, 128x64
    out = []
    for y in range(64):
        for bx in range(32):
            v = 0
            for k in range(4):
                v = (v << 2) | (pix[y][bx * 4 + k] & 3)
            out.append(v)
    return out


def save_preview(pix, name, css=0):
    pal = CSS0 if css == 0 else CSS1
    w = len(pix[0]); h = len(pix)
    im = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            im.putpixel((x, y), pal[pix[y][x]])
    im = im.resize((w * 4, h * 6), Image.NEAREST)
    im.save(os.path.join(PREV, name))


# ---------------------------------------------------------------- 3x5 font
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
    '!': [".#.", ".#.", ".#.", "...", ".#."], '?': ["##.", "..#", ".#.", "...", ".#."],
    '.': ["...", "...", "...", "...", ".#."], ',': ["...", "...", "...", ".#.", "#.."],
    ':': ["...", ".#.", "...", ".#.", "..."], '-': ["...", "...", "###", "...", "..."],
    '+': ["...", ".#.", "###", ".#.", "..."], '/': ["..#", "..#", ".#.", "#..", "#.."],
    "'": [".#.", ".#.", "...", "...", "..."], '&': [".#.", "#.#", ".#.", "#.#", ".##"],
    '=': ["...", "###", "...", "###", "..."], '<': ["..#", ".#.", "#..", ".#.", "..#"],
    '>': ["#..", ".#.", "..#", ".#.", "#.."], '*': ["#.#", ".#.", "###", ".#.", "#.#"],
    '(': [".#.", "#..", "#..", "#..", ".#."], ')': [".#.", "..#", "..#", "..#", ".#."],
    '"': ["#.#", "#.#", "...", "...", "..."], '#': ["#.#", "###", "#.#", "###", "#.#"],
    '@': [".#.", "#.#", "###", "#.#", ".#."],  # used as heart/life? overwritten below
    '[': [".#.", "###", "###", ".#.", "..."],  # small heart-ish (life icon)
    ']': ["###", "#.#", "###", "...", "..."],
    '^': [".#.", "###", "...", "...", "..."], '_': ["...", "...", "...", "...", "###"],
    '$': [".##", "##.", ".#.", ".##", "##."], '%': ["#.#", "..#", ".#.", "#..", "#.#"],
    ';': ["...", ".#.", "...", ".#.", "#.."], '\\': ["#..", "#..", ".#.", "..#", "..#"],
}
# custom glyphs at '@'=copyright-ish 'c', '[' hero icon, ']' ghost icon
FONT['@'] = ["###", "#..", "#..", "#..", "###"]
FONT['['] = [".##", "##.", "#..", "##.", ".##"]   # chomper icon
FONT[']'] = [".#.", "###", "#.#", "###", "#.#"]   # ghost icon
L.append("; ---- 3x5 font, ASCII 32..95, 5 bytes/glyph, bit2=left pixel")
L.append("font3:")
for c in range(32, 96):
    g = FONT.get(chr(c), FONT[' '])
    db([int(r.replace('#', '1').replace('.', '0'), 2) for r in g])

# ---------------------------------------------------------------- sprites
CM = {'.': None, 'g': 0, 'y': 1, 'b': 2, 'r': 3}
SPR = []  # (name, rows)


def S(name, art):
    rows = [r for r in art.strip("\n").split("\n")]
    rows = [r.strip() for r in rows]
    SPR.append((name, rows))


def mirror(rows):
    return [r[::-1] for r in rows]


# hero facing right: 3 frames (wide, half, closed)
HR = ["""
.rrrrr
yyybyy
yyyy..
yyy...
.yyyy.
""", """
.rrrrr
yyybyy
yyyyy.
yyyy..
.yyyy.
""", """
.rrrrr
yyybyy
yyyyyy
yyyyyy
.yyyy.
"""]
HD = ["""
.rrrr.
rrrrrr
ybyyby
yy..yy
.y..y.
""", """
.rrrr.
rrrrrr
ybyyby
yy..yy
.yyyy.
""", """
.rrrr.
rrrrrr
ybyyby
yyyyyy
.yyyy.
"""]
HU = ["""
.rrrr.
rrrrrr
yyyyyy
yyyyyy
.y..y.
""", """
.rrrr.
rrrrrr
yyyyyy
yyyyyy
.yyyy.
""", """
.rrrr.
rrrrrr
yyyyyy
yyyyyy
.yyyy.
"""]
for i in range(3):
    S("HERO_R%d" % i, HR[i])
for i in range(3):
    SPR.append(("HERO_L%d" % i, mirror([r.strip() for r in HR[i].strip().split("\n")])))
for i in range(3):
    S("HERO_U%d" % i, HU[i])
for i in range(3):
    S("HERO_D%d" % i, HD[i])
# super hero (flaming cap: alternating colour cap)
S("SHERO_0", """
y.r.y.
.rrrrr
yyybyy
yyy...
.yyyy.
""")
S("SHERO_1", """
.r.y.r
.rrrrr
yyybyy
yyyyy.
.yyyy.
""")
# death animation frames (hero collapses)
S("HDIE_0", """
.rrrr.
y....y
yy..yy
yyyyyy
.yyyy.
""")
S("HDIE_1", """
.rrrr.
......
y....y
yyyyyy
.yyyy.
""")
S("HDIE_2", """
......
.rrrr.
......
y....y
.yyyy.
""")
S("HDIE_3", """
......
......
.rrrr.
......
.y..y.
""")
S("HDIE_4", """
......
y.r..y
..r.y.
.y....
y..r.y
""")

# ghost bodies: eyes for 4 dirs (R,L,U,D) x 2 skirt frames
def ghost(body, eye, stripe=None, hollow=False):
    res = []
    for d in "RLUD":
        for f in range(2):
            rows = [list(".BBBB."), list("BBBBBB"), list("BBBBBB"), list("BBBBBB"),
                    list("B.BB.B" if f == 0 else "BB..BB")]
            if hollow:
                rows = [list(".BBBB."), list("B....B"), list("B....B"), list("B....B"),
                        list("B.BB.B" if f == 0 else "BB..BB")]
            if d == 'R':
                pos = [(1, 2), (1, 4)]
            elif d == 'L':
                pos = [(1, 1), (1, 3)]
            elif d == 'U':
                pos = [(0, 1), (0, 4)]
            else:
                pos = [(2, 1), (2, 4)]
            for (y, x) in pos:
                rows[y][x] = 'E'
            out = []
            for y, r in enumerate(rows):
                s = ""
                for x, c in enumerate(r):
                    if c == 'B':
                        col = body
                        if stripe and x % 2 == 1:
                            col = stripe
                        s += col
                    elif c == 'E':
                        s += eye
                    else:
                        s += '.'
                out.append(s)
            res.append(out)
    return res


GH = {"GRUMBLE": ghost('r', 'y'), "SNEAKY": ghost('g', 'r'), "DIZZY": ghost('r', 'y', stripe='g'),
      "PEEKA": ghost('g', 'y', hollow=True)}
for gname in ["GRUMBLE", "SNEAKY", "DIZZY", "PEEKA"]:
    for i, rows in enumerate(GH[gname]):
        SPR.append(("G_%s_%d" % (gname, i), rows))
S("FRIGHT_0", """
.yyyy.
yryyry
yyyyyy
ryryry
y.yy.y
""")
S("FRIGHT_1", """
.yyyy.
yryyry
yyyyyy
ryryry
yy..yy
""")
S("FLASH_0", """
.gggg.
grggrg
gggggg
rgrgrg
g.gg.g
""")
S("FLASH_1", """
.gggg.
grggrg
gggggg
rgrgrg
gg..gg
""")
for d, a, b in (("R", "g g.", ""), ("L", "", ""), ("U", "", ""), ("D", "", "")):
    pass
S("EYES_R", """
......
.grgr.
.gggg.
......
......
""")
S("EYES_L", """
......
.rgrg.
.gggg.
......
......
""")
S("EYES_U", """
.r..r.
.g..g.
......
......
......
""")
S("EYES_D", """
......
......
.g..g.
.r..r.
......
""")
# frozen ghost (icy, shivering): white-green body with blue eyes
S("FROZEN_0", """
.gggg.
gbggbg
gggggg
gggggg
g.gg.g
""")
S("FROZEN_1", """
.gggg.
gbggbg
gggggg
gggggg
gg..gg
""")
# power-up icons
S("I_SPEED", """
...yy.
..yy..
.yyyy.
..yy..
.yy...
""")
S("I_FREEZE", """
g.g.g.
.ggg..
ggggg.
.ggg..
g.g.g.
""")
S("I_DECOY", """
.yyy..
yybyy.
.yyy..
..r...
.rrr..
""")
S("I_X2", """
r.ryy.
.r...y
r.r.y.
...y..
...yyy
""")
S("I_SHIELD", """
.ggg..
g...g.
g.y.g.
g...g.
.ggg..
""")
S("I_STAR", """
..y...
yyyyy.
.yry..
.y.y..
y...y.
""")
S("I_STAR2", """
..r...
rrrrr.
.ryr..
.r.r..
r...r.
""")
S("I_ENERG", """
......
..y...
.yyy..
..y...
......
""")
# Halloween treasures
S("T_CANDY", """
......
g.rr.g
ggrrgg
g.rr.g
......
""")
S("T_PUMPKIN", """
..g...
.rrrr.
ryryry
rrrrrr
.rrrr.
""")
S("T_POTION", """
..y...
..g...
.ggg..
gyyyg.
.ggg..
""")
S("T_CROWN", """
y.y.y.
yyyyy.
yryry.
yyyyy.
......
""")
S("T_GEM", """
.ggg..
ggygg.
.ggg..
..g...
......
""")
S("T_SKULL", """
.ggg..
gbgbg.
ggggg.
.g.g..
......
""")
# decoy dummy (hero cut-out on a stick, wobbling)
S("DECOY_0", """
.yyy..
yybyy.
yyy...
.yyy..
..r...
""")
S("DECOY_1", """
..yyy.
.yybyy
.yyy..
..yyy.
..r...
""")
# shield bubble around hero (drawn over hero)
S("BUBBLE_0", """
.g..g.
g....g
......
g....g
.g..g.
""")
S("BUBBLE_1", """
..gg..
......
g....g
......
..gg..
""")

# ---- big sprites (up to 16 px wide)
BIG = []


def B(name, art):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    BIG.append((name, rows))


B("BHERO_0", """
...rrrrr....
..rrrrrrrrr.
.rrrrrrrrrrr
.yyyyyyyy...
yyyyyybyy...
yyyyyyyy....
yyyyyyy.....
yyyyyyyy....
yyyyyyyyy...
.yyyyyyyyy..
..yyyyyyy...
""")
B("BHERO_1", """
...rrrrr....
..rrrrrrrrr.
.rrrrrrrrrrr
.yyyyyyyyy..
yyyyyybyyyy.
yyyyyyyyyyy.
yyyyyyyyyyy.
yyyyyyyyyyy.
yyyyyyyyyyy.
.yyyyyyyyy..
..yyyyyyy...
""")
BIG.append(("BHERO_L0", [r[::-1] for r in BIG[0][1]]))
BIG.append(("BHERO_L1", [r[::-1] for r in BIG[1][1]]))
B("BGHOST_0", """
...rrrrr...
.rrrrrrrrr.
rrryyrrryyr
rrybyrrybyr
rrrrrrrrrrr
rrrrrrrrrrr
rrrrrrrrrrr
rrrrrrrrrrr
rr.rrr.rrr.
r...r...r..
""")
B("BGHOST_1", """
...rrrrr...
.rrrrrrrrr.
rryyrrryyrr
rrbyrrrbyrr
rrrrrrrrrrr
rrrrrrrrrrr
rrrrrrrrrrr
rrrrrrrrrrr
.rrr.rrr.rr
..r...r...r
""")
B("BFRIGHT_0", """
...yyyyy...
.yyyyyyyyy.
yyyyyyyyyyy
yyrryyyrryy
yyyyyyyyyyy
yyyyyyyyyyy
yryyryyryyy
ryyryyryyry
yy.yyy.yyy.
y...y...y..
""")
B("BFRIGHT_1", """
...yyyyy...
.yyyyyyyyy.
yyyyyyyyyyy
yyrryyyrryy
yyyyyyyyyyy
yyyyyyyyyyy
yyryyryyryy
yryyryyryyr
.yyy.yyy.yy
..y...y...y
""")
B("BGHOST_S", """
...ggggg...
.ggggggggg.
gggrrgggrrg
ggrbrggrbrg
ggggggggggg
ggggggggggg
ggggggggggg
ggggggggggg
gg.ggg.ggg.
g...g...g..
""")
B("BGHOST_D", """
...rgrgr...
.rgrgrgrgr.
rgryygryyrg
rgybygrybyg
rgrgrgrgrgr
rgrgrgrgrgr
rgrgrgrgrgr
rgrgrgrgrgr
rg.grg.rgr.
r...r...r..
""")
B("BGHOST_P", """
...ggggg...
.gg.....gg.
g...yy...yy
g..by...by.
g.........g
g.........g
g.........g
g.........g
gg.ggg.ggg.
g...g...g..
""")
B("BEYES", """
...........
...........
...gg...gg.
...gr...gr.
...........
...........
...........
...........
...........
...........
""")

ALL = SPR + BIG
L.append("; ---- sprites: table of (src ptr, src width bytes, height)")
for i, (n, rows) in enumerate(ALL):
    L.append("SPR_%s equ %d" % (n, i))
L.append("NSPR equ %d" % len(ALL))
tot = 0
for n, rows in ALL:
    w = max(len(r) for r in rows); sw = 2 if w <= 8 else 4
    tot += (sw + 1) * len(rows) * 4
L.append("SHIFTSIZE equ %d" % tot)
L.append("sprtab:")
for n, rows in ALL:
    w = max(len(r) for r in rows)
    sw = 2 if w <= 8 else 4
    L.append("    dw spr_%s\n    db %d,%d" % (n, sw, len(rows)))
for n, rows in ALL:
    w = max(len(r) for r in rows)
    sw = 2 if w <= 8 else 4
    L.append("spr_%s:" % n)
    data = []
    for r in rows:
        r = r.ljust(sw * 4, '.')
        dv = 0
        for c in r:
            col = CM[c]
            dv = (dv << 2) | (2 if col is None else col)
        data += [(dv >> (8 * (sw - 1 - k))) & 255 for k in range(sw)]
    db(data)

# preview sheet
cells = []
for n, rows in ALL:
    cells.append(rows)
cw = 18; ch = 14; cols = 12
sheet = [[2] * (cw * cols) for _ in range(ch * ((len(cells) + cols - 1) // cols))]
for i, rows in enumerate(cells):
    ox = (i % cols) * cw + 1; oy = (i // cols) * ch + 1
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if CM[c] is not None:
                sheet[oy + y][ox + x] = CM[c]
save_preview(sheet, "sprites.png")

# ---------------------------------------------------------------- mazes
# 21 x 11 cells, cell 6x5 px, origin (1,6). Left half given (11 cols), mirrored.
# legend: # wall, . pellet, o energiser, ' ' empty, G house, - door, T tunnel (empty edge),
#         X teleporter, P player start (empty)
MAZES = [
    ('A', ['###########', '#o........#', '#.##.####.#', '#..........', '#.##.#.##--', 'T....#.#GGG', '#.##.#.####', '#....#....P', '#.##.####.#', '#o........#', '###########'], 1),
    ('B', ['###########', '#o....#....', '#.###.#.##.', '#..........', '##.##.###--', 'T......#GGG', '#.##.#.####', '#.#..#....P', '#.#.###.##.', '#o.........', '###########'], 2),
    ('C', ['###########', '#X...#...o.', '#.##.#.#.#.', '#.#........', '#.#.##.##--', 'T...#..#GGG', '#.#.#.#####', '#.#.......P', '#.##.#.##.#', '#o...#...X#', '###########'], 3),
    ('D', ['###########', '#o........#', '#.#.##.##.#', '#.#........', '#...##.##--', '##.#...#GGG', '#..#.#.####', '#.#..#....P', '#.#.##.##.#', '#o.......o.', '###########'], 4),
    ('E', ['###########', '#o..#.....#', '#.#.#.###.#', '#..........', '#.#.#.###--', 'T.#.#.##GGG', '#.....#####', '##.#......P', '#..#.#.####', '#o...#.....', '###########'], 5),
    ('F', ['###########', '#....X#o...', '#.###.#.##.', '#.#........', '#.#.##.##--', 'T...#..#GGG', '###.#.#####', '#......#..P', '#.####.#.#.', '#o...X.....', '###########'], 4),
]


def build_maze(half):
    rows = []
    for r in half:
        r = r.ljust(11)[:11]
        full = r[:10] + r[10] + r[9::-1]
        rows.append(list(full))
    return rows


def fix_house(rows):
    # ensure house: door at (4,10); interior row 5 cols 9..11; walls around
    return rows


MAZE_OUT = []
for name, half, style in MAZES:
    # rows given with 10 or 11 chars: if 10 chars, the 11th (centre) taken as last char repeated
    fixed = []
    for r in half:
        assert len(r) == 11, (name, r)
        fixed.append(r)
    rows = build_maze(fixed)
    # replace mirrored 'P' with ' ' and keep single P at centre-ish? P at col 10 row 7 is centre
    grid = rows
    MAZE_OUT.append((name, grid, style))


def neighbours_ok(grid):
    H = len(grid); W = len(grid[0])
    path = lambda c: c not in "#-G"
    # flood from P
    start = None
    for y in range(H):
        for x in range(W):
            if grid[y][x] == 'P':
                start = (x, y)
    seen = {start}
    st = [start]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = (x + dx) % W, y + dy
            if 0 <= ny < H and path(grid[ny][nx]) and (nx, ny) not in seen:
                seen.add((nx, ny)); st.append((nx, ny))
    allp = {(x, y) for y in range(H) for x in range(W) if path(grid[y][x])}
    missing = allp - seen
    # dead ends
    dead = []
    for (x, y) in allp:
        n = 0
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = (x + dx) % W, y + dy
            if 0 <= ny < H and path(grid[ny][nx]):
                n += 1
        if n < 2:
            dead.append((x, y))
    return missing, dead


CELL_CODE = {'#': 3, '.': 1, 'o': 2, ' ': 0, 'G': 5, '-': 4, 'T': 7, 'X': 6, 'P': 0}
L.append("; ---- mazes: 21x11 cell codes (0 empty,1 pellet,2 energiser,3 wall,4 door,5 house,6 teleport,7 tunnel)")
for name, grid, style in MAZE_OUT:
    for y, r in enumerate(grid):
        print(name, y, "".join(r))
    missing, dead = neighbours_ok(grid)
    if missing:
        print("MAZE", name, "unreachable", sorted(missing))
    if dead:
        print("MAZE", name, "dead ends", sorted(dead))
    assert len(grid) == 11 and all(len(r) == 21 for r in grid)
    L.append("maze%s_grid:" % name)
    db([CELL_CODE[c] for r in grid for c in r], 21)


# render wall bitmaps
def render_walls(grid, style):
    pix = [[2] * 128 for _ in range(64)]
    H = 11; W = 21
    def wall(x, y):
        if y < 0 or y >= H:
            return True
        if x < 0 or x >= W:
            return grid[y][max(0, min(W - 1, x))] == '#'   # outside horizontally: continue edge
        return grid[y][x] in "#"
    def solid(x, y):
        if y < 0 or y >= H or x < 0 or x >= W:
            return True
        return grid[y][x] in "#G-"
    for cy in range(H):
        for cx in range(W):
            c = grid[cy][cx]
            ox = 1 + cx * 6; oy = 6 + cy * 5
            if c == '-':   # door: dashed red line in middle row
                for i in range(6):
                    pix[oy + 3][ox + i] = 3 if i % 2 == 0 else 1
                continue
            if c != '#':
                continue
            L_ = not wall(cx - 1, cy); R_ = not wall(cx + 1, cy)
            U_ = not wall(cx, cy - 1); D_ = not wall(cx, cy + 1)
            for j in range(5):
                for i in range(6):
                    on = False
                    # inset lines: col 1 / col 4, row 1 / row 3
                    if L_ and i == 1 and (j >= 1 or not U_) and (j <= 3 or not D_):
                        on = True
                    if R_ and i == 4 and (j >= 1 or not U_) and (j <= 3 or not D_):
                        on = True
                    if U_ and j == 1 and (i >= 1 or not L_) and (i <= 4 or not R_):
                        on = True
                    if D_ and j == 3 and (i >= 1 or not L_) and (i <= 4 or not R_):
                        on = True
                    # extend lines across to neighbours (continuity) where neighbour is wall
                    if L_ and i == 1 and ((j == 0 and not U_) or (j == 4 and not D_)):
                        on = True
                    if R_ and i == 4 and ((j == 0 and not U_) or (j == 4 and not D_)):
                        on = True
                    if U_ and j == 1 and ((i == 0 and not L_) or (i == 5 and not R_)):
                        on = True
                    if D_ and j == 3 and ((i == 0 and not L_) or (i == 5 and not R_)):
                        on = True
                    # rounded corners: drop the corner pixel where two lines meet
                    if (L_ and U_ and i == 1 and j == 1) or (R_ and U_ and i == 4 and j == 1) or \
                       (L_ and D_ and i == 1 and j == 3) or (R_ and D_ and i == 4 and j == 3):
                        on = False
                    # inner corners (diagonal open, orthogonals walls)
                    if not L_ and not U_ and not wall(cx - 1, cy - 1) and i <= 1 and j <= 1 and (i == 1) != (j == 1) and False:
                        on = True
                    inner = 1 <= i <= 4 and 1 <= j <= 3
                    if style in (2, 5):   # filled blocks
                        if (not L_ or i >= 1) and (not R_ or i <= 4) and (not U_ or j >= 1) and (not D_ or j <= 3):
                            on = True
                            # leave a blue grain pattern inside
                            if inner and not on:
                                pass
                    if style == 3 and on and (i + j) % 2 == 1 and (i in (1, 4)) and (j in (1, 3)) is False:
                        pass
                    if on:
                        col = 0
                        if style == 3 and (i + j) % 2 == 0:
                            col = 0
                        if style == 4 and (i == 1 and L_ or i == 4 and R_) and j % 2 == 1:
                            col = 0
                        pix[oy + j][ox + i] = col
            # inner diagonal corner dots to join lines around concave corners
            for (dx, dy, ci, cj) in ((-1, -1, 0, 0), (1, -1, 5, 0), (-1, 1, 0, 4), (1, 1, 5, 4)):
                if wall(cx + dx, cy) and wall(cx, cy + dy) and not wall(cx + dx, cy + dy):
                    ii = 1 if dx < 0 else 4; jj = 1 if dy < 0 else 3
                    pix[oy + jj][ox + ii] = 0
                    pix[oy + (0 if dy < 0 else 4)][ox + ii] = 0
                    pix[oy + jj][ox + (0 if dx < 0 else 5)] = 0
            if style == 2:
                # fill interior with checker for texture
                for j in range(5):
                    for i in range(6):
                        if pix[oy + j][ox + i] == 2 and (L_ is False or i >= 2) and (R_ is False or i <= 3) and (U_ is False or j >= 2) and (D_ is False or j <= 2):
                            if (i + j + cx + cy) % 2 == 0:
                                pix[oy + j][ox + i] = 0
            if style in (3, 5) and 0 < cx < 20 and 0 < cy < 10:
                for j in range(5):
                    for i in range(6):
                        if pix[oy + j][ox + i] == 2 and (L_ is False or i >= 2) and (R_ is False or i <= 3) and (U_ is False or j >= 2) and (D_ is False or j <= 2):
                            if (i + 2 * j) % 4 == 0:
                                pix[oy + j][ox + i] = 3
            if style == 4 and 0 < cx < 20 and 0 < cy < 10:
                for j in range(5):
                    for i in range(6):
                        if pix[oy + j][ox + i] == 2 and (L_ is False or i >= 2) and (R_ is False or i <= 3) and (U_ is False or j >= 2) and (D_ is False or j <= 2):
                            if j == 2 and i % 3 == 0:
                                pix[oy + j][ox + i] = 3
    return pix


for name, grid, style in MAZE_OUT:
    pix = render_walls(grid, style)
    # preview with pellets
    pv = [r[:] for r in pix]
    for cy in range(11):
        for cx in range(21):
            c = grid[cy][cx]; ox = 1 + cx * 6; oy = 6 + cy * 5
            if c == '.':
                pv[oy + 2][ox + 2] = 1
            if c == 'o':
                for (i, j) in ((2, 1), (1, 2), (2, 2), (3, 2), (2, 3)):
                    pv[oy + j][ox + i] = 1
    save_preview(pv, "maze_%s.png" % name)
L.append("mazetab:")
for name, grid, style in MAZE_OUT:
    L.append("    dw maze%s_grid\n    db %d,0" % (name, style))

# ---------------------------------------------------------------- title art
exec(open(os.path.join(HERE, "title_art.py")).read())
exec(open(os.path.join(HERE, "music.py")).read())

open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT, "sprites:", len(ALL))

# ---- lookup tables
T2 = []
T2.append("div6: db " + ",".join(str(min(x // 6, 21)) for x in range(128)))
T2.append("mod6: db " + ",".join(str(x % 6) for x in range(128)))
T2.append("div5: db " + ",".join(str(x // 5) for x in range(64)))
T2.append("mod5: db " + ",".join(str(x % 5) for x in range(64)))
T2.append("mul23: db " + ",".join(str(x * 2 // 3) for x in range(128)))
T2.append("    db " + ",".join(str(x * 2 // 3) for x in range(128,256)))
T2.append("row21: db " + ",".join(str(y * 21) for y in range(11)))
open(OUT, "a").write("\n".join(T2) + "\n")
