# executed inside gen.py: 128x64 Mode 1 (CSS0) title backdrop -> title_pic (packbits)
# colours: 0 green, 1 yellow, 2 blue (space), 3 red
import random, math
random.seed(1984)
G_, Y_, B_, R_ = 0, 1, 2, 3
TT = [[B_] * 128 for _ in range(64)]


def put(x, y, c):
    if 0 <= x < 128 and 0 <= y < 64:
        TT[y][x] = c


# stars (kept away from the logo later)
for _ in range(70):
    put(random.randrange(128), random.randrange(0, 50), random.choice((Y_, Y_, G_)))

# planet horizon: a big green curve with darker (red-dithered) craters
for x in range(128):
    top = int(50 + 7 * ((x - 64) / 64.0) ** 2)
    for y in range(top, 64):
        put(x, y, G_)
    put(x, top, Y_)
for cx, cy, r in ((20, 57, 3), (47, 54, 2), (90, 55, 3), (112, 60, 2), (66, 61, 2)):
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - 2 * r, cx + 2 * r + 1):
            if ((x - cx) / 2.0) ** 2 + (y - cy) ** 2 <= r * r and TT[y][x] == G_ and (x + y) % 2 == 0:
                put(x, y, R_)

# a ringed moon top-right
for y in range(26, 41):
    for x in range(98, 126):
        dx = (x - 112) / 2.0; dy = y - 33
        if dx * dx + dy * dy <= 30:
            put(x, y, R_ if (x + y) % 3 else Y_)
for x in range(92, 128):
    y = int(33 + (x - 112) * 0.18)
    if not (106 <= x <= 118):
        put(x, y, Y_)

# clear logo area
for y in range(1, 25):
    for x in range(1, 127):
        TT[y][x] = B_

BIGF = {
    'K': ["##...##", "##..##.", "##.##..", "####...", "###....", "####...", "##.##..", "##..##.", "##...##"],
    'A': ["..###..", ".#####.", "##...##", "##...##", "#######", "#######", "##...##", "##...##", "##...##"],
    'M': ["##...##", "###.###", "#######", "##.#.##", "##...##", "##...##", "##...##", "##...##", "##...##"],
    'I': ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
    'Z': ["#######", "#######", "....##.", "...##..", "..##...", ".##....", "##.....", "#######", "#######"],
    'E': ["#######", "#######", "##.....", "#####..", "#####..", "##.....", "##.....", "#######", "#######"],
}
SMALLF = {
    'I': ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    'N': ["#..#", "##.#", "####", "#.##", "#..#", "#..#", "#..#"],
    'V': ["#..#", "#..#", "#..#", "#..#", "#..#", ".##.", ".##."],
    'A': [".##.", "#..#", "#..#", "####", "#..#", "#..#", "#..#"],
    'D': ["###.", "#..#", "#..#", "#..#", "#..#", "#..#", "###."],
    'E': ["####", "#...", "#...", "###.", "#...", "#...", "####"],
    'R': ["###.", "#..#", "#..#", "###.", "#.#.", "#..#", "#..#"],
    'S': [".###", "#...", "#...", ".##.", "...#", "...#", "###."],
}
# KAMIKAZE: yellow letters, red drop shadow, a green highlight on the top row
x = 3
for ch in "KAMIKAZE":
    g = BIGF[ch]
    for yy, row in enumerate(g):
        for xx, c in enumerate(row):
            if c == '#':
                put(x + xx + 1, 3 + yy + 1, R_)
    for yy, row in enumerate(g):
        for xx, c in enumerate(row):
            if c == '#':
                put(x + xx, 3 + yy, G_ if yy == 0 else Y_)
    x += len(g[0]) + 3
# INVADERS (smaller, green with red shadow), centred under KAMIKAZE
w = sum(len(SMALLF[c][0]) + 2 for c in "INVADERS") - 2
x = 3 + (x - 3 - w) // 2
for ch in "INVADERS":
    g = SMALLF[ch]
    for yy, row in enumerate(g):
        for xx, c in enumerate(row):
            if c == '#':
                put(x + xx + 1, 16 + yy + 1, R_)
                put(x + xx, 16 + yy, G_)
    x += len(g[0]) + 2
# the big 2: red with a yellow outline, right of the logo
TWO = [
    ".########.",
    "##########",
    "###....###",
    "........##",
    ".......###",
    ".....####.",
    "...####...",
    ".####.....",
    "###.......",
    "##........",
    "##########",
    "##########",
]
ox, oy = 104, 4
for yy, row in enumerate(TWO):
    for xx, c in enumerate(row):
        if c == '#':
            for ddx, ddy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
                if TT[oy + yy + ddy][ox + xx + ddx] == B_:
                    put(ox + xx + ddx, oy + yy + ddy, Y_)
for yy, row in enumerate(TWO):
    for xx, c in enumerate(row):
        if c == '#':
            put(ox + xx, oy + yy, R_)

save_preview(TT, "title.png", css=0)
L.append("title_pic:")
db(packbits(bitmap_to_bytes(TT)))
