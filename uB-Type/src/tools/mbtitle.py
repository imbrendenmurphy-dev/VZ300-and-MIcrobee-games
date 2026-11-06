"""uB-TYPE front-end artwork: the title logo, the planet horizon, the big
two-cell font, the crossing ship and the capsule icons.

Art is drawn as a full-colour picture (one Premium colour per pixel) and then
converted to PCG cells: each 8x16 cell gets the two colours it uses most,
the brighter one as ink, so the same glyphs read correctly on a monochrome
monitor (which lights ink pixels whatever their colour)."""
import math
import numpy as np
from mbart import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY,
                   DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE)

# perceived brightness of the 16 colours (for ink/paper order)
LUM = [0, 3, 5, 6, 1, 4, 7, 9, 2, 8, 10, 13, 6, 9, 12, 15]

# ------------------------------------------------------------------ logo
# letters on a unit grid, 7 wide x 8 tall (mu has a descender row).
# '#' full unit; corner chamfers: '/' fills the lower-right half,
# '\' the lower-left half, 'L' the upper-right half, 'J' the upper-left half
LETTERS = {
    'mu': ["##...##",
           "##...##",
           "##...##",
           "##...##",
           "##...##",
           "##...##",
           "##...##",
           "######J",
           "##.....",
           "##....."],
    'B': ["######\\",
          "##...##",
          "##...##",
          "#####J.",
          "######\\",
          "##...##",
          "##...##",
          "######J"],
    '-': [".....",
          ".....",
          ".....",
          "#####",
          "#####",
          ".....",
          ".....",
          "....."],
    'T': ["#######",
          "#######",
          "..###..",
          "..###..",
          "..###..",
          "..###..",
          "..###..",
          "..###.."],
    'Y': ["##...##",
          "##...##",
          "##...##",
          "L##.##J",
          ".L###J.",
          "..###..",
          "..###..",
          "..###.."],
    'P': ["######\\",
          "##...##",
          "##...##",
          "##...##",
          "######J",
          "##.....",
          "##.....",
          "##....."],
    'E': ["/######",
          "##.....",
          "##.....",
          "#####..",
          "#####..",
          "##.....",
          "##.....",
          "L######"],
}
UW, UH = 9, 6          # unit size in Microbee pixels (a pixel is ~1.8x taller than wide)
SLANT = 0.3           # italic: x shift per pixel of height


def unit_fill(ch, fx, fy):
    """is the point (fx, fy) in 0..1 inside the unit drawn as ch"""
    if ch == '#':
        return True
    if ch == '/':
        return fx + fy >= 1
    if ch == '\\':
        return fy >= fx
    if ch == 'L':
        return fx >= fy
    if ch == 'J':
        return fx + fy <= 1
    return False


def letter_mask(name):
    rows = LETTERS[name]
    h, w = len(rows) * UH, len(rows[0]) * UW
    m = np.zeros((h, w), bool)
    for y in range(h):
        for x in range(w):
            ch = rows[y // UH][x // UW]
            m[y, x] = unit_fill(ch, (x % UW + 0.5) / UW, (y % UH + 0.5) / UH)
    return m


# colour of each 16-pixel band of the logo, top to bottom (cap height = 4 rows)
LOGO_BANDS = [WHITE, YELLOW, BRED, BRED]
LOGO_ROW0 = 1          # first screen row of the logo


def logo(img):
    """draw the logo into img (screen-sized colour picture); returns its cell
    rectangle (col0, col1, row0, row1)"""
    names = ['mu', 'B', '-', 'T', 'Y', 'P', 'E']
    masks = [letter_mask(n) for n in names]
    gap = 8
    total = sum(m.shape[1] for m in masks) + gap * (len(masks) - 1) + int(SLANT * 48)
    x0 = (512 - total) // 2
    y0 = LOGO_ROW0 * 16
    xs = x0
    full = np.zeros((96, 512), bool)
    for m in masks:
        h, w = m.shape
        for y in range(h):
            sh = int(round(SLANT * (47 - min(y, 47))))
            for x in range(w):
                if m[y, x]:
                    xx = xs + x + sh
                    if 0 <= xx < 512:
                        full[y, xx] = True
        xs += w + gap
    # chrome: each 16-line band one colour; the band's last lines are
    # thinning rules, and a dark line rides 2 px inside the top edge
    for y in range(64):
        band = y // 16
        l = y % 16
        on_line = l < 11 or l in (12, 14)
        for x in range(512):
            if full[y, x]:
                edge_top = y > 0 and not full[y - 1, x]
                inner = 0 < y and full[y - 1, x] and y > 1 and not full[y - 2, x]
                if on_line and not inner:
                    img[y0 + y, x] = LOGO_BANDS[band]
                elif edge_top:
                    img[y0 + y, x] = LOGO_BANDS[band]
    cols = np.where(full.any(axis=0))[0]
    return int(cols.min()) // 8, int(cols.max()) // 8 + 1


# ------------------------------------------------------------------ horizon
HZ_ROW0 = 12            # planet limb across rows 12-13


def horizon(img):
    """a planet's edge across the bottom of the title page"""
    R = 700.0
    cx, cy = 330.0, HZ_ROW0 * 16 + 6 + R
    for y in range(HZ_ROW0 * 16, HZ_ROW0 * 16 + 32):
        for x in range(512):
            # pixels are ~1.8x taller than wide
            d = math.hypot((x - cx), (y - cy) * 1.8)
            depth = (R * 1.8 - d) / 1.8          # lines inside the limb
            if depth < 0:
                continue
            col = BCYAN if y < HZ_ROW0 * 16 + 16 else CYAN
            if depth < 1.2:
                img[y, x] = col                  # the lit rim
            else:
                # atmosphere glow fading into cloud bands
                v = 0.5 + 0.5 * math.sin(x / 19.0 + depth * 0.9) * math.sin(x / 53.0 - depth * 0.3)
                dens = max(0.0, 0.8 - depth / 12.0) + 0.35 * v
                bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
                if dens * 16 > bayer[y & 3][x & 3]:
                    img[y, x] = col


# ------------------------------------------------------------------ converter
def to_cells(img, rows=range(16)):
    """picture -> {(row, col): (glyph bytes, colour byte)} for every cell
    that has anything in it"""
    out = {}
    for r in rows:
        for c in range(64):
            blk = img[r * 16:r * 16 + 16, c * 8:c * 8 + 8]
            if not blk.any():
                continue
            vals, cnt = np.unique(blk, return_counts=True)
            order = sorted(zip(cnt, vals), reverse=True)
            if len(order) == 1:
                ink, paper = int(order[0][1]), BLACK
            else:
                a, b = int(order[0][1]), int(order[1][1])
                if BLACK in (a, b):
                    ink, paper = (b if a == BLACK else a), BLACK
                    # a third colour joins the ink if it is not black
                else:
                    ink, paper = (a, b) if LUM[a] >= LUM[b] else (b, a)
            g = []
            for y in range(16):
                byte = 0
                for x in range(8):
                    v = int(blk[y, x])
                    if v == BLACK and paper == BLACK:
                        continue
                    if v == ink:
                        on = True
                    elif v == paper:
                        on = False
                    else:     # nearest of the two by brightness
                        on = abs(LUM[v] - LUM[ink]) < abs(LUM[v] - LUM[paper])
                    if on:
                        byte |= 0x80 >> x
                g.append(byte)
            out[(r, c)] = (bytes(g), (paper << 4) | ink)
    return out


def title_picture():
    img = np.zeros((256, 512), np.uint8)
    lc0, lc1 = logo(img)
    horizon(img)
    return img, (lc0, lc1)


# ------------------------------------------------------------------ big font
def big_font():
    """2 x 2 cell letters (16 x 32 pixels) from the game font: each font
    pixel becomes 2 x 3; returns {char: [g00, g01, g10, g11]}"""
    import mbfont
    out = {}
    chars = ' ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.!:'
    for ch in chars:
        # the game font's 7 x 9 letter at 2 x 3: 14 x 27 in 16 x 32, with
        # every third line dark (each font row keeps two lit lines)
        g = np.array(mbfont.glyph57(ch, top=0), np.uint8) if ch != ' ' else np.zeros((16, 8), np.uint8)
        big = np.kron(g[:9, :7], np.ones((3, 2), np.uint8))
        big[2::3, :] = 0
        pic = np.zeros((32, 16), np.uint8)
        pic[3:30, 1:15] = big
        cells = []
        for r in range(2):
            for c in range(2):
                sub = pic[r * 16:r * 16 + 16, c * 8:c * 8 + 8]
                cells.append(bytes(int(''.join(str(int(v)) for v in row), 2) for row in sub))
        out[ch] = cells
    return chars, out


if __name__ == '__main__':
    from PIL import Image
    from mbee import PALETTE
    img, _ = title_picture()
    cells = to_cells(img)
    pal = np.array(PALETTE, np.uint8)
    out = np.zeros((256, 512, 3), np.uint8)
    mono = np.zeros((256, 512, 3), np.uint8)
    for (r, c), (g, col) in cells.items():
        for y in range(16):
            for x in range(8):
                on = g[y] & (0x80 >> x)
                out[r * 16 + y, c * 8 + x] = pal[col & 15] if on else pal[col >> 4]
                mono[r * 16 + y, c * 8 + x] = (255, 176, 0) if on else (0, 0, 0)
    both = np.concatenate([out, mono], 0)
    Image.fromarray(both).resize((1024, int(512 * 1.83 * 2)), Image.NEAREST).save('/tmp/claude-0/s/title.png')
    print(len(cells), 'cells', len(set(g for g, c in cells.values())), 'glyphs')
