"""THE LANTERN DEEP - music and sound effects compiler.

The beeper engine (src/sound.asm) toggles the Microbee speaker (PIO B
bit 6) inside the idle wait for vertical blanking. One loop count of the
tone loop is 40 T-states at 3.375 MHz, so a half period of n counts gives
f = 3375000 / (80 n).

Music: two channels; the engine plays one per frame, alternating, so the
melody and its arpeggio share the speaker like a classic 8-bit tracker.
Each note decays by narrowing its pulse (quieter, thinner) - a 1-bit
volume envelope.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
K = 3375000 / 84.0 / 1.02          # tone loop: 42T per count (+~2% measured overhead)

NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def freq(name):
    n, octv = name[:-1], int(name[-1])
    semis = NAMES.index(n) + 12 * (octv + 1)       # MIDI number
    return 440.0 * 2 ** ((semis - 69) / 12)


NOTES = []           # index 1.. -> half-period count
NOTE_IDX = {}
for octv in range(3, 7):
    for n in NAMES:
        name = '%s%d' % (n, octv)
        c = round(K / freq(name))
        if 6 <= c <= 400:
            NOTE_IDX[name] = len(NOTES) + 1
            NOTES.append(c)


def seq(text, unit):
    """'D4:2 F4 A4:2 -:1' -> [(frames, note)]; duration in units."""
    out = []
    for tok in text.split():
        if ':' in tok:
            n, d = tok.split(':')
            d = float(d)
        else:
            n, d = tok, 1
        frames = int(round(d * unit))
        note = 0 if n == '-' else NOTE_IDX[n]
        while frames > 255:
            out.append((255, note))
            frames -= 255
        out.append((frames, note))
    return out


# ------------------------------------------------------------------ songs
# The Drowned Hall: slow, D minor, a lone melody over a rippling arpeggio
HALL_A = seq('''
D4:2 F4:2 A4:4  G4:3 F4:1 E4:4  F4:2 E4:1 D4:1 C4:2 E4:2  A3:8
D4:2 F4:2 A4:2 D5:2  C5:3 A4:1 G4:4  A4:2 G4:1 F4:1 E4:2 C#4:2  D4:8
-:8
F4:2 G4:2 A4:4  A#4:3 A4:1 G4:4  A4:2 F4:2 D4:2 F4:2  E4:8
D4:2 E4:2 F4:2 A4:2  G4:2 F4:2 E4:2 C#4:2  D4:8  -:8
''', 16)
ARP = {
    'Dm': 'A3 D4 F4 A4 F4 D4 A3 D4',
    'Bb': 'A#3 D4 F4 A#4 F4 D4 A#3 D4',
    'C': 'G3 C4 E4 G4 E4 C4 G3 C4',
    'Am': 'A3 C4 E4 A4 E4 C4 A3 C4',
    'F': 'F3 A3 C4 F4 C4 A3 F3 A3',
    'Gm': 'G3 A#3 D4 G4 D4 A#3 G3 A#3',
    'A': 'A3 C#4 E4 A4 E4 C#4 A3 C#4',
}
HALL_B = seq(' '.join(ARP[c] for c in
                      'Dm Bb C Am Dm C Gm A Dm Dm F Gm F C Bb A Dm Dm'.split()), 8)

# Title: "The Lantern" - wider, more searching, A minor
TITLE_A = seq('''
A4:4 C5:2 E5:2  D5:4 C5:2 B4:2  C5:3 B4:1 A4:2 G4:2  A4:8
E4:2 A4:2 C5:2 E5:2  F5:4 E5:2 D5:2  E5:3 D5:1 C5:2 B4:2  A4:8
F4:2 A4:2 C5:4  G4:2 B4:2 D5:4  E5:2 D5:2 C5:2 B4:2  A4:4 -:4
''', 14)
TARP = {
    'Am': 'A3 E4 A4 C5 A4 E4', 'F': 'F3 C4 F4 A4 F4 C4', 'G': 'G3 D4 G4 B4 G4 D4',
    'E': 'E3 B3 E4 G#4 E4 B3', 'C': 'G3 C4 E4 G4 E4 C4', 'Dm': 'A3 D4 F4 A4 F4 D4',
}
TITLE_B = seq(' '.join(TARP[c] for c in
                       'Am Am F G Am E Am Am Am Am Dm Dm Am G Am E F F G G C E Am Am'.split()), 9.33)


# The Ossuary: a slow processional in E minor, low and hollow
OSS_A = seq("""
E4:4 -:2 G4:2  F#4:4 -:2 E4:2  D4:4 E4:2 F#4:2  B3:8
E4:4 -:2 G4:2  A4:4 G4:2 F#4:2  G4:3 F#4:1 E4:2 D#4:2  E4:8
-:8
B4:4 A4:2 G4:2  A4:4 G4:2 F#4:2  G4:2 F#4:2 E4:2 C4:2  B3:8
""", 20)
OARP = {'Em': 'E3 B3 E3 G3', 'C': 'C3 G3 C3 E3', 'D': 'D3 A3 D3 F#3', 'B': 'B3 F#3 B3 D#4', 'Am': 'A3 E3 A3 C4'}
OSS_B = seq(' '.join(OARP[c] for c in 'Em Em D B Em Am Em B Em Em Em Am D Em C B'.split()), 10)

# The Crystal Caverns: glassy, high, F# minor with a raised sixth
CAV_A = seq("""
C#5:2 E5:2 F#5:2 G#5:2  A5:4 G#5:2 E5:2  F#5:3 E5:1 C#5:2 D#5:2  E5:8
C#5:2 F#5:2 A5:2 C#6:2  B5:4 A5:2 G#5:2  A5:2 G#5:2 F#5:2 D#5:2  F#5:8
-:4 A5:2 G#5:2  F#5:4 E5:4  D#5:2 E5:2 F#5:2 G#5:2  C#5:8
""", 12)
CARP = {'F#m': 'F#4 A4 C#5 F#5 C#5 A4', 'D#': 'D#4 F#4 A4 D#5 A4 F#4', 'E': 'E4 G#4 B4 E5 B4 G#4',
        'A': 'A4 C#5 E5 A5 E5 C#5', 'B': 'B3 D#4 F#4 B4 F#4 D#4'}
CAV_B = seq(' '.join(CARP[c] for c in 'F#m F#m A E F#m F#m D# E F#m A E B F#m D# E F#m'.split()), 6)

# The Ember Halls: a driving ostinato in C minor
EMB_A = seq("""
C4:2 C4:1 D#4:1 F4:2 G4:2  G#4:2 G4:2 F4:2 D#4:2  F4:2 F4:1 G4:1 G#4:2 A#4:2  G4:8
C5:2 A#4:2 G#4:2 G4:2  F4:2 G4:2 G#4:2 F4:2  G4:2 F4:2 D#4:2 D4:2  C4:8
""", 9)
EARP = {'Cm': 'C3 G3 C4 G3', 'Ab': 'G#3 D#4 G#3 C4', 'Bb': 'A#3 F4 A#3 D4', 'G': 'G3 D4 G3 B3', 'Fm': 'F3 C4 F3 G#3'}
EMB_B = seq(' '.join(EARP[c] for c in 'Cm Cm Ab Ab Fm Fm G G Cm Cm Fm Fm Ab Bb G G Cm Cm'.split()), 4)

# The Heart of the Deep: still, chromatic, waiting
HRT_A = seq("""
D4:6 D#4:2  D4:8  -:4 A3:4  G#3:8
D4:4 F4:4  E4:6 D#4:2  D4:8  -:8
A4:4 G#4:4  G4:4 F#4:4  F4:6 E4:2  D4:8 -:8
""", 18)
HARP = {'Dm': 'D3 A3 D4 F4 D4 A3', 'Eb': 'D#3 A#3 D#4 G4 D#4 A#3', 'Bbm': 'A#3 F3 A#3 C#4 A#3 F3',
        'A': 'A3 E3 A3 C#4 A3 E3'}
HRT_B = seq(' '.join(HARP[c] for c in 'Dm Eb Dm A Dm Eb Dm A Bbm A Bbm A Dm Eb Dm A'.split()), 9)

# The ending: the Lantern rekindled, D major
END_A = seq("""
D5:2 F#5:2 A5:4  G5:2 F#5:2 E5:4  F#5:2 A5:2 D6:4  C#6:8
B5:2 A5:2 G5:2 F#5:2  E5:2 F#5:2 G5:2 E5:2  F#5:2 E5:2 D5:2 C#5:2  D5:8
""", 13)
DARP = {'D': 'D4 F#4 A4 D5 A4 F#4', 'G': 'D4 G4 B4 D5 B4 G4', 'A': 'C#4 E4 A4 C#5 A4 E4', 'Bm': 'B3 D4 F#4 B4 F#4 D4'}
END_B = seq(' '.join(DARP[c] for c in 'D D G A D D A A G G A A D A D D'.split()), 8.67)


# ------------------------------------------------------------------ effects
# frame list: ('t', hi, lo) tone half-counts, ('n', mask) noise, ('s',) silence
def tone(n, duty=0.5):
    hi = max(2, int(n * 2 * duty))
    return ('t', hi, 2 * n - hi)


def sweep(n0, n1, frames, duty=0.5):
    return [tone(int(n0 + (n1 - n0) * i / max(1, frames - 1)), duty) for i in range(frames)]


SFX = {
    # footsteps: a low thump, left and right feet a little apart
    'STEP': [tone(350, 0.35), tone(380, 0.2), ('s',)],
    'STEP2': [tone(310, 0.35), tone(340, 0.2), ('s',)],
    'BUMP': [tone(220, 0.3), ('s',)],
    'SWISH': [('n', 15), ('n', 31), ('n', 15), ('n', 7)],
    'HIT': [tone(70), tone(90), ('n', 31), ('n', 15)],
    'KILL': [('n', 63), tone(60), ('n', 63), tone(90), ('n', 31), tone(130, 0.3), ('n', 15)],
    'FIRE': sweep(40, 110, 8, 0.4) + [('n', 31), ('n', 15)],
    'BOOM': [('n', 127), ('n', 127), ('n', 255), ('n', 255), ('n', 127), ('n', 127), ('n', 63), ('n', 63), ('n', 31), ('n', 31), ('n', 15), ('n', 7)],
    'HURT': sweep(110, 200, 6, 0.5) + [('n', 63)],
    'DIE': sweep(90, 250, 30, 0.5) + [('n', 127)] * 6,
    'CHIME': [tone(NOTES[NOTE_IDX['E6'] - 1], d) for d in (0.5, 0.5, 0.4, 0.3, 0.25, 0.2)] +
             [tone(NOTES[NOTE_IDX['B5'] - 1], d) for d in (0.5, 0.4, 0.3, 0.2, 0.15, 0.1)],
    'JINGLE': sum(([tone(NOTES[NOTE_IDX[n] - 1], 0.5)] * 5 for n in ('D5', 'F5', 'A5', 'D6')), []) +
              [tone(NOTES[NOTE_IDX['A5'] - 1], 0.5)] * 3 + [tone(NOTES[NOTE_IDX['D6'] - 1], d) for d in (0.5,) * 8 + (0.4, 0.3, 0.2, 0.15, 0.1)],
    'SELECT': [tone(NOTES[NOTE_IDX['A5'] - 1]), tone(NOTES[NOTE_IDX['E6'] - 1]), ('s',)],
    'MOVE': [tone(NOTES[NOTE_IDX['E5'] - 1], 0.3), ('s',)],
    'UNLOCK': [tone(90, 0.5), ('s',), tone(70, 0.5), ('n', 31), tone(NOTES[NOTE_IDX['D5'] - 1], 0.5), tone(NOTES[NOTE_IDX['A5'] - 1], 0.5), tone(NOTES[NOTE_IDX['A5'] - 1], 0.3)],
    'ROAR': [('n', 255)] * 3 + sweep(250, 380, 10, 0.5) + [('n', 255), ('n', 127), ('n', 255), ('n', 63)],
    'STAIRS': sweep(60, 200, 14, 0.4),
    'BURN': [('n', 63), ('n', 127), ('n', 31), tone(240, 0.3), ('n', 63)],
    'ZAP': sweep(180, 60, 6, 0.3),
    'PLINK': [tone(NOTES[NOTE_IDX['A6'] - 1] if 'A6' in NOTE_IDX else 6, 0.2), tone(NOTES[NOTE_IDX['E6'] - 1], 0.12), ('s',),
              tone(NOTES[NOTE_IDX['E6'] - 1], 0.06)],
}


def emit():
    L = ['; generated by tools/audio.py - do not edit']
    L.append('NOTE_N: DB 0')
    for i, n in enumerate(NOTES):
        L.append('    DW %d' % n) if False else None
    # note table as words (counts may exceed 255)
    L[-1:] = []
    L.append('NOTE_TAB:')
    L.append('    DW 0,' + ','.join(str(n) for n in NOTES))

    def song(label, chan):
        # keep tunes low and warm: a 1-bit square above ~A4 turns shrill
        notes = [n for f, n in chan if n]
        while notes and max(notes) > NOTE_IDX['A#4'] and min(notes) - 12 >= 1:
            chan = [(f, n - 12 if n else 0) for f, n in chan]
            notes = [n - 12 for n in notes]
        L.append(label + ':')
        for i in range(0, len(chan), 8):
            L.append('    DB ' + ','.join('%d,%d' % (f, n) for f, n in chan[i:i + 8]))
        L.append('    DB 0')
    # in the game the tunes are played sparse: each note short and plucked,
    # then silence until the next, and no accompaniment
    def sparse(chan, on=10):
        out = []
        for f, n in chan:
            if n and f > on + 2:
                out += [(on, n), (f - on, 0)]
            else:
                out.append((f, n))
        return out
    song('MUS_HALL_A', sparse(HALL_A))
    # (the title tune is now the three-voice one in tools/tmusic.py; in the
    # game the melodies play alone, so only the ending keeps its second part)
    for nm, a, b in (('OSS', OSS_A, OSS_B), ('CAV', CAV_A, CAV_B), ('EMB', EMB_A, EMB_B), ('HRT', HRT_A, HRT_B),
                     ('END', END_A, END_B)):
        song('MUS_%s_A' % nm, a if nm == 'END' else sparse(a, 12))
        if nm == 'END':
            song('MUS_%s_B' % nm, b)
    names = list(SFX)
    for i, n in enumerate(names):
        L.append('SFX_%s EQU %d' % (n, i))
    L.append('SFX_TAB: DW ' + ','.join('sfx_%s' % n.lower() for n in names))
    for n in names:
        b = []
        for fr in SFX[n]:
            if fr[0] == 't':
                hi, lo = fr[1], fr[2]
                lo1 = min(lo, 255)
                lo2 = lo - lo1
                b += [1, min(hi, 255), lo1, lo2]
            elif fr[0] == 'n':
                b += [2, fr[1], 0, 0]
            else:
                b += [3, 0, 0, 0]
        b += [0]
        L.append('sfx_%s:' % n.lower())
        for i in range(0, len(b), 32):
            L.append('    DB ' + ','.join(str(x) for x in b[i:i + 32]))
    (ROOT / 'src' / 'gen' / 'audio.asm').write_text('\n'.join(L) + '\n')
    print('notes %d (%s..%s), hall %d+%d events, title %d+%d' % (len(NOTES), min(NOTES), max(NOTES),
          len(HALL_A), len(HALL_B), len(TITLE_A), len(TITLE_B)))


if __name__ == '__main__':
    emit()
