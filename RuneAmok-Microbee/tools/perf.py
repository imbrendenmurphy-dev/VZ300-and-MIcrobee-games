"""Step timing: compose cost (T-states) and frames until the new view shows."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import rd

pp = rd.boot()
S = pp.S
pp.run_frames(150)
pp.keys = {'SPACE'}
pp.run_frames(3)
pp.keys = set()
pp.run_frames(80)
for k in ['UP', 'RIGHT', 'UP', 'LEFT', 'LEFT', 'UP', 'RIGHT', 'RIGHT']:
    pp.keys = {k}
    pp.run_frames(1)
    f0 = pp.frames
    if pp.run_until(S['compose'], 20) is None:
        print(k, 'no compose (blocked)')
        pp.keys = set()
        pp.run_frames(20)
        continue
    ta = pp.tick
    pp.run_until(S['commit_start'], 20)
    tb = pp.tick
    pp.keys = set()
    for i in range(30):
        pp.run_frames(1)
        if rd.var(pp, 'cm_state') == 0:
            break
    print('%-6s compose %6d T (%.2f frames)   key to new view %d frames' % (k, tb - ta, (tb - ta) / 67608, pp.frames - f0))
    pp.run_frames(20)
