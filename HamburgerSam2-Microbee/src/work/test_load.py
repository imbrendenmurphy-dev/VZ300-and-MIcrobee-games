"""Boot the DS80 from the Microbee ROM, type HAMSAM2 at A>, then let the
game's own loader read HAMSAM2.DAT through CP/M and check every 32K block
landed in the right extended-RAM bank, byte for byte."""
from test_boot import *
b = BootBee(); m = b.m
entry = sym['game_entry']
for pc in [0xe406, 0xe409, 0xe40c, entry]: m.set_breakpoint(pc)
queue = list(b'HAMSAM2\r'); console = []
def ret():
    m.pc = b.read(m.sp) | (b.read((m.sp + 1) & 65535) << 8); m.sp = (m.sp + 2) & 65535
for i in range(20000):
    b.run(ticks=100000)
    if m.pc == 0xe406: m.a = 255 if queue else 0; ret()
    elif m.pc == 0xe409:
        assert queue, repr(''.join(console)); m.a = queue.pop(0); ret()
    elif m.pc == 0xe40c: console.append(chr(m.c & 127)); ret()
    elif m.pc == entry: break
else:
    raise AssertionError(('loader never finished', hex(m.pc), ''.join(console)))
text = ''.join(console)
assert 'missing' not in text, text
dat = Path('work/port/build/HAMSAM2.DAT').read_bytes()
n = len(dat) // 32768
for i in range(n):
    assert bytes(b.ram[4 + i]) == dat[i * 32768:(i + 1) * 32768], f'block {4+i} differs'
print(f'PASS CP/M loader: {n} x 32K blocks of HAMSAM2.DAT in banks 4-{3+n}, {len(b.fdc_reads)} FDC reads')
