"""fontzoom.py - big labelled view of part of the MZ-700 CG-ROM.

    py tools/fontzoom.py bank first last out.png
"""
import os
import sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rom = open(os.path.join(ROOT, 'rom', 'mz700fon.int'), 'rb').read()
bank, first, last = int(sys.argv[1]), int(sys.argv[2], 16), int(sys.argv[3], 16)
S = 6
cols = 16
n = last - first + 1
rows = (n + cols - 1) // cols
im = Image.new('RGB', (cols * (8 * S + 6) + 4, rows * (8 * S + 16) + 4), (40, 40, 40))
d = ImageDraw.Draw(im)
for i in range(n):
    code = first + i
    g = rom[(bank * 256 + code) * 8:(bank * 256 + code) * 8 + 8]
    ox = 4 + (i % cols) * (8 * S + 6)
    oy = 4 + (i // cols) * (8 * S + 16)
    d.text((ox, oy), '%02X' % code, fill=(255, 200, 0))
    for y in range(8):
        for x in range(8):
            on = (g[y] >> x) & 1
            d.rectangle((ox + x * S, oy + 12 + y * S, ox + x * S + S - 1, oy + 12 + y * S + S - 1),
                        fill=(255, 255, 255) if on else (0, 0, 110))
im.save(sys.argv[4])
