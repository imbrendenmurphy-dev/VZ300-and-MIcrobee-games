"""BILBIES! artwork: all drawn for the VZ300 mode(1) colour set 0.
Pixels: '.' blue (clear in sprites), 'Y' yellow, 'R' red, 'G' green.
Sprites are 8 pixels x 7 rows; the bilby's feet are on row 6, centred on column 3.
"""
COL = {'G': 0, 'Y': 1, '.': 2, 'B': 2, 'R': 3}

def pack(rows):
    """rows of 4*k chars -> bytes (4 pixels a byte, leftmost in bits 7-6)"""
    out = []
    for r in rows:
        for i in range(0, len(r), 4):
            b = 0
            for c in r[i:i + 4]:
                b = (b << 2) | COL[c]
            out.append(b)
    return out

def grid(w=8, h=7):
    return [['.'] * w for _ in range(h)]

def put(g, x, y, c):
    if 0 <= y < len(g) and 0 <= x < len(g[0]) and c != ' ':
        g[y][x] = c

def stamp(g, x, y, art):
    for j, row in enumerate(art):
        for i, c in enumerate(row):
            if c not in ' ':
                put(g, x + i, y + j, c)

def rows(g):
    return [''.join(r) for r in g]

def mirror(g):
    """mirror about column 3 (column c -> 6 - c)"""
    h = len(g)
    m = grid(8, h)
    for y in range(h):
        for x in range(7):
            m[y][6 - x] = g[y][x]
    return m

# ---------------------------------------------------------------------------
# the bilby (facing right): a little four-legged burrower - long upright ears,
# a pointed red-tipped snout, sandy body, a tail, the eye a dark gap
#   col: 0 tail  1-4 body  3-5 head  6 nose ; row 6 = feet
# ---------------------------------------------------------------------------
def quad(g, legs=0, ears=0, tail=0, dy=0, head=0, eye=True):
    """legs: 0 (1,3) 1 (2,4) 2 (1,4) 3 (2,3); ears: 0 up 1 back 2 flat 3 alert;
    tail: 0 low 1 up; head: 0 level, 1 down (nose to the ground)"""
    y = 6 + dy
    # ears
    if ears == 0:
        stamp(g, 3, y - 4, ['YR', 'YR'])
    elif ears == 1:
        stamp(g, 2, y - 4, ['YR ', ' YR'])
    elif ears == 2:
        stamp(g, 1, y - 3, ['YYR'])
    elif ears == 3:
        stamp(g, 3, y - 4, ['Y.R', 'YYR'])
    # head + body
    if head == 0:
        stamp(g, 1, y - 2, ['YYY' + ('.' if eye else 'Y') + 'YR'])
        stamp(g, 1, y - 1, ['YYYY'])
    else:
        stamp(g, 1, y - 2, ['YYY' + ('.' if eye else 'Y')])
        stamp(g, 1, y - 1, ['YYYYYR'])
    # tail
    if tail == 0:
        put(g, 0, y - 1, 'R')
    else:
        put(g, 0, y - 2, 'R')
    # legs
    lx = [(1, 3), (2, 4), (1, 4), (2, 3)][legs]
    for x in lx:
        put(g, x, y, 'R')

def body(g, dy=0, ears=0, tail=0, eye=True):
    quad(g, legs=0, ears=ears, tail=tail, dy=dy, eye=eye)

FEET = [(1, 3), (2, 4), (1, 4), (2, 3), (1, 3), (2, 4), (1, 4), (2, 3)]
WALKLEGS = [0, 2, 1, 3, 0, 2, 1, 3]

def walk(i):
    g = grid()
    quad(g, legs=WALKLEGS[i], ears=1 if i in (2, 3, 6, 7) else 0, tail=1 if i % 4 < 2 else 0)
    return g

def fall(i):
    g = grid()
    # ears streaming up, legs spread, tail up
    stamp(g, 3, 1 + (i & 1), ['YR', 'YR'])
    stamp(g, 1, 3, ['YYY.YR'])
    stamp(g, 1, 4, ['YYYY'])
    put(g, 0, 3 if i & 2 else 4, 'R')
    put(g, 1 - (i & 1), 5, 'R')
    put(g, 4 + (i & 1), 5, 'R')
    return g

LEAF = [['  G  '], [' GGG '], ['GGGGG', '  Y  '], ['GGGGG', 'G Y G']]
def float_(i):
    g = grid()
    if i < 4:
        sz, sway = i, 0
    else:
        sz, sway = 3, [0, 1, 0, -1][i - 4]
    # hanging from the leaf by the front paws
    stamp(g, 3, 3, ['YR'])
    stamp(g, 1, 4, ['YYY.YR'])
    stamp(g, 1, 5, ['YYYY'])
    put(g, 0, 5, 'R')
    put(g, 1, 6, 'R')
    put(g, 3, 6, 'R')
    stamp(g, 1 + sway, 0, LEAF[sz])
    if sz >= 2:
        put(g, 4, 2, 'Y')
    return g

def climb(i):
    g = grid()
    up = i % 4 < 2
    # body upright against the wall on the right, nose up, ears back
    stamp(g, 3, 0, ['R'])
    stamp(g, 2, 1, ['YR'])
    stamp(g, 3, 2, ['Y.'])
    put(g, 4, 1, 'R' if up else 'Y')
    stamp(g, 3, 3, ['YY'])
    stamp(g, 3, 4, ['YY'])
    stamp(g, 3, 5, ['YY'])
    put(g, 2, 6, 'R')
    put(g, 5, 2 if up else 3, 'R')        # front paws on the wall
    put(g, 5, 5 if up else 4, 'R')        # back paws
    put(g, 4, 6, 'R' if not up else '.')
    return g

def hoist(i):
    g = grid()
    # from upright against the wall to crouched on the top
    if i < 3:
        stamp(g, 3, 1, ['YR'])
        stamp(g, 3, 2, ['Y.R'])
        stamp(g, 3, 3, ['YYY'])
        stamp(g, 3, 4, ['YY'])
        put(g, 3, 5 - (i == 2), 'R')
        put(g, 5, 4 - i, 'R')
    elif i < 6:
        stamp(g, 4, 0 + (i - 3) // 2, ['YR'])
        stamp(g, 3, 2, ['YY.YR'])
        stamp(g, 2, 3, ['YYYY'])
        put(g, 2, 4, 'R')
        put(g, 4, 4, 'R' if i == 5 else '.')
    else:
        quad(g, legs=0 if i == 6 else 2, ears=1, dy=-1)
        for x in range(8):
            if g[6][x] == '.': pass
    return g

def block(i):
    g = grid()
    # up on the hind legs, front paws held wide, ears up and twitching
    tw = i % 4 >= 2
    stamp(g, 2, 0, ['YR' if not tw else 'Y.R'])
    stamp(g, 2, 1, ['YR' if not tw else 'YYR'])
    stamp(g, 2, 2, ['Y.YR'])
    stamp(g, 0, 3, ['RYYYYR'])
    stamp(g, 2, 4, ['YYY'])
    stamp(g, 2, 5, ['YYY'])
    put(g, 1, 5, 'R' if i < 4 else '.')     # tail
    put(g, 2, 6, 'R')
    put(g, 4, 6, 'R')
    put(g, 3, 6, 'R' if i % 2 else '.')
    return g

def build(i):
    g = grid()
    # 16 frames: fetch a stick (0-5), carry it forward (6-8), lay it (9-11), step up (12-15)
    lay = 9 <= i <= 11
    quad(g, legs=WALKLEGS[i % 8], ears=1 if lay else 0, head=1 if lay else 0)
    if i < 9:
        lift = 1 if 2 <= i <= 8 else 0
        stamp(g, 5, 4 - lift, ['YR'])      # the stick in the mouth
    elif lay:
        stamp(g, 5, 6, ['YY'])
    return g

def shrug(i):
    g = grid()
    # sits up on the haunches, paws up, ears flop
    up = [0, 1, 2, 2, 2, 2, 1, 0][i]
    if up == 0:
        quad(g)
        return g
    stamp(g, 3, 1, ['YR'] if up == 1 else ['R.R'])
    stamp(g, 3, 2, ['YR'] if up == 1 else ['YYR'])
    stamp(g, 2, 3, ['YY.YR'])
    stamp(g, 1, 4, ['YYYY'])
    stamp(g, 1, 5, ['YYY'])
    put(g, 0, 5, 'R')
    put(g, 1, 6, 'R'); put(g, 3, 6, 'R')
    put(g, 5, 3 - (up - 1), 'Y')
    put(g, 1, 3 - (up - 1), 'Y')
    return g

def bash(i):
    g = grid()
    # 32 frames: front paws punching into the wall, dirt flying back
    ph = i % 16
    reach = [0, 1, 2, 2, 1, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0, 0][ph]
    quad(g, legs=0 if ph < 8 else 2, ears=1, tail=1 if i & 4 else 0)
    py = 4 if i < 16 else 5
    for k in range(1, reach + 1):
        put(g, 4 + k, py, 'R' if k == reach else 'Y')
    if reach == 2:
        put(g, 0, 2 + (ph & 1), 'R')
        put(g, 1, 1, 'G')
    return g

def mine(i):
    g = grid()
    # 24 frames: scraping down and forward, nose down
    ph = i % 12
    quad(g, legs=1 if ph < 6 else 3, ears=1, head=1)
    swing = [0, 1, 2, 3, 3, 2, 1, 0, 0, 0, 0, 0][ph]
    pts = [(5, 5), (6, 5), (6, 6), (5, 6)]
    for k in range(swing):
        put(g, pts[k][0], pts[k][1], 'Y')
    if ph in (3, 4):
        put(g, 0, 3, 'R')
        put(g, 1, 2, 'G')
    return g

def dig(i):
    g = grid()
    # 16 frames: nose down, paws scrabbling, dirt kicked up behind
    ph = i % 8
    stamp(g, 3, 2 + (ph & 1), ['YR'])
    stamp(g, 1, 3, ['YYYY'])
    stamp(g, 2, 4, ['YYY.'])
    stamp(g, 3, 5, ['YYR'])
    put(g, 0, 3, 'R')
    put(g, 2 + (ph & 1), 6, 'Y')
    put(g, 4 - (ph & 1), 6, 'R')
    if ph in (2, 3, 6, 7):
        put(g, 0, 1 + (ph & 1), 'R')
        put(g, 1, 0 + (ph & 1), 'G')
    return g

def splat(i):
    g = grid()
    w = min(i // 2 + 3, 7)
    left = 3 - w // 2
    for x in range(left, left + w):
        put(g, x, 6, 'R' if (x + i) % 3 else 'Y')
    if i < 6:
        stamp(g, 1, 5, ['YYYY'])
    if i < 3:
        stamp(g, 3, 4, ['YR'])
    if i >= 12 and i % 2:
        for x in range(7):
            if g[6][x] != '.' and (x + i) % 2:
                g[6][x] = '.'
    return g

def drown(i):
    g = grid()
    sink = i // 3
    sub = grid()
    quad(sub, ears=3 if i < 6 else 0)
    for y in range(7):
        for x in range(8):
            if sub[y][x] != '.' and y + sink <= 6:
                put(g, x, y + sink, sub[y][x])
    if i >= 3:
        put(g, 3 + (i % 2), 6 - (i - 3) % 7, 'Y' if i % 3 else 'G')
    return g

def exit_(i):
    g = grid()
    # a happy hop, then down the burrow nose first
    hop = [0, 1, 1, 0, 0, 1, 2, 3][i]
    sub = grid()
    if i < 5:
        quad(sub, legs=2 if hop else 0, ears=3 if hop else 0, tail=1)
        shift = -hop
    else:
        quad(sub, ears=2, head=1)
        shift = hop
    for y in range(7):
        for x in range(8):
            if sub[y][x] != '.':
                yy = y + shift
                if 0 <= yy <= 6 and not (i >= 5 and yy >= 7 - hop):
                    put(g, x, yy, sub[y][x])
    return g

def ohno(i):
    g = grid()
    # sits up, paws over the ears, trembling; flashes red near the end
    shake = (i % 2) if i < 12 else 0
    stamp(g, 2 + shake, 0, ['Y.R'])
    stamp(g, 2 + shake, 1, ['YYR'])
    stamp(g, 2, 2, ['YY.YR'])
    stamp(g, 1, 3, ['YYYY'])
    stamp(g, 1, 4, ['YYY'])
    put(g, 0, 4, 'R')
    put(g, 1 + shake, 1, 'Y')
    put(g, 5 - shake, 1, 'Y')
    put(g, 1, 5, 'R'); put(g, 3, 5, 'R')
    if i >= 12 and i % 2:
        for y in range(7):
            for x in range(8):
                if g[y][x] == 'Y':
                    g[y][x] = 'R'
    # sit on row 6
    g = [['.'] * 8] + g[:-1]
    return g

# state order (game.asm): 1 walk 2 fall 3 float 4 climb 5 hoist 6 block 7 build
# 8 shrug 9 bash 10 mine 11 dig 12 splat 13 drown 14 exit 15 ohno
ANIMS = [('walk', walk, 8), ('fall', fall, 4), ('float', float_, 8), ('climb', climb, 8),
         ('hoist', hoist, 8), ('block', block, 8), ('build', build, 16), ('shrug', shrug, 8),
         ('bash', bash, 32), ('mine', mine, 24), ('dig', dig, 16), ('splat', splat, 16),
         ('drown', drown, 16), ('exit', exit_, 8), ('ohno', ohno, 16)]

def anim_frames():
    """-> list of (name, count, right frames, left frames) as row strings"""
    out = []
    for name, f, n in ANIMS:
        r = [f(i) for i in range(n)]
        l = [mirror(g) for g in r]
        out.append((name, n, [rows(g) for g in r], [rows(g) for g in l]))
    return out

# ---------------------------------------------------------------------------
# digits over a bomber's head (5..1), cursor
# ---------------------------------------------------------------------------
DIG3 = {
    '0': ['YYY', 'Y.Y', 'Y.Y', 'Y.Y', 'YYY'], '1': ['.Y.', 'YY.', '.Y.', '.Y.', 'YYY'],
    '2': ['YYY', '..Y', 'YYY', 'Y..', 'YYY'], '3': ['YYY', '..Y', '.YY', '..Y', 'YYY'],
    '4': ['Y.Y', 'Y.Y', 'YYY', '..Y', '..Y'], '5': ['YYY', 'Y..', 'YYY', '..Y', 'YYY'],
}
def digit_sprite(d):
    g = grid()
    for j, r in enumerate(DIG3[d]):
        for i, c in enumerate(r):
            if c == 'Y':
                put(g, 2 + i, 1 + j, 'R' if j in (0, 4) and False else 'Y')
    return rows(g)

CURS0 = ['...Y....', '........', '.Y.R.Y..', '........', '...Y....', '........', '........']
CURS1 = ['YY...YY.', 'Y.....Y.', '........', '........', '........', 'Y.....Y.', 'YY...YY.']

# ---------------------------------------------------------------------------
# objects: the hatch (12 x 6, 8 frames opening) and the burrow (12 x 8, 4 frames)
# ---------------------------------------------------------------------------
def hatch(i):
    """a hollow-log trapdoor: bark frame, two doors that swing down"""
    g = grid(12, 6)
    stamp(g, 0, 0, ['RRYRRRRRYRRR', 'RYYYYYYYYYYR', 'R..........R'])
    o = min(i, 5)                    # 0 shut .. 5 hanging open
    for side in (0, 1):
        for k in range(5):
            if o == 0:
                x, y = 1 + k, 2
            elif o < 3:
                x, y = 1 + k, 2 + (k * o) // 4
            elif o < 5:
                x, y = 1 + (k * (5 - o)) // 3, 2 + k * (o - 2) // 3 + (1 if k else 0)
            else:
                x, y = 1, 2 + min(k, 3)
            if side: x = 11 - x
            put(g, x, min(y, 5), 'G' if k % 2 == 0 else 'Y')
    return rows(g)

def burrow(i):
    g = grid(12, 8)
    flag = [['YY', 'Y '], ['YG', 'Y '], ['GY', 'Y '], ['YY', 'Y ']][i]
    stamp(g, 6, 0, ['Y' + flag[0][0] + flag[0][1]])
    stamp(g, 6, 1, ['Y' + flag[1]])
    put(g, 6, 2, 'Y')
    stamp(g, 0, 3, ['...RRRRRR...', '..RRYRRYRR..', '.RRR....RRR.', 'RRR......RRR', 'RRR..GG..RRR'])
    # the dark hole sparkles a little
    put(g, 4 + i, 6, 'G' if i % 2 else '.')
    return rows(g)

# ---------------------------------------------------------------------------
# textures: 8 x 8, two bytes a row
# ---------------------------------------------------------------------------
TEX = {
 'none':    ['........'] * 8,
 'earth':   ['RRRRRRRR', 'RRYRRRRR', 'RRRRRRGR', 'RRRRRRRR', 'RRRRYRRR', 'RGRRRRRR', 'RRRRRRRR', 'RRRRRRYR'],
 'rock':    ['RYRRRYRR', 'YRRYRRRY', 'RRYRRYRR', 'RYRRRRYR', 'RRRYRYRR', 'YRRRYRRR', 'RRYRRRRY', 'RYRYRRYR'],
 'brick':   ['YYYYYYYY', 'RRRYRRRR', 'RRRYRRRR', 'RRRYRRRR', 'YYYYYYYY', 'RRRRRRRY', 'RRRRRRRY', 'RRRRRRRY'],
 'moss':    ['GGGGGGGG', 'GYGGGGYG', 'GGGGGGGG', 'GGGYGGGG', 'GGGGGGGG', 'YGGGGGGY', 'GGGGGGGG', 'GGGGYGGG'],
 'stone':   ['RRRRRRRR', 'RYYYRYYY', 'RYYYRYYY', 'RYYYRYYY', 'RRRRRRRR', 'YYRYYYRY', 'YYRYYYRY', 'YYRYYYRY'],
 'steel':   ['GGGGGGGG', 'GYGGGGYG', 'GGGGGGGG', 'GGGGGGGG', 'GGGGGGGG', 'GGGGGGGG', 'GYGGGGYG', 'GGGGGGGG'],
 'wood':    ['YYYYYYYY', 'YYRYYYYY', 'YYYYYYYR', 'RRRRRRRR', 'YYYYYYYY', 'YYYYRYYY', 'RYYYYYYY', 'RRRRRRRR'],
 'crystal': ['GYGYGYGY', 'YGYGYGYG', 'GYGYGYGY', 'YGYGYGYG', 'GYGYGYGY', 'YGYGYGYG', 'GYGYGYGY', 'YGYGYGYG'],
 'red':     ['RRRRRRRR'] * 8,
 'yellow':  ['YYYYYYYY'] * 8,
 'green':   ['GGGGGGGG'] * 8,
 'dirt':    ['RRRRRRRR', 'RRRGRRRR', 'RRRRRRRR', 'GRRRRRRG', 'RRRRRRRR', 'RRRRGRRR', 'RRRRRRRR', 'RGRRRRRR'],
 'sand':    ['YYYYYYYY', 'YYYRYYYY', 'YYYYYYYY', 'YYYYYYRY', 'YYYYYYYY', 'YRYYYYYY', 'YYYYYYYY', 'YYYYRYYY'],
 'leaves':  ['GGYGGGGY', 'GYGGYGGG', 'YGGGGGYG', 'GGGYGGGG', 'GYGGGYGG', 'GGGGYGGY', 'YGGYGGGG', 'GGGGGYGG'],
 'checker': ['RYRYRYRY', 'YRYRYRYR', 'RYRYRYRY', 'YRYRYRYR', 'RYRYRYRY', 'YRYRYRYR', 'RYRYRYRY', 'YRYRYRYR'],
 # faint backgrounds and picture-only scenery (blue-led so the bilbies stand out)
 'sky':     ['........', '........', '.....G..', '........', '........', '........', '........', '........'],
 'night':   ['........', '..Y.....', '........', '........', '......G.', '........', '........', '........'],
 'cave':    ['........', '...R....', '........', '.......R', '........', '.R......', '........', '....R...'],
 'dusk':    ['....R...', '........', 'R.......', '........', '.....R..', '........', '..R.....', '........'],
 'mist':    ['..G.....', '........', '......G.', '........', 'G.......', '........', '....G...', '........'],
 'farhill': ['G.......', '....G...', '........', '..G...G.', '........', 'G...G...', '........', '..G.....'],
 'hill':    ['G...G...', '..G...G.', 'G...G...', '..G...G.', 'G...G...', '..G...G.', 'G...G...', '..G...G.'],
 'redhill': ['R...R...', '........', '..R...R.', '........', 'R...R...', '........', '..R...R.', '........'],
 'trunk':   ['.R...R..', '.R......', '.R...R..', '.....R..', '.R...R..', '.R......', '.R...R..', '.....R..'],
 'canopy':  ['G...G.G.', '.G.G....', 'G.....G.', '...G.G..', '.G......', 'G..G..G.', '.....G..', '.G.G...G'],
 'ruin':    ['R.R.R.R.', '...R....', '...R....', 'R.R.R.R.', '.......R', '.......R', 'R.R.R.R.', '...R....'],
 'cryst':   ['...G....', '..G.G...', '...G....', '........', '......G.', '.....G.G', '......G.', '........'],
 'cloud':   ['Y.......', '...Y...Y', '........', '.Y...Y..', '........', 'Y...Y...', '........', '..Y....Y'],
 'reed':    ['..G.....', '..G...G.', '..G...G.', '.GG...G.', '..G..GG.', '..G...G.', '..G...G.', '..G...G.'],
 'gstone':  ['GGGGGGGG', 'GYYYGYYY', 'GYYYGYYY', 'GYYYGYYY', 'GGGGGGGG', 'YYGYYYGY', 'YYGYYYGY', 'YYGYYYGY'],
}
TEXNAMES = list(TEX)

def tex_bytes(name):
    return pack(TEX[name])

# water: per depth row (surface, 2nd, 3rd, deep) x 4 phases (one byte, rotated as it goes)
WATER = [['YGGG', 'GYGG', 'GGYG', 'GGGY'],
         ['GBGB', 'BGBG', 'GBGB', 'BGBG'],
         ['BGBB', 'BBGB', 'BBBG', 'GBBB'],
         ['BBBB', 'BGBB', 'BBBB', 'BBGB']]

# ---------------------------------------------------------------------------
# font: 3 x 5, ASCII 32..95 (+ '^' drawn as a clock)
# ---------------------------------------------------------------------------
F = {}
def fdef(ch, *r): F[ch] = r
fdef(' ', '...', '...', '...', '...', '...')
fdef('!', '.Y.', '.Y.', '.Y.', '...', '.Y.')
fdef('"', 'Y.Y', 'Y.Y', '...', '...', '...')
fdef('#', 'Y.Y', 'YYY', 'Y.Y', 'YYY', 'Y.Y')
fdef('%', 'Y.Y', '..Y', '.Y.', 'Y..', 'Y.Y')
fdef("'", '.Y.', '.Y.', '...', '...', '...')
fdef('(', '..Y', '.Y.', '.Y.', '.Y.', '..Y')
fdef(')', 'Y..', '.Y.', '.Y.', '.Y.', 'Y..')
fdef('*', '...', 'Y.Y', '.Y.', 'Y.Y', '...')
fdef('+', '...', '.Y.', 'YYY', '.Y.', '...')
fdef(',', '...', '...', '...', '.Y.', 'Y..')
fdef('-', '...', '...', 'YYY', '...', '...')
fdef('.', '...', '...', '...', '...', '.Y.')
fdef('/', '..Y', '..Y', '.Y.', 'Y..', 'Y..')
fdef('0', 'YYY', 'Y.Y', 'Y.Y', 'Y.Y', 'YYY')
fdef('1', '.Y.', 'YY.', '.Y.', '.Y.', 'YYY')
fdef('2', 'YYY', '..Y', 'YYY', 'Y..', 'YYY')
fdef('3', 'YYY', '..Y', '.YY', '..Y', 'YYY')
fdef('4', 'Y.Y', 'Y.Y', 'YYY', '..Y', '..Y')
fdef('5', 'YYY', 'Y..', 'YYY', '..Y', 'YYY')
fdef('6', 'YYY', 'Y..', 'YYY', 'Y.Y', 'YYY')
fdef('7', 'YYY', '..Y', '.Y.', '.Y.', '.Y.')
fdef('8', 'YYY', 'Y.Y', 'YYY', 'Y.Y', 'YYY')
fdef('9', 'YYY', 'Y.Y', 'YYY', '..Y', 'YYY')
fdef(':', '...', '.Y.', '...', '.Y.', '...')
fdef(';', '...', '.Y.', '...', '.Y.', 'Y..')
fdef('<', '..Y', '.Y.', 'Y..', '.Y.', '..Y')
fdef('=', '...', 'YYY', '...', 'YYY', '...')
fdef('>', 'Y..', '.Y.', '..Y', '.Y.', 'Y..')
fdef('?', 'YYY', '..Y', '.YY', '...', '.Y.')
fdef('@', 'YYY', 'Y.Y', 'Y.Y', 'Y..', 'YYY')
fdef('A', '.Y.', 'Y.Y', 'YYY', 'Y.Y', 'Y.Y')
fdef('B', 'YY.', 'Y.Y', 'YY.', 'Y.Y', 'YY.')
fdef('C', '.YY', 'Y..', 'Y..', 'Y..', '.YY')
fdef('D', 'YY.', 'Y.Y', 'Y.Y', 'Y.Y', 'YY.')
fdef('E', 'YYY', 'Y..', 'YY.', 'Y..', 'YYY')
fdef('F', 'YYY', 'Y..', 'YY.', 'Y..', 'Y..')
fdef('G', '.YY', 'Y..', 'Y.Y', 'Y.Y', '.YY')
fdef('H', 'Y.Y', 'Y.Y', 'YYY', 'Y.Y', 'Y.Y')
fdef('I', 'YYY', '.Y.', '.Y.', '.Y.', 'YYY')
fdef('J', '..Y', '..Y', '..Y', 'Y.Y', '.Y.')
fdef('K', 'Y.Y', 'Y.Y', 'YY.', 'Y.Y', 'Y.Y')
fdef('L', 'Y..', 'Y..', 'Y..', 'Y..', 'YYY')
fdef('M', 'Y.Y', 'YYY', 'YYY', 'Y.Y', 'Y.Y')
fdef('N', 'YY.', 'Y.Y', 'Y.Y', 'Y.Y', 'Y.Y')
fdef('O', '.Y.', 'Y.Y', 'Y.Y', 'Y.Y', '.Y.')
fdef('P', 'YY.', 'Y.Y', 'YY.', 'Y..', 'Y..')
fdef('Q', '.Y.', 'Y.Y', 'Y.Y', 'YY.', '.YY')
fdef('R', 'YY.', 'Y.Y', 'YY.', 'Y.Y', 'Y.Y')
fdef('S', '.YY', 'Y..', '.Y.', '..Y', 'YY.')
fdef('T', 'YYY', '.Y.', '.Y.', '.Y.', '.Y.')
fdef('U', 'Y.Y', 'Y.Y', 'Y.Y', 'Y.Y', 'YYY')
fdef('V', 'Y.Y', 'Y.Y', 'Y.Y', 'Y.Y', '.Y.')
fdef('W', 'Y.Y', 'Y.Y', 'YYY', 'YYY', 'Y.Y')
fdef('X', 'Y.Y', 'Y.Y', '.Y.', 'Y.Y', 'Y.Y')
fdef('Y', 'Y.Y', 'Y.Y', '.Y.', '.Y.', '.Y.')
fdef('Z', 'YYY', '..Y', '.Y.', 'Y..', 'YYY')
fdef('[', 'YY.', 'Y..', 'Y..', 'Y..', 'YY.')
fdef(']', '.YY', '..Y', '..Y', '..Y', '.YY')
fdef('^', 'YYY', 'Y.Y', '.Y.', 'Y.Y', 'YYY')   # (shown for '~': an hourglass)
fdef('_', '...', '...', '...', '...', 'YYY')

def font_bytes():
    out = []
    for code in range(32, 96):
        ch = chr(code)
        r = F.get(ch, F[' '])
        for row in r:
            n = 0
            for c in row:
                n = (n << 1) | (c == 'Y')
            out.append(n << 1)      # bits 3..1 = pixels, bit 0 = the gap
    return out

# ---------------------------------------------------------------------------
# the panel (rows 44-63, 32 bytes a row)
# ---------------------------------------------------------------------------
ICONS = {   # 7 x 5 (pause / nuke are drawn 7 x 11)
 'rm':  ['.......', '.......', '.YYYYY.', '.......', '.......'],
 'rp':  ['...Y...', '...Y...', '.YYYYY.', '...Y...', '...Y...'],
 'climb': ['.....RR', '.YR..R.', '.YG.YR.', '..YY.R.', '..R..RR'],
 'float': ['.GGGGG.', 'G..Y..G', '...Y...', '..YGY..', '..R.R..'],
 'bomb':  ['....Y.R', '...R.Y.', '..RRR..', '.RRRRR.', '..RRR..'],
 'block': ['...Y...', 'Y.YGY.Y', '.YYYYY.', '..YYY..', '..R.R..'],
 'build': ['.....YY', '....YYR', '...YYR.', '..YYR..', '.YYR...'],
 'bash':  ['...RR..', '.Y.RR..', 'YYYYYYR', '.Y.RR..', '...RR..'],
 'mine':  ['Y......', '.YY....', '..YYRR.', '...YRRR', '....RRR'],
 'dig':   ['..YYY..', '..YYY..', 'YYYYYYY', '.YYYYY.', 'RRRYRRR'],
}
BIG = {
 'pause': ['.......', '.......', '.YY.YY.', '.YY.YY.', '.YY.YY.', '.YY.YY.', '.YY.YY.', '.YY.YY.', '.YY.YY.', '.......', '.......'],
 'nuke':  ['..YYY..', '.YYRYY.', 'YRRRRRY', '.YYRYY.', '...R...', '...R...', '..RRR..', '.RYRYR.', 'RRRRRRR', '.......', '.......'],
}

def panel_image():
    img = [['.'] * 128 for _ in range(20)]     # rows 44..63
    def p(x, y, c):
        if 0 <= x < 128 and 0 <= y < 20:
            img[y][x] = c
    for x in range(128):
        p(x, 0, 'R')                            # row 44
    # buttons rows 51..63 = 7..19
    for b in range(12):
        x0 = b * 8
        for y in range(7, 20):
            p(x0, y, 'R')
        for x in range(x0, x0 + 8):
            p(x, 7, 'R')
            p(x, 19, 'R')
    for y in range(7, 20):
        p(96, y, 'R')
    for x in range(96, 128):
        p(x, 7, 'R'); p(x, 19, 'R')
    names = ['rm', 'rp', 'climb', 'float', 'bomb', 'block', 'build', 'bash', 'mine', 'dig']
    for b, n in enumerate(names):
        for j, r in enumerate(ICONS[n]):
            for i, c in enumerate(r):
                if c != '.':
                    p(b * 8 + 1 + i, 14 + j, c)
    for b, n in ((10, 'pause'), (11, 'nuke')):
        for j, r in enumerate(BIG[n]):
            for i, c in enumerate(r):
                if c != '.':
                    p(b * 8 + 1 + i, 8 + j, c)
    return [''.join(r) for r in img]

STNAMES = ['', 'WALKER', 'FALLER', 'FLOATER', 'CLIMBER', 'CLIMBER', 'BLOCKER', 'BUILDER',
           'SHRUGGER', 'BASHER', 'MINER', 'DIGGER', '', '', '', 'BOMBER', '', '']
