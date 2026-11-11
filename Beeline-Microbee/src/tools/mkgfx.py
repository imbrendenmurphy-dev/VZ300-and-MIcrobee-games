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
NSEG = 16          # projected points ahead (1 segment apart up to 8, then 2) -> 24 segments
HY = 80            # horizon line (logical): low camera, lots of sky
F = 128            # focal length
CAMH = 94          # camera height (world units): CAMH*F/256 = 127-HY
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

STATIC0 = 9        # static characters live in PCG banks 9..15

def code_attr(i):
    i += STATIC0 * 128
    return (0x80 | (i & 127), i >> 7)

# ------------------------------------------------------------------ road masks
# PCG banks 1-8 are the double-buffered road characters, built every frame
# (page p uses banks 1+4p .. 4+4p, rows 1-4 / 5-8 / 9-12 / 13-15, 32 slots
# per row).  Each road character = for every logical line, the dither
# pattern of the left or right surface, chosen per pixel by an edge mask.
#
# Mask library: 8 bytes per mask, each byte = mval*2 where the line mask is
# one of 00 03 0F 3F FF (mval 0..4; set bits = right-hand surface).
# Boundary at logical x; pixel p (0..3) is right-hand iff p >= v,
# v = o + floor((s*l+1)/2), s in half logical pixels per line (-8..8).
MVAL = {0x00: 0, 0x03: 1, 0x0F: 2, 0x3F: 3, 0xFF: 4}
masks = [tuple([0] * 8), tuple([8] * 8)]       # 0 = all left, 1 = all right
mask_index = {masks[0]: 0, masks[1]: 1}
def mask_id(lines):
    t = tuple(MVAL[b] * 2 for b in lines)
    if t not in mask_index:
        mask_index[t] = len(masks)
        masks.append(t)
    return mask_index[t]

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
    ent = [mask_id(p) for o, p in rng if lo <= o <= hi]
    edge_tables.append((sq, lo, hi, ent))
assert len(masks) * 8 <= 1024
n_edge_chars = len(masks)

# Dither patterns per surface (0 verge, 1 kerb, 2 road) and band phase
# (0 dark, 1 light, 2 above the horizon), two scanlines each.
PATS = [
    [(0x88, 0x22), (0xAA, 0x55), (0x00, 0x00)],     # verge: sparse / checker
    [(0xFF, 0xFF), (0x00, 0x00), (0x00, 0x00)],     # kerb chevrons: inverse of the road
    [(0xAA, 0x55), (0xFF, 0xFF), (0x00, 0x00)],     # road: checker / solid
]
# surface pairs (left, right): 0 V|K 1 K|R 2 R|K 3 K|V 4 V|R 5 R|V
PAIRS = [(0, 1), (1, 2), (2, 1), (1, 0), (0, 2), (2, 0)]
RES = []
for l_, r_ in PAIRS:
    page = []
    for ph in range(3):
        for mv, m in enumerate((0x00, 0x03, 0x0F, 0x3F, 0xFF)):
            for sc in range(2):
                a_ = PATS[l_][ph][sc]; b_ = PATS[r_][ph][sc]
                page.append((a_ & ~m & 0xFF) | (b_ & m))
    RES.append(page)

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

IDX_SOLID = alloc([0xFF] * 16)
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
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mkcar
CAR_FRAMES = mkcar.frames()          # 5 poses, 80x48 screen pixels

def car_ink(c, x, y):
    if c == 'S': return 1 if (x % 2 == 0 and y % 2 == 0) else 0
    if c == 'W': return 1 if (x + y) % 2 == 0 else 0
    if c == 'G': return 1 if (y % 6 == 2 and x % 2 == 0) else 0
    return 0

car_partials = []                     # 32 bytes each: (notmask, ink) x 16
def convert_car(fr):
    """30 cells -> (type, a, b): 0 empty; 1 opaque (code, attr);
    2 opaque with tail light (code, attr); 3 partial (index into car_partials)"""
    cells = []
    for cy in range(3):
        for cx in range(10):
            px = [[fr[cy * 16 + y][cx * 8 + x] for x in range(8)] for y in range(16)]
            flat = [c for r in px for c in r]
            if all(c == '.' for c in flat):
                cells.append((0, 0, 0)); continue
            light = any(c == 'R' for c in flat)
            if light:                  # tail-light cells are made fully opaque
                px = [[('K' if c == '.' else c) for c in r] for r in px]
                flat = [c for r in px for c in r]
            if '.' not in flat:
                scan = []
                for y in range(16):
                    v = 0
                    for x in range(8):
                        c = px[y][x]
                        on = (c == 'R') if light else car_ink(c, cx * 8 + x, cy * 16 + y)
                        if on: v |= 0x80 >> x
                    scan.append(v)
                cd, at = code_attr(alloc(scan))
                cells.append((2 if light else 1, cd, at))
            else:
                data = []
                for y in range(16):
                    nm = ink = 0
                    for x in range(8):
                        c = px[y][x]
                        if c == '.': nm |= 0x80 >> x
                        elif c != 'R' and car_ink(c, cx * 8 + x, cy * 16 + y): ink |= 0x80 >> x
                    data += [nm, ink]
                car_partials.append(data)
                cells.append((3, len(car_partials) - 1, 0))
    return cells

car_poses = [convert_car(f) for f in CAR_FRAMES]

print('static PCG characters: %d (banks %d-%d), road masks %d, car partial cells %d' % (len(pcg), STATIC0, STATIC0 + (len(pcg) - 1) // 128, len(masks), len(car_partials)), file=sys.stderr)
assert len(pcg) <= (16 - STATIC0) * 128

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
PK = [0] + [p if p <= 8 else 8 + 2 * (p - 8) for p in range(1, NSEG + 1)]
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
             ('PCG_BANKS', (len(pcg) + 127) // 128), ('PCG_FIRST', STATIC0)):
    L.append('%-12s equ %d' % (k, v))

# edge tables.  EDGE_DIR (page aligned): 10 bytes per slope:
#   db omin, span ; dw sub0, sub1, sub2, sub3
# sub-table r holds the masks for j = r, r+4, r+8 ... (j = o - omin), so the
# cells along one boundary (j steps by -4) are consecutive bytes, walked down.
L.append('        align 256')
L.append('EDGE_DIR:')
for sq, lo, hi, ent in edge_tables:
    L.append('        db %d,%d' % (lo & 255, (hi - lo + 1) & 255))
    L.append('        dw ' + ','.join('EDGE_%d_%d' % (sq + 16, r) for r in range(4)))
for sq, lo, hi, ent in edge_tables:
    for r in range(4):
        L.append('EDGE_%d_%d:' % (sq + 16, r))
        sub = ent[r::4]
        if sub: db(sub)

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
                elif kind == 'FULL': vals.append(code_attr(IDX_SOLID)[sel])
                else: vals.append(code_attr(i)[sel])
            db(vals + vals)

# car: 5 poses x 30 cells x (type, a, b)
L.append('CARDATA:')
for pose in car_poses:
    db([v for cell in pose for v in cell])
L.append('CARPART:')
for data in car_partials:
    db(data)
# CARROAD: each partial car cell pre-composited over plain road, per line and
# band phase: 64-byte aligned blocks, line l phase p at +l*6+p*2 (2 scanlines)
L.append('        align 64')
L.append('CARROAD:')
for data in car_partials:
    blk = []
    for l in range(8):
        for ph in range(3):
            for sc in range(2):
                nm, ink = data[(l * 2 + sc) * 2], data[(l * 2 + sc) * 2 + 1]
                blk.append((PATS[2][ph][sc] & nm) | ink)
    db(blk + [0] * (64 - len(blk)))

# slope table: d = x7-x0 in -32..32 -> clamp(round(d*4/7)) + 16
L.append('        align 256')
L.append('SLOPETAB:'); db([(max(-8, min(8, int(math.floor(d / 4 + 0.5)))) + 8) * 10 for d in range(-32, 33)])
L.append('PSTEP:'); db([0] + [PK[i] - PK[i - 1] for i in range(1, NSEG + 1)])
L.append('        align 256')
L.append('TRK_CURVE:'); db(curve)
L.append('TRK_YL:'); db([v & 255 for v in ty])
L.append('TRK_YH:'); db([(v >> 8) & 255 for v in ty])
# interleaved: line l of mask i at MASKLIB + 256*l + i  (BC = page:index, inc b)
assert len(masks) <= 256
L.append('        align 256')
L.append('MASKLIB:')
for l in range(8):
    db([m[l] for m in masks] + [0] * (256 - len(masks)))
L.append('        align 256')
L.append('RESPAGES:')
for page in RES:
    db(page)
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
