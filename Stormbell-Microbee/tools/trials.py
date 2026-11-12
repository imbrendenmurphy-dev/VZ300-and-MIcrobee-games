"""Duel one opponent several times with one player style.
    python3 tools/trials.py STAGE STYLE N [REACT]
Prints one line per duel and a summary. A lost duel is retried with
SPACE (the game's own quick retry); a won one is replayed by putting
the stage back at the next duel's start."""
import sys
sys.path.insert(0, 'tools')
import stagewatch as SW
from mbee import L

stage, style, n = int(sys.argv[1]), sys.argv[2], int(sys.argv[3])
react = int(sys.argv[4]) if len(sys.argv) > 4 else 5
g = SW.at_stage(stage, style, react=react)
pp = g.pp
wins, hps, times = 0, [], []
for k in range(n):
    res, t = g.fight(max_ticks=2500)
    hp = g.f('hero', 'HP')
    fhp = g.f('foe', 'HP')
    print('stage %d %-6s %-7s %4d ticks  Wren %2d  foe %2d' % (stage, style, res, t, hp, fhp), flush=True)
    wins += res == 'won'
    hps.append(hp)
    times.append(t)
    if k == n - 1:
        break
    # back to the same duel
    L.mb_set_bp(pp.h, g.S['duel'], 1)
    if res == 'lost':
        pp.keys = {'SPACE'}
    while not L.mb_run(pp.h, pp.tick + 67608):
        pass
    L.mb_set_bp(pp.h, g.S['duel'], 0)
    pp.keys = set()
    pp.poke(g.S['stage'], stage - 1)
    g.hist = []
    g.wait_fight_start()
print('SUMMARY stage %d %s react %d: won %d/%d, Wren health left avg %.1f, avg %.1f s' % (
    stage, style, react, wins, n, sum(hps) / n, sum(times) / n / 25.0))
