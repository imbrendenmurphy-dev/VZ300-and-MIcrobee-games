"""Quick engine benchmark: Microbee busy T-states per game frame on a few
heavy scenes, identical gameplay (input follows game frames)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import prof, perfcmp
SCENES = [(2, True), (4, False), (1, True), (4, True), (0, True)]
if __name__ == '__main__':
    tot = 0
    out = []
    for st, boss in SCENES:
        pp = prof.setup(st, boss)
        busy, per = perfcmp.mb_run(pp, 300)
        b = [x for x in busy if x < 400000]
        m = sum(b) / len(b)
        fps = 50 * len(per) / sum(p / 67500 for p in per)
        out.append('st%d%s %6.0f %4.1f' % (st + 1, 'B' if boss else 's', m, fps))
        tot += m
    print('  '.join(out), ' total %d' % tot)
