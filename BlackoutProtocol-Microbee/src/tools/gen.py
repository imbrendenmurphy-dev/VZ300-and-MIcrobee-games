"""Generate src/assets.inc: tables, tiles, rooms, the lift shaft, Wren, HUD font.
Run from the project root: python tools/gen.py"""
from pathlib import Path

COLS, ROWS, CH = 42, 24, 12          # 336 x 288, cells of 8 x 12
ROOM_ROWS = 22                       # rows 22-23 are the HUD
NATIVE = 0x9000
out = []
def db(label, data, per=16):
    if label: out.append(f"{label}:")
    for i in range(0, len(data), per):
        out.append("        db " + ",".join(b if isinstance(b, str) else f"${b:02X}" for b in data[i:i+per]))
def dw(label, data, per=8):
    if label: out.append(f"{label}:")
    for i in range(0, len(data), per):
        out.append("        dw " + ",".join(str(w) if isinstance(w, str) else f"${w:04X}" for w in data[i:i+per]))


# --- BLACKOUT.DAT: the game's data, loaded into the Premium Plus's banked RAM ---
# The lower 32K of the Z80's map can be any of 32 blocks of the 1 MB; the upper
# 32K is always block 0, and block 2 is the program's own lower half.  The file
# is loaded at start-up into blocks DAT_FIRST, DAT_FIRST+1, ... (32K each).
DAT_FIRST = 4            # blocks 1 and 3: CP/M's own buffers while it's still running
class Dat:
    """A pack of data: blocks of 32K.  Block numbers are symbolic (BASE+k) until
    every pack's size is known; the core pack loads at DAT_FIRST, the others follow."""
    def __init__(s, sym, sig=None):
        s.sym = sym; s.blocks = [bytearray()]
        if sig: s.blocks[0] += sig
    def add(s, data):
        data = bytes(data); assert len(data) <= 32768
        if len(s.blocks[-1]) + len(data) > 32768: s.blocks.append(bytearray())
        b = s.blocks[-1]; ofs = len(b); b += data
        return f"{s.sym}+{len(s.blocks) - 1}", ofs, len(data)
    def image(s): return b''.join(bytes(b) + (b'\0' * (32768 - len(b)) if i < len(s.blocks) - 1 else b'') for i, b in enumerate(s.blocks))
dat = Dat("CORE_BASE")
# Packs on the other three drives: (drive, file name, disk letter).  Each starts
# with a 16-byte signature the game checks, so a wrong disk is caught.
PACK_DISKS = [(1, "WING2.DAT"), (2, "WING3.DAT"), (3, "WING4.DAT")]
packs = [Dat(f"PACK{k+1}_BASE", f"BLACKOUT PACK {k+1}".ljust(16).encode()) for k in range(len(PACK_DISKS))]
def dat_for(pack): return dat if pack == 0 else packs[pack - 1]
def far(label, placed):
    blk, ofs, n = placed
    out.append(f"{label}: db {blk}\n        dw ${ofs:04X},{n}")

db("ycell", [min(y // CH, 255) for y in range(320)])
db("yline", [y % CH for y in range(320)])
dw("rowbase", [NATIVE + r * COLS * 16 for r in range(ROWS + 3)])

# --- tiles: 12 rows of 8 pixels; default ink -------------------------------
# Premium colours: bit0 R, bit1 G, bit2 B, bit3 bright.  colour byte = bg<<4 | ink.
BLACK, RED, GREEN, BROWN, BLUE, MAG, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAG, BCYAN, WHITE = range(8, 16)
TILES = {}
def tile(name, rows, ink):
    rows = rows if isinstance(rows, list) else [rows] * 12
    assert len(rows) == 12 and all(len(r) == 8 for r in rows), name
    TILES[name] = ([int(r.replace('.', '0').replace('X', '1'), 2) for r in rows], ink)
E = "........"
tile('empty', E, BLACK)
tile('dot', [E]*5 + ["...X...."] + [E]*6, DGREY)
tile('rivet', ["X......X"] + [E]*10 + ["X......X"], DGREY)
tile('floor', ["XXXXXXXX", "X..XX..X", ".XX..XX.", "XXXXXXXX", "..X..X..", E, E, E, E, E, E, E], BCYAN)
tile('grate', ["XXXXXXXX", "X.X.X.X.", ".X.X.X.X", "XXXXXXXX", "X......X", E, E, E, E, E, E, E], YELLOW)
tile('hazard', ["XXXXXXXX", "XX..XX..", ".XX..XX.", "..XX..XX", "XXXXXXXX", E, E, E, E, E, E, E], YELLOW)
tile('wall', ["XXXXXXX.", "X.....X.", "X.....X.", "X.....X.", "XXXXXXX.", E,
              "XXX.XXXX", "..X.X...", "..X.X...", "..X.X...", "XXX.XXXX", E], GREY)
tile('hull', ["XXXXXXXX", "X......X", "X.XXXX.X", "X.X..X.X", "X.X..X.X", "X.XXXX.X",
              "X......X", "XXXXXXXX", "..X..X..", "..X..X..", "..X..X..", "XXXXXXXX"], GREY)
tile('lamp', ["...XX...", "...XX...", "..XXXX..", ".XXXXXX.", "XXXXXXXX", E, ".X.XX.X.", E, "..X..X..", E, E, E], WHITE)
tile('pipeh', [E, E, "XXXXXXXX", "........", "X.X.X.X.", "........", "XXXXXXXX", E, E, E, E, E], CYAN)
tile('pipev', ["..X..X.."] * 12, CYAN)
tile('valve', [E, "..XXXX..", ".X.XX.X.", "XXXXXXXX", ".X.XX.X.", "..XXXX..", "...XX...", "...XX...", "XXXXXXXX", E, E, E], BRED)
tile('scrtop', ["XXXXXXXX", "X......X", "X.XX.X.X", "X......X", "X.X.XX.X", "X......X",
                "X.XXX..X", "X......X", "XXXXXXXX", "...XX...", "XXXXXXXX", "X......X"], BGREEN)
tile('scrbot', ["X.X.X.XX", "X......X", "XX.X.X.X", "X......X", "X.XXXX.X", "X......X",
                "X......X", "X.XXXX.X", "X......X", "X......X", "XXXXXXXX", E], GREY)
tile('lockt', ["XXXXXXXX", "X..XX..X", "X..XX..X", "X..XX..X", "X..XX..X", "XXXXXXXX",
               "X..XX..X", "X.XXXX.X", "X..XX..X", "X..XX..X", "X..XX..X", "X..XX..X"], CYAN)
tile('lockb', ["X..XX..X", "X..XX..X", "XXXXXXXX", "X..XX..X", "X..XX..X", "X..XX..X",
               "X..XX..X", "X..XX..X", "X..XX..X", "X..XX..X", "XXXXXXXX", "X......X"], CYAN)
tile('cratet', [".XXXXXX.", "X......X", "X.X..X.X", "X..XX..X", "X..XX..X", "X.X..X.X",
                "X......X", "XXXXXXXX", "X......X", "X.X..X.X", "X..XX..X", "X..XX..X"], BROWN)
tile('crateb', ["X.X..X.X", "X......X", "XXXXXXXX", "X......X", "X.X..X.X", "X..XX..X",
                "X..XX..X", "X.X..X.X", "X......X", "X......X", "XXXXXXXX", E], BROWN)
tile('plantt', ["...X....", "..XXX.X.", ".XX.XXX.", "XX..X.XX", ".X.XXX..", "XXX.X.XX",
                "X.XXX..X", "..XXXX..", ".XX.X.X.", "X..XXX.X", "...XX...", "...XX..."], BGREEN)
tile('plantb', ["...XX...", "..XXXX..", ".XXXXXX.", "XXXXXXXX", "X.X..X.X", "XXXXXXXX",
                ".X....X.", ".X....X.", ".X....X.", ".X....X.", ".XXXXXX.", E], BROWN)
tile('rackt', ["XXXXXXXX", "X.....XX", "X.X.X..X", "X.....XX", "XXXXXXXX", "X.....XX",
               "X.X.X..X", "X.....XX", "XXXXXXXX", "X.....XX", "X..X.X.X", "X.....XX"], BMAG)
tile('rackb', ["XXXXXXXX", "X.....XX", "X.X.X..X", "X.....XX", "XXXXXXXX", "X.....XX",
               "X..X.X.X", "X.....XX", "XXXXXXXX", "X......X", "XXXXXXXX", E], BMAG)
tile('tankt', ["..XXXX..", ".X....X.", "X..XX..X", "X.X..X.X", "X.X..X.X", "X..XX..X",
               "X......X", "XXXXXXXX", "X......X", "X.XXXX.X", "X.X..X.X", "X.XXXX.X"], YELLOW)
tile('tankb', ["X......X", "X..XX..X", "X.X..X.X", "X.X..X.X", "X..XX..X", "X......X",
               "XXXXXXXX", ".X....X.", ".X....X.", "XX....XX", "XXXXXXXX", E], YELLOW)
tile('bunk', [E, E, E, "X.......", "XXXXXXXX", "XXXXXXXX", "X......X", "X......X", "XXXXXXXX", "X......X", "X......X", E], BBLUE)
tile('window', ["XXXXXXXX", "X......X", "X..X...X", "X......X", "X.....XX", "X.X....X",
                "X......X", "X...X..X", "X......X", "X.X....X", "X......X", "XXXXXXXX"], WHITE)
tile('fan', ["XXXXXXXX", "X..X...X", "X..X..XX", "X.XXXX.X", "XXXXXX.X", "X.XXXX.X",
             "XX.XX..X", "X..X...X", "X.XX...X", "X......X", "XXXXXXXX", E], GREY)
tile('rock', ["XXX.XXXX", "...X....", "...X....", "XXXXXXXX", "X.......", "X.......",
              "XXX.XXXX", "...X....", "...X....", "XXXXXXXX", "......X.", "......X."], BBLUE)
tile('shaftw', [".XX..XX."] * 12, BBLUE)
tile('lift', ["XXXXXXXX", "X.X.X.X.", "XXXXXXXX", ".X....X.", "X......X"] + [E] * 7, YELLOW)
tile('hudbar', ["XXXXXXXX"] + [E] * 11, BLUE)
tile('arrowl', [E, E, "..X.....", ".XX.....", "XXXXXXX.", ".XX.....", "..X.....", E, E, E, E, E], YELLOW)
tile('arrowr', [E, E, ".....X..", ".....XX.", ".XXXXXXX", ".....XX.", ".....X..", E, E, E, E, E], YELLOW)

# --- stylised wall panels: bevelled, dither-shaded, with a neon trim ----------
def pat(fn): return [''.join('X' if fn(x, y) else '.' for x in range(8)) for y in range(12)]
def dith(x, y): return (y % 4 == 1 and x % 4 == 0) or (y % 4 == 3 and x % 4 == 2)
for v in 'TMB':
    for h in 'LMR':
        def f(x, y, v=v, h=h):
            if v == 'T' and y == 0: return True
            if v == 'T' and y == 1: return False
            if v == 'B' and y == 11: return True
            if v == 'B' and y == 10: return x % 2 == 0
            if v == 'B' and y == 9: return False
            if h == 'L' and x == 0: return True
            if h == 'L' and x == 1: return False
            if h == 'R' and x == 7: return True
            if h == 'R' and x == 6: return False
            return dith(x, y)
        tile(f'p{v}{h}', pat(f), DGREY)
tile('pS', pat(lambda x, y: x in (3, 4) and y % 6 != 5 or (y % 6 == 2 and x in (2, 5))), DGREY)
tile('pSB', pat(lambda x, y: (x in (3, 4) and y < 9) or y == 11 or (y == 10 and x % 2 == 0)), DGREY)
tile('truss', ["XXXXXXXX", "X.....X.", ".X...X..", "..X.X...", "...X....", "..X.X...",
               ".X...X..", "X.....X.", "XXXXXXXX", E, E, E], DGREY)
tile('gauge', [E, "..XXXX..", ".X....X.", "X..X...X", "X...X..X", "X....X.X", ".X....X.",
               "..XXXX..", E, "XXXXXXXX", "X.X..X.X", E], WHITE)
tile('sign', ["XXXXXXXX", "X......X", "X.XXXX.X", "X......X", "X.XX.X.X", "X......X",
              "XXXXXXXX", E, E, E, E, E], WHITE)

tile('termt', ["XXXXXXXX", "X......X", "X.X.XX.X", "X......X", "X.XX.X.X", "X......X", "XXXXXXXX",
               ".X....X.", "XXXXXXXX", "X.X.X.XX", "XX.X.X.X", "XXXXXXXX"], BCYAN)
tile('termb', ["X......X", "X.XXXX.X", "X.X..X.X", "X.XXXX.X", "X......X", "X.X.X..X",
               "X......X", "X.XXXX.X", "X......X", "X......X", "XXXXXXXX", E], GREY)
tile('splt', ["..XXXX..", ".X....X.", "X..XX..X", "X.X..X.X", "X.X..X.X", "X..XX..X",
              ".X....X.", "..XXXX..", "...XX...", "..XXXX..", ".X.XX.X.", "XXXXXXXX"], BMAG)
tile('splb', ["X......X", "X.XXXX.X", "X.X..X.X", "X.X..X.X", "X.XXXX.X", "X......X",
              "XX.XX.XX", "X......X", "X.X..X.X", "X......X", "XXXXXXXX", E], BMAG)
tile('bedt', [E, E, E, E, E, "XX......", "X.X.....", "XXXXXXXX", "X......X", "XXXXXXXX", "X......X", "X......X"], WHITE)
tile('bedb', ["X......X", "XXXXXXXX", ".X....X.", ".X....X.", ".X....X.", ".X....X.", ".X....X.", ".X....X.", ".X....X.", ".X....X.", "XX....XX", E], GREY)
tile('dish', ["...XXXX.", "..X....X", ".X..X..X", "X..X..X.", "X.X..X..", "X...X...", ".X.X....", "..XX....", "..X.....", ".XXX....", "XXXXX...", E], WHITE)
tile('coret', ["...XX...", "..X..X..", ".X.XX.X.", "X.X..X.X", "X.X..X.X", ".X.XX.X.", "..X..X..", "...XX...", "..XXXX..", ".X.XX.X.", "X..XX..X", "XXXXXXXX"], BRED)

tile('cirh', [E, E, E, "XXXXXXXX", "X.X.X.X.", "XXXXXXXX", "XXXXXXXX", ".X.X.X.X", "XXXXXXXX", E, E, E], WHITE)
tile('cirv', ["..XXXX..", "..X.XX..", "..XX.X..", "..X.XX..", "..XX.X..", "..X.XX..",
              "..XX.X..", "..X.XX..", "..XX.X..", "..X.XX..", "..XX.X..", "..XXXX.."], WHITE)
tile('cirn', ["..XXXX..", ".XXXXXX.", "XXX..XXX", "XX.XX.XX", "XX.XX.XX", "XXX..XXX",
              "XXX..XXX", "XX.XX.XX", "XX.XX.XX", "XXX..XXX", ".XXXXXX.", "..XXXX.."], WHITE)
# --- UI pieces for the information screens ------------------------------------
# Bevelled panels: a solid outer line and a dotted inner line, clipped corners.
def rows8(*r): return list(r) + ['........'] * (12 - len(r))
TL = rows8('........', '........', '........', '........', '.....XXX', '....X...', '...X..X.',
           '..X.....', '..X.X...', '..X.....', '..X.X...', '..X.....')
tile('bz_tl', TL, BCYAN)
tile('bz_tr', [r[::-1] for r in TL], BCYAN)
tile('bz_bl', TL[::-1], BCYAN)
tile('bz_br', [r[::-1] for r in TL[::-1]], BCYAN)
tile('bz_t', rows8('........', '........', '........', '........', 'XXXXXXXX', '........', 'X.X.X.X.'), BCYAN)
tile('bz_b', rows8('........', '........', '........', '........', '........', 'X.X.X.X.', '........', 'XXXXXXXX'), BCYAN)
tile('bz_l', ['..X.X...', '..X.....'] * 6, BCYAN)
tile('bz_r', ['...X.X..', '.....X..'] * 6, BCYAN)
# header tab caps: wedges the colour of the label behind them, joined to the top line
TAB = []
for r in range(12):
    w = [2, 3, 4, 5, 6, 7, 7, 6, 5, 4, 3, 2][r]
    row = '.' * (8 - w) + 'X' * w
    if r == 4: row = 'X' * 8
    TAB.append(row)
tile('tab_l', TAB, BCYAN)
tile('tab_r', [r[::-1] for r in TAB], BCYAN)
tile('slot_on', rows8('........', '.XXXXXX.', 'XX.XXXXX', 'X.XXXXXX', 'XXXXXXXX', 'XXXXXXXX', 'XXXXXXXX',
                      'XXXXXXXX', 'XXXXXXXX', '.XXXXXX.'), BGREEN)
tile('slot_off', rows8('........', '.XXXXXX.', 'X......X', 'X......X', 'X......X', 'X......X', 'X......X',
                       'X......X', 'X......X', '.XXXXXX.'), DGREY)
tile('bul', rows8('........', '........', '.X......', '.XX.....', '.XXX....', '.XXXX...', '.XXX....', '.XX.....', '.X......'), YELLOW)
tile('sep', rows8('........', '........', '........', '........', '........', '........', 'X.X.X.X.'), BLUE)

# --- the wings' own floors and fittings ---------------------------------------
tile('convr', ["XXXXXXXX", "X.X..X.X", ".X.XX.X.", "XXXXXXXX", "..X...X.", "...X...X", "..X...X.", E, E, E, E, E], YELLOW)
tile('convl', ["XXXXXXXX", "X.X..X.X", ".X.XX.X.", "XXXXXXXX", ".X...X..", "X...X...", ".X...X..", E, E, E, E, E], YELLOW)
tile('ice', ["XXXXXXXX", "........", "X.X..X..", "........", "..X...X.", E, E, E, E, E, E, E], WHITE)
tile('ventf', ["XXXXXXXX", "X.X.X.X.", "XXXXXXXX", "X.X.X.X.", "XXXXXXXX", E, E, E, E, E, E, E], GREY)
tile('lasem', [E, E, E, E, ".XXXXXX.", "XXXXXXXX", "X.XXXX.X", ".XXXXXX.", "...XX...", "...XX...", "...XX...", "....X..."], BRED)
tile('mist', E, BLACK)

# --- each wing's own architecture (tools/styles.py) -------------------------------
import sys as _s0; _s0.path.insert(0, 'tools')
import styles as _styles
for _n, _rows in _styles.TILES.items(): tile(_n, _rows, DGREY)

names = list(TILES)
tid = {n: i for i, n in enumerate(names)}
db("tiles", sum((TILES[n][0] for n in names), []), 12)
TILE_BYTES = 12

# --- rooms -------------------------------------------------------------------
# A room is 42 x 22 cells of (tile, colour) on black.  Wren walks the two rows
# above each floor: those stay bare black (furniture only).  The wall between
# one walkway and the next floor up is panelled: bevelled, dither-shaded panels
# lit from above (top row light, middle dim) with a neon trim along the bottom,
# a girder truss under every platform, and themed fittings set into the panels.
FLOORS = ('floor', 'grate', 'hazard', 'ice', 'convr', 'convl', 'ventf')
class Room:
    def __init__(s, name, light, dim, neon, truss_ink, style='panel'):
        s.name = name; s.light, s.dim, s.neon, s.truss_ink = light, dim, neon, truss_ink
        s.style = style
        s.side_t, s.ceil_t, s.under_t = _styles.FRAME[style]
        s.t = [['empty'] * COLS for _ in range(ROOM_ROWS)]
        s.c = [[0] * COLS for _ in range(ROOM_ROWS)]
        s.pads = []; s.signs = []; s.robots = []; s.items = {}
    def put(s, r, c, name, ink=None, bg=BLACK):
        s.t[r][c] = name
        s.c[r][c] = (bg << 4) | (TILES[name][1] if ink is None else ink)
    def frame(s, left=None, right=None):
        """Walls and ceiling; left / right = the floor row of a door on that side (or None)."""
        s.doors = (left, right)
        for c in range(COLS): s.put(0, c, s.ceil_t, s.dim)
        for r in range(1, ROOM_ROWS):
            for c in (0, 1, 40, 41):
                f = left if c < 2 else right
                open_ = f is not None and f - 3 <= r < f
                s.put(r, c, 'empty' if open_ else s.side_t, s.dim)
        for f, dc, arrow in ((left, 0, 'arrowl'), (right, 40, 'arrowr')):
            if f is None: continue
            for c in (dc, dc + 1): s.put(f, c, 'floor', BCYAN)
            s.put(f - 3, dc if arrow == 'arrowl' else dc + 1, arrow, YELLOW)
    def floor(s, r, c0, c1, kind='floor', ink=None):
        for c in range(c0, c1 + 1): s.put(r, c, kind, ink)
    def furn(s, f, c, top, bot, ink=None):
        s.put(f - 2, c, top, ink); s.put(f - 1, c, bot, ink)
    def decor(s, r, c, name, ink=None): s.put(r, c, name, ink)
    def sign(s, r, c, text, ink=WHITE): s.signs.append((r, c, ink, text))
    def robot(s, kind, f, c0, c1, start=None, speed=1):
        """kind 0 patrol, 1 shooter, 2 hunter, 3 sentry; on floor f between cells c0..c1"""
        lo, hi = c0 * 4 - 2, (c1 - 2) * 4 + 2
        st = lo if start is None else start * 4
        s.robots.append((kind, f, lo, hi, st, speed))
    def searchables(s):
        return [(r, c) for r in range(ROOM_ROWS) for c in range(COLS) if s.t[r][c] in SEARCH]
    def pad(s, c0, floors):
        # an in-room lift pad, 3 cells wide, serving floors (top to bottom); a hole in each floor
        s.pads.append((c0, floors))
        for f in floors:
            for c in range(c0, c0 + 3): s.put(f, c, 'empty')
    def walls(s, floors, rng=None):
        """Fill every wall zone in the room's style, hang its supports under every
        platform.  Call after floors, before fittings."""
        s.floors = floors
        if s.style != 'panel':
            import random as _r
            rng = rng or _r.Random(hash(s.name) & 0xFFFF)
            prev = 0
            for f in floors:
                z0, z1 = prev + 1, f - 3
                if z1 >= z0: _styles.fill(s.style, s, z0, z1, s.light, s.dim, s.neon, rng)
                if prev:
                    for c in range(2, 40):
                        if s.t[prev][c] in FLOORS: s.put(prev + 1, c, s.under_t, s.truss_ink)
                prev = f
            return
        prev = 0
        for f in floors:
            z0, z1 = prev + 1, f - 3
            for r in range(z0, z1 + 1):
                v = 'T' if r == z0 else 'B' if r == z1 else 'M'
                col = s.light if v == 'T' else s.neon if v == 'B' else s.dim
                for c in range(2, 40):
                    k = (c - 2) % 5
                    if k == 4: s.put(r, c, 'pSB' if v == 'B' else 'pS', s.neon if v == 'B' else s.dim)
                    else: s.put(r, c, 'p' + v + 'LMMR'[k], col)
            if prev:
                for c in range(2, 40):
                    if s.t[prev][c] in FLOORS: s.put(prev + 1, c, 'truss', s.truss_ink)
            prev = f
    def walkband(s, r): return any(f - 2 <= r <= f - 1 for f in s.floors)
    def finish(s):
        for r in range(ROOM_ROWS):
            for c in range(2, 40):
                n = s.t[r][c]
                if s.walkband(r) and (n.startswith('p') and n not in ('plantt', 'plantb') or n in ('truss', 'window', 'fan', 'gauge')):
                    raise SystemExit(f"{s.name}: wall detail {n} in a walkway at {r},{c}")
    def rle(s):
        cells = [(tid[s.t[r][c]], s.c[r][c]) for r in range(ROOM_ROWS) for c in range(COLS)]
        data = []; i = 0
        while i < len(cells):
            j = i
            while j < len(cells) and cells[j] == cells[i] and j - i < 255: j += 1
            data += [j - i, cells[i][0], cells[i][1]]; i = j
        return data + [0]

SOLID = {'floor', 'grate', 'hazard', 'lift', 'convr', 'convl', 'ice', 'ventf'}
SEARCH = {'lockb', 'crateb', 'scrbot', 'rackb', 'tankb', 'plantb', 'bunk', 'bedb'}
rooms = []
def new(name, light, dim, neon, truss, left, right):
    r = Room(name, light, dim, neon, truss); r.frame(left, right); rooms.append(r); return r
# 0: cargo bay - amber light, crates, hazard-striped catwalks
r = new("CARGO BAY 7", YELLOW, BROWN, BRED, BROWN, 21, 21)
r.floor(7, 2, 15, 'grate'); r.floor(7, 24, 39, 'grate'); r.floor(14, 9, 31, 'hazard'); r.floor(21, 2, 39)
r.pad(16, [7, 14, 21]); r.walls([7, 14, 21])
for c in (5, 14, 22, 33): r.decor(1, c, 'lamp')
for c in (4, 5, 6, 30, 31): r.furn(7, c, 'cratet', 'crateb')
for c in (12, 13, 26, 27, 28): r.furn(14, c, 'cratet', 'crateb')
r.furn(21, 34, 'lockt', 'lockb'); r.furn(21, 35, 'lockt', 'lockb')
r.decor(9, 6, 'gauge'); r.decor(16, 37, 'gauge'); r.decor(16, 22, 'valve', YELLOW)
r.sign(3, 24, "BAY 7", YELLOW); r.sign(17, 4, "LOAD ZONE", BRED)
r.floor(21, 21, 31, 'convr')                    # the docking wing's belts
r.robot(0, 14, 19, 31, 24); r.robot(1, 7, 24, 39, 34)
# 1: hydroponics - green glass, grow lights, plants on every shelf
r = new("HYDROPONICS 2", BGREEN, GREEN, BCYAN, GREEN, 21, 13)
r.floor(6, 2, 39, 'floor', BGREEN); r.floor(13, 2, 18, 'floor', BGREEN); r.floor(13, 25, 39, 'floor', BGREEN)
r.floor(21, 2, 39, 'floor', BGREEN)
r.pad(19, [6, 13, 21]); r.walls([6, 13, 21])
for c in range(3, 38, 3):
    if not 18 <= c <= 22: r.furn(6, c, 'plantt', 'plantb')
for c in (4, 5, 9, 10, 15, 28, 29, 33, 34): r.furn(13, c, 'plantt', 'plantb')
for c in (6, 7, 8): r.furn(21, c, 'tankt', 'tankb', BCYAN)
r.furn(21, 24, 'termt', 'termb')
for c in (4, 12, 28, 36): r.decor(1, c, 'lamp', BGREEN)
for c in (7, 8, 31, 32): r.decor(9, c, 'window', BCYAN)
for c in (13, 14, 26, 27): r.decor(16, c, 'window', BCYAN)
r.sign(2, 15, "GROW DECK", BCYAN)
r.robot(0, 21, 10, 34, 30); r.robot(2, 6, 2, 17, 12)
# 2: server hall - cold blue and magenta, racks and status screens
r = new("SERVER HALL", BMAG, BLUE, BCYAN, BLUE, 21, 14)
r.floor(7, 6, 35); r.floor(14, 2, 13); r.floor(14, 28, 39); r.floor(21, 2, 39)
r.pad(14, [7, 14, 21]); r.walls([7, 14, 21])
for c in (8, 9, 10, 11, 25, 26, 27, 28): r.furn(7, c, 'rackt', 'rackb')
r.furn(7, 17, 'scrtop', 'scrbot'); r.furn(7, 18, 'scrtop', 'scrbot')
for c in (4, 5, 6, 33, 34, 35): r.furn(14, c, 'rackt', 'rackb')
for c in (12, 13, 22, 23, 30, 31): r.furn(21, c, 'rackt', 'rackb')
r.furn(21, 37, 'termt', 'termb')
for c in (6, 13, 27, 34): r.decor(1, c, 'lamp', BCYAN)
for c in (19, 20, 21): r.decor(9, c, 'fan', BMAG)
for c in (8, 32): r.decor(17, c, 'fan', BMAG)
r.sign(3, 17, "NODE A3", BCYAN); r.sign(16, 17, "COLD ROW", BMAG)
r.floor(7, 20, 30, 'convl')
r.robot(1, 21, 17, 36, 26); r.robot(0, 7, 6, 35, 20)
# 3: reactor control - red light, yellow warnings, tanks and gauges
r = new("REACTOR CONTROL", YELLOW, RED, BRED, RED, 21, 8)
r.floor(8, 2, 12, 'hazard'); r.floor(8, 29, 39, 'hazard'); r.floor(14, 14, 30, 'grate'); r.floor(21, 2, 39, 'hazard')
r.pad(13, [8, 14, 21]); r.pad(31, [8, 14, 21]); r.walls([8, 14, 21])
for c in (3, 4, 5, 34, 35): r.furn(8, c, 'tankt', 'tankb')
r.furn(14, 16, 'scrtop', 'scrbot', BRED); r.furn(14, 17, 'scrtop', 'scrbot', BRED); r.furn(14, 24, 'lockt', 'lockb', BRED)
for c in (10, 11, 28, 29, 30): r.furn(21, c, 'tankt', 'tankb')
for c in (6, 18, 24, 36): r.decor(1, c, 'lamp', BRED)
for c in (8, 20, 32): r.decor(3, c, 'gauge', YELLOW)
for c in (20, 21): r.decor(10, c, 'valve', YELLOW)
r.sign(16, 4, "DANGER", YELLOW); r.sign(16, 31, "CORE 2", YELLOW)
r.robot(2, 21, 14, 27, 20); r.robot(3, 14, 20, 23, 21)
# 4: crew quarters - violet, bunks and lockers
r = new("CREW QUARTERS", BMAG, MAG, BBLUE, MAG, 21, 21)
r.floor(7, 2, 39); r.floor(14, 2, 15); r.floor(14, 22, 39); r.floor(21, 2, 39)
r.pad(16, [7, 14, 21]); r.walls([7, 14, 21])
for c in (4, 5, 8, 9, 26, 27, 30, 31): r.furn(7, c, 'bedt', 'bedb', BCYAN)
for c in (5, 6, 7, 33, 34): r.furn(14, c, 'lockt', 'lockb', BMAG)
for c in (10, 11, 24, 25): r.furn(21, c, 'bedt', 'bedb', BCYAN)
for c in (5, 15, 26, 36): r.decor(1, c, 'lamp', BMAG)
for c in (12, 13, 28, 29): r.decor(10, c, 'window', BBLUE)
r.sign(3, 18, "DECK 4", BBLUE); r.sign(17, 15, "QUIET HOURS", BMAG)
r.robot(0, 21, 3, 39, 20); r.robot(0, 14, 22, 39, 30, 2)
# 5: med bay - clean white and cyan
r = new("MED BAY", WHITE, CYAN, BCYAN, GREY, 13, 21)
r.floor(6, 6, 34); r.floor(13, 2, 18); r.floor(13, 24, 39); r.floor(21, 2, 39)
r.pad(19, [6, 13, 21]); r.walls([6, 13, 21])
for c in (8, 9, 12, 13, 26, 27, 30, 31): r.furn(6, c, 'bedt', 'bedb', WHITE)
for c in (4, 5, 10, 28, 35): r.furn(13, c, 'lockt', 'lockb', BCYAN)
for c in (8, 9, 30, 31): r.furn(21, c, 'tankt', 'tankb', BCYAN)
r.furn(21, 16, 'termt', 'termb')
for c in (6, 14, 26, 34): r.decor(1, c, 'lamp', WHITE)
r.sign(2, 17, "MED BAY", BCYAN); r.sign(16, 18, "TRIAGE", WHITE)
r.robot(1, 13, 24, 39, 32); r.robot(2, 21, 20, 39, 30)
# 6: comms array - dishes and screens, cyan on blue
r = new("COMMS ARRAY", BCYAN, BLUE, WHITE, BLUE, 14, 21)
r.floor(7, 2, 12); r.floor(7, 20, 39); r.floor(14, 2, 39); r.floor(21, 2, 39)
r.pad(13, [7, 14, 21]); r.walls([7, 14, 21])
for c in (22, 23, 24, 34, 35): r.furn(7, c, 'scrtop', 'scrbot', BCYAN)
for c in (4, 5, 30, 31): r.furn(14, c, 'rackt', 'rackb', BCYAN)
for c in (18, 19, 20): r.furn(21, c, 'scrtop', 'scrbot', BCYAN)
for c in (6, 9, 27, 33): r.decor(2, c, 'dish', WHITE)
for c in (7, 33): r.decor(10, c, 'dish', BCYAN)
r.sign(3, 15, "UPLINK", WHITE); r.sign(17, 26, "BAND 9", BCYAN)
r.robot(2, 7, 20, 39, 30); r.robot(3, 21, 27, 30, 28)
# 7: cryo store - icy white and blue
r = new("CRYO STORE", WHITE, BBLUE, BCYAN, BBLUE, 8, 21)
r.floor(8, 2, 39, 'grate', BCYAN); r.floor(14, 2, 12, 'grate', BCYAN); r.floor(14, 18, 39, 'grate', BCYAN); r.floor(21, 2, 39, 'floor', BCYAN)
r.pad(13, [8, 14, 21]); r.walls([8, 14, 21])
for c in (5, 6, 7, 20, 21, 30, 31, 32): r.furn(8, c, 'tankt', 'tankb', BCYAN)
for c in (24, 25, 26, 36): r.furn(14, c, 'tankt', 'tankb', WHITE)
for c in (5, 6, 27, 28): r.furn(21, c, 'lockt', 'lockb', BCYAN)
for c in (6, 16, 26, 36): r.decor(1, c, 'lamp', WHITE)
r.sign(3, 15, "MINUS 90", BCYAN); r.sign(17, 14, "KEEP SEALED", WHITE)
r.robot(0, 8, 2, 39, 14); r.robot(1, 21, 10, 39, 22)
# 8: splice lab - the terminal that rebuilds the override keys
r = new("SPLICE LAB", BMAG, MAG, YELLOW, MAG, None, 21)
r.floor(14, 6, 35); r.floor(21, 2, 39); r.pad(3, [14, 21]); r.walls([14, 21])
r.furn(21, 20, 'splt', 'splb'); r.furn(21, 21, 'splt', 'splb')
for c in (8, 9, 31, 32): r.furn(21, c, 'scrtop', 'scrbot', BMAG)
for c in (10, 30): r.furn(14, c, 'rackt', 'rackb', BMAG)
for c in (8, 20, 32): r.decor(1, c, 'lamp', YELLOW)
r.sign(4, 16, "SPLICE LAB", YELLOW); r.sign(17, 13, "KEYS REBUILT HERE", BMAG)
# 9: security office - terminals and a guard
r = new("SECURITY OFFICE", BGREEN, DGREY, BGREEN, GREY, None, 21)
r.floor(14, 2, 30); r.floor(21, 2, 39); r.pad(32, [14, 21]); r.walls([14, 21])
for c in (6, 12): r.furn(21, c, 'termt', 'termb')
for c in (4, 5, 6, 20, 21, 22): r.furn(14, c, 'lockt', 'lockb', GREY)
for c in (18, 19, 26): r.furn(21, c, 'scrtop', 'scrbot', BGREEN)
for c in (8, 20, 32): r.decor(1, c, 'lamp', BGREEN)
r.sign(4, 14, "SECURITY", BGREEN); r.sign(17, 10, "AUTHORISED ONLY", WHITE)
r.robot(0, 14, 4, 30, 18)                       # (a sentry by the door would be unfair)
# 10: MERIDIAN core - sealed until all three keys are rebuilt
r = Room("MERIDIAN CORE", BRED, RED, YELLOW, RED, 'circuit'); r.frame(21, None); rooms.append(r)
r.floor(21, 2, 39); r.walls([21])
for c in range(16, 26): r.decor(9, c, 'coret', BRED)
r.sign(4, 15, "MERIDIAN", BRED); r.sign(16, 12, "OVERRIDE TERMINAL", YELLOW)
r.furn(21, 20, 'splt', 'splb', BRED)
for r_ in rooms: r_.finish()
# fair entries in the hand-built rooms too: nothing that shoots on a door's floor, and
# patrols on a door's floor keep 11 cells clear of that door
def fair_doors(rm):
    keep = []
    for (k, f, lo, hi, st, sp) in rm.robots:
        left, right = rm.doors
        if f in (left, right) and k in (1, 3): k = 0
        if left == f: lo = max(lo, 13 * 4 - 2)
        if right == f: hi = min(hi, (28 - 2) * 4 + 2)
        if hi - lo < 16: continue
        keep.append((k, f, lo, hi, min(max(st, lo), hi), sp))
    rm.robots = keep
for r_ in rooms: fair_doors(r_)
# the opening wing is gentle: its hunters patrol instead (Reactor Control keeps one)
for _k, _rm in enumerate(rooms):
    if _k != 3: _rm.robots = [((0 if k == 2 else k), f, lo, hi, st, sp) for (k, f, lo, hi, st, sp) in _rm.robots]
# where the hand-built rooms stand: (gap between shafts, level); gap -1 = west of A
HAND = {0: (0, 0), 1: (0, 1), 2: (0, 2), 3: (0, 3), 4: (1, 0), 5: (1, 1), 6: (1, 2), 7: (1, 3),
        8: (-1, 2), 9: (-1, 0), 10: (11, 3)}
for i, (gp, lv) in HAND.items():
    rooms[i].gap, rooms[i].level, rooms[i].wing = gp, lv, (5 if i == 10 else 0)
import sys as _sys; _sys.path.insert(0, 'tools')
import wings as _wings
for (ri, gp, lv) in _wings.make(globals(), rooms, SOLID):
    rooms[ri].gap, rooms[ri].level = gp, lv
# balance pass: a hunter never shares a floor with a door (it runs as fast as Wren, so it
# would meet her on arrival), and splice rooms keep no hunters at all
for _rm in rooms:
    _spl = any(_rm.t[r_][c_] == 'splb' for r_ in range(22) for c_ in range(42))
    _rm.robots = [((0 if k == 2 and (_spl or f in _rm.doors) else k), f, lo, hi, st, sp)
                  for (k, f, lo, hi, st, sp) in _rm.robots]
    if _spl and _rm is not rooms[10]:   # nothing patrols the splice terminal's floor
        _sf = {r_ + 1 for r_ in range(22) for c_ in range(42) if _rm.t[r_][c_] == 'splb'}
        _rm.robots = [rb for rb in _rm.robots if rb[1] not in _sf or rb[0] >= 4]

# shafts A..L: per level (room on the left, room on the right)
LETTERS = "ABCDEFGHIJKL"
at = {(rm.gap, rm.level): k for k, rm in enumerate(rooms)}
SHAFTS = [(LETTERS[s], [(at.get((s - 1, lv)), at.get((s, lv))) for lv in range(4)]) for s in range(12)]
NKEYS, SHARDS_PER_KEY = 6, 3
for _w in range(6):                 # every wing must have a splice terminal for its key
    assert any(rm.wing == _w and any(rm.t[r_][c_] == 'splb' for r_ in range(22) for c_ in range(42)) for rm in rooms), f"wing {_w} has no splice terminal"
# what the fittings hold: each wing hides its key's three shards ($40+k) in three of its
# rooms, plus SLEEP ($20) and RESET ($30) codes; the rest are empty
import random
rnd = random.Random(2091)
loot = {i: {} for i in range(len(rooms))}
def hide(ri, item):
    free = [rc for rc in rooms[ri].searchables() if rc not in loot[ri]]
    loot[ri][rnd.choice(free)] = item
for w in range(6):
    members = [k for k, rm in enumerate(rooms) if rm.wing == w and rm.searchables()
               and not any(rm.t[r_][c_] == 'splb' for r_ in range(22) for c_ in range(42))]
    for s, ri in enumerate(rnd.sample(members, 3)): hide(ri, 0x40 + w * 3 + s)
    for ri in rnd.sample(members, 2): hide(ri, 0x20)
    for ri in rnd.sample(members, 2 if w else 1): hide(ri, 0x30)

# Each room is one record in the DAT, copied to the staging window on entry:
#   dw name, pads, signs, runs, robots, fittings (offsets) ; then the parts
def room_record(i, rm):
    name = rm.name.encode() + b'\0'
    pads = [len(rm.pads)]
    for c0, fl in rm.pads: pads += [c0, len(fl)] + fl + [0] * (4 - len(fl))
    signs = []
    for (sr, sc, ink, text) in rm.signs: signs += [sr, sc, ink] + list(text.encode()) + [0]
    signs += [0xFF]
    robots = [len(rm.robots)]
    for (k, f, lo, hi, st, sp) in rm.robots: robots += [k, f, lo, hi, st, sp]
    fits = rm.searchables(); assert len(fits) <= 32, (rm.name, len(fits))
    fitb = [len(fits)]
    for (fr, fc) in fits: fitb += [fr, fc, loot[i].get((fr, fc), 0)]
    parts = [name, bytes(pads), bytes(signs), bytes(rm.rle()), bytes(robots), bytes(fitb)]
    o = 12; hdr = []
    for part in parts: hdr += [o & 255, o >> 8]; o += len(part)
    rec = bytes(hdr) + b''.join(parts)
    assert len(rec) <= 0x800, (rm.name, len(rec))
    return rec
# which disk: wing 0 on A; wings 1-2 on B; 3-4 on C; 5 and the core on D
WING_PACK = {0: 0, 1: 1, 2: 1, 3: 2, 4: 2, 5: 3}
db("room_pack", [WING_PACK[rm.wing] for rm in rooms])
db("room_wing", [rm.wing for rm in rooms])
out.append("room_far:")
for i, rm in enumerate(rooms):
    blk, ofs, n = dat_for(WING_PACK[rm.wing]).add(room_record(i, rm))
    out.append(f"        db {blk}\n        dw ${ofs:04X},{n}")
# tile flags: bit0 floor, bit1 search it, bit2 security terminal, bit3 splice terminal,
# bit4 conveyor right, bit5 conveyor left, bit6 spore mist, bit7 ice
db("tile_flags", [(1 if n in SOLID else 0) | (2 if n in SEARCH else 0) | (4 if n == 'termb' else 0)
                  | (8 if n == 'splb' else 0) | (16 if n == 'convr' else 0) | (32 if n == 'convl' else 0)
                  | (64 if n == 'mist' else 0) | (128 if n == 'ice' else 0) for n in names])

# --- lift shafts --------------------------------------------------------------
# Columns: 0-15 rock, 16 shaft wall, 17-24 shaft, 25 wall, 26-41 rock.  Colour is
# constant down each column (each wing tints its own shafts).
TOP = 12; GAP = 8; NLEV = 4
level_rows = [TOP + GAP * i for i in range(NLEV)]
SH_ROWS = level_rows[-1] + (ROOM_ROWS - 12) + 1
SHAFT_TINT = {0: (BLUE, BBLUE), 1: (GREEN, BGREEN), 2: (BLUE, BCYAN), 3: (RED, YELLOW), 4: (MAG, BMAG), 5: (RED, BRED)}
pairs = {}
shaft_tab = []
shaft_packs = []
for s, (letter, levels) in enumerate(SHAFTS):
    wing = s // 2
    sh = [['rock' if c < 16 or c > 25 else 'shaftw' if c in (16, 25) else 'empty' for c in range(COLS)] for _ in range(SH_ROWS)]
    for (left, right), lr in zip(levels, level_rows):
        for side, room_ in (('L', left), ('R', right)):
            if room_ is None: continue
            for c in (range(0, 18) if side == 'L' else range(24, 42)):
                sh[lr - 1][c] = sh[lr - 2][c] = sh[lr - 3][c] = 'empty'
                sh[lr][c] = 'floor'
    pm = []
    for y in range(SH_ROWS - 1):
        for c in range(COLS):
            key = (tid[sh[y][c]], tid[sh[y + 1][c]])
            if key not in pairs: pairs[key] = len(pairs)
            pm.append(0x80 | pairs[key])
    blk, ofs, n = dat_for(WING_PACK[wing]).add(pm)
    lv = []
    for (left, right), lr in zip(levels, level_rows):
        lv += [lr - 12, 255 if left is None else left, 255 if right is None else right]
    bg, ink = SHAFT_TINT[wing]
    colcol = [ink | (bg << 4) if c < 16 or c > 25 else ink for c in range(COLS)]
    shaft_tab += [blk, ofs & 255, ofs >> 8, n & 255, n >> 8] + lv + [ord(letter)] + colcol
    shaft_packs.append(WING_PACK[wing])
assert len(pairs) <= 128, len(pairs)
SHAFT_REC = 5 + 3 * NLEV + 1 + COLS
db("shaft_tab", shaft_tab, 30)
db("shaft_pack", shaft_packs)
dw("combo_src", [w for (a, b) in pairs for w in (f"tiles+{a*TILE_BYTES}", f"tiles+{b*TILE_BYTES}")])
db("combo_a", [a for (a, b) in pairs])
# doors: per room  left (shaft, level, floor row), right (shaft, level, floor row); 255 = none
room_door = []
for i, rm in enumerate(rooms):
    d = []
    for side, f in zip((1, 0), rm.doors):       # left door meets a shaft's right side
        found = [255, 255, 255]
        for si, (letter, levels) in enumerate(SHAFTS):
            for li, lr_ in enumerate(levels):
                if lr_[side] == i and f is not None: found = [si, li, f]
        d += found
    room_door += d
db("room_door", room_door, 6)
# wrist-deck map: per room the column and row of its block; per room its number of fittings
db("room_mapinfo", sum(([2 + (rm.gap + 1) * 3, 13 + rm.level * 2] for rm in rooms), []))
db("room_nfits", [len(rm.searchables()) for rm in rooms])
# splice puzzle: each shard is a circuit node with arms N=1 E=2 S=4 W=8
db("splice_tgt", [0b1010, 0b0110, 0b1011, 0b0101, 0b1110, 0b0011, 0b1101, 0b1100, 0b0111,
                  0b0111, 0b1010, 0b1110, 0b0011, 0b1011, 0b0101, 0b1101, 0b1100, 0b0110])
out.append(f"NCOMBOS equ {len(pairs)}")
out.append(f"NLEVELS equ {NLEV}")
out.append(f"SHAFT_REC equ {SHAFT_REC}")
out.append(f"NROOMS equ {len(rooms)}")
out.append(f"NSHAFTS equ {len(SHAFTS)}")
out.append(f"NKEYS equ {NKEYS}")
out.append(f"SHARDS_PER_KEY equ {SHARDS_PER_KEY}")
out.append(f"CORE_ROOM equ 10")


# --- pre-shifted sprites in the banks ------------------------------------------
# For every frame: 8 variants (facing right/left x shift 0/2/4/6 px), each row as
# four (inverted mask, pixels) byte pairs, ready to AND/OR straight onto the screen.
def variants(bm, mask, h):
    out_ = []
    for face in (0, 1):
        b = [row[::-1] for row in bm] if face else bm
        m = [row[::-1] for row in mask] if face else mask
        for s in (0, 2, 4, 6):
            for y in range(h):
                pv = int(''.join(map(str, b[y])), 2) << (8 - s)
                mv = int(''.join(map(str, m[y])), 2) << (8 - s)
                for k in (24, 16, 8, 0):
                    out_ += [(~(mv >> k)) & 255, (pv >> k) & 255]
    return out_
def vtab(label, frames_, h):
    out.append(f"{label}:")
    for bm, mask in frames_:
        blk, ofs, n = dat.add(variants(bm, mask, h))
        out.append(f"        db {blk}\n        dw ${ofs:04X}")

# --- robots and sparks: 24 wide, kept in the program (drawn every frame) ------
import sys; sys.path.insert(0, 'tools')
import robots_art
def dil_h(bm, h):
    return [[1 if any(bm[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                      if 0 <= y + dy < h and 0 <= x + dx < 24) else 0 for x in range(24)] for y in range(h)]
def rb(row): return [int(''.join(map(str, row[k:k + 8])), 2) for k in (0, 8, 16)]
rf = robots_art.frames()
vtab("robot_vt", [(bm, dil_h(bm, h)) for (nm, h, bm) in rf if h == 20], 20)
vtab("spark_vt", [(bm, dil_h(bm, h)) for (nm, h, bm) in rf if h == 6], 6)
vtab("hazard_vt", [(bm, dil_h(bm, h)) for (nm, h, bm) in rf if h == 24], 24)

# --- Wren: 24 x 24 frames from the skeleton animator ------------------------
import sys; sys.path.insert(0, 'tools')
import wren_anim
frames = wren_anim.all_frames()
def dil(bm):
    return [[1 if any(bm[y + dy][x + dx] for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                      if 0 <= y + dy < 24 and 0 <= x + dx < 24) else 0 for x in range(24)] for y in range(24)]
def row_bytes(row): return [int(''.join(map(str, row[k:k + 8])), 2) for k in (0, 8, 16)]
first = {}
for n, (name, i, bm) in enumerate(frames): first.setdefault(name, n)
vtab("wren_vt", [(bm, dil(bm)) for (name, i, bm) in frames], 24)
for name, n in first.items(): out.append(f"F_{name.upper()} equ {n}")
out.append(f"F_COUNT equ {len(frames)}")
out.append(f"RUN_FRAMES equ {wren_anim.RUN_FRAMES}")
# vault arc: 36 airborne frames, peak 20 px
import math as _m
db("vault_dy", [(-round(20 * (1 - ((2 * t / 35) - 1) ** 2))) & 255 for t in range(36)])
db("vault_dy_lg", [(-round(34 * (1 - ((2 * t / 51) - 1) ** 2))) & 255 for t in range(52)])
# --- title logo: the typeface at 2x, every third line cut away (chrome stripes) -------
import sys as _sys; _sys.path.insert(0, 'tools'); import font as _font
def logo_cells():
    gl = _font.G
    cells = []
    for line, (word, colours) in enumerate((("BLACKOUT", (BCYAN, CYAN)), ("PROTOCOL", (BMAG, MAG)))):
        W_, H_ = 16 * 8, 24
        bm = [[0] * W_ for _ in range(H_)]
        for k, ch in enumerate(word):
            rows = gl[ch]
            for y in range(9):
                for x in range(7):
                    if rows[y][x] == 'X':
                        for dy in (0, 1):
                            yy = 3 + y * 2 + dy
                            if yy % 3 == 2: continue
                            for dx in (0, 1): bm[yy][k * 16 + x * 2 + dx] = 1
        for cr in range(2):
            for cc in range(16):
                b = [int(''.join(str(bm[cr * 12 + y][cc * 8 + x]) for x in range(8)), 2) for y in range(12)]
                if any(b): cells.append([line * 2 + cr, cc, colours[cr]] + b)
    return cells
_lc = logo_cells()
far("logo_far", dat.add(bytes([len(_lc)] + sum(_lc, []))))
# the title tune (tools/music.py), copied to the D800 scratch buffer while the title is up
far("title_far", dat.add(Path('build/title.mus').read_bytes()))

# --- MERIDIAN's speech: 1-bit samples from tools/speech.py, on disk D (pack 3) ---
import json as _json
_lines = _json.loads(Path('build/speech/lines.json').read_text())
out.append("speech_far:")
for name in _lines:
    blk, ofs, n = packs[2].add(Path(f'build/speech/{name}.bin').read_bytes())
    out.append(f"        db {blk}\n        dw ${ofs:04X},{n}")

# --- the game's own typeface (tools/font.py) ------------------------------------
import font as _font
font = sum(_font.glyphs(), [])
db("font", font, 12)
for n in names: out.append(f"T_{n.upper()} equ {tid[n]}")

Path("src/assets.inc").write_text("\n".join(out) + "\n")
Path("build").mkdir(exist_ok=True); Path("build/BLACKOUT.DAT").write_bytes(dat.image())
print(f"BLACKOUT.DAT: {len(dat.image())} bytes in {len(dat.blocks)} block(s) from block {DAT_FIRST}")
# pack placement: blocks after the core; on disk, each pack file starts at CP/M block 1
# of its data disk = logical sector 8 of the data area (block 0 is the directory)
base = DAT_FIRST + len(dat.blocks)
pk = [f"CORE_BASE equ {DAT_FIRST}"]
ptab = []
for k, (pd, (drive, fname)) in enumerate(zip(packs, PACK_DISKS)):
    img = pd.image(); Path(f"build/{fname}").write_bytes(img)
    nsec = (len(img) + 511) // 512
    pk.append(f"PACK{k+1}_BASE equ {base}")
    ptab += [drive, 8, 0, nsec & 255, nsec >> 8, base]
    print(f"{fname}: {len(img)} bytes ({nsec} sectors) -> drive {'ABCD'[drive]}, blocks {base}..{base + len(pd.blocks) - 1}")
    base += len(pd.blocks)
assert base <= 32, "out of banked RAM"
txt = Path("src/assets.inc").read_text()
txt = "\n".join(pk) + "\n" + txt
txt += "pack_tab:\n        db " + ",".join(str(x) for x in ptab) + "\n"
txt += f"NPACKS equ {len(packs)}\nPACK_REC equ 6\n"
Path("src/assets.inc").write_text(txt)
print(f"assets.inc: {len(names)} tiles, {len(rooms)} rooms, {len(SHAFTS)} shafts "
      f"({sum(len(r.rle()) for r in rooms)} RLE bytes), shaft {SH_ROWS} rows, {len(pairs)} combos")
