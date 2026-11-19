#!/usr/bin/env python3
"""GYRUVZ title music: J.S. Bach, Toccata and Fugue in D minor (BWV 565),
arranged for the 3-voice beeper engine in front3.asm with an arcade beat.

Each bar is 16 rows (16ths).  Voice 1 = lead, voice 2 = bass / second voice,
voice 3 = drums or a third voice.  Tokens:
  .  nothing new        -  note off
  C#5 etc  a note       D5m / A4M / C#4d / D3o / A2f  an arpeggio chord
                        (m minor, M major, d diminished 7th, o octave, f fifth)
  K S H  kick, snare, hat (voice 3 only)
Writes music3.inc: song + NOTETAB.
"""
import sys

CPU = 3546900
SAMPLE_T = 191                    # T-states a sample in mus_lp
FS = CPU / SAMPLE_T
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
ARPS = {'m': 1, 'M': 2, 'd': 3, 'o': 4, 'f': 5}


def semis(n):
    return NAMES.index(n[:-1]) + 12 * (int(n[-1]) - 2)


def notetab():
    return [min(65535, int(round(65.406 * 2 ** (i / 12.0) * 65536 / FS))) for i in range(72)]


CHORDS = []


def tok(t):
    if t == '.':
        return 0
    if t == '-':
        return 1
    if t in 'KSH':
        return {'K': 0x80, 'S': 0x81, 'H': 0x82}[t]
    if t[-1] in ARPS:
        c = (2 + semis(t[:-1]), ARPS[t[-1]])
        if c not in CHORDS:
            CHORDS.append(c)
        return 0xC0 + CHORDS.index(c)
    n = 2 + semis(t)
    assert 2 <= n < 74, t
    return n


def bar(a, b, c):
    A, B, C = a.split(), b.split(), c.split()
    assert len(A) == 16 and len(B) == 16 and len(C) == 16, (a, b, c)
    out = []
    for i in range(16):
        out += [tok(A[i]), tok(B[i]), tok(C[i])]
    return out


NO = ". . . . . . . . . . . . . . . ."
D1 = "K . H . S . H . K . K H S . H ."
D2 = "K . H . S . H K . K H . S H S S"
D3 = "K . H H S . H H K . H K S . H H"
ROLL = "S . S . S . S . S S S S S S S S"


def pump(a, b):
    """driving octave bass: a for 8 rows, b for 8"""
    return "%s . %s . %s . %s . %s . %s . %s . %s ." % (a, up(a), a, up(a), b, up(b), b, up(b))


def up(n):
    s = semis(n) + 12
    return NAMES[s % 12] + str(s // 12 + 2)


BARS = {
 # ---- the opening: the mordent and the fall, three times, an octave lower each
 'i1': bar("A5 G5 A5 . . . . . . . . . . . . .",
           "A4 G4 A4 . . . . . . . . . . . . .",
           "K . . . . . . . . . . . . . . ."),
 'i2': bar("G5 F5 E5 D5 C#5 . . . . . D5 . . . . -",
           "G4 F4 E4 D4 C#4 . . . . . D4 . . . . -",
           ". . . . . . . . . . K . . . . ."),
 'i3': bar("A4 G4 A4 . . . . . . . . . . . . .",
           "A3 G3 A3 . . . . . . . . . . . . .",
           "K . . . . . . . . . . . . . . ."),
 'i4': bar("G4 F4 E4 D4 C#4 . . . . . D4 . . . . -",
           "G3 F3 E3 D3 C#3 . . . . . D3 . . . . -",
           ". . . . . . . . . . K . . . . ."),
 'i5': bar("A3 G3 A3 . . . . . . . . . . . . .",
           "A2 G2 A2 . . . . . . . . . . . . .",
           "K . . . . . . . . . . . . . . ."),
 'i6': bar("G3 F3 E3 D3 C#3 . . . . . D3 . . . . .",
           "G2 F2 E2 D2 C#2 . . . . . D2 . . . . .",
           ". . . . . . . . . . K . . . . ."),
 # the diminished seventh climbs over the low D, then the chord
 'i7': bar("C#4 E4 G4 A#4 C#5 E5 G5 A#5 C#6 . . . . . . .",
           "D2 . . . . . . . . . . . . . . .",
           ROLL),
 'i8': bar("D5m . . . . . . . . . . . . . . -",
           "D3o . . . . . . . . . . . . . . -",
           "K . . . . . . . S . . . S . S S"),
 # ---- prestissimo: cascades over the beat
 'p1': bar("A5 G5 F5 E5 F5 E5 D5 C#5 D5 C#5 A#4 A4 A#4 A4 G4 F4",
           pump('D2', 'D2'), D1),
 'p2': bar("G4 F4 E4 D4 E4 D4 C#4 A3 D4 . F4 . A4 . D5 .",
           pump('A2', 'D2'), D2),
 'p3': bar("A#5 A5 G5 F5 G5 F5 E5 D5 E5 D5 C#5 A#4 C#5 A#4 A4 G4",
           pump('G2', 'A2'), D1),
 'p4': bar("F4 E4 D4 C#4 D4 E4 F4 G4 A4 . C#5 . E5 . A5 .",
           pump('A2', 'A2'), D2),
 # chord stabs
 'p5': bar("D5m . . . D5m . . . A#4M . . . A4M . . .",
           "D2 . . . D2 . . . A#2 . . . A2 . . .",
           "K . . S K . S . K . . S K S S S"),
 'p6': bar("G4m . . . G4m . . . A4M . . . C#5d . . .",
           "G2 . . . G2 . . . A2 . . . A2 . . .",
           "K . . S K . S . K . K S K S S S"),
 # ---- the fugue: the subject over its pedal A, then the answer up a fifth
 'f1': bar("A4 A#4 A4 G4 A4 F4 A4 E4 A4 D4 A4 C#4 A4 D4 A4 E4",
           "D2 . . . D3 . . . A2 . . . A2 . . .", D3),
 'f2': bar("A4 F4 A4 G4 A4 E4 A4 F4 A4 D4 A4 E4 C#4 D4 E4 F4",
           "D2 . . . D3 . . . A2 . . . D2 . . .", D3),
 'f3': bar("E5 F5 E5 D5 E5 C5 E5 B4 E5 A4 E5 G#4 E5 A4 E5 B4",
           "A2 . . . A3 . . . E2 . . . E2 . . .", D3),
 'f4': bar("E5 C5 E5 D5 E5 B4 E5 C5 E5 A4 E5 B4 G#4 A4 B4 C#5",
           "A2 . . . A3 . . . E2 . . . A2 . . .", D2),
 'f5': bar("A5 A#5 A5 G5 A5 F5 A5 E5 A5 D5 A5 C#5 A5 D5 A5 E5",
           "D3m . . . . . . . A2M . . . . . . .", D3),
 'f6': bar("A5 F5 A5 G5 A5 E5 A5 F5 A5 D5 A5 E5 C#5 D5 E5 F5",
           "D3m . . . . . . . A2M . . . D3m . . .", D2),
 'f7': bar("D5 E5 F5 G5 A5 G5 F5 E5 F5 E5 D5 C#5 D5 . A4 .",
           pump('G2', 'A2'), D1),
 'f8': bar("F4 G4 A4 A#4 C#5 . E5 . G5 . A#5 . C#6 . . .",
           "A2 . . . . . . . A2 . . . . . . .", ROLL),
}

ORDER = ['i1', 'i2', 'i3', 'i4', 'i5', 'i6', 'i7', 'i8',
         'p1', 'p2', 'p3', 'p4', 'p1', 'p2', 'p5', 'p6',
         'f1', 'f2', 'f3', 'f4', 'f5', 'f6', 'f7', 'f8',
         'p5', 'p6', 'p1', 'p4', 'i7', 'i8']

SPEED = 8                                 # ticks a row (~89 ms)
# per voice: start duty, decay a tick, floor, pulse-width sweep depth
INS = [0x78, 3, 0x2C, 0x18,               # lead: bright attack, then a slow PWM sweep
       0x68, 2, 0x34, 0x10,               # bass / second voice
       0x58, 3, 0x24, 0x0C]               # third voice


def main(path):
    lines = ['; generated by music3.py - Bach BWV 565, arranged for GYRUVZ', '']
    pats = {k: v for k, v in BARS.items()}
    lines.append('song:')
    lines.append('        db %d' % SPEED)
    lines.append('        db ' + ','.join(str(x) for x in INS))
    lines.append('        dw song_chords')
    for o in ORDER:
        lines.append('        dw song_%s' % o)
    lines.append('        dw $FF00, song+%d' % (1 + 12 + 2))
    for k, v in pats.items():
        lines.append('song_%s: db %s' % (k, ','.join(str(x) for x in v)))
    lines.append('song_chords:')
    for root, arp in CHORDS:
        lines.append('        db %d,%d' % (root, arp))
    lines.append('NOTETAB: dw ' + ','.join(str(x) for x in notetab()))
    open(path, 'w').write('\n'.join(lines) + '\n')
    nbytes = 16 + 2 * len(ORDER) + 48 * len(pats) + 2 * len(CHORDS) + 144
    secs = len(ORDER) * 16 * SPEED * MUS_TICK
    print('music3: %d bars, %d bytes, %.0f s a loop' % (len(ORDER), nbytes, secs), file=sys.stderr)


MUS_TICK = 200 * SAMPLE_T / CPU

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'music3.inc')
