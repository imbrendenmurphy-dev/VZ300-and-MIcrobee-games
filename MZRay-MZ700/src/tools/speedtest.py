# Frame rates of the game in fixed views, all four modes. Set MZ_VRAMWAIT=72 for emulator-like timing.
import os
from mzemu import MZ, FIELD
d = open('DROPBEAR_FULL.MZT', 'rb').read()
sym = {l.split()[0]: int(l.split()[1], 16) for l in open('game.sym')}
m = MZ(0x1200, d[128:], 0x1200)
assert m.run_until(sym['tm1'], 50_000_000)
m.held = {'SPACE'}; m.run_until(sym['ws1'], 50_000_000); m.held = set()
m.run_until(sym['ws2'], 50_000_000); m.held = {'SPACE'}; m.run_t(FIELD); m.held = set()
m.run_until(sym['gloop'], 50_000_000)
def frame(n=1):
    for _ in range(n):
        m.mem[sym['hp']] = 100
        m.cpu.step(); m.run_until(sym['gloop'], 20_000_000)
def place(x, y, a):
    for nm, v in (('px', x), ('py', y)):
        m.mem[sym[nm]] = int(v*256) & 255; m.mem[sym[nm]+1] = int(v*256) >> 8
    m.mem[sym['pang']] = a
def go(area):
    m.mem[sym['newarea']] = area; m.mem[sym['goarea']] = 1; m.mem[sym['entrycell']] = 0x11; frame(2)
VIEWS = [('homestead room', 0, 1.5, 1.5, 20), ('bush track open', 1, 8.5, 9.5, 0), ('mine corridor', 3, 1.5, 3.5, 0),
         ('homestead hall', 0, 1.5, 9.5, 0)]
print('VRAM wait %s T per write' % os.environ.get('MZ_VRAMWAIT', '0'))
tot = [0]*4
for name, area, x, y, a in VIEWS:
    go(area); row = []
    for mode, key in enumerate('1234'):
        m.held = {key}; frame(); m.held = set()
        place(x, y, a); frame(2)
        t0 = m.cpu.t; n = 8
        for i in range(n):
            place(x, y, (a + i*2) & 255); frame()        # turning slowly, like real play
        fps = n*3546895/(m.cpu.t-t0); row.append(fps); tot[mode] += fps
    print('  %-16s %5.1f %5.1f %5.1f %5.1f' % ((name,) + tuple(row)))
print('  %-16s %5.1f %5.1f %5.1f %5.1f' % (('average',) + tuple(t/len(VIEWS) for t in tot)))
