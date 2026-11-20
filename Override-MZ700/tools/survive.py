"""survive.py - how long a passive or wandering player lasts from a new game.

    py tools/survive.py [idle|wander] [seconds] [seed]
"""
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402

mode = sys.argv[1] if len(sys.argv) > 1 else 'idle'
secs = int(sys.argv[2]) if len(sys.argv) > 2 else 30
rng = random.Random(int(sys.argv[3]) if len(sys.argv) > 3 else 1)
g = Game()
m = g.m
m.vram_wait = 'all'
g.run(100)
g.run(4, ['space'])
D = S['DROIDS']
keys = []
for f in range(secs * 50):
    if mode == 'wander' and f % 40 == 0:
        keys = rng.choice([['left'], ['right'], ['up'], ['down'], ['left', 'up'], ['right', 'down'], []])
    g.run(1, keys)
    if f % 250 == 0:
        print('%3ds energy %3d host %d dead %d' % (f // 50, m.mem[D + 3], m.mem[D], m.mem[S['pl_dead']]))
    if m.mem[S['pl_dead']]:
        print('died after %.1f s' % (f / 50))
        break
else:
    print('alive after %d s, energy %d' % (secs, m.mem[D + 3]))
