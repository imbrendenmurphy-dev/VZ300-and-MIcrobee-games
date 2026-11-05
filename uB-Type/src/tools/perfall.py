"""Performance under load on every stage, in the Premium Plus model.

For each stage: 600 game frames from the start of the stage, then the boss
fight (started 70 columns before the end of the level), with fire held in
bursts and the ship weaving, trainer mode on so the run never ends. Reports
frames per second, the share of frames that made the full 25 fps (two
fields), and the busiest frame against the two-field budget."""
import sys
import statistics as st
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
from mbee import FRAME_T
import measure

NAMES = ['OUTER HULL', 'THE HIVE', 'ROCK BELT', 'CRYSTAL VEIN', 'DREADNOUGHT', 'GUT CAVERNS', 'DEEP FIELD', 'THE CORE']


def script(pp, f):
    k = set()
    if (f // 6) % 2:
        k.add('SPACE')
    ph = (f // 40) % 4
    k.add(['Q', 'A', 'A', 'Q'][ph])
    if (f // 80) % 3 == 1:
        k.add('P')
    elif (f // 80) % 3 == 2:
        k.add('O')
    pp.keys = k


def one(stage, boss):
    pp = run.boot(stage)
    S = pp.S
    if boss:
        pp.run_until(S['prof_reset'], 400)
        cols = pp.peekw(S['lvlcols'])
        pp.poke(S['dbgcol'], (cols - 70) & 255)
        pp.poke(S['dbgcol'] + 1, (cols - 70) >> 8)
        pp.poke(S['checkpt'], (cols - 70) & 255)
        pp.poke(S['checkpt'] + 1, (cols - 70) >> 8)
    pp.run_until(S['mainloop'], 400)
    pp.poke(S['trainer'], 1)
    pp.run_frames(20)
    busy, per, prof = measure.frame_stats(pp, 1200, script)
    pf = [p / FRAME_T for p in per]
    return dict(fps=50 / st.mean(pf), full=100 * sum(1 for p in pf if p < 2.05) / len(pf),
                mean=st.mean(busy), mx=max(busy), boss=pp.peek(S['bossent'] + 1) != 0)


if __name__ == '__main__':
    stages = [int(a) for a in sys.argv[1:]] or range(8)
    print('%-14s %-6s %6s %8s %10s %10s' % ('stage', 'part', 'fps', '25fps %', 'mean T', 'max T'))
    for s in stages:
        for boss in (False, True):
            r = one(s, boss)
            print('%d %-12s %-6s %6.1f %7.0f%% %10d %10d' % (s + 1, NAMES[s], 'boss' if boss else 'start', r['fps'], r['full'], r['mean'], r['mx']))
