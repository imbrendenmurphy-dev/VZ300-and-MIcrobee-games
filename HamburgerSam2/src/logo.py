# HAMBURGER SAM II - rounded "bun" logo lettering (original pixel design, BPM 2026).
# Hand-pixelled bubble letters sized for Mode 1's tall pixels: strokes are 3 px wide and
# 2 rows tall so they look even on a 4:3 screen, with every corner rounded off.
# stamp() wraps them in a crust outline, a drop shadow and optional sesame seeds.

SMALL = {  # 10 x 12, for HAMBURGER
'H': """
.###..###.
####..####
###....###
###....###
###....###
##########
##########
###....###
###....###
###....###
####..####
.###..###.""",
'A': """
...####...
.########.
####..####
###....###
###....###
##########
##########
###....###
###....###
###....###
####..####
.###..###.""",
'M': """
.##....##.
####..####
##########
##########
###.##.###
###.##.###
###....###
###....###
###....###
###....###
####..####
.###..###.""",
'B': """
.######...
#########.
###...####
###....###
###...####
########..
#########.
###...####
###....###
###...####
#########.
.#######..""",
'U': """
.###..###.
####..####
###....###
###....###
###....###
###....###
###....###
###....###
###....###
####..####
.########.
...####...""",
'R': """
.######...
#########.
###...####
###....###
###...####
#########.
########..
###..####.
###...###.
###...####
####...###
.###...##.""",
'G': """
...#####..
.########.
####...##.
###.......
###.......
###..####.
###..#####
###....###
###....###
####..####
.########.
...####...""",
'E': """
.########.
##########
###.......
###.......
###.......
########..
########..
###.......
###.......
###.......
##########
.########.""",
}
BIG = {  # 13 x 17, for SAM II
'S': """
....#####....
..#########..
.####...####.
####.....###.
####.........
.#####.......
..########...
...#########.
.......######
.........####
..........###
###.......###
####.....####
.####...####.
..#########..
....#####....
.............""",
'A': """
....#####....
..#########..
.####...####.
####.....####
####.....####
####.....####
####.....####
#############
#############
####.....####
####.....####
####.....####
####.....####
####.....####
.###.....###.
.............
.............""",
'M': """
.##.......##.
####.....####
#####...#####
######.######
#############
####.###.####
####..#..####
####.....####
####.....####
####.....####
####.....####
####.....####
####.....####
####.....####
.###.....###.
.............
.............""",
'I': """
.#########.
###########
...#####...
...#####...
...#####...
...#####...
...#####...
...#####...
...#####...
...#####...
...#####...
...#####...
...#####...
###########
.#########.
...........
...........""",
}


def glyph(tab, ch):
    return [[1 if c == '#' else 0 for c in r] for r in tab[ch].strip('\n').split('\n')]


def word(tab, text, gap=2):
    gs = [glyph(tab, c) for c in text]
    h = max(len(g) for g in gs)
    rows = [[] for _ in range(h)]
    for i, g in enumerate(gs):
        for y in range(h):
            rows[y] += (g[y] if y < len(g) else [0] * len(g[0])) + ([0] * gap if i < len(gs) - 1 else [])
    while rows and not any(rows[-1]):
        rows.pop()
    return rows


def stamp(P, M, x0, y0, fill, crust, shadow, seeds=None, shine=None):
    """paint mask M at x0,y0: shadow (down-right), crust outline, fill, seeds, shine"""
    h, w = len(M), len(M[0])
    on = lambda x, y: 0 <= y < h and 0 <= x < w and M[y][x]
    def put(x, y, c):
        if 0 <= x0 + x < 128 and 0 <= y0 + y < 64:
            P[y0 + y][x0 + x] = c
    near = lambda x, y: any(on(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))
    if shadow is not None:
        for y in range(h + 3):
            for x in range(w + 3):
                if near(x - 1, y - 1) or near(x - 2, y - 1):
                    put(x, y, shadow)
    for y in range(-1, h + 1):
        for x in range(-1, w + 1):
            if not on(x, y) and near(x, y):
                put(x, y, crust)
    for y in range(h):
        for x in range(w):
            if on(x, y):
                c = fill
                inner = on(x - 1, y) and on(x + 1, y) and on(x, y - 1) and on(x, y + 1)
                if shine is not None and on(x, y) and not on(x, y - 1) and on(x + 1, y) and y < h // 2:
                    c = shine
                if seeds is not None and inner and y < h * 0.4 and (x * 5 + y * 3) % 9 == 0:
                    c = seeds
                put(x, y, c)
    return w, h
