#!/usr/bin/env python3
"""Random-input soak: mashes keys/joysticks for N frames, reports snow, render timing, stack."""
import os, random, subprocess, sys, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'duel2.sym'))}
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
frames = int(sys.argv[2]) if len(sys.argv) > 2 else 60000
random.seed(seed)
KEYS = ['A', 'S', 'Z', 'W', 'X', 'SHIFT', 'L', 'SEMI', 'DOT', 'P', 'SPACE', 'COMMA', 'RETURN', 'Q', 'M', 'C',
        'J1U', 'J1D', 'J1L', 'J1R', 'J1F', 'J2U', 'J2D', 'J2L', 'J2R', 'J2F']
W = [6, 6, 4, 3, 5, 3, 5, 5, 3, 2, 8, 3, 1, 1, 1, 1, 3, 3, 4, 4, 5, 2, 2, 3, 3, 3]
ev = []; f = 50
while f < frames and len(ev) < 4000:
    k = random.choices(KEYS, W)[0]
    d = random.randint(1, 60)
    ev.append('%d %d %s' % (f, f + d, k)); f += random.randint(2, 30)
kf = os.path.join(tempfile.gettempdir(), 'dfuzz%d.txt' % seed)
open(kf, 'w').write('\n'.join(ev) + '\n')
tr = os.path.join(tempfile.gettempdir(), 'dfuzzm%d.bin' % seed)
r = subprocess.run([os.path.join(ROOT, 'tools', 'vzemu', 'vzemu'), os.path.join(ROOT, 'build', 'DUEL2.VZ'),
                    '-frames', str(frames), '-keys', kf, '-bennvenn',
                    '-trace', '%x:1:%s' % (sym['mode'], tr)], capture_output=True, text=True)
d = open(tr, 'rb').read()
print('seed', seed, 'modes visited', sorted(set(d)), 'events', len(ev))
print('\n'.join(l for l in r.stderr.split('\n') if l.startswith(('snow', 'render', 'end', 'bennvenn'))))
