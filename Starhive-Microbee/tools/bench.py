"""STARHIVE speed benchmark: each level played the same way (weaving,
firing, invulnerable) for a while; frame rate and time by routine."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from collections import Counter
import numpy as np
import starhive_run as sh
from mbee import FRAME_T


def run(levels=(1, 2, 3, 4, 5), seconds=30, warm=8, profile=True, top=14):
    pp = sh.boot()
    S = pp.S
    pp.run_frames(250)
    pp.keys = {'SPACE'}
    pp.run_frames(6)
    labs = sorted([(v, k) for k, v in S.items() if isinstance(v, int) and 0x8000 <= v < 0xB000 and '.' not in k])
    res = {}
    for n in levels:
        if n > 1:
            pp.poke(S['level'], n - 1)
            pp.poke(S['state'], 3)
            pp.poke(S['stimer'], 1)
            pp.run_frames(150)
        for t in range(warm * 5):
            pp.keys = {'SPACE', ['LEFT', 'RIGHT'][(t // 20) % 2]}
            pp.poke(S['inv'], 100)
            pp.run_frames(10)
        pp.watch(S['commit'], 1)
        pp.watch(S['main'], 1)
        pp.events()
        if profile:
            pp.profile(True)
        for t in range(seconds * 5):
            pp.keys = {'SPACE', ['LEFT', 'RIGHT'][(t // 20) % 2]}
            pp.poke(S['inv'], 100)
            pp.run_frames(10)
        if profile:
            pp.profile(False)
        allev = pp.events()
        ev = [e[0] for e in allev if e[1] == S['commit']]
        work = []
        last = None
        for t_, p_ in allev:
            if p_ == S['commit']:
                last = t_
            elif p_ == S['main'] and last is not None:
                work.append(t_ - last)
                last = None
        pp.watch(S['commit'], 0)
        pp.watch(S['main'], 0)
        if work:
            w = np.array(work) / 1000
            print('   work per frame (k T): median %.0f  90%% %.0f  max %.0f   (2 fields = 135, 3 = 202)' % (
                np.median(w), np.percentile(w, 90), w.max()))
        d = Counter(round((b - a) / FRAME_T) for a, b in zip(ev, ev[1:]))
        nc = len(ev)
        line = 'level %d: %.1f fps  fields/frame %s' % (n, nc / seconds, dict(sorted(d.items())))
        print(line, flush=True)
        res[n] = nc / seconds
        if profile:
            pr = pp.prof()
            agg = {}
            for a in np.nonzero(pr)[0]:
                name = 'low' if a < 0x8000 else '?'
                for v, k in labs:
                    if v <= a:
                        name = k
                    else:
                        break
                agg[name] = agg.get(name, 0) + int(pr[a])
            items = sorted(agg.items(), key=lambda x: -x[1])[:top]
            print('   ' + '  '.join('%s %d' % (k, v // nc) for k, v in items))
    return res


if __name__ == '__main__':
    lv = tuple(int(x) for x in sys.argv[1:]) or (1, 2, 3, 4, 5)
    run(lv)
