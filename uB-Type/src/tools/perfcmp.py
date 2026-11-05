"""Original VZ-TYPE (VZ300 model) against uB-TYPE (Premium Plus model):
the same scripted input on every stage, from the start of the stage and in
the boss fight (started 70 columns before the end of the level), trainer
mode on so a run never ends early. Frame rate, share of frames at the full
25 fps, and busy time per game frame.

Frames that restart a life (a full redraw) are left out of the busy
figures on both machines."""
import sys
import statistics as st
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
import measure
import vzmeasure
from vzm import VZ, FIELD
from mbee import FRAME_T

VZFILE = '/home/claude/work/orig/VZTYPE.VZ'
VZSYM = '/home/claude/work/vzbuild/sym.txt'
NAMES = ['OUTER HULL', 'THE HIVE', 'ROCK BELT', 'CRYSTAL VEIN', 'DREADNOUGHT', 'GUT CAVERNS', 'DEEP FIELD', 'THE CORE']
NF = 1000           # 50 Hz fields measured


def keys_at(f):
    k = set()
    if (f // 6) % 2:
        k.add('SPACE')
    k.add(['Q', 'A', 'A', 'Q'][(f // 40) % 4])
    h = (f // 80) % 3
    if h == 1:
        k.add('P')
    elif h == 2:
        k.add('O')
    return k


def summarise(busy, per_fields):
    b = [x for x in busy if x < 400000]
    return dict(fps=50 / st.mean(per_fields), full=100 * sum(1 for p in per_fields if p < 2.05) / len(per_fields),
                mean=st.mean(b), mx=max(b))


def poke_start(poke, peekw, S, boss):
    if boss:
        cols = peekw(S['lvlcols'])
        for name in ('dbgcol', 'checkpt'):
            poke(S[name], (cols - 70) & 255)
            poke(S[name] + 1, (cols - 70) >> 8)


def decouple(peek, poke, S, dummy):
    """test only: the effect-noise generator gets a seed of its own, so the
    game's random numbers no longer depend on timing (as in fidelity.py)"""
    n = 0
    for a in range(S['sfx_tog'], S['sfx_frame']):
        if peek(a) in (0x2A, 0x22) and peek(a + 1) == S['rseed'] & 255 and peek(a + 2) == S['rseed'] >> 8:
            poke(a + 1, dummy & 255)
            poke(a + 2, dummy >> 8)
            n += 1
    assert n == 2, n


def mb(stage, boss):
    pp = run.boot(stage)
    S = pp.S
    decouple(pp.peek, pp.poke, S, 0xEF00)
    pp.run_until(S['prof_reset'], 400)
    poke_start(pp.poke, pp.peekw, S, boss)
    pp.run_until(S['mainloop'], 400)
    pp.poke(S['trainer'], 1)
    pp.poke(S['rseed'], 0x34)
    pp.poke(S['rseed'] + 1, 0x12)
    pp.run_frames(20)
    busy, per, _ = measure.frame_stats(pp, NF, lambda p, f: setattr(p, 'keys', keys_at(f)))
    return summarise(busy, [p / FRAME_T for p in per])


def vz(stage, boss):
    S = vzmeasure.vzsyms(VZSYM)
    v = VZ(VZFILE)
    decouple(v.peek, lambda a, x: v.mem.__setitem__(a, x), S, 0x7FF0)
    v.run_fields(150)
    v.keys = {'SPACE'}
    v.run_fields(4)
    v.keys = set()
    v.run_until(S['level_start'], 2000)
    v.mem[S['lvlnum']] = stage
    v.run_until(S['prof_reset'], 2000)
    poke_start(lambda a, x: v.mem.__setitem__(a, x), lambda a: v.peek(a) | v.peek(a + 1) << 8, S, boss)
    v.run_until(S['mainloop'], 2000)
    v.mem[S['trainer']] = 1
    v.mem[S['rseed']] = 0x34
    v.mem[S['rseed'] + 1] = 0x12
    v.run_fields(20)
    v.watch(S['blit'])
    v.watch(S['waitframe'])
    v.events()
    for f in range(NF):
        v.keys = keys_at(f)
        v.run_fields(1)
    ev = v.events()
    blits = [t for t, p in ev if p == S['blit']]
    waits = [t for t, p in ev if p == S['waitframe']]
    busy = []
    for b in blits:
        w = [x for x in waits if x > b]
        if w:
            busy.append(w[0] - b)
    per = [(b - a) / FIELD for a, b in zip(blits, blits[1:])]
    return summarise(busy, per)


if __name__ == '__main__':
    stages = [int(a) for a in sys.argv[1:]] or range(8)
    print('%-16s %-5s | %-24s | %-24s' % ('', '', 'VZ300 original', 'Microbee Premium Plus'))
    print('%-16s %-5s | %5s %6s %11s | %5s %6s %11s' % ('stage', 'part', 'fps', '25fps', 'busy mean', 'fps', '25fps', 'busy mean'))
    for s in stages:
        for boss in (False, True):
            a = vz(s, boss)
            b = mb(s, boss)
            print('%d %-14s %-5s | %5.1f %5.0f%% %11d | %5.1f %5.0f%% %11d' % (
                s + 1, NAMES[s], 'boss' if boss else 'start', a['fps'], a['full'], a['mean'], b['fps'], b['full'], b['mean']), flush=True)
