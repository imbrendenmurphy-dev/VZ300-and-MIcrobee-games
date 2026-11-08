"""Run the game in the Premium Plus model with RAM blocks preloaded as the
loader leaves them (for tests and screenshots)."""
import os, sys
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


def boot(extra=None, disk=None):
    S = symbols()
    pp = Mbee(disk=disk)
    for f, b in (extra or {}).items():
        put(pp, b, Path(f).read_bytes())
    for i in range(8):
        f = BUILD / ('SPR%d.BNK' % i)
        if f.exists():
            put(pp, 4 + i, f.read_bytes(), 0x2000)
    put(pp, 12, (BUILD / 'GFX.BNK').read_bytes())
    for i in range(8):
        f = BUILD / ('PIC%d.BNK' % i)
        if f.exists():
            put(pp, 13 + i, f.read_bytes())
    f = BUILD / 'PORT.BNK'
    if f.exists():
        put(pp, 26, f.read_bytes())
    f = BUILD / 'CLOUD.BNK'
    if f.exists():
        put(pp, 18, f.read_bytes())
    f = BUILD / 'BOARD.BNK'
    if f.exists():
        put(pp, 17, f.read_bytes())
    f = BUILD / 'FRONT.BIN'
    if f.exists():
        put(pp, 2, f.read_bytes())
    put(pp, 0, (BUILD / 'AOT.BIN').read_bytes())
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = S
    return pp
