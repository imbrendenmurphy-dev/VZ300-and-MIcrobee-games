"""Boot, start a game, play a little: screenshots in build/shots."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, tap, to_game, BUILD

out = BUILD / 'shots'
out.mkdir(exist_ok=True)
pp = boot()
pp.run_frames(30)
pp.png(out / '00_monitor.png', aspect=1.2)
tap(pp, 'C')
pp.run_frames(30)
pp.png(out / '01_front.png', aspect=1.2)
tap(pp, 'SPACE')
pp.run_frames(60)
pp.png(out / '02_intro.png', aspect=1.2)
pp.run_frames(120)
pp.png(out / '03_play.png', aspect=1.2)
pp.keys = ['SPACE', 'RIGHT', 'UP']
pp.run_frames(40)
pp.png(out / '04_fire.png', aspect=1.2)
pp.keys = []
print('pc %04X gstate %d scroll %d stage %d px %d py %d' % (pp.cpu.pc, peek(pp, 'gstate'), peekw(pp, 'scrollx'), peek(pp, 'stage'), peekw(pp, 'px'), peek(pp, 'py')))
