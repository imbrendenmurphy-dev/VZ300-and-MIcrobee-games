"""frame period and per-routine cost, still and moving"""
import sys, bisect
sys.path.insert(0, '.')
import numpy as np, rbtest, sprtest as Q
from mbee import FRAME_T


def measure(keys, n=60, warm=15, top=18, label=''):
    pp = rbtest.boot()
    while not pp.start_addr():
        pp.run_frames(1)
    pp.run_frames(3)
    labs = sorted((v, k) for k, v in pp.S.items() if 0x8000 <= v < 0xC000 and '.' not in k)
    ks = [a for a, _ in labs]
    pp.keys = set(keys)
    for i in range(warm):
        Q.go(pp, [pp.S['logic']])
    pp.profile(True)
    prev = pp.prof()
    t0 = pp.tick
    tot = {}
    per = []
    for f in range(n):
        Q.go(pp, [pp.S['logic']])
        per.append(pp.tick)
    cur = pp.prof()
    d = cur - prev
    for a in np.nonzero(d)[0]:
        i = bisect.bisect_right(ks, a) - 1
        nm = labs[i][1]
        tot[nm] = tot.get(nm, 0) + int(d[a])
    periods = np.diff([t0] + per) / FRAME_T
    span = (per[-1] - t0)
    busy = (span - tot.get('frame_wait', 0)) / n
    print('%s: %d frames, dropped (period>1.5) %d, period mean %.2f max %.2f; busy %.0f T/frame (%.0f%% of a frame)' %
          (label, n, int((periods > 1.5).sum()), periods.mean(), periods.max(), busy, 100 * busy / FRAME_T))
    for k_, v in sorted(tot.items(), key=lambda kv: -kv[1])[:top]:
        print('   %-14s %7.0f' % (k_, v / n))


if __name__ == '__main__':
    measure([], label='still', n=150, top=0)
    measure(['RIGHT'], label='right', n=300, top=0)
    measure(['LEFT'], label='left', n=300, top=0)
    measure(['RIGHT', 'UP'], label='right+up', n=200, top=0)
    measure(['LEFT', 'DOWN'], label='left+down', n=200, top=0)
