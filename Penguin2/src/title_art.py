# executed inside gen.py: 128x64 Mode 1 (CSS1) title backdrop -> title_pic (packbits)
import random, math
random.seed(2026)
W_, C_, M_, O_ = 0, 1, 2, 3
TT = [[M_] * 128 for _ in range(64)]


def put(x, y, c):
    if 0 <= x < 128 and 0 <= y < 64:
        TT[y][x] = c


# aurora: soft cyan/white dithered ribbons waving across the magenta night
for x in range(128):
    for band, (base, amp, per, ph, thick) in enumerate(((5, 3, 23.0, 0.0, 4), (14, 3, 31.0, 1.7, 3))):
        yc = base + amp * math.sin(x / per * 6.283 + ph)
        for t in range(thick):
            y = int(yc) + t
            if (x + y + band) % 2 == 0 or t == thick // 2:
                put(x, y, C_ if t != thick // 2 or band == 1 else W_)
# stars
for _ in range(40):
    x = random.randrange(128); y = random.randrange(0, 34)
    if TT[y][x] == M_:
        put(x, y, W_)

# snowy mountains / icebergs
peaks = [(-6, 40), (8, 31), (20, 40), (34, 28), (50, 41), (64, 32), (76, 40), (92, 27), (110, 41), (122, 33), (136, 42)]
def mtop(x):
    for (x0, y0), (x1, y1) in zip(peaks, peaks[1:]):
        if x0 <= x < x1:
            t = (x - x0) / (x1 - x0)
            return y0 + (y1 - y0) * t, y1 < y0
    return 40, False
for x in range(128):
    top, rising = mtop(x)
    top = int(top)
    for y in range(top, 47):
        shade = (not rising) and y < top + 5 and (x + y) % 2 == 0
        put(x, y, C_ if shade or y == top else W_)
# snow field
for y in range(47, 64):
    for x in range(128):
        put(x, y, W_)
for x in range(128):
    if x % 7 == 3:
        put(x, 47, C_)

# keep the logo area clean
for y in range(1, 22):
    for x in range(1, 81):
        if TT[y][x] != M_ and not (y < 2):
            TT[y][x] = M_
# logo: zig-zag PENGUIN (a nod to the original's sidebar) + a big 2
LET = {
 'P': ["#######.", "########", "###..###", "###..###", "########", "#######.", "###.....", "###.....", "###.....", "###....."],
 'E': ["########", "########", "###.....", "######..", "######..", "###.....", "###.....", "###.....", "########", "########"],
 'N': ["###..###", "####.###", "########", "########", "###.####", "###..###", "###..###", "###..###", "###..###", "###..###"],
 'G': [".#######", "########", "###.....", "###.....", "###.####", "###.####", "###..###", "###..###", "########", ".#######"],
 'U': ["###..###", "###..###", "###..###", "###..###", "###..###", "###..###", "###..###", "###..###", "########", ".######."],
 'I': ["########", "########", "..####..", "..####..", "..####..", "..####..", "..####..", "..####..", "########", "########"],
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
 "############",
 "############"]


def stamp(rows, x0, y0, fill, shadow=None, hilite=None, outline=None):
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
                    for (dx, dy) in ((1, 1), (2, 1), (1, 2)):
                        if not on(x + dx, y + dy):
                            put(x0 + x + dx, y0 + y + dy, shadow)
    for y in range(h):
        for x in range(w):
            if on(x, y):
                c = fill
                if hilite is not None and (y == 0 or not on(x, y - 1)):
                    c = hilite
                put(x0 + x, y0 + y, c)


x = 3
for i, ch in enumerate("PENGUIN"):
    y = 3 if i % 2 == 0 else 9
    fill = O_ if i % 2 == 0 else C_
    stamp(LET[ch], x, y, fill, hilite=W_)
    x += 11
stamp(TWOB, 86, 4, W_, outline=O_, shadow=M_)   # big 2 low between mountains
# small sparkles
for (sx, sy) in ((2, 1), (122, 4), (95, 19)):
    put(sx, sy, W_); put(sx - 1, sy, C_); put(sx + 1, sy, C_); put(sx, sy - 1, C_); put(sx, sy + 1, C_)


def text3(s, x, y, c):
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for j in range(5):
            for i in range(3):
                if g[j][i] == '#':
                    put(x + i, y + j, c)
        x += 4


text3("ICE AGE RAMPAGE", 10, 22, W_)
tb = bitmap_to_bytes(TT)
pk = packbits(tb)
L.append("; ---- title backdrop (%d bytes packed)" % len(pk))
L.append("title_pic:")
db(pk)
save_preview(TT, "title.png", css=1)
