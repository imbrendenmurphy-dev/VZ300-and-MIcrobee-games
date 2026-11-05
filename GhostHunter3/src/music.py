# executed in gen.py namespace: note table + songs
NAMES = {'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'A':9,'A#':10,'B':11}
LOOPRATE = 3546900.0 / 126
def nidx(tok):
    name = tok[:-1]; octv = int(tok[-1])
    return (octv - 2) * 12 + NAMES[name] + 1
L.append("; ---- note step table (index 1 = C2)")
steps = [0]
for i in range(1, 73):
    f = 65.406 * 2 ** ((i - 1) / 12.0)
    steps.append(int(round(f * 65536 / LOOPRATE)))
L.append("notetab:")
L.append("    dw " + ",".join(str(s) for s in steps))
def song(name, eighth, *chans, loop=False):
    for ci, txt in enumerate(chans):
        toks = txt.split()
        ev = []
        for t in toks:
            if t == '-':
                ev[-1][1] += eighth
            elif t == 'r':
                ev.append([0, eighth])
            else:
                ev.append([nidx(t), eighth])
        # merge rests
        out = []
        for n, d in ev:
            while d > 255:
                out += [n, 255]; d -= 255
            out += [n, d]
        out.append(0xFE if loop else 0xFF)
        L.append("mus_%s_%d:" % (name, ci))
        db(out)
# GH3 title: a creeping minor-key march with a walking bass; short, separate notes
TITLE_M = """
E4 G4 B4 - A#4 A4 G4 -  F#4 A4 C5 - B4 - r -  E4 G4 B4 - D5 C5 B4 A4  G4 - F#4 - E4 - r -
B4 - B4 C5 D5 - C5 B4   A4 - A4 B4 C5 - B4 A4  G4 B4 E5 - D#5 - B4 -   E5 - - - r - r -
E5 D5 C5 B4 A4 G4 F#4 E4  F#4 G4 A4 B4 C5 - B4 -  E5 D5 C5 B4 A4 C5 B4 A4  G4 - B4 - E4 - r -
C5 - C5 B4 A4 - G4 -   F#4 - A4 - D#4 - F#4 -   E4 G4 B4 E5 D#5 B4 F#4 A4  G4 - F#4 - E4 - r -
"""
def bassbar(root, hi=None):
    lo = root + '2'; hi = (hi or root) + '3'
    return "%s r %s r %s r %s %s " % (lo, hi, lo, hi, lo)
TITLE_B = "".join(bassbar(r) for r in "E D E B G A B E C D A E A B E B".split())
L = LOVL
song("title", 7, TITLE_M, TITLE_B, loop=True)
L = LMAIN
song("start", 5, "A4 C5 E5 A5 G#5 E5 B4 G#4 A4 - - - E5 - A5 - - - r r",
     "A2 - - - E2 - - - A2 - - - E3 - A2 - - - r r")
song("clear", 4, "E5 G5 C6 - G5 C6 - - r", "C3 - G3 - C4 - - - r")
song("death", 3, "E5 D#5 D5 C#5 C5 B4 A#4 A4 G#4 G4 F#4 F4 E4 - D4 - - - C#4 - - - C4 - - - - - - r",
     "r")
song("over", 9, "G4 - - F#4 - - F4 - - E4 - - - - - r", "G2 - - F#2 - - F2 - - E2 - - - - - r")
L = LOVL
song("inter", 6, "C5 E5 G5 E5 F5 A5 G5 E5  D5 F5 E5 C5 D5 B4 C5 r  C5 E5 G5 C6 B5 G5 A5 F5  G5 E5 D5 B4 C5 - r r",
     "C3 r G2 r F2 r G2 r  D3 r G2 r C3 r G2 r  C3 r E3 r F3 r D3 r  G2 r G2 r C3 - r r", loop=True)
L = LMAIN
song("bonus", 4, "A4 C5 E5 C5 A4 C5 E5 A5 G4 B4 D5 B4 G4 B4 D5 G5", "A2 r A2 r A2 r A2 r G2 r G2 r G2 r G2 r", loop=True)
L = LOVL
song("hiscore", 5, "C5 E5 G5 C6 B5 G5 C6 - - - r r", "C3 - G3 - E3 - C3 - - - r r")
L = LMAIN
song("super", 3, "C5 E5 G5 C6 G5 E5 C5 r C6 - r r", "r")
