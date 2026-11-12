"""Screenshots: title, the rogue mob, wave intros and play on several waves, game over."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD

out = BUILD / 'shots'
out.mkdir(exist_ok=True)
A = 1.2
pp = boot()
pp.run_frames(80)
pp.png(out / '01_title.png', aspect=A)
pp.run_frames(620)
pp.png(out / '02_rogue_mob.png', aspect=A)
pp.keys = ['SPACE']
pp.run_frames(4)
pp.keys = []
pp.run_frames(40)
pp.png(out / '03_wave1_intro.png', aspect=A)
pp.run_frames(120)
pp.keys = ['D', 'J']
pp.run_frames(20)
pp.keys = ['S', 'I']
pp.run_frames(14)
pp.png(out / '04_wave1_play.png', aspect=A)
S = pp.S
for w, name in ((4, '05_wave4_shearers_harvester'), (6, '06_wave6_maggies'), (10, '07_wave10_big_muster')):
    pp.poke(S['wave'], w - 1); pp.poke(S['state'], 2); pp.poke(S['stimer'], 1); pp.poke(S['pinv'], 0)
    pp.keys = []
    pp.run_frames(140)
    pp.poke(S['pinv'], 0)
    pp.keys = ['A', 'L']
    pp.run_frames(36)
    pp.poke(S['pinv'], 0)
    pp.keys = ['W', 'K', 'J']
    pp.run_frames(24)
    pp.png(out / (name + '.png'), aspect=A)
pp.poke(S['lives'], 1); pp.poke(S['pcells'], 1); pp.poke(S['pinv'], 0)
pp.poke(S['px'], 36); pp.poke(S['py'], 20)
for i in range(200):
    pp.run_frames(2)
    if peek(pp, 'state') == 4:
        break
    pp.poke(S['pinv'], 0)
    pp.poke(S['pcells'], 1)
    # walk into the nearest robot
pp.run_frames(40)
pp.png(out / '08_game_over.png', aspect=A)
print('state', peek(pp, 'state'))
