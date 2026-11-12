"""Random-input soak: play for N frames (several games), watch for crashes."""
import sys, random
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
N = int(sys.argv[1]) if len(sys.argv) > 1 else 6000
random.seed(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
out = BUILD / 'shots'
out.mkdir(exist_ok=True)
pp = boot(test=True)
pp.run_frames(60)
mv = ['W', 'A', 'S', 'D', 'JOY']
fire = ['I', 'J', 'K', 'L', 'UP', 'LEFT', 'SPACE']
held = []
maxwave = 0
games = 0
last_state = None
for f in range(0, N, 2):
    if f % 10 == 0:
        held = random.sample(mv[:4], random.choice([0, 1, 1, 2]))
        held += random.sample(fire, random.choice([0, 1, 1, 2]))
        if random.random() < 0.01:
            held.append('P')
        if random.random() < 0.01:
            held.append('M')
    pp.keys = held
    pp.run_frames(2)
    pc, sp = pp.cpu.pc, pp.cpu.sp
    ok_sp = 0xEE00 <= sp <= 0xF000 or 0xD000 <= sp <= 0xDC00   # stack, or a draw list being popped
    if not (0x8000 <= pc < 0xA400) or not ok_sp:
        print('CRASH? frame %d pc %04X sp %04X' % (f, pc, sp))
        pp.png(out / 'crash.png', aspect=1.2)
        break
    st = peek(pp, 'state')
    maxwave = max(maxwave, peek(pp, 'wave'))
    if st == 4 and last_state != 4:
        games += 1
    last_state = st
    if f % 1000 == 0:
        print('f %5d wave %d state %d lives %d cells %d left %d score %s' % (
            f, peek(pp, 'wave'), st, peek(pp, 'lives'), peek(pp, 'pcells'), peek(pp, 'enemies_left'),
            ''.join('%02X' % b for b in peek(pp, 'score', 3))))
print('done', N, 'frames; games over:', games, 'highest wave:', maxwave)
