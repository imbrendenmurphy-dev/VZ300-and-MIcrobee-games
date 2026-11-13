"""Frame rate on the busiest waves (fields per game frame) and a profile."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from run import boot, peek


def fc(pp):
    return pp.peekw(pp.S['framecount'])


for w in (1, 7, 10):
    pp = boot(test=True)
    pp.run_frames(40)
    pp.poke(pp.S['wave'], w)
    pp.poke(pp.S['state'], 2)      # 'paddock clear' -> next wave
    pp.poke(pp.S['stimer'], 1)
    pp.poke(pp.S['wave'], w - 1)
    pp.run_frames(150)
    pp.poke(pp.S['pinv'], 250)
    pp.keys = ['A', 'L']
    a = fc(pp); pp.run_frames(100); b = fc(pp)
    print('wave %2d: %d game frames in 100 fields (%.1f fps), %d cells drawn, %d robots' % (
        peek(pp, 'wave'), b - a, (b - a) / 2, peek(pp, 'dln'), peek(pp, 'enemies_left')))
pp.profile(True)
pp.run_frames(100)
prof = pp.prof()
S = pp.S
items = sorted((v, n) for n, v in S.items() if 0x8000 <= v < 0xD000 and '.' not in n)
tot = {}
for a_ in np.nonzero(prof)[0]:
    best = '?'
    for v, n in items:
        if v <= a_:
            best = n
        else:
            break
    tot[best] = tot.get(best, 0) + int(prof[a_])
s = sum(tot.values())
for n, v in sorted(tot.items(), key=lambda x: -x[1])[:14]:
    print('  %-16s %5.1f%%' % (n, 100 * v / s))
