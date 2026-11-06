#!/usr/bin/env python3
"""PANIK 2 data generator -> data.inc
font, sprites, girder/ladder tiles, world backdrops, stage layouts,
title art (title_art.py) and music (music.py).
Also checks every stage layout and writes previews into ../build/preview/ ."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "data.inc")
PREV = os.path.join(HERE, "..", "build", "preview")
os.makedirs(PREV, exist_ok=True)
CSS0 = [(7, 255, 0), (255, 255, 0), (59, 8, 255), (204, 0, 59)]
CSS1 = [(255, 255, 255), (7, 227, 153), (255, 28, 255), (255, 129, 0)]
L = []


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


def bitmap_to_bytes(pix):
    out = []
    for y in range(len(pix)):
        for bx in range(32):
            v = 0
            for k in range(4):
                v = (v << 2) | (pix[y][bx * 4 + k] & 3)
            out.append(v)
    return out


def save_preview(pix, name, css=0):
    pal = CSS0 if css == 0 else CSS1
    w = len(pix[0]); h = len(pix)
    im = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            im.putpixel((x, y), pal[pix[y][x]])
    im.resize((w * 4, h * 6), Image.NEAREST).save(os.path.join(PREV, name))


# ---------------------------------------------------------------- 3x5 font
FONT = {
    ' ': ["...", "...", "...", "...", "..."],
    '0': ["###", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", "###"],
    '2': ["###", "..#", "###", "#..", "###"], '3': ["###", "..#", ".##", "..#", "###"],
    '4': ["#.#", "#.#", "###", "..#", "..#"], '5': ["###", "#..", "###", "..#", "###"],
    '6': ["###", "#..", "###", "#.#", "###"], '7': ["###", "..#", ".#.", ".#.", ".#."],
    '8': ["###", "#.#", "###", "#.#", "###"], '9': ["###", "#.#", "###", "..#", "###"],
    'A': [".#.", "#.#", "###", "#.#", "#.#"], 'B': ["##.", "#.#", "##.", "#.#", "##."],
    'C': [".##", "#..", "#..", "#..", ".##"], 'D': ["##.", "#.#", "#.#", "#.#", "##."],
    'E': ["###", "#..", "##.", "#..", "###"], 'F': ["###", "#..", "##.", "#..", "#.."],
    'G': [".##", "#..", "#.#", "#.#", ".##"], 'H': ["#.#", "#.#", "###", "#.#", "#.#"],
    'I': ["###", ".#.", ".#.", ".#.", "###"], 'J': ["..#", "..#", "..#", "#.#", ".#."],
    'K': ["#.#", "#.#", "##.", "#.#", "#.#"], 'L': ["#..", "#..", "#..", "#..", "###"],
    'M': ["#.#", "###", "###", "#.#", "#.#"], 'N': ["##.", "#.#", "#.#", "#.#", "#.#"],
    'O': [".#.", "#.#", "#.#", "#.#", ".#."], 'P': ["##.", "#.#", "##.", "#..", "#.."],
    'Q': [".#.", "#.#", "#.#", "##.", ".##"], 'R': ["##.", "#.#", "##.", "#.#", "#.#"],
    'S': [".##", "#..", ".#.", "..#", "##."], 'T': ["###", ".#.", ".#.", ".#.", ".#."],
    'U': ["#.#", "#.#", "#.#", "#.#", "###"], 'V': ["#.#", "#.#", "#.#", "#.#", ".#."],
    'W': ["#.#", "#.#", "###", "###", "#.#"], 'X': ["#.#", "#.#", ".#.", "#.#", "#.#"],
    'Y': ["#.#", "#.#", ".#.", ".#.", ".#."], 'Z': ["###", "..#", ".#.", "#..", "###"],
    '!': [".#.", ".#.", ".#.", "...", ".#."], '?': ["##.", "..#", ".#.", "...", ".#."],
    '.': ["...", "...", "...", "...", ".#."], ',': ["...", "...", "...", ".#.", "#.."],
    ':': ["...", ".#.", "...", ".#.", "..."], '-': ["...", "...", "###", "...", "..."],
    '+': ["...", ".#.", "###", ".#.", "..."], '/': ["..#", "..#", ".#.", "#..", "#.."],
    "'": [".#.", ".#.", "...", "...", "..."], '&': [".#.", "#.#", ".#.", "#.#", ".##"],
    '=': ["...", "###", "...", "###", "..."], '<': ["..#", ".#.", "#..", ".#.", "..#"],
    '>': ["#..", ".#.", "..#", ".#.", "#.."], '*': ["#.#", ".#.", "###", ".#.", "#.#"],
    '(': [".#.", "#..", "#..", "#..", ".#."], ')': [".#.", "..#", "..#", "..#", ".#."],
    '"': ["#.#", "#.#", "...", "...", "..."], '#': ["#.#", "###", "#.#", "###", "#.#"],
    '^': [".#.", "###", "...", "...", "..."], '_': ["...", "...", "...", "...", "###"],
    '%': ["#.#", "..#", ".#.", "#..", "#.#"], ';': ["...", ".#.", "...", ".#.", "#.."],
    '\\': ["#..", "#..", ".#.", "..#", "..#"],
}
FONT['['] = [".#.", "###", ".#.", "###", "#.#"]   # digger (lives) icon
FONT[']'] = [".#.", "###", "#.#", "###", "#.#"]   # alien icon
FONT['$'] = [".#.", "#.#", "###", "#.#", ".#."]   # gem icon
FONT['@'] = ["###", "#.#", "#.#", "#.#", "###"]   # O2 bubble
L.append("; ---- 3x5 font, ASCII 32..95, 5 bytes/glyph, bit2 = left pixel")
L.append("font3:")
for c in range(32, 96):
    g = FONT.get(chr(c), FONT[' '])
    db([int(r.replace('#', '1').replace('.', '0'), 2) for r in g])

# ---------------------------------------------------------------- sprites
# colours by index: '.' transparent, 'y' 1, 'b' 2, 'r' 3
# (CSS0: yellow / blue / red on green.  CSS1: cyan / magenta / orange on buff)
CM = {'.': None, 'y': 1, 'b': 2, 'r': 3}
SPR = []


def S(name, art):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    assert all(len(r) == 8 for r in rows), (name, rows)
    SPR.append((name, rows))
    return rows


def mirror(rows):
    return [r[::-1] for r in rows]


def recol(rows, m):
    return ["".join(m.get(c, c) for c in r) for r in rows]


def SM(name, rows):
    SPR.append((name, mirror(rows)))


# --- the digger: red helmet, yellow face, blue overalls, red boots, shovel
DR0 = S("DR0", """
..rrr...
.rrrrr..
..yyby..
...yy..y
.bbbbbby
.b.bbb.y
..b..b.y
.rr..rry
""")
DR1 = S("DR1", """
..rrr...
.rrrrr..
..yyby..
...yy..y
.bbbbbby
.b.bbb.y
...bb..y
...rrr.y
""")
SM("DL0", DR0)
SM("DL1", DR1)
DC0 = S("DC0", """
y.rrr..y
y.rrrr.y
yyrrrryy
y.bbbb.y
yybbbbyy
y.bbbb.y
yyb..byy
y.r..r.y
""")
S("DC1", """
y.rrr..y
y.rrrr.y
yyrrrryy
y.bbbb.y
yybbbbyy
y.bbbb.y
yyb..byy
y.r..r.y
""".replace("y.r..r.y", "y..rr..y").replace("yyb..byy", "yy.bb.yy"))
DG0 = S("DG0", """
..rrr.y.
.rrrrry.
..yyby..
...yyy..
.bbbbbb.
.b.bbb..
..b..b..
.rr..rr.
""")
DG1 = S("DG1", """
..rrr...
.rrrrr..
..yyby..
...yy...
.bbbbbb.
.b.bbbby
..b..b.y
.rr..ryy
""")
SM("DGL0", DG0)
SM("DGL1", DG1)
S("DDIE0", """
y.rrr..y
.yrrrry.
..yyyy..
..ybby..
.bbbbbb.
..bbbb..
..b..b..
.rr..rr.
""")
S("DDIE1", """
........
........
........
.yyy....
yrrby.r.
rrrbbbbr
.y.bbbbr
........
""")
S("DDIE2", """
........
.y.y.y..
..yyy...
........
........
........
rrrbbbbr
rbbbbbbr
""")
S("DWIN0", """
y.rrr..y
y.rrrr.y
.yyyyyy.
..y..y..
..bbbb..
..bbbb..
..b..b..
.rr..rr.
""")
S("DWIN1", """
..rrr...
y.rrrr.y
.yyyyyy.
..y..y..
..bbbb..
..bbbb..
.b....b.
rr....rr
""")
# --- aliens.  GRUB (the original's little blue alien), BRUTE, KING
G0 = S("GRUB0", """
...bb...
..bbbb..
.bybbyb.
.bbbbbb.
bbbbbbbb
.bbbbbb.
.r.rr.r.
r..rr..r
""")
G1 = S("GRUB1", """
...bb...
..bbbb..
.bybbyb.
.bbbbbb.
bbbbbbbb
.bbbbbb.
..r..r..
.rr..rr.
""")
B0 = S("BRUTE0", """
r......r
rr.rr.rr
.rrrrrr.
rryrryrr
rrrrrrrr
.rbbbbr.
.rr..rr.
rr....rr
""")
B1 = S("BRUTE1", """
r......r
rr.rr.rr
.rrrrrr.
rryrryrr
rrrrrrrr
.rbbbbr.
..rrrr..
.rr..rr.
""")
K0 = S("KING0", """
y.y..y.y
yyyyyyyy
.yyyyyy.
yryyyyry
yyyyyyyy
.yrrrry.
.yy..yy.
yy....yy
""")
K1 = S("KING1", """
y.y..y.y
yyyyyyyy
.yyyyyy.
yryyyyry
yyyyyyyy
.yrrrry.
..yyyy..
.yy..yy.
""")
# angry versions (escaped from a hole): colours swapped
S("GRUBA0", "\n".join(recol(G0, {'b': 'r', 'r': 'b'})))
S("GRUBA1", "\n".join(recol(G1, {'b': 'r', 'r': 'b'})))
S("BRUTEA0", "\n".join(recol(B0, {'r': 'y', 'y': 'r'})))
S("BRUTEA1", "\n".join(recol(B1, {'r': 'y', 'y': 'r'})))
S("KINGA0", "\n".join(recol(K0, {'y': 'r', 'r': 'y'})))
S("KINGA1", "\n".join(recol(K1, {'y': 'r', 'r': 'y'})))
# alien squashed / exploding
S("SPLAT", """
........
........
........
.y....y.
..y..y..
y..yy..y
.bbbbbb.
bbbbbbbb
""")
# materialise sparkle
S("SPARK0", """
........
...y....
...y....
.yy.yy..
...y....
...y....
........
........
""")
S("SPARK1", """
y..y..y.
.y.y.y..
..y.y...
yy.r.yy.
..y.y...
.y.y.y..
y..y..y.
........
""")
# pickups
S("ITO2", """
...rr...
..bbbb..
.byybbb.
.by.ybb.
.byybbb.
.bbbbbb.
..bbbb..
........
""")
S("ITBOOT", """
........
..rr....
..rr....
..rr....
..rrrr..
.rrrrrr.
.yyyyyy.
........
""")
S("ITDRILL", """
........
.bbbb...
bbbbbyy.
bbbbbyyy
bbbbbyy.
.bbbb...
..r.....
........
""")
S("ITFREEZ", """
...b....
.b.b.b..
..bbb...
bbbybbb.
..bbb...
.b.b.b..
...b....
........
""")
S("ITGEM", """
........
..yyyy..
.yrryry.
yrrrrrry
.yrrrry.
..yrry..
...yy...
........
""")
S("CURSOR", """
...r....
..rrr...
.rrrrr..
...r....
...r....
........
........
........
""")
L.append("; ---- sprites: table of (src ptr, src width bytes, height)")
for i, (n, rows) in enumerate(SPR):
    L.append("SPR_%s equ %d" % (n, i))
L.append("NSPR equ %d" % len(SPR))
tot = 0
for n, rows in SPR:
    tot += 3 * len(rows) * 4 * 2
L.append("SHIFTSIZE equ %d" % tot)
L.append("sprtab:")
for n, rows in SPR:
    L.append("    dw spr_%s\n    db 2,%d" % (n, len(rows)))
for n, rows in SPR:
    L.append("spr_%s:" % n)
    data = []
    for r in rows:
        dv = 0
        for c in r:
            col = CM[c]
            dv = (dv << 2) | (0 if col is None else col)
        data += [dv >> 8, dv & 255]
    db(data)
cw, ch, cols = 10, 10, 12
sheet = [[0] * (cw * cols) for _ in range(ch * ((len(SPR) + cols - 1) // cols))]
for i, (n, rows) in enumerate(SPR):
    ox = (i % cols) * cw + 1; oy = (i // cols) * ch + 1
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if CM[c] is not None:
                sheet[oy + y][ox + x] = CM[c]
save_preview(sheet, "sprites_css0.png", 0)
save_preview(sheet, "sprites_css1.png", 1)

# ---------------------------------------------------------------- worlds
# per world: css flag, girder tile (3 rows x 8), steel tile, ladder colour,
# backdrop generator.  Floors: girder tops at rows 17,28,39,50,61.
GTOP = [17, 28, 39, 50, 61]
WORLDS = [
    # name, css, girder, steel, ladder colour, hud fg, hud bg
    ("SPACE STATION", 0, ["11111111", "22222211", "11111111"], ["22222222", "21122112", "22222222"], 1),
    ("MOON BASE", 1, ["11111111", "21212121", "22222222"], ["33333333", "31133113", "33333333"], 3),
    ("MARS MINES", 0, ["33333333", "31333133", "33333333"], ["22222222", "21122112", "22222222"], 1),
    ("MOTHERSHIP", 1, ["22222222", "23322332", "22222222"], ["11111111", "13311331", "11111111"], 1),
]


def rowbytes(s):
    v = 0
    for c in s:
        v = (v << 2) | int(c)
    return [v >> 8, v & 255]


L.append("; ---- per world: girder(6) steel(6) rails(2) rung(2) css(1) ladder colour(1) = 18")
L.append("worldtab:")
for name, css, gird, steel, lc in WORLDS:
    d = []
    for r in gird:
        d += rowbytes(r)
    for r in steel:
        d += rowbytes(r)
    d += rowbytes("".join(str(lc) if c == '#' else '0' for c in ".#....#."))  # rails
    d += rowbytes("".join(str(lc) if c == '#' else '0' for c in ".######."))  # rung
    d += [css, lc]
    db(d)
L.append("worldnames:")
for i, w in enumerate(WORLDS):
    L.append("    dw wn%d" % i)
for i, w in enumerate(WORLDS):
    L.append('wn%d: db "%s",0' % (i, w[0]))

import random
random.seed(1983)


def backdrop(wi):
    """sparse decoration in the free rows (never on girders)."""
    pix = [[0] * 128 for _ in range(64)]
    free = set(range(6, 64)) - set(r for g in GTOP for r in (g, g + 1, g + 2))

    def put(x, y, c):
        if 0 <= x < 128 and y in free:
            pix[y][x] = c
    if wi == 0:     # station: porthole windows with stars, wall rivets
        for fl in range(5):
            top = GTOP[fl] - 11 if fl else 6
            for wx in range(10, 128, 32):
                x0 = wx + (fl * 7) % 13
                y0 = GTOP[fl] - 8
                for dy in range(5):
                    for dx in range(7):
                        e = dy in (0, 4) or dx in (0, 6)
                        if e and not ((dy in (0, 4)) and (dx in (0, 6))):
                            put(x0 + dx, y0 + dy, 2)
                put(x0 + 2 + fl % 3, y0 + 2, 1)
            for rx in range(4, 128, 16):
                put(rx, GTOP[fl] - 2, 2)
    elif wi == 1:   # moon: starfield, distant earth, craters on the ground line
        for _ in range(70):
            x = random.randrange(128); y = random.randrange(6, 60)
            put(x, y, 1 if random.random() < 0.7 else 2)
        for dy in range(-3, 4):
            for dx in range(-4, 5):
                if dx * dx / 16 + dy * dy / 9 <= 1:
                    put(108 + dx, 11 + dy, 1 if (dx + dy) % 3 else 3)
    elif wi == 2:   # mars: rock speckle and stalactites under the girders
        for fl in range(4):
            for x in range(0, 128):
                if random.random() < 0.18:
                    ln = random.choice((1, 1, 2, 3))
                    for k in range(ln):
                        put(x, GTOP[fl] + 3 + k, 3 if k == 0 else 2)
        for _ in range(60):
            x = random.randrange(128); y = random.randrange(6, 60)
            put(x, y, 2)
    else:           # mothership: faint circuit lines and lights
        for fl in range(5):
            y = GTOP[fl] - 6
            for x in range(0, 128):
                if (x // 6) % 3 == 0:
                    put(x, y, 1)
            for x in range(3, 128, 12):
                put(x, y - 1, 3)
                put(x, y + 1, 3)
    return pix


for wi in range(4):
    pix = backdrop(wi)
    pk = packbits(bitmap_to_bytes(pix))
    L.append("; backdrop %d: %d bytes packed" % (wi, len(pk)))
    L.append("backdrop%d:" % wi)
    db(pk)
L.append("backdrops: dw backdrop0,backdrop1,backdrop2,backdrop3")

# ---------------------------------------------------------------- stages
# Each stage: 4 floor rows (floors 0-3; floor 4 is bedrock) and 4 ladder rows
# (between floor k and k+1).  16 slots of 8 px.
#   floors: '-' girder  '=' steel (can't dig)  '*' buried gem (bonus rounds)
#   ladders: 'H'
# params: name, grubs, brutes, kings, max on screen, speed (1/256 px/frame),
#         oxygen ticks (frames per O2 unit, 96 units), kind (0 normal 1 gem dig)
STAGES = [
 ("DOCKING BAY", 4, 0, 0, 3, 96, 60, 0, """
----------------
.H......H.....H.
----------------
...H.......H....
----------------
.H....H.......H.
----------------
....H......H....
"""),
 ("CARGO HOLD", 5, 0, 0, 3, 104, 58, 0, """
----------------
...H.....H....H.
----------------
.H....H......H..
----------------
....H.....H.....
----------------
.H......H.....H.
"""),
 ("REACTOR RING", 4, 1, 0, 4, 108, 56, 0, """
----------------
.H.....HH.....H.
----------------
....H......H....
----------------
..H....H....H...
----------------
.....H....H.....
"""),
 ("THE BRIDGE", 5, 2, 0, 4, 112, 54, 0, """
----------------
H......H......H.
----------------
..H...H...H.....
----------------
.....H.....H..H.
----------------
.H.....H.....H..
"""),
 ("GEM DIG 1", 0, 0, 0, 0, 0, 18, 1, """
--*----*----*---
.H......H.....H.
-*-----*------*-
...H.......H....
----*-----*-----
.H....H.......H.
-*------*-----*-
....H......H....
"""),
 ("TRANQUILITY", 5, 1, 0, 4, 112, 54, 0, """
-----===--------
.H.......H....H.
----------------
....H.....H.....
---===----------
.H.....H......H.
----------===---
...H.......H....
"""),
 ("CRATER COLONY", 4, 2, 0, 4, 116, 52, 0, """
----------------
..H.....H.....H.
--===-----===---
H.....H......H..
----------------
...H.....H....H.
-====-----------
.H.......H......
"""),
 ("LOW GRAVITY", 5, 2, 1, 4, 116, 52, 0, """
----------------
.H....H....H....
----===---------
...H......H...H.
----------===---
H.....H.....H...
----------------
...H.....H....H.
"""),
 ("DARK SIDE", 4, 3, 1, 5, 120, 50, 0, """
-===--------===-
.....H....H.....
----------------
.H.......H....H.
------====------
...H...H....H...
----------------
.H.....H......H.
"""),
 ("GEM DIG 2", 0, 0, 0, 0, 0, 18, 1, """
-*----===----*--
.....H....H.....
---*------*---*-
.H.......H....H.
*-----====----*-
...H...H....H...
----*-----*-----
.H.....H......H.
"""),
 ("RED DUST", 5, 2, 1, 5, 120, 50, 0, """
----------------
.H.....H....H...
---====---------
...H.....H....H.
----------------
H.....H.....H...
--------===-----
..H.....H.....H.
"""),
 ("THE DEEP SHAFT", 4, 3, 1, 5, 124, 48, 0, """
----------------
.......H........
-=====--------==
..H....H....H...
----------------
.......H........
==--------=====-
..H....H....H...
"""),
 ("OLYMPUS DIG", 5, 2, 2, 5, 128, 48, 0, """
---==------==---
.H....H....H..H.
----------------
...H.....H......
-==----==----==-
.H...H.....H..H.
----------------
....H....H....H.
"""),
 ("CANYON RUN", 4, 3, 2, 5, 132, 46, 0, """
-------==-------
H...H.....H...H.
----------------
..H....H....H...
===----------===
.H....H....H....
----------------
...H....H.....H.
"""),
 ("GEM DIG 3", 0, 0, 0, 0, 0, 16, 1, """
*------*------*-
H...H.....H...H.
--*----==---*---
..H....H....H...
===--*----*--===
.H....H....H....
-*----*----*----
...H....H.....H.
"""),
 ("THE HANGAR", 5, 3, 1, 5, 132, 46, 0, """
----------------
.H....H.....H...
--====----====--
....H....H....H.
----------------
.H.....H....H...
---===----===---
....H.....H...H.
"""),
 ("ENGINE ROOM", 4, 3, 2, 5, 136, 44, 0, """
-==------------
H.....H.....H...
----------------
...H.....H....H.
-----======-----
.H.....H......H.
----------------
...H.....H..H...
"""),
 ("HIVE", 4, 4, 2, 5, 140, 44, 0, """
----===--===----
..H.....H.....H.
----------------
H....H....H.....
---==------==---
..H....H.....H..
----------------
H....H.....H...H
"""),
 ("THE QUEEN'S LAIR", 3, 4, 3, 5, 144, 42, 0, """
-===--------===-
H......HH......H
----------------
..H..H....H..H..
--====----====--
H......HH......H
----------------
..H..H....H..H..
"""),
 ("GEM DIG 4", 0, 0, 0, 0, 0, 14, 1, """
-*---*----*---*-
H......HH......H
--*----==----*--
..H..H....H..H..
*-====----====-*
H......HH......H
---*---*--*---*-
..H..H....H..H..
"""),
]
NLEVELS = len(STAGES)
L.append("NLEVELS equ %d" % NLEVELS)
# stage record: name ptr(2), grubs, brutes, kings, maxact, speed, o2tick, kind,
#               pad, floors 4x16 (0 girder 1 steel 2 gem), ladders 4x16 (0/1)
L.append("stagetab:")
for i in range(NLEVELS):
    L.append("    dw stage%d" % i)
for i, (name, ng, nb, nk, mx, sp, o2, kind, lay) in enumerate(STAGES):
    rows = [r for r in lay.strip("\n").split("\n")]
    assert len(rows) == 8, name
    for r in rows:
        assert len(r) == 16 or len(r) == 15, (name, r)
    rows = [r.ljust(16, r[-1] if r[-1] in "-=" else '.') for r in rows]
    floors = [list(r) for r in rows[0::2]]; lads = rows[1::2]

    def ladder_end(k, s):
        return (k < 4 and lads[k][s] == 'H') or (k > 0 and lads[k - 1][s] == 'H')
    # checks: every ladder row has a ladder; a buried gem never sits where a
    # ladder ends (those slots can't be dug) - such gems move to the nearest
    # diggable slot on the same floor
    for k, lr in enumerate(lads):
        assert 'H' in lr, (name, "no ladder between floors", k, k + 1)
    for k in range(4):
        for s in range(16):
            if floors[k][s] == '*' and ladder_end(k, s):
                floors[k][s] = '-'
                for d in (1, -1, 2, -2, 3, -3, 4, -4):
                    t = s + d
                    if 0 <= t < 16 and floors[k][t] == '-' and not ladder_end(k, t):
                        floors[k][t] = '*'
                        break
                else:
                    raise AssertionError((name, "no room for gem", k, s))
    floors = ["".join(r) for r in floors]
    if kind == 1:
        print("  %s: %d gems" % (name, sum(r.count('*') for r in floors)))
    assert sp <= 256 and mx <= 5
    if kind == 0:
        assert ng + nb + nk <= 16
    L.append("stage%d:" % i)
    L.append("    dw sname%d" % i)
    db([ng, nb, nk, mx, sp & 255, o2, kind, sp >> 8])
    fl = []
    for r in floors:
        fl += [{'-': 0, '=': 1, '*': 2}[c] for c in r]
    db(fl)
    ld = []
    for r in lads:
        ld += [1 if c == 'H' else 0 for c in r]
    db(ld)
    L.append('sname%d: db "%s",0' % (i, name))
    # preview
    wi = min(i // 5, 3)
    pix = backdrop(wi)
    wname, css, gird, steel, lc = WORLDS[wi]
    for k in range(5):
        for s in range(16):
            t = gird
            if k < 4 and floors[k][s] == '=':
                t = steel
            for j in range(3):
                for x in range(8):
                    pix[GTOP[k] + j][s * 8 + x] = int(t[j][x])
            if k < 4 and floors[k][s] == '*':
                pix[GTOP[k] + 1][s * 8 + 3] = 3
                pix[GTOP[k] + 1][s * 8 + 4] = 3
    for k in range(4):
        for s in range(16):
            if lads[k][s] == 'H':
                for y in range(GTOP[k] - 3, GTOP[k + 1]):
                    for x in (1, 6):
                        pix[y][s * 8 + x] = lc
                    if (y - GTOP[k]) % 3 == 1:
                        for x in range(1, 7):
                            pix[y][s * 8 + x] = lc
    save_preview(pix, "stage_%02d.png" % (i + 1), css)

# ---------------------------------------------------------------- title art + music
exec(open(os.path.join(HERE, "title_art.py")).read())
exec(open(os.path.join(HERE, "music.py")).read())

L.append("    align 256")
L.append("rowaddr:")      # VRAM row address for pixel rows 0..63 (low/high)
L.append("    dw " + ",".join("$%04X" % (0x7000 + y * 32) for y in range(64)))
open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT, "sprites:", len(SPR), "stages:", NLEVELS)
