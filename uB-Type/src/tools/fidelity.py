"""Gameplay fidelity: run the original VZ-TYPE (VZ300 model) and uB-TYPE
(Premium Plus model) frame by frame on the same input script and compare
the game state after every game frame: player, pod, satellites, score,
lives, scroll, every entity, shot and bullet.

The RNG seed is set to the same value at the first game frame in both."""
import sys
import random
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run
import vzmeasure
from vzm import VZ

VZFILE = '/home/claude/work/orig/VZTYPE.VZ'
VZSYM = '/home/claude/work/vzbuild/sym.txt'
STATE = [('px', 1), ('py', 1), ('pstate', 1), ('pinv', 1), ('charge', 1), ('podst', 1), ('podx', 1), ('pody', 1),
         ('podw', 1), ('sats', 1), ('score', 3), ('lives', 1), ('scrollx', 2), ('scol', 2), ('lvlnum', 1),
         ('ENTS', 20 * 16), ('SHOTS', 80), ('BULS', 96), ('rseed', 2), ('frame', 1)]
MB_KEYS = {'Q': 'Q', 'A': 'A', 'O': 'O', 'P': 'P', 'SPACE': 'SPACE', 'M': 'M'}


def snapshot(peek, S):
    return {k: bytes(peek(S[k] + i) for i in range(n)) for k, n in STATE}


def script(seed, n):
    R = random.Random(seed)
    keys = []
    cur = set()
    for f in range(n):
        if f % 4 == 0:
            cur = set()
            v = R.random()
            if v < 0.3: cur.add('Q')
            elif v < 0.6: cur.add('A')
            h = R.random()
            if h < 0.25: cur.add('O')
            elif h < 0.5: cur.add('P')
            if R.random() < 0.7: cur.add('SPACE')
            if R.random() < 0.05: cur.add('M')
        keys.append(set(cur))
    return keys


def compare(nframes=600, seed=1, stage=0, verbose=True, decouple=True, trainer=True):
    keys = script(seed, nframes)
    # ---- VZ
    VS = vzmeasure.vzsyms(VZSYM)
    v = VZ(VZFILE)
    v.run_fields(150)
    v.keys = {'SPACE'}
    v.run_fields(4)
    v.keys = set()
    v.run_until(VS['mainloop'], 4000)
    # ---- Microbee
    pp = run.boot(stage)
    S = pp.S
    pp.poke(S['thin'], 0)          # compare the unthinned game
    pp.run_until(S['mainloop'], 4000)
    import vzm
    print('start frame VZ', v.peek(VS['frame']), 'MB', pp.peek(S['frame']), 'scrollx', v.peek(VS['scrollx']), pp.peek(S['scrollx']))
    for (poke, m) in ((lambda a, x: v.mem.__setitem__(a, x), VS), (lambda a, x: pp.poke(a, x), S)):
        poke(m['rseed'], 0x34)
        poke(m['rseed'] + 1, 0x12)
        poke(m['trainer'], 1 if trainer else 0)
    if decouple:
        # test only: the effect-noise generator gets its own seed in both
        # builds, so the game's random numbers no longer depend on timing
        def patch(peek, poke, a0, a1, rs, dummy):
            n = 0
            for a in range(a0, a1):
                if peek(a) in (0x2A, 0x22) and peek(a + 1) == rs & 255 and peek(a + 2) == rs >> 8:
                    poke(a + 1, dummy & 255); poke(a + 2, dummy >> 8); n += 1
            return n
        n1 = patch(v.peek, lambda a, x: v.mem.__setitem__(a, x), VS['sfx_tog'], VS['sfx_frame'], VS['rseed'], 0x7FF0)
        n2 = patch(pp.peek, pp.poke, S['sfx_tog'], S['sfx_frame'], S['rseed'], 0xEF00)
        assert n1 == 2 and n2 == 2, (n1, n2)
    diffs = []
    for f in range(nframes):
        v.keys = keys[f]
        pp.keys = keys[f]
        # one game frame each: from mainloop to mainloop
        v.run_fields(0) if False else None
        import vzm
        vzm.L.vz_set_bp(v.h, VS['mainloop'], 1)
        vzm.L.vz_run(v.h, v.tick + 1)       # step off the breakpoint
        vzm.L.vz_run(v.h, v.tick + 10 * vzm.FIELD)
        vzm.L.vz_set_bp(v.h, VS['mainloop'], 0)
        pp.run_ticks(1)
        pp.run_until(S['mainloop'], 200)
        # re-align on the game's frame counter (a stop can land mid-restart)
        for _ in range(3):
            fv, fm = v.peek(VS['frame']), pp.peek(S['frame'])
            if fv == fm:
                break
            if (fv - fm) & 255 > 128:
                vzm.L.vz_set_bp(v.h, VS['mainloop'], 1)
                vzm.L.vz_run(v.h, v.tick + 1)
                vzm.L.vz_run(v.h, v.tick + 10 * vzm.FIELD)
                vzm.L.vz_set_bp(v.h, VS['mainloop'], 0)
            else:
                pp.run_ticks(1)
                pp.run_until(S['mainloop'], 200)
        a = snapshot(v.peek, VS)
        b = snapshot(pp.peek, S)
        d = [k for k in a if a[k] != b[k]]
        if d:
            diffs.append((f, d))
            if verbose and len(diffs) <= 5:
                print('frame', f, 'differs in', d)
                for k in d[:3]:
                    print('  VZ ', a[k].hex()[:96])
                    print('  MB ', b[k].hex()[:96])
    return diffs, v, pp


if __name__ == '__main__':
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    diffs, v, pp = compare(n)
    print('frames compared: %d, frames with any difference: %d' % (n, len(diffs)))
