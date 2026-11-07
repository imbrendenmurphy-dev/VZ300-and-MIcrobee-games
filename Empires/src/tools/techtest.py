#!/usr/bin/env python3
"""Technology / new-building test: grant all technologies and resources, find
sites near the town for each new building (mine on hills, harbour on the shore,
school, hospital, temple, university, the 2x2 Forum), build them, let time run
and check they complete and do their work."""
import os, subprocess, sys
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build'))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open('empires.sym')}
TW = int(os.environ.get('TW', '340'))
def tap(k, n=1, hold=6, gap=6):
    o = []
    for _ in range(n):
        o += ['key %d 1' % k, 'frames %d' % hold, 'key %d 0' % k, 'frames %d' % gap]
    return o
PRE = ['frames 60'] + tap(3) + ['frames %d' % TW] + tap(33) + ['frames 1500']
def run(lines):
    return subprocess.run(['../tools/beeemu', 'EMPIRES.COM', 'banked'], input='\n'.join(lines) + '\n',
                          capture_output=True, text=True).stderr
run(PRE + ['mem tt0.bin', 'blk 8 tm8.bin', 'blk 9 tm9.bin'])
m = open('tt0.bin', 'rb').read()
MB = [open('tm8.bin', 'rb').read(), open('tm9.bin', 'rb').read()]
def t(x, y): return MB[y >> 6][(y & 63) * 256 + x] & 31
def o(x, y): return MB[y >> 6][0x4000 + (y & 63) * 256 + x]
def ex(x, y): return MB[y >> 6][(y & 63) * 256 + x] & 128
sx, sy = m[sym['startxy']], m[sym['startxy'] + 1]
used = {(sx, sy), (sx + 1, sy), (sx, sy + 1), (sx + 1, sy + 1)}
LAND = (3, 4, 5, 8, 13)
def free(x, y): return (x, y) not in used and ex(x, y) and o(x, y) == 0
def find(pred, r0=1, r1=7):
    for r in range(r0, r1 + 1):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                x, y = sx + dx, sy + dy
                if 0 <= x < 128 and 0 <= y < 128 and free(x, y) and pred(x, y):
                    return (x, y)
def water_next(x, y): return any(t(x + a, y + b) < 3 for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
plan = []
s = find(lambda x, y: t(x, y) in (8, 14));                        plan.append(('mine', 10, s))
if s: used.add(s)
s = find(lambda x, y: t(x, y) in LAND and water_next(x, y), 1, 7); plan.append(('harbour', 12, s))
if s: used.add(s)
for name, tool in (('school', 11), ('hospital', 13), ('temple', 14), ('university', 15)):
    s = find(lambda x, y: t(x, y) in (4, 5)); plan.append((name, tool, s))
    if s: used.add(s)
def f2(x, y): return all(free(x + a, y + b) and t(x + a, y + b) in (3, 4, 5, 13) for a in (0, 1) for b in (0, 1))
s = find(f2, 2, 7); plan.append(('forum', 16, s))
if s:
    for a in (0, 1):
        for b in (0, 1): used.add((s[0] + a, s[1] + b))
print('start', (sx, sy), 'plan', plan)
def poke16(name, v): return 'poke %04X %02X %02X' % (sym[name], v & 255, v >> 8)
L = list(PRE) + [poke16('techs', 0x1FFF), poke16('wood', 3000), poke16('stone', 3000), poke16('gold', 3000),
                 poke16('pop', 60), poke16('food', 3000), 'frames 2'] + tap(2) + ['frames 4']  # B: page 2
cx, cy = sx, sy
K = {'up': 23, 'left': 1, 'down': 19, 'right': 4}
def goto(x, y):
    global cx, cy
    out = []
    if x > cx: out += tap(K['right'], x - cx)
    if x < cx: out += tap(K['left'], cx - x)
    if y > cy: out += tap(K['down'], y - cy)
    if y < cy: out += tap(K['up'], cy - y)
    cx, cy = x, y
    return out
for name, tool, s in plan:
    if not s: continue
    slot = tool - 10
    key = 33 + slot if slot < 9 else 32
    L += tap(key) + goto(*s) + tap(55) + ['frames 10']
L += ['frames 20', 'shot d_tt1.bin'] + tap(46, 2) + ['frames 6000', 'shot d_tt2.bin', 'mem tt1.bin']
out = run(L)
m = open('tt1.bin', 'rb').read()
n = m[sym['nbld']]; b = sym['blist']
recs = [tuple(m[b + i * 4:b + i * 4 + 4]) for i in range(n)]
names = {16: 'mine', 17: 'school', 18: 'harbour', 19: 'hospital', 20: 'temple', 21: 'university', 22: 'forum'}
print('buildings:', [(names.get(r[0] & 0x7F, r[0]), 'building' if r[0] & 0x80 else 'done') for r in recs])
w = lambda nm: m[sym[nm]] | m[sym[nm] + 1] << 8
print('forum_done', m[sym['forum_done']], 'happy', m[sym['happy']], 'pop', w('pop'), 'year', w('year'),
      'rp/week', w('rp_week'), 'nschool', m[sym['nschool']], 'nuniv', m[sym['nuniv']], 'ntemple', m[sym['ntemple']])
print([l for l in out.split('\n') if 'HALT' in l or 'exited' in l])
