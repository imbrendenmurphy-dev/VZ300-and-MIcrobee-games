import sys, bisect, collections
syms = sorted((int(a, 16), n) for a, n in (l.split() for l in open('build/galahxy.sym')) if '.' not in n and not n.isupper())
addrs = [a for a, n in syms]
tot = collections.Counter(); T = 0
for l in open(sys.argv[1]):
    a, c = l.split(); a = int(a, 16); c = int(c); T += c
    i = bisect.bisect_right(addrs, a) - 1
    tot[syms[i][1] if i >= 0 else '?'] += c
for n, c in tot.most_common(30): print('%-20s %5.1f%%' % (n, 100 * c / T))
