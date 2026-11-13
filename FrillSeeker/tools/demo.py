"""Record the attract sequence's demonstrations: Bluff played by a pilot
that reads the game's own variables in the Premium Plus model and holds
the pad, a frame at a time. The game runs in its recording mode (demo =
2: the pad comes from dm_pad, dm_n counts the ticks), and what the pilot
held, tick for tick, is written to demos/regionN.txt as "pad ticks"
lines. The game plays that back (demo = 1) and, since everything in it
happens in ticks from a fixed start, plays the same game.

    python3 tools/demo.py [region ...]      record, check, save
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image
import run as emu

ROOT = Path(__file__).resolve().parent.parent
R, L, F, D, J = 1, 2, 4, 8, 16


class Bot:
    def __init__(self, region, mono=False, shots=None):
        pp = emu.title(mono)
        S = pp.S
        pp.keys = []
        pp.out(0x50, emu.blk_port(1))
        pp.poke(S['region'], region)
        pp.cpu.pc = S['demo_rec']
        self.pp, self.S, self.mono = pp, S, mono
        self.log = []           # (pad, ticks)
        self.frames = 0
        self.shots = shots
        self.ims = []
        self.step(0, 2)

    def v(self, name, w=False):
        return self.pp.peekw(self.S[name]) if w else self.pp.peek(self.S[name])

    @property
    def x(self):
        return self.v('hx', True)

    @property
    def y(self):
        return self.v('hy', True)

    @property
    def on(self):
        return self.v('h_on')

    @property
    def vy(self):
        v = self.v('hvy', True)
        return v - 65536 if v >= 32768 else v

    @property
    def room(self):
        return self.v('room')

    def ents(self, typ):
        out = []
        for i in range(8):
            a = self.S['ENTS'] + 16 * i
            if self.pp.peek(a) == typ:
                out.append(dict(x=self.pp.peekw(a + 2), y=self.pp.peekw(a + 4), state=self.pp.peek(a + 1)))
        return out

    def step(self, pad, frames=1):
        for i in range(frames):
            self.pp.poke(self.S['dm_pad'], pad)
            n0 = self.v('dm_n', True)
            self.pp.run_frames(1)
            n = (self.v('dm_n', True) - n0) & 0xFFFF
            if n:
                if self.log and self.log[-1][0] == pad:
                    self.log[-1][1] += n
                else:
                    self.log.append([pad, n])
            self.frames += 1
            h = self.v('hearts')
            if h < getattr(self, 'h0', 3):
                print('   OUCH at x %d y %d: magpies %s goannas %s toads %s' % (self.x, self.y, self.ents(6), self.ents(7), self.ents(2)))
            self.h0 = h
            if self.shots and self.frames % 3 == 0:
                self.ims.append(emu.view(self.pp, self.mono).resize((336, 180), Image.NEAREST))

    def until(self, cond, pad, limit=400):
        for i in range(limit):
            if cond():
                return True
            self.step(pad)
        print('   (gave up: room %d x %d y %d)' % (self.room, self.x, self.y))
        return False

    def right_to(self, x, pad=R, limit=400):
        return self.until(lambda: self.x >= x, pad, limit)

    def left_to(self, x, pad=L, limit=400):
        return self.until(lambda: self.x <= x, pad, limit)

    def land(self, pad=0, limit=200):
        self.step(pad, 2)
        return self.until(lambda: self.on, pad, limit)

    def jump(self, pad=0, hold=14):
        """a jump: the button held for `hold` frames, then until he lands"""
        self.step(pad | J, hold)
        return self.land(pad)

    def note(self, what):
        print('%-30s room %2d  x %3d  y %3d  bugs %2d  hearts %d  ticks %d' % (
            what, self.room, self.x, self.y, self.v('bugs'), self.v('hearts'), sum(t for _, t in self.log)))

    def state(self):
        return (self.room, self.x, self.y, self.v('bugs'), self.v('hearts'), self.v('gtick'))

    def gif(self, path):
        fr = [im.convert('P', palette=Image.ADAPTIVE, colors=32) for im in self.ims]
        fr[0].save(path, save_all=True, append_images=fr[1:], duration=120, loop=0)

    def sheet(self, path, every=8, cols=6):
        ims = self.ims[::every]
        rows = (len(ims) + cols - 1) // cols
        sh = Image.new('RGB', (cols * 336, rows * 180))
        for i, im in enumerate(ims):
            sh.paste(im, ((i % cols) * 336, (i // cols) * 180))
        sh.save(path)


def tile(b, col, row):
    if not (0 <= col < 20 and 0 <= row < 11):
        return 0
    return b.pp.peek(b.S['TMAP'] + row * 20 + col)


def toad_ahead(b, way=1, reach=400):
    ts = [t for t in b.ents(2) if 0 < (t['x'] - b.x) * way < reach and abs(t['y'] - b.y) < 40]
    return min(ts, key=lambda t: abs(t['x'] - b.x)) if ts else None


def bluff(b, way=1):
    """walk up to the nearest toad ahead and frill it on to its back"""
    pad = R if way > 0 else L
    t = toad_ahead(b, way)
    if not t:
        return None
    b.until(lambda: abs(toad_ahead(b, way, 600)['x'] - b.x) < 56, pad)
    b.step(0, 4)
    b.until(lambda: any(e['state'] >= 2 for e in b.ents(2)), F, 60)
    b.step(F, 12)
    b.until(lambda: all(e['state'] != 2 for e in b.ents(2)), 0, 80)
    b.step(0, 6)
    ts = [t for t in b.ents(2) if t['state'] == 3 and (t['x'] - b.x) * way > 0]
    return min(ts, key=lambda t: abs(t['x'] - b.x)) if ts else None


def bounce(b, t, way=1, glide=True, air=None):
    """hop on to the belly of the toad at t and off it; under the frill on the
    way down if glide; air(b) -> the pad while he flies"""
    pad = R if way > 0 else L
    b.until(lambda: abs(t['x'] - b.x) <= 50, pad)
    b.step(pad | J, 3)
    hit = False
    for i in range(120):
        d = (t['x'] - b.x) * way
        steer = pad if d > 2 else 0
        b.step(steer | J if b.vy < 0 else steer)
        if b.vy < -1000:
            hit = True
            break
        if b.on:
            break
    if not hit:
        print('   (missed the toad)')
        return False
    for i in range(300):
        p = air(b) if air else pad
        if glide and b.vy > 60:
            p |= F
        b.step(p)
        if b.on:
            break
    return True


def run(b, to_x=None, way=1, limit=600, frill_toads=True, leave=False):
    """run on, jumping what is in the way; to to_x, or out of the room"""
    pad = R if way > 0 else L
    room = b.room
    for i in range(limit):
        if b.room != room:
            return True
        if to_x is not None and (b.x - to_x) * way >= 0:
            return True
        p = pad
        if b.on:
            if [m for m in magpie_near(b, 120) if m['state'] == 1]:
                b.until(lambda: not [m for m in b.ents(6) if m['state'] == 1], F, 40)
                b.step(F, 4)
                continue
            col = (b.x + 10 * way) // 16
            row = (b.y - 1) // 16
            ahead = tile(b, col, row)
            under = tile(b, (b.x + 12 * way) // 16, row + 1)
            if ahead == 1 or (under in (0, 3) and not b.v('h_spr')):
                b.step(p | J, 12)
                continue
            t = toad_ahead(b, way, 44)
            if t and t['state'] < 2 and frill_toads:
                b.step(0, 3)
                b.until(lambda: any(e['state'] >= 2 for e in b.ents(2)), F, 60)
                b.step(F, 8)
                continue
        b.step(p)
    print('   (run: out of time, room %d x %d y %d)' % (b.room, b.x, b.y))
    return False


# ---------------------------------------------------------------------
def red_dirt(b):
    b.step(0, 24)
    t = bluff(b)
    b.note('the bluff')
    bounce(b, t)
    b.note('bounced and glided')
    run(b)
    b.note('into the billabong')
    # Mound City: over the little mound, flip the toad, off its belly to the
    # ledge, from the ledge to the top of the tall mound, and float down
    run(b, 70)
    t = bluff(b)
    b.note('mound city: the bluff')
    ok = bounce(b, t, glide=False, air=lambda b: (R if b.x < 170 else (L if b.x > 180 else 0)))
    b.note('on the ledge' if ok and b.y == 64 else 'NOT on the ledge')
    b.step(0, 10)
    b.right_to(186)
    b.step(0, 6)
    b.step(J, 13)
    b.step(R | J, 4)
    b.until(lambda: b.on, R, 100)
    b.note('on the tall mound' if b.y == 32 else 'NOT on the mound')
    b.step(0, 20)
    b.step(F, 16)
    b.step(0, 6)
    b.step(R | J, 10)
    b.until(lambda: b.on, R | F, 300)
    b.note('floated down')
    b.step(0, 30)
    return b


def hop(b, pad, hold=14, glide=False, until_x=None, way=1):
    """a jump with the direction held; under the frill on the way down if
    glide; the direction let go of past until_x"""
    b.step(pad | J, hold)
    for i in range(200):
        p = pad
        if until_x is not None and (b.x - until_x) * way >= 0:
            p = 0
        if glide and b.vy > 40:
            p |= F
        b.step(p)
        if b.on:
            return


def magpie_near(b, d=70):
    return [m for m in b.ents(6) if abs(m['x'] - b.x) < d and abs(m['y'] - b.y) < d and m['state'] != 3]


def stone_country(b):
    b.step(0, 24)
    run(b, 138)                      # up the first step
    b.note('under the first ledge')
    b.step(0, 4)
    hop(b, 0, 14)                    # straight up through it
    b.note('on ledge one' if b.y == 96 else 'NOT on ledge one')
    if magpie_near(b, 90):
        b.step(F, 14)
    b.right_to(152)
    hop(b, R, 14, until_x=200)
    b.note('on ledge two' if b.y == 80 else 'NOT on ledge two')
    b.right_to(216)
    hop(b, R, 12, until_x=236)
    b.note('on the tops' if b.y == 64 else 'NOT on the tops')
    b.step(0, 10)
    b.step(F, 16)                    # a frill for the goanna underneath, who is not impressed
    b.step(0, 8)
    run(b)
    b.note('the gorge')
    b.right_to(66)
    b.step(0, 6)
    hop(b, R, 10, until_x=108)
    b.note('gorge ledge one' if b.y == 80 else 'NOT gorge ledge one')
    if magpie_near(b, 100):
        b.until(lambda: not magpie_near(b, 100), F, 40)
        b.step(F, 6)
    b.right_to(122)
    hop(b, R, 16, glide=True, until_x=204)
    b.note('gorge ledge two' if b.y == 80 else 'NOT gorge ledge two')
    b.right_to(216)
    hop(b, R, 14, until_x=250)
    b.note('across' if b.y == 64 else 'NOT across')
    run(b)
    b.note('the cave')
    b.right_to(118)                  # down the steps
    b.land()
    t = bluff(b)
    b.note('the cave: the bluff')
    if t:
        bounce(b, t)
    b.note('bounced')
    b.step(0, 30)
    return b


PLANS = [red_dirt, stone_country]


def replay(region, mono=False, vwait=None):
    """play the built-in recording back as the attract sequence will
    -> the state when its script ran out"""
    pp = emu.title(mono)
    S = pp.S
    pp.keys = []
    pp.out(0x50, emu.blk_port(22))
    a = pp.peekw(S['demos'] + 2 * region)
    pp.out(0x50, emu.blk_port(1))
    pp.poke(S['region'], region)
    pp.poke(S['dm_ptr'], a & 255)
    pp.poke(S['dm_ptr'] + 1, a >> 8)
    pp.cpu.pc = S['demo_go'] - 2            # ld a,1
    pp.cpu.sp = 0xEFF0
    last = None
    for i in range(4000):
        pp.run_frames(1)
        if pp.peek(S['game_end']) == 3 or pp.peek(S['demo']) != 1:
            break
        last = (pp.peek(S['room']), pp.peekw(S['hx']), pp.peekw(S['hy']), pp.peek(S['bugs']), pp.peek(S['hearts']))
    return last, pp.peekw(S['dm_n'])


if __name__ == '__main__':
    if sys.argv[1] == 'check':
        for region in range(len(PLANS)):
            want = (ROOT / 'demos' / ('region%d.end' % region)).read_text().strip()
            for mono in (False, True):
                got, n = replay(region, mono)
                print('region %d %-6s %s after %d ticks: %s' % (region, 'mono' if mono else 'colour', got, n,
                                                                'as recorded' if str(got) == want else 'NOT AS RECORDED ' + want))
        sys.exit()
    O = sys.argv[1]
    for region in [int(a) for a in sys.argv[2:]] or range(len(PLANS)):
        b = Bot(region, shots=True)
        PLANS[region](b)
        b.sheet('%s/demo%d.png' % (O, region))
        end = (b.room, b.x, b.y, b.v('bugs'), b.v('hearts'))
        (ROOT / 'demos' / ('region%d.txt' % region)).write_text(''.join('%d %d\n' % (p, t) for p, t in b.log))
        (ROOT / 'demos' / ('region%d.end' % region)).write_text(str(end) + '\n')
        print('region %d: %d runs, %d ticks, ends %s' % (region, len(b.log), sum(t for _, t in b.log), end))
