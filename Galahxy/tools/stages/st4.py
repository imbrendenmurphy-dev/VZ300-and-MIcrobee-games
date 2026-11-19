"""stage 4: SHERBET SEA (pastel palette: o buff, w cyan, c magenta water, m orange)
Dive in! The water's fizzy."""
from art import *
ASM = 'stage4.asm'
PAL = 1
SPR = {}
SPR['FISH'] = (frames("""
..mmm..m
.mmmmmmm
mwmmmmm.
.mmmmmmm
..mmm..m
""", """
..mmm.m.
.mmmmmm.
mwmmmmmm
.mmmmmm.
..mmm.m.
"""), 4)
SPR['PUFFER'] = (frames("""
.o.o.o.
ooooooo
owoooo.
ooooooo
ommmoo.
ooooooo
.o.o.o.
""", """
o..o..o
.ooooo.
owooooo
.ooooo.
ommmooo
.ooooo.
o..o..o
"""), 4)
SPR['JELLY'] = (frames("""
.wwwww.
wwowoww
wwwwwww
wwwwwww
.w.w.w.
w.w.w..
.w.w.w.
""", """
.wwwww.
wwowoww
wwwwwww
wwwwwww
w.w.w.w
.w.w.w.
w.w.w..
"""), 4)
SPR['CRAB'] = (frames("""
m......m
mm.mm.mm
.mmmmmm.
mmwmmwmm
.m.mm.m.
""", """
.m....m.
mm.mm.mm
.mmmmmm.
mmwmmwmm
m..mm..m
"""), 4)
SPR['CLAM'] = (frames("""
.ooooo.
ooooooo
mmmmmmm
ooooooo
.ooooo.
""", """
.ooooo.
ooooooo
..www..
ooooooo
.ooooo.
"""), 4)
SPR['SEAHORSE'] = (frames("""
.mm..
mwmm.
.mmm.
..mmm
..mm.
.mm..
.m...
.mm..
""", """
.mm..
mwmm.
.mmm.
..mmm
..mm.
.mm..
..m..
.mm..
"""), 4)
SPR['GEYSER'] = (frames("""
.......
..ooo..
.ooooo.
ooocooo
""", """
.w.w.w.
..ooo..
.ooooo.
ooowooo
"""), 4)
SPR['FIZZ'] = (frames("""
.w.w.
w.w.w
.wow.
w.w.w
.w.w.
""", """
w.w.w
.w.w.
w.o.w
.w.w.
w.w.w
"""), 4)
SPR['CHEST'] = (frames("""
.mmmmmmm.
mmmwwwmmm
mmmmmmmmm
ooooooooo
mmmmwmmmm
mmmmmmmmm
"""), 4)
SPR['TORP'] = (frames("""
.ooooo.w
oooooooo
.ooooo.w
""", """
.ooooow.
oooooooo
.ooooow.
"""), 4)
SPR['TENTACLE'] = (frames("""
.www.
.www.
.wow.
.www.
.www.
.wow.
.www.
.www.
.wow.
.www.
.www.
.wow.
.www.
.www.
.wow.
wwwww
wwwww
.www.
""", """
.www.
.wow.
.www.
.www.
.wow.
.www.
.www.
.wow.
.www.
.www.
.wow.
.www.
.www.
.wow.
.www.
wwwww
wwwww
.www.
"""), 4)
SPR['SHOAL'] = (frames("""
..w.....w...w...
.www..w....www..
..w..www....w...
......w...w.....
.........www....
"""), 4)
SUB = """
........................
..........oo............
..........oo............
.........mmmm...........
....oooooooooooooo......
..oooooooooooooooooo.mm.
.ooowwooowwooowwoooooomm
oooowwooowwooowwooooommm
.ooooooooooooooooooooomm
..mmmmmmmmmmmmmmmmmm.mm.
....mmmmmmmmmmmmmm......
......mmmmmmmmmm........
........mmmmmm..........
..........mm............
........................
........................
"""
SPR['SUB'] = (frames(SUB, variant(SUB, {5: "..oooooooooooooooooo.m..", 6: ".ooowwooowwooowwooooomm.", 7: "oooowwooowwooowwoooommmm", 8: ".ooooooooooooooooooooomm", 9: "..mmmmmmmmmmmmmmmmmm.m.."})), 1)
QUEEN = """
............m..m..m..m..........
............mmmmmmmmmm..........
............mwmmwmmwmm..........
.........wwwwwwwwwwwwwwww.......
.......wwwwwwwwwwwwwwwwwwww.....
.....wwwwwwwwwwwwwwwwwwwwwwww...
....wwwwwoooowwwwwwwoooowwwwww..
....wwwwwocoowwwwwwwocoowwwwww..
...wwwwwwoooowwwwwwwoooowwwwwww.
...wwwwwwwwwwwwwwwwwwwwwwwwwwww.
...wwwwwwwwwwwmmmmmwwwwwwwwwwww.
...wwwwwwwwwwwwwwwwwwwwwwwwwwww.
....wwwwwwwwwwwwwwwwwwwwwwwwww..
.....o.wwo.wwo.wwo.wwo.wwo.wo...
....o..w.o.w.o.w.o.w.o.w.o.w.o..
.....o.w..ow..ow..ow..ow..ow.o..
....o..w.o.w.o.w.o.w.o.w.o.w.o..
.....o..w.o.w.o.w.o.w.o.w.o.o...
....o...w.o.w.o.w.o.w.o.w.o..o..
.........o...o...o...o...o......
................................
................................
"""
SPR['QUEEN'] = (frames(QUEEN,
    variant(QUEEN, {10: "...wwwwwwwwwwmmmmmmmwwwwwwwwwww.", 11: "...wwwwwwwwwwmcccccmwwwwwwwwwww.", 12: "....wwwwwwwwwmmmmmmmwwwwwwwwww.."}),
    variant(QUEEN, {5: ".....wwwwmmwwwwwwwwwwwmmwwwwww..", 6: "....wwwwwommowwwwwwwommowwwwww..", 10: "...wwwwwwwwwwmmmmmmmwwwwwwwwwww."})), 1)
ORDER = ['FISH', 'PUFFER', 'JELLY', 'CRAB', 'CLAM', 'SEAHORSE', 'GEYSER', 'FIZZ', 'CHEST', 'TORP', 'TENTACLE', 'SHOAL', 'SUB', 'QUEEN']

TUNES = {
    # "Sherbet Sea": slow and floaty
    'stage': (2, 8, "E4 . . B4 . . G4 . . E4 . . D4 . . A4 . . F#4 . . D4 . . "
                    "C4 . . G4 . . E4 . . C4 . . B3 . . F#4 . . D#4 . . B3 . . "),
    'mid':   (2, 6, "D3 . F3 . A3 . D4 . C#4 . A3 . F3 . E3 . "),
    'boss':  (2, 6, "F#3 . F#3 . C#4 . F#3 . A3 . G#3 . F#3 . E3 . "
                    "F#3 . C#4 . F#4 . C#4 . D4 . C#4 . B3 . C#4 . "),
}

def sky():
    """far off: coral, kelp, a sunken ice-cream cone or two"""
    rnd = random.Random(44)
    w = SKY_C * 4; cv = canvas(w, SH, C_)
    x = 3
    while x < w - 26:
        k = rnd.random()
        if k < 0.4:                                  # branching coral
            cx = x + 8
            rect(cv, cx, 5, 2, 7, M_)
            for dx, top in ((-5, 3), (5, 2), (-2, 1), (3, 5)):
                rect(cv, cx + dx, top, 2, 6 - top + 3, M_); rect(cv, min(cx, cx + dx), top + 5, abs(dx) + 2, 1, M_)
                cv[top - 1][cx + dx] = O_
            x += 22
        elif k < 0.75:                               # kelp
            for s in range(3):
                for y in range(1 + s, SH):
                    cv[y][x + 2 + s * 5 + int(1.4 * math.sin(y / 1.6 + s))] = W_
            x += 20
        else:                                        # a sunken cone
            for i in range(8):
                hw = max(0, 4 - i // 2); rect(cv, x + 6 - hw, 4 + i, 2 * hw + 1, 1, M_)
            disc(cv, x + 6, 2, 4, 2, O_)
            x += 16
    return cv

def sand(cv, x0, x1):
    for x in range(x0, x1):
        top = 5 + (1 if (x // 12) % 2 else 0)
        for y in range(top, GH): cv[y][x] = O_
        if x % 8 == 2:
            y = 9 + (x // 8) % 3 * 3; cv[y][x] = W_; cv[y][x + 1] = W_; cv[y][x + 2] = W_

def weed(cv, x, h, c):
    for y in range(6 - h, 7): cv[y][x + (1 if y % 2 else 0)] = c

def ground():
    segs = {}
    w = 320 * 4; cv = canvas(w, GH, C_); sand(cv, 0, w)
    for wx in range(20, w - 20, 44): weed(cv, wx, 4 + (wx // 44) % 2, W_); weed(cv, wx + 3, 3, W_)
    for sx in range(90, w - 60, 260):                 # shells and starfish
        disc(cv, sx, 10, 3, 2, M_); cv[10][sx] = O_
        for d in (-2, 0, 2): cv[14][sx + 60 + d] = M_
        cv[13][sx + 60] = M_; cv[15][sx + 60] = M_
    for cx in range(200, w - 80, 420):                # a coral clump on the bed
        rect(cv, cx, 1, 3, 5, M_); rect(cv, cx + 5, 0, 3, 6, M_); rect(cv, cx + 10, 2, 3, 4, M_)
    segs['intro'] = cv
    w = 32 * 4; cv = canvas(w, GH, C_); sand(cv, 0, w)
    for wx in range(20, w - 4, 44): weed(cv, wx, 4, W_)
    segs['loop'] = cv
    # THE WRECK: the deck of a sunken ship
    w = 240 * 4; cv = canvas(w, GH, C_)
    for x in range(w):
        for y in range(4, GH): cv[y][x] = M_ if (y - 4) % 5 else O_
        if x % 24 == 0:
            for y in range(4, GH): cv[y][x] = O_
        cv[3][x] = O_
        if x % 40 < 3: cv[0][x] = O_; cv[1][x] = O_; cv[2][x] = O_            # rail posts
    for px in range(60, w - 30, 120):                 # portholes
        disc(cv, px, 11, 4, 3, O_); disc(cv, px, 11, 3, 2, C_)
    segs['wreck'] = cv
    # the queen's court: a floor of shells
    w = 64 * 4; cv = canvas(w, GH, C_)
    for x in range(w):
        for y in range(5, GH): cv[y][x] = O_
        cv[5][x] = W_
    for sx in range(4, w, 16):
        for row in (8, 13):
            disc(cv, sx + (8 if row == 13 else 0), row + 1, 5, 2, W_); disc(cv, sx + (8 if row == 13 else 0), row + 2, 4, 1, O_)
    for px in range(28, w, 64): rect(cv, px, 0, 4, 5, W_); rect(cv, px - 2, 0, 8, 1, M_)
    segs['court'] = cv
    return segs
