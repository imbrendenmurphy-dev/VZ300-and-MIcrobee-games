# executed inside gen.py: title picture, trophy picture and player portraits (Mode 1, CSS0)
# CSS0 colours: 0 green, 1 yellow, 2 blue, 3 red
G_, Y_, B_, R_ = 0, 1, 2, 3


def canvas(w=128, h=64, c=G_):
    return [[c] * w for _ in range(h)]


def put(P, x, y, c):
    if 0 <= y < len(P) and 0 <= x < len(P[0]):
        P[y][x] = c


def rect(P, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(P, x, y, c)


# ---------------------------------------------------------------- title
BIG = {
    'T': ["######", "######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.."],
    'E': ["######", "######", "##....", "#####.", "#####.", "##....", "######", "######"],
    'N': ["##..##", "###.##", "###.##", "######", "##.###", "##.###", "##..##", "##..##"],
    'I': ["######", "######", "..##..", "..##..", "..##..", "..##..", "######", "######"],
    'S': [".#####", "######", "##....", "#####.", ".#####", "....##", "######", "#####."],
}
TP = canvas()
# a soft crowd / stand band at the very top
for x in range(128):
    if x % 2 == 0:
        put(TP, x, 0, (Y_, R_, B_)[(x * 7) % 3])
    put(TP, x, 1, B_ if x % 4 else Y_)


def big_word(P, word, x0, y0, face, edge, shadow):
    # glyph 6x8 scaled 2x2 -> 12x16, 2 px gap; outline + drop shadow
    mask = set()
    x = x0
    for ch in word:
        g = BIG[ch]
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == '#':
                    for dy in range(2):
                        for dx in range(2):
                            mask.add((x + gx * 2 + dx, y0 + gy * 2 + dy))
        x += 14
    for (px, py) in mask:
        put(P, px + 2, py + 2, shadow)
    for (px, py) in mask:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (px + dx, py + dy) not in mask:
                    put(P, px + dx, py + dy, edge)
    for (px, py) in mask:
        put(P, px, py, face)
    return x


big_word(TP, "TENNIS", 4, 4, R_, Y_, B_)
big_word(TP, "II", 94, 4, B_, Y_, R_)
# title court (perspective) rows 30..56
def tcourt(P, y0, y1, hw0, hw1, cx, net=True):
    for y in range(y0, y1 + 1):
        t = (y - y0) / (y1 - y0)
        hw = hw0 + (hw1 - hw0) * t
        a = round(cx - hw); b = round(cx + hw)
        put(P, a, y, Y_); put(P, b, y, Y_)
        if y in (y0, y1):
            for x in range(a, b + 1):
                put(P, x, y, Y_)
    if net:
        yn = (y0 + y1) // 2 - 2
        t = (yn - y0) / (y1 - y0)
        hw = hw0 + (hw1 - hw0) * t + 4
        for x in range(round(cx - hw), round(cx + hw) + 1):
            put(P, x, yn - 2, Y_)
            put(P, x, yn - 1, B_ if x % 2 else G_)
            put(P, x, yn, Y_)
        put(P, round(cx - hw), yn - 3, Y_); put(P, round(cx + hw), yn - 3, Y_)
        put(P, round(cx - hw), yn + 1, Y_); put(P, round(cx + hw), yn + 1, Y_)
    # centre line + service lines
    ym = (y0 + y1) // 2
    for y in range(y0 + 6, y1 - 7):
        put(P, cx, y, Y_)
    for yy in (y0 + 6, y1 - 7):
        t = (yy - y0) / (y1 - y0)
        hw = hw0 + (hw1 - hw0) * t
        for x in range(round(cx - hw), round(cx + hw) + 1):
            put(P, x, yy, Y_)


tcourt(TP, 35, 56, 28, 46, 64)
title_bytes = bitmap_to_bytes(TP)
d = packbits(title_bytes)
L.append("title_pic: ; %d bytes" % len(d))
db(d)
save_preview(TP, "title.png")


# ---------------------------------------------------------------- trophy (centre 48 px wide, rows 8..55)
TR = canvas(48, 48)
cx = 24
for y in range(0, 22):          # cup bowl
    hw = 15 - (y * y) // 40
    for x in range(cx - hw, cx + hw + 1):
        put(TR, x, y + 2, Y_)
    put(TR, cx - hw, y + 2, R_); put(TR, cx + hw, y + 2, R_)
for x in range(cx - 15, cx + 16):
    put(TR, x, 2, R_)
for y in range(4, 18):          # handles
    put(TR, cx - 19 + (1 if 7 < y < 15 else 0), y, Y_)
    put(TR, cx + 19 - (1 if 7 < y < 15 else 0), y, Y_)
for x in range(cx - 19, cx - 15):
    put(TR, x, 4, Y_); put(TR, x, 17, Y_)
for x in range(cx + 16, cx + 20):
    put(TR, x, 4, Y_); put(TR, x, 17, Y_)
for y in range(6, 16, 2):       # shine
    put(TR, cx - 9, y, G_ if y % 4 else Y_)
rect(TR, cx - 2, 24, cx + 2, 31, Y_)  # stem
rect(TR, cx - 8, 32, cx + 8, 34, Y_)
rect(TR, cx - 12, 35, cx + 12, 46, B_)  # plinth
rect(TR, cx - 10, 38, cx + 10, 43, Y_)
for x in range(cx - 9, cx + 10, 3):
    put(TR, x, 40, R_)
# ribbons
for y in range(4, 26):
    put(TR, cx - 16 + y // 4, y + 6, R_ if y < 22 else G_)
    put(TR, cx + 16 - y // 4, y + 6, R_ if y < 22 else G_)
d = packbits(bitmap_to_bytes(TR, 0, 48))
L.append("trophy_pic: ; 48x48, %d bytes" % len(d))
db(d)
save_preview(TR, "trophy.png")

# ---------------------------------------------------------------- portraits 24x20
def face(kind):
    P = canvas(24, 20, G_)
    rect(P, 0, 17, 23, 19, B_)                  # shoulders / shirt
    rect(P, 2, 16, 21, 16, B_)
    # head
    for y in range(3, 17):
        hw = [5, 7, 8, 8, 9, 9, 9, 9, 9, 9, 8, 7, 6, 4][y - 3]
        for x in range(12 - hw, 12 + hw):
            put(P, x, y, Y_)
    rect(P, 10, 15, 13, 17, Y_)                 # neck
    # eyes and mouth
    def eyes(c=B_):
        put(P, 8, 8, c); put(P, 9, 8, c); put(P, 14, 8, c); put(P, 15, 8, c)
    def smile(c=R_):
        for x in range(9, 15):
            put(P, x, 12, c)
        put(P, 8, 11, c); put(P, 15, 11, c)
    def frown(c=R_):
        for x in range(9, 15):
            put(P, x, 12, c)
        put(P, 8, 13, c); put(P, 15, 13, c)
    def hair(c, top=3, sides=7):
        for y in range(top, top + 3):
            for x in range(4, 20):
                if P[y][x] == Y_ or y == top:
                    put(P, x, y, c)
        for y in range(top, top + sides):
            put(P, 3, y, c); put(P, 4, y, c); put(P, 19, y, c); put(P, 20, y, c)
    if kind == 0:      # RUSTY: messy red mop, freckles, big grin
        hair(R_, 2, 6)
        for x in range(4, 21, 2):
            put(P, x, 1, R_)
        eyes(); smile()
        put(P, 7, 10, R_); put(P, 16, 10, R_)
    elif kind == 1:    # LOBBY LOU: backwards blue cap
        hair(B_, 2, 4)
        rect(P, 2, 4, 6, 5, B_)
        eyes(); smile()
    elif kind == 2:    # NET NETTA: long red hair + blue headband
        hair(R_, 2, 13)
        rect(P, 4, 5, 19, 5, B_)
        eyes(); smile(R_)
    elif kind == 3:    # BAZZA: bald, sweatband, moustache
        rect(P, 4, 4, 19, 5, R_)
        eyes()
        rect(P, 8, 11, 15, 11, B_); put(P, 7, 12, B_); put(P, 16, 12, B_)
        frown()
    elif kind == 4:    # DUSTY: bucket hat
        rect(P, 5, 1, 18, 4, R_)
        rect(P, 2, 5, 21, 5, R_)
        eyes(); frown(B_)
    elif kind == 5:    # ROCKET RITA: blue bun, red headband
        rect(P, 9, 0, 14, 2, B_)
        hair(B_, 3, 8)
        rect(P, 4, 6, 19, 6, R_)
        eyes(); smile()
    elif kind == 6:    # THE PROFESSOR: glasses + beard
        hair(B_, 2, 4)
        for x in (6, 7, 8, 9, 10, 13, 14, 15, 16, 17):
            put(P, x, 7, B_); put(P, x, 9, B_)
        put(P, 6, 8, B_); put(P, 10, 8, B_); put(P, 13, 8, B_); put(P, 17, 8, B_)
        put(P, 11, 8, B_); put(P, 12, 8, B_)
        for y in range(11, 16):
            for x in range(6, 18):
                if P[y][x] == Y_ and (x + y) % 2 == 0:
                    put(P, x, y, B_)
        rect(P, 10, 12, 13, 12, R_)
    elif kind == 7:    # MR VZ300: crown + shades
        for x in range(5, 19):
            put(P, x, 2, R_)
        for x in (5, 9, 12, 14, 18):
            put(P, x, 1, R_); put(P, x, 0, Y_)
        rect(P, 5, 3, 18, 4, R_)
        rect(P, 6, 7, 17, 9, B_)
        put(P, 11, 7, Y_); put(P, 12, 7, Y_)
        smile()
        rect(P, 0, 17, 23, 19, R_)
        rect(P, 10, 17, 13, 19, Y_)
    else:              # YOU: visor
        hair(R_, 3, 5)
        rect(P, 3, 5, 21, 6, B_)
        eyes(); smile()
        rect(P, 0, 17, 23, 19, R_)
    return P


L.append("portraits: ; 9 x 24x20 (6 bytes x 20 rows)")
pv = canvas(24 * 9, 20)
for k in range(9):
    P = face(k)
    db(bitmap_to_bytes(P, 0, 24))
    for y in range(20):
        for x in range(24):
            pv[y][k * 24 + x] = P[y][x]
save_preview(pv, "portraits.png")
