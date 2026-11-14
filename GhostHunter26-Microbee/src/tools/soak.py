"""Soak: the demo hunter plays for N fields; watch for crashes, log, shots."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
N = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
out = BUILD / 'shots'; out.mkdir(exist_ok=True)
pp = boot(test=True)
S = pp.S
pp.run_frames(60)
pp.poke(S['demo'], 1)
shots = set()
f0 = pp.peekw(S['framecount'])
def shot(name):
    if name not in shots:
        shots.add(name); pp.png(out / (name + '.png'), aspect=0.96)
for f in range(0, N, 4):
    pp.poke(S['att_t'], 0); pp.poke(S['att_t'] + 1, 0)
    pp.poke(S['demo'], 1)
    pp.run_frames(4)
    pc, sp = pp.cpu.pc, pp.cpu.sp
    inblit = S['sb_16'] <= pc <= S['sb_0'] + 8 or S['seg_blit'] <= pc < S['sb_tab']
    if not (0x8000 <= pc < S['code_end']) or (not inblit and not (0xEF00 <= sp <= 0xF000)):
        print('CRASH? field %d pc %04X sp %04X' % (f, pc, sp)); shot('crash'); break
    if peek(pp, 'fr_time'): shot('fright')
    if peek(pp, 'it_type') and peek(pp, 'it_shown'): shot('item%d' % peek(pp, 'it_type'))
    if peek(pp, 'gstate') == 2: shot('eat')
    if peek(pp, 'gstate') == 4: shot('clear')
    if peek(pp, 't_speed'): shot('speed')
    if peek(pp, 't_freeze'): shot('freeze')
    if peek(pp, 't_hunter'): shot('hunter')
    if peek(pp, 'rtype') and peek(pp, 'gstate') == 1: shot('bonus%d' % peek(pp, 'rtype'))
    if f % 400 == 0:
        print('f %5d round %d gs %d dots %3d hearts %d lives %d fr %d item %d phase %d ghosts %s' % (
            f, peek(pp, 'round'), peek(pp, 'gstate'), pp.peekw(S['dots_left']), peek(pp, 'hearts'), peek(pp, 'lives'),
            peek(pp, 'fr_time'), peek(pp, 'it_type'), peek(pp, 'phase'),
            [(pp.peek(S['ghosts'] + 8 * k), pp.peek(S['ghosts'] + 8 * k + 1), pp.peek(S['ghosts'] + 8 * k + 3)) for k in range(4)]))
f1 = pp.peekw(S['framecount'])
print('done: %d game frames in %d fields' % ((f1 - f0) & 0xFFFF, N))
shot('end')
