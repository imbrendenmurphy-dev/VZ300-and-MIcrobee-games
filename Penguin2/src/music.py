# executed in gen.py namespace: note table + songs (all original tunes)
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


TITLE_M = """
G4 - B4 D5 G5 - D5 B4  C5 - E5 G5 E5 - C5 -  D5 - F#5 A5 G5 F#5 E5 D5  B4 - G4 - A4 - r -
G4 - B4 D5 G5 - D5 B4  C5 - E5 G5 A5 - G5 E5  D5 E5 D5 C5 B4 A4 F#4 A4  G4 - - - r r r r
E5 - E5 F#5 G5 - E5 -  D5 - D5 E5 F#5 - D5 -  C5 - E5 - D5 - C5 B4  A4 - C5 - B4 - A4 -
G4 A4 B4 D5 G5 - F#5 -  E5 F#5 G5 E5 D5 - B4 -  C5 - A4 - D5 - F#4 -  G4 - - - r r r r
"""
song("title", 7, TITLE_M, bass("G C D G G C D G E D C A G C D G"), loop=True)
GAME_M = """
A4 r C5 r E5 r C5 r  B4 r D5 r E5 r D5 r  C5 r A4 r G4 r A4 B4  C5 r B4 r A4 r r r
F4 r A4 r C5 r A4 r  G4 r B4 r D5 r B4 r  A4 r C5 r E5 D5 C5 B4  A4 r E4 r A4 r r r
"""
GAME_B = bass("A E A A F G A A", "{lo} r {hi} r {lo} r {hi} r ")
song("game", 6, GAME_M, GAME_B, loop=True)
song("hurry", 4, GAME_M, GAME_B, loop=True)
song("start", 5, "G4 B4 D5 G5 - D5 G5 - B5 - - - r r", "G2 - D3 - G2 - B2 - G2 - - - r r")
song("clear", 4, "D5 F#5 A5 D6 - A5 B5 C#6 D6 - - - r r", "D3 - A2 - D3 - A2 - D3 - - - r r")
song("death", 3, "B4 A#4 A4 G#4 G4 F#4 F4 E4 - - D#4 - - D4 - - C#4 - - - C4 - - - - - r", "r")
song("over", 9, "E4 - - D4 - - C4 - - B3 - - - - - r", "A2 - - G2 - - F2 - - E2 - - - - - r")
song("hiscore", 5, "C5 E5 G5 C6 B5 G5 C6 - - - r r", "C3 - G2 - E3 - C3 - - - r r")
song("bonus", 4, "E5 G5 B5 G5 E5 G5 B5 E5 D5 F#5 A5 F#5 D5 F#5 A5 D5 C5 E5 G5 E5 B4 D#5 F#5 B5 E5 - B4 - E5 - r r",
     "E2 r E3 r E2 r E3 r D2 r D3 r D2 r D3 r C2 r C3 r B2 r B2 r E2 r E3 r E2 r r r", loop=True)
song("crystal", 3, "C5 E5 G5 C6 E5 G5 C6 E6 - - C6 - - - r", "C3 - G2 - C3 - G2 - - - C3 - - - r")
song("dance", 5, "G4 r B4 r D5 D5 B4 r  C5 r E5 r G5 G5 E5 r  D5 r F#5 r A5 G5 F#5 E5  D5 r B4 r G4 r r r",
     "G2 r D3 r G2 r D3 r  C3 r G2 r C3 r G2 r  D3 r A2 r D3 r A2 r  G2 r D3 r G2 r r r", loop=True)
song("ending", 6, """
C5 - E5 G5 C6 - G5 E5  F5 - A5 C6 A5 - F5 -  G5 - B5 D6 C6 B5 A5 G5  E5 - C5 - D5 - r -
C5 - E5 G5 C6 - G5 E5  F5 - A5 C6 D6 - C6 A5  G5 A5 G5 F5 E5 D5 B4 D5  C5 - - - r r r r
""", bass("C F G C C F G C"), loop=True)
song("oneup", 3, "G5 B5 D6 - G5 B5 D6 - - r", "r")
song("info", 6, "E5 r G5 r A5 r G5 E5 D5 r E5 r G5 - r r C5 r D5 r E5 r G5 E5 D5 r C5 r D5 - r r",
     "C3 r G2 r C3 r G2 r G2 r D3 r G2 r D3 r A2 r E3 r A2 r E3 r G2 r D3 r G2 r r r", loop=True)
