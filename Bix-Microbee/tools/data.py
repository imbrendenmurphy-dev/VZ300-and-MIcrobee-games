"""BIX for the Microbee: the level data.

The world is a map of 8 x 8 "cell glyphs" (two across and two down for
each 16 x 16 tile). The screen scrolls two Microbee pixels at a time, so
a screen cell shows the join of two neighbouring cell glyphs at one of
four shifts. Every join that can ever appear (a "pair") is drawn here at
all four shifts and given a home in PCG banks 0-11: bank = set * 4 +
shift, so the whole picture moves by changing only each cell's bank.
"""
import sys
from pathlib import Path
import numpy as np
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / 'vz'))
import gfx
import art as vz
import level1

import levels2

TOP, DEEP = 2, 2                # the VZ levels are 12 tiles high: two more above, two more of earth
H = level1.H + TOP + DEEP
ALT = {'soil': 'soilD', 'soil2': 'soilD', 'bstar': 'soilD', 'grass': 'grassD', 'star': 'sky',
       'bonus': 'used', 'termite': 'sky', 'check': 'checkon'}
E_PLATH, E_PLATV = 5, 6
E_START, E_BOSS = 9, 13
MAXPAIR = 384
NWORLD = int(__import__('os').environ.get('BIX_WORLDS', '5'))
NAMES = {1: ('GUMLEAF GULLY', 'KING CANE'), 2: ('CRYSTAL CAVERNS', 'THE GEODE GOLEM'),
         3: ('CLOCKWORK WORKS', 'RUST-O-TRON'), 4: ('SKYWARD ISLES', 'THUNDERHAWK'),
         5: ('MOLTEN PEAKS', 'THE MAGMA DRAGON')}
SOLID = lambda t: vz.TILES[vz.TID[t]][2] & vz.SOLID
EARTH = ('soil', 'soil2', 'bstar', 'grass')


def tall(g12, ents, world):
    """a VZ level made taller: what is at its top edge carried up, deeper
    earth with star pockets to tunnel to, and a high log with stars over
    each spring that only a full bounce reaches"""
    W = len(g12)
    ents = [(x, y + TOP, t, p) for (x, y, t, p) in ents]
    g = []
    for x, col in enumerate(g12):
        col = list(col)
        col = ['sky' if t.startswith('hill') else t for t in col]     # the far hills cost too many glyphs
        b = col[-1]
        if b in EARTH:
            deep = ['soil2' if (x * 7 + k * 3) % 5 == 0 else 'soil' for k in range(DEEP)]
        else:
            deep = [b] * DEEP
        top = [col[0] if world > 1 and col[0] in ('rock', 'leaf') else 'sky'] * TOP
        g.append(top + col + deep)
    earth = lambda x, y: 0 <= x < W and g[x][y] in ('soil', 'soil2')
    for x in range(6, W - 8):
        if x % 11 == 5 and all(earth(x + d, H - 1) and earth(x + d, H - 2) for d in (-1, 0, 1, 2)):
            g[x][H - 1] = 'bstar'
            g[x + 1][H - 1] = 'bstar'
            g[x + 1][H - 2] = 'bstar'
    for x in range(W - 8):
        for y in range(9, H):
            if g[x][y] == 'shroom':
                ly = y - 8
                if all(g[x + d][yy] == 'sky' for d in range(1, 7) for yy in range(ly - 2, ly + 1)):
                    for d in (2, 3, 4):
                        g[x + d][ly] = 'log'
                        g[x + d][ly - 1] = 'star'
                    g[x + 5][ly - 2] = 'star'
                    g[x + 6][ly - 2] = 'star'
    nonsolid = lambda t: vz.TILES[vz.TID[t]][2] == 0
    # nothing behind the moving logs: they are drawn as background cells
    for (x, y, t, p) in ents:
        if t == E_PLATH:
            for tx in range(x, x + p + 4):
                if tx < W and nonsolid(g[tx][y]):
                    g[tx][y] = 'sky'
        if t == E_PLATV:
            for tx in range(x, x + 3):
                for ty in range(max(0, y - p), y + 1):
                    if tx < W and nonsolid(g[tx][ty]):
                        g[tx][ty] = 'sky'
    return g, ents


MIRROR = {'slopeL': 'slopeR', 'slopeR': 'slopeL', 'cloudL': 'cloudR', 'cloudR': 'cloudL',
          'moonTL': 'moonTR', 'moonTR': 'moonTL', 'moonBL': 'moonBR', 'moonBR': 'moonBL',
          'hillL': 'hillR', 'hillR': 'hillL'}


def mirrored(L):
    """'The Way Back': the same land run the other way"""
    w = L['W']
    g = [[MIRROR.get(t, t) for t in col] for col in reversed(L['g'])]
    ents = []
    for (x, y, t, p) in L['ents']:
        if t == E_PLATH:
            x2 = w - 3 - x - p          # a log is three tiles wide and travels p
        elif t == E_PLATV:
            x2 = w - 3 - x
        else:
            x2 = w - 1 - x
        ents.append((x2, y, t, p))
    return dict(g=g, W=w, ents=ents, boss=0, world=L['world'], mirror=1)


LOOSE = ('moon', 'lantern', 'flower', 'tuft', 'bush', 'sky_tw', 'log', 'trunk', 'cloud')


def arena(world):
    """a boss's arena: the VZ one (16 tiles) with four more let into its middle
    to fill a 20 tile screen"""
    L = getattr(levels2, 'level_%d_2' % world)()
    plain = []
    for y in range(12):
        t = L.g[9][y]
        if any(t.startswith(k) for k in LOOSE):
            t = L.g[6][y] if not any(L.g[6][y].startswith(k) for k in LOOSE) else 'sky'
        plain.append(t)
    cols = [list(c) for c in L.g[:9]] + [list(plain) for _ in range(4)] + [list(c) for c in L.g[9:]]
    for y in range(12):                         # the ceiling's pattern runs on
        if L.g[9][y].startswith('cloud') and L.g[0][y].startswith('cloud'):
            for x in range(20):
                cols[x][y] = ('cloudL', 'cloudM', 'cloudR')[x % 3]
    ents = [(2, 7, E_START, 0), (12, 6, E_BOSS, 0)]
    g, ents = tall(cols, ents, world)
    for x in (0, 19):                           # the walls go all the way up
        if g[x][TOP + 4] == 'rock':
            for y in range(TOP):
                g[x][y] = 'rock'
    return dict(g=g, W=20, ents=ents, boss=world, world=world)


def stages():
    out = []
    for w in range(1, NWORLD + 1):
        if w == 1:
            g, ents = tall(level1.g, level1.ents, 1)
        else:
            L = getattr(levels2, 'level_%d_1' % w)()
            g, ents = tall(L.g, L.ents, w)
        s0 = dict(g=g, W=len(g), ents=ents, boss=0, world=w)
        out += [s0, mirrored(s0), arena(w)]
    for L in out:
        L['start'] = [(x, y) for (x, y, t, p) in L['ents'] if t == E_START][0]
    return out


class Cells:
    def __init__(self):
        self.ids = {(bytes(8), 0, 0): 0}
        self.list = [(bytes(8), 0, 0)]

    def add(self, bits8, ink, prio):
        pat = bytes(np.packbits(bits8, axis=1)[:, 0].tolist())
        if pat == bytes(8):
            return 0
        k = (pat, int(ink), int(prio))
        if k not in self.ids:
            self.ids[k] = len(self.list)
            self.list.append(k)
        return self.ids[k]


def build(L):
    T = gfx.build_tiles(L['world'])
    W = L['W']
    C = Cells()
    tcell = {}
    for name, _, _ in vz.TILES:
        bits, ink, prio = T[name]
        tcell[name] = [C.add(bits[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8], ink[cy, cx], prio)
                       for cy in (0, 1) for cx in (0, 1)]        # TL TR BL BR
    g = L['g']
    pairs = {(0, 0): 0}
    plist = [(0, 0)]

    def pair(l, r):
        if (l, r) not in pairs:
            pairs[(l, r)] = len(plist)
            plist.append((l, r))

    def variants(t):
        return [t, ALT[t]] if t in ALT else [t]
    for ty in range(H):
        for tx in range(W):
            a = g[tx][ty]
            b = g[tx + 1][ty] if tx + 1 < W else 'sky'
            for a2 in variants(a):
                ca = tcell[a2]
                pair(ca[0], ca[1]); pair(ca[2], ca[3])
                for b2 in variants(b):
                    cb = tcell[b2]
                    pair(ca[1], cb[0]); pair(ca[3], cb[2])
        ca = tcell[g[0][ty]]
    # the moving logs
    pb = gfx.platform_bits()                       # 8 x 48
    plath = []
    for j in range(4):
        strip = np.zeros((8, 56), bool)
        strip[:, 2 * j:2 * j + 48] = pb
        row = [C.add(strip[:, c * 8:c * 8 + 8], gfx.BROWN, 6) for c in range(7)]
        plath.append(row)
        seq = [0] + row + [0]
        for a, b in zip(seq, seq[1:]):
            pair(a, b)
    platv = []
    for j in range(4):
        blk = np.zeros((16, 48), bool)
        blk[2 * j:2 * j + 8, :] = pb
        rows = []
        for r in (0, 1):
            row = [C.add(blk[r * 8:r * 8 + 8, c * 8:c * 8 + 8], gfx.BROWN, 6) for c in range(6)]
            rows += row
            seq = [0] + row + [0]
            for a, b in zip(seq, seq[1:]):
                pair(a, b)
        platv.append(rows)
    assert len(C.list) <= 256, len(C.list)
    return dict(T=T, C=C, tcell=tcell, g=g, W=W, pairs=pairs, plist=plist, plath=plath, platv=platv)


def pair_glyphs(D):
    """-> TILEPAT (12 x 1024 bytes, by attribute = set * 4 + shift), the colour
    tables (colour, mono: [attribute * 128 + code]), mixed flags per pair"""
    C, plist = D['C'], D['plist']
    n = len(plist)
    assert n <= MAXPAIR, 'too many pairs: %d' % n
    pat = bytearray(12 * 1024)
    colc = bytearray(12 * 128)
    colm = bytearray(12 * 128)
    mixed = [0] * n
    for p, (l, r) in enumerate(plist):
        pl, il, ql = C.list[l]
        pr, ir, qr = C.list[r]
        s, code = p >> 7, p & 127
        inks = []
        for k in range(4):
            a = s * 4 + k
            for y in range(8):
                pat[a * 1024 + code * 8 + y] = ((pl[y] << (2 * k)) | (pr[y] >> (8 - 2 * k))) & 0xFF if k else pl[y]
            # the ink of whichever side shows more; on a tie the higher priority
            if l == 0 or (r != 0 and (k == 3 or (k == 2 and qr > ql))):
                ink = ir
            else:
                ink = il
            if k == 0:
                ink = il if l else ir
            inks.append(ink)
            colc[a * 128 + code] = ink
            colm[a * 128 + code] = gfx.MONO.get(ink, gfx.WHITE) if ink else 0
        if l and r and il != ir:
            mixed[p] = 1
    return bytes(pat), bytes(colc), bytes(colm), mixed


def hfun(l, r):
    lo = (l ^ (((r >> 2) | (r << 6)) & 0xFF)) & 0xFF
    return ((r & 3) << 8) | lo


def hash_table(D, mixed):
    """1024 entries of (left, right, screen code, attribute base | flags);
    empty = FF FF. Attribute byte: b7 = shifts with the scroll, b6 = the
    cell's colour depends on the shift, b5 = solid ground, b0-3 = set * 4."""
    tab = bytearray(b'\xff' * 4096)
    probes = 0
    for p, (l, r) in enumerate(D['plist']):
        i = hfun(l, r)
        while tab[i * 4] != 0xFF or tab[i * 4 + 1] != 0xFF:
            i = (i + 1) & 1023
            probes += 1
        dense = lambda c: sum(bin(b).count('1') for b in D['C'].list[c][0]) >= 44
        busy = dense(l) and dense(r)        # solid ground: it keeps its ink under a sprite
        tab[i * 4:i * 4 + 4] = bytes([l, r, 0x80 | (p & 127),
                                      0x80 | (0x40 if mixed[p] else 0) | (0x20 if busy else 0) | ((p >> 7) * 4)])
    return bytes(tab), probes


