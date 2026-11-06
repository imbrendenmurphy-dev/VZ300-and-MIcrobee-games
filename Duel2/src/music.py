# executed in gen.py namespace: note table + songs (all original tunes, BPM 2026)
# Two-voice pin-pulse engine from Ghost Hunter 2 / Penguin 2 / Tennis II.  Every note's last
# frame is silent, so notes stay separate (the gritty, un-slurred Cybernoid-title sound).
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


# title: "Tally-Ho Two-Step" - jaunty, cheeky, a bit of swagger
TITLE_M = """
G4 r B4 r D5 - G5 r  F#5 r E5 r D5 - r r  E5 r C5 r A4 r C5 r  D5 - - - r r r r
G4 r B4 r D5 - G5 r  A5 r G5 r F#5 r E5 r D5 r B4 r G4 r A4 r  G4 - - - r r r r
C5 r E5 r G5 - E5 r  D5 r B4 r G4 - r r  A4 r C5 r E5 r D5 r  B4 - G4 - r r r r
E5 r E5 r D5 r C5 r  B4 r D5 r G5 - r r  A5 r F#5 r D5 r E5 r  G5 - - - r r r r
"""
song("title", 6, TITLE_M, bass("G E C D G D G G C G A G E G D G"), loop=True)

# attract info pages: easy hangar swing
INFO_M = """
D5 r F#5 r A5 r F#5 r  G5 r E5 r C5 - r r  B4 r D5 r G5 r B4 r  A4 - - - r r r r
D5 r F#5 r A5 r D6 r  C6 r A5 r F#5 - r r  G5 r E5 r C5 r A4 r  G4 - - - r r r r
"""
song("info", 7, INFO_M, bass("D C G D D A D G", "{lo} r r {hi} {lo} r {hi} r "), loop=True)

# battle: tense minor loop, sparse so the guns cut through
BATTLE_M = """
A4 r r A4 C5 r E5 r  D5 r r C5 B4 r G4 r  A4 r r A4 C5 r E5 r  F5 - E5 - D5 - r r
A4 r r A4 C5 r E5 r  G5 r r F5 E5 r C5 r  D5 r E5 r F5 r D5 r  E5 - - - r r r r
"""
song("battle", 5, BATTLE_M, bass("A G A D A C D E", "{lo} r {lo} r {hi} r {lo} r "), loop=True)

# bonus round: balloon bust - bouncy
BONUS_M = """
C5 r G4 r C5 r E5 r  G5 r E5 r C5 r r r  D5 r A4 r D5 r F5 r  A5 r F5 r D5 r r r
E5 r C5 r E5 r G5 r  C6 r G5 r E5 r C5 r  D5 r G4 r B4 r D5 r  C5 - - - r r r r
"""
song("bonus", 5, BONUS_M, bass("C C D D C C G C", "{lo} r {hi} r {lo} r {hi} r "), loop=True)

# ending: Ace of Aces victory march
END_M = """
G4 - B4 - D5 - G5 -  F#5 - D5 - E5 - - -  C5 - E5 - G5 - C6 -  B5 - A5 - G5 - - -
G4 - B4 - D5 - G5 -  A5 - G5 - E5 - C5 -  D5 - B4 - A4 - F#4 -  G4 - - - r - r -
"""
song("ending", 6, END_M, bass("G D C G G C D G", "{lo} r {hi} r {lo} r {hi} r "), loop=True)

# jingles
song("start", 4, "G4 B4 D5 G5 - D5 G5 - - - r r", "G2 - D3 - G2 - D3 - G2 - r r")
song("round", 4, "D5 r D5 r G5 - - r", "D3 r D3 r G2 - - r")
song("win", 4, "G4 B4 D5 B4 D5 G5 - - r r", "G2 - D3 - G2 - - - r r")
song("duel", 5, "G4 G4 G4 D5 - - B4 C5 D5 - G5 - - - - - r r",
     "G2 G2 G2 B2 - - G2 A2 B2 - G2 - - - - - r r")
song("lose", 8, "E5 - D5 - C5 - B4 - A4 - - - - - r r", "A2 - G2 - F2 - E2 - A2 - - - - - r r")
song("over", 9, "A4 - G4 - F4 - E4 - D4 - E4 - A3 - - - - - r r", "A2 - - - D2 - - - E2 - - - A2 - - - - - r r")
song("hiscore", 5, "G4 B4 D5 G5 F#5 D5 G5 - - - r r", "G2 - D3 - B2 - G2 - - - r r")
song("power", 2, "C6 E6 G6 C6 E6 G6 C7 - r", "r")
song("theatre", 5, "D5 r A4 r D5 r F#5 r A5 - - - F#5 - A5 - D6 - - - r r",
     "D3 r A2 r D3 r A2 r D3 - - - A2 - D3 - D3 - - - r r")
