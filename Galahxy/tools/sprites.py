"""GALAHXY sprite art (all original). Mode 1, CSS1 pastel palette:
w = buff(0)  c = cyan(1)  m = magenta(2)  o = orange(3)   '.' = transparent.
Pixels are about 1.5x taller than wide on a 4:3 screen.
Each sprite: name -> (list of frames, nph) ; nph 4 = pre-shifted (any x), 1 = byte-aligned x."""

C = {'w': 0, 'c': 1, 'm': 2, 'o': 3}

def G(s):
    rows = [r for r in s.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    return [[(C[ch] if ch in C else -1) for ch in r.ljust(w, '.')] for r in rows]

S = {}
# ================================================================ the cast (buff outline added below)
# GAZZA the galah: pink (magenta) body, orange beak and crest
S['GAZZA'] = ([G("""
.oo.....
..oo..mo
.mwwmmmm
mmmmmmmo
.mmmmm..
..o..o..
"""), G("""
........
.oo...mo
.mmmmmmm
mmmmmmmo
.mwwwm..
..wwm...
""")], 4)
# CAPTAIN CUPPA the flying teapot: orange pot, buff spout and lid, a cyan rose
S['CUPPA'] = ([G("""
..w.....
.oooo...
oocooowww
woooooow
oooooo..
.wwww...
"""), G("""
..w...w.
.oooo...
oocooowww
wooooooo
oooooo..
.wwww...
""")], 4)
# TOASTIE the flying toaster: buff chrome, magenta slots, orange toast popping
S['TOASTIE'] = ([G("""
.oo.oo..
wwwwwww.
wmwwmwww
wwwwwwwo
wwwwwww.
.m...m..
"""), G("""
........
wwwwwww.
wmwwmwww
wwwwwwwo
wwwwwww.
.m...m..
""")], 4)
# sidekick: a chick in a party hat
S['CHICK'] = ([G("""
.m..
.oo.
ooom
.oo.
"""), G("""
.m..
.oo.
ooom
o.o.
""")], 4)
S['SHIELD'] = ([G("""
.wwwwwwwwww.
w..........w
w..........w
w..........w
w..........w
w..........w
w..........w
.wwwwwwwwww.
""")], 4)
# ================================================================ player shots (buff: never confused with enemy fire)
S['SEED'] = ([G("""
ww
""")], 4)
S['BEAM'] = ([G("""
wwwwwwww
""")], 4)
S['TOAST'] = ([G("""
www
wow
www
""")], 4)
S['NUT'] = ([G("""
ww
wo
""")], 4)
S['TEABAG'] = ([G("""
.w.
wmw
.w.
""")], 4)
S['VEGEMITE'] = ([G("""
.mw
mmw
.mw
""")], 4)
# ================================================================ enemy bullets & pickups
# enemy bullet: orange core, buff ring - reads on cyan sky and magenta ground
S['PELLET'] = ([G("""
.ww.
wood
.ww.
""".replace('d', 'w'))], 4)
# the PAV (pavlova): power capsule - buff meringue, magenta/orange fruit, it twinkles
S['PAV'] = ([G("""
.mom.
wwwww
wwwww
.www.
"""), G("""
.omo.
wwwww
wmwww
.www.
""")], 4)
S['COIN'] = ([G("""
.oo.
owwo
owwo
.oo.
"""), G("""
.o.
owo
owo
.o.
""")], 4)
# the cupcake (heals a heart)
S['PIE'] = ([G("""
.mmm.
mmwmm
.ooo.
.ooo.
""")], 4)
S['BOOM'] = ([G("""
.....
..w..
.wow.
..w..
.....
"""), G("""
.w.w.
w.o.w
.ooo.
w.o.w
.w.w.
"""), G("""
w...w
..o..
.o.o.
..o..
w...w
""")], 4)
S['SPARK'] = ([G("""
w.w
.w.
w.w
""")], 4)
# ================================================================ stage 1: PARTY PLANET
# JELLYBEAN - wobbly sine flyers
S['SNAG'] = ([G("""
.oooooo.
oowooooo
.oooooo.
"""), G("""
..oooo..
oowoooooo
.oooooo.
""")], 4)
# PARTY POPPER - hovers, then darts at you
S['BLOWIE'] = ([G("""
m..wm.
.mmmmo
mwmmmo
m..wm.
"""), G("""
.w.wm.
.mmmmo
mwmmmo
.w.wm.
""")], 4)
# PARTY PENGUIN - party hat, swoops down on you
S['SWOOPER'] = ([G("""
...o...
..mmm..
.mwwmo.
mmwwmm.
.mmmm..
"""), G("""
...o...
..mmm..
.mwwmo.
mmwwmmm
m.mm..m
""")], 4)
# BEACH BALL - bounces along the ground
S['THONG'] = ([G("""
.mwwo.
mmwwoo
.mwwo.
"""), G("""
.owwm.
oowwmm
.owwm.
""")], 4)
# BALLOON carrier - always drops a PAV
S['TINNIE'] = ([G("""
.oo.
owoo
oooo
.oo.
..m.
"""), G("""
.oo.
owoo
oooo
.oo.
.m..
""")], 4)
# CANDY CANNON - a ground turret lobbing sprinkles
S['SPRINKLER'] = ([G("""
..ww.
.mwmw
wmwmw
mmmmm
"""), G("""
.ww..
mwmw.
wmwmw
mmmmm
""")], 4)
# GIFT BOX - shoot it open for a cupcake
S['ESKY'] = ([G("""
..m..m..
...mm...
oooommoo
oooommoo
mmmmmmmm
oooommoo
""")], 4)
# GINGERBREAD MAN - shoot three and the golden one turns up
S['GNOME'] = ([G("""
.ooo.
owowo
.ooo.
ooooo
.owo.
.o.o.
oo.oo
"""), G("""
.www.
wmwmw
.www.
wwwww
.wmw.
.w.w.
ww.ww
""")], 4)
# JELLY BLOB - lobbed by the king
S['HOTSNAG'] = ([G("""
.mmm.
mwmmm
mmmmm
"""), G("""
.mmm.
mmwmm
mmmmm
""")], 4)
# PARTY BUNNY - hops about on the cloud tops
S['POSSUM'] = ([G("""
.w.w..
.w.w..
wwwww.
wmwwww
.wwww.
""")], 4)
# ================================================================ midboss: THE CAROUSEL
# a runaway merry-go-round spinning through the sky, horses on poles
S['HOIST'] = ([G("""
...........o...........
.........mmmmm.........
.......mmwmwmwmm.......
....mmmmmmmmmmmmmmm....
..wwwwwwwwwwwwwwwwwww..
..o...o...o.o...o...o..
..o...o...o.o...o...o..
.wwo..o..wwoo...o..wwo.
wwww..o.wwwwo...o.wwww.
.w.w..o..w.wo...o..w.w.
..o..wwo..o.o..wwo..o..
..o.wwww..o.o.wwww..o..
..o..w.w..o.o..w.w..o..
.mmmmmmmmmmmmmmmmmmmmm.
..ooooooooooooooooooo..
.....................
"""), G("""
...........o...........
.........mmmmm.........
.......mwmwmwmmm.......
....mmmmmmmmmmmmmmm....
..wwwwwwwwwwwwwwwwwww..
..o...o...o.o...o...o..
..o..wwo..o.o..wwo..o..
..o.wwww..o.o.wwww..o..
..o..w.w..o.o..w.w..o..
.wwo..o..wwoo...o..wwo.
wwww..o.wwwwo...o.wwww.
.w.w..o..w.wo...o..w.w.
..o...o...o.o...o...o..
.mmmmmmmmmmmmmmmmmmmmm.
..ooooooooooooooooooo..
.....................
""")], 1)
# a wooden horse flung off the carousel (arcs and falls)
S['PEG'] = ([G("""
ww.
www
o.o
""")], 4)
# streamers fluttering away from the carousel
S['UNDIES'] = ([G("""
m.o.m
.m.m.
m.o.m
"""), G("""
.m.o.
m.m.m
.m.o.
""")], 4)
# ================================================================ boss: KING WOBBLE
# a giant jelly in a crown on a cake-stand. frame 0 calm, 1 crown lifted (tell), 2 furious
S['GRILL'] = ([G("""
.........o..o..o..o.............
.........oooooooooo.............
.........owomowomwo.............
......mmmmmmmmmmmmmmmmmmmm......
....mmmmmmmmmmmmmmmmmmmmmmmm....
...mmmmwwwmmmmmmmmmmwwwmmmmmm...
...mmmwwcwwmmmmmmmmwwcwwmmmmm...
..mmmmmwwwmmmmmmmmmmwwwmmmmmmm..
..mmmwmmmmmmmmmmmmmmmmmmmmmmmm..
..mmmwmmmmmmmoooooommmmmmmmmmm..
..mmmmmmmmmmmmoooommmmmmmmmmmm..
...mmmmmmmmmmmmmmmmmmmmmmmmmm...
....mmmmmmmmmmmmmmmmmmmmmmmm....
..wwwwwwwwwwwwwwwwwwwwwwwwwwww..
...w.w.w.w.w.w.w.w.w.w.w.w.w....
..............ww................
..............ww................
.............wwww...............
...........wwwwwwww.............
........wwwwwwwwwwwwww..........
.......oooooooooooooooo.........
................................
"""), G("""
.........o..o..o..o.............
.........oooooooooo.............
.........owomowomwo.............
................................
......mmmmmmmmmmmmmmmmmmmm......
....mmmmmmmmmmmmmmmmmmmmmmmm....
...mmmmwwwmmmmmmmmmmwwwmmmmmm...
...mmmwwcwwmmmmmmmmwwcwwmmmmm...
..mmmmmwwwmmmmmmmmmmwwwmmmmmmm..
..mmmwmmmmmmooooooooommmmmmmmm..
..mmmwmmmmmoowwwwwwoommmmmmmmm..
..mmmmmmmmmoooooooooommmmmmmmm..
...mmmmmmmmmmmmmmmmmmmmmmmmmm...
..wwwwwwwwwwwwwwwwwwwwwwwwwwww..
...w.w.w.w.w.w.w.w.w.w.w.w.w....
..............ww................
..............ww................
.............wwww...............
...........wwwwwwww.............
........wwwwwwwwwwwwww..........
.......oooooooooooooooo.........
................................
"""), G("""
..o.......o..o..o..o.......o....
...o......oooooooooo......o.....
..........owomowomwo............
......mmmmmmmmmmmmmmmmmmmm......
....mmmmoommmmmmmmmmmmoommmm....
...mmmmmmooommmmmmmmooommmmmm...
...mmmmwwcwwmmmmmmmmwwcwwmmmm...
..mmmmmmwwwmmmmmmmmmmwwwmmmmmm..
..mmmmmmmmmmmmmmmmmmmmmmmmmmmm..
..mmmmmmmmmooooooooooommmmmmmm..
..mmmmmmmmmowowowowowommmmmmmm..
...mmmmmmmmoooooooooooommmmmm...
....mmmmmmmmmmmmmmmmmmmmmmmm....
..wwwwwwwwwwwwwwwwwwwwwwwwwwww..
...w.w.w.w.w.w.w.w.w.w.w.w.w....
..............ww................
..............ww................
.............wwww...............
...........wwwwwwww.............
........wwwwwwwwwwwwww..........
.......oooooooooooooooo.........
................................
""")], 1)
# the king's giant spoon, shot out at you
S['TONGS'] = ([G("""
.wwwwwwwwwww
ww.......www
.wwwwwwwwwww
"""), G("""
.wwwwwwwwwww
www......www
.wwwwwwwwwww
""")], 4)
S['SHOPBAL'] = ([G("""
..wwwwww..
.wwmmmmww.
wwmwwwwwww
wwwmmmwwww
wwwwwwmwww
wwmmmmwwww
.wwwwwwww.
..wwwwww..
....oo....
.....o....
""")], 1)
S['CLOUD'] = ([G("""
....wwww........
..wwwwwwww.www..
.wwwwwwwwwwwwwww
wwwwwwwwwwwwwwww
.wwwwwwwwwwwwww.
""")], 4)
def outline(fr, c=0):
    h = len(fr) + 2; w = len(fr[0]) + 2
    g = [[-1] * w for _ in range(h)]
    for y, row in enumerate(fr):
        for x, v in enumerate(row): g[y + 1][x + 1] = v
    out = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] < 0 and any(0 <= y + dy < h and 0 <= x + dx < w and g[y + dy][x + dx] >= 0
                                   for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))):
                out[y][x] = c
    return out
for n in ('GAZZA', 'CUPPA', 'TOASTIE'):
    S[n] = ([outline(f) for f in S[n][0]], S[n][1])

def big(n):
    f = S[n][0][0]
    return [[c for c in row for _ in (0, 1)] for row in f for _ in (0, 1)]
for n, b in (('GAZZA', 'BIGGAZ'), ('CUPPA', 'BIGCUP'), ('TOASTIE', 'BIGTOAST')):
    S[b] = ([big(n)], 1)

COMMON = ['BIGGAZ', 'BIGCUP', 'BIGTOAST', 'GAZZA', 'CUPPA', 'TOASTIE', 'CHICK', 'SHIELD', 'SEED', 'BEAM', 'TOAST', 'NUT', 'TEABAG',
          'VEGEMITE', 'PELLET', 'PAV', 'COIN', 'PIE', 'BOOM', 'SPARK', 'CLOUD', 'SHOPBAL']
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

LOW = set(); LOW_SPLIT = False
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
    R = []; R2 = []
    for i, (n, f, nph) in enumerate(recs):
        if n in LOW:
            R, R2 = R2, R
        b = pack(f, nph)
        st = b[0] * b[1] * 2
        b = b[:2] + bytes([st & 255, st >> 8]) + b[2:]
        R.append('%s_r%d:  ; %s' % (label, i, n))
        R.append('            db %d' % nph)
        for j in range(0, len(b), 24):
            R.append('            db ' + ','.join('$%02X' % x for x in b[j:j + 24]))
        if n in LOW:
            R, R2 = R2, R
    if LOW_SPLIT: return '\n'.join(lines) + '\n', '\n'.join(R) + '\n', '\n'.join(R2) + '\n'
    return '\n'.join(lines) + '\n', '\n'.join(R) + '\n'

def size(names):
    return sum(len(pack(f, nph)) + 3 for n in names for f in S[n][0] for nph in [S[n][1]])

if __name__ == '__main__':
    print('common', size(COMMON), 'stage1', size(STAGE1))
