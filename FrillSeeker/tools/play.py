"""Scripted play: a list of (frames, keys) -> frame timings, a GIF."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from PIL import Image
import run
from mbee import FRAME_T

DEMO = [(40, []), (70, ['RIGHT']), (12, ['RIGHT', 'SPACE']), (40, ['RIGHT']), (60, ['UP']), (30, []),
        (16, ['RIGHT', 'SPACE']), (60, ['RIGHT', 'UP']), (40, ['RIGHT']), (14, ['SPACE']), (80, ['RIGHT', 'UP']),
        (60, ['RIGHT'])]


def play(script=DEMO, mono=False, gif=None, every=2, scale=2):
    pp = run.start(mono)
    S = pp.S
    pp.watch(S['main_loop'])
    ims = []
    n = 0
    for frames, keys in script:
        pp.keys = keys
        for i in range(frames):
            pp.run_frames(1)
            n += 1
            if gif and n % every == 0:
                rgb = pp.frame_rgb(mono)[40:40 + 200, 32:32 + 528]
                im = Image.fromarray(rgb).resize((528 * scale // 2, int(200 * scale * 0.9)), Image.NEAREST)
                ims.append(im.convert('P', palette=Image.ADAPTIVE, colors=32))
    ev = pp.events()
    t = np.array([e[0] for e in ev], np.float64)
    d = np.diff(t) / FRAME_T
    if gif:
        ims[0].save(gif, save_all=True, append_images=ims[1:], duration=20 * every, loop=0)
    return pp, d


if __name__ == '__main__':
    out = sys.argv[1]
    pp, d = play(gif=out + '/play.gif')
    print('frames %d: mean %.2f fields, 1-field %.0f%%, 2-field %.0f%%, 3+ %.0f%%' % (
        len(d), d.mean(), 100 * (d.round() == 1).mean(), 100 * (d.round() == 2).mean(), 100 * (d.round() >= 3).mean()))
    print('nslots', pp.peek(pp.S['nslots']), 'hx', pp.peekw(pp.S['hx']), 'hy', pp.peekw(pp.S['hy']), 'room', pp.peek(pp.S['room']),
          'bugs', pp.peek(pp.S['bugs']), 'hearts', pp.peek(pp.S['hearts']))
    run.shot(pp, out + '/t2.png')
