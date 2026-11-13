"""Stage 1 frame rate for each pilot at three power levels (emulator)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game
from autoplay import step
LEVELS = {'bare': {}, 'mid': dict(pmissile=1, poptions=1, pdouble=1, pspeed=1),
          'full': dict(pmissile=1, poptions=2, pdouble=1, pshield=3, pspeed=2)}
names = ['HONK', 'TRUFFLE', 'BOLT', 'QUEENIE']
print('| Pilot | ' + ' | '.join(LEVELS) + ' |')
print('|---|' + '---|' * len(LEVELS))
for p in range(4):
    row = []
    for lv, pk in LEVELS.items():
        pp = boot(); to_game(pp, pilot=p); S = pp.S
        for t in range(60): step(pp)
        for k, v in pk.items(): pp.poke(S[k], v)
        for t in range(30): step(pp)
        a = peekw(pp, 'framecount')
        for t in range(200): step(pp)
        row.append('%.1f' % ((peekw(pp, 'framecount') - a) * 50 / 800))
    print('| %s | %s |' % (names[p], ' | '.join(row)))
