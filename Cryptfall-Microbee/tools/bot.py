"""Drive the real game in the Premium Plus model, one cave step at a time.

Used to prove every crypt can be cleared (tools/solve.py), to record the
attract-mode demo (tools/mkdemo.py) and for the mechanics tests.

A solution is a string of moves:
    R L U D        one step right / left / up / down     (R5 = five steps)
    r l u d        reach that way without stepping (SPACE + arrow)
    w              wait a step                            (w10)
    @x,y           walk to tile x,y (shortest way through earth and space)
    ~x,y           the same, but waiting first if going at once gets him killed
    S              wait until the slime has set
    !              collect gems by itself until the gate is open
    X              walk to the gate
"""
import sys
from collections import deque
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from emu import cold_boot, tap, peek, peekw, poke, shot

import tiles as TL
T = dict(TL.T)
T['DIRT'] = T['DIRT1']
PICK = {i for i, (n, c, a, f) in enumerate(TL.TILES) if f & TL.F_PICKUP}
GEMS = {T['GEM'], T['RUBY'], T['EMERALD']}
WALK = {i for i, (n, c, a, f) in enumerate(TL.TILES) if n.startswith('DIRT')} | {T['SPACE'], T['EXITO']}
KEYS = {'R': ['RIGHT'], 'L': ['LEFT'], 'U': ['UP'], 'D': ['DOWN'],
        'r': ['RIGHT', 'SPACE'], 'l': ['LEFT', 'SPACE'], 'u': ['UP', 'SPACE'], 'd': ['DOWN', 'SPACE'], 'w': []}
PADBIT = {'RIGHT': 1, 'LEFT': 2, 'UP': 4, 'DOWN': 8, 'SPACE': 16}
DELTA = {'R': (1, 0), 'L': (-1, 0), 'U': (0, -1), 'D': (0, 1)}
CAVE = 0xA000
TRANSIENT = {i for i, (n, c, a, f) in enumerate(TL.TILES) if n.endswith('F') or 'EXPL' in n or f & TL.F_ENEMY or n in ('KEGLIT', 'SLIME')}


class Dead(Exception):
    pass


class Game:
    def __init__(self, cave=0, disk=None, pp=None, press=True):
        self.pp = pp or cold_boot(disk)
        pp = self.pp
        if press:
            pp.run_frames(60)               # the title is up
            poke(pp, 'start_cave', cave)
            tap(pp, 'SPACE', 4, 2)
        self.wait_start()

    def wait_start(self):
        pp = self.pp
        self.log = []                       # the pad value of every step
        self.skipped = []
        for i in range(600):                # the cave is revealed, Mort appears
            pp.run_frames(1)
            if peek(pp, 'p_alive') and peek(pp, 'gstate') == 1:
                break
        else:
            raise RuntimeError('the cave did not start')
        t = peekw(pp, 'tick_no')            # let the step that brought him in finish
        for i in range(40):
            pp.run_frames(1)
            if peekw(pp, 'tick_no') != t:
                break
        self.log = [0] * peekw(pp, 'tick_no')   # the steps before he could move

    # ---- state
    def grid(self):
        pp = self.pp
        w, h = peek(pp, 'cave_w'), peek(pp, 'cave_h')
        blk0 = pp.blocks[0]
        return [[int(blk0[CAVE - 0x8000 + y * 64 + x]) & 0x7F for x in range(w)] for y in range(h)]

    def pos(self):
        p = peekw(self.pp, 'p_ptr') - CAVE
        return p % 64, p // 64

    def v(self, name):
        return peek(self.pp, name)

    def time(self):
        return peekw(self.pp, 'time')

    def score(self):
        return int(bytes(peek(self.pp, 'score', 3)).hex()) * 10

    def alive(self):
        return self.v('p_alive') and not self.v('p_dead')

    def done(self):
        return bool(self.v('cave_done'))

    # ---- acting
    def step(self, move='w'):
        """hold the keys for exactly one cave step"""
        pp = self.pp
        keys = KEYS[move]
        pp.keys = keys
        t = peekw(pp, 'tick_no')
        for i in range(40):
            pp.run_frames(1)
            if peekw(pp, 'tick_no') != t:
                break
        else:
            raise RuntimeError('no cave step (state %d)' % self.v('gstate'))
        self.log.append(sum(PADBIT[k] for k in keys))
        if self.v('p_dead'):
            pp.keys = []
            raise Dead('Mort died at %s on step %d' % (self.pos(), len(self.log)))

    def release(self):
        self.pp.keys = []

    def path(self, goal, grid=None, avoid=()):
        """shortest way to goal through earth, space and pickups"""
        g = grid or self.grid()
        x0, y0 = self.pos()
        keys_n = self.v('keys_n')
        ok = WALK | PICK
        if keys_n:
            ok.add(T['DOOR'])
        prev = {(x0, y0): None}
        q = deque([(x0, y0)])
        while q:
            x, y = q.popleft()
            if (x, y) == goal:
                out = []
                while prev[(x, y)]:
                    (x, y), m = prev[(x, y)]
                    out.append(m)
                return out[::-1]
            for m, (dx, dy) in DELTA.items():
                nx, ny = x + dx, y + dy
                if (nx, ny) in prev or (nx, ny) in avoid:
                    continue
                if g[ny][nx] in ok:
                    prev[(nx, ny)] = ((x, y), m)
                    q.append((nx, ny))
        return None

    def reach_order(self, g):
        """every cell Mort can walk to, nearest first"""
        x0, y0 = self.pos()
        ok = WALK | PICK
        if self.v('keys_n'):
            ok = ok | {T['DOOR']}
        seen = {(x0, y0)}
        q = deque([(x0, y0)])
        out = []
        while q:
            x, y = q.popleft()
            out.append((x, y))
            for dx, dy in DELTA.values():
                n = (x + dx, y + dy)
                if n not in seen and g[n[1]][n[0]] in ok:
                    seen.add(n)
                    q.append(n)
        return out

    def goto(self, goal, limit=400):
        blocked = 0
        for i in range(limit):
            if self.pos() == goal or self.done():
                return
            p = self.path(goal)
            if p is None:
                blocked += 1                # a haunter in the way? give it time
                if blocked > 60:
                    raise RuntimeError('no way from %s to %s' % (self.pos(), goal))
                self.step('w')
                continue
            self.step(p[0])
        raise RuntimeError('did not reach %s' % (goal,))

    def find(self, tile):
        g = self.grid()
        return [(x, y) for y, r in enumerate(g) for x, t in enumerate(r) if t == tile]

    def run(self, script, explore=False):
        """[ ... ] is a contraption being worked: if it goes wrong it is
        taken back and left alone"""
        import re
        for grp in re.findall(r'\[[^\]]*\]|[^\[\]]+', script):
            if grp[0] != '[':
                self._run(grp, explore)
                continue
            pp = self.pp
            snap, n = pp.snap(), len(self.log)
            try:
                self._run(grp[1:-1], explore)
                for i in range(3):
                    self.step('w')
                pp.snap_free(snap)
            except (Dead, RuntimeError) as e:
                self.skipped.append(grp)
                pp.restore(snap)
                pp.snap_free(snap)
                del self.log[n:]
        self.release()

    def _run(self, script, explore=False):
        import re
        for tok in re.findall(r'[@~]\d+,\d+|[RLUDrludw]\d*|!|X|S', script):
            if self.done():
                break
            if tok[0] == '@':
                x, y = tok[1:].split(',')
                self.goto((int(x), int(y)))
            elif tok[0] == '~':
                x, y = tok[1:].split(',')
                self.safe_goto((int(x), int(y)))
            elif tok == 'S':
                for i in range(900):
                    if not self.find(T['SLIME']):
                        break
                    self.step('w')
                else:
                    raise RuntimeError('the slime never set')
            elif tok == '!':
                self.auto_collect(explore=explore)
            elif tok == 'X':
                e = self.find(T['EXITO'])
                if not e:
                    raise RuntimeError('the gate is not open (%d of %d gems)' % (self.v('gems'), self.v('quota')))
                self.safe_goto(e[0])
            else:
                n = int(tok[1:] or 1)
                for i in range(n):
                    if self.done():
                        break
                    self.step(tok[0])

    # ---- playing by itself: nearest gem first, taking a move back when it kills
    DELAYS = (0, 2, 5, 9, 14, 20, 27, 35, 44)

    def _try(self, tgt, delay):
        """wait, walk to tgt, then stand a moment to see nothing lands on him"""
        for i in range(delay):
            self.step('w')
        have = self.v('gems') + self.v('keys_n')
        for i in range(250):
            if self.v('gems') + self.v('keys_n') > have or self.pos() == tgt:
                break
            p = self.path(tgt)
            if p is None:
                raise Dead('lost the way')
            self.step(p[0])
        else:
            raise Dead('too far')
        pp = self.pp
        s2 = pp.snap()
        n2 = len(self.log)
        try:
            for i in range(4):
                self.step('w')
        finally:
            pp.restore(s2)
            pp.snap_free(s2)
            del self.log[n2:]

    def auto_collect(self, budget=6000, explore=False):
        """greedy with roll-back: go for the nearest gem; if that gets Mort
        killed, go back and try it again after a wait (haunters move on),
        then the next nearest gem, then an earlier choice"""
        pp = self.pp
        stack = []                           # (snapshot, log length, banned targets, target)
        banned = set()
        waits = 0
        tries = 0
        while self.v('gems') < self.v('quota'):
            tries += 1
            if tries > budget:
                raise RuntimeError('ran out of patience')
            g = self.grid()
            gems = [(x, y) for y, r in enumerate(g) for x, t in enumerate(r) if t in GEMS]
            order = self.reach_order(g)
            cands = [(0, t) for t in order if g[t[1]][t[0]] in GEMS and t not in banned]
            if not cands and not self.v('keys_n'):          # no gem to be had: is there a key?
                cands = [(0, t) for t in order if g[t[1]][t[0]] == T['KEY'] and t not in banned]
            if not cands:
                moving = any(t in TRANSIENT for r in g for t in r)
                if moving and waits < 120 and not banned:
                    try:
                        self.step('w')
                        waits += 1
                        continue
                    except Dead:
                        pass
                if explore:
                    break
                if not stack:
                    raise RuntimeError('stuck with %d of %d gems at %s' % (self.v('gems'), self.v('quota'), self.pos()))
                snap, n, ban, tgt = stack.pop()
                pp.restore(snap)
                pp.snap_free(snap)
                del self.log[n:]
                banned = ban | {tgt}
                waits = 0
                continue
            _, tgt = cands[0]
            snap = pp.snap()
            n = len(self.log)
            ok = False
            for d in self.DELAYS:
                try:
                    self._try(tgt, d)
                    ok = True
                    break
                except Dead:
                    pp.restore(snap)
                    del self.log[n:]
            if ok:
                stack.append((snap, n, set(banned), tgt))
                banned = set()
                waits = 0
            else:
                pp.snap_free(snap)
                banned.add(tgt)
        for snap, n, ban, tgt in stack:
            pp.snap_free(snap)

    def safe_goto(self, goal):
        """goto, taken back and retried after a wait if it kills"""
        pp = self.pp
        snap = pp.snap()
        n = len(self.log)
        for d in self.DELAYS + (55, 70, 90):
            try:
                for i in range(d):
                    self.step('w')
                self.goto(goal)
                s2, n2 = pp.snap(), len(self.log)
                try:
                    if not self.done():
                        for i in range(3):
                            self.step('w')
                finally:
                    pp.restore(s2)
                    pp.snap_free(s2)
                    del self.log[n2:]
                pp.snap_free(snap)
                return
            except Dead:
                pp.restore(snap)
                del self.log[n:]
        raise Dead('no safe way to %s' % (goal,))

    def finish(self):
        """after the gate: wait for the tally to end.  -> the cave the game moved on to"""
        pp = self.pp
        self.release()
        c = peek(pp, 'cave_no')
        for i in range(3000):
            pp.run_frames(1)
            if peek(pp, 'cave_no') != c or pp.cpu.pc == 0:
                break
        return peek(pp, 'cave_no')


def rle(log):
    out = bytearray()
    i = 0
    while i < len(log):
        j = i
        while j < len(log) and log[j] == log[i] and j - i < 255:
            j += 1
        out += bytes([log[i], j - i])
        i = j
    return bytes(out)
