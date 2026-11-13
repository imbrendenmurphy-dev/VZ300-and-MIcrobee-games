#!/usr/bin/env python3
"""hist.py sym hist.bin [frames] - T-states per routine (nearest preceding label)"""
import sys, struct, bisect, collections
syms = []
for l in open(sys.argv[1]):
    a, n = l.split()
    syms.append((int(a, 16), n))
syms.sort()
addrs = [a for a, n in syms]
h = struct.unpack('<65536Q', open(sys.argv[2], 'rb').read())
frames = int(sys.argv[3]) if len(sys.argv) > 3 else 1
tot = collections.Counter()
for pc, t in enumerate(h):
    if not t: continue
    i = bisect.bisect_right(addrs, pc) - 1
    name = syms[i][1] if i >= 0 else '?'
    # fold local labels into their parent
    tot[name.split('.')[0] if not name.startswith('.') else name] += t
allt = sum(tot.values())
print('total T %d  (%d per frame)' % (allt, allt // frames))
for n, t in tot.most_common(30):
    print('%-20s %10d  %5.1f%%  %8d/frame' % (n, t, 100.0 * t / allt, t // frames))
