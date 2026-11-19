"""GALAHXY sprite art (all original). Mode 1, CSS0: g=green(0) y=yellow(1) b=blue(2) r=red(3)
'.' = transparent. Pixels are about 1.5x taller than wide on a 4:3 screen.
Each sprite: name -> (list of frames, nph) ; nph 4 = pre-shifted (any x), 1 = byte-aligned x."""

C = {'g': 0, 'y': 1, 'b': 2, 'r': 3}

def G(s):
    rows = [r for r in s.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    return [[(C[ch] if ch in C else -1) for ch in r.ljust(w, '.')] for r in rows]

S = {}
# ---------------------------------------------------------------- the cast
# GAZZA the rosy galah: pink-red body, yellow beak and crest
S['GAZZA'] = ([G("""
.yy.....
..yy..ry
.ryyrrrr
rrrrrrry
.rrrrr..
..r..r..
"""), G("""
........
......ry
.rrrrrrr
rrrrrrry
.ryyyr..
..yyr...
""")], 4)
# CAPTAIN CUPPA the flying teapot: blue pot, yellow spout and lid knob
S['CUPPA'] = ([G("""
..y.....
.gggg...
ggggggyy
yggggggy
gggggg..
.yyyy...
"""), G("""
..y...y.
.gggg...
ggggggyy
ygggggg.
gggggg..
.yyyy...
""")], 4)
# TOASTIE the flying toaster: yellow chrome, red slots, toast popping
S['TOASTIE'] = ([G("""
.rr.rr..
yyyyyyy.
yryyryyy
yyyyyyyr
yyyyyyy.
.r...r..
"""), G("""
........
yyyyyyy.
yryyryyy
yyyyyyyr
yyyyyyy.
.r...r..
""")], 4)
# player hit flash (white-ish not available: yellow silhouette)
S['FLASH'] = ([G("""
.yy.....
yyyyyyyy
yyyyyyyy
yyyyyyyy
.yyyyyy.
..y..y..
""")], 4)
# sidekick: CHOOK the chick
S['CHICK'] = ([G("""
.yy.
yyyr
.yy.
"""), G("""
.yy.
yyyr
y.y.
""")], 4)
S['SHIELD'] = ([G("""
.yyyyyyyy.
y........y
y........y
y........y
y........y
y........y
.yyyyyyyy.
""")], 4)
# ---------------------------------------------------------------- player shots
S['SEED'] = ([G("""
yy
""")], 4)
S['BEAM'] = ([G("""
yyyyyyyy
""")], 4)
S['TOAST'] = ([G("""
yyy
yry
yyy
""")], 4)
S['NUT'] = ([G("""
rr
rr
""")], 4)
S['TEABAG'] = ([G("""
.y.
yry
.y.
""")], 4)
S['VEGEMITE'] = ([G("""
.rr
rrr
.rr
""")], 4)
# ---------------------------------------------------------------- enemy bullets & pickups
S['PELLET'] = ([G("""
.yy.
yrry
.yy.
""")], 4)
S['FLAME'] = ([G("""
.ryy
ryyy
.ryy
"""), G("""
.yry
ryyr
.yry
""")], 4)
S['PAV'] = ([G("""
.yyy.
yrrry
yyyyy
.rrr.
"""), G("""
.rrr.
ryyyr
rrrrr
.yyy.
""")], 4)
S['COIN'] = ([G("""
.yy.
yrry
yrry
.yy.
"""), G("""
.y..
.yr.
.yr.
.y..
""")], 4)
S['PIE'] = ([G("""
.yyy.
yyyyy
rrrrr
""")], 4)
S['BOOM'] = ([G("""
...y....
.y.yy.y.
..yrry..
.yrrrry.
..yrry..
.y..y.y.
"""), G("""
.y....y.
..r..r..
.r.yy.r.
...yy...
.r....r.
y..r...y
"""), G("""
r......r
........
...r....
....r...
........
.r....r.
""")], 4)
S['SPARK'] = ([G("""
y.y
.y.
y.y
""")], 4)
# ---------------------------------------------------------------- stage 1 enemies
S['SNAG'] = ([G("""
.rrrrrr.
rryrrrrr
.rrrrrr.
"""), G("""
.rrrrrr.
rrrrryrr
.rrrrrr.
""")], 4)
S['BLOWIE'] = ([G("""
.yy.y.
..yy..
ggggg.
rggggr
.ggg..
"""), G("""
......
......
ggggg.
rggggr
.gggg.
..yyy.
""")], 4)
S['SWOOPER'] = ([G("""
y.....y
yy...yy
.yyyyy.
.yyryy.
..yyy..
...r...
"""), G("""
.......
.......
yyyyyyy
yyyryyy
..yyy..
...r...
""")], 4)
S['THONG'] = ([G("""
...rr..
yyyyyyy
.yyyyy.
"""), G("""
.yyyyy.
yyyyyyy
...rr..
""")], 4)
S['TINNIE'] = ([G("""
.yy.
rrrr
ryrr
rrrr
.yy.
"""), G("""
....
yrry
yryy
yrry
....
""")], 4)
S['SPRINKLER'] = ([G("""
..b..
.yyy.
yryry
.yyy.
"""), G("""
b...b
.yyy.
yryry
.yyy.
""")], 4)
S['ESKY'] = ([G("""
.rrrrrr.
bbbbbbbb
byyyyyyb
bbbbbbbb
bbbbbbbb
"""), G("""
r......r
.rrrrrr.
byyyyyyb
bbbbbbbb
bbbbbbbb
""")], 4)
S['GNOME'] = ([G("""
..r..
.rrr.
rrrrr
.yyy.
yyyyy
.bbb.
.b.b.
"""), G("""
..y..
.yyy.
yyyyy
.yyy.
yyyyy
.yyy.
.y.y.
""")], 4)
S['HOTSNAG'] = ([G("""
.rrrr.
ryyyyr
.rrrr.
"""), G("""
.rr.
rryr
rrrr
.rr.
""")], 4)
S['POSSUM'] = ([G("""
.y..y.
.yyyy.
yryyry
.yyyy.
..rr..
""")], 4)
# ---------------------------------------------------------------- midboss: THE HILLS HOIST
# a rotary clothesline flying on its own spinning arms, undies flapping
S['HOIST'] = ([G("""
y..........y..........y
.y.........y.........y.
..y...rr...y...gg...y..
...y..rr...y...gg..y...
....y......y......y....
yyyyyyyyyyyyyyyyyyyyyyy
....y......y......y....
...y.......y.......y...
..y.......yyy.......y..
.y........yry........y.
y.........yyy.........y
...........y...........
...........y...........
...........y...........
..........yyy..........
.........yyyyy.........
"""), G("""
...........y...........
.rr........y........gg.
.rr....y...y...y....gg.
.........y.y.y.........
..........yyy..........
yyyyyyyyyyyyyyyyyyyyyyy
..........yyy..........
.........y.y.y.........
.......y..yyy..y.......
.....y....yry....y.....
...y......yyy......y...
...........y...........
...........y...........
...........y...........
..........yyy..........
.........yyyyy.........
""")], 1)
S['PEG'] = ([G("""
y.y
.y.
.y.
""")], 4)
S['UNDIES'] = ([G("""
rrrrr
rr.rr
r...r
"""), G("""
ggggg
gg.gg
g...g
""")], 4)
# ---------------------------------------------------------------- boss: THE GRILLFATHER
# a kettle barbecue on legs with a magnificent moustache; the lid is its mouth
S['GRILL'] = ([G("""
........rrrrrrrrrrrrrrrr........
......rrrrrrrrrrrrrrrrrrrr......
.....rrrryyyrrrrrrrryyyrrrr.....
....rrrryyyyyrrrrrryyyyyrrrr....
....rrrryybyyrrrrrryybyyrrrr....
....rrrrryyyrrrrrrrryyyrrrrr....
...yyyyyyyyyyyyyyyyyyyyyyyyyy...
...yrrrrrrrrrrrrrrrrrrrrrrrry...
..yyyyyyyyyyyyyyyyyyyyyyyyyyyy..
..y.rrrrrrrrr.yyyy.rrrrrrrrr.y..
..yrrrrrrrrrrryyyyrrrrrrrrrrry..
..yyrrrrrrrrrrrrrrrrrrrrrrrryy..
...yyrrrrrrrrrrrrrrrrrrrrrryy...
....yyrrrrrrrrrrrrrrrrrrrryy....
.....yyyyyyyyyyyyyyyyyyyyyy.....
...........yy......yy...........
..........yy........yy..........
.........yy..........yy.........
........yy....yyyy....yy........
.......yy....yy..yy....yy.......
......yy....yy....yy....yy......
.....rrr...rrr....rrr...rrr.....
"""), G("""
........rrrrrrrrrrrrrrrr........
......rrrrrrrrrrrrrrrrrrrr......
.....rrrryyyrrrrrrrryyyrrrr.....
....rrrryyyyyrrrrrryyyyyrrrr....
....rrrryybyyrrrrrryybyyrrrr....
...yyyyyyyyyyyyyyyyyyyyyyyyyy...
..y.rrrrrrrrr.yyyy.rrrrrrrrr.y..
..yrrrrrrrrrrryyyyrrrrrrrrrrry..
..y..........................y..
..y.r.r.r.r.r.r.r.r.r.r.r.r..y..
..yyyyyyyyyyyyyyyyyyyyyyyyyyyy..
..yyrrrrrrrrrrrrrrrrrrrrrrrryy..
...yyrrrrrrrrrrrrrrrrrrrrrryy...
....yyrrrrrrrrrrrrrrrrrrrryy....
.....yyyyyyyyyyyyyyyyyyyyyy.....
...........yy......yy...........
..........yy........yy..........
.........yy..........yy.........
........yy....yyyy....yy........
.......yy....yy..yy....yy.......
......yy....yy....yy....yy......
.....rrr...rrr....rrr...rrr.....
"""), G("""
........rrrrrrrrrrrrrrrr........
......rrrrrrrrrrrrrrrrrrrr......
.....rrrrrrrrrrrrrrrrrrrrrr.....
....rrrryyrrrrrrrrrrrryyrrrr....
....rrrrryyrrrrrrrrrryyrrrrr....
....rrrryybyrrrrrrrrybyyrrrr....
...yyyyyyyyyyyyyyyyyyyyyyyyyy...
...yrrrrrrrrrrrrrrrrrrrrrrrry...
..yyyyyyyyyyyyyyyyyyyyyyyyyyyy..
..y.rrrrrrrrr.yyyy.rrrrrrrrr.y..
..yrrrrrrrrrrryyyyrrrrrrrrrrry..
..yyrrrrrrrrrrrrrrrrrrrrrrrryy..
...yyrrrrrrrrrrrrrrrrrrrrrryy...
....yyrrrrrrrrrrrrrrrrrrrryy....
.....yyyyyyyyyyyyyyyyyyyyyy.....
...........yy......yy...........
..........yy........yy..........
.........yy..........yy.........
........yy....yyyy....yy........
.......yy....yy..yy....yy.......
......yy....yy....yy....yy......
.....rrr...rrr....rrr...rrr.....
""")], 1)
S['TONGS'] = ([G("""
yyyyyyyyyy.y
...........y
yyyyyyyyyy.y
"""), G("""
yyyyyyyyy.y.
.........y..
yyyyyyyyy.y.
""")], 4)
S['CLOUD'] = ([G("""
....yyyy........
..yyyyyyyy.yyy..
.yyyyyyyyyyyyyyy
yyyyyyyyyyyyyyyy
.yyyyyyyyyyyyyy.
""")], 4)

def big(n):
    f = S[n][0][0]
    return [[c for c in row for _ in (0, 1)] for row in f for _ in (0, 1)]
for n, b in (('GAZZA', 'BIGGAZ'), ('CUPPA', 'BIGCUP'), ('TOASTIE', 'BIGTOAST')):
    S[b] = ([big(n)], 1)

COMMON = ['BIGGAZ', 'BIGCUP', 'BIGTOAST', 'GAZZA', 'CUPPA', 'TOASTIE', 'FLASH', 'CHICK', 'SHIELD', 'SEED', 'BEAM', 'TOAST', 'NUT', 'TEABAG',
          'VEGEMITE', 'PELLET', 'FLAME', 'PAV', 'COIN', 'PIE', 'BOOM', 'SPARK', 'CLOUD']
STAGE1 = ['SNAG', 'BLOWIE', 'SWOOPER', 'THONG', 'TINNIE', 'SPRINKLER', 'ESKY', 'GNOME', 'HOTSNAG', 'POSSUM',
          'HOIST', 'PEG', 'UNDIES', 'GRILL', 'TONGS']

def pack(frame, nph):
    """-> bytes: db wbytes, h ; then nph phases of h rows x wbytes x (mask, data)"""
    h = len(frame); wpx = len(frame[0])
    wb = (wpx + 3 + (3 if nph == 4 else 0)) // 4
    if nph == 4: wb = (wpx + 3 + 3) // 4
    out = bytearray([wb, h])
    for ph in range(nph):
        for r in range(h):
            row = [-1] * (wb * 4)
            for x, c in enumerate(frame[r]):
                row[x + ph] = c
            for b in range(wb):
                m = d = 0
                for i in range(4):
                    c = row[b * 4 + i]; sh = 6 - 2 * i
                    if c < 0: m |= 3 << sh
                    else: d |= c << sh
                out += bytes([m, d])
    return bytes(out)

def asm(names, label, base=0):
    """-> (table text, records text): SPR_name equ base+index ; label_tab: dw per frame"""
    lines = []; idx = base; recs = []
    for n in names:
        frames, nph = S[n]
        lines.append('SPR_%s equ %d' % (n, idx))
        for f in frames:
            recs.append((n, f, nph)); idx += 1
    lines.append('%s_n equ %d' % (label, idx - base))
    lines.append('%s_tab:' % label)
    for i, (n, f, nph) in enumerate(recs):
        lines.append('            dw %s_r%d' % (label, i))
    R = []
    for i, (n, f, nph) in enumerate(recs):
        b = pack(f, nph)
        st = b[0] * b[1] * 2
        b = b[:2] + bytes([st & 255, st >> 8]) + b[2:]
        R.append('%s_r%d:  ; %s' % (label, i, n))
        R.append('            db %d' % nph)
        for j in range(0, len(b), 24):
            R.append('            db ' + ','.join('$%02X' % x for x in b[j:j + 24]))
    return '\n'.join(lines) + '\n', '\n'.join(R) + '\n'

def size(names):
    return sum(len(pack(f, nph)) + 3 for n in names for f in S[n][0] for nph in [S[n][1]])

if __name__ == '__main__':
    print('common', size(COMMON), 'stage1', size(STAGE1))
