"""End-to-end disk test: the Microbee boot ROM (resources/rom/bn60.rom, the
user's own, not in git) boots CP/M from build/AUSOPEN.DS8, AOT is typed at
the A> prompt, and the loader fills the RAM blocks and starts the game.
Checks every staged file arrived in its home block."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mbee import Mbee
import run

ROOT = Path(__file__).resolve().parent.parent


def type_text(pp, text, hold=4, gap=4):
    for ch in text:
        pp.keys = {'RET' if ch == '\r' else ch}
        pp.run_frames(hold)
        pp.keys = set()
        pp.run_frames(gap)


def boot(out=None):
    rom = (ROOT / 'resources' / 'rom' / 'bn60.rom').read_bytes()
    pp = Mbee(rom=rom, disk=(run.BUILD / 'AUSOPEN.DS8').read_bytes())
    pp.run_frames(60)
    type_text(pp, 'B')
    for i in range(100):
        pp.run_frames(10)
        if 'A>' in pp.text():
            break
    t0 = pp.frames
    print('CP/M prompt after %d frames' % t0)
    type_text(pp, 'AOT\r')
    S = run.symbols()
    pp.S = S
    ok = False
    for i in range(1500):
        pp.run_frames(10)
        if S['front_start'] <= pp.cpu.pc < 0x8000 or 0x8000 <= pp.cpu.pc < 0xC100 and pp.peek(0x8000) == (run.BUILD / 'AOT.BIN').read_bytes()[0] and pp.frames - t0 > 200:
            ok = True
            break
    print('\n'.join(l for l in pp.text().splitlines() if l.strip())[:600])
    print('game running %s, %.1f s after AOT was typed' % (ok, (pp.frames - t0) / 50.0))
    pp.run_frames(100)
    if out:
        pp.png(out, 2)
    return pp



def check(pp):
    """compare the RAM blocks with the files the loader put there"""
    B = run.BUILD
    want = [(2, 0, 'FRONT.BIN'), (12, 0, 'GFX.BNK'), (26, 0, 'PORT.BNK'), (13, 0, 'PIC0.BNK'), (14, 0, 'PIC1.BNK')]
    want += [(4 + i, 0x2000, 'SPR%d.BNK' % i) for i in range(6)]
    bad = 0
    for blk, off, f in want:
        d = (B / f).read_bytes()
        m = bytes(pp.blocks[blk][off:off + len(d)])
        n = sum(1 for a, b in zip(m, d) if a != b)
        if n:
            bad += 1
        print('%-10s block %2d: %d bytes differ' % (f, blk, n))
    print('blocks checked, %d mismatches' % bad)


if __name__ == '__main__':
    check(boot(sys.argv[1] if len(sys.argv) > 1 else None))
