#!/usr/bin/env python3
"""gen.py - engine tables and PCG glyphs for BUNYIP (Microbee Premium Plus)
VIBED BY BPM 2026

Writes
  build/TABLES.BIN   RAM block 1 (the lower window during play), org 0000h
  build/PCG.BIN      RAM block 4: 16 PCG banks x 128 glyphs x 10 bytes
  build/tabsym.inc   addresses of everything in TABLES.BIN, glyph numbers

Number formats
  angles   2048 to the circle (0 = east, clockwise on the map)
  lengths  8.8 fixed point (256 = one map cell)
  logs     256 * log2(value), where value is the 8.8 number
"""
import math, sys
from pathlib import Path

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else 'build')
NANG = 2048
VIEW_ROWS = 22            # character rows in the 3D window
CH = 10                   # scanlines per character cell
HALF = VIEW_ROWS * CH // 2   # 110 scanlines above / below the horizon
HFOV = math.radians(37.5) # half field of view (75 degrees across)
# A 40-column dot is 1.33 scanlines wide on the monitor, so a square wall is
# (160 dots / tan(half fov)) * 1.33 scanlines tall at distance 1; half of that:
KH = 0.5 * 160 / math.tan(HFOV) * 4 / 3
DDMAX = 64 * 256          # clamp for the per-cell ray step
SPEED = 0.05              # cells per 50 Hz field


def lg(v):
    return int(round(256 * math.log2(v)))


class Block:
    """lays tables out in a 32K block and remembers their addresses"""

    def __init__(self, size=0x8000):
        self.data = bytearray(size)
        self.pc = 0
        self.sym = {}

    def align(self, n=256):
        self.pc = (self.pc + n - 1) // n * n

    def put(self, name, b, align=None):
        if align:
            self.align(align)
        b = bytes(b)
        assert self.pc + len(b) <= len(self.data), ('block full', name, hex(self.pc))
        self.data[self.pc:self.pc + len(b)] = b
        if name:
            self.sym[name] = self.pc
        self.pc += len(b)

    def words(self, name, vals, align=None):
        self.put(name, b''.join((v & 0xFFFF).to_bytes(2, 'little') for v in vals), align)

    def space(self, name, n, align=None):
        self.put(name, bytes(n), align)


T = Block()

# ---------------------------------------------------------------- ray tables
ld4 = []
for a in range(NANG):
    t = 2 * math.pi * a / NANG
    c, s = abs(math.cos(t)), abs(math.sin(t))
    ld4 += [lg(min(DDMAX, 256 / c if c > 1e-9 else 1e9)), lg(min(DDMAX, 256 / s if s > 1e-9 else 1e9))]
T.words('LD4', ld4, 256)
EXPN = lg(DDMAX) + 2
T.words('EXPT', [min(32767, int(round(2 ** (i / 256)))) for i in range(EXPN)])
# movement per field along x for angle/4 (cells/65536)
T.words('MVT', [int(round(math.cos(2 * math.pi * a / 512) * 65536 * SPEED)) for a in range(512)], 2)
# log of the fraction to the next grid line: LFN[f] = log(f/256), LFP[f] = log((256-f)/256)
T.words('LFN', [(-8192 if f == 0 else lg(f) - 2048) for f in range(256)])
T.words('LFP', [lg(256 - f) - 2048 for f in range(256)])


def raytab(name, rays, n):
    v = []
    for i in rays:
        u = (i - (n - 1) / 2) / (n / 2) * math.tan(HFOV)
        off = int(round(math.atan(u) * NANG / (2 * math.pi)))
        v += [off, lg(math.cos(off * 2 * math.pi / NANG) * 256) - 2048]
    T.words(name, v)


raytab('RAYA', range(0, 81, 2), 80)   # even rays; ray 80 is just off the right edge
raytab('RAYO', range(1, 80, 2), 80)   # odd rays, cast only where the wall changes
raytab('RAY40', range(40), 40)

# distance (1/64 cell, 0..2047) -> e = scanlines of ceiling above the wall top
et = []
for i in range(2048):
    h = HALF if i == 0 else max(1, min(HALF, int(round(KH * 64 / i))))
    et.append(HALF - h)
T.put('ET', et, 256)

# column profiles: rows of the cell that are wall, for ceiling height e, row r
prof = []
for e in range(HALF + 1):
    prof += [max(0, min(CH, (r + 1) * CH - e)) for r in range(11)] + [0] * 5
T.put('PROF', [0x80 + v for v in prof], 256)
T.put('PROFL', [(CH + 1) * v for v in prof], 256)
T.put('TMINT', [e // CH for e in range(HALF + 1)], 256)
T.put('TFULLT', [(e + CH - 1) // CH for e in range(HALF + 1)])

# screen row addresses for the two pages (view starts on screen row 1)
T.words('ROWT', [0xF000 + (r + 1) * 40 for r in range(22)], 256)
T.space(None, 64 - 44)
T.words('ROWT1', [0xF400 + (r + 1) * 40 for r in range(22)])
T.put('ROWBANK', [0] * 11 + [6] * 11)              # PCG bank group for each view row

# shade key (type * 8 + side * 4 + band) -> ink, pattern.  +128 = mono.
# Filled per zone by the game.
T.space('SHC', 256, 256)
T.space('SHP', 256, 256)

# the zone being played (copied in from the zone data) and the cells seen
T.space('MAP', 1024, 256)
T.space('SEEN', 1024)
T.space('STAMP', 1024)        # MAP + 800h: the frame each cell was last crossed by a ray

# sprite projection
# |cos| of every angle, 0..255 (sign from the quadrant)
T.put('COSM', [min(255, int(round(abs(math.cos(2 * math.pi * a / NANG)) * 256))) for a in range(NANG)], 256)
# z in 1/32 cell -> half wall height in scanlines (KH / z), clamped to 255
T.put('YBT', [min(255, int(round(KH * 32 / max(z, 1)))) for z in range(512)], 256)
# quarter squares for 8 x 8 multiplies: n*n/4, n = 0..511
T.words('QSQ', [n * n // 4 for n in range(512)], 256)

print('TABLES.BIN: %d bytes used of 32768' % T.pc)

# ---------------------------------------------------------------- PCG glyphs
# Six wall textures, each 8 dots by 10 scanlines, tiling from cell to cell.
# 0 and 1 are the zone's wall (lit and shaded face) and 2 its accent wall;
# 3 doors, 4 gates and 5 lever / exit panels are the same in every zone.
# The game makes banks 0-11 again for every zone (src/main.asm wallgen)
# from the textures in the zone data; these are zone 1's, as a start.
PAT_DOOR = [0xFF, 0x81, 0x81, 0x81, 0x99, 0x99, 0x81, 0x81, 0x81, 0xFF]   # hollow panels with a stud
PAT_GATE = [0x66] * 4 + [0x00] + [0x66] * 4 + [0xFF]
PAT_PANEL = [0x18, 0x3C, 0x7E, 0xFF, 0x18, 0x18, 0x18, 0x18, 0x00, 0xFF]  # arrows: something to use
PAT = [
    [0x00, 0xFE, 0xFE, 0xFE, 0xFE, 0x00, 0xEF, 0xEF, 0xEF, 0xEF],
    [0x00, 0xAA, 0x54, 0xAA, 0x54, 0x00, 0xAA, 0x45, 0xAA, 0x45],
    [0xFF, 0x00, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0xDB, 0x00, 0xFF],
    PAT_DOOR, PAT_GATE, PAT_PANEL,
]
FLOOR = [0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00]
NPAT = 6


def nib(lcond, rcond, a, b):
    """left nibble from a if lcond else b; same for the right nibble"""
    return ((a if lcond else b) & 0xF0) | ((a if rcond else b) & 0x0F)


N1 = CH + 1                             # each half holds 0..CH scanlines of wall
banks = []
for p in range(NPAT):                   # top half: wall grows up from the cell bottom
    banks.append([[nib(y >= CH - l, y >= CH - r, PAT[p][y], 0) for y in range(CH)]
                  for l in range(N1) for r in range(N1)])
for p in range(NPAT):                   # bottom half: wall hangs from the cell top, floor below
    banks.append([[nib(y < l, y < r, PAT[p][y], FLOOR[y]) for y in range(CH)]
                  for l in range(N1) for r in range(N1)])

# ---------------------------------------------------------------- font + HUD icons (bank 12)
FONT = {    # 7 x 8, heavy two-dot strokes with clipped corners
 ' ': ['.......'] * 8,
 '0': ['.#####.', '#######', '##..###', '##.#.##', '###..##', '##...##', '#######', '.#####.'],
 '1': ['..##...', '.###...', '####...', '..##...', '..##...', '..##...', '######.', '######.'],
 '2': ['.#####.', '#######', '##...##', '....##.', '..###..', '.##....', '#######', '#######'],
 '3': ['######.', '#######', '.....##', '..####.', '..#####', '.....##', '#######', '######.'],
 '4': ['...###.', '..####.', '.##.##.', '##..##.', '#######', '#######', '....##.', '....##.'],
 '5': ['#######', '#######', '##.....', '######.', '#######', '.....##', '#######', '######.'],
 '6': ['.#####.', '######.', '##.....', '######.', '#######', '##...##', '#######', '.#####.'],
 '7': ['#######', '#######', '.....##', '....##.', '...##..', '..##...', '..##...', '..##...'],
 '8': ['.#####.', '##...##', '##...##', '.#####.', '#######', '##...##', '#######', '.#####.'],
 '9': ['.#####.', '#######', '##...##', '#######', '.######', '.....##', '.######', '.#####.'],
 'A': ['.#####.', '#######', '##...##', '#######', '#######', '##...##', '##...##', '##...##'],
 'B': ['######.', '#######', '##...##', '######.', '######.', '##...##', '#######', '######.'],
 'C': ['.######', '#######', '##.....', '##.....', '##.....', '##.....', '#######', '.######'],
 'D': ['######.', '#######', '##...##', '##...##', '##...##', '##...##', '#######', '######.'],
 'E': ['#######', '#######', '##.....', '######.', '######.', '##.....', '#######', '#######'],
 'F': ['#######', '#######', '##.....', '######.', '######.', '##.....', '##.....', '##.....'],
 'G': ['.######', '#######', '##.....', '##.####', '##.####', '##...##', '#######', '.#####.'],
 'H': ['##...##', '##...##', '##...##', '#######', '#######', '##...##', '##...##', '##...##'],
 'I': ['.#####.', '.#####.', '..###..', '..###..', '..###..', '..###..', '.#####.', '.#####.'],
 'J': ['..#####', '..#####', '....##.', '....##.', '....##.', '##..##.', '######.', '.####..'],
 'K': ['##...##', '##..##.', '##.##..', '####...', '####...', '##.##..', '##..##.', '##...##'],
 'L': ['##.....', '##.....', '##.....', '##.....', '##.....', '##.....', '#######', '#######'],
 'M': ['##...##', '###.###', '#######', '##.#.##', '##...##', '##...##', '##...##', '##...##'],
 'N': ['##...##', '###..##', '####.##', '##.####', '##..###', '##...##', '##...##', '##...##'],
 'O': ['.#####.', '#######', '##...##', '##...##', '##...##', '##...##', '#######', '.#####.'],
 'P': ['######.', '#######', '##...##', '#######', '######.', '##.....', '##.....', '##.....'],
 'Q': ['.#####.', '#######', '##...##', '##...##', '##.#.##', '##..##.', '######.', '.###.##'],
 'R': ['######.', '#######', '##...##', '#######', '######.', '##.##..', '##..##.', '##...##'],
 'S': ['.######', '#######', '##.....', '######.', '.######', '.....##', '#######', '######.'],
 'T': ['#######', '#######', '..###..', '..###..', '..###..', '..###..', '..###..', '..###..'],
 'U': ['##...##', '##...##', '##...##', '##...##', '##...##', '##...##', '#######', '.#####.'],
 'V': ['##...##', '##...##', '##...##', '##...##', '.##.##.', '.##.##.', '..###..', '...#...'],
 'W': ['##...##', '##...##', '##...##', '##.#.##', '#######', '###.###', '##...##', '#.....#'],
 'X': ['##...##', '##...##', '.##.##.', '..###..', '..###..', '.##.##.', '##...##', '##...##'],
 'Y': ['##...##', '##...##', '.##.##.', '..###..', '..###..', '..###..', '..###..', '..###..'],
 'Z': ['#######', '#######', '....##.', '...##..', '..##...', '.##....', '#######', '#######'],
 '.': ['.......'] * 6 + ['..##...', '..##...'],
 ',': ['.......'] * 5 + ['..##...', '..##...', '.##....'],
 ':': ['.......', '..##...', '..##...', '.......', '.......', '..##...', '..##...', '.......'],
 '-': ['.......'] * 3 + ['######.', '######.'] + ['.......'] * 3,
 '/': ['.....##', '....##.', '....##.', '...##..', '..##...', '.##....', '.##....', '##.....'],
 '=': ['.......', '#######', '#######', '.......', '.......', '#######', '#######', '.......'],
 '!': ['..##...', '..##...', '..##...', '..##...', '..##...', '.......', '..##...', '..##...'],
 '?': ['.#####.', '##...##', '.....##', '...###.', '..##...', '.......', '..##...', '..##...'],
 "'": ['..##...', '..##...', '.##....'] + ['.......'] * 5,
 '+': ['.......', '..##...', '..##...', '######.', '######.', '..##...', '..##...', '.......'],
 '(': ['...##..', '..##...', '.##....', '.##....', '.##....', '.##....', '..##...', '...##..'],
 ')': ['.##....', '..##...', '...##..', '...##..', '...##..', '...##..', '..##...', '.##....'],
}
ICONS = {   # 8 x 10, full cell
 '#': ['########'] * 10,                                   # bar segment, full
 '%': ['####....'] * 10,                                   # bar segment, half
 '_': ['........'] * 3 + ['#.#.#.#.', '........'] * 2 + ['........'] * 3,   # bar, empty
 '^': ['########'] * 5 + ['........'] * 5,                 # map: top half
 '`': ['........'] * 5 + ['########'] * 5,                 # map: bottom half
 '~': ['........', '........', '...##...', '..####..', '.######.', '.######.', '..####..',
       '...##...', '........', '........'],               # map: you are here
 '<': ['........', '..###...', '.#...#..', '.#...#..', '..###...', '...#....', '...##...',
       '...#....', '...###..', '........'],               # key
 '>': ['........', '.##.##..', '#######.', '#######.', '#######.', '.#####..', '..###...',
       '...#....', '........', '........'],               # heart
 '|': ['........', '...#....', '..###...', '..###...', '..###...', '..###...', '..###...',
       '..###...', '........', '........'],               # charge (ammo)
 '@': ['..####..', '.#....#.', '#..##..#', '#.#..#.#', '#.#..#.#', '#..####.', '.#......',
       '..####..', '........', '........'],               # opal (score)
}
font_bank, fmap = [], [0x80] * 96
for i, (ch, rows) in enumerate(FONT.items()):
    assert len(rows) == 8 and all(len(r) == 7 for r in rows), ch
    font_bank.append([0] + [int(r.replace('#', '1').replace('.', '0'), 2) << 1 for r in rows] + [0])
    fmap[ord(ch) - 32] = 0x80 + i
for ch, rows in ICONS.items():
    fmap[ord(ch) - 32] = 0x80 + len(font_bank)
    font_bank.append([int(r.replace('#', '1').replace('.', '0'), 2) for r in rows])
# the zapper: a stepped block of whole cells (6 x 4), two frames; GUNMAP
# gives each cell's glyph (0 = not part of it, left alone)
sys.path.insert(0, str(Path(__file__).resolve().parent))
import art as _art
GUN_CODE = 0x80 + len(font_bank)
GUNMAP = []
_seen = {}
for fr in range(2):
    c, used = _art.zapper(fr)
    for r in range(4):
        for cx in range(6):
            if (cx, r) not in used:
                GUNMAP.append(0)
                continue
            g = tuple(sum(c[r * CH + y][cx * 8 + b] << (7 - b) for b in range(8)) for y in range(CH))
            if g not in _seen:
                _seen[g] = 0x80 + len(font_bank)
                font_bank.append(list(g))
            GUNMAP.append(_seen[g])
assert len(font_bank) <= 128
banks.append(font_bank)
FONT_BANK = len(banks) - 1          # 12

# banks 13..15: the title logo (overwritten by the sprite pools during play)
sys.path.insert(0, str(Path(__file__).resolve().parent))
import art
logo_glyphs, logo_map = art.title_logo(CH)
for b in range(3):
    banks.append(logo_glyphs[b * 128:(b + 1) * 128])

pcg = bytearray(16 * 1280)
for b, bank in enumerate(banks):
    for c, g in enumerate(bank):
        assert len(g) == CH
        pcg[b * 1280 + c * 10:b * 1280 + c * 10 + 10] = bytes(g)
# after the glyphs, in RAM block 4: 5000h the sprite directory (tools/art.py),
# then copies of the two cell-profile tables, so the sprite code can work out
# what the wall renderer put in a cell without reading the screen back;
# 7600h on is LITC (lit dots per glyph), made by the game
pcg += bytes(0x6800 - len(pcg))
pcg += bytes(T.data[T.sym['PROF']:T.sym['PROF'] + 0x700])
pcg += bytes(T.data[T.sym['PROFL']:T.sym['PROFL'] + 0x700])
assert len(pcg) == 0x7600
(OUT / 'PCG.BIN').write_bytes(pcg)
(OUT / 'TABLES.BIN').write_bytes(T.data[:T.pc])

S = ['; generated by tools/gen.py - do not edit']
for k, v in sorted(T.sym.items(), key=lambda kv: kv[1]):
    S.append('%-12s equ %05Xh' % (k, v))
S += ['FONT_BANK    equ %d' % FONT_BANK, 'CELLH        equ %d' % CH, 'NOWALL       equ %d' % HALF,
      'NWALLBANKS   equ 12', 'NPAT         equ %d' % NPAT, 'PROF4        equ 6800h', 'PROFL4       equ 6F00h',
      'LITC         equ 7600h']
S.append('GUN_CODE     equ %d' % GUN_CODE)
S.append('GUNMAP:      ; 2 frames x 4 rows x 6 cells')
for i in range(0, 48, 6):
    S.append('        db ' + ','.join('%d' % v for v in GUNMAP[i:i + 6]))
S.append('PAT_FIXED:   ; door, gate, panel')
for pt in (PAT_DOOR, PAT_GATE, PAT_PANEL):
    S.append('        db ' + ','.join('%d' % v for v in pt))
S.append('FMAP:')
for i in range(0, 96, 16):
    S.append('        db ' + ','.join('%d' % v for v in fmap[i:i + 16]))
S.append('LOGO_W       equ %d' % art.LOGO_W)
S.append('LOGO_H       equ %d' % art.LOGO_H)
(OUT / 'logo.map').write_bytes(bytes(logo_map))     # (code, bank) per cell: goes into block 2 (tools/front.py)
(OUT / 'tabsym.inc').write_text('\n'.join(S) + '\n')
print('PCG.BIN: %d banks, font %d glyphs; logo %dx%d cells' %
      (len(banks), len(font_bank), art.LOGO_W, art.LOGO_H))
