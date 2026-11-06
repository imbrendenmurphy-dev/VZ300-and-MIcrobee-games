#!/usr/bin/env python3
"""ROBOGEDDON 2085 graphics generator -> gfx.inc (sjasmplus syntax).
Pixel chars: '.'=0 background, 'y'=1, 'b'=2, 'r'=3  (CSS0: yellow/blue/red,
CSS1: cyan/magenta/orange).  Sprites are pre-shifted for the 4 pixel phases
inside a mode(1) byte and stored as  [wbytes][h][data...], drawn with OR.
"""
import sys

PIX = {'.': 0, 'y': 1, 'b': 2, 'r': 3, 'c': 9}

def parse(art):
    rows = [r.strip() for r in art.strip().split('\n')]
    w = max(len(r) for r in rows)
    return [[PIX[ch] for ch in r.ljust(w, '.')] for r in rows]

def recolour(px, c):
    return [[(c if v == 9 else v) for v in row] for row in px]

def shifted(px, s):
    h = len(px)
    w = len(px[0])
    wb = (s + w + 3) // 4
    out = []
    for row in px:
        line = [0] * s + row + [0] * (wb * 4 - s - w)
        for b in range(wb):
            v = 0
            for p in range(4):
                v = (v << 2) | line[b * 4 + p]
            out.append(v)
    return wb, h, out

FRAMES = []          # (name, pixels)

def add(name, art, colour=None):
    px = parse(art)
    if colour is not None:
        px = recolour(px, colour)
    FRAMES.append((name, px))

def mirror(px):
    return [list(reversed(r)) for r in px]

# ---------------------------------------------------------------- player
P_DOWN = ["""
.yyy.
.yby.
rrrrr
.rrr.
.b.b.
.b.b.
""", """
.yyy.
.yby.
rrrrr
.rrr.
.b.b.
b...b
"""]
P_UP = ["""
.yyy.
.yyy.
rrrrr
.rrr.
.b.b.
.b.b.
""", """
.yyy.
.yyy.
rrrrr
.rrr.
.b.b.
b...b
"""]
P_LEFT = ["""
.yy..
byy..
yrrr.
.rrr.
.b.b.
.b.b.
""", """
.yy..
byy..
yrrr.
.rrr.
.bb..
b..b.
"""]
for i, a in enumerate(P_DOWN): add('PL_D%d' % i, a)
for i, a in enumerate(P_UP): add('PL_U%d' % i, a)
for i, a in enumerate(P_LEFT): add('PL_L%d' % i, a)
for i, a in enumerate(P_LEFT):
    FRAMES.append(('PL_R%d' % i, mirror(parse(a))))

# ---------------------------------------------------------------- enemies
add('GRUNT0', """
.rrr.
ryryr
rrrrr
.rrr.
r...r
""")
add('GRUNT1', """
.rrr.
ryryr
rrrrr
.rrr.
.r.r.
""")
add('HULK0', """
..bbb..
..brb..
bbbbbbb
b.bbb.b
b.rrr.b
..b.b..
.bb.bb.
""")
add('HULK1', """
..bbb..
..brb..
bbbbbbb
b.bbb.b
b.rrr.b
..b.b..
..b.b..
""")
ELEC = ["""
..c..
.c.c.
c.c.c
.c.c.
..c..
""", """
ccccc
c...c
c.c.c
c...c
ccccc
""", """
c...c
.c.c.
..c..
.c.c.
c...c
"""]
for s, a in enumerate(ELEC):
    for c in (1, 2, 3):
        add('ELEC%d_%d' % (s, c), a, c)
add('MOM0', """
.rrr.
.yyy.
.yyy.
yyyyy
yyyyy
.y.y.
""")
add('MOM1', """
.rrr.
.yyy.
.yyy.
yyyyy
yyyyy
y...y
""")
add('DAD0', """
.bbb.
.yyy.
byyyb
.yyy.
.y.y.
.y.y.
""")
add('DAD1', """
.bbb.
.yyy.
byyyb
.yyy.
.y.y.
y...y
""")
add('KID0', """
.r.
.y.
yyy
.y.
y.y
""")
add('KID1', """
.r.
.y.
yyy
.y.
yy.
""")
add('BRAIN0', """
.rrrrr.
rrrrrrr
.ybbby.
..bbb..
.b.b.b.
.b...b.
""")
add('BRAIN1', """
.rrrrr.
rrrrrrr
.ybbby.
..bbb..
.b.b.b.
..b.b..
""")
add('PROG0', """
.rbr.
.byb.
rybyr
.rbr.
.r.r.
""")
add('PROG1', """
.brb.
.ryr.
byryb
.brb.
b...b
""")
add('SPH0', """
.....
.rrr.
.ryr.
.rrr.
.....
""")
add('SPH1', """
.rrr.
r.y.r
ryyyr
r.y.r
.rrr.
""")
add('SPH2', """
r.r.r
.....
r.y.r
.....
r.r.r
""")
add('ENF0', """
..y..
.yry.
yrrry
.yry.
y...y
""")
add('ENF1', """
..y..
.yry.
yrrry
.yry.
.y.y.
""")
add('TANK0', """
...b...
..bbb..
bbybybb
bbbbbbb
b.b.b.b
.b.b.b.
""")
add('TANK1', """
...b...
..bbb..
bbybybb
bbbbbbb
.b.b.b.
b.b.b.b
""")
add('SKULL', """
.yyy.
ybyby
yyyyy
.y.y.
.yyy.
""")
add('PICK_TRI0', """
bbbbb
by.yb
b.y.b
by.yb
bbbbb
""")
add('PICK_TRI1', """
rrrrr
ry.yr
r.y.r
ry.yr
rrrrr
""")
add('PICK_SH0', """
.rrr.
ryyyr
ryyyr
.ryr.
..r..
""")
add('PICK_SH1', """
.bbb.
byyyb
byyyb
.byb.
..b..
""")

add('SPARK0', """
.r.
rbr
.r.
""")
add('SPARK1', """
r.r
.b.
r.r
""")
add('SHELL', """
bbb
byb
bbb
""")
add('MISS', """
yry
rrr
yry
""")

# ---------------------------------------------------------------- big logo
BIG = {
'R': ["1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1"],
'O': [".111.", "1...1", "1...1", "1...1", "1...1", "1...1", ".111."],
'B': ["1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111."],
'G': [".111.", "1...1", "1....", "1.111", "1...1", "1...1", ".111."],
'E': ["11111", "1....", "1....", "1111.", "1....", "1....", "11111"],
'D': ["111..", "1..1.", "1...1", "1...1", "1...1", "1..1.", "111.."],
'N': ["1...1", "11..1", "1.1.1", "1..11", "1...1", "1...1", "1...1"],
}
def big_letter(ch):
    src = BIG[ch]
    W, H = 11, 15
    g = [[0] * W for _ in range(H)]
    solid = [[0] * 10 for _ in range(14)]
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c == '1':
                for dy in range(2):
                    for dx in range(2):
                        solid[y * 2 + dy][x * 2 + dx] = 1
    # shadow first (offset +1,+1) in blue
    for y in range(14):
        for x in range(10):
            if solid[y][x]:
                g[y + 1][x + 1] = 2
    for y in range(14):
        for x in range(10):
            if solid[y][x]:
                g[y][x] = 1 if y < 5 else 3      # yellow top, red body
                if y == 5 or y == 6:
                    g[y][x] = 1 if (x + y) % 2 == 0 else 3   # dithered blend
    return g
NGAME = len(FRAMES)      # frames before here also get a masked game copy
for ch in "ROBGEDN":
    FRAMES.append(('BIG_' + ch, big_letter(ch)))

# ---------------------------------------------------------------- title badges
# round discs (9x6 pixels look round on the 4:3 screen) with a V or a Z
BADGE = {'V': """
..ccccc..
.clccclc.
ccclclccc
ccclclccc
.ccclccc.
..ccccc..
""", 'Z': """
..ccccc..
.clllllc.
cccccllcc
ccllccccc
.clllllc.
..ccccc..
"""}
BADGE_COLS = [(1, 3), (3, 1), (2, 1)]     # disc, letter: yellow/red, red/yellow, blue/yellow
for letter in 'VZ':
    for i, (dc, lc) in enumerate(BADGE_COLS):
        art = BADGE[letter].replace('l', 'L')
        px = [[{'.': 0, 'c': dc, 'L': lc}[ch] for ch in row.strip()] for row in art.strip().split('\n')]
        FRAMES.append(('BADGE_%s%d' % (letter, i), px))

# ---------------------------------------------------------------- tiny font 3x5
F3 = {
' ': ["...", "...", "...", "...", "..."],
'!': [".#.", ".#.", ".#.", "...", ".#."],
'"': ["#.#", "#.#", "...", "...", "..."],
'#': ["#.#", "###", "#.#", "###", "#.#"],
'$': [".##", "##.", ".#.", ".##", "##."],
'%': ["#.#", "..#", ".#.", "#..", "#.#"],
'&': [".#.", "#.#", ".#.", "#.#", ".##"],
"'": [".#.", ".#.", "...", "...", "..."],
'(': ["..#", ".#.", ".#.", ".#.", "..#"],
')': ["#..", ".#.", ".#.", ".#.", "#.."],
'*': ["...", "#.#", ".#.", "#.#", "..."],
'+': ["...", ".#.", "###", ".#.", "..."],
',': ["...", "...", "...", ".#.", "#.."],
'-': ["...", "...", "###", "...", "..."],
'.': ["...", "...", "...", "...", ".#."],
'/': ["..#", "..#", ".#.", "#..", "#.."],
'0': ["###", "#.#", "#.#", "#.#", "###"],
'1': [".#.", "##.", ".#.", ".#.", "###"],
'2': ["###", "..#", "###", "#..", "###"],
'3': ["###", "..#", ".##", "..#", "###"],
'4': ["#.#", "#.#", "###", "..#", "..#"],
'5': ["###", "#..", "###", "..#", "###"],
'6': ["###", "#..", "###", "#.#", "###"],
'7': ["###", "..#", ".#.", ".#.", ".#."],
'8': ["###", "#.#", "###", "#.#", "###"],
'9': ["###", "#.#", "###", "..#", "###"],
':': ["...", ".#.", "...", ".#.", "..."],
';': ["...", ".#.", "...", ".#.", "#.."],
'<': ["..#", ".#.", "#..", ".#.", "..#"],
'=': ["...", "###", "...", "###", "..."],
'>': ["#..", ".#.", "..#", ".#.", "#.."],
'?': ["###", "..#", ".##", "...", ".#."],
'@': [".#.", "#.#", "#.#", "#..", ".##"],   # used as copyright-ish
'A': [".#.", "#.#", "###", "#.#", "#.#"],
'B': ["##.", "#.#", "##.", "#.#", "##."],
'C': [".##", "#..", "#..", "#..", ".##"],
'D': ["##.", "#.#", "#.#", "#.#", "##."],
'E': ["###", "#..", "##.", "#..", "###"],
'F': ["###", "#..", "##.", "#..", "#.."],
'G': [".##", "#..", "#.#", "#.#", ".##"],
'H': ["#.#", "#.#", "###", "#.#", "#.#"],
'I': ["###", ".#.", ".#.", ".#.", "###"],
'J': ["..#", "..#", "..#", "#.#", ".#."],
'K': ["#.#", "#.#", "##.", "#.#", "#.#"],
'L': ["#..", "#..", "#..", "#..", "###"],
'M': ["#.#", "###", "###", "#.#", "#.#"],
'N': ["##.", "#.#", "#.#", "#.#", "#.#"],
'O': [".#.", "#.#", "#.#", "#.#", ".#."],
'P': ["##.", "#.#", "##.", "#..", "#.."],
'Q': [".#.", "#.#", "#.#", "##.", ".##"],
'R': ["##.", "#.#", "##.", "#.#", "#.#"],
'S': [".##", "#..", ".#.", "..#", "##."],
'T': ["###", ".#.", ".#.", ".#.", ".#."],
'U': ["#.#", "#.#", "#.#", "#.#", "###"],
'V': ["#.#", "#.#", "#.#", "#.#", ".#."],
'W': ["#.#", "#.#", "###", "###", "#.#"],
'X': ["#.#", "#.#", ".#.", "#.#", "#.#"],
'Y': ["#.#", "#.#", ".#.", ".#.", ".#."],
'Z': ["###", "..#", ".#.", "#..", "###"],
'[': [".##", ".#.", ".#.", ".#.", ".##"],
'\\': [".#.", "###", ".#.", "#.#", "..."],  # tiny man (life icon)
']': ["##.", ".#.", ".#.", ".#.", "##."],
'^': [".#.", "#.#", "...", "...", "..."],
'_': ["...", "...", "...", "...", "###"],
}

def font3_bytes():
    out = []
    for code in range(32, 96):
        ch = chr(code)
        g = F3.get(ch, F3['?'])
        for row in g:
            v = 0
            for p in range(4):
                bit = 3 if (p < 3 and row[p] == '#') else 0
                v = (v << 2) | bit
            out.append(v)
    return out

def font2x_bytes():
    out = []
    for code in range(32, 96):
        ch = chr(code)
        g = F3.get(ch, F3['?'])
        for row in g:
            cells = [(row[p] == '#') for p in range(3)] + [False]
            bits = []
            for c in cells:
                bits += [c, c]
            b0 = 0
            b1 = 0
            for p in range(4):
                b0 = (b0 << 2) | (3 if bits[p] else 0)
                b1 = (b1 << 2) | (3 if bits[p + 4] else 0)
            out += [b0, b1, b0, b1]     # each source row -> 2 rows
    return out

def db_lines(label, data, per=16):
    s = [label + ':']
    for i in range(0, len(data), per):
        s.append('    db ' + ','.join('$%02X' % b for b in data[i:i + per]))
    return '\n'.join(s)

def main():
    out = ['; generated by gfx.py - do not edit', '']
    for i, (name, _) in enumerate(FRAMES):
        out.append('F_%s equ %d' % (name, i))
    out.append('NUMFRAMES equ %d' % len(FRAMES))
    out.append('')
    out.append('frametab:')
    for name, _ in FRAMES:
        out.append('    dw %s' % ','.join('sp_%s_%d' % (name, s) for s in range(4)))
    out.append('')
    total = 0
    for name, px in FRAMES:
        for s in range(4):
            wb, h, data = shifted(px, s)
            total += 2 + len(data)
            out.append('sp_%s_%d: db %d,%d,%s' % (name, s, wb, h, ','.join('$%02X' % b for b in data)))
    out.append('')
    # masked copies of the game frames for the blue arena: blue -> green,
    # stored as (keep-mask, pixels) byte pairs
    out.append('NGFRAMES equ %d' % NGAME)
    out.append('gframetab:')
    for name, _ in FRAMES[:NGAME]:
        out.append('    dw %s' % ','.join('gp_%s_%d' % (name, s) for s in range(4)))
    for name, px in FRAMES[:NGAME]:
        rec = [[(2 if v == 2 else v) for v in row] for row in px]
        data_px = [[(0 if v == 2 else v) for v in row] for row in px]
        mask_px = [[(3 if v else 0) for v in row] for row in px]
        for s_ in range(4):
            wb, h, d = shifted(data_px, s_)
            _, _, m = shifted(mask_px, s_)
            inter = []
            for a, b in zip(m, d):
                inter += [(~a) & 255, b]
            total += 2 + len(inter)
            out.append('gp_%s_%d: db %d,%d,%s' % (name, s_, wb, h, ','.join('$%02X' % b for b in inter)))
    out.append('')
    out.append(db_lines('font3', font3_bytes()))
    out.append('')
    out.append(db_lines('font2x', font2x_bytes()))
    out.append('')
    with open(sys.argv[1] if len(sys.argv) > 1 else 'gfx.inc', 'w') as f:
        f.write('\n'.join(out) + '\n')
    print('frames', len(FRAMES), 'sprite bytes', total, file=sys.stderr)

main()
