"""OVERRIDE ships for the MZ-700: deck generator, waypoint graphs, droid placement.

A ship is a stack of decks (side view, deck 0 at the top).  Lift shafts run
through several decks at a fixed ship x.  Each deck is generated from a seed:
a hull with tapered ends, a four-row spine corridor, rooms above and below it
with sliding doors, consoles, energizers, props and the lift pads.

One map cell is one character.  A droid covers 3 x 2 cells; positions are
the droid's top-left cell.
"""
import random
from collections import deque

import roster

FW, FH = 3, 2            # droid footprint
MAXWPT = 96
MAXDROIDS = 14
MX0, MY0 = 24, 13        # deck origin inside the 128-wide map buffer
MAXW, MAXH = 80, 30


def walkable(k):
    return k in ('F', 'M') or k[0] in 'LED'


def fits(K, x, y):
    H = len(K)
    W = len(K[0])
    if x < 0 or y < 0 or x + FW > W or y + FH > H:
        return False
    for j in range(FH):
        for i in range(FW):
            if not walkable(K[y + j][x + i]):
                return False
    return True


def step_path(a, b):
    """the cells a droid visits going from a to b: diagonal steps first"""
    (x, y), (tx, ty) = a, b
    out = [(x, y)]
    while (x, y) != (tx, ty):
        x += (tx > x) - (tx < x)
        y += (ty > y) - (ty < y)
        out.append((x, y))
    return out


def step_clear(K, a, b):
    return all(fits(K, x, y) for x, y in step_path(a, b)) and all(fits(K, x, y) for x, y in step_path(b, a))


def positions(K):
    H = len(K)
    W = len(K[0])
    return {(x, y) for y in range(H) for x in range(W) if fits(K, x, y)}


def connected(K):
    ok = positions(K)
    if not ok:
        return True
    start = next(iter(ok))
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in ok and n not in seen:
                seen.add(n)
                q.append(n)
    return len(seen) == len(ok)


def bfs_path(K, a, b, ok=None):
    ok = ok or positions(K)
    prev = {a: None}
    q = deque([a])
    while q:
        p = q.popleft()
        if p == b:
            break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            n = (p[0] + dx, p[1] + dy)
            if n not in prev and n in ok:
                if dx and dy and not ((p[0] + dx, p[1]) in ok and (p[0], p[1] + dy) in ok):
                    continue
                prev[n] = p
                q.append(n)
    if b not in prev:
        return None
    path = []
    p = b
    while p is not None:
        path.append(p)
        p = prev[p]
    return path[::-1]


class Deck:
    pass


def gen_deck(name, W, H, seed, lift_xs, n_con=1, n_ener=1, droids=()):
    rng = random.Random(seed)
    K = [['V'] * W for _ in range(H)]
    taper = 3

    def span(y):
        d = min(y - 1, H - 2 - y)
        inset = max(0, taper - d) * 2
        return 1 + inset, W - 2 - inset

    for y in range(1, H - 1):
        a, b = span(y)
        for x in range(a, b + 1):
            K[y][x] = 'W' if (y in (1, H - 2) or x in (a, b)) else 'F'
    for y in range(1, H - 1):             # close the stepped taper
        a, b = span(y)
        for yy in (y - 1, y + 1):
            if 1 <= yy < H - 1:
                a2, b2 = span(yy)
                for x in range(min(a, a2), max(a, a2) + 1):
                    if K[y][x] == 'F':
                        K[y][x] = 'W'
                for x in range(min(b, b2), max(b, b2) + 1):
                    if K[y][x] == 'F':
                        K[y][x] = 'W'
    sy0 = H // 2 - 2                       # spine rows sy0..sy0+3
    top_wall, bot_wall = sy0 - 1, sy0 + 4
    ax, bx = span(sy0)
    for x in range(ax + 1, bx):
        K[top_wall][x] = 'W'
        K[bot_wall][x] = 'W'
    rooms = []
    for side in ('top', 'bot'):
        if side == 'top':
            ry0, ry1 = 2, top_wall - 1
        else:
            ry0, ry1 = bot_wall + 1, H - 3
        if ry1 - ry0 + 1 < FH + 1:
            continue
        xs = []
        x = ax + 1
        while True:
            wdt = rng.randint(9, 16)
            if x + wdt >= bx - 6:
                xs.append(bx)
                break
            xs.append(x + wdt)
            x = x + wdt + 1
        x0 = ax + 1
        prev = None
        for xe in xs:
            if xe < bx:
                for y in range(ry0, ry1 + 1):
                    if K[y][xe] == 'F':
                        K[y][xe] = 'W'
            cells = [(x, y) for y in range(ry0, ry1 + 1) for x in range(x0, xe) if K[y][x] == 'F']
            if len(cells) >= 12:
                r = dict(side=side, x0=x0, x1=xe - 1, y0=ry0, y1=ry1, cells=cells, door=None)
                rooms.append(r)
                wy = top_wall if side == 'top' else bot_wall
                iny = wy - 1 if side == 'top' else wy + 1
                cand = [x for x in range(x0, xe - 2)
                        if all(K[iny][x + i] == 'F' and K[wy][x + i] == 'W' for i in range(3))
                        and K[iny + (-1 if side == 'top' else 1)][x] == 'F']
                if cand:
                    lo, hi = len(cand) // 4, max(len(cand) // 4 + 1, 3 * len(cand) // 4)
                    dx = rng.choice(cand[lo:hi])
                    for i in range(3):
                        K[wy][dx + i] = 'DH%d' % i
                    r['door'] = (dx, wy)
                if prev is not None:
                    wxx = x0 - 1
                    cand = [y for y in range(ry0, ry1)
                            if all(K[y + j][wxx] == 'W' and K[y + j][wxx - 1] == 'F' and K[y + j][wxx + 1] == 'F'
                                   for j in range(2))]
                    if cand and rng.random() < 0.6:
                        dy = rng.choice(cand)
                        K[dy][wxx] = 'DV0'
                        K[dy + 1][wxx] = 'DV1'
                        r['sidedoor'] = (wxx, dy, prev)
                prev = r
            x0 = xe + 1
    # sealed rooms become hull
    for r in rooms:
        if r['door'] is None and 'sidedoor' not in r:
            for (x, y) in r['cells']:
                K[y][x] = 'W'
    rooms = [r for r in rooms if r['door'] is not None or 'sidedoor' in r]
    # anything a droid can't reach from the spine becomes wall
    ok = positions(K)
    start = ((ax + bx) // 2, sy0 + 1)
    assert start in ok, name
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in ok and n not in seen:
                seen.add(n)
                q.append(n)
    cov = set()
    for (x, y) in seen:
        for j in range(FH):
            for i in range(FW):
                cov.add((x + i, y + j))
    for y in range(H):
        for x in range(W):
            if walkable(K[y][x]) and (x, y) not in cov:
                K[y][x] = 'W'
    rooms = [r for r in rooms if any(c in cov for c in r['cells'])]
    for r in rooms:
        r['cells'] = [c for c in r['cells'] if c in cov]
    # lift pads in the middle of the spine
    lifts = []
    for lx in lift_xs:
        lx = max(ax + 2, min(bx - 4, lx))
        for j in range(2):
            for i in range(3):
                K[sy0 + 1 + j][lx + i] = 'L%d' % (j * 3 + i)
        lifts.append((lx, sy0 + 1))
    reserved = set()
    for (lx, ly) in lifts:
        for j in range(-2, 4):
            for i in range(-2, 5):
                reserved.add((lx + i, ly + j))
    for r in rooms:
        if r['door']:
            dx, wy = r['door']
            for j in range(-3, 4):
                for i in range(-1, 4):
                    reserved.add((dx + i, wy + j))
        if 'sidedoor' in r:
            wxx, dy, _ = r['sidedoor']
            for j in range(-1, 3):
                for i in range(-4, 5):
                    reserved.add((wxx + i, dy + j))
    order = rooms[:]
    rng.shuffle(order)
    consoles = []
    for r in order:
        if len(consoles) >= n_con:
            break
        by = r['y0'] if r['side'] == 'top' else r['y1']
        cand = [x for x in range(r['x0'], r['x1'])
                if K[by][x] == 'F' and K[by][x + 1] == 'F' and (x, by) not in reserved and (x + 1, by) not in reserved]
        rng.shuffle(cand)
        for cx in cand:
            K[by][cx] = 'C0'
            K[by][cx + 1] = 'C1'
            if connected(K):
                consoles.append((cx, by))
                r['console'] = True
                for i in range(-1, 3):
                    for j in (-2, -1, 0, 1, 2):
                        reserved.add((cx + i, by + j))
                break
            K[by][cx] = 'F'
            K[by][cx + 1] = 'F'
    eners = []
    for r in order:
        if len(eners) >= n_ener:
            break
        if r.get('console'):
            continue
        cand = [(x, y) for y in range(r['y0'], r['y1']) for x in range(r['x0'], r['x1'] - 1)
                if all(K[y + j][x + i] == 'F' and (x + i, y + j) not in reserved for i in range(3) for j in range(2))]
        if cand:
            ex, ey = rng.choice(cand)
            for j in range(2):
                for i in range(3):
                    K[ey + j][ex + i] = 'E%d' % (j * 3 + i)
            eners.append((ex, ey))
            r['ener'] = True
            for i in range(-1, 4):
                for j in range(-1, 3):
                    reserved.add((ex + i, ey + j))
    assert len(eners) >= 1, name
    props = ['CRATE', 'CRATE', 'BARREL', 'BANK', 'BANK', 'REACT']
    for r in rooms:
        n = rng.randint(2, 5)
        for _ in range(n * 4):
            if n <= 0:
                break
            x = rng.randint(r['x0'], r['x1'])
            y = rng.randint(r['y0'], r['y1'])
            if K[y][x] != 'F' or (x, y) in reserved:
                continue
            if not any(K[y + dy][x + dx] == 'W' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                continue
            K[y][x] = 'P' + rng.choice(props)
            if not connected(K):
                K[y][x] = 'F'
            else:
                n -= 1
    for y in range(H):
        for x in range(W):
            if K[y][x] == 'F' and x % 4 == 2 and y % 3 == 1:
                K[y][x] = 'M'
    d = Deck()
    d.name, d.W, d.H, d.K = name, W, H, K
    d.rooms, d.lifts, d.consoles, d.eners = rooms, lifts, consoles, eners
    d.sy0, d.ax, d.bx = sy0, ax, bx
    d.doors = [('H', r['door'][0], r['door'][1]) for r in rooms if r['door']]
    d.doors += [('V', r['sidedoor'][0], r['sidedoor'][1]) for r in rooms if 'sidedoor' in r]
    d.tiles = autotile(K, rng)
    build_waypoints(d)
    place_droids(d, droids, rng)
    assert connected(K), name
    assert W <= MAXW and H <= MAXH
    return d


def autotile(K, rng):
    H = len(K)
    W = len(K[0])
    T = [[None] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            k = K[y][x]
            if k == 'V':
                r = rng.random()
                T[y][x] = 'STAR1' if r < 0.025 else 'STAR2' if r < 0.07 else 'VOID'
            elif k == 'W':
                below = K[y + 1][x] if y + 1 < H else 'V'
                T[y][x] = 'FACE' if (walkable(below) or below[0] in 'PC') and not below.startswith('D') else 'WALL'
            elif k == 'F':
                T[y][x] = 'FLOOR'
            elif k == 'M':
                T[y][x] = 'MARK'
            elif k.startswith('DH'):
                T[y][x] = 'DH0'
            elif k.startswith('DV'):
                T[y][x] = 'DV0'
            elif k[0] == 'L':
                T[y][x] = 'LIFT' + k[1]
            elif k[0] == 'E':
                T[y][x] = 'ENER0'
            elif k[0] == 'C':
                T[y][x] = 'CON' + k[1]
            elif k[0] == 'P':
                T[y][x] = k[1:]
            else:
                raise ValueError(k)
    return T


def build_waypoints(d):
    K = d.K
    ok = positions(K)
    nodes = []
    edges = set()

    def add(x, y):
        assert (x, y) in ok, (d.name, x, y)
        if (x, y) in nodes:
            return nodes.index((x, y))
        nodes.append((x, y))
        return len(nodes) - 1

    sy = d.sy0 + 1
    xs = set(range(d.ax + 3, d.bx - 4, 10))
    for r in d.rooms:
        if r['door']:
            xs.add(r['door'][0])
    for (lx, ly) in d.lifts:
        xs.add(lx)
    xs = sorted(x for x in xs if (x, sy) in ok)
    spine = {x: add(x, sy) for x in xs}
    for a, b in zip(xs, xs[1:]):
        edges.add((spine[a], spine[b]))
    for r in d.rooms:
        fit = [(x, y) for (x, y) in ok if r['x0'] <= x and x + FW - 1 <= r['x1'] and r['y0'] <= y and y + FH - 1 <= r['y1']]
        if not fit:
            continue
        cx = (r['x0'] + r['x1']) / 2 - 1
        cy = (r['y0'] + r['y1']) / 2 - 0.5
        c = min(fit, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
        ci = add(*c)
        r['node'] = ci
        if r['door']:
            dx, wy = r['door']
            iy = wy - FH if r['side'] == 'top' else wy + 1
            di = add(dx, iy)
            if di != ci:
                edges.add((ci, di))
            edges.add((di, spine[dx]))
        if len(fit) > 50:
            far = [(r['x0'], r['y0']), (r['x1'] - 2, r['y1'] - 1)]
            if r['side'] == 'bot':
                far = [(r['x0'], r['y1'] - 1), (r['x1'] - 2, r['y0'])]
            for corner in far:
                cc = min(fit, key=lambda p: (p[0] - corner[0]) ** 2 + (p[1] - corner[1]) ** 2)
                if abs(cc[0] - c[0]) + abs(cc[1] - c[1]) >= 5 and step_clear(K, c, cc):
                    edges.add((ci, add(*cc)))
    for r in d.rooms:
        if 'sidedoor' in r and 'node' in r and 'node' in r['sidedoor'][2]:
            wxx, dy, prev = r['sidedoor']
            if (wxx + 1, dy) not in ok or (wxx - FW, dy) not in ok:
                continue
            a = add(wxx + 1, dy)
            b = add(wxx - FW, dy)
            edges.add((r['node'], a))
            edges.add((a, b))
            edges.add((b, prev['node']))
    # route edges that are not clear step paths through extra nodes
    for a, b in list(edges):
        if step_clear(K, nodes[a], nodes[b]):
            continue
        edges.discard((a, b))
        path = bfs_path(K, nodes[a], nodes[b], ok)
        assert path, (d.name, nodes[a], nodes[b])
        cur = a
        k = 0
        while nodes[cur] != nodes[b]:
            j = len(path) - 1
            while not step_clear(K, nodes[cur], path[j]):
                j -= 1
            assert j > k, (d.name, 'stuck')
            nxt = b if path[j] == nodes[b] else add(*path[j])
            edges.add((cur, nxt))
            cur = nxt
            k = j
    adj = [[] for _ in nodes]
    for a, b in edges:
        if a == b:
            continue
        if b not in adj[a]:
            adj[a].append(b)
        if a not in adj[b]:
            adj[b].append(a)
    for i, l in enumerate(adj):
        assert 1 <= len(l) <= 7, (d.name, i, l)
        for j in l:
            assert step_clear(K, nodes[i], nodes[j]) and step_clear(K, nodes[j], nodes[i]), (d.name, nodes[i], nodes[j])
    # graph connected
    seen = {0}
    q = deque([0])
    while q:
        i = q.popleft()
        for j in adj[i]:
            if j not in seen:
                seen.add(j)
                q.append(j)
    assert len(seen) == len(nodes), (d.name, 'graph not connected')
    assert len(nodes) <= MAXWPT, (d.name, len(nodes))
    d.nodes, d.adj = nodes, adj


def place_droids(d, droids, rng):
    spots = [r['node'] for r in d.rooms if 'node' in r]
    rng.shuffle(spots)
    others = [i for i in range(len(d.nodes)) if i not in spots]
    rng.shuffle(others)

    def near_lift(i):
        x, y = d.nodes[i]
        return any(abs(x - lx) < 18 and abs(y - ly) < 8 for lx, ly in d.lifts)

    pool = [i for i in spots + others if not near_lift(i)] + [i for i in spots + others if near_lift(i)]
    out = []
    used = set()
    for num in droids:
        for i in pool:
            if i not in used:
                used.add(i)
                out.append((roster.TYPE_OF[num], i))
                break
    assert len(out) == len(droids) <= MAXDROIDS, d.name
    d.droids = out


# ---------------------------------------------------------------- ships
# side view: off = deck's x offset in the ship (cells)
SHIPS = [
    dict(name='SV CORMORANT', seed=1101, decks=[
        dict(name='BRIDGE', w=46, h=22, off=18, droids=[104, 152, 218]),
        dict(name='QUARTERS', w=64, h=24, off=8, droids=[104, 152, 218, 263]),
        dict(name='GALLEY', w=72, h=24, off=4, droids=[104, 218, 307, 355]),
        dict(name='CARGO HOLD', w=78, h=26, off=1, droids=[307, 104, 263, 355, 408]),
        dict(name='MACHINE SHOP', w=68, h=24, off=6, droids=[263, 355, 307, 461]),
        dict(name='ENGINES', w=52, h=22, off=14, droids=[263, 408, 461]),
    ], shafts=[24, 40, 58]),
    dict(name='MV HALCYON', seed=2202, decks=[
        dict(name='OBSERVATORY', w=40, h=22, off=20, droids=[355, 461]),
        dict(name='BRIDGE', w=56, h=24, off=12, droids=[218, 461, 524]),
        dict(name='SICKBAY', w=68, h=24, off=6, droids=[408, 218, 152, 524]),
        dict(name='LABS', w=78, h=26, off=1, droids=[355, 461, 524, 587, 408]),
        dict(name='BRIG', w=74, h=24, off=3, droids=[587, 461, 632, 307]),
        dict(name='STORES', w=64, h=24, off=8, droids=[307, 668, 263, 355]),
        dict(name='REACTOR', w=46, h=22, off=17, droids=[632, 408, 668]),
    ], shafts=[26, 40, 56]),
    dict(name='CV LEVIATHAN', seed=3303, decks=[
        dict(name='COMMAND', w=42, h=22, off=20, droids=[908, 632]),
        dict(name='ARMOURY', w=60, h=24, off=11, droids=[705, 632, 587, 461]),
        dict(name='BARRACKS', w=72, h=24, off=5, droids=[705, 773, 524, 218, 461]),
        dict(name='HANGAR', w=80, h=28, off=1, droids=[856, 773, 668, 307, 152, 524]),
        dict(name='FOUNDRY', w=74, h=26, off=4, droids=[817, 668, 587, 263, 461]),
        dict(name='CORE', w=60, h=24, off=11, droids=[960, 908, 773]),
    ], shafts=[28, 44, 60]),
]


def make_ship(spec):
    decks = []
    shafts = spec['shafts']
    for i, ds in enumerate(spec['decks']):
        lx = []
        for sx in shafts:
            tx = sx - ds['off']
            if 6 <= tx <= ds['w'] - 9:
                lx.append(tx)
        assert lx, ds['name']
        d = gen_deck(ds['name'], ds['w'], ds['h'], spec['seed'] * 31 + i, lx, 1, 2 if ds['w'] >= 70 else 1, ds['droids'])
        d.off = ds['off']
        d.shaft_of = []
        for (tx, ty) in d.lifts:
            s = min(range(len(shafts)), key=lambda k: abs(shafts[k] - (tx + ds['off'])))
            d.shaft_of.append(s)
        decks.append(d)
    # every shaft must connect at least two decks
    for s in range(len(shafts)):
        n = sum(1 for d in decks if s in d.shaft_of)
        assert n >= 2, (spec['name'], 'shaft', s)
    # the whole ship must be reachable through the lifts
    seen = {0}
    q = [0]
    while q:
        i = q.pop()
        for s in decks[i].shaft_of:
            for j, d in enumerate(decks):
                if s in d.shaft_of and j not in seen:
                    seen.add(j)
                    q.append(j)
    assert len(seen) == len(decks), spec['name']
    return decks


def deck_preview(d, path):
    import codes
    from mzfont import render_cells
    chars, attrs = [], []
    for y in range(d.H):
        for x in range(d.W):
            c = codes.codes[codes.index[d.tiles[y][x]]]
            chars.append(c.char)
            attrs.append(c.attr)
    # droids
    for t, n in d.droids:
        x, y = d.nodes[n]
        num = roster.ROSTER[t][0]
        bi = codes.body_index(num)
        cells = [('DL%d' % bi, 0, 0), ('EYE%d_0' % bi, 1, 0), ('DR%d' % bi, 2, 0)]
        for k, ch in enumerate('%03d' % num):
            cells.append(('DG%d_%s' % (bi, ch), k, 1))
        for nm, i, j in cells:
            c = codes.codes[codes.index[nm]]
            chars[(y + j) * d.W + x + i] = c.char
            attrs[(y + j) * d.W + x + i] = c.attr
    im = render_cells(chars, attrs, cols=d.W, rows=d.H, scale=2)
    from PIL import ImageDraw
    dr = ImageDraw.Draw(im)
    for i, (x, y) in enumerate(d.nodes):
        px, py = x * 16 + 24, y * 16 + 16
        for j in d.adj[i]:
            qx, qy = d.nodes[j][0] * 16 + 24, d.nodes[j][1] * 16 + 16
            dr.line((px, py, qx, qy), fill=(255, 128, 0))
    im.save(path)


if __name__ == '__main__':
    import sys
    import os
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'build')
    for si, spec in enumerate(SHIPS):
        decks = make_ship(spec)
        for di, d in enumerate(decks):
            if len(sys.argv) < 2 or sys.argv[1] == 'png':
                deck_preview(d, os.path.join(out, 'deck_%d_%d.png' % (si + 1, di)))
            print(spec['name'], d.name, d.W, d.H, 'nodes', len(d.nodes), 'rooms', len(d.rooms),
                  'lifts', d.lifts, 'doors', len(d.doors))
