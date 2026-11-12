#!/usr/bin/env python3
"""
mktrack.py - the five legs of BEELINE as road sections -> build/track.inc
ViBED by BPM 2026

A section is (length in segments, curve target, slope target).  The game
streams segments into the 256-entry ring (TRK_CURVE / TRK_YL / TRK_YH) ahead
of the camera, easing curve and slope towards each section's targets, so the
road flows smoothly from one section to the next.

  curve: X acceleration per segment (about +-36 = hairpin)
  slope: height change per segment (about +-14 = steep)
  one segment takes ~1/16 s at 250 km/h
"""
import os, sys

S = lambda n, c=0, s=0: (n, c, s)

LEGS = [
    ("GREEN VALLEY", [          # gentle sweepers and rolling hills
        S(60), S(50, 14), S(30), S(40, 0, 6), S(40, 0, -6), S(50, -18), S(30, -18, 5),
        S(30, 0, -5), S(60), S(40, 22), S(30, 10, 4), S(40, 0, -4), S(40, -14), S(40, 14),
        S(50, 0, 7), S(40, 0, -7), S(30), S(50, -24), S(40, 0, 3), S(60, 16, -3), S(40),
        S(40, 0, 6), S(40, 0, -6), S(60),
    ]),
    ("RED CENTRE", [            # long straights over big crests
        S(40), S(50, 0, 10), S(50, 0, -10), S(40), S(40, 12), S(60, 0, 12), S(30, 0, -12),
        S(30, 0, -12), S(40, 0, 12), S(40), S(50, -16), S(60), S(40, 0, 14), S(40, 0, -14),
        S(40, 0, 14), S(40, 0, -14), S(40, 20), S(40, -20), S(60), S(50, 0, 9), S(50, 0, -9),
        S(60, 10), S(40),
    ]),
    ("SNOWY RANGE", [           # twisty mountain pass, steep climbs
        S(30), S(40, 28, 8), S(40, -28, 8), S(30, 0, 10), S(40, 32, -6), S(30, 0, -10),
        S(40, -32, 4), S(40, 24, 10), S(30, 0, -12), S(40, -26, -6), S(40, 30), S(30, 0, 12),
        S(30, -30, -12), S(40, 0, 6), S(40, 34, -6), S(40, -34), S(30), S(40, 26, 8),
        S(40, -26, -8), S(40, 0, 10), S(40, 0, -10), S(40),
    ]),
    ("COAST AT DUSK", [         # flowing esses along the cliffs
        S(40), S(40, 20), S(40, -20), S(40, 20, 6), S(40, -20, -6), S(50), S(40, 26, 4),
        S(40, -26, -4), S(40, 0, 8), S(40, 0, -8), S(40, -22), S(40, 22), S(40, -22, 6),
        S(40, 22, -6), S(60), S(40, 30), S(40, -30), S(40, 16, 8), S(40, -16, -8), S(50),
        S(40, 24), S(40, -24), S(40),
    ]),
    ("NIGHT RUN", [             # everything at once, in the dark
        S(40), S(40, 30, 10), S(30, 0, -12), S(40, -30, -4), S(40, 0, 14), S(40, 0, -14),
        S(30, 34), S(30, -34), S(50), S(40, 0, 12), S(30, 24, -12), S(30, -24, -6),
        S(40, 28, 6), S(40, -32), S(40, 0, 14), S(30, 0, -14), S(40, 20), S(40, -26, 8),
        S(40, 26, -8), S(40, -20), S(40, 0, 10), S(40, 0, -10), S(60),
    ]),
]

def main(out):
    L = []
    cps = []
    tot = 0
    L.append('NLEGS        equ %d' % len(LEGS))
    L.append('LEGSEC:')
    for li, (name, secs) in enumerate(LEGS):
        L.append('LEGSEC_%d:' % (li + 1))
        if li == len(LEGS) - 1: L.append('LEGSEC_LAST:')
        for n, c, s in secs:
            assert 0 < n < 256 and -40 <= c <= 40 and -16 <= s <= 16
            L.append('        db %d,%d,%d' % (n, c & 255, s & 255))
            tot += n
        cps.append(tot)
    L.append('        db 0                    ; end: the streamer repeats the last leg')
    L.append('LEGEND:')
    L.append('        dw ' + ','.join(str(c) for c in cps) + '   ; distance (segments) at the end of each leg')
    L.append('LEGNAME:')
    for name, _ in LEGS:
        L.append('        db "%s"' % name.center(14)[:14])
    open(os.path.join(out, 'track.inc'), 'w').write('\n'.join(L) + '\n')
    print('track: %s segments per leg, %d total' % (
        [c - p for c, p in zip(cps, [0] + cps)], tot), file=sys.stderr)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'build')
