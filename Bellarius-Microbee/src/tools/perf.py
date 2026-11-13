"""Frame rate and profile in play."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from run import boot, peek, peekw, tap, to_game

def fc(pp):
    return peekw(pp, 'framecount')

def profile(pp, fields, keys=()):
    pp.keys = list(keys)
    pp.profile(True)
    a = fc(pp); pp.run_frames(fields); b = fc(pp)
    prof = pp.prof()
    pp.profile(False)
    S = pp.S
    items = sorted((v, n) for n, v in S.items() if v >= 0x8000 and v < 0xD000 and '.' not in n)
    tot = {}
    idx = np.nonzero(prof)[0]
    import bisect
    keys_ = [v for v, n in items]
    for a_ in idx:
        i = bisect.bisect_right(keys_, a_) - 1
        n = items[i][1] if i >= 0 else '?'
        tot[n] = tot.get(n, 0) + int(prof[a_])
    s = sum(tot.values())
    print('%d game frames in %d fields: %.1f fps' % (b - a, fields, (b - a) * 50.0 / fields))
    for n, v in sorted(tot.items(), key=lambda x: -x[1])[:16]:
        print('  %-16s %5.1f%%' % (n, 100 * v / s))
    return (b - a) * 50.0 / fields

if __name__ == '__main__':
    pp = boot()
    to_game(pp)
    pp.run_frames(150)
    print('pinv', peek(pp, 'pinv'), 'pdead', peek(pp, 'pdead'), 'hearts', peek(pp, 'hearts'), 'px', peekw(pp, 'px'), 'py', peek(pp, 'py'))
    profile(pp, 200, ['SPACE'])
