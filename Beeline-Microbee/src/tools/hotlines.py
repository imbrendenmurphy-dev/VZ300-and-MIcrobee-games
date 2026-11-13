#!/usr/bin/env python3
"""hotlines.py sym lst hist.bin frames routine [n] - hottest source lines of a routine"""
import sys, struct
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(sys.argv[1])}
lst = {}
for l in open(sys.argv[2]):
    if len(l) > 4 and l[:4].strip() and l[4:6] == '  ':
        try: lst[int(l[:4], 16)] = l.rstrip()
        except ValueError: pass
h = struct.unpack('<65536Q', open(sys.argv[3], 'rb').read())
N = int(sys.argv[4]); r = sys.argv[5]; n = int(sys.argv[6]) if len(sys.argv) > 6 else 15
a0 = sym[r]
a1 = min(v for k, v in sym.items() if v > a0 and '.' not in k)
print('== %s  %d T/frame' % (r, sum(h[a0:a1]) // N))
for t, a in sorted([(h[a], a) for a in range(a0, a1) if h[a]], reverse=True)[:n]:
    print('%7d  %s' % (t // N, lst.get(a, '?')[:76]))
