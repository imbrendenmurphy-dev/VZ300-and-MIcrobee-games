# Ghost Hunter 3 - maze tile art + level data.
# Walls are raised slabs seen from slightly above ("3-D"): a textured top
# surface with a lit rim on the north/west edges and a shadow on the east,
# and where the cell below is open the slab's front face shows in the
# bottom two rows.  Tiles are 6x5 pixels, colours 0 green 1 yellow 2 blue 3 red.
# Textures depend only on the pixel inside the cell and the row parity, so the
# Z80 can rebuild every wall from (neighbour mask, row parity).
import mazes

G, Y, B, R = 0, 1, 2, 3
CW, CH = 6, 5
# cell codes used by the game (same as Ghost Hunter 2)
CODE = {'#': 3, '.': 1, 'o': 2, ' ': 0, 'G': 5, '-': 4, 'T': 7, 'X': 6, 'P': 0, '$': 1}
# codes in the packed maze data (4 bits): as CODE, plus 8 = item spot (pellet)
PCODE = {'#': 3, '.': 1, 'o': 2, ' ': 0, 'G': 5, '-': 4, 'T': 7, 'X': 6, 'P': 9, '$': 8}

# fixed tile ids (same in every style)
T_EMPTY, T_PELLET, T_ENERG0, T_ENERG1, T_DOOR, T_HOUSE, T_TELE0 = 0, 1, 2, 3, 4, 5, 6   # tele 6..9
T_TUNNEL = 10
T_EYES0 = 11          # 11..14 eyes in a wall face: plain, slit, look left, look right
T_EYESB0 = 15         # 15..18 the same in a face whose slab continues north
T_CANDLE0 = 19        # 19..21 candle flame frames
T_WALL0 = 22          # walls from here on (<= 63)
FIXCODE = [0, 1, 2, 2, 4, 5, 6, 6, 6, 6, 7] + [3] * (64 - 11)


def chk(i, j, yp):
    return (i + j + yp) % 2 == 0


STYLES = [
    # 0 CRYPT: dark mossy stone - blue/green dither, yellow lit rim, red brick faces
    dict(name="CRYPT", hi=Y, lo=R,
         top=lambda i, j, yp: G if chk(i, j, yp) and not (i == 3 and j % 2 == 0) else B,
         face=lambda i, k, yp: B if (k == 1 and i in (0, 3)) or (k == 0 and i == 5) else R),
    # 1 HALLS: haunted wood panelling - red grain lines, yellow rim, red/blue faces
    dict(name="HALLS", hi=Y, lo=B,
         top=lambda i, j, yp: B if i in (1, 4) else R,
         face=lambda i, k, yp: R if (i + k) % 2 == 0 else B),
    # 2 HEDGE: overgrown graveyard hedges - leafy green, dark drooping faces
    dict(name="HEDGE", hi=Y, lo=B,
         top=lambda i, j, yp: G if chk(i, j, yp) or (i + 2 * j + 3 * yp) % 5 == 0 else B,
         face=lambda i, k, yp: G if (i + k * 2 + yp) % 3 == 0 else B),
    # 3 BONE: catacomb ossuary - dark red stone slabs, rows of little skulls in the faces
    dict(name="BONE", hi=Y, lo=R,
         top=lambda i, j, yp: R if chk(i, j, yp) and (i + 2 * j + yp) % 3 else B,
         face=lambda i, k, yp: B if (k == 0 and i in (1, 4)) or (k == 1 and i in (0, 2, 3, 5)) else Y),
]

NB = ['n', 's', 'w', 'e', 'nw', 'ne', 'sw', 'se']


def mask_of(nb):
    return sum(1 << k for k, n in enumerate(NB) if nb[n])


def nb_of(mask):
    return {n: bool(mask >> k & 1) for k, n in enumerate(NB)}


def neigh(grid, x, y):
    H = len(grid); W = len(grid[0])

    def wall(xx, yy):
        if yy < 0 or yy >= H:
            return True
        if xx < 0 or xx >= W:
            return True
        return grid[yy][xx] == '#'
    return {k: wall(x + dx, y + dy) for k, (dx, dy) in dict(
        n=(0, -1), s=(0, 1), w=(-1, 0), e=(1, 0), nw=(-1, -1), ne=(1, -1), sw=(-1, 1), se=(1, 1)).items()}


def wall_tile(nb, st, yp):
    """6x5 pixels for a wall cell from its neighbours, style and row parity"""
    t = [[0] * CW for _ in range(CH)]
    face = not nb['s']
    ftop = CH - 2 if face else 99
    for j in range(CH):
        for i in range(CW):
            t[j][i] = st['face'](i, j - ftop, yp) if j >= ftop else st['top'](i, j, yp)
    hi = st['hi']; lo = st['lo']
    last = (ftop - 1) if face else CH - 1
    if not nb['n']:
        for i in range(CW):
            t[0][i] = hi
    if not nb['w']:
        for j in range(0, last + 1):
            t[j][0] = hi
    if not nb['e']:
        for j in range(0 if nb['n'] else 1, last + 1):
            t[j][CW - 1] = lo
    if face:
        for j in range(ftop, CH):
            if not nb['w']:
                t[j][0] = lo
            if not nb['e']:
                t[j][CW - 1] = lo
    # inner corners: diagonal open while both orthogonals are wall
    if nb['n'] and nb['w'] and not nb['nw']:
        t[0][0] = hi
    if nb['n'] and nb['e'] and not nb['ne']:
        t[0][CW - 1] = lo
    if nb['s'] and nb['w'] and not nb['sw']:
        t[CH - 1][0] = hi
    if nb['s'] and nb['e'] and not nb['se']:
        t[CH - 1][CW - 1] = lo
    # rounded outer corners
    if not nb['n'] and not nb['w']:
        t[0][0] = B
    if not nb['n'] and not nb['e']:
        t[0][CW - 1] = B
    if face and not nb['w']:
        t[CH - 1][0] = B
    if face and not nb['e']:
        t[CH - 1][CW - 1] = B
    return t


def shape_key(mask):
    """the parts of the mask that change the drawing (diagonals only matter in corners)"""
    nb = nb_of(mask)
    k = [nb['n'], nb['s'], nb['w'], nb['e']]
    k.append(nb['n'] and nb['w'] and not nb['nw'])
    k.append(nb['n'] and nb['e'] and not nb['ne'])
    k.append(nb['s'] and nb['w'] and not nb['sw'])
    k.append(nb['s'] and nb['e'] and not nb['se'])
    return tuple(k)


# global shape table: mask (0..255) -> shape index
SHAPES = []
SHAPETAB = []
for m in range(256):
    k = shape_key(m)
    if k not in SHAPES:
        SHAPES.append(k)
    SHAPETAB.append(SHAPES.index(k))
REP = {}
for m in range(256):
    REP.setdefault(SHAPETAB[m], m)


def floor_tile(tid):
    t = [[B] * CW for _ in range(CH)]
    if tid == T_PELLET:
        t[2][2] = Y; t[2][3] = Y
    elif tid in (T_ENERG0, T_ENERG1):            # power pill: a glowing orb
        c = Y if tid == T_ENERG0 else R
        for (i, j) in ((2, 1), (3, 1), (1, 2), (4, 2), (2, 3), (3, 3)):
            t[j][i] = c
        t[2][2] = Y; t[2][3] = Y
        if tid == T_ENERG1:
            t[2][2] = R; t[2][3] = Y
    elif tid == T_DOOR:
        for i in range(CW):
            t[2][i] = R if i % 2 == 0 else Y
    elif T_TELE0 <= tid < T_TELE0 + 4:           # teleporter: a swirling ring
        f = tid - T_TELE0
        ring = [(1, 0), (2, 0), (3, 0), (4, 0), (5, 1), (5, 2), (5, 3), (4, 4), (3, 4), (2, 4), (1, 4), (0, 3), (0, 2), (0, 1)]
        for k, (i, j) in enumerate(ring):
            t[j][i] = Y if (k + f * 4) % 14 < 5 else (G if (k + f * 4) % 14 < 9 else R)
        t[2][2] = G if f % 2 else B
        t[2][3] = B if f % 2 else G
    return t


EYE_MASK = mask_of(dict(n=False, s=False, w=True, e=True, nw=False, ne=False, sw=False, se=False))
EYEB_MASK = mask_of(dict(n=True, s=False, w=True, e=True, nw=True, ne=True, sw=False, se=False))
CANDLE_MASK = EYE_MASK


def decal_tile(st, kind, f):
    if kind in ('eyes', 'eyesb'):
        t = wall_tile(nb_of(EYE_MASK if kind == 'eyes' else EYEB_MASK), st, 0)
        if f >= 1:
            for i in range(1, 5):
                t[3][i] = B
        if f == 2:
            t[3][1] = Y; t[3][3] = Y
        if f == 3:
            t[3][2] = Y; t[3][4] = Y
    else:
        t = wall_tile(nb_of(CANDLE_MASK), st, 0)
        # a stubby candle on the slab top with a flickering flame
        t[2][2] = Y; t[2][3] = Y
        t[1][2] = B; t[1][3] = B
        t[0][2] = B; t[0][3] = B
        if f == 0:
            t[1][2] = Y; t[0][2] = R
        elif f == 1:
            t[1][3] = Y; t[0][3] = R
        else:
            t[1][2] = R; t[1][3] = Y; t[0][2] = Y
    return t


def build_tileset(si):
    """returns (tiles list indexed by id, idtab[shape*2+parity] -> id)"""
    st = STYLES[si]
    tiles = [None] * T_WALL0
    for tid in range(T_EYES0):
        tiles[tid] = floor_tile(tid)
    tiles[T_TUNNEL] = floor_tile(T_EMPTY)
    for f in range(4):
        tiles[T_EYES0 + f] = decal_tile(st, 'eyes', f)
        tiles[T_EYESB0 + f] = decal_tile(st, 'eyesb', f)
    for f in range(3):
        tiles[T_CANDLE0 + f] = decal_tile(st, 'candle', f)
    used = set()
    for n, m in mazes.MAZES.items():
        if m['style'] != si:
            continue
        g = mazes.build(n)
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x] == '#':
                    used.add((SHAPETAB[mask_of(neigh(g, x, y))], y & 1))
    idtab = [None] * (len(SHAPES) * 2)
    seen = {}
    for (sh, yp) in sorted(used):
        t = wall_tile(nb_of(REP[sh]), st, yp)
        key = tuple(map(tuple, t))
        if key not in seen:
            seen[key] = len(tiles)
            tiles.append(t)
        idtab[sh * 2 + yp] = seen[key]
    assert len(tiles) <= 64, (st['name'], len(tiles))
    fallback = idtab[[i for i, v in enumerate(idtab) if v is not None][0]]
    idtab = [v if v is not None else fallback for v in idtab]
    return tiles, idtab


def choose_decals(name):
    """spread out eyes (peeking from wall faces) and candles (on slab tops)"""
    g = mazes.build(name)
    H = len(g); W = len(g[0])
    out = []
    keys = {'eyes': shape_key(EYE_MASK), 'eyesb': shape_key(EYEB_MASK), 'candle': shape_key(CANDLE_MASK)}
    for kinds, want in ((('eyes', 'eyesb'), 9), (('candle',), 6)):
        cand = []
        for y in range(2, H - 2):
            for x in range(1, W - 1):
                if g[y][x] != '#' or (y & 1):
                    continue
                k = shape_key(mask_of(neigh(g, x, y)))
                for kind in kinds:
                    if k == keys[kind]:
                        cand.append((x, y, kind))
        pick = []
        cand.sort(key=lambda p: (p[1] * 31 + p[0] * 17) % 97)
        while cand and len(pick) < want:
            others = [d[:2] for d in pick + out]
            if not others:
                best = cand[0]
            else:
                dist = lambda p: min(abs(p[0] - q[0]) + abs(p[1] - q[1]) for q in others)
                best = max(cand, key=dist)
                if dist(best) < (5 if kinds[0] == 'eyes' else 3):
                    break
            pick.append(best)
            cand.remove(best)
        out += pick
    return out


DECAL_ID = {'eyes': T_EYES0, 'eyesb': T_EYESB0, 'candle': T_CANDLE0}
DECAL_KIND = {'eyes': 0, 'eyesb': 1, 'candle': 2}


def tile_grid(name):
    """tile ids per cell, exactly as the Z80 builds them"""
    g = mazes.build(name)
    st = mazes.MAZES[name]['style']
    tiles, idtab = build_tileset(st)
    H = len(g); W = len(g[0])
    ids = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            c = g[y][x]
            if c == '#':
                ids[y][x] = idtab[SHAPETAB[mask_of(neigh(g, x, y))] * 2 + (y & 1)]
            elif c in '.$':
                ids[y][x] = T_PELLET
            elif c == 'o':
                ids[y][x] = T_ENERG0
            elif c == 'G':
                ids[y][x] = T_HOUSE
            elif c == '-':
                ids[y][x] = T_DOOR
            elif c == 'X':
                ids[y][x] = T_TELE0
            elif c == 'T':
                ids[y][x] = T_TUNNEL
            else:
                ids[y][x] = T_EMPTY
    for (x, y, kind) in choose_decals(name):
        ids[y][x] = DECAL_ID[kind]
    return ids, tiles


def render_map(name, frame=0):
    ids, tiles = tile_grid(name)
    H = len(ids); W = len(ids[0])
    pix = [[B] * (W * CW) for _ in range(H * CH)]
    for y in range(H):
        for x in range(W):
            tid = ids[y][x]
            if frame and tid == T_ENERG0:
                tid = T_ENERG1
            if frame and tid in (T_EYES0, T_EYESB0):
                tid = tid + 2
            if frame and tid == T_CANDLE0:
                tid = tid + 1
            t = tiles[tid]
            for j in range(CH):
                for i in range(CW):
                    pix[y * CH + j][x * CW + i] = t[j][i]
    return pix


def viewport(name, cx, cy, frame=0):
    p = render_map(name, frame)
    return [r[cx:cx + 128] for r in p[cy:cy + 58]]


def row12(row):
    v = 0
    for c in row:
        v = (v << 2) | c
    return v


def emit(L, db):
    """assembler data: shape table, per-style tile sets and id tables, mazes"""
    L.append("; ---- maze tiles: mask(8 neighbours) -> shape, per style shape*2+parity -> tile id")
    L.append("NSHAPES equ %d" % len(SHAPES))
    L.append("T_WALL0 equ %d" % T_WALL0)
    L.append("T_EYES0 equ %d" % T_EYES0)
    L.append("T_CANDLE0 equ %d" % T_CANDLE0)
    L.append("T_EYESB0 equ %d" % T_EYESB0)
    L.append("T_TELE0 equ %d" % T_TELE0)
    L.append("T_EMPTY equ %d" % T_EMPTY)
    L.append("T_PELLET equ %d" % T_PELLET)
    L.append("T_ENERG0 equ %d" % T_ENERG0)
    L.append("T_ENERG1 equ %d" % T_ENERG1)
    L.append("T_DOOR equ %d" % T_DOOR)
    L.append("T_HOUSE equ %d" % T_HOUSE)
    L.append("T_TUNNEL equ %d" % T_TUNNEL)
    L.append("shapetab:")
    db(SHAPETAB)
    L.append("    align 256")
    L.append("codetab:   ; indexed by tile id * 4 (the grid stores id*4)")
    ct = [3] * 256
    for i, c in enumerate(FIXCODE):
        ct[i * 4] = c
    db(ct)
    for si in range(len(STYLES)):
        tiles, idtab = build_tileset(si)
        L.append("style%d_ids:   ; shape*2+row parity -> tile id*4" % si)
        db([v * 4 for v in idtab])
        L.append("style%d_tiles:  ; %d tiles x 5 rows x 12 bits (2 bytes, left aligned)" % (si, len(tiles)))
        L.append("    db %d" % len(tiles))
        data = []
        for t in tiles:
            for r in t:
                v = row12(r) << 4
                data += [v >> 8, v & 255]
        db(data)
    L.append("styletab: dw " + ",".join("style%d_ids,style%d_tiles" % (i, i) for i in range(len(STYLES))))
    # mazes: header + packed half rows (14 cells, 4 bits each -> 7 bytes)
    for n, m in mazes.MAZES.items():
        rows = [r for r in m['rows'].strip('\n').split('\n')]
        g = mazes.build(n)
        H = len(g)
        L.append("maze_%s:" % n)
        L.append("    db %d,%d   ; height, style" % (H, m['style']))
        data = []
        for r in rows:
            if r[12] == 'P':
                r = r[:12] + '.P'
            for k in range(0, 14, 2):
                data.append(PCODE[r[k]] << 4 | PCODE[r[k + 1]])
        db(data, 14)
        dec = choose_decals(n)
        L.append("    db %d   ; decals: x, y, kind (0 eyes, 1 eyes in a deep slab, 2 candle)" % len(dec))
        db([v for (x, y, kind) in dec for v in (x, y, DECAL_KIND[kind])], 15)


if __name__ == "__main__":
    import sys
    from PIL import Image
    CSS0 = [(7, 255, 0), (255, 255, 0), (59, 8, 255), (204, 0, 59)]
    out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/maps.png"
    ims = []
    for n in mazes.MAZES:
        p = render_map(n)
        im = Image.new("RGB", (len(p[0]), len(p)))
        for y, r in enumerate(p):
            for x, c in enumerate(r):
                im.putpixel((x, y), CSS0[c])
        ims.append(im.resize((im.width * 2, im.height * 3), Image.NEAREST))
    w = sum(i.width for i in ims) + 10 * len(ims); h = max(i.height for i in ims)
    sheet = Image.new("RGB", (w, h), (30, 30, 30))
    x = 0
    for i in ims:
        sheet.paste(i, (x, 0)); x += i.width + 10
    sheet.save(out)
    for si in range(4):
        print("style", si, "tiles", len(build_tileset(si)[0]))
    print("shapes", len(SHAPES))
    for n in mazes.MAZES:
        print(n, len(choose_decals(n)), "decals")
