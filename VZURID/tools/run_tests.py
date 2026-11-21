#!/usr/bin/env python3
import os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from vztest import VZ, FIELD
root = os.path.join(os.path.dirname(__file__), '..')
build = os.path.join(root, 'build')
shots_dir = os.path.join(build, 'shots'); os.makedirs(shots_dir, exist_ok=True)
vz = VZ(os.path.join(build, 'vzurid.bin'), os.path.join(build, 'vzurid.sym'))
script = {}
def at(f, key, down=True): script.setdefault(f, []).append((key, down))
at(5, ',')                      # fly right
for f in range(10, 400, 6):     # rapid fire taps
    at(f, '.'); at(f+3, '.', False)
at(120, 'M'); at(120, ',', False)      # reverse -> flip to face left
at(230, ',') ; at(230, 'M', False)     # reverse again -> flip back
at(260, 'Q'); at(300, 'Q', False)      # climb
at(300, 'A'); at(330, 'A', False)      # dive
at(340, 'M'); at(340, ',', False)      # and another flip
at(352, ',') ; at(352, 'M', False)     # flip back quickly (mid-flip reversal)
shots = set([8, 40, 100, 119, 121, 123, 125, 127, 129, 131, 133, 135, 140, 200, 232, 234, 236, 238, 240, 270, 320, 345, 348, 351])
N = int(sys.argv[1]) if len(sys.argv) > 1 else 400
t0 = time.time()
frames = vz.run(N, script, shots, shots_dir)
print('emulated %d frames in %.1fs' % (len(frames), time.time() - t0))
work = [f['work'] for f in frames if 'work' in f]
print('work T/frame: min %d  mean %d  max %d   (field = %d)' % (min(work), sum(work)/len(work), max(work), FIELD))
over = [f['n'] for f in frames if f.get('work', 0) > FIELD - 400]
print('frames at/over the field budget:', over[:20], 'count', len(over))
margins = [(f['margin'][0], f['margin'][1], f['n']) for f in frames if f.get('margin')]
m = min(margins)
print('tightest row deadline: margin %d T on row %d in frame %d' % m)
print('frames with rows drawn after the beam passed:', sum(1 for f in frames if f['late_rows']))
print('VRAM writes while beam inside that row:', len(vz.beam_conflicts), vz.beam_conflicts[:5])
print('late counter (game):', vz.var('lateCnt', 2), ' min slack count:', vz.var('minSlack', 2), ' score:', vz.var('score', 2))
print('posX', vz.var('posX', 2), 'speed', vz.var('speed', 2), 'flipF', vz.var('flipF'))
if len(sys.argv) > 2:
    a, b = int(sys.argv[2]), int(sys.argv[3])
    print(' '.join('%d:%d' % (f['n'], f.get('work', 0)) for f in frames if a <= f['n'] < b))
