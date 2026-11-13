"""Each pilot fully powered (missile, laser or double, 2 options, shield)
in a busy part of stage 1, with frame-rate figures: build/shots/weapons.png"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game, BUILD
from autoplay import step, enemies
from PIL import Image
ims = []
for pilot in range(4):
    for kind in ('double', 'laser'):
        pp = boot(); to_game(pp, pilot=pilot); S = pp.S
        for t in range(60): step(pp)
        pp.poke(S['pmissile'], 1); pp.poke(S['poptions'], 2); pp.poke(S['pshield'], 3); pp.poke(S['pspeed'], 2)
        pp.poke(S['pdouble'], 1 if kind == 'double' else 0); pp.poke(S['plaser'], 1 if kind == 'laser' else 0)
        for t in range(40): step(pp)
        a = peekw(pp, 'framecount')
        for t in range(50): step(pp)
        fps = (peekw(pp, 'framecount') - a) * 50 / 200
        im = pp.png('/tmp/claude-0/w.png', scale=1, aspect=1.2).copy()
        ims.append(im)
        print('pilot', pilot, kind, 'fps %.1f' % fps, 'enemies', len(enemies(pp)), 'pool', peek(pp, 'poolcnt'), 'direct', peek(pp, 'dlcnt'))
w, h = ims[0].size
o = Image.new('RGB', (w * 2, h * 4))
for i, im in enumerate(ims):
    o.paste(im, ((i % 2) * w, (i // 2) * h))
o.save(BUILD / 'shots' / 'weapons.png')
