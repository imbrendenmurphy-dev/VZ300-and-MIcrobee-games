"""OVERRIDE music: songs for the three-voice pulse player (the engine from
Dracula's Castle II; same stream format). All tunes are original.

Channel string tokens:
  i<n>      instrument n
  u<n>      unit = n ticks (lengths below are multiplied); a tick is one field (1/50 s)
  NOTE:len  e.g. A4:3  C#5:2  Bb3:1   (len in units)
  r:len     rest
  s<+/-n>   pitch slide per tick (raw step units)
  |         bar line (ignored)
  [ ... ]xN repeat
Stream bytes: $00 rest, $01-$5F note (1 = C1), $60-$7F length, $80-$8F instrument,
$90 slide, $91 long length, $FE jump, $FF stop.
"""
import re

NOTES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
SAMPLE_T = 211                      # T-states a sample in the player's loop
RATE = 3546875 / SAMPLE_T


def note_num(tok):
    name = tok[0]; i = 1; acc = 0
    while i < len(tok) and tok[i] in '#b':
        acc += 1 if tok[i] == '#' else -1; i += 1
    octv = int(tok[i:])
    return (octv - 1) * 12 + NOTES[name] + acc + 1     # C1 = 1


def expand(s):
    s = re.sub(r'\](?!x\d)', ']x1', s)
    while '[' in s:
        n = s
        s = re.sub(r'\[([^\[\]]*)\]x(\d+)', lambda m: ' '.join([m.group(1)] * int(m.group(2))), s)
        assert s != n, 'unbalanced [ ] in song'
    return s.split()


def compile_channel(s):
    out = bytearray(); unit = 1; curlen = None; ticks_total = 0
    for tok in expand(s):
        if tok == '|': continue
        if tok[0] == 'i': out.append(0x80 + int(tok[1:])); continue
        if tok[0] == 'u': unit = int(tok[1:]); continue
        if tok[0] == 's':
            v = int(tok[1:]) & 0xFFFF; out += bytes([0x90, v & 255, v >> 8]); continue
        n, l = tok.split(':')
        ticks = int(round(float(l) * unit))
        assert 0 < ticks < 256, tok
        ticks_total += ticks
        if ticks != curlen:
            if ticks <= 32: out.append(0x5F + ticks)
            else: out += bytes([0x91, ticks])
            curlen = ticks
        out.append(0 if n == 'r' else note_num(n))
    return bytes(out), ticks_total


def note_steps():
    out = []
    for n in range(1, 96):
        f = 32.7032 * 2 ** ((n - 1) / 12.0)
        out.append(min(65535, int(round(f * 65536 / RATE))))
    return out


# instruments: (start duty, decay a tick, min duty, flags: bit0 noise)
INSTR = [
    (44, 1, 14, 0),   # 0 lead: bright, slowly thinning
    (64, 2, 20, 0),   # 1 bass
    (30, 1, 10, 0),   # 2 soft pad
    (96, 18, 0, 1),   # 3 snare (noise)
    (56, 7, 0, 0),    # 4 staccato
    (60, 1, 34, 0),   # 5 organ
    (72, 5, 4, 0),    # 6 bell
    (110, 14, 0, 0),  # 7 kick
    (70, 14, 0, 1),   # 8 hat (noise short)
    (40, 0, 40, 0),   # 9 flat beep
    (80, 3, 22, 0),   # 10 synth brass
    (24, 0, 24, 0),   # 11 thin drone
]

SONGS = {}

# ------------------------------------------------------------------ title
# "Override" - A minor, 150 bpm, a 16th = 5 ticks.
_A_LEAD = ("E5:2 A5:2 B5:2 C6:4 B5:2 A5:2 G5:2 | A5:6 F5:2 C5:4 F5:2 G5:2 | "
           "E5:2 G5:2 C6:2 E6:4 D6:2 C6:2 B5:2 | D6:6 B5:2 G5:4 A5:2 B5:2 | "
           "C6:2 B5:2 A5:2 E5:4 A5:2 C6:2 E6:2 | F6:4 E6:2 D6:2 C6:4 A5:4 | "
           "B5:2 C6:2 D6:2 G5:4 B5:2 D6:2 G6:2 | E6:6 D6:2 B5:4 G#5:4 | ")
_B_LEAD = ("D6:4 F6:4 A6:4 F6:4 | E6:8 C6:4 A5:4 | D6:4 F6:2 D6:2 Bb5:4 F5:4 | G#5:4 B5:4 E6:6 r:2 | "
           "F6:2 E6:2 D6:2 A5:2 F6:2 E6:2 D6:2 A5:2 | E6:2 D6:2 C6:2 A5:2 E6:2 D6:2 C6:2 A5:2 | "
           "C6:2 D6:2 E6:2 F6:2 G6:4 A6:4 | B6:4 G#6:4 E6:4 r:4 | ")
_TAG_LEAD = "A6:6 E6:2 C6:2 E6:2 A6:4 | A6:12 r:4 | "

def _bass(ch):
    pat = {'Am': 'A2 A2 E3 A2 A3 A2 E3 G2', 'F': 'F2 F2 C3 F2 F3 F2 C3 E2', 'C': 'C3 C3 G3 C3 C4 C3 G3 B2',
           'G': 'G2 G2 D3 G2 G3 G2 D3 F#2', 'E': 'E2 E2 B2 E2 E3 E2 G#2 B2', 'Dm': 'D3 D3 A3 D3 D4 D3 A3 C3',
           'Bb': 'Bb2 Bb2 F3 Bb2 Bb3 Bb2 F3 A2'}[ch]
    return ' '.join(n + ':2' for n in pat.split()) + ' | '

_A_BASS = ''.join(_bass(c) for c in ['Am', 'F', 'C', 'G', 'Am', 'F', 'G', 'E'])
_B_BASS = ''.join(_bass(c) for c in ['Dm', 'Am', 'Bb', 'E', 'Dm', 'Am', 'F', 'E'])
_DR = "i7 C3:2 i8 C6:2 i3 C5:2 i8 C6:2 i7 C3:2 i7 C3:2 i3 C5:2 i8 C6:2 | "
_DR_FILL = "i7 C3:2 i8 C6:2 i3 C5:2 i8 C6:2 i3 C5:1 C5:1 C5:2 i3 C5:1 C5:1 C5:1 C5:1 | "
_HATS = "i8 [C6:2 r:2]x4 | "

SONGS['TITLE'] = dict(loop=True, ch=[
    # lead: four bars of bass alone, a rising pickup, then A B A and a tag
    "u5 r:16 r:16 r:16 i6 r:8 A4:2 C5:2 E5:2 G5:2 | i0 " + _A_LEAD + "i10 " + _B_LEAD + "i0 " + _A_LEAD + "i10 " + _TAG_LEAD,
    "u5 i1 " + _bass('Am') * 4 + _A_BASS + _B_BASS + _A_BASS + _bass('Am') + _bass('Am'),
    "u5 " + _HATS * 2 + _DR + _DR_FILL + (_DR * 7 + _DR_FILL) * 3 + _DR + _DR_FILL,
])

# ------------------------------------------------------------------ link duel: tense ostinato in E minor
SONGS['LINK'] = dict(loop=True, ch=[
    "u4 i4 [E5:1 G5:1 B5:1 G5:1]x4 [F5:1 A5:1 C6:1 A5:1]x4 [E5:1 G5:1 B5:1 G5:1]x4 [D#5:1 F#5:1 B5:1 F#5:1]x4",
    "u4 i1 [E2:2 E3:2]x4 [F2:2 F3:2]x4 [E2:2 E3:2]x4 [B1:2 B2:2]x4",
    "u4 [i7 C3:2 i8 C6:1 C6:1]x16",
])

SONGS['WIN'] = dict(loop=False, ch=[
    "u3 i6 E5:1 G5:1 B5:1 E6:2 r:1 B5:1 E6:6",
    "u3 i4 B4:1 E5:1 G5:1 B5:2 r:1 G5:1 B5:6",
    "u3 i1 E3:3 r:3 B2:2 E3:6",
])
SONGS['LOSE'] = dict(loop=False, ch=[
    "u5 i5 E5:2 D#5:2 D5:2 C#5:4 r:2",
    "u5 i5 B4:2 A#4:2 A4:2 G#4:4 r:2",
    "u5 i1 E2:6 A1:4 r:2",
])
SONGS['SHIPCARD'] = dict(loop=False, ch=[
    "u5 i10 A4:2 r:1 A4:1 C5:2 E5:2 A5:6 G5:1 F5:1 E5:8",
    "u5 i2 E4:4 A4:4 C5:6 B4:2 C5:8",
    "u5 i1 A2:4 A2:4 F2:4 G2:4 A2:8",
])
SONGS['SHIPDONE'] = dict(loop=False, ch=[
    "u4 i10 C5:1 E5:1 G5:1 C6:3 G5:1 C6:6 r:2 D6:2 E6:2 F6:2 G6:8",
    "u4 i4 E4:1 G4:1 C5:1 E5:3 C5:1 E5:6 r:2 F5:2 G5:2 A5:2 B5:8",
    "u4 i1 C3:6 G2:6 r:2 F2:2 G2:2 A2:2 C3:8",
])
SONGS['GAMEOVER'] = dict(loop=False, ch=[
    "u7 i5 A4:2 G4:2 E4:2 C4:2 D4:3 B3:1 A3:8",
    "u7 i5 E4:2 D4:2 C4:2 A3:2 B3:3 G#3:1 E3:8",
    "u7 i1 A2:4 C3:4 E2:4 A1:8",
])
SONGS['HISCORE'] = dict(loop=True, ch=[
    "u6 i6 C6:1 E6:1 G6:1 E6:1 D6:1 F6:1 A6:1 F6:1 E6:1 G6:1 C7:1 G6:1 D6:2 B5:2",
    "u6 i1 C3:2 G3:2 D3:2 A3:2 E3:2 C3:2 G2:2 B2:2",
    "u6 i2 E5:4 F5:4 G5:4 G5:2 F5:2",
])
SONGS['ENDING'] = dict(loop=True, ch=[
    "u6 i0 A5:2 C6:1 E6:1 A6:2 G6:1 E6:1 | F6:3 E6:1 C6:4 | D6:2 F6:1 D6:1 B5:2 G5:2 | A5:6 r:2 | "
    "C6:2 E6:1 C6:1 A5:2 C6:2 | D6:3 C6:1 B5:4 | G#5:2 B5:2 E6:2 G#6:2 | A6:6 r:2",
    "u6 i2 E5:4 C5:4 | C5:4 A4:4 | B4:4 G4:4 | C5:6 r:2 | A4:4 E5:4 | F5:4 D5:4 | E5:4 D5:4 | C5:6 r:2",
    "u6 i1 [A2:2 E3:2]x2 [F2:2 C3:2]x2 [G2:2 D3:2]x2 [A2:2 E3:2]x2 [A2:2 E3:2]x2 [D2:2 A2:2]x2 [E2:2 B2:2]x2 [A2:2 E3:2]x2",
])

# ------------------------------------------------------------------ attract pages: a calm briefing tune
SONGS['BRIEF'] = dict(loop=True, ch=[
    "u6 i2 r:4 E5:2 A5:2 | C6:4 B5:2 A5:2 | G5:6 E5:2 | F5:8 | r:4 D5:2 F5:2 | A5:4 G5:2 F5:2 | E5:6 G#5:2 | A5:8",
    "u6 i6 [A4:1 C5:1 E5:1 C5:1]x4 [F4:1 A4:1 C5:1 A4:1]x4 [D4:1 F4:1 A4:1 F4:1]x4 [E4:1 G#4:1 B4:1 G#4:1]x4",
    "u6 i1 A2:4 E2:4 | F2:4 C3:4 | D2:4 A2:4 | E2:4 E3:4 | A2:4 E2:4 | F2:4 C3:4 | D2:4 E2:4 | A2:8",
])

SONG_ORDER = ['TITLE', 'LINK', 'WIN', 'LOSE', 'SHIPCARD', 'SHIPDONE', 'GAMEOVER', 'HISCORE', 'ENDING', 'BRIEF']

# ------------------------------------------------------------------ in-game soundtrack
# Two channels (bass on speaker line 5, lead on line 0), ticked once a game
# frame (25 a second); the mixer's samples are ~875 T apart.
GRATE = 3546875 / 875.0
GINSTR = [
    (120, 3, 56),    # 0 bass: punchy square, settling
    (100, 2, 36),    # 1 lead
    (110, 9, 0),     # 2 staccato blip
    (70, 0, 70),     # 3 steady reed
    (128, 1, 80),    # 4 long bass
]


def _gbass(ch, style=0):
    """one bar (16 sixteenths) of bass for chord ch"""
    R = {'Dm': ('D2', 'A2', 'F2', 'C3'), 'Bb': ('Bb1', 'F2', 'D2', 'Ab2'), 'Gm': ('G1', 'D2', 'Bb1', 'F2'),
         'A': ('A1', 'E2', 'C#2', 'G2'), 'Em': ('E2', 'B2', 'G2', 'D3'), 'C': ('C2', 'G2', 'E2', 'Bb2'),
         'D': ('D2', 'A2', 'F#2', 'C3'), 'B': ('B1', 'F#2', 'D#2', 'A2'), 'Cm': ('C2', 'G2', 'Eb2', 'Bb2'),
         'Ab': ('Ab1', 'Eb2', 'C2', 'Gb2'), 'G': ('G1', 'D2', 'B1', 'F2'), 'Fm': ('F1', 'C2', 'Ab1', 'Eb2')}[ch]
    up = lambda n: n[:-1] + str(int(n[-1]) + 1)     # an octave up: the VZ speaker is small
    r, f, t, s = [up(n) for n in R]
    if style == 0:   # slow, uneasy
        return '%s:4 r:2 %s:2 %s:4 %s:2 %s:2 | ' % (r, r, f, t, r)
    if style == 1:   # pulsing eighths
        return ' '.join(n + ':2' for n in (r, r, f, r, s, r, f, t)) + ' | '
    return ' '.join(n + ':1' for n in (r, r, r, f, r, r, s, r, r, r, f, r, t, r, f, s)) + ' | '


GSONGS = {}
GSONGS['CORMORANT'] = [
    "u3 i0 " + ''.join(_gbass(c, 0) for c in ['Dm', 'Dm', 'Bb', 'Bb', 'Gm', 'Gm', 'A', 'A'] * 2),
    "u3 i1 r:4 A4:2 D5:2 F5:4 E5:2 D5:2 | A4:12 r:4 | r:4 F5:2 Bb5:2 A5:4 G5:2 F5:2 | D5:12 r:4 | "
    "r:4 G5:2 Bb5:2 D6:4 C6:2 Bb5:2 | A5:8 G5:4 F5:4 | E5:4 C#5:4 E5:4 A5:4 | C#6:12 r:4 | "
    "i3 D6:6 C6:2 A5:8 | F5:4 E5:4 D5:8 | D6:6 C6:2 Bb5:8 | F5:8 r:8 | "
    "i1 G5:4 Bb5:4 D6:4 G6:4 | F6:6 E6:2 D6:8 | E6:4 C#6:4 A5:4 E5:4 | A5:12 r:4 | ",
]
GSONGS['HALCYON'] = [
    "u3 i0 " + ''.join(_gbass(c, 1) for c in ['Em', 'Em', 'C', 'C', 'D', 'D', 'B', 'B'] * 2),
    "u3 i2 [E5:2 r:2 B5:2 r:2 G5:2 E5:2 r:4]x2 [E5:2 r:2 C6:2 r:2 G5:2 E5:2 r:4]x2 "
    "[F#5:2 r:2 D6:2 r:2 A5:2 F#5:2 r:4]x2 [D#5:2 r:2 B5:2 r:2 F#5:2 D#5:2 r:4]x2 "
    "i1 B5:6 A5:2 G5:4 E5:4 | G5:8 r:8 | C6:6 B5:2 A5:4 G5:4 | E5:8 r:8 | "
    "A5:6 G5:2 F#5:4 D5:4 | F#5:4 A5:4 D6:8 | B5:4 A5:4 G5:4 F#5:4 | D#5:8 B4:8 | ",
]
GSONGS['LEVIATHAN'] = [
    "u3 i0 " + ''.join(_gbass(c, 2) for c in ['Cm', 'Cm', 'Ab', 'Ab', 'Fm', 'Fm', 'G', 'G'] * 2),
    "u3 i1 C5:4 Eb5:4 G5:6 F5:2 | Eb5:4 D5:4 C5:8 | C5:4 Eb5:4 Ab5:6 G5:2 | F5:4 Eb5:4 C5:8 | "
    "F5:4 Ab5:4 C6:6 Bb5:2 | Ab5:4 G5:4 F5:8 | G5:4 B5:4 D6:4 F6:4 | Eb6:4 D6:4 B5:8 | "
    "i3 G5:2 C6:2 Eb6:4 D6:2 C6:2 G5:4 | Eb5:16 | Ab5:2 C6:2 Eb6:4 D6:2 C6:2 Ab5:4 | F5:16 | "
    "i1 F5:2 Ab5:2 C6:4 Eb6:4 F6:4 | Eb6:4 D6:4 C6:8 | D6:4 B5:4 G5:4 D5:4 | G5:8 B5:8 | ",
]
GSONG_ORDER = ['CORMORANT', 'HALCYON', 'LEVIATHAN']


def gasm():
    out = ['; generated by tools/music.py: the in-game soundtrack', 'ginstr:']
    for ins in GINSTR:
        out.append('            db %d,%d,%d,0' % ins)
    out.append('gnote_steps:')
    st = [min(65535, int(round(32.7032 * 2 ** ((n - 1) / 12.0) * 65536 / GRATE))) for n in range(1, 84)]
    for i in range(0, len(st), 12):
        out.append('            dw ' + ','.join(str(v) for v in st[i:i + 12]))
    out.append('gsong_table: dw ' + ','.join('gs_%s' % n.lower() for n in GSONG_ORDER))
    total = 0
    for n in GSONG_ORDER:
        lens = []
        out.append('gs_%s: dw gs_%s_0,gs_%s_1' % (n.lower(), n.lower(), n.lower()))
        for k, ch in enumerate(GSONGS[n]):
            data, t = compile_channel(ch)
            lens.append(t)
            total += len(data) + 1
            out.append('gs_%s_%d:' % (n.lower(), k))
            for i in range(0, len(data), 24):
                out.append('            db ' + ','.join(str(b) for b in data[i:i + 24]))
            out.append('            db 254')
        if len(set(lens)) != 1:
            raise SystemExit('game song %s: channel lengths differ %s' % (n, lens))
    out.append('; game music bytes: %d' % total)
    return '\n'.join(out) + '\n'

# front-end sound effects (channel 3, full volume)
SFX = {
    'move': "i4 u1 G6:2",
    'select': "i6 u1 C6:2 G6:3",
    'fire': "i4 u1 s-60 C6:6",
    'pulse': "i6 u1 s40 C5:4",
    'zap': "i3 u1 C5:5",
    'tick': "i9 u1 C7:1",
    'type': "i8 u1 C6:1",
    'lift': "i11 u1 s4 C3:20",
    'beep': "i9 u1 E6:3",
    'alarm': "i10 u1 s25 A5:7 s-25 E6:7",
}

# the intro cinematic's own tune (lives in OVATT.DAT): bells, a pad, a heartbeat
INTRO = [
    "u10 r:8 [[A4:1 E5:1 A5:1 C6:1]x2 [F4:1 C5:1 F5:1 A5:1]x2 [D4:1 A4:1 D5:1 F5:1]x2 [E4:1 B4:1 E5:1 G#5:1]x2]x2 A5:8",
    "u10 r:8 A3:8 F3:8 D3:8 E3:8 A3:8 F3:8 D3:8 E3:8 A3:8",
    "u10 [i7 C3:1 r:1 C3:1 r:5]x10",
]


def intro_asm():
    out = ['song_intro: dw si_c0,si_c1,si_c2']
    lens = []
    for k, ch in enumerate(INTRO):
        prefix = 'i6 ' if k == 0 else ('i2 ' if k == 1 else '')
        data, t = compile_channel(prefix + ch)
        lens.append(t)
        out.append('si_c%d:' % k)
        for i in range(0, len(data), 24):
            out.append('            db ' + ','.join(str(b) for b in data[i:i + 24]))
        out.append('            db 255')
    assert len(set(lens)) == 1, lens
    return '\n'.join(out) + '\n'


def asm():
    out = ['; generated by tools/music.py', 'instruments:']
    for ins in INSTR:
        out.append('            db %d,%d,%d,%d' % ins)
    out.append('note_steps:')
    st = note_steps()
    for i in range(0, len(st), 12):
        out.append('            dw ' + ','.join(str(v) for v in st[i:i + 12]))
    out.append('song_table:')
    out.append('            dw ' + ','.join('song_%s' % n.lower() for n in SONG_ORDER))
    for i, n in enumerate(SONG_ORDER):
        out.append('MUS_%s equ %d' % (n, i))
    total = 0
    for n in SONG_ORDER:
        S = SONGS[n]
        out.append('song_%s: dw %s' % (n.lower(), ','.join('%s_c%d' % (n.lower(), k) for k in range(3))))
        lens = []
        for k, ch in enumerate(S['ch']):
            data, t = compile_channel(ch)
            lens.append(t)
            lab = '%s_c%d' % (n.lower(), k)
            total += len(data) + 3
            out.append('%s:' % lab)
            for i in range(0, len(data), 24):
                out.append('            db ' + ','.join(str(b) for b in data[i:i + 24]))
            if S['loop']:
                out.append('            db 254')
                out.append('            dw %s' % lab)
            else:
                out.append('            db 255')
        if S['loop'] and len(set(lens)) != 1:
            raise SystemExit('song %s: channel lengths differ %s' % (n, lens))
    for n, s in SFX.items():
        data, t = compile_channel(s)
        total += len(data) + 1
        out.append('fsfx_%s: db %s,255' % (n, ','.join(map(str, data))))
    out.append('; music bytes: %d' % total)
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    a = asm()
    print(a.splitlines()[-1])
