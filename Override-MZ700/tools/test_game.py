"""test_game.py - scripted gameplay checks for OVERRIDE in the simulator.

    py tools/test_game.py

Starts a game from the title screen, then pokes the game state to check
shooting, transfers, lifts, consoles, clearing a deck and game over.
Screenshots go to build/shots/t_*.png.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402

DSZ = 16
fails = []
g = Game()
m = g.m
mem = m.mem
D = S['DROIDS']


def check(cond, what):
    print(('  ok   ' if cond else '  FAIL ') + what)
    if not cond:
        fails.append(what)


def droid(i):
    a = D + i * DSZ
    return dict(type=mem[a], x=mem[a + 1], y=mem[a + 2], en=mem[a + 3])


def enemies():
    return [(i, droid(i)) for i in range(1, 15) if droid(i)['type'] != 0xFF]


def put_player(x, y):
    mem[D + 1] = x
    mem[D + 2] = y


def score():
    return int('%02X%02X%02X' % (mem[S['score'] + 2], mem[S['score'] + 1], mem[S['score']]))


def in_routine(name, size=0x200):
    return S[name] <= m.cpu.pc < S[name] + size


def wait_deck(maxf=400):
    """deck play is running when the frame counter ticks and the HUD is up"""
    last = mem[S['frame']]
    n = 0
    for _ in range(maxf):
        mem[S['invuln']] = 200
        g.run(1)
        f = mem[S['frame']]
        if f != last and mem[S['event']] == 0 and mem[0xD000 + 1] == 0x13:   # 'S' of SCORE
            n += 1
            if n >= 3:
                return True
        last = f
    return False


def run(n, keys=()):
    for _ in range(n):
        mem[S['invuln']] = 200
        g.run(1, keys)


def set_host(t):
    mem[D] = t
    mem[D + 3] = 60


print('start')
g.run(100)
g.run(4, ['space'])
g.run(40)
check(wait_deck(), 'game reaches the deck')
g.shot('t_01_start')
check(mem[S['deck']] == 0 and mem[S['ship']] == 0, 'ship 1 deck 1')
n0 = len(enemies())
check(n0 == 3, '3 droids on the bridge (%d)' % n0)

print('shooting')
set_host(8)                       # 461 SENTRY, laser
mem[S['invuln']] = 250
i, e = enemies()[0]
# freeze it and stand 8 cells to its left on the same row
mem[D + i * DSZ + 15] = 250       # D_WAIT
put_player(e['x'] - 8, e['y'])
# clear the space between (test only)
sc0 = score()
en0 = e['en']
for _ in range(30):
    run(2, ['space', 'right'])
    if droid(i)['type'] == 0xFF:
        break
g.shot('t_02_shoot')
e2 = droid(i)
check(e2['type'] == 0xFF or e2['en'] < en0, 'laser hits (energy %d -> %d, type %02X)' % (en0, e2['en'], e2['type']))
for _ in range(60):
    if droid(i)['type'] == 0xFF:
        break
    run(2, ['space', 'right'])
check(droid(i)['type'] == 0xFF, 'droid destroyed')
check(score() > sc0, 'score went up (%d)' % score())
g.run(6)
g.shot('t_03_boom')

print('transfer')
lx, ly = mem[S['LIFTS']], mem[S['LIFTS'] + 1]
i, e = enemies()[0]
etype = e['type']
mem[D + i * DSZ + 1] = lx + 11
mem[D + i * DSZ + 2] = ly
mem[D + i * DSZ + 15] = 250
put_player(lx + 5, ly)
mem[S['bump_cool']] = 0
run(14, ['space'])
check(mem[S['xmode']] > 0, 'holding fire arms transfer mode')
g.shot('t_04_xmode')
ev = 0
for _ in range(40):
    run(2, ['right'])
    if 'C I R C U I T' in g.text(0):
        ev = 1
        break
check(ev == 1, 'touching a droid starts the transfer')
g.run(80)
g.shot('t_05_duel_ready')
g.run(150, [])
g.shot('t_06_duel')
for _ in range(900):
    for k in range(13):
        mem[S['TRC'] + k] = 0
    g.run(1)
    if 'C I R C U I T' not in g.text(0):
        break
check(mem[D] == etype, 'took over droid type %d (host %d)' % (etype, mem[D]))
check(mem[D + 14] == S['C_DL4'], 'new host is drawn yellow')
check(wait_deck(), 'back on the deck after the duel')
g.shot('t_07_newhost')

print('lift')
put_player(lx, ly)
run(4)
run(4, ['space'])
run(10)
check('CHOOSE DECK' in g.text(23), 'lift screen opens')
g.shot('t_08_lift')
run(4, ['down'])
run(8)
sel = mem[S['lift_sel']]
check(sel == 1, 'down selects the next deck (%d)' % sel)
g.shot('t_08b_lift')
run(4, ['space'])
check(wait_deck(), 'back on a deck')
check(mem[S['deck']] == sel, 'arrived on deck %d' % mem[S['deck']])
g.shot('t_09_newdeck')

print('console')
cx, cy = mem[S['CONS']], mem[S['CONS'] + 1]
# stand just below (top rooms) or above (bottom rooms) the console
for dy in (1, -2):
    put_player(cx, cy + dy)
    fl = 0
    run(4)
    run(4, ['space'])
    run(20)
    if 'DECK CONSOLE' in g.text(0):
        break
check('DECK CONSOLE' in g.text(0), 'console opens')
g.shot('t_10_console')
run(6, ['space'])
check(wait_deck(), 'console closes')
print('clear the deck')
for i, e in enemies():
    mem[D + i * DSZ + 3] = 1
    mem[D + i * DSZ + 15] = 250
mem[S['invuln']] = 250
put_player(enemies()[0][1]['x'] - 3, enemies()[0][1]['y'])
for _ in range(150):
    g.run(2)
    for i, e in enemies():
        # poke an explosion onto each droid
        mem[D + i * DSZ + 3] = 0
    if not enemies():
        break
for i, e in enemies():
    mem[D + i * DSZ] = 0xFF
mem[S['check_clear']] = 1
g.run(10)
check(mem[S['dimmed']] == 1, 'lights go down on a cleared deck')
g.shot('t_11_dark')

print('game over')
mem[S['score'] + 2] = 0x03
set_host(0)
mem[D + 3] = 1
mem[S['invuln']] = 0
# an enemy shot right on top of us
sh = S['SHOTS']
mem[sh:sh + 8] = bytes([5, mem[D + 1] + 1, mem[D + 2], 0, 0, 1, 10, 0])
g.run(10)
check(mem[S['pl_dead']] == 1, 'probe destroyed')
for _ in range(300):
    g.run(2)
    if 'G A M E' in g.text(9):
        break
g.shot('t_12_gameover')
check('G A M E' in g.text(9), 'game over screen')
for _ in range(400):
    g.run(2)
    if 'ENTER YOUR NAME' in g.text(21):
        break
check('ENTER YOUR NAME' in g.text(21), 'high score entry')
g.run(4, ['up'])
g.run(4)
g.run(4, ['up'])
g.run(4)
g.run(4, ['space'])
g.run(4)
g.run(4, ['space'])
g.run(4)
g.run(4, ['space'])
g.run(20)
g.shot('t_13_hiscore')
name = bytes(mem[S['HISCORES'] + 8 * mem[S['hiscore_rank']]:][:3])
check(name[:1] == b'C', 'name entered (%r)' % name)

print('\n%d failures' % len(fails) if fails else '\nall checks passed')
