#!/usr/bin/env python3
"""Random-input soak: mashes keys/joysticks for N frames, reports snow, render timing, stack."""
import os, random, subprocess, sys, tempfile, struct
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'hamsam2.sym'))}
seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
frames = int(sys.argv[2]) if len(sys.argv) > 2 else 60000
random.seed(seed)
KEYS = ['Q', 'A', 'M', 'COMMA', 'SPACE', 'RETURN', 'P', 'S', 'X', 'C', 'I', 'J', 'K', 'L', 'H',
        'J1U', 'J1D', 'J1L', 'J1R', 'J1F', 'J2U', 'J2D', 'J2L', 'J2R', 'J2F', 'D', 'N']
W = [6, 6, 6, 6, 8, 2, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3, 3, 3, 4, 2, 2, 2, 2, 2, 1, 1]
ev = []; f = 50
while f < frames and len(ev) < 4000:
    k = random.choices(KEYS, W)[0]
    d = random.randint(1, 40)
    ev.append('%d %d %s' % (f, f + d, k)); f += random.randint(3, 40)
kf = os.path.join(tempfile.gettempdir(), 'fuzz%d.txt' % seed)
open(kf, 'w').write('\n'.join(ev) + '\n')
tr = os.path.join(tempfile.gettempdir(), 'fuzzsp%d.bin' % seed)
r = subprocess.run([os.path.join(ROOT, 'tools', 'vzemu', 'vzemu'), os.path.join(ROOT, 'release', 'HAMSAM2.VZ'),
                    '-frames', str(frames), '-keys', kf, '-bennvenn',
                    '-trace', '%x:2:%s' % (sym['mode'], tr)], capture_output=True, text=True)
d = open(tr, 'rb').read()
modes = sorted(set(d[i] for i in range(0, len(d), 2)))
print('seed', seed, 'modes visited', modes)
print('\n'.join(l for l in r.stderr.split('\n') if l.startswith(('snow', 'render', 'end', 'bennvenn'))))
