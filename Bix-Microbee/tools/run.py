"""Run BIX in the raster-accurate Premium Plus model (tools/emu), with the
RAM blocks filled as the loader leaves them."""
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
    S = symbols()
    pp = Mbee()
    for line in (ROOT / 'src' / 'loadfiles.inc').read_text().splitlines():
        blk, off, name = [x.strip() for x in line.replace('DB', '').split(',')]
        name = name.strip('"')
        f = BUILD / ('%s.%s' % (name[:8].strip(), name[8:]))
        d = np.frombuffer(f.read_bytes(), np.uint8)
        b = 0 if blk == 'STG_PROG' else int(blk)
        o = int(off.replace('$', ''), 16) * 256
        pp.blocks[b][o:o + len(d)] = d
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0x9A00
    pp.S = S
    return pp


def start(mono=False):
    """boot, choose the monitor, into the level"""
    pp = boot()
    pp.run_frames(20)
    if mono:
        pp.keys = ['M']
        pp.run_frames(6)
        pp.keys = []
        pp.run_frames(6)
    pp.keys = ['SPACE']
    pp.run_frames(6)
    pp.keys = []
    pp.run_frames(40)
    return pp


def view(pp, mono=False):
    from PIL import Image
    rgb = pp.frame_rgb(mono)[28:28 + 224, 24:24 + 672]
    return Image.fromarray(rgb)


def shot(pp, path, mono=False, scale=1.5):
    from PIL import Image
    im = view(pp, mono)
    im = im.resize((int(im.width * scale), int(im.height * scale * 1.6)), Image.NEAREST)
    im.save(path)
    return im


if __name__ == '__main__':
    out = sys.argv[1]
    pp = boot()
    pp.run_frames(20)
    shot(pp, out + '/title.png')
    pp = start()
    shot(pp, out + '/t1.png')
    S = pp.S
    print('pc %04X' % pp.cpu.pc, 'camx', pp.peekw(S['camx']), 'nslots', pp.peek(S['nslots']), 'late', pp.peek(S['perf_late']))
