"""music.py - songs and sound effects for OVERRIDE (one 8253 square voice).

Songs are tracker-style: each row lasts `speed` ticks (50 Hz) and holds a
lead note, a bass note, a drum and an effect.  The player gives the voice
to the drum, then a short bass pluck, then the lead (see src/sound.asm).

Tokens in the pattern strings, one per row (16th note):
    A4 C#5 ...  note        -   hold        .   off
Drums: k kick, s snare, h hat, . none.   Effects per row: 0-3 arpeggio,
4 = lead/bass alternate.
"""
CLOCK = 1108800
NOTE_BASE = 20                      # NOTETAB index = midi - NOTE_BASE

NAMES = {'C': 0, 'C#': 1, 'DB': 1, 'D': 2, 'D#': 3, 'EB': 3, 'E': 4, 'F': 5, 'F#': 6, 'GB': 6,
         'G': 7, 'G#': 8, 'AB': 8, 'A': 9, 'A#': 10, 'BB': 10, 'B': 11}


def midi(tok):
    tok = tok.upper()
    n, o = tok[:-1], int(tok[-1])
    return NAMES[n] + 12 * (o + 1)


def notetab():
    vals = []
    for i in range(128):
        m = i + NOTE_BASE
        f = 440.0 * 2 ** ((m - 69) / 12)
        d = round(CLOCK / f)
        vals.append(max(2, min(65535, d)))
    vals[0] = 0
    return vals


def note_byte(tok):
    if tok == '-':
        return 0
    if tok == '.':
        return 1
    idx = midi(tok) - NOTE_BASE
    assert 1 <= idx < 127, tok
    return idx + 1


DRUM = {'.': 0, 'k': 1, 's': 2, 'h': 3}


def pattern(lead, bass, drums, fx=None):
    L = lead.split()
    B = bass.split()
    D = drums.split() if ' ' in drums.strip() else list(drums.replace(' ', ''))
    n = len(L)
    assert len(B) == n and len(D) == n, (len(L), len(B), len(D), lead[:30])
    F = [0] * n if fx is None else (fx if isinstance(fx, list) else [fx] * n)
    out = []
    for i in range(n):
        out += [note_byte(L[i]), note_byte(B[i]), DRUM[D[i]], F[i]]
    return out + [0xFF]


# ------------------------------------------------------------------ title
def bass_bar(root, fifth=None, style=0):
    """16 rows of bass: root on beats, octave/fifth pickups"""
    r1 = root
    r2 = root[:-1] + str(int(root[-1]) + 1)
    if style == 0:
        return '%s - %s - %s - %s - %s - %s - %s - %s -' % (r1, r2, r1, r2, r1, r2, r1, r2)
    return '%s - - %s - - %s - %s - - %s - - %s -' % (r1, r1, r2, r1, r1, r2)


DR_A = 'k . h . s . h . k . h k s . h .'
DR_B = 'k . h . s . h . k . k . s . s s'
DR_C = 'k . . . s . . . k . . . s . . .'

TITLE_BARS = [
    # verse (lead, bass root, drums)
    ('E5 - - - A5 - - - G5 - E5 - D5 - C5 -', 'A2', DR_C),
    ('C5 - - - F5 - - - E5 - C5 - A4 - - -', 'F2', DR_C),
    ('G4 - - - C5 - - - E5 - G5 - E5 - C5 -', 'C3', DR_C),
    ('D5 - - - B4 - - - G4 - - - B4 - D5 -', 'G2', DR_B),
    ('E5 - - - A5 - - - B5 - C6 - B5 - A5 -', 'A2', DR_A),
    ('A5 - - - F5 - - - C5 - F5 - A5 - C6 -', 'F2', DR_A),
    ('B5 - - - G5 - - - D5 - G5 - B5 - D6 -', 'G2', DR_A),
    ('E6 - - - - - - - B5 - G#5 - E5 - D5 -', 'E2', DR_B),
    # bridge
    ('D5 - - F5 - - A5 - G5 - F5 - E5 - D5 -', 'D3', DR_A),
    ('C5 - - E5 - - A5 - G5 - E5 - C5 - - -', 'A2', DR_A),
    ('D5 - - F5 - - A5 - C6 - B5 - A5 - - -', 'D3', DR_A),
    ('G#5 - - - E5 - - - B4 - - - E5 - - -', 'E2', DR_B),
    ('F5 - - - A5 - - - C6 - - - A5 - F5 -', 'F2', DR_A),
    ('G5 - - - B5 - - - D6 - - - B5 - G5 -', 'G2', DR_A),
    ('A5 - - - - - - - E5 - - - C5 - - -', 'A2', DR_A),
    ('A4 - - - . . . . E5 - D5 - C5 - B4 -', 'E2', DR_B),
]


def title_song():
    pats = []
    for i, (lead, root, dr) in enumerate(TITLE_BARS):
        style = 0 if i < 4 or i >= 8 else 1
        # shimmer: an octave arpeggio on the tail of long held notes
        toks = lead.split()
        fx = [0] * 16
        run = 0
        for k, tok in enumerate(toks):
            run = run + 1 if tok == '-' else 0
            if run >= 2:
                fx[k] = 3
        pats.append(pattern(lead, bass_bar(root, style=style), dr, fx))
    return dict(speed=6, pats=pats, loop=True)


# intro: four bars of bass and drums with chord arpeggio stabs
def title_intro():
    pats = []
    for root, chord in (('A2', 'A4'), ('F2', 'F4'), ('C3', 'C5'), ('E2', 'E4')):
        lead = '%s - - - - - - - %s - - - - - - -' % (chord, chord)
        fx = [2 if root in ('A2', 'E2') else 1] * 16
        if root == 'E2':
            fx = [1] * 16
        pats.append(pattern(lead, bass_bar(root, style=1), DR_C, fx))
    return pats


# ------------------------------------------------------------------ jingles
def jingle(lead, bass, drums, speed=5, fx=None):
    return dict(speed=speed, pats=[pattern(lead, bass, drums, fx)], loop=False)


SONGS = {}


def build_songs():
    t = title_song()
    t['pats'] = title_intro() + t['pats']
    t['loop_from'] = 4
    SONGS['SONG_TITLE'] = t
    SONGS['SONG_BOARD'] = jingle(
        'A4 - - C5 E5 - - A5 G5 - E5 - D5 - E5 - - - - - - - . . A4 - C5 - E5 - A5 - - - - - - - .',
        'A2 - - - A2 - - - G2 - - - G2 - - - A2 - - - A2 - - - F2 - - - E2 - - - A1 - - - - - .',
        'k . h . s . h . k . h . s . h . k . h . s . h . k . h . s . s s k . . . . . .', speed=5)
    SONGS['SONG_CLEAR'] = jingle('C5 - E5 - G5 - C6 - - - G5 - C6 - - - .',
                                 'C3 - - - - - - - - - - - C3 - - - .',
                                 'k . . . s . . . k . . . s . . . .', speed=4)
    SONGS['SONG_XFER'] = dict(speed=4, pats=[pattern(
        'A4 - C5 - A4 - C5 - A4 - D#5 - A4 - D#5 -',
        'A2 - - - A2 - - - A2 - - - A2 - - -',
        'k . h . k . h . k . h . k . h .')], loop=True)
    SONGS['SONG_WIN'] = jingle('C5 - E5 - G5 - C6 - E6 - G6 - - - - - .',
                               'C3 - - - G2 - - - C3 - - - - - - - .',
                               'k . . . . . . . k . . . s . . . .', speed=4, fx=[0] * 12 + [1] * 5)
    SONGS['SONG_LOSE'] = jingle('E5 - D#5 - D5 - C#5 - C5 - - - - - .',
                                'A2 - - - G#2 - - - A2 - - - - - .',
                                'k . . . . . . . s . . . . . .', speed=6)
    SONGS['SONG_GAMEOVER'] = jingle(
        'A4 - - - G4 - - - F4 - - - E4 - - - D4 - - - E4 - - - A3 - - - - - - - .',
        'A2 - - - G2 - - - F2 - - - E2 - - - D2 - - - E2 - - - A1 - - - - - - - .',
        'k . . . s . . . k . . . s . . . k . . . s . . . k . . . . . . . .', speed=8)
    SONGS['SONG_SHIP'] = jingle(
        'A4 - C5 - E5 - A5 - G5 - E5 - C5 - E5 - G5 - B5 - D6 - B5 - A5 - - - - - - - .',
        'A2 - - - A2 - - - C3 - - - C3 - - - G2 - - - G2 - - - A2 - - - - - - - .',
        'k . h . s . h . k . h . s . h . k . h . s . h . k . . . s . . . .', speed=5)
    SONGS['SONG_VICTORY'] = dict(speed=5, loop=False, pats=[
        pattern('C5 - - - E5 - - - G5 - - - C6 - - - B5 - - - G5 - - - D6 - - - B5 - - -',
                'C3 - - - C3 - - - C3 - - - C3 - - - G2 - - - G2 - - - G2 - - - G2 - - -',
                'k . h . s . h . k . h . s . h . k . h . s . h . k . h . s . h .'),
        pattern('A5 - - - F5 - - - C6 - - - A5 - - - G5 - - - E5 - - - C6 - - - - - - - .',
                'F2 - - - F2 - - - F2 - - - F2 - - - C3 - - - C3 - - - C3 - - - - - - - .',
                'k . h . s . h . k . h . s . h . k . h . s . h . k . . . s . . . .',
                [0] * 24 + [1] * 9),
    ])


# ------------------------------------------------------------------ effects
REST = 0xFE00


def div(f):
    return max(2, min(0xFDFF, round(CLOCK / f)))


def noise(band):
    return 0xFF00 | band


def sweep(f0, f1, ticks):
    return [div(f0 * (f1 / f0) ** (i / max(1, ticks - 1))) for i in range(ticks)]


SFX = {
    'SFX_ZAP': sweep(2200, 700, 5),
    'SFX_CANNON': [noise(1), noise(2)] + sweep(500, 90, 5),
    'SFX_EZAP': sweep(1300, 450, 4),
    'SFX_HIT': [noise(0), div(330), noise(1)],
    'SFX_PHIT': [noise(2), div(180), noise(3), div(120)],
    'SFX_BOOM': [noise(1), noise(1), noise(2), noise(2), noise(3), noise(3), noise(4), REST,
                 noise(5), REST, noise(6), REST, REST, noise(7)],
    'SFX_DEATH': [x if i % 3 else noise(2 + i // 8) for i, x in enumerate(sweep(900, 40, 40))],
    'SFX_XMODE': sweep(300, 1600, 7),
    'SFX_BUMP': [noise(3), noise(4), div(90)],
    'SFX_DOOR': [noise(0), REST, noise(0)],
    'SFX_CHARGE': [div(900), div(1350)],
    'SFX_ALARM': [div(1500), div(1500), div(1500), REST, div(1100), div(1100)],
    'SFX_TAKEOVER': [div(523), div(523), div(659), div(659), div(784), div(784), div(1047), div(1047),
                     div(1319), div(1568), div(2093), div(2093)],
    'SFX_LIFT': sweep(150, 700, 14),
    'SFX_CONSOLE': [div(2000), REST, div(1500), REST, div(2500), REST, div(1800)],
    'SFX_CLICK': [div(3000)],
    'SFX_PULSE': sweep(600, 2000, 4),
    'SFX_EPULSE': sweep(400, 1100, 4),
    'SFX_BUZZ': [div(110)] * 4,
    'SFX_FLIP': [div(2400), div(1800)],
    'SFX_TICK': [div(1000)],
}


def gen_asm():
    build_songs()
    out = ['; generated by tools/music.py']
    for name, s in SONGS.items():
        out.append('%s:' % name)
        out.append('        db %d' % s['speed'])
        names = ['%s_p%d' % (name, i) for i in range(len(s['pats']))]
        if s.get('loop_from'):
            # play the intro once, then loop the rest
            out.append('        dw ' + ','.join(names[:s['loop_from']]))
            out.append('%s_loop:' % name)
            out.append('        dw ' + ','.join(names[s['loop_from']:]))
            out.append('        dw 0FFFFh, %s_loop' % name)
        else:
            out.append('        dw ' + ','.join(names))
            out.append('        dw %d' % (0 if s['loop'] else 1))
        for n, p in zip(names, s['pats']):
            out.append('%s:' % n)
            for i in range(0, len(p), 16):
                out.append('        db ' + ','.join('%d' % v for v in p[i:i + 16]))
    for name, words in SFX.items():
        out.append('%s:' % name)
        out.append('        dw ' + ','.join('%d' % w for w in words) + ',0')
    return '\n'.join(out) + '\n'
