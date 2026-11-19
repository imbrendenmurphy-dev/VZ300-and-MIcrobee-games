# Diagnostic: where does an incremental frame differ from a forced full redraw? (Homestead, mode 3)
from mzemu import MZ, FIELD
d = open('DROPBEAR.MZT', 'rb').read()
sym = {l.split()[0]: int(l.split()[1], 16) for l in open('game.sym')}
m = MZ(0x1200, d[128:], 0x1200)
m.run_until(sym['tm1'], 50_000_000)
m.held = {'SPACE'}; m.run_until(sym['ws1'], 50_000_000); m.held = set()
m.run_until(sym['ws2'], 50_000_000); m.held = {'SPACE'}; m.run_t(FIELD); m.held = set()
m.run_until(sym['gloop'], 50_000_000)
def frame():
    m.mem[sym['hp']] = 100; m.cpu.step(); m.run_until(sym['gloop'], 20_000_000)
def place(x, y, a):
    for nm, v in (('px', x), ('py', y)):
        m.mem[sym[nm]] = int(v*256) & 255; m.mem[sym[nm]+1] = int(v*256) >> 8
    m.mem[sym['pang']] = a
m.held = {'3'}; frame(); m.held = set()
for step in range(6):
    place(1.5 + step*0.1, 1.5, (step*9) & 255); frame()
frame()
view = lambda: bytes(m.mem[0xD800+40:0xD800+40+880])
a = view(); nv = m.mem[sym['nvis']]
P = sym['PREVP']; m.mem[P+128:P+168] = bytes([1]*40); frame(); b = view()
print('nvis', nv, m.mem[sym['nvis']])
for i in range(880):
    if a[i] != b[i]: print('row %2d col %2d: incremental %02X full %02X' % (i//40, i % 40, a[i], b[i]))
