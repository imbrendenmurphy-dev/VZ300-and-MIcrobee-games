"""A bot that plays RUNE AMOK in the emulator model through the keyboard,
reading the game's memory to find its way (the whole-game test).

    py tools/bot.py OUTDIR       plays all four levels, screenshots + log
"""
import sys
from collections import deque
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import rd
import levels as LV

MAP, MONMAP, ITEMMAP = 0xC800, 0xCC00, 0xD000
FWD = [(0, -1), (1, 0), (0, 1), (-1, 0)]
PASS = {0, 6, 16, 17, 18, 19, 20, 21, 22}
OPENABLE = {3, 8, 9, 10, 5}


class Bot:
    def __init__(self, out):
        self.out = Path(out)
        self.out.mkdir(parents=True, exist_ok=True)
        self.pp = rd.boot()
        self.n = 0
        self.log = []
        self.frames = 0

    # ---- state
    def v(self, name, n=1):
        return rd.var(self.pp, name, n)

    def pos(self):
        o = self.v('ppos', 2) - MAP
        return (o & 31) - 8, (o >> 5) - 8

    def sq(self, x, y, base=MAP):
        return self.pp.peek(base + (y + 8) * 32 + x + 8)

    def idle(self, maxf=200):
        for _ in range(maxf):
            self.pp.run_frames(1)
            self.frames += 1
            if self.v('cm_state') == 0:
                break

    def key(self, k, hold=2, after=4):
        self.pp.keys = {k}
        self.pp.run_frames(hold)
        self.pp.keys = set()
        self.pp.run_frames(after)
        self.frames += hold + after
        self.idle()

    def shot(self, name):
        self.n += 1
        rd.shot(self.pp, self.out / ('%03d_%s.png' % (self.n, name)))

    def text(self):
        b = [self.pp.peek(0xE100 + i) for i in range(6 * 24)]
        return [bytes(b[i * 24:i * 24 + 24]).decode('ascii', 'replace').rstrip() for i in range(6)]

    def note(self, s):
        st = 'L%d (%d,%d) f%d hp %d/%d lv %d xp %d gold %d' % (self.v('level') + 1, *self.pos(), self.v('facing'),
                                                                   self.v('hp'), self.v('hpmax'), self.v('lvl'),
                                                                   self.v('xp', 2), self.v('gold', 2))
        line = '%-40s %s' % (s, st)
        self.log.append(line)
        print(line)

    # ---- moving
    def face(self, d):
        f = self.v('facing')
        if (f + 1) % 4 == d:
            self.key('RIGHT')
        elif (f + 3) % 4 == d:
            self.key('LEFT')
        elif f != d:
            self.key('RIGHT')
            self.key('RIGHT')

    def survive(self):
        if self.v('dead'):
            self.note('DIED - rising again')
            self.shot('dead')
            self.pp.run_frames(30)
            self.key('Y')
            self.pp.run_frames(60)
            return True
        if self.v('hp') < self.v('hpmax') // 3 and self.v('potions') > 0:
            self.key('3')
            self.note('drank a potion')
        elif self.v('hp') < self.v('hpmax') // 2 and self.v('spells') & 2 and self.v('mp') >= 4:
            self.key('2')
            self.note('cast mend')
        return False

    def path(self, goal, avoid_mons=False):
        start = self.pos()
        prev = {start: None}
        q = deque([start])
        while q:
            p = q.popleft()
            if p == goal:
                break
            for d, (dx, dy) in enumerate(FWD):
                n = (p[0] + dx, p[1] + dy)
                if n in prev or not (0 <= n[0] < 16 and 0 <= n[1] < 16):
                    continue
                t = self.sq(*n)
                if t in PASS or t in OPENABLE or n == goal:
                    if t in (16, 17, 18, 20) and n != goal:
                        continue        # no stairs, pits, portals or spinners on the way
                    mi = self.pp.peek(MONMAP + (n[1] + 8) * 32 + n[0] + 8)
                    if mi and self.pp.peek(0xD900 + 16 * (mi - 1)) == 9 and n != goal:
                        continue        # walk round the trader
                    prev[n] = p
                    q.append(n)
        if goal not in prev:
            return None
        out = []
        p = goal
        while prev[p] is not None:
            out.append(p)
            p = prev[p]
        return out[::-1]

    def goto(self, x, y, tries=400):
        for _ in range(tries):
            if self.survive():
                return False
            if self.pos() == (x, y):
                return True
            lvl = self.v('level')
            p = self.path((x, y))
            if not p:
                self.note('NO PATH to (%d,%d)' % (x, y))
                if getattr(self, 'dumped', -1) != self.v('level'):
                    self.dumped = self.v('level')
                    for yy in range(16):
                        print('   ', ' '.join('%2d' % self.sq(xx, yy) for xx in range(16)))
                return False
            nx, ny = p[0]
            cx, cy = self.pos()
            d = FWD.index((nx - cx, ny - cy))
            self.face(d)
            if self.pp.peek(MONMAP + (ny + 8) * 32 + nx + 8):
                self.key('SPACE')
                continue
            t = self.sq(nx, ny)
            if t in OPENABLE:
                self.key('SPACE')
                if self.sq(nx, ny) in OPENABLE:
                    self.note('cannot open (%d,%d) type %d' % (nx, ny, t))
                    return False
                continue
            self.key('UP')
            if self.v('level') != lvl:
                return True
        self.note('gave up on (%d,%d)' % (x, y))
        return False

    def use(self, x, y, side):
        dx, dy = FWD[side]
        for _ in range(4):
            if not self.goto(x + dx, y + dy):
                return False
            self.face((side + 2) % 4)
            if self.pos() == (x + dx, y + dy) and self.v('facing') == (side + 2) % 4:
                self.key('SPACE')
                self.note('used (%d,%d) side %d, runestep %d' % (x, y, side, self.v('runestep')))
                return True
            self.note('not in place for (%d,%d): retry' % (x, y))
        return False

    def fight_all(self, radius=99):
        """hunt every monster on the level (not the trader)"""
        for _ in range(40):
            best = None
            for i in range(self.v('nmons')):
                a = 0xD900 + 16 * i
                t = self.pp.peek(a)
                if t in (0xFF, 9):
                    continue
                o = self.pp.peek(a + 2) | (self.pp.peek(a + 3) << 8)
                mx, my = (o & 31) - 8, (o >> 5) - 8
                p = self.path((mx, my))
                if p and (best is None or len(p) < best[0]):
                    best = (len(p), mx, my)
            if not best or best[0] > radius:
                return
            self.goto(best[1], best[2])


def play_level1(b):
    b.shot('start')
    b.goto(3, 1)
    b.face(1)
    b.shot('torch_corridor')
    b.fight_all(radius=12)
    b.goto(11, 3)
    b.note('bronze key: %d' % b.pp.peek(b.pp.S['keys']))
    b.use(6, 9, LV.E)
    b.note('lever pulled')
    b.shot('lever')
    b.goto(9, 10)
    b.face(1)
    b.shot('gate_open')
    b.use(0, 11, LV.E)
    b.note('button pressed')
    b.goto(2, 13)
    b.goto(1, 14)
    b.goto(13, 11)
    b.note('sigils %d' % b.v('sigils'))
    b.shot('sigil')
    b.fight_all()
    b.goto(14, 14)


def play_level2(b):
    b.pp.run_frames(40)
    b.shot('l2_start')
    b.fight_all(radius=10)
    b.goto(1, 1)
    b.goto(3, 1)
    b.note('silver key: %d' % b.pp.peek(b.pp.S['keys'] + 1))
    b.use(10, 13, LV.W)
    b.note('button: gate')
    b.goto(7, 13)
    b.use(6, 14, LV.N)
    b.note('lever: hidden wall')
    b.goto(1, 14)
    b.note('sigils %d' % b.v('sigils'))
    b.shot('l2_sigil')
    b.goto(11, 6)
    b.face(2)
    b.shot('l2_trader')
    b.fight_all()
    b.goto(14, 9)


def play_level3(b):
    b.pp.run_frames(40)
    b.shot('l3_start')
    b.fight_all(radius=8)
    b.goto(6, 2)
    b.use(0, 10, LV.E)
    b.note('rune flame')
    b.use(3, 0, LV.S)
    b.note('rune wave')
    b.use(7, 15, LV.N)
    b.note('rune stone')
    b.use(9, 5, LV.S)
    b.note('rune star')
    b.shot('l3_runes')
    b.goto(1, 12)
    b.goto(13, 14)
    b.note('sigils %d' % b.v('sigils'))
    b.shot('l3_vault')
    b.goto(14, 14)


def play_level4(b):
    b.pp.run_frames(40)
    b.shot('l4_start')
    b.fight_all(radius=12)
    b.use(8, 6, LV.S)
    b.note('the seal')
    b.shot('l4_seal')
    for _ in range(3):
        b.fight_all()
        if b.v('won'):
            break
    b.note('won %d' % b.v('won'))
    b.shot('l4_end')


def main():
    b = Bot(sys.argv[1] if len(sys.argv) > 1 else 'build/bot')
    b.pp.run_frames(150)
    b.shot('title')
    b.key('SPACE')
    b.pp.run_frames(60)
    play_level1(b)
    b.note('end of level 1 script')
    if '--l3' in sys.argv:
        play_level2(b)
        play_level3(b)
        return
    for f in (play_level2, play_level3, play_level4):
        f(b)
        b.note('end of %s' % f.__name__)
    for l in b.text():
        print('  |', l)
    (b.out / 'log.txt').write_text('\n'.join(b.log))


if __name__ == '__main__':
    main()
