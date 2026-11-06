"""Routine profile of uB-TYPE under the perfcmp script (identical gameplay
set-up: decoupled noise seed, seed 1234h, trainer on).
usage: prof.py STAGE BOSS(0/1) [FN]  - FN: per-label profile inside FN"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run, measure, perfcmp


def setup(st, boss):
    pp = run.boot(st)
    S = pp.S
    perfcmp.decouple(pp.peek, pp.poke, S, 0xEF00)
    pp.run_until(S['prof_reset'], 400)
    perfcmp.poke_start(pp.poke, pp.peekw, S, boss)
    pp.run_until(S['mainloop'], 400)
    pp.poke(S['trainer'], 1)
    pp.poke(S['rseed'], 0x34)
    pp.poke(S['rseed'] + 1, 0x12)
    pp.run_frames(20)
    return pp


if __name__ == '__main__':
    st, boss = int(sys.argv[1]), sys.argv[2] == '1'
    pp = setup(st, boss)
    S = pp.S
    busy, per, prof = perfcmp.mb_run(pp, 400, profile=True)
    b = [x for x in busy if x < 400000]
    print('busy mean %d  fps %.1f  frames %d' % (sum(b) / len(b), 50 * len(per) / sum(p / 67500 for p in per), len(b)), flush=True)
    if len(sys.argv) > 3:
        FN = sys.argv[3]
        labs = sorted((v, k) for k, v in S.items() if k == FN or k.startswith(FN + '.'))
        end = min(v for k, v in S.items() if v > labs[-1][0] and not k.startswith(FN))
        tot = sum(prof[labs[0][0]:end])
        for i, (v, k) in enumerate(labs):
            e = labs[i + 1][0] if i + 1 < len(labs) else end
            t = sum(prof[v:e])
            print('%-20s %9d %5.1f%%' % (k, t // len(b), 100 * t / max(tot, 1)))
    else:
        rp, tot = measure.routine_profile(prof, S)
        for k, v, pc in rp[:28]:
            print('%-16s %9d %5.1f%%' % (k, v // len(b), pc))
