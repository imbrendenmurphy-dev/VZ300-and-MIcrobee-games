#!/usr/bin/env python3
"""Generate all Phase-1 graphics assets as Z80 'db' source (build/assets.asm)
plus PNG previews.  Colour indices (MODE(1), colour set 0):
    0 = green, 1 = yellow, 2 = blue, 3 = red
Pixel packing: byte = p0<<6 | p1<<4 | p2<<2 | p3  (leftmost pixel in the high bits).
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'build')
os.makedirs(OUT, exist_ok=True)

PALETTE = {0: (0x20, 0xC0, 0x20), 1: (0xE0, 0xE0, 0x30), 2: (0x30, 0x40, 0xE0), 3: (0xE0, 0x30, 0x30)}
G, Y, B, R = 0, 1, 2, 3
CH = {'G': 0, 'Y': 1, 'B': 2, 'R': 3}

# ------------------------------------------------------------------ helpers
def pack4(px):
    return px[0] << 6 | px[1] << 4 | px[2] << 2 | px[3]


def art(rows):
    """ASCII art -> (colour array, alpha array).  '.' is transparent."""
    h = len(rows)
    w = len(rows[0])
    col = np.zeros((h, w), dtype=np.uint8)
    al = np.zeros((h, w), dtype=np.uint8)
    for y, r in enumerate(rows):
        assert len(r) == w, (y, r)
        for x, c in enumerate(r):
            if c != '.':
                col[y, x] = CH[c]
                al[y, x] = 1
    return col, al


def tile_from_art(rows):
    assert len(rows) == 8 and all(len(r) == 8 for r in rows)
    return np.array([[CH[c] for c in r] for r in rows], dtype=np.uint8)


# ------------------------------------------------------------------ hull tiles
TILES = []          # list of 8x8 colour arrays
TNAME = {}


def add_tile(name, rows):
    TNAME[name] = len(TILES)
    TILES.append(tile_from_art_rows(rows) if isinstance(rows, list) else rows)


def tile_from_art_rows(rows):
    return tile_from_art(rows)


# plating: green with blue panel dither; seams blue; rivets yellow
add_tile('plate', ['GGGGGGGG',
                   'GGGGGGGG',
                   'GGGBGGGG',
                   'GGGGGGGG',
                   'GGGGGGGG',
                   'GGGGGBGG',
                   'GGGGGGGG',
                   'GGGGGGGG'])
add_tile('seamR', ['GGGGGGGB',
                   'GGGGGGGB',
                   'GGGBGGGB',
                   'GGGGGGGB',
                   'GGGGGGGB',
                   'GGGGGBGB',
                   'GGGGGGGB',
                   'GGGGGGGB'])
add_tile('seamB', ['GGGGGGGG',
                   'GGGGGGGG',
                   'GGGBGGGG',
                   'GGGGGGGG',
                   'GGGGGGGG',
                   'GGGGGBGG',
                   'GGGGGGGG',
                   'BBBBBBBB'])
add_tile('seamRB', ['GGGGGGGB',
                    'GGGGGGGB',
                    'GGGBGGGB',
                    'GGGGGGGB',
                    'GGGGGGGB',
                    'GGGGGBGB',
                    'GGGGGGGB',
                    'BBBBBBBB'])
add_tile('rivet', ['GGGGGGGG',
                   'GYGGGGYG',
                   'GGGGGGGG',
                   'GGGGGGGG',
                   'GGGGGGGG',
                   'GGGGGGGG',
                   'GYGGGGYG',
                   'GGGGGGGG'])
add_tile('rivetR', ['GGGGGGGB',
                    'GYGGGGYB',
                    'GGGGGGGB',
                    'GGGGGGGB',
                    'GGGGGGGB',
                    'GGGGGGGB',
                    'GYGGGGYB',
                    'GGGGGGGB'])
add_tile('rivetB', ['GGGGGGGG',
                    'GYGGGGYG',
                    'GGGGGGGG',
                    'GGGGGGGG',
                    'GGGGGGGG',
                    'GGGGGGGG',
                    'GYGGGGYG',
                    'BBBBBBBB'])
add_tile('rivetRB', ['GGGGGGGB',
                     'GYGGGGYB',
                     'GGGGGGGB',
                     'GGGGGGGB',
                     'GGGGGGGB',
                     'GGGGGGGB',
                     'GYGGGGYB',
                     'BBBBBBBB'])

# raised block, 3x3 tiles: top-left lit (yellow edge), shadow bottom-right (blue/red)
add_tile('blkTL', ['BBBBBBBB',
                   'BYYYYYYY',
                   'BYGYGYGY',
                   'BYYGYGYG',
                   'BYGYGYGY',
                   'BYYGYGYG',
                   'BYGYGYGY',
                   'BYYGYGYG'])
add_tile('blkT', ['BBBBBBBB',
                  'YYYYYYYY',
                  'GYGYGYGY',
                  'YGYGYGYG',
                  'GYGYGYGY',
                  'YGYGYGYG',
                  'GYGYGYGY',
                  'YGYGYGYG'])
add_tile('blkTR', ['BBBBBBBB',
                   'YYYYYYYB',
                   'GYGYGYGB',
                   'YGYGYGYB',
                   'GYGYGYGB',
                   'YGYGYGYB',
                   'GYGYGYGB',
                   'YGYGYGYB'])
add_tile('blkL', ['BYGYGYGY',
                  'BYYGYGYG',
                  'BYGYGYGY',
                  'BYYGYGYG',
                  'BYGYGYGY',
                  'BYYGYGYG',
                  'BYGYGYGY',
                  'BYYGYGYG'])
add_tile('blkC', ['GYGYGYGY',
                  'YGYGYGYG',
                  'GYGYGYGY',
                  'YGYGYGYG',
                  'GYGYGYGY',
                  'YGYGYGYG',
                  'GYGYGYGY',
                  'YGYGYGYG'])
add_tile('blkR', ['GYGYGYGB',
                  'YGYGYGYB',
                  'GYGYGYGB',
                  'YGYGYGYB',
                  'GYGYGYGB',
                  'YGYGYGYB',
                  'GYGYGYGB',
                  'YGYGYGYB'])
add_tile('blkBL', ['BYGYGYGY',
                   'BYYGYGYG',
                   'BYGYGYGY',
                   'BYYGYGYG',
                   'BYGYGYGY',
                   'BYYGYGYG',
                   'BBBBBBBB',
                   'BBBBBBBB'])
add_tile('blkB', ['GYGYGYGY',
                  'YGYGYGYG',
                  'GYGYGYGY',
                  'YGYGYGYG',
                  'GYGYGYGY',
                  'YGYGYGYG',
                  'BBBBBBBB',
                  'BBBBBBBB'])
add_tile('blkBR', ['GYGYGYGB',
                   'YGYGYGYB',
                   'GYGYGYGB',
                   'YGYGYGYB',
                   'GYGYGYGB',
                   'YGYGYGYB',
                   'BBBBBBBB',
                   'BBBBBBBB'])
# dark-faced raised block (green face + blue shading) for variety
add_tile('dkTL', ['BBBBBBBB',
                  'BGGGGGGG',
                  'BGBGBGBG',
                  'BGGBGBGB',
                  'BGBGBGBG',
                  'BGGBGBGB',
                  'BGBGBGBG',
                  'BGGBGBGB'])
add_tile('dkT', ['BBBBBBBB',
                 'GGGGGGGG',
                 'BGBGBGBG',
                 'GBGBGBGB',
                 'BGBGBGBG',
                 'GBGBGBGB',
                 'BGBGBGBG',
                 'GBGBGBGB'])
add_tile('dkTR', ['BBBBBBBB',
                  'GGGGGGGB',
                  'BGBGBGBB',
                  'GBGBGBGB',
                  'BGBGBGBB',
                  'GBGBGBGB',
                  'BGBGBGBB',
                  'GBGBGBGB'])
add_tile('dkL', ['BGBGBGBG',
                 'BGGBGBGB',
                 'BGBGBGBG',
                 'BGGBGBGB',
                 'BGBGBGBG',
                 'BGGBGBGB',
                 'BGBGBGBG',
                 'BGGBGBGB'])
add_tile('dkC', ['BGBGBGBG',
                 'GBGBGBGB',
                 'BGBGBGBG',
                 'GBGBGBGB',
                 'BGBGBGBG',
                 'GBGBGBGB',
                 'BGBGBGBG',
                 'GBGBGBGB'])
add_tile('dkR', ['BGBGBGBB',
                 'GBGBGBGB',
                 'BGBGBGBB',
                 'GBGBGBGB',
                 'BGBGBGBB',
                 'GBGBGBGB',
                 'BGBGBGBB',
                 'GBGBGBGB'])
add_tile('dkBL', ['BGBGBGBG',
                  'BGGBGBGB',
                  'BGBGBGBG',
                  'BGGBGBGB',
                  'BGBGBGBG',
                  'BGGBGBGB',
                  'BBBBBBBB',
                  'BBBBBBBB'])
add_tile('dkB', ['BGBGBGBG',
                 'GBGBGBGB',
                 'BGBGBGBG',
                 'GBGBGBGB',
                 'BGBGBGBG',
                 'GBGBGBGB',
                 'BBBBBBBB',
                 'BBBBBBBB'])
add_tile('dkBR', ['BGBGBGBB',
                  'GBGBGBGB',
                  'BGBGBGBB',
                  'GBGBGBGB',
                  'BGBGBGBB',
                  'GBGBGBGB',
                  'BBBBBBBB',
                  'BBBBBBBB'])
# vents (louvres)
add_tile('ventA', ['BBBBBBBB',
                   'GGGGGGGG',
                   'BBBBBBBB',
                   'GGGGGGGG',
                   'BBBBBBBB',
                   'GGGGGGGG',
                   'BBBBBBBB',
                   'GGGGGGGG'])
add_tile('ventV', ['BGBGBGBG',
                   'BGBGBGBG',
                   'BGBGBGBG',
                   'BGBGBGBG',
                   'BGBGBGBG',
                   'BGBGBGBG',
                   'BGBGBGBG',
                   'BGBGBGBG'])
# turret base ring + cap (2x2 tiles: TL TR / BL BR)
add_tile('turTL', ['GGGGGBBB',
                   'GGGBBRRR',
                   'GGBRRRRR',
                   'GBRRYYYY',
                   'GBRYYRRR',
                   'BRRYRRYY',
                   'BRRYRYYY',
                   'BRRYRYYY'])
add_tile('turTR', ['BBBGGGGG',
                   'RRRBBGGG',
                   'RRRRRBGG',
                   'YYYYRRBG',
                   'RRRYYRBG',
                   'YYRRYRRB',
                   'YYYRYRRB',
                   'YYYRYRRB'])
add_tile('turBL', ['BRRYRYYY',
                   'BRRYRYYY',
                   'BRRYRRYY',
                   'GBRYYRRR',
                   'GBRRYYYY',
                   'GGBRRRRR',
                   'GGGBBRRR',
                   'GGGGGBBB'])
add_tile('turBR', ['YYYRYRRB',
                   'YYYRYRRB',
                   'YYRRYRRB',
                   'RRRYYRBG',
                   'YYYYRRBG',
                   'RRRRRBGG',
                   'RRRBBGGG',
                   'BBBGGGGG'])
# trench (dark channel) with hazard edge
add_tile('trench', ['BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB'])
add_tile('trenchT', ['RYRYRYRY',
                     'YRYRYRYR',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB'])
add_tile('trenchB', ['BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'YRYRYRYR',
                     'RYRYRYRY'])
add_tile('trenchPipe', ['BBBBBBBB',
                        'BBBBBBBB',
                        'BYYYYYYB',
                        'BGGGGGGB',
                        'BBBBBBBB',
                        'BBBBBBBB',
                        'BBBBBBBB',
                        'BBBBBBBB'])
# pipes
add_tile('pipeH', ['GGGGGGGG',
                   'GGGGGGGG',
                   'YYYYYYYY',
                   'YGYGYGYG',
                   'BBBBBBBB',
                   'GGGGGGGG',
                   'GGGGGGGG',
                   'GGGGGGGG'])
add_tile('pipeV', ['GGYYBBGG',
                   'GGYGBBGG',
                   'GGYYBBGG',
                   'GGYGBBGG',
                   'GGYYBBGG',
                   'GGYGBBGG',
                   'GGYYBBGG',
                   'GGYGBBGG'])
add_tile('pipeX', ['GGYYBBGG',
                   'GGYGBBGG',
                   'YYYYYYYY',
                   'YGYGYGYG',
                   'BBBBBBBB',
                   'GGYGBBGG',
                   'GGYYBBGG',
                   'GGYGBBGG'])
# hazard stripe plate
add_tile('hazard', ['RYGGGRYG',
                    'YGGGRYGG',
                    'GGGRYGGG',
                    'GGRYGGGR',
                    'GRYGGGRY',
                    'RYGGGRYG',
                    'YGGGRYGG',
                    'GGGRYGGG'])
# reactor / engine glow
add_tile('glowA', ['BBBBBBBB',
                   'BRRRRRRB',
                   'BRYYYYRB',
                   'BRYYYYRB',
                   'BRYYYYRB',
                   'BRYYYYRB',
                   'BRRRRRRB',
                   'BBBBBBBB'])
add_tile('glowB', ['BBBBBBBB',
                   'BRYRYRYB',
                   'BYRYRYRB',
                   'BRYRYRYB',
                   'BYRYRYRB',
                   'BRYRYRYB',
                   'BYRYRYRB',
                   'BBBBBBBB'])
# runway / landing strip
add_tile('runway', ['BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB',
                    'YYYYBBBB',
                    'YYYYBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB',
                    'BBBBBBBB'])
add_tile('runwayE', ['YYYYYYYY',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'BBBBBBBB',
                     'YYYYYYYY'])
# antenna / dish
add_tile('dishTL', ['GGGGGGGG',
                    'GGGGYYYY',
                    'GGYYGGGG',
                    'GYGGGGBB',
                    'GYGGBBBB',
                    'GYGBBGGG',
                    'GYGBGGGG',
                    'GYGBGGGG'])
add_tile('dishTR', ['GGGGGGGG',
                    'YYYYGGGG',
                    'GGGGYYGG',
                    'BBGGGGYG',
                    'BBBBGGYG',
                    'GGGBBGYG',
                    'GGGGBGYG',
                    'GGGGBGYG'])
add_tile('dishBL', ['GYGBGGGG',
                    'GYGBGGGG',
                    'GYGBBGGG',
                    'GYGGBBBB',
                    'GYGGGGBB',
                    'GGYYGGGG',
                    'GGGGYYYY',
                    'GGGGGGGG'])
add_tile('dishBR', ['GGGGBGYG',
                    'GGGGBGYG',
                    'GGGBBGYG',
                    'BBBBGGYG',
                    'BBGGGGYG',
                    'GGGGYYGG',
                    'YYYYGGGG',
                    'GGGGGGGG'])

# gun emplacement: dark socket with a yellow rim; the gun itself is a sprite on top
SOCKET = [
    'GGGGGYYYYYYGGGGG',
    'GGYYYBBBBBBYYYGG',
    'GYYBBBBBBBBBBYYG',
    'GYBBBBBBBBBBBBYG',
    'GYBBBBBBBBBBBBYG',
    'YBBBBBBBBBBBBBBY',
    'YBBBBBBBBBBBBBBY',
    'YBBBBBBBBBBBBBBY',
    'YBBBBBBBBBBBBBBY',
    'YBBBBBBBBBBBBBBY',
    'YBBBBBBBBBBBBBBY',
    'GYBBBBBBBBBBBBYG',
    'GYBBBBBBBBBBBBYG',
    'GYYBBBBBBBBBBYYG',
    'GGYYYBBBBBBYYYGG',
    'GGGGGYYYYYYGGGGG',
]
for nm, (r0, c0) in (('turTL', (0, 0)), ('turTR', (0, 8)), ('turBL', (8, 0)), ('turBR', (8, 8))):
    TILES[TNAME[nm]] = tile_from_art([row[c0:c0 + 8] for row in SOCKET[r0:r0 + 8]])

assert len(TILES) < 64, len(TILES)
T = TNAME

# ------------------------------------------------------------------ hull map
MAP_ROWS = 6
MAP_COLS = 192        # 192 tiles * 8 px = 1536 px = 12 screens
rng = random.Random(0x5EED)
hull = [[T['plate']] * MAP_COLS for _ in range(MAP_ROWS)]

# base plating: seams every 4 tile columns / 3 tile rows, rivets in a rhythm
for r in range(MAP_ROWS):
    for c in range(MAP_COLS):
        sr = (c % 4) == 3
        sb = (r % 3) == 2
        riv = ((c * 7 + r * 5) % 6) == 0
        if sr and sb:
            t = 'rivetRB' if riv else 'seamRB'
        elif sr:
            t = 'rivetR' if riv else 'seamR'
        elif sb:
            t = 'rivetB' if riv else 'seamB'
        else:
            t = 'rivet' if riv else 'plate'
        hull[r][c] = T[t]


def put(c0, r0, name):
    if 0 <= r0 < MAP_ROWS:
        hull[r0][c0 % MAP_COLS] = T[name]


def block(c0, r0, w, h, style='blk'):
    for dr in range(h):
        for dc in range(w):
            top = dr == 0
            bot = dr == h - 1
            lef = dc == 0
            rig = dc == w - 1
            name = style + ('T' if top else 'B' if bot else '') + ('L' if lef else 'R' if rig else '')
            if not top and not bot and not lef and not rig:
                name = style + 'C'
            if (top or bot) and not lef and not rig:
                name = style + ('T' if top else 'B')
            if not top and not bot:
                name = style + ('L' if lef else 'R' if rig else 'C')
            if h == 1:
                name = style + 'T' if not (lef or rig) else style + ('TL' if lef else 'TR')
            put(c0 + dc, r0 + dr, name)


TURRETS = []


def turret(c0, r0):
    if r0 + 1 < MAP_ROWS:
        TURRETS.append((c0, r0))
    put(c0, r0, 'turTL'); put(c0 + 1, r0, 'turTR')
    put(c0, r0 + 1, 'turBL'); put(c0 + 1, r0 + 1, 'turBR')


def dish(c0, r0):
    put(c0, r0, 'dishTL'); put(c0 + 1, r0, 'dishTR')
    put(c0, r0 + 1, 'dishBL'); put(c0 + 1, r0 + 1, 'dishBR')


def trench(c0, w, r0=2, h=3, pipes=True):
    for dc in range(w):
        for dr in range(h):
            name = 'trenchT' if dr == 0 else 'trenchB' if dr == h - 1 else 'trench'
            if pipes and dr == 1 and dc % 5 == 2:
                name = 'trenchPipe'
            put(c0 + dc, r0 + dr, name)


def pipe_run(c0, r0, w):
    for dc in range(w):
        put(c0 + dc, r0, 'pipeH')


def vents(c0, r0, w, h):
    for dc in range(w):
        for dr in range(h):
            put(c0 + dc, r0 + dr, 'ventA' if (dc % 2) == 0 else 'ventV')


def engine(c0, r0, w, h):
    for dc in range(w):
        for dr in range(h):
            put(c0 + dc, r0 + dr, 'glowA' if (dc + dr) % 2 == 0 else 'glowB')


def hazard(c0, r0, w, h):
    for dc in range(w):
        for dr in range(h):
            put(c0 + dc, r0 + dr, 'hazard')


# --- section 0 (cols 0..15): bow structures
block(2, 0, 5, 2, 'blk'); turret(9, 1); block(12, 3, 3, 2, 'dk')
# --- section 1 (16..31)
trench(16, 14, 2, 3); block(18, 0, 3, 2, 'dk'); block(26, 0, 4, 2, 'blk'); block(18, 5, 4, 2, 'blk'); turret(27, 5)
# --- section 2 (32..47)
dish(34, 0); block(38, 1, 4, 3, 'dk'); turret(44, 4); vents(33, 4, 4, 2); pipe_run(38, 5, 8)
# --- section 3 (48..63)
block(49, 0, 6, 2, 'blk'); trench(48, 10, 4, 3, False); block(58, 1, 4, 4, 'blk'); turret(52, 1); dish(60, 5)
# --- section 4 (64..79): hazard corridor
hazard(64, 2, 14, 1); block(65, 0, 3, 2, 'dk'); block(72, 4, 4, 3, 'dk'); turret(68, 4); vents(76, 0, 3, 2)
# --- section 5 (80..95): command tower
block(82, 0, 8, 3, 'blk'); block(84, 3, 4, 3, 'dk'); turret(80, 5); turret(90, 4); dish(92, 1)
# --- section 6 (96..111): engine room
engine(96, 0, 6, 2); engine(96, 5, 6, 2); trench(102, 10, 2, 3); block(104, 0, 3, 2, 'dk'); vents(108, 4, 4, 2); turret(100, 3)
# --- section 7 (112..127)
block(113, 4, 5, 3, 'blk'); dish(119, 1); block(121, 3, 4, 3, 'dk'); turret(114, 0); pipe_run(112, 2, 15)
# --- section 8 (128..143): landing runway
for c in range(128, 144):
    for r in (2, 3, 4):
        put(c, r, 'runway' if r == 3 else 'trench')
    put(c, 1, 'seamB')
for r in (2, 3, 4):
    put(128, r, 'runwayE'); put(143, r, 'runwayE')
block(130, 5, 3, 2, 'blk'); block(138, 0, 4, 2, 'blk')
# --- section 9 (144..159)
turret(146, 0); block(149, 1, 3, 3, 'dk'); vents(153, 0, 5, 2); block(144, 4, 4, 3, 'blk'); turret(155, 4)
# --- section 10 (160..175)
trench(160, 16, 3, 3); block(161, 0, 5, 2, 'blk'); dish(168, 0); block(163, 6, 6, 1, 'dk'); turret(172, 5)
# --- section 11 (176..191): stern
engine(176, 1, 4, 2); engine(176, 4, 4, 2); block(182, 0, 6, 3, 'blk'); block(183, 3, 4, 3, 'dk'); turret(188, 4); dish(189, 0)

# ------------------------------------------------------------------ tile column data
# TILE0 / TILE1 tables: id*8 bytes each, byte b (0: left 4 px, 1: right 4 px)
tile0 = bytearray()
tile1 = bytearray()
for t in TILES:
    for row in range(8):
        tile0.append(pack4(t[row, 0:4]))
    for row in range(8):
        pass
for t in TILES:
    pass
tile0 = bytearray()
tile1 = bytearray()
for t in TILES:
    for row in range(8):
        tile0.append(pack4(t[row, 0:4]))
for t in TILES:
    for row in range(8):
        tile1.append(pack4(t[row, 4:8]))
# pad both tables to 64 tiles so that the engine can use a fixed offset
while len(tile0) < 64 * 8:
    tile0.append(0)
while len(tile1) < 64 * 8:
    tile1.append(0)

# map: column-major, MAP_ROWS bytes per tile column
mapdata = bytearray()
for c in range(MAP_COLS):
    for r in range(MAP_ROWS):
        mapdata.append(hull[r][c])

# preview of hull
def render_px(arr, scale=3):
    h, w = arr.shape
    img = Image.new('RGB', (w, h))
    for y in range(h):
        for x in range(w):
            img.putpixel((x, y), PALETTE[int(arr[y, x])])
    return img.resize((w * scale, h * scale * 3 // 2), Image.NEAREST)


full = np.zeros((MAP_ROWS * 8, MAP_COLS * 8), dtype=np.uint8)
for r in range(MAP_ROWS):
    for c in range(MAP_COLS):
        full[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = TILES[hull[r][c]]
for k in range(3):
    seg = full[:, k * 512:(k + 1) * 512]
    render_px(seg, 2).save(os.path.join(OUT, 'hull_preview_%d.png' % k))

# ------------------------------------------------------------------ sprites
def shift_sprite(col, al, phase, wb):
    """Return list of rows of (mask, data) bytes for the sprite shifted right by phase px."""
    h, w = col.shape
    rows = []
    for y in range(h):
        mrow = []
        drow = []
        for b in range(wb):
            m = 0
            d = 0
            for p in range(4):
                x = b * 4 + p - phase
                m <<= 2
                d <<= 2
                if 0 <= x < w and al[y, x]:
                    d |= int(col[y, x])
                else:
                    m |= 3
            mrow.append(m)
            drow.append(d)
        rows.append((mrow, drow))
    return rows


def sprite_bytes(col, al, wb):
    """All four x-phases, interleaved [mask,data] per byte."""
    out = bytearray()
    for ph in range(4):
        for mrow, drow in shift_sprite(col, al, ph, wb):
            for m, d in zip(mrow, drow):
                out.append(m)
                out.append(d)
    return out


# --- player ship (facing right), 16 x 7
SHIP_R = [
    '.BY.............',
    '..YYB...........',
    '..BYYYYY.......B',
    'RRRYYYYYYYYYYYYR',
    '..BYYYYY.......B',
    '..YYB...........',
    '.BY.............',
]
# refine: nose cone, cockpit
SHIP_R = [
    '..YB............',
    '..BYYY..........',
    '...BYYYYYB......',
    'RRBYYBYYYYYYYYRR',
    '...BYYYYYB......',
    '..BYYY..........',
    '..YB............',
]
SHIP_R = [
    '.YB.............',
    '..YYB...........',
    '..BYYYYYYY......',
    'RRYYYRRYYYYYYYYR',
    '..BYYYYYYY......',
    '..YYB...........',
    '.YB.............',
]
ship_col, ship_al = art(SHIP_R)
SHIP_W, SHIP_H = 16, 7


def squeeze(col, al, scale, mirror, under=False):
    """Horizontal squeeze of a sprite about its centre to emulate a roll about the vertical axis."""
    h, w = col.shape
    nw = max(2, int(round(w * abs(scale))))
    ncol = np.zeros((h, w), dtype=np.uint8)
    nal = np.zeros((h, w), dtype=np.uint8)
    x0 = (w - nw) // 2
    src = (col[:, ::-1], al[:, ::-1]) if mirror else (col, al)
    for x in range(nw):
        # source span for destination pixel x
        sx0 = x * w / nw
        sx1 = (x + 1) * w / nw
        for y in range(h):
            votes = {}
            cover = 0.0
            xi = int(math.floor(sx0))
            while xi < sx1 and xi < w:
                lo = max(sx0, xi)
                hi = min(sx1, xi + 1)
                wgt = hi - lo
                if src[1][y, xi]:
                    votes[int(src[0][y, xi])] = votes.get(int(src[0][y, xi]), 0) + wgt
                    cover += wgt
                xi += 1
            if cover >= 0.5 * (sx1 - sx0):
                c = max(votes, key=votes.get)
                if under and c == Y:
                    c = B if (x + y) % 2 == 0 else Y     # underside shading
                ncol[y, x0 + x] = c
                nal[y, x0 + x] = 1
    return ncol, nal


# flip: theta = 0 .. 180 in 8 steps
FLIP_FRAMES = []
for k in range(9):
    th = math.radians(22.5 * k)
    s = math.cos(th)
    if k == 0:
        FLIP_FRAMES.append((ship_col.copy(), ship_al.copy()))
    elif k == 8:
        FLIP_FRAMES.append((ship_col[:, ::-1].copy(), ship_al[:, ::-1].copy()))
    elif k == 4:
        # edge-on: a thin spine with nose/tail highlights
        spine = ['....YB..........',
                 '....YB..........',
                 '....YB..........',
                 '....RY..........',
                 '....YB..........',
                 '....YB..........',
                 '....YB..........']
        # build 4px wide edge-on view centred
        edge = ['......YB........',
                '......YB........',
                '.....BYYB.......',
                '.....RYYR.......',
                '.....BYYB.......',
                '......YB........',
                '......YB........']
        FLIP_FRAMES.append(art(edge))
    else:
        c, a = squeeze(ship_col, ship_al, s, mirror=(s < 0), under=(k > 4))
        FLIP_FRAMES.append((c, a))

# banking variants (at the two rest poses)
def bank(col, al, up):
    c = col.copy()
    a = al.copy()
    h, w = c.shape
    if up:
        # far (top) wing foreshortened, near (bottom) wing emphasised
        for x in range(w):
            c[0, x] = 0; a[0, x] = 0
        for x in range(w):
            if a[1, x] and x < 5:
                a[1, x] = 0
        # add under-shadow below near wing
        for x in range(1, 6):
            if a[5, x]:
                c[5, x] = Y
        for x in range(1, 6):
            c[6, x] = B if a[6, x] else c[6, x]
    else:
        for x in range(w):
            c[6, x] = 0; a[6, x] = 0
        for x in range(w):
            if a[5, x] and x < 5:
                a[5, x] = 0
        for x in range(1, 6):
            if a[1, x]:
                c[1, x] = Y
        for x in range(1, 6):
            c[0, x] = B if a[0, x] else c[0, x]
    return c, a


bank_frames = []
for base_idx, mirror in ((0, False), (8, True)):
    c0, a0 = FLIP_FRAMES[base_idx]
    bank_frames.append(bank(c0, a0, True))
    bank_frames.append(bank(c0, a0, False))
SHIP_FRAMES = FLIP_FRAMES + bank_frames      # 0..8 flip, 9 R-up, 10 R-down, 11 L-up, 12 L-down

# --- enemies
ENEMY_A = [
    '...RRRRRR...',
    '..RYYRRYYR..',
    '.RRYBRRBYRR.',
    'RRRRRRRRRRRR',
    '.RRBRRRRBRR.',
    '..RRB..BRR..',
    '...R....R...',
]
ENEMY_A2 = [
    '...RRRRRR...',
    '..RYYRRYYR..',
    '.RRBYRRYBRR.',
    'RRRRRRRRRRRR',
    '.RRRBRRBRRR.',
    '..R.RBBR.R..',
    '....R..R....',
]
ENEMY_B = [
    '..YYYY..',
    '.YRRRRY.',
    'YRBYYBRY',
    'YRRRRRRY',
    '.YRBBRY.',
    '..Y..Y..',
]
EXPL = [
    ['............',
     '............',
     '....Y..Y....',
     '.....YY.....',
     '....Y..Y....',
     '............',
     '............'],
    ['............',
     '..R..Y..R...',
     '...RYYYR....',
     '.Y.YRRRY.Y..',
     '...RYYYR....',
     '..R..Y..R...',
     '............'],
    ['.R...Y...R..',
     '..R.....R...',
     '.....RR.....',
     'Y..R....R..Y',
     '.....RR.....',
     '..R.....R...',
     '.R...Y...R..'],
]
TURGUN = [
    '...YY...',
    '..YRRY..',
    '.YRBBRY.',
    '.YRBBRY.',
    '..YRRY..',
    '...YY...',
]
TURGUN2 = [
    '...YY...',
    '..YYYY..',
    '.YYRRYY.',
    '.YYRRYY.',
    '..YYYY..',
    '...YY...',
]
EBULLET = [
    '.YY.',
    'YRRY',
    '.YY.',
]
BULLET = [
    'YYYYYY',
    '.RYYR.',
]

# ------------------------------------------------------------------ font (3x5, bg blue)
GLYPHS = {
    '0': ['111', '101', '101', '101', '111'], '1': ['010', '110', '010', '010', '111'],
    '2': ['111', '001', '111', '100', '111'], '3': ['111', '001', '111', '001', '111'],
    '4': ['101', '101', '111', '001', '001'], '5': ['111', '100', '111', '001', '111'],
    '6': ['111', '100', '111', '101', '111'], '7': ['111', '001', '010', '010', '010'],
    '8': ['111', '101', '111', '101', '111'], '9': ['111', '101', '111', '001', '111'],
    'A': ['010', '101', '111', '101', '101'], 'B': ['110', '101', '110', '101', '110'],
    'C': ['011', '100', '100', '100', '011'], 'D': ['110', '101', '101', '101', '110'],
    'E': ['111', '100', '110', '100', '111'], 'F': ['111', '100', '110', '100', '100'],
    'G': ['011', '100', '101', '101', '011'], 'H': ['101', '101', '111', '101', '101'],
    'I': ['111', '010', '010', '010', '111'], 'J': ['001', '001', '001', '101', '010'],
    'K': ['101', '101', '110', '101', '101'], 'L': ['100', '100', '100', '100', '111'],
    'M': ['101', '111', '111', '101', '101'], 'N': ['110', '101', '101', '101', '101'],
    'O': ['010', '101', '101', '101', '010'], 'P': ['110', '101', '110', '100', '100'],
    'Q': ['010', '101', '101', '111', '011'], 'R': ['110', '101', '110', '101', '101'],
    'S': ['011', '100', '010', '001', '110'], 'T': ['111', '010', '010', '010', '010'],
    'U': ['101', '101', '101', '101', '111'], 'V': ['101', '101', '101', '101', '010'],
    'W': ['101', '101', '111', '111', '101'], 'X': ['101', '101', '010', '101', '101'],
    'Y': ['101', '101', '010', '010', '010'], 'Z': ['111', '001', '010', '100', '111'],
    '+': ['000', '010', '111', '010', '000'], '-': ['000', '000', '111', '000', '000'],
    ' ': ['000'] * 5, ':': ['000', '010', '000', '010', '000'],
}
CHARSET = ' 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+-:'


def glyph_bytes(ch):
    rows = GLYPHS[ch]
    out = []
    for r in rows:
        px = [Y if b == '1' else B for b in r] + [B]
        out.append(pack4(px))
    return out


def textcodes(s):
    return [CHARSET.index(c) for c in s]


# ------------------------------------------------------------------ emit assembly
def db_lines(label, data, per=16, comment=None):
    lines = []
    if comment:
        lines.append('; ' + comment)
    lines.append(label + ':')
    for i in range(0, len(data), per):
        chunk = data[i:i + per]
        lines.append('    db ' + ','.join('$%02X' % b for b in chunk))
    return lines


def wb_for(w):
    return (w + 3 + 3) // 4 if False else (w + 3 + 3) // 4  # placeholder (overridden below)


def wbytes(w):
    # a w-pixel sprite shifted by 0..3 pixels spans at most ceil((w+3)/4) bytes
    return (w + 3 + 3) // 4


asm = []
asm.append('; ---- generated by tools/gen_assets.py - do not edit ----')

# classes: 0 ship, 1 enemyA, 2 enemyB, 3 bullet, 4 explosion
classes = []


def emit_frames(name, frames, w, h):
    wb = wbytes(w)
    base_label = name
    addrs = []
    for i, (c, a) in enumerate(frames):
        assert c.shape == (h, w), (name, i, c.shape, (h, w))
        data = sprite_bytes(c, a, wb)
        asm.extend(db_lines('%s_%d' % (name, i), list(data)))
        addrs.append('%s_%d' % (name, i))
    asm.append('%s_TAB:' % name)
    asm.append('    dw ' + ','.join(addrs))
    phasesz = h * wb * 2
    assert phasesz < 256
    classes.append((wb, h, wb * 2, phasesz))
    return wb, phasesz


emit_frames('SHIPFR', SHIP_FRAMES, 16, 7)
ea = [art(ENEMY_A), art(ENEMY_A2)]
emit_frames('ENAFR', ea, 12, 7)
eb = [art(ENEMY_B), art(ENEMY_B)]
emit_frames('ENBFR', eb, 8, 6)
emit_frames('BULFR', [art(BULLET)], 6, 2)
emit_frames('EXPFR', [art(e) for e in EXPL], 12, 7)
emit_frames('TURFR', [art(TURGUN), art(TURGUN2)], 8, 6)
emit_frames('EBLFR', [art(EBULLET)], 4, 3)

solid = bytearray(64)
for nm, idx in TNAME.items():
    if nm.startswith('blk') or nm.startswith('dk'):
        solid[idx] = 1
asm.extend(db_lines('SOLID', list(solid), 16, 'solid (damaging) hull tiles'))
asm.append('NTUR equ %d' % len(TURRETS))
asm.append('TURLIST:   ; world x (gun left), y (gun top), pad')
for (c0, r0) in TURRETS:
    asm.append('    dw %d' % (c0 * 8 + 4))
    asm.append('    db %d,0' % (16 + r0 * 8 + 5))
asm.append('CLSTAB:   ; wb, h, rowlen, phasesz')
for c in classes:
    asm.append('    db %d,%d,%d,%d' % c)

# hull data
asm.extend(db_lines('TILE0', list(tile0), 16, 'tile left-half columns, 8 bytes per tile'))
asm.extend(db_lines('TILE1', list(tile1), 16, 'tile right-half columns'))
asm.extend(db_lines('HULLMAP', list(mapdata), 14, 'map, 6 tile rows per column, 192 columns'))

# font
gl = []
for ch in CHARSET:
    gl.extend(glyph_bytes(ch))
asm.extend(db_lines('GLYPHS', gl, 5, 'font: 5 bytes per glyph'))

# text strings (character indexes)
def string(label, s):
    asm.append('%s:  db %s,255' % (label, ','.join(str(c) for c in textcodes(s))))


string('TXT_SL', 'SL')
string('TXT_LT', 'LT')
string('TXT_SP', 'SP')
string('TXT_SC', 'SC')
string('TXT_VIBED', 'VIBED BY BPM 2026')
string('TXT_TITLE', 'VZURID PHASE 2')
string('TXT_EN', 'EN')
string('TXT_LV', 'LV')
string('TXT_WV', 'WV')
string('TXT_GAMEOVER', 'GAME OVER')
string('TXT_BLANK', '         ')

with open(os.path.join(OUT, 'assets.asm'), 'w') as f:
    f.write('\n'.join(asm) + '\n')

# previews: sprites sheet
sheet = Image.new('RGB', (16 * 14 * 4, 7 * 3 * 4 + 40), (20, 20, 20))
x = 4
for i, (c, a) in enumerate(SHIP_FRAMES):
    for yy in range(7):
        for xx in range(16):
            p = (60, 60, 60)
            if a[yy, xx]:
                p = PALETTE[int(c[yy, xx])]
            for dx in range(4):
                for dy in range(6):
                    sheet.putpixel((x + xx * 4 + dx, 4 + yy * 6 + dy), p) if x + xx * 4 + dx < sheet.width and 4 + yy * 6 + dy < sheet.height else None
    x += 16 * 4 + 4
sheet.save(os.path.join(OUT, 'ship_frames.png'))

print('tiles:', len(TILES), 'map bytes:', len(mapdata), 'asm lines:', len(asm))
print('classes:', classes)
