#!/usr/bin/env python3
"""DUEL II - ACE OF ACES RETURNS  data generator -> data.inc
font, plane frames (16 headings, pre-shifted 4 ways, logical colours, recoloured per
theatre at run time), other sprites, cloud masks, theatre backdrops, velocity tables,
title picture, ace portraits, medal picture, music.  Previews go to ../build/preview/.
All graphics are original (BPM 2026); nothing is taken from the 1980s DUEL."""
import os, math, random
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "data.inc")
PREV = os.path.join(HERE, "..", "build", "preview")
os.makedirs(PREV, exist_ok=True)
CSS0 = [(7, 255, 0), (255, 255, 0), (59, 8, 255), (204, 0, 59)]
CSS1 = [(255, 255, 255), (7, 227, 153), (255, 28, 255), (255, 129, 0)]
L = []
ARENA_H = 58


def db(vals, per=16):
    vals = list(vals)
    for i in range(0, len(vals), per):
        L.append("    db " + ",".join("$%02X" % (v & 255) for v in vals[i:i + per]))


def packbits(data):
    """0..127 -> n+1 literals; 129..255 -> repeat next byte 257-n times; 128 = end"""
    out = []; i = 0; n = len(data)
    while i < n:
        j = i
        while j < n and j - i < 128 and data[j] == data[i]:
            j += 1
        if j - i >= 3:
            out += [257 - (j - i), data[i]]; i = j; continue
        lit = []
        while i < n and len(lit) < 128:
            if i + 2 < n and data[i] == data[i + 1] == data[i + 2]:
                break
            lit.append(data[i]); i += 1
        out += [len(lit) - 1] + lit
    out.append(128)
    return out


def bitmap_to_bytes(pix, x0=0, w=128):
    out = []
    for y in range(len(pix)):
        for bx in range(w // 4):
            v = 0
            for k in range(4):
                v = (v << 2) | (pix[y][x0 + bx * 4 + k] & 3)
            out.append(v)
    return out


def save_preview(pix, name, pal=CSS0, sx=4, sy=6):
    w = len(pix[0]); h = len(pix)
    im = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            c = pix[y][x]
            im.putpixel((x, y), (40, 40, 40) if c is None else pal[c & 3])
    im.resize((w * sx, h * sy), Image.NEAREST).save(os.path.join(PREV, name))


exec(open(os.path.join(HERE, "font.py")).read())

# ---------------------------------------------------------------- frames
# A frame = image with per-pixel logical colour or None (transparent), plus the offset of its
# top-left pixel from the object's position.  Stored pre-shifted 4 ways as rows of
# (mask, data) byte pairs.  'map' 0 = theatre colours, 1 = theatre colours with 1<->2 swapped
# (the second plane), so both planes share one set of source data.
FRAMES = []          # (name, ox, oy, rows, map, srcname)
BLOCKS = {}          # srcname -> list of 4 shifted blocks


def shifted_blocks(rows):
    h = len(rows); w = len(rows[0])
    out = []
    for s in range(4):
        wb = (w + s + 3) // 4
        bs = [wb, h]
        for r in rows:
            m = [0xFF] * wb; d = [0] * wb
            for x, c in enumerate(r):
                if c is None:
                    continue
                X = x + s; b = X // 4; sh = 6 - 2 * (X % 4)
                m[b] &= ~(3 << sh) & 0xFF
                d[b] |= c << sh
            for i in range(wb):
                bs += [m[i], d[i]]
        out.append(bs)
    return out


def add_frame(name, rows, ox, oy, mp=0, src=None):
    src = src or name
    if src not in BLOCKS:
        BLOCKS[src] = shifted_blocks(rows)
    FRAMES.append((name, ox, oy, rows, mp, src))


def crop(rows, cx, cy):
    """crop transparent border; return rows, ox, oy relative to centre (cx, cy)"""
    ys = [y for y, r in enumerate(rows) if any(c is not None for c in r)]
    xs = [x for x in range(len(rows[0])) if any(r[x] is not None for r in rows)]
    y0, y1, x0, x1 = min(ys), max(ys), min(xs), max(xs)
    return [r[x0:x1 + 1] for r in rows[y0:y1 + 1]], x0 - cx, y0 - cy


def art(txt, cmap):
    rows = [r for r in txt.strip("\n").split("\n")]
    w = max(len(r) for r in rows)
    return [[cmap.get(ch) for ch in r.ljust(w, '.')] for r in rows]


# --- the planes: biplanes drawn as strokes in aspect-corrected space (Mode 1 pixels are
# 2/3 as wide as they are tall), headings 0..4 rasterised, the rest made by mirroring
PW, PH = 13, 10


def plane_raster(h):
    a = h * math.pi / 8; ca, sa = math.cos(a), math.sin(a)
    out = [[None] * PW for _ in range(PH)]
    cx, cy = 6, 4.5

    def P(u, v):
        wx = u * ca + v * sa; wy = u * sa - v * ca
        return cx + wx * 1.5, cy + wy

    def seg(u0, v0, u1, v1, c):
        for i in range(41):
            t = i / 40.0
            x, y = P(u0 + (u1 - u0) * t, v0 + (v1 - v0) * t)
            X, Y = int(math.floor(x + .5)), int(math.floor(y + .5))
            if 0 <= X < PW and 0 <= Y < PH:
                out[Y][X] = c
    for v in (0.2, 0.6, 1.0):
        seg(-3.8, v, 3.8, v, 1)          # upper + lower wing (seen as one from above)
    seg(-1.6, -3.0, 1.6, -3.0, 1)        # tailplane
    seg(0, -3.3, 0, 3.0, 1)              # fuselage
    seg(-0.5, 3.6, 0.5, 3.6, 3)          # spinning propeller (accent)
    seg(0, 1.9, 0, 1.9, 3)               # pilot's cockpit (accent)
    return out


_pb = [plane_raster(h) for h in range(5)]


def plane_img(h):
    if h <= 4:
        return _pb[h]
    if h <= 8:
        return _pb[8 - h][::-1]
    return [r[::-1] for r in plane_img(16 - h)]


for team in (1, 2):
    for h in range(16):
        rows, ox, oy = crop(plane_img(h), 6, 4)
        add_frame("P%d_%d" % (team, h), rows, ox, oy, team - 1, "PLANE_%d" % h)

# --- other sprites ('L' logical 1, 'D' 2, 'A' accent 3)
CM = {'L': 1, 'D': 2, 'A': 3, 'O': 0}
SPRITES = {
    'BALLOON': ("""
.AAA.
AALAA
AAAAA
AAAAA
.AAA.
..L..
.LLL.
""", 2, 3),
    'CHUTE': ("""
..LLL..
.LALAL.
LLALALL
.LALAL.
..LLL..
...A...
""", 3, 2),
    'EXP1': ("""
.A.A.
..L..
AL.LA
..L..
.A.A.
""", 2, 2),
    'EXP2': ("""
A..L..A
.A.L.A.
..ALA..
LLA.ALL
..ALA..
.A.L.A.
A..L..A
""", 3, 3),
    'EXP3': ("""
.A...L...A.
...A...A...
L..........L
..A..L..A..
............
A.L.....L.A
............
..A..L..A..
L..........L
...A...A...
.A...L...A.
""", 5, 5),
    'BURST': ("""
..LLL..
.LAAAL.
LAA.AAL
.LAAAL.
..LLL..
""", 3, 2),
    'STAR': ("""
..L..
L.L.L
.LLL.
L.L.L
..L..
""", 2, 2),
    'BOLT': ("""
..AA
.AA.
AAAA
..AA
.AA.
AA..
""", 2, 3),
}
for n, (txt, ox, oy) in SPRITES.items():
    add_frame(n, art(txt, CM), -ox, -oy)

L.append("; ---- frames: ox, oy, map, dw shift0..3  (11 bytes)")
L.append("NFRAMES equ %d" % len(FRAMES))
for i, f in enumerate(FRAMES):
    L.append("FR_%s equ %d" % (f[0], i))
L.append("frametab:")
for (n, ox, oy, rows, mp, src) in FRAMES:
    L.append("    db %d,%d,%d : dw bl_%s_0,bl_%s_1,bl_%s_2,bl_%s_3" % (ox & 255, oy & 255, mp, src, src, src, src))
tot = 0
for src, bl in BLOCKS.items():
    for s, b in enumerate(bl):
        L.append("bl_%s_%d:" % (src, s))
        db(b)
for (n, ox, oy, rows, mp, src) in FRAMES:
    tot += sum(len(b) for b in BLOCKS[src])
L.append("FRAMEWORK equ %d   ; bytes of recoloured copies built at run time" % tot)

# preview: planes for both teams in theatre 1 colours
sheet = [[0] * (16 * 15) for _ in range(26)]
for i, (n, ox, oy, rows, mp, src) in enumerate(FRAMES):
    bx = (i % 16) * 15 + 1; by = (i // 16) * 12 + 1
    if by + len(rows) >= 26:
        continue
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c is not None:
                cc = c if mp == 0 else {1: 2, 2: 1}.get(c, c)
                sheet[by + y][bx + x] = cc
save_preview(sheet, "frames.png")

# ---------------------------------------------------------------- clouds (masks only)
random.seed(1984)


def cloud_shape(w, h, puffs, seed):
    rnd = random.Random(seed)
    m = [[0] * w for _ in range(h)]
    circles = []
    for i in range(puffs):
        t = (i + 0.5) / puffs
        cx = 3 + t * (w - 6) + rnd.uniform(-1.2, 1.2)
        r = rnd.uniform(0.32, 0.5) * h * (1.0 - 0.45 * abs(t - 0.5))
        cy = h - 1.2 - r + rnd.uniform(-0.3, 0.6)
        circles.append((cx, cy, r))
    circles.append((w / 2, h - 2.2, h * 0.36))
    for y in range(h):
        for x in range(w):
            for (cx, cy, r) in circles:
                dx = (x + 0.5 - cx) / 1.5; dy = y + 0.5 - cy
                if dx * dx + dy * dy <= r * r:
                    m[y][x] = 1
    # trim empty rows/cols
    while not any(m[0]):
        m.pop(0)
    while not any(m[-1]):
        m.pop()
    while not any(r[0] for r in m):
        m = [r[1:] for r in m]
    while not any(r[-1] for r in m):
        m = [r[:-1] for r in m]
    return m


CLOUDS = [cloud_shape(30, 12, 5, 3), cloud_shape(22, 10, 4, 11), cloud_shape(16, 8, 3, 21),
          cloud_shape(36, 13, 6, 5), cloud_shape(12, 7, 2, 8)]
L.append("; ---- cloud masks (11 = clear): per shape 4 shifts: db wbytes,h, masks")
L.append("NCLOUDS equ %d" % len(CLOUDS))
L.append("cloudtab: ; dw shift0..3, db width px, height")
for i, c in enumerate(CLOUDS):
    L.append("    dw cl%d_0,cl%d_1,cl%d_2,cl%d_3 : db %d,%d" % (i, i, i, i, len(c[0]), len(c)))
for i, c in enumerate(CLOUDS):
    h = len(c); w = len(c[0])
    for s in range(4):
        wb = (w + s + 3) // 4
        bs = [wb, h]
        for r in c:
            m = [0xFF] * wb
            for x, v in enumerate(r):
                if v:
                    X = x + s
                    m[X // 4] &= ~(3 << (6 - 2 * (X % 4))) & 0xFF
            bs += m
        L.append("cl%d_%d:" % (i, s))
        db(bs)
csheet = [[0] * 128 for _ in range(16)]
x = 1
for c in CLOUDS:
    for yy, r in enumerate(c):
        for xx, v in enumerate(r):
            if v and x + xx < 128:
                csheet[1 + yy][x + xx] = 1
    x += len(c[0]) + 2
save_preview(csheet, "clouds.png")

# ---------------------------------------------------------------- velocity table
# level 0..5 = throttle settings, 6..7 = turbo, 8 = bullets, 9 = falling drift
# vertical rows per game tick (25 Hz) * 256; horizontal is x1.5 (Mode 1 pixels are narrow)
LEVELS = [156, 196, 236, 276, 316, 356, 410, 456, 1040, 104]   # per 25 Hz game tick
L.append("NLEVELS equ %d" % len(LEVELS))
L.append("veltab: ; [level][heading] dw vx, vy  (8.8 pixels/frame)")
for sp in LEVELS:
    vals = []
    for h in range(16):
        a = h * math.pi / 8
        vx = int(round(math.sin(a) * sp * 1.5)); vy = int(round(-math.cos(a) * sp))
        vals += ["$%04X" % (vx & 0xFFFF), "$%04X" % (vy & 0xFFFF)]
    L.append("    dw " + ",".join(vals))

# ---------------------------------------------------------------- theatre backdrops
# logical: 0 ground/sea, 3 features, 1 = tiny highlights (sparingly; it's the plane colour)
def backdrop(kind):
    rnd = random.Random({'meadow': 7, 'ocean': 8, 'desert': 9, 'night': 10, 'classic': 1}[kind])
    P = [[0] * 128 for _ in range(ARENA_H)]

    def put(x, y, c):
        P[y % ARENA_H][x % 128] = c
    if kind == 'meadow':
        # hedgerows (dotted field boundaries), a winding lane and farmhouses
        for k in range(3):
            y = rnd.randrange(ARENA_H)
            for x in range(0, 128, 3):
                if rnd.random() < 0.8:
                    put(x, y + (x // 40), 3)
        for k in range(3):
            x = rnd.randrange(128)
            for y in range(0, ARENA_H, 2):
                if rnd.random() < 0.6:
                    put(x + (y // 20), y, 3)
        x = 20.0
        for y in range(ARENA_H):
            x += math.sin(y / 6.0) * 1.3
            put(int(x), y, 3)
        for k in range(7):
            fx, fy = rnd.randrange(128), rnd.randrange(ARENA_H)
            for dy in range(2):
                for dx in range(3):
                    put(fx + dx, fy + dy, 3)
            put(fx + 1, fy - 1, 3)
        for k in range(18):
            put(rnd.randrange(128), rnd.randrange(ARENA_H), 3)
    elif kind == 'ocean':
        # islands with surf dots, wave flecks
        for (cx, cy, r) in ((26, 14, 6), (96, 40, 8), (70, 10, 3), (14, 46, 4), (118, 18, 3)):
            for y in range(-r - 2, r + 3):
                for x in range(-2 * r - 3, 2 * r + 4):
                    d = (x / 1.5) ** 2 + y * y
                    wob = r + math.sin(x * 0.9 + y * 1.3) * 0.8
                    if d <= wob * wob:
                        put(cx + x, cy + y, 3)
                    elif d <= (wob + 1.5) ** 2 and (x + y) % 2 == 0:
                        put(cx + x, cy + y, 3)
        for k in range(70):
            x, y = rnd.randrange(128), rnd.randrange(ARENA_H)
            if P[y][x] == 0 and P[y][(x + 1) % 128] == 0:
                put(x, y, 3); put(x + 1, y, 3)
    elif kind == 'desert':
        # dune ridges (dither) and an oasis
        for k in range(7):
            y0 = rnd.randrange(ARENA_H); ph = rnd.uniform(0, 6)
            for x in range(128):
                y = int(y0 + 3 * math.sin(x / 9.0 + ph))
                put(x, y, 3)
                if x % 2 == 0:
                    put(x, y + 1, 3)
        for y in range(-4, 5):
            for x in range(-8, 9):
                if (x / 1.5) ** 2 + y * y <= 12:
                    put(84 + x, 30 + y, 3)
        for (px, py) in ((78, 25), (91, 26), (80, 35), (90, 34)):
            put(px, py, 1); put(px - 1, py - 1, 1); put(px + 1, py - 1, 1)
        for k in range(40):
            put(rnd.randrange(128), rnd.randrange(ARENA_H), 3)
    elif kind == 'night':
        # coastline at the bottom, town lights, stars reflected... and a river
        for x in range(128):
            top = int(44 + 4 * math.sin(x / 11.0) + 2 * math.sin(x / 4.3))
            for y in range(top, ARENA_H):
                put(x, y, 3)
        for k in range(30):
            x, y = rnd.randrange(128), rnd.randrange(46, ARENA_H)
            if P[y][x] == 3:
                put(x, y, 1)
        for k in range(26):
            put(rnd.randrange(128), rnd.randrange(0, 40), 3)
    return P


BACKS = ['meadow', 'ocean', 'desert', 'night', 'classic']
for n in BACKS:
    P = backdrop(n)
    d = packbits(bitmap_to_bytes(P))
    L.append("bd_%s: ; %d bytes" % (n, len(d)))
    db(d)
    save_preview(P, "back_%s.png" % n)

# ---------------------------------------------------------------- tables
L.append("    align 256")
L.append("rowlo: ; low byte of row*32 for screen rows 0..63")
db([(y * 32) & 255 for y in range(64)])
L.append("rowhi:")
db([(y * 32) >> 8 for y in range(64)])
L.append("blinds: ; commit order (8 interleaved passes)")
db([p + 8 * k for p in range(8) for k in range(8)])
L.append("pixtab: ; masks to clear pixel n of a byte")
db([0x3F, 0xCF, 0xF3, 0xFC])

exec(open(os.path.join(HERE, "pics.py")).read())
exec(open(os.path.join(HERE, "music.py")).read())

open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT, "frames:", len(FRAMES), "framework bytes:", tot)
