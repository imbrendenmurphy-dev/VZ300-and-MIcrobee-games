"""Measure CPU time (T-states at 3.375 MHz) from typing KILLTOM2 to hw_init, and BIOS vs game split."""
import sys
from test_plus import *
from test_plus_boot import PlusBoot  # noqa: runs the boot test once as a side effect
disk = sys.argv[1] if len(sys.argv) > 1 else 'outputs/KILLTPP.DS80'
b = PlusBoot(); b.disk = Path(disk).read_bytes(); m = b.m
queue = list(b'KILLTOM2\r')
for pc in [0xe406, 0xe409, 0xe40c, 0x100, sym['hw_init']]: m.set_breakpoint(pc)
def ret():
    m.pc = b.read(m.sp) | (b.read((m.sp + 1) & 65535) << 8); m.sp = (m.sp + 2) & 65535
start = None
for i in range(200000):
    b.run(ticks=100000)
    if m.pc == 0xe406: m.a = 255 if queue else 0; ret()
    elif m.pc == 0xe409: m.a = queue.pop(0); ret()
    elif m.pc == 0xe40c: ret()
    elif m.pc == 0x100: start = b.elapsed; m.clear_breakpoint(0x100)
    elif m.pc == sym['hw_init']:
        t = b.elapsed - start
        print(f'{disk}: {t} T-states = {t/3375000:.1f} s CPU, FDC sector reads {len(b.fdc_reads)}')
        break
