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
GOD = [True]                     # keep the tester alive unless a test wants to get bitten
def frame(n=1):
    for _ in range(n):
        if GOD[0]: m.mem[sym['hp']] = 100
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

# ---- sprites, creatures, shooting
OBJ = sym['OBJ']
def putobj(i, typ, x, y, hp=2, flags=0, cool=0):
    m.mem[OBJ+i*8:OBJ+i*8+8] = bytes([typ, int(x*256) & 255, int(x*256) >> 8, int(y*256) & 255, int(y*256) >> 8, hp, flags, cool])
def clearobjs():
    m.mem[OBJ:OBJ+256] = bytes(256)
go(0); place(1.5, 1.5, 40); frame(2)
check('furniture and pickups are on screen', m.mem[sym['nvis']] >= 2)
m.shot('g_sprites_room.png', 2)
go(1); clearobjs()
place(8.5, 9.5, 0)                               # open ground in the Bush Track
putobj(0, 1, 11.5, 9.5)                           # a drop bear three cells ahead, asleep
m.held = {'3'}; frame(2); m.held = set()
check('bear seen and targeted', m.mem[sym['nvis']] >= 2 and (m.mem[sym['target']] | m.mem[sym['target']+1] << 8) == OBJ)
m.shot('g_bear_far.png', 2)
putobj(0, 1, 9.9, 9.5, flags=0x80)
frame(2); m.shot('g_bear_near.png', 2)
m.held = {'1'}; frame(2); m.held = set(); m.shot('g_bear_mode1.png', 2)
m.held = {'3'}; frame(2); m.held = set()
GOD[0] = False; m.mem[sym['hp']] = 100
putobj(0, 1, 9.1, 9.5, flags=0x80, cool=0); frame(3)
check('an awake bear bites', m.mem[sym['hp']] < 100)
GOD[0] = True
ammo0 = m.mem[sym['ammo']]
putobj(0, 1, 11.5, 9.5, hp=2, flags=0x80, cool=200)
frame(2); walk(['SPACE'], 1); frame(2)
check('shooting uses ammo and hurts', m.mem[sym['ammo']] == ammo0-1 and m.mem[OBJ+5] == 1)
m.shot('g_gunflash.png', 2)
frame(20); walk(['SPACE'], 1); frame(2)
check('second shot kills the bear', m.mem[OBJ] == 0)
m.shot('g_kill.png', 2)
putobj(0, 1, 11.5, 9.5, hp=2, flags=0x80, cool=200)
place(8.5, 9.5, 128); frame(2)
check('nothing targeted when facing away', (m.mem[sym['target']] | m.mem[sym['target']+1] << 8) == 0)
place(8.5, 9.5, 0); putobj(0, 1, 12.5, 9.5, hp=2, flags=0x80, cool=200)
x0 = m.mem[OBJ+2] << 8 | m.mem[OBJ+1]; frame(10)
check('awake bear walks towards you', (m.mem[OBJ+2] << 8 | m.mem[OBJ+1]) < x0)
# busy view: speed with sprites on screen
clearobjs()
for i, (x, y) in enumerate([(10.5, 8.5), (11.5, 9.5), (12.5, 10.5), (13.5, 9.5), (11, 11)]):
    putobj(i, [1, 6, 9, 10, 16][i], x, y, hp=9, cool=250)
for mode, key in enumerate('1234'):
    m.held = {key}; frame(); m.held = set()
    place(8.5, 9.5, 0); frame(2); setw('fields', 0)
    t0 = m.cpu.t; frame(16)
    print('  busy view, mode %d: %.1f fps (simulator)' % (mode+1, 16*3546895/(m.cpu.t-t0)))
m.shot('g_busy.png', 2)
m.held = {'3'}; frame(); m.held = set()
# dying puts you back at the door, full health
GOD[0] = False; m.mem[sym['hp']] = 1
putobj(0, 1, 9.1, 9.5, flags=0x80, cool=0); place(8.5, 9.5, 0)
m.cpu.step(); ok = m.run_until(sym['ws2'], 50_000_000)
check('death page shows', ok)
m.shot('g_dead.png', 2)
m.held = {'SPACE'}; m.run_t(70938); m.held = set()
check('back in play with full health', m.run_until(sym['gloop'], 50_000_000) and m.mem[sym['hp']] == 100)
GOD[0] = True

go(8); place(14.5, 14.5, 0); walk('W', 12); frame(2)
check('last way out finishes the game', m.run_until(sym['ws2'], 50_000_000))
m.shot('g_win.png', 2)
print('FAILED: %d' % len(fails) if fails else 'all passed')
