"""OVERRIDE ships: deck generator, waypoint graphs, droid placement, ship file packing.

A ship is a stack of decks (side view, deck 0 at the top). Lift shafts run up and
down through several decks at a fixed ship x. Every deck is generated from a seed:
a hull with tapered ends, a two-tile-wide spine corridor, rooms above and below it
with sliding doors, props, consoles, energizers and the lift pads on the spine.
"""
import random
from collections import deque
import gfx
from gfx import (T_VOID, T_FLOOR, T_GRATE, T_HAZ, T_WALL, T_DHT, T_DHB, T_DVL, T_DVR, T_LIFT,
                 T_ENER, T_CONL, T_CRATE, T_BARREL, T_BANKA, T_BANKB, T_PIPE, T_REACT,
                 A_SOLID, attr)
import roster

MAXWPT = 80
MAXDROIDS = 16


class Deck:
    pass


def gen_deck(name, W, H, seed, lift_xs, n_con=1, n_ener=1, droids=(), style='rooms'):
    rng = random.Random(seed)
    K = [['V'] * W for _ in range(H)]          # V void, W wall, F floor, plus specials
    # hull outline: rows 0 and H-1 are void, walls at the hull edge, tapered ends
    taper = min(4, (H - 4) // 3)
    def span(y):
        d = min(y - 1, H - 2 - y)                # distance from top/bottom hull row
        inset = max(0, taper - d)
        return 1 + inset, W - 2 - inset
    for y in range(1, H - 1):
        a, b = span(y)
        for x in range(a, b + 1):
            K[y][x] = 'W' if (y in (1, H - 2) or x in (a, b)) else 'F'
    # hull corner walls along the taper
    for y in range(1, H - 1):
        a, b = span(y)
        for yy in (y - 1, y + 1):
            if 1 <= yy < H - 1:
                a2, b2 = span(yy)
                for x in range(min(a, a2), max(a, a2) + 1):
                    if K[y][x] == 'F': K[y][x] = 'W'
                for x in range(min(b, b2), max(b, b2) + 1):
                    if K[y][x] == 'F': K[y][x] = 'W'
    sy0 = H // 2 - 1; sy1 = sy0 + 1              # spine rows
    top_wall = sy0 - 1; bot_wall = sy1 + 1
    ax, bx = span(sy0)
    for x in range(ax + 1, bx):
        K[top_wall][x] = 'W'; K[bot_wall][x] = 'W'
    rooms = []
    doors = []
    # style: 'rooms' (the default), 'cells' (rows of small cabins), 'halls'
    # (a few big halls full of machinery), 'bay' (an open bay right across
    # the middle of the deck, the spine walls gone, cargo stacked about)
    wmin, wmax = {'cells': (4, 6), 'halls': (12, 20)}.get(style, (6, 12))
    bay = None
    if style == 'bay':
        bw = (bx - ax) * 2 // 5
        b0 = (ax + bx) // 2 - bw // 2
        bay = (b0, b0 + bw - 1)
    # rooms above and below the spine
    for side in ('top', 'bot'):
        if side == 'top':
            ry0, ry1 = 2, top_wall - 1
        else:
            ry0, ry1 = bot_wall + 1, H - 3
        if ry1 - ry0 + 1 < 3:
            continue
        x = ax + 1
        xs = []
        while True:
            wdt = rng.randint(wmin, wmax)
            if bay and x <= bay[0] - 1 <= x + wdt + 3:
                # end this room at the bay's edge, carry on beyond it
                if bay[0] - 1 - x >= 3:
                    xs.append(bay[0] - 1)
                xs.append(('BAY',))
                x = bay[1] + 2
                continue
            if x + wdt >= bx - 4:
                xs.append(bx); break
            xs.append(x + wdt)
            x = x + wdt + 1
        x0 = ax + 1
        prev = None
        for xe in xs:
            if isinstance(xe, tuple):
                # the bay: open floor; wall off the room beyond it
                for y in range(ry0, ry1 + 1):
                    if K[y][bay[1] + 1] == 'F': K[y][bay[1] + 1] = 'W'
                x0 = bay[1] + 2
                prev = None
                continue
            # room spans x0..xe-1 (walls at xe unless it's the hull)
            if xe < bx:
                for y in range(ry0, ry1 + 1):
                    if K[y][xe] == 'F': K[y][xe] = 'W'
            cells = [(x, y) for y in range(ry0, ry1 + 1) for x in range(x0, xe) if K[y][x] == 'F']
            if len(cells) >= 8:
                r = dict(side=side, x0=x0, x1=xe - 1, y0=ry0, y1=ry1, cells=cells)
                rooms.append(r)
                # door to the spine: two floor tiles wide, both open to the room
                wy = top_wall if side == 'top' else bot_wall
                iny = wy - 1 if side == 'top' else wy + 1
                cand = [x for x in range(x0, xe - 1) if K[iny][x] == 'F' and K[iny][x + 1] == 'F'
                        and K[wy][x] == 'W' and K[wy][x + 1] == 'W'
                        and K[2 * iny - wy][x] == 'F' and K[2 * iny - wy][x + 1] == 'F']
                if cand:
                    dx = rng.choice(cand[len(cand) // 4: max(len(cand) // 4 + 1, 3 * len(cand) // 4)])
                    K[wy][dx] = 'DVL'; K[wy][dx + 1] = 'DVR'
                    doors.append(('V', dx, wy))
                    r['door'] = (dx, wy, iny)
                else:
                    r['door'] = None
                # side door to the previous room
                if prev is not None and ry1 - ry0 + 1 >= 3:
                    wxx = x0 - 1
                    cand = [y for y in range(ry0, ry1) if K[y][wxx] == 'W' and K[y + 1][wxx] == 'W'
                            and K[y][wxx - 1] == 'F' and K[y + 1][wxx - 1] == 'F'
                            and K[y][wxx + 1] == 'F' and K[y + 1][wxx + 1] == 'F'
                            and K[y][wxx + 2] == 'F' and K[y + 1][wxx + 2] == 'F'
                            and K[y][wxx - 2] == 'F' and K[y + 1][wxx - 2] == 'F']
                    if cand and rng.random() < 0.6:
                        dy = rng.choice(cand)
                        K[dy][wxx] = 'DHT'; K[dy + 1][wxx] = 'DHB'
                        doors.append(('H', wxx, dy))
                        r['sidedoor'] = (wxx, dy, prev)
                prev = r
            x0 = xe + 1
    if bay:
        for x in range(bay[0], bay[1] + 1):
            for y in (top_wall, bot_wall):
                if K[y][x] == 'W' and ax < x < bx: K[y][x] = 'F'
    # rooms without a door are sealed: make them part of the hull
    for r in rooms:
        if r['door'] is None and 'sidedoor' not in r:
            for (x, y) in r['cells']:
                K[y][x] = 'W'
    rooms = [r for r in rooms if r['door'] is not None or 'sidedoor' in r]
    # anything a droid can't reach from the spine becomes wall
    reach = reach_from(K, W, H, ((ax + bx) // 2, sy0))
    for y in range(H):
        for x in range(W):
            if walkable(K[y][x]) and (x, y) not in reach:
                K[y][x] = 'W'
    rooms = [r for r in rooms if any(c in reach for c in r['cells'])]
    for r in rooms:
        r['cells'] = [c for c in r['cells'] if c in reach]
        if r['door'] and K[r['door'][1]][r['door'][0]] == 'W': r['door'] = None
        if 'sidedoor' in r and K[r['sidedoor'][1]][r['sidedoor'][0]] == 'W': del r['sidedoor']
    # lifts on the spine
    lifts = []
    for lx in lift_xs:
        lx = max(ax + 2, min(bx - 3, lx))
        for dy in (0, 1):
            for dx in (0, 1):
                K[sy0 + dy][lx + dx] = 'L%d' % (dy * 2 + dx)
        lifts.append((lx, sy0))
    reserved = set()
    for (lx, ly) in lifts:
        for dy in range(-1, 3):
            for dx in range(-1, 3):
                reserved.add((lx + dx, ly + dy))
    # keep door fronts clear
    for r in rooms:
        if r['door']:
            dx, wy, iny = r['door']
            for yy in (iny, iny + (1 if r['side'] == 'bot' else -1)):
                for xx in (dx - 1, dx, dx + 1, dx + 2):
                    reserved.add((xx, yy))
        if 'sidedoor' in r:
            wxx, dy, _ = r['sidedoor']
            for yy in (dy - 1, dy, dy + 1, dy + 2):
                for xx in (wxx - 2, wxx - 1, wxx + 1, wxx + 2):
                    reserved.add((xx, yy))
    # consoles: against the back wall of a room (top rooms: top wall; bottom rooms: bottom wall)
    consoles = []
    order = rooms[:]
    rng.shuffle(order)
    for r in order:
        if len(consoles) >= n_con: break
        by = r['y0'] if r['side'] == 'top' else r['y1']
        cand = [x for x in range(r['x0'], r['x1']) if K[by][x] == 'F' and K[by][x + 1] == 'F'
                and (x, by) not in reserved and (x + 1, by) not in reserved]
        rng.shuffle(cand)
        for cx in cand:
            K[by][cx] = 'C0'; K[by][cx + 1] = 'C1'
            if connected(K, W, H): break
            K[by][cx] = 'F'; K[by][cx + 1] = 'F'
        else:
            cand = []
        if cand:
            consoles.append((cx, by)); r['console'] = True
            for xx in range(cx - 1, cx + 3):
                for yy in (by - 1, by, by + 1):
                    reserved.add((xx, yy))
    # energizers: 2x2 pads inside rooms
    eners = []
    for r in order:
        if len(eners) >= n_ener: break
        if r.get('console'): continue
        cand = [(x, y) for y in range(r['y0'], r['y1']) for x in range(r['x0'], r['x1'])
                if all(K[y + j][x + i] == 'F' and (x + i, y + j) not in reserved for i in (0, 1) for j in (0, 1))]
        if cand:
            ex, ey = rng.choice(cand)
            for j in (0, 1):
                for i in (0, 1):
                    K[ey + j][ex + i] = 'E%d' % (j * 2 + i)
            eners.append((ex, ey)); r['ener'] = True
            for xx in range(ex - 1, ex + 3):
                for yy in range(ey - 1, ey + 3):
                    reserved.add((xx, yy))
    # props along room walls, checked against 2x2 clearance connectivity
    props = [T_CRATE, T_CRATE, T_BARREL, T_BANKA, T_BANKB, T_REACT]
    for r in rooms:
        n = rng.randint(1, 4)
        for _ in range(n * 3):
            if n <= 0: break
            x = rng.randint(r['x0'], r['x1']); y = rng.randint(r['y0'], r['y1'])
            if K[y][x] != 'F' or (x, y) in reserved: continue
            # only against a wall
            if not any(K[y + dy][x + dx] == 'W' for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))): continue
            K[y][x] = 'P%d' % rng.choice(props)
            if not connected(K, W, H):
                K[y][x] = 'F'
            else:
                n -= 1
    # room character: islands of machinery in the big rooms, studded or grated floors
    for r in rooms:
        w = r['x1'] - r['x0'] + 1; h = r['y1'] - r['y0'] + 1
        if w >= 8 and h >= 5 and rng.random() < 0.55:
            cx = (r['x0'] + r['x1']) // 2; cy = (r['y0'] + r['y1']) // 2
            kind = rng.choice([('P%d' % T_BANKA, 'P%d' % T_BANKB), ('P%d' % T_REACT, 'P%d' % T_REACT),
                               ('P%d' % T_CRATE, 'P%d' % T_BARREL)])
            cells = [(cx, cy), (cx + 1, cy)]
            if all(K[y][x] == 'F' and (x, y) not in reserved for x, y in cells):
                for (x, y), k in zip(cells, kind): K[y][x] = k
                if not connected(K, W, H):
                    for x, y in cells: K[y][x] = 'F'
        if style == 'halls' and w >= 12 and h >= 4:
            # rows of machinery down a big hall
            cy = (r['y0'] + r['y1']) // 2
            for cx in range(r['x0'] + 3, r['x1'] - 3, 5):
                cells = [(cx, cy), (cx + 1, cy)]
                if all(K[y][x] == 'F' and (x, y) not in reserved for x, y in cells):
                    kind = rng.choice([('P%d' % T_BANKA, 'P%d' % T_BANKB), ('P%d' % T_REACT, 'P%d' % T_REACT)])
                    for (x, y), k in zip(cells, kind): K[y][x] = k
                    if not connected(K, W, H):
                        for x, y in cells: K[y][x] = 'F'
        fs = rng.random()
        if fs < 0.25 or fs > 0.92:
            fk = 'S' if fs < 0.25 else 'G'
            for (x, y) in r['cells']:
                if K[y][x] == 'F': K[y][x] = fk
    # the bay: stacks of cargo on open floor, hazard plating round the edge
    if bay:
        for x in range(bay[0], bay[1] + 1):
            for y in (2, H - 3):
                if K[y][x] == 'F': K[y][x] = 'S'
        for cx in range(bay[0] + 2, bay[1] - 2, 5):
            for cy in (4, H - 6):
                cells = [(cx, cy), (cx + 1, cy), (cx, cy + 1), (cx + 1, cy + 1)]
                kinds = rng.choice([(T_CRATE,) * 4, (T_CRATE, T_BARREL, T_CRATE, T_CRATE), (T_BARREL,) * 4])
                if all(K[y][x] in ('F', 'S') and (x, y) not in reserved for x, y in cells):
                    old = [K[y][x] for x, y in cells]
                    for (x, y), k in zip(cells, kinds): K[y][x] = 'P%d' % k
                    if not connected(K, W, H):
                        for (x, y), k in zip(cells, old): K[y][x] = k
    # floor decoration: grates along the spine, hazard strips by the lifts
    for x in range(ax + 1, bx):
        if K[sy0][x] == 'F' and K[sy1][x] == 'F' and (x // 6) % 3 == 1:
            K[sy0][x] = 'G'; K[sy1][x] = 'G'
    d = Deck()
    d.name = name; d.W = W; d.H = H; d.K = K
    d.rooms = rooms; d.lifts = lifts; d.consoles = consoles; d.eners = eners
    d.sy0 = sy0; d.ax = ax; d.bx = bx; d.bay = bay
    d.tiles = autotile(K, W, H, rng)
    build_waypoints(d)
    place_droids(d, droids, rng)
    check_deck(d)
    return d


def walkable(k):
    return k in ('F', 'G', 'S') or k.startswith('L') or k.startswith('E') or k.startswith('D')


def reach_from(K, W, H, start):
    """cells covered by 2x2 footprints reachable from start"""
    def ok(x, y):
        return 0 <= x < W - 1 and 0 <= y < H - 1 and all(walkable(K[y + j][x + i]) for i in (0, 1) for j in (0, 1))
    seen = {start}; q = deque([start]); cov = set()
    while q:
        x, y = q.popleft()
        for i in (0, 1):
            for j in (0, 1):
                cov.add((x + i, y + j))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in seen and ok(*n):
                seen.add(n); q.append(n)
    return cov


def connected(K, W, H):
    """every walkable cell that can hold a 2x2 droid is reachable from every other"""
    ok = set()
    for y in range(H - 1):
        for x in range(W - 1):
            if all(walkable(K[y + j][x + i]) for i in (0, 1) for j in (0, 1)):
                ok.add((x, y))
    if not ok: return True
    start = next(iter(ok)); seen = {start}; q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in ok and n not in seen:
                seen.add(n); q.append(n)
    return len(seen) == len(ok)


def autotile(K, W, H, rng):
    T = [[0] * W for _ in range(H)]
    def is_wallish(x, y):
        if x < 0 or y < 0 or x >= W or y >= H: return True
        k = K[y][x]
        return k in ('W', 'V') or k.startswith('C') or k.startswith('P') or k.startswith('D')
    for y in range(H):
        for x in range(W):
            k = K[y][x]
            if k == 'V':
                r = rng.random()
                T[y][x] = T_VOID + (1 if r < 0.06 else 2 if r < 0.10 else 3 if r < 0.13 else 0)
            elif k == 'W':
                m = 0
                if not is_wallish(x, y - 1): m |= 1
                if not is_wallish(x + 1, y): m |= 2
                if not is_wallish(x, y + 1): m |= 4
                if not is_wallish(x - 1, y): m |= 8
                T[y][x] = T_WALL + m
            elif k == 'F':
                T[y][x] = T_FLOOR + ((x & 1) ^ 1) * 0 + (0 if (x % 2 == 0 and y % 2 == 0) else
                                                       1 if (y % 2 == 0) else 2 if (x % 2 == 0) else 3)
            elif k == 'G':
                T[y][x] = T_GRATE
            elif k == 'S':
                T[y][x] = 10
            elif k == 'DVL': T[y][x] = T_DVL
            elif k == 'DVR': T[y][x] = T_DVR
            elif k == 'DHT': T[y][x] = T_DHT
            elif k == 'DHB': T[y][x] = T_DHB
            elif k[0] == 'L': T[y][x] = T_LIFT + int(k[1])
            elif k[0] == 'E': T[y][x] = T_ENER + int(k[1])
            elif k[0] == 'C': T[y][x] = T_CONL + int(k[1])
            elif k[0] == 'P': T[y][x] = int(k[1:])
    return T


def build_waypoints(d):
    """nodes are the top-left tile of a 2x2 droid footprint"""
    K = d.K; sy0 = d.sy0
    nodes = []; edges = set()
    def add(x, y):
        for i, (nx, ny) in enumerate(nodes):
            if (nx, ny) == (x, y): return i
        nodes.append((x, y)); return len(nodes) - 1
    spine = {}
    xs = set(range(d.ax + 2, d.bx - 2, 8))
    for r in d.rooms:
        if r['door']: xs.add(r['door'][0])
    for (lx, ly) in d.lifts: xs.add(lx)
    bxs = []
    if d.bay:
        bxs = list(range(d.bay[0] + 1, d.bay[1], 5))
        xs.update(bxs)
    xs = sorted(x for x in xs if d.ax + 1 <= x <= d.bx - 2)
    for x in xs: spine[x] = add(x, sy0)
    for a, b in zip(xs, xs[1:]): edges.add((spine[a], spine[b]))
    if bxs:
        # the open bay: a row of nodes above and below the spine, linked across and to it
        def fits(x, y):
            return all(walkable(K[y + j][x + i]) for i in (0, 1) for j in (0, 1))
        for y in ((2 + sy0) // 2 - 1, (sy0 + 2 + d.H - 3) // 2):
            prev = None
            for x in bxs:
                p = next(((xx, y) for xx in (x, x + 1, x - 1, x + 2) if fits(xx, y)), None)
                if p is None: prev = None; continue
                i = add(*p)
                edges.add((i, spine[x]))
                if prev is not None: edges.add((prev, i))
                prev = i
    for r in d.rooms:
        cells = set(r['cells'])
        fit = [(x, y) for (x, y) in cells if all(walkable(K[y + j][x + i]) for i in (0, 1) for j in (0, 1))]
        if not fit: continue
        cx = (r['x0'] + r['x1']) / 2 - 0.5; cy = (r['y0'] + r['y1']) / 2 - 0.5
        if r['door']:
            dx, wy, iny = r['door']
            iy = iny if r['side'] == 'bot' else iny - 1
            dpos = (dx, iy)
            ok = [p for p in fit if line_clear(K, p, dpos)] or fit
            c = min(ok, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
            ci = add(*c); r['node'] = ci
            di = add(*dpos)
            if di != ci: edges.add((ci, di))
            edges.add((di, spine[dx]))
        else:
            c = min(fit, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)
            ci = add(*c); r['node'] = ci
        # corners of big rooms for patrols
        if len(fit) > 30:
            for corner in ((r['x0'], r['y0']), (r['x1'] - 1, r['y1'] - 1)):
                cc = min(fit, key=lambda p: (p[0] - corner[0]) ** 2 + (p[1] - corner[1]) ** 2)
                if cc != c and line_clear(K, c, cc):
                    edges.add((ci, add(*cc)))
    for r in d.rooms:
        if 'sidedoor' in r and 'node' in r and 'node' in r['sidedoor'][2]:
            wxx, dy, prev = r['sidedoor']
            a = add(wxx + 1, dy); b = add(wxx - 2, dy)
            edges.add((r['node'], a)); edges.add((a, b)); edges.add((b, prev['node']))
    # route any edge that isn't a clear straight line through intermediate nodes
    for a, b in list(edges):
        if line_clear(K, nodes[a], nodes[b]): continue
        edges.discard((a, b))
        path = bfs_path(K, nodes[a], nodes[b])
        assert path, (d.name, nodes[a], nodes[b])
        cur = a; k = 0
        while nodes[cur] != nodes[b]:
            # furthest point along the path still in a clear line
            j = len(path) - 1
            while not line_clear(K, nodes[cur], path[j]): j -= 1
            assert j > k, (d.name, 'stuck')
            nxt = b if path[j] == nodes[b] else add(*path[j])
            edges.add((cur, nxt)); cur = nxt; k = j
    adj = [[] for _ in nodes]
    for a, b in edges:
        if b not in adj[a]: adj[a].append(b)
        if a not in adj[b]: adj[b].append(a)
    for i, l in enumerate(adj):
        assert len(l) <= 5, (d.name, i, l)
        for j in l:
            assert line_clear(K, nodes[i], nodes[j]), (d.name, nodes[i], nodes[j])
    assert len(nodes) <= MAXWPT, (d.name, len(nodes))
    d.nodes = nodes; d.adj = adj


def bfs_path(K, a, b):
    H = len(K); W = len(K[0])
    def ok(x, y):
        return 0 <= x < W - 1 and 0 <= y < H - 1 and all(walkable(K[y + j][x + i]) for i in (0, 1) for j in (0, 1))
    prev = {a: None}; q = deque([a])
    while q:
        p = q.popleft()
        if p == b: break
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (p[0] + dx, p[1] + dy)
            if n not in prev and ok(*n):
                prev[n] = p; q.append(n)
    if b not in prev: return None
    path = []; p = b
    while p is not None: path.append(p); p = prev[p]
    return path[::-1]


def line_clear(K, a, b):
    """axis-aligned or diagonal path of a 2x2 footprint between two nodes"""
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0), 1) * 4
    for i in range(n + 1):
        fx = x0 + (x1 - x0) * i / n; fy = y0 + (y1 - y0) * i / n
        for ox in (0, 1.99):
            for oy in (0, 1.99):
                k = K[int(fy + oy)][int(fx + ox)]
                if not walkable(k): return False
    return True


def place_droids(d, droids, rng):
    """droids: list of droid numbers; each goes on a waypoint (rooms first)"""
    spots = [r['node'] for r in d.rooms if 'node' in r]
    rng.shuffle(spots)
    others = [i for i in range(len(d.nodes)) if i not in spots]
    rng.shuffle(others)
    # never right by a lift (where the player arrives)
    def near_lift(i):
        x, y = d.nodes[i]
        return any(abs(x - lx) < 6 and abs(y - ly) < 4 for lx, ly in d.lifts)
    pool = [i for i in spots + others if not near_lift(i)] + [i for i in spots + others if near_lift(i)]
    out = []
    for k, num in enumerate(droids):
        out.append((roster.TYPE_OF[num], pool[k % len(pool)]))
    assert len(out) <= MAXDROIDS
    d.droids = out


def check_deck(d):
    assert connected(d.K, d.W, d.H), d.name
    assert d.W <= 64 and d.H <= 32


# ---------------------------------------------------------------- ships
# side-view: each deck has an offset (in tiles) from the ship's left end.
SHIPS = [
    dict(name='SV CORMORANT', seed=1101, start=0, theme=0, tunes=('CORMORANT', 'CORMORANT_CORE'), decks=[
        dict(name='BRIDGE', w=34, h=16, off=14, con=1, ener=1, droids=[104, 152, 218, 355]),
        dict(name='QUARTERS', w=50, h=18, off=6, con=1, ener=1, style='cells', droids=[104, 104, 152, 218, 218, 263]),
        dict(name='GALLEY', w=56, h=18, off=3, con=1, ener=1, droids=[104, 152, 218, 263, 307, 355]),
        dict(name='CARGO HOLD', w=60, h=20, off=1, con=1, ener=1, style='bay', droids=[307, 307, 104, 263, 355, 408]),
        dict(name='MACHINE SHOP', w=52, h=18, off=5, con=1, ener=1, style='halls', droids=[263, 263, 355, 307, 461]),
        dict(name='ENGINES', w=40, h=16, off=11, con=1, ener=1, droids=[263, 355, 408, 461]),
    ], shafts=[20, 34, 48]),
    dict(name='LV ARCADIA', seed=4404, start=0, theme=1, tunes=('ARCADIA', 'ARCADIA_CORE'), decks=[
        dict(name='SUN DECK', w=32, h=16, off=15, con=1, ener=1, style='halls', droids=[129, 129, 104, 152]),
        dict(name='PROMENADE', w=48, h=18, off=8, con=1, ener=1, style='halls', droids=[129, 152, 218, 218, 104]),
        dict(name='STATEROOMS', w=56, h=18, off=4, con=1, ener=1, style='cells', droids=[129, 129, 218, 218, 408, 104]),
        dict(name='CASINO', w=58, h=20, off=3, con=1, ener=1, style='halls', droids=[218, 263, 355, 461, 129, 129]),
        dict(name='THEATRE', w=54, h=18, off=5, con=1, ener=1, style='bay', droids=[218, 355, 408, 461, 152]),
        dict(name='LAUNDRY', w=46, h=18, off=9, con=1, ener=1, droids=[104, 104, 307, 263, 218]),
        dict(name='ENGINES', w=36, h=16, off=14, con=1, ener=1, droids=[263, 355, 461, 524]),
    ], shafts=[18, 32, 46]),
    dict(name='MV HALCYON', seed=2202, start=0, theme=2, tunes=('HALCYON', 'HALCYON_CORE'), decks=[
        dict(name='OBSERVATORY', w=30, h=16, off=17, con=1, ener=1, droids=[355, 408, 218]),
        dict(name='BRIDGE', w=44, h=18, off=10, con=1, ener=1, droids=[218, 461, 524, 355]),
        dict(name='SICKBAY', w=54, h=18, off=5, con=1, ener=1, style='cells', droids=[408, 408, 218, 152, 524]),
        dict(name='LABS', w=60, h=20, off=2, con=1, ener=1, style='halls', droids=[355, 355, 461, 524, 587, 263]),
        dict(name='BRIG', w=58, h=18, off=3, con=1, ener=1, style='cells', droids=[587, 587, 461, 632, 307]),
        dict(name='STORES', w=50, h=18, off=7, con=1, ener=1, style='bay', droids=[307, 307, 668, 263, 104]),
        dict(name='REACTOR', w=36, h=16, off=14, con=1, ener=1, droids=[632, 461, 408, 668]),
    ], shafts=[20, 32, 44]),
    dict(name='HV GRINDSTONE', seed=5505, start=0, theme=3, tunes=('GRINDSTONE', 'GRINDSTONE_CORE'), decks=[
        dict(name='BRIDGE', w=32, h=16, off=17, con=1, ener=1, droids=[341, 263, 461]),
        dict(name='CREW MESS', w=46, h=18, off=10, con=1, ener=1, style='cells', droids=[218, 341, 104, 152, 408]),
        dict(name='ORE BAY', w=62, h=22, off=1, con=1, ener=2, style='bay', droids=[307, 307, 341, 341, 479, 668]),
        dict(name='DRILL DECK', w=58, h=20, off=3, con=1, ener=1, style='halls', droids=[341, 341, 479, 263, 587]),
        dict(name='REFINERY', w=56, h=18, off=4, con=1, ener=1, droids=[479, 668, 632, 263, 355]),
        dict(name='SMELTER', w=48, h=18, off=8, con=1, ener=1, style='halls', droids=[479, 705, 632, 587, 341]),
        dict(name='ENGINES', w=38, h=16, off=14, con=1, ener=1, droids=[668, 705, 479, 461]),
    ], shafts=[20, 34, 48]),
    dict(name='CV LEVIATHAN', seed=3303, start=0, theme=4, tunes=('LEVIATHAN', 'LEVIATHAN_CORE'), decks=[
        dict(name='COMMAND', w=32, h=16, off=18, con=1, ener=1, droids=[632, 587, 461, 218]),
        dict(name='ARMOURY', w=46, h=18, off=10, con=1, ener=1, style='halls', droids=[705, 741, 632, 587, 461]),
        dict(name='BARRACKS', w=56, h=18, off=5, con=1, ener=1, style='cells', droids=[705, 773, 741, 524, 218, 104]),
        dict(name='HANGAR', w=62, h=22, off=1, con=1, ener=2, style='bay', droids=[856, 773, 705, 668, 307, 307, 152]),
        dict(name='FOUNDRY', w=58, h=20, off=3, con=1, ener=1, style='halls', droids=[817, 668, 741, 587, 263, 263]),
        dict(name='CORE', w=48, h=18, off=8, con=1, ener=1, droids=[960, 908, 856, 773]),
    ], shafts=[22, 36, 50]),
]

def make_ship(spec):
    decks = []
    shafts = spec['shafts']
    # every shaft runs through every deck that is long enough for it
    for i, ds in enumerate(spec['decks']):
        lx = []
        for sx in shafts:
            tx = sx - ds['off']
            if 3 <= tx <= ds['w'] - 5:
                lx.append(tx)
        assert lx, ds['name']
        d = gen_deck(ds['name'], ds['w'], ds['h'], spec['seed'] * 31 + i, lx, ds['con'], ds['ener'], ds['droids'],
                     ds.get('style', 'rooms'))
        d.off = ds['off']
        d.shaft_of = []
        for (tx, ty) in d.lifts:
            # which shaft is this pad on (pads may have been clamped)
            s = min(range(len(shafts)), key=lambda k: abs(shafts[k] - (tx + ds['off'])))
            d.shaft_of.append(s)
        decks.append(d)
    return decks


def deck_preview(d, path, theme=0):
    from vzpal import pix_image
    ts = gfx.theme_tiles(theme)
    rows = []
    for ty in range(d.H):
        for sr in range(6):
            r = []
            for tx in range(d.W):
                r += ts[d.tiles[ty][tx]][sr]
            rows.append(r)
    im = pix_image(rows, sx=2, sy=3)
    from PIL import ImageDraw
    dr = ImageDraw.Draw(im)
    for i, (x, y) in enumerate(d.nodes):
        px, py = x * 16 + 16, y * 18 + 18
        for j in d.adj[i]:
            qx, qy = d.nodes[j][0] * 16 + 16, d.nodes[j][1] * 18 + 18
            dr.line((px, py, qx, qy), fill=(255, 255, 255))
    for t, n in d.droids:
        x, y = d.nodes[n]
        dr.rectangle((x * 16 + 4, y * 18 + 4, x * 16 + 28, y * 18 + 28), outline=(255, 0, 0))
    im.save(path)


if __name__ == '__main__':
    import sys
    for si, spec in enumerate(SHIPS):
        decks = make_ship(spec)
        for di, d in enumerate(decks):
            deck_preview(d, 'build/deck_%d_%d.png' % (si + 1, di), spec['theme'])
            print(spec['name'], d.name, d.W, d.H, 'nodes', len(d.nodes), 'rooms', len(d.rooms), 'lifts', d.lifts)
