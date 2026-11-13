"""Run ROBOT RIOT 2086 in the Premium Plus model with the RAM blocks loaded
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


def boot(test=False):
    S = symbols()
    pp = Mbee()
    gfx = (BUILD / 'GFX.BNK').read_bytes()
    pp.blocks[7][:len(gfx)] = np.frombuffer(gfx, np.uint8)
    prog = (BUILD / 'RR.BIN').read_bytes()
    pp.blocks[0][:len(prog)] = np.frombuffer(prog, np.uint8)
    if test:
        pp.blocks[0][S['boot_test'] - 0x8000] = 1
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = S
    return pp


def peek(pp, name, n=1):
    a = pp.S[name]
    return pp.peek(a) if n == 1 else [pp.peek(a + i) for i in range(n)]
