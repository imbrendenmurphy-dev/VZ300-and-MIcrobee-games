"""A fixed run of three stages (running, jumping, a fall from high up): frames a second.
python3 tools/bench.py"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tour
from collections import Counter

def bench(stage):
    b = tour.Bot(stage=stage)
    b.go(('RIGHT',), 30)
    b.loops = b.fields = b.slow = 0
    for i in range(3):
        b.go(('RIGHT',), 40)
        b.go(('RIGHT', 'SPACE'), 16)
        b.go(('RIGHT',), 20)
    tx = b.v('ppx', 2) // 8
    b.warp(tx, 1)                       # drop him from the top: a long pan down
    b.go((), 60)
    b.go(('LEFT',), 40)
    return b.loops, b.fields, b.slow

if __name__ == '__main__':
    tl = tf = 0
    for st in (0, 5, 13, 17):
        l, f, s = bench(st)
        tl += l; tf += f
        print('stage %2d: %.1f fps, %d slow of %d' % (st, 50.0 * l / f, s, l))
    print('all: %.2f fps' % (50.0 * tl / tf))
