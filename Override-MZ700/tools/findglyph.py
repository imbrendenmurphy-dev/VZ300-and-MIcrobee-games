"""findglyph.py - search the CG-ROM for box-drawing / triangle glyphs."""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rom = open(os.path.join(ROOT, 'rom', 'mz700fon.int'), 'rb').read()


def bits(g):
    return [[(rom[g * 8 + y] >> x) & 1 for x in range(8)] for y in range(8)]


def box(row, col, l, r, u, d):
    """glyph with a horizontal line on `row` (left part if l, right part if r)
    and a vertical line on `col` (upper part if u, lower part if d)"""
    g = [[0] * 8 for _ in range(8)]
    for x in range(8):
        if (x <= col and l) or (x >= col and r):
            g[row][x] = 1
    for y in range(8):
        if (y <= row and u) or (y >= row and d):
            g[y][col] = 1
    return g


def tri(kind):
    g = [[0] * 8 for _ in range(8)]
    for y in range(8):
        for x in range(8):
            if kind == 'ul':
                g[y][x] = int(x + y <= 7)
            elif kind == 'ur':
                g[y][x] = int(x >= y)
            elif kind == 'll':
                g[y][x] = int(x <= y)
            elif kind == 'lr':
                g[y][x] = int(x + y >= 7)
    return g


def close(a, b, tol):
    return sum(a[y][x] != b[y][x] for y in range(8) for x in range(8)) <= tol


names = {'-': (1, 1, 0, 0), '|': (0, 0, 1, 1), '+': (1, 1, 1, 1), 'T': (1, 1, 0, 1), 'B': (1, 1, 1, 0),
         '-|': (1, 0, 1, 1), '|-': (0, 1, 1, 1), 'TL': (0, 1, 0, 1), 'TR': (1, 0, 0, 1), 'BL': (0, 1, 1, 0), 'BR': (1, 0, 1, 0)}
for row in (3, 4):
    for col in (3, 4):
        found = []
        for nm, (l, r, u, d) in names.items():
            want = box(row, col, l, r, u, d)
            hits = ['%d:%02X' % (g // 256, g % 256) for g in range(512) if close(bits(g), want, 0)]
            found.append('%s=%s' % (nm, ','.join(hits) or '-'))
        print('row', row, 'col', col, ' '.join(found))
for k in ('ul', 'ur', 'll', 'lr'):
    want = tri(k)
    hits = ['%d:%02X' % (g // 256, g % 256) for g in range(512) if close(bits(g), want, 4)]
    print('tri', k, hits)
