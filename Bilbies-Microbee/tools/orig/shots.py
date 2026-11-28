"""Gameplay screenshots: python3 tools/shots.py level frame [frame...] -> run/shot_L<n>.png"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu
i = int(sys.argv[1]); fs = [int(a) for a in sys.argv[2:]]
body = 'vz ../build/BILBIES.VZ\nuntilpc {front_main} 100\npoke {v_lvl} %02X\nsetpc {test_run}\n' % i
t = 0
for f in fs:
    body += 'frames %d\nscreen S%d_%d.ppm\n' % (f - t, i, f); t = f
emu.run(body, 'shot%d' % i)
emu.png(['S%d_%d' % (i, f) for f in fs])
print(' '.join('run/S%d_%d.png' % (i, f) for f in fs))
