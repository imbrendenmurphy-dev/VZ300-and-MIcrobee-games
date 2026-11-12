"""Play SPINDRIFT with a scripted pilot in the Premium Plus model, log the
run (phases, sectors, score, lives) and save a picture at each change.

    python3 tools/playtest.py OUTDIR [seconds] [--god] [--sector N]

The pilot reads the enemy table, turns toward the enemy nearest the
orbit and fires; it dodges bullets that are close. --god keeps the ship
from harm so the whole campaign can be seen.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import run

PHASES = ['INTRO', 'PLAY', 'CLEAR', 'WARN', 'BOSS', 'BOSSEND', 'BONUSI', 'BONUS', 'BONUSR', 'OVER', 'DONE']
ENEMY = 0xD500
BULLETS = 0xD730


def sdiff(a, b):
    d = (a - b) & 255
    return d - 256 if d > 127 else d


def pilot(pp, f):
    S = pp.S
    pa = pp.peek(S['p_a'])
    keys = ['SPACE'] if (f % 4) < 2 else []
    # dodge
    for i in range(9):
        b = BULLETS + i * 12
        if pp.peek(b) & 1 and pp.peek(b + 4) > 150:
            d = sdiff(pa, pp.peek(b + 1))
            if abs(d) < 12:
                return keys + (['X'] if d >= 0 else ['Z'])
    best, ang = -1, None
    for i in range(16):
        e = ENEMY + i * 32
        if pp.peek(e):
            r = pp.peek(e + 5)
            if r > best:
                best, ang = r, pp.peek(e + 3)
    if pp.peek(S['bossmode']):
        ang = (f * 3) & 255
    if ang is None:
        return keys
    d = sdiff(ang, pa)
    if abs(d) > 4:
        keys.append('X' if d > 0 else 'Z')
    return keys


def playtest(out, seconds=300, god=False, sector=None, verbose=True):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    pp = run.start_game()
    S = pp.S
    if sector is not None:
        pp.poke(S['sector'], sector)
    last = None
    log = []
    for f in range(seconds * 50):
        if f % 2 == 0:
            pp.keys = pilot(pp, f)
        if god:
            pp.poke(S['p_inv'], 40)
        pp.run_frames(1)
        state = (run.var(pp, 'phase'), run.var(pp, 'sector'), run.var(pp, 'wave'), run.var(pp, 'lives'))
        if state != last:
            sc = ''.join('%02X' % pp.peek(S['score'] + i) for i in (2, 1, 0)) + '0'
            line = '%6.1fs %-8s sector %d wave %d lives %d score %s lap %d' % (
                f / 50, PHASES[state[0]] if state[0] < len(PHASES) else state[0], state[1] + 1, state[2],
                state[3], sc, run.var(pp, 'lap'))
            log.append(line)
            if verbose:
                print(line, flush=True)
            pp.run_frames(12)
            run.shot(pp, out / ('%04d_%s_s%d.png' % (f // 50, PHASES[state[0]] if state[0] < len(PHASES) else 'X', state[1] + 1)))
            last = state
        if state[0] == 10 or (state[0] == 9 and not god):
            break
    return pp, log


if __name__ == '__main__':
    args = sys.argv[1:]
    god = '--god' in args
    sec = None
    if '--sector' in args:
        sec = int(args[args.index('--sector') + 1]) - 1
    nums = [a for a in args if a.isdigit()]
    playtest(args[0], int(nums[0]) if nums else 300, god, sec)
