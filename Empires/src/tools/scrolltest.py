#!/usr/bin/env python3
"""Scroll regression test.  For each direction, scroll the view one or more
steps, take a screen shot, then force a full redraw (C twice) and take
another: the map rows must match exactly (cursor cells excepted)."""
import os, subprocess, sys
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build'))
K = {'up': 23, 'left': 1, 'down': 19, 'right': 4}
def tap(k, n=1):
    o = []
    for _ in range(n):
        o += ['key %d 1' % k, 'frames 6', 'key %d 0' % k, 'frames 8']
    return o
L = ['frames 60'] + tap(3) + ['frames 300'] + tap(33) + ['frames 1700'] + tap(16)
checks = [('left', 20), ('left', 6), ('up', 12), ('up', 4), ('right', 40), ('right', 5),
          ('down', 25), ('down', 4), ('left', 3), ('up', 2)]
for i, (d, n) in enumerate(checks):
    L += tap(K[d], n) + ['frames 4', 'shot d_sc%da.bin' % i] + tap(3, 2) + ['frames 4', 'shot d_sc%db.bin' % i]
subprocess.run(['../tools/beeemu', 'EMPIRES.COM', 'banked'], input='\n'.join(L) + '\n',
               capture_output=True, text=True)
fail = 0
for i, (d, n) in enumerate(checks):
    a = open('d_sc%da.bin' % i, 'rb').read(); b = open('d_sc%db.bin' % i, 'rb').read()
    bad = 0
    for base in (0, 2048, 4096):
        for j in range(80, 80 * 21):
            if a[base + j] != b[base + j] and a[j] not in (0xF8, 0xF9) and b[j] not in (0xF8, 0xF9):
                bad += 1
    print('%-5s x%-2d  differing cells: %d' % (d, n, bad))
    fail |= bad > 0
sys.exit(1 if fail else 0)
