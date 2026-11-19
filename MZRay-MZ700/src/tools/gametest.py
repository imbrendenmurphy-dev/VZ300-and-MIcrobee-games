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

def skip_attract():
    """SPACE during the title skips to the intro page; SPACE again starts the game."""
    assert m.run_until(sym['tm1'], 50_000_000)
    m.run_t(70938*10)
    m.held = {'SPACE'}; assert m.run_until(sym['ws1'], 50_000_000); m.held = set()
    assert m.run_until(sym['ws2'], 50_000_000)
    m.held = {'SPACE'}; m.run_t(70938); m.held = set()
skip_attract()
m.shot('g_title.png', 2)
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
frame(20); walk(['SPACE'], 1)
check('second shot kills the bear', m.mem[OBJ] == 0)
PART = sym['PART']
live = lambda: sum(1 for i in range(32) if m.mem[PART+i*8+7])
check('the bear bursts into pieces', live() >= 15)
check('a splat is playing', m.mem[sym['sact']] == 1)
for i in range(4):
    frame(1); m.shot('g_explode%d.png' % i, 2)
frame(40)
check('the pieces fade away', live() == 0)
t_snd = m.cpu.t

# bitten: the sky flashes red
GOD[0] = False; m.mem[sym['hp']] = 100
putobj(0, 1, 9.1, 9.5, flags=0x80, cool=0); frame(1)
check('bite flashes the sky red', m.mem[sym['d1_cl']+1] == 0x22 or m.mem[sym['d2_cl']+1] == 0x22)
m.shot('g_bitten.png', 2)
GOD[0] = True; clearobjs(); frame(6)
check('sky back to normal', m.mem[sym['d1_cl']+1] == m.mem[sym['skycol']])

# a boss: big burst, white flash, its gates open
go(4); clearobjs()
place(10.5, 7.5, 64); putobj(0, 3, 10.5, 8.5, hp=1, flags=0x80, cool=250)   # Big Fella in the den
frame(3); walk(['SPACE'], 1)
check('Big Fella goes down', m.mem[OBJ] == 0)
check('boss burst is big', live() >= 28)
check('white flash', m.mem[sym['d1_cl']+1] == 0x77 or m.mem[sym['d2_cl']+1] == 0x77)
check('the den gate opens', mapcell(13, 9) == 0)
frame(1); m.shot('g_boss_burst.png', 2)
frame(60)
m.wav('sfx_preview.wav', t_snd - 8*70938*10, m.cpu.t)

# the in-game tune dinks away when nothing else is playing
go(0); clearobjs(); n0 = len(m.snd); frame(60)
dinks = sum(1 for t, a, v in m.snd[n0:] if a == 0xE008 and v == 1)
check('in-game tune plays', dinks >= 2)
m.wav('tune_preview.wav', m.snd[n0][0], m.cpu.t)
m.shot('g_kill.png', 2)
putobj(0, 1, 11.5, 9.5, hp=2, flags=0x80, cool=200)
place(8.5, 9.5, 128); frame(2)
check('nothing targeted when facing away', (m.mem[sym['target']] | m.mem[sym['target']+1] << 8) == 0)
place(8.5, 9.5, 0); putobj(0, 1, 12.5, 9.5, hp=2, flags=0x80, cool=200)
x0 = m.mem[OBJ+2] << 8 | m.mem[OBJ+1]; frame(10)
check('awake bear walks towards you', (m.mem[OBJ+2] << 8 | m.mem[OBJ+1]) < x0)
# busy view: speed with sprites on screen
go(1); clearobjs()
for i, (x, y) in enumerate([(10.5, 8.5), (11.5, 9.5), (12.5, 10.5), (13.5, 9.5), (11, 11)]):
    putobj(i, [1, 6, 9, 10, 16][i], x, y, hp=9, cool=250)
for mode, key in enumerate('1234'):
    m.held = {key}; frame(); m.held = set()
    place(8.5, 9.5, 0); frame(2); setw('fields', 0)
    t0 = m.cpu.t; frame(16)
    print('  busy view, mode %d: %.1f fps (simulator)' % (mode+1, 16*3546895/(m.cpu.t-t0)))
m.shot('g_busy.png', 2)
m.held = {'3'}; frame(); m.held = set()
# automap: known areas show it on M; the maze needs its map scroll first
CRAM = 0xD800
MAPTOP = CRAM + 40 + 3*40 + 4
go(0); place(2.5, 2.5, 0); walk('M', 3)
check('map shows in the Homestead', m.mem[MAPTOP] == 0x11 and m.mem[MAPTOP + 1*40 + 2] == 0x00)
m.shot('g_map.png', 2)
frame(2)
check('view comes back after M', m.mem[sym['mapon']] == 0)
go(2); clearobjs(); place(3.5, 3.5, 0)
m.mem[sym['aflags']+2] = 0; walk('M', 2)
check('no map in the maze yet', m.mem[sym['mapon']] == 0)
putobj(0, 15, 3.5, 3.5); frame(2)
check('map scroll picked up', m.mem[sym['aflags']+2] & 1 == 1)
walk('M', 3)
check('maze map shows after the scroll', m.mem[sym['mapon']] == 1)
m.shot('g_map_maze.png', 2)
frame(2)
# fog in the mine: far walls in the murk, far creatures hidden
go(3); clearobjs()
check('mine has fog', m.mem[sym['fogh']] == 7)
place(1.5, 3.5, 0); frame(2)
fogc = 0x11; row = 11
cells = [m.mem[CRAM + 40 + row*40 + c] for c in range(40)]
check('far wall drawn in fog colours', any(v == 0x22 for v in cells) and any(v == 0x00 for v in cells))
m.shot('g_fog_mine.png', 2)
putobj(0, 1, 8.5, 3.5, flags=0, cool=250); frame(2)
check('bear in the fog unseen', m.mem[sym['nvis']] == 1)
putobj(0, 1, 4.5, 3.5, flags=0, cool=250); frame(2)
check('bear near enough seen', m.mem[sym['nvis']] == 2)
go(5); place(1.5, 2.5, 0); frame(2); m.shot('g_fog_swamp.png', 2)
go(8); place(1.5, 2.5, 0); frame(2); m.shot('g_fog_lair.png', 2)
go(0); frame(2)
check('no fog at the homestead', m.mem[sym['fogh']] == 0)

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
