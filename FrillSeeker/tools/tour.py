"""A played tour of the prototype's rooms: checks the game's state as it
goes and saves pictures. A simple pilot: it reads the hero's position from
the game's variables and decides what to hold."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from PIL import Image
import run
from mbee import FRAME_T


class Pilot:
    def __init__(self, mono=False, gif=None):
        self.pp = run.start(mono)
        self.S = self.pp.S
        self.mono = mono
        self.ims = [] if gif else None
        self.n = 0
        self.log = []

    def v(self, name, w=False):
        return self.pp.peekw(self.S[name]) if w else self.pp.peek(self.S[name])

    def step(self, keys, frames=1):
        self.pp.keys = keys
        for i in range(frames):
            self.pp.run_frames(1)
            self.n += 1
            if self.ims is not None and self.n % 2 == 0:
                rgb = self.pp.frame_rgb(self.mono)[40:40 + 200, 32:32 + 528]
                self.ims.append(Image.fromarray(rgb).resize((528, 360), Image.NEAREST))

    def state(self):
        return dict(room=self.v('room'), x=self.v('hx', True), y=self.v('hy', True), bugs=self.v('bugs'),
                    hearts=self.v('hearts'), on=self.v('h_on'))

    def note(self, what):
        s = self.state()
        self.log.append((what, s))
        print('%-34s room %d  x %3d  y %3d  bugs %d  hearts %d' % (what, s['room'], s['x'], s['y'], s['bugs'], s['hearts']))

    def shot(self, path):
        run.shot(self.pp, path, self.mono)

    def gif(self, path, colors=48):
        fr = [im.convert('P', palette=Image.ADAPTIVE, colors=colors) for im in self.ims]
        fr[0].save(path, save_all=True, append_images=fr[1:], duration=40, loop=0)


def tour(out, mono=False, gif=True):
    P = Pilot(mono, gif)
    tag = 'm' if mono else ''
    P.note('start')
    P.step([], 30)
    P.step(['RIGHT'], 78)
    P.step(['UP'], 50)                      # the bluff
    P.shot('%s/tour_flare%s.png' % (out, tag))
    toad = [P.pp.peek(P.S['ENTS'] + 16 * i + 1) for i in range(8) if P.pp.peek(P.S['ENTS'] + 16 * i) == 2]
    P.note('flared; toad states %s' % toad)
    for i in range(200):                    # hop on to the toad's belly and glide off the bounce
        s = P.state()
        if P.v('hvy', True) >= 0xFC00 and not s['on']:
            break
        P.step(['RIGHT', 'SPACE'] if (i % 30) < 10 else ['RIGHT'], 1)
    P.note('bounced' if P.v('hvy', True) >= 0xFC00 else 'no bounce')
    P.step(['RIGHT'], 26)
    P.step(['RIGHT', 'UP'], 60)
    P.shot('%s/tour_glide%s.png' % (out, tag))
    P.note('glided')
    for i in range(400):                    # on to the right-hand edge, jumping what is in the way
        s = P.state()
        if s['room'] != 0:
            break
        P.step(['RIGHT', 'SPACE'] if (i % 40) < 12 else ['RIGHT'], 1)
    P.note('walked out of the red dirt')
    P.step([], 20)
    P.shot('%s/tour_room1%s.png' % (out, tag))
    # the billabong: hop the lily pads, gliding
    air = 0
    for i in range(900):
        s = P.state()
        if s['room'] != 1:
            break
        if s['on']:
            if air:
                P.step(['RIGHT'], 1)            # let go of jump
            air = 0
            P.step(['RIGHT', 'SPACE'], 1)
        else:
            air += 1
            P.step(['RIGHT', 'SPACE'] if air < 16 else ['RIGHT', 'UP'], 1)
        if i == 150:
            P.shot('%s/tour_pads%s.png' % (out, tag))
    P.note('crossed the billabong')
    P.step([], 20)
    P.shot('%s/tour_room2%s.png' % (out, tag))
    for i in range(300):
        P.step(['RIGHT', 'SPACE'] if (i % 50) < 14 else ['RIGHT'], 1)
    P.note('in mound city')
    P.shot('%s/tour_end%s.png' % (out, tag))
    if gif:
        P.gif('%s/tour%s.gif' % (out, tag))
    return P


if __name__ == '__main__':
    tour(sys.argv[1], mono=len(sys.argv) > 2)
