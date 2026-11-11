"""BUZZ OFF! level builder.

A level is a grid of terrain *corners* (PFCOLS+1 wide, rows+1 tall,
row 0 = the bottom = the start). Each cell's glyph is made from its four
corner classes (clean, slightly organic edges where two terrains meet),
interior cells get the terrain's own texture. Stamps (flowers, stones,
objects) are drawn over whole cells afterwards. The result is cut into
cells, de-duplicated into glyphs (<= 896) and 2x2 metatiles (<= 256).
"""
import hashlib
import numpy as np
import gfx

PFCOLS = 36


class Terrain:
    def __init__(self, name, bg, fg, textures, pick=None):
        """textures: list of 8 x 4 strings ('#' = fg) used for interior cells;
        pick(row, col) -> texture index (default: hashed per 2x2 block)"""
        self.name, self.bg, self.fg, self.pick = name, bg, fg, pick
        self.tex = [np.array([[c == '#' for c in r] for r in t]) for t in textures]


def h32(*a):
    return int.from_bytes(hashlib.md5(repr(a).encode()).digest()[:4], 'little')


class Level:
    def __init__(self, rows, terrains):
        self.rows = rows                       # cell rows (bottom = 0)
        self.T = terrains
        self.corner = np.zeros((rows + 1, PFCOLS + 1), np.int8)   # [y][x], y up
        self.stamp = {}                         # (row, col) -> (glyph8 tuple, colour)
        self.markers = []

    # ---- painting helpers (cell coordinates, y = row from the bottom)
    def fill(self, t, x0, y0, x1, y1):
        x0, x1 = max(0, x0), min(PFCOLS, x1)
        y0, y1 = max(0, y0), min(self.rows, y1)
        self.corner[y0:y1 + 1, x0:x1 + 1] = t

    def disc(self, t, cx, cy, rx, ry):
        ys, xs = np.mgrid[0:self.rows + 1, 0:PFCOLS + 1]
        m = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 <= 1.0
        self.corner[m] = t

    def put_art(self, art_rows, key, col, row, bgmap=None):
        """draw pixel art (fat pixels, top line first) with its top-left at
        cell (col, row = the top cell row). '.' cells keep the terrain."""
        a = gfx.parse_art(art_rows, key)
        h, w = a.shape
        assert h % 8 == 0 and w % 4 == 0, (h, w)
        self.pending = getattr(self, 'pending', [])
        self.pending.append((a, col, row))

    # ---- rendering
    def cell_pixels(self, r, c):
        """the 8 x 4 colour image of cell (row r from bottom, col c)"""
        tl = self.corner[r + 1, c]
        tr = self.corner[r + 1, c + 1]
        bl = self.corner[r, c]
        br = self.corner[r, c + 1]
        cs = {tl, tr, bl, br}
        if len(cs) == 1:
            t = self.T[tl]
            if t.pick:
                tex = t.tex[t.pick(r, c) % len(t.tex)]
            else:
                tex = t.tex[h32(t.name, r // 2, c // 2) % len(t.tex)] if len(t.tex) > 1 else t.tex[0]
            return np.where(tex, t.fg, t.bg)
        # mixed: blend by bilinear weights, organic wobble keyed by the pattern
        img = np.zeros((8, 4), np.int16)
        key = (int(tl), int(tr), int(bl), int(br))
        wob = h32('wob', key) & 0xFFFF
        for y in range(8):
            for x in range(4):
                fx = (x + 0.5) / 4.0
                fy = 1.0 - (y + 0.5) / 8.0
                w = {}
                for cl, wt in ((tl, (1 - fx) * fy), (tr, fx * fy), (bl, (1 - fx) * (1 - fy)), (br, fx * (1 - fy))):
                    w[cl] = w.get(cl, 0) + wt
                n = (((wob >> ((y * 4 + x) % 13)) & 3) - 1.5) * 0.04
                best = sorted(w.items(), key=lambda kv: (-(kv[1] + (n if kv[0] == min(w) else 0)), kv[0]))[0][0]
                img[y, x] = self.T[best].bg
        # more than two colours: keep the two most common
        vals, cnt = np.unique(img, return_counts=True)
        if len(vals) > 2:
            keep = [v for _, v in sorted(zip(cnt, vals), reverse=True)[:2]]
            img = np.where(np.isin(img, keep), img, keep[0])
        return img

    def render(self):
        """-> image (rows*8 x PFCOLS*4) of colour indices, top line = top row"""
        H = self.rows * 8
        img = np.zeros((H, PFCOLS * 4), np.int16)
        for r in range(self.rows):
            y0 = H - (r + 1) * 8
            for c in range(PFCOLS):
                img[y0:y0 + 8, c * 4:c * 4 + 4] = self.cell_pixels(r, c)
        for a, col, row in getattr(self, 'pending', []):
            h, w = a.shape
            y0 = H - (row + 1) * 8
            x0 = col * 4
            for y in range(h):
                for x in range(w):
                    if a[y, x] >= 0 and 0 <= y0 + y < H and 0 <= x0 + x < PFCOLS * 4:
                        img[y0 + y, x0 + x] = a[y, x]
        return img

    def build(self, glyph_base=0, max_glyphs=896):
        """-> dict(glyphs=[8-byte], meta=[12-byte], map=bytes, nrows, img)"""
        img = self.render()
        G, C = gfx.to_cells(img)
        R = len(G)
        gl = {}
        glyphs = []
        cells = {}                              # (row_from_bottom, col) -> (code, attr, colour)
        for rt in range(R):
            r = R - 1 - rt
            for c in range(PFCOLS):
                g = G[rt][c]
                col = C[rt][c]
                if g == (0,) * 8 and (col >> 4) != (col & 15):
                    col = (col & 0xF0) | (col >> 4)
                if g not in gl:
                    gl[g] = glyph_base + len(glyphs)
                    glyphs.append(g)
                gi = gl[g]
                cells[(r, c)] = (0x80 | (gi & 0x7F), gi >> 7, col)
        assert len(glyphs) + glyph_base <= max_glyphs, 'too many glyphs: %d' % len(glyphs)
        metas = {}
        meta = []
        mp = bytearray()
        rows = R if R % 2 == 0 else R + 1
        for mr in range(rows // 2):
            for mc in range(PFCOLS // 2):
                def cl(r, c):
                    return cells.get((r, c), cells[(R - 1, c)])
                tl = cl(2 * mr + 1, 2 * mc)
                tr = cl(2 * mr + 1, 2 * mc + 1)
                bl = cl(2 * mr, 2 * mc)
                br = cl(2 * mr, 2 * mc + 1)
                k = tl + tr + bl + br
                if k not in metas:
                    metas[k] = len(meta)
                    meta.append(bytes(k))
                mp.append(metas[k])
        assert len(meta) <= 256, 'too many metatiles: %d' % len(meta)
        return dict(glyphs=glyphs, meta=meta, map=bytes(mp), nrows=R, img=img, G=G, C=C)


def level_bank(b):
    """LEVEL block: 0000 nrows (2), 0010 metatiles (12 bytes), 0C10 map"""
    bank = bytearray(32768)
    bank[0:2] = b['nrows'].to_bytes(2, 'little')
    for i, m in enumerate(b['meta']):
        bank[0x10 + i * 12:0x10 + i * 12 + 12] = m
    assert 0xC10 + len(b['map']) <= len(bank) - 0x1000, 'map too long'
    bank[0xC10:0xC10 + len(b['map'])] = b['map']
    return bytes(bank[:0xC10 + len(b['map'])])
