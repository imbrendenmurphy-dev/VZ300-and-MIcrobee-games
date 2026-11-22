"""RUNE AMOK title logo -> build/TITLE.BNK

The word RUNE AMOK built from the game font, scaled up, its corners
rounded, a bevel cut along its edges, then dithered and coloured by cell
rows from gold to ember (one ink per cell, as everywhere else).
Block layout: +0 dw glyph count, +2 db first row, rows, first column,
columns, then codes, attributes and colours (row by row), then glyphs.
"""
import numpy as np
from pathlib import Path
from PIL import Image, ImageFilter
import font
import tiles as T
from walls import YELLOW, BRED, RED, WHITE, BROWN
import views as V

ROOT = Path(__file__).resolve().parent.parent
WORD = 'RUNE AMOK'
SX, SY = 4, 6
COLS, ROWS = 36, 5          # the logo region in cells
C0, R0 = 2, 1


def build():
    W, H = COLS * 8, ROWS * 10
    big = np.zeros((H * 4, W * 4), np.uint8)
    x = 2 * 4
    for ch in WORD:
        if ch == ' ':
            x += 14 * 4
            continue
        g = font.FONT[ch]
        for r in range(10):
            for c in range(8):
                if g[r] >> (7 - c) & 1:
                    y0 = ((r - 1) * SY) * 4 + 3 * 4
                    x0 = x + (c * SX) * 4 - 4 * 4
                    if y0 >= 0:
                        big[y0:y0 + SY * 4, x0:x0 + SX * 4] = 255
        x += 32 * 4 + 1 * 4
    im = Image.fromarray(big).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(5))
    a = np.array(im.resize((W, H), Image.BOX)) / 255.0
    solid = a > 0.45
    # bevel: lit from the top left
    gy, gx = np.gradient(a)
    light = np.clip(0.75 - 3.0 * (gy + gx), 0, 1.0)
    inner = a > 0.9
    lum = np.where(inner, 0.8, light)
    # a carved line through the middle of the strokes
    ys, xs = np.mgrid[0:H, 0:W]
    th = V.BAYER4[ys % 4, xs % 4]
    on = solid & (lum > th * 0.9)
    D = T.Dict()
    ramp = [YELLOW, YELLOW, BRED, BRED, RED]
    codes, attrs, cols = [], [], []
    for r in range(ROWS):
        for c in range(COLS):
            blk = on[r * 10:r * 10 + 10, c * 8:c * 8 + 8]
            pat = bytes(int(sum(int(blk[i, j]) << (7 - j) for j in range(8))) for i in range(10))
            code, attr, col = D.tile(pat, ramp[r])
            codes.append(code)
            attrs.append(attr)
            cols.append(col)
    out = bytearray()
    out += len(D.pats).to_bytes(2, 'little')
    out += bytes([R0, ROWS, C0, COLS])
    out += bytes(codes) + bytes(attrs) + bytes(cols)
    out += D.blob()
    (ROOT / 'build' / 'TITLE.BNK').write_bytes(bytes(out))
    print('title logo: %d glyphs, %d bytes' % (len(D.pats), len(out)))
    return on


if __name__ == '__main__':
    on = build()
    Image.fromarray((on * 255).astype(np.uint8)).resize((on.shape[1] * 3, on.shape[0] * 3)).save(ROOT / 'build' / 'prev' / 'logo.png')
