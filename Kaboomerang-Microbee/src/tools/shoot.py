"""Boot, choose colour, look at the title, start, play a little: screenshots."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
from mbee import KEY

out = BUILD / 'shots'
out.mkdir(exist_ok=True)
mono = '--mono' in sys.argv
pp = boot(mono=mono)
pp.run_frames(60)
pp.png(out / '00_choose.png', aspect=1.1)
pp.keys = [KEY['M' if mono else 'C']]
pp.run_frames(4)
pp.keys = []
pp.run_frames(60)
pp.png(out / '01_title.png', aspect=1.1, mono=mono)
pp.keys = [KEY['SPACE']]
pp.run_frames(4)
pp.keys = []
pp.run_frames(40)
pp.png(out / '02_ready.png', aspect=1.1, mono=mono)
pp.run_frames(60)
pp.png(out / '03_play.png', aspect=1.1, mono=mono)
print('pc %04X stage %d gstate %d hx %d hy %d' % (pp.cpu.pc, peek(pp, 'stage'), peek(pp, 'gstate'), peek(pp, 'p_hx'), peek(pp, 'p_hy')))
