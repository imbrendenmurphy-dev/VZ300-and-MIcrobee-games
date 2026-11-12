"""Run SKYLARK.COM (the CP/M loader) in the Premium Plus model with the few
BDOS calls it makes (print, open, read, set DMA) served from build/, then
check that the game starts. No boot ROM or CP/M needed."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mbee import Mbee, L as ML
from run import blk_port, symbols, BUILD, peek

CPM_BLK = 2
pp = Mbee()
pp.out(0x50, blk_port(CPM_BLK))
com = (BUILD / 'SKYLARK.COM').read_bytes()
for i, b in enumerate(com):
    pp.poke(0x100 + i, b)
for a, b in ((0, 0x76), (5, 0xC3), (6, 0x06), (7, 0xE4)):     # HALT at 0, BDOS at E406h
    pp.poke(a, b)
pp.cpu.pc = 0x100
pp.cpu.sp = 0xE400
pp.poke(0xE3FE, 0); pp.poke(0xE3FF, 0); pp.cpu.sp = 0xE3FE      # return to 0 = HALT
files = {p.name.upper(): p.read_bytes() for p in BUILD.iterdir() if p.is_file()}
pos = {}
dma = 0x80
out = []
ML.mb_set_bp(pp.h, 5, 1)
for step in range(200000):
    r = ML.mb_run(pp.h, pp.tick + 50 * 67500)
    pc = pp.cpu.pc
    if pc != 5:
        break
    c = pp.cpu.c
    de = pp.cpu.d << 8 | pp.cpu.e
    a = 0
    if c == 9:
        s = ''
        while pp.peek(de) != ord('$'):
            s += chr(pp.peek(de)); de += 1
        out.append(s)
    elif c == 2:
        out.append(chr(pp.cpu.e))
    elif c == 26:
        dma = de
    elif c == 15:
        nm = bytes(pp.peek(de + 1 + k) for k in range(11)).decode()
        fn = nm[:8].strip() + '.' + nm[8:].strip()
        if fn in files:
            pos[de] = (fn, 0)
            a = 0
        else:
            a = 0xFF
            out.append('[missing %s]' % fn)
    elif c == 20:
        fn, p = pos[de]
        d = files[fn]
        if p >= len(d):
            a = 1
        else:
            rec = d[p:p + 128].ljust(128, b'\x1a')
            for k in range(128):
                pp.poke(dma + k, rec[k])
            pos[de] = (fn, p + 128)
    else:
        out.append('[bdos %d]' % c)
    pp.cpu.a = a
    sp = pp.cpu.sp                       # RET
    pp.cpu.pc = pp.peek(sp) | pp.peek(sp + 1) << 8
    pp.cpu.sp = sp + 2
ML.mb_set_bp(pp.h, 5, 0)
print(''.join(out).replace('\r', ''))
print('loader handed over at %04X' % pp.cpu.pc)
pp.S = symbols()
pp.run_frames(60)
print('after 60 fields: pc %04X' % pp.cpu.pc)
print('\n'.join(l for l in pp.text().split('\n') if l.strip()))
pp.png(BUILD / 'shots' / 'loader_boot.png', scale=1, aspect=1.2)
pp.keys = ['C']; pp.run_frames(6); pp.keys = []; pp.run_frames(80)
pp.png(BUILD / 'shots' / 'loader_title.png', scale=1, aspect=1.2)
print('title reached: pc %04X' % pp.cpu.pc)
