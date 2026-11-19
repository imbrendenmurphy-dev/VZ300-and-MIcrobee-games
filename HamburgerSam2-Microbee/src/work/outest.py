"""Run the Order Up! bonus round directly with the test autopilot."""
from test_native import *
Path('outputs/ou').mkdir(parents=True, exist_ok=True)
for f in Path('outputs/ou').glob('*.png'): f.unlink()
b = Bee(); b.until('title_screen.l'); M = b.m.memory
M[sym['autoplay']] = 1; M[sym['mode']] = 1; M[sym['kitchen']] = 1
b.m.sp = 0xEF00; M[0xEF00:0xEF02] = bytes([0xFE, 0xEF]); b.m.pc = sym['order_up']
b.m.set_breakpoint(0xEFFE)
for i in range(4000):
    b.run()
    if i % 150 == 0: b.shot(f'ou/o{i:05d}')
    if b.m.pc == 0xEFFE: print('round over at field', i, 'orders', M[sym['ou_orders']]); b.shot('ou/end'); break
