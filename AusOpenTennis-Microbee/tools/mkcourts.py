"""Court pictures for the game: base glyphs + crowd and umpire variants,
colour and mono, packed (LZB) for the picture blocks.

File (unpacked):
  dw n glyphs, n*16 patterns          (glyph 0 is blank; the glyphs the
                                       sprites may cover come first: the
                                       game copies the first 512 into every
                                       sprite block)
  1024 lo codes, 1024 banks, 1024 colours
  dw ncrowd, ncrowd x (dw cell, db column, lo1 hi1 col1, lo2 hi2 col2), by column; 64 counts
  4 x (db n, n x (dw cell, db lo, hi, col))                          umpire poses 1..4
"""
import numpy as np
import venues
from cells import compile_cells, compile_mono, mono_bits, GlyphSet, CH, CW

# mono dot levels (of 16) per colour
MONO_LEVEL = [0, 2, 3, 3, 1, 4, 3, 10, 4, 8, 6, 12, 3, 8, 9, 16]


def compile_variant(c, mono):
    if mono:
        bits = mono_bits(c.a, MONO_LEVEL)
        pats = compile_mono(bits)
        ink = np.full(pats.shape[:2], 15, np.uint8)
        paper = np.zeros(pats.shape[:2], np.uint8)
        return pats, ink, paper
    return compile_cells(c.a)


def build(venue, mono):
    base = compile_variant(venues.draw(venue), mono)
    crowd = [compile_variant(venues.draw(venue, crowd=k), mono) for k in (1, 2)]
    umps = [compile_variant(venues.draw(venue, ump=k), mono) for k in (1, 2, 3, 4)]
    pats, ink, paper = base
    gs = GlyphSet(0)
    gs.add(bytes(16))
    order = [(r, c) for r in range(2, 16) for c in range(64)] + [(r, c) for r in range(0, 2) for c in range(64)]
    # base cells under the sprites first, then variants, then the top rows
    for r, c in order[:14 * 64]:
        gs.add(pats[r, c])
    crowd_cells = []
    for r in range(16):
        for c in range(64):
            if any((v[0][r, c] != pats[r, c]).any() for v in crowd):
                crowd_cells.append((r, c))
    for v in crowd:
        for r, c in crowd_cells:
            gs.add(v[0][r, c])
    ump_cells = []
    for v in umps:
        cl = []
        for r in range(16):
            for c in range(64):
                if (v[0][r, c] != pats[r, c]).any() or v[1][r, c] != ink[r, c] or v[2][r, c] != paper[r, c]:
                    cl.append((r, c, gs.add(v[0][r, c]), (v[2][r, c] << 4) | v[1][r, c]))
        ump_cells.append(cl)
    for r, c in order[14 * 64:]:
        gs.add(pats[r, c])
    lo = bytearray(1024)
    hi = bytearray(1024)
    col = bytearray(1024)
    for r in range(16):
        for c in range(64):
            g = gs.add(pats[r, c])
            i = r * 64 + c
            lo[i] = 0x80 | (g & 127)
            hi[i] = g >> 7
            col[i] = (paper[r, c] << 4) | ink[r, c]
    out = bytearray(len(gs).to_bytes(2, 'little') + gs.data() + lo + hi + col)
    crowd_cells.sort(key=lambda rc: (rc[1], rc[0]))
    out += len(crowd_cells).to_bytes(2, 'little')
    counts = [0] * 64
    for r, c in crowd_cells:
        counts[c] += 1
        rec = (r * 64 + c).to_bytes(2, 'little') + bytes([c])
        for v in crowd:
            g = gs.idx[bytes(v[0][r, c])]
            rec += bytes([0x80 | (g & 127), g >> 7, (v[2][r, c] << 4) | v[1][r, c]])
        out += rec
    out += bytes(counts)
    for cl in ump_cells:
        out.append(len(cl))
        for r, c, g, cc in cl:
            out += (r * 64 + c).to_bytes(2, 'little') + bytes([0x80 | (g & 127), g >> 7, cc])
    assert len(gs) <= 1280, (venue, len(gs))
    return bytes(out), len(gs), len(crowd_cells)


if __name__ == '__main__':
    for v in venues.VENUES:
        for m in (False, True):
            data, n, nc = build(v, m)
            print(v, 'mono' if m else 'colour', 'glyphs', n, 'crowd cells', nc, 'bytes', len(data))
