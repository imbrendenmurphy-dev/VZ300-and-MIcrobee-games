#!/usr/bin/env python3
"""Soak test: let the computer play both sides and report how points end.
usage: why.py frames [keys-file]   (default keys: start an exhibition match)"""
import os, subprocess, sys, tempfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'tennis2.sym'))}
frames = int(sys.argv[1]) if len(sys.argv) > 1 else 15000
keys = sys.argv[2] if len(sys.argv) > 2 else None
if not keys:
    keys = os.path.join(tempfile.gettempdir(), 't2keys.txt')
    open(keys, 'w').write("100 103 SPACE\n200 203 A\n260 263 SPACE\n340 343 SPACE\n")
dump = os.path.join(tempfile.gettempdir(), 't2why.bin')
r = subprocess.run([os.path.join(ROOT, 'tools', 'vzemu', 'vzemu'), os.path.join(ROOT, 'build', 'TENNIS2.VZ'),
                    '-frames', str(frames), '-keys', keys, '-poke', '400:%x:1' % sym['autoplay'],
                    '-dump', '%x:8:%s' % (sym['dbg_why'], dump)], capture_output=True, text=True)
d = open(dump, 'rb').read()
names = ['normal', 'out', 'net', 'ace', 'winner', 'dbl fault', 'fault', 'let']
print(' '.join('%s=%d' % (n, v) for n, v in zip(names, d)), '| total', sum(d))
print(r.stderr.strip().split('\n')[-3])
