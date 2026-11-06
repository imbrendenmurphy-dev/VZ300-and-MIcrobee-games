# HAMBURGER SAM II - title picture (executed in gen.py's namespace). All original.
# Logical = physical CSS0 colours: 0 green, 1 yellow, 2 blue, 3 red.


def blank(c=0):
    return [[c] * 128 for _ in range(64)]


def put(P, x, y, c):
    if 0 <= x < 128 and 0 <= y < 64:
        P[y][x] = c


def big_text(P, s, x, y, sx, sy, col, shadow=None, gap=1):
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for r, row in enumerate(g):
            for cx, v in enumerate(row):
                if v == '#':
                    for yy in range(sy):
                        for xx in range(sx):
                            if shadow is not None:
                                put(P, x + cx * sx + xx + 1, y + r * sy + yy + 1, shadow)
        for r, row in enumerate(g):
            for cx, v in enumerate(row):
                if v == '#':
                    for yy in range(sy):
                        for xx in range(sx):
                            put(P, x + cx * sx + xx, y + r * sy + yy, col)
        x += 3 * sx + gap
    return x


def text_w(s, sx, gap=1):
    return len(s) * (3 * sx + gap) - gap


def small(P, s, x, y, col):
    big_text(P, s, x, y, 1, 1, col, None, 1)


def burger(P, cx, top, w):
    """a big juicy burger, w px wide, centred on cx"""
    x0 = cx - w // 2
    y = top
    # top bun dome (6 rows)
    for r in range(7):
        inset = [8, 5, 3, 2, 1, 0, 0][r]
        for x in range(x0 + inset, x0 + w - inset):
            put(P, x, y + r, 1)
    for (sx, sy) in ((6, 2), (13, 1), (20, 2), (27, 1), (34, 2), (10, 4), (17, 4), (24, 4), (31, 4)):
        if sx < w - 3:
            put(P, x0 + sx, y + sy, 2)
    y += 7
    # lettuce frill (2 rows)
    for x in range(x0 - 2, x0 + w + 2):
        put(P, x, y, 2)
        if x % 2 == 0:
            put(P, x, y + 1, 2)
    y += 2
    # cheese with drips
    for x in range(x0 - 1, x0 + w + 1):
        put(P, x, y, 1)
    for d in (3, 11, 20, 29, 36):
        if d < w:
            put(P, x0 + d, y + 1, 1); put(P, x0 + d + 1, y + 1, 1); put(P, x0 + d, y + 2, 1)
    y += 1
    # patty (4 rows) with grill marks
    for r in range(4):
        inset = 1 if r in (0, 3) else 0
        for x in range(x0 + inset, x0 + w - inset):
            put(P, x, y + r, 3)
    for gx in range(4, w - 2, 7):
        put(P, x0 + gx, y + 1, 2); put(P, x0 + gx + 1, y + 2, 2)
    y += 4
    # bottom bun (3 rows)
    for r in range(3):
        inset = [0, 0, 2][r]
        for x in range(x0 + inset, x0 + w - inset):
            put(P, x, y + r, 1)
    return y + 3


T = blank(0)
# frame: red rule top and bottom with yellow dots (diner trim)
for x in range(128):
    T[0][x] = 3
    T[63][x] = 3
    if x % 4 == 1:
        T[1][x] = 1
# logo: hand-pixelled bubble lettering (logo.py) - bun-yellow HAMBURGER with sesame seeds,
# a patty-red SAM and a lettuce-blue II, all in a crust outline with a drop shadow
exec(open(os.path.join(HERE, "logo.py")).read())
m1 = word(SMALL, "HAMBURGER", 2)
stamp(T, m1, (128 - len(m1[0])) // 2 - 1, 3, 1, 3, 2, seeds=0)
m2 = word(BIG, "SAM", 3)
stamp(T, m2, 4, 19, 3, 1, 2)
m3 = word(BIG, "II", 3)
stamp(T, m3, 4 + len(m2[0]) + 6, 19, 2, 1, 3)
# the burger, right hand side
burger(T, 105, 18, 30)
# subtitle
w = text_w("- THE BURGER RUSH -", 1, 2)
big_text(T, "- THE BURGER RUSH -", (128 - w) // 2, 37, 1, 1, 3, None, 2)
# chase lane girder (sprites run along y 48..55)
for x in range(2, 126):
    T[56][x] = 1
    if x % 6 == 0:
        T[57][x] = 1
small(T, "VIBED BY BPM 2026", (128 - text_w("VIBED BY BPM 2026", 1)) // 2, 58, 2)
L.append("title_pic:")
db(packbits(bitmap_to_bytes(T)))
save_preview(T, "title.png")
L.append("TITLE_MSG_Y equ 43")
L.append("TITLE_RUN_Y equ 55")
