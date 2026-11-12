def load(path):
    syms = {}
    for l in open(path):
        p = l.replace(':', ' ').split()
        if len(p) >= 3 and p[1].lower() == 'equ':
            try:
                syms[p[0]] = int(p[2], 16)
            except ValueError:
                pass
    return syms


def namer(syms, lo=0x8000, hi=0xC000):
    code = sorted((v, k) for k, v in syms.items() if lo <= v < hi)

    def near(a):
        best = None
        for v, k in code:
            if v <= a:
                best = '%s+%d' % (k, a - v)
        return best
    return near
