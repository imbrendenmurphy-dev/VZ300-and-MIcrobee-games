# BIX music: Bix's motif (G-B-D-G rising "dig-dig-dig-POP") runs through
# every tune.  Generates build/music.inc
import os
OUT = os.path.join(os.path.dirname(__file__), '..', 'build', 'music.inc')
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
def freq(n):
    name, octv = n[:-1], int(n[-1])
    midi = 12 * (octv + 1) + NAMES[name]
    return 440.0 * 2 ** ((midi - 69) / 12)

R_GAME = 3546900 / 760      # in-game: one tick per copied row
R_TITLE = 3546900 / 199     # 3-voice title player loop

def parse(s):
    return s.split()

# 8th-note grids. '-' = tie, 'r' = rest
MEL = """G4 B4 D5 G5 F#5 D5 E5 -   C5 E5 G5 C6 B5 G5 A5 -
G4 B4 D5 G5 A5 G5 E5 D5   C5 D5 E5 F#5 G5 - - r
E5 - E5 G5 D5 - B4 -   C5 - C5 E5 D5 - - -
E5 F#5 G5 A5 B5 A5 G5 E5   D5 G5 F#5 A5 G5 - - r"""
BASS = """G2 G3 G2 G3 D2 D3 D2 D3   C2 C3 C2 C3 D2 D3 D2 D3
G2 G3 G2 G3 E2 E3 E2 E3   C2 C3 D2 D3 G2 G3 G2 r
C2 C3 C2 C3 G2 G3 G2 G3   A2 A3 A2 A3 D2 D3 D2 D3
C2 C3 C2 C3 E2 E3 E2 E3   D2 D3 D2 D3 G2 G3 G2 r"""
# second in-game phrase: same motif an octave down, more syncopated
MEL2 = """G4 - B4 D5 - G5 F#5 E5   D5 - B4 G4 A4 - B4 -
C5 - E5 G5 - C6 B5 A5   G5 E5 D5 B4 G4 - - r"""

def tokens_to_events(toks):
    ev = []
    for t in toks:
        if t == '-':
            ev[-1][1] += 1
        else:
            ev.append([t, 1])
    return ev

def game_song(name, mel, frames8):
    out = [f'{name}:']
    for n, d in tokens_to_events(parse(mel)):
        inc = 0 if n == 'r' else round(freq(n) * 65536 / R_GAME)
        out.append(f'  dw {inc} : db {d * frames8}')
    return out

BLIP_L = int(0.075 * R_TITLE)
def two_ch(name, mel, bass, loops8, end=True):
    a, b = parse(mel), parse(bass)
    assert len(a) == len(b), (len(a), len(b))
    out = [f'{name}:']
    i = 0
    # merge: emit an event per 8th, but join ties of both channels
    while i < len(a):
        n1 = a[i]; n2 = b[i]; d = 1
        while i + d < len(a) and a[i + d] == '-' and b[i + d] == '-':
            d += 1
        def inc(n, prev):
            if n == 'r': return 0
            if n == '-': return prev
            return round(freq(n) * 65536 / R_TITLE)
        if n1 == '-': n1 = last1
        if n2 == '-': n2 = last2
        last1, last2 = n1, n2
        i1 = 0 if n1 == 'r' else round(freq(n1) / 2 * 65536 / R_TITLE)
        i2 = 0 if n2 == 'r' else round(freq(n2) * 65536 / R_TITLE)
        out.append(f'  dw {i1},{i2},{loops8 * d}')   # (the player blips each note)
        i += d
    if end: out.append('  dw 0,0,0')
    return out


# ---- in-game songs as binary (dw inc, db frames ... dw $FFFF)
import struct
def game_song_bin(mel, frames8):
    b = bytearray()
    for n, d in tokens_to_events(parse(mel)):
        inc = 0 if n == 'r' else round(freq(n) / 2 * 65536 / R_GAME)   # an octave lower
        b += struct.pack('<HB', inc, d * frames8)
    b += b'\xff\xff'
    return b

SONG_GULLY = MEL + ' ' + MEL2 + ' ' + MEL
# Crystal Caverns: E minor, the motif inverted and echoing
SONG_CAVES = """E4 - G4 B4 - E5 - D5   B4 - G4 - A4 - B4 -
E4 - G4 B4 - E5 F#5 G5   F#5 - D5 - B4 - - r
C5 - E5 G5 - C5 - B4   A4 - C5 - E5 - D5 -
B4 - D#5 F#5 - B5 - A5   G5 F#5 E5 - - - - r
E5 r E5 G5 r B5 r A5   G5 - E5 - D5 - B4 -
C5 r C5 E5 r G5 r F#5   E5 - - - B4 - - r"""
# King Cane: driving, chromatic
SONG_BOSS = """G4 G4 A#4 G4 C5 G4 C#5 C5   G4 G4 A#4 G4 F4 G4 F#4 F4
G4 G4 A#4 G4 C5 G4 D5 C#5   D5 - C5 - A#4 - G4 r
D5 D5 F5 D5 G5 D5 G#5 G5   D5 D5 F5 D5 C5 D5 C#5 C5
G5 F5 D5 C5 A#4 G4 F4 D4   G4 - G4 - G4 - r r"""

# Clockwork Works: D minor, ticking ostinato with the motif in the gaps
SONG_FACTORY = """D4 r D5 r A4 r D5 r   D4 r D5 r A4 D5 F5 A5
C4 r C5 r G4 r C5 r   C4 r C5 r G4 C5 E5 G5
A#3 r A#4 r F4 r A#4 r   A3 r A4 r E4 A4 C#5 E5
D5 F5 A5 D6 - C6 A5 F5   D5 - A4 - D5 - r r"""
# Geode Golem: slow, heavy, low
SONG_GOLEM = """E3 - E3 G3 - E3 A#3 -   E3 - E3 G3 - B3 A#3 -
E4 - D4 - B3 - G3 -   A#3 - A3 - G3 - E3 r
E3 E3 G3 E3 A#3 E3 B3 A#3   E3 E3 G3 E3 D4 C#4 C4 B3
E4 - G4 - E4 - D4 -   E4 - - - E3 - r r"""

# Skyward Isles: bright G major waltz-ish skip, the motif soaring an octave up
SONG_SKY = """G5 - B5 - D6 -   C6 - A5 - F#5 -   G5 - D5 - B4 -   C5 - D5 - E5 -
D5 - G5 - B5 -   A5 - G5 - E5 -   D5 - F#5 - A5 -   G5 - - - r -
E5 - G5 - C6 -   B5 - G5 - E5 -   D5 - G5 - B5 -   A5 - - - r -
C6 - B5 - A5 -   G5 - F#5 - E5 -   D5 - E5 - F#5 -   G5 - - - - r"""
# Rust-o-Tron: clanking, square, mechanical
SONG_ROBOT = """C4 C5 C4 C5 D#4 D#5 F4 F5   G4 G5 F4 F5 D#4 D#5 D4 D5
C4 C5 C4 C5 D#4 D#5 F4 F5   G4 - G#4 - G4 - F4 r
C5 D#5 G5 C6 - A#5 G5 D#5   F5 - D5 - A#4 - G4 -
C5 D#5 G5 C6 - D6 C6 A#5   C6 - - - C5 - r r"""

# Molten Peaks: A minor, urgent and rumbling
SONG_PEAKS = """A3 A4 A3 A4 C4 C5 E4 E5   D4 D5 C4 C5 B3 B4 G#3 G#4
A3 A4 A3 A4 C4 C5 E4 E5   F4 F5 E4 E5 D4 D5 E4 r
A4 - C5 E5 - A5 G5 E5   F5 - D5 - A4 - D5 -
E5 - G#5 B5 - E6 D6 B5   A5 - - - A4 - r r"""
# Thunderhawk: windy, rising
SONG_HAWK = """D5 F5 A5 D6 C6 A5 F5 A5   C5 E5 G5 C6 A#5 G5 E5 G5
A#4 D5 F5 A#5 A5 F5 D5 F5   A4 C#5 E5 A5 - E5 C#5 r
D5 - D6 - C6 - A5 -   A#5 - G5 - F5 - E5 -
D5 F5 A5 D6 - - D5 -   D6 - - - D5 - r r"""
# Magma Dragon: the motif, in fire
SONG_DRAGON = """E3 E4 E3 E4 G3 G4 A#3 A#4   E3 E4 E3 E4 B3 B4 A#3 A#4
G4 B4 D5 G5 - F#5 D5 B4   E5 - D#5 - E5 - B4 r
E4 G4 B4 E5 - G5 F#5 E5   D#5 - B4 - F#4 - B3 -
G4 B4 D5 G5 - B5 A5 G5   E5 - - - E4 - r r"""

def songs():
    return {'gully': game_song_bin(SONG_GULLY, 6),
            'caves': game_song_bin(SONG_CAVES, 7),
            'boss': game_song_bin(SONG_BOSS, 4),
            'golem': game_song_bin(SONG_GOLEM, 5),
            'factory': game_song_bin(SONG_FACTORY, 4),
            'sky': game_song_bin(SONG_SKY, 4),
            'robot': game_song_bin(SONG_ROBOT, 4),
            'peaks': game_song_bin(SONG_PEAKS, 4),
            'hawk': game_song_bin(SONG_HAWK, 4),
            'dragon': game_song_bin(SONG_DRAGON, 4)}


def three_ch(name, mel, bass, loops8, drums=None, end=True, shift=0):
    """lead = mel (an octave down), voice 2 = sub-bass (the bass an octave
    lower), voice 3 = bass.  drums: string of K S H . per 8th (repeats).
    shift = semitones to transpose."""
    a, b = parse(mel), parse(bass)
    assert len(a) == len(b), (name, len(a), len(b))
    def inc(n, div=1):
        return 0 if n == 'r' else round(freq(n) * 2 ** (shift / 12) / div * 65536 / R_TITLE)
    out = [f'{name}:']
    l1 = l3 = 'r'
    for i in range(len(a)):
        n1, n3 = a[i], b[i]
        flags = 0
        if n1 != '-':
            l1 = n1; flags |= 4
        if n3 != '-':
            l3 = n3; flags |= 8 | 16
        if drums:
            d = drums[i % len(drums)]
            flags |= {'K': 1, 'S': 2, 'H': 3}.get(d, 0)
        out.append(f'  dw {inc(l1, 2)},{inc(l3)},{inc(l3)},{loops8} : db {flags}')
    if end:
        out.append('  dw 0,0,0,0 : db 0')
    return out

L8 = int(0.135 * R_TITLE)
lines = ['; generated by music.py (title + jingles, overlay)']
lines += three_ch('title_song', MEL, BASS, int(0.152 * R_TITLE), drums='K...S..K' 'K...S...', shift=-3)
J = L8 // 2
lines += three_ch('jingle_start', 'G4 B4 D5 G5 - - D5 G5 - - - -', 'G2 G2 G2 G2 - - D3 G2 - - - -', J, drums='HHHK..HK....')
lines += three_ch('jingle_clear', 'C5 E5 G5 C6 - B5 C6 D6 - - G6 - - - - -',
                'C3 C3 C3 C3 - G2 G2 B2 - - G2 - - - - -', J, drums='HHHK.HHS..K.....')
lines += three_ch('jingle_over', 'G4 - F#4 - F4 - E4 - - - D4 - - - - -',
                'G2 - F#2 - F2 - E2 - - - G2 - - - - -', J, drums='K.K.K.K...S.....')
lines += three_ch('jingle_boss', 'G4 A#4 D5 G5 - F5 D5 A#4 C5 - - - - - - -',
                'G2 G2 G2 G2 - F2 F2 F2 C3 - - - - - - -', J, drums='KHSHK.KSK.......')
END_MEL = """G4 B4 D5 G5 - - F#5 -   E5 - C5 - E5 G5 - -
A5 - G5 - E5 - D5 -   G5 - - - - - - r"""
END_BASS = """G2 - D3 - G2 - D3 -   C3 - G2 - C3 - G2 -
D3 - A2 - D3 - A2 -   G2 - D3 - G2 - - r"""
lines += three_ch('ending_song', END_MEL, END_BASS, L8 + L8 // 3, drums='K...S...K.K.S..H')
if __name__ == '__main__':
    open(OUT, 'w').write('\n'.join(lines) + '\n')
    print('music ok', L8)
