"""Mode 0 / mode 1 VRAM -> PNG preview using the MC6847 font + VZ palette (matches vzemu)."""
import os
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
FONT = [int(l, 16) for l in open(os.path.join(HERE, 'font.txt')) if l.strip()]
PAL = [(0x07, 0xFF, 0x00), (0xFF, 0xFF, 0x00), (0x3B, 0x08, 0xFF), (0xCC, 0x00, 0x3B),
       (0xFF, 0xFF, 0xFF), (0x07, 0xE3, 0x99), (0xFF, 0x1C, 0xFF), (0xFF, 0x81, 0x00),
       (0, 0, 0), (0x00, 0x3A, 0x00), (0x48, 0x1A, 0x00), (0xFF, 0xA0, 0x30)]
BLACK, DKGREEN, DKORANGE, BRORANGE = 8, 9, 10, 11


def mode0(vram, css=1, scale=2, rows=16):
    img = Image.new('RGB', (256, rows * 12))
    px = img.load()
    for r in range(rows):
        for c in range(32):
            b = vram[r * 32 + c]
            for y in range(12):
                for x in range(8):
                    if b & 0x80:
                        top = y < 6
                        bit = (3 if x < 4 else 2) if top else (1 if x < 4 else 0)
                        col = ((b >> 4) & 7) if b & (1 << bit) else BLACK
                    else:
                        f = FONT[(b & 0x7F) * 12 + y]
                        on = (f >> (7 - x)) & 1
                        col = (BRORANGE if css else 0) if on else (DKORANGE if css else DKGREEN)
                    px[c * 8 + x, r * 12 + y] = PAL[col]
    return img.resize((256 * scale, rows * 12 * scale), Image.NEAREST)


def mode1(vram, css=1, scale=2):
    img = Image.new('RGB', (128, 64))
    px = img.load()
    for y in range(64):
        for x in range(128):
            b = vram[y * 32 + x // 4]
            p = (b >> (6 - 2 * (x % 4))) & 3
            px[x, y] = PAL[(4 if css else 0) + p]
    return img.resize((256 * scale, 192 * scale), Image.NEAREST)
