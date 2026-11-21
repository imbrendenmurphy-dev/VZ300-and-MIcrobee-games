#!/usr/bin/env python3
import os, sys, bisect, collections
sys.path.insert(0, os.path.dirname(__file__))
from vztest import VZ, FIELD
root = os.path.join(os.path.dirname(__file__), '..')
build = os.path.join(root, 'build')
vz = VZ(os.path.join(build, 'vzurid.bin'), os.path.join(build, 'vzurid.sym'))
# global (non-local) symbols sorted by address
glob = sorted((a, n) for n, a in vz.syms.items() if '.' not in n and 0x8000 <= a < 0xB000)
addrs = [a for a, n in glob]
names = [n for a, n in glob]
prof = collections.Counter()
cpu = vz.cpu
orig = cpu.step
state = {'on': False}
def step():
    pc = cpu.pc
    t = orig()
    if state['on']:
        i = bisect.bisect_right(addrs, pc) - 1
        prof[names[i] if i >= 0 else '?'] += t
    return t
cpu.step = step
script = {}
def at(f, key, down=True): script.setdefault(f, []).append((key, down))
at(5, ',')
for f in range(10, 400, 6):
    at(f, '.'); at(f+3, '.', False)
A, B = int(sys.argv[1]), int(sys.argv[2])
# turn profiling on between frames A and B by wrapping run's frame counter through script hook
class Hook(dict):
    pass
orig_run = vz.run
frames_seen = {'n': -1}
import types
def run(nframes, script, **kw):
    return orig_run(nframes, script)
# simple approach: monkeypatch finish_frame to toggle
fin = vz.finish_frame
def finish():
    n = vz.cur['n']
    if n + 1 == A: state['on'] = True
    if n + 1 == B: state['on'] = False
    fin()
vz.finish_frame = finish
vz.run(B + 1, script)
tot = sum(prof.values())
nfr = B - A
print('profile over %d frames, total %d T (%.0f T/frame)' % (nfr, tot, tot / nfr))
for n, t in prof.most_common(14):
    print('%-18s %8.0f T/frame  %5.1f%%' % (n, t / nfr, 100 * t / tot))
