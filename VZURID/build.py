#!/usr/bin/env python3
"""Build VZURID2.VZ: generate assets, assemble, wrap in a VZ header."""
import os, subprocess, sys
root = os.path.dirname(os.path.abspath(__file__))
tools = os.path.join(root, 'tools')
build = os.path.join(root, 'build')
os.makedirs(build, exist_ok=True)
for g in ('gen_assets.py', 'gen_blocks.py'):
    subprocess.check_call([sys.executable, '-I', os.path.join(tools, g)])
sys.path.insert(0, tools)
from z80asm import Asm, preprocess
src = preprocess(os.path.join(root, 'src', 'engine.asm'))
a = Asm()
errs = a.assemble(src, 'engine.asm')
if errs:
    print('\n'.join(errs[:30])); print(len(errs), 'error(s)'); sys.exit(1)
lo, hi = min(a.out), max(a.out)
blob = bytes(a.out.get(i, 0) for i in range(lo, hi + 1))
assert lo == 0x8000, hex(lo)
end = a.sym['prog_end']
print('code+data: $%04X-$%04X  (%d bytes)' % (lo, hi, len(blob)))
assert hi < 0xC000, 'program overlaps the ring buffer at $C000'
open(os.path.join(build, 'vzurid.bin'), 'wb').write(blob)
with open(os.path.join(build, 'vzurid.sym'), 'w') as f:
    for k, v in sorted(a.sym.items(), key=lambda kv: kv[1]):
        f.write('%04X %s\n' % (v & 0xFFFF, k))
name = b'VZURID2'
hdr = b'VZF0' + name.ljust(17, b'\0') + bytes([0xF1]) + bytes([lo & 255, lo >> 8])
open(os.path.join(build, 'VZURID2.VZ'), 'wb').write(hdr + blob)
print('wrote build/VZURID2.VZ (%d bytes)' % (len(hdr) + len(blob)))
