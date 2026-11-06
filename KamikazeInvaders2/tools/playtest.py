#!/usr/bin/env python3
"""Scripted soak test in the headless emulator.
Starts a game, lets the demo AI play it (test hooks poked into RAM), optionally
forces the current mothership/bonus round to finish every N frames, and saves
a screenshot every M frames.
usage: playtest.py out_prefix [frames] [clear_every] [shot_every] [startkey] [god]"""
import os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'kami2.sym')):
    m = re.match(r'(\S+): EQU 0x([0-9A-F]+)', l)
    if m:
        sym[m.group(1)] = int(m.group(2), 16)
out = sys.argv[1]
frames = int(sys.argv[2]) if len(sys.argv) > 2 else 6000
every = int(sys.argv[3]) if len(sys.argv) > 3 else 0
shot = int(sys.argv[4]) if len(sys.argv) > 4 else 100
startkey = sys.argv[5] if len(sys.argv) > 5 else 'SPACE'
god = int(sys.argv[6]) if len(sys.argv) > 6 else 1
keys = out + '_keys.txt'
open(keys, 'w').write("100 103 %s\n" % startkey)
args = [os.path.join(HERE, 'vzemu', 'vzemu'), os.path.join(ROOT, 'build', 'KAMI2.VZ'),
        '-frames', str(frames), '-keys', keys, '-every', str(shot), '-out', out]
pk = [(150, sym['autoplay'], 1)]
if god:
    pk.append((150, sym['godmode'], 1))
if every:
    f = 150 + every
    while f < frames and len(pk) < 62:
        pk.append((f, sym['forceclear'], 1)); f += every
for (fr, a, v) in pk:
    args += ['-poke', '%d:%x:%x' % (fr, a, v)]
r = subprocess.run(args, capture_output=True, text=True)
print(r.stderr.strip())
