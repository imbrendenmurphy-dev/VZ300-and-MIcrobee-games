#!/usr/bin/env python3
"""PENGUIN 2 data generator -> data.inc
font, sprites, cell tiles, levels, title art (title_art.py), music (music.py).
Also writes preview PNGs into ../build/preview/ ."""
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
FONT['['] = [".#.", "###", "#.#", "###", "#.#"]   # penguin (lives) icon
FONT[']'] = [".#.", "###", "###", "###", ".#."]   # egg icon
FONT['@'] = [".#.", "#.#", "#.#", "##.", ".#."]   # clock-ish icon
L.append("; ---- 3x5 font, ASCII 32..95, 5 bytes/glyph, bit2 = left pixel")
L.append("font3:")
for c in range(32, 96):
    g = FONT.get(chr(c), FONT[' '])
    db([int(r.replace('#', '1').replace('.', '0'), 2) for r in g])

# ---------------------------------------------------------------- sprites
# colours (CSS1): '.' transparent (shows snow), 'c' cyan, 'm' magenta, 'o' orange
# 'w' is not available in sprites (colour 0 = transparent).
CM = {'.': None, 'c': 1, 'm': 2, 'o': 3}
SPR = []


def S(name, art):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    SPR.append((name, rows))
    return rows


def mirror(rows):
    w = max(len(r) for r in rows)
    return [r.ljust(w, '.')[::-1] for r in rows]


def SM(name, rows):
    SPR.append((name, mirror(rows)))


# penguin facing right (white belly = transparent snow)
PR0 = S("PR0", """
..mmmm..
.mmm.mm.
.mmmmmoo
mmmm..c.
.mmm..c.
.mmm..c.
..oo.oo.
""")
PR1 = S("PR1", """
..mmmm..
.mmm.mm.
.mmmmmoo
.mmm..c.
mmmm..c.
.mmm..c.
.oo...oo
""")
SM("PL0", PR0)
SM("PL1", PR1)
S("PD0", """
..mmmm..
.m.mm.m.
.mmoomm.
mm....mm
.m....m.
.mc..cm.
..oo.oo.
""")
S("PD1", """
..mmmm..
.m.mm.m.
.mmoomm.
.m....m.
mm....mm
.mc..cm.
.oo...oo
""")
S("PU0", """
..mmmm..
.mmmmmm.
.mmmmmm.
mmmmmmmm
.mmmmmm.
.mmmmmm.
..oo.oo.
""")
S("PU1", """
..mmmm..
.mmmmmm.
.mmmmmm.
.mmmmmm.
mmmmmmmm
.mmmmmm.
.oo...oo
""")
PPR = S("PPR", """
..mmmm..
.mmm.mm.
.mmmmmoo
.mmm.cmm
.mmm..c.
mmm...c.
oo...oo.
""")
SM("PPL", PPR)
S("PPU", """
m.mmmm.m
mmmmmmmm
.mmmmmm.
.mmmmmm.
.mmmmmm.
.mmmmmm.
.oo..oo.
""")
S("PPD", """
..mmmm..
.m.mm.m.
.mmoomm.
.m....m.
.m....m.
mmc..cmm
..oo.oo.
""")
S("PDIE0", """
o.o.o.o.
..mmmm..
.mc.cmm.
.mmoomm.
mm....mm
.mc..cm.
..oo.oo.
""")
S("PDIE1", """
........
........
........
..mmmm..
.mc.cmoo
mmm..mmm
.ooo.oo.
""")
S("PDIE2", """
........
........
........
........
...c....
.mmmmmo.
oo.oo.oo
""")
S("PDANCE0", """
m.mmmm.m
mm.mm.mm
.mmoomm.
.m....m.
.m....m.
.mc..cm.
..oo.oo.
""")
S("PDANCE1", """
..mmmm..
.m.mm.m.
.mmoomm.
mm....mm
.m....m.
.mc..cm.
.oo...o.
""")
# monsters ------------------------------------------------------------
S("BLOB0", """
..oooo..
.oooooo.
oo.oo.oo
oommoomm
oooooooo
.ommmmo.
o.o..o.o
""")
S("BLOB1", """
........
..oooo..
.oooooo.
oo.oo.oo
oommoomm
oooooooo
oommmmoo
""")
S("BLOBS", """
c.o..o.c
.oooooo.
oocoocoo
oo.oo.oo
oooooooo
oo.mm.oo
.o.o.o.o
""")
S("CHOMP0", """
.cccccc.
cc.cc.cc
cm.cm.cc
cccccccc
coooooo.
c.....c.
.cccccc.
""")
S("CHOMP1", """
.cccccc.
cc.cc.cc
cm.cm.cc
cccccccc
cccccccc
coooooo.
.cccccc.
""")
S("CHOMPS", """
o.o..o.o
.cccccc.
cc.cc.cc
cocccocc
cccccccc
c.ooooc.
.cccccc.
""")
S("FLIT0", """
cc....cc
ccc..ccc
.cmoomc.
..oooo..
.mo..om.
..o..o..
........
""")
S("FLIT1", """
........
........
..moom..
ccooooc.
ccmoomcc
c.o..o.c
........
""")
S("FLITS", """
c.c..o.o
........
..moom..
.coooomc
.cm..mc.
..o..o..
........
""")
S("WISP0", """
..cccc..
.cccccc.
cc.cc.cc
ccoccocc
cccccccc
.c.c.c.c
c.c.c.c.
""")
S("WISP1", """
..cccc..
.cccccc.
cc.cc.cc
ccoccocc
cccccccc
c.c.c.c.
.c.c.c..
""")
S("WISPS", """
o.o..o.o
.cccccc.
ccmccmcc
cccccccc
cc.cc.cc
.c.c.c.c
c.c.c.c.
""")
S("WISPP", """
..c..c..
.c......
c.oc.oc.
........
.c..c..c
........
c..c..c.
""")
S("HATCH0", """
...mm...
..mmmm..
.mmmmmm.
.mmcmmm.
.mmmcmm.
.mmmmmm.
..mmmm..
""")
S("HATCH1", """
.m.m..m.
..m..m..
.m.oo.m.
.oo..oo.
.mooooo.
.mmmmmm.
..mmmm..
""")
S("SQUASH", """
........
........
........
o.o..o.o
.oo.ooo.
oooooooo
.o.oo.o.
""")
S("POOF0", """
........
..c..c..
...cc...
.c.cc.c.
...cc...
..c..c..
........
""")
S("POOF1", """
c..c...c
........
.c....c.
c......c
.c....c.
........
c..c...c
""")
# sliding blocks (same art as the tiles; colour 0 parts show snow)
S("BICE", """
ccccccc.
c..cccm.
c.ccccm.
ccccccm.
ccccccm.
cmmmmmm.
........
""")
S("BCRYS", """
ooooooo.
o.occom.
oocccom.
occcccm.
oocccom.
ommmmmm.
........
""")
S("SPARK", """
...c....
...c....
.ccocc..
...c....
...c....
........
........
""")
S("CURSOR", """
........
........
........
........
oooooooo
oooooooo
........
""")
S("FISHS", """
........
.......o
.oooo.oo
oo.ooooo
oooooooo
.oooo.oo
.......o
""")
# big sprites (16 wide) for the title / intermission
BIG = []


def B(name, art):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    BIG.append((name, rows))
    return rows


BP0 = B("BIGP0", """
...mmmmm....
..mmmmmmm...
.mmmm.mmmm..
.mmmm.mmmooo
.mmmmmmmoooo
mmmmmmm.ooo.
mmmmm.....c.
mmmmm.....c.
.mmmm.....c.
..mmm....c..
...mmc..c...
..oooo.oooo.
""")
BP1 = B("BIGP1", """
...mmmmm....
..mmmmmmm...
.mmmm.mmmm..
.mmmm.mmmooo
.mmmmmmmoooo
.mmmmmm.ooo.
mmmmmm....c.
mmmmm.....c.
mmmmm.....c.
..mmm....c..
...mmc..c...
.oooo...oooo
""")
B("BIGP0L", "\n".join(mirror(BP0)))
B("BIGP1L", "\n".join(mirror(BP1)))
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
            col = CM[c]
            dv = (dv << 2) | (0 if col is None else col)
        data += [(dv >> (8 * (sw - 1 - k))) & 255 for k in range(sw)]
    db(data)
# preview sheet (transparent shown as snow)
cw, ch, cols = 18, 16, 10
sheet = [[0] * (cw * cols) for _ in range(ch * ((len(ALL) + cols - 1) // cols))]
for i, (n, rows) in enumerate(ALL):
    ox = (i % cols) * cw + 1; oy = (i // cols) * ch + 1
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if CM[c] is not None:
                sheet[oy + y][ox + x] = CM[c]
save_preview(sheet, "sprites.png")

# ---------------------------------------------------------------- cell tiles (8x7, opaque)
TM = {'.': 0, 'c': 1, 'm': 2, 'o': 3}
TILES = []


def T(name, art):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    assert len(rows) == 7 and all(len(r) == 8 for r in rows), name
    TILES.append((name, rows))


T("EMPTY", "........\n" * 7)
T("ICE", """
ccccccc.
c..cccm.
c.ccccm.
ccccccm.
ccccccm.
cmmmmmm.
........
""")
T("EGG", """
ccccccc.
cc.mmcm.
c.mmmmm.
cmmmmmm.
cmmmmmm.
cmmmmmm.
........
""")
T("CRYS", """
ooooooo.
o.occom.
oocccom.
occcccm.
oocccom.
ommmmmm.
........
""")
T("ROCK", """
mmmmmmm.
m.mmomm.
mmmmmmm.
mmommmm.
mmmmmom.
mmmmmmm.
........
""")
T("CR1", """
ccc.ccc.
c..c.cm.
c.cc.cm.
cc.ccc..
c.cc.cm.
cm.mmmm.
........
""")
T("CR2", """
c.c..c..
.c...cm.
c..c....
.c..c.c.
c.c...m.
.m.m.m..
........
""")
T("CR3", """
........
.c....c.
...c....
c.....c.
..c.c...
c..m..m.
........
""")
T("FISH", """
........
......o.
.oooo.oo
oo.ooooo
oooooo..
.oooo.oo
......o.
""")
T("FLAKE", """
...c....
.c.c.c..
..ccc...
cccocccc
..ccc...
.c.c.c..
...c....
""")
T("SKATE", """
.mm.....
.mm.....
.mmmm...
.mmmmmm.
.mmmmmm.
cccccccc
.c....c.
""")
T("HEART", """
........
.oo.oo..
oooooooo
oooooooo
.oooooo.
..oooo..
...oo...
""")
T("SPARK", """
........
........
....c...
........
........
........
........
""")
T("MUNCH", """
ccccc...
c..cm...
c.cc....
cccm....
ccccc...
cmmmmmm.
........
""")
T("HATCH", """
ccc.ccc.
cc.m.cm.
c.mmm.m.
cmm.mmm.
cm.mmmm.
cmmm.mm.
........
""")
T("GOLDB", """
ccccccc.
c..cccm.
c.ccccm.
ccmmccm.
ccccccm.
cmmmmmm.
........
""")
for i, (n, rows) in enumerate(TILES):
    L.append("T_%s equ %d" % (n, i))
L.append("; tiles: 14 bytes each (2 bytes x 7 rows)")
L.append("tiles:")
for n, rows in TILES:
    data = []
    for r in rows:
        v = 0
        for c in r:
            v = (v << 2) | TM[c]
        data += [v >> 8, v & 255]
    db(data)

# ---------------------------------------------------------------- levels
# 15 x 8 grid. '#' ice  '.' empty  'C' crystal  'R' rock (unbreakable)  'P' penguin start
G_EMPTY, G_ICE, G_EGG, G_CRYS, G_ROCK = 0, 1, 2, 3, 4
LEVELS = [
 # name, eggs, maxactive, roster(1 blob 2 chomp 4 flit 8 wisp), speed, kind(0 normal 1 gold)
 ("SNOWY START", 5, 3, 1, 150, 0, """
#.#####.#####.#
#...#.....#...#
#.#.#.###.#.#.#
..#C..#P#..C#..
#.#.#.#.#.#.#.#
#...#...C.#...#
#.###.#.#.###.#
.......#.......
"""),
 ("ICE CUBES", 6, 3, 1, 160, 0, """
##.##.##.##.##.
##.##.##.##.##.
...............
##.##C##.##.##C
...............
##.##.##P##.##.
##.C#.##.##.##.
...............
"""),
 ("SLIPPERY", 6, 3, 1, 170, 0, """
.#.#.#.#.#.#.#.
...............
#.#.#C#.#.#.#.#
.......P.......
#.#.#.#.#.#C#.#
...............
.#.C.#.#.#.#.#.
...............
"""),
 ("V Z", 7, 3, 1, 180, 0, """
...............
.#...#..#####..
.#...#.....#C..
.#C..#....#....
..#.#..P.#.....
..#.#...#......
...#...C#####..
...............
"""),
 ("GOLD RUSH 1", 0, 0, 0, 0, 1, """
.##.###.###.##.
.#....#.#....#.
.#.##.#.#.##.#.
...#...P...#...
.#.##.#.#.##.#.
.#....#.#....#.
.##.###.###.##.
...............
"""),
 ("CHOMP CHOMP", 7, 3, 3, 180, 0, """
###.#######.###
#.....#C#.....#
#.###.#.#.###.#
#.#.........#.#
#.#.###P###.#.#
#...#.....#...#
###.#.#C#.#.###
C.............#
"""),
 ("IGLOO", 7, 3, 3, 190, 0, """
.....#####.....
...##.....##...
..#..##C##..#..
.#..#.....#..#.
.#.#..#P#..#.#.
.#.#.......#.#.
.C.#.##.##.#.C.
...............
"""),
 ("CROSSROADS", 8, 4, 3, 190, 0, """
##.###.#.###.##
#C.#...#...#..#
.......#.......
##.##.###.##.##
.......P.......
#..#...#...#.C#
##.###.#.###.##
...C...........
"""),
 ("FISH", 8, 4, 3, 200, 0, """
...............
.....###.##...#
...##......#.##
..#..C.#.......
..#....P....###
...##.....C#.##
.....##.###...#
.C.............
"""),
 ("GOLD RUSH 2", 0, 0, 0, 0, 1, """
#.#.#.#.#.#.#.#
...............
#.#.#.#.#.#.#.#
.......P.......
#.#.#.#.#.#.#.#
...............
#.#.#.#.#.#.#.#
...............
"""),
 ("ROCKY ROAD", 8, 4, 7, 200, 0, """
#.#.###.###.#.#
#.R.....C...R.#
#.#.##.#.##.#.#
..#..#.P.#..#..
#.##.#...#.##.#
#C...R.#.R....#
#.##.#.#.#.##.#
.......C.......
"""),
 ("CRYSTAL CAVE", 8, 4, 7, 210, 0, """
R#############R
#.....#.#.....#
#.###.#.#.###.#
#.#C....P...#.#
#.#.###.###.#.#
#...#C...C#...#
###.#.###.#.###
R.............R
"""),
 ("SNOWFLAKE", 9, 4, 7, 210, 0, """
#.....#.#.....#
.#..#.#.#.#..#.
..#..#...#..#..
#..#..#P#..#..#
.C..#.....#..C.
..#..#.#.#..#..
.#..#..C..#..#.
#.............#
"""),
 ("ZIGZAG", 9, 4, 7, 220, 0, """
...............
#############..
...............
..#############
.......P.......
#############..
..C.....C......
C.##########...
"""),
 ("GOLD RUSH 3", 0, 0, 0, 0, 1, """
###.#######.###
#.#.#.....#.#.#
###.#.###.#.###
.......P.......
###.#.###.#.###
#.#.#.....#.#.#
###.#######.###
...............
"""),
 ("WISPY WOODS", 9, 4, 15, 220, 0, """
.#.#.#.#.#.#.#.
.#.#.#.#.#.#.#.
.#C#.#...#.#.#.
.......P.......
.#.#.#...#.#C#.
.#.#.#.#.#.#.#.
.#.#.#C#.#.#.#.
...............
"""),
 ("AURORA", 10, 4, 15, 230, 0, """
###...#.#...###
#.....#.#.....#
#.C.#.....#...#
.#.....P.....#.
#...#.....#.C.#
#.....#.#.....#
###...#C#...###
...............
"""),
 ("THE MAZE", 10, 4, 15, 240, 0, """
#.#.#.#.#.#.#.#
#...#...#...#.#
#.###.#.#.###.#
#C....#P.....C#
###.###.###.###
#.....#.#.....#
#.#.#.#C#.#.#.#
..#...#...#....
"""),
 ("ICE AGE 2", 12, 4, 15, 250, 0, """
.###.....###...
.#.#..#.#..#..#
...#..#.#.#...#
..#..C.P.C....#
.#..R.#.#..#..#
.###..#.#.###.#
......C........
R.............R
"""),
 ("GOLD RUSH 4", 0, 0, 0, 0, 1, """
#######.#######
#.............#
#.#####.#####.#
..#....P....#..
#.#####.#####.#
#.............#
#######.#######
...............
"""),
]
CODES = {'#': G_ICE, '.': G_EMPTY, 'C': G_CRYS, 'R': G_ROCK, 'P': G_EMPTY}


def check_level(name, rows, kind):
    assert len(rows) == 8, name
    for r in rows:
        assert len(r) == 15, (name, r)
    P = [(x, y) for y in range(8) for x in range(15) if rows[y][x] == 'P']
    assert len(P) == 1, name
    nc = sum(r.count('C') for r in rows)
    if kind == 0:
        assert nc == 3, (name, nc)
        # crystals must not start aligned (3 in a row or column, contiguous)
        cs = sorted((x, y) for y in range(8) for x in range(15) if rows[y][x] == 'C')
        xs = {x for x, y in cs}; ys = {y for x, y in cs}
        if len(ys) == 1 and max(x for x, y in cs) - min(x for x, y in cs) == 2:
            raise AssertionError("crystals aligned " + name)
        if len(xs) == 1 and max(y for x, y in cs) - min(y for x, y in cs) == 2:
            raise AssertionError("crystals aligned " + name)
    # connectivity of empty space from P
    seen = {P[0]}; st = [P[0]]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a, b = x + dx, y + dy
            if 0 <= a < 15 and 0 <= b < 8 and (a, b) not in seen and rows[b][a] in '.P':
                seen.add((a, b)); st.append((a, b))
    empties = sum(1 for y in range(8) for x in range(15) if rows[y][x] in '.P')
    nice = sum(r.count('#') for r in rows)
    return P[0], len(seen), empties, nice


L.append("; ---- levels: header dw grid / db px,py,eggs,maxact,roster,speed,kind,0 / name")
L.append("NLEVELS equ %d" % len(LEVELS))
L.append("leveltab:")
for i, (name, eggs, maxa, roster, spd, kind, art) in enumerate(LEVELS):
    L.append("    dw lvgrid%d,lvname%d" % (i, i))
for i, (name, eggs, maxa, roster, spd, kind, art) in enumerate(LEVELS):
    rows = [r for r in art.strip("\n").split("\n")]
    (px, py), reach, empt, nice = check_level(name, rows, kind)
    print("level %2d %-13s reach %d/%d empty, ice %d, eggs %d" % (i + 1, name, reach, empt, nice, eggs))
    assert eggs <= nice - 4 or kind == 1
    L.append("lvgrid%d:" % i)
    db([px, py, eggs, maxa, roster, spd, kind, 0])
    g = []
    for r in rows:
        g += [CODES[c] for c in r] + [G_ROCK]   # 16-wide rows, col 15 = solid sentinel
    db(g)
    L.append('lvname%d: db "%s",0' % (i, name))
    # preview
    pix = [[0] * 128 for _ in range(64)]
    for y in range(8):
        for x in range(15):
            c = rows[y][x]
            t = {'#': 'ICE', 'C': 'CRYS', 'R': 'ROCK'}.get(c)
            if t:
                tr = dict(TILES)[t]
                for j in range(7):
                    for k in range(8):
                        pix[6 + y * 7 + j][4 + x * 8 + k] = TM[tr[j][k]]
            if c == 'P':
                for j in range(7):
                    for k, ch_ in enumerate(PR0[j]):
                        if ch_ != '.':
                            pix[6 + y * 7 + j][4 + x * 8 + k] = CM[ch_]
    for y in range(64):
        for x in range(128):
            if y < 6 or y >= 62 or x < 4 or x >= 124:
                pix[y][x] = 2
    save_preview(pix, "level_%02d.png" % (i + 1), css=0 if kind == 1 else 1)

# ---------------------------------------------------------------- title art + music
exec(open(os.path.join(HERE, "title_art.py")).read())
exec(open(os.path.join(HERE, "music.py")).read())

# lookup tables
L.append("ytab: db 0,1,2,3,3,4,5,6")
L.append("    align 256")
L.append("rowaddr:")      # VRAM row address for pixel rows 0..63 (low/high)
L.append("    dw " + ",".join("$%04X" % (0x7000 + y * 32) for y in range(64)))
open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT, "sprites:", len(ALL), "tiles:", len(TILES), "levels:", len(LEVELS))
