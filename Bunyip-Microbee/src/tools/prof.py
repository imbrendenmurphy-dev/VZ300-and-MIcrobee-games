#!/usr/bin/env python3
"""prof.py keysfile frames [pokes..] - where the T-states go, by label (uses beemu -hist)"""
import sys, struct, subprocess, bisect, os
B = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build')
cmd = [B + '/beemu', B + '/RAY.COM', '-sym', B + '/ray.sym', '-frames', sys.argv[2], '-vwait', '4', '-hist', '-keys', sys.argv[1]]
for p in sys.argv[3:]: cmd += ['-poke', p]
subprocess.run(cmd, capture_output=True)
h = struct.unpack('<65536Q', open('hist.bin', 'rb').read()); os.remove('hist.bin')
syms = sorted((int(l.split()[0], 16), l.split()[1]) for l in open(B + '/ray.sym'))
addrs = [a for a, n in syms]
tot = {}
for pc, t in enumerate(h):
    if t:
        i = bisect.bisect_right(addrs, pc) - 1
        tot[syms[i][1]] = tot.get(syms[i][1], 0) + t
T = sum(tot.values())
for n, t in sorted(tot.items(), key=lambda x: -x[1])[:int(os.environ.get('N', 28))]:
    print('%-22s %9d %5.1f%%' % (n, t, 100 * t / T))
