# Counts colour-RAM writes per game frame and which view rows they hit (diagnostic).
from mzemu import MZ, FIELD
d = open('DROPBEAR.MZT', 'rb').read()
sym = {l.split()[0]: int(l.split()[1], 16) for l in open('game.sym')}
m = MZ(0x1200, d[128:], 0x1200)
m.run_until(sym['tm1'], 50_000_000)
m.held = {'SPACE'}; m.run_until(sym['ws1'], 50_000_000); m.held = set()
m.run_until(sym['ws2'], 50_000_000); m.held = {'SPACE'}; m.run_t(FIELD); m.held = set()
m.run_until(sym['gloop'], 50_000_000)
cnt = {}
orig = m.wr
def wr(a, v):
    if 0xD800 <= a < 0xDC00: cnt[a] = cnt.get(a, 0) + 1
    orig(a, v)
m.cpu.wr = wr
def frame():
    m.mem[sym['hp']] = 100; m.cpu.step(); m.run_until(sym['gloop'], 20_000_000)
for i in range(4): frame()
for i in range(3):
    cnt.clear(); frame()
    rows = [sum(cnt.get(0xD800+40+r*40+c, 0) for c in range(40)) for r in range(22)]
    print('frame: %d writes; per view row %s' % (sum(cnt.values()), rows))
print('dirty flags', list(m.mem[sym['PREVP']+128:sym['PREVP']+168]))
print('tops', list(m.mem[sym['PREVP']:sym['PREVP']+40]))
