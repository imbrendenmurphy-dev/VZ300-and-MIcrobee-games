"""dropped frames in the scripted combat flight (combattest.keys_at):
how many, how many sprite cells, and the routine profile of the first few.

    python dropprof.py [frames]
"""
import sys, bisect
sys.path.insert(0, '.')
import numpy as np, rbtest, sprtest as Q, combattest as C
from mbee import FRAME_T

N = int(sys.argv[1]) if len(sys.argv) > 1 else 1500
pp = rbtest.boot()
while not pp.start_addr():
    pp.run_frames(1)
pp.run_frames(3)
S = pp.S
labs = sorted((v, k) for k, v in S.items() if 0x8000 <= v < 0xC000 and '.' not in k)
ks = [a for a, _ in labs]
pp.profile(True)
prev = pp.prof().copy()
t0 = pp.tick
cells, drops, busy = [], [], []
for f in range(N):
    pp.keys = set(C.keys_at(f))
    Q.go(pp, [S['logic']])
    cur = pp.prof().copy()
    d = cur - prev
    prev = cur
    per = (pp.tick - t0) / FRAME_T
    t0 = pp.tick
    tot = {}
    for a in np.nonzero(d)[0]:
        nm = labs[bisect.bisect_right(ks, a) - 1][1]
        tot[nm] = tot.get(nm, 0) + int(d[a])
    busy.append(per * FRAME_T - tot.get('frame_wait', 0))
    cells.append(pp.peek(S['poolcnt']))
    if per > 1.5 and f > 0:
        drops.append(f)
        if len(drops) <= 3:
            print('frame', f, 'period %.2f' % per, 'cells', cells[-2],
                  ' '.join('%s %d' % kv for kv in sorted(tot.items(), key=lambda kv: -kv[1])[:10]))
cells = np.array(cells)
busy = np.array(busy[1:])
print('%d frames: dropped %d, cells mean %.1f max %d, busy mean %.0f T (%.0f%%) max %.0f T' %
      (N, len(drops), cells.mean(), cells.max(), busy.mean(), 100 * busy.mean() / FRAME_T, busy.max()))
