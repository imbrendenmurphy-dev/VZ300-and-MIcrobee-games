"""Run BUZZ OFF! programs in the Premium Plus model (tools/emu/mbee.c) with
the RAM blocks preloaded as the loader leaves them.

render() draws the picture as the monitor shows it: the 6545's vertical
total adjust (R5) delays the picture, so the displayed rows are drawn
(R5 - R5BASE) lines lower on a fixed canvas."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from mbee import Mbee, FRAME_T, KEY, PALETTE

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'
R5BASE = 0
WINTOP, WINBOT = 32, 264


def blk_port(b):
    return ((b & 0x1C) << 3) | ((b & 3) ^ 2) | 4


def symbols(path):
    S = {}
    for line in Path(path).read_text().splitlines():
        if ': equ ' in line:
            n, v = line.split(': equ ')
            S[n] = int(v, 16)
    return S


def boot(binname='SCRLTEST.BIN', sym='scrtest.sym', blocks=None):
    pp = Mbee()

    def put(b, data, off=0):
        pp.blocks[b][off:off + len(data)] = np.frombuffer(data, np.uint8)
    blocks = blocks or {2: 'WORK.BNK', 3: 'LEVEL1.BNK'}
    for b, f in blocks.items():
        put(b, (BUILD / f).read_bytes())
    put(0, (BUILD / binname).read_bytes())
    pp.out(0x50, blk_port(2) | 8)   # as the loader leaves it: no video window
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = symbols(BUILD / sym)
    return pp


def render(pp, mono=False, window=True):
    """the monitor's view: 29 rows of 8 lines shifted down by k on a
    240-line canvas; window=True dims what lies outside the 224-line
    window (to check the edges never show)"""
    cols = int(pp.crtc[1]) or 64
    rows = int(pp.crtc[6]) or 16
    lines = (int(pp.crtc[9]) & 31) + 1
    k = int(pp.crtc[5]) - R5BASE
    img = pp.screen_rgb(mono)
    H = rows * lines + 11
    canvas = np.zeros((H, cols * 8, 3), np.uint8)
    canvas[k:k + img.shape[0]] = img[:H - k]
    if window:
        canvas[:10] //= 4
        canvas[WINBOT:] //= 4
    return canvas, k


def png(pp, path, scale=2, aspect=1.5, mono=False, window=True):
    """40-column pixels are two standard dots wide: x2 across, x1.5 down"""
    from PIL import Image
    c, k = render(pp, mono, window)
    im = Image.fromarray(c)
    im = im.resize((im.width * scale, int(im.height * scale * aspect / 2)), Image.NEAREST)
    im.save(path)
    return im


def press(pp, keys, frames):
    pp.keys = set(keys)
    pp.run_frames(frames)
    pp.keys = set()


if __name__ == '__main__':
    pp = boot()
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    pp.run_frames(n)
    png(pp, '/tmp/claude-0/st.png')
    print('pc %04X' % pp.cpu.pc, pp.regs(), 'crtc', list(pp.crtc[:16]))
