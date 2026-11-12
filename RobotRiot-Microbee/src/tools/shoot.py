"""Screenshots: the attract round (title, story, gallery, legends, demo),
waves, the wave-clear rectangles, game over and the initials."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD

out = BUILD / 'shots'
out.mkdir(exist_ok=True)
A = 1.2
pp = boot()
S = pp.S


def until(cond, limit=5000):
    for i in range(limit // 2):
        if cond():
            return True
        pp.run_frames(2)
    raise SystemExit('timed out at pc %04X' % pp.cpu.pc)


pp.run_frames(300)
pp.png(out / '01_title.png', aspect=A)
until(lambda: peek(pp, 'att') == 1)
pp.run_frames(640)
pp.png(out / '02_story.png', aspect=A)
until(lambda: peek(pp, 'att') == 2)
pp.run_frames(600)
pp.png(out / '03_gallery.png', aspect=A)
until(lambda: peek(pp, 'att') == 3)
pp.run_frames(200)
pp.png(out / '04_legends.png', aspect=A)
until(lambda: peek(pp, 'demo') == 1)
pp.run_frames(400)
pp.png(out / '05_demo.png', aspect=A)
print('demo: state', peek(pp, 'state'), 'wave', peek(pp, 'wave'), 'score', bytes(peek(pp, 'score', 3)).hex())
pp.keys = ['SPACE']
pp.run_frames(4)
pp.keys = []
pp.run_frames(50)
pp.png(out / '06_wave1_intro.png', aspect=A)
pp.run_frames(110)
pp.keys = ['D', 'J']
pp.run_frames(20)
pp.keys = ['S', 'I']
pp.run_frames(14)
pp.png(out / '07_wave1_play.png', aspect=A)
for w, name in ((4, '08_wave4'), (6, '09_wave6'), (10, '10_wave10')):
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
pp.keys = []
pp.poke(S['state'], 2); pp.poke(S['stimer'], 40)
pp.run_frames(26)
pp.png(out / '11_wave_clear.png', aspect=A)
pp.run_frames(100)
pp.poke(S['score'], 0x07); pp.poke(S['nextlife'], 0x99); pp.poke(S['lives'], 1); pp.poke(S['pcells'], 1); pp.poke(S['pinv'], 0)
until(lambda: (pp.poke(S['pinv'], 0), pp.poke(S['pcells'], 1), peek(pp, 'state') == 4)[2])
pp.run_frames(40)
pp.png(out / '12_game_over.png', aspect=A)
print('hs_new', peek(pp, 'hs_new'))
pp.run_frames(300)
pp.run_frames(20)
for k in ('B', 'P'):
    pp.keys = [k]; pp.run_frames(6); pp.keys = []; pp.run_frames(6)
pp.png(out / '13_initials.png', aspect=A)
pp.keys = ['M']; pp.run_frames(6); pp.keys = []
pp.run_frames(80)
pp.png(out / '14_legends_new.png', aspect=A)
print('att', peek(pp, 'att'), 'hs', bytes(peek(pp, 'hs_tab', 18)))
