#!/usr/bin/env python3
# Two-voice tunes for the HOPPY 2 beeper engine -> src/music2.inc
# Row = (fields, bass, melody).  Notes like C3, F#4, '-' = rest.  Loop rate 140T.
import os
RATE = 3546900/140.0
NAMES = {'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'A':9,'A#':10,'B':11}
def midi(n):
    if n in ('-','.'): return 0
    nm, o = n[:-1], int(n[-1])
    return 12*(o+1)+NAMES[nm]
LOW = 36  # C2
def inc(m):
    f = 440*2**((m-69)/12)
    return round(f*65536/RATE)

def tune(name, rows, step):
    """rows: list of 'bass mel' eighths, or 'bass mel *n' for n eighths"""
    out = []
    for r in rows.split(','):
        p = r.split()
        if not p: continue
        n = 1
        if len(p) == 3 and p[2].startswith('*'): n = int(p[2][1:])
        b, m = midi(p[0]), midi(p[1])
        out.append((step*n, (b-LOW+1) if b else 0, (m-LOW+1) if m else 0))
    s = f"{name}:\n"
    for f,b,m in out: s += f"\tdb {f},{b},{m}\n"
    return s + "\tdb 0\n"

T = []
T.append("m2_ftab:\n\tdw 0\n" + "".join(f"\tdw {inc(m)}\n" for m in range(LOW, 97)))

# Title theme: bouncy, cheeky, notes kept apart
title = """
C3 C5, - E5, G2 G5, - E5, C3 C5, - E5, G2 G5, - C6,
F2 A5, - G5, C3 E5, - G5, F2 A5, - -, C3 G5, - -,
G2 F5, - E5, D3 D5, - E5, G2 F5, - A5, D3 G5, - F5,
C3 E5, - D5, G2 C5, - D5, C3 E5 *2, G2 - , - -,
C3 C5, - E5, G2 G5, - E5, C3 C5, - E5, G2 G5, - C6,
F2 D6, - C6, A2 A5, - G5, F2 A5, - -, A2 C6, - -,
G2 B5, - G5, B2 D5, - G5, G2 B5, - A5, D3 G5, - F5,
C3 E5, G2 G5, C3 C6, G2 G5, C3 C6 *2, C2 - *2
"""
T.append(tune("m2_title", title.replace('\n',' '), 5))
T.append(tune("m2_go", "C3 G4, - C5, G2 E5, - G5, C3 - , G2 G5, C3 C6 *3", 5))
T.append(tune("m2_clear", "C3 C5, - E5, G2 G5, - C6, F2 A5, - C6, F2 E6 *2, G2 D6, - E6, C3 C6 *3, - -", 5))
T.append(tune("m2_over", "G2 G4 *2, - -, F2 F4 *2, - -, E2 E4 *2, - -, D2 D4 *2, C2 C4 *4", 5))
T.append(tune("m2_hi", "C3 C5, E3 E5, G3 G5, C4 C6, G3 G5, C4 C6 *3", 4))
T.append(tune("m2_win", "C3 G4, - C5, C3 E5, - G5, F2 A5 *2, F2 F5 *2, G2 G5, - B5, G2 D6, - B5, C3 C6 *2, G2 G5 *2, C3 E6, - D6, C3 C6, - G5, C3 C6 *4", 5))

open(os.path.join(os.path.dirname(__file__),'..','music2.inc'),'w').write("\n".join(T))
print("ok")
