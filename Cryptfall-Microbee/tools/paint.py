"""Painting crypts (VIBED BY BPM 2026).

The crypts of CRYPTFALL are designed in tools/crypts.py with the brushes
here and written out as the text files in caves/, which is what the cave
compiler reads.  A crypt is painted from the tile set in tools/tiles.py:
four earths, three walls, three blocks, two steels, three heavy things,
three jewels, the haunters and the charms.

The contraptions (a bat cage, a keg over a vault, a hopper over the
grate...) also write down how they are worked, so that tools/tune.py can
play every crypt in the model, set its quota and clock from what can
really be done, and keep the solution for the tests.
"""
import os
import random
import zlib

DIRT = '.,:;'
SOFT = ' ' + DIRT


class Cave:
    def __init__(s, name, w, h, hint, fill='.', theme='', frac=0.75, **kw):
        assert 25 <= w <= 64 and 15 <= h <= 32, (name, w, h)
        s.name, s.w, s.h, s.hint, s.theme, s.frac = name, w, h, hint, theme, frac
        s.g = [[fill] * w for _ in range(h)]
        for x in range(w):
            s.g[0][x] = s.g[h - 1][x] = '#'
        for y in range(h):
            s.g[y][0] = s.g[y][w - 1] = '#'
        s.kw = dict(gem=(10, 20), magic=25, slow=40, slmax=80, bonus=0)
        s.kw.update(kw)
        s.script = []
        s.r = random.Random(zlib.crc32(name.encode()))

    # ---- cells
    def ok(s, x, y):
        return 0 < x < s.w - 1 and 0 < y < s.h - 1

    def get(s, x, y):
        return s.g[y][x] if 0 <= x < s.w and 0 <= y < s.h else '#'

    def put(s, x, y, ch, on=None):
        if s.ok(x, y) and (on is None or s.g[y][x] in on):
            s.g[y][x] = ch

    def fill(s, x0, y0, x1, y1, ch, on=None):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                s.put(x, y, ch, on)

    def box(s, x0, y0, x1, y1, ch, on=None):
        for x in range(x0, x1 + 1):
            s.put(x, y0, ch, on)
            s.put(x, y1, ch, on)
        for y in range(y0, y1 + 1):
            s.put(x0, y, ch, on)
            s.put(x1, y, ch, on)

    def hl(s, x0, x1, y, ch, on=None):
        s.fill(x0, y, x1, y, ch, on)

    def vl(s, x, y0, y1, ch, on=None):
        s.fill(x, y0, x, y1, ch, on)

    def rows(s, x, y, rows, skip='~'):
        """stamp a little picture; ~ leaves the cave as it is"""
        for j, r in enumerate(rows):
            for i, ch in enumerate(r):
                if ch != skip:
                    s.put(x + i, y + j, ch)

    def ellipse(s, cx, cy, rx, ry, ch, on=None, ring=False):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1 and (not ring or d > (1 - 1.2 / min(rx, ry)) ** 2):
                    s.put(x, y, ch, on)

    def cells(s, x0=1, y0=1, x1=None, y1=None, on=None):
        x1 = s.w - 2 if x1 is None else x1
        y1 = s.h - 2 if y1 is None else y1
        return [(x, y) for y in range(max(1, y0), min(s.h - 2, y1) + 1) for x in range(max(1, x0), min(s.w - 2, x1) + 1)
                if on is None or s.g[y][x] in on]

    def scatter(s, ch, n, x0=1, y0=1, x1=None, y1=None, on=DIRT, free_above=False):
        """n of ch on random cells (n < 1: that share of them)"""
        c = s.cells(x0, y0, x1, y1, on)
        if n < 1:
            n = int(len(c) * n + 0.5)
        out = []
        for x, y in s.r.sample(c, min(int(n), len(c))):
            if free_above and s.get(x, y - 1) in 'oqTu*re':
                continue
            s.g[y][x] = ch
            out.append((x, y))
        return out

    def mix(s, x0, y0, x1, y1, table, on=None):
        """every cell at random from a table like {'.': 70, 'o': 10, '*': 6}"""
        ks, ws = list(table), list(table.values())
        for x, y in s.cells(x0, y0, x1, y1, on):
            s.g[y][x] = s.r.choices(ks, ws)[0]

    def strata(s, bands, x0=1, y0=1, x1=None, y1=None, on='.', wobble=2):
        """bands of different earth across the cave: bands = '.,:;' top to bottom"""
        x1 = s.w - 2 if x1 is None else x1
        y1 = s.h - 2 if y1 is None else y1
        n = len(bands)
        off = [s.r.uniform(-wobble, wobble) for _ in range(s.w)]
        for i in range(1, s.w):
            off[i] = (off[i - 1] * 2 + off[i]) / 3
        for x, y in s.cells(x0, y0, x1, y1, on):
            k = int((y - y0 + off[x]) * n / (y1 - y0 + 1))
            s.g[y][x] = bands[max(0, min(n - 1, k))]

    def cavern(s, x0, y0, x1, y1, p=0.42, it=3, ch=' ', on=DIRT):
        """natural hollows"""
        cs = s.cells(x0, y0, x1, y1)
        a = {c: s.r.random() < p for c in cs}
        for _ in range(it):
            b = {}
            for (x, y) in cs:
                n = sum(a.get((x + i, y + j), False) for i in (-1, 0, 1) for j in (-1, 0, 1))
                b[(x, y)] = n >= 5
            a = b
        for (x, y), v in a.items():
            if v:
                s.put(x, y, ch, on)

    def maze(s, x0, y0, nx, ny, cw=2, chh=2, wall='W', path=' ', loops=0.1):
        """a maze of nx x ny cells, each cw x chh inside, walls one thick.
        -> the list of dead ends (cell centres)"""
        pw, ph = cw + 1, chh + 1
        s.fill(x0, y0, x0 + nx * pw, y0 + ny * ph, wall)
        seen = {(0, 0)}
        stack = [(0, 0)]
        deg = {}

        def room(i, j):
            s.fill(x0 + 1 + i * pw, y0 + 1 + j * ph, x0 + i * pw + cw, y0 + j * ph + chh, path)

        def open_(i, j, di, dj):
            deg[(i, j)] = deg.get((i, j), 0) + 1
            deg[(i + di, j + dj)] = deg.get((i + di, j + dj), 0) + 1
            if di:
                x = x0 + (i + (di > 0)) * pw
                s.fill(x, y0 + 1 + j * ph, x, y0 + j * ph + chh, path)
            else:
                y = y0 + (j + (dj > 0)) * ph
                s.fill(x0 + 1 + i * pw, y, x0 + i * pw + cw, y, path)
        room(0, 0)
        while stack:
            i, j = stack[-1]
            nb = [(di, dj) for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if 0 <= i + di < nx and 0 <= j + dj < ny and (i + di, j + dj) not in seen]
            if not nb:
                stack.pop()
                continue
            di, dj = s.r.choice(nb)
            open_(i, j, di, dj)
            room(i + di, j + dj)
            seen.add((i + di, j + dj))
            stack.append((i + di, j + dj))
        for i in range(nx - 1):
            for j in range(ny - 1):
                if s.r.random() < loops:
                    open_(i, j, *s.r.choice(((1, 0), (0, 1))))
        return [(x0 + 1 + i * pw, y0 + 1 + j * ph) for (i, j), d in deg.items() if d == 1 and (i, j) != (0, 0)]

    # ---- the way in and the gate
    def start(s, x, y, clear=1):
        for j in range(-clear, clear + 1):
            for i in range(-clear, clear + 1):
                if s.get(x + i, y + j) not in DIRT + '#%WVABNH':
                    s.put(x + i, y + j, '.')
        s.put(x, y - 2, '.', 'oqTu*re')
        s.g[y][x] = 'P'
        s.px, s.py = x, y

    def gate(s, x, y):
        """x, y on the border"""
        s.g[y][x] = 'X'
        ix = min(max(x, 1), s.w - 2)
        iy = min(max(y, 1), s.h - 2)
        if s.g[iy][ix] not in SOFT:
            s.g[iy][ix] = '.'
        if s.get(ix, iy - 1) in 'oqTu*re':
            s.g[iy - 1][ix] = '.'

    # ---- contraptions.  Each leaves a note of how it is worked.
    def do(s, text):
        s.script.append('[' + text + ']')

    def drop(s, x, y, thing='o', side=-1, wait=8, earth='.'):
        """thing held up at x,y by a plug of earth under it; Mort stands
        beside the plug (side -1 left, 1 right), reaches it out, steps back"""
        s.put(x, y, thing)
        s.put(x, y + 1, earth)
        for i in (1, 2):
            for j in (0, 1):
                if s.get(x + side * i, y + j) not in DIRT:
                    s.put(x + side * i, y + j, earth)
        s.calm(x + side, y - 3, x + side * 3, y + 1)
        s.do('~%d,%d %s %s w%d' % (x + side, y + 1, 'r' if side < 0 else 'l', 'L' if side < 0 else 'R', wait))

    def calm(s, x0, y0, x1, y1):
        """no loose heavy things over where Mort will stand"""
        for x in range(min(x0, x1), max(x0, x1) + 1):
            for y in range(min(y0, y1), max(y0, y1) + 1):
                if s.get(x, y) in 'oqTu':
                    s.put(x, y, '.')

    def shaft(s, x, y, things, wall='W', wait=30):
        """a walled shaft of things standing on a plug of earth at x,y,
        over whatever is below (a grate, usually); Mort reaches the plug
        out from the left"""
        n = len(things)
        s.vl(x - 1, y - n - 1, y - 1, wall)
        s.vl(x + 1, y - n - 1, y - 1, wall)
        for i, ch in enumerate(things):
            s.put(x, y - n + i, ch)
        s.put(x, y, '.')
        s.put(x - 1, y, '.')
        s.put(x - 2, y, '.')
        s.put(x - 2, y - 1, '.', 'oqTu*re')
        s.calm(x - 4, y - 3, x - 1, y)
        s.do('~%d,%d r L w%d' % (x - 1, y, wait))

    def bat_cage(s, x, y, wall='W', side=-1, what='b', earth='.'):
        """x,y = the stone; 5 rows: stone, plug, gap, the bat in its cage, floor"""
        s.rows(x - 1, y + 2, [wall + ' ' + wall, wall + what + wall, wall * 3])
        s.drop(x, y, 'o', side, 9, earth)

    def push(s, x, y, d=1, wait=8):
        """Mort at x,y shoves what is beside him (two steps of leaning)"""
        m = 'R' if d > 0 else 'L'
        s.do('~%d,%d %s %s w%d' % (x, y, m, m, wait))

    # ---- out
    def text(s, quota=1, time=200, solve=None):
        L = ['name: ' + s.name, 'hint: ' + s.hint, 'quota: %d' % quota, 'time: %d' % time,
             'gem: %d %d' % s.kw['gem'], 'magic: %d' % s.kw['magic'], 'slow: %d' % s.kw['slow'],
             'slmax: %d' % s.kw['slmax'], 'bonus: %d' % s.kw['bonus']]
        if s.theme:
            L.append('theme: ' + s.theme)
        if solve:
            L.append('; solve: ' + solve)
        L.append('map:')
        L += [''.join(r) for r in s.g]
        return '\n'.join(L) + '\n'

    def solve_script(s):
        return ' '.join(s.script + ['!', 'X'])
