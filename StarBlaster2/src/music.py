# executed in gen.py namespace: note table + songs (all original tunes, ViBED by BPM 2026)
# Engine: 2-voice pin-pulse beeper from Ghost Hunter 2 / Penguin 2. Notes are
# separated (last frame of each note is silent) for the gritty, chopped sound.
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


# Title: "The Enermy Returns" - a striding minor-key space march
TITLE_M = """
E4 r E4 G4 B4 r E5 r  D5 r B4 r A4 G4 A4 r  B4 r B4 D5 F#5 r B5 r  A5 r F#5 r E5 D5 E5 r
C5 r C5 E5 G5 r C6 r  B5 r G5 r E5 D5 E5 r  D5 r F#5 r A5 r F#5 D5  B4 r - r B4 r r r
E5 r G5 r E5 r B4 r  C5 r E5 r C5 r A4 r  D5 r F#5 r D5 r B4 r  E5 r D5 C5 B4 r r r
E5 r G5 r B5 r G5 r  C6 r B5 r A5 r G5 r  F#5 r G5 A5 B5 r D#5 r  E5 r - r E4 r r r
"""
song("title", 7, TITLE_M, bass("E E B B C C D B E A D E E C B E"), loop=True)

# In-game patrol loop (light, so effects cut through)
GAME_M = """
E4 r r G4 r r A4 r  B4 r A4 r G4 r E4 r  D4 r r F#4 r r A4 r  B4 r A4 r F#4 r D4 r
C4 r r E4 r r G4 r  A4 r G4 r E4 r C4 r  B3 r D#4 r F#4 r B4 r  A4 r G4 r F#4 r D#4 r
"""
GAME_B = bass("E E D D C C B B", "{lo} r r {lo} r {hi} r r ")
song("game", 6, GAME_M, GAME_B, loop=True)

# Boss: driving, chromatic menace
BOSS_M = """
E5 r E5 r F5 r E5 r  D#5 r E5 r G5 r F#5 r  E5 r E5 r F5 r E5 r  B4 r C5 r D#5 r E5 r
A5 r A5 r A#5 r A5 r  G#5 r A5 r C6 r B5 r  E5 r G5 r F#5 r D#5 r  E5 r - r B4 r r r
"""
BOSS_B = bass("E E E E A A E E", "{lo} {lo} {hi} {lo} {lo} {hi} {lo} {hi} ")
song("boss", 4, BOSS_M, BOSS_B, loop=True)

# Warp-in / sector start fanfare
song("start", 5, "B4 r E5 r G5 r B5 - - r A5 r G5 r B5 - - - r r",
     "E2 r E3 r E2 r E3 - - r D3 r D2 r E3 - - - r r")
# Sector clear
song("clear", 4, "E5 G5 B5 E6 - r D6 r E6 - - - r r", "E3 - B2 - E3 r B2 r E3 - - - r r")
# Energy depleted / game over
song("over", 9, "B4 - - A4 - - G4 - - F#4 - - E4 - - - - - r", "E3 - - D3 - - C3 - - B2 - - E2 - - - - - r")
# New high score
song("hiscore", 5, "E5 G5 B5 E6 D6 B5 E6 - - - r r", "E3 - B2 - G3 - E3 - - - r r")
# Mission complete (ending) loop
END_M = """
E5 r G5 r B5 r E6 r  D6 r B5 r A5 r B5 r  C6 r B5 r A5 r G5 r  F#5 r G5 r A5 r B5 r
E5 r G5 r B5 r E6 r  D6 r B5 r G5 r A5 r  B5 r A5 r G5 r F#5 r  E5 r - - r r r r
"""
song("ending", 6, END_M, bass("E B A B E G B E"), loop=True)
# Info pages loop (calm)
song("info", 7, "E5 r B4 r G4 r B4 r  D5 r A4 r F#4 r A4 r  C5 r G4 r E4 r G4 r  B4 r F#4 r D#4 r F#4 r",
     "E2 r r r E3 r r r D2 r r r D3 r r r C2 r r r C3 r r r B1 r r r B2 r r r".replace("B1", "B2"), loop=True)
