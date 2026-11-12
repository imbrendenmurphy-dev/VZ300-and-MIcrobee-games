#!/usr/bin/env python3
"""
mklogo.py - the BEELINE title logo: heavy italic letters with racing
speed-cuts, rendered for 8x16 character cells (3 rows).  Imported by mkgfx.
ViBED by BPM 2026
"""
import os
from PIL import Image, ImageDraw, ImageFont

FONT = '/usr/share/fonts/truetype/google-fonts/Poppins-BoldItalic.ttf'
ROWS = 3
COLS = 32

def render():
    """-> list of ROWS lists of COLS cells: 16 scanline bytes or None (empty)"""
    W, H = COLS * 8, ROWS * 16
    big = Image.new('L', (W * 4, int(H * 1.5) * 4), 0)
    d = ImageDraw.Draw(big)
    size = 200
    while True:
        f = ImageFont.truetype(FONT, size)
        bb = d.textbbox((0, 0), 'BEELINE', font=f)
        if bb[2] - bb[0] <= W * 4 - 24 and bb[3] - bb[1] <= int(H * 1.5) * 4 - 8: break
        size -= 2
    x = (W * 4 - (bb[2] - bb[0])) // 2 - bb[0]
    y = (int(H * 1.5) * 4 - (bb[3] - bb[1])) // 2 - bb[1]
    d.text((x, y), 'BEELINE', font=f, fill=255)
    # screen pixels are 1.5x taller than wide: squash
    img = big.resize((W, H), Image.LANCZOS)
    px = img.load()
    on = [[px[xx, yy] > 110 for xx in range(W)] for yy in range(H)]
    # speed cuts: thin gaps through the lower half, growing towards the bottom
    top = min(yy for yy in range(H) if any(on[yy]))
    bot = max(yy for yy in range(H) if any(on[yy]))
    hgt = bot - top + 1
    for yy in range(top, bot + 1):
        t = (yy - top) / hgt
        if t > 0.58 and (yy - top) % 5 == 4:
            on[yy] = [False] * W
    rows = []
    for r in range(ROWS):
        cells = []
        for c in range(COLS):
            data = []
            for l in range(16):
                b = 0
                for k in range(8):
                    if on[r * 16 + l][c * 8 + k]: b |= 0x80 >> k
                data.append(b)
            cells.append(data if any(data) else None)
        rows.append(cells)
    return rows

if __name__ == '__main__':
    rows = render()
    out = Image.new('RGB', (COLS * 8, ROWS * 16 * 2))
    for r, cells in enumerate(rows):
        for c, data in enumerate(cells):
            if not data: continue
            for l, b in enumerate(data):
                for k in range(8):
                    if b & (0x80 >> k):
                        for dy in range(2): out.putpixel((c * 8 + k, (r * 16 + l) * 2 + dy), (255, 220, 0))
    out = out.resize((COLS * 8 * 3, ROWS * 32 * 3 // 2))
    out.save('build/logo_preview.png')
    print(sum(1 for cells in rows for d in cells if d), 'cells')
