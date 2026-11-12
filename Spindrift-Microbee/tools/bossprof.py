"""Profile a Guardian fight: where a frame's T-states go."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import jump, playtest, run
s = int(sys.argv[1]) if len(sys.argv) > 1 else 7
pp = jump.to_boss(s)
S = pp.S
for f in range(250):
    if f % 2 == 0: pp.keys = playtest.pilot(pp, f)
    pp.poke(S['p_inv'], 40); pp.run_frames(1)
print('phase', run.var(pp, 'phase'))
pp.watch(S['commit']); pp.events(); pp.profile(True)
N = 500
for f in range(N):
    if f % 2 == 0: pp.keys = playtest.pilot(pp, f)
    pp.poke(S['p_inv'], 40); pp.run_frames(1)
nf = len(pp.events())
p = pp.prof()
names = sorted((v, k) for k, v in S.items() if 0x8000 <= v < 0xC000 and '.' not in k)
out = []
for i, (a, n) in enumerate(names):
    b = names[i + 1][0] if i + 1 < len(names) else 0xC000
    out.append((int(p[a:b].sum()), n))
out.sort(reverse=True)
print('%d frames in %d fields = %.1f fps' % (nf, N, 50.0 * nf / N))
tot = sum(t for t, n in out)
for t, n in out[:22]:
    print('  %-16s %7.0f T a frame' % (n, t / nf))
