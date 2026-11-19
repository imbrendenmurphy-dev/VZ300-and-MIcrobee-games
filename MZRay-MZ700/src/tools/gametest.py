# Tests the DROPBEAR MZ walkabout in the simulator: start, walking, doors, keys, switches, secrets,
# furniture, pickups, area changes, frame rates. Run from src after build_game.py.
import sys
from mzemu import MZ
d = open('DROPBEAR.MZT', 'rb').read()
sym = {l.split()[0]: int(l.split()[1], 16) for l in open('game.sym')}
m = MZ(int.from_bytes(d[20:22], 'little'), d[128:], int.from_bytes(d[22:24], 'little'))
R = lambda n: m.mem[sym[n]]
W16 = lambda n: m.mem[sym[n]] | m.mem[sym[n]+1] << 8
def setw(n, v): m.mem[sym[n]] = v & 255; m.mem[sym[n]+1] = v >> 8
fails = []
def check(what, ok):
    print(('ok   ' if ok else 'FAIL ') + what)
    if not ok: fails.append(what)

assert m.run_until(sym['ws2'], 50_000_000)
m.shot('g_title.png', 2)
m.held = {'SPACE'}; m.run_t(70938); m.held = set()
check('game starts', m.run_until(sym['gloop'], 50_000_000))
def frame(n=1):
    for _ in range(n):
        m.cpu.step(); m.run_until(sym['gloop'], 20_000_000)
def place(x, y, ang):
    setw('px', int(x*256)); setw('py', int(y*256)); m.mem[sym['pang']] = ang
def mapcell(x, y): return m.mem[sym['MAP']+y*16+x]
def go(area):
    m.mem[sym['newarea']] = area; m.mem[sym['goarea']] = 1
    m.mem[sym['entrycell']] = 0x11; m.mem[sym['entryang']] = 0; frame(2)
frame(3)
m.shot('g_start.png', 2)
check('starts in area 0 at 1,1', R('area') == 0 and W16('px') >> 8 == 1 and W16('py') >> 8 == 1)

# frame rate per mode, looking down the first room
for mode, key in enumerate('1234'):
    m.held = {key}; frame(); m.held = set()
    place(1.5, 1.5, 20); frame(2); setw('fields', 0)
    t0 = m.cpu.t; frame(16)
    print('  mode %d: %.1f fps (simulator, no VRAM waits)' % (mode+1, 16*3546895/(m.cpu.t-t0)))
m.held = {'3'}; frame(); m.held = set()

def walk(keys, n):
    m.held = set(keys); frame(n); m.held = set()
place(1.5, 1.5, 0); walk('W', 15)
check('W walks east', W16('px') > 0x200)
place(2.5, 2.5, 0); walk(['up'], 5)
check('cursor up walks', W16('px') > 0x280)
a0 = m.mem[sym['pang']]; walk('A', 10)
check('A turns left', m.mem[sym['pang']] != a0)
place(2.5, 2.5, 0); walk('E', 10)
check('E strafes right (south)', W16('py') > 0x280 and abs(W16('px')-0x280) < 8)

place(4.5, 3.5, 0); walk('W', 12)
check('door opens', mapcell(5, 3) == 0)
walk('W', 20)
check('walk through the doorway', W16('px') >> 8 >= 6)
place(8.5, 4.5, 64); walk('W', 12)
check('secret wall opens', mapcell(8, 5) == 0)
place(2.5, 3.5, 64); walk('W', 15)
check('drum blocks', W16('py') < 0x3D0)
place(3.5, 3.5, 64); walk('W', 10)
check('ammo picked up', R('ammo') == 55)
m.shot('g_msg.png', 2)
place(14.5, 14.5, 0); walk('W', 12); frame(2)
check('way out leads to the Bush Track', R('area') == 1)
m.shot('g_area1_entry.png', 2)
print('  arrived at', hex(W16('px')), hex(W16('py')), 'facing', m.mem[sym['pang']])

m.mem[sym['keys']] = 0
place(3.5, 11.5, 64); walk('W', 12)
check('locked door stays shut without a key', mapcell(3, 12) == 6)
m.mem[sym['keys']] = 1; walk('W', 12)
check('key opens it', mapcell(3, 12) == 0 and R('keys') == 0)

go(3)
check('area 3 loaded', R('area') == 3)
place(2.5, 12.5, 64); walk('W', 12)
check('switch flips and gate opens', mapcell(2, 13) == 8 and mapcell(11, 9) == 0)
go(0)
check('area 0 remembers its open door', mapcell(5, 3) == 0 and mapcell(8, 5) == 0)

# a view of every area
views = [(0, 1.5, 1.5, 20), (1, 1.5, 2.5, 0), (2, 1.5, 7.5, 0), (3, 1.5, 2.5, 10), (4, 1.5, 2.5, 0),
         (5, 1.5, 2.5, 0), (6, 1.5, 2.5, 0), (7, 1.5, 2.5, 0), (8, 1.5, 2.5, 0)]
for a, x, y, ang in views:
    go(a); place(x, y, ang); frame(2); m.shot('g_area%d.png' % a, 2)

go(8); place(14.5, 14.5, 0); walk('W', 12); frame(2)
check('last way out finishes the game', m.run_until(sym['ws2'], 50_000_000))
m.shot('g_win.png', 2)
print('FAILED: %d' % len(fails) if fails else 'all passed')
