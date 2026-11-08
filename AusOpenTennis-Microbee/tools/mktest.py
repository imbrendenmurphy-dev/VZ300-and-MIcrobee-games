import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import venues
from cells import compile_cells
from pack import picture_bytes, sprite_frame, SpriteBanks
B = '/home/claude/aot/build/'
c = venues.draw(sys.argv[1] if len(sys.argv) > 1 else 'MELBOURNE')
pats, ink, paper = compile_cells(c.a)
data, gs = picture_bytes(pats, ink, paper)
print('glyphs', len(gs), 'bytes', len(data))
open(B + 'TESTPIC.BIN', 'wb').write(data)
sb = SpriteBanks()
yy, xx = np.mgrid[0:44, 0:30]
fig = ((xx - 15) ** 2 / 36 + (yy - 6) ** 2 / 25 < 1) | ((abs(xx - 15) < 8) & (yy > 11) & (yy < 30)) | ((abs(xx - 15) > 2) & (abs(xx - 15) < 7) & (yy >= 30))
sb.add('T0', sprite_frame(fig, ax=15, ay=43))
ball = (xx[:6, :8] - 4) ** 2 / 9 + (yy[:6, :8] - 3) ** 2 / 6 < 1
sb.add('T1', sprite_frame(ball, ax=4, ay=3))
for i, b in enumerate(sb.banks):
    open(B + 'SPR%d.BNK' % i, 'wb').write(b)
open('/home/claude/aot/src/sprtab.inc', 'w').write(sb.inc())
