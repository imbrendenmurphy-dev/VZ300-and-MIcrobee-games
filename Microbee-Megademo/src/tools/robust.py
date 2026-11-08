"""Run parts under different guesses at the real hardware: the video RAM
hold (until the blanking / N T an access) and the phase of the 6545's
blanking flag (lag in characters). Every frame must stay 313 lines."""
import sys
sys.path.insert(0, 'tools')
from run import boot_demo
from mbee import Mbee

CASES = [(1, 0, 0), (1, 0, 12), (2, 6, 0), (3, 2, 0), (3, 4, 8), (3, 8, 0)]


def check(parts, frames=100, mono=True):
    bad = 0
    for mode, t, lag in CASES:
        Mbee.vwait_mode(mode, t)
        Mbee.b5_lag(lag)
        for part in parts:
            pp = boot_demo(part=part, mono=mono)
            pp.frame_lines()
            pp.run_to_frame(frames)
            fl = pp.frame_lines()
            nb = len([x for x in fl if x != 313])
            bad += nb
            print('wait %d/%2d lag %2d part %d: %s' % (mode, t, lag, part, 'ok' if not nb else 'BAD %d %s' % (nb, sorted(set(fl))[:4])), flush=True)
    Mbee.vwait_mode(1, 4)
    Mbee.b5_lag(0)
    return bad


if __name__ == '__main__':
    parts = [int(a) for a in sys.argv[1:]] or [0, 1, 2, 3]
    print('bad frames:', check(parts))
