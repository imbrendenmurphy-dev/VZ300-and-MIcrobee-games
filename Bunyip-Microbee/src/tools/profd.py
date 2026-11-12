#!/usr/bin/env python3
"""profd.py keys f0 f1 - T-states by routine between frames f0 and f1"""
import sys, struct, subprocess, bisect, os
B = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build')
def hist(n):
    cmd = [B + '/beemu', '-up', B + '/BN.BIN', '-sym', B + '/main.sym', '-blk', '1:' + B + '/TABLES.BIN',
           '-blk', '2:' + B + '/ZONES.BIN', '-blk', '3:' + B + '/ART.BIN', '-blk', '4:' + B + '/PCG.BIN',
           '-frames', str(n), '-vwait', '4', '-hist', '-keys', sys.argv[1]]
    subprocess.run(cmd, capture_output=True)
    h = struct.unpack('<65536Q', open('hist.bin', 'rb').read()); os.remove('hist.bin')
    return h
h0, h1 = hist(int(sys.argv[2])), hist(int(sys.argv[3]))
syms = sorted((int(l.split()[0], 16), l.split()[1]) for l in open(B + '/main.sym') if int(l.split()[0], 16) >= 0x8000)
addrs = [a for a, n in syms]
tot = {}
for pc in range(0x8000, 0x10000):
    t = h1[pc] - h0[pc]
    if t:
        i = bisect.bisect_right(addrs, pc) - 1
        n = syms[i][1] if os.environ.get('FULL') else syms[i][1].split('.')[0]
        tot[n] = tot.get(n, 0) + t
T = sum(tot.values())
for n, t in sorted(tot.items(), key=lambda x: -x[1])[:int(os.environ.get('N', 25))]:
    print('%-24s %10d %5.1f%%' % (n, t, 100 * t / T))
