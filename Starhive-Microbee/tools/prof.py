"""T-state profile by routine (symbols from the .sym file)"""
import sys
import numpy as np
import run

def profile(pp, frames=50):
    S = pp.S
    labs = sorted((v, k) for k, v in S.items() if 0x8000 <= v < 0xD000 and '.' not in k)
    pp.profile(True)
    t0 = pp.tick
    pp.run_frames(frames)
    p = pp.prof()
    tot = pp.tick - t0
    agg = {}
    addrs = np.nonzero(p)[0]
    import bisect
    keys = [a for a, _ in labs]
    for a in addrs:
        i = bisect.bisect_right(keys, a) - 1
        name = labs[i][1] if i >= 0 else '?'
        agg[name] = agg.get(name, 0) + int(p[a])
    print('total T per field: %.0f' % (tot / frames))
    for n, t in sorted(agg.items(), key=lambda kv: -kv[1])[:25]:
        print('%-16s %6.1f%%  %8.0f T/field' % (n, 100.0 * t / tot, t / frames))

if __name__ == '__main__':
    pp = run.boot()
    pp.run_frames(60)
    profile(pp, 100)
