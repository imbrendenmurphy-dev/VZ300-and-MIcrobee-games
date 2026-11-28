"""Record the showcase GIF from the emulator model: the title, a walk
through each depth, a fight, the Hollow King and the victory page.

    py tools/showcase.py [out.gif]          default docs/showcase.gif
Scenes jump straight to each level (tools/jump.py) and place the Warden,
so the tour is the same every run.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from PIL import Image
import rd
import jump

ROOT = Path(__file__).resolve().parent.parent
MAP = 0xC800
W, H = 640, 375
FIELD_MS = 20


class Rec:
    def __init__(self):
        self.frames = []          # [image, duration ms]

    def grab(self, pp, ms):
        im = Image.fromarray(pp.screen_rgb()).resize((W, H), Image.NEAREST)
        if self.frames and np.array_equal(np.asarray(self.frames[-1][0]), np.asarray(im)):
            self.frames[-1][1] += ms
        else:
            self.frames.append([im, ms])

    def run(self, pp, fields, every=3):
        for _ in range(fields // every):
            pp.run_frames(every)
            self.grab(pp, every * FIELD_MS)

    def hold(self, img, ms):
        self.frames.append([Image.open(img).convert('RGB').resize((W, H), Image.NEAREST), ms])

    def key(self, pp, k, after=30):
        pp.keys = {k}
        pp.run_frames(2)
        pp.keys = set()
        self.grab(pp, 2 * FIELD_MS)
        self.run(pp, after)

    def save(self, out):
        # one palette of every colour the frames use (the Microbee's 16, and
        # the panel's few others): exact, no dithering
        cols = set()
        for f in self.frames:
            cols |= {tuple(int(v) for v in c) for c in np.unique(np.asarray(f[0]).reshape(-1, 3), axis=0)}
        cols = sorted(cols)
        assert len(cols) <= 256, len(cols)
        flat = [v for c in cols for v in c] + [0] * (768 - 3 * len(cols))
        ims = []
        for f in self.frames:
            a = np.asarray(f[0]).reshape(-1, 3)
            key = (a[:, 0].astype(np.int32) << 16) | (a[:, 1].astype(np.int32) << 8) | a[:, 2]
            ck = np.array([(c[0] << 16) | (c[1] << 8) | c[2] for c in cols])
            idx = np.searchsorted(ck, key).astype(np.uint8).reshape(H, W)
            im = Image.fromarray(idx, 'P')
            im.putpalette(flat)
            ims.append(im)
        ims[0].save(out, save_all=True, append_images=ims[1:], duration=[f[1] for f in self.frames], loop=0,
                    optimize=False, disposal=1)


def place(b, x, y, f):
    """put the Warden on (x, y) facing f (0 N .. 3 W) and show the view"""
    pp, S = b.pp, b.pp.S
    o = MAP + (y + 8) * 32 + x + 8
    pp.poke(S['ppos'], o & 255)
    pp.poke(S['ppos'] + 1, o >> 8)
    pp.poke(S['facing'], (f + 1) & 3)
    b.key('LEFT')
    pp.run_frames(10)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'docs' / 'showcase.gif'
    tmp = ROOT / 'build' / 'showcase'
    tmp.mkdir(parents=True, exist_ok=True)
    R = Rec()
    # the title, then into the Gatehouse
    pp = rd.boot()
    pp.run_frames(60)
    R.run(pp, 150, every=5)
    b = jump.to(0, tmp, strong=False)
    pp = b.pp
    R.grab(pp, 600)
    for k in ('UP', 'UP', 'RIGHT', 'UP', 'UP', 'LEFT', 'UP'):
        R.key(pp, k, 18)
    R.run(pp, 30)
    # a rat in the corridor: blows land
    place(b, 8, 3, 1)
    R.grab(pp, 900)
    for _ in range(3):
        R.key(pp, 'SPACE', 60)
    # the gate, seen from the side as you walk up
    place(b, 11, 13, 0)
    R.grab(pp, 500)
    R.key(pp, 'UP', 30)
    R.key(pp, 'UP', 45)
    # the Fungal Grotto: the trap plate drops spiders
    b = jump.to(1, tmp)
    pp = b.pp
    place(b, 2, 3, 1)
    R.grab(pp, 600)
    R.key(pp, 'UP', 25)
    R.key(pp, 'UP', 40)
    R.key(pp, 'LEFT', 20)
    R.key(pp, 'LEFT', 50)
    # the Archive: a rune plaque
    b = jump.to(2, tmp)
    pp = b.pp
    place(b, 3, 3, 0)
    R.grab(pp, 500)
    R.key(pp, 'UP', 25)
    R.key(pp, 'UP', 60)
    # the Ember Throne: an ash hound, then the Hollow King
    b = jump.to(3, tmp)
    pp = b.pp
    place(b, 8, 1, 1)
    R.grab(pp, 700)
    R.key(pp, 'UP', 50)
    place(b, 12, 14, 1)
    R.grab(pp, 1200)
    R.key(pp, 'SPACE', 60)
    R.key(pp, 'SPACE', 60)
    # the oath kept
    R.hold(ROOT / 'screenshots' / '08_victory.png', 3500)
    R.save(out)
    print('wrote %s: %d frames, %.1f s, %d KB' % (out, len(R.frames), sum(f[1] for f in R.frames) / 1000,
                                                  out.stat().st_size // 1024))


if __name__ == '__main__':
    main()
