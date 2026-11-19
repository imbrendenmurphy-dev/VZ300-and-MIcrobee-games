"""perf.py - frame rate of the demo game under a VRAM wait-state model.

    py tools/perf.py [all|display|none] [fields] [seed]

'all' holds every VRAM access until the 63-T window of each line (the
conservative model used for Neutronium); 'display' only during the 200
visible lines.  Prints game frames per second over 50-field windows.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402

mode = sys.argv[1] if len(sys.argv) > 1 else 'all'
fields = int(sys.argv[2]) if len(sys.argv) > 2 else 1000
seed = int(sys.argv[3]) if len(sys.argv) > 3 else 1234
g = Game()
g.run(10)
m = g.m
m.vram_wait = None if mode == 'none' else mode
c = m.cpu
m.mem[S['seed']] = seed & 0xFF
m.mem[S['seed'] + 1] = seed >> 8
m.mem[S['demo']] = 1
c.sp = 0xCFF0 - 2
m.mem[c.sp] = S['attract'] & 0xFF
m.mem[c.sp + 1] = S['attract'] >> 8
c.pc = S['game']
g.run(60)
rates = []
for w in range(fields // 50):
    f0 = m.mem[S['frame']]
    ev0 = m.mem[S['event']]
    g.run(50)
    df = (m.mem[S['frame']] - f0) & 0xFF
    in_deck = S['deck_play'] <= c.pc < S['deck_play'] + 400 or True
    rates.append(df)
    print('fields %5d-%5d  frames %3d  (%.1f fps)  waits %d' % (w * 50, w * 50 + 49, df, df, m.waits))
    m.waits = 0
r = [x for x in rates if x > 5]
if r:
    print('average %.1f fps, worst %d' % (sum(r) / len(r), min(r)))
