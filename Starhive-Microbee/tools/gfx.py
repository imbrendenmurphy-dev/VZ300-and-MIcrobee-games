"""STARHIVE graphics helpers: pixel art -> Microbee PCG cells.

Display: 40 columns of 8 x 11 cells (one PCG pixel = one 40-column dot,
about 1.33x wider than a line is tall on a 4:3 screen). A cell has one
foreground and one background colour. Glyphs are 16 bytes apart in PCG
and in the RAM mirror; 11 lines are used.
"""
import numpy as np

CL = 11
PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 192, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
       (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)


def byte8(row):
    b = 0
    for i, v in enumerate(row):
        if v:
            b |= 0x80 >> i
    return b


def quantise_cells(img, bg=0):
    """force at most two colours per 8 x 11 cell (drop the rarest)"""
    H, W = img.shape
    out = img.copy()
    for y in range(0, H, CL):
        for x in range(0, W, 8):
            cell = out[y:y + CL, x:x + 8]
            vals, cnt = np.unique(cell, return_counts=True)
            if len(vals) > 2:
                order = [v for _, v in sorted(zip(cnt, vals), reverse=True)]
                keep = order[:2]
                if bg in vals and bg not in keep:
                    keep = [order[0], bg]
                rest = [v for v in vals if v not in keep]
                for v in rest:
                    cell[cell == v] = keep[0] if keep[0] != bg else keep[1]
    return out


def to_cells(img):
    """img: H x W colour indices (H multiple of 11, W of 8) ->
    (glyphs[rows][cols] = 11-byte tuple, colours[rows][cols])"""
    H, W = img.shape
    assert H % CL == 0 and W % 8 == 0
    glyphs, cols = [], []
    for r in range(H // CL):
        grow, crow = [], []
        for c in range(W // 8):
            cell = img[r * CL:(r + 1) * CL, c * 8:(c + 1) * 8]
            vals, counts = np.unique(cell, return_counts=True)
            if len(vals) > 2:
                raise ValueError('cell %d,%d has %d colours' % (r, c, len(vals)))
            if len(vals) == 1:
                bg = fg = int(vals[0])
            else:
                order = sorted(zip(counts, vals), reverse=True)
                bg, fg = int(order[0][1]), int(order[1][1])
                if BLACK in (bg, fg):            # black is always the paper
                    bg, fg = BLACK, (fg if bg == BLACK else bg)
            g = tuple(byte8([cell[y, x] == fg and fg != bg for x in range(8)]) for y in range(CL))
            if bg == fg:
                g = (0,) * CL
                fg = bg
            grow.append(g)
            crow.append((bg << 4) | fg)
        glyphs.append(grow)
        cols.append(crow)
    return glyphs, cols


def render_cells(glyphs, cols):
    R, C = len(glyphs), len(glyphs[0])
    out = np.zeros((R * CL, C * 8, 3), np.uint8)
    for r in range(R):
        for c in range(C):
            col = cols[r][c]
            fg, bg = PAL[col & 15], PAL[col >> 4]
            for y in range(CL):
                b = glyphs[r][c][y]
                for x in range(8):
                    out[r * CL + y, c * 8 + x] = fg if (b >> (7 - x)) & 1 else bg
    return out


def parse_art(rows, key):
    """ASCII art -> colour-index array; key maps char -> colour, other
    characters are transparent (-1)"""
    h, w = len(rows), max(len(r) for r in rows)
    a = np.full((h, w), -1, np.int16)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in key:
                a[y, x] = key[ch]
    return a


def dilate(mask):
    m = mask.copy()
    m[1:, :] |= mask[:-1, :]
    m[:-1, :] |= mask[1:, :]
    m[:, 1:] |= mask[:, :-1]
    m[:, :-1] |= mask[:, 1:]
    return m


def sprite_frame(art, outline=True):
    """art: colour-index array (-1 = transparent), h x w pixels.
    -> frame bytes: wb, h, flags, 0, block size (2), then 8 blocks (one
    per pixel shift): wb x (first line, end line, colour), then wb
    columns x h lines x (mask, gfx). A column's colour is its most
    common ink."""
    h, w = art.shape
    solid = art >= 0
    pad = 1 if outline else 0
    wb = (w + 2 * pad + 7 + 7) // 8
    blocks = []
    for s in range(8):
        W = wb * 8
        g = np.zeros((h, W), bool)
        cimg = np.full((h, W), -1, np.int16)
        x0 = s + pad
        g[:, x0:x0 + w] = solid
        cimg[:, x0:x0 + w] = art
        if outline:
            big = np.zeros((h, W + 2), bool)
            big[:, x0 + 1:x0 + 1 + w] = solid
            m = dilate(big)[:, 1:W + 1]
        else:
            m = g.copy()
        head = bytearray()
        data = bytearray()
        for c in range(wb):
            first, end = h, 0
            inks = cimg[:, c * 8:(c + 1) * 8]
            inks = inks[inks >= 0]
            colour = int(np.bincount(inks).argmax()) if len(inks) else WHITE
            for y in range(h):
                gb = byte8(g[y, c * 8:(c + 1) * 8])
                mb = byte8(m[y, c * 8:(c + 1) * 8])
                if gb or mb:
                    first, end = min(first, y), y + 1
                data += bytes([(~mb) & 0xFF, gb])
            if end == 0:
                first = end = 0
            head += bytes([first, end, colour])
        blocks.append(bytes(head + data))
    bsz = len(blocks[0])
    return bytes([wb, h, 0, 0, bsz & 0xFF, bsz >> 8]) + b''.join(blocks)
