"""ROBOT RIOT 2086 title logo: a stylised 80s chrome-style font.

Letters are drawn on a coarse grid (5 x 7 blocks), every block becoming
CW x CH pixels; outside corners are chamfered at 45 degrees; the lower
half gets venetian-blind stripes that widen towards the bottom (the old
chrome-logo look); the whole thing leans forward (italic) and throws a
dotted drop shadow down and to the right. "2086" is drawn hollow."""
import numpy as np

# '#' a full block; a b c d a block with its top-left, top-right,
# bottom-left or bottom-right corner cut at 45 degrees
GRID = {
    'R': ["####b", "#...#", "#...#", "####d", "#..b.", "#...b", "#...#"],
    'O': ["a###b", "#...#", "#...#", "#...#", "#...#", "#...#", "c###d"],
    'B': ["####b", "#...#", "#...#", "####.", "#...b", "#...#", "####d"],
    'T': ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    'I': ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    '2': ["a###b", "....#", "....#", "a###d", "#....", "#....", "#####"],
    '0': ["a###b", "#...#", "#..##", "#.#.#", "##..#", "#...#", "c###d"],
    '8': ["a###b", "#...#", "#...#", "a###b", "#...#", "#...#", "c###d"],
    '6': ["a###b", "#....", "#....", "####b", "#...#", "#...#", "c###d"],
    ' ': [".", ".", ".", ".", ".", ".", "."],
}


def letter(ch, cw, chh, stroke=None):
    """one letter: blocks to pixels, the marked corners cut at 45 degrees"""
    g = GRID[ch]
    gh, gw = len(g), len(g[0])
    img = np.zeros((gh * chh, gw * cw), bool)
    k = min(cw, chh) - 2
    for y in range(gh):
        for x in range(gw):
            c = g[y][x]
            if c == '.':
                continue
            blk = np.ones((chh, cw), bool)
            for i in range(k):
                for j in range(k - i):
                    if c == 'a':
                        blk[i, j] = False
                    if c == 'b':
                        blk[i, cw - 1 - j] = False
                    if c == 'c':
                        blk[chh - 1 - i, j] = False
                    if c == 'd':
                        blk[chh - 1 - i, cw - 1 - j] = False
            img[y * chh:(y + 1) * chh, x * cw:(x + 1) * cw] = blk
    return img


def word(text, cw, chh, stroke, gap):
    parts = []
    for c in text:
        L = letter(c, cw, chh, stroke)
        parts.append(L)
        parts.append(np.zeros((L.shape[0], gap), bool))
    return np.concatenate(parts[:-1], axis=1)


def stylise(a, lean=5, shadow=(3, 2), stripes=True, hollow=False):
    h, w = a.shape
    if hollow:                                      # outline only
        inner = a.copy()
        inner[1:-1, 1:-1] = a[1:-1, 1:-1] & a[:-2, 1:-1] & a[2:, 1:-1] & a[1:-1, :-2] & a[1:-1, 2:]
        inner[0, :] = inner[-1, :] = False
        a = a & ~inner
    if stripes:                                     # venetian blinds below the middle
        y = h * 3 // 5
        gap = 4
        while y < h:
            a[y, :] = False
            y += gap
            gap = max(2, gap - 1)
    out = np.zeros((h + shadow[1], w + h // lean + shadow[0] + 1), bool)
    sh = np.zeros_like(out)
    for y in range(h):
        dx = (h - 1 - y) // lean                    # lean forward
        out[y, dx:dx + w] |= a[y]
        sh[y + shadow[1], dx + shadow[0]:dx + shadow[0] + w] |= a[y]
    # the drop shadow: a dotted copy where the letters are not
    yy, xx = np.indices(out.shape)
    dots = ((yy + xx) % 2 == 0)
    return out | (sh & ~out & dots)


def title_logo():
    """(main logo array, 2086 array)"""
    main = stylise(word('ROBOT RIOT', 5, 5, 3, 4), lean=5)
    year = stylise(word('2086', 5, 4, 3, 5), lean=6, shadow=(2, 1), stripes=False, hollow=True)
    return main, year


if __name__ == '__main__':
    from PIL import Image
    m, y = title_logo()
    print(m.shape, y.shape)
    W = 320
    img = np.zeros((96, W), np.uint8)
    img[2:2 + m.shape[0], (W - m.shape[1]) // 2:(W - m.shape[1]) // 2 + m.shape[1]] = m * 255
    img[48:48 + y.shape[0], (W - y.shape[1]) // 2:(W - y.shape[1]) // 2 + y.shape[1]] = y * 255
    Image.fromarray(img).resize((W * 3, 96 * 4), Image.NEAREST).save('/tmp/claude-0/-home-claude/4aa4c1d5-2769-5914-a6a4-7f2bee245b03/scratchpad/logo.png')
