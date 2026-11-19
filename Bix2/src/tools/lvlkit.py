# Level construction kit (stamps) shared by all levels after 1-1.
E_ANT, E_MAG, E_DROP, E_TOAD, E_PLATH, E_PLATV, E_GLOW, E_ONEUP, E_START, E_WORM = range(1, 11)
E_BOSS = 13

class Level:
    def __init__(self, W, H=12):
        self.W, self.H = W, H
        self.g = [['sky'] * H for _ in range(W)]
        self.ents = []
    def put(self, x, y, t):
        if 0 <= x < self.W and 0 <= y < self.H: self.g[x][y] = t
    def get(self, x, y): return self.g[x][y]
    def fill(self, x0, x1, y0, y1, t):
        for x in range(x0, x1):
            for y in range(y0, y1 + 1): self.put(x, y, t)
    def ground(self, x0, x1, top=9, kind='grass'):
        for x in range(x0, x1):
            self.put(x, top, kind)
            for y in range(top + 1, self.H):
                self.put(x, y, 'soil2' if (x * 7 + y * 3) % 11 == 0 else 'soil')
    def earth(self, x0, x1, y0, y1):
        for x in range(x0, x1):
            for y in range(y0, y1 + 1):
                self.put(x, y, 'soil2' if (x * 5 + y * 3) % 11 == 0 else 'soil')
    def rock(self, x0, x1, y0, y1, top=True):
        for x in range(x0, x1):
            for y in range(y0, y1 + 1):
                self.put(x, y, 'rocktop' if (top and y == y0) else 'rock')
    def logs(self, x, y, n):
        for i in range(n): self.put(x + i, y, 'log')
    def stars(self, x, y, n, dy=None, t='star'):
        for i in range(n): self.put(x + i, y + (dy[i] if dy else 0), t)
    def plateau(self, x0, x1, top=8, base=9):
        # a raised step with a ramp up on the left and down on the right
        self.put(x0, top, 'slopeR')
        for x in range(x0 + 1, x1 - 1):
            self.put(x, top, 'grass')
            for y in range(top + 1, base + 1): self.put(x, y, 'soil')
        self.put(x1 - 1, top, 'slopeL')
        self.put(x0, base, 'soil'); self.put(x1 - 1, base, 'soil')
    def ent(self, x, y, t, p=0): self.ents.append((x, y, t, p))
    def deco(self, x, y, t):
        if self.g[x][y] in ('sky', 'hillB', 'hillBT'): self.put(x, y, t)
    def build(self, tid):
        m = bytearray()
        for x in range(self.W):
            for y in range(self.H): m.append(tid[self.g[x][y]])
        e = bytearray()
        for (x, y, t, p) in sorted(self.ents):
            e += bytes([x & 255, x >> 8, y, t, p])
        e += b'\xff\xff'
        return m, e
    def start(self):
        return [e for e in self.ents if e[2] == E_START][0][:2]
