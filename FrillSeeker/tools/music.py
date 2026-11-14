"""The soundtrack, for the front end's three-voice-and-drums player
(src/front.asm). Everything here is original.

THE FRILLSEEKER STRUT - a twelve-bar shuffle in E, the blues scale with
its flat five left in: a growling staccato bass riff, a lead that scoops
into its notes and leaves gaps, chord stabs on the back of each beat
(the chord rattled through as a fast arpeggio, the way the old Hewson
tunes faked harmony on one voice), a kick that drops in pitch and a
noise snare. Intro, the head, a busier chorus, then the head again over
stop-time, and round again.

A beat is 24 ticks (a tick is a fiftieth): 125 to the minute, swung -
long 16, short 8.

The notation, a token at a time:
  E2 F#4 Bb3   a note, for the current length      .    a rest
  l16          the length in ticks                 i3   the instrument
  t5 t-7 t0    transpose what follows              @R1  call a pattern
  |            the place the song loops back to
"""
SAMPLE_T = 205
RATE = 3375000.0 / SAMPLE_T

NOTE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def note_no(tok):
    n = NOTE[tok[0]]
    rest = tok[1:]
    while rest[0] in '#b':
        n += 1 if rest[0] == '#' else -1
        rest = rest[1:]
    return n + 12 * (int(rest) - 1) + 1          # C1 = 1


def steps(n=84):
    out = []
    for i in range(1, n + 1):
        f = 32.7032 * 2 ** ((i - 1) / 12.0)
        out.append(int(round(f * 65536 / RATE)))
    return out


# start width, narrowing a tick, floor, flags (1 = noise), slide a tick, arpeggio
INSTR = [
    (0x58, 7, 0x1C, 0, 0, 0),        # 0 bass, held: a fat pulse that narrows to a growl
    (0x58, 9, 0x00, 0, 0, 0),        # 1 bass, plucked: dead after nine ticks
    (0x34, 3, 0x12, 0, 0, 0),        # 2 lead
    (0x20, 2, 0x0C, 0, 0, 0),        # 3 lead, echo
    (0x30, 5, 0x00, 0, 0, 1),        # 4 stab, minor
    (0x30, 5, 0x00, 0, 0, 2),        # 5 stab, major
    (0x30, 5, 0x00, 0, 0, 3),        # 6 stab, seventh
    (0x80, 0x24, 0x00, 0, -70, 0),   # 7 kick: a wide pulse falling fast
    (0xB0, 0x2C, 0x00, 1, 0, 0),     # 8 snare
    (0x40, 0x40, 0x00, 1, 0, 0),     # 9 hat
    (0x2C, 2, 0x10, 0, 0, 4),        # 10 lead in octaves
    (0x70, 0x1C, 0x00, 1, 0, 0),     # 11 snare, soft
]
ARPS = [(0, 3, 7, 12), (0, 4, 7, 12), (0, 4, 7, 10), (0, 12, 0, 12)]


class Song:
    def __init__(self, name):
        self.name = name
        self.pats = {}
        self.chans = []

    def pat(self, name, text):
        self.pats[name] = text

    def chan(self, text):
        self.chans.append(text)

    def compile_tokens(self, text, lab):
        """-> assembler lines (db ... with labels for calls), ticks"""
        out, ticks, length, loop = [], 0, 6, None
        self.loop_at = None
        for tok in text.split():
            if tok == '|':
                out.append('%s_loop:' % lab)
                loop = True
                self.loop_at = ticks
            elif tok == '.':
                out.append('\tdb 0')
                ticks += length
            elif tok[0] == 'l' and tok[1:].isdigit():
                length = int(tok[1:])
                out.append('\tdb %d' % (0x5F + length) if length <= 32 else '\tdb $91,%d' % length)
            elif tok[0] == 'i' and tok[1:].isdigit():
                out.append('\tdb %d' % (0x80 + int(tok[1:])))
            elif tok[0] == 't' and tok[1:].lstrip('-').isdigit():
                out.append('\tdb $93,%d' % (int(tok[1:]) & 255))
            elif tok[0] == '@':
                out.append('\tdb $F0\n\tdw %s_%s' % (self.name, tok[1:]))
                ticks += self.pat_ticks[tok[1:]]
            else:
                out.append('\tdb %d' % note_no(tok))
                ticks += length
        return out, ticks, loop

    def build(self, loops=True):
        L = []
        self.pat_ticks = {}
        for name, text in self.pats.items():
            o, t, _ = self.compile_tokens(text, '')
            self.pat_ticks[name] = t
            L.append('%s_%s:' % (self.name, name))
            L += o + ['\tdb $F1']
        lens = []
        for i, text in enumerate(self.chans):
            lab = '%s_c%d' % (self.name, i)
            o, t, loop = self.compile_tokens(text, lab)
            lens.append((self.loop_at, t))
            L.append(lab + ':')
            L += o
            if loops:
                L.append('\tdb $FE\n\tdw %s' % (lab + '_loop' if loop else lab))
            else:
                L.append('\tdb $FF')
        L.append('%s:\tdw %s' % (self.name, ','.join('%s_c%d' % (self.name, i) for i in range(len(self.chans)))))
        return L, lens


def beat(*xs):
    return ' '.join(xs)


def title():
    s = Song('song_title')
    # ---- the bass: one-bar riffs on E; t5 and t7 move them to A and B
    s.pat('R1', 'i1 l16 E2 l8 E2  l16 G2 l8 A2  l16 . i0 l8 Bb2  i1 l16 A2 l8 G2')
    s.pat('R2', 'i1 l16 E2 l8 E2  l16 G2 l8 A2  l16 B2 l8 D3  l16 B2 l8 G2')
    s.pat('TURN', 'i1 l16 E2 l8 E2  l16 G2 l8 G#2  l16 A2 l8 Bb2  i0 l24 B2')
    s.pat('STOP', 'i1 l16 E2 l8 E2 l72 .')
    chorus = '@R1 @R2 @R1 @R2 t5 @R1 @R2 t0 @R1 @R2 t7 @R1 t5 @R1 t0 @R1 @TURN'
    stop = '@STOP @STOP @STOP @R2 t5 @R1 @R2 t0 @R1 @R2 t7 @R1 t5 @R1 t0 @R1 @TURN'
    s.chan('@R1 @R2 @R1 @R2 | ' + chorus + ' ' + chorus + ' ' + stop)

    # ---- the lead. The head: twelve bars, call and answer
    s.pat('H', ' '.join([
        'i2',
        'l16 E5 l8 D5  l16 E5 l8 .  l8 B4 D5 B4  l16 A4 l8 G4',                 # 1
        'l2 D4 l22 E4  l24 .  l16 . l8 E4  l16 G4 l8 A4',                        # 2
        'l2 A4 l14 Bb4 l8 A4  l16 G4 l8 E4  l24 G4  l16 . l8 E4',                # 3
        'l16 D4 l8 E4  l48 .  l8 B4 D5 E5',                                      # 4
        'l2 F#5 l22 G5  l16 E5 l8 G5  l16 E5 l8 D5  l16 C5 l8 A4',               # 5 (A)
        'l24 C5  l16 A4 l8 C5  l16 A4 l8 G4  l16 E4 l8 G4',                      # 6
        'l16 A4 l8 Bb4  l16 B4 l8 D5  l24 E5  l8 D5 B4 A4',                      # 7 (E)
        'l16 G4 l8 E4  l2 D4 l22 E4  l24 .  l16 . l8 B4',                        # 8
        'l16 D#5 l8 B4  l16 D#5 l8 F#5  l16 A5 l8 F#5  l16 D#5 l8 B4',           # 9 (B)
        'l16 C#5 l8 A4  l16 C#5 l8 E5  l16 G5 l8 E5  l16 C#5 l8 A4',             # 10 (A)
        'l8 E5 D5 B4  l8 A4 Bb4 A4  l16 G4 l8 E4  l24 E4',                       # 11 (E)
        'l24 .  l16 . l8 E4  l16 G4 l8 A4  l2 A4 l22 B4']))                      # 12
    # the second chorus: busier, up the neck, in triplets
    s.pat('S', ' '.join([
        'i2',
        'l8 E5 G5 E5  l8 D5 E5 D5  l8 B4 D5 B4  l16 A4 l8 B4',                   # 1
        'l2 D5 l22 E5  l16 . l8 E5  l8 G5 A5 G5  l16 E5 l8 D5',                  # 2
        'l8 B5 A5 G5  l8 E5 G5 E5  l8 D5 E5 D5  l8 B4 A4 G4',                    # 3
        'l48 E4  l16 . l8 G4  l8 A4 B4 D5',                                      # 4
        'l16 E5 l8 C5  l16 E5 l8 C5  l8 E5 G5 A5  l24 G5',                       # 5 (A)
        'l8 A5 G5 E5  l8 C5 E5 C5  l16 A4 l8 C5  l16 A4 l8 G4',                  # 6
        'l16 E4 l8 G4  l16 A4 l8 Bb4  l16 B4 l8 D5  l16 E5 l8 G5',               # 7 (E)
        'l2 A5 l22 B5  l8 A5 G5 E5  l16 D5 l8 B4  l16 A4 l8 B4',                 # 8
        'l8 B4 D#5 F#5  l16 A5 l8 F#5  l8 D#5 F#5 D#5  l16 B4 l8 A4',            # 9 (B)
        'l8 A4 C#5 E5  l16 G5 l8 E5  l8 C#5 E5 C#5  l16 A4 l8 G4',               # 10 (A)
        'l8 E5 D5 B4  l8 A4 Bb4 A4  l16 G4 l8 E4  l24 E4',                       # 11 (E)
        'l24 .  l16 . l8 E4  l16 G4 l8 A4  l2 A4 l22 B4']))                      # 12
    s.chan('i2 l96 . . . l72 . l8 B4 D5 E5 | @H @S @H')

    # ---- the third voice: a stab on the back of every beat
    s.pat('M', 'i4 l16 . l8 E4  l16 . l8 E4  l16 . l8 E4  l16 . l8 E4')
    s.pat('M2', 'i4 l16 . l8 E4  l16 . l8 E4  l16 . l8 E4  l8 . E4 E4')
    s.pat('D', 'i6 l16 . l8 E4  l16 . l8 E4  l16 . l8 E4  l16 . l8 E4')
    s.pat('H1', 'i4 l16 E4 l8 . l72 .')
    stabs = '@M @M @M @M2 t5 @M @M2 t0 @M @M2 t-5 @D t-7 @D t0 @M t-5 @D t0'
    s.chan('l96 . . . . | ' + stabs + ' ' + stabs + ' @H1 @H1 @H1 @M2 t5 @M @M2 t0 @M @M2 t-5 @D t-7 @D t0 @M t-5 @D t0')

    # ---- drums: kick on one and three, snare on two and four
    s.pat('K', 'i7 l24 C3  i8 l24 C3  i7 l16 C3 l8 .  i8 l24 C3')
    s.pat('K2', 'i7 l24 C3  i8 l24 C3  i7 l16 C3 i7 l8 C3  i8 l24 C3')
    s.pat('F', 'i7 l24 C3  i8 l24 C3  i7 l24 C3  i8 l8 C3 i11 C3 i8 C3')
    s.pat('P', 'i7 l24 C3 l72 .')
    s.pat('P2', 'i7 l24 C3 l48 . i11 l8 C3 C3 i8 C3')
    drums = '@K @K2 @K @K2 @K @K2 @K @K2 @K @K2 @K @F'
    s.chan('l96 . . @K @F | ' + drums + ' ' + drums + ' @P @P @P @P2 @K @K2 @K @K2 @K @K2 @K @F')
    return s


def clear():
    """the region is clear: a run up the blues scale and a big E"""
    s = Song('song_clear')
    s.chan('i1 l8 E2 E2 E2 l16 G2 l8 A2 l16 B2 l8 D3 i0 l72 E2')
    s.chan('i2 l8 E4 G4 A4 l8 B4 D5 E5 l16 G5 l8 B5 i10 l72 E5')
    s.chan('l72 . i5 l72 E4')
    s.chan('i8 l8 C3 i11 C3 C3 i8 C3 i11 C3 C3 i8 C3 C3 C3 i7 l24 C3 l48 .')
    return s


def over():
    """out of hearts: the riff falls down the stairs"""
    s = Song('song_over')
    s.chan('i0 l24 E2 l24 D2 l24 C2 i0 l72 B1')
    s.chan('i2 l16 E4 l8 D4 l16 Bb3 l8 A3 l16 G3 l8 E3 l2 A3 l70 B3')
    s.chan('l72 . i6 l72 B3')
    s.chan('i7 l24 C3 i7 l24 C3 i7 l24 C3 i8 l24 C3 l48 .')
    return s


def ready():
    """a region begins: four bars of the riff's first half"""
    s = Song('song_ready')
    s.chan('i1 l16 E2 l8 E2 l16 G2 l8 A2 l16 B2 l8 D3 i0 l24 E3')
    s.chan('i2 l48 . l8 B4 D5 E5 l24 E5')
    s.chan('i4 l16 . l8 E4 l16 . l8 E4 l16 . l8 E4 l24 .')
    s.chan('i7 l24 C3 i8 l24 C3 i7 l24 C3 i8 l24 C3')
    return s


def build():
    L = ['; generated by tools/music.py', 'note_steps:']
    st = steps()
    for i in range(0, len(st), 12):
        L.append('\tdw ' + ','.join(str(v) for v in st[i:i + 12]))
    L.append('instruments:')
    for d0, dec, dmin, fl, sl, arp in INSTR:
        L.append('\tdb %d,%d,%d,%d\n\tdw %d\n\tdb %d,0' % (d0, dec, dmin, fl, sl & 0xFFFF, arp))
    L.append('arps:')
    for a in ARPS:
        L.append('\tdb %d,%d,%d,%d' % a)
    info = []
    for song, loops in ((title(), True), (clear(), False), (over(), False)):
        o, lens = song.build(loops)
        L += o
        info.append((song.name, lens))
    L.append('jingles:\tdw song_clear,song_over')
    return L, info


if __name__ == '__main__':
    L, info = build()
    for name, lens in info:
        print(name, lens)
