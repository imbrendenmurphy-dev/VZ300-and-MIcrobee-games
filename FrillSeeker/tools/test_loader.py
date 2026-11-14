"""The loader's unpacking, run on the Premium Plus model: each packed block
of rooms is put where the loader's file read leaves it and the loader's own
code (from FRILL.COM) unpacks it in place; the result must be the block the
rest of the tools use. (CP/M itself is not modelled, so this is the part of
the loader that can be proven off the machine.)"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from mbee import Mbee
import run

B = run.BUILD
S = {}
for line in (B / 'loader.sym').read_text().splitlines():
    if ': equ ' in line:
        k, v = line.split(': equ ')
        S[k.strip()] = int(v, 16)
com = (B / 'FRILL.COM').read_bytes()
ok = True
for line in (run.ROOT / 'src' / 'loadfiles.inc').read_text().splitlines():
    blk, off, name = [x.strip() for x in line.replace('DB', '').split(',')]
    if '?' not in name:
        continue
    blk, off, name = int(blk), int(off.replace('$', ''), 16), name.strip('"')
    for t in 'CM':
        stem = name[:8].strip().replace('?', t)
        pp = Mbee()
        pp.out(0x50, run.blk_port(1))
        code = com[S['reloc'] - 0x100:S['reloc'] - 0x100 + S['reloc_end'] - 0xA000]
        for i, b in enumerate(code):
            pp.poke(0xA000 + i, b)
        f = np.frombuffer((B / (stem + '.LZB')).read_bytes(), np.uint8)
        assert off * 256 + len(f) == 0x8000, 'does not end at the top of its block'
        pp.blocks[blk][off * 256:] = f
        pp.poke(S['cur_blk'], blk)
        pp.poke(S['cur_off'], off)
        pp.poke(S['cpm_port'], run.blk_port(1))
        pp.poke(0xA7EE, 0x00)
        pp.poke(0xA7EF, 0xB0)                   # "return" to B000h
        pp.cpu.sp = 0xA7EE
        pp.cpu.pc = S['load_file.eof']
        done = pp.run_until(0xB000, 400)
        want = np.frombuffer((B / (stem + '.BNK')).read_bytes(), np.uint8)
        good = bool(done) and bool((pp.blocks[blk][:len(want)] == want).all())
        ok &= good
        print('%s -> block %d: %s' % (stem, blk, 'unpacked right' if good else 'WRONG'))
sys.exit(0 if ok else 1)
