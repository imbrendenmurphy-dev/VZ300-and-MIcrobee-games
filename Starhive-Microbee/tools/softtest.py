"""Emulator check of SOFTSCRL: the playfield must move down by exactly
the scroll amount every frame (far stars, in blue, excluded)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import run
from mbee import PALETTE

B = run.BUILD
files = [l.strip() for l in (B / 'soft_files.txt').read_text().split()]
blocks = {}
for line in (B / 'soft_files.inc').read_text().splitlines():
    blk, name = line.split('DB ')[1].split(',', 1)
    blocks[int(blk)] = name.strip('"').replace(' ', '').replace('BNK', '.BNK')


def frame(pp):
    return pp.screen_rgb(False).copy()


def shift_of(a, b, top=22, bot=264):
    """lines b is a moved down from a (scenery pixels only)"""
    best = None
    for d in range(0, 12):
        x = a[top:bot - d]
        y = b[top + d:bot]
        m = (x.sum(2) > 0) & ~((x[..., 2] > 0) & (x[..., 0] == 0) & (x[..., 1] == 0))
        if m.sum() < 50:
            return None
        err = (np.abs(x.astype(int) - y.astype(int)).sum(2) * m).sum() / m.sum()
        if best is None or err < best[1]:
            best = (d, err)
    return best


if __name__ == '__main__':
    pp = run.boot('SOFTSCRL.BIN', 'softscrl.sym', blocks=blocks)
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else B
    pp.run_frames(400)            # into the station section
    shots = []
    prev = frame(pp)
    res = []
    for i in range(120):
        pp.run_frames(1)
        cur = frame(pp)
        res.append(shift_of(prev, cur))
        prev = cur
        if i in (0, 3, 6):
            shots.append(cur)
    ok = [r for r in res if r]
    print('shifts:', [r[0] for r in ok][:60])
    print('worst error %.1f' % max(r[1] for r in ok))
    from PIL import Image
    Image.fromarray(np.hstack(shots)).save(out / 'soft_frames.png')
    S = pp.S
    print('top row', pp.peek(S['top']) | pp.peek(S['top'] + 1) << 8, 'k', pp.peek(S['k']))


def beam_frame(pp, top=0, bot=264):
    """the picture as the beam draws it: each line from the state at the
    moment the beam reaches it (run from a frame boundary)"""
    from mbee import FRAME_T
    t0 = (pp.tick // FRAME_T) * FRAME_T
    if t0 < pp.tick:
        t0 += FRAME_T
    out = None
    for L in range(top, bot):
        pp.run_ticks(t0 + (L * FRAME_T) // 312 - pp.tick)
        img = pp.screen_rgb(False)
        if out is None:
            out = np.zeros_like(img)
        out[L] = img[L]
    return out
