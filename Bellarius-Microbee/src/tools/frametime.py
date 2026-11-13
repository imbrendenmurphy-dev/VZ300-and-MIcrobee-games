"""T-states of each step of one busy frame (fully powered pilot)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game
from autoplay import step
import re
pilot = int(sys.argv[1]) if len(sys.argv) > 1 else 0
pp = boot(); to_game(pp, pilot=pilot); S = pp.S
for t in range(60): step(pp)
for k, v in (('pmissile', 1), ('poptions', 2), ('pshield', 3), ('pspeed', 2), ('pdouble', 1), ('plaser', 0)):
    pp.poke(S[k], v)
for t in range(40): step(pp)
src = open(Path(__file__).resolve().parent.parent / 'src' / 'game.asm').read()
loop = src[src.index('game_loop:'):src.index('jp game_loop')]
calls = [c for c in re.findall(r'call (\w+)', loop) if c in S]
calls = [c for c in calls if c not in ('map_blk',)]
targets = {S[c]: c for c in calls}
targets[S['game_loop']] = 'game_loop'
for a in targets: pp.watch(a, 1)
pp.events()
NF = 12
pp.run_frames(NF * 4)
ev = pp.events()
tot = {}; frames = 0
for (t0, p0), (t1, p1) in zip(ev, ev[1:]):
    n = targets.get(p0, hex(p0))
    if n == 'game_loop': frames += 1
    tot[n] = tot.get(n, 0) + (t1 - t0)
s = sum(tot.values())
print('%d frames, average %d T-states (%.2f fields)' % (frames, s / frames, s / frames / 67500))
for c, v in sorted(tot.items(), key=lambda x: -x[1])[:22]:
    print('  %-18s %7d' % (c, v / frames))
