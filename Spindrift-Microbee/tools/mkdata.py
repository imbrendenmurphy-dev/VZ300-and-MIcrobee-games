"""SPINDRIFT: build the data blocks and the generated include.

  build/TAB.BNK  (block 4): polar position table, row pointers, size
                 classes, font, star glyphs, ship / shots / bullets
  build/ENM.BNK  (block 5): enemies (9 kinds x 2 frames x 6 depth sizes),
                 explosions, score popups, the Guardian's core
  build/PIC.BNK  (block 6): the SPINDRIFT logo (glyphs + cell map)
  src/gen.inc    : record tables and addresses
"""
import math
import os
import sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import art
import font70

BUILD = os.path.join(ROOT, 'build')
os.makedirs(BUILD, exist_ok=True)

POSTAB = 0x0000
ROWPTR = 0x4200
SIZECLS = 0x4300
FONT = 0x4400
STARG = 0x4700
SPR0 = 0x4800
CORE_PAT = 0x2000             # in PIC.BNK
DX136 = 0x3000                # in PIC.BNK, after the core


# ------------------------------------------------------------------ font
FONT_ORDER = [chr(c) for c in range(32, 96)]
KEEP = [0, 1, 3, 4, 5, 7, 8]          # the 9-row skeletons squeezed to 7 rows


def font_glyph(ch):
    rows = font70.S.get(ch, font70.S[' '])
    g = [0] * 8
    for oy, sy in enumerate(KEEP):
        r = rows[sy]
        lit = 0
        if len(r) == 7:
            for x, c in enumerate(r):
                if c in '#@+':
                    lit |= 0x80 >> x
        else:
            for x, c in enumerate(r):
                if c in '#@+':
                    lit |= 0x80 >> (x + 1)
                    if c == '@' or (x == 0 and sy >= 4 and c == '#'):
                        lit |= 0x80 >> x            # the doubled lower-left stroke
        g[oy] = lit
    return g


def icons():
    """bank 0 glyphs 64..: HUD icons"""
    def bm(rows):
        g = []
        for r in rows:
            b = 0
            for x, c in enumerate(r):
                if c == '#':
                    b |= 0x80 >> x
            g.append(b)
        return g
    return [
        bm(['...##...', '...##...', '..#..#..', '..####..', '.######.', '##.##.##', '#..##..#', '........']),  # 64 life
        bm(['........', '.######.', '.######.', '.######.', '.######.', '.######.', '.######.', '........']),  # 65 pip full
        bm(['........', '.######.', '.#....#.', '.#....#.', '.#....#.', '.#....#.', '.######.', '........']),  # 66 pip empty
        bm(['........', '........', '........', '########', '########', '........', '........', '........']),  # 67 bar
        bm(['#.......', '##......', '###.....', '####....', '###.....', '##......', '#.......', '........']),  # 68 arrow
        bm(['........', '..####..', '.#....#.', '.#.##.#.', '.#.##.#.', '.#....#.', '..####..', '........']),  # 69 boss eye
    ]


# ------------------------------------------------------------------ logo
def logo():
    """SPINDRIFT in the 70s skeleton, four times over, slanted, with speed
    stripes through its lower half. Returns a bitmap and a colour per
    cell row."""
    word = 'SPINDRIFT'
    SX, SY = 4, 4
    cols = []
    for ch in word:
        rows = font70.S[ch]
        w = 7 if len(rows[0]) == 7 else 6
        if ch == 'I':
            rows = [r[1:4] for r in rows]
            w = 3
        bm = np.zeros((9, w + 1), bool)
        for y, r in enumerate(rows):
            for x, c in enumerate(r):
                if c in '#@+':
                    bm[y, x + (0 if len(r) in (3, 7) else 1)] = True
                    if x == 0 and y >= 4 and len(r) == 6:
                        bm[y, x] = True
        cols.append(bm)
    big = np.concatenate([np.pad(b, ((0, 0), (0, 1))) for b in cols], axis=1)
    big = np.kron(big, np.ones((SY, SX), bool))
    h, w = big.shape
    out = np.zeros((h, w + 12), bool)
    for y in range(h):
        sh = (h - 1 - y) // 4          # slant to the right
        out[y, sh:sh + w] = big[y]
    for y in range(h):
        if y >= 18 and (y - 18) % 4 == 3:
            out[y] = False             # speed stripes
    return out


# ------------------------------------------------------------------ sprites
def dims(s):
    return art.dims(s)


def build():
    tab = art.Bank(0)
    # polar table: dx, dy for radius index 0..127, s 0..64
    for ri in range(128):
        f = art.radius_frac(ri)
        for s in range(65):
            t = s * 2 * math.pi / 256
            dx = int(round(art.RX * f * math.sin(t)))
            dy = int(round(art.RY * f * math.cos(t)))
            tab.d += bytes([min(255, dx), min(255, dy)])
    assert len(tab.d) == 128 * 130
    tab.d += bytes(ROWPTR - len(tab.d))
    for ri in range(128):
        a = POSTAB + ri * 130
        tab.d += bytes([a & 255, a >> 8])
    assert len(tab.d) == SIZECLS
    tab.d += bytes([art.size_class(ri) for ri in range(128)])
    tab.d += bytes(FONT - len(tab.d))
    for ch in FONT_ORDER:
        tab.d += bytes(font_glyph(ch))
    for g in icons():
        tab.d += bytes(g)
    nfont = 64 + len(icons())
    tab.d += bytes(STARG - len(tab.d))
    # star glyphs: 0 blank, then a dot at (x 0,2,4,6) x (line 0,2,4,6)
    tab.d += bytes(8)
    for yy in range(4):
        for xx in range(4):
            g = [0] * 8
            g[yy * 2 + 1] = 0x80 >> (xx * 2 + 1)
            tab.d += bytes(g)
    tab.d += bytes(SPR0 - len(tab.d))

    recs = {}
    sheet = []
    # the ship: 32 headings
    recs['ship'] = []
    for k in range(32):
        bm, _, _ = art.ship_frame(k * 8)
        recs['ship'].append(tab.family('ship%d' % k, bm))
        sheet.append(('', bm))
    # player shots: near, middle, far
    recs['shot'] = []
    for s in (7, 5, 3):
        bm = art.raster(art.s_pshot, 2 if s > 3 else 1, s)
        recs['shot'].append(tab.family('shot%d' % s, bm))
        sheet.append(('', bm))
    # enemy bullets: three sizes, two frames
    recs['bul'] = []
    for s in (3, 5, 7):
        for f in (0, 1):
            w, h = dims(s)
            bm = art.raster(art.s_ebul, w, h, f)
            recs['bul'].append(tab.family('bul%d%d' % (s, f), bm))
            sheet.append(('', bm))
    assert len(tab.d) <= 0x8000, hex(len(tab.d))
    print('TAB.BNK %d bytes' % len(tab.d))

    enm = art.Bank(0)
    recs['enm'] = []
    for t, fn in enumerate(art.ENEMIES):
        for f in (0, 1):
            for s in art.SIZES:
                w, h = dims(s)
                bm = art.raster(fn, w, h, f)
                recs['enm'].append(enm.family('e%d%d%d' % (t, f, s), bm))
                sheet.append(('', bm))
    # explosions: four frames, three sizes
    recs['boom'] = []
    for f in range(4):
        for s in (7, 11, 16):
            w, h = dims(s)
            bm = art.raster(art.x_boom, w, h, f)
            recs['boom'].append(enm.family('boom%d%d' % (f, s), bm))
            sheet.append(('', bm))
    # score popups in a tiny 3 x 5 font
    TINY = {'0': ['###', '#.#', '#.#', '#.#', '###'], '1': ['.#.', '##.', '.#.', '.#.', '###'],
            '2': ['##.', '..#', '.#.', '#..', '###'], '3': ['##.', '..#', '.#.', '..#', '##.'],
            '4': ['#.#', '#.#', '###', '..#', '..#'], '5': ['###', '#..', '##.', '..#', '##.'],
            '6': ['.##', '#..', '###', '#.#', '###'], '7': ['###', '..#', '.#.', '.#.', '.#.'],
            '8': ['###', '#.#', '###', '#.#', '###'], '9': ['###', '#.#', '###', '..#', '##.'],
            'x': ['...', '#.#', '.#.', '#.#', '...']}
    POPS = ['100', '200', '300', '400', '500', '800', '1000', '1500', '2000', '3000', '5000', '10000', 'x2']
    recs['pop'] = []
    for p in POPS:
        w = len(p) * 4 - 1
        bm = np.zeros((5, w), bool)
        for i, c in enumerate(p):
            for y, r in enumerate(TINY[c]):
                for x, cc in enumerate(r):
                    if cc == '#':
                        bm[y, i * 4 + x] = True
        recs['pop'].append(enm.family('pop' + p, bm))
        sheet.append(('', bm))
    recs['core'] = []
    for f in range(3):
        bm = art.raster(art.core_shape, 26, 32, f)
        recs['core'].append(enm.family('core%d' % f, bm))
        sheet.append(('', bm))
    assert len(enm.d) <= 0x8000, hex(len(enm.d))
    print('ENM.BNK %d bytes' % len(enm.d))

    # logo
    lb = logo()
    h, w = lb.shape
    H = (h + 7) // 8 * 8
    W = (w + 7) // 8 * 8
    pad = np.zeros((H, W), bool)
    pad[:h, :w] = lb
    glyphs = {b'\0' * 8: 0}
    pats = [bytes(8)]
    cmap = []
    for r in range(H // 8):
        row = []
        for c in range(W // 8):
            cell = np.packbits(pad[r * 8:r * 8 + 8, c * 8:c * 8 + 8], axis=1)[:, 0].tobytes()
            if cell not in glyphs:
                glyphs[cell] = len(pats)
                pats.append(cell)
            row.append(glyphs[cell])
        cmap.append(row)
    pic = bytearray(b''.join(pats))
    assert len(pats) <= 256
    pic += bytes(0x1000 - len(pic))
    for row in cmap:
        pic += bytes(row)
    # the Guardian's core: drawn where draw_spr would put a 26 x 32 sprite
    # centred on the vanishing point, cut into its 4 x 5 cells at column
    # 18, row 10 (pixel 144, 80): 20 glyphs a face, three faces
    pic += bytes(CORE_PAT - len(pic))
    for f in range(3):
        bm = art.raster(art.core_shape, 26, 32, f)
        box = np.zeros((40, 32), bool)
        ox, oy = (160 - 26 // 2) - 144, (100 - 32 // 2) - 80
        box[oy:oy + 32, ox:ox + 26] = bm
        for r in range(5):
            for c in range(4):
                pic += np.packbits(box[r * 8:r * 8 + 8, c * 8:c * 8 + 8], axis=1)[:, 0].tobytes()
    # the pristine dx column of the position table (a 136-pixel orbit):
    # src/shape.asm rescales the live table from it
    assert len(pic) <= DX136
    pic += bytes(DX136 - len(pic))
    for ri in range(128):
        f = art.radius_frac(ri)
        for s in range(65):
            pic.append(min(255, int(round(136.0 * f * math.sin(s * 2 * math.pi / 256)))))
    print('logo: %d x %d cells, %d glyphs' % (W // 8, H // 8, len(pats)))

    open(os.path.join(BUILD, 'TAB.BNK'), 'wb').write(bytes(tab.d))
    open(os.path.join(BUILD, 'ENM.BNK'), 'wb').write(bytes(enm.d))
    open(os.path.join(BUILD, 'PIC.BNK'), 'wb').write(bytes(pic))

    L = ['; generated by tools/mkdata.py - do not edit',
         'ROWPTR      EQU $%04X' % ROWPTR, 'SIZECLS     EQU $%04X' % SIZECLS,
         'FONTPAT     EQU $%04X' % FONT, 'NFONT       EQU %d' % nfont, 'STARPAT     EQU $%04X' % STARG,
         'LOGO_W      EQU %d' % (W // 8), 'LOGO_H      EQU %d' % (H // 8), 'LOGO_NG     EQU %d' % len(pats),
         'LOGO_MAP    EQU $1000', 'CORE_PAT    EQU $%04X' % CORE_PAT, 'DX136       EQU $%04X' % DX136, 'POSTAB      EQU 0', 'NPOP        EQU %d' % len(POPS)]
    for i, p in enumerate(POPS):
        L.append('POP_%s EQU %d' % (p, i))
    for k in ('ship', 'shot', 'bul', 'boom', 'pop', 'enm', 'core'):
        L.append('rec_%s:' % k)
        v = recs[k]
        for i in range(0, len(v), 12):
            L.append('\tdw ' + ','.join('$%04X' % a for a in v[i:i + 12]))
    open(os.path.join(ROOT, 'src', 'gen.inc'), 'w').write('\n'.join(L) + '\n')
    art.sheet(sheet, os.path.join(BUILD, 'sprites.png'), scale=4, cols=24)
    # font proof
    from PIL import Image
    fimg = np.zeros((8 * 4, 8 * 20), np.uint8)
    for i, ch in enumerate(FONT_ORDER[:80]):
        g = font_glyph(ch)
        for y in range(8):
            for x in range(8):
                if g[y] & (0x80 >> x):
                    fimg[(i // 20) * 8 + y, (i % 20) * 8 + x] = 255
    Image.fromarray(fimg).resize((160 * 5, 32 * 4), Image.NEAREST).save(os.path.join(BUILD, 'font.png'))
    Image.fromarray(pad.astype(np.uint8) * 255).resize((W * 3, H * 2 * 1), Image.NEAREST).save(os.path.join(BUILD, 'logo.png'))


def pcgcopy():
    """the unrolled glyph copy: slot k's 8 bytes from POOLBUF + 8k to PCG
    glyph 11h + k, by pops and pushes (112 T a glyph). Blocks run from
    slot 110 down to slot 0; enter at pcg_end - 16 * n."""
    L = ['; generated by tools/mkdata.py: the unrolled PCG copy', 'pcg_top:']
    for k in range(110, -1, -1):
        L += ['\tld sp,$%04X' % (0xD000 + 8 * k), '\tpop bc', '\tpop de', '\tpop hl', '\tpop ix',
              '\tld sp,$%04X' % (0xF800 + (0x11 + k) * 16 + 8), '\tpush ix', '\tpush hl', '\tpush de', '\tpush bc']
    L += ['pcg_end:', '\tld sp,(save_sp)', '\tret']
    open(os.path.join(ROOT, 'src', 'pcgcopy.inc'), 'w').write('\n'.join(L) + '\n')


if __name__ == '__main__':
    build()
    pcgcopy()
