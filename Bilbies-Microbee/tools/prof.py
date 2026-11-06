"""per-routine T-state profile between two PCs over N frames"""
import sys, run
def profile(pp, frames=10):
    S = pp.S
    pp.profile(True)
    pp.run_frames(frames)
    p = pp.prof()
    pp.profile(False)
    labs = sorted((v, k) for k, v in S.items() if 0x8000 <= v < 0xCC00 and '.' not in k)
    res = {}
    for i, (a, k) in enumerate(labs):
        b = labs[i + 1][0] if i + 1 < len(labs) else 0xCC00
        res[k] = int(p[a:b].sum())
    tot = sum(res.values())
    for k, v in sorted(res.items(), key=lambda x: -x[1])[:15]:
        print('%-18s %8d %5.1f%%' % (k, v // frames, 100.0 * v / max(tot, 1)))
    return res
if __name__ == '__main__':
    pp = run.boot(); pp.run_frames(20); profile(pp, 10)
