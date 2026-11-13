"""GALAHXY title logo: 128 x LOGO_H, mode 1 CSS0 (0 green 1 yellow 2 blue 3 red).
Fat rounded letters in yellow with a red outline and a red drop shadow, a galah crest on the G,
on the blue sky. Drawn from a 5x7 'design grid' scaled to chunky cells."""
LOGO_H = 16
# 5 wide x 7 tall letter designs ('#' = ink)
L = {
'G': [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
'A': [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
'L': ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
'H': ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
'X': ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
'Y': ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
}
def build():
    W, H = 128, LOGO_H
    ink = [[0] * W for _ in range(H)]
    word = "GALAHXY"
    cw, ch = 3, 2                       # cell size: 3 px wide, 2 rows tall -> 15 x 14 letters
    x = 3; y0 = 1
    bounce = [0, 0, 0, 0, 0, 0, 0]
    for i, c in enumerate(word):
        g = L[c]
        for r, row in enumerate(g):
            for k, v in enumerate(row):
                if v == '#':
                    for yy in range(ch):
                        for xx in range(cw):
                            Y = y0 + bounce[i] + r * ch + yy; X = x + k * cw + xx
                            if 0 <= Y < H and 0 <= X < W: ink[Y][X] = 1
        x += 5 * cw + 2
    pix = [[1] * W for _ in range(H)]
    # shadow (down-right), outline, then ink
    for Y in range(H):
        for X in range(W):
            if ink[Y][X]:
                for dy, dx in ((1, 1), (1, 2), (0, 2)):
                    if Y + dy < H and X + dx < W: pix[Y + dy][X + dx] = 2
    for Y in range(H):
        for X in range(W):
            if ink[Y][X]:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        if 0 <= Y + dy < H and 0 <= X + dx < W and not ink[Y + dy][X + dx]: pix[Y + dy][X + dx] = 2
    for Y in range(H):
        for X in range(W):
            if ink[Y][X]: pix[Y][X] = 0
    # highlight stripe through the letters (green) for a bit of chrome
    for X in range(W):
        if ink[5][X]: pix[5][X] = 3
        if ink[6][X]: pix[6][X] = 3
    return pix

def asm():
    from vzpal import pack_rows
    b = pack_rows(build())
    L2 = ['LOGO_H equ %d' % LOGO_H, 'logo_data:']
    for i in range(0, len(b), 32): L2.append('            db ' + ','.join('$%02X' % v for v in b[i:i + 32]))
    return '\n'.join(L2) + '\n'

if __name__ == '__main__':
    import sys
    from vzpal import to_img
    p = build()
    to_img(p + [[1] * 128] * 4, 1).save(sys.argv[1])
