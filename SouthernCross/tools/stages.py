#!/usr/bin/env python3
"""SOUTHERN CROSS - the six stage packs.

Each pack is assembled at $4000 (SRAM bank B) and starts with a fixed header
the core reads (see the H_ equates in src/main.asm):

  $4000 db "S", stage, colour set ($00/$10), 0
  $4004 dw waves, boss definition, song record, name, boss name, next name
  $4010 dw 13 enemy sprites (the stage's own, or the core's)
  $4030 dw 16 block images
  $4050 db 256 block numbers (the map, one block per 32 rows)
  $4150 ... data

Every label in a pack is prefixed S<n>_ so the six packs can share one
assembly with the core.
"""
import math, random
from mkassets import (pack, vnoise, h2, flash_variant, seq, note_index,
                      G, Y, B, R, CH, PFW, T_DRONE, T_DART, T_BOAT, T_HORNET)
import stage1
from stage1 import sprites_asm, PATH_IDS

BLK_ROWS = 32
PACK_LIMIT = 0x2800           # $4000-$67FF

def env(y):
    return math.sin(math.pi * (y + 0.5) / BLK_ROWS) ** 0.6

def bayer(x, y):
    return [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]][y & 3][x & 3] / 16.0

def stamp(img, art, ox, oy, keep='.'):
    for j, row in enumerate(art):
        for i, ch in enumerate(row):
            if ch != keep and 0 <= oy + j < BLK_ROWS and 0 <= ox + i < PFW:
                img[oy + j][ox + i] = CH[ch]

def new_img(c):
    return [[c] * PFW for _ in range(BLK_ROWS)]

def pnoise(x, y, cx, cy, seed):
    """value noise periodic over the 32-row block (cy must divide 32)"""
    return vnoise(x / cx, y / cy, seed, BLK_ROWS // cy)

# =========================================================================
#  STAGE 2: DAINTREE - rainforest canopy, billabongs, a gorge
# =========================================================================
def daintree_base(x, y):
    n = 0.65 * pnoise(x, y, 7.0, 4, 201) + 0.35 * pnoise(x, y, 3.0, 2, 202)
    if n > 0.62:
        hl = pnoise(x - 1, y - 1, 7.0, 4, 201) - pnoise(x + 1, y + 1, 7.0, 4, 201)
        return Y if hl > 0.05 and (x + y) % 2 == 0 else G
    if n > 0.42:
        return G
    if n > 0.34:
        return G if (x + y) % 2 == 0 else B
    return B

def daintree_block(kind, seed):
    img = new_img(G)
    rnd = random.Random(seed)
    for y in range(BLK_ROWS):
        e = env(y)
        for x in range(PFW):
            c = daintree_base(x, y)
            if kind == 'billabong':
                cx = 48 + 18 * math.sin(2 * math.pi * y / 64 + 1.0)
                w = 13 * e * (0.8 + 0.4 * pnoise(x, y, 6, 4, 210))
                d = abs(x - cx)
                if d < w - 2:
                    c = B if not (rnd.random() < 0.03) else G
                elif d < w:
                    c = Y if (x + y) % 2 else G
            elif kind == 'gorge':
                for side in (x, 95 - x):
                    w = (22 + 6 * pnoise(side, y, 4, 4, 220 + (x > 47))) * e
                    if side < w - 3:
                        c = R if (side * 3 + y * 5) % 9 else Y
                    elif side < w:
                        c = R if (x + y) % 2 else B
                if 40 <= x < 56 and e > 0.3:
                    d = abs(x - 48 - 3 * math.sin(y / 3.0))
                    if d < 7 * e:
                        c = B if (x * 5 + y) % 13 else G
            elif kind == 'falls':
                if 10 <= y < 16:
                    c = R if (x + y) % 3 else Y          # the escarpment
                    if 40 <= x < 56:
                        c = Y if (x + y) % 2 else B      # white water
                elif 16 <= y < 22 and 36 <= x < 60:
                    c = B if (x * 7 + y * 3) % 5 else Y  # the plunge pool
            elif kind == 'clearing':
                d = ((x - 30) / 18.0) ** 2 + ((y - 16) / 9.0) ** 2
                if d < 1.0 * e + 0.0:
                    c = Y if (x + y) % 5 else G
                    if d > 0.8:
                        c = G if (x + y) % 2 else Y
            elif kind == 'arena':
                # the gorge floor: a broad river between red walls, every row alike
                wl = 20 + 3 * math.sin(2 * math.pi * y / 32)
                wr = 20 + 3 * math.sin(2 * math.pi * y / 32 + 2)
                if x < wl - 3 or 95 - x < wr - 3:
                    c = c if (x < 8 or 95 - x < 8) else (R if (x * 3 + y * 5) % 9 else Y)
                elif x < wl or 95 - x < wr:
                    c = R if (x + y) % 2 else B
                else:
                    c = B
                    if (x * 7 + y * 13) % 41 == 0:
                        c = G
            img[y][x] = c
    if kind == 'clearing':
        # a research camp: two huts and a landing pad
        hut = ["rrrrrr", "ryyyyr", "rrrrrr"]
        stamp(img, hut, 20, 12)
        stamp(img, hut, 32, 18)
        stamp(img, [".yyy.", "y.r.y", "yrrry", "y.r.y", ".yyy."], 38, 10)
    if kind == 'ruins':
        pass
    return img

DAINTREE_KINDS = ['canopy', 'billabong', 'gorge', 'falls', 'clearing', 'arena']

# =========================================================================
#  STAGE 3: RED CENTRE (colour set 1: 0 buff 1 cyan 2 magenta 3 orange)
# =========================================================================
BF, CY, MG, OR = 0, 1, 2, 3

def centre_base(x, y):
    # long dune ridges running north-west, crests catching the light
    p = math.sin(2 * math.pi * (x / 26.0 + y / 16.0) + 2.5 * pnoise(x, y, 12, 8, 301))
    t = bayer(x, y)
    if p > 0.82:
        return BF if t < 0.6 else OR
    if p < -0.75:
        return MG if t < 0.55 else OR
    return OR

def centre_block(kind, seed):
    img = new_img(OR)
    for y in range(BLK_ROWS):
        e = env(y)
        for x in range(PFW):
            c = centre_base(x, y)
            t = bayer(x, y)
            if kind == 'spinifex':
                if pnoise(x, y, 3, 2, seed) > 0.72 and (x + y) % 2 == 0:
                    c = BF if pnoise(x, y, 2, 2, seed + 1) > 0.5 else MG
            elif kind == 'saltlake':
                d = ((x - 52) / 34.0) ** 2 + ((y - 16) / 13.0) ** 2
                d += 0.35 * (pnoise(x, y, 6, 4, seed) - 0.5)
                lim = e * 1.0
                if d < lim * 0.75:
                    c = BF if t > 0.12 else CY
                elif d < lim:
                    c = CY if t < 0.5 else BF
            elif kind == 'rock':
                # the monolith: a long rounded mass with weathering grooves
                d = ((x - 46) / 30.0) ** 2 + ((y - 16) / 11.0) ** 2
                if d < 1.0 * e:
                    shade = (x - 46) / 30.0 + (y - 16) / 22.0
                    c = OR
                    if shade > 0.35 and t < shade - 0.2:
                        c = MG
                    if shade < -0.45 and t < 0.4:
                        c = BF
                    if (x + 3 * y) % 11 == 0 and d < 0.8:
                        c = MG
                elif d < 1.15 * e and t < 0.6:
                    c = MG                         # its shadow
            elif kind == 'waterhole':
                for (cx, cy, r) in ((30, 14, 7), (64, 19, 5)):
                    d = math.hypot((x - cx), (y - cy) * 1.5) / (r * e + 0.01)
                    if d < 0.7:
                        c = CY if (x + y) % 5 else BF
                    elif d < 1.0:
                        c = BF if t < 0.6 else OR
                    elif d < 1.4 and t < 0.35:
                        c = MG                     # a ring of scrub
            elif kind == 'crater':
                d = math.hypot(x - 48, (y - 16) * 1.5) / (18 * e + 0.01)
                if d < 0.75:
                    c = OR if t > 0.3 else MG
                    if x - 48 + (y - 16) * 1.5 < -6 and d > 0.55:
                        c = MG
                elif d < 1.0:
                    c = BF if t < 0.7 else OR      # the rim
            elif kind == 'arena':
                # a rail yard: three tracks, ballast between, every row alike
                c = OR if t > 0.25 else MG
                for rx in (14, 46, 78):
                    if x in (rx, rx + 5):
                        c = BF
                    elif rx - 1 <= x <= rx + 6 and y % 3 == 0:
                        c = MG
            img[y][x] = c
    if kind == 'outpost':
        pass
    return img

CENTRE_KINDS = ['dunes', 'spinifex', 'saltlake', 'rock', 'waterhole', 'crater', 'arena']

# =========================================================================
#  STAGE 4: HARBOUR NIGHT (colour set 0) - water, city lights, the bridge
# =========================================================================
def harbour_base(x, y):
    if h2(x, y, 401) > 0.985:
        return G                        # glints on the water
    if (x + 2 * y) % 23 == 0 and h2(x // 3, y, 402) > 0.8:
        return G
    return B

def city(x, y, seed):
    """city blocks: red roofs, yellow window lights, green parks, lit streets"""
    bx, by = x // 8, y // 8
    lx, ly = x % 8, y % 8
    if lx == 0 or ly == 0:
        return Y if (x + y) % 3 == 0 else B           # streets with lamps
    k = h2(bx, by % 4, seed)
    if k < 0.18:
        return G if (x + y) % 2 else (Y if (x * y) % 7 == 0 else G)   # a park
    if k > 0.85 and 2 <= lx <= 6 and 2 <= ly <= 6:
        return Y if (lx + ly) % 2 else R               # a lit tower
    if lx in (1, 7) or ly in (1, 7):
        return R
    return Y if h2(x, y % 32, seed + 1) > 0.55 else R

def harbour_block(kind, seed):
    img = new_img(B)
    for y in range(BLK_ROWS):
        e = env(y)
        for x in range(PFW):
            c = harbour_base(x, y)
            # both shores are lit city all the way up; some blocks push it out
            wl = 9 + 2 * math.sin(2 * math.pi * y / 32)
            wr = 9 + 2 * math.sin(2 * math.pi * y / 32 + 2)
            if kind == 'city_l':
                wl += (18 + 8 * pnoise(0, y, 1, 8, seed)) * e
            if kind == 'city_r':
                wr += (18 + 8 * pnoise(0, y, 1, 8, seed + 5)) * e
            if kind == 'opera':
                wr += 10 * e
            if kind == 'arena':
                wl += 4 * e * 0
            if x < wl:
                c = city(x, y, seed) if x < wl - 2 else (Y if y % 2 else R)
            elif 95 - x < wr:
                c = city(x, y, seed + 9) if 95 - x < wr - 2 else (Y if y % 2 else R)
            if kind == 'bridge':
                # the deck crossing the harbour, pylons at each end
                if 13 <= y <= 18:
                    if y in (13, 18):
                        c = Y if x % 2 else R
                    elif y in (14, 17):
                        c = R if x % 6 else Y          # the arch's lit girders
                    else:
                        c = Y if (x // 2) % 3 else B   # traffic
                if (x < 10 or x > 85) and 9 <= y <= 22:
                    c = Y if (x + y) % 3 else R
                if e < 0.35 and (x < 6 or x > 89):
                    c = c
            if kind == 'opera':
                # the sails on the point
                if x < 40:
                    d = ((x - 4) / 34.0) ** 2 + ((y - 16) / 12.0) ** 2
                    if d < e:
                        c = G if (x + y) % 2 else R
                        for sx, sy in ((14, 10), (22, 14), (30, 18), (18, 20)):
                            dd = (x - sx) ** 2 / 25.0 + (y - sy) ** 2 / 9.0
                            if dd < 1:
                                c = Y if (x - sx) + (y - sy) < 1 else (Y if (x + y) % 2 else G)
            img[y][x] = c
    if kind == 'ferries':
        ferry = ["..yyyy..", ".yrrrry.", "yryyyyry", "yryyyyry", ".yrrrry.", "..yyyy.."]
        stamp(img, ferry, 30, 6)
        stamp(img, ferry, 60, 18)
        for j in range(8):
            for x0 in (33, 63):
                for dx in (-1 - j // 3, 2 + j // 3):
                    yy = (12 if x0 == 33 else 24) + j
                    if yy < BLK_ROWS and 0 <= x0 + dx < PFW and j % 2 == 0:
                        img[yy][x0 + dx] = G
    return img

HARBOUR_KINDS = ['water', 'city_l', 'city_r', 'cities', 'bridge', 'opera', 'ferries', 'arena']

# =========================================================================
#  STAGE 5: SOUTHERN ICE (colour set 1)
# =========================================================================
def ice_base(x, y):
    # wind-cut sastrugi: short cyan streaks on buff ice
    n = pnoise(x, y, 10, 4, 501)
    s = math.sin(2 * math.pi * (x / 9.0 - y / 32.0 * 3) + 3 * n)
    t = bayer(x, y)
    if s > 0.9 and t < 0.6:
        return CY
    if n < 0.28 and t < 0.25:
        return MG
    return BF

def floe_dist(x, y, seed):
    """distances to the nearest two floe centres (a 12 x 8 jittered grid,
    wrapping every 32 rows)"""
    ds = []
    gy0 = y // 8
    for gx in range(x // 12 - 1, x // 12 + 2):
        for gy in range(gy0 - 1, gy0 + 2):
            px = gx * 12 + 2 + 8 * h2(gx, gy % 4, seed)
            py = gy * 8 + 1 + 6 * h2(gx, gy % 4, seed + 1)
            ds.append(math.hypot(x - px, (y - py) * 1.4))
    ds.sort()
    return ds[0], ds[1]

def ice_block(kind, seed):
    img = new_img(BF)
    for y in range(BLK_ROWS):
        e = env(y)
        for x in range(PFW):
            c = ice_base(x, y)
            t = bayer(x, y)
            if kind == 'crevasse':
                for k, (cx0, ph) in enumerate(((26, 0.0), (66, 1.7))):
                    cx = cx0 + 6 * math.sin(y / 3.0 + ph) * e
                    w = 3.2 * e
                    d = x - cx
                    if abs(d) < w:
                        c = MG if d > -w + 1.2 else CY
            elif kind == 'seaice':
                # broken pack ice: plates with cracks that open wide mid-block
                d1, d2 = floe_dist(x, y, seed)
                if d2 - d1 < 3.2 * e:
                    c = CY if t > 0.08 else BF
                elif d2 - d1 < 3.2 * e + 1.0:
                    c = MG
            elif kind == 'berg':
                d = ((x - 50) / 28.0) ** 2 + ((y - 16) / 11.0) ** 2
                d2 = ((x - 50) / 36.0) ** 2 + ((y - 16) / 14.0) ** 2
                if d < e:
                    c = BF
                    if (x - 50) / 28.0 + (y - 16) / 11.0 > 0.6 and t < 0.5:
                        c = MG
                    elif (x * 3 + y * 7) % 17 == 0:
                        c = CY
                elif d2 < e:
                    c = CY if t > 0.1 else BF
            elif kind == 'ridge':
                for ry in (9, 22):
                    dy = abs(y - ry - 2 * math.sin(x / 7.0 + ry))
                    if dy < 1.8 * e:
                        c = MG if ((x // 3) + y) % 2 else BF
                    elif dy < 2.8 * e and t < 0.5:
                        c = CY
            elif kind == 'station':
                pass
            elif kind == 'arena':
                # the citadel's plain: a marked ice runway, every row alike
                c = BF if t > 0.12 else CY
                if x in (20, 75):
                    c = OR if y % 8 < 4 else MG
                if 46 <= x <= 49 and y % 8 < 3:
                    c = MG
            img[y][x] = c
    if kind == 'station':
        hut = ["oooooooo", "obbobbbo", "oooooooo", "mmmmmmmm"]
        hut = [r.replace('o', 'r').replace('m', 'b') for r in hut]
        stamp(img, hut, 20, 8)
        stamp(img, hut, 34, 8)
        stamp(img, ["rrrrrrrrrrrr", "rggrggrggrgr", "rrrrrrrrrrrr", "bbbbbbbbbbbb"], 22, 16)
        for y in range(4, 28):
            img[y][60] = CY if y % 2 else MG            # the radio mast's guys
        stamp(img, ["..r..", ".rrr.", "rrgrr", ".rrr.", "..r.."], 58, 13)
    return img

ICE_KINDS = ['ice', 'crevasse', 'seaice', 'berg', 'ridge', 'station', 'arena']

# =========================================================================
#  STAGE 6: ORBIT (colour set 0) - stars, the Moon, the station, debris
# =========================================================================
def space_base(x, y, seed=601):
    k = h2(x, y, seed)
    if k > 0.992:
        return Y
    if k > 0.975:
        return G if (x + y) % 2 else B
    return B

def orbit_block(kind, seed):
    img = new_img(B)
    for y in range(BLK_ROWS):
        e = env(y)
        for x in range(PFW):
            c = space_base(x, y, seed)
            t = bayer(x, y)
            if kind == 'nebula':
                n = pnoise(x, y, 12, 8, seed) * e
                if n > 0.5 and t < (n - 0.5) * 1.6:
                    c = R if n > 0.62 and t < 0.15 else G
            elif kind == 'moon':
                d = math.hypot(x - 62, (y - 16) * 1.5) / (21 * e + 0.01)
                if d < 1.0:
                    c = Y
                    lit = (x - 62) / 21.0 + (y - 16) / 18.0
                    if lit > 0.35 and t < lit - 0.3:
                        c = R
                    for (mx, my, mr) in ((54, 10, 3), (68, 20, 4), (60, 18, 2), (72, 11, 2)):
                        if math.hypot(x - mx, (y - my) * 1.5) < mr:
                            c = R if (x + y) % 2 else Y
            elif kind == 'truss':
                if 12 <= y <= 19:
                    if y in (12, 19) or (x - y) % 8 == 0 or (x + y) % 8 == 0:
                        c = Y
                    else:
                        c = B
                    if x % 16 == 0 and y in (12, 19):
                        c = R                           # running lights
                for px in (8, 72):
                    if px <= x < px + 16 and 4 <= y <= 27 and not 12 <= y <= 19:
                        c = G if (x % 4 and y % 3) else Y   # solar wings
            elif kind == 'debris':
                pass
            elif kind == 'arena':
                c = space_base(x, y, 650)
                if (x * 3 + y * 7) % 97 == 0:
                    c = R
            img[y][x] = c
    if kind == 'debris':
        rnd = random.Random(seed)
        bits = [["yr.", "ryy"], [".y.", "yry", ".y."], ["rr", "ry"], ["y.y", ".r.", "y.y"],
                ["yyrr", "rryy"]]
        for i in range(12):
            b = rnd.choice(bits)
            stamp(img, b, rnd.randrange(4, 88), rnd.randrange(3, 27))
    return img

ORBIT_KINDS = ['space', 'nebula', 'moon', 'truss', 'debris', 'arena']

# =========================================================================
#  boss art
# =========================================================================
def grid(w, h):
    return [['.'] * w for _ in range(h)]

def rows_of(g):
    return [''.join(r) for r in g]

def open_core(rows, cx, cy, frame, r=4):
    """open the shell over (cx, cy): a dark ring and a pulsing eye"""
    g = [list(s) for s in rows]
    for y in range(len(g)):
        for x in range(len(g[0])):
            d = math.hypot(x - cx, (y - cy) * 1.4)
            if d < r + 1.5 and g[y][x] != '.':
                g[y][x] = 'b'
            if d < r:
                if frame == 0:
                    g[y][x] = 'r' if d > r - 1.6 else ('y' if d > 1.2 else 'r')
                else:
                    g[y][x] = 'y' if d > r - 1.2 else ('r' if d > 1.6 else 'y')
    return rows_of(g)

# -- Cassowary Walker: seen from above, a feathered armoured hull with a
#    casqued head; its two clawed feet and two wing guns are the parts
def cassowary():
    W, H = 24, 16
    g = grid(W, H)
    for y in range(H):
        for x in range(W):
            d = ((x - 11.5) / 11.5) ** 2 + ((y - 7) / 7.5) ** 2
            if d < 1:
                c = 'b' if (x + y) % 3 else 'g'          # dark plumage
                if d > 0.72:
                    c = 'y'
                elif abs(x - 11.5) < 2 and y < 12:
                    c = 'r'                              # the armoured spine
                g[y][x] = c
    # head and casque at the front (bottom), wattles red and blue
    head = ["..yyyy..",
            ".yrrrry.",
            "yryyyyry",
            "yrbyybry",
            ".yrrrry.",
            "..rbbr..",
            "...rr..."]
    for j, r in enumerate(head):
        for i, ch in enumerate(r):
            if ch != '.' and 9 + j < H:
                g[9 + j][8 + i] = ch
    return rows_of(g)

CASS_FOOT = ["y.yy.y..",
             "yryyryr.",
             ".rbbbr..",
             ".ryyyr..",
             "..rrr...",
             ".r.r.r..",
             "r..r..r."]
CASS_FOOT2 = ["..yy....",
              ".ryyry..",
              "yrbbbry.",
              ".ryyyr..",
              "..rrr...",
              ".r.r.r..",
              ".r.r.r.."]

# -- Drill Train: a drill-headed engine with ore wagons in tow
def drill_head():
    W, H = 20, 14
    g = grid(W, H)
    for y in range(H):
        for x in range(W):
            if 2 <= x < 18 and y < 9:                    # the cab
                c = 'r' if x in (2, 17) or y == 0 else 'y'
                if 5 <= x < 15 and 2 <= y < 7:
                    c = 'g' if (x + y) % 2 else 'b'
                g[y][x] = c
            # the drill: a cone of spiral bands at the front
            if y >= 9:
                half = (H - y) * 1.7
                if abs(x - 9.5) < half:
                    g[y][x] = 'y' if (x + 2 * y) % 4 < 2 else 'r'
    for y in range(1, 9):
        g[y][0] = g[y][19] = 'b'                         # tracks
        g[y][1] = g[y][18] = 'g' if y % 2 else 'b'
    return rows_of(g)

WAGON = ["rrrrrrrrrr",
         "ryyyyyyyyr",
         "ryrrbbrryr",
         "ryrbyybryr",
         "ryrrbbrryr",
         "ryyyyyyyyr",
         "rrrrrrrrrr",
         ".b......b."]
WAGON2 = ["rrrrrrrrrr",
          "ryyyyyyyyr",
          "ryrrbbrryr",
          "ryrbrrbryr",
          "ryrrbbrryr",
          "ryyyyyyyyr",
          "rrrrrrrrrr",
          "b........b"]

# -- Skyhook Carrier: a flat-decked airship with bay doors
def carrier():
    W, H = 30, 18
    g = grid(W, H)
    for y in range(H):
        for x in range(W):
            d = ((x - 14.5) / 15.0) ** 2 + ((y - 8.5) / 9.0) ** 4
            if d < 1:
                c = 'b' if (x // 2 + y) % 2 else 'g'
                if d > 0.8:
                    c = 'y'
                g[y][x] = c
    # the flight deck down the middle, lights along its edges
    for y in range(1, 17):
        for x in (10, 19):
            g[y][x] = 'y' if y % 3 else 'r'
        for x in range(11, 19):
            if g[y][x] != '.':
                g[y][x] = 'g' if (y % 4) else 'y'
    # bay doors at the front
    for x in range(11, 19):
        g[15][x] = 'r'
        g[16][x] = 'b'
    return rows_of(g)

DECKGUN = ["..yyy..",
           ".yrrry.",
           "yrbybry",
           "yrybyry",
           "yrbybry",
           ".yrrry.",
           "..yyy.."]
DECKGUN2 = ["..yyy..",
            ".yrrry.",
            "yrrbrry",
            "yrbybry",
            "yrrbrry",
            ".yrrry.",
            "..yyy.."]

# -- Ice Citadel (colour set 1: g buff, y cyan, b magenta, r orange)
def citadel():
    W, H = 28, 18
    g = grid(W, H)
    for y in range(H):
        for x in range(W):
            # a star fort: square with bastions
            inx = 3 <= x < 25 and 2 <= y < 16
            if inx:
                c = 'g'
                if x in (3, 24) or y in (2, 15):
                    c = 'y'
                elif (x + y) % 4 == 0:
                    c = 'y'
                g[y][x] = c
    for (cx, cy) in ((3, 2), (24, 2), (3, 15), (24, 15)):
        for y in range(H):
            for x in range(W):
                if abs(x - cx) + abs(y - cy) * 1.4 < 4:
                    g[y][x] = 'b' if (x + y) % 2 else 'g'
    # a ring wall round the keep
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - 13.5, (y - 8.5) * 1.4)
            if 6 < d < 7.5:
                g[y][x] = 'r'
    return rows_of(g)

ICETUR = ["..ggg..",
          ".grrrg.",
          "grbybrg",
          "gryyyrg",
          "grbybrg",
          ".grrrg.",
          "..ggg.."]
ICETUR2 = ["..ggg..",
           ".grrrg.",
           "grrbrrg",
           "grbybrg",
           "grrbrrg",
           ".grrrg.",
           "..ggg.."]

# -- Rust Heart: a corroded engine-heart in orbit, behind a ring of shields
def rust_heart(frame):
    W, H = 24, 18
    g = grid(W, H)
    rnd = random.Random(66)
    for y in range(H):
        for x in range(W):
            d = math.hypot(x - 11.5, (y - 8.5) * 1.35)
            if d < 11.5:
                c = 'r' if rnd.random() < 0.6 else 'y'
                if d > 10:
                    c = 'y'
                elif (x * 5 + y * 3) % 7 == 0:
                    c = 'b'                              # pitting
                g[y][x] = c
    # vents round the edge
    for k in range(8):
        a = 2 * math.pi * k / 8
        vx, vy = int(round(11.5 + 9 * math.cos(a))), int(round(8.5 + 9 / 1.35 * math.sin(a)))
        g[vy][vx] = 'b'
    return open_core(rows_of(g), 11.5, 8.5, frame, r=5)

SHIELD = ["..yyyy..",
          ".yrrrry.",
          "yrryrrry",
          "yrrrryry",
          "yryrrrry",
          ".yrrrry.",
          "..yyyy.."]
SHIELD2 = ["..yyyy..",
           ".yrrrry.",
           "yrrrryry",
           "yryrrrry",
           "yrryrrry",
           ".yrrrry.",
           "..yyyy.."]

# =========================================================================
#  enemy reskins (same sizes as the core's: drone 8x6, hornet 10x6, boat 12x8)
# =========================================================================
SKINS = {
    2: {  # fruit bats, rhinoceros beetles, a croc-hull river boat
        'drone0': ["y......y", "rr.yy.rr", "rrrbbrrr", ".rrbbrr.", "..r..r..", "........"],
        'drone1': ["........", "...yy...", "rrrbbrrr", "rrrbbrrr", "r.r..r.r", "........"],
        'horn0': [".r..yy..r.", "rrryyyyrrr", "rrybbbbyrr", ".rybbbbyr.", "..ryyyyr..", "...r..r..."],
        'horn1': ["....yy....", "rrryyyyrrr", ".rybbbbyr.", "rrybbbbyrr", "..ryyyyr..", "..r....r.."],
        'boat0': ["....yyyy....", "...yggggy...", "..yggrrggy..", ".ygyrbbrygy.",
                  ".ygyrbbrygy.", "..yggrrggy..", "...ygyygy...", "....g..g...."],
    },
    3: {  # dust-devil drones, wedge-tail gliders, a desert buggy
        'drone0': ["r.y..y.r", ".ryyyyr.", "rrybbyrr", ".ryyyyr.", "r.r..r.r", "........"],
        'drone1': [".r.yy.r.", "rryyyyrr", ".rybbyr.", "rryyyyrr", ".r.rr.r.", "........"],
        'horn0': ["r........r", "rrr.yy.rrr", ".rrryyrrr.", "...rbbr...", "....rr....", "...r..r..."],
        'horn1': ["..........", "rrrryyrrrr", "rrrryyrrrr", "...rbbr...", "....rr....", "....rr...."],
        'boat0': ["..rr....rr..", "..rryyyyrr..", "...yrrrry...", "...yrbbry...",
                  "...yrbbry...", "...yrrrry...", "..rryyyyrr..", "..rr....rr.."],
    },
    4: {  # searchlight drones, harbour gunships (the core's patrol boat)
        'drone0': ["...yy...", "..yrry..", "yyrbbryy", "..yrry..", "...yy...", "...y.y.."],
        'drone1': ["...yy...", "..yrry..", "rrrbbrrr", "..yrry..", "...yy...", "..y..y.."],
        'horn0': ["yyyyyyyyyy", "....rr....", ".rryyyyrr.", "rrybbbbyrr", ".rryyyyrr.", "....yy...."],
        'horn1': ["..yy..yy..", "....rr....", ".rryyyyrr.", "rrybbbbyrr", ".rryyyyrr.", "....yy...."],
    },
    5: {  # skua drones, ice hornets, a snow crawler
        'drone0': ["g......g", "gg.yy.gg", ".ggyygg.", "..gbbg..", "..g..g..", ".g....g."],
        'drone1': ["........", "gg.yy.gg", "gggyyggg", "..gbbg..", "..g..g..", "..g..g.."],
        'horn0': ["g.g....g.g", "gggyyyyggg", ".ggybbygg.", "..gyyyyg..", "...gggg...", "....rr...."],
        'horn1': ["..........", "gggyyyyggg", "gggybbyggg", "..gyyyyg..", "...gggg...", "....rr...."],
        'boat0': ["bb.bb.bb.bb.", "rrrrrrrrrrr.", "ryyyyyyyyyr.", "ryrbbbbbbyr.",
                  "ryrbbbbbbyr.", "ryyyyyyyyyr.", "rrrrrrrrrrr.", "bb.bb.bb.bb."],
    },
    6: {  # satellite drones, star fighters, drifting mines
        'drone0': ["yy....yy", "yy.rr.yy", "yyrbbryy", "yy.rr.yy", "yy....yy", "...rr..."],
        'drone1': ["gg....gg", "gg.rr.gg", "ggrbbrgg", "gg.rr.gg", "gg....gg", "...yy..."],
        'horn0': ["....yy....", "r..yrry..r", "ryyrbbryyr", "r..yrry..r", "...y..y...", "...r..r..."],
        'horn1': ["....yy....", "y..yrry..y", "yyyrbbryyy", "y..yrry..y", "...y..y...", "....rr...."],
        'boat0': ["...r..r.....", "....yy......", "..ryrryr....", "rryrbbryrr..",
                  "rryrbbryrr..", "..ryrryr....", "....yy......", "...r..r....."],
    },
}

def recolour(rows, m):
    return [''.join(m.get(c, c) for c in r) for r in rows]

# on the sand and the ice the usual colours vanish into the ground
SKIN_RECOLOUR = {3: {'r': 'b', 'b': 'r'}, 5: {'g': 'b', 'b': 'r'}}

def skin_sprites(n):
    """-> (art list, header pointer dict)"""
    sk = {k: recolour(v, SKIN_RECOLOUR.get(n, {})) for k, v in SKINS.get(n, {}).items()}
    p = 's%d_' % n
    art = []
    hdr = {'drone0': 'SPR_DRONE0', 'drone1': 'SPR_DRONE1', 'dronew': 'SPR_DRONE0W',
           'horn0': 'SPR_HORNET0', 'horn1': 'SPR_HORNET1', 'hornw': 'SPR_HORNET0W',
           'dart0': 'SPR_DART0', 'dart1': 'SPR_DART1', 'dartw': 'SPR_DART0W',
           'boat0': 'SPR_BOAT0', 'boatw': 'SPR_BOAT0W', 'rip0': 'SPR_RIPPLE0', 'rip1': 'SPR_RIPPLE1'}
    for base, (a, b, w) in (('drone', ('drone0', 'drone1', 'dronew')),
                             ('horn', ('horn0', 'horn1', 'hornw'))):
        if a in sk:
            art += [(p + a, sk[a]), (p + b, sk[b]), (p + w, flash_variant(sk[a]))]
            hdr[a] = 'SPR_' + (p + a).upper()
            hdr[b] = 'SPR_' + (p + b).upper()
            hdr[w] = 'SPR_' + (p + w).upper()
    if 'boat0' in sk:
        art += [(p + 'boat0', sk['boat0']), (p + 'boatw', flash_variant(sk['boat0']))]
        hdr['boat0'] = 'SPR_' + (p + 'boat0').upper()
        hdr['boatw'] = 'SPR_' + (p + 'boatw').upper()
    return art, hdr

HDR_ORDER = ['drone0', 'drone1', 'dronew', 'horn0', 'horn1', 'hornw',
             'dart0', 'dart1', 'dartw', 'boat0', 'boatw', 'rip0', 'rip1']

# =========================================================================
#  waves
# =========================================================================
def build_waves(seed, sections, gap, hardness):
    """sections: lists of formation names.  gap: frames between formations.
    hardness 0..1 adds members and tightens spacing a little."""
    rnd = random.Random(seed)
    W = []
    def w(d, t, p, x, n, s): W.append((d, t, p, x, n, s))
    extra = int(round(hardness * 2))
    for si, sec in enumerate(sections):
        if si:
            w(10, 'CP', 0, 0, 0, 0)
        first = True
        for f in sec:
            d = 60 if first else gap + rnd.randrange(-15, 16)
            first = False
            if f == 'swoopR':
                w(d, T_DRONE, 'PATH_SWOOPR', rnd.choice((4, 8, 12)), 5 + extra // 2, 7)
            elif f == 'swoopL':
                w(d, T_DRONE, 'PATH_SWOOPL', rnd.choice((76, 80, 84)), 5 + extra // 2, 7)
            elif f == 'pincer':
                w(d, T_DRONE, 'PATH_SWOOPR', 4, 5 + extra // 2, 6)
                w(30, T_DRONE, 'PATH_SWOOPL', 84, 5 + extra // 2, 6)
            elif f == 'sine':
                w(d, T_DRONE, 'PATH_SINE', rnd.choice((20, 44, 66)), 4 + extra, 10)
            elif f == 'sine2':
                w(d, T_DRONE, 'PATH_SINE', 20, 4 + extra // 2, 10)
                w(5, T_DRONE, 'PATH_SINE', 66, 4 + extra // 2, 10)
            elif f == 'loop':
                w(d, T_DRONE, 'PATH_LOOP', rnd.choice((30, 44, 60)), 5 + extra // 2, 6)
            elif f == 'loop2':
                w(d, T_DRONE, 'PATH_LOOP', 30, 5, 6)
                w(70, T_DRONE, 'PATH_LOOP', 60, 5, 6)
            elif f == 'darts':
                w(d, T_DART, 'PATH_DART', rnd.choice((10, 16, 40, 70)), 3 + extra, 9 - extra)
            elif f == 'boat':
                w(d, T_BOAT, 0, rnd.choice((14, 20, 40, 70, 74)), 1, 0)
            elif f == 'boats':
                w(d, T_BOAT, 0, 14, 1, 0)
                w(10, T_BOAT, 0, 74, 1, 0)
            elif f == 'boatdart':
                w(d, T_BOAT, 0, 40, 1, 0)
                w(10, T_DART, 'PATH_DART', rnd.choice((10, 70)), 3, 9)
            elif f == 'hornet':
                w(d, T_HORNET, 0, rnd.choice((20, 40, 64)), 1, 0)
            elif f == 'hornets':
                w(d, T_HORNET, 0, 20, 1, 0)
                w(60, T_HORNET, 0, 64, 1, 0)
            else:
                raise ValueError(f)
        w(150, 0, 0, 0, 0, 0)
    w(30, 'CP', 0, 0, 0, 0)
    w(10, 'BOSS', 0, 0, 0, 0)
    return W

def frames_to_boss(W):
    return sum(d for d, *_ in W)

# =========================================================================
#  music: arpeggiated "dink" tunes over a slow bass
# =========================================================================
def arp_song(chords, pattern, bass, unit, octave=5, boct=2):
    """chords: list of (root name, intervals) per bar.  pattern: tokens per bar,
    digits index the chord's notes (from octave), '-' holds, '.' rests."""
    A, Bv = [], []
    for root, iv in chords:
        r = note_index(root + str(octave))
        tones = [r + i for i in iv]
        for tok in pattern.split():
            if tok == '-':
                A[-1][1] += unit
            elif tok == '.':
                A.append([0, unit])
            else:
                A.append([tones[int(tok)], unit])
        rb = note_index(root + str(boct))
        for tok in bass.split():
            if tok == '-':
                Bv[-1][1] += unit
            elif tok == '.':
                Bv.append([0, unit])
            else:
                k = int(tok)
                Bv.append([rb + [0, 7, 12, 3, 5][k], unit])
    return A, Bv

MIN = (0, 3, 7, 12, 15, 19)
MAJ = (0, 4, 7, 12, 16, 19)
SUS = (0, 5, 7, 12, 17, 19)
MIN7 = (0, 3, 7, 10, 12, 15)

SONGS = {
    2: dict(chords=[('E', MIN), ('C', MAJ), ('D', MAJ), ('B', MIN), ('E', MIN), ('A', MIN), ('C', MAJ), ('D', SUS)],
            pattern="3 - 2 - 1 - 2 - 4 - 3 - 2 - 1 -",
            bass="0 - - - - - 1 - 2 - - - 1 - - -", unit=6, octave=4),
    3: dict(chords=[('A', MIN), ('A', MIN), ('G', MAJ), ('A', MIN), ('F', MAJ), ('G', MAJ), ('A', MIN), ('E', SUS)],
            pattern="3 - - - . 2 - - 1 - - 2 . . . .",
            bass="0 - - - - - - - 0 - 1 - - - - -", unit=7, octave=4, boct=1),
    4: dict(chords=[('C', MIN7), ('A#', MAJ), ('G#', MAJ), ('G', MIN), ('C', MIN7), ('F', MIN), ('G#', MAJ), ('G', SUS)],
            pattern="0 - 2 3 - 2 . 4 - 3 - 2 1 - . .",
            bass="0 - - 0 . 1 - - 0 - - 0 . 2 - -", unit=6, octave=4),
    5: dict(chords=[('F#', MIN), ('D', MAJ), ('A', MAJ), ('E', SUS), ('F#', MIN), ('B', MIN), ('D', MAJ), ('C#', SUS)],
            pattern="4 - - - 3 - - - 2 - - . 3 - . .",
            bass="0 - - - - - - - 1 - - - - - - -", unit=7, octave=4),
    6: dict(chords=[('D', MIN7), ('G', MAJ), ('D', MIN7), ('C', MAJ), ('A#', MAJ), ('C', MAJ), ('D', MIN7), ('A', SUS)],
            pattern="0 2 3 4 3 2 0 2 3 5 4 3 2 1 0 .",
            bass="0 - - - 1 - - - 2 - - - 1 - - -", unit=5, octave=4),
}

def song_asm(n):
    s = SONGS[n]
    A, Bv = arp_song(s['chords'], s['pattern'], s['bass'], s['unit'], s.get('octave', 5), s.get('boct', 2))
    assert sum(d for _, d in A) == sum(d for _, d in Bv), n
    t = []
    for nm, chan in (('S%d_SONG_A' % n, A), ('S%d_SONG_B' % n, Bv)):
        t.append('%s:\n' % nm)
        for note, d in chan:
            while d > 255:
                t.append('        db %d,255\n' % note); d -= 255; note = 0
            t.append('        db %d,%d\n' % (note, d))
        t.append('        db $FF\n')
    t.append('S%d_SONG:\n        dw S%d_SONG_A,S%d_SONG_B\n' % (n, n, n))
    return ''.join(t)

# =========================================================================
#  the stages
# =========================================================================
def bossdef(p, body_c, body_o0, body_o1, bw, bh, np_, pmode, ps0, ps1, psw, pw, ph,
            php, shield, chp, armour, move, pfire, cfire, limbs, spin, fint,
            core, ofs, parky, xmin, xmax, launch):
    ofs = list(ofs) + [(0, 0)] * (5 - len(ofs))
    b = lambda v: '%d' % (v & 255)
    t = ['%sBOSS:\n' % p,
         '        dw %s,%s,%s\n' % (body_c, body_o0, body_o1),
         '        db %d,%d,%d,%d\n' % (bw, bh, np_, pmode),
         '        dw %s,%s,%s\n' % (ps0, ps1, psw),
         '        db %s\n' % ','.join(b(v) for v in (pw, ph, php, shield, chp, armour, move, pfire,
                                                     cfire, limbs, spin, fint) + tuple(core)),
         '        db %s\n' % ','.join(b(v) for xy in ofs for v in xy),
         '        db %d,%d,%d,%d\n' % (parky, xmin, xmax, launch)]
    return ''.join(t)

def strz(label, s):
    for ch in s:
        assert ch in " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-!.'", s
    return '%s: db "%s",0\n' % (label, s)

STAGES = {
    1: dict(name="THE CORAL SEA", boss="CROWN OF THORNS", css=0),
    2: dict(name="THE DAINTREE", boss="CASSOWARY WALKER", css=0),
    3: dict(name="THE RED CENTRE", boss="THE DRILL TRAIN", css=1),
    4: dict(name="HARBOUR NIGHT", boss="SKYHOOK CARRIER", css=0),
    5: dict(name="THE SOUTHERN ICE", boss="THE ICE CITADEL", css=1),
    6: dict(name="LOW ORBIT", boss="THE RUST HEART", css=0),
}

def stage_content(n):
    """-> blocks, kinds, map pattern, pre-arena, waves, boss text, art"""
    p = 'S%d_' % n
    fs = lambda *names: {nm: [0, 2] for nm in names}
    if n == 1:
        kinds = stage1.KINDS
        blks = stage1.blocks()
        W = stage1.stage1_waves()
        pattern = ['sea', 'left', 'sea', 'garden', 'right', 'sea', 'wreck', 'garden', 'sea',
                   'left', 'both', 'sea', 'beacon', 'garden', 'right', 'sea', 'jetty', 'sea']
        pre, arena = ['both'], 'atoll'
        art = [(p + 'body_c', stage1.BODY_CLOSED), (p + 'body_o0', stage1.body_open(0)),
               (p + 'body_o1', stage1.body_open(1)),
               (p + 'pod0', stage1.POD), (p + 'pod1', stage1.POD2), (p + 'podw', flash_variant(stage1.POD))]
        fixed = fs(p + 'body_c', p + 'body_o0', p + 'body_o1')
        bd = bossdef(p, 'SPR_S1_BODY_C', 'SPR_S1_BODY_O0', 'SPR_S1_BODY_O1', 28, 18, 5, 0,
                     'SPR_S1_POD0', 'SPR_S1_POD1', 'SPR_S1_PODW', 7, 7,
                     14, 0, 60, 1, 0, 0, 0, 1, 1, 42, (2, 1, 24, 16), [], 22, 12, 50, 0)
        return kinds, blks, pattern, pre, arena, W, art, fixed, bd
    if n == 2:
        kinds = ['canopy', 'canopy2', 'billabong', 'gorge', 'falls', 'clearing', 'arena']
        blks = [daintree_block(k if k != 'canopy2' else 'canopy', 230 + i) for i, k in enumerate(kinds)]
        # canopy2: the same canopy with flowering trees
        for y in range(BLK_ROWS):
            for x in range(PFW):
                if blks[1][y][x] == G and h2(x // 2, y // 2, 240) > 0.93 and env(y) > 0.3:
                    blks[1][y][x] = R
        W = build_waves(2, [
            ['swoopR', 'swoopL', 'sine', 'boat', 'darts', 'loop', 'hornet', 'pincer', 'boat', 'sine2'],
            ['darts', 'loop2', 'boatdart', 'hornet', 'swoopR', 'swoopL', 'sine', 'hornets', 'boats', 'loop'],
        ], 85, 0.25)
        pattern = ['canopy', 'canopy2', 'billabong', 'canopy', 'clearing', 'canopy2', 'billabong',
                   'canopy', 'falls', 'canopy2', 'gorge', 'canopy', 'billabong', 'canopy2', 'clearing']
        pre, arena = ['gorge'], 'arena'
        body = cassowary()
        art = [(p + 'body_c', body), (p + 'body_o0', open_core(body, 11.5, 6, 0)),
               (p + 'body_o1', open_core(body, 11.5, 6, 1)),
               (p + 'pod0', CASS_FOOT), (p + 'pod1', CASS_FOOT2), (p + 'podw', flash_variant(CASS_FOOT))]
        fixed = fs(p + 'body_c', p + 'body_o0', p + 'body_o1')
        # parts: two clawed feet below, two wing guns at the sides
        bd = bossdef(p, 'SPR_S2_BODY_C', 'SPR_S2_BODY_O0', 'SPR_S2_BODY_O1', 24, 16, 4, 2,
                     'SPR_S2_POD0', 'SPR_S2_POD1', 'SPR_S2_PODW', 7, 7,
                     12, 0, 70, 1, 1, 1, 0, 1, 2, 50, (4, 1, 16, 12),
                     [(-1, 18), (17, 18), (-9, 3), (25, 3)], 20, 12, 54, 0)
        return kinds, blks, pattern, pre, arena, W, art, fixed, bd
    if n == 3:
        kinds = ['dunes', 'spinifex', 'saltlake', 'rock', 'waterhole', 'crater', 'arena']
        blks = [centre_block(k, 330 + i) for i, k in enumerate(kinds)]
        W = build_waves(3, [
            ['swoopL', 'boat', 'sine', 'darts', 'swoopR', 'hornet', 'boats', 'loop', 'sine2'],
            ['pincer', 'darts', 'boatdart', 'hornet', 'loop2', 'sine', 'boat', 'hornets'],
            ['swoopR', 'swoopL', 'darts', 'boats', 'loop', 'hornet', 'sine2'],
        ], 82, 0.5)
        pattern = ['dunes', 'spinifex', 'dunes', 'saltlake', 'dunes', 'waterhole', 'spinifex',
                   'dunes', 'crater', 'dunes', 'spinifex', 'rock', 'dunes', 'saltlake', 'spinifex']
        pre, arena = ['dunes'], 'arena'
        sand = {'r': 'b', 'b': 'r'}
        head = recolour(drill_head(), sand)
        WAGON_, WAGON2_ = recolour(WAGON, sand), recolour(WAGON2, sand)
        art = [(p + 'body_c', head), (p + 'body_o0', open_core(head, 9.5, 4.5, 0, r=3.5)),
               (p + 'body_o1', open_core(head, 9.5, 4.5, 1, r=3.5)),
               (p + 'pod0', WAGON_), (p + 'pod1', WAGON2_), (p + 'podw', flash_variant(WAGON_))]
        fixed = fs(p + 'body_c', p + 'body_o0', p + 'body_o1')
        bd = bossdef(p, 'SPR_S3_BODY_C', 'SPR_S3_BODY_O0', 'SPR_S3_BODY_O1', 20, 14, 4, 3,
                     'SPR_S3_POD0', 'SPR_S3_POD1', 'SPR_S3_PODW', 10, 8,
                     12, 0, 70, 1, 2, 0, 1, 0, 1, 46, (2, 0, 16, 12), [], 24, 30, 46, 0)
        return kinds, blks, pattern, pre, arena, W, art, fixed, bd
    if n == 4:
        kinds = ['water', 'city_l', 'city_r', 'bridge', 'opera', 'ferries', 'arena']
        blks = [harbour_block(k, 430 + i) for i, k in enumerate(kinds)]
        W = build_waves(4, [
            ['swoopR', 'swoopL', 'boat', 'sine2', 'darts', 'hornet', 'loop', 'boats', 'pincer'],
            ['darts', 'hornets', 'boatdart', 'loop2', 'sine', 'swoopL', 'boat', 'hornet'],
            ['pincer', 'darts', 'sine2', 'boats', 'hornets', 'loop'],
        ], 80, 0.6)
        pattern = ['water', 'city_l', 'water', 'ferries', 'city_r', 'water', 'city_l', 'opera',
                   'water', 'city_r', 'ferries', 'city_l', 'water', 'bridge', 'city_r']
        pre, arena = ['city_l'], 'arena'
        body = carrier()
        art = [(p + 'body_c', body), (p + 'body_o0', open_core(body, 14.5, 8.5, 0)),
               (p + 'body_o1', open_core(body, 14.5, 8.5, 1)),
               (p + 'pod0', DECKGUN), (p + 'pod1', DECKGUN2), (p + 'podw', flash_variant(DECKGUN))]
        fixed = fs(p + 'body_c', p + 'body_o0', p + 'body_o1')
        bd = bossdef(p, 'SPR_S4_BODY_C', 'SPR_S4_BODY_O0', 'SPR_S4_BODY_O1', 30, 18, 4, 1,
                     'SPR_S4_POD0', 'SPR_S4_POD1', 'SPR_S4_PODW', 7, 7,
                     14, 0, 80, 1, 0, 0, 0, 0, 1, 40, (6, 3, 18, 12),
                     [(-7, 2), (30, 2), (-3, 12), (26, 12)], 20, 30, 34, 1)
        return kinds, blks, pattern, pre, arena, W, art, fixed, bd
    if n == 5:
        kinds = ['ice', 'crevasse', 'seaice', 'berg', 'ridge', 'station', 'arena']
        blks = [ice_block(k, 530 + i) for i, k in enumerate(kinds)]
        W = build_waves(5, [
            ['swoopL', 'sine', 'boat', 'darts', 'pincer', 'hornet', 'loop2', 'boats'],
            ['darts', 'sine2', 'hornets', 'boatdart', 'swoopR', 'loop', 'darts', 'hornet'],
            ['pincer', 'boats', 'sine2', 'hornets', 'darts', 'loop'],
        ], 78, 0.75)
        pattern = ['ice', 'ridge', 'ice', 'crevasse', 'seaice', 'berg', 'seaice', 'ice',
                   'station', 'ice', 'ridge', 'crevasse', 'ice', 'seaice', 'ice']
        pre, arena = ['ice'], 'arena'
        body = recolour(citadel(), {'g': 'y', 'y': 'b', 'b': 'r'})
        tur, tur2 = recolour(ICETUR, {'g': 'b'}), recolour(ICETUR2, {'g': 'b'})
        art = [(p + 'body_c', body), (p + 'body_o0', open_core(body, 13.5, 8.5, 0)),
               (p + 'body_o1', open_core(body, 13.5, 8.5, 1)),
               (p + 'pod0', tur), (p + 'pod1', tur2), (p + 'podw', flash_variant(tur))]
        fixed = fs(p + 'body_c', p + 'body_o0', p + 'body_o1')
        bd = bossdef(p, 'SPR_S5_BODY_C', 'SPR_S5_BODY_O0', 'SPR_S5_BODY_O1', 28, 18, 4, 1,
                     'SPR_S5_POD0', 'SPR_S5_POD1', 'SPR_S5_PODW', 7, 7,
                     16, 0, 80, 1, 0, 1, 1, 0, 0, 52, (4, 2, 20, 14),
                     [(0, -1), (21, -1), (0, 12), (21, 12)], 22, 12, 52, 0)
        return kinds, blks, pattern, pre, arena, W, art, fixed, bd
    if n == 6:
        kinds = ['space', 'nebula', 'moon', 'truss', 'debris', 'arena']
        blks = [orbit_block(k, 630 + i) for i, k in enumerate(kinds)]
        W = build_waves(6, [
            ['pincer', 'sine2', 'darts', 'boat', 'hornet', 'loop2', 'swoopR', 'boats'],
            ['darts', 'hornets', 'sine', 'boatdart', 'pincer', 'loop', 'darts'],
            ['swoopL', 'hornets', 'boats', 'sine2', 'darts', 'loop2', 'hornet'],
        ], 76, 0.9)
        pattern = ['space', 'nebula', 'space', 'debris', 'space', 'truss', 'space', 'nebula',
                   'moon', 'space', 'debris', 'space', 'truss', 'nebula', 'space']
        pre, arena = ['space'], 'arena'
        o0, o1 = rust_heart(0), rust_heart(1)
        art = [(p + 'body_o0', o0), (p + 'body_o1', o1),
               (p + 'pod0', SHIELD), (p + 'pod1', SHIELD2), (p + 'podw', flash_variant(SHIELD))]
        fixed = fs(p + 'body_o0', p + 'body_o1')
        bd = bossdef(p, 'SPR_S6_BODY_O0', 'SPR_S6_BODY_O0', 'SPR_S6_BODY_O1', 24, 18, 5, 0,
                     'SPR_S6_POD0', 'SPR_S6_POD1', 'SPR_S6_PODW', 8, 7,
                     99, 1, 70, 0, 0, 0, 1, 0, 1, 40, (4, 2, 16, 14), [], 22, 14, 52, 0)
        return kinds, blks, pattern, pre, arena, W, art, fixed, bd

def stage_map(kinds, pattern, pre, arena, W):
    idx = {k: i for i, k in enumerate(kinds)}
    nb = frames_to_boss(W) // 32 + 2
    seq_ = []
    i = 0
    while len(seq_) < nb - 1 - len(pre):
        seq_.append(pattern[i % len(pattern)])
        i += 1
    seq_ += pre + [arena]
    m = [idx[k] for k in seq_]
    m += [idx[arena]] * (256 - len(m))
    return m, len(seq_) - 1

def gen_stage(n):
    st = STAGES[n]
    p = 'S%d_' % n
    kinds, blks, pattern, pre, arena, W, art, fixed, bd = stage_content(n)
    assert len(blks) <= 16
    m, boss_blk = stage_map(kinds, pattern, pre, arena, W)
    skin_art, hdr = skin_sprites(n)
    t = ['; Stage %d: %s - %d blocks, boss at block %d\n' % (n, st['name'], len(blks), boss_blk)]
    t.append('        db "S",%d,$%02X,0\n' % (n, st['css'] * 0x10))
    song = 'SONG_GAME' if n == 1 else p + 'SONG'
    nxt = (p + 'NEXT') if n < 6 else '0'
    t.append('        dw %sWAVES,%sBOSS,%s,%sNAME,%sBNAME,%s\n' % (p, p, song, p, p, nxt))
    t.append('        dw %s\n' % ','.join(hdr[k] for k in HDR_ORDER))
    t.append('        ds 6\n')
    t.append('        assert $ == STG_BLKADDR\n')
    t.append('        dw ' + ','.join('%sBLOCKS+%d' % (p, i * 768) for i in range(len(blks))) + '\n')
    t.append('        ds %d\n' % (2 * (16 - len(blks))))
    t.append('        assert $ == STG_MAP\n')
    for i in range(0, 256, 16):
        t.append('        db ' + ','.join('%d' % v for v in m[i:i + 16]) + '\n')
    t.append(strz(p + 'NAME', st['name']))
    t.append(strz(p + 'BNAME', st['boss']))
    if n < 6:
        t.append(strz(p + 'NEXT', STAGES[n + 1]['name']))
    t.append('%sWAVES:\n' % p)
    for d, ty, pa, x, cnt, s in W:
        tyv = {'CP': '$FE', 'BOSS': '$FD'}.get(ty, ty)
        pid = PATH_IDS.get(pa, 0) if pa else 0
        t.append('        db %d,%s,%d,%d,%d,%d\n' % (d, tyv, pid, x, cnt, s))
    t.append('        db 1,$FF,0,0,0,0\n')
    t.append(bd)
    if n > 1:
        t.append(song_asm(n))
    t.append(sprites_asm(art + skin_art, fixed_shifts=fixed))
    t.append('%sBLOCKS:\n' % p)
    for img in blks:
        for y in range(BLK_ROWS):
            row = [pack(img[y][i:i + 4]) for i in range(0, PFW, 4)]
            t.append('        db ' + ','.join('$%02X' % b for b in row) + '\n')
    t.append('S%d_END:\n' % n)
    return ''.join(t), m, blks, boss_blk, W

PAL0 = [(48, 210, 0), (193, 229, 0), (76, 58, 180), (154, 50, 54)]
PAL1 = [(210, 210, 200), (60, 200, 200), (190, 60, 200), (220, 110, 30)]

def preview(n, m, blks, path, count=40):
    from PIL import Image
    pal = PAL1 if STAGES[n]['css'] else PAL0
    im = Image.new('RGB', (PFW, 32 * count))
    for bi in range(count):
        img = blks[m[count - 1 - bi]]
        for y in range(32):
            for x in range(PFW):
                im.putpixel((x, bi * 32 + y), pal[img[y][x]])
    im.resize((PFW * 2, 32 * count * 3), Image.NEAREST).save(path)

def preview_sprites(n, path):
    from PIL import Image
    pal = PAL1 if STAGES[n]['css'] else PAL0
    kinds, blks, pattern, pre, arena, W, art, fixed, bd = stage_content(n)
    sk, _ = skin_sprites(n)
    allart = art + sk
    wtot = sum(max(len(r) for r in rows) + 4 for _, rows in allart)
    im = Image.new('RGB', (wtot, 24), (0, 0, 0))
    x0 = 0
    for _, rows in allart:
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch != '.':
                    im.putpixel((x0 + x, y), pal[CH[ch]])
        x0 += max(len(r) for r in rows) + 4
    im.resize((wtot * 4, 24 * 6), Image.NEAREST).save(path)
