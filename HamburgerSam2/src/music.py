# executed in gen.py namespace: note table + songs (all original tunes, BPM 2026)
# Two-voice pin-pulse engine from Ghost Hunter 2 / Penguin 2 / Tennis II. Every note's last
# frame is silent, so notes stay separate (the gritty, un-slurred sound of the Cybernoid title).
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


# title: "Sizzle Shuffle" - cheeky diner swing
TITLE_M = """
C5 r C5 E5 G5 r A5 G5  r E5 C5 r D5 - r r  E5 r E5 G5 A5 r C6 A5  r G5 E5 r G5 - r r
F5 r F5 A5 C6 r A5 F5  G5 r G5 B5 D6 r B5 G5  C6 r A5 r G5 r E5 r  D5 - E5 - C5 - r r
A5 r A5 r G5 E5 r G5  A5 r C6 r A5 - r r  G5 r G5 r E5 C5 r E5  D5 r E5 r D5 - r r
C5 r C5 E5 G5 r A5 G5  r E5 C5 r D5 - r r  F5 r A5 r G5 r B4 r  C5 - - - r r r r
"""
song("title", 6, TITLE_M, bass("C C A G F G C G A A C G C C G C"), loop=True)

# in the kitchen: "Short Order" - busy, march-like, gets out of the way of the effects
GAME_M = """
E5 r G5 r C6 r G5 r  A5 r G5 r E5 r D5 r  E5 r G5 r C6 r E6 r  D6 - r r r r r r
C6 r A5 r F5 r A5 r  G5 r E5 r C5 r E5 r  D5 r E5 r F5 r D5 r  C5 - r r r r r r
"""
song("game", 5, GAME_M, bass("C F C G F C G C", "{lo} r {hi} r {lo} r {hi} r "), loop=True)

# info pages / Meet the Menu / Top Ten: laid-back shuffle
INFO_M = """
G5 r E5 r G5 r A5 r  G5 r E5 r C5 - r r  D5 r E5 r F5 r A5 r  G5 - - - r r r r
G5 r E5 r G5 r C6 r  B5 r A5 r G5 - r r  F5 r E5 r D5 r B4 r  C5 - - - r r r r
"""
song("info", 7, INFO_M, bass("C A D G C E F C", "{lo} r r {hi} {lo} r {hi} r "), loop=True)

# Order Up! bonus round: chirpy and quick
BONUS_M = """
C6 r G5 r E5 r G5 r  A5 r F5 r C5 r F5 r  G5 r E5 r C5 r E5 r  D5 r G5 r B5 r D6 r
C6 r G5 r E5 r G5 r  A5 r C6 r A5 r F5 r  G5 r B4 r D5 r G5 r  C6 - r r C5 - r r
"""
song("bonus", 4, BONUS_M, bass("C F C G C F G C", "{lo} r {hi} r {lo} r {hi} r "), loop=True)

# ending: the Burger Rush is won
END_M = """
C5 - E5 - G5 - C6 -  A5 - F5 - A5 - C6 -  B5 - G5 - D6 - B5 -  C6 - - - r - r -
E5 - G5 - C6 - E6 -  D6 - C6 - A5 - F5 -  G5 - E5 - D5 - B4 -  C5 - - - r - r -
"""
song("ending", 6, END_M, bass("C F G C C F G C", "{lo} r {hi} r {lo} r {hi} r "), loop=True)

# jingles
song("start", 4, "G4 C5 E5 G5 r G5 E5 G5 C6 - - - r r", "C3 - G2 - C3 - G2 - C3 - - - r r")
song("clear", 4, "C5 E5 G5 C6 r G5 C6 r E6 - D6 - C6 - - - r r",
     "C3 - G2 - C3 - E3 - G3 - G2 - C3 - - - r r")
song("die", 5, "C6 B5 A#5 A5 G#5 G5 F#5 F5 E5 - r D#5 - r D5 - - - r r",
     "r r r r r r r r C3 - r B2 - r C2 - - - r r")
song("over", 9, "G5 - E5 - C5 - r r  D5 - B4 - G4 - r r  C5 - - - - - r r",
     "C3 - - - G2 - r r  G2 - - - D2 - r r  C2 - - - - - r r")
song("life", 3, "C6 E6 G6 C6 E6 G6 C7 - r", "C4 r G3 r C4 r C4 - r")
song("item", 3, "G5 C6 E6 G6 - r", "r")
song("burger", 3, "C6 G5 C6 E6 G6 - r", "C3 - G2 - C3 - r")
song("hiscore", 5, "C5 E5 G5 C6 B5 G5 C6 - - - r r", "C3 - G2 - E3 - C3 - - - r r")
song("order", 3, "E6 G6 C7 - r", "C4 E4 G4 - r")
