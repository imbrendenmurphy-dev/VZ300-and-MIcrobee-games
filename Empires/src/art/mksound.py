#!/usr/bin/env python3
"""mksound.py - EMPIRES music and sound effects -> src/sfx.inc

Entries are 2 bytes: period, frames.
  period = tone period in counts of the tone loop (71 T-states each),
           0 = silence, 1 = soft noise, 0FFh = end, 0FEh = loop to start
  frames = length in 50 Hz frames; bit 7 set = wider pulse (1/4, fuller)
Music notes are played for (frames - 1) and then one silent frame, so notes
never run together; the first frame of a music note is a wider pulse (a
little attack), the rest a thin 1/8 pulse.
"""
CPU = 3375000
LOOP = 74          # T-states per count of the tone loop
OVER = 84          # T-states of edge overhead per period
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}

def freq(n):
    name, octv = n[:-1], int(n[-1])
    semis = NAMES[name] + 12 * (octv - 4) - 9          # from A4
    return 440.0 * 2 ** (semis / 12)

def period(n):
    p = round((CPU / freq(n) - OVER) / LOOP)
    assert 8 <= p <= 250, (n, p)
    return p

def seq(items, wide=False):
    out = []
    for it in items:
        if it[0] == 'r':
            out += [0, it[1]]
        elif it[0] == 'n':                     # noise
            out += [1, it[1]]
        else:
            out += [period(it[0]), it[1] | (0x80 if (wide or (len(it) > 2 and it[2])) else 0)]
    return out

FX = {
    # short, thin ticks for the interface
    'click':  [('A6', 1)],
    'tool':   [('E6', 1), ('r', 1), ('A6', 1)],
    # a carpenter's knock-knock when building starts (low, fuller pulse)
    'build':  [('G3', 1, 1), ('r', 3), ('D4', 1, 1)],
    'done':   [('C5', 3), ('r', 1), ('E5', 3), ('r', 1), ('G5', 6)],
    'error':  [('E4', 4), ('r', 2), ('C4', 6)],
    'grow':   [('G5', 2), ('r', 1), ('C6', 4)],
    'warn':   [('A3', 5, 1), ('r', 4), ('A3', 5, 1)],
    'ruins':  [('C5', 2), ('r', 1), ('E5', 2), ('r', 1), ('G5', 2), ('r', 1), ('C6', 6)],
    'spring': [('C5', 3), ('r', 1), ('D5', 3), ('r', 1), ('G5', 7)],
    'summer': [('E5', 3), ('r', 1), ('G5', 3), ('r', 1), ('C6', 7)],
    'autumn': [('G5', 3), ('r', 1), ('E5', 3), ('r', 1), ('C5', 7)],
    'winter': [('A4', 4), ('r', 2), ('F4', 4), ('r', 2), ('D4', 9)],
    'start':  [('G4', 3), ('r', 1), ('C5', 3), ('r', 1), ('E5', 3), ('r', 1), ('G5', 9)],
    'good':   [('E5', 2), ('r', 1), ('A5', 4)],
    'bad':    [('D4', 4), ('r', 2), ('A3', 6)],
    'research': [('C5', 2), ('r', 1), ('G5', 2), ('r', 1), ('E5', 2), ('r', 1), ('C6', 8)],
    'victory': [('C5', 4), ('r', 1), ('C5', 2), ('r', 1), ('G5', 4), ('r', 1), ('E5', 4), ('r', 1),
                ('G5', 3), ('r', 1), ('C6', 12)],
    'raid':   [('n', 2), ('r', 2), ('n', 2), ('r', 3), ('C4', 6, 1)],
}

# Victory: a stately march in D minor ("the legions return"); 8th note = 7 frames
E8 = 7
def bar(*notes):
    return [(n, int(l * E8)) if n != 'r' else ('r', int(l * E8)) for n, l in notes]
TITLE = []
TITLE += bar(('D4', 2), ('A4', 2), ('D5', 3), ('C5', 1))
TITLE += bar(('A4', 2), ('G4', 1), ('F4', 1), ('G4', 4))
TITLE += bar(('F4', 2), ('G4', 2), ('A4', 2), ('C5', 2))
TITLE += bar(('D5', 6), ('r', 2))
TITLE += bar(('F5', 2), ('E5', 1), ('D5', 1), ('C5', 2), ('A4', 2))
TITLE += bar(('G4', 2), ('A4', 1), ('C5', 1), ('D5', 4))
TITLE += bar(('C5', 2), ('A4', 2), ('G4', 2), ('E4', 2))
TITLE += bar(('D4', 6), ('r', 2))
TITLE += bar(('A4', 1), ('A4', 1), ('D5', 2), ('A4', 1), ('A4', 1), ('F5', 2))
TITLE += bar(('E5', 2), ('D5', 2), ('C5', 4))
TITLE += bar(('A#4', 2), ('A4', 2), ('G4', 2), ('F4', 2))
TITLE += bar(('E4', 4), ('A4', 4))
TITLE += bar(('D4', 2), ('F4', 2), ('A4', 2), ('D5', 2))
TITLE += bar(('C5', 2), ('A#4', 1), ('A4', 1), ('G4', 4))
TITLE += bar(('F4', 2), ('E4', 2), ('C#4', 2), ('E4', 2))
TITLE += bar(('D4', 6), ('r', 10))

# Title: a gentle pastoral air in F major, 3/4, played like a lyre: a melody
# note on the beat, then the chord rippled beneath it.  8th note = 9 frames.
G8 = 9
def lyre(mel, arps, ml=2):
    """one bar: melody note for ml eighths, then the arpeggio in eighths"""
    return [(mel, ml * G8)] + [(a, G8) for a in arps]
def air(*notes):
    return [(n, int(l * G8)) for n, l in notes]
GENTLE = []
GENTLE += [(a, G8) for a in ('F4', 'A4', 'C5', 'A4', 'C5', 'F5')]          # intro ripple
GENTLE += [(a, G8) for a in ('F4', 'A4', 'C5', 'A4', 'C5', 'A4')]
# A: the air over rippled chords
GENTLE += lyre('C5', ('F4', 'A4', 'C5', 'A4'))
GENTLE += lyre('E5', ('G4', 'C5', 'E5', 'C5'))
GENTLE += lyre('F5', ('A4', 'D5', 'F5', 'D5'))
GENTLE += lyre('D5', ('F4', 'A#4', 'D5', 'A#4'))
GENTLE += lyre('C5', ('A4', 'C5', 'F5', 'C5'))
GENTLE += lyre('A#4', ('G4', 'A#4', 'D5', 'A#4'))
GENTLE += lyre('G4', ('C5', 'E5', 'G5', 'E5'))
GENTLE += air(('F5', 4), ('C5', 1), ('A4', 1))
# B: the air sings on its own
GENTLE += air(('A5', 3), ('G5', 1), ('F5', 2))
GENTLE += air(('F5', 3), ('D5', 1), ('A#4', 2))
GENTLE += air(('C5', 2), ('F5', 2), ('A5', 2))
GENTLE += air(('G5', 4), ('E5', 2))
GENTLE += air(('F5', 3), ('E5', 1), ('D5', 2))
GENTLE += air(('D5', 2), ('C5', 2), ('A#4', 2))
GENTLE += air(('A4', 2), ('C5', 2), ('E5', 2))
GENTLE += air(('F5', 6))
# A': the ripple returns, and the air settles home
GENTLE += lyre('A5', ('F4', 'A4', 'C5', 'A4'))
GENTLE += lyre('G5', ('G4', 'C5', 'E5', 'C5'))
GENTLE += lyre('F5', ('A4', 'D5', 'F5', 'D5'))
GENTLE += lyre('D5', ('F4', 'A#4', 'D5', 'A#4'))
GENTLE += lyre('C5', ('A4', 'C5', 'F5', 'C5'))
GENTLE += lyre('D5', ('G4', 'A#4', 'D5', 'A#4'))
GENTLE += air(('E5', 2), ('G4', 1), ('C5', 1), ('E5', 1), ('G5', 1))
GENTLE += air(('F5', 6))
GENTLE += [(a, G8) for a in ('C5', 'A4', 'F4')] + [('r', 5 * G8)]
out = ['; ---- generated by art/mksound.py - do not edit ----']
for name, items in FX.items():
    out.append('fx_%s:' % name)
    out.append(' db ' + ','.join(str(x) for x in seq(items) + [0xFF]))
total = 0
for lbl, tune in (('mus_title', GENTLE), ('mus_march', TITLE)):
    out.append(lbl + ':')
    data = seq(tune) + [0xFE]
    total += len(data)
    for i in range(0, len(data), 24):
        out.append(' db ' + ','.join(str(x) for x in data[i:i + 24]))
data = [0] * total
open('src/sfx.inc', 'w').write('\n'.join(out) + '\n')
print('sound data:', sum(len(seq(v)) + 1 for v in FX.values()) + len(data), 'bytes')
