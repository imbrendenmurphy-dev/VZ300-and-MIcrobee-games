"""Stage 1 (BACKYARD BLITZ) scenery: skyline band (12 rows, half speed, looping) and ground band
(18 rows, full speed): INTRO -> ROOF route | GARDEN route -> PATIO arena (loops under the boss).
Colours CSS0: 0 green 1 yellow 2 blue 3 red. Columns are 4 px (one byte) wide and de-duplicated."""
import random
GH, SH = 18, 12
INTRO_C, ROUTE_C, ARENA_C, LAWN_C, GATE_C = 352, 240, 64, 32, 48       # lengths in 4-px columns
SKY_C = 128

def canvas(w, h, c): return [[c] * w for _ in range(h)]
def rect(cv, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= yy < len(cv) and 0 <= xx < len(cv[0]): cv[yy][xx] = c

def skyline():
    rnd = random.Random(7)
    w = SKY_C * 4; cv = canvas(w, SH, 2)
    x = 0
    while x < w - 4:
        k = rnd.random()
        if k < 0.45:                      # house: red roof, yellow walls, a window
            hw = rnd.choice([20, 24, 28]); top = rnd.choice([2, 3, 4])
            for i in range(5):            # pitched roof
                rect(cv, x + 4 - i, top + i, hw - 8 + 2 * i, 1, 3)
            rect(cv, x + 1, top + 5, hw - 2, SH - top - 5, 1)
            for wx in range(x + 4, x + hw - 6, 8): rect(cv, wx, top + 7, 3, 2, 2)
            if rnd.random() < 0.5: rect(cv, x + hw - 7, top - 1, 2, 3, 3)   # chimney
            x += hw + rnd.choice([0, 2, 4])
        elif k < 0.8:                     # gum tree
            tw = rnd.choice([12, 16]); top = rnd.choice([0, 1, 2])
            for yy in range(top, top + 7):
                for xx in range(x, x + tw):
                    if rnd.random() < 0.8 - abs(xx - x - tw / 2) / tw: cv[yy][xx] = 0
            rect(cv, x + tw // 2 - 1, top + 6, 2, SH - top - 6, 1)
            x += tw + 2
        else:                             # Hills hoist far away
            c = x + 8
            rect(cv, c, 4, 1, SH - 4, 1)
            for i in range(-6, 7): cv[4 + abs(i) // 3][c + i] = 1
            x += 18
    rect(cv, 0, SH - 1, w, 1, 0)          # distant lawn line
    return cv

def fence(cv, x0, x1):
    for x in range(x0, x1):
        p = x % 4
        for y in range(0, 6):
            if p == 3: c = 2
            elif y == 0 and p != 1: c = 2         # pointy paling tops
            elif y in (2, 4): c = 3               # rails
            else: c = 1
            cv[y][x] = c

DAND = random.Random(5)
DPAT = [(DAND.randint(8, GH - 2) if DAND.random() < 0.3 else -1) for _ in range(32)]
def lawn(cv, x0, x1, rnd=None):
    rect(cv, x0, 6, x1 - x0, GH - 6, 0)
    for x in range(x0, x1):
        if x % 4 == 1:
            y = DPAT[(x // 4) % 32]
            if y >= 0: cv[y][x] = 1                                   # dandelions (repeat every 128 px)

def arrow(cv, x, y, up, c):
    for i in range(4):
        w = 2 * i + 1
        yy = y + i if up else y + 3 - i
        rect(cv, x + 3 - i, yy, w, 1, c)
    rect(cv, x + 2, y + (4 if up else -2), 3, 2, c)

def ground():
    rnd = random.Random(11)
    segs = {}
    # INTRO: fence, lawn, garden beds, letterbox, paths, kennel, a hose, a wheelbarrow
    w = INTRO_C * 4; cv = canvas(w, GH, 2)
    fence(cv, 0, w); lawn(cv, 0, w)
    for bx in range(60, w - 80, 256):          # flower beds
        rect(cv, bx, 6, 40, 3, 3)
        for x in range(bx + 1, bx + 39, 3): cv[6][x] = 1; cv[7][x + 1] = 0
    for px0 in range(150, w - 60, 384):        # paver path
        for px in range(px0, px0 + 32):
            for y in range(9, GH): cv[y][px] = 1 if (px // 4 + y // 3) % 2 else 3
    rect(cv, 300, 1, 6, 4, 3); rect(cv, 302, 5, 2, 8, 1)     # letterbox
    rect(cv, 500, 2, 16, 4, 3); rect(cv, 502, 6, 12, 5, 1); rect(cv, 506, 8, 4, 3, 2)   # kennel
    for x in range(700, 760):                  # garden hose snaking across the lawn
        y = 12 + int(2.5 * __import__('math').sin(x / 6.0))
        cv[y][x] = 3
    rect(cv, 900, 8, 14, 4, 2); rect(cv, 897, 7, 3, 1, 2); rect(cv, 910, 12, 3, 3, 3)    # wheelbarrow
    rect(cv, 1100, 0, 3, 6, 1); rect(cv, 1096, 0, 11, 1, 3)    # bird bath
    segs['intro'] = cv
    # LAWN: a plain stretch that loops while the midboss is up
    w = LAWN_C * 4; cv = canvas(w, GH, 2)
    fence(cv, 0, w); lawn(cv, 0, w)
    segs['lawn'] = cv
    # GATE: the side gate, a sign with two arrows (ROOF up, GARDEN down)
    w = GATE_C * 4; cv = canvas(w, GH, 2)
    fence(cv, 0, w); lawn(cv, 0, w)
    rect(cv, 40, 0, 44, 13, 3); rect(cv, 42, 1, 40, 11, 1)          # sign board
    arrow(cv, 47, 2, True, 3); arrow(cv, 69, 4, False, 0)          # red up = roof, green down = garden
    rect(cv, 60, 13, 3, 5, 1)                                      # post
    rect(cv, 130, 0, 30, 6, 2); rect(cv, 128, 0, 2, 6, 3); rect(cv, 160, 0, 2, 6, 3)   # open gate
    segs['gate'] = cv
    # ROOF: up on the shed - corrugated iron, gutters, whirlybirds
    w = ROUTE_C * 4; cv = canvas(w, GH, 2)
    for x in range(w):
        for y in range(5, GH):
            cv[y][x] = 3 if (x % 3 == 0) else 1
        cv[5][x] = 1; cv[6][x] = 2 if x % 2 else 3                 # gutter
    for wx in range(30, w, 110):          # whirlybird vents
        rect(cv, wx, 1, 6, 3, 1); rect(cv, wx + 1, 0, 4, 1, 3); rect(cv, wx + 2, 4, 2, 1, 3)
    for ax in range(80, w, 150):          # TV antenna
        rect(cv, ax, 0, 1, 5, 1); rect(cv, ax - 4, 1, 9, 1, 1); rect(cv, ax - 2, 3, 5, 1, 1)
    segs['roof'] = cv
    # GARDEN: veggie patch - soil rows, sprouts, pumpkins, stakes
    w = ROUTE_C * 4; cv = canvas(w, GH, 2)
    fence(cv, 0, w)
    rect(cv, 0, 6, w, GH - 6, 3)
    for y in (8, 11, 14):
        for x in range(0, w, 4):
            cv[y][x] = 0; cv[y][x + 1] = 0; cv[y - 1][x + 1] = 0
    for px in range(20, w, 70):
        rect(cv, px, 14, 6, 3, 1); cv[13][px + 3] = 0                 # pumpkin
    for sx in range(45, w, 90):
        rect(cv, sx, 2, 1, 12, 1); rect(cv, sx - 1, 6, 3, 2, 3)        # tomato stake
    segs['garden'] = cv
    # PATIO: pavers, pergola posts (loops under the boss)
    w = ARENA_C * 4; cv = canvas(w, GH, 2)
    for x in range(w):
        for y in range(0, 6):
            cv[y][x] = 1 if x % 32 in (0, 1) else (3 if y == 0 else 2)
        for y in range(6, GH):
            cv[y][x] = 1 if ((x // 8) + ((y - 6) // 4)) % 2 else 3
        cv[6][x] = 1
    segs['patio'] = cv
    return segs

SEGS = ('intro', 'lawn', 'gate', 'roof', 'garden', 'patio')
def columns(cv):
    h = len(cv); out = []
    for cx in range(len(cv[0]) // 4):
        col = []
        for y in range(h):
            b = 0
            for i in range(4): b |= (cv[y][cx * 4 + i] & 3) << (6 - 2 * i)
            col.append(b)
        out.append(tuple(col))
    return out

def build():
    g = ground(); s = skyline()
    tiles = []; idx = {}
    def tid(col):
        if col not in idx: idx[col] = len(tiles); tiles.append(col)
        return idx[col]
    maps = {k: [tid(c) for c in columns(g[k])] for k in SEGS}
    stiles = []; sidx = {}
    smap = []
    for c in columns(s):
        if c not in sidx: sidx[c] = len(stiles); stiles.append(c)
        smap.append(sidx[c])
    assert len(tiles) <= 256 and len(stiles) <= 256, (len(tiles), len(stiles))
    return tiles, maps, stiles, smap, g, s

def asm():
    tiles, maps, stiles, smap, g, s = build()
    L = ['; stage 1 scenery (tools/scenery.py): %d ground tiles, %d skyline tiles' % (len(tiles), len(stiles))]
    L.append('GTILES:')        # tile-major: 18 bytes per tile, row 0 first
    for t in tiles: L.append('            db ' + ','.join('$%02X' % b for b in t))
    L.append('STILES:')
    for t in stiles: L.append('            db ' + ','.join('$%02X' % b for b in t))
    for k in SEGS:
        L.append('GMAP_%s:' % k.upper())
        m = maps[k]
        for i in range(0, len(m), 32): L.append('            db ' + ','.join(str(v) for v in m[i:i + 32]))
    L.append('SMAP:')
    for i in range(0, len(smap), 32): L.append('            db ' + ','.join(str(v) for v in smap[i:i + 32]))
    L.append('INTRO_C equ %d\nROUTE_C equ %d\nARENA_C equ %d\nLAWN_C equ %d\nGATE_C equ %d' % (INTRO_C, ROUTE_C, ARENA_C, LAWN_C, GATE_C))
    return '\n'.join(L) + '\n'

if __name__ == '__main__':
    import sys
    sys.path.insert(0, '.')
    from vzpal import CSS0
    from PIL import Image
    tiles, maps, stiles, smap, g, s = build()
    print('ground tiles', len(tiles), 'sky tiles', len(stiles))
    W = sum(len(g[k][0]) for k in g)
    im = Image.new('RGB', (W, GH + SH + 2), (0, 0, 0))
    x = 0
    for k in SEGS:
        for y in range(GH):
            for xx in range(len(g[k][0])): im.putpixel((x + xx, SH + 2 + y), CSS0[g[k][y][xx]])
        x += len(g[k][0])
    for y in range(SH):
        for xx in range(min(W, len(s[0]))): im.putpixel((xx, y), CSS0[s[y][xx]])
    im.crop((0, 0, 1000, GH + SH + 2)).resize((2000, (GH + SH + 2) * 3), Image.NEAREST).save(sys.argv[1])
