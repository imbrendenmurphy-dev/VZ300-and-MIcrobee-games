"""Run KABOOMERANG in the Premium Plus model with the RAM blocks preloaded
as the loader leaves them (tests, screenshots)."""
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


def boot(test=False, mono=False, disk=None):
    S = symbols()
    pp = Mbee(disk=disk)
    put(pp, 4, (BUILD / 'SPR0.BNK').read_bytes(), 0x3000)
    put(pp, 7, (BUILD / 'GFX.BNK').read_bytes())
    put(pp, 0, (BUILD / 'KB.BIN').read_bytes())
    if test:
        pp.blocks[0][S['boot_test'] - 0x8000] = 1
    if mono:
        pp.blocks[0][S['boot_mono'] - 0x8000] = 1
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = S
    return pp


def peek(pp, name, n=1):
    a = pp.S[name]
    return pp.peek(a) if n == 1 else [pp.peek(a + i) for i in range(n)]
