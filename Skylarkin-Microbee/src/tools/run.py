"""Run SKYLARKIN' in the Premium Plus model with the RAM blocks preloaded as
the loader leaves them (tests, screenshots, measurements)."""
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


def boot():
    S = symbols()
    pp = Mbee()
    for f in BUILD.glob('B??.BNK'):
        b = int(f.stem[1:])
        d = f.read_bytes()
        pp.blocks[b][0:len(d)] = np.frombuffer(d, np.uint8)
    d = (BUILD / 'SKY.BIN').read_bytes()
    pp.blocks[0][0:len(d)] = np.frombuffer(d, np.uint8)
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = S
    return pp


def peek(pp, name, n=1):
    a = pp.S[name]
    return pp.peek(a) if n == 1 else [pp.peek(a + i) for i in range(n)]


def peekw(pp, name):
    a = pp.S[name]
    return pp.peek(a) | (pp.peek(a + 1) << 8)


def tap(pp, k, n=3):
    pp.keys = [k]
    pp.run_frames(n)
    pp.keys = []
    pp.run_frames(n)


def to_game(pp, mono=False, pilot=0):
    pp.run_frames(30)
    tap(pp, 'M' if mono else 'C')
    pp.run_frames(20)
    for _ in range(pilot):
        tap(pp, 'RIGHT')
    tap(pp, 'SPACE')
