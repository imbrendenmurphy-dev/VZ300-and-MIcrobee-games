import sys, struct
syms = sorted((int(l.split()[0], 16), l.split()[1]) for l in open(sys.argv[1]) if not '.' in l.split()[1])
data = open('prof.bin', 'rb').read(); prof = struct.unpack('<65536Q', data)
import bisect
addrs = [a for a, n in syms]
tot = {}
for pc, c in enumerate(prof):
    if c:
        i = bisect.bisect_right(addrs, pc) - 1
        name = syms[i][1] if i >= 0 else '?'
        tot[name] = tot.get(name, 0) + c
frames = int(sys.argv[2]) if len(sys.argv) > 2 else 1
for n, c in sorted(tot.items(), key=lambda x: -x[1])[:25]: print('%-20s %10d  (%.1f%%)' % (n, c, 100.0 * c / sum(tot.values())))
