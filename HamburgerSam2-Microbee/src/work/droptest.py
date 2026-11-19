"""Drop the first piece on floor 0 by hand and film the fall."""
from test_native import *
Path('outputs/drop').mkdir(parents=True, exist_ok=True)
b = Bee(); b.until('title_screen.l'); b.call('dl_reset')
M = b.m.memory
M[sym['kitchen']] = 0; M[sym['mode']] = 1; M[sym['lives']] = 4; M[sym['peppers']] = 6
b.m.a = 0; b.call('load_kitchen'); b.call('draw_kitchen'); b.call('setup_round'); b.call('wipe_show')
M[sym['godmode']] = 1
P = sym['pieces']
npc = M[sym['npc']]
for i in range(npc):
    r = M[P + i * 10:P + i * 10 + 10]
    print(i, 'x', r[0], 'f', r[1], 'y', r[2], 't', r[4], 'c', r[5], 'st', r[6])
k = int(__import__('sys').argv[1]) if len(__import__('sys').argv) > 1 else 0
# park Sam far away so he doesn't interfere
for f in range(3): b.call('game_frame')
b.shot('drop/f000')
# start the fall via the real routine
b.m.ix = P + k * 10
b.call('grab_riders'); b.m.ix = P + k * 10; b.call('start_fall')
for f in range(1, 40):
    b.call('game_frame')
    if f % 4 == 0: b.shot(f'drop/f{f:03d}')
r = M[P + k * 10:P + k * 10 + 10]
print('after', 'y', r[2], 'st', r[6], 'f', r[1])
