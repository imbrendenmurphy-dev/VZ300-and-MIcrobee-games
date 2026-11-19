"""Sample the PC every 500 T-states while loading, bucketed by region."""
from collections import Counter
from test_plus import *
import test_plus_boot
from test_plus_boot import PlusBoot
b = PlusBoot(); m = b.m; queue = list(b'KILLTOM2\r')
for pc in [0xe406, 0xe409, 0xe40c, 0x100, sym['hw_init']]: m.set_breakpoint(pc)
def ret():
    m.pc = b.read(m.sp) | (b.read((m.sp + 1) & 65535) << 8); m.sp = (m.sp + 2) & 65535
labels = sorted((v, k) for k, v in sym.items() if v < 0x7000 and not k.startswith('.') and '.' not in k)
def region(pc):
    if pc >= 0xD000: return f'CP/M {pc & 0xFF00:04X}'
    if 0x8000 <= pc < 0x8100: return 'bank copy'
    name = 'game?'
    for v, k in labels:
        if v <= pc: name = k
        else: break
    return name
hist = Counter(); go = False
while True:
    b.run(ticks=500)
    if m.pc == 0xe406: m.a = 255 if queue else 0; ret(); continue
    if m.pc == 0xe409: m.a = queue.pop(0); ret(); continue
    if m.pc == 0xe40c: ret(); continue
    if m.pc == 0x100: go = True; m.clear_breakpoint(0x100); continue
    if m.pc == sym['hw_init']: break
    if go: hist[region(m.pc)] += 1
tot = sum(hist.values())
for k, v in hist.most_common(15): print(f'{100*v/tot:5.1f}%  {k}')
