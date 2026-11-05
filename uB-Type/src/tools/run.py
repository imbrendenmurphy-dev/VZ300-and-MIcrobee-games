"""Run uB-TYPE in the Premium Plus model with the RAM blocks preloaded as
the loader leaves them, plus helpers for scripted tests and measurement."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from mbee import Mbee, FRAME_T, KEY

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'


def blk_port(b):
    return ((b & 0x1C) << 3) | ((b & 3) ^ 2) | 4


def symbols(path=BUILD / 'main.sym'):
    S = {}
    for line in Path(path).read_text().splitlines():
        if ': equ ' in line:
            n, v = line.split(': equ ')
            S[n] = int(v, 16)
    return S


def load_blocks(pp):
    def put(b, data, off=0):
        pp.blocks[b][off:off + len(data)] = np.frombuffer(data, np.uint8)
    put(4, (BUILD / 'GFX.BNK').read_bytes())
    for n in range(8):
        put(8 + 2 * n, (BUILD / ('STAGE%d.PCG' % n)).read_bytes())
        put(9 + 2 * n, (BUILD / ('STAGE%d.TAB' % n)).read_bytes())
    for f, b in (('FRONT.BNK', 1), ('TITLE.BNK', 5)):
        if (BUILD / f).exists():
            put(b, (BUILD / f).read_bytes())
    code = (BUILD / 'UBTYPE.BIN').read_bytes()
    put(0, code)


def boot(stage=0, mono=False, S=None):
    S = S or symbols()
    pp = Mbee()
    load_blocks(pp)
    if 'protostage' in S:
        pp.blocks[0][S['protostage'] - 0x8000] = 255 if stage is None else stage
    if mono and 'mono' in S:
        pp.blocks[0][S['mono'] - 0x8000] = 1
    pp.out(0x50, blk_port(2))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = S
    return pp


def press(pp, keys, frames):
    pp.keys = set(keys)
    pp.run_frames(frames)
    pp.keys = set()


if __name__ == '__main__':
    pp = boot()
    pp.run_frames(int(sys.argv[1]) if len(sys.argv) > 1 else 100)
    pp.png('/tmp/claude-0/ub.png', 2, aspect=1.83)
    print('pc %04X' % pp.cpu.pc, pp.regs())
