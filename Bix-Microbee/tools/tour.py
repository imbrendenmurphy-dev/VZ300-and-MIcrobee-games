"""Play through the level with a simple script and save pictures: python3 tools/tour.py outdir"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
from mbee import FRAME_T

class Bot:
    def __init__(self, mono=False):
        self.pp = run.start(mono)
        self.S = self.pp.S
        self.g = self.pp.blocks[4]
        self.mono = mono
        self.loops = 0; self.fields = 0; self.slow = 0
    def v(self, n, w=1):
        a = self.S[n]
        return int(self.g[a]) | (int(self.g[a + 1]) << 8 if w == 2 else 0)
    def poke(self, n, val, w=1):
        a = self.S[n]
        self.g[a] = val & 255
        if w == 2: self.g[a + 1] = val >> 8
    def go(self, keys, n):
        pp = self.pp
        pp.keys = list(keys)
        pp.watch(self.S['game_loop']); pp.events()
        pp.run_frames(n)
        ev = pp.events()
        d = [(ev[i + 1][0] - ev[i][0]) / FRAME_T for i in range(len(ev) - 1)]
        self.loops += len(ev); self.fields += n; self.slow += sum(1 for x in d if x > 2.2)
    def shot(self, path):
        run.shot(self.pp, path, self.mono)
    def state(self):
        return 'ppx %d ppy %d state %d health %d lives %d stars %d camx %d' % (
            self.v('ppx', 2), self.v('ppy'), self.v('pstate'), self.v('health'), self.v('lives'), self.v('nstars'), self.pp.peekw(self.S['camx']))
    def warp(self, tx, ty=7):
        """put Bix at a tile (testing only)"""
        self.poke('ppx', tx * 8, 2); self.poke('px16', tx * 8 * 16, 2)
        self.poke('ppy', ty * 8 - 2); self.poke('py16', (ty * 8 - 2) * 16, 2)
        self.poke('vx', 0); self.poke('vy', 0); self.poke('pstate', 0); self.poke('health', 3); self.poke('invuln', 100)

if __name__ == '__main__':
    out = sys.argv[1]
    b = Bot()
    k = 0
    for tx in (3, 40, 64, 92, 100, 124, 160, 200, 208, 240, 270):
        b.warp(tx)
        b.go((), 60)
        b.go(('RIGHT',), 50)
        b.go(('RIGHT', 'SPACE'), 20)
        b.go((), 10)
        b.shot('%s/tour%02d.png' % (out, k)); k += 1
        print(tx, b.state())
    print('%d frames in %d fields: %.1f fps, %d slow frames' % (b.loops, b.fields, 50.0 * b.loops / b.fields, b.slow))
