# Dawn Patrol 2 - original music, compiled for the 3-channel beeper engine
FS = 3546900 / 192.0
NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']


def semis(n):
    # 'C2' .. 'B7'
    name = n[:-1]; octv = int(n[-1])
    return NAMES.index(name) + 12 * (octv - 2)


def notetab():
    out = []
    for i in range(72):
        f = 65.406 * 2 ** (i / 12.0)
        out.append(min(65535, int(round(f * 65536 / FS))))
    return out


def tok(t, drum=False):
    if t == '.':
        return 0
    if t == '-':
        return 1
    if t == 'K':
        return 0x80
    if t == 'S':
        return 0x81
    if t == 'H':
        return 0x82
    return 2 + semis(t)


def bar(a, b, c):
    A = a.split(); B = b.split(); C = c.split()
    assert len(A) == 16 and len(B) == 16 and len(C) == 16, (a, b, c)
    out = []
    for i in range(16):
        out += [tok(A[i]), tok(B[i]), tok(C[i])]
    return out


D1 = "K . H . S . H . K . K H S . H ."
D2 = "K . H . S . H K . K H . S H S S"
DQ = "K . . . . . . . K . . . . . . ."
NO = ". . . . . . . . . . . . . . . ."

# ------------------------------------------------------------ title theme (E minor march)
def b_bass(r, f):
    # driving eighths: root root oct root fifth root oct fifth
    return "%s . %s . %s . %s . %s . %s . %s . %s ." % (r, r, up(r), r, f, r, up(r), f)


def up(n):
    s = semis(n) + 12
    return NAMES[s % 12] + str(s // 12 + 2)


TITLE_BARS = {
 'in1': bar(NO, b_bass('E2', 'B2'), D1),
 'in2': bar(NO, b_bass('E2', 'B2'), D2),
 'a1': bar("E4 . . G4 . B4 . . E5 . . D5 . B4 . .", b_bass('E2', 'B2'), D1),
 'a2': bar("C5 . . B4 . A4 . . G4 . . A4 . B4 . .", b_bass('C2', 'G2'), D1),
 'a3': bar("E4 . . G4 . B4 . . E5 . . F#5 . G5 . .", b_bass('E2', 'B2'), D1),
 'a4': bar("F#5 . . E5 . D#5 . . B4 . . . - . . .", b_bass('B2', 'F#2'), D2),
 'b1': bar("C5 . . . E5 . . . G5 . . . E5 . D5 .", b_bass('C2', 'G2'), D1),
 'b2': bar("D5 . . . F#5 . . . A5 . . . F#5 . E5 .", b_bass('D2', 'A2'), D1),
 'b3': bar("E5 . G5 . F#5 . E5 . D5 . B4 . A4 . G4 .", b_bass('E2', 'B2'), D1),
 'b4': bar("F#4 . . . A4 . . . B4 . . . . . - .", b_bass('B2', 'F#2'), D2),
 'c1': bar("B4 . E5 . G5 . E5 . B5 . G5 . E5 . G5 .", b_bass('E2', 'B2'), D1),
 'c2': bar("A4 . C5 . E5 . C5 . A5 . E5 . C5 . E5 .", b_bass('A2', 'E2'), D1),
 'c3': bar("G4 . B4 . D5 . B4 . G5 . D5 . B4 . D5 .", b_bass('G2', 'D2'), D1),
 'c4': bar("F#4 . A4 . B4 . D#5 . F#5 . . . E5 . - .", b_bass('B2', 'F#2'), D2),
}
TITLE_ORDER = ['in1', 'in2', 'a1', 'a2', 'a3', 'a4', 'b1', 'b2', 'b3', 'b4',
               'a1', 'a2', 'a3', 'a4', 'c1', 'c2', 'c3', 'c4', '*2']

# ------------------------------------------------------------ mission briefing / tally (bright, C major)
MB = {
 'm1': bar("C5 . G4 . C5 . E5 . G5 . . . E5 . . .", "C2 . C3 . G2 . C3 . C2 . C3 . G2 . C3 .", D1),
 'm2': bar("F5 . . . E5 . D5 . C5 . . . D5 . . .", "F2 . F3 . C3 . F3 . G2 . G3 . D3 . G3 .", D1),
 'm3': bar("E5 . . . G5 . . . A5 . . . G5 . E5 .", "A2 . A3 . E3 . A3 . F2 . F3 . C3 . F3 .", D1),
 'm4': bar("D5 . . . G4 . . . C5 . . . . . . .", "G2 . G3 . D3 . G3 . C2 . C3 . G2 . C3 .", D2),
}
MB_ORDER = ['m1', 'm2', 'm3', 'm4', '*0']

# ------------------------------------------------------------ game over (slow A minor, ends)
GO = {
 'g1': bar("A4 . . . . . . . G4 . . . E4 . . .", "A2 . . . . . . . E2 . . . . . . .", DQ),
 'g2': bar("F4 . . . . . E4 . D4 . . . . . . .", "D2 . . . . . . . A2 . . . . . . .", DQ),
 'g3': bar("C4 . . . D4 . . . E4 . . . . . . .", "F2 . . . . . . . E2 . . . . . . .", DQ),
 'g4': bar("A3 . . . . . . . . . . . - . . .", "A2 . . . . . . . . . . . - . . .", "K . . . . . . . . . . . . . . ."),
}
GO_ORDER = ['g1', 'g2', 'g3', 'g4']

# ------------------------------------------------------------ level complete fanfare (short, ends)
FF = {
 'f1': bar("G4 . C5 . E5 . G5 . . . E5 . G5 . . .", "C3 . . . G2 . . . C3 . . . G2 . . .", "K . . . S . . . K . K . S . S S"),
 'f2': bar("C6 . . . . . . . . . . . - . . .", "C3 . . . . . . . . . . . - . . .", "K . . . . . . . . . . . . . . ."),
}
FF_ORDER = ['f1', 'f2']


def song_asm(name, speed, ins, bars, order):
    lines = ['%s:' % name, '        db %d' % speed, '        db ' + ','.join(str(x) for x in ins)]
    pats = {}
    olines = []
    for o in order:
        if o.startswith('*'):
            idx = int(o[1:])
            olines.append('        dw $FF00, %s_o%d' % (name, idx))
            continue
        olines.append('        dw %s_%s' % (name, o))
    # order with position labels
    out = []
    pos = 0
    for o in order:
        if o.startswith('*'):
            out.append('        dw $FF00, %s_o%d' % (name, int(o[1:])))
        else:
            out.append('%s_o%d: dw %s_%s' % (name, pos, name, o))
            pos += 1
    if not order[-1].startswith('*'):
        out.append('        dw 0')
    lines += out
    for k, v in bars.items():
        lines.append('%s_%s: db %s' % (name, k, ','.join(str(x) for x in v)))
    return '\n'.join(lines)


def music_asm():
    s = ['NOTETAB: dw ' + ','.join(str(x) for x in notetab())]
    s.append(song_asm('SONG_TITLE', 8, [0x70, 4, 0x24, 0x58, 1, 0x30, 0x40, 3, 0x10], TITLE_BARS, TITLE_ORDER))
    s.append(song_asm('SONG_BRIEF', 7, [0x78, 5, 0x20, 0x50, 1, 0x30, 0x40, 3, 0x10], MB, MB_ORDER))
    s.append(song_asm('SONG_OVER', 12, [0x60, 2, 0x18, 0x50, 1, 0x28, 0x40, 3, 0x10], GO, GO_ORDER))
    s.append(song_asm('SONG_FANFARE', 7, [0x80, 3, 0x30, 0x58, 1, 0x30, 0x40, 3, 0x10], FF, FF_ORDER))
    return '\n'.join(s) + '\n'


if __name__ == '__main__':
    print(music_asm()[:2000])
