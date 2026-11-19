"""Emulator run of SHIPTEST: pictures as the beam draws them, timing."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import run
import softtest as st
from mbee import FRAME_T

blocks = dict(st.blocks)
blocks[19] = 'SWORK.BNK'


def boot():
    return run.boot('SHIPTEST.BIN', 'shiptest.sym', blocks=blocks)


if __name__ == '__main__':
    from PIL import Image
    out = Path(sys.argv[1])
    pp = boot()
    S = pp.S
    pp.run_frames(500)
    # timing: commit start to the next commit, and the work after it
    t = []
    for i in range(24):
        pp.run_until(S['commit'], 5)
        a = pp.tick
        pp.run_until(S['advance'], 5)
        b = pp.tick
        pp.run_until(S['main'], 5)
        c = pp.tick
        t.append((b - a, c - a, pp.peek(S['nslot']), pp.peek(S['k'])))
    print('commit, whole frame, cells, k:')
    print(t)
    fr = [st.beam_frame(pp) for i in range(3)]
    im = np.hstack([np.pad(f, ((0, 0), (0, 4), (0, 0))) for f in fr])
    Image.fromarray(im).resize((im.shape[1] * 2, im.shape[0] * 2), Image.NEAREST).save(out / 'ship3.png')
