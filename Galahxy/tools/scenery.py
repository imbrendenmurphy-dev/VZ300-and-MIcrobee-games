"""Stage 1 (PARTY PLANET) scenery: skyline band (12 rows, half speed, looping) and ground band
(18 rows, full speed): INTRO -> CLOUD TOPS route | LOLLY GARDEN route -> PARTY TABLE (loops under the boss).
Colours CSS0: W_ yellow, C_ blue (sky), M_ green, O_ red. Columns are 4 px (one byte) wide and de-duplicated."""
import random, math
GH, SH = 18, 12
INTRO_C, ROUTE_C, ARENA_C, LAWN_C, GATE_C = 352, 240, 64, 32, 48       # lengths in 4-px columns
SKY_C = 128
W_, C_, M_, O_ = 1, 2, 0, 3      # CSS0: yellow, blue sky, green, red

def canvas(w, h, c): return [[c] * w for _ in range(h)]
def rect(cv, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            if 0 <= yy < len(cv) and 0 <= xx < len(cv[0]): cv[yy][xx] = c
def disc(cv, cx, cy, rx, ry, c):
    for yy in range(cy - ry, cy + ry + 1):
        for xx in range(cx - rx, cx + rx + 1):
            if ((xx - cx) / (rx + .5)) ** 2 + ((yy - cy) / (ry + .5)) ** 2 <= 1 and 0 <= yy < len(cv) and 0 <= xx < len(cv[0]):
                cv[yy][xx] = c

def skyline():
    """far away: floating cake islands, giant mushrooms, ice-cream towers, a big top"""
    rnd = random.Random(7)
    w = SKY_C * 4; cv = canvas(w, SH, C_)
    x = 2
    while x < w - 24:
        k = rnd.random()
        if k < 0.3:                       # giant mushroom
            r = rnd.choice([6, 7, 8]); cx = x + r
            disc(cv, cx, 3, r, 3, O_); rect(cv, cx - r, 4, 2 * r + 1, 3, C_)
            for d in range(-r + 2, r - 1, 4): cv[2][cx + d] = W_; cv[1 + (d // 4) % 2][cx + d + 1] = W_
            rect(cv, cx - 1, 4, 3, SH - 4, W_)
            x += 2 * r + 4
        elif k < 0.55:                    # ice-cream tower: scoop on a cone
            cx = x + 5
            disc(cv, cx, 2, 4, 2, rnd.choice([W_, M_])); cv[0][cx] = O_
            for i in range(9):
                hw = max(0, 4 - i // 2); rect(cv, cx - hw, 4 + i, 2 * hw + 1, 1, O_)
            x += 13
        elif k < 0.8:                     # floating cake island
            iw = rnd.choice([16, 20, 24]); top = rnd.choice([3, 4, 5])
            rect(cv, x, top, iw, 2, W_)
            for d in range(0, iw, 3): cv[top + 2][x + d] = M_
            rect(cv, x + 1, top + 2, iw - 2, 2, O_)
            for i in range(4): rect(cv, x + 3 + i * 2, top + 4 + i, iw - 6 - i * 4, 1, O_)
            rect(cv, x + iw // 2, top - 3, 1, 3, W_); cv[top - 4][x + iw // 2] = O_   # a candle
            x += iw + 4
        else:                             # the big top
            cx = x + 9
            for i in range(6): rect(cv, cx - i * 2 + 1, 2 + i, i * 4 - 1 if i else 1, 1, M_ if i % 2 else W_)
            rect(cv, cx - 9, 8, 19, SH - 8, W_)
            for d in range(-9, 10, 3): rect(cv, cx + d, 8, 1, SH - 8, M_)
            cv[1][cx] = O_
            x += 22
    return cv

def fence(cv, x0, x1):
    """candy-cane railing along the top of the ground band"""
    for x in range(x0, x1):
        cv[1][x] = W_ if (x // 2) % 2 else M_
        cv[4][x] = W_ if (x // 2) % 2 else M_
        if x % 24 in (0, 1):
            for y in range(0, 6): cv[y][x] = W_ if (y + x) % 2 else M_

DAND = random.Random(5)
DPAT = [(DAND.randint(8, GH - 2) if DAND.random() < 0.35 else -1) for _ in range(32)]
def lawn(cv, x0, x1, rnd=None):
    """magenta icing with sprinkles (repeats every 128 px)"""
    rect(cv, x0, 6, x1 - x0, GH - 6, M_)
    for x in range(x0, x1):
        cv[6][x] = W_ if x % 6 < 4 else M_                         # icing drips
        if x % 6 == 1: cv[7][x] = W_
        if x % 4 == 1:
            y = DPAT[(x // 4) % 32]
            if y >= 0: cv[y][x] = O_ if (x // 4) % 3 else W_; cv[y][x + 1] = cv[y][x]

def arrow(cv, x, y, up, c):
    for i in range(4):
        w = 2 * i + 1
        yy = y + i if up else y + 3 - i
        rect(cv, x + 3 - i, yy, w, 1, c)
    rect(cv, x + 2, y + (4 if up else -2), 3, 2, c)

def lolly(cv, x, top, c):
    rect(cv, x + 2, top + 4, 1, GH - top - 4, W_)
    disc(cv, x + 2, top + 2, 2, 2, c); cv[top + 2][x + 2] = W_

def ground():
    segs = {}
    # INTRO: candy-cane railing, icing lawn, lollipops, wafer paths, presents, a toy train, a cake
    w = INTRO_C * 4; cv = canvas(w, GH, C_)
    fence(cv, 0, w); lawn(cv, 0, w)
    for bx in range(60, w - 80, 256):          # lollipop clumps
        for i, c in enumerate((O_, W_, O_)): lolly(cv, bx + i * 7, 2 + (i % 2) * 2, c)
    for px0 in range(150, w - 60, 384):        # wafer path
        for px in range(px0, px0 + 32):
            for y in range(9, GH): cv[y][px] = W_ if (px // 4 + y // 3) % 2 else O_
    rect(cv, 300, 3, 8, 5, O_); rect(cv, 303, 3, 2, 5, W_); rect(cv, 300, 5, 8, 1, W_)     # a present
    rect(cv, 302, 1, 1, 2, W_); rect(cv, 305, 1, 1, 2, W_)
    disc(cv, 507, 4, 8, 4, O_); rect(cv, 499, 5, 17, 2, C_)                              # mushroom house
    for d in (-5, 0, 5): cv[2][507 + d] = W_
    rect(cv, 502, 6, 11, 5, W_); rect(cv, 506, 8, 3, 3, O_)
    for x in range(700, 760):                  # a liquorice strap snaking over the icing
        y = 12 + int(2.5 * math.sin(x / 6.0)); cv[y][x] = O_; cv[y + 1][x] = O_
    for i in range(3):                         # toy train
        rect(cv, 900 + i * 12, 8, 10, 4, (O_, W_, O_)[i]); disc(cv, 902 + i * 12, 12, 1, 1, W_); disc(cv, 907 + i * 12, 12, 1, 1, W_)
    rect(cv, 900, 5, 3, 3, O_)
    rect(cv, 1096, 4, 13, 7, W_); rect(cv, 1096, 4, 13, 1, M_)                            # a slice of cake
    for d in range(0, 13, 3): cv[5][1096 + d] = M_
    rect(cv, 1096, 7, 13, 1, O_)
    segs['intro'] = cv
    # LAWN: a plain stretch that loops while the midboss is up
    w = LAWN_C * 4; cv = canvas(w, GH, C_)
    fence(cv, 0, w); lawn(cv, 0, w)
    segs['lawn'] = cv
    # GATE: a balloon arch and a sign: buff arrow up = CLOUD TOPS, orange arrow down = LOLLY GARDEN
    w = GATE_C * 4; cv = canvas(w, GH, C_)
    fence(cv, 0, w); lawn(cv, 0, w)
    rect(cv, 40, 0, 44, 13, O_); rect(cv, 42, 1, 40, 11, W_)
    arrow(cv, 47, 2, True, C_); arrow(cv, 69, 4, False, O_)
    rect(cv, 60, 13, 3, 5, W_)
    for i in range(16):                        # balloon arch
        a = math.pi * i / 15
        disc(cv, 145 + int(20 * math.cos(a)), 16 - int(14 * math.sin(a)), 1, 1, (M_, O_, W_)[i % 3])
    segs['gate'] = cv
    # CLOUD TOPS: puffy cloud floor, bouncy and bright
    w = ROUTE_C * 4; cv = canvas(w, GH, C_)
    for x in range(w):
        p = x % 48
        top = 6 + int(2.2 * abs(math.sin(p * math.pi / 24))) + (1 if p >= 24 else 0)
        for y in range(top, GH): cv[y][x] = W_
        if p % 12 == 5 and top + 4 < GH: cv[top + 3][x] = C_; cv[top + 3][x + 1] = C_
    for sx in range(50, w, 120):               # little star-on-a-stick markers
        rect(cv, sx, 1, 1, 6, O_); cv[0][sx] = O_; rect(cv, sx - 1, 1, 3, 1, O_)
    segs['roof'] = cv
    # LOLLY GARDEN: toffee soil, candy canes, gumdrops, lollipops
    w = ROUTE_C * 4; cv = canvas(w, GH, C_)
    fence(cv, 0, w)
    rect(cv, 0, 6, w, GH - 6, O_)
    for y in (9, 13):
        for x in range(0, w, 4): cv[y][x] = W_; cv[y][x + 1] = W_
    for px in range(20, w, 70):
        disc(cv, px + 3, 15, 3, 2, M_); cv[14][px + 2] = W_                                  # gumdrop
    for sx in range(45, w, 90):                                                             # candy cane
        for y in range(3, 14): cv[y][sx] = W_ if y % 2 else M_
        cv[2][sx + 1] = W_; cv[2][sx + 2] = M_; cv[3][sx + 3] = W_
    for lx in range(80, w, 130): lolly(cv, lx, 1, M_)
    segs['garden'] = cv
    # PARTY TABLE: tablecloth checks, plates (loops under the boss)
    w = ARENA_C * 4; cv = canvas(w, GH, C_)
    for x in range(w):
        for y in range(0, 6):
            cv[y][x] = O_ if x % 32 in (0, 1) else (W_ if y == 0 else C_)
        for y in range(6, GH):
            cv[y][x] = W_ if ((x // 8) + ((y - 6) // 4)) % 2 else M_
        cv[6][x] = O_
    for px in range(10, w, 64): disc(cv, px + 6, 4, 6, 1, W_); rect(cv, px + 3, 4, 7, 1, O_)   # plates of cake
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
