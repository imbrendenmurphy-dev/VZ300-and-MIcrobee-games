#!/usr/bin/env python3
"""Asset generator for ASTEROIDS II (VZ300, CG2 128x64, 2bpp).
Colours: 0 = background (green), 1 = yellow, 2 = blue, 3 = red.
A CG2 pixel is 2 units wide and 3 units tall, so all vector shapes are
rasterised in 'physical' units and sampled at pixel centres.
Outputs src/assets.inc (sjasmplus) and build/assets_preview.png."""
import math, random, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets.inc')
PREV = os.path.join(ROOT, '..', 'build', 'assets_preview.png')

def blank(w, h): return [[0]*w for _ in range(h)]

def point_in_poly(x, y, pts):
    c = False; n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]; x2, y2 = pts[(i+1) % n]
        if (y1 > y) != (y2 > y):
            if x < (x2-x1)*(y-y1)/(y2-y1)+x1: c = not c
    return c

def raster_poly(pts, w, h, col, thr=0.45, grid=None, ss=4):
    """pts in physical units relative to sprite centre."""
    g = grid or blank(w, h)
    cx, cy = w, h*1.5  # centre in physical units
    for py in range(h):
        for px in range(w):
            hit = 0
            for sy in range(ss):
                for sx in range(ss):
                    X = px*2 + (sx+0.5)*2/ss - cx
                    Y = py*3 + (sy+0.5)*3/ss - cy
                    if point_in_poly(X, Y, pts): hit += 1
            if hit/(ss*ss) >= thr: g[py][px] = col
    return g

def outline(g, col, inner=False):
    """pixels of g that are set and touch background -> col"""
    h = len(g); w = len(g[0]); o = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x]:
                edge = False
                for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
                    X, Y = x+dx, y+dy
                    if X < 0 or Y < 0 or X >= w or Y >= h or not g[Y][X]: edge = True
                if edge: o[y][x] = col
    return o

def from_ascii(rows, cmap={'.':0,'Y':1,'B':2,'R':3,'G':4,' ':0}):
    return [[cmap[c] for c in r] for r in rows]

HW = {0:0, 1:1, 2:2, 3:3, 4:0}
def enc_xor(c):   # sprite pixel -> value XORed onto a blue (2) background
    return 0 if c == 0 else HW[c] ^ 2
def enc_direct(c):  # direct pixel on blue background
    return 2 if c == 0 else HW[c]
def pack(g, enc=enc_xor):
    h = len(g); w = len(g[0]); wb = (w+3)//4; out = []
    for y in range(h):
        for b in range(wb):
            v = 0
            for p in range(4):
                x = b*4+p; c = g[y][x] if x < w else 0
                v = (v << 2) | enc(c)
            out.append(v)
    return out

sprites = []  # (name, grid)
def add(name, g): sprites.append((name, g)); return len(sprites)-1

def rot(pts, a):
    c, s = math.cos(a), math.sin(a)
    return [(x*c - y*s, x*s + y*c) for x, y in pts]

# ---------------- ship: 32 rotations ----------------
SHIP = [(0,-8.5), (6.5,6.5), (2.2,3.6), (0,4.6), (-2.2,3.6), (-6.5,6.5)]
ship_ids = []
for i in range(32):
    a = i*2*math.pi/32
    pts = rot(SHIP, a)
    g = raster_poly(pts, 8, 6, 1, thr=0.40)
    # nose tip pixel highlighted red for direction readability
    nx, ny = rot([(0,-6.0)], a)[0]
    px = int((nx + 8)//2); py = int((ny + 9)//3)
    if 0 <= px < 8 and 0 <= py < 6 and g[py][px]: g[py][px] = 3
    ship_ids.append(add('ship%d' % i, g))

# shield rings (2 frames)
def ellipse_ring(w, h, col, col2=None, rx=None, ry=None, thick=1.6):
    g = blank(w, h); cx, cy = w, h*1.5
    rx = rx or w - 0.6; ry = ry or h*1.5 - 0.8
    for py in range(h):
        for px in range(w):
            X = px*2+1-cx; Y = py*3+1.5-cy
            d = math.hypot(X/rx, Y/ry)
            if abs(d-1) < thick/ max(rx, ry) * 1.6:
                ang = math.atan2(Y, X)
                c = col
                if col2 is not None and int((ang+math.pi)/(math.pi/4)) % 2: c = col2
                g[py][px] = c
    return g
shield0 = add('shield0', ellipse_ring(12, 7, 1, 4))
shield1 = add('shield1', ellipse_ring(12, 7, 4, 1))

# ---------------- rocks ----------------
random.seed(1984)
SIZES = [('L', 15, 9, 14.0), ('M', 10, 6, 9.0), ('S', 6, 4, 5.2)]
NFR = {'L': 8, 'M': 8, 'S': 4}
TYPES = ['STONE', 'ORE', 'VOLATILE', 'CRYSTAL']
rock_ids = {}
for t, tname in enumerate(TYPES):
    for sname, w, h, R in SIZES:
        n = 10 if sname != 'S' else 7
        if tname == 'CRYSTAL':
            n = 6 if sname != 'S' else 5
            radii = [R*(0.95 if k % 2 == 0 else 0.62) for k in range(n)]
        else:
            radii = [R*random.uniform(0.72, 1.0) for _ in range(n)]
        base = [(radii[k]*math.cos(2*math.pi*k/n), radii[k]*math.sin(2*math.pi*k/n)) for k in range(n)]
        feats = []  # interior features in polar coords
        for _ in range(4 if sname == 'L' else 2 if sname == 'M' else 1):
            feats.append((random.uniform(0.15, 0.55)*R, random.uniform(0, 2*math.pi)))
        ids = []
        for f in range(NFR[sname]):
            a = f*2*math.pi/NFR[sname] + 0.2
            pts = rot(base, a)
            g = raster_poly(pts, w, h, 4, thr=0.42)
            cx, cy = w, h*1.5
            def plot_feat(r, th, col, only_inside=True):
                X = r*math.cos(th+a); Y = r*math.sin(th+a)
                px = int((X+cx)//2); py = int((Y+cy)//3)
                if 0 <= px < w and 0 <= py < h and (g[py][px] or not only_inside): g[py][px] = col
            if tname == 'STONE':
                for r, th in feats: plot_feat(r, th, 0)
            elif tname == 'ORE':
                for r, th in feats:
                    plot_feat(r, th, 1); plot_feat(r*0.5, th+2.0, 1)
            elif tname == 'VOLATILE':
                for r, th in feats:
                    for k in range(5): plot_feat(r*k/4.0, th, 3)
            elif tname == 'CRYSTAL':
                g = outline(g, 4)
                inner = [[0 if (c == 2 and not any(
                    0 <= y+dy < h and 0 <= x+dx < w and g[y+dy][x+dx] == 0 for dx, dy in ((1,0),(-1,0),(0,1),(0,-1))) and
                    0 < x < w-1 and 0 < y < h-1) else c for x, c in enumerate(row)] for y, row in enumerate(g)]
                # hollow: keep only edge pixels
                hol = blank(w, h)
                for y in range(h):
                    for x in range(w):
                        if g[y][x]:
                            edge = any(not (0 <= y+dy < h and 0 <= x+dx < w) or g[y+dy][x+dx] == 0
                                       for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)))
                            hol[y][x] = 4 if edge else 0
                g = hol
                # glints at alternate vertices
                for k in range(0, n, 2):
                    X, Y = rot([base[k]], a)[0]
                    px = min(w-1, max(0, int((X*0.86+cx)//2))); py = min(h-1, max(0, int((Y*0.86+cy)//3)))
                    g[py][px] = 1
            ids.append(add('rock_%s_%s_%d' % (tname, sname, f), g))
        rock_ids[(t, sname)] = ids

# ---------------- enemies ----------------
SAUCER = [
 ["....GGG....",
  "..RRRRRRR..",
  "RRYRRYRRYRR",
  "..RRRRRRR..",
  "....R.R...."],
 ["....GGG....",
  "..RRRRRRR..",
  "RYRRYRRYRRR",
  "..RRRRRRR..",
  "...R...R..."]]
saucer_ids = [add('saucer%d' % i, from_ascii(s)) for i, s in enumerate(SAUCER)]
HUNTER = [
 [".GGG.", "RRYRR", ".R.R."],
 [".GGG.", "RYRYR", "R...R"]]
hunter_ids = [add('hunter%d' % i, from_ascii(s)) for i, s in enumerate(HUNTER)]
STING = [(0,-7.5), (4.8,5.5), (0,2.5), (-4.8,5.5)]
sting_ids = []
for i in range(8):
    a = i*2*math.pi/8
    g = raster_poly(rot(STING, a), 7, 5, 3, thr=0.40)
    nx, ny = rot([(0,-1.0)], a)[0]
    px = int((nx+7)//2); py = int((ny+7.5)//3)
    if 0 <= px < 7 and 0 <= py < 5: g[py][px] = 1
    sting_ids.append(add('sting%d' % i, g))
MINE = [
 ["R.Y.R", ".RRR.", "YRYRY", ".RRR.", "R.Y.R"],
 [".YRY.", "YRRRY", "RRYRR", "YRRRY", ".YRY."]]
mine_ids = [add('mine%d' % i, from_ascii(s)) for i, s in enumerate(MINE)]

# ---------------- jewels (spin) ----------------
JEWEL_FR = [
 ["..A..", ".AWA.", "AAAAA", ".AAA.", "..A.."],
 ["..A..", ".AWA.", ".AAA.", ".AAA.", "..A.."],
 ["..A..", "..W..", "..A..", "..A..", "..A.."],
 ["..A..", ".AWA.", ".AAA.", ".AAA.", "..A.."]]
jewel_ids = {}
for colname, col, wcol in (('TOPAZ', 1, 3), ('RUBY', 3, 1), ('EMERALD', 4, 1)):
    ids = []
    for f, fr in enumerate(JEWEL_FR):
        g = from_ascii([r.replace('A', 'C').replace('W', 'D') for r in fr], {'.':0, 'C':col, 'D':wcol})
        ids.append(add('jewel_%s_%d' % (colname, f), g))
    jewel_ids[colname] = ids

# ---------------- pickups (icon in a capsule) ----------------
PICK = {
 'SHIELD': ["YYYYYYY", "Y.GGG.Y", "YG...GY", "Y.GGG.Y", "YYYYYYY"],
 'BOMB':   ["YYYYYYY", "Y..RY.Y", "Y.RRR.Y", "Y.RRR.Y", "YYYYYYY"],
 'SPREAD': ["YYYYYYY", "YR.R.RY", "Y.RRR.Y", "Y..R..Y", "YYYYYYY"],
 'RAPID':  ["YYYYYYY", "YR.R..Y", "Y.R.R.Y", "YR.R..Y", "YYYYYYY"],
 'LIFE':   ["YYYYYYY", "Y..R..Y", "Y.RRR.Y", "YR.R.RY", "YYYYYYY"]}
pick_ids = {}
for k, rows in PICK.items():
    g = from_ascii(rows)
    alt = [[(4 if c == 1 else c) for c in r] for r in g]  # blinking frame: green capsule
    pick_ids[k] = [add('pick_%s_0' % k, g), add('pick_%s_1' % k, alt)]

# ---------------- shockwave rings ----------------
ring_ids = [add('ring0', ellipse_ring(8, 5, 1, 3)),
            add('ring1', ellipse_ring(14, 8, 3, 1)),
            add('ring2', ellipse_ring(20, 12, 3, 4, thick=1.3))]

# ---------------- life icon for HUD ----------------
lifeicon = add('lifeicon', from_ascii(["..Y..", ".YYY.", "YYRYY"]))
bombicon = add('bombicon', from_ascii([".RY", "RRR", "RRR"]))

# ---------------- font 3x5 ----------------
FONT = {
'0':["YYY","Y.Y","Y.Y","Y.Y","YYY"], '1':[".Y.","YY.",".Y.",".Y.","YYY"],
'2':["YYY","..Y","YYY","Y..","YYY"], '3':["YYY","..Y",".YY","..Y","YYY"],
'4':["Y.Y","Y.Y","YYY","..Y","..Y"], '5':["YYY","Y..","YYY","..Y","YYY"],
'6':["YYY","Y..","YYY","Y.Y","YYY"], '7':["YYY","..Y",".Y.",".Y.",".Y."],
'8':["YYY","Y.Y","YYY","Y.Y","YYY"], '9':["YYY","Y.Y","YYY","..Y","YYY"],
'A':[".Y.","Y.Y","YYY","Y.Y","Y.Y"], 'B':["YY.","Y.Y","YY.","Y.Y","YY."],
'C':[".YY","Y..","Y..","Y..",".YY"], 'D':["YY.","Y.Y","Y.Y","Y.Y","YY."],
'E':["YYY","Y..","YY.","Y..","YYY"], 'F':["YYY","Y..","YY.","Y..","Y.."],
'G':[".YY","Y..","Y.Y","Y.Y",".YY"], 'H':["Y.Y","Y.Y","YYY","Y.Y","Y.Y"],
'I':["YYY",".Y.",".Y.",".Y.","YYY"], 'J':["..Y","..Y","..Y","Y.Y",".Y."],
'K':["Y.Y","Y.Y","YY.","Y.Y","Y.Y"], 'L':["Y..","Y..","Y..","Y..","YYY"],
'M':["Y.Y","YYY","YYY","Y.Y","Y.Y"], 'N':["YY.","Y.Y","Y.Y","Y.Y","Y.Y"],
'O':[".Y.","Y.Y","Y.Y","Y.Y",".Y."], 'P':["YY.","Y.Y","YY.","Y..","Y.."],
'Q':[".Y.","Y.Y","Y.Y","YY.",".YY"], 'R':["YY.","Y.Y","YY.","Y.Y","Y.Y"],
'S':[".YY","Y..",".Y.","..Y","YY."], 'T':["YYY",".Y.",".Y.",".Y.",".Y."],
'U':["Y.Y","Y.Y","Y.Y","Y.Y","YYY"], 'V':["Y.Y","Y.Y","Y.Y","Y.Y",".Y."],
'W':["Y.Y","Y.Y","YYY","YYY","Y.Y"], 'X':["Y.Y","Y.Y",".Y.","Y.Y","Y.Y"],
'Y':["Y.Y","Y.Y",".Y.",".Y.",".Y."], 'Z':["YYY","..Y",".Y.","Y..","YYY"],
' ':["...","...","...","...","..."], '.':["...","...","...","...",".Y."],
'-':["...","...","YYY","...","..."], '!':[".Y.",".Y.",".Y.","...",".Y."],
':':["...",".Y.","...",".Y.","..."], ',':["...","...","...",".Y.","Y.."],
'+':["...",".Y.","YYY",".Y.","..."], '/':["..Y","..Y",".Y.","Y..","Y.."],
'X2':["...","...","...","...","..."], "'":[".Y.",".Y.","...","...","..."],
'=':["...","YYY","...","YYY","..."], '?':["YYY","..Y",".YY","...",".Y."],
'(':[".Y.","Y..","Y..","Y..",".Y."], ')':[".Y.","..Y","..Y","..Y",".Y."],
'*':["Y.Y",".Y.","YYY",".Y.","Y.Y"], '#':["Y.Y","YYY","Y.Y","YYY","Y.Y"],
'%':["Y.Y","..Y",".Y.","Y..","Y.Y"], '&':[".Y.","Y.Y",".Y.","Y.Y",".YY"],
'<':["..Y",".Y.","Y..",".Y.","..Y"], '>':["Y..",".Y.","..Y",".Y.","Y.."],
'"':["Y.Y","Y.Y","...","...","..."], '^':["...",".Y.",".Y.","YYY","Y.Y"],
'[':["..Y",".Y.","YYY","YYY",".Y."], ']':["...","YYY","Y.Y","YYY","..."], '@':[".Y.","Y.Y","YYY","Y..",".YY"],
}
# Font index = ASCII 32..95; bytes: 5 rows, each 4 px (3 + 1 gap) as 2bpp '11' mask
font_bytes = []
for code in range(32, 96):
    ch = chr(code); rows = FONT.get(ch, FONT['?'] if ch not in FONT else FONT[ch])
    for r in rows:
        v = 0
        for p in range(4):
            v = (v << 2) | (3 if p < 3 and r[p] == 'Y' else 0)
        font_bytes.append(v)

# ---------------- title logo ----------------
BIG = {  # 5x7 base glyphs
'A':[".YYY.","Y...Y","Y...Y","YYYYY","Y...Y","Y...Y","Y...Y"],
'S':[".YYYY","Y....","Y....",".YYY.","....Y","....Y","YYYY."],
'T':["YYYYY","..Y..","..Y..","..Y..","..Y..","..Y..","..Y.."],
'E':["YYYYY","Y....","Y....","YYYY.","Y....","Y....","YYYYY"],
'R':["YYYY.","Y...Y","Y...Y","YYYY.","Y.Y..","Y..Y.","Y...Y"],
'O':[".YYY.","Y...Y","Y...Y","Y...Y","Y...Y","Y...Y",".YYY."],
'I':["YYY",".Y.",".Y.",".Y.",".Y.",".Y.","YYY"],
'D':["YYYY.","Y...Y","Y...Y","Y...Y","Y...Y","Y...Y","YYYY."],
}
def make_logo(text, sx=2, sy=2, slant=True):
    glyphs = [BIG[c] for c in text]
    W = sum(len(g[0])*sx + 2 for g in glyphs) + 6; H = 7*sy + 4
    face = blank(W, H); x0 = 2
    for g in glyphs:
        gw = len(g[0])
        for y in range(7):
            for x in range(gw):
                if g[y][x] == 'Y':
                    for yy in range(sy):
                        for xx in range(sx):
                            Y = 1 + y*sy + yy
                            X = x0 + x*sx + xx + ((H - Y)//4 if slant else 0) - 1
                            face[Y][X] = 1
        x0 += gw*sx + 2
    # trim width
    maxx = max(x for y in range(H) for x in range(W) if face[y][x])
    W = maxx + 3
    face = [r[:W] for r in face]
    out = blank(W, H)
    for y in range(H):  # drop shadow (blue) offset +1,+1
        for x in range(W):
            if face[y][x] and y+1 < H and x+1 < W: out[y+1][x+1] = 4
    for y in range(H):  # face: yellow upper, red lower band, with a bright top edge
        for x in range(W):
            if face[y][x]:
                out[y][x] = 1 if y < 1 + 7*sy*0.55 else 3
    return out
logo = make_logo('ASTEROIDS', slant=False)
LW = len(logo[0]); LH = len(logo)
# Big 'II' emblem
II = [[0]*16 for _ in range(15)]
for y in range(15):
    for x in range(16):
        bar = (2 <= x <= 5) or (10 <= x <= 13)
        serif = (y < 2 or y >= 13) and 0 <= x <= 15
        if bar or serif: II[y][x] = 3
for y in range(15):
    for x in range(16):
        if II[y][x] and (y in (0, 14) or x in (0, 15) or (II[y][x-1] == 0 if x else True)): II[y][x] = 1
emblem = II

def logo_bytes(g):
    w = len(g[0]); wb = (w+3)//4
    return wb, len(g), pack(g, enc_direct)

# ---------------- write include ----------------
def dbl(vals, per=16):
    return '\n'.join('    db ' + ','.join('$%02X' % v for v in vals[i:i+per]) for i in range(0, len(vals), per))

with open(OUT, 'w') as f:
    f.write('; generated by tools/gen_assets.py - do not edit\n')
    f.write('NSPRITES equ %d\n' % len(sprites))
    for name, val in (('SPR_SHIP', ship_ids[0]), ('SPR_SHIELD', shield0), ('SPR_SAUCER', saucer_ids[0]),
                      ('SPR_HUNTER', hunter_ids[0]), ('SPR_STING', sting_ids[0]), ('SPR_MINE', mine_ids[0]),
                      ('SPR_RING', ring_ids[0]), ('SPR_LIFEICON', lifeicon), ('SPR_BOMBICON', bombicon)):
        f.write('%s equ %d\n' % (name, val))
    for t in range(4):
        for s in 'LMS': f.write('SPR_ROCK_%d_%s equ %d\n' % (t, s, rock_ids[(t, s)][0]))
    for k, v in jewel_ids.items(): f.write('SPR_JEWEL_%s equ %d\n' % (k, v[0]))
    for k, v in pick_ids.items(): f.write('SPR_PICK_%s equ %d\n' % (k, v[0]))
    # sprite source table: w_px, h, then packed rows (unshifted)
    # simulate the run-time cache allocator (SRAM bank first, then main RAM)
    p = 0x4000; over = 0; insram = True
    for name, gg in sprites:
        w = len(gg[0]); h = len(gg); need = ((w+6)//4)*h*4
        if insram and p + need > 0x6800: insram = False
        if insram: p += need
        else: over += need
    f.write('CACHE_OVERFLOW equ %d\n' % over)
    f.write('\n    MACRO SPRITE_SOURCE\nsprite_src:\n')
    total = 0
    for i, (name, g) in enumerate(sprites):
        w = len(g[0]); h = len(g); data = pack(g)
        f.write('; %d %s %dx%d\n    db %d,%d\n' % (i, name, w, h, w, h))
        f.write(dbl(data) + '\n'); total += 2 + len(data)
    f.write('    ENDM\n')
    f.write('\nfont_data: ; ASCII 32-95, 5 bytes each (2bpp mask)\n' + dbl(font_bytes) + '\n')
    wb, h, d = logo_bytes(logo)
    f.write('\nLOGO_WB equ %d\nLOGO_H equ %d\nlogo_data:\n' % (wb, h) + dbl(d) + '\n')
    wb, h, d = logo_bytes(emblem)
    f.write('\nEMB_WB equ %d\nEMB_H equ %d\nemblem_data:\n' % (wb, h) + dbl(d) + '\n')
print('sprites', len(sprites), 'src bytes', total, 'logo', LW, 'x', LH, file=sys.stderr)

# ---------------- preview ----------------
PAL = [(59,8,255), (255,255,0), (59,8,255), (204,0,59), (7,255,0)]
cols = 16; cellw, cellh = 26, 16
rows_n = (len(sprites)+cols-1)//cols
img = Image.new('RGB', (cols*cellw*2, rows_n*cellh*3 + 120*3), (30,30,30))
def blit(g, X, Y):
    for y, r in enumerate(g):
        for x, c in enumerate(r):
            for yy in range(3):
                for xx in range(2):
                    img.putpixel((X+x*2+xx, Y+y*3+yy), PAL[c])
for i, (name, g) in enumerate(sprites):
    blit(g, (i % cols)*cellw*2 + 2, (i//cols)*cellh*3 + 2)
by = rows_n*cellh*3 + 6
blit(logo, 4, by); blit(emblem, 4 + LW*2 + 10, by)
img = img.resize((img.width*2, img.height*2), Image.NEAREST)
img.save(PREV)
