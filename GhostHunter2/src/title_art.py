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
TWO = [
 "...##########...",
 ".##############.",
 "################",
 "#####......#####",
 "####........####",
 "...........#####",
 "..........#####.",
 "........######..",
 "......######....",
 "....######......",
 "..######........",
 ".#####..........",
 "#####...........",
 "################",
 "################",
 "################"]


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


# stars
for _ in range(70):
    x = random.randrange(128); y = random.randrange(0, 44)
    put(x, y, Y if random.random() < 0.8 else G)
# moon (behind the 2): centre (106,13) radius 14px horiz, 9 rows vert
mx, my, rx, ry = 101, 13, 15, 10
for y in range(64):
    for x in range(128):
        dx = (x - mx) / rx; dy = (y - my) / ry
        d = dx * dx + dy * dy
        if d <= 1.0:
            T[y][x] = Y
            # craters
for (cx, cy, r) in ((106, 8, 1), (98, 17, 1), (110, 17, 1), (93, 9, 1)):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - 2 * r, cx + 2 * r + 1):
            if ((x - cx) / (2 * r + 0.5)) ** 2 + ((y - cy) / (r + 0.5)) ** 2 <= 1 and T[y][x] == Y:
                T[y][x] = G if (x + y) % 2 else Y
# clear stars around the logo zone
for y in range(1, 27):
    for x in range(1, 84):
        if T[y][x] != BL:
            T[y][x] = BL

# logo
x = 3
for ch in "GHOST":
    stamp(LET[ch], x, 2, R, shadow=G, hilite=Y)
    x += 11
x = 3
for ch in "HUNTER":
    stamp(LET[ch], x, 13, Y, shadow=R)
    x += 11
stamp(TWO, 74, 3, R, outline=Y, shadow=None)
# tagline under the logo
def text3(s, x, y, c):
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for j in range(5):
            for i in range(3):
                if g[j][i] == '#':
                    put(x + i, y + j, c)
        x += 4
text3("THE BOO-QUEL", 18, 23, G)
# little sparkles near the 2
for (sx, sy) in ((71, 1), (120, 26), (60, 25)):
    put(sx, sy, Y); put(sx - 1, sy, Y); put(sx + 1, sy, Y)

# graveyard hill
import math
for x in range(128):
    top = int(49 + 2.5 * math.sin(x / 13.0) + 1.5 * math.sin(x / 5.3 + 1))
    for y in range(top, 57):
        T[y][x] = G
    if 0 <= top - 1:
        pass
# tombstones (blue cut-outs with green rims, sitting on the hill)
def tomb(x0, y0, w, h, cross=False):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            edge = x in (x0, x0 + w - 1) or y == y0
            if y == y0 and x in (x0, x0 + w - 1):
                continue
            put(x, y, G)
    if cross:
        cx = x0 + w // 2
        put(cx, y0 + 1, BL); put(cx - 1, y0 + 2, BL); put(cx, y0 + 2, BL); put(cx + 1, y0 + 2, BL); put(cx, y0 + 3, BL)
    else:
        # "RIP" scratch
        for i in range(1, w - 1):
            if i % 2 == 1:
                put(x0 + i, y0 + 2, BL)
tomb(10, 43, 5, 7, cross=True)
tomb(34, 44, 6, 6)
tomb(60, 45, 5, 6, cross=True)
tomb(86, 43, 6, 7)
# dead tree on the right
for y in range(33, 52):
    put(121, y, G); put(122, y, G)
for (bx, by, d) in ((121, 38, -1), (122, 35, 1), (121, 42, -1)):
    for k in range(6):
        put(bx + d * k, by - k // 2, G)
put(116, 34, G); put(125, 31, G)
# fence posts
for fx in range(40, 84, 6):
    pass
# bottom strip (text area) stays blue: rows 57..63
for y in range(57, 64):
    for x in range(128):
        T[y][x] = BL

save_preview(T, "title.png")
stars = [(x, y) for y in range(0, 46) for x in range(128) if T[y][x] in (Y, G) and not (66 <= x <= 118 and y <= 25) and not (y <= 28 and x <= 70) and y < 44 and all(T[y][x+d] == BL for d in (-1, 1) if 0 <= x+d < 128)]
stars = stars[:40]
L.append("NSTARS equ %d" % len(stars))
L.append("starlist:")
db([v for p in stars for v in p])
tb = bitmap_to_bytes(T)
tp = packbits(tb)
unpack_check(tp, 2048)
L.append("title_pic: ; %d bytes packed" % len(tp))
db(tp)
