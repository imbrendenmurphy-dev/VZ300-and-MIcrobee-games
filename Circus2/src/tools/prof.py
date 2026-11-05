import re, struct, sys
lst = open('/home/claude/circus2/build/circus2.lst').read()
labs = []
for m in re.finditer(r'^\s*\d+\+?\s+([0-9A-F]{4})(?: [0-9A-F]{2})*\s+([A-Za-z_][A-Za-z0-9_]*):', lst, re.M):
    labs.append((int(m.group(1), 16), m.group(2)))
labs.sort()
h = struct.unpack('65536Q', open('pchist.bin', 'rb').read())
tot = sum(h)
acc = {}
import bisect
addrs = [a for a, _ in labs]
for pc, c in enumerate(h):
    if not c: continue
    i = bisect.bisect_right(addrs, pc) - 1
    n = labs[i][1] if i >= 0 else '?'
    acc[n] = acc.get(n, 0) + c
for n, c in sorted(acc.items(), key=lambda x: -x[1])[:30]:
    print(f'{n:20s} {100*c/tot:5.1f}%')
