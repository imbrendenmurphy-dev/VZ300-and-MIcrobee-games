#!/usr/bin/env python3
"""Level builder for stages 2-7: themed set pieces, an upper and a lower route,
secret ledges, guided coin trails, enemy placement by section, two checkpoints,
and a reachability check (tools/reach.py) that rejects unfair layouts.

Map rows 0-6 (8 px each); the ground surface is normally row 5 (y 40).
Object y: walkers, toughs, spitters, chests, checkpoints = the surface they
stand on; flyers, floaters, divers, the mini-boss, items = their top.
"""
import random
from reach import World, explore, can_touch, traps

OT = {'zombie': 1, 'skel': 2, 'bat': 3, 'ghost': 4, 'crow': 5, 'imp': 6, 'plant': 7,
      'chest': 8, 'item': 9, 'checkpt': 10, 'zzone': 11, 'boss': 12, 'torch': 13}
ROLE = {'walker': 'zombie', 'tough': 'skel', 'flyer': 'bat', 'floater': 'ghost',
        'diver': 'crow', 'spitter': 'plant', 'mini': 'imp'}
IT = {'coin': 0, 'jewel': 1, 'armour': 2, 'potion': 3, 'lance': 4, 'dagger': 5, 'axe': 6,
      'torchw': 7, 'heart': 8}
W = 176
ARENA = 158


class Level:
    def __init__(self, n, seed):
        self.n = n
        self.r = random.Random(seed)
        self.M = [['sky'] * W for _ in range(7)]
        self.ground = [5] * W
        self.pit = set()
        self.objs = []
        self.reserved = set()        # columns decor must leave alone
        self.sections = []           # (start, end, kind)
        self.spikes = set()

    # ---- primitives
    def put(self, c, r, t):
        if 0 <= c < W and 0 <= r < 7:
            self.M[r][c] = t

    def o(self, c, kind, param=0, y=None):
        if y is None:
            y = self.ground[c] * 8
        self.objs.append([c, y, OT[kind], param])

    def enemy(self, c, role, y=None):
        self.o(c, ROLE[role], 0, y)

    def coin(self, c, y, kind='coin'):
        self.o(c, 'item', IT[kind], y)

    def surface(self, c):
        """y of the highest standable surface in column c (ground or block)"""
        for r in range(7):
            t = self.M[r][c]
            if t in SOLIDISH:
                return r * 8
        return self.ground[c] * 8

    # ---- set pieces: each returns its width
    def p_flat(self, c, w=None):
        w = w or self.r.randint(6, 10)
        return w

    def p_hill(self, c):
        ln = self.r.randint(12, 16)
        for x in range(c, c + ln):
            self.ground[x] = 4
        for x in range(c + 3, c + ln - 3):
            self.ground[x] = 3
        for x in range(c + 4, c + ln - 4, 2):
            self.coin(x, 12)
        return ln + 1

    def p_pit(self, c, long=False):
        ln = self.r.randint(12, 16) if long else self.r.randint(7, 10)
        for x in range(c, c + ln):
            self.pit.add(x)
        x = c + 2
        prev = 5
        while x < c + ln - 2:
            pl = self.r.randint(2, 3)
            hy = self.r.choice([3, 4, 4]) if prev != 3 else 4
            for k in range(pl):
                if x + k < c + ln - 1:
                    self.put(x + k, hy, 'plat')
            # coin over the gap before the platform guides the jump
            self.coin(x - 1, hy * 8 - 14)
            prev = hy
            x += pl + self.r.randint(2, 3)
        return ln + 2

    def p_building(self, c, roof_reward=True):
        ln = self.r.randint(7, 10)
        for x in range(c, c + ln):
            self.put(x, 3, 'block'); self.put(x, 4, 'block'); self.put(x, 2, 'roof_m')
            self.reserved.add(x)
        self.put(c, 2, 'roof_l'); self.put(c + ln - 1, 2, 'roof_r')
        mid = c + ln // 2
        self.put(mid, 3, 'door_t'); self.put(mid, 4, 'door_b')
        self.put(c - 1, 4, 'block_top'); self.reserved.add(c - 1)
        if roof_reward:
            for x in range(c + 1, c + ln - 1, 2):
                self.coin(x, 4)
        return ln + 3

    def p_rooftops(self, c):
        """houses separated by flooded streets: run across the roofs"""
        x = c
        self.put(x, 4, 'block_top'); self.reserved.add(x); x += 1
        for i in range(3):
            hw = self.r.randint(4, 6)
            for k in range(hw):
                self.put(x + k, 3, 'block'); self.put(x + k, 4, 'block'); self.put(x + k, 2, 'roof_m')
                self.reserved.add(x + k)
            self.put(x, 2, 'roof_l'); self.put(x + hw - 1, 2, 'roof_r')
            if i == 1:
                self.put(x + hw // 2, 3, 'door_t'); self.put(x + hw // 2, 4, 'door_b')
            x += hw
            if i < 2:
                gap = self.r.randint(2, 3)
                for k in range(gap):
                    self.pit.add(x + k)
                self.put(x + gap // 2, 4, 'plat')       # a floating plank: a way back up
                self.coin(x + gap // 2, 2)
                x += gap
        return x - c + 2

    def p_upper(self, c):
        """a ledge route over a spike strip: treasure above, danger below"""
        ln = self.r.randint(8, 11)
        self.put(c, 4, 'plat_post')
        for x in range(c + 2, c + 2 + ln):
            self.put(x, 2, 'plat')
            self.reserved.add(x)
        for x in range(c + 4, c + ln - 1):
            if x % 3:
                self.spikes.add(x)
        for x in range(c + 3, c + 1 + ln, 2):
            self.coin(x, 4)
        return ln + 4

    def p_toadstools(self, c):
        """giant mushroom caps on stalks, rising then falling"""
        heights = [4, 3, 2, 2, 3]
        x = c
        for i, h in enumerate(heights):
            for k in range(2):
                self.put(x + k, h, 'plat')
                self.reserved.add(x + k)
            for r in range(h + 1, self.ground[x]):
                self.put(x, r, 'stalk')
            if h == 2:
                self.coin(x, h * 8 - 10)
            x += 4
        for k in range(c + 9, c + 13):
            self.spikes.add(k)
        return x - c + 1

    def p_secret(self, c):
        """a wall to climb; beyond a gap, a ledge with a prize for a bold leap"""
        self.put(c, 4, 'block_top')
        for x in range(c + 1, c + 4):
            self.put(x, 3, 'block_top'); self.put(x, 4, 'block')
        self.reserved.update(range(c, c + 4))
        gap = self.r.randint(3, 4)
        for x in range(c + 4 + gap, c + 7 + gap):
            self.put(x, 2, 'plat')
            self.reserved.add(x)
        for x in range(c + 4, c + 4 + gap):
            self.spikes.add(x)
        self.secret_at = c + 5 + gap
        return 9 + gap

    def p_spikes(self, c):
        w = self.r.randint(2, 3)
        for x in range(c + 3, c + 3 + w):
            self.spikes.add(x)
        self.coin(c + 3 + w // 2, 18)
        return w + 7

    def p_steps(self, c):
        for k in range(3):
            for x in range(c + k * 2, c + k * 2 + 2):
                self.ground[x] = 4 - k
        for x in range(c + 6, c + 9):
            self.ground[x] = 2
        self.coin(c + 7, 0)
        return 12

    def p_cavern(self, c):
        """low ceiling with stalactites and a lava pit"""
        ln = self.r.randint(12, 16)
        for x in range(c, c + ln):
            self.put(x, 0, 'block'); self.reserved.add(x)
            if x % 4 == 1:
                self.put(x, 1, 'deco_t')
        p0 = c + ln // 2 - 1
        for x in range(p0, p0 + 3):
            self.pit.add(x)
        self.coin(p0 + 1, 22)
        return ln + 1

    def p_rampart(self, c):
        """castle walkway on posts over a spiked moat"""
        ln = self.r.randint(10, 13)
        self.put(c, 4, 'block_top'); self.put(c + 1, 3, 'block_top'); self.put(c + 1, 4, 'block')
        for x in range(c + 2, c + 2 + ln):
            self.put(x, 3, 'plat_post' if x % 4 == 0 else 'plat')
            if x % 4 == 0:
                self.put(x, 4, 'stalk')
            self.reserved.add(x)
            if x % 4:
                self.spikes.add(x)
        self.reserved.update((c, c + 1))
        for x in range(c + 3, c + 2 + ln, 3):
            self.coin(x, 12)
        return ln + 4

    def p_floaters(self, c):
        """floating platforms over arcane fire at mixed heights"""
        ln = self.r.randint(12, 15)
        for x in range(c, c + ln):
            self.pit.add(x)
        x = c + 2
        h = 4
        while x < c + ln - 2:
            for k in range(2):
                self.put(x + k, h, 'plat')
            self.coin(x, h * 8 - 10)
            h = self.r.choice([2, 3, 4]) if h == 4 else h + 1
            x += 4
        return ln + 2

    PIECES = {
        2: ['hill', 'pit', 'toadstools', 'building', 'upper', 'spikes', 'steps', 'toadstools', 'hill', 'pit'],
        3: ['rooftops', 'pit', 'building', 'upper', 'rooftops', 'spikes', 'hill', 'pit', 'steps'],
        4: ['longpit', 'hill', 'pit', 'upper', 'longpit', 'spikes', 'building', 'steps', 'pit'],
        5: ['cavern', 'pit', 'hill', 'steps', 'cavern', 'upper', 'spikes', 'pit', 'building'],
        6: ['rampart', 'building', 'pit', 'spikes', 'rampart', 'steps', 'upper', 'hill', 'pit'],
        7: ['floaters', 'building', 'spikes', 'upper', 'floaters', 'steps', 'pit', 'hill', 'floaters'],
    }

    def build(self):
        r = self.r
        n = self.n
        pieces = list(self.PIECES[n])
        r.shuffle(pieces)
        # the secret goes somewhere in the middle third
        pieces.insert(r.randint(3, 5), 'secret')
        c = 14
        self.cps = []
        while c < ARENA - 14 and pieces:
            kind = pieces.pop(0)
            fn = {'longpit': lambda c: self.p_pit(c, True)}.get(kind) or getattr(self, 'p_' + kind)
            w = fn(c)
            self.sections.append((c, c + w, kind))
            c += w
            # breathing space (and checkpoints) between pieces
            gap = r.randint(3, 5)
            self.sections.append((c, c + gap, 'flat'))
            if not self.cps and c > 55 or len(self.cps) == 1 and c > 105:
                self.cps.append(c + 1)
                gap = max(gap, 5)
            c += gap
        while len(self.cps) < 2:
            self.cps.append(min(c, ARENA - 6) if self.cps else 70)
        self.finish()

    def finish(self):
        r = self.r
        M = self.M
        g = self.ground
        # ground and pits
        for x in range(W):
            if x in self.pit:
                self.put(x, 6, 'haz' if x % 2 else 'haz2')
                continue
            for row in range(g[x], 7):
                if M[row][x] != 'sky':
                    continue
                if row == g[x]:
                    if x in self.spikes:
                        self.put(x, row, 'spike')
                        continue
                    left = g[x - 1] if x > 0 and (x - 1) not in self.pit else 9
                    right = g[x + 1] if x < W - 1 and (x + 1) not in self.pit else 9
                    self.put(x, row, 'top_l' if left > g[x] else 'top_r' if right > g[x] else 'top')
                else:
                    self.put(x, row, r.choice(['fill'] * 6 + ['fill2', 'fill3']))
        # decorations: only on plain ground away from set pieces
        def free(x, row):
            return 0 <= row < 7 and M[row][x] == 'sky'
        for x in range(3, ARENA - 6):
            if x in self.reserved or x in self.pit or x in self.spikes:
                continue
            if any(k in self.pit or k in self.reserved for k in (x - 1, x + 1)):
                continue
            gy = g[x]
            roll = r.random()
            if roll < 0.08 and self.n == 5 and free(x, gy - 1):
                self.put(x, gy - 1, 'deco_b')            # stalagmite
            elif roll < 0.08 and all(free(x, gy - k) for k in (1, 2, 3)) and gy - 4 >= 0:
                self.put(x, gy - 1, 'deco_b'); self.put(x, gy - 2, 'deco_m')
                self.put(x, gy - 3, 'deco_m'); self.put(x, gy - 4, 'deco_t')
            elif roll < 0.12 and x > 20 and free(x, gy - 1) and free(x, gy - 2) and x not in self.cps:
                self.put(x, gy - 1, 'sm_b'); self.put(x, gy - 2, 'sm_t')
                self.reserved.add(x)
            elif roll < 0.16 and x > 14 and free(x, gy - 1) and x not in self.cps:
                self.put(x, gy - 1, 'small')
                self.reserved.add(x)
            elif roll < 0.26 and free(x, gy - 1):
                self.put(x, gy - 1, 'deco2')
        # boss arena
        for x in range(ARENA, W):
            g[x] = 5
            self.pit.discard(x)
            for row in range(0, 5):
                self.put(x, row, 'sky')
            self.put(x, 5, 'top'); self.put(x, 6, 'fill')
        for x in (ARENA, W - 1):
            for row in range(1, 5):
                self.put(x, row, 'column')
            self.put(x, 0, 'roof_m')
        # make sure the checkpoint columns are plain ground
        for i, cp in enumerate(self.cps):
            while cp in self.pit or cp in self.spikes or M[g[cp] - 1][cp] not in ('sky',):
                cp += 1
            self.cps[i] = cp
        self.populate()

    def populate(self):
        r = self.r
        n = self.n
        g = self.ground
        density = {2: 8, 3: 7, 4: 7, 5: 6, 6: 6, 7: 5}[n]   # columns between enemies
        safe = set()
        for cp in self.cps:
            safe.update(range(cp - 3, cp + 6))
        safe.update(range(0, 16))
        # per-section enemies
        for (a, b, kind) in self.sections:
            if a < 16:
                continue
            mid = (a + b) // 2
            if kind in ('pit', 'longpit', 'floaters'):
                self.enemy(mid, 'flyer', r.choice([4, 8, 12]))
                if kind != 'pit':
                    self.enemy(b - 2, 'diver', 8)
            elif kind == 'hill':
                self.enemy(mid, 'tough', 24)
                self.enemy(b - 1, 'walker')
            elif kind in ('building', 'rooftops'):
                self.enemy(a + 2, 'spitter', 16)
                self.enemy(b, 'walker')
            elif kind in ('upper', 'rampart'):
                self.enemy(mid, 'floater', 8)
                self.enemy(b - 1, 'tough')
            elif kind == 'toadstools':
                self.enemy(a + 5, 'diver', 2)
                self.enemy(b, 'walker')
            elif kind == 'cavern':
                self.enemy(a + 2, 'flyer', 10)
                self.enemy(b - 2, 'walker')
            elif kind == 'steps':
                self.enemy(a + 7, 'spitter', 16)
            elif kind == 'spikes':
                self.enemy(b, 'diver', 8)
            elif kind == 'flat' and b - a >= 4 and a not in safe:
                self.enemy(mid, r.choice(['walker', 'walker', 'floater', 'flyer']),
                           None if True else 0)
        # extra walkers on long stretches, density by stage
        last = 0
        for (c, y, t, p) in sorted(self.objs):
            last = c
        # zombie (walker) ambush zones
        self.o(36, 'zzone', 10)
        self.o(118, 'zzone', 12)
        # mini-boss before the second checkpoint
        self.enemy(self.cps[1] - 12, 'mini', 4)
        # chests: weapon on the main path, armour in the secret
        weap = ['dagger', 'axe', 'torchw', 'lance']
        main_chest = [c for (a, b, k) in self.sections if k in ('building', 'rooftops', 'hill')
                      for c in [a + 2]]
        if main_chest:
            c = main_chest[0]
            self.o(c, 'chest', IT[weap[n % 4]], self.surface(c))
        if len(main_chest) > 1:
            c = main_chest[-1]
            self.o(c, 'chest', IT[weap[(n + 1) % 4]], self.surface(c))
        if hasattr(self, 'secret_at'):
            self.o(self.secret_at, 'chest', IT['armour'], 16)
        # a potion and a jewel somewhere high
        highs = [(c, r_) for c in range(20, ARENA - 4) for r_ in (2, 3)
                 if self.M[r_][c] == 'plat' and self.M[r_ - 1][c] == 'sky']
        r.shuffle(highs)
        for (c, r_), kind in zip(highs[:2], ('potion', 'jewel')):
            self.coin(c, r_ * 8 - 9, kind)
        self.o(self.cps[0], 'checkpt')
        self.o(self.cps[1], 'checkpt')
        self.coin(ARENA - 3, 20, 'heart')
        self.o(160, 'boss', 0, 0)
        for (c, row) in [(30, 1), (90, 1), (ARENA + 1, 0), (W - 2, 0)]:
            self.o(c, 'torch', 0, row * 8)
        # drop enemies in the safe zones or inside walls; fix ground enemies' y
        out = []
        for (c, y, t, p) in self.objs:
            if t in (1, 2, 3, 4, 5, 7) and c in safe:
                continue
            if t in (1, 2, 7):           # stands on something
                if c in self.pit and t == 1:
                    continue
                y = self.surface(c)
                if c in self.pit and y >= 48:
                    continue
            out.append([c, y, t, p])
        self.objs = sorted(out)


SOLIDISH = {'top', 'top_l', 'top_r', 'fill', 'fill2', 'fill3', 'block', 'block_top', 'sm_t', 'sm_b',
            'small', 'roof_l', 'roof_m', 'roof_r', 'pillar', 'plat', 'plat_post', 'spike'}


def check(L, attr):
    """returns (ok, report) using the hero movement model"""
    w = World(L.M, attr, W)
    stands, touched, hz = explore(w, (16, 24), (8, W * 8 - 16))
    report = []
    tr = traps(w, hz, (8, W * 8 - 16))
    if tr:
        report.append('trap at columns %s' % sorted({x // 8 for x, y in tr}))
    arena = any(x >= (ARENA + 2) * 8 for (x, y) in stands)
    if not arena:
        far = max(x for x, y in stands) // 8
        report.append('arena unreachable (got to column %d)' % far)
    for (c, y, t, p) in L.objs:
        if t == OT['checkpt']:
            if not can_touch(touched, c * 8 + 2, y - 8, 4, 8):
                report.append('checkpoint %d unreachable' % c)
        if t == OT['chest']:
            if not can_touch(touched, c * 8, y - 9, 12, 9):
                report.append('chest %d unreachable' % c)
        if t == OT['item']:
            if not can_touch(touched, c * 8, y, 8, 7):
                report.append('item %d,%d unreachable' % (c, y))
    return arena, report, stands, touched


def build(n, attr, tries=40):
    """build stage n, retrying seeds until the arena, checkpoints and chests
    are reachable without damage; unreachable loose items are removed"""
    best = None
    for k in range(tries):
        L = Level(n, 9000 + n * 101 + k)
        L.build()
        ok, rep, stands, touched = check(L, attr)
        hard = [x for x in rep if not x.startswith('item')]
        if ok and not hard:
            # drop items nobody can collect
            bad = {(int(x.split()[1].split(',')[0]), int(x.split()[1].split(',')[1]))
                   for x in rep if x.startswith('item')}
            L.objs = [o for o in L.objs if not (o[2] == OT['item'] and (o[0], o[1]) in bad)]
            L.report = rep
            L.seed = k
            L.stands = stands
            return L
        if best is None:
            best = (L, rep)
    raise SystemExit('stage %d: no fair layout in %d tries: %s' % (n, tries, best[1]))
