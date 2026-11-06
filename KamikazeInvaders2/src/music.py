# executed in gen.py namespace: note table + songs (all original tunes, BPM 2026)
# Style: gritty two-voice beeper, short separated notes (engine silences the
# last frame of every note), simple tunes that aren't screechy (mostly octave 4-5).
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}
LOOPRATE = 3546900.0 / 126


def nidx(tok):
    return (int(tok[-1]) - 2) * 12 + NAMES[tok[:-1]] + 1


L.append("; ---- note step table (index 1 = C2)")
steps = [0]
for i in range(1, 73):
    f = 65.406 * 2 ** ((i - 1) / 12.0)
    steps.append(int(round(f * 65536 / LOOPRATE)))
L.append("notetab:")
L.append("    dw " + ",".join(str(s) for s in steps))


def song(name, eighth, *chans, loop=False):
    for ci, txt in enumerate(chans):
        ev = []
        for t in txt.split():
            if t == '-':
                ev[-1][1] += eighth
            elif t == 'r':
                ev.append([0, eighth])
            else:
                ev.append([nidx(t), eighth])
        out = []
        for n, d in ev:
            while d > 255:
                out += [n, 255]; d -= 255
            out += [n, d]
        out.append(0xFE if loop else 0xFF)
        L.append("mus_%s_%d:" % (name, ci))
        db(out)


def bass(roots, pat="{lo} r {hi} r {lo} {lo} {hi} r "):
    return "".join(pat.format(lo=r + '2', hi=r + '3') for r in roots.split())


# Title: a cocky minor-key march - "here they come"
TITLE_M = """
E4 r E4 r G4 r A4 -  B4 r A4 r G4 E4 r r  D4 r D4 r F#4 r G4 -  A4 r G4 r F#4 D4 r r
E4 r E4 r G4 r A4 -  B4 r D5 r E5 - D5 B4  A4 r G4 r F#4 r D4 r  E4 - - - r r r r
B4 r B4 r C5 r B4 -  A4 r G4 r A4 B4 r r  G4 r G4 r A4 r G4 -  F#4 r E4 r F#4 G4 r r
E4 r G4 r B4 r E5 -  D5 r B4 r A4 G4 r r  F#4 r A4 r D5 r F#4 r  E4 - - - r r r r
"""
song("title", 6, TITLE_M, bass("E E D D E E D E E A G D E B D E"), loop=True)

# In-game: tense pulsing loop
GAME_M = """
A4 r r A4 r r C5 r  B4 r r G4 r r A4 r  A4 r r A4 r r E5 r  D5 r C5 r B4 r G4 r
F4 r r F4 r r A4 r  G4 r r E4 r r G4 r  E4 r r G#4 r r B4 r  E5 r r D5 r B4 G#4 r
"""
GAME_B = bass("A A A G F F E E", "{lo} r {lo} r {hi} r {lo} r ")
song("game", 5, GAME_M, GAME_B, loop=True)
# breach: urgent alarm over the bass
song("breach", 4, "A5 r E5 r A5 r E5 r A5 r E5 r G#5 r E5 r", "A2 r A2 r A3 r A2 r A2 r A2 r A3 r E3 r", loop=True)
# bonus round: bouncy major shooting-gallery tune
song("bonus", 4, """
C5 r E5 r G5 r E5 r  C5 r E5 r G5 - r r  D5 r F5 r A5 r F5 r  D5 r F5 r A5 - r r
E5 r G5 r C6 r G5 r  F5 r A5 r C6 - A5 r  G5 r F5 r E5 r D5 r  C5 - - r G4 r r r
""", bass("C C D D C F G C"), loop=True)
# jingles
song("start", 5, "E4 r G4 r B4 r E5 - - r D5 r E5 - - - r r",
     "E2 - r r E2 - r r B2 - - r E2 - - - r r")
song("clear", 4, "A4 C5 E5 A5 - r G5 A5 - - - r r", "A2 - E3 - A2 - E3 - A2 - - r r")
song("sector", 5, "E5 r E5 r E5 r C5 - E5 r G5 - - r G4 - - - r r",
     "C3 r C3 r C3 r C3 - C3 r G2 - - r G2 - - - r r")
song("death", 3, "E5 D#5 D5 C#5 C5 B4 A#4 A4 - - G#4 - - G4 - - F#4 - - - F4 - - - - - r", "r")
song("over", 8, "A4 - - G4 - - F4 - - E4 - - - - - r", "A2 - - G2 - - F2 - - E2 - - - - - r")
song("hiscore", 5, "E5 G5 B5 E6 D6 B5 E6 - - - r r", "E3 - B2 - G3 - E3 - - - r r")
song("oneup", 3, "E5 G5 B5 - E5 G5 B5 - - r", "r")
song("boom", 2, "C3 r B2 r A#2 r A2 r G#2 r G2 r F#2 r F2 - - - r", "r")
song("info", 6, "A4 r C5 r E5 r C5 A4 G4 r B4 r D5 - r r F4 r A4 r C5 r A4 F4 E4 r G#4 r B4 - r r",
     "A2 r E3 r A2 r E3 r G2 r D3 r G2 r D3 r F2 r C3 r F2 r C3 r E2 r B2 r E2 r r r", loop=True)
song("ending", 6, """
A4 - C5 E5 A5 - E5 C5  G4 - B4 D5 G5 - D5 B4  F4 - A4 C5 F5 - C5 A4  E4 - G#4 B4 E5 - r -
A4 - C5 E5 A5 - E5 C5  G4 - B4 D5 G5 - B5 A5  F5 E5 D5 C5 B4 A4 G#4 B4  A4 - - - r r r r
""", bass("A G F E A G F A"), loop=True)
