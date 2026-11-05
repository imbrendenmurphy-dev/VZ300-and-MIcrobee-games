# Sprite / tile art. Logical colours: '.'=0 (transparent / floor), 'y'=1, 'b'=2, 'r'=3
# CSS0 physical: 0 green 1 yellow 2 blue 3 red ; CSS1: 0 buff 1 cyan 2 magenta 3 orange
from font import GLYPHS, CHARS

SPR = {}   # name -> list of rows

def S(name, art):
    rows = [r for r in art.strip('\n').split('\n')]
    rows = [r.strip() for r in rows]
    w = len(rows[0])
    assert all(len(r) == w for r in rows), (name, rows)
    SPR[name] = rows

# ---------------- player: Mason Dixon, armed with a mallet ----------------
S('PR1', """
...yyy..
...yby..
..bbbbyy
...bbb..
..b...b.""")
S('PR2', """
...yyy..
...yby..
..bbbbyy
...bbb..
...b.b..""")
S('PD1', """
..yyyy..
..ybby..
.ybbbby.
..bbbb..
..b..b..""")
S('PD2', """
..yyyy..
..ybby..
.ybbbby.
..bbbb..
...bb...""")
S('PU1', """
..yyyy..
..yyyy..
.ybbbby.
..bbbb..
..b..b..""")
S('PU2', """
..yyyy..
..yyyy..
.ybbbby.
..bbbb..
...bb...""")
S('PDIE1', """
........
.r.yy.r.
..ybby..
rrbbbbrr
.r.rr.r.""")
S('PDIE2', """
........
........
r.y..y.r
.rrbbrr.
rrrrrrrr""")
S('PWIN', """
y.yyy.y.
.yybyy..
..bbbb..
..bbbb..
.b....b.""")

# ---------------- tomatoes ----------------
S('CH1', """
....b...
.rrrbrr.
ryyrryyr
rrrbbrrr
.r....r.""")
S('CH2', """
...b....
.rrbrrr.
ryyrryyr
rrrbbrrr
..r..r..""")
S('RO1', """
...bb...
..rrrr..
.ryrryr.
.rbyybr.
..r..r..""")
S('RO2', """
...bb...
..rrrr..
.ryrryr.
.rbyybr.
.r....r.""")
S('BF1', """
..bbbb..
rrrrrrrr
ryyrryyr
rybybybr
.rr..rr.""")
S('BF2', """
..bbbb..
rrrrrrrr
ryyrryyr
rbybybyr
rr....rr""")
S('UN1', """
...bb...
.yyyyyy.
yybyybyy
yyybbyyy
.y....y.""")
S('UN2', """
...bb...
.yyyyyy.
yybyybyy
yyybbyyy
..y..y..""")
S('GO1', """
...bb...
.yyyyyy.
yyryyryy
yyyrryyy
.y....y.""")
S('GO2', """
y..bb..y
.yyyyyy.
yyryyryy
yyyrryyy
..y..y..""")
S('CAUGHT', """
...b....
.rrbrr..
yrrbrrry
rrrrrrrr
rrryyrrr""")
S('FLAT1', """
........
.rrrrrr.
rbyrrybr
rrrrrrrr
rrrrrrrr""")
S('FLAT2', """
........
........
rrbrrbrr
rrryyrrr
rrrrrrrr""")
S('SCARED1', """
........
..bbbb..
.bybbyb.
.byybyb.
..b..b..""")
S('SCARED2', """
........
.bbbbbb.
.bybbyb.
.bbyybb.
.b....b.""")
S('POP1', """
........
........
...rr...
..rbbr..
.r.rr.r.""")
S('POP2', """
........
..r..r..
.r.rr.r.
...rr...
........""")
S('SHOT', """
........
...rr...
..rrrr..
...rr...
........""")
S('SHOT3', """
...y....
..yrr...
.rrrrr..
..yrr...
...y....""")
S('SEED', """
........
...yy...
..yyyy..
...yy...
........""")
S('BONK', """
y..y..y.
.y.y.y..
..yyy...
.y.y.y..
y..y..y.""")
S('SHIELD', """
..yyyy..
.y....y.
y......y
.y....y.
..yyyy..""")

# ---------------- tiles (opaque, '.' = floor) ----------------
S('T_FLOOR', """
........
........
........
........
........""")
S('T_STAIN', """
.r....r.
...rr...
.rrrrr..
r..rr..r
...r....""")
S('T_TRAP1', """
........
...yy...
...yy...
..bbbb..
........""")
S('T_TRAP2', """
........
.y....y.
.yy..yy.
.bbbbbb.
........""")
S('T_TRAP3', """
y.y..y.y
yyy..yyy
.yy..yy.
bbbbbbbb
.b....b.""")
S('T_GUN', """
...yy...
...rr...
..rrrr..
..ryyr..
..rrrr..""")
S('T_SNEAK', """
........
.bb.....
.bbbbb..
.bbbbbbb
.yyyyyyy""")
S('T_RECORD', """
.bbbbbb.
bbbbbbbb
bbbrrbbb
bbbbbbbb
.bbbbbb.""")
S('T_X2', """
rrrrrrrr
ryrryyrr
rryrrryr
ryrryrrr
rrrryyyr""")
S('T_COLAND', """
..yyyy..
.ybybyb.
yyyyyyyy
.y....y.
........""")
S('T_DISG', """
........
bbb..bbb
bybbbbyb
bbb..bbb
.yyyyyy.""")
S('T_CAN', """
.yyyyyy.
.rrrrrr.
.ryyyyr.
.rrrrrr.
.yyyyyy.""")
S('T_MANHOLE', """
.bbbbbb.
bb.bb.bb
bbbbbbbb
bb.bb.bb
.bbbbbb.""")
# hazards: three looks (grill / steam vent / zapper), each off / warn / on
S('T_GRILL0', """
........
bbbbbbbb
b.b.b.b.
bbbbbbbb
.b....b.""")
S('T_GRILL1', """
..r..r..
bbbbbbbb
brbrbrbr
bbbbbbbb
.b....b.""")
S('T_GRILL2', """
r.yr.ry.
ryrryryr
yryyryyr
bbbbbbbb
.b....b.""")
S('T_VENT0', """
........
.bbbbbb.
.b.b.b..
.bbbbbb.
........""")
S('T_VENT1', """
..y..y..
.bbbbbb.
.byb.by.
.bbbbbb.
........""")
S('T_VENT2', """
.yy.yyy.
yyyyyyyy
yyyyyyyy
.yyyyyy.
..y..y..""")
S('T_ZAP0', """
.b....b.
.b....b.
.b....b.
.b....b.
bbb..bbb""")
S('T_ZAP1', """
.y....y.
.b....b.
.b.y..b.
.b....b.
bbb..bbb""")
S('T_ZAP2', """
.yyyyyy.
.by..yb.
.b.yy.b.
.by..yb.
bbbyybbb""")
# conveyors (2 frames each, generated below)

# ---------------- walls (base fill per world) ----------------
S('W_BRICK', """
yyyyyyyy
yyyryyyy
yyyyyyyy
yyyyyyry
yyyyyyyy""")
S('W_CANS', """
bbbbbbbb
bybbbbyb
bbbbbbbb
bbbbybbb
bbbbbbbb""")
S('W_LAB', """
bbbbbbbb
bbyybbbb
bbbybbbb
bbbyyyyb
bbbbbbbb""")

# ---------------- bosses 16x10 ----------------
S('MAMA1', """
......bbbb......
...rrrrbbrrrr...
..rrrrrrrrrrrr..
.rryyyrrrryyyrr.
.rryybrrrrbyyrr.
rrrrrrrrrrrrrrrr
rrybybybybybyrrr
rrrybybybybyrrrr
.rrrrrrrrrrrrrr.
..rrr......rrr..""")
S('MAMA2', """
.....bbbb.......
...rrrrbbrrrr...
..rrrrrrrrrrrr..
.rryyyrrrryyyrr.
.rrbyyrrrryybrr.
rrrrrrrrrrrrrrrr
rrybbbbbbbbbyrrr
rrrybybybybyrrrr
.rrrrrrrrrrrrrr.
.rrr........rrr.""")
S('BARON1', """
.......yy.......
......bbbb......
....bbbbbbbb....
...rrrrrrrrrr...
..ryyyrrrryyyrr.
..rybyrrrryyyrr.
.rrrrrbbbbrrrrrr
.rrrrybybybrrrrr
..rrrrrrrrrrrr..
..rr..rrrr..rr..""")
S('BARON2', """
.......yy.......
......bbbb......
....bbbbbbbb....
...rrrrrrrrrr...
..ryyyrrrryyyrr.
..ryybrrrryyyrr.
.rrrrrbbbbrrrrrr
.rrrryybyyyrrrrr
..rrrrrrrrrrrr..
...rr.rrrr.rr...""")
# final boss 24x15
S('GREAT1', """
..........bbbb..........
.......bbbbbbbbbb.......
.....rrrrrrbbrrrrrrr....
...rrrrrrrrrrrrrrrrrrr..
..rrrrrrrrrrrrrrrrrrrrr.
.rryyyyyrrrrrrrryyyyyrrr
.rryyyybbrrrrrrbbyyyyrrr
rrryyyybbrrrrrrbbyyyyrrr
rrrryyyyrrrrrrrryyyyrrrr
rrrrrrrrrrrrrrrrrrrrrrrr
rrrybbbbbbbbbbbbbbbbyrrr
rrrrybybybybybybybyrrrrr
.rrrrrrrrrrrrrrrrrrrrrr.
..rrrrrrrrrrrrrrrrrrrr..
....rrrrrrrrrrrrrrrr....""")
S('GREAT2', """
..........bbbb..........
.......bbbbbbbbbb.......
.....rrrrrrbbrrrrrrr....
...rrrrrrrrrrrrrrrrrrr..
..rrrrrrrrrrrrrrrrrrrrr.
.rryyyyyrrrrrrrryyyyyrrr
.rryyyyyyrrrrrryyyyyyrrr
rrrybbyyyrrrrrryyybbyrrr
rrrrbbyyrrrrrrrryybbrrrr
rrrrrrrrrrrrrrrrrrrrrrrr
rrrrybybybybybybybybrrrr
rrrybbbbbbbbbbbbbbbbbrrr
.rrrybybybybybybybybrrr.
..rrrrrrrrrrrrrrrrrrrr..
....rrrrrrrrrrrrrrrr....""")
S('GREATS', """
....bbbb........
..rrrbbrrrr.....
.rrrrrrrrrrr....
.ryyyrrryyyr....
.ryybrrrbyyr....
.rrrrrrrrrrr....
.rrybbbbbyrr....
..rrrrrrrrr.....
...rrrrrrr......
................""")
S('CARROT', """
.b.b.b..
..bbb...
.rrrrr..
.ryrry..
..rrr...""")

def mirror(rows):
    return [r[::-1] for r in rows]

SPR['PL1'] = mirror(SPR['PR1'])
SPR['PL2'] = mirror(SPR['PR2'])

# conveyors: arrows over belt, frames 0/1 shifted
def conveyor(d, f):
    base = [list('bbbbbbbb'), list('........'), list('........'), list('........'), list('bbbbbbbb')]
    if d in 'LR':
        for k in range(2):
            c = (k * 4 + f * 2) % 8
            # chevron > or <
            pts = [(1, c), (2, (c + 1) % 8), (3, c)] if d == 'R' else [(1, (c + 1) % 8), (2, c), (3, (c + 1) % 8)]
            for (r, cc) in pts: base[r][cc] = 'y'
    else:
        base = [list('b......b') for _ in range(5)]
        r0 = (f + (0 if d == 'D' else 0)) % 2
        rows = [0, 2, 4] if f == 0 else [1, 3]
        for r in rows:
            if d == 'U':
                base[r][3] = 'y'; base[r][4] = 'y'
            else:
                base[r][3] = 'y'; base[r][4] = 'y'
        if d == 'U':
            for r in rows:
                if r + 1 < 5: base[r + 1][2] = 'y'; base[r + 1][5] = 'y'
        else:
            for r in rows:
                if r - 1 >= 0: base[r - 1][2] = 'y'; base[r - 1][5] = 'y'
    return [''.join(x) for x in base]

for d in 'UDLR':
    for f in range(2):
        SPR['T_CONV%s%d' % (d, f)] = conveyor(d, f)

# letter tiles S A U C E: red block, yellow letter
def letter_tile(ch):
    rows = dict(GLYPHS)[ch]
    out = []
    for r in rows:
        out.append('rr' + ''.join('y' if p == '#' else 'r' for p in r) + 'rrr')
    return out
for ch in 'SAUCE':
    SPR['T_L' + ch] = letter_tile(ch)

CV = {'.': 0, 'y': 1, 'b': 2, 'r': 3}

def encode(rows):
    out = []
    for r in rows:
        assert len(r) % 4 == 0
        for i in range(0, len(r), 4):
            v = 0
            for p in r[i:i + 4]:
                v = (v << 2) | CV[p]
            out.append(v)
    return out

# ---- extra enemies & frames ----
S('HOP1', """
...b....
.rrbrr..
ryrrryrr
rrbbbrrr
.y....y.""")
S('HOP2', """
...b....
.rrbrr..
ryrrryrr
rrbbbrrr
y......y""")
S('ROT1', """
...b....
.rbrrbr.
rybrryrb
rrbbbrrr
.rb..br.""")
S('ROT2', """
....b...
.rbrrbr.
brryrbyr
rrbbbrrr
.br..rb.""")
S('BALL1', """
..rrrr..
.ryrryr.
rrrrrrrr
.rbbbbr.
..rrrr..""")
S('BALL2', """
..rrrr..
.rrbrrr.
rrrrbrrr
.ryrrbr.
..rrrr..""")
S('DIZZY1', """
y.....y.
.rrrrrr.
rbrrrrbr
rrryyrrr
.rrrrrr.""")
S('DIZZY2', """
.y...y..
.rrrrrr.
rrbrrbrr
rrryyrrr
.rrrrrr.""")
S('DISGUISE', """
...bb...
.rrrrrr.
rbbbbbbr
ryyyyyyr
.yy..yy.""")
S('GREATD', """
..........bbbb..........
.......bbbbbbbbbb.......
.....rrrrrrbbrrrrrrr....
...rrrrrrrrrrrrrrrrrrr..
..rrrrrrrrrrrrrrrrrrrrr.
.rryyyyyrrrrrrrryyyyyrrr
.rryybyyrrrrrrrryybyyrrr
rrryyyyyrrrrrrrryyyyyrrr
rrrrrrrrrrrrrrrrrrrrrrrr
rrrrrrrrbbbbbbbbrrrrrrrr
rrrrrrrbyyyyyyyybrrrrrrr
rrrrrrrbbbbbbbbbbrrrrrrr
.rrrrrrrrrrrrrrrrrrrrrr.
..rrrrrrrrrrrrrrrrrrrr..
....rrrrrrrrrrrrrrrr....""")
S('T_STINK', """
.y..b.y.
b.yy..b.
.yyyyy..
y.yyy.yb
.b..y...""")
S('T_GRASS', """
........
...y....
........
......b.
.b......""")
S('T_GRASSSH', """
bbbbbbbb
.b.b.b.b
........
......b.
.b......""")
S('T_CHECK', """
y.......
........
........
....y...
........""")
S('T_CHECKSH', """
bbbbbbbb
b.b.b.b.
........
....y...
........""")
S('T_GRID', """
b.......
........
........
........
........""")
S('T_GRIDSH', """
bbbbbbbb
.b.b.b.b
........
........
........""")
S('T_PARTY', """
........
..y.....
........
.....r..
........""")
SPR['CAUGHTM'] = mirror(SPR['CAUGHT'])
