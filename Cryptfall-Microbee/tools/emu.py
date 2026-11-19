"""Test helpers: cold-boot the disk image in the Premium Plus model with the
real BN60 boot ROM and the disk's own CP/M, exactly as the machine does."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mbee import Mbee, FRAME_T, KEY

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / 'build'


def symbols(path=BUILD / 'main.sym'):
    S = {}
    for line in Path(path).read_text().splitlines():
        if ': equ ' in line:
            n, v = line.split(': equ ')
            S[n.strip()] = int(v, 16)
    return S


def tap(pp, key, hold=4, gap=4):
    pp.keys = [key]
    pp.run_frames(hold)
    pp.keys = []
    pp.run_frames(gap)


def type_text(pp, text):
    for ch in text:
        tap(pp, {'\r': 'RET', ' ': 'SPACE'}.get(ch, ch))


def cold_boot(disk=None, wp=False, wait=True):
    """power-on: boot ROM at 8000h, the disk in drive A.  The ROM's menu wants
    B (boot the diskette); then CP/M loads SHELL.SYS, which runs the game."""
    rom = (ROOT / 'resources' / 'bn60.rom').read_bytes()
    img = Path(disk or BUILD / 'CRYPTFAL.DS8').read_bytes()
    pp = Mbee(rom=rom, disk=img)
    pp.S = symbols()
    pp.set_wp(wp)
    pp.out(0x50, 0)
    pp.cpu.pc = 0x8000
    pp.run_frames(60)
    tap(pp, 'B')
    if wait:
        for i in range(400):
            pp.run_frames(5)
            if int(pp.crtc[1]) == 40 and int(pp.crtc[0]) == 0x35 and pp.cpu.pc < 0x8000:   # the game is up in its 40-column mode
                break
    return pp


def peek(pp, name, n=1):
    a = pp.S[name]
    return pp.peek(a) if n == 1 else [pp.peek(a + i) for i in range(n)]


def peekw(pp, name):
    return pp.peekw(pp.S[name])


def poke(pp, name, v):
    pp.poke(pp.S[name], v)


def shot(pp, path, mono=False):
    return pp.png(str(path), scale=2, mono=mono, aspect=0.92)
