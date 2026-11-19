"""Builds DROPBEAR.MZT, the MZ-700 port of DROPBEAR 3D (step 1: world walkabout).
The world layout is DROPBEAR 3D's (VZ300 build.py), unchanged apart from dropping apostrophes
from area names (no safe display code for them yet)."""
import sys
from zasm import assemble, dispcode
from raytables import fill, mzt

# ---- textures: 8x8, colour letters K B R M G C Y W -------------------------------------------
DARK = {'W': 'C', 'Y': 'R', 'C': 'B', 'G': 'G', 'M': 'R', 'R': 'M', 'B': 'K', 'K': 'K'}
def dark(t): return [''.join(DARK[c] for c in r) for r in t]
def crack(t, c='K'):
    t = [list(r) for r in t]
    for v, u in enumerate([3, 4, 4, 3, 3, 4, 5, 4]):
        t[v][u] = c
    t[2][5] = t[5][2] = c
    return [''.join(r) for r in t]

T = dict(
 brick =["KKKKKKKK","RRRRKRRR","RRRRKRRR","RRRRKRRR","KKKKKKKK","RKRRRRRR","RKRRRRRR","RKRRRRRR"],
 crate =["YYYYYYYY","YYRRRRYY","YRYRRYRY","YRRYYRRY","YRRYYRRY","YRYRRYRY","YYRRRRYY","YYYYYYYY"],
 iron  =["BBBBBBBB","CBCBCBCB","CBCBCBCB","CBWBCBWB","CBCBCBCB","CBCBCBCB","CBCBCBCB","BBBBBBBB"],
 hedge =["GGBGGGKG","GKGGBGGG","GGGKGGGB","BGGGGKGG","GGKGBGGG","GBGGGGKG","KGGBGGGG","GGGGKGBG"],
 bark  =["YYRYYYRY","YYRYYYRY","YYRYRYRY","YYRYYYRY","YYRYYYRY","YRRYYYRY","YYRYYYRY","YYRYYYRY"],
 cliff =["MMRMMMMR","MRMMMRMM","RMMMRMMM","MMMRMMMM","MMRMMMRM","MRMMMRMM","RMMMRMMM","MMMRMMMR"],
 rock  =["RRMRRRRM","RRRMRRRR","MRRRRMRR","RRRRRRMR","RMRRRRRR","RRRMRRRR","RRRRRMRR","MRRRRRRM"],
 timber=["YYYYYYYY","YRKKKKRY","YRKKKKRY","YRKKKKRY","YYYYYYYY","YRKKKKRY","YRKKKKRY","YRKKKKRY"],
 ore   =["RRMRRRRM","RYRMRRRR","MRRRRMRR","RRRRRCMR","RMRRRRRR","RRRMRYRR","RCRRRMRR","MRRRRRRM"],
 mud   =["GGGGGGGG","YGGGYGGG","GGGGGGYG","GGYGGGGG","GGGGGBGG","BGGBGGGB","BBGBBGBB","BBBBBBBB"],
 reeds =["BGBYBGBB","BGBYBGBG","BGBGBGBG","GGBGBGBG","BGBGGGBG","BGGGBGGG","GGGGGGGG","YYGYYGYY"],
 sand  =["YYYYYYYY","YYYYRYYY","RRRRRRRR","YYYYYYYY","YRYYYYYY","RRRRRRRR","YYYYYYYY","YYYRYYYY"],
 bones =["MMMMMMMM","MWMMMMWM","MWWWWWWM","MWMMMMWM","MMMKKMMM","MMKWWKMM","MMKKKKMM","MMMMMMMM"],
)
# shared walls: door 3, way out 4, locked 6, switch off 7, switch on 8, gate 9
SHARED = {
 3: ["WWWWWWWW","WCCCCCCW","WCWWWWCW","WCCCCCCW","WCCCCYCW","WCCCCCCW","WCCCCCCW","WWWWWWWW"],
 4: ["WWWWWWWW","BBBRBBBB","BBBRRBBB","RRRRRRBB","RRRRRRBB","BBBRRBBB","BBBRBBBB","WWWWWWWW"],
 6: ["RRRRRRRR","RYYKKYYR","RYKYYKYR","RYKKKKYR","RYKYYKYR","RYKKKKYR","RYYYYYYR","RRRRRRRR"],
 7: ["WWWWWWWW","WKKKKKKW","WKKKKKKW","WKKKKKKW","WKKYYKKW","WKKYYKKW","WKKYYKKW","WWWWWWWW"],
 8: ["WWWWWWWW","WKKGGKKW","WKKGGKKW","WKKGGKKW","WKKKKKKW","WKKKKKKW","WKKKKKKW","WWWWWWWW"],
 9: ["WWWWWWWW","CKKCKKCK","CKKCKKCK","CKKCKKCK","CKKCKKCK","CKKCKKCK","CKKCKKCK","WWWWWWWW"],
}
# fog: walls farther than the fog distance (cells, as in DROPBEAR) are drawn in a murky pattern
FOG = dict(mine=["RKRKRKRK", "KRKRKRKR"]*4, swamp=["MBMBMBMB", "BMBMBMBM"]*4, lair=["MKMKMKMK", "KMKMKMKM"]*4)
# themes: sky, ground, walls A (1), B (2), C (5), cracked (10), fog distance, fog pattern
THEMES = [
 ('STATION', 0x11, 0x44, 'brick', 'crate', 'iron',  0,   None),
 ('BUSH',    0x11, 0x22, 'hedge', 'bark',  'cliff', 0,   None),
 ('MINE',    0x00, 0x11, 'rock',  'timber','ore',   5.0, 'mine'),
 ('SWAMP',   0x33, 0x00, 'mud',   'reeds', 'bark',  7.0, 'swamp'),
 ('RIDGE',   0x11, 0x22, 'sand',  'cliff', 'bones', 0,   None),
 ('LAIR',    0x00, 0x11, 'cliff', 'bones', 'sand',  5.5, 'lair'),
]
TH = {t[0]: i for i, t in enumerate(THEMES)}
SLOTS = [1, 2, 5, 10, 16]           # cell types that change with the theme (16 = the fog texture)
FOGTEX = (16-1)*16
def theme_walls(i):
    nm, sky, gr, a, b, c, fd, fp = THEMES[i]
    return {1: T[a], 2: T[b], 5: T[c], 10: crack(T[a], 'W' if a in ('rock', 'cliff') else 'K'),
            16: FOG[fp] if fp else T[a]}
def fogh(i):
    import raytables
    fd = THEMES[i][6]
    return round(raytables.PROJ/fd) if fd else 0

def texlist(theme):
    walls = dict(SHARED); walls.update(theme_walls(theme))
    out = []
    for typ in range(1, 17):
        t = walls.get(typ, T['brick'])
        out += [t, t if typ == 16 else dark(t)]
    return out
COL = {'K':0,'B':1,'R':2,'M':3,'G':4,'C':5,'Y':6,'W':7}
def cb(ch): c = COL[ch]; return c << 4 | c

# ---- the world (DROPBEAR 3D areas) ------------------------------------------------------------
AREAS = [
 dict(name="THE HOMESTEAD", theme='STATION', known=1, exits=[1], rows=[
  "################","#P...#..lo#.g..#","#....#....#.b..#","#....D....D..r.#","#.ra.#.t..#....#","###D####%###D###",
  "#....#..o..#..g#","#.CC.#.....#.h.#","#.CC.#######...#","#l...D....l....#","#.b..#..CCC..b.#","#..t.#..C.C....#",
  "#WWWW#..r.t....#","#..o%....g...r.#","#...#....b.....X","################"]),
 dict(name="THE BUSH TRACK", theme='BUSH', known=1, exits=[0, 2, 3], rows=[
  "################","#...q.#..j...g.#","X.....#..v.....#","#.....D.....CC.#","#..C.b#.n...CC.#","#..C..###D######",
  "#j......#.b..q.#","##.###..#......X","#....#..%..o...#","#.o.n#..#.gh...#","#....#..########","#.a..D....n....#",
  "###L###..v..CC.#","X.....#.....CC.#","#....b#.qb..o.j#","################"]),
 dict(name="GUM TREE MAZE", theme='BUSH', known=0, exits=[1], rows=[
  "################","#m#.....#..g..o#","#.#.###.#.###..#","#.#.#...#...#..#","#...#.#####.#.##","###.#.#.n.#.#..#",
  "#...#...#.#.##.#","X.###.#.#.#....#","#.....#.#.####.#","####.##.#..n.#.#","#..#.#..####.#.#","#.##.#.##..#.#.#",
  "#.#..#.n..##.#.#","#.#.#####.#..#.#","#o..g.v...#k.b.#","################"]),
 dict(name="THE OLD MINE", theme='MINE', known=0, exits=[1, 4], rows=[
  "################","#..l.WW..c.#...#","X....WW..b.#.o.#","#......s...#.l.#","#.WW...WW..##D##","#.WW.b.WW..s...#",
  "#..r.......WW..#","####D#####.WW..#","#..l.#.....v...#","#.m..#..WWWGWWWW","#s...#..W.b.s.h#","#..b.#..W......#",
  "#....#..W.WWWW.#","##S###..W.W..%.#","#a..s...W.Wo.W.X","################"]),
 dict(name="BIG FELLA'S DEN", theme='MINE', known=1, exits=[3, 5], rows=[
  "################","#.....#..l..l..#","X..a..D........#","#.....#..W..W..#","#.h...#.x....x.#","###D###...B....#",
  "#.s...#........#","#..o..#..W..W..#","#...c.#.s....s.#","#.....#######G##","#.b...#.....#..#","#...s.#..o..#..#",
  "#.....%.....#..#","#.c...#..x..#..#","#..a..#.....#..X","################"]),
 dict(name="THE BILLABONG", theme='SWAMP', known=0, exits=[4, 6], rows=[
  "################","#....te#..v....#","X..CC..#.CC.uCC#","#..CC..D.CC..t.#","#....v.#....b..#","#......###L#####",
  "##D#####.......#","#e...n.#.CC.v..#","#.CC...#.CC...u#","#.CC.b.#.b.WWt.#","#..t...#...WW.o#","#.k..m.#.t.....#",
  "####%###.n.....#","#.o.h..#e......#","#......#..a....X","################"]),
 dict(name="BUNYIP'S POOL", theme='SWAMP', known=1, exits=[5, 7], rows=[
  "################","#....e#e.....e.#","X.....D...CC...#","#..h..#...CC.t.#","#.....#.t......#","#..a..#.CC..U..#",
  "##D####.CC.....#","#..n..#......u.#","#.o...#.u.CC...#","#....n#...CC.t.#","#..v..#........#","#e....######G###",
  "#.....#.v.t...o#","#..a.t#...e....#","#.....#........X","################"]),
 dict(name="THE RIDGE", theme='RIDGE', known=0, exits=[6, 8], rows=[
  "################","#.....#.v...#.o#","X.###.#.###.#..#","#.#x..#...#.#L##","#.#.#####n#....#","#.#..b..#.####n#",
  "#.#####.#..d.#.#","#m....#...k..#.#","#####G###S######","#......j....d..#","#.WW.qb...WW...#","#.WW......WWj..#",
  "#...d..v.x.....#","#..a....n..h...#","#..x.......o...X","################"]),
 dict(name="YOWIE'S LAIR", theme='LAIR', known=1, exits=[7, 255], rows=[
  "################","#.....#..l...l.#","X..h..D.u....d.#","#.....#..WW....#","#..a..#..WW.Y..#","###D###x.......#",
  "#.....#....WW.x#","#..o.d#.s..WW..#","#.....D......s.#","#.b...#######G##","#..s..#..x....v#","#..a..#.u.....o#",
  "#.....#.......h#","#.d...#..l.....#","#..v..#........X","################"]),
]
NAREA = len(AREAS)
CELL = {'#': 1, 'C': 2, 'D': 3, 'X': 4, 'W': 5, 'L': 6, 'S': 7, 'G': 9, '%': 10}
OBJC = {'b': 1, 'v': 2, 'B': 3, 'U': 4, 'Y': 5, 't': 6, 'g': 7, 'n': 8, 's': 9, 'd': 10,
        'h': 11, 'a': 12, 'k': 13, 'o': 14, 'm': 15,
        'r': 16, 'l': 17, 'j': 18, 'q': 19, 'c': 20, 'u': 21, 'e': 22, 'x': 23}
SOLIDDEC = {16, 18, 19, 20, 21}
DIRS = {(1, 0): 0, (0, 1): 1, (-1, 0): 2, (0, -1): 3}

WORLD = []
for A in AREAS:
    rows = A['rows']; assert len(rows) == 16 and all(len(r) == 16 for r in rows), A['name']
    grid = [[CELL.get(ch, 0) for ch in r] for r in rows]
    objs = [(OBJC[ch], x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch in OBJC]
    assert len(objs) <= 32, A['name']
    xs = [(x, y) for y in range(16) for x in range(16) if rows[y][x] == 'X']
    assert len(xs) == len(A['exits']), A['name']
    WORLD.append(dict(grid=grid, objs=objs, xs=xs))
def entry_for(area, cell):
    x, y = cell; g = WORLD[area]['grid']
    for (dx, dy), f in DIRS.items():
        if 0 <= x+dx < 16 and 0 <= y+dy < 16 and g[y+dy][x+dx] == 0 and AREAS[area]['rows'][y+dy][x+dx] not in OBJC:
            return (x+dx, y+dy), f
    raise SystemExit('no floor beside exit %s in %s' % (cell, AREAS[area]['name']))

def enc(s): return [dispcode(c) for c in s] + [0xFF]
def dbl(vals): return '\n'.join(' db ' + ','.join(str(v & 0xFF) for v in vals[i:i+16]) for i in range(0, len(vals), 16))

out = []
recs = []
for ai, A in enumerate(AREAS):
    W = WORLD[ai]; ex = []
    for (x, y), tgt in zip(W['xs'], A['exits']):
        if tgt == 255: ex += [y*16+x, 255, 0, 0]; continue
        back = [c for c, t in zip(WORLD[tgt]['xs'], AREAS[tgt]['exits']) if t == ai]
        assert len(back) == 1, (A['name'], tgt)
        (cx, cy), face = entry_for(tgt, back[0])
        ex += [y*16+x, tgt, cy*16+cx, face]
    name = A['name'].replace("'", '').ljust(16)
    data = [TH[A['theme']], A['known']] + enc(name) + [len(W['xs'])] + ex + [len(W['objs'])]
    for o in W['objs']: data += list(o)
    flatg = [c for r in W['grid'] for c in r]
    data += [flatg[i] << 4 | flatg[i+1] for i in range(0, 256, 2)]
    out.append('AREA%d:\n%s' % (ai, dbl(data)))
out.append('ATAB: dw ' + ','.join('AREA%d' % i for i in range(NAREA)))

# theme table and wall library: per theme, slot (A, B, C, cracked) x row x (8 light + 8 dark)
out.append('THEMES:\n' + '\n'.join(' db %d,%d\n dw TLIB%d\n db %d,0,0,0' % (t[1], t[2], i, fogh(i))
                                    for i, t in enumerate(THEMES)))
out.append('TOFF: db ' + ','.join(str((t-1)*16) for t in SLOTS))
for i in range(len(THEMES)):
    w = theme_walls(i); blk = []
    for t in SLOTS:
        d = w[t] if t == 16 else dark(w[t])
        for k in range(8):
            blk += [cb(ch) for ch in w[t][k]] + [cb(ch) for ch in d[k]]
    out.append('TLIB%d:\n%s' % (i, dbl(blk)))
out.append('SOLIDT: db ' + ','.join('1' if t in SOLIDDEC else '0' for t in range(24)))
def msg(nm, s):
    assert len(s) <= 20, s
    out.append('%s: db %s' % (nm, ','.join(map(str, enc(s.ljust(20))))))

# ---- sprites: 16x16 pages, byte index u*16+v, FF = see-through ---------------------------------
import dbart as A_
SPRPAGES = {}
PREVIEW = {}
def sprpage(name, fn, pal, outline='K'):
    g = A_.raster(fn, pal, outline)
    PREVIEW[name] = g
    data = [0xFF]*256
    for v in range(16):
        for u in range(16):
            if g[v][u] is not None: data[u*16+v] = cb(g[v][u])
    out.append(' align 256\n%s:\n%s' % (name, dbl(data)))
    return name
def pal(s): return {i: c for i, c in enumerate(s)}      # shape colours 0,1,2,3 -> MZ letters
# type: frames (fn0, fn1), palette, outline, frac, aspect, raise, hp, speed, bite, flags, kill message
TYPES = [
 ('BEAR',    (A_.bear_walk, A_.bear_bite),     'CWKR', 'B', .62, 1.125, 0,   2, 13,  8, 0, 'GOT ONE'),
 ('BAT',     (A_.bat_up, A_.bat_dn),           'KYRM', 'K', .30, 1.6,  .35,  1, 17,  4, 8, 'BAT DOWN'),
 ('BIGF',    (A_.bear_walk, A_.bear_bite),     'RYKW', 'K', .95, 1.125, 0,  18,  9, 15, 1, 'BIG FELLA DOWN'),
 ('BUNYIP',  (A_.bunyip_walk, A_.bunyip_bite), 'KGRY', 'K', .70, 1.4,   0,  24, 24, 15, 3, 'BUNYIP BEATEN'),
 ('YOWIE',   (A_.yowie_walk, A_.yowie_bite),   'RWKY', 'K', 1.0, 0.8,   0,  24,  7, 18, 5, 'YOWIE DOWN'),
 ('TOAD',    (A_.toad_sit, A_.toad_hop),       'WGKY', 'K', .24, 1.3,   0,   1, 22,  4, 2, 'TOAD SQUASHED'),
 ('MAGPIE',  (A_.mag_up, A_.mag_dn),           'YWKR', 'C', .26, 1.5,  .35,  1, 20,  5, 8, 'MAGPIE DOWN'),
 ('SNAKE',   (A_.snake_up, A_.snake_hit),      'KYRG', 'K', .30, 1.35,  0,   2,  8,  9, 0, 'SNAKE GONE'),
 ('SPIDER',  (A_.spider_a, A_.spider_b),       'KWYR', 'K', .26, 1.7,   0,   1, 18,  5, 0, 'SPIDER SPLAT'),
 ('DINGO',   (A_.dingo_run, A_.dingo_bite),    'KWRY', 'K', .50, 0.9,   0,   3, 18,  8, 0, 'DINGO DOWN'),
 ('HEALTH',  (A_.item_health,),                'KYWR', 'K', .28, 1.1,   0,   0,  0,  0, 0, ''),
 ('AMMO',    (A_.item_ammo,),                  'KYGR', 'K', .28, 1.4,   0,   0,  0,  0, 0, ''),
 ('KEY',     (A_.item_key,),                   'KYKK', 'K', .28, 1.8,   0,   0,  0,  0, 0, ''),
 ('OPAL',    (A_.item_opal,),                  'WCKM', 'K', .28, 0.8,   0,   0,  0,  0, 0, ''),
 ('MAPI',    (A_.item_map,),                   'WKKY', 'K', .28, 1.3,   0,   0,  0,  0, 0, ''),
 ('DRUM',    (A_.d_drum,),                     'KYKR', 'K', .45, 0.7,   0,   0,  0,  0, 0, ''),
 ('LAMP',    (A_.d_lamp,),                     'KWKY', 'K', .34, 0.55, .66,  0,  0,  0, 0, ''),
 ('SHRUB',   (A_.d_shrub,),                    'GYKK', 'K', .45, 1.0,   0,   0,  0,  0, 0, ''),
 ('TERMITE', (A_.d_termite,),                  'KKKR', 'K', .70, 0.55,  0,   0,  0,  0, 0, ''),
 ('CART',    (A_.d_cart,),                     'KYKB', 'K', .42, 1.25,  0,   0,  0,  0, 0, ''),
 ('STUMP',   (A_.d_stump,),                    'KRKY', 'K', .50, 0.75,  0,   0,  0,  0, 0, ''),
 ('REEDS',   (A_.d_reeds,),                    'KYRG', 'K', .50, 0.9,   0,   0,  0,  0, 0, ''),
 ('BONES',   (A_.d_bones,),                    'WKKK', 'K', .28, 1.2,   0,   0,  0,  0, 0, ''),
]
assert len(TYPES) == 23
# burst size when beaten (DROPBEAR's piece counts)
BURSTN = dict(BEAR=22, BAT=14, BIGF=32, BUNYIP=32, YOWIE=32, TOAD=14, MAGPIE=14, SNAKE=16, SPIDER=14, DINGO=20)
# automap colours by cell: floor, walls (blue), door, way out, locked, switches, gate; cracked walls stay secret
MAPCOL = [0x00, 0x11, 0x11, 0x55, 0x66, 0x11, 0x22, 0x44, 0x44, 0x33, 0x11] + [0x11]*5
tt = [' align 256', 'MAPCOL: db ' + ','.join(map(str, MAPCOL)), 'TYPET:', ' ds 16']
for nm, frames, p, ol, frac, asp, rs, hp, sp, bite, fl, kmsg in TYPES:
    pages = [sprpage('SPR_%s%d' % (nm, i), f, pal(p), ol) for i, f in enumerate(frames)]
    if len(pages) == 1: pages.append(pages[0])
    if kmsg: msgname = 'MSG_K_' + nm; msg(msgname, kmsg)
    else: msgname = 'MSG_BLANK'
    bc = [c for c in p if c != 'K'] or ['W']          # pieces in the creature's own colours
    bc = [cb(bc[i % len(bc)]) for i in range(4)]
    tt.append(' db %s>>8,%s>>8,%d,%d,%d,%d,%d,%d,%d\n dw %s\n db %s,%d' %
              (pages[0], pages[1], min(255, round(frac*256)), round(asp*64), round(rs*256), hp, sp, bite, fl, msgname,
               ','.join(map(str, bc)), BURSTN.get(nm, 0)))
out.append('\n'.join(tt))

# the gun: art at its final size, one texel per cell (u = column, v = row)
GUN = ["....KWWK....",
       "...KCCWWK...",
       "..KBBCWBBK..",
       ".KBBBBBBBBK.",
       "KBBYYBBYYBBK"]
GUNF = ["..YRYWWYRY..",
        "...KYCWYK...",
        "..KBBCWBBK..",
        ".KBBBBBBBBK.",
        "KBBYYBBYYBBK"]
def gunpage(name, art):
    data = [0xFF]*256
    for v, r in enumerate(art):
        for u, ch in enumerate(r):
            if ch != '.': data[u*16+v] = cb(ch)
    out.append(' align 256\n%s:\n%s' % (name, dbl(data)))
gunpage('GUN0', GUN); gunpage('GUN1', GUNF)
# u step per column for a sprite w columns wide (8.8 texels, 16 texels across), and v step per row
ust = [0] + [16*256//w for w in range(1, 256)]
out.append(' align 256\nUSTL:\n%s\nUSTH:\n%s' % (dbl([v & 255 for v in ust]), dbl([v >> 8 for v in ust])))
out.append(' align 256\nSVSTEP:\n%s' % dbl([255] + [max(1, min(255, 256//h)) for h in range(1, 256)]))
# cull distance for a farthest wall of height h: things farther than this (Chebyshev, 8.8 cells)
# can't be in view. Wall height h means distance PROJ/h; on-screen things have z >= 0.85*distance,
# and Chebyshev >= distance/1.42, so cull above 1.42*PROJ/h/0.85 plus half a cell.
import raytables
df = [0x7FFF if h < 2 else min(0x7FFF, int((raytables.PROJ/h*1.42/0.85 + 0.5)*256)) for h in range(256)]
out.append(' align 256\nDFL:\n%s\nDFH:\n%s' % (dbl([v & 255 for v in df]), dbl([v >> 8 for v in df])))
out.append('ROW40: dw ' + ','.join(str(r*40) for r in range(raytables.VIEWH)))

# ---- sound -------------------------------------------------------------------------------------
# 8253 counter 0 clock on the MZ-700 (assumed 894.886 kHz; if the PAL machine differs, every pitch
# shifts by the same ratio, so tunes stay in tune).
SCLK = 894886
NOTE = {n: 440*2**((i-9)/12) for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}
def freq(n): return NOTE[n[:-1]]*2**(int(n[-1])-4)
def count(n): return round(SCLK/freq(n))
# effect parts: (start count, change per field, noise mask, fields). Bigger count = lower pitch.
SFX = dict(
 SHOT  =[(220, 90, 0x0F, 3), (1200, 150, 0x7F, 3)],              # wucka-thump
 HIT   =[(900, 250, 0x3F, 5)],                                   # thwack
 KILL  =[(500, 200, 0xFF, 8), (2600, 300, 0x7F, 10)],             # spurt, then squelch
 BOSS  =[(400, 120, 0xFF, 20), (3000, 150, 0xFF, 30)],            # long rumbling splat
 BITE  =[(2600, -120, 0x3F, 7)],                                  # a growly chomp
 PICK  =[(count('E6'), 0, 0, 3), (count('A6'), 0, 0, 4)],         # ding-ding
 EMPTY =[(3000, 0, 0, 1)],                                        # click
 DOOR  =[(2200, -120, 0x0F, 10)],                                 # creak
 SECRET=[(1500, -80, 0, 6), (900, -40, 0, 8)],
 NOKEY =[(3500, 0, 0x07, 6)],                                     # rattle
 GATE  =[(3200, -150, 0x1F, 14)],
 DEATH =[(1200, 60, 0x07, 25), (4000, 100, 0x3F, 20)],            # sad slide down
 WIN   =[(count(n), 0, 0x01, 7) for n in ('C5', 'E5', 'G5', 'C6', 'G5', 'C6')],
)
for nm, parts in SFX.items():
    lines = []
    for i, (c, dlt, mask, f) in enumerate(parts):
        nxt = 'SFX_%s_%d' % (nm, i+1) if i+1 < len(parts) else '0'
        lines.append('%s: dw %d,%d\n db %d,%d\n dw %s' % ('SFX_'+nm if i == 0 else 'SFX_%s_%d' % (nm, i),
                                                        c, dlt & 0xFFFF, mask, f, nxt))
    out.append('\n'.join(lines))
# DROPBEAR's in-game tune: sparse dinks, one step every MUSP fields
GT = ['E4', '-', '-', 'E4', 'G4', 'E4', '-', '-', 'D4', '-', '-', 'D4', 'F4', 'D4', '-', '-',
      'E4', '-', '-', 'E4', 'G4', 'A4', '-', '-', 'B4', '-', 'A4', '-', 'G4', '-', '-', '-']
out.append('GTUNE: dw ' + ','.join('0' if n == '-' else str(count(n)) for n in GT) + ',0xFFFF')
qs = [n*n//4 for n in range(512)]              # quarter squares for the fast 8x8 multiply
out.append(' align 256\nQSL:\n%s\nQSH:\n%s' % (dbl([v & 255 for v in qs]), dbl([v >> 8 for v in qs])))

# text
for nm, s in (('MSG_BLANK', ''), ('MSG_SECRET', 'SECRET FOUND'), ('MSG_DOOR', 'DOOR OPENS'),
              ('MSG_UNLOCK', 'UNLOCKED'), ('MSG_NEEDKEY', 'NEED A KEY'), ('MSG_GATE', 'A GATE OPENS'),
              ('MSG_MAP', 'GOT THE MAP'), ('MSG_KEY', 'GOT A KEY'), ('MSG_OPAL', 'OPAL. BEAUTY'),
              ('MSG_HEALTH', 'VEGEMITE PLUS 25'), ('MSG_AMMO', 'AMMO PLUS 15'), ('MSG_OUCH', 'OUCH'), ('MSG_NOMAP', 'NO MAP HERE YET')):
    msg(nm, s)
def page(nm, items):
    lines = [nm + ':']
    for r, c, s in items:
        assert c + len(s) <= 40, s
        lines.append(' dw %d\n db %s' % (0xD000 + r*40 + c, ','.join(map(str, enc(s)))))
    lines.append(' dw 0')
    out.append('\n'.join(lines))
def centre(r, s): return (r, (40-len(s))//2, s)
NOPALS = sum(1 for W in WORLD for o in W['objs'] if o[0] == 14)
# ---- title screen: a chunky arched logo in colour cells, Doom-parody style, with slime drips ----------
LOGOFONT = {
 'D': ["###.", "##.#", "##.#", "##.#", "##.#", "##.#", "###."],
 'R': ["###.", "##.#", "##.#", "###.", "##.#", "##.#", "##.#"],
 'O': [".##.", "##.#", "##.#", "##.#", "##.#", "##.#", ".##."],
 'P': ["###.", "##.#", "##.#", "###.", "##..", "##..", "##.."],
 'B': ["###.", "##.#", "##.#", "###.", "##.#", "##.#", "###."],
 'E': ["####", "##..", "##..", "###.", "##..", "##..", "####"],
 'A': [".##.", "##.#", "##.#", "####", "##.#", "##.#", "##.#"]}
SMALLFONT = {'3': ["###", "..#", ".##", "..#", "###"], 'D': ["##.", "#.#", "#.#", "#.#", "##."]}
TROWS = 18
def make_title():
    L = [[0]*40 for _ in range(TROWS)]                 # 1 big letters, 2 the small "3D"
    base = 10; heights = [9, 8, 7, 7, 7, 7, 8, 9]       # taller towards the ends: an arch
    for k, ch in enumerate("DROPBEAR"):
        x0 = k*5; h = heights[k]
        for yy in range(h):
            sy = min(6, int(yy*7/h)); y = base-h+1+yy
            for x in range(4):
                if LOGOFONT[ch][sy][x] == '#': L[y][x0+x] = 1
    for k, ch in enumerate("3D"):
        for y, r in enumerate(SMALLFONT[ch]):
            for x, c in enumerate(r):
                if c == '#': L[13+y][16+k*4+x] = 2
    pic = [['K']*40 for _ in range(TROWS)]
    for y in range(TROWS):                              # extrusion straight down (keeps the gaps between letters)
        for x in range(40):
            if L[y][x]:
                for dx, dy in ((0, 1),):
                    if y+dy < TROWS and x+dx < 40 and not L[y+dy][x+dx]: pic[y+dy][x+dx] = 'B'
    for y in range(TROWS):                              # hot metal: yellow top edge, red body, magenta base
        for x in range(40):
            if L[y][x] == 1:
                top = y == 0 or not L[y-1][x]
                bot = y+1 >= TROWS or not L[y+1][x] or y == base
                pic[y][x] = 'Y' if top else ('M' if bot else 'R')
            elif L[y][x] == 2:
                pic[y][x] = 'W' if (y == 0 or not L[y-1][x]) else 'C'
    for k, ln in ((0, 3), (2, 2), (5, 4), (7, 3)):     # green slime dripping off D, O, E, R
        x = k*5 + 1
        for y in range(base+1, base+1+ln): pic[y][x] = 'G'
    return pic
TPIC = make_title()
out.append('TSCR:\n%s\nTSCRLEN equ %d' % (dbl([cb(c) for r in TPIC for c in r]), TROWS*40))
page('PG_TITLE', [centre(19, 'VIBED BY BPM 2026'), centre(21, 'W S A D Q E MOVE  SPACE FIRE  M MAP'),
                  centre(23, 'PRESS SPACE TO PLAY')])
page('PG_INTRO', [centre(2, 'GDAY RANGER.'), centre(5, 'DROP BEARS HAVE OVERRUN THE OUTBACK.'),
                  centre(7, 'FIGHT THROUGH NINE AREAS. BEAT THE'), centre(9, 'BIG THREE AND GET BACK TO YOUR UTE.'),
                  centre(12, 'KEYS OPEN LOCKED DOORS.'), centre(13, 'BUMP SWITCHES TO OPEN GATES.'),
                  centre(14, 'CRACKED WALLS HIDE OPALS.'), centre(15, 'HOLD M FOR THE MAP.'),
                  centre(17, 'KEYS 1 2 3 4 CHANGE THE RENDER MODE.'), centre(19, 'TEST V0.5'),
                  centre(22, 'PRESS SPACE')])
msg('MSG_DEMO', 'DEMO. PRESS SPACE')

# ---- title music: DROPBEAR's three voices, slow and ominous, with a cheeky ending -----------------
# one row per change: bass, mid, top counts and how many fields; the player arpeggiates them.
TN = {'A1': 55.0, 'Bb1': 58.27, 'E2': 82.41, 'G#2': 103.83, 'A2': 110.0, 'Bb2': 116.54, 'B2': 123.47, 'C3': 130.81,
      'Db3': 138.59, 'D#3': 155.56, 'E3': 164.81, 'F3': 174.61, 'F#3': 185.0, 'G3': 196.0, 'G#3': 207.65, 'A3': 220.0,
      'Bb3': 233.08}
v_bass = []; v_mid = []; v_top = []
for bar in range(20):                                   # heartbeat: dum-dum ... dum-dum
    t = bar*2; v_bass += [(t, .25, 'A1'), (t+.5, .25, 'A1')]
for k in range(8): v_bass.append((40+k*.5, .25, 'A1' if k % 2 == 0 else 'Bb1'))
for k, n in enumerate(['A2', 'Bb2', 'A2', 'G#2']): v_mid.append((8+k*4, 3.5, n))
for k, n in enumerate(['C3', 'Db3', 'C3', 'B2']): v_mid.append((24+k*4, 3.5, n))
for k, n in enumerate(['E3', 'F3', 'E3', 'D#3', 'A3', 'G#3', 'G3', 'F#3']): v_top.append((24+k*2, 1.75, n))
v_mid.append((40, 3.8, 'E3')); v_top.append((40, 3.8, 'Bb3'))   # the stinger: a tritone
v_top += [(45, .55, 'Bb2'), (45.7, .55, 'A2'), (46.4, 1.6, 'G#2')]   # ...and a sad trombone
v_bass.append((46.4, 1.6, 'E2'))
def at(voice, t):
    for t0, d, n in voice:
        if t0 <= t < t0+d: return n
    return None
FPB = 25                                                # fields per beat (half a second)
rows = []
for f in range(int(48.5*FPB)):
    t = f/FPB
    key = tuple(round(SCLK/TN[n]) if n else 0 for n in (at(v_bass, t), at(v_mid, t), at(v_top, t)))
    if rows and rows[-1][0] == key and rows[-1][1] < 255: rows[-1][1] += 1
    else: rows.append([key, 1])
tm = []
for (b, mm, tp), n in rows: tm += [b & 255, b >> 8, mm & 255, mm >> 8, tp & 255, tp >> 8, n]
tm += [0]*7
out.append('TMUS:\n' + dbl(tm))

# ---- the gallery: the locals introduce themselves (no apostrophes: no safe display code yet) ---------
GAL = [('BEAR', 'DROP BEAR', 'I DROP OUT OF TREES.', 'MOSTLY ON PURPOSE.', ('C5', 'E5', 'G5')),
       ('BAT', 'FRUIT BAT', 'I ONLY CAME FOR THE MANGOES.', 'THE BITING JUST HAPPENS.', ('E5', 'G5', 'B5')),
       ('TOAD', 'CANE TOAD', 'NOBODY INVITED ME.', 'I STAYED ANYWAY.', ('G4', 'C5', 'E5')),
       ('MAGPIE', 'MAGPIE', 'I SWOOP. I MISS. I SWOOP AGAIN.', 'IT IS A SPRING THING.', ('A5', 'C6', 'E6')),
       ('SNAKE', 'SNAKE', 'SLOW BUT GRUMPY ABOUT IT.', 'PLEASE DO NOT STEP ON ME.', ('D5', 'F5', 'A5')),
       ('SPIDER', 'HUNTSMAN', 'I AM TOTALLY HARMLESS.', 'SO WHY IS EVERYONE SCREAMING.', ('F5', 'A5', 'C6')),
       ('DINGO', 'DINGO', 'I ATE YOUR SANDWICH.', 'AND I WOULD DO IT AGAIN.', ('C5', 'D#5', 'G5')),
       ('BIGF', 'BIG FELLA', 'I AM NOT FAT.', 'I AM BIG BONED.', ('C4', 'D#4', 'F#4')),
       ('BUNYIP', 'THE BUNYIP', 'MOSTLY TEETH.', 'SOME FEELINGS.', ('D4', 'F4', 'G#4')),
       ('YOWIE', 'THE YOWIE', 'BLURRY IN EVERY PHOTO.', 'THIS IS MY GOOD SIDE.', ('E4', 'G4', 'A#4'))]
gt = ['GALT:']
for i, (sp, name, l1, l2, notes) in enumerate(GAL):
    page('PG_GAL%d' % i, [centre(19, name), centre(21, l1), centre(22, l2)])
    lines = []
    for j, n in enumerate(notes):                       # ta-da: three short notes
        nxt = 'SFX_GAL%d_%d' % (i, j+1) if j < 2 else '0'
        lines.append('SFX_GAL%d_%d: dw %d,0\n db 1,6\n dw %s' % (i, j, count(n), nxt))
    out.append('\n'.join(lines))
    gt.append(' dw SPR_%s0,SPR_%s1,PG_GAL%d,SFX_GAL%d_0' % (sp, sp, i, i))
gt.append(' dw 0')
out.append('\n'.join(gt))

# ---- where the demo starts in each area: a way in, facing into the room ------------------------------
dt = []
for ai in range(NAREA):
    if ai == 0: dt += [sy0*16+sx0 for sx0, sy0 in [(1, 1)]] + [0]; continue
    src_ = [(a0, c) for a0, A0 in enumerate(AREAS) for c, t in zip(WORLD[a0]['xs'], A0['exits']) if t == ai][0]
    back = [c for c, t in zip(WORLD[ai]['xs'], AREAS[ai]['exits']) if t == src_[0]][0]
    (cx, cy), face = entry_for(ai, back)
    dt += [cy*16+cx, face]
out.append('DEMOTAB: db ' + ','.join(map(str, dt)))
page('PG_DEAD', [centre(8, 'OUCH'), centre(11, 'THE DROP BEARS GOT YOU.'), centre(14, 'HAVE ANOTHER GO MATE.'),
                 centre(20, 'PRESS SPACE')])
page('PG_HUD', [(23, 0, 'HEALTH'), (23, 12, 'AMMO'), (23, 21, 'KEYS'), (23, 29, 'OPALS'),
                (24, 0, 'FPS'), (24, 11, 'MODE'), (24, 19, 'KEYS 1 TO 4 SET MODE')])
page('PG_WIN', [centre(5, 'YOU BEAUTY'), centre(8, 'THE YOWIE IS DOWN AND THE'), centre(10, 'UTE ROARS OFF HOME.'),
                (14, 10, 'OPALS FOUND    OF %d' % NOPALS), centre(19, 'VIBED BY BPM 2026'), centre(22, 'PRESS SPACE')])
(sx, sy), = [(x, y) for y, r in enumerate(AREAS[0]['rows']) for x, ch in enumerate(r) if ch == 'P']
consts = dict(NAREA=NAREA, STARTCELL=sy*16+sx, STARTANG=0, T_HEALTH=11, T_AMMO=12, T_KEY=13, T_OPAL=14,
              T_MAP=15, DECOR=16, NENEMY=10, WINNUM=0xD000+14*40+10+12,
              GUNW=len(GUN[0]), GUNL=20-len(GUN[0])//2, GUNH=len(GUN), MUSP=14, FOGTEX=FOGTEX,
              DEMOFLD=25*50)
gamedata = '\n'.join('%-10s equ %d' % kv for kv in consts.items()) + '\n' + '\n'.join(out)

src = open('game.asm').read().replace(';@@GAMEDATA@@', gamedata).replace(';@@OBJECTS@@', open('objects.asm').read()).replace(';@@FX@@', open('fx.asm').read()).replace(';@@ATTRACT@@', open('attract.asm').read())
src = fill(src, [0]*256, texlist(0), sprhook=' call sprcol', predraw=' call fogchk')
if '--preview' in sys.argv:                    # contact sheet of every sprite
    from PIL import Image
    RGB = {'K': (0, 0, 0), 'B': (0, 0, 255), 'R': (255, 0, 0), 'M': (255, 0, 255), 'G': (0, 255, 0),
           'C': (0, 255, 255), 'Y': (255, 255, 0), 'W': (255, 255, 255)}
    names = sorted(PREVIEW); cols = 8; S = 8
    im = Image.new('RGB', (cols*17*S, ((len(names)+cols-1)//cols)*17*S), (40, 40, 60))
    for i, nm in enumerate(names):
        g = PREVIEW[nm]; ox = (i % cols)*17*S; oy = (i//cols)*17*S
        for y in range(16):
            for x in range(16):
                if g[y][x]: im.paste(RGB[g[y][x]], (ox+x*S, oy+y*S, ox+x*S+S, oy+y*S+S))
    im.save('sprites.png')
open('game_full.asm', 'w').write(src)
lo, data, sym = assemble(src)
assert sym['BUFEND'] <= 0xD000, 'out of memory: %04X' % sym['BUFEND']
open('DROPBEAR.MZT', 'wb').write(mzt(b'DROPBEAR 3D', lo, data, sym['start']))
open('game.sym', 'w').write('\n'.join('%-14s %04X' % (k, v) for k, v in sorted(sym.items(), key=lambda x: x[1])))
print('load %04X size %d end %04X exec %04X  work areas to %04X, free %d bytes' %
      (lo, len(data), lo+len(data)-1, sym['start'], sym['BUFEND'], 0xD000-sym['BUFEND']))
