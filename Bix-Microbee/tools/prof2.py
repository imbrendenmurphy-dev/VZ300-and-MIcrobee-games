"""Where the T-states go, by routine (upper engine, map block, game block):
python3 tools/prof2.py [stage] [frames]"""
import sys, re
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import run, tour
import numpy as np

def syms(path):
    out = []
    for line in Path(path).read_text().splitlines():
        m = re.match(r'([A-Za-z_][\w]*): equ 0x([0-9A-Fa-f]+)', line)
        if m and '.' not in m.group(1):
            out.append((int(m.group(2), 16), m.group(1)))
    return sorted(out)

def attribute(prof, table, lo, hi):
    res = {}
    names = [(a, n) for a, n in table if lo <= a < hi]
    for pc in np.nonzero(prof)[0]:
        if not (lo <= pc < hi): continue
        best = None
        for a, n in names:
            if a <= pc: best = n
            else: break
        res[best] = res.get(best, 0) + int(prof[pc])
    return res

if __name__ == '__main__':
    stage = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    frames = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    b = tour.Bot(stage=stage)
    b.go(('RIGHT',), 30)
    pp = b.pp
    pp.prof_blk(5)
    pp.profile(True)
    for i in range(frames // 46):
        b.go(('RIGHT', 'SPACE'), 16); b.go(('RIGHT',), 30)
    pp.profile(False)
    P = pp.prof(); M = pp.prof_map()
    S = run.ROOT / 'build'
    up = attribute(P, syms(S / 'main.sym'), 0x8000, 0x10000)
    gm = attribute(P, syms(S / 'main.sym'), 0x0100, 0x8000)
    mp = attribute(M, syms(S / 'map.sym'), 0, 0x8000)
    n = b.loops
    print('%d frames in %d fields: %.1f fps, %d slow' % (b.loops, b.fields, 50.0 * b.loops / b.fields, b.slow))
    for title, d in (('upper', up), ('map block', mp), ('lower (game/sprite)', gm)):
        tot = sum(d.values())
        print('%s: %d T a frame' % (title, tot / max(1, n)))
        for k, v in sorted(d.items(), key=lambda kv: -kv[1])[:14]:
            print('   %-18s %7d' % (k, v / max(1, n)))
