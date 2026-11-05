"""Frame-time measurement for uB-TYPE in the model.

Watches the main loop and the frame wait: busy T-states per game frame,
fields per frame (25 fps = 2), and a routine-level profile."""
import sys
import bisect
from collections import Counter
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
from mbee import FRAME_T


def frame_stats(pp, nframes, script=None):
    S = pp.S
    pp.watch(S['flip'])
    pp.watch(S['waitframe'])
    pp.events()
    pp.profile(True)
    f0 = pp.frames
    while pp.frames - f0 < nframes:
        if script:
            script(pp, pp.frames - f0)
        pp.run_frames(1)
    ev = pp.events()
    prof = pp.prof()
    pp.profile(False)
    starts = [t for t, pc in ev if pc == S['flip']]
    waits = [t for t, pc in ev if pc == S['waitframe']]
    busy = []
    for s in starts:
        w = [x for x in waits if x > s]
        if w:
            busy.append(w[0] - s)
    periods = [b - a for a, b in zip(starts, starts[1:])]
    return busy, periods, prof


def routine_profile(prof, S, top=25):
    names = sorted((v, k) for k, v in S.items() if 0x8000 <= v < 0xEF00 and not k.count('.') and not k.isupper())
    addrs = [v for v, k in names]
    acc = Counter()
    for pc in prof.nonzero()[0]:
        i = bisect.bisect_right(addrs, pc) - 1
        if i >= 0:
            acc[names[i][1]] += int(prof[pc])
    tot = sum(acc.values())
    return [(k, v, 100.0 * v / tot) for k, v in acc.most_common(top)], tot


if __name__ == '__main__':
    pp = run.boot()
    pp.run_until(pp.S['mainloop'], 400)
    pp.run_frames(80)

    def fire(pp, f):
        pp.keys = {'SPACE'} if (f // 6) % 2 else set()
    busy, per, prof = frame_stats(pp, 400, fire)
    import statistics as st
    print('frames', len(busy), 'busy T: mean %d  max %d  min %d' % (st.mean(busy), max(busy), min(busy)))
    pf = [p / FRAME_T for p in per]
    print('fields/frame mean %.2f -> %.1f fps; frames at 2 fields: %.0f%%' % (st.mean(pf), 50 / st.mean(pf), 100 * sum(1 for p in pf if p < 2.05) / len(pf)))
    rp, tot = routine_profile(prof, pp.S)
    for k, v, pc in rp:
        print('%-16s %9d %5.1f%%' % (k, v, pc))
