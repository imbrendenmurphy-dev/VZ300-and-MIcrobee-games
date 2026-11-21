"""test_joy.py - MZ-1X03 joystick support in the simulator.

    py tools/test_joy.py

Uses the MiSTer-style 1X03 model in mzsim.py: J on the title with nothing
plugged in, then calibration, starting a game with the fire button,
moving and shooting with the stick, and the keyboard still working.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402

fails = []


def check(cond, what):
    print(('  ok   ' if cond else '  FAIL ') + what)
    if not cond:
        fails.append(what)


g = Game()
m = g.m
mem = m.mem
D = S['DROIDS']


def tap(key):
    g.run(3, [key])
    g.run(6)


g.run(60)
check('JOYSTICK OFF' in g.text(19), 'title shows the joystick option (%s)' % g.text(19).strip())

print('nothing plugged in')
tap('j')
g.run(10)
check(mem[S['joy_on']] == 0 and 'NO JOYSTICK' in g.text(19), 'J with no stick: "%s"' % g.text(19).strip())

print('stick plugged in, centred')
m.joy = dict(x=0, y=0, f1=False, f2=False)
tap('j')
g.run(10)
check(mem[S['joy_on']] == 1, 'J switches the joystick on')
cx, cy = mem[S['joy_cx']], mem[S['joy_cy']]
check(20 < cx < 200 and 20 < cy < 200, 'calibrated centre %d,%d' % (cx, cy))
check('JOYSTICK ON' in g.text(19), 'title says "%s"' % g.text(19).strip())
g.shot('j_01_title')
m.joy['x'] = 1
g.run(4)
check(mem[S['joy_dirs']] == 0x08, 'stick right reads as RIGHT (%02X)' % mem[S['joy_dirs']])
m.joy['x'], m.joy['y'] = -1, -1
g.run(4)
check(mem[S['joy_dirs']] == 0x05, 'stick up-left reads as UP+LEFT (%02X)' % mem[S['joy_dirs']])
m.joy['x'], m.joy['y'] = 0, 0
g.run(4)
check(mem[S['joy_dirs']] == 0, 'centred reads as nothing')

print('fire starts a game')
m.joy['f1'] = True
g.run(6)
m.joy['f1'] = False
for _ in range(300):
    g.run(2)
    if 'SCORE' in g.text(0) and mem[S['frame']] > 20:
        break
check('SCORE' in g.text(0), 'game running after the joystick fire button')
g.run(200)
for _ in range(50):
    mem[S['invuln']] = 200
    g.run(1)

print('moving with the stick')
x0 = mem[D + 1]
m.joy['x'] = -1
for _ in range(40):
    mem[S['invuln']] = 200
    g.run(1)
m.joy['x'] = 0
x1 = mem[D + 1]
check(x1 < x0, 'stick left moves the probe left (%d -> %d)' % (x0, x1))
m.joy['x'] = 1
for _ in range(40):
    mem[S['invuln']] = 200
    g.run(1)
m.joy['x'] = 0
x2 = mem[D + 1]
check(x2 > x1, 'stick right moves it right (%d -> %d)' % (x1, x2))

print('keyboard still works')
for _ in range(30):
    mem[S['invuln']] = 200
    g.run(1, ['left'])
check(mem[D + 1] < x2, 'cursor left still moves (%d -> %d)' % (x2, mem[D + 1]))

print('shooting with the stick')
mem[D] = 8                         # 461 SENTRY, laser
mem[D + 3] = 46
shots_before = sum(1 for i in range(10) if mem[S['SHOTS'] + i * 8])
m.joy['x'], m.joy['f2'] = 1, True
seen = 0
for _ in range(20):
    mem[S['invuln']] = 200
    g.run(1)
    seen = max(seen, sum(1 for i in range(10) if mem[S['SHOTS'] + i * 8] and mem[S['SHOTS'] + i * 8 + 5] == 0))
m.joy['x'], m.joy['f2'] = 0, False
check(seen > 0, 'fire 2 + right fires a shot (%d player shots seen)' % seen)
g.shot('j_02_game')

print('\n%d failures' % len(fails) if fails else '\nall checks passed')
