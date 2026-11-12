"""Profile a fully powered pilot in stage 1 (worst normal case)."""
import sys, bisect
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from run import boot, peek, peekw, to_game
from autoplay import step
pilot = int(sys.argv[1]) if len(sys.argv) > 1 else 0
dbl = int(sys.argv[2]) if len(sys.argv) > 2 else 1
pp = boot(); to_game(pp, pilot=pilot); S = pp.S
for t in range(60): step(pp)
for k, v in (('pmissile', 1), ('poptions', 2), ('pshield', 3), ('pspeed', 2), ('pdouble', dbl), ('plaser', 1 - dbl)):
    pp.poke(S[k], v)
for t in range(40): step(pp)
pp.profile(True)
a = peekw(pp, 'framecount')
for t in range(100): step(pp)
b = peekw(pp, 'framecount')
prof = pp.prof(); pp.profile(False)
items = sorted((v, n) for n, v in S.items() if 0x8000 <= v < 0xD000 and '.' not in n)
ks = [v for v, n in items]
tot = {}
for a_ in np.nonzero(prof)[0]:
    i = bisect.bisect_right(ks, a_) - 1
    n = items[i][1] if i >= 0 else '?'
    tot[n] = tot.get(n, 0) + int(prof[a_])
s = sum(tot.values())
print('%.1f fps' % ((b - a) * 50 / 400))
for n, v in sorted(tot.items(), key=lambda x: -x[1])[:22]:
    print('  %-16s %5.1f%%' % (n, 100 * v / s))
