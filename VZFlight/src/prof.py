"""profile one flight frame: inclusive T-states per routine.  usage: prof.py loc mis [x z y hdg]"""
import sys
from collections import defaultdict
from h2 import Sim

def enter(loc, mis):
    s = Sim(); S, vz = s.S, s.vz
    s.fields(40); s.tap('SPACE'); s.fields(30)
    vz.m[S['locidx']] = loc; vz.m[S['misidx']] = mis
    s.tap('A'); s.tap('Q'); s.fields(10); s.tap('SPACE'); s.fields(30); s.tap('SPACE', 6, 2)
    vz.run_until(S['flyloop'], 50_000_000)
    return s

def pose(s, x, z, y, hdg, spd=45, pitch=0):
    S, vz = s.S, s.vz
    def p32(n, v):
        a = S[n]; vz.m[a:a + 4] = int(v * 65536).to_bytes(4, 'little', signed=True)
    p32('px', x); p32('pz', z); p32('py', y); p32('spd', spd)
    a = S['yaw3']; v = int(hdg * 65536 / 360) & 0xFFFF
    vz.m[a] = 0; vz.m[a + 1] = v & 255; vz.m[a + 2] = v >> 8
    vz.m[S['ongnd']] = 0; vz.m[S['thr']] = 180

NAMES = ['readkeys', 'physics', 'setview', 'buildmat', 'drawbg', 'drawgrid', 'drawobjs', 'drawgoal', 'overlay',
         'drawmsg', 'flip', 'drawpanel', 'drawobj', 'vfin', 'drawseg', 'bisect', 'line2d', 'projpm', 'ocode', 'tcode',
         'pdiv', 'xform', 'mul16m', 'umul8', 'poll', 'fmul', 'udiv32', 'umul16', 'gridx', 'gridz', 'muldiv', 'interp',
         'calctrig', 'contact', 'obstac', 'prnum', 'ptext', 'pchar', 'ochar', 'vcoords', 'addcol0', 'addcol1', 'addcol2']

def profile(s, frames=2):
    S, vz = s.S, s.vz
    names = [n for n in NAMES if n in S]
    ent = {S[n]: n for n in names}
    for _ in range(frames - 1):
        vz.step(); vz.run_until(S['flyloop'], 60_000_000)
    tot = defaultdict(int); cnt = defaultdict(int); stack = []
    t0 = vz.t
    vz.step()
    while vz.pc != S['flyloop']:
        pc = vz.pc
        if pc in ent:
            stack.append((ent[pc], vz.t, vz.m[vz.sp] | vz.m[vz.sp + 1] << 8, vz.sp))
        vz.step()
        while stack and vz.pc == stack[-1][2] and vz.sp == stack[-1][3] + 2:
            n, t1, _, _ = stack.pop(); tot[n] += vz.t - t1; cnt[n] += 1
    return vz.t - t0, tot, cnt

if __name__ == '__main__':
    a = [float(v) for v in sys.argv[1:]]
    s = enter(int(a[0]), int(a[1]))
    if len(a) > 2:
        pose(s, *a[2:])
    T, tot, cnt = profile(s)
    print('frame %d T = %.1f fields' % (T, T / 70630))
    for n in sorted(tot, key=lambda k: -tot[k]):
        print('%-9s %4d calls %8d T %5.1f%%  avg %6d' % (n, cnt[n], tot[n], 100 * tot[n] / T, tot[n] // cnt[n]))
    s.shot(sys.argv[0].replace('.py', '') + '_view.png')
