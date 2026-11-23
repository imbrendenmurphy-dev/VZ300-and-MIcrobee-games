"""RUNE AMOK music and sound effects -> build/snd.inc

All tunes are original. Each level has its own mode and pulse:
  title        D minor march         "The Runedeep"
  gatehouse    A aeolian, steady     torchlit stone
  grotto       E phrygian, sparse    dripping water, slow
  archive      D dorian waltz        harpsichord arpeggios
  ember        C minor, driving      the throne room
  dirge, victory: short pieces
Notation: 'D5:4' = D in octave 5 for 4 steps ('r' = rest); a step is
`unit` frames. Bass lines are written the same way; drums: k s h r.
The melody is quieter than the effects by its duty (see sound.asm).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RATE = 3375000 / 216.0
NAMES = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6, 'G': 7,
         'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
LOWEST = 24   # C2 = note 1 (MIDI 36 = C2)


def midi(n):
    name, octv = n[:-1], int(n[-1])
    return 12 * (octv + 1) + NAMES[name]


def note_index(n):
    return midi(n) - 36 + 1


def steps():
    out = []
    for i in range(1, 61):
        m = 36 + i - 1
        f = 440.0 * 2 ** ((m - 69) / 12.0)
        out.append(int(round(f * 65536 / RATE)))
    return out


def seq(text, unit, loop=True):
    b = []
    for tok in text.split():
        n, l = tok.split(':')
        frames = int(float(l) * unit)
        while frames > 250:
            b += [0 if n == 'r' else note_index(n), 250]
            frames -= 250
        b += [0 if n == 'r' else note_index(n), frames]
    b.append(0xFE if loop else 0xFF)
    return b


def drums(text, unit, loop=True):
    m = {'k': 1, 's': 2, 'h': 3, 'r': 0, 't': 4}
    b = []
    for tok in text.split():
        n, l = tok.split(':')
        b += [m[n], int(float(l) * unit)]
    b.append(0xFE if loop else 0xFF)
    return b


def rep(s, n):
    return ' '.join([s] * n)


def bass_bar(root, fifth, n=1, pat='rfor'):
    """an eighth-note bass bar: root fifth octave fifth"""
    hi = root[:-1] + str(int(root[-1]) + 1)
    p = {'r': root, 'f': fifth, 'o': hi}
    return ' '.join('%s:2' % p[c] for c in pat * 2) if n == 1 else ' '.join([bass_bar(root, fifth, 1, pat)] * n)


TUNES = {}

# ---- the title: D minor march, unit 6 frames (a sixteenth)
TUNES['mus_title'] = dict(unit=6, duty=64, mel="""
D5:4 A4:4 F4:4 A4:4  G4:2 A4:2 Bb4:4 A4:4 G4:4  F4:4 E4:2 F4:2 G4:4 E4:4  D4:12 r:4
D5:4 A4:4 F4:4 A4:4  Bb4:2 C5:2 D5:4 C5:4 Bb4:4  A4:4 G4:2 A4:2 Bb4:4 C#5:4  D5:12 r:4
F5:4 E5:2 D5:2 C5:4 A4:4  Bb4:4 A4:2 G4:2 F4:4 D4:4  G4:4 F4:2 E4:2 F4:4 A4:4  E4:12 r:4
F5:4 E5:2 D5:2 C5:4 A4:4  Bb4:2 C5:2 D5:4 G4:4 Bb4:4  A4:4 F4:2 E4:2 E4:4 C#4:4  D4:12 r:4
""", bass=' '.join(bass_bar(r, f) for r, f in [
    ('D2', 'A2'), ('G2', 'D3'), ('C2', 'G2'), ('D2', 'A2'), ('D2', 'A2'), ('Bb2', 'F2'), ('A2', 'E2'), ('D2', 'A2'),
    ('F2', 'C3'), ('Bb2', 'F2'), ('C2', 'G2'), ('A2', 'E2'), ('F2', 'C3'), ('G2', 'D3'), ('A2', 'E2'), ('D2', 'A2')]),
    dr=rep('k:4 h:2 h:2 s:4 h:2 h:2', 16))

# ---- level 1, the Gatehouse: A aeolian, unit 7
TUNES['mus_l1'] = dict(unit=7, duty=56, mel="""
A4:8 C5:4 B4:4  A4:6 E4:2 A4:8  G4:4 F4:4 E4:4 D4:4  E4:16
A4:8 C5:4 D5:4  E5:6 D5:2 C5:8  B4:4 G4:4 A4:4 B4:4  A4:16
r:4 E5:4 D5:4 C5:4  D5:6 C5:2 B4:8  r:4 C5:4 B4:4 A4:4  B4:6 A4:2 G#4:8
A4:4 E4:4 A4:4 C5:4  B4:4 A4:4 G#4:4 E4:4  F4:4 D4:4 E4:4 G#4:4  A4:16
""", bass=' '.join('%s:4 %s:4 %s:4 %s:4' % (a, b, a, b) for a, b in [
    ('A2', 'E3'), ('A2', 'E3'), ('D2', 'A2'), ('E2', 'B2'), ('A2', 'E3'), ('C3', 'G2'), ('G2', 'D3'), ('A2', 'E3'),
    ('C3', 'G2'), ('G2', 'D3'), ('F2', 'C3'), ('E2', 'B2'), ('A2', 'E3'), ('E2', 'B2'), ('D2', 'A2'), ('A2', 'E3')]),
    dr=rep('k:8 r:8 h:8 r:8', 8) + ' ' + rep('k:8 h:8 s:8 h:8', 8))

# ---- level 2, the Grotto: E phrygian, sparse drips, unit 8
TUNES['mus_l2'] = dict(unit=8, duty=48, mel="""
E5:2 r:6 F5:2 r:6  G5:2 r:2 F5:2 r:2 E5:8  B4:2 r:6 C5:2 r:6  D5:2 r:2 C5:2 r:2 B4:8
E5:2 r:2 G5:2 r:2 B5:4 A5:4  G5:2 F5:2 E5:4 r:8  C5:2 r:2 D5:2 r:2 E5:4 F5:4  E5:16
""", bass=rep('E2:4 r:4 E2:4 F2:4', 4) + ' ' + rep('C2:4 r:4 C2:4 D2:4', 2) + ' ' + rep('E2:4 r:4 B2:4 F2:4', 2),
    dr=rep('r:12 t:4', 16))

# ---- level 3, the Archive: D dorian waltz (3/4), unit 6
TUNES['mus_l3'] = dict(unit=6, duty=60, mel="""
D5:4 F5:4 A5:4  G5:6 F5:2 E5:4  D5:4 C5:4 A4:4  B4:12
C5:4 E5:4 G5:4  F5:6 E5:2 D5:4  C5:4 A4:4 B4:4  D5:12
A5:4 G5:4 F5:4  E5:4 D5:4 C5:4  B4:4 C5:4 D5:4  E5:12
F5:4 E5:4 D5:4  C5:4 B4:4 A4:4  B4:6 C5:2 A4:4  D5:12
""", bass=' '.join('%s:4 %s:4 %s:4' % (a, b, b) for a, b in [
    ('D3', 'A3'), ('G2', 'D3'), ('D3', 'A3'), ('G2', 'B2'), ('C3', 'G3'), ('D3', 'A3'), ('A2', 'E3'), ('D3', 'A3'),
    ('F2', 'C3'), ('C3', 'G3'), ('G2', 'D3'), ('A2', 'E3'), ('D3', 'A3'), ('A2', 'E3'), ('G2', 'D3'), ('D3', 'A3')]),
    dr=rep('h:4 r:8', 16))

# ---- level 4, the Ember Throne: C minor, driving, unit 5
TUNES['mus_l4'] = dict(unit=5, duty=64, mel="""
C5:2 r:2 Eb5:2 r:2 G5:4 F5:4  Eb5:2 D5:2 C5:4 Bb4:4 C5:4  Ab4:4 Bb4:2 C5:2 D5:4 Eb5:4  D5:12 r:4
C5:2 r:2 Eb5:2 r:2 G5:4 Ab5:4  G5:2 F5:2 Eb5:4 D5:4 Eb5:4  F5:4 Eb5:2 D5:2 C5:4 B4:4  C5:12 r:4
""", bass=' '.join(bass_bar(r, f, 1, 'rrfr') for r, f in [
    ('C2', 'G2'), ('C2', 'G2'), ('Ab2', 'Eb2'), ('G2', 'D2'), ('C2', 'G2'), ('C2', 'G2'), ('F2', 'C2'), ('G2', 'D2')]),
    dr=rep('k:2 h:2 h:2 h:2 s:2 h:2 k:2 h:2', 8))

TUNES['mus_dirge'] = dict(unit=9, duty=52, loop=False, mel="D4:6 C4:6 Bb3:6 A3:12 r:2 D4:4 E4:4 F4:4 E4:8 D4:16",
                          bass="D2:12 F2:12 G2:12 A2:12 D2:20", dr="k:12 r:12 k:12 r:12 k:20")
TUNES['mus_victory'] = dict(unit=6, duty=72, loop=False,
                            mel="D4:2 F#4:2 A4:2 D5:6 A4:2 D5:8 E5:4 F#5:4 G5:4 A5:12 r:2 F#5:2 G5:2 A5:2 D6:16",
                            bass="D2:4 A2:4 D3:8 A2:8 D2:4 E2:4 G2:4 A2:12 D2:6 A2:6 D2:16",
                            dr="k:4 h:4 s:4 h:4 k:4 h:4 s:4 h:4 k:4 s:4 k:4 s:4 k:16")


# ---------------------------------------------------------------------
# effects: (frames, duty (or 0x80|mask for noise), step Hz, glide Hz/frame)
def hz(f):
    return int(round(f * 65536 / RATE)) & 0xFFFF


def fx(*entries):
    b = []
    for fr, duty, f, g in entries:
        if not duty & 0x80 or duty == 128:
            duty = min(duty, 120)       # bit 7 means noise: a tone stays below it
        b += [fr, duty]
        s = hz(f)
        gl = int(round(g * 65536 / RATE)) & 0xFFFF
        b += [s & 255, s >> 8, gl & 255, gl >> 8]
    b.append(0)
    return b


N = 0x80 | 0x40        # noise, full
SFX = {
    'sfx_step': fx((2, N, 2500, -800), (2, 40, 90, -20)),
    'sfx_turn': fx((2, N, 6000, -2000)),
    'sfx_bump': fx((2, 120, 150, -20), (2, N, 1500, 0)),
    'sfx_door': fx((3, 96, 180, 40), (5, 80, 300, -25), (4, N, 900, 0)),
    'sfx_unlock': fx((2, 128, 1200, 0), (2, 128, 1600, 0), (6, 100, 300, -20)),
    'sfx_swing': fx((5, N, 9000, -1200)),
    'sfx_hit': fx((2, N, 5000, -800), (4, 128, 160, -25)),
    'sfx_kill': fx((3, N, 4000, -600), (8, 120, 330, -20), (4, N, 1200, -200)),
    'sfx_hurt': fx((3, 120, 220, -15), (3, N, 2000, 0), (4, 120, 160, -10)),
    'sfx_coin': fx((3, 128, 1975, 0), (6, 112, 2637, 0)),
    'sfx_pickup': fx((3, 128, 880, 60), (4, 128, 1320, 0)),
    'sfx_fanfare': fx((4, 128, 523, 0), (4, 128, 659, 0), (4, 128, 784, 0), (10, 120, 1047, 0)),
    'sfx_sigil': fx((3, 128, 784, 0), (3, 128, 988, 0), (3, 128, 1175, 0), (3, 128, 1568, 0), (12, 112, 1568, -40)),
    'sfx_levelup': fx((4, 128, 392, 0), (4, 128, 523, 0), (4, 128, 659, 0), (4, 128, 784, 0), (12, 120, 1047, 8)),
    'sfx_lever': fx((2, N, 500, 0), (4, 128, 140, -15), (3, N, 1200, 0)),
    'sfx_gate': fx((10, 96, 130, 6), (6, N, 900, 0)),
    'sfx_rune': fx((3, 112, 660, 90), (8, 100, 1320, -20)),
    'sfx_wrong': fx((6, 128, 220, -12), (8, 128, 150, -8)),
    'sfx_heal': fx((3, 112, 523, 40), (3, 112, 784, 40), (8, 100, 1047, 20)),
    'sfx_fire': fx((4, N, 3000, 1200), (6, 120, 300, 80), (6, N, 8000, -1000)),
    'sfx_stairs': fx((3, 128, 400, -30), (3, 128, 300, -30), (3, 128, 200, -20), (6, N, 500, 0)),
    'sfx_fall': fx((20, 120, 900, -40), (6, N, 400, 0)),
    'sfx_portal': fx((16, 100, 300, 70), (8, 90, 1400, -60)),
    'sfx_spin': fx((10, 100, 400, 60), (10, 100, 1000, -60)),
}
DRUMS = [
    fx((1, 120, 220, -60), (2, 120, 130, -25)),           # kick
    fx((3, N, 9000, -1500)),                               # snare
    fx((2, 0x80 | 0x40, 12000, 0)),                        # hat
    fx((2, 128, 2400, -500)),                              # drip (tick)
]


def dbs(b, per=16):
    return '\n'.join('\tdb ' + ','.join(str(x) for x in b[i:i + per]) for i in range(0, len(b), per))


def main():
    L = ['; generated by tools/mkmusic.py', 'NOTETAB:', '\tdw ' + ','.join(str(s) for s in steps())]
    total = 0
    for name, t in TUNES.items():
        loop = t.get('loop', True)
        m = seq(t['mel'], t['unit'], loop)
        b = seq(t['bass'], t['unit'], loop)
        d = drums(t['dr'], t['unit'], loop)
        tm, tb, td = sum(m[1::2][:len(m) // 2]), sum(b[1::2][:len(b) // 2]), sum(d[1::2][:len(d) // 2])
        if loop and not (tm == tb == td):
            print('  %s: lengths differ (mel %d, bass %d, drums %d frames)' % (name, tm, tb, td))
        L.append('%s:\n\tdw %s_m, %s_b, %s_d\n\tdb %d' % (name, name, name, name, t['duty']))
        L.append('%s_m:\n%s' % (name, dbs(m)))
        L.append('%s_b:\n%s' % (name, dbs(b)))
        L.append('%s_d:\n%s' % (name, dbs(d)))
        total += len(m) + len(b) + len(d)
    for name, b in SFX.items():
        L.append('%s:\n%s' % (name, dbs(b)))
        total += len(b)
    L.append('drum_tab:\tdw drum_1, drum_2, drum_3, drum_4')
    for i, b in enumerate(DRUMS, 1):
        L.append('drum_%d:\n%s' % (i, dbs(b)))
    (ROOT / 'build' / 'snd.inc').write_text('\n'.join(L) + '\n')
    print('music and effects: %d bytes' % total)


if __name__ == '__main__':
    main()
