"""Scripted play-through for testing: python3 tools/play.py outdir"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
from mbee import FRAME_T

def stats(pp, n, keys=()):
    S = pp.S
    pp.keys = list(keys)
    pp.watch(S['game_loop'])
    pp.events()
    w0 = pp.vwait(); t0 = pp.tick
    pp.run_frames(n)
    ev = pp.events()
    loops = len(ev)
    d = [(ev[i + 1][0] - ev[i][0]) / FRAME_T for i in range(len(ev) - 1)]
    worst = max(d) if d else 0
    slow = sum(1 for x in d if x > 2.2)
    print('%-22s %3d frames in %3d fields = %.1f fps, worst %.1f fields, slow %d, held %.0f T/frame, camx %d ppx %d ppy %d st %d slots %d miss %d' % (
        '+'.join(keys) or 'idle', loops, n, 50.0 * loops / n, worst, slow, (pp.vwait() - w0) / max(1, loops),
        pp.peekw(S['camx']), int(pp.blocks[4][S['ppx']]) + 256 * int(pp.blocks[4][S['ppx'] + 1]), int(pp.blocks[4][S['ppy']]), int(pp.blocks[4][S['pstate']]), pp.peek(S['nslots']),
        pp.blocks[5][run.symbols(run.BUILD / 'map.sym')['miss_count']]))

if __name__ == '__main__':
    out = sys.argv[1]
    pp = run.start()
    stats(pp, 50)
    k = 0
    for keys, n in [(('RIGHT',), 100), (('RIGHT',), 100), (('RIGHT', 'SPACE'), 60), (('LEFT',), 80), ((), 30),
                    (('DOWN',), 30), (('DOWN', 'RIGHT'), 60), (('SPACE',), 40), (('RIGHT',), 200)]:
        stats(pp, n, keys)
        run.shot(pp, '%s/p%d.png' % (out, k))
        k += 1
