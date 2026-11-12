"""Jump to a stage (by clearing the ones before), autoplay it, contact sheet.
Usage: stagetest.py stage [fields] [pilot]"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game, BUILD
from autoplay import step, score
from PIL import Image
st = int(sys.argv[1]) if len(sys.argv) > 1 else 2
fields = int(sys.argv[2]) if len(sys.argv) > 2 else 4000
pilot = int(sys.argv[3]) if len(sys.argv) > 3 else 0
pp = boot(); to_game(pp, pilot=pilot); S = pp.S
while peek(pp, 'stage') != st:
    pp.run_frames(20)
    if peek(pp, 'gstate') == 0 and peek(pp, 'stage') < st:
        pp.poke(S['stage'], st - 1); pp.poke(S['gstate'], S['GS_CLEAR'])
for i in range(200): step(pp)
ims = []
n = 8
for i in range(n):
    for t in range(fields // n // 4):
        step(pp, 4, ['X'] if t % 40 == 0 else ())
        pp.poke(S['lives'], 3)
    ims.append(pp.png('/tmp/claude-0/s.png', scale=1, aspect=1.2).copy())
    print(i, 'stage', peek(pp, 'stage'), 'scroll', peekw(pp, 'scrollx'), 'gstate', peek(pp, 'gstate'), 'boss st', peek(pp, 'boss_st'), 'hp', peekw(pp, 'boss_hp'), 'gas', peek(pp, 'boss_jam'), 'score', score(pp), 'pc %04X' % pp.cpu.pc)
w, h = ims[0].size
o = Image.new('RGB', (w * 2, h * ((n + 1) // 2)))
for i, im in enumerate(ims):
    o.paste(im, ((i % 2) * w, (i // 2) * h))
o.save(BUILD / 'shots' / ('stage%d.png' % st))
