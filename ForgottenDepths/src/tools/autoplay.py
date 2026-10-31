"""Autopilot: drives the game in the emulator via BFS over the live map (read from memory dumps)."""
import sys, os, re, subprocess, importlib
from collections import deque
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run
from tiles import DEFS, TILES
from levelc import compile_level, W, H
ROOT = run.ROOT
MAPBASE = 0xCC00
DIRK = {(1, 0): 'R', (-1, 0): 'L', (0, 1): 'D', (0, -1): 'U'}

def objectives(n):
    mod = importlib.import_module(f'level{n}')
    lv = compile_level(mod)
    E = {k: (x, y) for k, x, y in lv['ents']}
    goal = [(x, y) for y in range(H) for x in range(W) if DEFS[lv['tiles'][y][x]]['special'] == 2][0]
    order = {1: ['staff', 'key', 'boss'], 2: ['boots', 'blade', 'key', 'sunstone', 'boss'], 3: ['ring', 'key', 'boss']}[n]
    return [(k, E[k]) for k in order] + [('goal', goal)]

class Pilot:
    def __init__(self, name, defs=()):
        self.name = name
        self.script = [(30, 'N', 3), (90, 'FIRE', 3)]
        self.f = 150
        self.done = 0
        self.hist = []
    def step(self, k, hold=5, gap=9):
        self.script.append((self.f, k, hold))
        self.f += gap
    def sim(self, snaps=()):
        # continue from the last snapshot with only the new key presses
        new = [k for k in self.script if k[0] >= getattr(self, 'done', 0)]
        end = self.f + 30
        extra = ['-dumpmem', str(end - 1), f'{ROOT}/build/mem.bin', '-save', f'{ROOT}/build/snap_new.bin', '-until', str(end)]
        if getattr(self, 'done', 0):
            extra += ['-load', f'{ROOT}/build/snap.bin']
        p = run.run(self.name, (end + 50) / 49.86, new, list(snaps), extra=extra)
        os.replace(f'{ROOT}/build/snap_new.bin', f'{ROOT}/build/snap.bin')
        self.done = end
        self.f = max(self.f, end)
        st, m, s = run.state()
        return st, m, s, p
    def tile(self, m, x, y):
        return m[MAPBASE + y * 256 + x] & 0x7F
    def passable(self, st, m, x, y, s):
        if not (0 <= x < W and 0 <= y < H): return False
        t = self.tile(m, x, y)
        d = DEFS.get(t)
        if d is None: return False
        sp = d['special']
        if sp == 9: return False          # portals: avoid (they teleport)
        if not d['solid']: return True
        if sp == 5: return True
        if sp == 7 and st['p_boots']: return True
        if sp == 6 and st['p_ring']: return True
        if sp == 4 and st['p_key']: return True
        if sp == 2: return True
        return False
    def path(self, st, m, s, target, near=False):
        start = (st['p_x'], st['p_y'])
        prev = {start: None}
        q = deque([start])
        tx, ty = target
        while q:
            c = q.popleft()
            if c == target or (near and abs(c[0] - tx) + abs(c[1] - ty) <= 1):
                out = []
                while prev[c] is not None:
                    out.append(c); c = prev[c]
                return out[::-1]
            for dx, dy in DIRK:
                n = (c[0] + dx, c[1] + dy)
                if n in prev: continue
                if n == target or self.passable(st, m, n[0], n[1], s):
                    prev[n] = c; q.append(n)
        return None

LVBUF = 0xC800

def spawns(m):
    out = []
    a = LVBUF + 140
    while m[a]:
        out.append((m[a], m[a + 1], m[a + 2], m[a + 3]))
        a += 4
    return out

ENTN = ['none', 'player', 'skeleton', 'bat', 'slime', 'ghost', 'eel', 'drowned', 'imp', 'magma', 'spider',
        'staff', 'key', 'gem', 'potion', 'heart', 'boots', 'sunstone', 'ring', 'blade', 'mana']

def drive(name='auto', maxit=400, upto=3, verbose=True, maxframe=10**9, demo=False):
    P = Pilot(name)
    lastpos = None
    stuck = 0
    for it in range(maxit):
        st, m, s, _ = P.sim()
        n = st['lv_num']
        pos = (st['p_x'], st['p_y'])
        if st['game_over'] == 2 or (n > upto):
            return P, st, 'DONE'
        if P.f >= maxframe:
            return P, st, 'FRAMES'
        if demo and st['p_staff'] and it % 5 == 2:
            P.step('MAG', gap=20)
        objs = objectives(n)
        sp = spawns(m)
        alive = {(x, y) for t, x, y, a in sp if a}
        boss_alive = m[LVBUF + 52 + 19]
        target = None
        for k, p in objs:
            if k == 'boss':
                if boss_alive:
                    target = ('boss', (m[s['b_x']], m[s['b_y']]) if m[s['b_on']] else p)
                    break
            elif k == 'goal':
                target = ('goal', p); break
            elif p in alive:
                target = (k, p); break
        if pos == lastpos:
            stuck += 1
        else:
            stuck = 0
        lastpos = pos
        if verbose:
            print(f'it{it} f{P.f} ch{n} pos{pos} hp{st["p_hp"]} lvl{st["p_lvl"]} -> {target} stuck{stuck} boss{boss_alive}/{st["b_hp"]}')
        if stuck >= 2 and target[0] != 'boss' and stuck % 2 == 0:
            P.f += 60
            P.step('FIRE')
            if stuck % 6 == 0:
                import random
                P.step(random.choice('LRUD'))
            continue
        if target[0] == 'boss':
            bx, by = target[1]
            size = m[LVBUF + 52 + 12]
            cells = [(bx + i, by + j) for i in range(size) for j in range(size)]
            best = None
            for c in cells:
                pth = P.path(st, m, s, c, near=True)
                if pth is not None and (best is None or len(pth) < len(best[0])):
                    best = (pth, c)
            if best is None:
                P.step('FIRE'); continue
            pth, c = best
            if not pth:      # adjacent: strike toward it
                dx = max(-1, min(1, c[0] - pos[0])); dy = max(-1, min(1, c[1] - pos[1]))
                if dx and dy: dy = 0
                k = DIRK.get((dx, dy), 'R')
                for i in range(4):
                    P.step(k, hold=3, gap=14)
                if st['p_mp']: P.step('MAG')
                continue
        else:
            pth = P.path(st, m, s, target[1])
            if pth is None:
                P.step('FIRE'); continue
        cur = pos
        for c in pth[:6]:
            d = (c[0] - cur[0], c[1] - cur[1])
            k = DIRK[d]
            t = P.tile(m, c[0], c[1])
            if DEFS[t]['special'] == 5:
                P.step(k); P.step('FIRE', gap=20); P.step(k)
                break
            if DEFS[t]['special'] == 4:
                P.step(k, gap=40)
            P.step(k)
            cur = c
    return P, st, 'MAXIT'

if __name__ == '__main__':
    P, st, res = drive(upto=int(sys.argv[1]) if len(sys.argv) > 1 else 3)
    print(res, st)
    open(f'{ROOT}/build/auto.keys.py', 'w').write(repr(P.script))
