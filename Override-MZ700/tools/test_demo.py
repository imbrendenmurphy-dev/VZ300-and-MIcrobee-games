"""test_demo.py - jump straight into the demo game and watch the AI pilot.

    py tools/test_demo.py FIELDS [shot_every] [seed]
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402

fields = int(sys.argv[1]) if len(sys.argv) > 1 else 1500
every = int(sys.argv[2]) if len(sys.argv) > 2 else 100
seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1234

g = Game()
g.run(10)
m = g.m
c = m.cpu
m.mem[S['seed']] = seed & 0xFF
m.mem[S['seed'] + 1] = seed >> 8
m.mem[S['demo']] = 1
m.mem[S['demo_time']] = 0xFF
m.mem[S['demo_time'] + 1] = 0x7F
c.sp = 0xCFF0 - 2
m.mem[c.sp] = S['attract'] & 0xFF
m.mem[c.sp + 1] = S['attract'] >> 8
c.pc = S['game']
D = S['DROIDS']
prev = None
names = {}
for f in range(fields):
    g.run(1)
    mem = m.mem
    st = (mem[D], mem[D + 3], mem[S['deck']], mem[S['event']], mem[S['xmode']], mem[S['enemies_left']],
          mem[S['score'] + 2], mem[S['score'] + 1], mem[S['score']], mem[S['pl_dead']])
    if st[:4] != (prev or (None,) * 10)[:4] or st[5:9] != (prev or (None,) * 10)[5:9]:
        print('%5d host %2d en %3d deck %d ev %d xm %3d left %d score %02X%02X%02X dead %d  pos %d,%d  pc %04X' % (
            (f,) + st + (mem[D + 1], mem[D + 2], c.pc)))
        prev = st
    if every and f % every == every - 1:
        g.shot('demo_%05d' % f)
    if c.pc == S['attract'] or c.pc == S['title_screen']:
        print('demo ended at field', f)
        break
print(g.screen_text())
