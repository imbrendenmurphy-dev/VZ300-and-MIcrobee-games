"""Build STARHIVE from scratch: all generated data into build/, then the
game, its loader and the disk (build/STARHIVE.DS8).

    python tools/build_all.py          # everything (the levels take a few minutes)
    python tools/build_all.py --quick  # skip the levels if build/ has them
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
T = ROOT / 'tools'


def step(name):
    print('==', name)
    subprocess.check_call([sys.executable, str(T / name)], cwd=ROOT)


def main():
    (ROOT / 'build').mkdir(exist_ok=True)
    step('mksin.py')
    step('mkmusic.py')
    step('mkwaves.py')
    if '--quick' not in sys.argv or not (ROOT / 'build' / 'game.inc').exists():
        step('mklevels.py')
    step('mk_starhive_disk.py')


if __name__ == '__main__':
    main()
