import sys, bisect
sys.path.insert(0, '.')
import numpy as np, rbtest, sprtest as Q
from mbee import FRAME_T
pp = rbtest.boot()
while not pp.start_addr(): pp.run_frames(1)
pp.run_frames(3)
labs = sorted((v, k) for k, v in pp.S.items() if 0x8000 <= v < 0xC000 and '.' not in k)
ks = [a for a, _ in labs]
pp.keys = {'RIGHT'}
for i in range(15): Q.go(pp, [pp.S['logic']])
pp.profile(True)
prev = pp.prof().copy(); t0 = pp.tick
for f in range(300):
    Q.go(pp, [pp.S['logic']])
    cur = pp.prof().copy(); d = cur - prev; prev = cur
    per = (pp.tick - t0) / FRAME_T; t0 = pp.tick
    if per > 1.5:
        tot = {}
        for a in np.nonzero(d)[0]:
            nm = labs[bisect.bisect_right(ks, a) - 1][1]; tot[nm] = tot.get(nm, 0) + int(d[a])
        print('frame', f, 'period', round(per, 2), 'X', pp.peek(pp.S['xpos']) | pp.peek(pp.S['xpos'] + 1) << 8)
        for k, v in sorted(tot.items(), key=lambda kv: -kv[1])[:8]: print('   ', k, v)
