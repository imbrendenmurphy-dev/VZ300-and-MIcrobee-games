import bisect
def report(pp, p, lo=0x8000, hi=0xD800, top=25):
    S = pp.S
    labs = sorted((v, k) for k, v in S.items() if lo <= v < hi)
    addrs = [l[0] for l in labs]
    acc = {}
    for a in range(lo, hi):
        if p[a]:
            i = bisect.bisect_right(addrs, a) - 1
            n = labs[i][1] if i >= 0 else '?'
            acc[n] = acc.get(n, 0) + int(p[a])
    tot = sum(acc.values())
    for n, v in sorted(acc.items(), key=lambda x: -x[1])[:top]:
        print('%-28s %6.1f%%  %8d' % (n, 100 * v / tot, v))
