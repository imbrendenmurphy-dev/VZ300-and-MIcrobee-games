"""Shared graphics helpers for the megademo asset generators.

The Microbee Premium screen: cells of 8 x 16 (or fewer) lines; each cell
has a code (screen RAM: 80h | glyph), an attribute (PCG bank, b0-3) and a
colour (paper << 4 | ink). PCG: 16 banks x 128 glyphs x 16 bytes.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
PREV = BUILD / 'preview'

BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)
PAL = np.array([(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192),
                (192, 192, 192), (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255),
                (255, 64, 255), (64, 255, 255), (255, 255, 255)], np.uint8)
# perceived brightness (for mono and for choosing shades)
LUM = np.array([0, 60, 90, 100, 40, 85, 120, 170, 85, 150, 200, 235, 125, 175, 215, 255])

# permanent PCG banks
BK_PAT0, BK_PAT1, BK_FONT = 13, 14, 15     # line-0 patterns 00-7F, 80-FF; the font

FONTFILE = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf'


def font8x16():
    """96 glyphs (ASCII 32-127) of 16 bytes: bold, 7 px wide + a gap"""
    f = ImageFont.truetype(FONTFILE, 15)
    asc = f.getmetrics()[0]
    out = np.zeros((96, 16), np.uint8)
    for i in range(96):
        ch = chr(32 + i)
        im = Image.new('L', (12, 16), 0)
        d = ImageDraw.Draw(im)
        bb = f.getbbox(ch)
        w = bb[2] - bb[0]
        d.text((1 + (7 - w) // 2 - bb[0], 13 - asc), ch, font=f, fill=255)
        a = np.array(im)[:, 1:8] > 110          # 7 columns, column 0 left blank
        bits = np.zeros((16, 8), bool)
        bits[:, 0:7] = a
        out[i] = np.packbits(bits, axis=1)[:, 0]
    # hand-drawn: M and W (too narrow for the typeface at 7 pixels)
    hand = {
        'M': ['##...##', '###.###', '#######', '##.#.##', '##.#.##', '##...##', '##...##', '##...##',
              '##...##', '##...##', '##...##'],
        'W': ['##...##', '##...##', '##...##', '##...##', '##...##', '##.#.##', '##.#.##', '#######',
              '###.###', '###.###', '##...##'],
    }
    for ch, rows in hand.items():
        g = [0] * 16
        for i, r in enumerate(rows):
            g[2 + i] = int(r.replace('#', '1').replace('.', '0') + '0', 2)
        out[ord(ch) - 32] = g
    # a solid block (127) and a heart (126 '~' replaced)
    heart = ['........', '........', '........', '.##.##..', '#######.', '#######.', '#######.', '.#####..',
             '..###...', '...#....', '........', '........', '........', '........', '........', '........']
    out[126 - 32] = [int(r.replace('#', '1').replace('.', '0'), 2) for r in heart]
    out[127 - 32] = 0xFE
    return out


def glyph_bits(g):
    """16 bytes -> 16 x 8 bool"""
    if isinstance(g, (bytes, bytearray)):
        g = np.frombuffer(bytes(g), np.uint8)
    return np.unpackbits(np.asarray(g, np.uint8)[:, None], axis=1).astype(bool)


def cells_from_bitmap(bits, ink, paper, ch=16):
    """bits (H x W bool), ink/paper (H/ch x W/8) -> list of (glyph bytes, colour) per cell, row-major"""
    H, W = bits.shape
    out = []
    for cy in range(H // ch):
        for cx in range(W // 8):
            b = bits[cy * ch:(cy + 1) * ch, cx * 8:(cx + 1) * 8]
            g = np.packbits(b, axis=1)[:, 0]
            if ch < 16:
                g = np.concatenate([g, np.zeros(16 - ch, np.uint8)])
            out.append((bytes(g), (int(paper[cy, cx]) << 4) | int(ink[cy, cx])))
    return out


class Glyphs:
    """allocates PCG glyphs in a set of banks, sharing identical ones"""

    def __init__(self, banks):
        self.banks = list(banks)
        self.data = {b: bytearray(2048) for b in self.banks}
        self.used = {}
        self.n = 0

    def add(self, g16):
        g16 = bytes(g16)
        if g16 in self.used:
            return self.used[g16]
        if self.n >= 128 * len(self.banks):
            raise ValueError('PCG banks %s full' % self.banks)
        b = self.banks[self.n // 128]
        k = self.n % 128
        self.data[b][k * 16:(k + 1) * 16] = g16
        self.used[g16] = (b, 0x80 | k)
        self.n += 1
        return self.used[g16]

    def fixed(self, bank, k, g16):
        """put a glyph at a fixed place (no sharing)"""
        self.data[bank][k * 16:(k + 1) * 16] = bytes(g16)
        return (bank, 0x80 | k)


class Screen:
    """2K cells of code / attr / colour (colour and mono variants)"""

    def __init__(self):
        self.code = np.full(2048, 0x80, np.uint8)
        self.attr = np.full(2048, BK_PAT0, np.uint8)
        self.col = np.zeros(2048, np.uint8)
        self.mcol = np.zeros(2048, np.uint8)
        self.owner = [''] * 2048

    def put(self, addr, bank, code, col, mcol=None, who='?'):
        a = addr & 0x7FF
        self.code[a] = code
        self.attr[a] = bank
        self.col[a] = col
        self.mcol[a] = col if mcol is None else mcol
        self.owner[a] = who

    def region_free(self, a, n):
        return all(self.owner[(a + i) & 0x7FF] == '' for i in range(n))


def render_cells(scr, pcg, start, rows, cols=64, lines=16, mono=False):
    """preview: rows x cols cells from start, lines per row -> RGB"""
    img = np.zeros((rows * lines, cols * 8, 3), np.uint8)
    for r in range(rows):
        for c in range(cols):
            a = (start + r * cols + c) & 0x7FF
            code, bank = int(scr.code[a]), int(scr.attr[a])
            col = int(scr.mcol[a] if mono else scr.col[a])
            g = pcg[bank][(code & 0x7F) * 16:(code & 0x7F) * 16 + 16] if code & 0x80 else bytes(16)
            bits = glyph_bits(g)[:lines]
            ink, paper = PAL[col & 15], PAL[col >> 4]
            img[r * lines:(r + 1) * lines, c * 8:(c + 1) * 8] = np.where(bits[:, :, None], ink, paper)
    return img


def save_png(path, rgb, scale=1, aspect=1.5):
    """aspect: a pixel's height / width on the Microbee's 4:3 screen (~1.5)"""
    PREV.mkdir(parents=True, exist_ok=True)
    im = Image.fromarray(rgb)
    im = im.resize((im.width * scale, int(im.height * scale * aspect)), Image.NEAREST)
    im.save(path)
