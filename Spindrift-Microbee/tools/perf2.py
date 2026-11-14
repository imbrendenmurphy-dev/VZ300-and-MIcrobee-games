"""Measure SPINDRIFT's busiest scenes: each sector's waves and each
Guardian, flown by the playtest pilot. Reports per scene the frame rate,
the longest vertical-blanking commit, the most sprite cells and glyphs,
and the worst gap between a key press being read and the frame showing it
(input latency, in fields).

    python3 tools/perf2.py [seconds per scene]
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import run
import jump
import playtest
from mbee import FRAME_T

VBLANK_T = 62 * 216           # 62 blanked lines of 216 T (312 - 250)
PH_PLAY, PH_BOSS, PH_BONUS = 1, 4, 7


def scene(pp, seconds, shot=None, god=True):
    S = pp.S
    pp.watch(S['commit'])
    pp.watch(S['cleanup'])
    pp.events()
    rows = []
    t_last = t_commit = None
    worst = (-1, None)
    for f in range(seconds * 50):
        if f % 2 == 0:
            pp.keys = playtest.pilot(pp, f)
        if god:
            pp.poke(S['p_inv'], 40)
        pp.run_frames(1)
        ph = run.var(pp, 'phase')
        for t, pc in pp.events():
            if pc == S['commit']:
                if t_last is not None:
                    rows.append([(t - t_last) / FRAME_T, 0, (run.var(pp, 'nextcode') - 0x91) & 255,
                                 run.var(pp, 'lcount'), run.var(pp, 'nenemy'), ph])
                t_last = t_commit = t
            elif pc == S['cleanup'] and t_commit is not None and rows:
                rows[-1][1] = t - t_commit
        if shot and rows and ph in (PH_PLAY, PH_BOSS, PH_BONUS) and rows[-1][3] > worst[0]:
            worst = (rows[-1][3], f)
            run.shot(pp, shot)
    return np.array(rows, float)


def report(name, a):
    play = a[np.isin(a[:, 5], (PH_PLAY, PH_BOSS, PH_BONUS))]
    if not len(play):
        play = a
    over = play[play[:, 1] > VBLANK_T]
    print('%-22s %4.1f fps  %3.0f%% at 25  commit max %5.0f T  over %d  cells max %3.0f  glyphs max %3.0f  enemies max %2.0f'
          % (name, 50.0 / play[:, 0].mean(), 100.0 * (play[:, 0] < 2.5).mean(), play[:, 1].max(), len(over),
             play[:, 3].max(), play[:, 2].max(), play[:, 4].max()))
    allover = a[a[:, 1] > VBLANK_T]
    if len(allover):
        print('%22s (outside play: %d overruns, in phases %s)' % ('', len(allover) - len(over),
                                                                sorted(set(int(p) for p in allover[:, 5]))))
    return play


if __name__ == '__main__':
    secs = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    out = Path('/tmp/claude-0/perf')
    out.mkdir(parents=True, exist_ok=True)
    allp = []
    for s in range(8):
        pp = jump.to_sector(s, 1)
        a = scene(pp, secs, out / ('s%d.png' % (s + 1)))
        allp.append(report('sector %d wave 2' % (s + 1), a))
    for s in (1, 3, 5, 7):
        pp = jump.to_boss(s)
        a = scene(pp, secs, out / ('boss%d.png' % (s + 1)))
        allp.append(report('guardian, sector %d' % (s + 1), a))
    a = np.concatenate(allp)
    print('ALL PLAY: %.1f fps, %.1f%% of frames at 25, worst commit %.0f T of %d' % (
        50.0 / a[:, 0].mean(), 100.0 * (a[:, 0] < 2.5).mean(), a[:, 1].max(), VBLANK_T))
