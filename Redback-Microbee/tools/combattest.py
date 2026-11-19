"""Phase 2 combat check in the model: a scripted flight with fire, turns and
climbs. Logs score / ships / objects, checks the program never leaves its
code, counts kills, deaths and GAME OVER, and saves screenshots.

    python combattest.py [outdir] [frames]
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import rbtest
import sprtest as Q
from mbee import FRAME_T

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else None
NFR = int(sys.argv[2]) if len(sys.argv) > 2 else 1500


def keys_at(f):
    """fly right firing, weave up and down, turn round now and then"""
    k = ['SPACE']
    ph = (f // 300) % 2
    k.append('RIGHT' if ph == 0 else 'LEFT')
    if (f // 45) % 4 == 1:
        k.append('UP')
    elif (f // 45) % 4 == 3:
        k.append('DOWN')
    return k


def bcd(pp, a):
    v = 0
    for i in (2, 1, 0):
        b = pp.peek(a + i)
        v = v * 100 + (b >> 4) * 10 + (b & 15)
    return v


def main():
    pp = rbtest.boot()
    while not pp.start_addr():
        pp.run_frames(1)
    pp.run_frames(3)
    S = pp.S
    code_end = S['code_end']
    last_state = 0
    deaths = overs = 0
    max_obj = 0
    prev_score = 0
    kills = 0
    periods = []
    t_prev = pp.tick
    shots_at = [60, 200, 420, 700, 1000, 1400]
    tears = 0
    pp.vw_tear()
    for f in range(NFR):
        pp.keys = set(keys_at(f))
        pc = Q.go(pp, [S['logic']])
        if pc is None:
            print('frame %d: logic not reached (pc %04X) - CRASH?' % (f, pp.cpu.pc))
            return 1
        if pp.vw_tear():
            tears += 1
        periods.append((pp.tick - t_prev) / FRAME_T)
        t_prev = pp.tick
        st = pp.peek(S['pstate'])
        if st == 1 and last_state == 0:
            deaths += 1
            if deaths == 1:
                shots_at.append(f + 6)          # the ship exploding
        if st == 2 and last_state != 2:
            overs += 1
            if overs == 1:
                shots_at.append(f + 10)         # GAME OVER
        if 'boom' not in globals() and any(pp.peek(S['enemies'] + 16 * i) == 2 for i in range(4)):
            globals()['boom'] = f
            shots_at.append(f + 3)              # an enemy exploding
        last_state = st
        n = sum(1 for i in range(8) if pp.peek(S['objs'] + 16 * i))
        max_obj = max(max_obj, n)
        sc = bcd(pp, S['score'])
        if sc != prev_score:
            kills += 1
            prev_score = sc
        if OUT and f in shots_at:
            OUT.mkdir(parents=True, exist_ok=True)
            rbtest.shot(pp, OUT / ('combat_%04d.png' % f))
    import numpy as np
    p = np.array(periods[1:])
    print('frames %d  score %d  kills %d  deaths %d  game overs %d  ships now %d  max objects %d' %
          (NFR, prev_score, kills, deaths, overs, pp.peek(S['lives']), max_obj))
    print('frame period mean %.3f max %.2f  dropped (>1.5) %d  frames with writes behind the beam (tear) %d' %
          (p.mean(), p.max(), int((p > 1.5).sum()), tears))
    ok = 0x8000 <= pp.cpu.pc < code_end
    print('pc %04X %s' % (pp.cpu.pc, 'in code' if ok else 'OUTSIDE THE PROGRAM'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
