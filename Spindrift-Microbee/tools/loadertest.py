"""Run SPIN.COM, the CP/M loader, straight off the built disk image in the
Premium Plus model, with a stand-in for CP/M's BDOS that serves the files
from the image's own directory. Checks the disk's directory and every
file on it, the loader's search for CP/M's bank, its 1MB RAM check, the
staging into the RAM blocks, the final copy and the start of the game.

(The real boot - the Microbee boot ROM reading CP/M off the system
tracks - needs the ROM, which is not included.)

    python3 tools/loadertest.py [disk]
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from mbee import Mbee, FRAME_T
import build_disk as BD
import run

ROOT = Path(__file__).resolve().parent.parent
BDOS_AT = 0xE400            # in the upper 32K: the TPA reaches past B000h
CPM_BLOCK = 2               # CP/M's lower 32K


def main(disk=ROOT / 'build' / 'SPINDRIFT.DS8'):
    img = Path(disk).read_bytes()
    files = BD.read_dir(BD.unskew(img))
    print('disk directory:', ', '.join('%s %d' % (n, len(d)) for n, d in files.items()))
    B = ROOT / 'build'
    for n in ('SPIN.COM', 'SPIN.BIN', 'TAB.BNK', 'ENM.BNK', 'PIC.BNK'):
        want = (B / n).read_bytes()
        got = files[n][:len(want)]
        assert got == want, n + ' differs on the disk'
    print('every file on the disk matches the build')
    assert not any(n.startswith('SHELL') for n in files), 'no shell wanted'

    pp = Mbee()
    pp.out(0x50, run.blk_port(CPM_BLOCK) & 0xF7)        # CP/M: its block, video at F000
    lo = pp.blocks[CPM_BLOCK]
    com = files['SPIN.COM']
    lo[0x100:0x100 + len(com)] = np.frombuffer(com, np.uint8)
    lo[0:3] = (0xC3, 0, 0)
    lo[5:8] = (0xC3, BDOS_AT & 255, BDOS_AT >> 8)
    pp.blocks[0][BDOS_AT - 0x8000] = 0xC9               # RET
    pp.cpu.pc = 0x100
    pp.cpu.sp = 0xA7F0
    dma = [0x80]
    opened = {}
    out = []
    calls = 0
    import mbee
    mbee.L.mb_set_bp(pp.h, 0x8000, 1)       # stop when the game is started
    while True:
        pc = pp.run_until(BDOS_AT, 400)
        if pc is None or pp.cpu.pc == 0x8000:
            break
        calls += 1
        c, de = pp.cpu.c, pp.cpu.d << 8 | pp.cpu.e
        a = 0
        if c == 9:
            s = ''
            while pp.peek(de) != ord('$'):
                s += chr(pp.peek(de))
                de += 1
            out.append(s)
        elif c == 2:
            out.append(chr(pp.cpu.e))
        elif c == 26:
            dma[0] = de
        elif c == 15:
            name = bytes(pp.peek(de + 1 + i) for i in range(11)).decode()
            fn = name[:8].strip() + '.' + name[8:].strip()
            if fn in files:
                opened[de] = (fn, 0)
            else:
                a = 0xFF
        elif c == 20:
            fn, pos = opened[de]
            d = files[fn]
            if pos >= len(d):
                a = 1
            else:
                rec = d[pos:pos + 128].ljust(128, b'\x1a')
                for i, v in enumerate(rec):
                    pp.poke(dma[0] + i, v)
                opened[de] = (fn, pos + 128)
        pp.cpu.a = a
        pp.cpu.l = a
        if pp.cpu.pc == BDOS_AT:
            pass
        if c == 0:
            break
        # the loader has jumped to the game once its final stage runs
        if run.symbols()['entry'] and pp.cpu.pc >= 0xF000 and c not in (2, 9):
            break
    text = ''.join(out).replace('\r', '')
    print('loader said:', ' | '.join(l for l in text.split('\n') if l.strip()))
    assert 'missing' not in text and 'needs' not in text.lower() and 'Cannot' not in text, text
    # let the final stage copy the program and jump to it
    S = run.symbols()
    prog = (B / 'SPIN.BIN').read_bytes()
    at = pp.cpu.pc if pp.cpu.pc == 0x8000 else pp.run_until(0x8000, 50)
    mbee.L.mb_set_bp(pp.h, 0x8000, 0)
    mem = bytes(pp.blocks[0][:len(prog)])
    ok_prog = at == 0x8000 and mem == prog
    if not ok_prog:
        diff = [i for i in range(len(prog)) if mem[i] != prog[i]]
        print('  stopped at %s; %d bytes differ, first at %04X, last at %04X (prog %04X long)' % (
            at if at is None else '%04X' % at, len(diff), 0x8000 + diff[0] if diff else 0,
            0x8000 + diff[-1] if diff else 0, len(prog)))
    print('final stage jumped to 8000h with the program intact:', ok_prog)
    pp.run_frames(60)
    for blk, n in ((4, 'TAB'), (5, 'ENM'), (6, 'PIC')):
        d = (B / (n + '.BNK')).read_bytes()
        print('block %d holds %s.BNK:' % (blk, n), bytes(pp.blocks[blk][:len(d)]) == d)
    pp.S = S
    import fronttest
    t = fronttest.screen_text(pp)
    started = 'COLOUR MONITOR' in t
    print('the game started (monitor question on screen):', started)
    pp.png(str(ROOT / 'build' / 'loader_start.png'))
    return ok_prog and started


if __name__ == '__main__':
    sys.exit(0 if main(*sys.argv[1:]) else 1)
