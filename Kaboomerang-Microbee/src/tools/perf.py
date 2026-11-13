"""Frame rate and profile in a busy scene."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from run import boot, peek
pp = boot(test=True)
pp.run_frames(200)


def fc():
    return pp.peek(pp.S['framecount']) | (pp.peek(pp.S['framecount'] + 1) << 8)


a = fc(); pp.run_frames(100); b = fc()
print('quiet: %d game frames in 100 fields (%.1f fps)' % (b - a, (b - a) / 2))
pp.profile(True)
pp.keys = ['RIGHT']; pp.run_frames(16); pp.keys = ['SPACE']; pp.run_frames(4); pp.keys = ['LEFT']; pp.run_frames(20)
pp.keys = ['X']; pp.run_frames(4); pp.keys = []
a = fc(); pp.run_frames(100); b = fc()
print('bomb, flames, boomerang: %d game frames in 100 fields (%.1f fps)' % (b - a, (b - a) / 2))
prof = pp.prof()
S = pp.S
items = sorted((v, n) for n, v in S.items() if v >= 0x8000 and '.' not in n)
tot = {}
for a_ in np.nonzero(prof)[0]:
    best = '?'
    for v, n in items:
        if v <= a_:
            best = n
        else:
            break
    tot[best] = tot.get(best, 0) + int(prof[a_])
s = sum(tot.values())
for n, v in sorted(tot.items(), key=lambda x: -x[1])[:12]:
    print('  %-16s %5.1f%%' % (n, 100 * v / s))
