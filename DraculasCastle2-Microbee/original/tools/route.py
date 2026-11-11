# route.py - expand high-level route tokens into key tokens for play.py
#   @x,y      walk (BFS) to x,y in the current area, doors opened on the way
#   face:D    turn to face N/E/S/W
#   area:N x y d   set simulated position (after an exit/teleport)
from collections import deque
import maps
DV = [(0, -1), (1, 0), (0, 1), (-1, 0)]
class Sim:
    def __init__(self):
        self.area = 0; self.x, self.y, self.d = 8, 14, 0
        self.cells = {a: bytearray(maps.compile_area(a)[0]) for a in maps.AREA_MAPS}
        self.events = {a: maps.compile_area(a)[1] for a in maps.AREA_MAPS}
    def passable(self, x, y):
        if not (0 <= x < 16 and 0 <= y < 16): return False
        c = self.cells[self.area][y * 16 + x]; t = c & 7
        if t == 3: return True
        if t != 0: return False
        p = c >> 3
        if p:
            ev = self.events[self.area][p - 1]
            return ev['obj'] == 0
        return True
    def turn_to(self, nd, out):
        diff = (nd - self.d) & 3
        if diff == 1: out.append('D')
        elif diff == 3: out.append('A')
        elif diff == 2: out.append('S')
        self.d = nd
    def goto(self, tx, ty, out):
        prev = {(self.x, self.y): None}; q = deque([(self.x, self.y)])
        while q:
            p = q.popleft()
            if p == (tx, ty): break
            for d, (dx, dy) in enumerate(DV):
                n = (p[0] + dx, p[1] + dy)
                if n not in prev and self.passable(*n):
                    prev[n] = p; q.append(n)
        if (tx, ty) not in prev: raise ValueError('no path to %d,%d' % (tx, ty))
        path = []; p = (tx, ty)
        while p != (self.x, self.y): path.append(p); p = prev[p]
        for (nx, ny) in reversed(path):
            nd = DV.index((nx - self.x, ny - self.y))
            self.turn_to(nd, out)
            c = self.cells[self.area][ny * 16 + nx]
            if c & 7 == 3:
                out.append('W:70'); self.cells[self.area][ny * 16 + nx] = 0
            out.append('W'); self.x, self.y = nx, ny
def expand(script):
    s = Sim(); out = []
    toks = script.split(); i = 0
    while i < len(toks):
        t = toks[i]
        if t.startswith('@'):
            cap = t.endswith('!'); x, y = map(int, t[1:].rstrip('!').split(','))
            s.goto(x, y, out)
            if cap: out[-1] += '!'
        elif t.startswith('face:'):
            cap = t.endswith('!')
            s.turn_to('NESW'.index(t[5].upper()), out)
            if cap and out: out[-1] += '!'
        elif t == 'clear':
            x, y = int(toks[i + 1]), int(toks[i + 2]); s.cells[s.area][y * 16 + x] = 0; i += 2
        elif t == 'secret':
            x, y = int(toks[i + 1]), int(toks[i + 2]); s.cells[s.area][y * 16 + x] = 0; i += 2
        elif t == 'pos':
            s.x, s.y, s.d = int(toks[i + 1]), int(toks[i + 2]), int(toks[i + 3]); i += 3
        elif t == 'area':
            s.area = int(toks[i + 1]); s.x = int(toks[i + 2]); s.y = int(toks[i + 3]); s.d = int(toks[i + 4]); i += 4
        else: out.append(t)
        i += 1
    return ' '.join(out)
if __name__ == '__main__':
    import sys
    print(expand(open(sys.argv[1]).read()))
