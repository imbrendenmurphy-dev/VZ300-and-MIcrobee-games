"""BELLARIUS graphics helpers (VIBED BY BPM 2026).

Everything is drawn in Python and packed into Microbee PCG glyphs of 8 x 8
pixels. Colours are the Premium Plus numbers:
0 black 1 red 2 green 3 brown 4 blue 5 magenta 6 cyan 7 grey
8 dark grey 9 bright red 10 bright green 11 yellow 12 bright blue
13 bright magenta 14 bright cyan 15 white
"""
import numpy as np

BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)
LUM = [0, 57, 113, 85, 22, 79, 135, 192, 96, 140, 190, 235, 90, 170, 215, 255]
PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]

STORE_TOP = 12          # banks 0..11 live in the 8-byte glyph store
G_FAST_TOP = 12 * 128   # ready-made glyphs are given out downwards from here (banks 10-11)
G_STAGE0 = 128          # stage scenery from bank 1 up


def grid(rows, sym='#'):
    """text rows -> bool array; any char in sym is set"""
    return np.array([[c in sym for c in r] for r in rows], bool)


def cell_bytes(bits, cx, cy):
    out = bytearray(8)
    for y in range(8):
        v = 0
        row = bits[cy * 8 + y]
        for x in range(8):
            if row[cx * 8 + x]:
                v |= 128 >> x
        out[y] = v
    return bytes(out)


def mono_of(pat, ink, paper):
    """a mono monitor shows only the pixel bits: where the paper is brighter
    than the ink the pattern is inverted so the picture reads the same"""
    if LUM[paper] > LUM[ink] + 20:
        return bytes(255 - b for b in pat)
    return pat


# ---------------------------------------------------------------- font
FD = {'A': "01110 10001 10001 11111 10001 10001 10001", 'B': "11110 10001 10001 11110 10001 10001 11110", 'C': "01110 10001 10000 10000 10000 10001 01110",
      'D': "11110 10001 10001 10001 10001 10001 11110", 'E': "11111 10000 10000 11110 10000 10000 11111", 'F': "11111 10000 10000 11110 10000 10000 10000",
      'G': "01110 10001 10000 10111 10001 10001 01111", 'H': "10001 10001 10001 11111 10001 10001 10001", 'I': "01110 00100 00100 00100 00100 00100 01110",
      'J': "00111 00010 00010 00010 00010 10010 01100", 'K': "10001 10010 10100 11000 10100 10010 10001", 'L': "10000 10000 10000 10000 10000 10000 11111",
      'M': "10001 11011 10101 10101 10001 10001 10001", 'N': "10001 10001 11001 10101 10011 10001 10001", 'O': "01110 10001 10001 10001 10001 10001 01110",
      'P': "11110 10001 10001 11110 10000 10000 10000", 'Q': "01110 10001 10001 10001 10101 10010 01101", 'R': "11110 10001 10001 11110 10100 10010 10001",
      'S': "01111 10000 10000 01110 00001 00001 11110", 'T': "11111 00100 00100 00100 00100 00100 00100", 'U': "10001 10001 10001 10001 10001 10001 01110",
      'V': "10001 10001 10001 10001 10001 01010 00100", 'W': "10001 10001 10001 10101 10101 10101 01010", 'X': "10001 10001 01010 00100 01010 10001 10001",
      'Y': "10001 10001 10001 01010 00100 00100 00100", 'Z': "11111 00001 00010 00100 01000 10000 11111",
      '0': "01110 10001 10011 10101 11001 10001 01110", '1': "00100 01100 00100 00100 00100 00100 01110", '2': "01110 10001 00001 00010 00100 01000 11111",
      '3': "11111 00010 00100 00010 00001 10001 01110", '4': "00010 00110 01010 10010 11111 00010 00010", '5': "11111 10000 11110 00001 00001 10001 01110",
      '6': "00110 01000 10000 11110 10001 10001 01110", '7': "11111 00001 00010 00100 01000 01000 01000", '8': "01110 10001 10001 01110 10001 10001 01110",
      '9': "01110 10001 10001 01111 00001 00010 01100", '-': "00000 00000 00000 11111 00000 00000 00000", ':': "00000 01100 01100 00000 01100 01100 00000",
      '.': "00000 00000 00000 00000 00000 01100 01100", '!': "00100 00100 00100 00100 00100 00000 00100", "'": "00100 00100 01000 00000 00000 00000 00000",
      ',': "00000 00000 00000 00000 01100 00100 01000", '?': "01110 10001 00001 00010 00100 00000 00100", '/': "00001 00010 00010 00100 01000 01000 10000",
      '(': "00010 00100 01000 01000 01000 00100 00010", ')': "01000 00100 00010 00010 00010 00100 01000", '+': "00000 00100 00100 11111 00100 00100 00000",
      '*': "00000 10101 01110 11111 01110 10101 00000", ' ': "00000 00000 00000 00000 00000 00000 00000",
      '"': "01010 01010 10100 00000 00000 00000 00000", '=': "00000 00000 11111 00000 11111 00000 00000",
      '<': "00010 00100 01000 10000 01000 00100 00010", '>': "01000 00100 00010 00001 00010 00100 01000",
      '#': "01010 11111 01010 01010 01010 11111 01010", '&': "01100 10010 10100 01000 10101 10010 01101",
      '%': "11001 11010 00010 00100 01000 01011 10011", '$': "00100 01111 10100 01110 00101 11110 00100",
      ';': "00000 01100 01100 00000 01100 00100 01000", '@': "01110 10001 10111 10101 10111 10000 01111"}


def font_glyph(ch):
    """bold 6 x 7 letters in an 8 x 8 cell: each 5-wide row is OR-ed with
    itself one pixel along, so strokes are two pixels wide"""
    rows = FD.get(ch)
    if rows is None:
        return bytes(8)
    out = []
    for r in rows.split():
        v = int(r, 2) << 2
        out.append((v | (v >> 1)) & 0xFF)
    return bytes(out + [0])


def font_bits(text, bold=True):
    """a string as a bit image (8 px per char, 8 tall)"""
    img = np.zeros((8, 8 * len(text)), bool)
    for i, ch in enumerate(text):
        g = font_glyph(ch)
        for y in range(8):
            for x in range(8):
                img[y, i * 8 + x] = bool(g[y] & (128 >> x))
    return img


# ---------------------------------------------------------------- the glyph store
class Store:
    """glyphs 0..1535 (banks 0..11): what the PCG holds and what the sprite
    compositor copies from. Colour and mono versions."""

    def __init__(self):
        self.col = [bytes(8)] * (STORE_TOP * 128)
        self.mono = [bytes(8)] * (STORE_TOP * 128)
        self.next_stage = G_STAGE0
        self.next_fast = G_FAST_TOP
        self.key = {}
        self.fast_key = {}

    def put(self, g, pc, pm=None):
        self.col[g] = bytes(pc)
        self.mono[g] = bytes(pm if pm is not None else pc)

    def stage(self, pc, pm):
        k = (bytes(pc), bytes(pm))
        if not any(pc) and not any(pm):
            return 0
        if k not in self.key:
            g = self.next_stage
            assert g < self.next_fast, 'out of glyphs: stage %d, fast %d' % (g, self.next_fast)
            self.next_stage += 1
            self.key[k] = g
            self.put(g, pc, pm)
        return self.key[k]

    def fast(self, pc):
        pc = bytes(pc)
        if pc not in self.fast_key:
            self.next_fast -= 1
            g = self.next_fast
            assert g >= self.next_stage, 'out of glyphs (fast)'
            self.fast_key[pc] = g
            self.put(g, pc, pc)
        return self.fast_key[pc]

    def blob(self, mono=False):
        src = self.mono if mono else self.col
        return b''.join(src)

    def copy(self):
        s = Store()
        s.col, s.mono = list(self.col), list(self.mono)
        s.next_stage, s.next_fast = self.next_stage, self.next_fast
        s.key, s.fast_key = dict(self.key), dict(self.fast_key)
        return s


# ---------------------------------------------------------------- ready-made glyph objects
def kind_pieces(store, shape, even=False):
    """shape at x phases 0..3 (0,2,4,6 px) and y offsets 0..7 -> 32 piece
    lists [(dc, dr, glyph)]. even: odd y offsets use the even one above"""
    shape = np.asarray(shape, bool)
    h, w = shape.shape
    assert w <= 10 and h <= 9
    out = []
    for xp in range(4):
        for yo in range(8):
            if even and yo & 1:
                out.append(out[-1])
                continue
            can = np.zeros((24, 24), bool)
            can[yo:yo + h, 2 * xp:2 * xp + w] = shape
            ps = []
            for cy in range(3):
                for cx in range(3):
                    p = cell_bytes(can, cx, cy)
                    if any(p):
                        ps.append((cx, cy, store.fast(p)))
            out.append(ps)
    return out


# ---------------------------------------------------------------- sprites
def sprite_frame(bits, mask=None):
    """-> db w, h, ax, ay; dw offsets of the 4 shifts (0,2,4,6 px); then per
    shift, per byte column: db first row, db rows, rows x (and, or)"""
    bits = np.asarray(bits, bool)
    mask = bits.copy() if mask is None else (np.asarray(mask, bool) | bits)
    h, W = bits.shape
    w = (W + 6 + 7) // 8
    blocks = []
    for s in range(4):
        B = np.zeros((h, w * 8), bool)
        M = np.zeros((h, w * 8), bool)
        B[:, 2 * s:2 * s + W] = bits
        M[:, 2 * s:2 * s + W] = mask
        out = bytearray()
        for c in range(w):
            colm = M[:, c * 8:(c + 1) * 8].any(1)
            rows = np.nonzero(colm)[0]
            if len(rows) == 0:
                out += bytes([0, 0])
                continue
            y0, y1 = rows.min(), rows.max()
            out += bytes([y0, y1 - y0 + 1])
            for y in range(y0, y1 + 1):
                d = k = 0
                for b in range(8):
                    if B[y, c * 8 + b]:
                        d |= 128 >> b
                    if M[y, c * 8 + b]:
                        k |= 128 >> b
                out.append((~k) & 255)
                out.append(d & k)
        blocks.append(out)
    head = bytearray([w, h, 0, 0])
    off = 12
    for b in blocks:
        head += off.to_bytes(2, 'little')
        off += len(b)
    return bytes(head) + b''.join(blocks)


def outline(bits):
    """1-pixel dark outline mask around a shape (sprites keep a black edge)"""
    b = np.asarray(bits, bool)
    h, w = b.shape
    p = np.zeros((h + 2, w + 2), bool)
    p[1:-1, 1:-1] = b
    m = p.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            m[1 + dy:h + 1 + dy, 1 + dx:w + 1 + dx] |= b
    return m


def pad(bits, l=1, t=1, r=1, b_=1):
    a = np.asarray(bits, bool)
    h, w = a.shape
    o = np.zeros((h + t + b_, w + l + r), bool)
    o[t:t + h, l:l + w] = a
    return o


def to_png(path, rgb, scale=2):
    from PIL import Image
    im = Image.fromarray(np.asarray(rgb, np.uint8))
    im = im.resize((im.width * scale, int(im.height * scale * 1.2)), Image.NEAREST)
    im.save(path)


# ---------------------------------------------------------------- a colour canvas
class Canvas:
    """colour-index image (0 = transparent / sky)"""

    def __init__(self, w, h):
        self.a = np.zeros((h, w), np.uint8)
        self.w, self.h = w, h

    def rect(self, x, y, w, h, c):
        x0, y0, x1, y1 = max(0, x), max(0, y), min(self.w, x + w), min(self.h, y + h)
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1] = c

    def frame(self, x, y, w, h, c):
        self.rect(x, y, w, 1, c)
        self.rect(x, y + h - 1, w, 1, c)
        self.rect(x, y, 1, h, c)
        self.rect(x + w - 1, y, 1, h, c)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = c

    def line(self, x0, y0, x1, y1, c):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            self.px(int(round(x0 + (x1 - x0) * i / n)), int(round(y0 + (y1 - y0) * i / n)), c)

    def ellipse(self, cx, cy, rx, ry, c, fill=True):
        for y in range(int(cy - ry - 1), int(cy + ry + 2)):
            for x in range(int(cx - rx - 1), int(cx + rx + 2)):
                d = ((x - cx) / max(rx, 0.1)) ** 2 + ((y - cy) / max(ry, 0.1)) ** 2
                if (d <= 1.0) if fill else (0.62 <= d <= 1.0):
                    self.px(x, y, c)

    def stamp(self, x, y, rows, cmap):
        """rows of chars; cmap: char -> colour (missing = transparent)"""
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch in cmap:
                    self.px(x + i, y + j, cmap[ch])

    def text(self, x, y, s, c, scale=1):
        b = font_bits(s)
        for j in range(b.shape[0]):
            for i in range(b.shape[1]):
                if b[j, i]:
                    self.rect(x + i * scale, y + j * scale, scale, scale, c)

    def hatch(self, x, y, w, h, c, period=2, phase=0):
        for j in range(max(0, y), min(self.h, y + h)):
            for i in range(max(0, x), min(self.w, x + w)):
                if ((i + j + phase) % period) == 0:
                    self.a[j, i] = c


def cell_colours(win, sky):
    """win: 8x8 colour indices (0 = sky). -> (pattern bytes, ink, paper)"""
    w = np.where(win == 0, sky, win)
    vals, cnt = np.unique(w, return_counts=True)
    order = [int(v) for _, v in sorted(zip(-cnt, vals))]
    if len(order) == 1:
        c = order[0]
        return bytes(8), c, c
    if sky in order:
        paper = sky
        ink = [c for c in order if c != sky][0]
    else:
        paper, ink = order[0], order[1]
        if LUM[paper] > LUM[ink]:       # brighter colour as the ink where we can
            paper, ink = ink, paper
    pat = bytearray(8)
    for y in range(8):
        v = 0
        for x in range(8):
            c = int(w[y, x])
            if c == ink:
                on = True
            elif c == paper:
                on = False
            else:
                on = abs(LUM[c] - LUM[ink]) < abs(LUM[c] - LUM[paper])
            if on:
                v |= 128 >> x
        pat[y] = v
    if not any(pat):
        return bytes(8), paper, paper
    if all(b == 255 for b in pat):
        return bytes(8), ink, ink
    return bytes(pat), ink, paper
