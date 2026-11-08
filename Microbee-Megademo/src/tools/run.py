"""Run the megademo program in the Premium Plus model (blocks preloaded
as the loader leaves them)."""
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


def put(pp, b, data, off=0):
    pp.blocks[b][off:off + len(data)] = np.frombuffer(data, np.uint8)


def boot(banks=None, pokes=None):
    S = symbols()
    pp = Mbee()
    for b, data in (banks or {}).items():
        put(pp, b, data)
    put(pp, 0, (BUILD / 'MEGA.BIN').read_bytes())
    for k, v in (pokes or {}).items():
        pp.blocks[0][S[k] - 0x8000] = v
    pp.out(0x50, blk_port(1))
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xEFF0
    pp.S = S
    return pp


def boot_demo(mono=False, extra=None, part=0):
    """the demo with its data blocks loaded, the monitor chosen"""
    banks = {}
    i = 0
    while (BUILD / ('DATA%d.BNK' % i)).exists():
        banks[4 + i] = (BUILD / ('DATA%d.BNK' % i)).read_bytes()
        i += 1
    if extra:
        banks.update(extra)
    pp = boot(banks, pokes={'boot_part': part} if part else None)
    pp.run_until(pp.S['select_screen.w'], 50)
    pp.keys = ['M' if mono else 'C']
    pp.run_to_frame(3)
    pp.keys = []
    return pp
