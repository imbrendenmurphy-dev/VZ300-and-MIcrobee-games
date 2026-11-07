#!/usr/bin/env python3
"""Reveal the land around each rival town and screenshot it in colour and mono."""
import os, subprocess
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build'))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open('empires.sym')}
def tap(k, n=1):
    o = []
    for _ in range(n): o += ['key %d 1' % k, 'frames 6', 'key %d 0' % k, 'frames 6']
    return o
PRE = ['frames 60'] + tap(3) + ['frames 340'] + tap(33) + ['frames 1500']
def run(lines):
    return subprocess.run(['../tools/beeemu', 'EMPIRES.COM', 'banked'], input='\n'.join(lines) + '\n',
                          capture_output=True, text=True).stderr
run(PRE + ['mem rw0.bin'])
m = open('rw0.bin', 'rb').read()
n = m[sym['nrivals']]
L = list(PRE) + ['poke %04X 03' % sym['speed'], 'frames 3000', 'poke %04X 00' % sym['speed']]
for i in range(n):
    b = sym['rivals'] + 16 * i
    rx, ry = m[b + 1], m[b + 2]
    for y in range(ry - 9, ry + 10):
        for x in range(rx - 14, rx + 15):
            if 0 <= x < 256 and 0 <= y < 256:
                L.append('bor %d %X 80' % (8 + (y >> 6), (y & 63) * 256 + x))
    L += ['poke %04X %02X %02X' % (sym['viewx'], max(0, rx - 14), max(0, ry - 8)),
          'poke %04X %02X %02X' % (sym['curx'], rx, ry), 'frames 2'] + tap(13) + ['frames 20'] + tap(13) + ['frames 20',
          'shot rw%d.bin' % i]
print(run(L)[-300:])
