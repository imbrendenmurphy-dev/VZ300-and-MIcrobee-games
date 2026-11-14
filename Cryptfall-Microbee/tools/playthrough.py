"""The whole campaign in one sitting: cold boot, start at crypt 1 and clear
every crypt in turn with its solution, each one loaded off the disk when it
is needed, through to the ending.  Also reports the frame rate held.

    python3 tools/playthrough.py
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import caves as C
from bot import Game, Dead, peek, peekw, shot
from solve import solution
from mechtest import screen_text
from emu import BUILD


def main(shots=False):
    allc = C.load_all()
    g = Game(0)
    pp = g.pp
    ok = True
    worst = 0
    for i, (path, c) in enumerate(allc):
        if peek(pp, 'cave_no') != i:
            print('expected crypt %d, the game is in %d' % (i + 1, peek(pp, 'cave_no') + 1))
            ok = False
            break
        name = bytes(pp.peek(0xB000 + 128 + k) for k in range(24)).decode().strip()
        f0, t0 = peekw(pp, 'framecount'), pp.frames
        try:
            g.run(solution(path))
        except (Dead, RuntimeError) as e:
            print('%2d %-24s FAILED: %s' % (i + 1, name, e))
            ok = False
            break
        fr = (peekw(pp, 'framecount') - f0) & 0xFFFF
        fpf = (pp.frames - t0) / max(1, fr)
        worst = max(worst, fpf)
        if shots:
            shot(pp, BUILD / ('play%02d.png' % (i + 1)))
        print('%2d %-24s cleared  score %6d  lives %d  %.2f fields a frame' % (i + 1, name, g.score(), g.v('lives'), fpf))
        g.finish()
        if i + 1 < len(allc):
            g.wait_start()
    if ok:
        for k in range(600):
            pp.run_frames(1)
            if 'YOU HAVE ESCAPED' in screen_text(pp):
                break
        won = 'YOU HAVE ESCAPED' in screen_text(pp)
        print('the ending: %s' % ('reached' if won else 'NOT reached'))
        ok = won
    print('slowest crypt: %.2f fields a frame (3.00 is full speed)' % worst)
    print('campaign cleared from start to finish' if ok else 'FAILED')
    return ok


if __name__ == '__main__':
    sys.exit(0 if main('--pics' in sys.argv) else 1)
