#!/usr/bin/env python3
"""
mkgfx.py - builds the static PCG library and lookup tables for the
Microbee Premium Plus road engine ("PCG strip engine").

Output: build/gfx.inc (assembler source with DB/DW data + EQUs)
        build/pcg.bin (raw PCG character data, 16 bytes per character,
                       character index i lives in PCG bank i>>7, code 0x80|(i&127))

Screen model: 64x16 cells of 8x16 pixels (CRTC R9=15).  The engine works in
"chunky" logical pixels of 2x2 screen pixels, so a cell is 4x8 logical pixels
and the playfield is 256x128 logical pixels (square pixels on a 4:3 monitor).
"""
import os, math, struct, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else 'build'
os.makedirs(OUT, exist_ok=True)

# ------------------------------------------------------------------ engine constants
NSEG = 20          # projected points ahead (1 segment apart up to 12, then 2) -> 28 segments
HY = 50            # horizon line (logical) for flat ground
F = 128            # focal length
CAMH = 154         # camera height (world units): CAMH*F/256 = 127-HY
RW = 200           # road half width (world units)
SEGLEN = 256

# ------------------------------------------------------------------ PCG allocator
pcg = []           # list of 16-byte tuples
pcg_index = {}

def alloc(data16, dedupe=True):
    t = tuple(data16)
    assert len(t) == 16
    if dedupe and t in pcg_index:
        return pcg_index[t]
    pcg.append(t)
    i = len(pcg) - 1
    if dedupe:
        pcg_index[t] = i
    return i

def reserve(n):
    base = len(pcg)
    for _ in range(n):
        pcg.append(tuple([0] * 16))
    return base

def dbl(lines8):
    """8 logical lines -> 16 scanline bytes"""
    out = []
    for b in lines8:
        out += [b, b]
    return out

def expand4(bits4):
    """4 logical pixels (bit3 = leftmost) -> screen byte (2 px each)"""
    v = 0
    for i in range(4):
        if bits4 & (8 >> i):
            v |= 0xC0 >> (2 * i)
    return v

def code_attr(i):
    return (0x80 | (i & 127), i >> 7)

# fixed characters ---------------------------------------------------------
# Bank 0 holds everything the road rows use, so road cells never need an
# attribute change: 15 stripe chars (rows 1..15, rewritten in vblank),
# FULL, 9 horizon masks and the edge library.
IDX_STRIPE = reserve(15)
IDX_FULL = alloc([0xFF] * 16, dedupe=False)
pcg_index[tuple([0xFF] * 16)] = IDX_FULL
IDX_HMASK = len(pcg)
for k in range(9):
    pcg.append(tuple(dbl([0 if l < k else 0xFF for l in range(8)])))
# edge library: boundary at logical x; pixel p (0..3) set iff p >= v,
# v = o + floor((s*l+1)/2), s in half logical pixels per line (-8..8)
SLOPES = list(range(-8, 9))
edge_tables = []
for sq in SLOPES:
    rng = []
    for o in range(-80, 12):
        pat = []
        for l in range(8):
            v = o + math.floor((sq * l + 1) / 2)
            bits = 0
            for p_ in range(4):
                if p_ >= v:
                    bits |= 8 >> p_
            pat.append(expand4(bits))
        rng.append((o, pat))
    def triv(p): return all(b == 0xFF for b in p) or all(b == 0 for b in p)
    nz = [o for o, p in rng if not triv(p)]
    lo, hi = min(nz), max(nz)
    ent = []
    for o, p in rng:
        if lo <= o <= hi:
            if all(b == 0xFF for b in p): ent.append(('FULL', None))
            elif all(b == 0 for b in p): ent.append(('EMPTY', None))
            else: ent.append(('CH', alloc(dbl(p))))
    edge_tables.append((sq, lo, hi, ent))
n_edge_chars = len(pcg)
assert len(pcg) <= 128, 'bank 0 overflow: %d' % len(pcg)
reserve(128 - len(pcg))
# HUD font ------------------------------------------------------------------
FONT = {
 '0': ['.##.', '#..#', '#.##', '##.#', '#..#', '#..#', '.##.'],
 '1': ['.#..', '##..', '.#..', '.#..', '.#..', '.#..', '###.'],
 '2': ['.##.', '#..#', '...#', '..#.', '.#..', '#...', '####'],
 '3': ['###.', '...#', '...#', '.##.', '...#', '...#', '###.'],
 '4': ['..#.', '.##.', '#.#.', '#.#.', '####', '..#.', '..#.'],
 '5': ['####', '#...', '###.', '...#', '...#', '#..#', '.##.'],
 '6': ['.##.', '#...', '#...', '###.', '#..#', '#..#', '.##.'],
 '7': ['####', '...#', '..#.', '..#.', '.#..', '.#..', '.#..'],
 '8': ['.##.', '#..#', '#..#', '.##.', '#..#', '#..#', '.##.'],
 '9': ['.##.', '#..#', '#..#', '.###', '...#', '...#', '.##.'],
 'A': ['.##.', '#..#', '#..#', '####', '#..#', '#..#', '#..#'],
 'B': ['###.', '#..#', '#..#', '###.', '#..#', '#..#', '###.'],
 'C': ['.##.', '#..#', '#...', '#...', '#...', '#..#', '.##.'],
 'D': ['###.', '#..#', '#..#', '#..#', '#..#', '#..#', '###.'],
 'E': ['####', '#...', '#...', '###.', '#...', '#...', '####'],
 'F': ['####', '#...', '#...', '###.', '#...', '#...', '#...'],
 'G': ['.##.', '#..#', '#...', '#.##', '#..#', '#..#', '.###'],
 'H': ['#..#', '#..#', '#..#', '####', '#..#', '#..#', '#..#'],
 'I': ['###.', '.#..', '.#..', '.#..', '.#..', '.#..', '###.'],
 'K': ['#..#', '#.#.', '##..', '##..', '#.#.', '#..#', '#..#'],
 'L': ['#...', '#...', '#...', '#...', '#...', '#...', '####'],
 'M': ['#..#', '####', '####', '#..#', '#..#', '#..#', '#..#'],
 'N': ['#..#', '##.#', '##.#', '#.##', '#.##', '#..#', '#..#'],
 'O': ['.##.', '#..#', '#..#', '#..#', '#..#', '#..#', '.##.'],
 'P': ['###.', '#..#', '#..#', '###.', '#...', '#...', '#...'],
 'R': ['###.', '#..#', '#..#', '###.', '#.#.', '#..#', '#..#'],
 'S': ['.###', '#...', '#...', '.##.', '...#', '...#', '###.'],
 'T': ['###.', '.#..', '.#..', '.#..', '.#..', '.#..', '.#..'],
 'U': ['#..#', '#..#', '#..#', '#..#', '#..#', '#..#', '.##.'],
 'V': ['#..#', '#..#', '#..#', '#..#', '#..#', '.##.', '.##.'],
 'W': ['#..#', '#..#', '#..#', '#..#', '####', '####', '#..#'],
 'Y': ['#.#.', '#.#.', '#.#.', '.#..', '.#..', '.#..', '.#..'],
 'Z': ['####', '...#', '..#.', '.#..', '#...', '#...', '####'],
 'X': ['#..#', '#..#', '.##.', '.##.', '.##.', '#..#', '#..#'],
 '=': ['....', '....', '####', '....', '####', '....', '....'],
 '(': ['..#.', '.#..', '.#..', '.#..', '.#..', '.#..', '..#.'],
 ')': ['.#..', '..#.', '..#.', '..#.', '..#.', '..#.', '.#..'],
 ':': ['....', '.#..', '.#..', '....', '.#..', '.#..', '....'],
 '.': ['....', '....', '....', '....', '....', '.#..', '.#..'],
 '-': ['....', '....', '....', '###.', '....', '....', '....'],
 '/': ['...#', '...#', '..#.', '.#..', '.#..', '#...', '#...'],
}
font_idx = {}
for ch, rows in FONT.items():
    lines = [0] + [expand4(int(r.replace('#', '1').replace('.', '0'), 2)) for r in rows]
    font_idx[ch] = alloc(dbl(lines))
font_idx[' '] = None   # use ROM space 0x20

# ------------------------------------------------------------------ sky + panorama
# sky gradient rows use dither chars between two colours
DITHER = {}
for name, pat in (('d25', [0x88, 0x00, 0x22, 0x00]), ('d50', [0xAA, 0x55]), ('d75', [0x77, 0xFF, 0xDD, 0xFF])):
    lines = [pat[i % len(pat)] for i in range(16)]
    DITHER[name] = alloc(lines)

# panorama: 256 logical px loop, 16 logical lines (2 cell rows), 4 sub-cell shifts
def mountain_height(x):
    t = x / 256.0 * 2 * math.pi
    h = 6.5 + 3.2 * math.sin(t * 3 + 0.7) + 2.1 * math.sin(t * 7 + 2.0) + 1.3 * math.sin(t * 13 + 0.3) \
        + 0.8 * math.sin(t * 23 + 1.1)
    return max(1, min(15, int(round(h))))
H = [mountain_height(x) for x in range(256)]
pano = []    # pano[shift][row][cell] -> pcg index (or 'SKY'/'SOLID')
for shift in range(4):
    rows = []
    for row in range(2):
        cells = []
        for c in range(64):
            lines = []
            for l in range(8):
                y = row * 8 + l          # 0 = top
                bits = 0
                for p in range(4):
                    x = (c * 4 + p + shift) % 256
                    if y >= 16 - H[x]:
                        bits |= 8 >> p
                lines.append(expand4(bits))
            if all(b == 0 for b in lines): cells.append(('EMPTY', None))
            elif all(b == 0xFF for b in lines): cells.append(('FULL', None))
            else: cells.append(('CH', alloc(dbl(lines))))
        rows.append(cells)
    pano.append(rows)

# ------------------------------------------------------------------ player car
CAR = [
 "............KKKKKKKKKKKKKKKK............",
 ".........KKKKKKKKKKKKKKKKKKKKKK.........",
 ".......KKKKKKKKKKKKKKKKKKKKKKKKKK.......",
 "......KKKKKKKKKKKKKKKKKKKKKKKKKKKK......",
 ".....KKKKKKKKKKKKKKKKKKKKKKKKKKKKKK.....",
 "....KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK....",
 "...KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK...",
 "..KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK..",
 ".KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK.",
 ".KKKKKKKRRRRRRRRKKKKKKKKRRRRRRRRKKKKKKK.",
 "KKKKKKKKRRRRRRRRKKKKKKKKRRRRRRRRKKKKKKKK",
 "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
 "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
 "KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK",
 ".KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK.",
 "..KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK..",
 "...KKKKKKK....................KKKKKKK...",
 "...KKKKKKK....................KKKKKKK...",
 "........................................",
 "........................................",
 "........................................",
 "........................................",
 "........................................",
 "........................................",
]
COLS = {'K': 0, 'R': 9, 'r': 1, 'Y': 11, 'W': 15, 'G': 8, 'P': 13}

def shift_rows(art, top_shift):
    out = []
    n = len(art)
    for y, row in enumerate(art):
        s = int(round(top_shift * max(0, (12 - y)) / 12))
        if s > 0: row = '.' * s + row[:-s]
        elif s < 0: row = row[-s:] + '.' * (-s)
        out.append(row)
    return out

def convert_sprite(art, W, Hh):
    """returns list of cells: (pcg_idx or None, fg, bg or None[=transparent->dynamic])"""
    cw, ch = W // 4, Hh // 8
    cells = []
    for cy in range(ch):
        for cx in range(cw):
            px = [[art[cy * 8 + l][cx * 4 + p] for p in range(4)] for l in range(8)]
            flat = [c for r in px for c in r]
            cnt = {}
            for c in flat: cnt[c] = cnt.get(c, 0) + 1
            if set(cnt) == {'.'}:
                cells.append(None); continue
            inks = sorted([c for c in cnt if c != '.'], key=lambda c: -cnt[c])
            if '.' in cnt:
                fgc, bgc = inks[0], None       # transparent bg
            elif len(inks) == 1:
                fgc, bgc = inks[0], inks[0]
            else:
                fgc, bgc = inks[1], inks[0]
            lines = []
            for l in range(8):
                bits = 0
                for p in range(4):
                    c = px[l][p]
                    if c == '.' or c == bgc: continue
                    if c == fgc or bgc is None or True:
                        # nearest assignment: anything not bg becomes fg
                        bits |= 8 >> p
                lines.append(expand4(bits))
            idx = alloc(dbl(lines))
            cells.append((idx, COLS[fgc], None if bgc is None else COLS[bgc]))
    return cells

car_poses = [convert_sprite(shift_rows(CAR, s), 40, 24) for s in (-2, 0, 2)]

print('PCG characters used: %d of 2048 (bank 0 road set %d/128)' % (len(pcg), n_edge_chars), file=sys.stderr)
assert len(pcg) <= 2048 - 0

# ------------------------------------------------------------------ track
# 256 segments: curve (signed, X accel per segment) and height (world units)
curve = [0] * 256
hill = [0.0] * 256
def put_curve(a, b, c):
    for i in range(a, b): curve[i % 256] = c
put_curve(20, 60, 18); put_curve(70, 100, -24); put_curve(120, 140, 30)
put_curve(150, 190, -14); put_curve(200, 230, 22)
# smooth height profile (looping)
for i in range(256):
    t = i / 256 * 2 * math.pi
    hill[i] = 260 * math.sin(t * 2) + 140 * math.sin(t * 5 + 1.0)
ty = [int(round(h)) for h in hill]

# ------------------------------------------------------------------ tables
PK = [0] + [p if p <= 12 else 12 + 2 * (p - 12) for p in range(1, NSEG + 1)]
INV = []
HWT = []
for p_ in range(NSEG + 1):
    k = PK[p_]
    for fq in range(32):
        z = SEGLEN * k - fq * 8
        z = max(z, 40)
        v = min(65535, int(round(F * 16384 / z)))
        INV.append(v)
        HWT.append(min(32767, int(round(RW * F / z))))

# ------------------------------------------------------------------ emit
L = []
def db(vals, per=16):
    for i in range(0, len(vals), per):
        L.append('        db ' + ','.join(str(v & 255) for v in vals[i:i + per]))
def dw(vals, per=8):
    for i in range(0, len(vals), per):
        L.append('        dw ' + ','.join(str(v & 0xffff) for v in vals[i:i + per]))

L.append('; generated by mkgfx.py - do not edit')
for k, v in (('NSEG', NSEG), ('HY', HY), ('CAMH', CAMH), ('RW', RW), ('PCG_COUNT', len(pcg)),
             ('IDX_FULL', IDX_FULL), ('PCG_BANKS', (len(pcg) + 127) // 128), ('IDX_HMASK', IDX_HMASK), ('IDX_STRIPE', IDX_STRIPE)):
    L.append('%-12s equ %d' % (k, v))
fc, fa = code_attr(IDX_FULL)
L.append('FULL_CODE    equ %d' % fc); L.append('FULL_ATTR    equ %d' % fa)

# edge table: per slope: dw entries_ptr ; db omin, omax   (4 bytes, index = slope+16)
L.append('EDGE_DIR:')
for sq, lo, hi, ent in edge_tables:
    L.append('        dw EDGE_%d' % (sq + 16))
    L.append('        db %d,%d' % (lo & 255, (hi - lo + 1) & 255))
for sq, lo, hi, ent in edge_tables:
    L.append('EDGE_%d:' % (sq + 16))
    vals = []
    for kind, i in ent:
        if kind == 'FULL': vals.append(fc)
        elif kind == 'EMPTY': vals.append(0x20)
        else:
            assert i < 128
            vals.append(code_attr(i)[0])
    db(vals)

# HUD font map: ascii 32..95 -> code, attr
L.append('FONTMAP:')
vals = []
for a in range(32, 96):
    i = font_idx.get(chr(a))
    if i is None: vals += [0x20, 0]
    else: vals += list(code_attr(i))
db(vals)

# dither chars
for name, i in DITHER.items():
    c, a = code_attr(i)
    L.append('%s_CODE equ %d' % (name.upper(), c)); L.append('%s_ATTR equ %d' % (name.upper(), a))

# panorama: 4 shifts x 2 rows x 64 cells x (code, attr)
# PANOC/PANOA: [shift][row][128] codes / attributes (64-cell loop stored twice)
for nm, sel in (('PANOC', 0), ('PANOA', 1)):
    L.append(nm + ':')
    for shift in range(4):
        for row in range(2):
            vals = []
            for kind, i in pano[shift][row]:
                if kind == 'EMPTY': vals.append((0x20, 0)[sel])
                elif kind == 'FULL': vals.append((fc, fa)[sel])
                else: vals.append(code_attr(i)[sel])
            db(vals + vals)

# car: 3 poses x 30 cells: code, attr, fg, bg(255 = transparent)
L.append('CARDATA:')
for pose in car_poses:
    vals = []
    for cell in pose:
        if cell is None: vals += [0, 0, 0, 254]          # 254 = empty cell (leave road)
        else:
            i, fg, bg = cell
            c, a = code_attr(i)
            vals += [c, a, fg, 255 if bg is None else bg]
    db(vals)

# slope table: d = x7-x0 in -32..32 -> clamp(round(d*4/7)) + 16
L.append('SLOPETAB:'); db([max(-8, min(8, int(math.floor(d / 4 + 0.5)))) + 8 for d in range(-32, 33)])
L.append('PSTEP:'); db([0] + [PK[i] - PK[i - 1] for i in range(1, NSEG + 1)])
L.append('TRK_CURVE:'); db(curve)
L.append('TRK_YL:'); db([v & 255 for v in ty])
L.append('TRK_YH:'); db([(v >> 8) & 255 for v in ty])
L.append('        align 256')
L.append('SQL:'); db([(n * n // 4) & 255 for n in range(512)])
L.append('SQH:'); db([(n * n // 4) >> 8 for n in range(512)])
L.append('INVL:'); db([v & 255 for v in INV])
L.append('INVH:'); db([v >> 8 for v in INV])
# mantissa/shift form of INV: inv ~= m << s, store m and r = 14 - s
INVM = []; INVR = []
for v in INV:
    s_ = max(0, v.bit_length() - 8)
    INVM.append(v >> s_); INVR.append(14 - s_)
L.append('INVM:'); db(INVM)
L.append('INVR:'); db(INVR)
L.append('HWTL:'); db([v & 255 for v in HWT])
L.append('HWTH:'); db([v >> 8 for v in HWT])

open(os.path.join(OUT, 'fill.inc'), 'w').write(''.join('        ld (hl),a\n        inc l\n' for _ in range(64)))
open(os.path.join(OUT, 'gfx.inc'), 'w').write('\n'.join(L) + '\n')
with open(os.path.join(OUT, 'pcg.bin'), 'wb') as f:
    for ch in pcg: f.write(bytes(ch))
    pad = (-len(pcg)) % 128
    f.write(bytes(16 * pad))
print('wrote %s/gfx.inc, pcg.bin (%d bytes)' % (OUT, len(pcg) * 16), file=sys.stderr)
