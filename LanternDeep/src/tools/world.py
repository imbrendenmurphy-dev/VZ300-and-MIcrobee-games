"""THE LANTERN DEEP - world compiler and reference renderer.

Builds the showcase area (the Lanternless Corridor and the Drowned Hall)
from a semantic layout, auto-tiles it into PCG tiles with light variants,
computes static light, zones and the torch ray-trees, and renders frames in
Python exactly the way the Z80 engine does (this is the test oracle).
"""
import math
import random
import numpy as np
from PIL import Image

import art

COLS, ROWS = 80, 22          # play area (screen rows 0..21)
STRIDE = 128                 # map buffers: 24 rows x 128 (1-cell border)
MAPROWS = ROWS + 2
EDGE = 0xFF                  # border tile: stops rays, never drawn

# Premium palette as MAME draws it (RGBI; colour 8 is dark grey).
PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 192, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255)]
# Colour numbers
BLK, RED, GRN, YEL, BLU, MAG, CYN, GRY, DGR, BRED, BGRN, BYEL, BBLU, BMAG, BCYN, WHT = range(16)

TINTS = ['warm', 'cool', 'magic', 'lava']

# ------------------------------------------------------------------ ramps
# ramp[tint] = list of 8 (variant, fg, bg) for light 0..7. Light 0 is the
# "remembered" look (only used for explored, currently dark cells).
# Backgrounds stay black almost everywhere: light falls off through colour
# (white > yellow > ochre > grey) and ink density (variants 0 > 1 > 2), so
# the lit area has soft edges instead of coloured rectangles.
MEM_WALL = (2, BLU, BLK)
MEM_FLOOR = (3, BLU, BLK)

# colour ladders per tint (dark .. bright)
LADDER = {
    'warm': (DGR, YEL, BYEL, WHT),
    'cool': (BLU, CYN, BCYN, WHT),
    'magic': (BLU, MAG, BMAG, WHT),
    'lava': (RED, BRED, BYEL, WHT),
}


def ramp_solid(t, mem=MEM_WALL):
    a, b, c, d = LADDER[t]
    # surfaces that catch the light: walls, carved stone
    return [mem, (2, a, BLK), (1, a, BLK), (1, b, BLK), (0, b, BLK), (0, c, BLK), (0, c, BLK), (0, d, BLK)]


def ramp_floor(t, mem=MEM_FLOOR):
    a, b, c, d = LADDER[t]
    # ground: one step darker than walls at the same light
    return [mem, (2, a, BLK), (1, a, BLK), (0, a, BLK), (1, b, BLK), (0, b, BLK), (0, b, BLK), (1, c, BLK)]


def ramp_cap(t):
    a, b, c, d = LADDER[t]
    return [MEM_WALL, (2, a, BLK), (1, a, BLK), (0, a, BLK), (0, a, BLK), (0, b, BLK), (0, b, BLK), (0, c, BLK)]


def R(fn, **kw):
    return {t: fn(t, **kw) for t in TINTS}


def R_fixed(lst):
    return {t: lst for t in TINTS}


RAMPS = {
    'stone': R(ramp_solid),
    'moss': {'warm': [MEM_WALL, (2, DGR, BLK), (1, GRN, BLK), (1, GRN, BLK), (0, GRN, BLK), (0, BGRN, BLK), (0, BGRN, BLK), (0, BYEL, BLK)],
             'cool': [MEM_WALL, (2, BLU, BLK), (1, GRN, BLK), (1, CYN, BLK), (0, CYN, BLK), (0, BGRN, BLK), (0, BCYN, BLK), (0, WHT, BLK)],
             'magic': ramp_solid('magic'), 'lava': ramp_solid('lava')},
    'cap': R(ramp_cap),
    'flag': R(ramp_floor),
    # temple mosaic: gold on black, the brightest band gets a dark red ground
    'mosaic': {'warm': [MEM_FLOOR, (2, DGR, BLK), (1, YEL, BLK), (0, YEL, BLK), (0, YEL, BLK), (0, BYEL, BLK), (0, BYEL, BLK), (0, BYEL, BLK)],
               'cool': [MEM_FLOOR, (2, BLU, BLK), (1, BLU, BLK), (0, BLU, BLK), (0, CYN, BLK), (0, BCYN, BLK), (0, BCYN, BLK), (0, BCYN, BLK)],
               'magic': ramp_floor('magic'), 'lava': ramp_floor('lava')},
    'border': {'warm': [MEM_FLOOR, (2, DGR, BLK), (1, RED, BLK), (0, RED, BLK), (0, RED, BLK), (0, BRED, BLK), (0, BRED, BLK), (0, BYEL, BLK)],
               'cool': [MEM_FLOOR, (2, BLU, BLK), (1, BLU, BLK), (0, BLU, BLK), (0, BBLU, BLK), (0, BBLU, BLK), (0, BCYN, BLK), (0, BCYN, BLK)],
               'magic': ramp_floor('magic'), 'lava': ramp_floor('lava')},
    'marble': {'warm': [MEM_WALL, (2, DGR, BLK), (1, DGR, BLK), (1, GRY, BLK), (0, GRY, BLK), (0, GRY, BLK), (0, WHT, BLK), (0, WHT, BLK)],
               'cool': [MEM_WALL, (2, BLU, BLK), (1, BLU, BLK), (1, CYN, BLK), (0, CYN, BLK), (0, BCYN, BLK), (0, WHT, BLK), (0, WHT, BLK)],
               'magic': ramp_solid('magic'), 'lava': ramp_solid('lava')},
    'water': {'warm': [MEM_FLOOR, (2, BLU, BLK), (1, BLU, BLK), (0, BLU, BLK), (0, BBLU, BLK), (0, CYN, BLK), (0, BCYN, BLK), (0, WHT, BLU)],
              'cool': [MEM_FLOOR, (2, BLU, BLK), (1, BLU, BLK), (0, BBLU, BLK), (0, CYN, BLK), (0, BCYN, BLK), (0, BCYN, BLK), (0, WHT, BLU)],
              'magic': ramp_floor('magic'), 'lava': ramp_floor('lava')},
    'crystal': R_fixed([(1, BCYN, BLK), (0, CYN, BLK), (0, BCYN, BLK), (0, BCYN, BLK), (0, BCYN, BLK), (0, WHT, BLK), (0, WHT, BLK), (0, WHT, BLK)]),
    'flame': R_fixed([(0, YEL, BLK)] + [(0, BYEL, BLK)] * 7),
    'iron': R(ramp_solid),
    'bone': {'warm': [MEM_WALL, (2, DGR, BLK), (1, GRY, BLK), (0, GRY, BLK), (0, GRY, BLK), (0, WHT, BLK), (0, WHT, BLK), (0, WHT, BLK)],
             'cool': [MEM_WALL, (2, BLU, BLK), (1, CYN, BLK), (0, CYN, BLK), (0, BCYN, BLK), (0, WHT, BLK), (0, WHT, BLK), (0, WHT, BLK)],
             'magic': ramp_solid('magic'), 'lava': ramp_solid('lava')},
    'web': {'warm': [MEM_FLOOR, (3, DGR, BLK), (2, DGR, BLK), (1, GRY, BLK), (0, GRY, BLK), (0, GRY, BLK), (0, WHT, BLK), (0, WHT, BLK)],
            'cool': [MEM_FLOOR, (3, BLU, BLK), (2, BLU, BLK), (1, CYN, BLK), (0, CYN, BLK), (0, CYN, BLK), (0, WHT, BLK), (0, WHT, BLK)],
            'magic': ramp_floor('magic'), 'lava': ramp_floor('lava')},
    'gold': {'warm': [MEM_WALL, (2, YEL, BLK), (1, YEL, BLK), (0, YEL, BLK), (0, YEL, BLK), (0, BYEL, BLK), (0, BYEL, BLK), (0, BYEL, RED)],
             'cool': [MEM_WALL, (2, BLU, BLK), (1, CYN, BLK), (0, YEL, BLK), (0, YEL, BLK), (0, BYEL, BLK), (0, BYEL, BLK), (0, BYEL, BLU)],
             'magic': ramp_solid('magic'), 'lava': ramp_solid('lava')},
    'rune': R_fixed([(2, MAG, BLK), (0, MAG, BLK), (0, MAG, BLK), (0, MAG, BLK), (0, BMAG, BLK), (0, BMAG, BLK), (0, BMAG, BLK), (0, WHT, BLK)]),
}
RAMP_IDS = {n: i for i, n in enumerate(RAMPS)}

# cycler phases: some tiles cycle colours with time (runes pulse)
CYCLE = {'rune': [(0, MAG, BLK), (0, BMAG, BLK), (0, WHT, BLK), (0, BMAG, BLK), (0, MAG, BLK), (1, MAG, BLK)]}


# ------------------------------------------------------------------ tiles
class Tile:
    def __init__(self, name, glyph, ramp, opaque=False, solid=False, frames=None, cycle=False, mem=True):
        self.name, self.glyph, self.ramp = name, glyph, ramp
        self.opaque, self.solid = opaque, solid or opaque
        self.frames = frames      # list of glyphs (animation), glyph = frames[0]
        self.cycle = cycle
        self.mem = mem
        self.face_lo = name.startswith('face_lo')
        self.group = None
        self.index = None


class TileSet:
    def __init__(self):
        self.tiles = []
        self.byname = {}
        self.byglyph = {}

    def add(self, name, glyph, ramp, **kw):
        key = (glyph, ramp, kw.get('opaque', False), kw.get('solid', False), kw.get('frames') is not None, kw.get('cycle', False))
        if kw.get('frames') is None and key in self.byglyph:
            t = self.byglyph[key]
            self.byname[name] = t
            return t
        t = Tile(name, glyph, ramp, **kw)
        self.tiles.append(t)
        self.byname[name] = t
        if kw.get('frames') is None:
            self.byglyph[key] = t
        return t


def dilate(g):
    a = art.g_to_array(g)
    b = a.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            b |= np.roll(np.roll(a, dy, 0), dx, 1)
    return art.g_from_array(b)


def overlay(floor, deco):
    """Decoration over a floor: floor grain kept faintly, cleared around the
    decoration so it stays readable with only two colours."""
    hole = art.g_inv(dilate(deco))
    return art.g_or(art.g_and(art.variant(floor, 1), hole), deco)


# ------------------------------------------------------------------ layout
class Room:
    def __init__(self):
        self.sem = [['#'] * COLS for _ in range(ROWS)]   # semantic map
        self.objects = []      # (kind, x, y)
        self.lights = []       # (x, y, tint, max, radius_visual)
        self.zone = np.zeros((ROWS, COLS), dtype=np.uint8)
        self.groups = []       # multi-cell opaque pieces lit as one object

    def carve(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.sem[y][x] = ch

    def at(self, x, y):
        if 0 <= x < COLS and 0 <= y < ROWS:
            return self.sem[y][x]
        return 'E'


def build_showcase():
    r = Room()
    # The Lanternless Corridor: enters from the west edge, 3 rows high.
    r.carve(0, 9, 37, 11, '.')
    # a collapsed side passage to the south (dead end, rubble)
    r.carve(22, 12, 24, 14, '.')
    # The Drowned Hall
    r.carve(38, 3, 77, 19, ',')
    # mosaic border band one cell inside the hall walls
    for x in range(38, 78):
        r.sem[3][x] = 'b'
        r.sem[19][x] = 'b'
    for y in range(3, 20):
        r.sem[y][38] = 'b'
        r.sem[y][77] = 'b'
    # doorway stays plain flagstone, arch over it
    for y in (9, 10, 11):
        r.sem[y][36] = 'd'
        r.sem[y][37] = 'd'
    # pool: an ellipse drawn at pixel resolution so the carved rim is smooth
    r.pool = (59.5, 14.0, 9.6, 3.4)
    cx, cy, rx, ry = r.pool
    r.poolbm = {}
    for y in range(7, 20):
        for x in range(45, 75):
            water = rim = 0
            px = np.zeros((8, 8), dtype=np.uint8)
            for py in range(8):
                for pxl in range(8):
                    fx, fy = x + (pxl + 0.5) / 8, y + (py + 0.5) / 8
                    d = math.hypot((fx - cx) / rx, (fy - cy) / ry)
                    if d < 1.0:
                        water += 1
                    elif d < 1.0 + 0.55 / ry:
                        rim += 1
                        px[py, pxl] = 1
            if water == 64:
                r.sem[y][x] = '~'
            elif rim or water:
                if r.sem[y][x] in ',b':
                    r.sem[y][x] = 'o'
                    # a few ripples survive in the water part of edge cells
                    r.poolbm[(x, y)] = px
    r.zone[:, :] = 1
    r.zone[:, 36:] = 2
    # set pieces (kind, x, y) - top-left cell
    r.objects += [('crystal', 39, 4), ('statue', 56, 3), ('brazier', 52, 4), ('brazier', 63, 4),
                  ('pillar', 44, 7), ('pillar', 72, 7), ('pillar', 44, 15), ('pillar', 72, 15),
                  ('tablet', 57, 8), ('chest', 76, 18),
                  ('bones', 9, 11), ('skull', 10, 10), ('rubble', 23, 13), ('rubble', 24, 14), ('rubble', 22, 14),
                  ('rubble', 25, 11), ('web', 0, 9), ('web', 38, 19), ('web', 77, 3), ('urn', 31, 9),
                  ('bones', 74, 19), ('rubble', 40, 18), ('sconce', 18, 8),
                  ('puddle', 14, 11), ('puddle', 27, 9), ('puddle', 6, 10)]
    # static light sources (x, y, tint, max level, visual radius)
    r.lights += [(40, 7, 'cool', 7, 13.0), (52, 5, 'warm', 6, 7.5), (63, 5, 'warm', 6, 7.5)]
    return r


# ------------------------------------------------------------------ auto-tiler
def is_wall(ch):
    return ch in '#E'


def build_tiles(room):
    ts = TileSet()
    rnd = random.Random(7)
    tilemap = [[None] * COLS for _ in range(ROWS)]

    # ---- textures
    masonry = [art.masonry_strip(11 + k, 8, 2, crack=0.2 if k else 0.08, holes=0.08 * k) for k in range(3)]
    mason_cells = [art.cut(m, 8, 2) for m in masonry]
    paving = [art.cut(art.paving_patch(100 + k, cracked=0.25 + 0.1 * k), 4, 2) for k in range(3)]
    mosaic = art.cut(art.mosaic_patch(), 2, 2)
    meander_h = art.cut(art.meander_strip(False), 2, 1)[0]
    meander_v = [row[0] for row in art.cut(art.meander_strip(True), 1, 2)]

    def floor_glyph(x, y):
        ch = room.sem[y][x]
        if ch in '.d':
            patch = paving[((x // 4) * 7 + (y // 2) * 3 + (x // 4) * (y // 2)) % 3]
            return patch[y % 2][x % 4], 'flag'
        if ch == 'b':
            if x in (38, 77) and y not in (3, 19):
                return meander_v[y % 2], 'border'
            return meander_h[x % 2], 'border'
        g = mosaic[y % 2][x % 2]
        h = (x * 73 + y * 151) % 17
        if h < 3:      # missing tesserae
            g = art.g_and(g, DAMAGE[h])
        return g, 'mosaic'

    for y in range(ROWS):
        for x in range(COLS):
            ch = room.sem[y][x]
            if is_wall(ch):
                below = room.at(x, y + 1)
                below2 = room.at(x, y + 2)
                if not is_wall(below) and below != 'E':
                    strip = mason_cells[(x // 8 + y) % 3]
                    tilemap[y][x] = ts.add('face_lo_%d_%d' % (x % 8, (x // 8 + y) % 3), strip[1][x % 8], 'stone', opaque=True)
                elif is_wall(below) and not is_wall(below2) and below2 != 'E':
                    strip = mason_cells[(x // 8 + y + 1) % 3]
                    mossy = False
                    tilemap[y][x] = ts.add('face_hi', strip[0][x % 8], 'moss' if mossy else 'stone', opaque=True)
                else:
                    edges = set()
                    for d, (dx, dy) in {'N': (0, -1), 'S': (0, 1), 'W': (-1, 0), 'E': (1, 0)}.items():
                        n = room.at(x + dx, y + dy)
                        if not is_wall(n) and n != 'E':
                            edges.add(d)
                        # wall faces count as open for side rims
                        if d in 'WE' and is_wall(n):
                            nb = room.at(x + dx, y + 1)
                            if not is_wall(nb) and nb != 'E':
                                pass
                    g = art.rock_cap((x * 31 + y * 17) % 5, edges)
                    tilemap[y][x] = ts.add('cap', g, 'cap', opaque=True)
            elif ch == '~':
                tilemap[y][x] = None  # filled below (animated)
            elif ch == 'o':
                g = art.g_from_array(room.poolbm[(x, y)])
                tilemap[y][x] = ts.add('rim', g, 'marble', solid=True)
            else:
                g, ramp = floor_glyph(x, y)
                # ambient occlusion under wall faces
                if is_wall(room.at(x, y - 1)):
                    g = art.g_and(g, (0x00, 0x55, 0xAA, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF))
                tilemap[y][x] = ts.add('floor', g, ramp)

    # ---- water: two animated tiles (left/right halves of the ripple strip)
    wf = art.water_frames()
    water = [ts.add('water%d' % k, wf[0][k], 'water', solid=True, frames=[f[k] for f in wf]) for k in range(2)]
    for y in range(ROWS):
        for x in range(COLS):
            if room.sem[y][x] == '~':
                tilemap[y][x] = water[x % 2]

    # ---- arch over the doorway with three pulsing rune stones
    for i, (x, y) in enumerate([(36, 8), (37, 8), (35, 8)]):
        pass
    rune_tiles = [ts.add('rune%d' % k, art.RUNES[k], 'rune', opaque=True, cycle=True) for k in range(3)]
    tilemap[8][36] = rune_tiles[0]
    tilemap[8][37] = rune_tiles[1]
    tilemap[12][36] = ts.add('runelow', art.RUNES[2], 'rune', opaque=True, cycle=True)

    # ---- set pieces
    piece_bitmaps = {
        'statue': (4, 5, art.paint(4, 5, art.statue_paint), 'marble', True),
        'crystal': (3, 4, art.paint(3, 4, art.crystal_paint), 'crystal', False),
        'pillar': (2, 3, art.paint(2, 3, art.pillar_paint), 'marble', True),
        'brazier': (1, 2, None, 'iron', False),
    }
    flames = art.FLAME
    for kind, x0, y0 in room.objects:
        if kind in ('statue', 'crystal', 'pillar'):
            w, h, bm, ramp, opaque = piece_bitmaps[kind]
            cells = art.cut(bm, w, h)
            for cy in range(h):
                for cx in range(w):
                    if kind == 'crystal':
                        # shimmer: 2 frames, the second with facets shifted
                        g0 = cells[cy][cx]
                        g1 = shimmer(g0, cx + cy)
                        t = ts.add('%s_%d_%d' % (kind, cx, cy), g0, ramp, solid=True, frames=[g0, g0, g1, g0])
                    else:
                        t = ts.add('%s_%d_%d' % (kind, cx, cy), cells[cy][cx], ramp, opaque=opaque, solid=True)
                    tilemap[y0 + cy][x0 + cx] = t
            if opaque:
                room.groups.append([(x0 + cx, y0 + cy) for cy in range(h) for cx in range(w)])
        elif kind == 'brazier':
            bm = art.paint(1, 1, art.brazier_paint)
            tilemap[y0][x0] = ts.add('flame', flames[0], 'flame', solid=True, frames=flames)
            tilemap[y0 + 1][x0] = ts.add('bowl', art.cut(bm, 1, 1)[0][0], 'iron', solid=True)
        elif kind == 'puddle':
            base = tilemap[y0][x0]
            fr = [overlay(base.glyph, g) for g in art.puddle_frames()]
            tilemap[y0][x0] = ts.add('puddle_%d' % x0, fr[0], 'water', frames=fr)
        elif kind == 'sconce':
            base = tilemap[y0][x0]
            tilemap[y0][x0] = ts.add('sconce', art.g_or(art.g_and(base.glyph, art.g_inv(dilate(art.SCONCE))), art.SCONCE), 'iron', opaque=True)
        else:
            deco = {'bones': art.BONES, 'skull': art.SKULL, 'rubble': art.RUBBLE, 'web': art.COBWEB,
                    'urn': art.URN, 'chest': art.CHEST_SHUT, 'tablet': TABLET}[kind]
            base = tilemap[y0][x0]
            g = overlay(base.glyph, deco)
            ramp = {'bones': 'bone', 'skull': 'bone', 'rubble': 'flag', 'web': 'web', 'urn': 'marble',
                    'chest': 'gold', 'tablet': 'marble'}[kind]
            solid = kind in ('urn', 'chest', 'tablet', 'rubble')
            tilemap[y0][x0] = ts.add(kind, g, ramp, solid=solid)
            if kind == 'chest':
                room.chest_open = ts.add('chest_open', overlay(base.glyph, art.CHEST_OPEN), 'gold', solid=True)
    return ts, tilemap


DAMAGE = [art.G("########", "########", "##....##", "#......#", "#......#", "##....##", "########", "########"),
          art.G("########", "####..##", "###....#", "####...#", "#####.##", "########", "########", "########"),
          art.G("#####...", "######..", "#######.", "########", "########", "#.######", "..######", "...#####")]

TABLET = art.G("........",
               ".######.",
               "#......#",
               "#.####.#",
               "#......#",
               "#.###..#",
               "#......#",
               "########")


def shimmer(g, k):
    a = art.g_to_array(g)
    b = np.roll(a, 1 if k % 2 else -1, axis=1) & a
    hl = np.zeros_like(a)
    hl[(k * 3) % 8, (k * 5) % 8] = 1
    hl[(k * 3 + 4) % 8, (k * 5 + 3) % 8] = 1
    return art.g_from_array((a ^ (a & ~b & (np.indices(a.shape).sum(0) % 2 == 0))) | hl)


def rim_glyph(room, x, y):
    """Pool rim stone: a carved lip on the sides facing the water."""
    a = np.zeros((8, 8), dtype=np.uint8)
    a[:, :] = 0
    for yy in range(8):
        for xx in range(8):
            if (xx + yy * 3) % 7 == 0:
                a[yy, xx] = 1
    n = {d: room.at(x + dx, y + dy) == '~' for d, (dx, dy) in {'N': (0, -1), 'S': (0, 1), 'W': (-1, 0), 'E': (1, 0)}.items()}
    if n['N']:
        a[0:2, :] = 1
        a[2, ::2] = 1
    if n['S']:
        a[5, ::2] = 1
        a[6:8, :] = 1
    if n['W']:
        a[:, 0:2] = 1
    if n['E']:
        a[:, 6:8] = 1
    if not any(n.values()):
        # diagonal neighbours: small corner stones
        for (dx, dy, sl) in ((-1, -1, (slice(0, 3), slice(0, 3))), (1, -1, (slice(0, 3), slice(5, 8))),
                             (-1, 1, (slice(5, 8), slice(0, 3))), (1, 1, (slice(5, 8), slice(5, 8)))):
            if room.at(x + dx, y + dy) == '~':
                a[sl] = 1
    return art.g_from_array(a)


# ------------------------------------------------------------------ light
ASPECT = 0.55          # a cell is 0.55 as wide as it is tall on screen


def bresenham(x0, y0, x1, y1):
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    x, y = x0, y0
    while True:
        pts.append((x, y))
        if x == x1 and y == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy
    return pts


class LightTree:
    """Prefix tree of Bresenham rays from the origin. Pre-order list of
    nodes: (dx, dy, level, flicker, skip_index). Casting walks the list; on
    an opaque cell the cell is lit and its subtree skipped; on the map edge
    the subtree is skipped unlit."""

    def __init__(self, intensity, rx, ry):
        root = {}
        cells = {}
        for dy in range(-ry, ry + 1):
            for dx in range(-rx, rx + 1):
                lv, fl = intensity(dx, dy)
                if lv > 0:
                    cells[(dx, dy)] = (lv, fl)
        for (dx, dy) in sorted(cells, key=lambda c: (abs(c[0]) * ASPECT) ** 2 + c[1] ** 2):
            path = bresenham(0, 0, dx, dy)[1:]
            node = root
            for p in path:
                node = node.setdefault(p, {})
        self.nodes = []

        def emit(node):
            for p in sorted(node, key=lambda c: (abs(c[0]) * ASPECT) ** 2 + c[1] ** 2):
                lv, fl = cells.get(p, (1, 0))
                idx = len(self.nodes)
                self.nodes.append([p[0], p[1], lv, fl, None])
                emit(node[p])
                self.nodes[idx][4] = len(self.nodes)
        own = intensity(0, 0)
        self.origin_level = own[0]
        emit(root)


def torch_intensity(facing):
    fx, fy = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}[facing]

    def f(dx, dy):
        vx, vy = dx * ASPECT, dy
        dist = math.hypot(vx, vy)
        if dist == 0:
            return 7, 0
        amb = 7.6 - dist * 1.55                     # small pool around the bearer
        cosang = (vx * fx + vy * fy) / dist
        # beam: strong within ~32 degrees, soft shoulder to ~55 degrees
        if cosang > 0.57:
            cone = min(1.0, (cosang - 0.57) / (0.85 - 0.57))
            reach = 7.4 - dist * 0.62
            beam = reach * (0.45 + 0.55 * cone)
        else:
            beam = 0
        lv = max(amb, beam)
        lv = int(round(min(7, lv)))
        if lv <= 0:
            return 0, 0
        flick = 1 if (lv <= 3 and dist > 2.5) else 0
        return lv, flick
    return f


def static_intensity(maxlv, radius):
    def f(dx, dy):
        dist = math.hypot(dx * ASPECT, dy)
        lv = maxlv * (1 - dist / radius) ** 0.8 if dist < radius else 0
        lv = int(round(lv))
        return (lv, 0)
    return f


def opaque_at(tilemap, x, y):
    if not (0 <= x < COLS and 0 <= y < ROWS):
        return None   # edge
    return tilemap[y][x].opaque


GROUPMAP = {}


def apply_groups(out):
    for cells in GROUPS:
        m = max(out.get(c, 0) for c in cells)
        if m:
            for c in cells:
                out[c] = m
    return out


GROUPS = []


def cast(tree, tilemap, ox, oy, out, sub=0):
    """out: dict (x,y)->level (max). Mirrors the Z80 cast routine."""
    nodes = tree.nodes
    i = 0
    n = len(nodes)
    out[(ox, oy)] = max(out.get((ox, oy), 0), tree.origin_level)
    while i < n:
        dx, dy, lv, fl, skip = nodes[i]
        x, y = ox + dx, oy + dy
        op = opaque_at(tilemap, x, y)
        if op is None:
            i = skip
            continue
        lv2 = lv - (sub if fl else 0)
        if lv2 > out.get((x, y), 0):
            out[(x, y)] = lv2
        if op and tilemap[y][x].face_lo and lv2 > out.get((x, y - 1), 0):
            out[(x, y - 1)] = lv2          # the face above shares the light
        i = skip if op else i + 1
    return apply_groups(out)


def static_light(room, tilemap):
    GROUPS[:] = room.groups
    level = np.zeros((ROWS, COLS), dtype=np.uint8)
    tint = np.zeros((ROWS, COLS), dtype=np.uint8)
    for (x, y, t, mx, rad) in room.lights:
        tree = LightTree(static_intensity(mx, rad), int(rad / ASPECT) + 1, int(rad) + 1)
        tree.origin_level = mx
        out = cast(tree, tilemap, x, y, {})
        for (cx, cy), lv in out.items():
            if 0 <= cx < COLS and 0 <= cy < ROWS and lv > level[cy, cx]:
                level[cy, cx] = lv
                tint[cy, cx] = TINTS.index(t)
    # self-luminous tiles
    for y in range(ROWS):
        for x in range(COLS):
            t = tilemap[y][x]
            if t.name.startswith('water'):
                if level[y, x] < 2:
                    level[y, x], tint[y, x] = 2, 1
            if t.name.startswith('crystal') or t.name == 'flame':
                level[y, x] = 7
                tint[y, x] = 1 if t.name.startswith('crystal') else 0
            if t.cycle:
                level[y, x] = max(level[y, x], 4)
    return level, tint


# ------------------------------------------------------------------ reference renderer
class View:
    """Python model of the engine's per-cell appearance."""

    def __init__(self, room, ts, tilemap):
        self.room, self.ts, self.tilemap = room, ts, tilemap
        self.slevel, self.stint = static_light(room, tilemap)
        self.trees = {f: LightTree(torch_intensity(f), 24, 12) for f in ('up', 'down', 'left', 'right')}
        self.seen = np.zeros((ROWS, COLS), dtype=bool)
        self.frame = 0

    def cell(self, x, y, dyn, zones_vis, sprites):
        t = self.tilemap[y][x]
        d = dyn.get((x, y), 0)
        s = self.slevel[y, x] if self.room.zone[y, x] in zones_vis else 0
        if d >= s:
            lv, tint = d, 'warm'
        else:
            lv, tint = s, TINTS[self.stint[y, x]]
        if lv > 0:
            self.seen[y, x] = True
        if lv == 0 and not self.seen[y, x]:
            return art.EMPTY, BLK, BLK
        ramp = RAMPS[t.ramp][tint]
        var, fg, bg = ramp[lv]
        if t.cycle and lv > 0:
            var, fg, bg = CYCLE[t.ramp][(self.frame // 4 + x) % len(CYCLE[t.ramp])]
        g = t.glyph
        if t.frames:
            g = t.frames[(self.frame // 6) % len(t.frames)]
        if lv > 0 and (x, y) in sprites:
            sg, sfg = sprites[(x, y)]
            return sg, sfg, BLK
        return art.variant(g, var), fg, bg

    def render(self, px, py, facing, zones_vis, sprites=None, flick=0):
        sprites = sprites or {}
        dyn = cast(self.trees[facing], self.tilemap, px, py, {}, flick)
        img = np.zeros((ROWS * 8, COLS * 8, 3), dtype=np.uint8)
        for y in range(ROWS):
            for x in range(COLS):
                g, fg, bg = self.cell(x, y, dyn, zones_vis, sprites)
                a = art.g_to_array(g)
                img[y * 8:y * 8 + 8, x * 8:x * 8 + 8] = np.where(a[..., None] == 1, PALETTE[fg], PALETTE[bg])
        return img


def save_png(img, path, scale=2):
    im = Image.fromarray(img)
    h, w = img.shape[:2]
    im = im.resize((w * scale, h * scale * 2 // 1 if False else h * 2 * scale), Image.NEAREST)
    im.save(path)


if __name__ == '__main__':
    room = build_showcase()
    ts, tm = build_tiles(room)
    print('tiles', len(ts.tiles))
    v = View(room, ts, tm)
    print('tree nodes', {f: len(t.nodes) for f, t in v.trees.items()})
    sprites = {(12, 10): (art.PLAYER['right0'], WHT)}
    img = v.render(12, 10, 'right', {1}, sprites)
    save_png(img, '/home/claude/lantern/out/ref_corridor.png', 1)
    v2 = View(room, ts, tm)
    for x in range(12, 40):
        v2.render(x, 10, 'right', {1} if x < 36 else {2})
    sprites = {(50, 10): (art.PLAYER['right0'], WHT)}
    img = v2.render(50, 10, 'right', {2}, sprites)
    save_png(img, '/home/claude/lantern/out/ref_hall.png', 1)
    # full-light debug view of the art
    v3 = View(room, ts, tm)
    v3.slevel[:, :] = 6
    v3.stint[:, :] = 0
    img = v3.render(0, 0, 'right', {1, 2})
    save_png(img, '/home/claude/lantern/out/ref_fulllight.png', 1)


def art_sheet(path):
    """Close-up of every tile at light 6 warm and 5 cool."""
    room = build_showcase()
    ts, tm = build_tiles(room)
    sheet = Image.new('RGB', (0, 0))
    cols = 20
    n = len(ts.tiles)
    img = np.zeros((((n + cols - 1) // cols) * 2 * 10, cols * 10, 3), dtype=np.uint8)
    for i, t in enumerate(ts.tiles):
        for k, (tint, lv) in enumerate((('warm', 6), ('cool', 5))):
            var, fg, bg = RAMPS[t.ramp][tint][lv]
            a = art.g_to_array(art.variant(t.glyph, var))
            y0 = (i // cols) * 20 + k * 10
            x0 = (i % cols) * 10
            img[y0:y0 + 8, x0:x0 + 8] = np.where(a[..., None] == 1, PALETTE[fg], PALETTE[bg])
    im = Image.fromarray(img)
    im.resize((im.width * 4, im.height * 8), Image.NEAREST).save(path)


def piece_sheet(path):
    room = build_showcase()
    ts, tm = build_tiles(room)
    v = View(room, ts, tm)
    v.slevel[:, :] = 6
    v.stint[:, :] = 0
    img = v.render(0, 0, 'right', {1, 2})
    # crop hall
    im = Image.fromarray(img[0:22 * 8, 36 * 8:80 * 8])
    im.resize((im.width * 3, im.height * 6), Image.NEAREST).save(path)
