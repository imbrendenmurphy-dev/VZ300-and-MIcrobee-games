#!/usr/bin/env python3
"""Capture emulator frames for the release screenshots and showcase GIF.
Each scenario runs the headless emulator with test pokes and saves every
3rd frame as build/cap/<name>_NNNNN.ppm.   usage: showcase_capture.py [name ...]"""
import os, re, subprocess, sys, glob
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
EMU = os.path.join(HERE, 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'STARBLS2.VZ')
CAP = os.path.join(ROOT, 'build', 'cap')
os.makedirs(CAP, exist_ok=True)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'sb2.sym')):
    m = re.match(r'(\S+): EQU 0x([0-9A-F]+)', l)
    if m:
        sym[m.group(1)] = int(m.group(2), 16)

START = "100 103 SPACE\n"


def play(sec, extra=()):
    return [(50, 'startsec', sec), (150, 'autoplay', 1), (150, 'godmode', 1)] + list(extra)


# name: (frames, keys, pokes, every)
SCEN = {
    'title':  (1400, "", [], 3),
    'attract': (9000, "", [], 10),
    's1': (2400, START, play(0), 3),
    's2': (2000, START, play(1), 3),
    's3': (2000, START, play(2), 3),
    's4': (2600, START, play(3), 3),
    's5': (2000, START, play(4), 3),
    's6': (2200, START, play(5), 3),
    's7': (2000, START, play(6), 3),
    # mothership: turrets knocked out at 1500 so the core fight and the
    # big explosion happen on camera, then the mission-complete screen
    's8': (5200, START, play(7, [(1500, 'turhp', 0), (1500, 'turhp+1', 0), (1500, 'turhp+2', 0),
                                 (1500, 'turhp+3', 0), (1500, 'quota+3', 0)]), 3),
    # nobody at the controls: fighters get through (hit flash, warnings)
    'hit': (2400, START, [], 3),
    # a sector cleared on cue: tally, refuel, warp out and the next warp in
    'clear': (1700, START, play(0, [(900, 'forceclear', 1)]), 3),
    # out of energy -> game over -> new high score -> initials
    'over': (2400, START + "1500 1503 Q\n1560 1563 SPACE\n1620 1623 SPACE\n1680 1683 SPACE\n",
             [(300, 'score+1', 0x87), (300, 'score', 0x02), (700, 'energy', 3), (700, 'energy+1', 0)], 3),
    'pause': (900, START + "700 703 P\n", [], 3),
}


def run(name):
    frames, keys, pokes, every = SCEN[name]
    for f in glob.glob(os.path.join(CAP, name + '_*.ppm')):
        os.remove(f)
    kf = os.path.join(CAP, name + '.keys')
    open(kf, 'w').write(keys)
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-every', str(every), '-out', os.path.join(CAP, name)]
    for (f, s, v) in pokes:
        base, _, off = s.partition('+')
        a += ['-poke', '%d:%x:%x' % (f, sym[base] + int(off or 0), v)]
    r = subprocess.run(a, capture_output=True, text=True)
    print(name, r.stderr.strip().split('\n')[-1])


for n in (sys.argv[1:] or SCEN):
    run(n)
