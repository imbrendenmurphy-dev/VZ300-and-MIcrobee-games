"""Clear every crypt with the real game in the model (cold boot, real BDOS
loading the cave off the disk image) and report how long each takes.

    python3 tools/solve.py            all crypts
    python3 tools/solve.py 5 7        just crypts 5 and 7
A crypt's solution is the line  ; solve: ...  in its text file (see
tools/bot.py for the moves); with none, the bot plays it by itself.
"""
import sys, os, re, time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import caves as C
from bot import Game, Dead, shot


def solution(path):
    m = re.findall(r'^;\s*solve:\s*(.*)$', open(path).read(), re.M)
    return ' '.join(m) if m else '!X'


def solve(i, path, c, verbose=True, pic=None):
    g = Game(i)
    t0 = g.time()
    try:
        g.run(solution(path))
        ok = g.done()
        why = '' if ok else 'not at the gate: %s, %d of %d gems' % (g.pos(), g.v('gems'), g.v('quota'))
    except (Dead, RuntimeError) as e:
        ok, why = False, str(e)
    used = t0 - g.time()
    if pic:
        shot(g.pp, pic)
    nxt = g.finish() if ok else None
    if verbose:
        print('%2d %-24s %s  %3d steps, %3d of %3d s used%s%s' % (
            i + 1, c['name'], 'CLEARED' if ok else 'FAILED ', len(g.log), used, t0,
            '' if not ok else '  score %d' % g.score(), '  ' + why if why else ''))
    return ok, g


if __name__ == '__main__':
    allc = C.load_all()
    want = [int(a) - 1 for a in sys.argv[1:] if a.isdigit()] or range(len(allc))
    bad = 0
    for i in want:
        p, c = allc[i]
        ok, g = solve(i, p, c, pic=('build/solve%02d.png' % (i + 1)) if '--pics' in sys.argv else None)
        bad += not ok
    print('all cleared' if not bad else '%d FAILED' % bad)
    sys.exit(1 if bad else 0)
