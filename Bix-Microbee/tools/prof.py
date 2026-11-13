"""Where a frame's T-states go, by stage of the frame."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
from mbee import FRAME_T

def profile(keys=('RIGHT',), frames=200, warm=60, mono=False):
    pp = run.start(mono)
    S = pp.S
    pp.keys = list(keys)
    pp.run_frames(warm)
    marks = [('input', 'game_loop'), ('player', 'player_update'), ('camera', 'camera_update'), ('ents', 'ents_update'), ('hud', 'hud_update'), ('scroll', 'e_frame'), ('queue', 'e_frame.steady'), ('ladders', 'lad_apply'), ('compose', 'ef_sprites'),
             ('sprites', 'ef_sprites.nospr'), ('restores', 'restores'), ('present', 'present'), ('show', 'present.show'),
             ('flips', 'do_flips')]
    name = {}
    for n, s in marks:
        pp.watch(S[s]); name[S[s]] = n
    pp.events()
    pp.run_frames(frames)
    ev = pp.events()
    tot = {}; cnt = 0; mx = {}
    for (t0, p0), (t1, p1) in zip(ev, ev[1:]):
        n = name[p0]
        tot[n] = tot.get(n, 0) + (t1 - t0)
        mx[n] = max(mx.get(n, 0), t1 - t0)
        cnt += n == 'input'
    print('%d frames in %d fields (%.1f fps)' % (cnt, frames, 50.0 * cnt / frames))
    for n, _ in marks:
        print('  %-9s %7.0f T a frame, worst %6d' % (n, tot.get(n, 0) / cnt, mx.get(n, 0)))
    return pp

if __name__ == '__main__':
    profile()
