"""Tick-by-tick comparison of the Microbee game against the VZ300 original's
own rules (tools/vzref/ref.asm: the original game.asm and script player,
assembled alone) on the same level: python3 compare.py level [ticks]"""
import sys, os
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import run
from mbee import Mbee


def ref_symbols():
    S = {}
    for line in open(os.path.join(HERE, 'vzref', 'ref.sym')):
        if ': equ ' in line:
            n, v = line.split(': equ ')
            S[n.strip()] = int(v, 16)
    return S


def ref_boot(level):
    R = ref_symbols()
    pp = Mbee()
    data = open(os.path.join(HERE, 'vzref', 'ref.bin'), 'rb').read()
    pp.blocks[0][:len(data)] = np.frombuffer(data, np.uint8)
    pp.out(0x50, run.blk_port(1) | 8)          # lower = block 1, no video window
    bank = open(os.path.join(run.BUILD, 'W%02dC.BNK' % level), 'rb').read()
    W = pp.poke
    hdr = bank[0x5A00:0x5A00 + 100]
    for i, v in enumerate(hdr[24:36]):
        W(R['v_ncrt'] + i, v)
    W(R['v_minrate'], hdr[25])
    W(R['v_lwb'], hdr[36])
    lw = hdr[36] * 4
    W(R['v_lw'], lw & 255); W(R['v_lw'] + 1, lw >> 8)
    for i in range(13):
        W(R['v_lh'] + i, hdr[37 + i])
    W(R['v_nsteel'], hdr[51])
    for i in range(48):
        W(R['v_steel'] + i, hdr[52 + i])
    W(R['v_bgtex'], R['TEXBUF'] & 255); W(R['v_bgtex'] + 1, R['TEXBUF'] >> 8)
    for i, v in enumerate(bank[0x6000:0x6000 + 5120]):
        W(0xDE00 + i, v)
    tl = hdr[27] * 60
    W(R['v_tleft'], tl & 255); W(R['v_tleft'] + 1, tl >> 8)
    W(R['v_seed'], 0x71); W(R['v_seed'] + 1, 0x3A)
    W(R['v_demo'], 1)
    for i, v in enumerate(bank[0x5B00:0x5B80]):
        W(0x7F02 + i, v)
    W(R['v_dptr'], 0x02); W(R['v_dptr'] + 1, 0x7F)
    pp.cpu.pc = 0x8000
    pp.cpu.sp = 0xDDF0
    pp.R = R
    return pp


def ref_tick(pp, secfr):
    """one tick + the clock for the two loops it spans (as play_level)"""
    R = pp.R
    pp.run_ticks(1)
    pp.run_until(R['ref_tick'], 50)
    for _ in range(2):
        secfr += 2
        if secfr >= 50:
            tl = pp.peekw(R['v_tleft'])
            if tl:
                tl -= 1
                pp.poke(R['v_tleft'], tl & 255); pp.poke(R['v_tleft'] + 1, tl >> 8)
            secfr = 0
    return secfr


def crt(pp, base):
    return [tuple(pp.peek(base + i * 16 + k) for k in range(9)) for i in range(40)]


if __name__ == '__main__':
    lv = int(sys.argv[1])
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
    ref = ref_boot(lv)
    mb = run.boot(lv)
    S = mb.S
    secfr = 0
    for t in range(n):
        secfr = ref_tick(ref, secfr)
        mb.run_until(S['play_level.tick_done'], 1000 if t == 0 else 100)
        mb.run_ticks(1)
        a = crt(ref, 0x7B00)
        b = crt(mb, S['CRT'])
        if a != b:
            print('tick', t + 1, 'differs')
            for i, (x, y) in enumerate(zip(a, b)):
                if x != y:
                    print('  bilby', i, 'ref', x, 'mb', y)
            break
        if ref.peek(ref.R['v_end']):
            print('ref ended at tick', t + 1, 'saved', ref.peek(ref.R['v_saved']), 'mb saved', mb.peek(S['v_saved']))
            break
    else:
        print('identical for', n, 'ticks')
