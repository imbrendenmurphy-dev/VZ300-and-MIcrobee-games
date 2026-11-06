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


# title: a jumpy A-minor alarm tune, short punchy notes
TITLE_M = """
A4 r A4 C5 E5 r D5 C5  B4 r G4 B4 D5 r C5 B4  A4 r A4 C5 E5 r A5 G5  E5 - - - r r r r
F5 r F5 E5 D5 r C5 D5  E5 r E5 D5 C5 r B4 C5  D5 r B4 r G4 r B4 D5  A4 - - - r r r r
A4 r C5 r E5 r A5 r  G5 r E5 r C5 r E5 r  F5 r D5 r A4 r D5 r  E5 r B4 r G#4 r B4 r
A4 r C5 r E5 r A5 r  G5 r F5 r E5 r D5 r  C5 r B4 r G#4 r B4 r  A4 - - - r r r r
"""
song("title", 7, TITLE_M, bass("A G A E F E G A A G F E A G E A"), loop=True)
# in game: tense creeping arpeggios
GAME_M = """
E5 r A4 r C5 r E5 r  D5 r G4 r B4 r D5 r  C5 r F4 r A4 r C5 r  B4 r E4 r G#4 r B4 r
E5 r A4 r C5 r E5 r  F5 r A4 r D5 r F5 r  E5 r C5 r A4 r C5 r  B4 r G#4 r E4 r r r
"""
GAME_B = bass("A G F E A D A E", "{lo} r r r {hi} r r r ")
song("game", 6, GAME_M, GAME_B, loop=True)
song("hurry", 4, GAME_M, GAME_B, loop=True)
song("start", 5, "A4 C5 E5 A5 - E5 A5 - C6 - - - r r", "A2 - E3 - A2 - C3 - A2 - - - r r")
song("clear", 4, "E5 G#5 B5 E6 - B5 C#6 D#6 E6 - - - r r", "E3 - B2 - E3 - B2 - E3 - - - r r")
song("death", 3, "E5 D#5 D5 C#5 C5 B4 A#4 A4 - - G#4 - - G4 - - F#4 - - - F4 - - - - - r", "r")
song("over", 9, "A4 - - G4 - - F4 - - E4 - - - - - r", "A2 - - G2 - - F2 - - E2 - - - - - r")
song("hiscore", 5, "A4 C5 E5 A5 G5 E5 A5 - - - r r", "A2 - E3 - C3 - A2 - - - r r")
song("bonus", 4, "A5 E5 C5 E5 A5 E5 C5 E5 G5 D5 B4 D5 G5 D5 B4 D5 F5 C5 A4 C5 F5 C5 A4 C5 E5 B4 G#4 B4 E5 - r r",
     "A2 r A3 r A2 r A3 r G2 r G3 r G2 r G3 r F2 r F3 r F2 r F3 r E2 r E3 r E2 r r r", loop=True)
song("trap", 3, "A5 E5 A5 - r", "r")
song("inter", 5, "C5 r E5 r G5 G5 E5 r  D5 r F5 r A5 A5 F5 r  E5 r G5 r C6 B5 A5 G5  F5 r D5 r C5 r r r",
     "C3 r G2 r C3 r G2 r  D3 r A2 r D3 r A2 r  E3 r B2 r E3 r B2 r  F2 r G2 r C3 r r r", loop=True)
song("ending", 6, """
A4 - C5 E5 A5 - E5 C5  F4 - A4 C5 F5 - C5 A4  G4 - B4 D5 G5 F5 E5 D5  E5 - B4 - G#4 - r -
A4 - C5 E5 A5 - E5 C5  F4 - A4 C5 D5 - F5 A5  G5 A5 G5 F5 E5 D5 B4 G#4  A4 - - - r r r r
""", bass("A F G E A F G A"), loop=True)
song("oneup", 3, "A5 C#6 E6 - A5 C#6 E6 - - r", "r")
song("info", 6, "A4 r C5 r E5 r C5 A4 G4 r B4 r D5 - r r F4 r A4 r C5 r A4 F4 E4 r G#4 r B4 - r r",
     "A2 r E3 r A2 r E3 r G2 r D3 r G2 r D3 r F2 r C3 r F2 r C3 r E2 r B2 r E2 r r r", loop=True)
