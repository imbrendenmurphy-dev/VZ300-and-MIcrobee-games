"""Canvas + cell compiler for the Microbee Premium Plus.

A picture is drawn at 512 x 256 in Microbee colour numbers (0..15). The
compiler turns it into 64 x 16 cells of 8 x 16 pixels, each with one ink and
one paper colour, deduplicates the glyph patterns, and can make the
monochrome version (each colour becomes a dot pattern, ink white on black).
"""
import numpy as np
from PIL import Image, ImageDraw

BLK, RED, GRN, BRN, BLU, MAG, CYN, LGR, DGR, BRED, BGRN, YEL, BBLU, BMAG, BCYN, WHT = range(16)
PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
       (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
PALA = np.array(PAL, np.int32)
LUM = [int(0.3 * r + 0.59 * g + 0.11 * b) for r, g, b in PAL]
W, H = 512, 256
CW, CH = 8, 16


class Canvas:
    def __init__(self, fill=0, w=W, h=H):
        self.w, self.h = w, h
        self.img = Image.new('L', (w, h), fill)
        self.d = ImageDraw.Draw(self.img)

    @property
    def a(self):
        return np.array(self.img, np.uint8)

    def set(self, arr):
        self.img = Image.fromarray(np.asarray(arr, np.uint8), 'L')
        self.d = ImageDraw.Draw(self.img)

    def rect(self, x0, y0, x1, y1, c):          # inclusive
        if x1 >= x0 and y1 >= y0:
            self.d.rectangle([x0, y0, x1, y1], fill=c)

    def poly(self, pts, c):
        self.d.polygon([(float(x), float(y)) for x, y in pts], fill=c)

    def line(self, x0, y0, x1, y1, c, w=1):
        self.d.line([(x0, y0), (x1, y1)], fill=c, width=w)

    def ellipse(self, cx, cy, rx, ry, c):
        self.d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=c)

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img.putpixel((int(x), int(y)), c)

    def get(self, x, y):
        return self.img.getpixel((int(x), int(y)))

    def rgb(self):
        return PALA[self.a].astype(np.uint8)

    def save(self, path, scale=2, aspect=1.5):
        im = Image.fromarray(self.rgb())
        im = im.resize((im.width * scale, int(im.height * scale * aspect)), Image.NEAREST)
        im.save(path)


def _dist(c1, c2):
    d = PALA[c1] - PALA[c2]
    return int((d * d).sum())


DIST = [[_dist(i, j) for j in range(16)] for i in range(16)]


def compile_cells(a, paper_pref=None, ink_pref=None):
    """a: (256, 512) colour numbers -> pats (16,64,16) uint8 bytes, ink (16,64), paper (16,64).
    paper_pref(colour) -> priority to be the paper (higher wins ties of 'background')."""
    rows, cols = a.shape[0] // CH, a.shape[1] // CW
    pats = np.zeros((rows, cols, CH), np.uint8)
    ink = np.zeros((rows, cols), np.uint8)
    paper = np.zeros((rows, cols), np.uint8)
    wbits = np.array([128, 64, 32, 16, 8, 4, 2, 1], np.uint16)
    for cy in range(rows):
        for cx in range(cols):
            c = a[cy * CH:(cy + 1) * CH, cx * CW:(cx + 1) * CW]
            vals, cnt = np.unique(c, return_counts=True)
            order = sorted(zip(cnt, vals), reverse=True)
            if len(order) == 1:
                p = order[0][1]
                ink[cy, cx] = p
                paper[cy, cx] = p
                continue
            if len(order) == 2:
                (n1, c1), (n2, c2) = order
                pa, ik = c1, c2
            else:
                best = None
                cs = [v for _, v in order]
                for i in range(len(cs)):
                    for j in range(i + 1, len(cs)):
                        e = 0
                        for n, v in order:
                            e += n * min(DIST[v][cs[i]], DIST[v][cs[j]])
                        if best is None or e < best[0]:
                            best = (e, cs[i], cs[j])
                _, x1, x2 = best
                n1 = sum(n for n, v in order if DIST[v][x1] <= DIST[v][x2])
                pa, ik = (x1, x2) if n1 >= c.size - n1 else (x2, x1)
            if paper_pref:
                if paper_pref(ik) > paper_pref(pa):
                    pa, ik = ik, pa
            on = np.array([[DIST[v][ik] < DIST[v][pa] for v in r] for r in c])
            pats[cy, cx] = (on * wbits).sum(1).astype(np.uint8)
            ink[cy, cx] = ik
            paper[cy, cx] = pa
    return pats, ink, paper


# --------------------------------------------------------------- monochrome
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])


def mono_bits(a, level):
    """a: colour numbers; level[c] = 0..16 dots of 16 lit -> bool image"""
    lv = np.array(level)[a]
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    # pixels are tall: use the bayer matrix with rows halved so dots look square-ish
    th = BAYER[(yy // 1) % 4, xx % 4]
    return lv > th


def compile_mono(bits):
    rows, cols = bits.shape[0] // CH, bits.shape[1] // CW
    wbits = np.array([128, 64, 32, 16, 8, 4, 2, 1], np.uint16)
    b = bits.reshape(rows, CH, cols, CW).transpose(0, 2, 1, 3)
    return (b * wbits).sum(3).astype(np.uint8)


# --------------------------------------------------------------- glyph sets
class GlyphSet:
    """deduplicated glyph patterns (16 bytes each)"""

    def __init__(self, first=0):
        self.first = first
        self.pats = []
        self.idx = {}

    def add(self, pat):
        k = bytes(pat)
        if k not in self.idx:
            self.idx[k] = self.first + len(self.pats)
            self.pats.append(k)
        return self.idx[k]

    def data(self):
        return b''.join(self.pats)

    def __len__(self):
        return len(self.pats)


def preview(pats, ink, paper, path, scale=2, aspect=1.5):
    rows, cols = ink.shape
    out = np.zeros((rows * CH, cols * CW, 3), np.uint8)
    for cy in range(rows):
        for cx in range(cols):
            for r in range(CH):
                v = pats[cy, cx, r]
                for b in range(8):
                    on = (v >> (7 - b)) & 1
                    out[cy * CH + r, cx * CW + b] = PAL[ink[cy, cx] if on else paper[cy, cx]]
    im = Image.fromarray(out)
    im = im.resize((im.width * scale, int(im.height * scale * aspect)), Image.NEAREST)
    im.save(path)
    return im


def preview_mono(pats, path, scale=2, aspect=1.5, colour=(255, 176, 0)):
    rows, cols = pats.shape[:2]
    out = np.zeros((rows * CH, cols * CW, 3), np.uint8)
    for cy in range(rows):
        for cx in range(cols):
            for r in range(CH):
                v = pats[cy, cx, r]
                for b in range(8):
                    if (v >> (7 - b)) & 1:
                        out[cy * CH + r, cx * CW + b] = colour
    im = Image.fromarray(out)
    im = im.resize((im.width * scale, int(im.height * scale * aspect)), Image.NEAREST)
    im.save(path)
    return im
