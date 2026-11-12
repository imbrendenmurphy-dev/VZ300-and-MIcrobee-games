"""Where a frame's T-states go: a profile by routine, and the T-states the
6545 holds the CPU for (video RAM touched while a line is drawn)."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import run
from mbee import FRAME_T

def profile(keys=('RIGHT',), frames=150, warm=60, mono=False):
    pp = run.start(mono)
    S = pp.S
    pp.keys = list(keys)
    pp.run_frames(warm)
    pp.watch(S['main_loop'])
    pp.events()
    pp.profile(True)
    w0 = pp.vwait()
    t0 = pp.tick
    pp.run_frames(frames)
    nloops = len(pp.events())
    prof = pp.prof()
    tot = pp.tick - t0
    names = sorted((v, k) for k, v in S.items() if 0x8000 <= v < 0xA800 and '.' not in k)
    rows = []
    for i, (a, n) in enumerate(names):
        b = names[i + 1][0] if i + 1 < len(names) else 0xA800
        rows.append((int(prof[a:b].sum()), n))
    rows.sort(reverse=True)
    print('%d game frames in %d fields (%.2f fields a frame = %.1f fps); %.0f T a frame' % (
        nloops, frames, frames / nloops, 50.0 * nloops / frames, tot / nloops))
    print('held by the 6545: %.0f T a frame' % ((pp.vwait() - w0) / nloops))
    for t, n in rows[:14]:
        print('  %-14s %7.0f T a frame' % (n, t / nloops))
    return pp

if __name__ == '__main__':
    profile()
