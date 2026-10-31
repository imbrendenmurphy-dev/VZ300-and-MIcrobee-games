"""Music + sound effects for THE FORGOTTEN DEPTHS.

Sound engine (sound.asm): three pulse voices interleaved like the Cybernoid
VZ player, 184 T per round (19.3 kHz), plus a drum stream that fires short
noise / thump bursts.  Voice A lead, B harmony (shared with sound effects),
C bass.  Pulse width = loudness; each note's width decays every frame, so
notes stay separate (detached, "blippy").

Channel stream bytes:
   1..95  note (semitone, 1 = C1) followed by duration (frames)
   0      rest, followed by duration
   $FE p d f   instrument: start width p, decay d per frame, floor f
   $FF    loop to stream start
Drum stream: (drum, frames) pairs; drum = type<<6 | n
   type 1 kick (n half-cycles of a falling thump), 2 snare (n*4 noise
   samples), 3 hat (n*2 noise samples); 0 = rest.

In-game tracks use thin pulses and the lower octaves: the game logic takes
part of every frame, and thin pulses make that gap far less audible.
"""
CLK = 3546900
LOOPT = 184
RATE = CLK / LOOPT

NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
        'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def n(s):
    name, octv = s[:-1], int(s[-1])
    return (octv - 1) * 12 + NOTE[name] + 1


def freq(num):
    return 440.0 * 2 ** ((num - n('A4')) / 12)


def inc_table():
    return [int(round(freq(i) * 65536 / RATE)) if i else 0 for i in range(96)]


def seq(spec, dur):
    """'D4 F4 A4 - C5' -> stream; '-' = rest; 'x:k' = k*dur"""
    out = []
    for tok in spec.split():
        k = 1
        if ':' in tok:
            tok, k = tok.split(':')
            k = int(k)
        d = dur * k
        while d > 0:
            dd = min(d, 250)
            out += [0 if tok == '-' else n(tok), dd]
            d -= dd
    return out


def ins(p, d, f=0):
    return [0xFE, p, d, f]


KICK, SNARE, HAT = 0x40 | 4, 0x80 | 24, 0xC0 | 10
KICKS, SNARES, HATS = 0x40 | 3, 0x80 | 12, 0xC0 | 5      # soft (in game)


def drums(spec, dur):
    """'K . H . S . H .' ; k/s/h = soft versions; '.' rest"""
    m = {'K': KICK, 'S': SNARE, 'H': HAT, 'k': KICKS, 's': SNARES, 'h': HATS, '.': 0}
    out = []
    for t in spec.split():
        out += [m[t], dur]
    return out + [0xFF]


def rep(spec, k):
    return ' '.join([spec] * k)


SILENT = [0, 250, 0xFF]

# ================================================================ front end (full frame: richer)
# TITLE - A minor, gritty and driving; lead stays below A5.
u = 6
title_a = (ins(128, 6, 52) +
           seq('A3 - A3 C4 - A3 G3 -  E3 - G3 A3 - - - -  A3 - A3 C4 - D4 E4 -  D4 C4 A3 G3 A3 - - -', u) +
           seq('E4 - E4 D4 - C4 D4 -  C4 A3 G3 E3 G3 - - -  A3 - C4 - E4 - D4 C4  A3 - G3 - A3 - - -', u) + [0xFF])
title_b = (ins(64, 4, 36) +
           seq(rep('A3 C4 E4 C4', 2) + ' ' + rep('G3 B3 D4 B3', 2) + ' ' + rep('F3 A3 C4 A3', 2) + ' ' +
               rep('E3 G#3 B3 G#3', 2), u) + [0xFF])
title_c = (ins(128, 4, 88) +
           seq(' '.join(rep(f'{r}2 - {r}2 {r}3 - {r}2 {r}3 {r}2', 1) for r in 'AGFE'), u) + [0xFF])
title_d = drums('K . H K S . H . K . H K S . H H', u)

# ENDING - A major, broad and bright
u = 8
end_a = (ins(128, 4, 52) + seq('A4:2 C#5:2 E5:2 A5:4 -  G#5 F#5:2 E5:2 F#5:2 E5:4 - -  D5:2 C#5:2 B4:2 C#5:2 D5:2 E5:2 A4:4 -:2 -:2', u) + [0xFF])
end_b = (ins(64, 3, 36) + seq(rep('A3 C#4 E4 C#4', 4) + ' ' + rep('D3 F#3 A3 F#3', 2) + ' ' + rep('E3 G#3 B3 G#3', 2), u // 2) + [0xFF])
end_c = (ins(128, 3, 88) + seq('A2:4 E2:4 F#2:4 C#2:4 D2:4 A2:4 E2:4 A2:4', u) + [0xFF])
end_d = drums('K . H . S . H . K . H K S . H .', u)

# BOSS (in game, but it should bite): E minor, short notes, soft drums
u = 4
boss_a = (ins(112, 7, 48) + seq('E4 - E4 G4 - E4 A#4 A4  G4 - E4 - D4 - E4 -  E4 - E4 G4 - E4 B4 A#4  A4 G4 F#4 G4 A4 - B4 -', u) + [0xFF])
boss_b = SILENT
boss_c = (ins(112, 4, 72) + seq(rep('E2 E2 E3 E2', 4) + ' ' + rep('D2 D2 D3 D2', 2) + ' ' + rep('C2 C2 C3 C2', 2), u) + [0xFF])
boss_d = drums('k . h . s . h . k k h . s . h h', u)

# ================================================================ in game (thin, low, detached)
# TEMPLE - D dorian, slow and ceremonial
u = 8
temple_a = (ins(100, 5, 40) + seq('D4 - F4 - A4 - - -  G4 - F4 - E4 - D4 -  C4 - E4 - G4 - - -  A4 - G4 - E4 - - -', u) + [0xFF])
temple_b = (ins(56, 3, 0) + seq('- - - - D5 - - -  - - - - A4 - - -  - - - - G4 - - -  - - - - C#5 - - -', u) + [0xFF])
temple_c = (ins(100, 3, 56) + seq('D2:8 C2:8 A1:8 A1:4 C#2:4', u) + [0xFF])
temple_d = [0, 250, 0xFF]
# CAVE - drips over a hollow pulse
u = 6
cave_a = (ins(96, 5, 0) + seq('E4 -:5 B3 -:7 G4 -:3 F#4 -:9 E4 -:2 D4 -:6 B3 -:4 A3:2 -:8', u) + [0xFF])
cave_b = (ins(48, 3, 0) + seq('- B4 -:15 - E5 -:15', u) + [0xFF])
cave_c = (ins(96, 2, 56) + seq('E2:16 C2:16 D2:16 B1:16', u) + [0xFF])
cave_d = drums('h . . . . . . . . . . . . . . .', u * 2)
# CRYPT - tolling bell, chromatic descent
u = 6
crypt_a = (ins(104, 3, 0) + seq('A3:4 -:4 G#3:4 -:4 G3:4 -:4 F#3:2 F3:2 E3:8  C4:4 -:4 B3:4 -:4 A#3:4 -:4 A3:8 -:4', u) + [0xFF])
crypt_b = SILENT
crypt_c = (ins(100, 2, 56) + seq('A1:16 G#1:16 G1:16 E1:12', u) + [0xFF])
crypt_d = [0, 250, 0xFF]
# DROWNED CITY - E minor arpeggios, watery
u = 6
city_a = (ins(96, 6, 36) + seq('E4 G4 B4 - - B4 G4 -  D4 F#4 A4 - - A4 F#4 -  C4 E4 G4 - - G4 E4 -  B3 D#4 F#4 - B3:2 -:2', u) + [0xFF])
city_b = SILENT
city_c = (ins(96, 3, 56) + seq('E2:8 D2:8 C2:8 B1:8', u) + [0xFF])
city_d = drums('h . . . . . . . h . . . . . . .', u)
tide_a = (ins(100, 3, 40) + seq('B3:3 -:3 A3 G3 F#3:4 -:4 E3:3 -:3 G3 A3 B3:6 -:6  D4:3 -:3 C4 B3 A3:4 -:4 G3:3 F#3:3 E3:8 -:4', u + 2) + [0xFF])
tide_b = (ins(48, 3, 0) + seq('- - - - E5 - - - - - - - B4 - - -', u + 2) + [0xFF])
tide_c = (ins(96, 2, 56) + seq('E2:12 C2:12 D2:12 B1:12', u + 2) + [0xFF])
tide_d = [0, 250, 0xFF]
# EMBER CORE - driving low riff
u = 6
volcano_a = (ins(104, 7, 40) + seq('A3 A3 C4 A3 D#4 A3 D4 C4 A3 A3 C4 A3 D#4 A3 D4 C4  G3 G3 A#3 G3 C#4 G3 C4 A#3 G3 G3 A#3 G3 E4 D#4 D4 C#4', u) + [0xFF])
volcano_b = SILENT
volcano_c = (ins(112, 4, 64) + seq('A1:4 A1:4 G1:4 G1:4', u * 2) + [0xFF])
volcano_d = drums('k . . . s . . . k . k . s . . .', u)
core_a = (ins(100, 5, 40) + seq('E4:2 F4:2 E4:2 -:2 D#4:2 E4:2 -:4 B3:2 C4:2 B3:2 -:2 A#3:2 B3:2 -:4  G4:2 F#4:2 E4:4 D#4:4 E4:8 -:8', 5) + [0xFF])
core_b = SILENT
core_c = (ins(104, 3, 60) + seq('E2:4 E2:4 F2:4 E2:4', 10) + [0xFF])
core_d = drums('k . . . . . . . s . . . . . . .', 5)

COMMON = ['title', 'end', 'boss']
LEVELTRACKS = {1: ['temple', 'cave', 'crypt'], 2: ['city', 'tide'], 3: ['volcano', 'core']}
DATA = {k: tuple(globals()[f'{k}_{c}'] for c in 'abcd')
        for k in ['title', 'end', 'boss', 'temple', 'cave', 'crypt', 'city', 'tide', 'volcano', 'core']}


# ---------------------------------------------------------------- sound effects (channel B)
# frame entries: inc (word), width (byte), flags (bit0 noise); terminated by width 255
def sfx_sweep(f0, f1, frames, w0, w1, noise=0):
    out = []
    for i in range(frames):
        t = i / max(1, frames - 1)
        f = f0 * (f1 / f0) ** t
        w = int(w0 + (w1 - w0) * t)
        inc = int(f * 65536 / RATE)
        out += [inc & 255, inc >> 8, max(0, min(254, int(w * 0.6))), noise]
    return out + [0, 0, 255, 0]


def sfx_notes(notes, d, w0, decay):
    out = []
    for nn in notes:
        inc = int(freq(n(nn)) * 65536 / RATE)
        w = w0
        for i in range(d):
            out += [inc & 255, inc >> 8, max(0, int(w * 0.6)), 0]
            w -= decay
    return out + [0, 0, 255, 0]


SFX = {
    'step':    sfx_sweep(90, 70, 2, 20, 6, 1),
    'swing':   sfx_sweep(1800, 400, 6, 60, 10, 1),
    'hit':     sfx_sweep(300, 90, 6, 110, 30, 1),
    'kill':    sfx_sweep(600, 60, 14, 120, 10, 1),
    'hurt':    sfx_sweep(220, 110, 10, 127, 40),
    'fire':    sfx_sweep(200, 900, 8, 90, 50, 1),
    'boom':    sfx_sweep(160, 40, 20, 127, 20, 1),
    'pickup':  sfx_notes(['E5', 'G5', 'B5', 'E6'], 3, 110, 10),
    'gem':     sfx_notes(['B5', 'E6', 'G#6'], 3, 90, 12),
    'staff':   sfx_notes(['A4', 'C5', 'E5', 'A5', 'C6', 'E6', 'A6'], 4, 120, 6),
    'door':    sfx_sweep(80, 50, 18, 100, 60, 1),
    'crumble': sfx_sweep(120, 30, 26, 127, 30, 1),
    'rune':    sfx_notes(['E5', 'B5', 'E5', 'B5'], 5, 70, 5),
    'bump':    sfx_sweep(70, 60, 3, 50, 20),
    'nomp':    sfx_sweep(300, 200, 6, 40, 10),
    'shot':    sfx_sweep(700, 300, 6, 70, 20),
    'splash':  sfx_sweep(400, 150, 4, 40, 10, 1),
    'roar':    sfx_sweep(90, 40, 40, 127, 60, 1),
    'victory': sfx_notes(['C5', 'E5', 'G5', 'C6', 'G5', 'C6', 'E6'], 5, 120, 4),
    'chapter': sfx_notes(['E4', 'A4', 'C5', 'E5', 'A5'], 8, 120, 3),
}


def emit_tracks(names, prefix):
    L = []
    for name in names:
        for ch, s in zip('abcd', DATA[name]):
            L.append(f'{prefix}{name}_{ch}:')
            for i in range(0, len(s), 16):
                L.append('        db ' + ','.join(str(v) for v in s[i:i + 16]))
    return L


def emit_table(names, prefix, label):
    return [f'{label}:'] + [f'        dw {prefix}{n}_a,{prefix}{n}_b,{prefix}{n}_c,{prefix}{n}_d' for n in names]


def emit_cold():
    """note table + sfx (cold common area)"""
    L = ['NOTEINC:']
    t = inc_table()
    for i in range(0, 96, 12):
        L.append('        dw ' + ','.join(str(v) for v in t[i:i + 12]))
    for name, s in SFX.items():
        L.append(f'SFX_{name.upper()}:')
        for j in range(0, len(s), 16):
            L.append('        db ' + ','.join(str(v) for v in s[j:j + 16]))
    return L


def emit_hot():
    """common tracks (title, end, boss) live in main RAM"""
    return emit_table(COMMON, 'MUS_', 'TRACKTAB') + emit_tracks(COMMON, 'MUS_')


def consts():
    return [f'TR_{n.upper()} EQU {i + 1}' for i, n in enumerate(COMMON)]
