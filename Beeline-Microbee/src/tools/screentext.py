#!/usr/bin/env python3
"""screentext.py vdump.bin gfx.inc - decode the on-screen HUD-font text (rows of 64)"""
import sys, re
d = open(sys.argv[1], 'rb').read()
vram, aram = d[0:2048], d[2048:4096]
inc = open(sys.argv[2]).read()
m = inc[inc.index('FONTMAP:'):]
vals = []
for line in m.split('\n')[1:]:
    line = line.strip()
    if not line.startswith('db'): break
    vals += [int(x) for x in line[2:].split(',')]
rev = {}
for i in range(64):
    rev[(vals[2 * i], vals[2 * i + 1])] = chr(32 + i)
start = 0
for r in range(16):
    s = ''.join(rev.get((vram[(start + r * 64 + c) & 2047], aram[(start + r * 64 + c) & 2047]), '?') for c in range(64))
    if s.strip(' ?'): print('%2d %s' % (r, s.rstrip()))
