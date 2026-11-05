# executed inside gen.py namespace: builds the 128x64 Mode 1 title backdrop
import random
random.seed(1031)
G, Y, BL, R = 0, 1, 2, 3
T = [[BL] * 128 for _ in range(64)]


def put(x, y, c):
    if 0 <= x < 128 and 0 <= y < 64:
        T[y][x] = c


LET = {
 'G': [".#######.", "#########", "###......", "###..####", "###..####", "###....##", "#########", ".#######."],
 'H': ["###...###", "###...###", "###...###", "#########", "#########", "###...###", "###...###", "###...###"],
 'O': [".#######.", "#########", "###...###", "###...###", "###...###", "###...###", "#########", ".#######."],
 'S': [".########", "#########", "###......", "########.", ".########", "......###", "#########", "########."],
 'T': ["#########", "#########", "...###...", "...###...", "...###...", "...###...", "...###...", "...###..."],
 'U': ["###...###", "###...###", "###...###", "###...###", "###...###", "###...###", "#########", ".#######."],
 'N': ["####..###", "#####.###", "#########", "###.#####", "###..####", "###...###", "###...###", "###...###"],
 'E': ["#########", "#########", "###......", "#######..", "#######..", "###......", "#########", "#########"],
 'R': ["########.", "#########", "###...###", "#########", "########.", "###.####.", "###..####", "###...###"],
}
THREE = [
 ".#############.",
 "###############",
 "###############",
 "####.......####",
 "...........####",
 "...........####",
 "..........####.",
 ".....#######...",
 ".....########..",
 ".....#########.",
 "..........#####",
 "...........####",
 "...........####",
 "####.......####",
 "###############",
 "###############",
 ".#############."]
DEE = [
 "############...",
 "#############..",
 "##############.",
 "####......#####",
 "####.......####",
 "####.......####",
 "####.......####",
 "####.......####",
 "####.......####",
 "####.......####",
 "####.......####",
 "####.......####",
 "####.......####",
 "####......#####",
 "##############.",
 "#############..",
 "############..."]


def stamp(rows, x0, y0, fill, shadow=None, outline=None, hilite=None):
    h = len(rows); w = len(rows[0])
    on = lambda x, y: 0 <= y < h and 0 <= x < len(rows[y]) and rows[y][x] == '#'
    if shadow is not None:
        for y in range(h):
            for x in range(w):
                if on(x, y):
                    for (dx, dy) in ((1, 1), (2, 1)):
                        if not on(x + dx, y + dy):
                            put(x0 + x + dx, y0 + y + dy, shadow)
    if outline is not None:
        for y in range(-1, h + 1):
            for x in range(-1, w + 1):
                if not on(x, y) and any(on(x + a, y + b) for a in (-1, 0, 1) for b in (-1, 0, 1)):
                    put(x0 + x, y0 + y, outline)
    for y in range(h):
        for x in range(w):
            if on(x, y):
                c = fill
                if hilite is not None and (y == 0 or not on(x, y - 1)):
                    c = hilite
                put(x0 + x, y0 + y, c)


def extrude(rows, x0, y0, face, side, rim, depth=3):
    """a block letter with a 3-D extrusion down and to the right"""
    h = len(rows); w = len(rows[0])
    on = lambda x, y: 0 <= y < h and 0 <= x < w and rows[y][x] == '#'
    for d in range(depth, 0, -1):
        for y in range(h):
            for x in range(w):
                if on(x, y):
                    put(x0 + x + d, y0 + y + d, side)
    for y in range(h):
        for x in range(w):
            if on(x, y):
                c = face
                if not on(x, y - 1) or not on(x - 1, y):
                    c = rim
                put(x0 + x, y0 + y, c)


# stars
for _ in range(80):
    x = random.randrange(128); y = random.randrange(0, 46)
    put(x, y, Y if random.random() < 0.8 else G)
# moon low on the right, behind the haunted house
mx, my, rx, ry = 106, 33, 13, 9
for y in range(64):
    for x in range(128):
        dx = (x - mx) / rx; dy = (y - my) / ry
        if dx * dx + dy * dy <= 1.0:
            T[y][x] = Y
for (cx, cy) in ((100, 29), (111, 36), (104, 38), (113, 28)):
    put(cx, cy, G); put(cx + 1, cy, G)
# clear stars around the logo zone
for y in range(0, 27):
    for x in range(0, 128):
        if T[y][x] != BL:
            T[y][x] = BL

# logo: GHOST / HUNTER with depth, then a big extruded 3-D
x = 2
for ch in "GHOST":
    stamp(LET[ch], x, 2, R, shadow=G, hilite=Y)
    x += 11
x = 2
for ch in "HUNTER":
    stamp(LET[ch], x, 13, Y, shadow=R)
    x += 11
extrude(THREE, 73, 1, R, G, Y)
extrude(DEE, 92, 1, R, G, Y)
# tagline under the logo
def text3(s, x, y, c):
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for j in range(5):
            for i in range(3):
                if g[j][i] == '#':
                    put(x + i, y + j, c)
        x += 4
text3("THE BIG HAUNT", 9, 23, G)
text3("IN SPOOKY 3-D", 72, 20, Y) if False else None
for (sx, sy) in ((70, 1), (124, 22), (66, 24)):
    put(sx, sy, Y); put(sx - 1, sy, Y); put(sx + 1, sy, Y)

# graveyard hill
import math
for x in range(128):
    top = int(49 + 2.5 * math.sin(x / 13.0) + 1.5 * math.sin(x / 5.3 + 1))
    for y in range(top, 57):
        T[y][x] = G
# the haunted house on the right, a dark silhouette against the moon
HOUSE = [
 "..........#..........",
 ".........###.........",
 "........#####........",
 ".......#######.......",
 "......####w####......",
 "......#########......",
 "....#############....",
 "...###############...",
 "..#################..",
 "..##w##w#####w##w##..",
 "..#################..",
 "..#################..",
 "..##w##w##ddd##w##w..",
 "..#########d#######..",
 "..#########d#######..",
 "..#################..",
]
hx, hy = 95, 31
WINDOWS = []
for j, r in enumerate(HOUSE):
    for i, c in enumerate(r):
        if c == '#':
            put(hx + i, hy + j, R)
        elif c == 'w':
            put(hx + i, hy + j, Y)
            WINDOWS.append((hx + i, hy + j))
        elif c == 'd':
            put(hx + i, hy + j, BL)
# roof line highlights
for i in range(21):
    for j in range(len(HOUSE)):
        if HOUSE[j][i] == '#' and (j == 0 or HOUSE[j - 1][i] == '.'):
            put(hx + i, hy + j, G)
            break
# tombstones (blue cut-outs with green rims, sitting on the hill)
def tomb(x0, y0, w, h, cross=False):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if y == y0 and x in (x0, x0 + w - 1):
                continue
            put(x, y, G)
    if cross:
        cx = x0 + w // 2
        put(cx, y0 + 1, BL); put(cx - 1, y0 + 2, BL); put(cx, y0 + 2, BL); put(cx + 1, y0 + 2, BL); put(cx, y0 + 3, BL)
    else:
        for i in range(1, w - 1):
            if i % 2 == 1:
                put(x0 + i, y0 + 2, BL)
tomb(8, 43, 5, 7, cross=True)
tomb(30, 44, 6, 6)
tomb(54, 45, 5, 6, cross=True)
tomb(76, 44, 6, 6)
# a crooked fence by the house
for fx in range(84, 95, 3):
    for fy in range(45, 49):
        put(fx, fy, R)
for fx in range(84, 95):
    put(fx, 46, R)
# bottom strip (text area) stays blue: rows 57..63
for y in range(57, 64):
    for x in range(128):
        T[y][x] = BL

save_preview(T, "title.png")
stars = [(x, y) for y in range(27, 46) for x in range(128) if T[y][x] in (Y, G) and not (88 <= x <= 122) and y < 44 and all(T[y][x+d] == BL for d in (-1, 1) if 0 <= x+d < 128)]
stars = stars[:40]
L.append("NWIN equ %d" % len(WINDOWS))
L.append("winlist:")
db([v for p in WINDOWS for v in p])
L.append("NSTARS equ %d" % len(stars))
L.append("starlist:")
db([v for p in stars for v in p])
tb = bitmap_to_bytes(T)
tp = packbits(tb)
unpack_check(tp, 2048)
L.append("title_pic: ; %d bytes packed" % len(tp))
db(tp)
