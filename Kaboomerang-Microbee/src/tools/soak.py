"""Random-input soak: play for N frames, watch for crashes, log state, shots."""
import sys, random
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
N = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
random.seed(seed)
out = BUILD / 'shots'
out.mkdir(exist_ok=True)
pp = boot(test=True)
pp.run_frames(80)
dirs = ['LEFT', 'RIGHT', 'UP', 'DOWN']
held = []
shots = 0
for f in range(0, N, 2):
    if f % 12 == 0:
        held = [random.choice(dirs)]
        r = random.random()
        if r < 0.18:
            held.append('SPACE')
        elif r < 0.24:
            held.append('X')
    pp.keys = held
    pp.run_frames(2)
    pc, sp = pp.cpu.pc, pp.cpu.sp
    inblit = pp.S['sb_16'] <= pc <= pp.S['sb_0'] + 8 or pp.S['seg_blit'] <= pc < pp.S['sb_tab']
    if not (0x8000 <= pc < 0xB000) or (not inblit and not (0xE700 <= sp <= 0xF000)):
        print('CRASH? frame %d pc %04X sp %04X' % (f, pc, sp))
        pp.png(out / 'crash.png', aspect=1.1)
        break
    if f % 500 == 0:
        print('f %5d stage %d gstate %d hearts %d enemies %d score %s bombs %d range %d' % (
            f, peek(pp, 'stage'), peek(pp, 'gstate'), peek(pp, 'p_hearts'), peek(pp, 'nenemy'),
            ''.join('%02X' % b for b in peek(pp, 'score', 3)), peek(pp, 'p_bombs'), peek(pp, 'p_range')))
    if peek(pp, 'chain') and shots < 4 and f > 200:
        pp.run_frames(4)
        pp.png(out / ('boom%d.png' % shots), aspect=1.1)
        shots += 1
print('done', N)
