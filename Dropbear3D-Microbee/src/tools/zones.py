#!/usr/bin/env python3
"""zones.py - the nine areas of DROPBEAR 3D (Microbee), taken from the VZ300
DROPBEAR 3D maps: themes, critters, furniture, keys, levers, gates, exits
between areas.  Checks that the whole game can be finished.
VIBED BY BPM 2026

Dropbear map legend (16 x 16, placed at the top left of the 32 x 32 map)
  # wall A   C wall B   W wall C   D door   X way out   L locked door
  S switch (lever)   G gate (a boss's gate in a boss area)   % secret wall
  . floor   P start
  b drop bear  v fruit bat  t cane toad  g magpie  n snake  s huntsman
  d dingo     B Big Fella  U the Bunyip  Y the Yowie
  h Vegemite  a ammo  k key  o opal  m map (not used: M always maps)
  r oil drum  l lamp  j shrub  q termite mound  c mine cart  u stump
  e reeds     x bones

  build/ZONES.BIN  RAM block 2, one area every 800h
  build/zonesym.inc
"""
import sys
from collections import deque
from pathlib import Path

STRIDE = 0x800
BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)

# critter kinds (actors.asm KTAB order) and their sprite images
KINDS = {'HUNTSMAN': 0, 'FRUITBAT': 1, 'YOWIE': 2, 'BUNYIP': 3, 'CANETOAD': 4,
         'DROPBEAR': 5, 'MAGPIE': 6, 'SNAKE': 7, 'DINGO': 8}
KIND_IMG = {'HUNTSMAN': 'RB', 'FRUITBAT': 'FF', 'YOWIE': 'YW', 'BUNYIP': 'BN', 'CANETOAD': 'CT',
            'DROPBEAR': 'DB', 'MAGPIE': 'MM', 'SNAKE': 'CR', 'DINGO': 'DG'}
CRIT = {'b': 'DROPBEAR', 'v': 'FRUITBAT', 't': 'CANETOAD', 'g': 'MAGPIE', 'n': 'SNAKE',
        's': 'HUNTSMAN', 'd': 'DINGO'}
BOSS = {'B': 'DROPBEAR', 'U': 'BUNYIP', 'Y': 'YOWIE'}
# furniture (actors.asm PTAB): letter -> (name, number, solid, images)
FURN = {'r': ('DRUM', 0, True, ['URN']), 'u': ('STUMP', 2, True, ['STUMP']),
        'j': ('SHRUB', 3, True, ['SHROOM']), 'q': ('TERMITES', 4, True, ['NEST']),
        'c': ('CART', 5, True, ['CART']), 'l': ('LAMP', 6, False, ['LANTERN']),
        'x': ('BONES', 8, False, ['BONES']), 'e': ('REEDS', 9, False, ['REEDS'])}
# the key (and locked door) colour of the areas that have one: 0 gold 1 blue 2 red
KEYCOL = {1: 0, 2: 0, 5: 1, 7: 2}
DIRS = {(1, 0): 0, (0, 1): 1, (-1, 0): 2, (0, -1): 3}


def inks(a, b, c):
    """wall type -> (x-side ink, y-side ink).  Doors, keys, levers, gates
    and exits look the same in every area."""
    t = [(0, 0)] * 16
    t[1], t[2], t[3], t[4], t[15] = a, b, c, a, b
    t[5] = (WHITE, GREY)         # door
    t[6] = (YELLOW, BROWN)       # gold door
    t[7] = (BBLUE, BLUE)         # blue door
    t[8] = (BRED, RED)           # red door
    t[9] = (BRED, RED)           # lever, not pulled
    t[10] = (BGREEN, GREEN)      # lever, pulled
    t[11] = (BMAGENTA, MAGENTA)  # way out
    t[12] = (BCYAN, CYAN)        # gate
    t[13] = a                    # secret wall looks like wall A
    t[14] = (BRED, MAGENTA)      # boss gate
    return t


# 8 x 10 wall textures (lit, shaded, accent) and floor, by theme
TEX = {
 'brick':    [0x00, 0xF7, 0xF7, 0xF7, 0xF7, 0x00, 0x7F, 0x7F, 0x7F, 0x7F],
 'crate':    [0xFF, 0x81, 0xC3, 0xA5, 0x99, 0x99, 0xA5, 0xC3, 0x81, 0xFF],
 'iron':     [0xCC, 0xCC, 0xCC, 0xCC, 0x00, 0xCC, 0xCC, 0xCC, 0xCC, 0x00],
 'hedge':    [0x5A, 0xB5, 0x6E, 0xDB, 0xB6, 0x6D, 0xDA, 0xB5, 0x5B, 0xEE],
 'bark':     [0xDB, 0xDB, 0x9B, 0xDA, 0xDB, 0x5B, 0xDB, 0xD9, 0xDB, 0xDB],
 'cliff':    [0x00, 0x7E, 0x7E, 0x3C, 0x00, 0xE7, 0xE7, 0xC3, 0x00, 0x3C],
 'minerock': [0x00, 0x6C, 0x7E, 0x36, 0x00, 0x1B, 0xDB, 0xCE, 0x00, 0x76],
 'timber':   [0xF7, 0xF7, 0x00, 0xEF, 0xEF, 0x00, 0xFB, 0xFB, 0x00, 0x00],
 'ore':      [0x24, 0x00, 0x81, 0x18, 0x42, 0x00, 0x24, 0x81, 0x00, 0x18],
 'mud':      [0x55, 0xAA, 0x11, 0xAA, 0x55, 0x00, 0x55, 0xAA, 0x44, 0xAA],
 'reeds':    [0x92, 0x92, 0x96, 0x92, 0xB2, 0x92, 0x92, 0x9A, 0x92, 0x92],
 'sand':     [0x00, 0xFE, 0xFE, 0xFE, 0xFE, 0x00, 0xEF, 0xEF, 0xEF, 0xEF],
 'bones':    [0x00, 0x66, 0xFF, 0x66, 0x00, 0x00, 0x3C, 0x7E, 0x3C, 0x00],
}
FLOOR = {
 'dots':  [0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00],
 'grass': [0x00, 0x10, 0x00, 0x00, 0x02, 0x00, 0x00, 0x40, 0x00, 0x00],
 'rubble': [0x00, 0x00, 0x60, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00],
 'water': [0x00, 0x00, 0x30, 0x0C, 0x00, 0x00, 0x03, 0xC0, 0x00, 0x00],
}
THEMES = {   # textures: A lit face, A shaded face (wall B shares them), C; floor; inks A B C; floor ink
 'STATION': (('brick', 'brick', 'iron'), 'dots', ((BRED, RED), (YELLOW, BROWN), (WHITE, GREY)), BROWN),
 'BUSH': (('hedge', 'hedge', 'cliff'), 'grass', ((BGREEN, GREEN), (YELLOW, BROWN), (BRED, RED)), GREEN),
 'MINE': (('minerock', 'minerock', 'ore'), 'rubble', ((GREY, DGREY), (YELLOW, BROWN), (YELLOW, GREY)), DGREY),
 'SWAMP': (('mud', 'mud', 'bark'), 'water', ((BCYAN, CYAN), (BGREEN, GREEN), (YELLOW, BROWN)), CYAN),
 'RIDGE': (('sand', 'sand', 'bones'), 'dots', ((YELLOW, BROWN), (BRED, RED), (WHITE, GREY)), BROWN),
 'LAIR': (('cliff', 'cliff', 'sand'), 'rubble', ((BMAGENTA, MAGENTA), (WHITE, GREY), (BRED, RED)), MAGENTA),
}

TEXTS = [
 (['THE STATION IS CRAWLING WITH DROP', 'BEARS. THE COUNCIL SENT YOU. YOU',
   'HAVE A BLASTER, A JAR OF VEGEMITE', 'AND NO IDEA. GET BACK TO THE UTE.'],
  'DOORS ARE PANELLED. PRESS E TO OPEN.'),
 (['GUM TREES, TERMITES AND A GOLD', 'DOOR. THE GOLD KEY IS IN THE MAZE.',
   'THE MAZE IS FULL OF SNAKES.', 'NATURALLY.'], 'GOLD DOORS NEED THE GOLD KEY.'),
 (['HEDGES. MORE HEDGES. A MAGPIE.', 'SOMEWHERE IN HERE IS A GOLD KEY.',
   'SOMEWHERE ELSE IS THE WAY OUT.', 'GOOD LUCK. WE MEAN IT. MOSTLY.'], 'M SHOWS A MAP OF WHERE YOU HAVE BEEN.'),
 (['NOBODY HAS MINED HERE SINCE 1893.', 'THE HUNTSMEN DID NOT GET THE MEMO.',
   'A LEVER SOMEWHERE SWINGS THE GATE.', 'THE ARROWS ARE A HINT.'], 'BUMP THE ARROWED LEVER TO SWING GATES.'),
 (['THE BIGGEST DROP BEAR IN THE SHIRE.', 'HE IS NOT FAT. HE IS BIG BONED.',
   'DO NOT MENTION IT. JUST SHOOT HIM.', 'HIS GATE OPENS WHEN HE FALLS.'], 'BEAT BIG FELLA TO OPEN HIS GATE.'),
 (['MIST, REEDS AND THINGS THAT CROAK.', 'THE BLUE KEY IS ON THIS SIDE.',
   'SO IS THE BLUE DOOR. FOR ONCE,', 'SOMETHING HERE IS EASY.'], 'BLUE DOORS NEED THE BLUE KEY.'),
 (['HE LIVES HERE. HE IS MOSTLY TEETH.', 'HE SPITS. HE LUNGES. HE HAS SOME',
   'FEELINGS ABOUT VISITORS. BEAT HIM', 'AND HIS GATE OPENS.'], 'KEEP MOVING. THE BUNYIP SPITS.'),
 (['SANDSTONE, DINGOES AND A RED DOOR.', 'THE RED KEY IS UP HERE TOO, PAST',
   'A GATE. THE LEVER IS HIDDEN IN A', 'CORNER. OF COURSE IT IS.'], 'RED DOORS NEED THE RED KEY.'),
 (['THE YOWIE. BLURRY IN EVERY PHOTO.', 'GETS CROSS WHEN HURT. CHUCKS ROCKS.',
   'BEAT HIM AND THE UTE IS PAST HIS', 'GATE. HOME BY TEA TIME. PROBABLY.'], 'THE UTE IS PAST THE YOWIE.'),
]
BOSSHP = {4: 'BIG FELLA', 6: 'THE BUNYIP', 8: 'THE YOWIE'}

AREAS = [
 dict(name='THE HOMESTEAD', theme='STATION', exits=[1], rows=[
  '################',
  '#P...#..lo#.g..#',
  '#....#....#.b..#',
  '#....D....D..r.#',
  '#.ra.#.t..#....#',
  '###D####%###D###',
  '#....#..o..#..g#',
  '#.CC.#.....#.h.#',
  '#.CC.#######...#',
  '#l...D....l....#',
  '#.b..#..CCC..b.#',
  '#..t.#..C.C....#',
  '#WWWW#..r.t....#',
  '#..o%....g...r.#',
  '#...#....b.....X',
  '################',
 ]),
 dict(name='THE BUSH TRACK', theme='BUSH', exits=[0, 2, 3], rows=[
  '################',
  '#...q.#..j...g.#',
  'X.....#..v.....#',
  '#.....D.....CC.#',
  '#..C.b#.n...CC.#',
  '#..C..###D######',
  '#j......#.b..q.#',
  '##.###..#......X',
  '#....#..%..o...#',
  '#.o.n#..#.gh...#',
  '#....#..########',
  '#.a..D....n....#',
  '###L###..v..CC.#',
  'X.....#.....CC.#',
  '#....b#.qb..o.j#',
  '################',
 ]),
 dict(name='GUM TREE MAZE', theme='BUSH', exits=[1], rows=[
  '################',
  '#m#.....#..g..o#',
  '#.#.###.#.###..#',
  '#.#.#...#...#..#',
  '#...#.#####.#.##',
  '###.#.#.n.#.#..#',
  '#...#...#.#.##.#',
  'X.###.#.#.#....#',
  '#.....#.#.####.#',
  '####.##.#..n.#.#',
  '#..#.#..####.#.#',
  '#.##.#.##..#.#.#',
  '#.#..#.n..##.#.#',
  '#.#.#####.#..#.#',
  '#o..g.v...#k.b.#',
  '################',
 ]),
 dict(name='THE OLD MINE', theme='MINE', exits=[1, 4], rows=[
  '################',
  '#..l.WW..c.#...#',
  'X....WW..b.#.o.#',
  '#......s...#.l.#',
  '#.WW...WW..##D##',
  '#.WW.b.WW..s...#',
  '#..r.......WW..#',
  '####D#####.WW..#',
  '#..l.#.....v...#',
  '#.m..#..WWWGWWWW',
  '#s...#..W.b.s.h#',
  '#..b.#..W......#',
  '#....#..W.WWWW.#',
  '##S###..W.W..%.#',
  '#a..s...W.Wo.W.X',
  '################',
 ]),
 dict(name="BIG FELLA'S DEN", theme='MINE', exits=[3, 5], rows=[
  '################',
  '#.....#..l..l..#',
  'X..a..D........#',
  '#.....#..W..W..#',
  '#.h...#.x....x.#',
  '###D###...B....#',
  '#.s...#........#',
  '#..o..#..W..W..#',
  '#...c.#.s....s.#',
  '#.....#######G##',
  '#.b...#.....#..#',
  '#...s.#..o..#..#',
  '#.....%.....#..#',
  '#.c...#..x..#..#',
  '#..a..#.....#..X',
  '################',
 ]),
 dict(name='THE BILLABONG', theme='SWAMP', exits=[4, 6], rows=[
  '################',
  '#....te#..v....#',
  'X..CC..#.CC.uCC#',
  '#..CC..D.CC..t.#',
  '#....v.#....b..#',
  '#......###L#####',
  '##D#####.......#',
  '#e...n.#.CC.v..#',
  '#.CC...#.CC...u#',
  '#.CC.b.#.b.WWt.#',
  '#..t...#...WW.o#',
  '#.k..m.#.t.....#',
  '####%###.n.....#',
  '#.o.h..#e......#',
  '#......#..a....X',
  '################',
 ]),
 dict(name="BUNYIP'S POOL", theme='SWAMP', exits=[5, 7], rows=[
  '################',
  '#....e#e.....e.#',
  'X.....D...CC...#',
  '#..h..#...CC.t.#',
  '#.....#.t......#',
  '#..a..#.CC..U..#',
  '##D####.CC.....#',
  '#..n..#......u.#',
  '#.o...#.u.CC...#',
  '#....n#...CC.t.#',
  '#..v..#........#',
  '#e....######G###',
  '#.....#.v.t...o#',
  '#..a.t#...e....#',
  '#.....#........X',
  '################',
 ]),
 dict(name='THE RIDGE', theme='RIDGE', exits=[6, 8], rows=[
  '################',
  '#.....#.v...#.o#',
  'X.###.#.###.#..#',
  '#.#x..#...#.#L##',
  '#.#.#####n#....#',
  '#.#..b..#.####n#',
  '#.#####.#..d.#.#',
  '#m....#...k..#.#',
  '#####G###S######',
  '#......j....d..#',
  '#.WW.qb...WW...#',
  '#.WW......WWj..#',
  '#...d..v.x.....#',
  '#..a....n..h...#',
  '#..x.......o...X',
  '################',
 ]),
 dict(name="YOWIE'S LAIR", theme='LAIR', exits=[7, 255], rows=[
  '################',
  '#.....#..l...l.#',
  'X..h..D.u....d.#',
  '#.....#..WW....#',
  '#..a..#..WW.Y..#',
  '###D###x.......#',
  '#.....#....WW.x#',
  '#..o.d#.s..WW..#',
  '#.....D......s.#',
  '#.b...#######G##',
  '#..s..#..x....v#',
  '#..a..#.u.....o#',
  '#.....#.......h#',
  '#.d...#..l.....#',
  '#..v..#........X',
  '################',
 ]),
]


def parse(ai):
    A = AREAS[ai]
    rows = A['rows']
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), A['name']
    cells = [1] * 1024
    ents, levers, gates, xs = [], [], [], []
    kinds = [None] * 5                         # A, B, guardian, C, D
    slots = [0, 1, 3, 4]
    props = []
    solid = set()
    start = None
    isboss = any(ch in BOSS for r in rows for ch in r)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            i = y * 32 + x
            c = 0
            if ch == '#': c = 1
            elif ch == 'C': c = 2
            elif ch == 'W': c = 3
            elif ch == 'D': c = 5
            elif ch == 'X': c = 11; xs.append((x, y))
            elif ch == 'L': c = 6 + KEYCOL[ai]
            elif ch == 'S': c = 9; levers.append((x, y))
            elif ch == 'G':
                if isboss: c = 14
                else: c = 12; gates.append((x, y, 0, 1))
            elif ch == '%': c = 13
            elif ch == 'P': start = (x, y)
            elif ch in CRIT:
                k = CRIT[ch]
                if k not in [kinds[s] for s in slots]:
                    free = [s for s in slots if kinds[s] is None]
                    assert free, (A['name'], 'more than 4 kinds')
                    kinds[free[0]] = k
                s = [s for s in slots if kinds[s] == k][0]
                ents.append(((8, 9, 10, 11, 12)[s], x, y))
            elif ch in BOSS:
                kinds[2] = BOSS[ch]
                ents.append((10, x, y))
            elif ch == 'h': ents.append((4, x, y))
            elif ch == 'a': ents.append((5, x, y))
            elif ch == 'o': ents.append((6, x, y))
            elif ch == 'k': ents.append((1 + KEYCOL[ai], x, y))
            elif ch in FURN:
                nm, num, sol, imgs = FURN[ch]
                if nm not in props: props.append(nm)
                ents.append((16 + num, x, y))
                if sol: solid.add((x, y))
            else:
                assert ch in '.m', (A['name'], x, y, ch)
            cells[i] = c
    assert len(props) <= 3, (A['name'], props)
    assert len(xs) == len(A['exits']), A['name']
    return dict(cells=cells, ents=ents, levers=levers, gates=gates, xs=xs, kinds=kinds,
                props=props, solid=solid, start=start)


P = [parse(i) for i in range(len(AREAS))]


def entry_for(area, cell):
    """the floor beside an area's way in, and the facing away from it"""
    x, y = cell
    p = P[area]
    for (dx, dy), f in DIRS.items():
        nx, ny = x + dx, y + dy
        if 0 <= nx < 16 and 0 <= ny < 16 and p['cells'][ny * 32 + nx] == 0                 and not any(e[1] == nx and e[2] == ny for e in p['ents']):
            return (nx, ny), f
    raise SystemExit('no floor beside the way in at %s in %s' % (cell, AREAS[area]['name']))


EXITS = []
for ai, A in enumerate(AREAS):
    ex = []
    for (x, y), tgt in zip(P[ai]['xs'], A['exits']):
        if tgt == 255:
            ex.append((x, y, 255, 0, 0, 0))
            continue
        back = [c for c, t in zip(P[tgt]['xs'], AREAS[tgt]['exits']) if t == ai]
        assert len(back) == 1, (A['name'], tgt)
        (cx, cy), face = entry_for(tgt, back[0])
        ex.append((x, y, tgt, cx, cy, face))
    EXITS.append(ex)


def needed_images(ai):
    names = []
    for k in P[ai]['kinds']:
        if k:
            names += [KIND_IMG[k] + '_A', KIND_IMG[k] + '_B']
    for nm in P[ai]['props']:
        names += [f[3] for f in FURN.values() if f[0] == nm][0]
    return names


def solve():
    """breadth-first over the whole game: area, cell, keys, levers pulled
    (one bit per area), guardians beaten.  Returns steps to the ute and the
    cells that can be reached."""
    sx, sy = P[0]['start']
    st0 = (0, sx, sy, 0, 0, 0)
    seen = {st0}
    reach = set()
    q = deque([(st0, 0)])
    while q:
        (a, x, y, keys, levs, boss), d = q.popleft()
        p = P[a]
        reach.add((a, x, y))
        for t, ex, ey in p['ents']:
            if (ex, ey) == (x, y):
                if t in (1, 2, 3): keys |= 1 << (t - 1)
                if t == 10: boss |= 1 << a
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            c = p['cells'][ny * 32 + nx]
            na, nlevs = a, levs
            if c == 12:
                if not levs >> a & 1: continue
            elif c == 11:
                e = [e for e in EXITS[a] if e[:2] == (nx, ny)][0]
                if e[2] == 255:
                    return d + 1, reach
                na, nx, ny = e[2], e[3], e[4]
            elif c == 9:
                nlevs = levs ^ (1 << a); nx, ny = x, y
            elif c in (5, 13): pass
            elif c in (6, 7, 8):
                if not keys >> (c - 6) & 1: continue
            elif c == 14:
                if not boss >> a & 1: continue
            elif c != 0 or (nx, ny) in p['solid']:
                continue
            s = (na, nx, ny, keys, nlevs, boss)
            if s not in seen:
                seen.add(s); q.append((s, d + 1))
    raise SystemExit('the game cannot be finished')


def build(out):
    import art
    idx = {n: i for i, (n, _, _) in enumerate(art.IMAGES)}
    steps, reach = solve()
    for ai, p in enumerate(P):
        for t, x, y in p['ents']:
            if t < 16 and (ai, x, y) not in reach:
                raise SystemExit('%s: thing %d at %d,%d cannot be reached' % (AREAS[ai]['name'], t, x, y))
    blob = bytearray(STRIDE * len(AREAS))
    nopals = 0
    for k, A in enumerate(AREAS):
        p = P[k]
        base = k * STRIDE
        blob[base:base + 1024] = bytes(p['cells'])
        name = A['name'].encode()[:23]
        blob[base + 0x400:base + 0x400 + len(name)] = name
        st = p['start'] or (EXITS[k][0][0], EXITS[k][0][1])
        blob[base + 0x418:base + 0x41C] = bytes([st[0], st[1], 0, 0])
        tex, flo, ink3, flink = THEMES[A['theme']]
        kinds = [KINDS[n] if n else 0 for n in p['kinds']]
        blob[base + 0x41C:base + 0x424] = bytes([BLACK, BLACK, flink] + kinds)
        need = 0
        for n in needed_images(k):
            need |= 1 << idx[n]
        blob[base + 0x570:base + 0x576] = need.to_bytes(6, 'little')
        t = [v for nm in tex for v in TEX[nm]] + FLOOR[flo]
        blob[base + 0x6A0:base + 0x6C8] = bytes(t)
        blob[base + 0x424:base + 0x444] = bytes(v for pair in inks(*ink3) for v in pair)
        blob[base + 0x444] = len(p['levers'])
        for i, (x, y) in enumerate(p['levers']):
            blob[base + 0x445 + i * 3:base + 0x448 + i * 3] = bytes([x, y, 1])
        blob[base + 0x460] = len(p['gates'])
        for i, g in enumerate(p['gates']):
            blob[base + 0x461 + i * 4:base + 0x465 + i * 4] = bytes(g)
        assert len(p['ents']) <= 52, (A['name'], len(p['ents']))
        for i, e in enumerate(p['ents']):
            blob[base + 0x4B0 + i * 3:base + 0x4B3 + i * 3] = bytes(e)
        blob[base + 0x4B0 + len(p['ents']) * 3] = 0xFF
        intro, hint = TEXTS[k]
        blob[base + 0x580:base + 0x580 + len(hint)] = hint.encode()[:39]
        for i, line in enumerate(intro):
            assert len(line) <= 36, line
            blob[base + 0x600 + i * 40:base + 0x600 + i * 40 + len(line)] = line.encode()
        blob[base + 0x6C8] = len(EXITS[k])
        for i, e in enumerate(EXITS[k]):
            blob[base + 0x6C9 + i * 6:base + 0x6CF + i * 6] = bytes(e)
        n_en = sum(1 for e in p['ents'] if 8 <= e[0] < 16)
        n_op = sum(1 for e in p['ents'] if e[0] == 6)
        nopals += n_op
        print('area %d %-16s %2d critters, %2d opals, %2d furniture, %d exits, kinds %s' %
              (k + 1, A['name'], n_en, n_op, sum(1 for e in p['ents'] if e[0] >= 16), len(EXITS[k]),
               ','.join(n or '-' for n in p['kinds'])))
    print('the ute is %d steps away, %d opals in all' % (steps, nopals))
    (out / 'ZONES.BIN').write_bytes(blob)
    S = ['; generated by tools/zones.py',
         'Z_NAME       equ 400h', 'Z_START      equ 418h', 'Z_CEIL       equ 41Ch', 'Z_FLOOR      equ 41Dh',
         'Z_FLINK      equ 41Eh', 'Z_KINDS      equ 41Fh', 'Z_INKS       equ 424h', 'Z_LEVERS     equ 444h',
         'Z_GATES      equ 460h', 'Z_ENTS       equ 4B0h', 'Z_NEED       equ 570h', 'Z_TEX        equ 6A0h',
         'Z_HINT       equ 580h', 'Z_INTRO      equ 600h', 'Z_EXITS      equ 6C8h',
         'NZONES       equ %d' % len(AREAS), 'NOPALS       equ %d' % nopals, 'ZSTRIDE      equ %d' % STRIDE]
    (out / 'zonesym.inc').write_text('\n'.join(S) + '\n')


if __name__ == '__main__':
    build(Path(sys.argv[1] if len(sys.argv) > 1 else 'build'))
