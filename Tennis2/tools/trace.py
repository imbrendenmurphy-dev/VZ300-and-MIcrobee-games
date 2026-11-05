#!/usr/bin/env python3
"""Trace players + ball each frame under autoplay; print the frames before each point ends."""
import os, subprocess, sys, struct, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'tennis2.sym'))}
frames = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
keys = os.path.join(tempfile.gettempdir(), 't2keys.txt')
open(keys, 'w').write("100 103 SPACE\n200 203 A\n260 263 SPACE\n340 343 SPACE\n")
base = sym['pl0']; end = sym['pt_reason'] + 1
tr = os.path.join(tempfile.gettempdir(), 't2trace.bin')
subprocess.run([os.path.join(ROOT, 'tools', 'vzemu', 'vzemu'), os.path.join(ROOT, 'build', 'TENNIS2.VZ'),
                '-frames', str(frames), '-keys', keys, '-poke', '400:%x:1' % sym['autoplay'],
                '-trace', '%x:%x:%s' % (base, end - base, tr)], capture_output=True)
d = open(tr, 'rb').read(); n = end - base
PS = sym['PSIZE'] if 'PSIZE' in sym else 41
def g(fr, name, size=1, signed=False):
    o = fr * n + sym[name] - base
    if size == 2:
        return struct.unpack('<h' if signed else '<H', d[o:o + 2])[0]
    return d[o]
def pl(fr, i, off, size=1):
    o = fr * n + i * PS + off
    if size == 2:
        return struct.unpack('<h', d[o:o + 2])[0] / 64
    return d[o]
prev = 0
for fr in range(frames):
    po = g(fr, 'pt_over')
    if po and not prev:
        print('--- point over at frame', fr, 'reason', g(fr, 'pt_reason'), 'winner', g(fr, 'pt_win'))
        for f in range(max(0, fr - 14), fr + 1, 2):
            print('  f%d ball %.0f,%.0f z%.0f st%d bnc%d last%d | p0 %.0f,%.0f tgt %d,%d dly%d | p1 %.0f,%.0f tgt %d,%d dly%d' % (
                f, g(f, 'ball_x', 2, 1) / 64, g(f, 'ball_y', 2, 1) / 64, g(f, 'ball_z', 2, 1) / 64, g(f, 'ball_st'), g(f, 'ball_bnc'), g(f, 'ball_last'),
                pl(f, 0, 0, 2), pl(f, 0, 2, 2), pl(f, 0, 25), pl(f, 0, 26), pl(f, 0, 27),
                pl(f, 1, 0, 2), pl(f, 1, 2, 2), pl(f, 1, 25), pl(f, 1, 26), pl(f, 1, 27)))
    prev = po
