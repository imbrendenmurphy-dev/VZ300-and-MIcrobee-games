"""uB-TYPE text font: a 70s 'future' face (see font70.py) drawn 7 x 9 in the
8 x 16 Premium cell, plus the Greek mu used in the title and the HUD glyphs."""
import numpy as np
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import font70

def glyph57(ch, bold=True, top=3):
    """the game's text glyph (8 x 16 cell): the 70s 'future' design from
    font70.py, 7 x 9 pixels at row TOP. Strokes are 2 pixels wide; the
    left-hand stroke doubles to 3 from the middle down, the style's mark."""
    g = np.zeros((16, 8), np.uint8)
    rows = font70.S.get(ch, font70.S[' '])
    for y, row in enumerate(rows):
        if len(row) == 7:                     # drawn literally
            for x, c in enumerate(row):
                g[top + y, x] = c != '.'
            continue
        for x, c in enumerate(row):
            if c == '.':
                continue
            thick = c == '@' or (x == 0 and y >= 4)
            w = 1 if c == '+' else (3 if thick else 2)
            g[top + y, x:x + w] = 1
    if ch == 'mu':
        g[top + 9:top + 12, 0:3] = 1          # descender
    return g


def pack(g):
    return bytes(int(''.join(str(int(v)) for v in row), 2) for row in g)


def font_bank():
    """bank 0: 0-63 ASCII 32..95, 64-72 meter 0..8 px, 73-74 ship icon,
    75/76 pip on/off, 77/78 meter brackets, 79 mu, 80-95 stars."""
    b = bytearray(2048)
    for c in range(32, 96):
        b[(c - 32) * 16:(c - 32) * 16 + 16] = pack(glyph57(chr(c)))
    for k in range(9):
        g = np.zeros((16, 8), np.uint8)
        g[5:11, :k] = 1
        g[5, :] = 1 if False else g[5, :]
        b[(64 + k) * 16:(64 + k) * 16 + 16] = pack(g)
    # ship icon: 16 x 16 two cells
    icon = ["................",
            "................",
            "................",
            "....##..........",
            ".....###........",
            "..########......",
            ".#############..",
            "################",
            ".#############..",
            "..########......",
            ".....###........",
            "....##..........",
            "................",
            "................",
            "................",
            "................"]
    for h in range(2):
        g = np.array([[1 if ch == '#' else 0 for ch in r[h * 8:h * 8 + 8]] for r in icon], np.uint8)
        b[(73 + h) * 16:(73 + h) * 16 + 16] = pack(g)
    pip_on = np.zeros((16, 8), np.uint8)
    for y in range(4, 12):
        w = 4 - abs(y - 7.5) // 1
        pip_on[y, 1:1 + int(max(1, 4 - abs(y - 7.5)) * 1.5)] = 1
    b[75 * 16:76 * 16] = pack(pip_on)
    pip_off = np.zeros((16, 8), np.uint8)
    pip_off[7:9, 1:3] = 1
    b[76 * 16:77 * 16] = pack(pip_off)
    lb = np.zeros((16, 8), np.uint8)
    lb[3:13, 6] = 1
    lb[3, 6:8] = 1
    lb[12, 6:8] = 1
    b[77 * 16:78 * 16] = pack(lb)
    b[78 * 16:79 * 16] = pack(lb[:, ::-1])
    b[79 * 16:80 * 16] = pack(glyph57('mu'))
    # stars: 8 positions (x 0/4, y 0/4/8/12) x 2 sizes
    for k in range(16):
        g = np.zeros((16, 8), np.uint8)
        x = 1 + 4 * (k & 1)
        y = 1 + 4 * ((k >> 1) & 3)
        if k < 8:
            g[y, x] = 1
        else:
            g[y:y + 2, x] = 1
            g[y, x - 1:x + 2] = 1
        b[(80 + k) * 16:(80 + k) * 16 + 16] = pack(g)
    return bytes(b)
