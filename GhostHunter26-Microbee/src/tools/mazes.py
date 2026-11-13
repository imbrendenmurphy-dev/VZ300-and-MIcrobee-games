"""GHOST HUNTER '26 mazes (VIBED BY BPM 2026).

A maze is a 13 x 7 grid of nodes joined by lanes. On the 40 x 25 screen a
node is 2 x 2 cells and the walls between lanes are one cell thick, so the
node pitch is 3 cells (24 pixels). Every maze is mirror-symmetric, fully
connected, has no dead ends and no open 2 x 2 plazas (so every wall pillar
joins a wall). Nodes (5,3) (6,3) (7,3) are the ghost pen; its door opens up
to node (6,2). Power-ups appear on node (6,4); the hunter starts on (6,5).

Direction bits: 1 right, 2 left, 4 up, 8 down.
"""
import random

NX, NY = 13, 7
R, L, U, D = 1, 2, 4, 8
DX = {R: 1, L: -1, U: 0, D: 0}
DY = {R: 0, L: 0, U: -1, D: 1}
OPP = {R: L, L: R, U: D, D: U}
PEN = {(5, 3), (6, 3), (7, 3)}
DOOR = (6, 2)
ITEM = (6, 4)
START = (6, 5)
ENERG = [(0, 1), (12, 1), (0, 5), (12, 5)]


class Maze:
    def __init__(self, name, style, seed, keep, tunnels, dotcol, holes=()):
        self.name, self.style, self.tunnels, self.dotcol = name, style, tunnels, dotcol
        self.holes = set(holes) | {(12 - x, y) for x, y in holes}
        self.h = {}     # (i, j): edge (i,j)-(i+1,j)
        self.v = {}     # (i, j): edge (i,j)-(i,j+1)
        for k in range(200):
            if self.generate(seed + 1000 * k, keep):
                break
        else:
            raise SystemExit('no maze for ' + name)

    def node_ok(self, n):
        return 0 <= n[0] < NX and 0 <= n[1] < NY and n not in PEN and n not in self.holes

    def edges_of(self, n, tunnels=True):
        i, j = n
        e = 0
        if self.h.get((i, j)):
            e |= R
        if self.h.get((i - 1, j)):
            e |= L
        if self.v.get((i, j - 1)):
            e |= U
        if self.v.get((i, j)):
            e |= D
        if tunnels and j in self.tunnels:
            if i == 0:
                e |= L
            if i == NX - 1:
                e |= R
        return e

    def nodes(self):
        return [(i, j) for j in range(NY) for i in range(NX) if self.node_ok((i, j))]

    def connected(self):
        ns = self.nodes()
        seen = {ns[0]}
        todo = [ns[0]]
        while todo:
            n = todo.pop()
            e = self.edges_of(n, False)
            for d in (R, L, U, D):
                if e & d:
                    m = (n[0] + DX[d], n[1] + DY[d])
                    if m not in seen:
                        seen.add(m)
                        todo.append(m)
        return len(seen) == len(ns)

    def plazas(self):
        out = []
        for j in range(NY - 1):
            for i in range(NX - 1):
                if self.h.get((i, j)) and self.h.get((i, j + 1)) and self.v.get((i, j)) and self.v.get((i + 1, j)):
                    out.append((i, j))
        return out

    def generate(self, seed, keep):
        rnd = random.Random(seed)
        self.h, self.v = {}, {}
        for j in range(NY):
            for i in range(NX - 1):
                self.h[(i, j)] = self.node_ok((i, j)) and self.node_ok((i + 1, j))
        for j in range(NY - 1):
            for i in range(NX):
                self.v[(i, j)] = self.node_ok((i, j)) and self.node_ok((i, j + 1))

        def mirror(k, e):
            i, j = e
            return (k, (NX - 2 - i, j)) if k == 'h' else (k, (NX - 1 - i, j))

        def count():
            return sum(self.h.values()) + sum(self.v.values())

        def try_remove(k, e):
            tab = self.h if k == 'h' else self.v
            mk, me = mirror(k, e)
            if not tab.get(e):
                return False
            tab[e] = False
            tab[me] = False
            ok = self.connected() and all(bin(self.edges_of(n)).count('1') >= 2 for n in self.nodes())
            # the lanes round the pen and under the door stay open
            ok = ok and self.h[(5, 2)] and self.h[(6, 2)] and self.h[(5, 4)] and self.h[(6, 4)]
            if not ok:
                tab[e] = True
                tab[me] = True
            return ok
        for rounds in range(4000):
            pl = self.plazas()
            if not pl and count() <= keep:
                break
            if pl:
                i, j = rnd.choice(pl)
                k, e = rnd.choice([('h', (i, j)), ('h', (i, j + 1)), ('v', (i, j)), ('v', (i + 1, j))])
            else:
                k = rnd.choice('hv')
                e = (rnd.randrange(NX), rnd.randrange(NY))
            try_remove(k, e)
        return not self.plazas() and count() <= keep + 4

    # ---- data for the game
    def edge_table(self):
        return bytes(self.edges_of((i, j)) if self.node_ok((i, j)) else 0 for j in range(NY) for i in range(NX))

    def home_table(self):
        """direction to take from each node to reach the pen door node"""
        dist = {DOOR: 0}
        todo = [DOOR]
        while todo:
            n = todo.pop(0)
            e = self.edges_of(n)
            for d in (R, L, U, D):
                if e & d:
                    m = ((n[0] + DX[d]) % NX, n[1] + DY[d])
                    if m not in dist:
                        dist[m] = dist[n] + 1
                        todo.append(m)
        out = bytearray()
        for j in range(NY):
            for i in range(NX):
                n = (i, j)
                best = 0
                if n in dist and n != DOOR:
                    e = self.edges_of(n)
                    for d in (U, L, D, R):
                        if e & d:
                            m = ((n[0] + DX[d]) % NX, n[1] + DY[d])
                            if dist[m] == dist[n] - 1:
                                best = d
                                break
                out.append({0: 255, R: 0, L: 1, U: 2, D: 3}[best])
        return bytes(out)

    def open_cells(self):
        """22 x 40 booleans: True = corridor (pen interior included)"""
        o = [[False] * 40 for _ in range(22)]
        for j in range(NY):
            for i in range(NX):
                if self.node_ok((i, j)) or (i, j) in PEN:
                    for a in (1, 2):
                        for b in (1, 2):
                            o[3 * j + a][3 * i + b] = True
                if self.h.get((i, j)):
                    o[3 * j + 1][3 * i + 3] = o[3 * j + 2][3 * i + 3] = True
                if self.v.get((i, j)):
                    o[3 * j + 3][3 * i + 1] = o[3 * j + 3][3 * i + 2] = True
        for j in (3,):                          # the pen's inside
            for c in (18, 21):
                o[3 * j + 1][c] = o[3 * j + 2][c] = True
        for j in self.tunnels:
            for c in (0, 39):
                o[3 * j + 1][c] = o[3 * j + 2][c] = True
        return o

    def dots(self):
        """{(lx, ly): 1 dot / 2 energiser} on the lattice of cell corners"""
        d = {}
        for j in range(NY):
            for i in range(NX):
                if not self.node_ok((i, j)):
                    continue
                d[(3 * i + 2, 3 * j + 2)] = 1
                if self.h.get((i, j)):
                    d[(3 * i + 3, 3 * j + 2)] = d[(3 * i + 4, 3 * j + 2)] = 1
                if self.v.get((i, j)):
                    d[(3 * i + 2, 3 * j + 3)] = d[(3 * i + 2, 3 * j + 4)] = 1
        for (i, j) in ENERG:
            d[(3 * i + 2, 3 * j + 2)] = 2
        ix, iy = 3 * ITEM[0] + 2, 3 * ITEM[1] + 2
        for a in (-1, 0, 1):
            for b in (-1, 0, 1):
                d.pop((ix + a, iy + b), None)
        d.pop((3 * START[0] + 2, 3 * START[1] + 2), None)
        return d

    def ascii(self):
        o = self.open_cells()
        return '\n'.join(''.join(' ' if c else '#' for c in row) for row in o)


#          name               style  seed keep tunnels dot colour  holes
SPECS = [
    ('THE OLD CRYPT',     0, 11, 118, (3,), 15, ()),
    ('HEDGE MAZE',        1, 5, 122, (3,), 11, ()),
    ('BOILER ROOM',       2, 23, 114, (1, 5), 15, ((2, 3),)),
    ('BRICK MANOR',       3, 31, 120, (3,), 11, ()),
    ('NEON ARCADE',       4, 47, 112, (2, 4), 15, ((3, 1), (3, 5))),
    ('PHANTOM PALACE',    5, 59, 116, (0, 6), 14, ((1, 3),)),
]


def all_mazes():
    return [Maze(*s) for s in SPECS]


if __name__ == '__main__':
    for m in all_mazes():
        print(m.name, 'edges', sum(m.h.values()) + sum(m.v.values()), 'dots', len(m.dots()))
        print(m.ascii())
