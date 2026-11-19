"""Emulator runs of STARHIVE: pictures as the beam draws them."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import run
import softtest as st

blocks = dict(st.blocks)
blocks[19] = 'SWORK.BNK'


def boot():
    return run.boot('STARHIVE.BIN', 'starhive.sym', blocks=blocks)


def shot(pp, path, n=1):
    from PIL import Image
    fr = [st.beam_frame(pp) for i in range(n)]
    im = np.hstack([np.pad(f, ((0, 0), (0, 4), (0, 0))) for f in fr])
    Image.fromarray(im).resize((im.shape[1] * 2, im.shape[0] * 2), Image.NEAREST).save(path)
