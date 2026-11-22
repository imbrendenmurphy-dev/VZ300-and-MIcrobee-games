"""Compose a view the way the Z80 will (near-to-far slot fill, backdrop,
then sprites) and save it as a PNG. Used to judge the art without the
emulator, and as the reference the emulator's screens are checked against."""
import numpy as np
from PIL import Image
import views as V
import walls as W

PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
       (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]


def compose(theme, grid, cache):
    """grid(dx, dz) -> None or wall kind ('A','B','D','G','V')"""
    cells = {}
    filled = [None] * V.VW
    for s in V.SLOTS:
        k = grid(s.dx, s.dz)
        if not k:
            continue
        key = (s.name(), k)
        if key not in cache:
            cache[key] = W.face_cells(s, theme, k)
        fc = cache[key]
        for c in range(s.c0, s.c1):
            if filled[c] is not None:
                continue
            filled[c] = s
            for (cc, r), v in fc.items():
                if cc == c:
                    cells[(c, r)] = v
    if ('floor',) not in cache:
        cache[('floor',)] = W.floor_cells(theme)
    for (c, r), v in cache[('floor',)].items():
        s = filled[c]
        if s is None or (c, r) not in cells and not covered(cache, s, grid, c, r):
            cells.setdefault((c, r), v)
    return cells


def covered(cache, s, grid, c, r):
    fc = cache[(s.name(), grid(s.dx, s.dz))]
    rows = [rr for (cc, rr) in fc if cc == c]
    return min(rows) <= r <= max(rows)


def image(cells, scale=3):
    img = np.zeros((V.PH, V.PW, 3), np.uint8)
    for (c, r), (pat, col) in cells.items():
        ink = PAL[col & 15]
        for i in range(10):
            for j in range(8):
                if pat[i] >> (7 - j) & 1:
                    img[r * 10 + i, c * 8 + j] = ink
    im = Image.fromarray(img)
    return im.resize((V.PW * scale, int(V.PH * scale * 0.75)), Image.NEAREST)


MAP = [
    "#########",
    "#...#...#",
    "#.#.D.#.#",
    "#.#...#.#",
    "#...B...#",
    "#.#.#.#.#",
    "#.......#",
    "#########",
]


def grid_from(m, x, y, d):
    # d: 0 north (-y), 1 east, 2 south, 3 west
    fx, fy = [(0, -1), (1, 0), (0, 1), (-1, 0)][d]
    rx, ry = -fy, fx

    def g(dx, dz):
        mx, my = x + fx * dz + rx * dx, y + fy * dz + ry * dx
        if 0 <= my < len(m) and 0 <= mx < len(m[0]):
            ch = m[my][mx]
            return {'#': 'A', 'B': 'B', 'D': 'D', 'G': 'G', 'V': 'V'}.get(ch)
        return 'A'
    return g


if __name__ == '__main__':
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else 'prev'
    for ti, th in enumerate(W.THEMES):
        cache = {}
        for n, (x, y, d) in enumerate([(4, 6, 0), (1, 6, 0), (7, 6, 0), (4, 4, 0)]):
            cells = compose(th, grid_from(MAP, x, y, d), cache)
            image(cells).save('%s_%s_%d.png' % (out, th.name, n))
        print(th.name, 'ok')
