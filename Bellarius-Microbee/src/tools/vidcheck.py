"""Video RAM discipline check (raster model): every access to video RAM
(screen, attributes, colours, PCG) while the picture is being displayed,
and every video read, during play. The real Premium Plus in the
40-column mode garbles the picture when the CPU touches video RAM while
a line is drawn (BPM's photos, Nov 2026), so the game must do all of it
in the vertical blanking.   usage: vidcheck.py [stage] [steps]"""
import os, sys, bisect
os.environ['RASTER'] = '1'
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game, BUILD, symbols
from autoplay import step

st = int(sys.argv[1]) if len(sys.argv) > 1 else 1
n = int(sys.argv[2]) if len(sys.argv) > 2 else 300
S = symbols()
ovl = symbols(BUILD / ('stage%d.sym' % st)) if (BUILD / ('stage%d.sym' % st)).exists() else {}
names = sorted([(v, k) for k, v in S.items() if 0x8000 <= v < 0xC000] + [(v, 'ovl:' + k) for k, v in ovl.items() if 0xC000 <= v < 0xD000])
addrs = [a for a, _ in names]


def where(pc):
    i = bisect.bisect_right(addrs, pc) - 1
    return names[i][1] if i >= 0 else '?'


pp = boot(); to_game(pp)
S = pp.S
if st > 1:
    while peek(pp, 'stage') != st:
        pp.run_frames(20)
        if peek(pp, 'gstate') == 0 and peek(pp, 'stage') < st:
            pp.poke(S['stage'], st - 1); pp.poke(S['gstate'], S['GS_CLEAR'])
for i in range(60): step(pp)
pp.vdisp(); pp.vreads()
f = peekw(pp, 'framecount')
for i in range(n): step(pp); pp.poke(S['lives'], 3)
frames = peekw(pp, 'framecount') - f
d = pp.vdisp()
by = {}
for pc, c in d.items():
    k = where(pc).split('.')[0]
    by[k] = by.get(k, 0) + c
print('stage %d, %d frames: %d display-time video accesses, %d video reads'
      % (st, frames, sum(d.values()), pp.vreads()))
for k, c in sorted(by.items(), key=lambda x: -x[1])[:25]:
    print('  %-24s %8d' % (k, c))
