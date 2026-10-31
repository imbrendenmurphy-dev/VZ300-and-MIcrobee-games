"""Track compiler.  A track is a list of sections:
   ('S', length)                      straight
   ('C', length, curve)               bend: curve -127..127 (+ = right), eased in/out
   ('H', length, rise)                hill: altitude change over the section (+ up), eased
   ('CH', length, curve, rise)        both
   ('T', length)                      tunnel (flag), straight
   ('G', kind)                        overhead gantry at this point (0 start,1 checkpoint,2 finish)
   ('O', type, side, every, count)    roadside objects from here: every N segs, side -1/1/0 both
Output: per-segment curve/alt/flags arrays + object list."""
import math, struct

def ease(t):  # smooth in/out
    return (1 - math.cos(math.pi * t)) / 2

class Track:
    def __init__(self, name):
        self.name = name; self.curv = []; self.alt = [0]; self.flag = []
        self.objs = []; self.gantries = []
        self.obj_rules = []
    def _push(self, c, dalt, flag=0):
        self.curv.append(int(round(c))); self.alt.append(self.alt[-1] + dalt); self.flag.append(flag)
    def S(self, n, flag=0):
        for i in range(n): self._push(0, 0, flag)
    def C(self, n, curve, rise=0, flag=0):
        # curve eases in over the first quarter and out over the last quarter
        e = max(1, n // 4)
        for i in range(n):
            if i < e: k = ease((i + 1) / e)
            elif i >= n - e: k = ease((n - i) / e)
            else: k = 1
            self._push(curve * k, 0, flag)
        if rise: self._hill_over(n, rise)
    def H(self, n, rise, curve=0, flag=0):
        start = len(self.curv)
        self.C(n, curve, 0, flag) if curve else self.S(n, flag)
        self._hill_over(n, rise, start)
    def _hill_over(self, n, rise, start=None):
        if start is None: start = len(self.curv) - n
        base = self.alt[start]
        for i in range(n + 1):
            self.alt[start + i] = base + int(round(rise * ease(i / n)))
        # re-base the following (none yet)
    def T(self, n, curve=0):
        if curve: self.C(n, curve, 0, 1)
        else: self.S(n, 1)
    def G(self, kind):
        self.gantries.append((len(self.curv), kind))
    def obj(self, seg, typ, xoff):
        self.objs.append((seg, typ, xoff))
    def scatter(self, start, end, typ, every, side, xoff=300, jitter=0, seed=1):
        import random
        r = random.Random(seed)
        s = start
        while s < end:
            if self.flag[s] & 1 == 0:
                sides = [-1, 1] if side == 0 else [side]
                for sd in sides:
                    x = xoff + (r.randint(0, jitter) if jitter else 0)
                    self.obj(s, typ, sd * x)
            s += every

    def compile(self, maxseg=512, tail=40):
        self.S(tail)  # run-out
        n = len(self.curv)
        assert n <= maxseg, (self.name, n)
        curv = bytes((c & 255) for c in self.curv) + bytes(maxseg - n)
        alt = self.alt[:n] + [self.alt[n - 1]] * (maxseg - n)
        altl = bytes(a & 255 for a in alt); alth = bytes((a >> 8) & 255 for a in alt)
        flag = bytes(self.flag) + bytes(maxseg - n)
        return curv, altl, alth, flag, n

def test_track():
    t = Track('TEST')
    t.S(20); t.G(0)
    t.C(40, 30); t.S(10)
    t.H(40, 2400); t.C(30, -40)
    t.H(30, -2400, 20)
    t.S(10); t.C(50, 50, 0)
    t.T(30); t.S(10)
    t.H(25, 1200); t.H(25, -1200)
    t.C(40, -60); t.S(20); t.C(30, 35)
    t.H(60, 3000, -20); t.H(40, -3000)
    t.S(30)
    return t

if __name__ == '__main__':
    import os
    B = os.path.join(os.path.dirname(__file__), '..', 'build')
    t = test_track()
    c, al, ah, f, n = t.compile()
    open(os.path.join(B, 'test_trk.bin'), 'wb').write(c + al + ah + f)
    print('segments', n)
