"""Run SPINDRIFT in the raster-accurate Premium Plus model (tools/emu),
with the RAM blocks filled as the loader leaves them.

    python3 tools/run.py out/       title, a game, screenshots
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from mbee import Mbee, FRAME_T

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'


def blk_port(b):
    return ((b & 0x1C) << 3) | ((b & 3) ^ 2) | 4


def symbols(path=BUILD / 'main.sym'):
    S = {}
    for line in Path(path).read_text().splitlines():
        if ': equ ' in line:
            n, v = line.split(': equ ')
            S[n.strip()] = int(v, 16)
    return S


def boot():
    pp = Mbee()
    pp.S = symbols()
    pp.blocks[0][:0x7000] = 0
    d = np.frombuffer((BUILD / 'SPIN.BIN').read_bytes(), np.uint8)
    pp.blocks[0][:len(d)] = d
    for b, n in ((4, 'TAB'), (5, 'ENM'), (6, 'PIC')):
        d = np.frombuffer((BUILD / (n + '.BNK')).read_bytes(), np.uint8)
        pp.blocks[b][:len(d)] = d
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    return pp


def var(pp, name, n=1):
    a = pp.S[name]
    if n == 1:
        return pp.peek(a)
    return pp.peek(a) | (pp.peek(a + 1) << 8)


def press(pp, keys, frames=3, after=3):
    pp.keys = keys
    pp.run_frames(frames)
    pp.keys = []
    pp.run_frames(after)


def to_title(mono=False):
    pp = boot()
    pp.run_frames(20)
    press(pp, ['M' if mono else 'C'])
    pp.run_frames(10)
    return pp


def start_game(mono=False):
    pp = to_title(mono)
    press(pp, ['SPACE'])
    pp.run_frames(5)
    return pp


def view(pp, mono=False, current=False):
    """the last complete picture off the model's tube: the 320 x 200
    picture (each pixel 2 wide in the model) with a little border"""
    from PIL import Image
    rgb = pp.frame_rgb(mono, current)
    return Image.fromarray(rgb[36:244, 32:688])


def shot(pp, path, mono=False, scale=1.5):
    from PIL import Image
    im = view(pp, mono)
    im = im.resize((int(im.width * scale), int(im.height * scale * 1.6)), Image.NEAREST)
    im.save(path)
    return im


if __name__ == '__main__':
    out = Path(sys.argv[1] if len(sys.argv) > 1 else 'out')
    out.mkdir(exist_ok=True)
    pp = to_title()
    pp.run_frames(60)
    shot(pp, out / 'title.png')
    print('title: pc %04X frame %d' % (pp.cpu.pc, var(pp, 'frameno', 2)))
    press(pp, ['SPACE'])
    for i in range(6):
        pp.run_frames(100)
        shot(pp, out / ('game%d.png' % i))
        print('t=%d phase %d enemies %d slots %d list %d late %d' % (
            i, var(pp, 'phase'), var(pp, 'nenemy'), (var(pp, 'nextcode') - 0x91) & 255, var(pp, 'lcount'), var(pp, 'commit_late')))
