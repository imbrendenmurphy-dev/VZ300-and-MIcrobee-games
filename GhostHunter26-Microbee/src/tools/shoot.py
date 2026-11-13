"""Screenshots of the attract round and of set-up moments in play."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
out = BUILD / 'shots'; out.mkdir(exist_ok=True)
A = 1.2
mono = '--mono' in sys.argv
pp = boot(mono=mono)
S = pp.S
pre = 'm_' if mono else ''
def png(n): pp.png(out / (pre + n + '.png'), aspect=A, mono=mono)
def tap(k, n=4):
    pp.keys = [k]; pp.run_frames(n); pp.keys = []; pp.run_frames(4)
pp.run_frames(30); png('00_choose')
tap('M' if mono else 'C')
pp.run_frames(150); png('01_title')
pp.run_frames(330); png('01_title_b')
pp.run_frames(1120 - 480 + 200); png('02_ghosts')
pp.run_frames(600); png('03_powers')
pp.run_frames(600 + 300); png('04_demo')
pp.run_frames(1400 - 300 + 150); png('05_fame')
print('pc %04X' % pp.cpu.pc)
tap('SPACE'); pp.run_frames(60); png('06_ready')
pp.run_frames(100)
pp.keys = ['RIGHT']; pp.run_frames(120); png('07_play')
pp.poke(S['round'], 1); pp.poke(S['gstate'], 4); pp.poke(S['gtimer'], 2); pp.run_frames(8)
pp.keys = []
pp.run_frames(150); png('08_inter_a')
pp.run_frames(260); png('08_inter_b')
pp.run_frames(240); pp.keys=['LEFT']; pp.run_frames(60); pp.keys=[]; png('09_maze3')
# bonus rounds
for r, n in ((3, '10_buffet'), (4, '11_maze4'), (5, '12_maze5'), (6, '13_maze6'), (7, '14_panic')):
    pp.poke(S['round'], r - 1); pp.poke(S['gstate'], 4); pp.poke(S['gtimer'], 2)
    pp.run_frames(40)
    if r == 5: pp.run_frames(480)
    pp.run_frames(200)
    pp.keys = ['RIGHT']; pp.run_frames(60); pp.keys = []
    png(n)
# death and game over
pp.poke(S['lives'], 1); pp.poke(S['hearts'], 1)
pp.poke(S['score'] + 1, 0x88)
for i in range(3000):
    pp.poke(S['p_inv'], 0)
    pp.poke(S['ghosts'], peek(pp, 'p_x')); pp.poke(S['ghosts'] + 1, peek(pp, 'p_y')); pp.poke(S['ghosts'] + 3, 2); pp.poke(S['ghosts'] + 4, 0)
    pp.run_frames(2)
    if peek(pp, 'gstate') == 3: break
pp.run_frames(70); png('15_dying')
pp.run_frames(100); png('16_over')
pp.run_frames(260); png('17_initials')
tap('UP'); tap('SPACE'); tap('DOWN'); tap('SPACE'); tap('SPACE')
pp.run_frames(60); png('18_fame_new')
print('pc %04X sp %04X' % (pp.cpu.pc, pp.cpu.sp))
