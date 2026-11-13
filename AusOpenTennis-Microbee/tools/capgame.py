"""Release screenshots: matches on every court (shots/pkg/game_*.png)."""
import run, sys
OUT = '/home/claude/aot/shots/pkg/'
NAMES = ['kooyong', 'perth', 'sydney', 'melbourne', 'classic']


def match(venue, mono=False, mode=None, fly=False, call=False, frames=400):
    pp = run.boot()
    S = pp.S
    pp.poke(S['boot_venue'], venue)
    if mode is not None:
        pp.poke(S['boot_mode'], mode)
    pp.poke(S['monomode'], 1 if mono else 0)
    pp.poke(S['boot_test'], 1)
    pp.run_frames(5)
    pp.poke(S['autoplay'], 1)
    pp.run_frames(frames)
    if fly:
        pp.poke(S['fly_wait'], 2); pp.poke(S['fly_wait'] + 1, 0)
        while not (pp.peek(S['fly_on']) and (pp.peek(S['fly_x']) | pp.peek(S['fly_x'] + 1) << 8) < 330):
            pp.run_frames(2)
    def w(a): return (pp.peek(a) | pp.peek(a + 1) << 8) >> 6
    for k in range(3000):
        pp.run_frames(1)
        if call:
            if pp.peek(S['pop_on']) and pp.peek(S['pt_over']):
                pp.run_frames(8)
                break
        elif pp.peek(S['ball_st']) == 2 and 120 < w(S['ball_y']) < 150 and pp.peek(S['rally']) >= 2 and pp.peek(S['pt_over']) == 0:
            break
    return pp


if __name__ == '__main__':
    what = sys.argv[1]
    if what == 'courts':
        for v in range(5):
            pp = match(v, fly=v in (0, 3))
            pp.png(OUT + 'game_%02d_%s.png' % (v + 1, NAMES[v]), 2)
    elif what == 'mono':
        pp = match(3, mono=True, frames=900)
        pp.png(OUT + 'game_06_melbourne_mono.png', 2, mono=True)
        pp = match(0, mono=True, frames=1300)
        pp.png(OUT + 'game_07_kooyong_mono.png', 2, mono=True)
    elif what == 'extra':
        pp = match(1, call=True, frames=200)
        pp.png(OUT + 'game_08_perth_call.png', 2)
        pp = match(2, frames=200, mode=4)
        pp.run_frames(300)
        pp.png(OUT + 'game_09_target_practice.png', 2)
