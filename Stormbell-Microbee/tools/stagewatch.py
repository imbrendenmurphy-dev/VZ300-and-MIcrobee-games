"""Start STORMBELL at a chosen stage and print the duel tick by tick.
    python3 tools/stagewatch.py STAGE STYLE TICKS [EVERY]"""
import sys
sys.path.insert(0, 'tools')
import playtest as P
import boottest as T
from mbee import L

NAMES = 'IDLE STEP GUARD ATK HIT BLOCKED FALL DOWN BOW STAND'.split()


def at_stage(stage, style, out='/tmp/sw', react=5):
    g = P.Game(out, style)
    g.react = react
    pp = g.pp
    T.launch(pp, 700)
    L.mb_set_bp(pp.h, g.S['duel'], 1)
    pp.keys = {'SPACE'}
    while not L.mb_run(pp.h, pp.tick + 67608):
        pass
    L.mb_set_bp(pp.h, g.S['duel'], 0)
    pp.keys = set()
    pp.poke(g.S['stage'], stage - 1)
    g.wait_fight_start()
    return g


def line(g):
    f = g.f
    return 'hero x%2d %-7s ph%d hp%2d | foe x%2d %-7s ph%d hp%2d | op@%d t%d' % (
        f('hero', 'X'), NAMES[f('hero', 'ST')], f('hero', 'PH'), f('hero', 'HP'),
        f('foe', 'X'), NAMES[f('foe', 'ST')], f('foe', 'PH'), f('foe', 'HP'), g.var('scr_pc'), g.var('scr_t'))


if __name__ == '__main__':
    stage, style, ticks = int(sys.argv[1]), sys.argv[2], int(sys.argv[3])
    every = int(sys.argv[4]) if len(sys.argv) > 4 else 5
    g = at_stage(stage, style)
    for n in range(ticks):
        g.pp.keys = g.decide()
        g.pp.run_frames(2)
        if n % every == 0:
            print(n, line(g), flush=True)
