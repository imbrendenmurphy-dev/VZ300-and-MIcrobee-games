#!/usr/bin/env python3
"""INTERNATIONAL FISTICUFFS! asset packer.

Builds everything the game loads from the SD card:
  FISTCUF1.DAT .. FISTCUF9.DAT   one fighter and that fighter's home stage
  FISTCUF0.DAT                   the fighter-select picture and the world map
and src/gen/roster.asm (frame numbers, file table, names).

A fighter file is the fighter block (see fighters.py) padded to whole 512-byte
sectors, then the stage: 54 rows x 48 bytes (rows 10-63 of a 192-pixel-wide
picture), then the background animation: db count, then count x (dw address,
db value A, db value B) - the bytes that differ between the stage's two
animation phases, in the stage and in its 2-pixel-shifted copy.

Usage: pack.py gen_dir out_dir [preview_dir]
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
import stage as mainst
import worldtour as wt
import fighters as F
from worldtour import Pic

STAGE0 = 0xD000            # where the stage sits in memory (see main.asm)
STAGE2 = STAGE0 + 54 * 48  # its 2-pixel-shifted copy
PATCHMAX = 448
RELIEF = True
NORELIEF = {'bigtop': [(56, 29, 136, 45)]}     # the seating stays plain line work
RELIEF_DARK = {0: 2, 1: 3}     # CSS0: blue shade; CSS1: orange shade
SW = 192


import arenas
STAGES = arenas.STAGES


def copy_pic(P):
    Q = Pic()
    Q.p = [row[:] for row in P.p]
    return Q


def phases(st):
    A = st[4](0)
    B = st[4](1)
    A.__class__ = Pic
    B.__class__ = Pic
    return A, B


def shift2(rows48):
    """the stage moved 2 pixels left, as build_stage2 makes it"""
    out = []
    for r in range(54):
        row = rows48[r * 48:(r + 1) * 48]
        for i in range(47):
            out.append(((row[i] << 4) & 0xF0) | (row[i + 1] >> 4))
        out.append((row[47] << 4) & 0xF0)
    return out


def stage_part(st):
    A, B = phases(st)
    a0 = mainst.to_bytes(A, range(10, 64))
    b0 = mainst.to_bytes(B, range(10, 64))
    a2, b2 = shift2(a0), shift2(b0)
    patch = []
    for base, a, b in ((STAGE0, a0, b0), (STAGE2, a2, b2)):
        for i in range(len(a)):
            if a[i] != b[i]:
                assert i >= 7 * 48, '%s: animation in the still sky rows' % st[0]
                patch.append((base + i, a[i], b[i]))
    blk = [len(patch)]
    for (ad, a, b) in patch:
        blk += [ad & 255, ad >> 8, a, b]
    assert len(blk) <= PATCHMAX, '%s: %d animation bytes is too many' % (st[0], len(patch))
    blk += [0] * (PATCHMAX - len(blk))
    return bytes(a0) + bytes(blk), len(patch), A, B


# ------------------------------------------------------------------ screens
def screen_bytes(P):
    return bytes(mainst.to_bytes(P, range(64)))


def select_screen(frames_by_fighter):
    """8 fighters in a 4 x 2 grid of 32 x 25 cells from row 7"""
    G, Y, B, R = 0, 1, 2, 3
    P = Pic(128)
    P.rect(0, 0, 127, 63, B)
    P.__class__ = Pic
    for i in range(8):
        f, frames = frames_by_fighter[i]
        cx, cy = (i % 4) * 32, 7 + (i // 4) * 25
        P.rect(cx + 2, cy + 1, cx + 29, cy + 17, G)
        fr = frames[F.FR['IDLE']]
        rows = fr['rows'][:16]
        # centre the head and shoulders in the cell
        cols = [c for row in rows for c, v in enumerate(row) if v]
        mid = (min(cols) + max(cols)) // 2
        for r, row in enumerate(rows):
            for c, v in enumerate(row):
                x = cx + 16 + c - mid
                if v in (1, 2) and cx + 2 <= x <= cx + 29:
                    P.put(x, cy + 2 + r, v)
        n = f['name']
        P.text(n, cx + 16 - len(n) * 2, cy + 19, Y)
    return P


CONTINENTS = [
    # (longitude, latitude) outlines, very roughly
    [(-165, 62), (-150, 70), (-125, 70), (-95, 72), (-80, 66), (-62, 58), (-56, 50), (-68, 44), (-76, 35), (-82, 26),
     (-97, 26), (-97, 18), (-88, 15), (-84, 10), (-79, 8), (-90, 16), (-105, 21), (-112, 30), (-123, 38), (-125, 48), (-135, 58), (-150, 59)],
    [(-79, 8), (-62, 10), (-50, 0), (-35, -7), (-40, -22), (-55, -35), (-66, -45), (-70, -54), (-75, -45), (-71, -18), (-80, -5)],
    [(-10, 36), (-9, 43), (0, 46), (-4, 48), (3, 51), (9, 54), (11, 58), (6, 60), (12, 66), (25, 71), (40, 67), (60, 69), (80, 73),
     (105, 77), (140, 73), (170, 68), (178, 64), (162, 58), (156, 50), (142, 46), (140, 40), (128, 35), (122, 30), (120, 22),
     (108, 20), (105, 10), (100, 14), (97, 16), (90, 22), (80, 14), (77, 8), (72, 20), (66, 25), (57, 25), (58, 19),
     (52, 13), (44, 12), (35, 28), (36, 36), (27, 36), (23, 38), (19, 41), (13, 44), (15, 38), (8, 44), (3, 42), (-2, 37)],
    [(-17, 15), (-16, 28), (-6, 36), (10, 37), (20, 32), (33, 31), (37, 20), (43, 11), (51, 11), (41, -3), (40, -15),
     (33, -26), (20, -35), (17, -29), (12, -17), (9, 4), (-5, 5), (-12, 8)],
    [(114, -22), (122, -18), (131, -12), (137, -15), (142, -11), (146, -19), (153, -26), (150, -37), (141, -38), (135, -34), (126, -32), (115, -34)],
    [(-52, 60), (-42, 60), (-22, 70), (-20, 80), (-55, 82), (-70, 77), (-55, 68)],
    [(-24, 64), (-22, 66), (-14, 66), (-14, 64)],
    [(131, 31), (136, 34), (141, 37), (141, 42), (139, 36), (135, 35)],
    [(-5, 50), (1, 52), (-2, 56), (-5, 58), (-6, 54)],
    [(166, -46), (172, -41), (175, -37), (178, -39), (172, -44)],
]


def map_xy(lon, lat):
    return int(round((lon + 170) * 127 / 360.0)), int(round(10 + (78 - lat) * 46 / 136.0))


def map_screen():
    G, Y, B, R = 0, 1, 2, 3
    P = Pic(128)
    P.__class__ = Pic
    P.rect(0, 0, 127, 63, B)
    for poly in CONTINENTS:
        P.poly([map_xy(*p) for p in poly], G)
    # a yellow shoreline on the south and east of the land gives it weight
    for y in range(10, 57):
        for x in range(127):
            if P.get(x, y) == G and P.get(x, y + 1) == B:
                P.put(x, y, Y)
    for st in STAGES[:8]:
        x, y = st[6]
        P.rect(x - 1, y - 1, x + 1, y + 1, R)
        P.put(x, y, Y)
    P.text('WORLD TOUR', 44, 2, Y)
    return P


# ------------------------------------------------------------------ output
def save_png(P, fn, css=0, sx=6, sy=9):
    from PIL import Image
    pal = {0: {0: (0x07, 0xFF, 0x00), 1: (0xFF, 0xFF, 0x00), 2: (0x3B, 0x08, 0xFF), 3: (0xCC, 0x00, 0x3B)},
           1: {0: (0xFF, 0xFF, 0xFF), 1: (0x07, 0xE3, 0x99), 2: (0xFF, 0x1C, 0xFF), 3: (0xFF, 0x81, 0x00)}}[css]
    im = Image.new('RGB', (P.w, 64))
    for y in range(64):
        for x in range(P.w):
            im.putpixel((x, y), pal[P.p[y][x]])
    im.resize((P.w * sx, 64 * sy), Image.NEAREST).save(fn)


def main():
    gen, out = sys.argv[1], sys.argv[2]
    prev = sys.argv[3] if len(sys.argv) > 3 else None
    os.makedirs(out, exist_ok=True)
    built = F.build_all()
    secs = []
    L = ['; generated by tools/pack.py - do not edit', 'NFRAMES equ %d' % len(F.FRAME_NAMES)]
    for i, n in enumerate(F.FRAME_NAMES):
        L.append('FR_%s equ %d' % (n, i))
    L.append('NFIGHTERS equ %d' % len(built))
    L.append('STAGELEN equ %d' % (54 * 48 + PATCHMAX))
    L.append('PATCHLEN equ %d' % PATCHMAX)
    for i, (f, frames, blk) in enumerate(built):
        assert len(blk) <= 10240, f['name']
        n = (len(blk) + 511) // 512
        secs.append(n)
        part, npatch, A, B = stage_part(STAGES[i])
        data = blk + bytes(n * 512 - len(blk)) + part
        open(os.path.join(out, 'FISTCUF%d.DAT' % (i + 1)), 'wb').write(data)
        print('FISTCUF%d.DAT  %-7s %5d bytes (%2d sectors)  %-20s %3d animated bytes' %
              (i + 1, f['name'], len(blk), n, STAGES[i][1], npatch))
        if prev:
            os.makedirs(prev, exist_ok=True)
            save_png(A, os.path.join(prev, 'stage_%d_%s_a.png' % (i + 1, STAGES[i][0])), STAGES[i][3], 5, 7)
            save_png(B, os.path.join(prev, 'stage_%d_%s_b.png' % (i + 1, STAGES[i][0])), STAGES[i][3], 5, 7)
    sel = select_screen([(f, fr) for (f, fr, b) in built])
    mp = map_screen()
    open(os.path.join(out, 'FISTCUF0.DAT'), 'wb').write(screen_bytes(sel) + screen_bytes(mp))
    if prev:
        save_png(sel, os.path.join(prev, 'select.png'))
        save_png(mp, os.path.join(prev, 'map.png'))
    # tables for the program
    open(os.path.join(gen, 'fsecs.asm'), 'w').write('; generated: sectors of fighter data at the start of each file\n        db ' + ','.join(str(s) for s in secs) + '\n')
    L.append('; per stage: palette bit ($00 / $10), shadow pattern, map x, map y')
    L.append('stage_info:')
    for st in STAGES:
        L.append('        db $%02X,$%02X,%d,%d' % (0x10 if st[3] else 0, st[5], st[6][0], st[6][1]))
    L.append('stage_names:')
    for i, st in enumerate(STAGES):
        L.append('        dw sn_%d,sc_%d' % (i, i))
    for i, st in enumerate(STAGES):
        L.append('sn_%d: db "%s",0' % (i, st[1]))
        L.append('sc_%d: db "%s",0' % (i, st[2]))
    L.append('fighter_names:')
    for i, (f, fr, b) in enumerate(built):
        L.append('        dw fn_%d' % i)
    for i, (f, fr, b) in enumerate(built):
        L.append('fn_%d: db "%s",0' % (i, f['name']))
    open(os.path.join(gen, 'roster.asm'), 'w').write('\n'.join(L) + '\n')
    # a moves card for the README
    with open(os.path.join(out, 'MOVES.txt'), 'w') as fh:
        dn = {F.DN: 'DOWN', F.BK: 'BACK', F.FW: 'FORWARD'}
        for (f, fr, b) in built:
            fh.write('%-7s A+B: %-15s DOWN + A+B: %-15s FINISHER: %s, %s, A+B  (%s)\n' %
                     (f['name'], f['specials'][0], f['specials'][1], dn[f['fin'][1]], dn[f['fin'][2]], f['fin'][0]))


if __name__ == '__main__':
    main()
