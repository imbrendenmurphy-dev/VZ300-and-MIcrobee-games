"""Builds DROPBEAR.VZ: generates tables, art and levels, assembles, packs."""
import math, pickle, sys
from z80tools import assemble, Z80
from PIL import Image

VIEWH = 48; NA = 1024; K = 42; DMIN = 0.25; WALL = 74.0
CLOCK = 3546900
mem = bytearray(65536); syms = {}; ptr = 0x8100

def blob(name, data, align=1):
    global ptr
    ptr = (ptr+align-1)//align*align
    if name: syms[name] = ptr
    mem[ptr:ptr+len(data)] = bytes(data); a = ptr; ptr += len(data); return a

# fixed work areas (not in the file)
syms.update(MAP=0xF800, TEXBUF=0xF900, ZBUF=0xF920, VIS=0xF940, BUF=0xFA00)

# ---- trig, folded to one quadrant (angles sit on half steps) -------------------
act = []; dxl = []; dxh = []
for i in range(256):
    th = 2*math.pi*(i+0.5)/NA
    c = math.cos(th); act.append(min(255, int(round(c*256))))
    d = min(32767, int(round(256/c))); dxl.append(d & 255); dxh.append(d >> 8)
blob('ACT', act, 256); blob('DXLO', dxl+dxh, 256)

# ---- distance -> wall height ------------------------------------------------------
logd = [max(0, min(255, int(round(K*math.log2(max(i, 16)/64/DMIN))))) for i in range(1024)]
blob('LOGD', logd, 256)
HEIGHTS = list(range(1, 49)) + [52, 56, 60, 64, 72, 80, 88, 96, 112, 128, 144, 160, 192, 224, 256]
NH = len(HEIGHTS)
hitab = []
for v in range(256):
    h = WALL/(DMIN*2**(v/K))
    hitab.append(min(range(NH), key=lambda k: abs(HEIGHTS[k]-h)))
blob('HITAB', hitab, 256)

# ---- textures: 5 wall types x 2 sides, 16 columns of 16 byte-wide texels --------
def solid(c): return c*0x55
def dith(a, b): return a << 6 | b << 4 | a << 2 | b
def px4(a, b, c, d): return a << 6 | b << 4 | c << 2 | d
def tex_brick(dark):
    body = dith(3, 2) if dark else solid(3)
    t = [[body]*16 for _ in range(16)]
    for u in range(16):
        for v in range(16):
            if v % 4 == 3: t[u][v] = solid(1)
            elif (u + (4 if (v//4) % 2 else 0)) % 8 == 7: t[u][v] = px4(3, 2 if dark else 3, 3, 1)
    return t
def tex_crate(dark):
    face = dith(1, 2) if dark else solid(1)
    t = [[face]*16 for _ in range(16)]
    for u in range(16):
        for v in range(16):
            if u in (0, 15) or v in (0, 15): t[u][v] = solid(3)
            elif u == v or u == 15-v: t[u][v] = solid(3)
            elif u in (1, 14) or v in (1, 14): t[u][v] = dith(3, 1)
    return t
def tex_door(dark):
    face = dith(2, 3) if dark else solid(2)
    t = [[face]*16 for _ in range(16)]
    for u in range(16):
        for v in range(16):
            if v in (0, 15) or u in (0, 15): t[u][v] = solid(3)
            elif u % 4 == 0: t[u][v] = px4(3, 2, 2, 2)
            elif 11 <= u <= 12 and 7 <= v <= 9: t[u][v] = solid(1)
    return t
def tex_exit(dark):
    t = [[solid(1)]*16 for _ in range(16)]
    for u in range(16):
        for v in range(16):
            if v in (0, 1, 14, 15) or u in (0, 15): t[u][v] = solid(3)
            elif 3 <= v <= 12 and abs(v-7.5) <= (u-2)*0.75 and u <= 9: t[u][v] = solid(2)   # big arrow head
            elif 6 <= v <= 9 and 9 < u <= 13: t[u][v] = solid(2)
    return t
def tex_stone(dark):
    body = solid(2) if dark else dith(0, 2)
    t = [[body]*16 for _ in range(16)]
    for u in range(16):
        for v in range(16):
            if v % 8 == 7: t[u][v] = dith(0, 2) if dark else solid(2)
            elif (u + (8 if (v//8) % 2 else 0)) % 16 == 15: t[u][v] = px4(2, 2, 2, 0) if dark else px4(0, 2, 0, 2) & 0xFC | 2
            elif (u*5+v*3) % 13 == 0: t[u][v] = dith(0, 2) if dark else solid(0)
    return t
texdata = []
for fn in (tex_brick, tex_crate, tex_door, tex_exit, tex_stone):
    for dark in (0, 1):
        t = fn(dark)
        texdata += [t[u][v] for u in range(16) for v in range(16)]
blob('TEX', texdata, 256)

# ---- unrolled helpers ---------------------------------------------------------------
FILL = blob('FILL', [0x71, 0x19]*VIEWH + [0xC9])                         # ld (hl),c / add hl,de
blob('mul816', [0x21, 0, 0] + [0x29, 0x17, 0x30, 0x03, 0x19, 0xCE, 0x00]*8 + [0xC9])
blob('BLIT8', [0xED, 0xA0]*256 + [0xC9])
SPRMAX = 44
SPRUNR = blob('SPRUNR', [0xD1, 0x7E, 0xA3, 0xB2, 0x77, 0x09]*SPRMAX + [0xC3, 0, 0])
syms['SPREND'] = SPRUNR + 6*SPRMAX

# ---- compiled wall scalers, one per height -----------------------------------------
recs = []
for k, h in enumerate(HEIGHTS):
    if h <= VIEWH:
        top = (VIEWH-h)//2; n = h
        rows = [min(15, int((y+0.5)*16/h)) for y in range(n)]
    else:
        top = 0; n = VIEWH
        rows = [max(0, min(15, int(math.floor(8+(y-(VIEWH/2-0.5))*16/h)))) for y in range(n)]
    code = []; prev = None
    for v in rows:
        if v != prev: code += [0x3A, (syms['TEXBUF']+v) & 255, syms['TEXBUF'] >> 8]; prev = v
        code += [0x77, 0x19]
    sc = blob(None, code+[0xC9])
    for a in (FILL+(VIEWH-top)*2, sc, FILL+(top+n)*2, 0): recs += [a & 255, a >> 8]
blob('REC', recs)
blob('BOT', [min(VIEWH, VIEWH//2 + (h+1)//2) for h in HEIGHTS])

# ---- ray columns -------------------------------------------------------------------
FOV2 = math.radians(30); cols = []
for i in range(32):
    th = math.atan((i+0.5-16)/16*math.tan(FOV2))
    off = int(round(th*NA/(2*math.pi))) & 0xFFFF
    cols += [off & 255, off >> 8, int(round(-K*math.log2(math.cos(th))))]
blob('COLS', cols)

# ---- sprites: drawn as shapes so every size is sampled cleanly ---------------------
def ell(cx, cy, rx, ry, col): return lambda u, v: col if ((u-cx)/rx)**2+((v-cy)/ry)**2 <= 1 else None
def rect(x0, y0, x1, y1, col): return lambda u, v: col if x0 <= u <= x1 and y0 <= v <= y1 else None
CLEAR = -1
def paint(layers):
    def f(u, v):
        out = None
        for L in layers:
            c = L(u, v)
            if c is not None: out = None if c == CLEAR else c
        return out
    return f
bear_common = [ell(.2, .13, .13, .12, 0), ell(.8, .13, .13, .12, 0), ell(.2, .13, .07, .065, 1), ell(.8, .13, .07, .065, 1),
               ell(.33, .92, .13, .08, 0), ell(.67, .92, .13, .08, 0), ell(.27, .96, .06, .035, 3), ell(.73, .96, .06, .035, 3),
               ell(.5, .68, .27, .27, 0), ell(.5, .72, .15, .17, 1)]
bear_walk = paint(bear_common + [
    ell(.2, .62, .09, .17, 0), ell(.8, .62, .09, .17, 0), ell(.2, .80, .07, .04, 3), ell(.8, .80, .07, .04, 3),
    ell(.5, .33, .29, .23, 0), ell(.38, .28, .06, .055, 2), ell(.62, .28, .06, .055, 2),
    ell(.38, .29, .03, .03, 1), ell(.62, .29, .03, .03, 1), ell(.5, .39, .075, .10, 2),
    rect(.43, .50, .47, .57, 1), rect(.53, .50, .57, .57, 1)])
bear_bite = paint(bear_common + [
    ell(.11, .42, .09, .18, 0), ell(.89, .42, .09, .18, 0), ell(.11, .24, .08, .045, 3), ell(.89, .24, .08, .045, 3),
    ell(.5, .33, .29, .23, 0), ell(.38, .25, .07, .04, 3), ell(.62, .25, .07, .04, 3),
    ell(.5, .33, .06, .05, 3), ell(.5, .46, .14, .09, 3),
    rect(.39, .39, .44, .47, 1), rect(.56, .39, .61, .47, 1), rect(.45, .49, .48, .54, 1), rect(.52, .49, .55, .54, 1)])
item_health = paint([rect(.15, .28, .85, 1.0, 3), rect(.15, .45, .85, .80, 1), rect(.30, .56, .70, .68, 3),
                     rect(.22, .06, .78, .28, 2)])
item_ammo = paint([rect(.05, .40, .95, 1.0, 2), rect(.05, .58, .95, .74, 1),
                   rect(.18, .08, .30, .40, 3), rect(.44, .08, .56, .40, 3), rect(.70, .08, .82, .40, 3)])
item_key = paint([ell(.26, .5, .24, .36, 1), ell(.26, .5, .11, .17, CLEAR), rect(.45, .40, .97, .60, 1),
                  rect(.68, .60, .78, .90, 1), rect(.86, .60, .96, .82, 1), ell(.26, .5, .24, .36, None)])

def prescale(fn, h, wpx):
    wb = max(1, math.ceil((wpx+2)/4)); W = wb*4; pad = (W-wpx)/2; out = []
    g = [[(fn((x+0.5-pad)/wpx, (y+0.5)/h) if 0 <= (x+0.5-pad)/wpx <= 1 else None) for x in range(W)] for y in range(h)]
    o = [r[:] for r in g]                      # dark outline so it reads against any wall or floor
    for y in range(h):
        for x in range(W):
            if g[y][x] is None and any(0 <= y+dy < h and 0 <= x+dx < W and g[y+dy][x+dx] is not None
                                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))): o[y][x] = 2
    for bx in range(wb):
        for y in range(h):
            m = 0; d = 0
            for c in o[y][bx*4:bx*4+4]:
                m = m << 2 | (3 if c is None else 0); d = d << 2 | (0 if c is None else c)
            out += [m, d]
    return wb, out
def frameset(name, fn, ladder, aspect):
    table = []
    for h in ladder:
        wb, data = prescale(fn, h, max(2, round(h*aspect)))
        a = blob(None, data); table += [wb, h, a & 255, a >> 8]
    return blob(name, table)
BEAR_L = [3, 4, 6, 8, 11, 14, 18, 23, 29, 36, 44]
ITEM_L = [2, 3, 4, 6, 8, 11, 14, 18]
BW = frameset('SPR_WALK', bear_walk, BEAR_L, 1.125)
BB = frameset('SPR_BITE', bear_bite, BEAR_L, 1.125)
IH = frameset('SPR_HEALTH', item_health, ITEM_L, 1.1)
IA = frameset('SPR_AMMO', item_ammo, ITEM_L, 1.4)
IK = frameset('SPR_KEY', item_key, ITEM_L, 1.8)
def sizetab(name, ladder, frac):
    return blob(name, [min(range(len(ladder)), key=lambda j: abs(ladder[j]-frac*h)) for h in HEIGHTS])
SB = sizetab('SZ_BEAR', BEAR_L, 0.62); SBOSS = sizetab('SZ_BOSS', BEAR_L, 0.95); SI = sizetab('SZ_ITEM', ITEM_L, 0.28)
types = []
for st, f0, f1 in ((SB, BW, BB), (SBOSS, BW, BB), (SI, IH, IH), (SI, IA, IA), (SI, IK, IK)):
    for a in (st, f0, f1): types += [a & 255, a >> 8]
blob('TYPES', types)
syms['TBEAR0'] = BW + 9*4; syms['TBEAR1'] = BB + 9*4

GUN = ["..........3333..........",
       "..........3113..........",
       ".........222222.........",
       ".........212222.........",
       ".........212222.........",
       ".........212222.........",
       "........22122222........",
       "........22122222........",
       ".......2221222222.......",
       "......222212222222......",
       ".....22222222222222.....",
       "....2223333333333222....",
       "....2223111111113222....",
       "...222233333333332222...",
       "...222222222222222222...",
       "..22222222222222222222.."]
FLASH = ["........1..33..1........",
         ".........131131.........",
         "......1.13311331.1......",
         ".......1331111331.......",
         "........33111133........",
         ".........331133........."]
def gunrec(name, art):
    h = len(art); out = []
    for bx in range(6):
        for y in range(h):
            m = 0; d = 0
            for ch in art[y][bx*4:bx*4+4]:
                m = m << 2 | (3 if ch == '.' else 0); d = d << 2 | (0 if ch == '.' else int(ch))
            out += [m, d]
    a = blob(None, out); return blob(name, [6, h, a & 255, a >> 8])
gunrec('GUN0', GUN)
syms['GUNH'] = len(GUN)
gunrec('GUN1', [("".join(f if f != '.' else g for f, g in zip(FLASH[y], GUN[y])) if y < len(FLASH) else GUN[y]) for y in range(len(GUN))])

# ---- font: 3x5 in a 4x6 cell, yellow/cyan on the panel colour -----------------------
GLYPHS = {
 ' ': "... ... ... ... ...", 'A': ".#. #.# ### #.# #.#", 'B': "##. #.# ##. #.# ##.", 'C': ".## #.. #.. #.. .##",
 'D': "##. #.# #.# #.# ##.", 'E': "### #.. ##. #.. ###", 'F': "### #.. ##. #.. #..", 'G': ".## #.. #.# #.# .##",
 'H': "#.# #.# ### #.# #.#", 'I': "### .#. .#. .#. ###", 'J': "..# ..# ..# #.# .#.", 'K': "#.# #.# ##. #.# #.#",
 'L': "#.. #.. #.. #.. ###", 'M': "#.# ### ### #.# #.#", 'N': "##. #.# #.# #.# #.#", 'O': "### #.# #.# #.# ###",
 'P': "### #.# ### #.. #..", 'Q': "### #.# #.# ### ..#", 'R': "### #.# ##. #.# #.#", 'S': ".## #.. .#. ..# ##.",
 'T': "### .#. .#. .#. .#.", 'U': "#.# #.# #.# #.# ###", 'V': "#.# #.# #.# #.# .#.", 'W': "#.# #.# ### ### #.#",
 'X': "#.# #.# .#. #.# #.#", 'Y': "#.# #.# .#. .#. .#.", 'Z': "### ..# .#. #.. ###",
 '0': ".#. #.# #.# #.# .#.", '1': ".#. ##. .#. .#. ###", '2': "##. ..# .#. #.. ###", '3': "##. ..# .#. ..# ##.",
 '4': "#.# #.# ### ..# ..#", '5': "### #.. ##. ..# ##.", '6': ".## #.. ### #.# ###", '7': "### ..# .#. .#. .#.",
 '8': "### #.# ### #.# ###", '9': "### #.# ### ..# ##.", '!': ".#. .#. .#. ... .#.", '-': "... ... ### ... ...",
 '+': "... .#. ### .#. ...", '.': "... ... ... ... .#.", ':': "... .#. ... .#. ...", "'": ".#. .#. ... ... ...",
 '/': "..# ..# .#. #.. #..", ',': "... ... ... .#. #.."}
CHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-+.:'/,"
font = []
for ch in CHARS:
    rows = GLYPHS[ch].split()
    for r in rows: font.append(sum((1 if c == '#' else 2) << (6-2*i) for i, c in enumerate(r)) | 2)
    font.append(0xAA)
blob('FONT', font)
def enc(s): return [CHARS.index(c) for c in s] + [0xFF]
def page(name, lines):
    out = []
    for row, col, s in lines:
        assert col+len(s) <= 32, s
        a = 0x7000+row*32+col; out += [a & 255, a >> 8] + enc(s)
    return blob(name, out+[0, 0])
def centre(row, s): return (row, (32-len(s))//2, s)

# logo: the font doubled, with a shadow
LOGOTXT = "DROPBEAR 3D"; LW = len(LOGOTXT)*8; LH = 12
lg = [[2]*LW for _ in range(LH)]
for pas, col in ((1, 3), (0, 1)):
    for ci, ch in enumerate(LOGOTXT):
        for ry, r in enumerate(GLYPHS[ch].split()):
            for rx, c in enumerate(r):
                if c == '#':
                    for yy in range(2):
                        for xx in range(2):
                            x = ci*8+rx*2+xx+pas; y = ry*2+yy+pas
                            if x < LW and y < LH: lg[y][x] = col
blob('LOGO', [sum(lg[y][x*4+i] << (6-2*i) for i in range(4)) for y in range(LH) for x in range(LW//4)])
syms['LOGOW'] = LW//4; syms['LOGOH'] = LH

page('PG_TITLE', [centre(18, "VIBED BY BPM 2026"), (27, 16, "W S    WALK"), (34, 16, "A D    TURN"),
                  (41, 16, "Q E    STRAFE"), (48, 16, "SPACE  FIRE"), (57, 16, "PRESS FIRE!")])
page('PG_HUD', [(50, 0, "HP"), (50, 15, "AMMO"), (57, 0, "BEARS"), (57, 9, "LVL")])
page('PG_DEAD', [centre(12, "OUCH!"), centre(24, "THE DROP BEARS GOT YOU."), centre(34, "HAVE ANOTHER GO, MATE."),
                 centre(54, "PRESS FIRE")])
page('PG_WIN', [centre(8, "YOU BEAUTY!"), centre(20, "BIG FELLA IS DOWN AND THE"), centre(27, "DROP BEARS HAVE GONE BUSH."),
                centre(34, "THE STATION IS SAFE."), centre(45, "VIBED BY BPM 2026"), centre(56, "PRESS FIRE")])
for nm, s in (('MSG_KEY', "GOT THE KEY!"), ('MSG_HEALTH', "VEGEMITE! +25"), ('MSG_AMMO', "AMMO +15"),
              ('MSG_NEEDKEY', "NEED THE KEY!"), ('MSG_OUCH', "OUCH!"), ('MSG_GOTONE', "GOT ONE!"),
              ('MSG_BOSS', "BIG FELLA DOWN!"), ('MSG_DOOR', "DOOR OPENS"), ('MSG_BLANK', "")):
    blob(nm, enc(s.ljust(16)))
blob('STR_KEY', enc("KEY")); blob('STR_NOKEY', enc("   "))

# ---- levels ---------------------------------------------------------------------------
LEVELS = [
 dict(name="THE OLD STATION", css=0x18, ang=0, hint=["FIND THE KEY, THEN THE EXIT.", "MIND THE DROP BEARS!"], rows=[
  "################",
  "#P...#....#....#",
  "#....#....D..b.#",
  "#....D....#....#",
  "#....#.b..#..a.#",
  "###D####.###D###",
  "#......#.#.....#",
  "#..CC..#.#..b..#",
  "#..CC....#.....#",
  "#......#.#...k.#",
  "#.h....#.###.###",
  "###.####.......#",
  "#.....b#..CC...X",
  "#......D..CC...#",
  "#......#.......#",
  "################"]),
 dict(name="GUM TREE GULLY", css=0x08, ang=0, hint=["THE BEARS ARE RESTLESS", "OUT IN THE HEDGES."], rows=[
  "MMMMMMMMMMMMMMMM",
  "MP..M.....M...kM",
  "M...M.MMM.M.b..M",
  "M.........M....M",
  "MMM.MMM.b.MMDMMM",
  "M.....M.......aM",
  "M.b...M..MM....M",
  "M.....D..MM..b.M",
  "M..h..M........M",
  "MMMMDMMMMM.MMMMM",
  "M........M.....M",
  "M..MM..b.M..h..M",
  "M..MM....D.....M",
  "M.a......M..b..X",
  "M........M.....M",
  "MMMMMMMMMMMMMMMM"]),
 dict(name="BIG FELLA'S DEN", css=0x18, ang=0, hint=["BIG FELLA GUARDS THE KEY.", "BRING PLENTY OF AMMO."], rows=[
  "################",
  "#P...#.b...#..h#",
  "#....#.....#...#",
  "#....D.....D...#",
  "##D###.....###D#",
  "#..a.#MMDMM#...#",
  "#....#M...M#.b.#",
  "#.b..#M.B.M#...#",
  "#....#M..kM#...#",
  "#....#MMMMM#...#",
  "###D###...###D##",
  "#.....#.b.#....#",
  "#..CC.....#..a.#",
  "#..CC.#...D..b.X",
  "#h....#...#....#",
  "################"])]
WALLCH = {'#': 1, 'C': 2, 'D': 3, 'X': 4, 'M': 5}
OBJCH = {'b': 1, 'B': 2, 'h': 3, 'a': 4, 'k': 5}
levaddr = []; pgaddr = []; LEVINFO = []
for li, L in enumerate(LEVELS):
    rows = L['rows']; assert len(rows) == 16 and all(len(r) == 16 for r in rows), L['name']
    grid = [[WALLCH.get(ch, 0) for ch in r] for r in rows]
    objs = [(OBJCH[ch], x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch in OBJCH]
    (sx, sy), = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'P']
    (ex, ey), = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == 'X']
    assert len(objs) <= 16
    # everything must be reachable on foot (doors open when walked into)
    seen = {(sx, sy)}; todo = [(sx, sy)]
    while todo:
        x, y = todo.pop()
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if (nx, ny) not in seen and grid[ny][nx] in (0, 3): seen.add((nx, ny)); todo.append((nx, ny))
    for t, x, y in objs: assert (x, y) in seen, (L['name'], t, x, y)
    assert any((ex+dx, ey+dy) in seen for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    data = [L['css'], sx, sy, L['ang'] & 255, L['ang'] >> 8, len(objs)]
    for o in objs: data += list(o)
    data += [c for r in grid for c in r]
    levaddr.append(blob(None, data))
    pgaddr.append(page(None, [centre(8, "LEVEL %d" % (li+1)), centre(18, L['name'])] +
                       [centre(32+7*i, s) for i, s in enumerate(L['hint'])] + [centre(54, "PRESS FIRE")]))
    LEVINFO.append(dict(grid=grid, objs=objs, start=(sx, sy), exit=(ex, ey)))
blob('LEVTAB', sum(([a & 255, a >> 8] for a in levaddr), []))
blob('PGTAB', sum(([a & 255, a >> 8] for a in pgaddr), []))

# ---- music ------------------------------------------------------------------------------
NOTE = {n: 440*2**((i-9)/12) for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}
def freq(n): return NOTE[n[:-1]]*2**(int(n[-1])-4)
def count(f): return max(4, int(round((CLOCK/(2*f)-130)/26)))
def ttune(seq):
    out = []
    for n, ms, gap in seq:
        if n == '-': out += [0, 0, 0, gap]
        else:
            f = freq(n); out += [count(f) & 255, count(f) >> 8, min(255, max(2, int(round(f*2*ms/1000)))), gap]
    return out + [0xFF, 0xFF]
riff = [('E3', 110, 12), ('E3', 110, 12), ('G3', 110, 12), ('E3', 110, 30), ('A3', 110, 12), ('G3', 110, 12), ('E3', 150, 40),
        ('E3', 110, 12), ('E3', 110, 12), ('G3', 110, 12), ('A3', 110, 30), ('B3', 110, 12), ('A3', 110, 12), ('G3', 150, 40),
        ('E3', 110, 12), ('E3', 110, 12), ('G3', 110, 12), ('E3', 110, 30), ('D3', 110, 12), ('D3', 110, 12), ('E3', 220, 60),
        ('-', 0, 40)]
blob('TTUNE', ttune(riff))
def gtune(seq):
    out = []
    for n in seq:
        if n == '-': out += [0, 0, 0]
        else: f = freq(n); out += [count(f) & 255, count(f) >> 8, 4]
    return out + [0xFF, 0xFF]
blob('GTUNE', gtune(['E4', '-', '-', 'E4', 'G4', 'E4', '-', '-', 'D4', '-', '-', 'D4', 'F4', 'D4', '-', '-',
                     'E4', '-', '-', 'E4', 'G4', 'A4', '-', '-', 'B4', '-', 'A4', '-', 'G4', '-', '-', '-']))

# ---- assemble the game after the data ------------------------------------------------------
syms['CODEORG'] = ptr
for k in list(syms):
    if k.isupper() or k.startswith('SPR'): syms[k+'_HI'] = syms[k] >> 8
syms['ZBUF_LO'] = syms['ZBUF'] & 255
code = assemble(open('dropbear.asm').read(), syms)
for a, v in code.items(): mem[a] = v
codeend = syms['codeend']; IMGEND = (codeend+255) & 0xFF00
assert IMGEND <= 0xF800, hex(IMGEND)
mem[syms['SPREND']+1] = syms['ds_ret'] & 255; mem[syms['SPREND']+2] = syms['ds_ret'] >> 8
image = bytes(mem[0x8100:IMGEND])

# ---- pack ---------------------------------------------------------------------------------
def pack(data):
    out = bytearray(); i = 0; n = len(data); lit = bytearray(); table = {}
    def flush():
        nonlocal lit
        while lit:
            chunk = lit[:128]; out.append(len(chunk)-1); out.extend(chunk); lit = lit[128:]
    while i < n:
        best = 0; bd = 0
        if i+3 <= n:
            for p in reversed(table.get(data[i:i+3], [])[-64:]):
                l = 3
                while l < 130 and i+l < n and data[p+l] == data[i+l]: l += 1
                if l > best: best = l; bd = i-p
                if l == 130: break
        if best >= 4:
            flush(); out.append(0x80 | (best-3)); out += bytes([bd & 255, bd >> 8])
            for j in range(i, i+best):
                if j+3 <= n: table.setdefault(data[j:j+3], []).append(j)
            i += best
        else:
            if i+3 <= n: table.setdefault(data[i:i+3], []).append(i)
            lit.append(data[i]); i += 1
    flush(); return bytes(out)
packed = pack(image)
STUB = """
        org $8000
        di
        ld sp,$80F0
        ld hl,PKSRC+PKLEN-1
        ld de,$F9FF
        ld bc,PKLEN
        lddr
        inc de
        ex de,hl
        ld de,$8100
dp:     ld a,(hl)
        inc hl
        or a
        jp m,dpm
        ld c,a
        ld b,0
        inc bc
        ldir
        jr dpc
dpm:    and $7F
        add a,3
        ld c,a
        ld b,0
        ld a,(hl)
        inc hl
        push hl
        ld h,(hl)
        ld l,a
        ld a,e
        sub l
        ld l,a
        ld a,d
        sbc a,h
        ld h,a
        ldir
        pop hl
        inc hl
dpc:    ld a,d
        cp IMGENDHI
        jr c,dp
        jp START
PKSRC:
"""
ss = dict(PKLEN=len(packed), IMGENDHI=IMGEND >> 8, START=syms['start'])
stub = assemble(STUB, ss)
body = bytes(stub[a] for a in range(0x8000, ss['PKSRC'])) + packed
assert ss['PKSRC'] <= 0x8100 and 0x8000+len(body) < 0xFA00-len(packed)
vz = b'VZF0' + b'DROPBEAR'.ljust(17, b'\0') + bytes([0xF1, 0x00, 0x80]) + body
open('DROPBEAR.VZ', 'wb').write(vz)
pickle.dump(dict(syms=syms, image=image, body=body, IMGEND=IMGEND, levels=LEVINFO, heights=HEIGHTS), open('image.pkl', 'wb'))
print('data ends %04X, code %04X-%04X (%d bytes), image %d bytes, packed %d, file loads 8000-%04X' %
      (syms['CODEORG'], syms['CODEORG'], codeend, codeend-syms['CODEORG'], len(image), len(packed), 0x8000+len(body)-1))
