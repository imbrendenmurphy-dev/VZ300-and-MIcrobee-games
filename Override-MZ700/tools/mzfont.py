# MZ-700 character ROM helpers + screen renderer (European CG-ROM, MAME dump).
# Glyph index g: 0..255 = set 1 (attr bit7=0), 256..511 = set 2 (attr bit7=1).
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROMFILE = os.path.join(HERE, '..', 'rom', 'mz700fon.int')
_rom = open(ROMFILE, 'rb').read()
assert len(_rom) == 4096

PAL = [(0, 0, 0), (0, 0, 255), (255, 0, 0), (255, 0, 255),
       (0, 255, 0), (0, 255, 255), (255, 255, 0), (255, 255, 255)]
BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE = range(8)


def glyph_bits(g):
    """8 rows of 8 ints (1=foreground), leftmost pixel first."""
    return [[(_rom[g * 8 + y] >> x) & 1 for x in range(8)] for y in range(8)]


def attr(g, fg, bg):
    return ((g >> 8) << 7) | (fg << 4) | bg


def render_cells(chars, attrs, cols=40, rows=25, scale=2):
    """chars/attrs: flat lists of display codes and attribute bytes."""
    im = Image.new('RGB', (cols * 8, rows * 8))
    px = im.load()
    for r in range(rows):
        for c in range(cols):
            ch = chars[r * cols + c]
            at = attrs[r * cols + c]
            g = ch | ((at & 0x80) << 1)
            fg = PAL[(at >> 4) & 7]
            bg = PAL[at & 7]
            base = g * 8
            for y in range(8):
                b = _rom[base + y]
                for x in range(8):
                    px[c * 8 + x, r * 8 + y] = fg if (b >> x) & 1 else bg
    if scale != 1:
        im = im.resize((cols * 8 * scale, rows * 8 * scale), Image.NEAREST)
    return im


# Display codes for the ASCII-ish text used in the HUD (MZ display code table)
def text_codes(s):
    out = []
    for ch in s.upper():
        if 'A' <= ch <= 'Z':
            out.append(ord(ch) - 64)
        elif '0' <= ch <= '9':
            out.append(0x20 + ord(ch) - 48)
        elif ch == ' ':
            out.append(0x00)
        elif ch == '-':
            out.append(0x2A)
        elif ch == '=':
            out.append(0x2B)
        elif ch == '.':
            out.append(0x2E)
        elif ch == ',':
            out.append(0x2F)
        elif ch == ':':
            out.append(0x4F)
        elif ch == '!':
            out.append(0x61)
        elif ch == '?':
            out.append(0x49)
        elif ch == '/':
            out.append(0x2D)
        else:
            out.append(0x00)
    return out
