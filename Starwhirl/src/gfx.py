#!/usr/bin/env python3
"""STARWHIRL graphics -> gfx.inc (sjasmplus).
Pixel chars: '.' transparent, 'g' green (0), 'y' yellow (1), 'b' blue (2),
'r' red (3).  In CSS1 sectors the same pixels show as buff/cyan/magenta/orange.
Every frame is pre-shifted for the 4 pixel phases of a mode(1) byte and
stored as [width bytes][rows] then (keep-mask, pixels) byte pairs, drawn
through the mask with POP.  A size table (pixel w, h) lets sprites be drawn
centred on a point.  All art is original.
"""
import math
import sys
from font3 import F3
import ship

PIX = {'.': None, 'g': 0, 'y': 1, 'b': 2, 'r': 3}
FRAMES = []          # (name, rows of pixel values / None)


def parse(art):
    rows = [r.strip() for r in art.strip('\n').split('\n')]
    w = max(len(r) for r in rows)
    return [[PIX[ch] for ch in r.ljust(w, '.')] for r in rows]


def add(name, art):
    FRAMES.append((name, parse(art) if isinstance(art, str) else art))


# ---------------------------------------------------------------- player
for i, a in enumerate(ship.headings()):
    add('SHIP%d' % i, '\n'.join(a))

# ---------------------------------------------------------------- enemies
# each type: s0 (dot), s1 (3x2), s2a, s2b (5x3), s3a, s3b (7x5)
ENEMIES = {
'GLINT': ["y", "yry\n.y.",
          "..y..\nyyryy\n..y..", ".y.y.\n..r..\n.y.y.",
          "...y...\n..yry..\nyyrrryy\n..yry..\n...y...",
          ".y...y.\n..yry..\n..rrr..\n..yry..\n.y...y."],
'MOTH':  ["r", "ryr\nr.r",
          "r...r\nrryrr\n..y..", ".r.r.\nrryrr\nr.y.r",
          "r.....r\nrr.y.rr\nrrryrrr\n.r.y.r.\n...y...",
          ".r...r.\nrr.y.rr\n.rryrr.\nrr.y.rr\n...y..."],
'SPIN':  ["g", ".g.\ngyg",
          "..g..\nggygg\n..g..", ".g.g.\n..y..\n.g.g.",
          "...r...\n...g...\nrggyggr\n...g...\n...r...",
          ".r...r.\n..g.g..\n...y...\n..g.g..\n.r...r."],
'HORNET': ["r", "gyg\n.r.",
          "g.r.g\ngyryg\n..r..", "..r..\nggygg\n.yry.",
          "g..r..g\ngg.r.gg\n.gyryg.\n..yry..\n...r...",
          "...r...\ng..r..g\nggyrygg\n..yry..\n...r..."],
'MINE':  ["r", "yry\n.r.",
          "y.r.y\n.rrr.\ny.r.y", "..y..\nyrrry\n..y..",
          "y..r..y\n.rrrrr.\nrrryrrr\n.rrrrr.\ny..r..y",
          "...y...\ny.rrr.y\n.rryrr.\ny.rrr.y\n...y..."],
'POD':   ["g", "gyg\n.g.",
          ".ggg.\ngyyyg\n.ggg.", ".yyy.\nygggy\n.yyy.",
          "..ggg..\n.gyyyg.\ngyyryyg\n.gyyyg.\n..ggg..",
          "..yyy..\n.ygggy.\nyggrggy\n.ygggy.\n..yyy.."],
'SPARK': ["y", ".y.\nyyy",
          "..y..\nyyyyy\n.y.y.", "..g..\ngyyyg\n.g.g.",
          "...y...\n..yyy..\nyyyyyyy\n..yyy..\n.y...y.",
          "...g...\n..ygy..\ngyyyyyg\n..ygy..\n.g...g."],
'ARMOR': ["r", "rgr\n.r.",
          ".rrr.\nrgygr\n.rrr.", ".yyy.\nyryry\n.yyy.",
          "..rrr..\n.rgggr.\nrggyggr\n.rgggr.\n..rrr..",
          "..yyy..\n.yrrry.\nyrryrry\n.yrrry.\n..yyy.."],
}
ETYPES = ['GLINT', 'MOTH', 'SPIN', 'HORNET', 'MINE', 'POD', 'SPARK', 'ARMOR']
for t in ETYPES:
    for k, a in enumerate(ENEMIES[t]):
        add('%s_%d' % (t, k), a)

# ---------------------------------------------------------------- bosses
BOSSES = {
'WARDEN': ["""
....rrrrr....
..rryyyyyrr..
.ryy.....yyr.
ryy..ggg..yyr
ry..grrrg..yr
ryy..ggg..yyr
.ryy.....yyr.
..rryyyyyrr..
....rrrrr....
""", """
....rrrrr....
..rryyyyyrr..
.ryyyyyyyyyr.
ryygyyyyygyyr
rrrrrrrrrrrrr
ryygyyyyygyyr
.ryyyyyyyyyr.
..rryyyyyrr..
....rrrrr....
"""],
'CORAL': ["""
g.g..y.y..g.g
.ggyyyyyyygg.
..yy.....yy..
.yy..rrr..yy.
gy..rgggr..yg
.yy..rrr..yy.
..yy.....yy..
.ggyyyyyyygg.
g.g..y.y..g.g
""", """
g.g..y.y..g.g
.ggyyyyyyygg.
..yyyyyyyyy..
.yyyygggyyyy.
gyyygrrrgyyyg
.yyyygggyyyy.
..yyyyyyyyy..
.ggyyyyyyygg.
g.g..y.y..g.g
"""],
'EMBER': ["""
r...........r
rr.yyyyyyy.rr
.rry.....yrr.
..ry.ggg.yr..
..ry.grg.yr..
..ry.ggg.yr..
.rry.....yrr.
rr.yyyyyyy.rr
r...........r
""", """
r...........r
rr.yyyyyyy.rr
.rryyyyyyyrr.
..ryyyyyyyr..
..rrrrrrrrr..
..ryyyyyyyr..
.rryyyyyyyrr.
rr.yyyyyyy.rr
r...........r
"""],
'EYE': ["""
...ggggggg...
.ggyyyyyyygg.
gyyy.rrr.yyyg
gyy.rr.rr.yyg
gy.rr.y.rr.yg
gyy.rr.rr.yyg
gyyy.rrr.yyyg
.ggyyyyyyygg.
...ggggggg...
""", """
...ggggggg...
.ggyyyyyyygg.
gyyyyyyyyyyyg
gggyyyyyyyggg
grrrrrrrrrrrg
gggyyyyyyyggg
gyyyyyyyyyyyg
.ggyyyyyyygg.
...ggggggg...
"""],
}
for t in ['WARDEN', 'CORAL', 'EMBER', 'EYE']:
    add('B%s_O' % t, BOSSES[t][0])
    add('B%s_C' % t, BOSSES[t][1])
add('BSEED0', "..rrr..\n.ryyyr.\nryyryyr\n.ryyyr.\n..rrr..")
add('BSEED1', "...rrr...\n.rryyyrr.\nryyy.yyyr\nryy.r.yyr\nryyy.yyyr\n.rryyyrr.\n...rrr...")

# ---------------------------------------------------------------- effects
add('EXA', "y..r..y\n.r.y.r.\nr.yyy.r\n.r.y.r.\ny..r..y")
add('EXB', "r.....r\n...y...\n.y...y.\n...y...\nr.....r")
add('EXS', ".y.\nyry\n.y.")
add('EXT', "y.y\n...\ny.y")
add('SHOT0', "y")
add('SHOT1', "y\ny")
add('SHOT2', "yy\nyy")
add('ESHOT0', "r")
add('ESHOT1', "ry\nyr")
add('ESHOT2', ".r.\nryr\n.r.")
add('PLASMA0', "y")
add('PLASMA1', "yr\nry")
add('PLASMA2', "ryr\nyyy\nryr")
add('LIFE', "..y..\n.yyy.\nr.g.r")
add('PIP', "gg\ngg")
add('PIPX', "rr\nrr")


def vortex(phase):
    """two-arm spiral 11x5 (the eye of the whirl), rotated by phase*45 deg"""
    W, H = 11, 5
    rows = []
    for y in range(H):
        row = ''
        for x in range(W):
            vx = (x + 0.5 - W / 2)
            vy = (y + 0.5 - H / 2) * 1.5
            rho = math.hypot(vx, vy)
            if rho > 5.6:
                row += '.'
                continue
            th = math.atan2(vy, vx)
            v = (th - rho * 0.9 + phase * math.pi / 4) % math.pi
            if rho < 1.0:
                row += 'y'
            elif v < 0.9:
                row += 'y' if rho < 3.2 else 'g'
            elif v < 1.3 and rho < 4.5:
                row += 'g'
            else:
                row += '.'
        rows.append(row)
    return '\n'.join(rows)


for p in range(4):
    add('VORTEX%d' % p, vortex(p))

# ---------------------------------------------------------------- logo
BIG = {
'S': [".1111", "1....", "1....", ".111.", "....1", "....1", "1111."],
'T': ["11111", "..1..", "..1..", "..1..", "..1..", "..1..", "..1.."],
'A': [".111.", "1...1", "1...1", "11111", "1...1", "1...1", "1...1"],
'R': ["1111.", "1...1", "1...1", "1111.", "1.1..", "1..1.", "1...1"],
'W': ["1...1", "1...1", "1...1", "1.1.1", "1.1.1", "11.11", "1...1"],
'H': ["1...1", "1...1", "1...1", "11111", "1...1", "1...1", "1...1"],
'I': ["111", ".1.", ".1.", ".1.", ".1.", ".1.", "111"],
'L': ["1....", "1....", "1....", "1....", "1....", "1....", "11111"],
}


def big_letter(ch):
    src = BIG[ch]
    w = len(src[0])
    W, H = w * 2 + 1, 15
    g = [[None] * W for _ in range(H)]
    solid = [[0] * (w * 2) for _ in range(14)]
    for y, row in enumerate(src):
        for x, c in enumerate(row):
            if c == '1':
                for dy in range(2):
                    for dx in range(2):
                        solid[y * 2 + dy][x * 2 + dx] = 1
    for y in range(14):          # green drop shadow
        for x in range(w * 2):
            if solid[y][x]:
                g[y + 1][x + 1] = 0
    for y in range(14):
        for x in range(w * 2):
            if solid[y][x]:
                if y < 4:
                    v = 1
                elif y < 6:
                    v = 1 if (x + y) % 2 == 0 else 3
                else:
                    v = 3
                g[y][x] = v
    return g


for ch in "STARWHIL":
    FRAMES.append(('BIG_' + ch, big_letter(ch)))


# ---------------------------------------------------------------- output
def shifted(px, s, fn):
    h = len(px)
    w = len(px[0])
    wb = (s + w + 3) // 4
    out = []
    for row in px:
        line = [None] * s + row + [None] * (wb * 4 - s - w)
        for b in range(wb):
            v = 0
            for p in range(4):
                v = (v << 2) | fn(line[b * 4 + p])
            out.append(v)
    return wb, h, out


def font3_bytes():
    out = []
    for code in range(32, 96):
        g = F3.get(chr(code), F3['?'])
        for row in g:
            v = 0
            for p in range(4):
                v = (v << 2) | (3 if (p < 3 and row[p] == '#') else 0)
            out.append(v)
    return out


def font2x_bytes():
    out = []
    for code in range(32, 96):
        g = F3.get(chr(code), F3['?'])
        for row in g:
            cells = [(row[p] == '#') for p in range(3)] + [False]
            bits = []
            for c in cells:
                bits += [c, c]
            b0 = b1 = 0
            for p in range(4):
                b0 = (b0 << 2) | (3 if bits[p] else 0)
                b1 = (b1 << 2) | (3 if bits[p + 4] else 0)
            out += [b0, b1, b0, b1]
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
    for t in ETYPES:
        out.append('FT_%s equ F_%s_0' % (t, t))
    out.append('')
    out.append('gframetab:')
    total = 0
    def shifts_of(name, px):
        # frames always drawn centred on x=64 (bosses, the vortex) or at a
        # byte-aligned column (logo letters) need only that one phase
        if name.startswith('BIG_'):
            return [0]
        if name[0] == 'B' and not name.startswith('BIG') or name.startswith('VORTEX'):
            return [(64 - len(px[0]) // 2) & 3]
        return [0, 1, 2, 3]
    for name, px in FRAMES:
        sh = shifts_of(name, px)
        out.append('    dw %s' % ','.join('gp_%s_%d' % (name, s if s in sh else sh[0]) for s in range(4)))
    out.append('fsize:                  ; half width, half height, height of each frame')
    for name, px in FRAMES:
        out.append('    db %d,%d,%d' % (len(px[0]) // 2, len(px) // 2, len(px)))
    for name, px in FRAMES:
        for s_ in shifts_of(name, px):
            wb, h, d = shifted(px, s_, lambda v: 0 if v is None else v)
            _, _, m = shifted(px, s_, lambda v: 0 if v is None else 3)
            assert wb <= 4, name
            inter = []
            for a, b in zip(m, d):
                inter += [(~a) & 255, b]
            total += 2 + len(inter)
            out.append('gp_%s_%d: db %d,%d,%s' % (name, s_, wb, h, ','.join('$%02X' % b for b in inter)))
    out.append('')
    out.append(db_lines('font3', font3_bytes()))
    with open(sys.argv[1] if len(sys.argv) > 1 else 'gfx.inc', 'w') as f:
        f.write('\n'.join(out) + '\n')
    print('frames', len(FRAMES), 'sprite bytes', total, file=sys.stderr)
    # preview sheet
    if len(sys.argv) > 2:
        sys.path.insert(0, '/tmp/claude-0')
        import prev
        inv = {v: k for k, v in PIX.items()}
        arts = [[''.join(inv[v] for v in row) for row in px] for _, px in FRAMES]
        prev.sheet(arts, sys.argv[2], scale=3, cols=12)


main()
