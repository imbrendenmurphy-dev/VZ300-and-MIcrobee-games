"""RUNEDEEP UI glyphs.

Bank 14: the font (codes 80h-DFh = ASCII 32-127) and icons (E0h-FFh).
Bank 15: the frame (80h-BFh) and the minimap (C0h-FFh, drawn at run time).
All 8 x 10. The frame is a bronze double rule with knotted corners.
"""
import font


def g(rows):
    rows = [r.ljust(8, '.') for r in rows]
    assert len(rows) == 10, rows
    return bytes(int(r.replace('.', '0').replace('#', '1'), 2) for r in rows)


ICONS = {
    'key': ["........", "..##....", ".#..#...", ".#..#...", "..##....", "...#....", "...##...", "...#....", "...##...", "........"],
    'potion': ["........", "...##...", "...##...", "..#..#..", ".#....#.", ".#.##.#.", ".#####.#", ".######.", "..####..", "........"],
    'sigil': ["........", "...#....", "..###...", ".##.##..", "##...##.", ".##.##..", "..###...", "...#....", "........", "........"],
    'flame': ["....#...", "...#....", "..##.#..", "..####..", ".##.###.", ".#..#.#.", ".#....#.", "..#..#..", "...##...", "........"],
    'mend': ["........", "...##...", "...##...", ".######.", ".######.", "...##...", "...##...", "...##...", "........", "........"],
    'coin': ["........", "..####..", ".#....#.", "#..##..#", "#.#....#", "#..##..#", ".#....#.", "..####..", "........", "........"],
    'sword': ["......#.", ".....#..", "....#...", "...#....", "#.#.....", ".#......", "#.#.....", "........", "........", "........"],
    'shield': ["........", ".######.", ".#.##.#.", ".######.", ".#.##.#.", "..#..#..", "...##...", "........", "........", "........"],
    'arrN': ["...##...", "..####..", ".##.###.", "...##...", "...##...", "...##...", "........", "........", "........", "........"],
    'skull': ["........", "..####..", ".######.", ".#.##.#.", ".######.", "..#..#..", "..####..", "........", "........", "........"],
    'heart': ["........", ".##.##..", "#######.", "#######.", ".#####..", "..###...", "...#....", "........", "........", "........"],
}
ICON_ORDER = ['key', 'potion', 'sigil', 'flame', 'mend', 'coin', 'sword', 'shield', 'skull', 'heart']


def bar(n):
    rows = []
    for y in range(10):
        if y in (2, 3, 4, 5, 6):
            rows.append(''.join('#' if x < n else ('#' if y == 6 and x % 2 == 0 else '.') for x in range(8)))
        else:
            rows.append('.' * 8)
    return g(rows)


def bank14():
    out = list(font.glyphs())                  # 96
    names = {}
    for n in ICON_ORDER:
        names[n] = 0x80 + len(out)
        out.append(g(ICONS[n]))
    for i in range(9):
        names['bar%d' % i] = 0x80 + len(out)
        out.append(bar(i))
    for k in FRAME_ORDER:
        names['f' + k] = 0x80 + len(out)
        out.append(frame_glyph(k))
    assert len(out) <= 128, len(out)
    return out, names


# ---- the frame: a double rule. '=' horizontal, '|' vertical.
def frame_glyph(kind):
    E = ['.' * 8 for _ in range(10)]
    rows = [list(r) for r in E]

    def hl(y, x0=0, x1=8):
        for x in range(x0, x1):
            rows[y][x] = '#'

    def vl(x, y0=0, y1=10):
        for y in range(y0, y1):
            rows[y][x] = '#'
    if kind == 'H':
        hl(3)
        hl(6)
        rows[4][3] = rows[5][4] = '#'
    elif kind == 'V':
        vl(2)
        vl(5)
        rows[4][3] = rows[5][4] = '#'
    elif kind in ('TL', 'TR', 'BL', 'BR', 'X', 'TD', 'TU', 'TRt', 'TLt'):
        # a knot: a ring with the rules running out of it
        ring = ["........", "..####..", ".#....#.", "#..##..#", "#.#..#.#", "#.#..#.#", "#..##..#", ".#....#.", "..####..", "........"]
        rows = [list(r) for r in ring]
        out_r = kind in ('TL', 'BL', 'X', 'TD', 'TU', 'TRt')
        out_l = kind in ('TR', 'BR', 'X', 'TD', 'TU', 'TLt')
        out_d = kind in ('TL', 'TR', 'X', 'TD', 'TRt', 'TLt')
        out_u = kind in ('BL', 'BR', 'X', 'TU', 'TRt', 'TLt')
        if out_r:
            rows[3][7] = rows[6][7] = '#'
        if out_l:
            rows[3][0] = rows[6][0] = '#'
        if out_d:
            rows[9][2] = rows[9][5] = '#'
        if out_u:
            rows[0][2] = rows[0][5] = '#'
    elif kind == 'RUNE':
        rows = [list(r) for r in ["........", "...#....", "..###...", ".#.#.#..", "...#....", "..#.#...", ".#...#..", "........", "........", "........"]]
    elif kind == 'DOT':
        rows = [list(r) for r in ["........", "........", "........", "........", "...##...", "...##...", "........", "........", "........", "........"]]
    return g([''.join(r) for r in rows])


FRAME_ORDER = ['H', 'V', 'TL', 'TR', 'BL', 'BR', 'X', 'TD', 'TU', 'TRt', 'TLt', 'RUNE', 'DOT']


def bank15():
    return [], {}


def inc_lines():
    _, n14 = bank14()
    _, n15 = bank15()
    L = []
    for k, v in n14.items():
        if k.startswith('f') and k[1:] in FRAME_ORDER:
            L.append('F_%s EQU $%02X' % (k[1:].upper(), v))
        else:
            L.append('I_%s EQU $%02X' % (k.upper(), v))
    return L
