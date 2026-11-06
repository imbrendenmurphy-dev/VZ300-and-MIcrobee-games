#!/usr/bin/env python3
"""prof.py prof.bin sym [n] - cycles per routine from vzemu -prof output"""
import struct, sys, bisect
p = struct.unpack('65536Q', open(sys.argv[1], 'rb').read())
sym = sorted((int(l.split()[0], 16), l.split()[1]) for l in open(sys.argv[2])
             if int(l.split()[0], 16) >= 0x8000 and l.split()[1][0] != '.')
addrs = [a for a, _ in sym]
tot = {}
for a, c in enumerate(p):
    if c:
        i = bisect.bisect_right(addrs, a) - 1
        n = sym[i][1].split('.')[0] if i >= 0 else '?'
        tot[n] = tot.get(n, 0) + c
T = sum(tot.values())
for n, c in sorted(tot.items(), key=lambda x: -x[1])[:int(sys.argv[3]) if len(sys.argv) > 3 else 20]:
    print("%-20s %5.1f%%" % (n, 100 * c / T))
