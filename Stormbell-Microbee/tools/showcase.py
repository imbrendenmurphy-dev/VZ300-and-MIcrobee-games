"""STORMBELL release pictures, from the emulator (VIBED BY BPM 2026).

    python3 tools/showcase.py OUTDIR

Plays the game with the scripted player and writes:
  OUTDIR/gameplay/   moments from play: each stage's road and duel, a kick
                     landing, a guard holding, a fall, the monochrome mode
  OUTDIR/info/       the title (colour and mono), a stage's opening, the
                     pause screen, defeat, victory, the ending
  OUTDIR/frames_*/   the frames of each showcase GIF segment
Then tools/showcase_gif.py joins the segments into the showcase GIF.
"""
import sys
import pickle
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import playtest as P
import boottest as T
from mbee import L

ST = {n: i for i, n in enumerate('IDLE STEP GUARD ATK HIT BLOCKED FALL DOWN BOW STAND RUN'.split())}
FR_PUNCH, FR_KICK = 8, 10
ASPECT = 0.92            # a 40-column pixel is about 1.09 times wider than a line is tall
STAGES = ['outer-gate', 'river-bridge', 'cliff-path', 'dojo-hall', 'bell-tower']


class Cam:
    def __init__(self, g, out, mono=False):
        self.g, self.pp, self.out, self.mono = g, g.pp, Path(out), mono
        (self.out / 'gameplay').mkdir(parents=True, exist_ok=True)
        (self.out / 'info').mkdir(parents=True, exist_ok=True)
        self.seg = None
        self.segs = {}
        self.count = 0

    def shot(self, kind, name):
        if self.mono and kind == 'gameplay':
            name = 'mono_' + name
        p = self.out / kind / (name + '.png')
        self.pp.png(str(p), scale=2, aspect=ASPECT, mono=self.mono)
        print('  ', kind, name)

    def start(self, name):
        self.seg = name
        self.segs[name] = []

    def stop(self):
        self.seg = None

    def frames(self, n):
        """run n frames; while a segment is on, keep every second one"""
        for i in range(n):
            self.pp.run_frames(1)
            self.count += 1
            if self.seg and self.count % 2 == 0:
                self.segs[self.seg].append(self.pp.screen_rgb(mono=self.mono))

    def save(self):
        with open(self.out / ('segments%s.pkl' % ('_mono' if self.mono else '')), 'wb') as f:
            pickle.dump(self.segs, f)


def to_duel(g, stage, mono=False):
    """from the title, start the game at `stage` (1..5)"""
    pp = g.pp
    L.mb_set_bp(pp.h, g.S['duel'], 1)
    pp.keys = {'SPACE'}
    while not L.mb_run(pp.h, pp.tick + 67608):
        pass
    L.mb_set_bp(pp.h, g.S['duel'], 0)
    pp.keys = set()
    pp.poke(g.S['stage'], stage - 1)
    pp.poke(g.S['mono'], 1 if mono else 0)


def run_road(c, stage, gif=None):
    """hold advance until this stage's road is moving, then on until the
    duel begins: a picture and (optionally) a GIF segment of the run"""
    g = c.g
    for i in range(3000):
        g.pp.keys = {'D'}
        c.frames(2)
        if g.var('stage') == stage - 1 and g.var('cam_c') >= 2 and g.f('hero', 'ST') == ST['RUN']:
            break
    if gif:
        c.start(gif)
    for i in range(1500):
        g.pp.keys = {'D'}
        c.frames(2)
        if i == 40:
            c.shot('gameplay', 'stage%d_%s_road' % (stage, STAGES[stage - 1]))
        if gif and i == 70:
            c.stop()
        if g.in_fight():
            break
    g.pp.keys = set()
    c.stop()


def duel(c, stage, gif=None, gif_ticks=0, fall_gif=None):
    """the scripted player fights one duel; pictures of the moments that
    show the game: a blow landing, a guard holding, the fall"""
    g = c.g
    got = set()
    last_attack = set()
    if gif:
        c.start(gif)
    n = 0
    while n < 3000:
        h, f = g.f('hero', 'ST'), g.f('foe', 'ST')
        hfr = g.f('hero', 'FR')
        if f == ST['DOWN'] or h == ST['DOWN']:
            break
        if 'hit' not in got and f == ST['HIT'] and hfr == FR_KICK:
            c.shot('gameplay', 'stage%d_%s_kick_lands' % (stage, STAGES[stage - 1])); got.add('hit')
        if 'punch' not in got and f == ST['HIT'] and hfr == FR_PUNCH:
            c.shot('gameplay', 'stage%d_%s_punch_lands' % (stage, STAGES[stage - 1])); got.add('punch')
        if 'block' not in got and h == ST['GUARD'] and f == ST['ATK'] and g.f('foe', 'PH') == 1:
            c.shot('gameplay', 'stage%d_%s_guard' % (stage, STAGES[stage - 1])); got.add('block')
        if 'fall' not in got and f == ST['FALL']:
            if fall_gif:
                c.start(fall_gif)
            got.add('fall')
        if 'fall2' not in got and f == ST['FALL'] and g.f('foe', 'FR') == 14:
            c.shot('gameplay', 'stage%d_%s_knockdown' % (stage, STAGES[stage - 1])); got.add('fall2')
        if n == 140:
            c.shot('gameplay', 'stage%d_%s_duel' % (stage, STAGES[stage - 1]))
        keys = g.decide()
        if keys & {'K', 'L'}:
            if keys & last_attack:
                keys = keys - {'K', 'L'}
        last_attack = keys & {'K', 'L'}
        g.pp.keys = keys
        c.frames(2)
        n += 1
        if gif and n == gif_ticks:
            c.stop()
    g.pp.keys = set()
    res = 'won' if g.f('foe', 'ST') == ST['DOWN'] else 'lost'
    c.frames(60)
    c.stop()
    return res


def colour_run(out):
    g = P.Game(str(Path(out) / 'tmp'), 'good')
    g.react = 5
    c = Cam(g, out)
    pp = g.pp
    T.launch(pp, 520)
    c.shot('info', 'info_01_title')
    c.start('a_title')
    c.frames(110)
    c.stop()
    # stage 1 from the start: the road, the opponent's entrance, the bows
    g.press({'SPACE'})
    c.start('b_road1')
    for i in range(160):
        pp.keys = {'D'}
        c.frames(2)
        if i == 80:
            c.shot('gameplay', 'stage1_outer-gate_road')
    c.stop()
    for i in range(1500):
        pp.keys = {'D'}
        c.frames(2)
        if g.f('hero', 'ST') == ST['BOW'] or g.f('foe', 'ST') == ST['BOW']:
            break
    pp.keys = set()
    c.frames(10)
    c.shot('info', 'info_02_stage_opening')
    c.start('c_bow')
    for i in range(400):
        c.frames(2)
        if g.in_fight():
            break
    c.stop()
    duel(c, 1, gif='d_duel1', gif_ticks=230, fall_gif='e_fall1')
    c.shot('info', 'info_05_victory')
    # stages 2..5: run on, fight
    for st in range(2, 6):
        run_road(c, st, gif='f_road%d' % st if st in (2, 5) else None)
        res = duel(c, st, gif='g_duel%d' % st, gif_ticks={2: 110, 3: 110, 4: 110, 5: 260}[st],
                   fall_gif='h_fall5' if st == 5 else None)
        print('stage %d: %s' % (st, res))
        if res != 'won':
            pp.keys = {'SPACE'}
            c.frames(4)
            pp.keys = set()
            if not g.wait_fight_start():
                break
            res = duel(c, st)
            print('stage %d again: %s' % (st, res))
    # the run to the bell and the ending
    for i in range(600):
        pp.keys = {'D'}
        c.frames(2)
        if g.name(pp.cpu.pc).startswith(('ending', 'pause_ticks')) or g.var('stage') >= 5:
            break
    pp.keys = set()
    c.frames(150)
    c.start('i_ending')
    c.frames(300)
    c.stop()
    c.shot('info', 'info_06_ending')
    c.save()


def mono_run(out):
    """the monochrome mode: the title, two stages"""
    g = P.Game(str(Path(out) / 'tmp'), 'good')
    g.react = 5
    c = Cam(g, out, mono=True)
    pp = g.pp
    T.launch(pp, 520)
    g.press({'M'}, frames=6)
    c.frames(150)
    c.shot('info', 'info_08_title_mono')
    to_duel(g, 2, mono=True)
    run_road(c, 2)
    duel(c, 2, gif='j_mono2', gif_ticks=140)
    c.save()


def extra_screens(out):
    """pause, defeat, and the monochrome bell tower"""
    import stagewatch as SW
    g = SW.at_stage(4, 'good', out=str(Path(out) / 'tmp'), react=5)
    c = Cam(g, out)
    for i in range(60):
        g.pp.keys = g.decide()
        c.frames(2)
    g.pp.keys = set()
    g.press({'P'})
    c.frames(30)
    c.shot('info', 'info_03_pause')
    g.press({'P'})
    c.frames(10)
    g = SW.at_stage(3, 'idle', out=str(Path(out) / 'tmp'), react=5)
    c = Cam(g, out)
    g.fight(max_ticks=3000)
    c.frames(150)
    c.shot('info', 'info_04_defeat')
    # the bell tower in mono
    g = P.Game(str(Path(out) / 'tmp'), 'good')
    g.react = 5
    c = Cam(g, out, mono=True)
    T.launch(g.pp, 520)
    to_duel(g, 5, mono=True)
    g.wait_fight_start()
    duel(c, 5)


if __name__ == '__main__':
    out = sys.argv[1]
    what = sys.argv[2] if len(sys.argv) > 2 else 'all'
    if what in ('all', 'colour'):
        colour_run(out)
    if what in ('all', 'mono'):
        mono_run(out)
    if what in ('all', 'extra'):
        extra_screens(out)
