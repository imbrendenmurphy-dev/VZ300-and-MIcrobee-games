"""Measure SPINDRIFT on the Premium Plus model: frame rate, how long the
commit (the vertical-blanking work) takes, what is on screen, and where
the time goes.

    python3 tools/perf.py [seconds] [sector]
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import run
from mbee import FRAME_T

VBLANK_T = 113 * 216          # 113 blanked lines of 216 T


def bot_keys(pp, t):
    """sweep one way then the other, firing"""
    k = ['SPACE']
    k.append('X' if (t // 90) % 2 else 'Z')
    return k


def measure(seconds=40, sector=0, prof=False, quiet=False, shots_dir=None):
    pp = run.start_game()
    S = pp.S
    if sector:
        pp.poke(S['sector'], sector)
    pp.watch(S['commit'])
    pp.watch(S['cleanup'])
    pp.events()
    if prof:
        pp.profile(True)
    w0 = pp.vwait()
    rows = []
    t_last = None
    t_commit = None
    fields = seconds * 50
    worst = (0, None)
    for f in range(fields):
        pp.keys = bot_keys(pp, f)
        pp.run_frames(1)
        for t, pc in pp.events():
            if pc == S['commit']:
                if t_last is not None:
                    rows.append([(t - t_last) / FRAME_T, 0, (run.var(pp, 'nextcode') - 0x91) & 255, run.var(pp, 'lcount'),
                                 run.var(pp, 'nenemy'), run.var(pp, 'phase')])
                t_last = t
                t_commit = t
            elif pc == S['cleanup'] and t_commit is not None and rows:
                rows[-1][1] = t - t_commit
        if shots_dir and rows and rows[-1][3] > worst[0]:
            worst = (rows[-1][3], f)
            run.shot(pp, Path(shots_dir) / 'busiest.png')
    a = np.array(rows, float)
    fps = 50.0 / a[:, 0].mean()
    if not quiet:
        print('%d frames in %d s: %.1f frames a second; %.0f%% of frames at 25' % (
            len(a), seconds, fps, 100.0 * (a[:, 0] < 2.5).mean()))
        print('commit: mean %.0f T, max %.0f T (the blanking is %d T); over it in %d frames' % (
            a[:, 1].mean(), a[:, 1].max(), VBLANK_T, (a[:, 1] > VBLANK_T).sum()))
        print('cells a frame: mean %.0f, max %.0f; glyphs: mean %.0f, max %.0f; enemies max %d' % (
            a[:, 3].mean(), a[:, 3].max(), a[:, 2].mean(), a[:, 2].max(), a[:, 4].max()))
        print('held by the 6545: %.0f T a frame' % ((pp.vwait() - w0) / len(a)))
        print('score', ''.join('%02X' % pp.peek(S['score'] + i) for i in (2, 1, 0)),
              'lives', run.var(pp, 'lives'), 'phase', run.var(pp, 'phase'), 'sector', run.var(pp, 'sector'),
              'wave', run.var(pp, 'wave'))
    if prof:
        p = pp.prof()
        names = sorted((v, k) for k, v in S.items() if 0x8000 <= v < 0xC800 and '.' not in k)
        out = []
        for i, (ad, n) in enumerate(names):
            b = names[i + 1][0] if i + 1 < len(names) else 0xC800
            out.append((int(p[ad:b].sum()), n))
        out.sort(reverse=True)
        for t, n in out[:16]:
            print('  %-16s %7.0f T a frame' % (n, t / len(a)))
    return pp, a


if __name__ == '__main__':
    secs = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    sec = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    measure(secs, sec, prof=True, shots_dir='/tmp/claude-0/sd')
