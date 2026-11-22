"""Screenshot of STARHIVE in the emulator, as the beam draws it.

    python tools/shot.py LEVEL OUT.png [SECONDS] [--mono]

Starts the game, jumps to LEVEL, plays it for SECONDS (weaving, firing,
invulnerable) and saves two frames side by side, doubled."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import starhive_run as sh


def main():
    lv, out = int(sys.argv[1]), sys.argv[2]
    secs = float(sys.argv[3]) if len(sys.argv) > 3 and not sys.argv[3].startswith('-') else 8
    pp = sh.boot()
    S = pp.S
    pp.run_frames(250)
    if '--mono' in sys.argv:
        pp.keys = {'M'}
        pp.run_frames(10)
        pp.keys = set()
        pp.run_frames(10)
    pp.keys = {'SPACE'}
    pp.run_frames(6)
    if lv > 1:                      # through the level-clear screen to LEVEL
        pp.poke(S['level'], lv - 1)
        pp.poke(S['state'], 3)
        pp.poke(S['stimer'], 1)
        pp.run_frames(560)
    for t in range(int(secs * 5)):
        pp.keys = {'SPACE', ['LEFT', 'RIGHT'][(t // 10) % 2]}
        pp.poke(S['inv'], 100)
        pp.run_frames(10)
    sh.shot(pp, out, 2)


if __name__ == '__main__':
    main()
