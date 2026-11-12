"""Work time per frame (T-states; 135000 = two fields) on a busy wave."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek
w = int(sys.argv[1]) if len(sys.argv) > 1 else 10
pp = boot(test=True); pp.run_frames(40)
pp.poke(pp.S['wave'], w - 1); pp.poke(pp.S['state'], 2); pp.poke(pp.S['stimer'], 1)
pp.run_frames(80); pp.poke(pp.S['pinv'], 250); pp.keys = ['A', 'L']
S = pp.S
rows = []
for i in range(30):
    pp.run_until(S['game_loop'], 10); t0 = pp.tick
    pp.run_until(S['dl_begin'], 10); t1 = pp.tick
    pp.run_until(S['dl_flush'], 10); t2 = pp.tick
    pp.run_until(S['hud_update'], 10); t3 = pp.tick
    pp.run_until(S['show_page'], 10); t4 = pp.tick
    rows.append((t4 - t0, t1 - t0, t2 - t1, t3 - t2, t4 - t3, peek(pp, 'dln')))
rows.sort()
print('total  update  draw  flush  hud  cells')
for r in rows[::6] + [rows[-1]]:
    print('%6d %6d %6d %6d %5d %4d' % r)
