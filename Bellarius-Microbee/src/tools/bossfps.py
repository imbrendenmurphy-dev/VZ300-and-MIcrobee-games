"""Frame rate in each stage's boss fight (autopilot, emulator)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game, BUILD
from autoplay import step
stages = [int(a) for a in sys.argv[1:]] or [1, 2, 3, 4]
for st in stages:
    pp = boot(); to_game(pp); S = pp.S
    while peek(pp, 'stage') != st:
        pp.run_frames(20)
        if peek(pp, 'gstate') == 0 and peek(pp, 'stage') < st:
            pp.poke(S['stage'], st - 1); pp.poke(S['gstate'], S['GS_CLEAR'])
    pp.run_frames(100)
    pp.poke(S['scrollx'], 0x80); pp.poke(S['scrollx'] + 1, 0x11)
    while peek(pp, 'gstate') != 1: step(pp, 8)
    for i in range(60): step(pp)
    a = peekw(pp, 'framecount')
    for i in range(150): step(pp); pp.poke(S['lives'], 3)
    print('stage %d boss fight: %.1f fps' % (st, (peekw(pp, 'framecount') - a) * 50 / 600))
    pp.png(BUILD / 'shots' / ('bossfight%d.png' % st), scale=2, aspect=1.2)
