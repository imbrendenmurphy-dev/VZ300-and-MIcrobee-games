# executed inside gen.py: 128x64 Mode 1 (CSS0) title backdrop -> title_pic (packbits)
import random
random.seed(1984)
G_, Y_, B_, R_ = 0, 1, 2, 3
TT = [[B_] * 128 for _ in range(64)]


def put(x, y, c):
    if 0 <= x < 128 and 0 <= y < 64:
        TT[y][x] = c


# deep space: stars (two brightnesses), a ringed planet, the station girders below
for _ in range(55):
    x = random.randrange(128); y = random.randrange(0, 40)
    put(x, y, Y_ if random.random() < 0.6 else G_)
for dy in range(-6, 7):
    for dx in range(-9, 10):
        if dx * dx / 81.0 + dy * dy / 36.0 <= 1:
            put(112 + dx, 30 + dy, R_ if (dx - dy) % 4 else Y_)
for dx in range(-15, 16):
    y = 30 + int(dx * 0.25)
    if abs(dx) > 8:
        put(112 + dx, y, Y_)
# ground: the station deck (green), one girder with a ladder, message strip
for y in range(40, 64):
    for x in range(128):
        TT[y][x] = G_
for x in range(128):
    put(x, 40, Y_ if x % 4 else R_)
GIRD = ["11111111", "22222211", "11111111"]
for j in range(3):
    for x in range(128):
        put(x, 52 + j, int(GIRD[j][x % 8]))
for y in range(41, 52):
    for x in (9, 14):
        put(x, y, Y_)
    if (y - 41) % 3 == 1:
        for x in range(9, 15):
            put(x, y, Y_)

LET = {
 'P': ["#######.", "########", "###..###", "###..###", "########", "#######.", "###.....", "###.....", "###.....", "###....."],
 'A': ["..####..", ".######.", "###..###", "###..###", "###..###", "########", "########", "###..###", "###..###", "###..###"],
 'N': ["###..###", "####.###", "########", "########", "###.####", "###..###", "###..###", "###..###", "###..###", "###..###"],
 'I': ["########", "########", "..####..", "..####..", "..####..", "..####..", "..####..", "..####..", "########", "########"],
 'K': ["###..###", "###.###.", "######..", "#####...", "####....", "#####...", "######..", "###.###.", "###..###", "###..###"],
}
TWOB = [
 "..########..",
 ".##########.",
 "####....####",
 "####....####",
 "........####",
 ".......####.",
 ".....#####..",
 "...#####....",
 ".#####......",
 "####........",
 "############",
 "############"]


def stamp(rows, x0, y0, fill, shadow=None, hilite=None, outline=None, wobble=0):
    h = len(rows); w = len(rows[0])
    on = lambda x, y: 0 <= y < h and 0 <= x < len(rows[y]) and rows[y][x] == '#'
    if outline is not None:
        for y in range(-1, h + 1):
            for x in range(-1, w + 1):
                if not on(x, y) and any(on(x + a, y + b) for a in (-1, 0, 1) for b in (-1, 0, 1)):
                    put(x0 + x, y0 + y, outline)
    if shadow is not None:
        for y in range(h):
            for x in range(w):
                if on(x, y):
                    for (dx, dy) in ((1, 1), (2, 1), (1, 2), (2, 2)):
                        if not on(x + dx, y + dy):
                            put(x0 + x + dx, y0 + y + dy, shadow)
    for y in range(h):
        for x in range(w):
            if on(x, y):
                c = fill
                if hilite is not None and (y == 0 or not on(x, y - 1)):
                    c = hilite
                put(x0 + x, y0 + y, c)


# PANIK: shaky "panic" letters, each nudged up or down a pixel or two
x = 4
for i, ch in enumerate("PANIK"):
    y = 4 + (0, 2, -1, 1, 0)[i]
    stamp(LET[ch], x, y, Y_, shadow=R_)
    x += 11
stamp(TWOB, 63, 3, R_, outline=Y_)
# speed lines behind the 2
for (yy, ln) in ((6, 6), (9, 9), (12, 5)):
    for k in range(ln):
        put(80 + k * 2, yy, Y_)


def text3(s, x, y, c):
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for j in range(5):
            for i in range(3):
                if g[j][i] == '#':
                    put(x + i, y + j, c)
        x += 4


text3("DIG DEEPER!", 6, 20, Y_)
text3("THE ALIENS ARE BACK", 6, 28, G_)
tb = bitmap_to_bytes(TT)
pk = packbits(tb)
L.append("; ---- title backdrop (%d bytes packed)" % len(pk))
L.append("title_pic:")
db(pk)
save_preview(TT, "title.png", css=0)
