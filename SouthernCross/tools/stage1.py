#!/usr/bin/env python3
"""SOUTHERN CROSS - Stage 1 (Coral Sea) pack: scenery blocks, map, waves, boss art.
Imported by mkassets.py, which writes src/gen/stage1.asm (assembled as the
SCROSS01 segment, loaded from SD into SRAM bank B at $4000).
"""
import math, random
from mkassets import (pack, vnoise, sprite_bytes, flash_variant, G, Y, B, R, CH,
                      PFW, T_DRONE, T_DART, T_BOAT)

T_HORNET = 4
BLK_ROWS = 32
NBLK = 9

def block(kind, seed):
    """32 rows x 96 px; open water at the top and bottom row so blocks join in any order"""
    img = [[B] * PFW for _ in range(BLK_ROWS)]
    rnd = random.Random(seed)
    for y in range(BLK_ROWS):
        env = math.sin(math.pi * (y + 0.5) / BLK_ROWS) ** 0.6       # 0 at the edges
        for x in range(PFW):
            n = (0.6 * vnoise(x / 22.0, y / 12.0, seed, 1 << 20)
                 + 0.3 * vnoise(x / 10.0, y / 6.0, seed + 7, 1 << 20)
                 + 0.1 * vnoise(x / 4.0, y / 3.0, seed + 13, 1 << 20))
            if kind in ('sea', 'jetty'):
                n = n * 0.9 + 0.02
            elif kind == 'left':
                n = n * 0.7 + 0.12 + 0.5 * max(0, 1 - x / 40.0)
            elif kind == 'right':
                n = n * 0.7 + 0.12 + 0.5 * max(0, 1 - (95 - x) / 40.0)
            elif kind == 'both':
                n = n * 0.6 + 0.12 + 0.45 * max(0, 1 - x / 30.0) + 0.45 * max(0, 1 - (95 - x) / 30.0)
            elif kind in ('garden', 'wreck', 'beacon'):
                n = n * 1.0 + 0.13 - 0.12 * math.exp(-((x - 48) / 16.0) ** 2)
            n = 0.3 + (n - 0.3) * env
            if n > 0.70:
                c = Y
                if n > 0.75 and vnoise(x / 3.0, y / 2.0, seed + 33, 1 << 20) > 0.6:
                    c = G
            elif n > 0.645:
                c = G
                if (x + y) % 2 == 0 and vnoise(x / 3.0, y / 1.5, seed + 9, 1 << 20) > 0.62:
                    c = Y
            elif n > 0.60:
                c = G if (x + y) % 2 == 0 else B
            elif n > 0.565:
                c = G if (x % 2 == 0 and y % 2 == 0) else B
            else:
                c = B
                if vnoise(x / 6.0, y / 2.0, seed + 50, 1 << 20) > 0.74 and x % 4 != 3 and 0 < y < 31:
                    c = G if y % 3 == 0 else B
            img[y][x] = c
    def stamp(art, ox, oy):
        for j, row in enumerate(art):
            for i, ch in enumerate(row):
                if ch != '.':
                    img[oy + j][ox + i] = CH[ch]
    if kind == 'wreck':
        stamp(["....yyyy.......",
               "..yyggggyy.....",
               ".yggyyyyggyyy..",
               "yggyrrrryggyyyy",
               ".yggyyyyggyyy..",
               "..yy.g..g......"], 60, 12)
    if kind == 'beacon':
        stamp([".yyyyy.", "yyyryyy", "yyrrryy", "yyyryyy", ".yyyyy."], 14, 13)
    if kind == 'jetty':
        for y in range(4, 28):
            for x in (44, 45, 50, 51):
                img[y][x] = Y
            if y % 3 == 0:
                for x in range(44, 52):
                    img[y][x] = Y
        stamp(["yyyyyyyyyyyyyy", "yrrrrrrrrrrrry", "yyyyyyyyyyyyyy"], 41, 1)
    if kind == 'atoll':
        # boss arena: reef walls on both sides, a lagoon ring pattern in the middle
        for y in range(BLK_ROWS):
            for x in range(PFW):
                d = min(x, 95 - x)
                w = 9 + 3 * math.sin(2 * math.pi * y / BLK_ROWS)
                if d < w - 3:
                    img[y][x] = Y if (x * 7 + y * 3) % 11 else G
                elif d < w:
                    img[y][x] = G if (x + y) % 2 else B
    return img

KINDS = ['sea', 'left', 'right', 'both', 'garden', 'wreck', 'beacon', 'jetty', 'atoll']
BLK = {k: i for i, k in enumerate(KINDS)}

def blocks():
    return [block(k, 100 + 17 * i) for i, k in enumerate(KINDS)]

# ------------------------------------------------------------------ waves
# (delay frames, type, path name, x, count, spacing).  Special types:
#   0 pause, 'CP' checkpoint, 'BOSS' warning then boss
def stage1_waves():
    W = []
    def w(d, t, p, x, n, s): W.append((d, t, p, x, n, s))
    # -- opening: learn to shoot and catch shards
    w(60, T_DRONE, 'PATH_SWOOPR', 8, 5, 7)
    w(110, T_DRONE, 'PATH_SWOOPL', 80, 5, 7)
    w(100, T_DRONE, 'PATH_SINE', 44, 4, 12)
    w(90, T_BOAT, 0, 20, 1, 0)
    w(40, T_DART, 'PATH_DART', 16, 3, 10)
    w(80, T_DRONE, 'PATH_LOOP', 30, 5, 6)
    w(70, T_DRONE, 'PATH_LOOP', 60, 5, 6)
    w(90, T_BOAT, 0, 70, 1, 0)
    w(20, T_DRONE, 'PATH_SWOOPL', 84, 5, 6)
    w(80, T_HORNET, 0, 40, 1, 0)
    w(170, 0, 0, 0, 0, 0)
    # -- checkpoint
    w(10, 'CP', 0, 0, 0, 0)
    w(40, T_DART, 'PATH_DART', 70, 4, 8)
    w(90, T_DRONE, 'PATH_SWOOPR', 4, 6, 6)
    w(30, T_DRONE, 'PATH_SWOOPL', 84, 6, 6)
    w(90, T_BOAT, 0, 40, 1, 0)
    w(10, T_DART, 'PATH_DART', 10, 3, 9)
    w(70, T_DRONE, 'PATH_SINE', 20, 5, 10)
    w(5, T_DRONE, 'PATH_SINE', 66, 5, 10)
    w(110, T_HORNET, 0, 20, 1, 0)
    w(60, T_HORNET, 0, 64, 1, 0)
    w(150, T_BOAT, 0, 14, 1, 0)
    w(10, T_BOAT, 0, 74, 1, 0)
    w(60, T_DRONE, 'PATH_LOOP', 44, 6, 6)
    w(80, T_DART, 'PATH_DART', 40, 5, 7)
    w(120, 0, 0, 0, 0, 0)
    # -- the boss
    w(30, 'CP', 0, 0, 0, 0)
    w(10, 'BOSS', 0, 0, 0, 0)
    return W

def frames_to_boss(W):
    return sum(d for d, *_ in W)

def stage_map(W):
    """block per 32 rows (1 row a frame): scenery that builds towards the atoll"""
    boss_rows = frames_to_boss(W)
    nb = boss_rows // 32 + 2
    rnd = random.Random(42)
    seq = []
    pattern = ['sea', 'left', 'sea', 'garden', 'right', 'sea', 'wreck', 'garden', 'sea',
               'left', 'both', 'sea', 'beacon', 'garden', 'right', 'sea', 'jetty', 'sea']
    i = 0
    while len(seq) < nb - 2:
        seq.append(pattern[i % len(pattern)])
        i += 1
    seq += ['both', 'atoll']
    m = [BLK[k] for k in seq]
    m += [BLK['atoll']] * (256 - len(m))
    return m, len(seq) - 1

# ------------------------------------------------------------------ boss art
BODY_CLOSED = [
    "..........yyyyyyyy..........",
    ".......yyyrrrrrrrryyy.......",
    ".....yyrrryyyyyyyyrrryy.....",
    "...yyrryyyrrrrrrrryyyrryy...",
    "..yrryyrrrrbbbbbbrrrryyrry..",
    ".yrryrrrbbbyyyyyybbbrrryrry.",
    "yrrygrrbbyygggggyybbrrgyrry.",
    "yrrygrrbyygrrrrrgyybrrgyrry.",
    "yrygrrbbyggrryyrrggybbrrgyry",
    "yrygrrbbyggrryyrrggybbrrgyry",
    "yrrygrrbyygrrrrrgyybrrgyrry.",
    "yrrygrrbbyygggggyybbrrgyrry.",
    ".yrryrrrbbbyyyyyybbbrrryrry.",
    "..yrryyrrrrbbbbbbrrrryyrry..",
    "...yyrryyyrrrrrrrryyyrryy...",
    ".....yyrrryyyyyyyyrrryy.....",
    ".......yyyrrrrrrrryyy.......",
    "..........yyyyyyyy..........",
]
def body_open(f):
    rows = [list(r) for r in BODY_CLOSED]
    eye = ["bbbbbb", "byyyyb", "yyrryy", "yryyry", "yryyry", "yyrryy", "byyyyb", "bbbbbb"] if f == 0 else \
          ["bbbbbb", "byyyyb", "yrrrry", "rryyrr", "rryyrr", "yrrrry", "byyyyb", "bbbbbb"]
    # open the shell: the inner ring becomes a glowing core
    for j in range(5, 13):
        for i in range(8, 20):
            rows[j][i] = 'b' if rows[j][i] in 'yg' else rows[j][i]
    for j, r in enumerate(eye):
        for i, ch in enumerate(r):
            rows[5 + j][11 + i] = ch
    return [''.join(r) for r in rows]

POD = ["..r.r..",
       ".ryyyr.",
       "ryyryyr",
       ".yrbry.",
       "ryyryyr",
       ".ryyyr.",
       "..r.r.."]
POD2 = ["...r...",
        ".ryyyr.",
        ".yyryy.",
        "ryrbryr",
        ".yyryy.",
        ".ryyyr.",
        "...r..."]

HORNET0 = ["r.r....r.r",
           "rrryyyyrrr",
           ".rrybbyrr.",
           "..ryyyyr..",
           "...rrrr...",
           "....yy...."]
HORNET1 = ["..........",
           "rrryyyyrrr",
           "rrrybbyrrr",
           "..ryyyyr..",
           "...rrrr...",
           "....yy...."]

def sprites_asm(names_rows, fixed_shifts=None):
    t = []
    for name, rows in names_rows:
        if fixed_shifts and name in fixed_shifts:
            sh_list = fixed_shifts[name]
            h = len(rows); w = max(len(r) for r in rows)
            wb = (w + max(sh_list) + 3) // 4
            ptrs = ['.s%d' % max(v for v in sh_list if v <= s) for s in range(4)]
            t.append('SPR_%s:\n        db %d,%d\n        dw %s\n' % (name.upper(), h, wb, ','.join(ptrs)))
            for s in sh_list:
                _, _, d = sprite_bytes_fixed(rows, s, wb)
                t.append('.s%d:\n' % s)
                for i in range(0, len(d), 16):
                    t.append('        db ' + ','.join('$%02X' % b for b in d[i:i + 16]) + '\n')
            continue
        h, wb, sh = sprite_bytes(rows)
        t.append('SPR_%s:\n        db %d,%d\n        dw .s0,.s1,.s2,.s3\n' % (name.upper(), h, wb))
        for s in range(4):
            t.append('.s%d:\n' % s)
            d = sh[s]
            for i in range(0, len(d), 16):
                t.append('        db ' + ','.join('$%02X' % b for b in d[i:i + 16]) + '\n')
    return ''.join(t)

def sprite_bytes_fixed(rows, s, wb):
    h = len(rows); w = max(len(r) for r in rows)
    d = []
    for r in rows:
        r = r.ljust(w, '.')
        px = ['.'] * s + list(r) + ['.'] * (wb * 4 - s - w)
        for b in range(wb):
            m = g = 0
            for k in range(4):
                ch = px[b * 4 + k]
                m <<= 2; g <<= 2
                if ch == '.':
                    m |= 3
                else:
                    g |= CH[ch]
            d += [m, g]
    return h, wb, d

def gen_stage1():
    W = stage1_waves()
    m, boss_blk = stage_map(W)
    blks = blocks()
    t = []
    t.append('; Stage 1: the Coral Sea - %d blocks, boss at block %d\n' % (len(blks), boss_blk))
    t.append('        db "S",1\nSTG_BLKADDR:\n')
    t.append('        dw ' + ','.join('STG_BLOCKS+%d' % (i * 768) for i in range(NBLK)) + '\n')
    t.append('STG_MAP:\n')
    for i in range(0, 256, 16):
        t.append('        db ' + ','.join('%d' % v for v in m[i:i + 16]) + '\n')
    t.append('STG_WAVES:\n')
    for d, ty, p, x, n, s in W:
        tyv = {'CP': '$FE', 'BOSS': '$FD'}.get(ty, ty)
        pid = PATH_IDS.get(p, 0) if p else 0
        t.append('        db %d,%s,%d,%d,%d,%d\n' % (d, tyv, pid, x, n, s))
    t.append('        db 1,$FF,0,0,0,0\n')
    # boss and stage-1 enemy art
    art = [('body_c', BODY_CLOSED), ('body_o0', body_open(0)), ('body_o1', body_open(1)),
           ('turret0', POD), ('turret1', POD2), ('turretw', flash_variant(POD))]
    t.append(sprites_asm(art, fixed_shifts={'body_c': [0, 2], 'body_o0': [0, 2], 'body_o1': [0, 2]}))
    t.append('STG_BLOCKS:\n')
    for img in blks:
        for y in range(BLK_ROWS):
            row = [pack(img[y][i:i + 4]) for i in range(0, PFW, 4)]
            t.append('        db ' + ','.join('$%02X' % b for b in row) + '\n')
    t.append('STG_END:\n')
    return ''.join(t), m, blks, boss_blk

PATH_IDS = {'PATH_SWOOPR': 0, 'PATH_SWOOPL': 1, 'PATH_SINE': 2, 'PATH_DART': 3, 'PATH_LOOP': 4}

def preview(m, blks, path, n=40):
    from PIL import Image
    pal = [(48, 210, 0), (193, 229, 0), (76, 58, 180), (154, 50, 54)]
    im = Image.new('RGB', (PFW, 32 * n))
    for bi in range(n):
        img = blks[m[n - 1 - bi]]
        for y in range(32):
            for x in range(PFW):
                im.putpixel((x, bi * 32 + y), pal[img[y][x]])
    im.resize((PFW * 2, 32 * n * 3), Image.NEAREST).save(path)
