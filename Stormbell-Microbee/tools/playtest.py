"""Play STORMBELL in the emulator, from the CP/M boot to the ending.

A scripted player presses the real keys (D A S K L, SPACE) by reading
the duel off the game's memory the way a person reads the screen:
how far apart the fighters are, and whether the opponent is winding up,
striking or recovering.

    python3 tools/playtest.py [outdir] [--style good|masher|idle] [--stage N]

It reports every duel (won or lost, health left, ticks taken) and saves
screenshots along the way.
"""
import sys
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import boottest as T
import bootrom
import syms as SY

ROOT = HERE.parent
ST = dict(IDLE=0, STEP=1, GUARD=2, ATK=3, HIT=4, BLOCKED=5, FALL=6, DOWN=7, BOW=8, STAND=9)
F = dict(X=0, FR=1, ST=4, T=5, PH=6, ATK=7, HP=8, MAX=9)


class Game:
    def __init__(self, out, style='good'):
        self.out = Path(out)
        self.out.mkdir(exist_ok=True)
        self.S = SY.load(ROOT / 'build' / 'main.sym')
        self.name = SY.namer(self.S)
        self.style = style
        self.pp = T.boot()
        self.log = []
        self.shots = 0
        self.hist = []
        self.react = 0
        self.mono = False

    def f(self, who, field):
        return self.pp.peek(self.S[who] + F[field])

    def var(self, n):
        return self.pp.peek(self.S[n])

    def press(self, keys, frames=3, gap=2):
        self.pp.keys = set(keys)
        self.pp.run_frames(frames)
        self.pp.keys = set()
        self.pp.run_frames(gap)

    def shot(self, tag):
        self.shots += 1
        p = self.out / ('%02d_%s.png' % (self.shots, tag))
        self.pp.png(str(p), scale=2, aspect=0.92, mono=self.mono)
        return p

    def in_fight(self):
        pc = self.pp.cpu.pc
        return self.var('msg_t') >= 0 and self.f('hero', 'ST') in (0, 1, 2, 3, 4, 5)

    # ---- the player
    def ranges(self):
        rp = self.pp.peekw(self.S['rangep'])
        return [self.pp.peek(rp + i) for i in range(4)]

    def snapshot(self):
        return dict(gap=self.f('foe', 'X') - self.f('hero', 'X'), fst=self.f('foe', 'ST'), fph=self.f('foe', 'PH'),
                    fatk=self.f('foe', 'ATK'), ft=self.f('foe', 'T'))

    def decide(self):
        """keys to hold this tick: what the player saw REACT ticks ago"""
        self.hist.append(self.snapshot())
        seen = self.hist[max(0, len(self.hist) - 1 - self.react)]
        gap = self.f('foe', 'X') - self.f('hero', 'X')     # where things are, they can see
        hp, hk, fp, fk = self.ranges()
        fst, fph, fatk, ft = seen['fst'], seen['fph'], seen['fatk'], seen['ft']
        hst = self.f('hero', 'ST')
        if self.style == 'idle':
            return set()
        if self.style == 'masher':
            return {'D', ['K', 'L'][self.pp.frames // 4 % 2]}
        foe_reach = fk if fatk else fp
        # the foe is winding up and we are in its reach: guard (or step out)
        if fst == ST['ATK'] and fph == 0 and gap <= foe_reach + 1:
            return {'S'}
        if fst == ST['ATK'] and fph == 1 and gap <= foe_reach:
            return {'S'}
        if hst == ST['GUARD'] and fst == ST['ATK'] and fph < 2:
            return {'S'}
        # the foe is open: recovering, recoiling or staggered
        open_ = (fst == ST['ATK'] and fph == 2) or fst == ST['BLOCKED'] or fst == ST['IDLE'] and self.var('ticks') % 37 < 6
        if open_:
            if gap <= hp:
                return {'K'}
            if gap <= hk:
                return {'L'}
            return {'D'}
        # otherwise hover just outside its reach
        if gap > max(fp, fk) + 2:
            return {'D'}
        if gap <= max(fp, fk) - 1 and fst not in (ST['STEP'],):
            return {'A'}
        return set()

    def fight(self, max_ticks=3000):
        """play one duel to its end -> 'won' / 'lost'"""
        t0 = self.var('ticks')
        n = 0
        last_attack = set()
        shot_at = {40, 200}
        while n < max_ticks:
            hst, fst = self.f('hero', 'ST'), self.f('foe', 'ST')
            if fst == ST['DOWN'] or hst == ST['DOWN']:
                self.pp.run_frames(50)
                return ('won' if fst == ST['DOWN'] else 'lost'), n
            keys = self.decide()
            # attack keys are taps: never hold one from one tick into the next
            if keys & {'K', 'L'}:
                if keys & last_attack:
                    keys = keys - {'K', 'L'}
            last_attack = keys & {'K', 'L'}
            self.pp.keys = keys
            self.pp.run_frames(2)
            n += 1
            if n in shot_at:
                self.shot('stage%d_t%d' % (self.var('stage') + 1, n))
        return 'timeout', n

    def wait_fight_start(self, limit=1500, shots=None):
        """hold advance (to run along the road) until the duel begins"""
        for i in range(limit):
            self.pp.keys = {'D'}
            self.pp.run_frames(2)
            if shots and i in shots:
                self.shot(shots[i])
            if self.f('hero', 'ST') == ST['IDLE'] and self.f('foe', 'ST') in (0, 1) and self.f('hero', 'HP') > 0:
                self.pp.keys = set()
                return True
        self.pp.keys = set()
        return False


def main():
    args = sys.argv[1:]
    out = args[0] if args and not args[0].startswith('--') else str(ROOT / 'screenshots' / 'playtest')
    style = args[args.index('--style') + 1] if '--style' in args else 'good'
    g = Game(out, style)
    g.react = int(args[args.index('--react') + 1]) if '--react' in args else 5
    pp = g.pp
    T.launch(pp, 700)
    if '--mono' in args:
        # M on the title: the scenery for a monochrome monitor
        g.press({'M'}, frames=6)
        pp.run_frames(150)
        g.mono = True
        assert pp.peek(g.S['mono']) == 1, 'M did not switch to mono'
        print('mono: on')
    g.shot('title')
    g.press({'SPACE'})
    results = []
    retries = 0
    while True:
        if not g.wait_fight_start():
            print('the duel never started; pc', g.name(pp.cpu.pc))
            break
        stage = g.var('stage') + 1
        res, n = g.fight()
        hp, fhp = g.f('hero', 'HP'), g.f('foe', 'HP')
        print('stage %d: %-7s in %4d ticks (%5.1f s)  Wren %2d/12  foe %2d' % (stage, res, n, n / 25.0, hp, fhp))
        results.append((stage, res, n, hp))
        if res == 'won':
            g.shot('stage%d_won' % stage)
            if stage == 5:
                pp.run_frames(400)
                g.shot('ending')
                print('ENDING reached; pc', g.name(pp.cpu.pc))
                break
            pp.run_frames(150)
            g.shot('stage%d_intro' % (stage + 1))
        elif res == 'lost':
            g.shot('stage%d_lost' % stage)
            retries += 1
            if retries > 12 or style != 'good':
                break
            g.press({'SPACE'})
        else:
            print('timeout')
            break
    print('retries', retries)
    return results


if __name__ == '__main__':
    main()
