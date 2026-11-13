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

W = level1.W
TOP, DEEP = 2, 2                # the VZ level is 12 tiles high: two more of sky, two more of earth
H = level1.H + TOP + DEEP
ALT = {'soil': 'soilD', 'soil2': 'soilD', 'bstar': 'soilD', 'grass': 'grassD', 'star': 'sky',
       'bonus': 'used', 'termite': 'sky', 'check': 'checkon'}
E_PLATH, E_PLATV = 5, 6
MAXPAIR = 384
ENTS = [(x, y + TOP, t, p) for (x, y, t, p) in level1.ents]


def level_grid():
    """Gumleaf Gully made taller: deeper earth with star pockets to tunnel
    to, and high logs over the springs that only a full bounce reaches."""
    solid = lambda t: vz.TILES[vz.TID[t]][2] & vz.SOLID
    g = []
    for x, col in enumerate(level1.g):
        col = ['sky' if t.startswith('hill') else t for t in col]
        b = col[-1]
        if b in ('soil', 'soil2', 'bstar', 'grass'):
            deep = ['soil2' if (x * 7 + k * 3) % 5 == 0 else 'soil' for k in range(DEEP)]
        else:
            deep = [b] * DEEP
        g.append(['sky'] * TOP + col + deep)
    earth = lambda x, y: 0 <= x < W and g[x][y] in ('soil', 'soil2')
    # star pockets in the deep earth
    for x in range(6, W - 8):
        if x % 11 == 5 and all(earth(x + d, H - 1) and earth(x + d, H - 2) for d in (-1, 0, 1, 2)):
            g[x][H - 1] = 'bstar'
            g[x + 1][H - 1] = 'bstar'
            g[x + 1][H - 2] = 'bstar'
    # a high log and a line of stars over each spring
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
    for (x, y, t, p) in ENTS:
        if t == E_PLATH:
            for tx in range(x, x + p + 4):
                if tx < W and nonsolid(g[tx][y]):
                    g[tx][y] = 'sky'
        if t == E_PLATV:
            for tx in range(x, x + 3):
                for ty in range(max(0, y - p), y + 1):
                    if nonsolid(g[tx][ty]):
                        g[tx][ty] = 'sky'
    return g


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


def build():
    T = gfx.build_tiles()
    C = Cells()
    tcell = {}
    for name, _, _ in vz.TILES:
        bits, ink, prio = T[name]
        tcell[name] = [C.add(bits[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8], ink[cy, cx], prio)
                       for cy in (0, 1) for cx in (0, 1)]        # TL TR BL BR
    g = level_grid()
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
    return dict(T=T, C=C, tcell=tcell, g=g, pairs=pairs, plist=plist, plath=plath, platv=platv)


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


def cgmap(D):
    """32 cell glyphs a column (two a tile)"""
    out = bytearray()
    for tx in range(W):
        for half in (0, 1):
            for ty in range(H):
                c = D['tcell'][D['g'][tx][ty]]
                out += bytes([c[half], c[2 + half]])
    out += bytes(2 * H * 2)                 # blank columns past the end
    return bytes(out)


if __name__ == '__main__':
    D = build()
    pat, colc, colm, mixed = pair_glyphs(D)
    tab, probes = hash_table(D, mixed)
    print('cell glyphs', len(D['C'].list), 'pairs', len(D['plist']), 'mixed', sum(mixed), 'extra probes', probes)
