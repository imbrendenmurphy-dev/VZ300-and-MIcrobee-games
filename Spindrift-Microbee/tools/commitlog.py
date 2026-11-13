"""Break on every commit in a scene and log what the slow ones contain."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import jump, run, playtest
from mbee import FRAME_T

def log(pp, frames, god=True, limit=24408):
    S = pp.S
    slow = []
    f = 0
    t_end = pp.tick + frames * FRAME_T
    while pp.tick < t_end:
        if f % 4 == 0:
            pp.keys = playtest.pilot(pp, f)
        if god:
            pp.poke(S['p_inv'], 40)
        if pp.run_until(S['commit'], 4) is None:
            continue
        f += 1
        b = pp.beam()
        st = dict(line=b['line'], ven=b['venable'], age=run.var(pp, 'vb_age'), fl=run.var(pp, 'flashcnt'),
                  glyphs=(run.var(pp, 'nextcode') - 0x91) & 255, cells=run.var(pp, 'lcount'),
                  tq=pp.peek((run.var(pp, 'tqcur') + 3) * 256 + 255), tqp=pp.peek((run.var(pp, 'tqprev') + 3) * 256 + 255),
                  ph=run.var(pp, 'phase'), sp=pp.cpu.sp)
        t0 = pp.tick
        pp.run_until(S['cleanup'], 4)
        st['T'] = pp.tick - t0
        if st['T'] > limit:
            slow.append(st)
    return slow

if __name__ == '__main__':
    for s in (1, 7):
        pp = jump.to_boss(s)
        for st in log(pp, 1200)[:12]:
            print('boss%d' % (s + 1), st)
