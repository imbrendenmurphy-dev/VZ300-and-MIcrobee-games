"""STARHIVE level builder (space). A level is a picture 320 pixels wide
and rows * 11 lines tall (row 0 = the bottom = the start), drawn in
colour indices with -1 for empty space. Empty cells become far-star
cells (rotated each frame for parallax); the rest is cut into 8 x 11
two-colour cells, de-duplicated into glyphs (<= 624) and 2 x 2
metatiles (16-bit map)."""
import math
import numpy as np
import gfx
from gfx import *
import art

COLS = 40
CL = 11


def h32(*a):
    import hashlib
    return int.from_bytes(hashlib.md5(repr(a).encode()).digest()[:4], 'little')


class Space:
    def __init__(self, rows):
        self.rows = rows
        self.img = np.full((rows * CL, COLS * 8), -1, np.int16)

    def y_of(self, row):            # top line of map row 'row' in the picture
        return (self.rows - 1 - row) * CL

    def stamp(self, a, x, row, dy=0):
        """colour-index art a, top-left at pixel x, top at map row 'row'"""
        h, w = a.shape
        y0 = self.y_of(row) + dy
        for yy in range(h):
            for xx in range(w):
                v = a[yy, xx]
                if v >= 0 and 0 <= y0 + yy < self.img.shape[0] and 0 <= x + xx < COLS * 8:
                    self.img[y0 + yy, x + xx] = v

    def rect(self, colour, x0, y0, x1, y1):
        self.img[max(0, y0):y1, max(0, x0):x1] = colour

    def build(self):
        img = self.img.copy()
        R = self.rows
        empty = np.zeros((R, COLS), bool)
        for rt in range(R):
            for c in range(COLS):
                empty[rt, c] = (img[rt * CL:(rt + 1) * CL, c * 8:(c + 1) * 8] < 0).all()
        img[img < 0] = BLACK
        img = gfx.quantise_cells(img)
        G, C = gfx.to_cells(img)
        vcol = [h32('v', c) % 4 for c in range(COLS)]
        gl = {(0,) * CL: 0}
        glyphs = [(0,) * CL]
        cells = {}
        for rt in range(R):
            r = R - 1 - rt
            for c in range(COLS):
                if empty[rt, c]:
                    gi = art.STAR_FIRST + vcol[c] * 4 + (r % 4)
                    col = art.STAR_COLOUR
                else:
                    g, col = G[rt][c], C[rt][c]
                    if g not in gl:
                        gl[g] = len(glyphs)
                        glyphs.append(g)
                    gi = gl[g]
                cells[(r, c)] = (0x80 | (gi & 0x7F), gi >> 7, col)
        assert len(glyphs) <= art.STAR_FIRST, 'too many glyphs: %d' % len(glyphs)
        metas, meta, mp = {}, [], bytearray()
        for mr in range(R // 2):
            for mc in range(COLS // 2):
                k = cells[(2 * mr + 1, 2 * mc)] + cells[(2 * mr + 1, 2 * mc + 1)] + \
                    cells[(2 * mr, 2 * mc)] + cells[(2 * mr, 2 * mc + 1)]
                if k not in metas:
                    metas[k] = len(meta)
                    meta.append(bytes(k))
                mp += metas[k].to_bytes(2, 'little')
        assert len(meta) <= 1020, 'too many metatiles: %d' % len(meta)
        return dict(glyphs=glyphs, meta=meta, map=bytes(mp), nrows=R - R % 2, img=img, G=G, C=C,
                    cells=cells, vcol=vcol)


def level_bank(b):
    bank = bytearray(0x3000)
    bank[0:2] = b['nrows'].to_bytes(2, 'little')
    for i, m in enumerate(b['meta']):
        bank[0x10 + i * 12:0x10 + i * 12 + 12] = m
    out = bytes(bank) + b['map']
    assert len(out) <= 32768, 'level too big'
    return out


def preview(b, tex, rows=None):
    """RGB picture of the map as the game shows it (stars at phase 0)"""
    cells = b['cells']
    R = b['nrows']
    rows = rows or R
    out = np.zeros((rows * CL, COLS * 8, 3), np.uint8)
    glyphs = list(b['glyphs'])
    for rt in range(rows):
        r = R - 1 - rt
        for c in range(COLS):
            code, attr, col = cells[(r, c)]
            gi = attr * 128 + (code & 0x7F)
            if gi >= art.STAR_FIRST:
                k = gi - art.STAR_FIRST
                g = art.star_glyph(tex, k // 4, k % 4)
            else:
                g = glyphs[gi]
            fg, bg = PAL[col & 15], PAL[col >> 4]
            for y in range(CL):
                for x in range(8):
                    out[rt * CL + y, c * 8 + x] = fg if (g[y] >> (7 - x)) & 1 else bg
    return out


# ---------------------------------------------------------------------
#  test level: starfield, a space station, an asteroid belt
# ---------------------------------------------------------------------
NEAR_STARS = [
    (['W'], WHITE), (['.W.', 'WWW', '.W.'], WHITE), (['C'], BCYAN), (['Y'], YELLOW),
    (['.c.', 'cCc', '.c.'], BCYAN), (['w'], GREY),
]


def station_block(w, h, seed):
    """a hull block: grey plating with dark panel seams and lit windows"""
    rng = np.random.default_rng(seed)
    a = np.full((h, w), GREY, np.int16)
    a[0, :] = WHITE
    a[:, 0] = WHITE
    a[-1, :] = DGREY
    a[:, -1] = DGREY
    for x in range(8, w - 1, 16):
        a[1:-1, x] = DGREY
    for y in range(11, h - 1, 22):
        a[y, 1:-1] = DGREY
    for i in range(w * h // 300):
        x = int(rng.integers(2, w - 4)) & ~1
        y = int(rng.integers(3, h - 3))
        a[y:y + 2, x:x + 3] = YELLOW
    return a


def girder(w):
    a = np.full((11, w), -1, np.int16)
    a[1, :] = GREY
    a[9, :] = GREY
    for x in range(0, w, 8):
        for y in range(1, 10):
            xx = x + (y - 1) % 8
            if xx < w:
                a[y, xx] = DGREY
    return a


def asteroid(r, seed):
    rng = np.random.default_rng(seed)
    w = int(r * 2)
    h = int(r * 2 * 1.33)
    a = np.full((h, w), -1, np.int16)
    k = rng.uniform(0.75, 1.0, 12)
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2 + 0.5) / (w / 2)
            dy = (y - h / 2 + 0.5) / (h / 2)
            ang = math.atan2(dy, dx)
            rad = k[int((ang + math.pi) / (2 * math.pi) * 12) % 12]
            if dx * dx + dy * dy <= rad * rad:
                lit = dx + dy < -0.6 * rad
                a[y, x] = GREY if lit else DGREY
    for i in range(int(r // 2)):
        cx, cy = int(rng.integers(2, w - 2)), int(rng.integers(2, h - 2))
        if a[cy, cx] == DGREY:
            a[cy, cx] = BLACK
            if cx + 1 < w and a[cy, cx + 1] == DGREY:
                a[cy, cx + 1] = BLACK
    return a


def build_test(rows=600, seed=3):
    sp = Space(rows)
    rng = np.random.default_rng(seed)
    # near stars, cell aligned
    for i in range(rows * 2):
        row = int(rng.integers(0, rows))
        col = int(rng.integers(0, COLS))
        s, c = NEAR_STARS[int(rng.integers(0, len(NEAR_STARS)))]
        a = gfx.parse_art(s, {'W': WHITE, 'C': BCYAN, 'Y': YELLOW, 'c': CYAN, 'w': GREY})
        sp.stamp(a, col * 8 + 2, row, 4)
    # station segments
    for k, row in enumerate(range(40, rows - 40, 120)):
        side = k & 1
        w = 120 + (h32('w', row) % 5) * 16
        x = 0 if side == 0 else COLS * 8 - w
        blk = station_block(w, 44, row)
        sp.stamp(blk, x, row)
        g = girder(COLS * 8 - w)
        sp.stamp(g, w if side == 0 else 0, row - 1)
    # asteroids
    for k in range(rows // 12):
        row = int(rng.integers(80, rows - 10))
        if (row % 120) < 10 or (row % 120) > 110:
            continue
        r = float(rng.uniform(4, 14))
        x = int(rng.integers(0, COLS * 8 - 2 * r))
        sp.stamp(asteroid(r, k), x, row)
    return sp


if __name__ == '__main__':
    from PIL import Image
    sp = build_test()
    b = sp.build()
    print('rows', b['nrows'], 'glyphs', len(b['glyphs']), 'metatiles', len(b['meta']))
    rgb = preview(b, art.star_textures(), rows=60)
    Image.fromarray(rgb).resize((640, 60 * 11 * 3 // 2), Image.NEAREST).save('/tmp/claude-0/space.png')
