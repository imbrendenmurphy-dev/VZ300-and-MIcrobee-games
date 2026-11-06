#!/usr/bin/env python3
"""KAMIKAZE INVADERS 2 data generator -> data.inc
font, sprites, mothership images, column/ground tiles, sector tables,
title art (title_art.py) and music (music.py). Writes previews to ../build/preview/.
Font and helpers carried over from PENGUIN 2."""
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


def save_preview(pix, name, css=1):
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
    '$': [".#.", "###", "###", "###", ".#."],
    '\\': ["#..", "#..", ".#.", "..#", "..#"],
}
FONT['['] = ["...", "...", ".#.", "###", "#.#"]   # ship (lives) icon
FONT[']'] = ["#.#", "###", "#.#", "###", "#.#"]   # kamikaze icon
FONT['@'] = ["...", ".#.", "#.#", ".#.", "..."]   # mothership-cargo icon
L.append("; ---- 3x5 font, ASCII 32..95, 5 bytes/glyph, bit2 = left pixel")
L.append("font3:")
for c in range(32, 96):
    g = FONT.get(chr(c), FONT[' '])
    db([int(r.replace('#', '1').replace('.', '0'), 2) for r in g])


# ---------------------------------------------------------------- sprites
# Sprite colours: '.' transparent (= colour 2, the space background),
# 'g' colour 0 (green / buff), 'y' colour 1 (yellow / cyan), 'r' colour 3 (red / orange).
# The engine treats colour 2 as transparent, so space (colour 2) shows through.
CM = {'.': 2, 'g': 0, 'y': 1, 'r': 3}
TM = {'.': 2, 'b': 2, 'g': 0, 'y': 1, 'r': 3}
SPR = []


def S(name, art):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    SPR.append((name, rows))
    return rows


S("SHIP", """
...r...
..yyy..
.yygyy.
yyyyyyy
r.y.y.r
""")
S("SHIPG", """
...g...
..ggg..
.ggrgg.
ggggggg
g.g.g.g
""")
S("SHIPX0", """
.r.y.r..
..ryr...
.yyryy..
r.yyy.r.
..r.r...
""")
S("SHIPX1", """
r..y..r.
..r.r...
.y...y..
..r.r...
r..y..r.
""")
S("SHIPX2", """
y.....y.
...r....
.r...r..
....r...
y..r..y.
""")
S("SHOT", """
y
y
r
""")
S("SHOTR", """
g
y
y
r
""")
# kamikazes (7x5), two leg frames each
S("GRUNT0", """
y.....y
.yrrry.
.rgrgr.
..rrr..
.y.y.y.
""")
S("GRUNT1", """
.y...y.
.yrrry.
.rgrgr.
..rrr..
y..y..y
""")
S("ARMOR0", """
y.....y
yyyyyyy
yrgrgry
.yyyyy.
.y.y.y.
""")
S("ARMOR1", """
.y...y.
yyyyyyy
yrgrgry
.yyyyy.
y..y..y
""")
S("CRACK0", """
y.....y
yy.yy.y
yrgrgr.
.y.yy..
.y.y.y.
""")
S("CRACK1", """
.y...y.
yy.yy.y
yrgrgr.
.y.yy..
y..y..y
""")
S("ZIG0", """
r.....r
rr.y.rr
.ryyyr.
..ygy..
...r...
""")
S("ZIG1", """
.......
r..y..r
rryyyrr
..ygy..
...r...
""")
S("SPARK0", """
.y.y.y.
..ggg..
.gryrg.
..ggg..
.y.y.y.
""")
S("SPARK1", """
y.y.y.y
..ggg..
.gyryg.
..ggg..
y.y.y.y
""")
# warning flash for a column's bottom kamikaze that is about to be pushed out
S("WARN", """
g.....g
.ggggg.
.grgrg.
..ggg..
.g.g.g.
""")
S("POP0", """
..y.y..
.y.r.y.
..rgr..
.y.r.y.
..y.y..
""")
S("POP1", """
y..r..y
.......
r..g..r
.......
y..r..y
""")
S("BOMB0", """
..yyy..
.rrrrr.
rrryrrr
rrrrrrr
.rrrrr.
..g.g..
""")
S("BOMB1", """
..ggg..
.rrrrr.
rrrgrrr
rrrrrrr
.rrrrr.
..y.y..
""")
S("CAPT", """
.yyyyy.
yrgggry
yrrgrry
yrrgrry
.yyyyy.
""")
S("CAPR", """
.yyyyy.
yrggrry
yrggrry
yrgrgry
.yyyyy.
""")
S("CAPS", """
.yyyyy.
yrrggry
yrrgrry
yrggrry
.yyyyy.
""")
S("CAPN", """
.yyyyy.
yrgrgry
yrgggry
yrgrgry
.yyyyy.
""")
S("ARROW", """
...y...
..yyy..
.y.y.y.
...y...
...y...
""")
# big sprites for the title and pages
BIG = []


def B(name, art):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    BIG.append((name, rows))
    return rows


B("BIGK0", """
yy........yy
..y......y..
..yyrrrryy..
.rrrrrrrrrr.
rrggrrrrggrr
rrggrrrrggrr
.rrrrrrrrrr.
..rrryyrrr..
.y.y.yy.y.y.
y..y....y..y
""")
B("BIGK1", """
..y......y..
..y......y..
..yyrrrryy..
.rrrrrrrrrr.
rrggrrrrggrr
rrggrrrrggrr
.rrrrrrrrrr.
..rrryyrrr..
y.y.y..y.y.y
.y..y..y..y.
""")
ALL = SPR + BIG
L.append("; ---- sprites: table of (src ptr, src width bytes, height)")
for i, (n, rows) in enumerate(ALL):
    L.append("SPR_%s equ %d" % (n, i))
L.append("NSPR equ %d" % len(ALL))
tot = 0
for n, rows in ALL:
    w = max(len(r) for r in rows); sw = (w + 3) // 4
    tot += (sw + 1) * len(rows) * 4 * 2
L.append("SHIFTSIZE equ %d" % tot)
L.append("sprtab:")
for n, rows in ALL:
    w = max(len(r) for r in rows); sw = (w + 3) // 4
    L.append("    dw spr_%s\n    db %d,%d" % (n, sw, len(rows)))
for n, rows in ALL:
    w = max(len(r) for r in rows); sw = (w + 3) // 4
    L.append("spr_%s:" % n)
    data = []
    for r in rows:
        r = r.ljust(sw * 4, '.')
        dv = 0
        for c in r:
            dv = (dv << 2) | CM[c]
        data += [(dv >> (8 * (sw - 1 - k))) & 255 for k in range(sw)]
    db(data)
cw, ch, cols = 16, 12, 10
sheet = [[2] * (cw * cols) for _ in range(ch * ((len(ALL) + cols - 1) // cols))]
for i, (n, rows) in enumerate(ALL):
    ox = (i % cols) * cw + 1; oy = (i // cols) * ch + 1
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            sheet[oy + y][ox + x] = CM[c]
save_preview(sheet, "sprites_css0.png", css=0)
save_preview(sheet, "sprites_css1.png", css=1)

# ---------------------------------------------------------------- mothership (BG blits)
# 24x7 hull, pre-shifted 0..3 px into 9-byte-wide opaque images (1 byte of
# space each side so a 1-pixel move fully repaints the old position).
HULL = [
    "...rrrryyyyyyyyyyyrrrr..",
    ".rrrrrryggggggggg yrrrrr.".replace(' ', ''),
    "rryryrryggggggggg yryryrr".replace(' ', ''),
    "ryyyyyryggggggggg yryyyyr".replace(' ', ''),
    "rryryrryggggggggg yryryrr".replace(' ', ''),
    ".rrrrrryggggggggg yrrrrr.".replace(' ', ''),
    "...r.r.yyyyyyyyyyy.r.r..",
]
CORE0 = [r[:8] + m + r[17:] for r, m in zip(HULL, [
    "yyyyyyyyy"[:9], "ggggrgggg", "ggrryrrgg", "grryyyrrg", "ggrryrrgg", "ggggrgggg", "yyyyyyyyy"])]
CORE1 = [r[:8] + m + r[17:] for r, m in zip(HULL, [
    "yyyyyyyyy", "grgggggrg", "gggrrrggg", "ggrrgrrgg", "gggrrrggg", "grgggggrg", "yyyyyyyyy"])]
# fix: the box border is cols 7..17; CORE rows replace cols 8..16
CORE0 = [h[:8] + c[8:17] + h[17:] for h, c in zip(HULL, CORE0)]
CORE1 = [h[:8] + c[8:17] + h[17:] for h, c in zip(HULL, CORE1)]
for img in (HULL, CORE0, CORE1):
    for r in img:
        assert len(r) == 24, (len(r), r)


def shifted(img, s):
    out = []
    for r in img:
        px = [2] * 36
        for i, c in enumerate(r):
            px[4 + s + i] = TM[c]
        for b in range(9):
            v = 0
            for k in range(4):
                v = (v << 2) | px[b * 4 + k]
            out.append(v)
    return out


for nm, img in (("hull", HULL), ("core0", CORE0), ("core1", CORE1)):
    L.append("ms_%s:" % nm)
    for s in range(4):
        db(shifted(img, s), per=9)
prev = [[2] * 40 for _ in range(26)]
for k, img in enumerate((HULL, CORE0, CORE1)):
    for y, r in enumerate(img):
        for x, c in enumerate(r):
            prev[1 + k * 8 + y][8 + x] = TM[c]
save_preview(prev, "mothership.png", css=0)

# ---------------------------------------------------------------- blast bolt bytes (5 rows x 2 frames x 4 phases)
import random
random.seed(77)
bolt = []
for f in range(8):
    rows = []
    for y in range(5):
        v = 0
        for k in range(4):
            on = random.random() < (0.55 if y in (1, 2, 3) else 0.3)
            c = random.choice((0, 1, 1, 3)) if on else 2
            v = (v << 2) | c
        rows.append(v)
    bolt += rows
L.append("bolttab:     ; 8 frames x 5 rows")
db(bolt, per=5)

# ---------------------------------------------------------------- sector tables
# per sector: css flag, rail colour, rail style, ground colours, name
SECTORS = [
    ("OUTER RIM", 0, 1, 0),
    ("ION STORM", 1, 1, 1),
    ("RED NEBULA", 0, 3, 2),
    ("THE HIVE", 1, 3, 3),
]
L.append("sec_css: db " + ",".join(str(s[1] * 16) for s in SECTORS))
L.append("sec_rail: db " + ",".join(str(s[2]) for s in SECTORS))
L.append("sec_style: db " + ",".join(str(s[3]) for s in SECTORS))
L.append("sec_names: dw " + ",".join("secn%d" % i for i in range(4)))
for i, s in enumerate(SECTORS):
    L.append('secn%d: db "%s",0' % (i, s[0]))
# column slot x positions (left edge of a 7-wide kamikaze)
COLX = [6 + 10 * k for k in range(5)] + [76 + 10 * k for k in range(5)]
RAILX = [4 + 10 * k for k in range(6)] + [74 + 10 * k for k in range(6)]
L.append("colx: db " + ",".join(map(str, COLX)))
L.append("railx: db " + ",".join(map(str, RAILX)))
# per column: first byte, byte count of the 7-px slot
L.append("colb: db " + ",".join("%d,%d" % (x >> 2, ((x + 6) >> 2) - (x >> 2) + 1) for x in COLX))
# zig-zag sideways offsets (signed, 32 steps)
import math
L.append("zigtab: db " + ",".join(str(int(round(5 * math.sin(i / 32 * 6.2832))) & 255) for i in range(32)))

# ---------------------------------------------------------------- title art + music
exec(open(os.path.join(HERE, "title_art.py")).read())
exec(open(os.path.join(HERE, "music.py")).read())

L.append("    align 256")
L.append("rowaddr:")      # VRAM row address for pixel rows 0..63
L.append("    dw " + ",".join("$%04X" % (0x7000 + y * 32) for y in range(64)))
open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT, "sprites:", len(ALL))
