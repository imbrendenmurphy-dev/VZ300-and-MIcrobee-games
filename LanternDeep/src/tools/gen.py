"""THE LANTERN DEEP - world compiler (all regions).

Outputs (build/):
  GFX.BNK       block 8: font, status bar, sprites (PCG banks 14, 15)
  WORLD.BNK     block 9: torch ray-trees (plain lantern) + omni tree
  WORLD2.BNK    block 12: torch ray-trees (glimmer lantern)
  REGIONn.BNK   block 16+2n: region PCG tiles + REGTAB
  ROOMSn.BNK    block 17+2n: the region's rooms (RLE)
  src/gen/world.asm  constants, sprite ids, room/region tables, messages
"""
import math
import random
from pathlib import Path
import numpy as np

import art
import art2
import world as W
import levels as L

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
GEN = ROOT / 'src' / 'gen'

STRIDE = 128
FLAGS_BASE = 0xC000
F_OPAQUE, F_EDGE, F_FACE, F_SOLID, F_CYCLE = 1, 2, 4, 8, 16
SPRITE_BANK, FONT_BANK = 14, 15
TILE_BANKS = 14                     # region tiles may use PCG banks 0..13
REGTAB = 0x9A00                     # region tables in the fixed upper block
RT_TD = REGTAB                      # 9 pages: CHR0-3, BANK, RL, RH, FLAGS, CLASS
RT_CYC = REGTAB + 0x900             # 32 bytes: cycle tables (rune, ...)
RT_RAMP = REGTAB + 0xA00            # 16 ramps x 128 bytes
RT_ANIM = REGTAB + 0x1200           # animation list + frames
RT_END = 0xBC00
WORLD_SPECIAL = 0x7000              # all-$FF marker region in each tree bank
SPECIAL_OFS = (WORLD_SPECIAL - FLAGS_BASE) & 0xFFFF
TINT = {'warm': 0, 'cool': 1, 'magic': 2, 'lava': 3, 'green': 4}
TINTS = ['warm', 'cool', 'magic', 'lava', 'green']

# tile classes (engine: TD_CLASS)
C_NONE, C_WATER, C_FLAME, C_LAVA, C_HOT, C_CRYSTAL, C_BOSS, C_STAIRS, C_MUSH, C_GATE = range(10)

# colours
BLK, RED, GRN, YEL, BLU, MAG, CYN, GRY, DGR, BRED, BGRN, BYEL, BBLU, BMAG, BCYN, WHT = range(16)


# ================================================================== ramps
LADDER = {'warm': (DGR, YEL, BYEL, WHT), 'cool': (BLU, CYN, BCYN, WHT), 'magic': (BLU, MAG, BMAG, WHT),
          'lava': (RED, BRED, BYEL, WHT), 'green': (DGR, GRN, BGRN, WHT)}
MEM_WALL, MEM_FLOOR = (2, BLU, BLK), (3, BLU, BLK)


def solid_r(lad, mem=MEM_WALL):
    a, b, c, d = lad
    return [mem, (2, a, BLK), (1, a, BLK), (1, b, BLK), (0, b, BLK), (0, c, BLK), (0, c, BLK), (0, d, BLK)]


def floor_r(lad, mem=MEM_FLOOR):
    a, b, c, d = lad
    return [mem, (2, a, BLK), (1, a, BLK), (0, a, BLK), (1, b, BLK), (0, b, BLK), (0, b, BLK), (1, c, BLK)]


def cap_r(lad):
    a, b, c, d = lad
    return [MEM_WALL, (2, a, BLK), (1, a, BLK), (0, a, BLK), (0, a, BLK), (0, b, BLK), (0, b, BLK), (0, c, BLK)]


def ramp(kind, warm=None, **over):
    """a material: per tint a list of 8 (variant, ink, paper). 'warm' etc.
    override the colour ladder of that tint (material colour)."""
    fn = {'solid': solid_r, 'floor': floor_r, 'cap': cap_r}[kind]
    out = {}
    for t in TINTS:
        lad = over.get(t) or (warm if (t == 'warm' and warm) else LADDER[t])
        out[t] = fn(lad)
    return out


def fixed(lst):
    return {t: lst for t in TINTS}


RAMPS = dict(W.RAMPS)                       # the temple materials from milestone 1
for k in list(RAMPS):
    RAMPS[k] = dict(RAMPS[k])
    RAMPS[k].setdefault('green', RAMPS[k]['warm'])
RAMPS.update({
    'bonewall': ramp('solid', warm=(DGR, GRY, WHT, WHT), cool=(BLU, CYN, WHT, WHT)),
    'earth': ramp('floor', warm=(DGR, DGR, YEL, BYEL)),
    'cave': ramp('solid', warm=(DGR, GRY, WHT, WHT), cool=(BLU, BLU, CYN, BCYN), magic=(BLU, MAG, BMAG, WHT),
                 green=(DGR, GRN, BGRN, WHT)),
    'cavecap': ramp('cap', warm=(DGR, DGR, GRY, GRY), cool=(BLU, BLU, CYN, CYN), green=(DGR, GRN, GRN, BGRN)),
    'cavefloor': ramp('floor', warm=(DGR, DGR, GRY, WHT), cool=(BLU, BLU, CYN, BCYN), green=(DGR, GRN, GRN, BGRN)),
    'moss2': ramp('floor', warm=(DGR, GRN, BGRN, BYEL), cool=(BLU, GRN, CYN, BCYN), green=(GRN, GRN, BGRN, WHT)),
    'basalt': ramp('solid', warm=(DGR, DGR, GRY, WHT), lava=(RED, RED, BRED, BYEL)),
    'basaltcap': ramp('cap', warm=(DGR, DGR, DGR, GRY), lava=(RED, RED, RED, BRED)),
    'ash': ramp('floor', warm=(DGR, DGR, GRY, WHT), lava=(RED, RED, BRED, BYEL)),
    'lava': fixed([(1, RED, BLK), (0, RED, BLK), (0, BRED, RED), (0, BRED, RED), (0, BYEL, RED), (0, BYEL, RED),
                   (0, BYEL, BRED), (0, WHT, BRED)]),
    'fissure': fixed([MEM_FLOOR, (1, RED, BLK), (0, RED, BLK), (0, BRED, BLK), (0, BRED, BLK), (0, BYEL, BLK),
                      (0, BYEL, BLK), (0, WHT, BLK)]),
    'obsidian': ramp('solid', warm=(BLU, DGR, GRY, WHT), magic=(BLU, MAG, BMAG, WHT), cool=(BLU, BLU, CYN, WHT)),
    'obscap': ramp('cap', warm=(BLU, BLU, DGR, GRY), magic=(BLU, BLU, MAG, BMAG)),
    'voidfloor': ramp('floor', warm=(BLU, BLU, DGR, GRY), magic=(BLU, BLU, MAG, BMAG), cool=(BLU, BLU, CYN, BCYN)),
    'crystal_m': fixed([(1, BMAG, BLK), (0, MAG, BLK), (0, BMAG, BLK), (0, BMAG, BLK), (0, BMAG, BLK), (0, WHT, BLK),
                        (0, WHT, BLK), (0, WHT, BLK)]),
    'crystal_g': fixed([(1, BGRN, BLK), (0, GRN, BLK), (0, BGRN, BLK), (0, BGRN, BLK), (0, BGRN, BLK), (0, WHT, BLK),
                        (0, WHT, BLK), (0, WHT, BLK)]),
    'mushroom': fixed([(1, GRN, BLK), (0, GRN, BLK), (0, BGRN, BLK), (0, BGRN, BLK), (0, BGRN, BLK), (0, BGRN, BLK),
                       (0, BYEL, BLK), (0, WHT, BLK)]),
    'portal': fixed([(1, MAG, BLK), (0, MAG, BLK), (0, BMAG, BLK), (0, BMAG, BLK), (0, BMAG, BLU), (0, WHT, BLU),
                     (0, WHT, MAG), (0, WHT, MAG)]),
    'candle': fixed([(0, YEL, BLK)] + [(0, BYEL, BLK)] * 5 + [(0, WHT, BLK)] * 2),
    'heartlit': fixed([(0, BYEL, BLK)] + [(0, WHT, BLK)] * 7),
    'boss': ramp('solid', warm=(DGR, GRY, WHT, WHT), magic=(BLU, MAG, BMAG, WHT)),
})
RAMP_LIST = list(RAMPS)
RAMPS['moss']['green'] = RAMPS['moss']['warm']


# ================================================================== styles
def style_art(name):
    """textures for a region: face strips, floor patches, cap ramp etc."""
    if name == 'temple':
        faces = [art.masonry_strip(11 + k, 8, 2, crack=0.2 if k else 0.08, holes=0.08 * k) for k in range(2)]
        return dict(faces=faces, face_ramp='stone', cap_ramp='cap',
                    floor1=[art.paving_patch(100 + k, cracked=0.25 + 0.1 * k) for k in range(3)], floor1_ramp='flag',
                    floor2='mosaic', floor2_ramp='mosaic', border=True, rubble='flag')
    if name == 'ossuary':
        faces = [art2.bone_wall_strip(21 + k) for k in range(2)] + [art.masonry_strip(12, 8, 2, crack=0.3)]
        return dict(faces=faces, face_ramp='bonewall', cap_ramp='cap',
                    floor1=[art2.speckle_patch(200 + k, density=0.10) for k in range(3)], floor1_ramp='earth',
                    floor2=[art.paving_patch(210 + k, cracked=0.4) for k in range(2)], floor2_ramp='flag', rubble='earth')
    if name == 'caverns':
        faces = [art2.cave_wall_strip(41 + k) for k in range(3)]
        return dict(faces=faces, face_ramp='cave', cap_ramp='cavecap',
                    floor1=[art2.speckle_patch(300 + k, density=0.07, cracks=1, pebbles=8) for k in range(3)],
                    floor1_ramp='cavefloor',
                    floor2=[art2.speckle_patch(310 + k, density=0.22, cracks=0) for k in range(2)], floor2_ramp='moss2',
                    rubble='cavefloor')
    if name == 'ember':
        faces = [art2.basalt_strip(51 + k) for k in range(3)]
        return dict(faces=faces, face_ramp='basalt', cap_ramp='basaltcap',
                    floor1=[art2.speckle_patch(400 + k, density=0.09, cracks=3) for k in range(3)], floor1_ramp='ash',
                    floor2=[art2.speckle_patch(410, density=0.14, cracks=4)], floor2_ramp='ash', rubble='ash')
    if name == 'heart':
        faces = [art2.obsidian_strip(61 + k) for k in range(2)]
        return dict(faces=faces, face_ramp='obsidian', cap_ramp='obscap',
                    floor1=[art2.slab_patch(500 + k) for k in range(2)], floor1_ramp='voidfloor',
                    floor2=[art2.slab_patch(510 + k) for k in range(2)], floor2_ramp='voidfloor', rubble='voidfloor')
    raise KeyError(name)


# ================================================================== tiles
class Tile:
    def __init__(self, name, glyph, ramp, opaque=False, solid=False, frames=None, cycle=False, cls=C_NONE, period=8):
        self.name, self.glyph, self.ramp = name, glyph, ramp
        self.opaque, self.solid = opaque, solid or opaque
        self.frames, self.cycle, self.cls, self.period = frames, cycle, cls, period
        self.face_lo = name.startswith('face_lo')
        self.index = None


class TileSet:
    def __init__(self):
        self.tiles, self.key = [], {}

    def add(self, name, glyph, ramp, **kw):
        frames = kw.get('frames')
        k = (tuple(frames) if frames else glyph, ramp, kw.get('opaque', False), kw.get('solid', False),
             kw.get('cycle', False), kw.get('cls', C_NONE), name.startswith('face_lo'))
        if k in self.key:
            return self.key[k]
        t = Tile(name, glyph, ramp, **kw)
        t.index = len(self.tiles)
        self.tiles.append(t)
        self.key[k] = t
        return t


def dilate(g):
    a = art.g_to_array(g)
    b = a.copy()
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            b |= np.roll(np.roll(a, dy, 0), dx, 1)
    return art.g_from_array(b)


def overlay(floor, deco):
    hole = art.g_inv(dilate(deco))
    return art.g_or(art.g_and(art.variant(floor, 1), hole), deco)


PIECES = {}


def piece(kind, **kw):
    """painted multi-cell set pieces: -> (w, h, [frames of cell grids])"""
    key = (kind, tuple(sorted(kw.items())))
    if key in PIECES:
        return PIECES[key]
    if kind == 'statue':
        r = (4, 5, [art.cut(art.paint(4, 5, art.statue_paint), 4, 5)])
    elif kind == 'crystal':
        r = (3, 4, [art.cut(art.paint(3, 4, art.crystal_paint), 3, 4)])
    elif kind == 'shard':
        r = (2, 2, [art.cut(art.paint(2, 2, art.crystal_paint), 2, 2)])
    elif kind == 'pillar':
        r = (2, 3, [art.cut(art.paint(2, 3, art.pillar_paint), 2, 3)])
    elif kind == 'sarcophagus':
        r = (3, 2, [art.cut(art.paint(3, 2, art2.sarcophagus_paint), 3, 2)])
    elif kind == 'altar':
        r = (3, 2, [art.cut(art.paint(3, 2, art2.altar_paint), 3, 2)])
    elif kind == 'forge':
        r = (3, 2, [art.cut(art.paint(3, 2, art2.forge_paint), 3, 2)])
    elif kind == 'stairs':
        r = (2, 2, [art.cut(art.paint(2, 2, art2.stairs_paint), 2, 2)])
    elif kind == 'portal':
        r = (3, 3, art2.portal_frames())
    elif kind == 'colossus':
        r = (4, 5, [art.cut(art.paint(4, 5, art2.colossus_paint(e)), 4, 5) for e in (False, True)])
    elif kind == 'king':
        r = (5, 5, [art.cut(art.paint(5, 5, art2.king_paint(p)), 5, 5) for p in (0, 1, 2)])
    elif kind == 'heart':
        r = (3, 3, [art.cut(art.paint(3, 3, art2.heart_paint(kw.get('lit', False))), 3, 3)])
    else:
        raise KeyError(kind)
    PIECES[key] = r
    return r


def shimmer(g, k):
    return W.shimmer(g, k)


class Built:
    """a room after tiling: tile per cell, static light, groups, objects"""
    pass


def tile_room(spec, st, ts):
    m = spec.m
    tm = [[None] * L.W for _ in range(L.H)]
    face_cells = [art.cut(f, 8, 2) for f in st['faces']]
    f1 = [art.cut(p, p.shape[1] // 8, p.shape[0] // 8) for p in st['floor1']]
    if st['floor2'] == 'mosaic':
        mos = art.cut(art.mosaic_patch(), 2, 2)
        f2 = None
    else:
        f2 = [art.cut(p, p.shape[1] // 8, p.shape[0] // 8) for p in st['floor2']]
    meander_h = art.cut(art.meander_strip(False), 2, 1)[0]
    meander_v = [row[0] for row in art.cut(art.meander_strip(True), 1, 2)]

    def is_wall(ch):
        return ch in '#EX'

    def floor_glyph(x, y, ch):
        if ch in '.d':
            pats = f1
            p = pats[((x // 4) * 7 + (y // 2) * 3 + (x // 4) * (y // 2)) % len(pats)]
            return p[y % len(p)][x % len(p[0])], st['floor1_ramp']
        if ch == 'b' and st.get('border'):
            vert = (x > 0 and m[y][x - 1] in '#E' or x < L.W - 1 and m[y][x + 1] in '#E') and not (
                y > 0 and m[y - 1][x] in '#E' or y < L.H - 1 and m[y + 1][x] in '#E')
            # vertical band when the wall is beside it
            left = x == 0 or m[y][x - 1] not in ',b'
            right = x == L.W - 1 or m[y][x + 1] not in ',b'
            up = y == 0 or m[y - 1][x] not in ',b'
            down = y == L.H - 1 or m[y + 1][x] not in ',b'
            if (left or right) and not (up or down):
                return meander_v[y % 2], 'border'
            return meander_h[x % 2], 'border'
        # ',' (and 'b' outside the temple)
        if f2 is None:
            g = mos[y % 2][x % 2]
            h = (x * 73 + y * 151) % 17
            if h < 3:
                g = art.g_and(g, W.DAMAGE[h])
            return g, st['floor2_ramp']
        p = f2[((x // 4) * 5 + (y // 2) * 7) % len(f2)]
        return p[y % len(p)][x % len(p[0])], st['floor2_ramp']

    for y in range(L.H):
        for x in range(L.W):
            ch = m[y][x]
            if is_wall(ch):
                below = spec.at(x, y + 1)
                below2 = spec.at(x, y + 2)
                k = (x // 8 + y) % len(face_cells)
                if not is_wall(below) and below != 'E':
                    tm[y][x] = ts.add('face_lo', face_cells[k][1][x % 8], st['face_ramp'], opaque=True)
                elif is_wall(below) and not is_wall(below2) and below2 != 'E':
                    tm[y][x] = ts.add('face_hi', face_cells[(k + 1) % len(face_cells)][0][x % 8], st['face_ramp'], opaque=True)
                else:
                    edges = set()
                    for d, (dx, dy) in {'N': (0, -1), 'S': (0, 1), 'W': (-1, 0), 'E': (1, 0)}.items():
                        n = spec.at(x + dx, y + dy)
                        if not is_wall(n) and n != 'E':
                            edges.add(d)
                    tm[y][x] = ts.add('cap', art.rock_cap((x * 31 + y * 17) % 5, edges), st['cap_ramp'], opaque=True)
                if ch == 'X':                                      # a cracked false wall
                    t = tm[y][x]
                    g = art.g_or(t.glyph, art2.CRACKED_WALL_MARK)
                    tm[y][x] = ts.add('secret', g, t.ramp, opaque=True, cls=C_NONE)
            elif ch == '~':
                tm[y][x] = 'water'
            elif ch == 'L':
                tm[y][x] = 'lava'
            elif ch == 'h':
                tm[y][x] = ts.add('hot', art2.hot_floor_frames()[0], 'fissure', frames=art2.hot_floor_frames(),
                                  cls=C_HOT, period=6)
            elif ch == 'Y':
                g, _ = floor_glyph(x, y, '.')
                tm[y][x] = ts.add('barrier', overlay(g, art2.BARRIER), 'crystal', solid=True, cls=C_CRYSTAL)
            elif ch == 'o':
                tm[y][x] = ts.add('rim', art.g_from_array(spec.poolbm[(x, y)]), 'marble', solid=True)
            else:
                g, rp = floor_glyph(x, y, ch)
                if is_wall(spec.at(x, y - 1)):
                    g = art.g_and(g, (0x00, 0x55, 0xAA, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF))
                tm[y][x] = ts.add('floor', g, rp)
    wf = art.water_frames()
    water = [ts.add('water%d' % k, wf[0][k], 'water', solid=True, frames=[f[k] for f in wf], cls=C_WATER) for k in range(2)]
    lf = art2.lava_frames()
    lava = [ts.add('lava%d' % k, lf[0][k], 'lava', solid=True, frames=[f[k] for f in lf], cls=C_LAVA, period=7) for k in range(2)]
    for y in range(L.H):
        for x in range(L.W):
            if tm[y][x] == 'water':
                tm[y][x] = water[x % 2]
            elif tm[y][x] == 'lava':
                tm[y][x] = lava[x % 2]
    return tm, (lambda x, y, ch: floor_glyph(x, y, ch))


def build_room(spec, st, ts, floorfn_holder=None):
    """tile one room and place its objects. -> Built"""
    if spec.pool:
        _pool(spec)
    tm, floor_glyph = tile_room(spec, st, ts)
    b = Built()
    b.spec, b.tm, b.groups, b.objs, b.self_lit = spec, tm, [], [], []
    flames = art.FLAME
    rubble_ramp = st['rubble']
    for kind, x0, y0, p in spec.objects:
        base = tm[y0][x0]
        if kind in ('statue', 'crystal', 'pillar', 'sarcophagus', 'altar', 'forge', 'stairs', 'stairs_up', 'shard',
                    'portal', 'colossus', 'king', 'heart'):
            pk = 'stairs' if kind == 'stairs_up' else kind
            w, h, frames = piece(pk)
            ramp = {'statue': 'marble', 'pillar': 'marble', 'sarcophagus': 'marble', 'altar': 'marble', 'forge': 'iron',
                    'stairs': 'marble', 'stairs_up': 'marble', 'portal': 'portal', 'colossus': 'boss', 'king': 'boss',
                    'heart': 'marble'}.get(kind)
            if kind in ('crystal', 'shard'):
                ramp = {'cool': 'crystal', 'magic': 'crystal_m', 'green': 'crystal_g'}[p.get('colour', 'cool')]
            opaque = kind in ('statue', 'pillar', 'forge', 'colossus', 'king')
            walk = kind in ('stairs', 'stairs_up')
            cls = {'stairs': C_STAIRS, 'colossus': C_BOSS, 'king': C_BOSS, 'crystal': C_CRYSTAL, 'shard': C_CRYSTAL}.get(kind, C_NONE)
            if kind == 'stairs_up':
                cls = C_STAIRS
            for cy in range(h):
                for cx in range(w):
                    if kind in ('crystal', 'shard'):
                        g0 = frames[0][cy][cx]
                        t = ts.add('%s_%s_%d_%d' % (kind, ramp, cx, cy), g0, ramp, solid=True, cls=cls,
                                   frames=[g0, g0, shimmer(g0, cx + cy), g0], period=10)
                    elif len(frames) > 1:
                        fr = [f[cy][cx] for f in frames]
                        if kind == 'king':
                            fr = [fr[0], fr[0], fr[1], fr[0], fr[2], fr[0]]
                        elif kind == 'colossus':
                            fr = [fr[0], fr[0], fr[0], fr[1], fr[0], fr[1]]
                        if len(set(fr)) > 1:
                            t = ts.add('%s_%d_%d' % (kind, cx, cy), fr[0], ramp, opaque=opaque, solid=True, cls=cls,
                                       frames=fr, period=7)
                        else:
                            t = ts.add('%s_%d_%d' % (kind, cx, cy), fr[0], ramp, opaque=opaque, solid=True, cls=cls)
                    else:
                        t = ts.add('%s_%d_%d' % (kind, cx, cy), frames[0][cy][cx], ramp, opaque=opaque, solid=not walk, cls=cls)
                    tm[y0 + cy][x0 + cx] = t
            if opaque:
                b.groups.append([(x0 + cx, y0 + cy) for cy in range(h) for cx in range(w)])
            if kind == 'forge':
                gf = art2.forge_glow_frames()
                gt = ts.add('forge_glow', gf[0], 'lava', solid=True, frames=gf, period=5, cls=C_LAVA)
                tm[y0 + 1][x0 + 1] = gt
                b.self_lit.append((x0 + 1, y0 + 2, 'lava', 7, 9.0))
            if kind == 'heart':
                lw, lh, lit = piece('heart', lit=True)
                lit_tiles = [ts.add('heart_lit_%d_%d' % (cx, cy), lit[0][cy][cx], 'heartlit', solid=True)
                             for cy in range(3) for cx in range(3)]
                b.objs.append(('heart', x0, y0, 3, 3, dict(p, lit=lit_tiles[0].index, tiles=[t.index for t in lit_tiles])))
            elif kind in ('colossus', 'king'):
                rub = ts.add('rubble', overlay(floor_glyph(x0, y0, '.')[0], art.RUBBLE), rubble_ramp, solid=False)
                b.objs.append((kind, x0, y0, w, h, dict(p, rubble=rub.index)))
            elif kind == 'stairs':
                b.objs.append(('stairs', x0, y0, w, h, p))
        elif kind == 'brazier':
            bm = art.paint(1, 1, art.brazier_paint)
            tm[y0][x0] = ts.add('flame', flames[0], 'flame', solid=True, frames=flames, period=4, cls=C_FLAME)
            tm[y0 + 1][x0] = ts.add('bowl', art.cut(bm, 1, 1)[0][0], 'iron', solid=True)
        elif kind == 'candle':
            cf = [overlay(base.glyph, g) for g in art2.candle_frames()]
            tm[y0][x0] = ts.add('candle', cf[0], 'candle', solid=True, frames=cf, period=5, cls=C_FLAME)
        elif kind == 'mushroom':
            mf = [overlay(base.glyph, g) for g in art2.MUSHROOM]
            tm[y0][x0] = ts.add('mushroom', mf[0], 'mushroom', solid=True, frames=[mf[0], mf[0], mf[1], mf[0]], period=9,
                                cls=C_MUSH)
        elif kind == 'sconce':
            tm[y0][x0] = ts.add('sconce', art.g_or(art.g_and(base.glyph, art.g_inv(dilate(art.SCONCE))), art.SCONCE),
                                'iron', opaque=True)
        elif kind == 'runestone':
            k = (x0 * 7 + y0) % 3
            tm[y0][x0] = ts.add('rune%d' % k, art.RUNES[k], 'rune', opaque=True, cycle=True)
        elif kind == 'puddle':
            fr = [overlay(base.glyph, g) for g in art.puddle_frames()]
            tm[y0][x0] = ts.add('puddle_%d' % (x0 % 3), fr[0], 'water', frames=fr, period=9)
        elif kind in ('gate', 'secret', 'barrier'):
            if kind == 'gate':
                shut = ts.add('gate', overlay(base.glyph, art2.GATE_SHUT) if not base.opaque else art2.GATE_SHUT,
                              'iron', solid=True, cls=C_GATE)
                tm[y0][x0] = shut
                fl = floor_glyph(x0, y0, '.')
                opened = ts.add('gate_open', overlay(fl[0], art2.GATE_OPEN), 'iron')
            elif kind == 'secret':
                fl = floor_glyph(x0, y0, '.')
                opened = ts.add('floor', fl[0], fl[1])
            else:
                fl = floor_glyph(x0, y0, '.')
                opened = ts.add('shards', overlay(fl[0], art2.SHARDS), 'crystal')
            b.objs.append((kind, x0, y0, 1, 1, dict(p, open=opened.index)))
        elif kind in ('chest', 'tablet', 'pedestal'):
            if kind == 'chest':
                g = overlay(base.glyph, art.CHEST_SHUT)
                tm[y0][x0] = ts.add('chest', g, 'gold', solid=True)
                opened = ts.add('chest_open', overlay(base.glyph, art.CHEST_OPEN), 'gold', solid=True)
                b.objs.append(('chest', x0, y0, 1, 1, dict(p, open=opened.index)))
            elif kind == 'tablet':
                tm[y0][x0] = ts.add('tablet', overlay(base.glyph, W.TABLET), 'marble', solid=True)
                b.objs.append(('tablet', x0, y0, 1, 1, p))
            else:
                item = {1: 'key', 2: 'lantern', 3: 'blade', 4: 'ring'}[p['item']]
                g = art.g_or(art2.PEDESTAL, art.g_and(art2.ITEMS[item], (0xFF, 0xFF, 0xFF, 0, 0, 0, 0, 0)))
                tm[y0][x0] = ts.add('pedestal_' + item, g, 'gold', solid=True)
                empty = ts.add('pedestal', art2.PEDESTAL, 'marble', solid=True)
                b.objs.append(('pedestal', x0, y0, 1, 1, dict(p, open=empty.index)))
        else:
            deco = {'bones': art.BONES, 'skull': art.SKULL, 'rubble': art.RUBBLE, 'web': art.COBWEB, 'urn': art.URN,
                    'stalagmite': art2.STALAGMITE, 'anvil': art2.ANVIL}[kind]
            ramp = {'bones': 'bone', 'skull': 'bone', 'rubble': rubble_ramp, 'web': 'web', 'urn': 'marble',
                    'stalagmite': st['face_ramp'], 'anvil': 'iron'}[kind]
            solid = kind in ('urn', 'rubble', 'stalagmite', 'anvil')
            tm[y0][x0] = ts.add(kind, overlay(base.glyph, deco), ramp, solid=solid)
    # runes over the temple door arch (room 0)
    if spec.rid == 0:
        rt = [ts.add('rune%d' % k, art.RUNES[k], 'rune', opaque=True, cycle=True) for k in range(3)]
        tm[8][36], tm[8][37], tm[12][36] = rt[0], rt[1], rt[2]
    return b


def _pool(spec):
    cx, cy, rx, ry = spec.pool
    spec.poolbm = {}
    for y in range(7, 20):
        for x in range(45, 75):
            water = rim = 0
            px = np.zeros((8, 8), dtype=np.uint8)
            for py in range(8):
                for pxl in range(8):
                    fx, fy = x + ((pxl // 2) * 2 + 1) / 8, y + ((py // 2) * 2 + 1) / 8
                    d = math.hypot((fx - cx) / rx, (fy - cy) / ry)
                    if d < 1.0:
                        water += 1
                    elif d < 1.0 + 0.55 / ry:
                        rim += 1
                        px[py, pxl] = 1
            if water == 64:
                spec.m[y][x] = '~'
            elif (rim or water) and spec.m[y][x] in ',b':
                spec.m[y][x] = 'o'
                spec.poolbm[(x, y)] = px


# ================================================================== light
class TM:
    """tilemap view for the light caster"""

    def __init__(self, tm):
        self.tm = tm


def opaque_at(tm, x, y):
    if not (0 <= x < L.W and 0 <= y < L.H):
        return None
    return tm[y][x].opaque


def cast(tree, tm, ox, oy, out, groups):
    nodes = tree.nodes
    i = 0
    out[(ox, oy)] = max(out.get((ox, oy), 0), tree.origin_level)
    while i < len(nodes):
        dx, dy, lv, fl, skip = nodes[i]
        x, y = ox + dx, oy + dy
        op = opaque_at(tm, x, y)
        if op is None:
            i = skip
            continue
        if lv > out.get((x, y), 0):
            out[(x, y)] = lv
        if op and tm[y][x].face_lo and lv > out.get((x, y - 1), 0):
            out[(x, y - 1)] = lv
        i = skip if op else i + 1
    for cells in groups:
        mx = max(out.get(c, 0) for c in cells)
        if mx:
            for c in cells:
                out[c] = mx
    return out


TREES = {}


def static_light(b):
    spec, tm = b.spec, b.tm
    level = np.zeros((L.H, L.W), dtype=np.uint8)
    tint = np.zeros((L.H, L.W), dtype=np.uint8)
    lights = list(spec.lights) + list(b.self_lit)
    # lava and hot rock glow
    for y in range(L.H):
        for x in range(L.W):
            t = tm[y][x]
            if t.cls == C_LAVA and (x + y * 2) % 4 == 0:
                lights.append((x, y, 'lava', 4, 3.2))
    for (x, y, t, mx, rad) in lights:
        key = (mx, rad)
        if key not in TREES:
            tr = W.LightTree(W.static_intensity(mx, rad), int(rad / W.ASPECT) + 1, int(rad) + 1)
            tr.origin_level = mx
            TREES[key] = tr
        out = cast(TREES[key], tm, x, y, {}, b.groups)
        for (cx, cy), lv in out.items():
            if 0 <= cx < L.W and 0 <= cy < L.H and lv > level[cy, cx]:
                level[cy, cx] = lv
                tint[cy, cx] = TINT[t]
    for y in range(L.H):
        for x in range(L.W):
            t = tm[y][x]
            self_l = {C_WATER: (2, 'cool'), C_FLAME: (7, 'warm'), C_LAVA: (6, 'lava'), C_HOT: (3, 'lava'),
                      C_MUSH: (6, 'green')}.get(t.cls)
            if t.name.startswith('crystal') or t.name.startswith('shard') or t.name == 'barrier':
                self_l = (7, {'crystal': 'cool', 'crystal_m': 'magic', 'crystal_g': 'green'}.get(t.ramp, 'cool'))
            if t.ramp == 'portal':
                self_l = (7, 'magic')
            if t.cycle:
                self_l = (4, 'magic')
            if spec.dark and self_l and self_l[1] == 'cool' and t.cls == C_WATER:
                self_l = None
            if self_l and level[y, x] < self_l[0]:
                level[y, x], tint[y, x] = self_l[0], TINT[self_l[1]]
    return level, tint


# ================================================================== packing helpers
def rle(data):
    """PackBits: n<128 -> n+1 literals; n>=128 -> run of (n-125) copies"""
    out = bytearray()
    i = 0
    n = len(data)
    while i < n:
        run = 1
        while i + run < n and data[i + run] == data[i] and run < 130:
            run += 1
        if run >= 3:
            out += bytes([run + 125, data[i]])
            i += run
            continue
        j = i
        lit = bytearray()
        while j < n and len(lit) < 128:
            if j + 2 < n and data[j] == data[j + 1] == data[j + 2]:
                break
            lit.append(data[j])
            j += 1
        out += bytes([len(lit) - 1]) + lit
        i = j
    return bytes(out)


def unrle(blob, n):
    out = bytearray()
    i = 0
    while len(out) < n:
        c = blob[i]
        i += 1
        if c < 128:
            out += blob[i:i + c + 1]
            i += c + 1
        else:
            out += bytes([blob[i]]) * (c - 125)
            i += 1
    return bytes(out)


def cellptr(x, y):
    return FLAGS_BASE + (y + 1) * STRIDE + (x + 1)


def asm_bytes(label, data, per=16):
    lines = [label + ':'] if label else []
    for i in range(0, len(data), per):
        lines.append('    DB ' + ','.join('$%02X' % b for b in data[i:i + per]))
    return '\n'.join(lines)


class PCG:
    def __init__(self, nbanks):
        self.banks = [[] for _ in range(nbanks)]
        self.index = [dict() for _ in range(nbanks)]

    def put(self, bank, g, unique=False):
        if not unique and g in self.index[bank]:
            return self.index[bank][g]
        assert len(self.banks[bank]) < 128, 'PCG bank %d full' % bank
        self.banks[bank].append(g)
        s = len(self.banks[bank]) - 1
        if not unique:
            self.index[bank][g] = s
        return s

    def free(self, bank):
        return 128 - len(self.banks[bank])


# ================================================================== objects / rooms metadata
OBJ_KIND = {'chest': 1, 'tablet': 2, 'gate': 3, 'secret': 4, 'barrier': 5, 'pedestal': 6, 'stairs': 7,
            'stairs_up': 8, 'colossus': 9, 'king': 10, 'heart': 11}
FOE_TYPE = {'bat': 2, 'skel': 3, 'beetle': 11, 'ghost': 12, 'spider': 13, 'slime': 14, 'imp': 15, 'shade': 16}
ROOMINFO = 0xB600
MONO_RAMPS_OFS = 0x3800 + (0xB600 - 0x9A00)     # in the region bank, after the tables
ROOMINFO_MAX = 0x0900          # B600-BEFF
BOSS_HP = {'colossus': 12, 'king': 18}


def glimmer_intensity(facing):
    fx, fy = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}[facing]

    def f(dx, dy):
        vx, vy = dx * W.ASPECT, dy
        dist = math.hypot(vx, vy)
        if dist == 0:
            return 7, 0
        amb = 7.6 - dist * 1.55
        cosang = (vx * fx + vy * fy) / dist
        if cosang > 0.60:
            cone = min(1.0, (cosang - 0.60) / (0.85 - 0.60))
            beam = (8.4 - dist * 0.62) * (0.45 + 0.55 * cone)
        else:
            beam = 0
        lv = int(round(min(7, max(amb, beam))))
        if lv <= 0:
            return 0, 0
        return lv, (1 if (lv <= 3 and dist > 3) else 0)
    return f


def tree_blob(trees, base0=0x0000):
    """trees: [(name, LightTree)] -> blob, {name: address}"""
    out = bytearray()
    addr = {}
    maxc = 0
    for name, tr in trees:
        base = base0 + len(out)
        nodes = tr.nodes
        seq, newidx = [], {}
        for i, nd in enumerate(nodes):
            if i and i % 40 == 0:
                seq.append(None)
            newidx[i] = len(seq)
            seq.append(nd)
        newidx[len(nodes)] = len(seq)
        blob = bytearray()
        for k, nd in enumerate(seq):
            if nd is None:
                blob += SPECIAL_OFS.to_bytes(2, 'little') + (base + (k + 1) * 6).to_bytes(2, 'little') + bytes([0, 0x80])
                continue
            dx, dy, lv, fl, skip = nd
            blob += ((dy * STRIDE + dx) & 0xFFFF).to_bytes(2, 'little')
            blob += (base + newidx[skip] * 6).to_bytes(2, 'little')
            blob += bytes([0, 0x80 | lv])
        blob += SPECIAL_OFS.to_bytes(2, 'little') + bytes([0, 0, 0, 0x80])
        addr[name] = base
        out += blob
        maxc = max(maxc, len({(n[0], n[1]) for n in nodes}))
    assert len(out) <= WORLD_SPECIAL, hex(len(out))
    out += bytes(WORLD_SPECIAL - len(out)) + b'\xFF' * 0x0C00
    return out, addr, maxc


def build_trees():
    omni = W.LightTree(W.static_intensity(6, 3.4), 7, 4)
    std = [('omni', omni)] + [(f, W.LightTree(W.torch_intensity(f), 24, 12)) for f in ('up', 'down', 'left', 'right')]
    gl = [('omni', omni)] + [(f, W.LightTree(glimmer_intensity(f), 28, 14)) for f in ('up', 'down', 'left', 'right')]
    b1, a1, m1 = tree_blob(std)
    b2, a2, m2 = tree_blob(gl)
    assert a1['omni'] == a2['omni'] == 0
    print('trees: std %d bytes max %d cells; glimmer %d bytes max %d cells' % (
        sum(len(t.nodes) for _, t in std) * 6, m1, sum(len(t.nodes) for _, t in gl) * 6, m2))
    assert m2 + 150 < 760, m2
    (BUILD / 'WORLD.BNK').write_bytes(b1)
    (BUILD / 'WORLD2.BNK').write_bytes(b2)
    return a1, a2


# ================================================================== shared PCG (font, HUD, sprites)
def build_gfx():
    pcg = PCG(16)
    eq = []
    for i in range(64):
        ch = chr(0x20 + i)
        pcg.put(FONT_BANK, art.font_glyph(ch) if ch in art.FONT_ROWS else art.EMPTY, unique=True)
    hud = dict(art.HUD)
    for k in ('key', 'lantern', 'blade', 'ring', 'potion'):
        hud['it_' + k] = art2.ITEMS[k]
    for name, g in hud.items():
        eq.append('G_%s EQU $%02X' % (name.upper(), 0x80 | pcg.put(FONT_BANK, g, unique=True)))
    spr = {}
    for name, g in art.PLAYER.items():
        spr['P_' + name] = g
    for nm, lst in (('BAT', art.BAT), ('BEETLE', art.BEETLE), ('SKEL', art.SKELETON), ('GHOST', art2.GHOST),
                    ('SPIDER', art2.SPIDER), ('SLIME', art2.SLIME), ('IMP', art2.IMP), ('SHADE', art2.SHADE),
                    ('EBOLT', art2.EBOLT)):
        for i, g in enumerate(lst):
            spr['%s%d' % (nm, i)] = g
    for k in ('h', 'v'):
        for i, g in enumerate(art.SLASH[k]):
            spr['SL%s%d' % (k.upper(), i)] = g
            spr['SL%sM%d' % (k.upper(), i)] = art.g_flip_h(g) if k == 'h' else art.g_flip_v(g)
    for name, g in art.FX.items():
        spr['FX_' + name.upper()] = g
    for name, g in spr.items():
        eq.append('S_%s EQU $%02X' % (name.upper(), 0x80 | pcg.put(SPRITE_BANK, g, unique=True)))
    # monochrome mode draws every sprite inverted (solid, with the figure
    # cut out) so creatures stand out without colour: copies at slot + 64
    n = len(pcg.banks[SPRITE_BANK])
    assert n <= 64, n
    while len(pcg.banks[SPRITE_BANK]) < 64:
        pcg.put(SPRITE_BANK, art.EMPTY, unique=True)
    for s in range(n):
        pcg.put(SPRITE_BANK, art.g_inv(pcg.banks[SPRITE_BANK][s]), unique=True)
    eq += ['SPRITE_BANK EQU %d' % SPRITE_BANK, 'FONT_BANK EQU %d' % FONT_BANK]
    blob = bytearray()
    for b in range(16):
        for s in range(128):
            blob += bytes(pcg.banks[b][s] if s < len(pcg.banks[b]) else art.EMPTY)
    (BUILD / 'GFX.BNK').write_bytes(blob)
    print('gfx: sprites %d, font+hud %d' % (len(pcg.banks[SPRITE_BANK]), len(pcg.banks[FONT_BANK])))
    return eq


# ================================================================== a region
def flags_of(t):
    f = 0
    if t.opaque:
        f |= F_OPAQUE
    if t.solid:
        f |= F_SOLID
    if t.face_lo:
        f |= F_FACE
    if t.cycle:
        f |= F_CYCLE
    return f


def compile_region(ri, specs):
    reg = L.REGIONS[ri]
    st = style_art(reg['style'])
    ts = TileSet()
    built = [build_room(s, st, ts) for s in specs]
    tiles = ts.tiles
    assert len(tiles) <= 255, 'region %d: %d tiles' % (ri, len(tiles))
    # ---- ramps used here
    rnames = []
    for t in tiles:
        if t.ramp not in rnames:
            rnames.append(t.ramp)
    assert len(rnames) <= 16, (ri, rnames)
    rid = {n: i for i, n in enumerate(rnames)}
    # ---- PCG: 4 variants per tile in one bank; animated tiles animate variants 0, 1
    pcg = PCG(TILE_BANKS)
    td_chr = [[0x80] * 256 for _ in range(4)]
    td_bank = [0] * 256
    anims = []
    bank = 0
    for t in tiles:
        while True:
            vs = [art.variant(t.frames[0] if t.frames else t.glyph, v) for v in range(4)]
            need = len(set(vs) - set(pcg.index[bank])) + (2 if t.frames else 0)
            if pcg.free(bank) >= need:
                break
            bank += 1
            assert bank < TILE_BANKS, 'region %d out of PCG banks' % ri
        for v in range(4):
            if t.frames and v < 2:
                s = pcg.put(bank, vs[v], unique=True)
                anims.append((bank, s, [art.variant(f, v) for f in t.frames], t.period))
            else:
                s = pcg.put(bank, vs[v])
            td_chr[v][t.index] = 0x80 | s
        td_bank[t.index] = bank
    td_rl = [((rid[t.ramp] & 1) << 7) for t in tiles] + [0] * (256 - len(tiles))
    td_rh = [((RT_RAMP >> 8) + (rid[t.ramp] >> 1)) for t in tiles] + [RT_RAMP >> 8] * (256 - len(tiles))
    td_flags = [flags_of(t) for t in tiles] + [F_OPAQUE | F_SOLID] * (256 - len(tiles))
    td_class = [t.cls for t in tiles] + [0] * (256 - len(tiles))
    # ---- REGTAB image (loaded to $9000)
    img = bytearray(RT_END - REGTAB)

    def put(addr, data):
        o = addr - REGTAB
        assert o + len(data) <= len(img), hex(addr)
        img[o:o + len(data)] = data
    for v in range(4):
        put(RT_TD + v * 256, bytes(td_chr[v]))
    put(RT_TD + 0x400, bytes(td_bank))
    put(RT_TD + 0x500, bytes(td_rl))
    put(RT_TD + 0x600, bytes(td_rh))
    put(RT_TD + 0x700, bytes(td_flags))
    put(RT_TD + 0x800, bytes(td_class))
    cyc = W.CYCLE['rune'] + W.CYCLE['rune'][:2]
    put(RT_CYC, b''.join(bytes([v, fg | (bg << 4)]) for v, fg, bg in cyc[:8]))
    ramps = bytearray(16 * 128)
    for n, i in rid.items():
        for ti, tint in enumerate(TINTS):
            for lv in range(8):
                var, fg, bg = RAMPS[n][tint][lv]
                o = i * 128 + (ti * 8 + lv) * 2
                ramps[o], ramps[o + 1] = var, fg | (bg << 4)
    put(RT_RAMP, ramps)
    # anim list: DB bank, slot, nframes, period ; DW frames ; DB ctr, frame
    alist = bytearray()
    frames = bytearray()
    fbase = RT_ANIM + len(anims) * 8 + 1
    for (b, s, fr, period) in anims:
        alist += bytes([b, s, len(fr), period]) + (fbase + len(frames)).to_bytes(2, 'little') + bytes([0, 0])
        frames += b''.join(bytes(f) for f in fr)
    alist += b'\xFF'
    put(RT_ANIM, bytes(alist) + bytes(frames))
    used = RT_ANIM + len(alist) + len(frames) - REGTAB
    assert RT_ANIM + len(alist) + len(frames) <= ROOMINFO, 'region %d anim data %x' % (ri, RT_ANIM + len(alist) + len(frames))
    pblob = bytearray()
    for b in range(TILE_BANKS):
        for s in range(128):
            pblob += bytes(pcg.banks[b][s] if s < len(pcg.banks[b]) else art.EMPTY)
    # monochrome light ramps: brightness shown by the pattern alone. The
    # lantern (warm) goes from full to faint; other light (crystals, lava,
    # water, glows) never quite full, so the beam stays the brightest thing
    mramps = bytearray(16 * 128)
    for n, i in rid.items():
        for ti, tint in enumerate(TINTS):
            for lv in range(8):
                var, fg, bg = RAMPS[n][tint][lv]
                if lv == 0:
                    mv = 3
                elif tint == 'warm':
                    mv = 2 if lv <= 2 else 1 if lv <= 4 else 0
                else:
                    mv = 2 if lv <= 2 else 1
                o = i * 128 + (ti * 8 + lv) * 2
                mramps[o], mramps[o + 1] = mv, fg | (bg << 4)
    regblob = pblob + bytes(img[:ROOMINFO - REGTAB])
    assert len(regblob) == MONO_RAMPS_OFS
    regblob += bytes(mramps)
    print('region %d %-22s tiles %3d ramps %2d banks %2d anims %3d regtab %04X' % (
        ri, reg['name'], len(tiles), len(rnames), bank + 1, len(anims), used + REGTAB))
    return built, regblob, ts


def room_info(b, ts):
    """the room's runtime record, assembled for ROOMINFO"""
    spec, tm = b.spec, b.tm
    level, tint = static_light(b)
    zone = np.ones((L.H, L.W), dtype=np.uint8)
    if spec.zones:
        for y in range(L.H):
            for x in range(L.W):
                zone[y, x] = spec.zones(x, y)
    tile = bytearray()
    stat = bytearray()
    for y in range(L.H):
        for x in range(L.W):
            tile.append(tm[y][x].index)
            stat.append((level[y, x] & 7) | ((tint[y, x] & 7) << 3) | ((zone[y, x] & 3) << 6))
    # ---- record
    hdr = bytearray(48)
    body = bytearray()

    def here():
        return ROOMINFO + len(hdr) + len(body)

    def text(s):
        a = here()
        body.extend(s.encode('ascii') + b'\0')
        return a
    names = getattr(spec, 'zone_names', {1: spec.name})
    n1 = text(names.get(1, spec.name))
    n2 = text(names.get(2, spec.name)) if 2 in names else n1
    # objects
    bits = {}
    nextbit = 8
    objs = []
    for (kind, x0, y0, p) in spec.objects:
        if kind not in OBJ_KIND:
            continue
        if kind in ('chest', 'pedestal'):
            bit, nextbit = nextbit, nextbit + 1
        else:
            bit = p.get('bit', 0xFF)
        objs.append((kind, x0, y0, p, bit))
    # find the built record extras (open tiles etc.)
    extra = {}
    for (kind, x0, y0, w, h, p) in b.objs:
        extra[(kind, x0, y0)] = (w, h, p)
    orecs = bytearray()
    msgs = []
    for (kind, x0, y0, p, bit) in objs:
        k = OBJ_KIND[kind]
        if kind == 'stairs_up':
            w, h, pp = 2, 2, p
        else:
            w, h, pp = extra.get((kind, x0, y0), (1, 1, p))
        a = [0, 0, 0, 0]
        if kind == 'chest':
            a = [p['item'], pp['open'], 0, 0]
        elif kind == 'tablet':
            msgs.append((len(orecs), p['msg']))
        elif kind in ('gate', 'secret', 'barrier'):
            a = [p['need'], pp['open'], 0, 0]
        elif kind == 'pedestal':
            lock = 0xFF
            for (k2, _, _, p2, b2) in objs:
                if k2 in ('colossus', 'king'):
                    lock = b2
            a = [p['item'], pp['open'], lock, 0]
        elif kind in ('stairs', 'stairs_up'):
            a = [p['to'], p['tx'], p['ty'], 0]
        elif kind in ('colossus', 'king'):
            a = [pp['rubble'], BOSS_HP[kind], 0, 0]
        elif kind == 'heart':
            lock = 0xFF
            for (k2, _, _, p2, b2) in objs:
                if k2 == 'king':
                    lock = b2
            a = [0, 0, lock, 0]       # pointer patched below
            msgs.append((len(orecs), bytes(pp['tiles'])))
        rec = bytes([k, x0, y0, w, h] + a + [bit])
        orecs += rec
    olist_at_body = len(body)
    body.extend(orecs + b'\0')
    olist = ROOMINFO + len(hdr) + olist_at_body
    for (o, m) in msgs:
        a = here()
        if isinstance(m, str):
            body.extend(m.encode('ascii') + b'\0')
        else:
            body.extend(m)
        p = olist_at_body + o + 5
        body[p], body[p + 1] = a & 0xFF, a >> 8
    # spawns
    sl = here()
    for (foe, x, y) in spec.spawns:
        body.extend(bytes([FOE_TYPE[foe], x, y]))
    body.append(0)
    # groups
    gl = here()
    for cells in b.groups:
        body.append(len(cells))
        for (x, y) in cells:
            body.extend(cellptr(x, y).to_bytes(2, 'little'))
    body.append(0)
    # cyclers
    cl = here()
    for y in range(L.H):
        for x in range(L.W):
            if tm[y][x].cycle:
                body.extend(cellptr(x, y).to_bytes(2, 'little'))
    body.extend(b'\0\0')
    # ambient sources: water cells (glints), fire cells (embers)
    water = [(x, y) for y in range(L.H) for x in range(L.W) if tm[y][x].cls == C_WATER]
    random.Random(spec.rid).shuffle(water)
    water = water[:32]
    wl = here()
    for (x, y) in water:
        body.extend(cellptr(x, y).to_bytes(2, 'little'))
    fire = [(x, y) for y in range(L.H) for x in range(L.W)
            if tm[y][x].cls in (C_FLAME, C_LAVA) and tm[y][x].name in ('flame', 'candle', 'forge_glow', 'lava0', 'lava1')]
    random.Random(spec.rid + 7).shuffle(fire)
    fire = fire[:16]
    fl = here()
    for (x, y) in fire:
        body.extend(cellptr(x, y).to_bytes(2, 'little'))
    ex = [spec.exits.get(d, 0xFF) for d in 'NSWE']
    amb = 1 if L.REGIONS[spec.region]['style'] in ('temple', 'caverns') else 0
    words = [n1, n2, olist, sl, gl, cl, wl, len(water), fl, len(fire)]
    hdr[0] = spec.rid
    hdr[1:5] = bytes(ex)
    hdr[5] = amb
    hdr[6] = spec.region
    for i, w in enumerate(words):
        hdr[8 + i * 2:10 + i * 2] = (w & 0xFFFF).to_bytes(2, 'little')
    info = bytes(hdr + body)
    assert len(info) <= ROOMINFO_MAX, (spec.rid, len(info))
    return bytes(tile), bytes(stat), info, objs


def validate(specs, built):
    """walk the world: every room reachable, every exit lines up, the
    progression can be completed"""
    byid = {s.rid: s for s in specs}
    opp = {'N': 'S', 'S': 'N', 'W': 'E', 'E': 'W'}
    for s in specs:
        for d, t in s.exits.items():
            assert byid[t].exits.get(opp[d]) == s.rid, 'exit %d %s -> %d not matched' % (s.rid, d, t)
    bm = {b.spec.rid: b for b in built}

    def passable(b, x, y, items, bits):
        t = b.tm[y][x]
        ch = b.spec.m[y][x]
        for (kind, x0, y0, w, h, p) in b.objs:
            if x0 <= x < x0 + w and y0 <= y < y0 + h and kind in ('gate', 'secret', 'barrier'):
                return p['need'] in items
        if t.cls == C_HOT:
            return L.IT_RING in items
        return not t.solid or t.cls == C_STAIRS

    items, beaten = set(), set()
    entries = {0: [(2, 10)]}
    for it in range(30):
        changed = False
        for rid, pts in list(entries.items()):
            b = bm[rid]
            seen = set()
            todo = [p for p in pts]
            while todo:
                x, y = todo.pop()
                if (x, y) in seen:
                    continue
                seen.add((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < L.W and 0 <= ny < L.H):
                        d = 'E' if nx >= L.W else 'W' if nx < 0 else 'S' if ny >= L.H else 'N'
                        t = b.spec.exits.get(d)
                        if t is not None:
                            np_ = (nx % L.W, ny % L.H)
                            if np_ not in entries.setdefault(t, []):
                                entries[t].append(np_)
                                changed = True
                        continue
                    if passable(b, nx, ny, items, beaten):
                        todo.append((nx, ny))
            # objects next to reachable floor
            for (kind, x0, y0, p) in b.spec.objects:
                adj = any((x, y) in seen for x in range(x0 - 1, x0 + 3) for y in range(y0 - 1, y0 + 3))
                if not adj:
                    continue
                if kind in ('chest', 'pedestal') and p['item'] not in items:
                    if kind == 'pedestal' and any(k in ('colossus', 'king') for (k, *_r) in b.spec.objects) and rid not in beaten:
                        continue
                    items.add(p['item'])
                    changed = True
                if kind in ('colossus', 'king') and rid not in beaten:
                    beaten.add(rid)
                    changed = True
                if kind == 'stairs':
                    if p['to'] not in entries or (p['tx'], p['ty']) not in entries[p['to']]:
                        entries.setdefault(p['to'], []).append((p['tx'], p['ty']))
                        changed = True
        if not changed:
            break
    reached = sorted(entries)
    print('validate: rooms reached %s, items %s, bosses %s' % (reached, sorted(items), sorted(beaten)))
    assert reached == sorted(byid), 'unreached rooms %s' % (set(byid) - set(entries))
    assert {1, 2, 3, 4} <= items, items
    assert 19 in beaten
    return entries


def main():
    GEN.mkdir(parents=True, exist_ok=True)
    BUILD.mkdir(exist_ok=True)
    specs = L.all_rooms()
    # stairs back up: the first stairs leading into this room
    for s in specs:
        for (kind, x0, y0, p) in s.objects:
            if kind == 'stairs_up':
                for s2 in specs:
                    for (k2, x2, y2, p2) in s2.objects:
                        if k2 == 'stairs' and p2['to'] == s.rid:
                            p.update(to=s2.rid, tx=x2 - 1, ty=y2 + 1)
    eq = build_gfx()
    t1, t2 = build_trees()
    for name, a in t1.items():
        eq.append('TREE_%s EQU $%04X' % (name.upper(), a))
    for name, a in t2.items():
        eq.append('TREE2_%s EQU $%04X' % (name.upper(), a))
    allbuilt = []
    lines = ['; generated by tools/gen.py - do not edit', '']
    lines += eq
    lines += ['MONO_RAMPS EQU $%04X' % MONO_RAMPS_OFS]
    lines += ['REGTAB EQU $%04X' % REGTAB, 'REGTAB_LEN EQU $%04X' % (ROOMINFO - REGTAB),
              'TD_CHR0 EQU $%04X' % RT_TD, 'TD_CHR1 EQU $%04X' % (RT_TD + 0x100), 'TD_CHR2 EQU $%04X' % (RT_TD + 0x200),
              'TD_CHR3 EQU $%04X' % (RT_TD + 0x300), 'TD_BANK EQU $%04X' % (RT_TD + 0x400),
              'TD_RL EQU $%04X' % (RT_TD + 0x500), 'TD_RH EQU $%04X' % (RT_TD + 0x600),
              'TD_FLAGS EQU $%04X' % (RT_TD + 0x700), 'TD_CLASS EQU $%04X' % (RT_TD + 0x800),
              'CYCTAB EQU $%04X' % RT_CYC, 'RAMPTAB EQU $%04X' % RT_RAMP, 'ANIM_LIST EQU $%04X' % RT_ANIM,
              'ROOMINFO EQU $%04X' % ROOMINFO, 'SPECIAL_H EQU $%02X' % (WORLD_SPECIAL >> 8)]
    for i, n in enumerate(['NONE', 'WATER', 'FLAME', 'LAVA', 'HOT', 'CRYSTAL', 'BOSS', 'STAIRS', 'MUSH', 'GATE']):
        lines.append('C_%s EQU %d' % (n, i))
    for n, k in OBJ_KIND.items():
        lines.append('O_%s EQU %d' % (n.upper(), k))
    room_tab = []
    region_tab = []
    for ri in range(len(L.REGIONS)):
        rs = [s for s in specs if s.region == ri]
        built, regblob, ts = compile_region(ri, rs)
        allbuilt += built
        (BUILD / ('REGION%d.BNK' % ri)).write_bytes(regblob)
        # rooms block: directory (8 x 8 bytes), then blobs
        rb = bytearray(64)
        for li, b in enumerate(built):
            tile, stat, info, objs = room_info(b, ts)
            ta = len(rb)
            rb += rle(tile)
            sa = len(rb)
            rb += rle(stat)
            ia = len(rb)
            rb += info
            assert unrle(rle(tile), len(tile)) == tile
            rb[li * 8:li * 8 + 8] = ta.to_bytes(2, 'little') + sa.to_bytes(2, 'little') + ia.to_bytes(2, 'little') + len(info).to_bytes(2, 'little')
            room_tab.append((b.spec.rid, ri, li))
        assert len(rb) <= 0x8000, len(rb)
        print('   rooms block %d bytes' % len(rb))
        (BUILD / ('ROOMS%d.BNK' % ri)).write_bytes(rb)
        region_tab.append(ri)
    validate(specs, allbuilt)
    room_tab.sort()
    lines.append('N_ROOMS EQU %d' % len(room_tab))
    lines.append('N_REGIONS EQU %d' % len(L.REGIONS))
    lines.append('ROOM_TAB:')
    for (rid, ri, li) in room_tab:
        lines.append('    DB %d,%d' % (ri, li))
    lines.append('REGION_NAMES:')
    lines.append('    DW ' + ','.join('rname%d' % i for i in range(len(L.REGIONS))))
    for i, r in enumerate(L.REGIONS):
        lines.append('rname%d: DB "%s",0' % (i, r['name']))
    # ---- journal maps: each region's rooms on a grid, from the exits
    SHORT = {0: 'DROWNED HALL', 1: 'CLOISTER', 2: 'SHRINE', 3: 'IRON GATE', 4: 'BONE STAIR', 5: 'HALL OF TOMBS',
             6: 'CHARNEL WAY', 7: 'COLOSSUS', 8: 'SEALED STAIR', 9: 'DESCENT', 10: 'PRISM GROTTO',
             11: 'MUSHROOMS', 12: 'THE RIVER', 13: 'ASH STAIR', 14: 'MAGMA BRIDGE', 15: 'THE FORGE',
             16: 'FISSURE WALK', 17: 'THRESHOLD', 18: 'ECHOES', 19: 'THE HEART'}
    lines.append('MAP_TAB: DW ' + ','.join('map%d' % i for i in range(len(L.REGIONS))))
    for ri in range(len(L.REGIONS)):
        rs = {s.rid: s for s in specs if s.region == ri}
        first = min(rs)
        pos = {first: (0, 0)}
        todo = [first]
        while todo:
            r = todo.pop()
            x, y = pos[r]
            for d, t in rs[r].exits.items():
                if t in rs and t not in pos:
                    pos[t] = (x + {'E': 1, 'W': -1}.get(d, 0), y + {'S': 1, 'N': -1}.get(d, 0))
                    todo.append(t)
        assert len(pos) == len(rs), (ri, pos)
        mx, my = min(p[0] for p in pos.values()), min(p[1] for p in pos.values())
        lines.append('map%d:' % ri)
        for r in sorted(pos):
            gx, gy = pos[r][0] - mx, pos[r][1] - my
            assert gx < 4 and gy < 3, (r, gx, gy)
            fl = (1 if 'E' in rs[r].exits else 0) | (2 if 'S' in rs[r].exits else 0)
            lines.append('    DB %d,%d,%d,%d\n    DW mapn%d' % (r, gx, gy, fl, r))
        lines.append('    DB $FF')
    for r, n in SHORT.items():
        lines.append('mapn%d: DB "%s",0' % (r, n))
    # where each region begins (a life lost returns you there)
    lines.append('REGION_START:')
    for ri in range(len(L.REGIONS)):
        first = min(s.rid for s in specs if s.region == ri)
        if ri == 0:
            lines.append('    DB %d,%d,%d' % (first, specs[0].start[0], specs[0].start[1]))
            continue
        for s2 in specs:
            for (k2, x2, y2, p2) in s2.objects:
                if k2 == 'stairs' and p2['to'] == first:
                    lines.append('    DB %d,%d,%d' % (first, p2['tx'], p2['ty']))
    s0 = specs[0]
    lines.append('START_ROOM EQU 0\nSTART_X EQU %d\nSTART_Y EQU %d' % s0.start)
    (GEN / 'world.asm').write_text('\n'.join(lines) + '\n')
    return specs, allbuilt


if __name__ == '__main__':
    main()
