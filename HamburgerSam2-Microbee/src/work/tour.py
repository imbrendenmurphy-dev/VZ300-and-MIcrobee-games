"""Screenshot tour: run attract mode in real time (1 run = one 50 Hz field)."""
import sys
from test_native import *
Path('outputs/tour').mkdir(parents=True, exist_ok=True)
frames = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
step = int(sys.argv[2]) if len(sys.argv) > 2 else 150
b = Bee()
for i in range(frames):
    b.run()
    if i % step == 0:
        b.shot(f'tour/a{i:05d}')
        print(i, 'mode', b.peek(sym['mode']), 'pc', hex(b.m.pc), 'fc', b.m.memory[sym['framecount']] | b.m.memory[sym['framecount'] + 1] << 8)
