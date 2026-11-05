# music.py - songs and SFX for the pulse engine
# token syntax per channel string:
#   i<n>      instrument n
#   u<n>      unit = n ticks (lengths below are multiplied)
#   NOTE:len  e.g. A4:3  C#5:2  Bb3:1   (len in units)
#   r:len     rest
#   s<+/-n>   pitch slide per tick (raw step units)
#   |         ignored (bar line)
#   [ ... ]xN repeat block N times
NOTES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}

def note_num(tok):
    name = tok[0]; i = 1; acc = 0
    while i < len(tok) and tok[i] in '#b':
        acc += 1 if tok[i] == '#' else -1; i += 1
    octv = int(tok[i:])
    return (octv - 1) * 12 + NOTES[name] + acc + 1     # C1 = 1

def expand(s):
    import re
    while '[' in s:
        s = re.sub(r'\[([^\[\]]*)\]x(\d+)', lambda m: ' '.join([m.group(1)] * int(m.group(2))), s)
    return s.split()

def compile_channel(s, loop=True):
    out = bytearray(); unit = 1; curlen = None
    for tok in expand(s):
        if tok == '|': continue
        if tok[0] == 'i': out.append(0x80 + int(tok[1:])); continue
        if tok[0] == 'u': unit = int(tok[1:]); continue
        if tok[0] == 's':
            v = int(tok[1:]) & 0xFFFF; out += bytes([0x90, v & 255, v >> 8]); continue
        n, l = tok.split(':')
        ticks = int(float(l) * unit)
        assert 0 < ticks < 256, tok
        if ticks != curlen:
            if ticks <= 32: out.append(0x5F + ticks)
            else: out += bytes([0x91, ticks])
            curlen = ticks
        out.append(0 if n == 'r' else note_num(n))
    return bytes(out)

INSTR = [
    (40, 2, 8, 0),    # 0 lead pluck
    (64, 2, 18, 0),   # 1 bass
    (24, 1, 6, 0),    # 2 soft pad
    (90, 20, 0, 1),   # 3 noise hit
    (48, 6, 0, 0),    # 4 staccato
    (52, 1, 26, 0),   # 5 organ
    (64, 4, 3, 0),    # 6 bell
    (96, 12, 0, 0),   # 7 kick / thump
    (60, 9, 0, 1),    # 8 noise short (hat)
    (40, 0, 40, 0),   # 9 flat beep (1984 maze)
]

SONGS = {}
SONGS['TITLE'] = dict(loop=True, ch=[
    "i5 u3 A5:1 G5:1 A5:5 r:3 G5:1 F5:1 E5:1 D5:1 C#5:3 D5:6 r:4 "
    "A4:1 G4:1 A4:5 r:3 E4:1 F4:1 C#4:2 D4:6 r:4 "
    "A3:1 G3:1 A3:5 r:3 G3:1 F3:1 E3:1 D3:1 C#3:3 D3:8 r:4 "
    "i0 u2 C#4:1 E4:1 G4:1 Bb4:1 C#5:1 E5:1 G5:1 Bb5:1 C#6:4 r:2 Bb5:1 G5:1 E5:1 C#5:1 i5 u3 D5:10 r:6",
    "i5 u3 A4:1 G4:1 A4:5 r:3 G4:1 F4:1 E4:1 D4:1 C#4:3 D4:6 r:4 "
    "A3:1 G3:1 A3:5 r:3 E3:1 F3:1 C#3:2 D3:6 r:4 "
    "A2:1 G2:1 A2:5 r:3 G2:1 F2:1 E2:1 D2:1 C#2:3 D2:8 r:4 "
    "u2 r:12 r:6 i1 u3 D3:10 r:6",
    "i1 u3 r:14 r:6 r:12 r:6 D2:16 r:4 i5 u2 A3:8 G3:4 E3:4 u3 F3:10 r:6",
])
SONGS['GROUNDS'] = dict(loop=True, ch=[
    "i0 u12 A4:1 C5:1 E5:1 D5:1 | C5:1 B4:1 G#4:2 | A4:1 C5:1 E5:1 A5:1 | G5:1 F5:1 E5:2 | "
    "F5:1 E5:1 D5:1 C5:1 | B4:1 C5:1 D5:2 | E5:1 C5:1 B4:1 G#4:1 | A4:3 r:1",
    "i1 u12 A2:2 E3:2 | A2:2 E2:2 | A2:2 E3:2 | C3:2 E3:2 | D3:2 A2:2 | G2:2 G3:2 | E3:2 E2:2 | A2:3 r:1",
    "i6 u12 r:4 E6:1 r:3 r:4 C6:1 r:3 r:4 D6:1 r:3 r:4 B5:1 r:2 G#5:1",
])
SONGS['HALL'] = dict(loop=True, ch=[
    "i0 u9 D5:3 F5:1 E5:1 D5:1 | C#5:3 E5:3 | D5:2 A4:2 F4:2 | E4:6 | "
    "D5:3 F5:1 E5:1 D5:1 | C#5:2 D5:2 E5:2 | F5:2 E5:2 D5:2 | D5:5 r:1",
    "i1 u9 D3:2 A3:2 A3:2 | A2:2 E3:2 E3:2 | D3:2 A3:2 A3:2 | A2:2 C#3:2 E3:2 | "
    "D3:2 A3:2 A3:2 | A2:2 E3:2 E3:2 | Bb2:2 F3:2 F3:2 | D3:2 A3:2 D4:2",
    "i2 u9 r:6 r:6 F4:6 E4:6 r:6 A4:6 Bb4:6 A4:6",
])
SONGS['BATTLE'] = dict(loop=True, ch=[
    "i0 u4 B4:2 E5:2 G5:2 F#5:1 E5:1 | D5:2 B4:2 A4:2 B4:2 | C5:2 E5:2 G5:2 A5:2 | B5:3 A5:1 F#5:4 | "
    "B4:2 E5:2 G5:2 F#5:1 E5:1 | D5:2 F#5:2 A5:2 G5:1 F#5:1 | E5:2 G5:2 C6:2 B5:1 A5:1 | B5:6 r:2",
    "i1 u4 [E2:1 E2:1 E3:1 E2:1]x2 [D2:1 D2:1 D3:1 D2:1]x2 [C2:1 C2:1 C3:1 C2:1]x2 [B1:1 B1:1 B2:1 B1:1]x2 "
    "[E2:1 E2:1 E3:1 E2:1]x2 [D2:1 D2:1 D3:1 D2:1]x2 [C2:1 C2:1 C3:1 C2:1]x2 [B1:1 B1:1 D#3:1 B2:1]x2",
    "i8 u4 [C6:1 r:1]x32",
])
SONGS['BOSS'] = dict(loop=True, ch=[
    "i5 u4 D5:4 C#5:2 D5:2 | F5:4 E5:2 D5:2 | Bb4:4 A4:2 G4:2 | A4:8 | "
    "D5:4 C#5:2 D5:2 | G5:4 F5:2 E5:2 | F5:2 E5:2 D5:2 C#5:2 | D5:8",
    "i1 u4 [D2:1 D3:1 D2:1 C3:1]x2 [Bb1:1 Bb2:1 Bb1:1 A2:1]x2 [G1:1 G2:1 G1:1 F2:1]x2 [A1:1 A2:1 A1:1 C#3:1]x2 "
    "[D2:1 D3:1 D2:1 C3:1]x2 [Bb1:1 Bb2:1 Bb1:1 A2:1]x2 [G1:1 G2:1 A1:1 A2:1]x2 [D2:1 D3:1 D2:1 A2:1]x2",
    "i7 u4 [C3:1 r:1 i8 C6:1 r:1 i7]x16",
])
SONGS['VICTORY'] = dict(loop=False, ch=[
    "i4 u3 C5:1 E5:1 G5:1 C6:2 r:1 G5:1 C6:6",
    "i4 u3 E4:1 G4:1 C5:1 E5:2 r:1 D5:1 E5:6",
    "i1 u3 C3:3 r:3 G2:2 C3:6",
])
SONGS['LEVELUP'] = dict(loop=False, ch=[
    "i6 u2 C5:1 E5:1 G5:1 C6:1 E6:1 G6:1 C7:4 r:2 G6:1 C7:6",
    "i4 u2 r:1 C4:1 E4:1 G4:1 C5:1 E5:1 G5:4 r:2 E5:1 G5:6",
    "i1 u2 C3:6 r:2 G2:2 C3:8",
])
SONGS['DEATH'] = dict(loop=False, ch=[
    "i5 u6 A4:2 G#4:2 G4:2 F#4:2 F4:6 r:2",
    "i5 u6 E4:2 D#4:2 D4:2 C#4:2 D4:6 r:2",
    "i1 u6 A2:8 D2:6 r:2",
])
SONGS['MAZE'] = dict(loop=True, ch=[
    "i9 u10 C4:1 r:3 C4:1 r:3 G3:1 r:3 r:4",
    "r:32", "r:32"])
SONGS['ENDING'] = dict(loop=True, ch=[
    "i0 u8 D5:2 F#5:1 A5:1 D6:2 C#6:1 B5:1 | A5:3 F#5:1 D5:4 | G5:2 B5:1 G5:1 F#5:2 E5:2 | D5:6 r:2",
    "i2 u8 F#4:4 A4:4 | F#4:4 D4:4 | G4:4 A4:4 | F#4:6 r:2",
    "i1 u8 D3:4 A2:4 | D3:4 F#2:4 | G2:4 A2:4 | D3:6 r:2",
])
SONG_ORDER = ['GROUNDS', 'HALL', 'BATTLE', 'BOSS', 'VICTORY', 'LEVELUP', 'DEATH', 'TITLE', 'MAZE', 'ENDING']

SFX = {
    'step':    "i8 u1 C6:2",
    'turn':    "i4 u1 G6:1",
    'bump':    "i7 u1 s-12 C3:4",
    'door':    "i4 u1 s6 C3:6 s-5 D3:6 s4 C3:8",
    'item':    "i6 u2 C6:1 E6:1 G6:1 C7:3",
    'secret':  "i6 u3 G5:1 A5:1 B5:1 D6:1 G6:3",
    'hit':     "i3 u1 C5:6",
    'slash':   "i8 u1 s-40 C7:8",
    'fire':    "i3 u1 C5:20 i8 C5:12",
    'heal':    "i6 u2 C6:1 D6:1 E6:1 G6:1 C7:3",
    'monatk':  "i7 u1 s-8 G3:10",
    'hurt':    "i3 u1 C4:10",
    'death':   "i4 u1 s-6 C5:30",
    'select':  "i4 u1 C6:2 G6:3",
    'tick':    "i4 u1 E6:2",
    'encounter': "i4 u1 s-30 C7:10 i3 C4:14",
    'run':     "i4 u1 s-20 G6:8",
    'thunder': "i3 u1 C4:16 i8 C4:30",
    'rattle':  "i8 u1 C6:2 r:2 C6:2 r:2 C6:2 r:3 C6:2",
    'sting':   "i4 u2 s-10 A5:6",
    'gameover': "i9 u4 C4:2 r:1 G3:2 r:1 E3:2 r:1 C3:8",
}

def asm():
    out = ['; generated music', 'instruments:']
    for ins in INSTR: out.append('            db %d,%d,%d,%d' % ins)
    out.append('song_table:')
    out.append('            dw ' + ','.join('song_%s' % n.lower() for n in SONG_ORDER))
    for i, n in enumerate(SONG_ORDER): out.append('MUS_%s equ %d' % (n, i + 1))
    total = 0
    for n in SONG_ORDER:
        S = SONGS[n]
        out.append('song_%s: dw %s' % (n.lower(), ','.join('%s_c%d' % (n.lower(), k) for k in range(3))))
        for k, ch in enumerate(S['ch']):
            data = compile_channel(ch)
            lab = '%s_c%d' % (n.lower(), k)
            total += len(data) + 3
            tail = 'dw %s' % lab if S['loop'] else ''
            out.append('%s: db %s' % (lab, ','.join(map(str, data))))
            out.append('            db %s' % ('254' if S['loop'] else '255'))
            if S['loop']: out.append('            dw %s' % lab)
    for n, s in SFX.items():
        data = compile_channel(s)
        total += len(data) + 1
        out.append('sfx_%s: db %s,255' % (n, ','.join(map(str, data))))
    out.append('; music+sfx bytes: %d' % total)
    return '\n'.join(out) + '\n'

if __name__ == '__main__':
    a = asm(); print(a.splitlines()[-1])
