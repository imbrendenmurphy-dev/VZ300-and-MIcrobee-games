"""Level 1: THE FRONT LAWN (dawn). Striped mown lawn, a winding paved
path, flowerbeds of mulch with flowers, stepping stones, a birdbath."""
import math
import numpy as np
import gfx
from gfx import *
from level import Level, Terrain, PFCOLS, h32

T_DARK, T_LIGHT, T_PAVE, T_MULCH, T_WATER, T_STONE = range(6)

G1 = ['....', '..#.', '..#.', '....', '....', '#...', '#...', '....']
G2 = ['....', '....', '.#..', '.#..', '....', '...#', '...#', '....']
G3 = ['...#', '....', '....', '.#..', '.#..', '....', '#...', '....']
G4 = ['....', '#...', '....', '....', '..#.', '..#.', '....', '....']
PV0 = ['...#', '...#', '...#', '...#', '...#', '...#', '...#', '####']
PV1 = ['#...', '#...', '#...', '#...', '#...', '#...', '#...', '####']
MU1 = ['....', '.#..', '....', '...#', '....', '#...', '....', '..#.']
MU2 = ['..#.', '....', '#...', '....', '...#', '....', '.#..', '....']
WA1 = ['....', '.##.', '....', '....', '....', '....', '##..', '....']
WA2 = ['....', '....', '..##', '....', '....', '.##.', '....', '....']
ST1 = ['.##.', '#..#', '....', '....', '....', '....', '#..#', '.##.']

TERR = [
    Terrain('dark', GREEN, BGREEN, [G1, G2, G3, G4], pick=lambda r, c: (r & 1) * 2 + (c & 1)),
    Terrain('light', BGREEN, GREEN, [G2, G4, G1, G3], pick=lambda r, c: (r & 1) * 2 + (c & 1)),
    Terrain('pave', GREY, DGREY, [PV0, PV1], pick=lambda r, c: (c + (r // 1)) & 1),
    Terrain('mulch', BROWN, RED, [MU1, MU2], pick=lambda r, c: (r ^ c) & 1),
    Terrain('water', BLUE, BCYAN, [WA1, WA2], pick=lambda r, c: (r ^ c) & 1),
    Terrain('stone', DGREY, GREY, [ST1]),
]

FLOWER = ['....', '.#..', '###.', '.#..', '...#', '..##', '...#', '....']
FLOWER2 = ['..#.', '.###', '..#.', '....', '#...', '##..', '#...', '....']
TULIP = ['....', '#.#.', '###.', '.#..', '.#..', '....', '..#.', '....']


def build_lawn(rows=420, seed=1):
    lv = Level(rows, TERR)
    # mown stripes: 4 cells wide, alternating
    for c in range(0, PFCOLS + 1):
        band = (c // 4) & 1
        lv.corner[:, c] = T_LIGHT if band else T_DARK
    # winding path from bottom to top
    for y in range(rows + 1):
        cx = 18 + 7 * math.sin(y / 23.0) + 3 * math.sin(y / 9.0 + 1)
        w = 3
        x0 = int(round(cx - w))
        x1 = int(round(cx + w))
        lv.corner[y, max(0, x0):min(PFCOLS, x1) + 1] = T_PAVE
    # flowerbeds along the sides
    y = 12
    i = 0
    while y < rows - 20:
        side = i & 1
        h = 10 + (h32('bed', y) % 8)
        if side == 0:
            lv.fill(T_MULCH, 0, y, 5, y + h)
        else:
            lv.fill(T_MULCH, PFCOLS - 6, y, PFCOLS, y + h)
        y += h + 14 + (h32('gap', y) % 10)
        i += 1
    # birdbath (water disc on stone) every so often, away from the path
    for by in range(60, rows - 20, 110):
        cx = 18 + 7 * math.sin(by / 23.0) + 3 * math.sin(by / 9.0 + 1)
        bx = 28 if cx < 18 else 8
        lv.disc(T_STONE, bx, by, 4.2, 3.6)
        lv.disc(T_WATER, bx, by, 2.6, 2.2)
    return lv


def add_flowers(lv):
    """flower stamps on mulch cells (single cells, colour per flower)"""
    cols = [BRED, BMAGENTA, YELLOW, WHITE, BBLUE]
    shapes = [FLOWER, FLOWER2, TULIP]
    for r in range(lv.rows):
        for c in range(PFCOLS):
            cs = {lv.corner[r, c], lv.corner[r, c + 1], lv.corner[r + 1, c], lv.corner[r + 1, c + 1]}
            mr, mc = r // 2, c // 2
            arr = h32('arr', mr, mc) % 4
            pos = (r & 1) * 2 + (c & 1)
            if cs == {T_MULCH} and pos in ((0, 3), (1, 2), (0,), (3,))[arr]:
                shp = shapes[(pos + arr) % len(shapes)]
                col = cols[h32('fc', mr, mc) % len(cols)]
                art = [''.join('X' if ch == '#' else 'm' for ch in row) for row in shp]
                lv.put_art(art, {'X': col, 'm': BROWN}, c, r)
    return lv


if __name__ == '__main__':
    from PIL import Image
    lv = add_flowers(build_lawn())
    b = lv.build()
    print('rows', b['nrows'], 'glyphs', len(b['glyphs']), 'metatiles', len(b['meta']), 'map bytes', len(b['map']))
    rgb = gfx.render_cells(b['G'], b['C'])
    im = Image.fromarray(rgb[-480:])
    im = im.resize((im.width * 2, im.height * 3 // 1), Image.NEAREST)
    im.save('/tmp/claude-0/lawn.png')
