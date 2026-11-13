#!/usr/bin/env python3
"""zones.py - the four zones of BUNYIP: maps, colour themes, levers and
gates, creatures and items.  Checks that every zone can be finished.
VIBED BY BPM 2026

Map legend
  #  wall A   %  wall B   &  wall C   $  wall D (accent)   *  decoration
  D  door     G  gold door   U  blue door   R  red door
  L  lever (wall you bump; see 'levers' for what each one swings)
  v w x y    gate of group 0..3, closed at the start
  V W X Y    gate of group 0..3, open at the start
  P  secret wall (slides away when bumped)
  B  boss gate (opens when the guardian falls)      E  exit
  .  floor    @  start (facing given in 'face')
  k u r      gold / blue / red key
  h  meat pie (health)   c  charges (ammo)   o  opal (score)
  e f g      creature of kind A / B / C      Z  the zone's guardian
  !  the Southern Cross (double zaps for a while)
  n m j      scenery: the zone's three kinds of 'props' (placed by 'extras',
             a list of (letter, x, y) on open floor, to keep the maps legible)

  build/ZONES.BIN  RAM block 2, one zone every 1000h
  build/zonesym.inc
"""
import sys
from collections import deque
from pathlib import Path

WALLS = {'#': 1, '%': 2, '&': 3, '$': 4, 'D': 5, 'G': 6, 'U': 7, 'R': 8, 'L': 9,
         'E': 11, 'P': 13, 'B': 14, '*': 15}
GATES = {'v': (0, 1), 'w': (1, 1), 'x': (2, 1), 'y': (3, 1), 'V': (0, 0), 'W': (1, 0), 'X': (2, 0), 'Y': (3, 0)}
ITEMS = {'k': 1, 'u': 2, 'r': 3, 'h': 4, 'c': 5, 'o': 6, '!': 7, 'e': 8, 'f': 9, 'Z': 10, 'g': 11}
PROP_LETTERS = 'nmj'
# scenery kinds (actors.asm PTAB): name -> (number, solid, images)
PROPS = {'URN': (0, True, ['URN']), 'BRAZIER': (1, True, ['BRAZ_A', 'BRAZ_B']), 'STUMP': (2, True, ['STUMP']),
         'SHROOM': (3, False, ['SHROOM']), 'NEST': (4, True, ['NEST']), 'CART': (5, True, ['CART']),
         'LANTERN': (6, False, ['LANTERN']), 'TNT': (7, True, ['TNT']), 'BONES': (8, False, ['BONES']),
         'REEDS': (9, False, ['REEDS']), 'TAR': (10, False, ['TAR'])}
KIND_IMG = {'REDBACK': 'RB', 'FLYINGFOX': 'FF', 'YOWIE': 'YW', 'BUNYIP': 'BN',
            'CANETOAD': 'CT', 'DROPBEAR': 'DB', 'MINMIN': 'MM', 'CROC': 'CR'}
T_GATE, T_LEVER_ON = 12, 10
KINDS = {'REDBACK': 0, 'FLYINGFOX': 1, 'YOWIE': 2, 'BUNYIP': 3,
         'CANETOAD': 4, 'DROPBEAR': 5, 'MINMIN': 6, 'CROC': 7}

# colour numbers
BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)


def inks(a, b, c, d, decor):
    """type -> (x-side ink, y-side ink).  Doors, keys, levers and gates are
    the same colours in every zone so they are always recognisable."""
    t = [(0, 0)] * 16
    t[1], t[2], t[3], t[4], t[15] = a, b, c, d, decor
    t[5] = (WHITE, GREY)         # door
    t[6] = (YELLOW, BROWN)       # gold door
    t[7] = (BBLUE, BLUE)         # blue door
    t[8] = (BRED, RED)           # red door
    t[9] = (BRED, RED)           # lever, not pulled
    t[10] = (BGREEN, GREEN)      # lever, pulled
    t[11] = (BMAGENTA, MAGENTA)  # exit
    t[12] = (BCYAN, CYAN)        # gate
    t[13] = a                    # secret wall looks like wall A
    t[14] = (BRED, MAGENTA)      # boss gate
    return t


ZONES = [
 dict(
  name='SANDSTONE GALLERY',
  intro=['THE BILLABONG HAS DRAINED INTO',
         'OLD SANDSTONE HALLS. REDBACKS',
         'NEST IN THE DARK. FIND THE GOLD',
         'KEY BEHIND THE LEVER GATES.'],
  hint='LEVERS SWING THE GATES. BUMP THEM.',
  kinds=('REDBACK', 'FLYINGFOX', 'REDBACK', 'CANETOAD'),
  props=('URN', 'BRAZIER', 'BONES'),
  extras=[('m', 1, 1), ('n', 5, 6), ('n', 1, 6), ('m', 7, 1), ('m', 19, 1), ('n', 7, 6), ('n', 19, 6),
          ('n', 29, 5), ('n', 21, 5), ('m', 21, 8), ('m', 29, 8), ('j', 25, 10), ('g', 24, 9), ('g', 27, 11),
          ('n', 7, 8), ('j', 13, 11), ('m', 16, 13), ('m', 28, 13), ('m', 16, 18), ('m', 28, 18), ('j', 20, 16),
          ('n', 1, 8), ('n', 5, 18), ('g', 3, 15), ('n', 1, 22), ('g', 6, 21),
          ('!', 15, 10)],
  ceil=BLACK, floor=BLACK, floorink=BROWN,
  inks=inks((YELLOW, BROWN), (BRED, RED), (WHITE, GREY), (BROWN, RED), (BMAGENTA, MAGENTA)),
  face=0,
  levers=[0b0011, 0b0010],
  map=[
   "################################",
   "#.....#.............############",
   "#..c..#..o..........#.........o#",
   "#.....D..$..$..$..$.D..f....f..#",
   "#.@...#.............#.........h#",
   "#.....#..e..$..e..$.#.........##",
   "#.....#......h......#######D####",
   "###D########D########.........##",
   "#.....#.......#.....#.........##",
   "#..h..L.......#..o..P.........##",
   "#.....#.......#.....#.........##",
   "#..e..#...e...#######.........##",
   "#.....L.......#####%%%%%%G%%%%%%",
   "#.....####v####%.............%%%",
   "#..c..####.####%.............%%%",
   "#.....####W####%......Z......%%%",
   "#.....##.....##%.............%%%",
   "#..e..##..k..##%..c.......h..%%%",
   "#.....##.....##%.............%%%",
   "##D############%%%%%%B%%%%%%%%%%",
   "#.......f.......D....E.......o.#",
   "#..............##............###",
   "#....h.....c...##..e.....h...###",
   "################################",
   "################################",
   "################################",
   "################################",
   "################################",
   "################################",
   "################################",
   "################################",
   "################################",
  ]),
 dict(
  name='MANGROVE TUNNELS',
  intro=['ROOTS HAVE TORN THE TUNNELS',
         'APART. FLYING FOXES ROOST IN',
         'THE GLOOM. THE BLUE KEY LIES',
         'PAST THREE GATES AND A MAZE.'],
  hint='SOME LEVERS SWING MORE THAN ONE GATE.',
  kinds=('FLYINGFOX', 'YOWIE', 'FLYINGFOX', 'DROPBEAR'),
  props=('STUMP', 'SHROOM', 'NEST'),
  extras=[('n', 5, 1), ('m', 1, 4), ('m', 5, 6), ('m', 7, 5), ('m', 13, 7), ('n', 12, 9), ('j', 13, 13),
          ('m', 8, 13), ('j', 23, 9), ('g', 19, 13), ('n', 29, 9), ('m', 25, 13), ('g', 28, 12), ('m', 20, 16),
          ('m', 26, 16), ('n', 17, 20), ('n', 28, 20), ('n', 17, 22), ('n', 28, 26), ('j', 24, 24),
          ('m', 18, 24), ('m', 27, 22), ('n', 1, 15), ('m', 5, 20), ('g', 3, 22), ('!', 9, 22)],
  ceil=BLACK, floor=GREEN, floorink=BGREEN,
  inks=inks((BGREEN, GREEN), (BROWN, DGREY), (BCYAN, CYAN), (GREEN, DGREY), (YELLOW, BROWN)),
  face=0,
  levers=[0b0001, 0b0011, 0b0110],
  map=[
   "################################",
   "#@....%.....%...........%......#",
   "#.....%.%%%.%.%%%%%%%%%.%.%%%%.#",
   "#..c..D.%...%.%.....o.%...%..%.#",
   "#.....%.%.%%%.%.%%%%%.%%%%%.%%.#",
   "##D####.%.....%.%...%.......%..#",
   "#.....%.%%%%%%%.%.%.%%%%%%%%%.##",
   "#..f..%.........%.%...........##",
   "#.....%%%%%%%%%%%.%%%%%%%%%%D###",
   "#.h...L.......&&&.&.....&.....##",
   "#.....D.......&...&..e..&..o..##",
   "#..e..&...f...&.&&&.....&.....##",
   "#.....L.......&...D.....U.....##",
   "#.....&.......&&&.&.....&.....##",
   "###D###&&v&&&&&&&.&..h..&..c..##",
   "#.....&&&.&&&&&&&.&&&&&&&&&&&&##",
   "#..f..&&&.&&&&&&&..............#",
   "#.....&&&w&&&&&&&&&&&&&&&&&&&&.#",
   "#.....L.....&&&&&&&&&&&&&&&&&&.#",
   "#..c..&&&x&&&&&&$$$$$$$$$$$$$$.#",
   "#.....&&&.&&&&&&$............$.#",
   "#.e...&&&.&&&&&&$...e.....h..$.#",
   "#.....&&&.&&&&&&$............$.#",
   "#.....&&.u.&&&&&$.....Z......$.#",
   "#.....&&...&&&&&$............$.#",
   "#..h..&&&&&&&&&&$..c......o..$.#",
   "#.....&&&&&&&&&&$............$.#",
   "#.....D.........U............$o#",
   "#..o..&&&&&&&&&&$$$$$$B$$$$$$$$#",
   "######################E#########",
   "################################",
   "################################",
  ]),
 dict(
  name='OPAL MINES',
  intro=['MINERS DUG TOO DEEP AND WOKE',
         'THE YOWIES. THE TUNNELS TWIST',
         'LIKE A WARREN. SOME WALLS ARE',
         'NOT WHAT THEY SEEM. PRESS M.'],
  hint='PRESS M FOR THE MAP. TRY THE WALLS.',
  kinds=('YOWIE', 'REDBACK', 'YOWIE', 'MINMIN'),
  props=('CART', 'LANTERN', 'TNT'),
  extras=[('m', 8, 8), ('m', 16, 8), ('n', 7, 7), ('n', 17, 13), ('j', 16, 7), ('j', 10, 9), ('n', 5, 7),
          ('m', 3, 9), ('j', 5, 13), ('m', 3, 15), ('n', 7, 15), ('j', 17, 21), ('j', 17, 22), ('n', 7, 22),
          ('n', 19, 19), ('m', 10, 20), ('m', 16, 20), ('n', 1, 25), ('n', 13, 29), ('j', 12, 25), ('m', 6, 25),
          ('g', 8, 28), ('n', 30, 24), ('n', 20, 29), ('j', 29, 28), ('j', 21, 25), ('m', 25, 26), ('m', 28, 24),
          ('g', 26, 28), ('g', 12, 1), ('m', 4, 3), ('!', 29, 13)],
  ceil=BLUE, floor=DGREY, floorink=GREY,
  inks=inks((BBLUE, BLUE), (BMAGENTA, MAGENTA), (BCYAN, CYAN), (WHITE, GREY), (BCYAN, BMAGENTA)),
  face=1,
  levers=[0b0011],
  map=[
   "################################",
   "#.......#.......#.......#.....o#",
   "#.#####.#.#####.#.#####.#.###..#",
   "#.#...#...#...#...#...#...#....#",
   "#.#.#.#####.#.#####.#.#####.####",
   "#...#.......#.......#.....#....#",
   "###.###################.#.####.#",
   "#.....#...........#.....#....#.#",
   "#.@...#..e........#.###.####.#.#",
   "#.....D...........D.#.#......#.#",
   "#..c..#.....f.....#.#.######.#.#",
   "#.....#...........#........#...#",
   "##D####.....h.....#####.##.#####",
   "#.....#...........#.....#..#...#",
   "#..e..########P####.###.#.##.#.#",
   "#.....&.....&*.*&.#.#........#.#",
   "#.....&..o..&.o.&...#.#####.##.#",
   "#..h..&.....&*.*&####.#...#....#",
   "#.....&&&D&&&&&&&...e.#.#.####.#",
   "##L####.............###.#....#.#",
   "#.....v.....c.......#...####.#.#",
   "#..r..#.......f.....#.#....#.#.#",
   "#.....#.............#.#.##.#...#",
   "#######R###########&&&&&&&&&w###",
   "#&&&&&&.&&&&&&&&&&&&...........#",
   "#.............&&&&&&...h...c...#",
   "#..c..........&&&&&&...........#",
   "#.....e....h..B.....Z..........#",
   "#.............&&&&&&...........#",
   "#.E...........&&&&&&.....o.....#",
   "################################",
   "################################",
  ]),
 dict(
  name="THE BUNYIP'S DEEP",
  intro=['BENEATH IT ALL, IN BLACK WATER,',
         'THE BUNYIP WAITS. YOU NEED THE',
         'GOLD, BLUE AND RED KEYS, AND THE',
         'LEVERS MUST ALL AGREE.'],
  hint='ALL THREE GATES MUST STAND OPEN AT ONCE.',
  kinds=('YOWIE', 'REDBACK', 'BUNYIP', 'CROC'),
  props=('BONES', 'REEDS', 'TAR'),
  extras=[('m', 6, 1), ('n', 1, 5), ('j', 14, 4), ('n', 8, 1), ('m', 26, 1), ('m', 18, 5), ('g', 24, 4),
          ('j', 6, 8), ('m', 10, 7), ('n', 14, 10), ('g', 19, 9), ('j', 28, 9),
          ('m', 6, 17), ('j', 19, 12), ('g', 28, 15), ('j', 24, 20), ('m', 1, 23), ('g', 6, 25),
          ('n', 12, 23), ('n', 20, 25), ('n', 22, 28), ('g', 27, 25), ('!', 2, 16)],
  ceil=RED, floor=BLACK, floorink=RED,
  inks=inks((GREY, DGREY), (BRED, RED), (BMAGENTA, MAGENTA), (WHITE, GREY), (YELLOW, BRED)),
  face=0,
  levers=[0b0011, 0b0110, 0b0100],
  map=[
   "################################",
   "#@.....#.........#.........#...#",
   "#......#..u......#.....f...#.o.#",
   "#..c...G....e....U.........D...#",
   "#......#.........#..r......#.h.#",
   "#..h...#....h....#..c......#...#",
   "##D#############D##########D####",
   "#..........#..........#........#",
   "#..e.......D....f.....D...e....#",
   "#..........#..........#........#",
   "#....k.....#....c.....#....h...#",
   "######U#################R#######",
   "#......#......#.......#........#",
   "#..L...#..o...P.......#...L....#",
   "#......#......#...e...#........#",
   "#......D......#.......D........#",
   "#..f...#......#.......#...c....#",
   "#......#......###L#####........#",
   "####D######################D####",
   "#...........................h..#",
   "#..c.......$$$$$v$$$$$.........#",
   "#..........$$$$$w$$$$$.........#",
   "$$$$$$$$$$$$$$$$x$$$$$$$$$$$$$$$",
   "$..........$....Z....$........o$",
   "$..h.......$....o....$..c......$",
   "$..........$.........$.........$",
   "$..........$$$$B$$$$$$.........$",
   "$..............................$",
   "$...e.........E.........f......$",
   "$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$",
   "################################",
   "################################",
  ]),
]


def parse(z):
    rows = z['map']
    assert len(rows) == 32, (z['name'], len(rows))
    cells = [0] * 1024
    ents, levers, gates = [], [], []
    start = None
    rows = [list(r) for r in rows]
    for ch, x, y in z.get('extras', []):
        assert rows[y][x] == '.', (z['name'], 'extra on', x, y, rows[y][x])
        rows[y][x] = ch
    rows = [''.join(r) for r in rows]
    solid = set()
    for y, row in enumerate(rows):
        assert len(row) == 32, (z['name'], y, len(row))
        for x, ch in enumerate(row):
            i = y * 32 + x
            if ch in WALLS:
                cells[i] = WALLS[ch]
                if ch == 'L':
                    levers.append((x, y))
            elif ch in GATES:
                g, closed = GATES[ch]
                gates.append((x, y, g, closed))
                cells[i] = T_GATE if closed else 0
            elif ch in ITEMS:
                ents.append((ITEMS[ch], x, y))
            elif ch in PROP_LETTERS:
                num, sol, _ = PROPS[z['props'][PROP_LETTERS.index(ch)]]
                ents.append((16 + num, x, y))
                if sol:
                    solid.add((x, y))
            elif ch == '@':
                start = (x, y)
            else:
                assert ch == '.', (z['name'], x, y, ch)
    assert start, z['name']
    assert len(levers) == len(z['levers']), (z['name'], 'levers', len(levers))
    for y in range(32):
        for x in range(32):
            if x in (0, 31) or y in (0, 31):
                assert cells[y * 32 + x] != 0 or False, (z['name'], 'not enclosed', x, y)
    z['_solid'] = solid
    return cells, ents, levers, gates, start


def needed_images(z):
    """the sprite images this zone draws beyond the common ones"""
    names = []
    for k in z['kinds']:
        names += [KIND_IMG[k] + '_A', KIND_IMG[k] + '_B']
    for p in z['props']:
        names += PROPS[p][2]
    return names


# ------------------------------------------------------------------ solvability
def solve(z):
    """Breadth-first search over (position, keys, lever states, guardian,
    opened doors).  Returns the number of steps to the exit, or raises."""
    cells, ents, levers, gates, start = parse(z)
    masks = z['levers']
    keyat = {(x, y): t for t, x, y in ents if t in (1, 2, 3)}
    boss = [(x, y) for t, x, y in ents if t == 10]
    assert len(boss) == 1, z['name']
    gate_at = {(x, y): (g, c) for x, y, g, c in gates}

    def gate_closed(g0, levs):
        # gate group g0 is closed if (initial closed) xor (odd number of pulls touching it)
        return lambda closed: closed ^ (bin(sum(masks[i] for i in range(len(masks)) if levs >> i & 1) >> g0 & 1).count('1') % 2 == 1)

    def is_closed(pos, levs):
        g, c = gate_at[pos]
        flips = sum(1 for i, m in enumerate(masks) if (levs >> i & 1) and (m >> g & 1))
        return bool(c) ^ (flips % 2 == 1)

    lever_idx = {p: i for i, p in enumerate(levers)}
    st0 = (start, 0, 0, False)
    seen = {st0}
    q = deque([(st0, 0)])
    while q:
        (pos, keys, levs, bossdead), d = q.popleft()
        x, y = pos
        if (x, y) in keyat:
            keys |= 1 << (keyat[(x, y)] - 1)
        if (x, y) == boss[0]:
            bossdead = True
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            c = cells[ny * 32 + nx]
            npos = (nx, ny)
            nkeys, nlevs, nb = keys, levs, bossdead
            if (nx, ny) in gate_at:
                if is_closed(npos, levs):
                    continue
            elif c == 11:
                if bossdead:
                    return d + 1
                continue
            elif c == 9:                       # bump a lever: toggles it, you stay put
                nlevs = levs ^ (1 << lever_idx[npos])
                npos = pos
            elif c in (5, 13):
                pass                           # doors and secret walls open
            elif c in (6, 7, 8):
                if not keys >> (c - 6) & 1:
                    continue
            elif c == 14:
                if not bossdead:
                    continue
            elif c != 0 or npos in z['_solid']:
                continue
            s = (npos, nkeys, nlevs, nb)
            if s not in seen:
                seen.add(s)
                q.append((s, d + 1))
    raise SystemExit('zone %s cannot be finished' % z['name'])


def build(out):
    blob = bytearray(0x4000)
    S = ['; generated by tools/zones.py']
    for k, z in enumerate(ZONES):
        steps = solve(z)
        cells, ents, levers, gates, start = parse(z)
        base = k * 0x1000
        blob[base:base + 1024] = bytes(cells)
        name = z['name'].encode()[:23]
        blob[base + 0x400:base + 0x400 + len(name)] = name
        ang = z['face'] * 512
        blob[base + 0x418:base + 0x41C] = bytes([start[0], start[1], ang & 255, ang >> 8])
        kinds = [KINDS[n] for n in z['kinds']]
        blob[base + 0x41C:base + 0x424] = bytes([z['ceil'], z['floor'], z['floorink']] + kinds + [0])
        import art
        idx = {n: i for i, (n, _, _) in enumerate(art.IMAGES)}
        need = 0
        for n in needed_images(z):
            need |= 1 << idx[n]
        blob[base + 0x570:base + 0x576] = need.to_bytes(6, 'little')
        blob[base + 0x424:base + 0x444] = bytes(v for pair in z['inks'] for v in pair)
        blob[base + 0x444] = len(levers)
        for i, ((x, y), m) in enumerate(zip(levers, z['levers'])):
            blob[base + 0x445 + i * 3:base + 0x448 + i * 3] = bytes([x, y, m])
        blob[base + 0x460] = len(gates)
        for i, g in enumerate(gates):
            blob[base + 0x461 + i * 4:base + 0x465 + i * 4] = bytes(g)
        assert len(ents) <= 52, (z['name'], len(ents))
        for i, e in enumerate(ents):
            blob[base + 0x4B0 + i * 3:base + 0x4B3 + i * 3] = bytes(e)
        blob[base + 0x4B0 + len(ents) * 3] = 0xFF
        hint = z['hint'].encode()[:39]
        blob[base + 0x580:base + 0x580 + len(hint)] = hint
        for i, line in enumerate(z['intro']):
            t = line.encode()[:32]
            blob[base + 0x600 + i * 40:base + 0x600 + i * 40 + len(t)] = t
        n_en = sum(1 for e in ents if e[0] in (8, 9, 11))
        n_pr = sum(1 for e in ents if e[0] >= 16)
        print('zone %d %-20s %2d creatures, %2d items, %2d scenery, %d levers, %d gates, exit in %d steps' %
              (k + 1, z['name'], n_en, len(ents) - n_en - n_pr - 1, n_pr, len(levers), len(gates), steps))
    (out / 'ZONES.BIN').write_bytes(blob)
    S += ['Z_NAME       equ 400h', 'Z_START      equ 418h', 'Z_CEIL       equ 41Ch', 'Z_FLOOR      equ 41Dh',
          'Z_FLINK      equ 41Eh', 'Z_KINDS      equ 41Fh', 'Z_INKS       equ 424h', 'Z_LEVERS     equ 444h',
          'Z_GATES      equ 460h', 'Z_ENTS       equ 4B0h', 'Z_NEED       equ 570h', 'Z_HINT       equ 580h', 'Z_INTRO      equ 600h',
          'NZONES       equ %d' % len(ZONES)]
    (out / 'zonesym.inc').write_text('\n'.join(S) + '\n')


if __name__ == '__main__':
    build(Path(sys.argv[1] if len(sys.argv) > 1 else 'build'))
