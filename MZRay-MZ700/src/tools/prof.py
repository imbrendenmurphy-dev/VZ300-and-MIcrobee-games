# Where does a game frame's time go? Samples T-states per routine (by nearest preceding label).
import bisect, sys
from mzemu import MZ
d = open('DROPBEAR_FULL.MZT', 'rb').read()
sym = {l.split()[0]: int(l.split()[1], 16) for l in open('game.sym')}
m = MZ(0x1200, d[128:], 0x1200)
m.run_until(sym['tm1'], 50_000_000)            # skip the title, then the intro page
m.held = {'SPACE'}; m.run_until(sym['ws1'], 50_000_000); m.held = set()
m.run_until(sym['ws2'], 50_000_000)
m.held = {'SPACE'}; m.run_t(70938); m.held = set()
m.run_until(sym['gloop'], 50_000_000)
m.held = {sys.argv[4] if len(sys.argv) > 4 else '3'}; m.cpu.step(); m.run_until(sym['gloop']); m.held = set()
x, y, a = (float(v) for v in (sys.argv[1:4] if len(sys.argv) > 3 else (1.5, 1.5, 20)))
def place():
    for n, v in (('px', x), ('py', y)):
        m.mem[sym[n]] = int(v*256) & 255; m.mem[sym[n]+1] = int(v*256) >> 8
    m.mem[sym['pang']] = int(a)
TOP = ['objects', 'ai', 'proj', 'smul', 'mula', 'mul8', 'sprcol', 'render', 'castray', 'drawcol1', 'drawcol2',
       'poll', 'hud', 'timers', 'turnmove', 'getinput', 'fire', 'addgun', 'insord', 'pick', 'testcell',
       'gdraw1', 'gdraw2', 'gprep', 'growp', 'gvset', 'invalall', 'dirtyray', 'sndtick', 'sndframe', 'partcol',
       'parts', 'sprites', 'qmul', 'fogchk', 'rnd', 'sfx', 'flash', 'attract']
labs = sorted((sym[n], n) for n in TOP if n in sym)
addrs = [p for p, n in labs]
cost = {}
if len(sys.argv) > 5:                          # optional area number
    m.mem[sym['newarea']] = int(sys.argv[5]); m.mem[sym['goarea']] = 1; m.mem[sym['entrycell']] = 0x11
    for _ in range(2): m.cpu.step(); m.run_until(sym['gloop'])
place()
for _ in range(2): m.cpu.step(); m.run_until(sym['gloop'])
t0 = m.cpu.t
for _ in range(4):
    place(); m.cpu.step()
    while m.cpu.pc != sym['gloop']:
        pc = m.cpu.pc; t = m.cpu.t; m.cpu.step()
        i = bisect.bisect_right(addrs, pc) - 1
        n = labs[i][1] if i >= 0 else '?'
        cost[n] = cost.get(n, 0) + m.cpu.t - t
tot = m.cpu.t - t0
for n, c in sorted(cost.items(), key=lambda kv: -kv[1]):
    print('%-10s %5.1f%%  %7d T/frame' % (n, 100*c/tot, c//4))
print('frame %d T = %.1f fps' % (tot//4, 4*3546895/tot))
