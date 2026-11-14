#!/usr/bin/env python3
"""RED DUST RUMBLE asset packer.

Builds everything the game loads from the SD card:
  RDRUMBL1.DAT .. RDRUMBL9.DAT   one fighter and that fighter's home stage
  RDRUMBL0.DAT                   the fighter-select picture and the world map
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


# ------------------------------------------------------------------ stage 9
def bigtop():
    """SABLE'S BIG TOP - inside the circus tent at night.  CSS0"""
    G, Y, B, R = 0, 1, 2, 3
    bands = {10: R, 11: Y, 12: Y, 13: Y, 14: Y, 15: Y, 16: R}
    for y in range(17, 28):
        bands[y] = Y
    P = wt.base(bands, ground=Y, edge=(Y, R))
    # the name, on the still band above the canopy (the view shows stage
    # columns 32-159 there, whatever the camera does)
    P.text("SABLE'S BIG TOP", 66, 11, R)
    # the canopy's scalloped valance: red and blue pennants along the top
    for i, x in enumerate(range(0, SW, 12)):
        c = R if i % 2 == 0 else B
        P.poly([(x, 17), (x + 11, 17), (x + 6, 20)], c)
        P.h(x, x + 11, 17, c)
    # king poles and guy ropes
    for x in (40, 151):
        P.v(x, 17, 45, Y); P.v(x + 1, 22, 45, Y)
        P.line(x, 28, x - 14, 45, Y); P.line(x + 1, 28, x + 15, 45, Y)
    # the stands: three rails of spectators, as lines and dots only
    for (x0, x1) in ((60, 132),):
        for y in (33, 38, 43):
            P.h(x0, x1, y, Y)
        for y in (31, 36, 41):
            for x in range(x0 + 3 + (y % 2) * 2, x1 - 1, 5):
                P.put(x, y, Y); P.put(x, y - 1, Y)
    # ring doors at both ends: curtained arches
    for x0 in (2, 166):
        P.outline(x0, 30, x0 + 22, 45, Y)
        P.line(x0 + 1, 31, x0 + 11, 40, Y); P.line(x0 + 21, 31, x0 + 11, 40, Y)
        P.v(x0 + 11, 40, 45, Y)
    # a trapeze, high up
    P.v(96 - 9, 28, 30, Y); P.v(96 + 9, 28, 30, Y); P.h(96 - 9, 96 + 9, 30, Y)
    # the ring: sawdust, the curb, two tubs
    for x in range(0, SW, 16):
        P.h(x + 2, x + 11, 50, R)
    for (x, y) in ((30, 55), (52, 58), (77, 53), (101, 60), (123, 55), (148, 58), (170, 53), (64, 61), (139, 62)):
        P.put(x, y, R); P.put(x + 1, y, R)
    for x0 in (3, 177):
        P.poly([(x0, 62), (x0 + 11, 62), (x0 + 9, 53), (x0 + 2, 53)], R)
        P.h(x0 + 1, x0 + 10, 52, B); P.h(x0 + 1, x0 + 10, 53, B)
        P.h(x0 + 1, x0 + 10, 57, Y)
    return P


# ------------------------------------------------------------------ animation
# Each returns the second phase of a stage (the first is the stage as drawn).
# Everything that moves is small, and sits above head height or is line work.
def flag(P, x, y, c, phase, pole=None, n=6):
    """a small pennant flying to the right of (x, y)"""
    if pole is not None:
        P.v(x, y, y + 6, pole)
    for i in range(1, n + 1):
        dy = (1 if ((i + phase * 2) // 2) % 2 else 0)
        P.put(x + i, y + dy, c)
        P.put(x + i, y + dy + 1, c)
        if i < n - 1:
            P.put(x + i, y + dy + 2, c)


def anim_station(P, ph):
    R, Y, G = 3, 1, 0
    # the windmill by the yards turns
    cx, cy = 150, 31
    P.v(cx, 32, 45, Y)
    P.line(cx - 3, 45, cx, 38, Y); P.line(cx + 3, 45, cx, 38, Y)
    for a in ((0, 90, 180, 270) if ph == 0 else (45, 135, 225, 315)):
        r = math.radians(a)
        for t in (1, 2, 3, 4):
            P.put(cx + int(round(math.cos(r) * t)), cy + int(round(math.sin(r) * t * 0.7)), Y)
    P.put(cx, cy, Y)


def anim_mainst(P, ph):
    R, Y, B = 3, 1, 2
    flag(P, 147, 17, R, ph, n=7)            # the flag over the hotel
    # the saloon lamps wink
    for i, x in enumerate(range(34, 58, 6)):
        P.put(x, 28, Y if (i + ph) % 2 else 0)


def anim_oia(P, ph):
    I1, I2, I3 = 1, 2, 3
    # the sun's reflection breaks up on the sea
    for i, y in enumerate((20, 21, 22, 23)):
        w = 6 - i - (1 if (i + ph) % 2 else 0)
        P.h(96 - 8, 96 + 8, y, I1)
        if w > 0:
            P.h(96 - w, 96 + w, y, I3)
    flag(P, 60, 17, I3, ph, n=5)


def anim_kyoto(P, ph):
    # snow drifts down in front of the temple
    I1 = 1
    for i, (x, y) in enumerate(((7, 30), (23, 36), (41, 31), (58, 40), (74, 33), (88, 29), (103, 38),
                                (117, 31), (133, 41), (148, 34), (160, 30), (175, 38), (186, 33), (96, 44))):
        yy = y + (2 if ph else 0)
        if P.get(x, yy) == 0:
            P.put(x, yy, I1)


def anim_nile(P, ph):
    G, Y, B, R = 0, 1, 2, 3
    # torches on the colonnade flare
    for x in (7, 33, 59):
        P.put(x, 19 - ph, R); P.put(x + 1, 18 + ph, R)
        P.put(x, 20, R); P.put(x + 1, 20, R)
    # moonlight ripples on the river (the far bank line)
    for i, x in enumerate(range(70, 186, 12)):
        if (i + ph) % 2:
            P.h(x, x + 4, 44, Y)


def anim_harbour(P, ph):
    G, Y, B, R = 0, 1, 2, 3
    # the lighthouse lamp turns: the beam swings and the lamp room glints
    if ph == 0:
        P.h(172, 179, 21, Y); P.h(175, 181, 22, Y)
    else:
        P.h(172, 179, 23, Y); P.h(175, 181, 24, Y)
        P.h(160, 163, 20, R); P.h(167, 170, 20, R)
    # mooring lights on the water wink
    for i, x in enumerate((66, 90, 114, 138)):
        if (i + ph) % 2:
            P.put(x, 44, Y); P.put(x + 1, 44, Y)


def anim_mercado(P, ph):
    I1, I2, I3 = 1, 2, 3
    # a string of paper flags across the sky flutters
    for i, x in enumerate(range(20, 176, 10)):
        y = 17 + (1 if 40 < x < 150 else 0)
        c = I2 if i % 2 else I3
        d = (i + ph) % 2
        P.put(x, y, c); P.put(x + 1, y, c); P.put(x + 2, y, c)
        P.put(x + d, y + 1, c); P.put(x + 1 + d, y + 1, c)
        P.put(x + 2 * d, y + 2, c)


def anim_jaipur(P, ph):
    I2, I3 = 2, 3
    flag(P, 20, 17, I3, ph, n=6)
    flag(P, 172, 17, I3, ph + 1, n=6)
    # kites over the palace
    for (x, y, c) in ((84, 19, I2), (112, 18, I3)):
        yy = y + (1 if ph else 0)
        P.put(x, yy, c); P.put(x - 1, yy + 1, c); P.put(x + 1, yy + 1, c); P.put(x, yy + 2, c)


def anim_bigtop(P, ph):
    G, Y, B, R = 0, 1, 2, 3
    # a string of lamps under the valance: alternate ones lit
    for i, x in enumerate(range(6, SW, 12)):
        c = R if (i + ph) % 2 else B
        P.put(x, 22, c); P.put(x, 23, c)
    # the trapeze swings
    P.rect(84, 28, 108, 30, G)
    d = -2 if ph else 2
    P.line(87, 28, 87 + d, 30, Y); P.line(105, 28, 105 + d, 30, Y)
    P.h(87 + d, 105 + d, 30, Y)


#           key        name                   country      css  builder       animation      map x, y
STAGES = [
    ('station', 'NEVER NEVER STATION', 'AUSTRALIA', 0, wt.australia, anim_station, (109, 44)),
    ('mainst',  'MAIN STREET',         'USA',       0, mainst.build, anim_mainst,  (24, 23)),
    ('oia',     'OIA CLIFFS',          'GREECE',    1, wt.greece,    anim_oia,     (70, 23)),
    ('kyoto',   'SNOW TEMPLE',         'JAPAN',     1, wt.japan,     anim_kyoto,   (110, 24)),
    ('nile',    'NILE BY NIGHT',       'EGYPT',     0, wt.egypt,     anim_nile,    (72, 27)),
    ('harbour', 'HARBOUR LIGHTS',      'ICELAND',   0, wt.iceland,   anim_harbour, (54, 13)),
    ('mercado', 'MERCADO',             'MEXICO',    1, wt.mexico,    anim_mercado, (25, 29)),
    ('jaipur',  'PALACE OF WINDS',     'INDIA',     1, wt.india,     anim_jaipur,  (88, 27)),
    ('bigtop',  "SABLE'S BIG TOP",     '???',       0, bigtop,       anim_bigtop,  (47, 40)),
]


def relief(P, dark, skip=(), y0=17, y1=47, minrun=6):
    """Bas-relief: the light comes from the upper left, so every ledge and
    post (a run of line colour at least 'minrun' long) throws a one-pixel dark
    edge below it or to its right.  Dots, lettering and diagonals are left
    alone, so nothing gets noisier - the structure just stands off the wall."""
    w = P.w
    def run_h(x, y):
        a = x
        while a > 0 and P.p[y][a - 1] == 1: a -= 1
        b = x
        while b < w - 1 and P.p[y][b + 1] == 1: b += 1
        return b - a + 1
    def run_v(x, y):
        a = y
        while a > y0 and P.p[a - 1][x] == 1: a -= 1
        b = y
        while b < y1 and P.p[b + 1][x] == 1: b += 1
        return b - a + 1
    def clear(x, y):
        return not (0 <= x < w and y <= y1) or P.p[y][x] != 1
    marks = []
    for y in range(y0, y1 + 1):
        for x in range(w):
            if P.p[y][x] != 1:
                continue
            # only the major edges: long runs that are not part of a group of
            # ruled lines (fences, shutters, seating keep their plain look)
            if y < y1 and P.p[y + 1][x] == 0 and clear(x, y + 2) and clear(x, y + 3) and run_h(x, y) >= 10:
                marks.append((x, y + 1))
            if x < w - 1 and P.p[y][x + 1] == 0 and clear(x + 2, y) and clear(x + 3, y) and clear(x + 4, y) and run_v(x, y) >= 9:
                marks.append((x + 1, y))
    # roofs, awnings and signs (solid colour at least two rows deep) cast a
    # shadow line on the wall beneath them
    for y in range(y0 + 2, y1 + 1):
        for x in range(w):
            if P.p[y][x] == 0 and P.p[y - 1][x] in (2, 3) and P.p[y - 2][x] in (2, 3):
                marks.append((x, y))
    for (x, y) in marks:
        if not any(a <= x <= c and b <= y <= d for (a, b, c, d) in skip):
            P.p[y][x] = dark
    return P


def copy_pic(P):
    Q = Pic()
    Q.p = [row[:] for row in P.p]
    return Q


def phases(st):
    A = st[4]()
    A.__class__ = Pic
    if RELIEF:
        relief(A, RELIEF_DARK[st[3]], NORELIEF.get(st[0], ()))
    B = copy_pic(A)
    st[5](A, 0)
    st[5](B, 1)
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
                if v and cx + 2 <= x <= cx + 29:
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
        open(os.path.join(out, 'RDRUMBL%d.DAT' % (i + 1)), 'wb').write(data)
        print('RDRUMBL%d.DAT  %-7s %5d bytes (%2d sectors)  %-20s %3d animated bytes' %
              (i + 1, f['name'], len(blk), n, STAGES[i][1], npatch))
        if prev:
            os.makedirs(prev, exist_ok=True)
            save_png(A, os.path.join(prev, 'stage_%d_%s_a.png' % (i + 1, STAGES[i][0])), STAGES[i][3], 5, 7)
            save_png(B, os.path.join(prev, 'stage_%d_%s_b.png' % (i + 1, STAGES[i][0])), STAGES[i][3], 5, 7)
    sel = select_screen([(f, fr) for (f, fr, b) in built])
    mp = map_screen()
    open(os.path.join(out, 'RDRUMBL0.DAT'), 'wb').write(screen_bytes(sel) + screen_bytes(mp))
    if prev:
        save_png(sel, os.path.join(prev, 'select.png'))
        save_png(mp, os.path.join(prev, 'map.png'))
    # tables for the program
    open(os.path.join(gen, 'fsecs.asm'), 'w').write('; generated: sectors of fighter data at the start of each file\n        db ' + ','.join(str(s) for s in secs) + '\n')
    L.append('; per stage: palette bit ($00 / $10), shadow pattern, map x, map y')
    L.append('stage_info:')
    for st in STAGES:
        L.append('        db $%02X,$%02X,%d,%d' % (0x10 if st[3] else 0, 0x55 if st[3] else 0x00, st[6][0], st[6][1]))
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
