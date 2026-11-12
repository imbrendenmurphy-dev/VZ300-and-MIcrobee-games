#!/usr/bin/env python3
"""profat.py zone,x,y,angle f0 f1 [keys] - T-states by routine between frames, debug start"""
import sys, struct, subprocess, bisect, os
B = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build')
S = {l.split()[1]: int(l.split()[0], 16) for l in open(B + '/main.sym')}
z, x, y, ang = [int(v, 0) for v in sys.argv[1].split(',')]
keys = sys.argv[4] if len(sys.argv) > 4 else 'tests/none.keys'
def hist(n):
    cmd = [B + '/beemu', '-up', B + '/BN.BIN', '-sym', B + '/main.sym', '-blk', '1:' + B + '/TABLES.BIN',
           '-blk', '2:' + B + '/ZONES.BIN', '-blk', '3:' + B + '/ART.BIN', '-blk', '4:' + B + '/PCG.BIN',
           '-frames', str(n), '-vwait', '4', '-hist', '-keys', keys]
    for k, v in (('dbg_on', 1), ('dbg_zone', z - 1), ('dbg_x', x), ('dbg_y', y), ('dbg_a', ang & 255), ('dbg_a+1', ang >> 8)):
        a = S[k] if '+' not in k else S[k[:-2]] + 1
        cmd += ['-poke', '%d,%d' % (a, v)]
    for p_ in os.environ.get('POKES', '').split():
        cmd += ['-poke', p_]
    if os.environ.get('FRZ'):
        cmd += ['-poke', '%d,1' % S['dbg_frz']]
    subprocess.run(cmd, capture_output=True)
    h = struct.unpack('<65536Q', open('hist.bin', 'rb').read()); os.remove('hist.bin')
    return h
h0, h1 = hist(int(sys.argv[2])), hist(int(sys.argv[3]))
syms = sorted((a, n) for n, a in S.items() if a >= 0x8000)
addrs = [a for a, n in syms]
tot = {}
for pc in range(0x8000, 0x10000):
    t = h1[pc] - h0[pc]
    if t:
        n = syms[bisect.bisect_right(addrs, pc) - 1][1]
        if not os.environ.get('FULL'): n = n.split('.')[0]
        tot[n] = tot.get(n, 0) + t
T = sum(tot.values())
for n, t in sorted(tot.items(), key=lambda x: -x[1])[:int(os.environ.get('N', 22))]:
    print('%-22s %9d %5.1f%%' % (n, t, 100 * t / T))
