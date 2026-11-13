"""Play stage 1 with a simple scripted input and save a contact sheet."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game, BUILD
from PIL import Image
pilot = int(sys.argv[1]) if len(sys.argv) > 1 else 0
every = int(sys.argv[2]) if len(sys.argv) > 2 else 150
n = int(sys.argv[3]) if len(sys.argv) > 3 else 8
pp = boot(); to_game(pp, pilot=pilot)
ims = []
script = [['SPACE', 'UP'], ['SPACE'], ['SPACE', 'DOWN'], ['SPACE', 'RIGHT'], ['SPACE', 'LEFT'], ['SPACE', 'X']]
for i in range(n):
    for j in range(every // 10):
        pp.keys = script[(i * 7 + j) % len(script)]
        pp.run_frames(10)
    ims.append(pp.png('/tmp/claude-0/f.png', scale=1, aspect=1.2).copy())
    print(i, 'scroll', peekw(pp, 'scrollx'), 'gstate', peek(pp, 'gstate'), 'hearts', peek(pp, 'hearts'), 'lives', peek(pp, 'lives'))
w, h = ims[0].size
o = Image.new('RGB', (w * 2, h * ((n + 1) // 2)))
for i, im in enumerate(ims):
    o.paste(im, ((i % 2) * w, (i // 2) * h))
o.save(BUILD / 'shots' / 'sheet.png')
