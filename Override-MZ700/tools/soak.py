"""soak.py - run the attract mode (title, pages, demo games) for a long time.

    py tools/soak.py [fields] [vram_mode]

Fails on a PC outside the program, a wandering stack pointer, or the
attract loop getting stuck on one screen.
"""
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game, S  # noqa: E402

fields = int(sys.argv[1]) if len(sys.argv) > 1 else 15000
g = Game()
if len(sys.argv) > 2:
    g.m.vram_wait = sys.argv[2]
t0 = time.time()
seen = {}
last_row0 = None
same = 0
demos = 0
in_demo = False
for f in range(0, fields, 50):
    g.run(50)
    row0 = g.text(0)
    kind = ('title' if 'PRESS SPACE' in g.text(17) else
            'gallery' if 'D A T A' in row0 else
            'hiscores' if 'L I N K E R S' in row0 else
            'howto' if 'HOW TO' in row0 else
            'duel' if 'C I R C U I T' in row0 else
            'lift' if 'CHOOSE DECK' in g.text(23) else
            'deck' if 'SCORE' in row0 else 'other')
    seen[kind] = seen.get(kind, 0) + 1
    if kind == 'deck' and not in_demo:
        demos += 1
    in_demo = kind in ('deck', 'duel', 'lift')
    if f % 1000 == 0:
        print('%6d %-9s sp %04X  %s' % (f, kind, g.m.cpu.sp, row0.strip()[:30]))
        g.shot('soak_%06d' % f)
print('screens seen:', seen)
print('demo games:', demos, ' time %.0fs' % (time.time() - t0))
