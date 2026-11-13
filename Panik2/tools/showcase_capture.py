#!/usr/bin/env python3
"""Capture emulator frames (every 3rd) for the showcase GIF.
usage: showcase_capture.py out_dir"""
import os, re, sys, subprocess
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'PANIK2.VZ')
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'panik2.sym')):
    m = re.match(r'(\S+): EQU 0x([0-9A-F]+)', l)
    if m:
        sym[m.group(1)] = int(m.group(2), 16)
AUTO = [(150, 'autoplay', 1), (150, 'godmode', 1)]


def run(name, frames, keys="", pokes=()):
    kf = os.path.join(OUT, name + '.keys')
    open(kf, 'w').write(keys)
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-out', os.path.join(OUT, name), '-every', '3']
    for (f, s, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, sym[s], v)]
    r = subprocess.run(a, capture_output=True, text=True)
    print(name, r.stderr.strip().splitlines()[-3])


START = "100 102 SPACE\n"
run('title', 1000)
for w in range(4):
    run('w%d' % (w + 1), 2400, START, [(90, 'startlevel', w * 5)] + AUTO)
run('clear', 1400, START, [(90, 'startlevel', 0)] + AUTO + [(1000, 'forceclear', 1)])
run('gem', 1400, START, [(90, 'startlevel', 4)] + AUTO)
run('int', 1300, START, [(90, 'startlevel', 9)] + AUTO + [(400, 'forceclear', 1)])
run('end', 1800, START, [(90, 'startlevel', 19)] + AUTO + [(400, 'forceclear', 1)])
run('att', 2700)
