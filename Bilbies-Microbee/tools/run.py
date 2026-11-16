"""Run BILBIES! in the Premium Plus model with RAM blocks preloaded as the
loader leaves them (for tests and measurements)."""
import os
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
            S[n.strip()] = int(v, 16)
    return S


def put(pp, b, data, off=0):
    pp.blocks[b][off:off + len(data)] = np.frombuffer(data, np.uint8)


def boot(level=1, mono=False, mode=1, disk=True):
    """mode 0: the front end; 1: level played by its script; 2: level by input"""
    S = symbols()
    d = (BUILD / 'BILBIES.DS8').read_bytes() if disk and (BUILD / 'BILBIES.DS8').exists() else None
    pp = Mbee(disk=d)
    put(pp, 27, (BUILD / 'GFX.BNK').read_bytes())
    for i in range(8):
        f = BUILD / ('SPR%d.BNK' % i)
        if f.exists():
            put(pp, 4 + i, f.read_bytes())
    for i in range(16):
        f = BUILD / ('LEV%d.BNK' % i)
        if f.exists():
            put(pp, 12 + i, f.read_bytes())
    put(pp, 0, (BUILD / 'BILBIES.BIN').read_bytes())
    pp.blocks[0][S['boot_mode'] - 0x8000] = mode
    pp.blocks[0][S['boot_level'] - 0x8000] = level
    pp.blocks[0][S['boot_mono'] - 0x8000] = 1 if mono else 0
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = S
    return pp


if __name__ == '__main__':
    pp = boot()
    pp.run_frames(int(sys.argv[1]) if len(sys.argv) > 1 else 50)
    pp.png('/tmp/claude-0/run.png', 2, aspect=1.8)
    print('pc %04X' % pp.cpu.pc, pp.regs())
