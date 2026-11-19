"""Call front-end screens directly and capture them: kitchen card, ending."""
from test_native import *
Path('outputs/screens').mkdir(parents=True, exist_ok=True)
def run(label, setup, shots):
    b = Bee(); b.until('title_screen.l'); M = b.m.memory
    for k, v in setup.items(): M[sym[k]] = v
    b.m.sp = 0xEF00; M[0xEF00:0xEF02] = bytes([0xFE, 0xEF]); b.m.pc = sym[label]
    b.m.set_breakpoint(0xEFFE)
    for i in range(max(shots) + 1):
        b.run()
        if i in shots: b.shot(f'screens/{label}_{i:04d}')
        if b.m.pc == 0xEFFE: break
run('kitchen_card', {'kitchen': 3, 'lives': 4, 'peppers': 7, 'mode': 1}, [60, 150])
run('ending', {'mode': 1}, [80, 300])
run('game_over', {'mode': 1}, [80])
