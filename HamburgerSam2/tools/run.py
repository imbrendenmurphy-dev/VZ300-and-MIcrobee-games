#!/usr/bin/env python3
"""run.py: run release/HAMSAM2.VZ in tools/vzemu with pokes by symbol name.
  python3 tools/run.py FRAMES [frame:symbol=value ...] [-- extra vzemu args]
  e.g. python3 tools/run.py 3000 5:autoplay=1 5:godmode=1 170:kitchen=7 -- -keys build/k1"""
import os, subprocess, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sym = {}
for l in open(os.path.join(root, "build", "hamsam2.sym")):
    p = l.split()
    if len(p) == 2:
        sym[p[1]] = p[0]
args = sys.argv[1:]
extra = []
if "--" in args:
    i = args.index("--"); extra = args[i + 1:]; args = args[:i]
cmd = [os.path.join(root, "tools", "vzemu", "vzemu"), os.path.join(root, "release", "HAMSAM2.VZ"),
       "-bennvenn", "-frames", args[0]]
for a in args[1:]:
    f, rest = a.split(":", 1)
    name, val = rest.split("=")
    cmd += ["-poke", "%s:%s:%x" % (f, sym[name], int(val, 0))]
cmd += extra
sys.exit(subprocess.call(cmd))
