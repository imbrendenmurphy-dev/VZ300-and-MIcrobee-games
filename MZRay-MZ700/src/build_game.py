"""Builds DROPBEAR.MZT, the MZ-700 port of DROPBEAR 3D (step 1: world walkabout).
The world layout is DROPBEAR 3D's (VZ300 build.py), unchanged apart from dropping apostrophes
from area names (no safe display code for them yet)."""
import sys
from zasm import assemble, dispcode
from raytables import fill, mzt

# ---- textures: 8x8, colour letters K B R M G C Y W -------------------------------------------
DARK = {'W': 'C', 'Y': 'R', 'C': 'B', 'G': 'B', 'M': 'R', 'R': 'M', 'B': 'K', 'K': 'K'}
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
# themes: sky, ground, walls A (1), B (2), C (5), cracked (10)
THEMES = [
 ('STATION', 0x11, 0x44, 'brick', 'crate', 'iron'),
 ('BUSH',    0x11, 0x22, 'hedge', 'bark',  'cliff'),
 ('MINE',    0x00, 0x11, 'rock',  'timber','ore'),
 ('SWAMP',   0x33, 0x00, 'mud',   'reeds', 'bark'),
 ('RIDGE',   0x11, 0x22, 'sand',  'cliff', 'bones'),
 ('LAIR',    0x00, 0x11, 'cliff', 'bones', 'sand'),
]
TH = {t[0]: i for i, t in enumerate(THEMES)}
SLOTS = [1, 2, 5, 10]               # cell types that change with the theme
def theme_walls(i):
    nm, sky, gr, a, b, c = THEMES[i]
    return {1: T[a], 2: T[b], 5: T[c], 10: crack(T[a], 'W' if a in ('rock', 'cliff') else 'K')}

def texlist(theme):
    walls = dict(SHARED); walls.update(theme_walls(theme))
    out = []
    for typ in range(1, 11):
        t = walls[typ]; out += [t, dark(t)]
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
out.append('THEMES:\n' + '\n'.join(' db %d,%d\n dw TLIB%d' % (sky, gr, i) for i, (nm, sky, gr, a, b, c) in enumerate(THEMES)))
out.append('TOFF: db ' + ','.join(str((t-1)*16) for t in SLOTS))
for i in range(len(THEMES)):
    w = theme_walls(i); blk = []
    for t in SLOTS:
        for k in range(8):
            blk += [cb(ch) for ch in w[t][k]] + [cb(ch) for ch in dark(w[t])[k]]
    out.append('TLIB%d:\n%s' % (i, dbl(blk)))
out.append('SOLIDT: db ' + ','.join('1' if t in SOLIDDEC else '0' for t in range(24)))

# text
def msg(nm, s):
    assert len(s) <= 20, s
    out.append('%s: db %s' % (nm, ','.join(map(str, enc(s.ljust(20))))))
for nm, s in (('MSG_BLANK', ''), ('MSG_SECRET', 'SECRET FOUND'), ('MSG_DOOR', 'DOOR OPENS'),
              ('MSG_UNLOCK', 'UNLOCKED'), ('MSG_NEEDKEY', 'NEED A KEY'), ('MSG_GATE', 'A GATE OPENS'),
              ('MSG_MAP', 'GOT THE MAP'), ('MSG_KEY', 'GOT A KEY'), ('MSG_OPAL', 'OPAL. BEAUTY'),
              ('MSG_HEALTH', 'VEGEMITE PLUS 25'), ('MSG_AMMO', 'AMMO PLUS 15')):
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
page('PG_TITLE', [centre(2, 'DROPBEAR 3D'), centre(4, 'FOR THE SHARP MZ 700'), centre(6, 'WORLD WALKABOUT TEST V0.1'),
                  (10, 4, 'W S  OR UP DOWN      WALK'), (11, 4, 'A D  OR LEFT RIGHT   TURN'),
                  (12, 4, 'Q E                  STRAFE'), (13, 4, '1 2 3 4              RENDER MODE'),
                  centre(15, 'BUMP DOORS AND SWITCHES.'), centre(16, 'CRACKED WALLS HIDE SECRETS.'),
                  centre(17, 'NO CREATURES YET. PICKUPS ARE INVISIBLE.'),
                  centre(21, 'VIBED BY BPM 2026'), centre(23, 'PRESS SPACE')])
page('PG_HUD', [(23, 0, 'HEALTH'), (23, 12, 'AMMO'), (23, 21, 'KEYS'), (23, 29, 'OPALS'),
                (24, 0, 'FPS'), (24, 11, 'MODE'), (24, 19, 'KEYS 1 TO 4 SET MODE')])
page('PG_WIN', [centre(6, 'YOU BEAUTY'), centre(9, 'YOU MADE IT BACK TO THE UTE.'),
                (13, 10, 'OPALS FOUND    OF %d' % NOPALS), centre(18, 'VIBED BY BPM 2026'), centre(22, 'PRESS SPACE')])
(sx, sy), = [(x, y) for y, r in enumerate(AREAS[0]['rows']) for x, ch in enumerate(r) if ch == 'P']
consts = dict(NAREA=NAREA, STARTCELL=sy*16+sx, STARTANG=0, T_HEALTH=11, T_AMMO=12, T_KEY=13, T_OPAL=14,
              T_MAP=15, DECOR=16, WINNUM=0xD000+13*40+10+12)
gamedata = '\n'.join('%-10s equ %d' % kv for kv in consts.items()) + '\n' + '\n'.join(out)

src = open('game.asm').read().replace(';@@GAMEDATA@@', gamedata)
src = fill(src, [0]*256, texlist(0))
open('game_full.asm', 'w').write(src)
lo, data, sym = assemble(src)
assert sym['BUFEND'] <= 0xD000, 'out of memory: %04X' % sym['BUFEND']
open('DROPBEAR.MZT', 'wb').write(mzt(b'DROPBEAR 3D', lo, data, sym['start']))
open('game.sym', 'w').write('\n'.join('%-14s %04X' % (k, v) for k, v in sorted(sym.items(), key=lambda x: x[1])))
print('load %04X size %d end %04X exec %04X  work areas to %04X, free %d bytes' %
      (lo, len(data), lo+len(data)-1, sym['start'], sym['BUFEND'], 0xD000-sym['BUFEND']))
