"""aggregate an emulator profile by routine: prof.py profile.txt symfile"""
import sys, bisect
sym = sorted((int(l.split()[0], 16), l.split()[1]) for l in open(sys.argv[2]) if '.' not in l.split()[1])
addrs = [a for a, n in sym]
tot = {}; T = 0
for l in open(sys.argv[1]):
    a, c = l.split(); a = int(a, 16); c = int(c); T += c
    i = bisect.bisect_right(addrs, a) - 1
    n = sym[i][1] if i >= 0 and a >= 0x8000 and a < 0xB000 else ('ROM/DOS' if a < 0x7000 else '$%02Xxx' % (a >> 8))
    tot[n] = tot.get(n, 0) + c
for n, c in sorted(tot.items(), key=lambda x: -x[1])[:25]:
    print('%-16s %6.2f%%  %10d' % (n, 100 * c / T, c))
