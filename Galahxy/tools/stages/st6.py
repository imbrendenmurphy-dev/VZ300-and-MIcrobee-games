"""stage 6: THE GALAH GALAXY (pastel palette: o buff, w cyan, c magenta space, m orange)
The big finish: where every galah comes from."""
from art import *
ASM = 'stage6.asm'
PAL = 1
SPR = {}
SPR['UFO'] = (frames("""
...ww...
..wwww..
oooooooo
mommommo
.oooooo.
""", """
...ww...
..wwww..
oooooooo
ommommom
.oooooo.
"""), 4)
SPR['COMET'] = (frames("""
.oo..m..
oooommm.
oooommmm
.oo..m..
""", """
.oo...m.
oooomm..
oooommm.
.oo...m.
"""), 4)
SPR['ALIEN'] = (frames("""
w.....w
.wwwww.
wwowoww
wwwwwww
.w.w.w.
""", """
.w...w.
.wwwww.
wwowoww
wwwwwww
w.w.w.w
"""), 4)
SPR['ROVER'] = (frames("""
..w.....
.ooooo..
oomoooo.
ooooooo.
.m..m..m
""", """
...w....
.ooooo..
oomoooo.
ooooooo.
m..m..m.
"""), 4)
SPR['DISH'] = (frames("""
o....o
.o..o.
..oo..
..mm..
.mmmm.
""", """
o....o
.owwo.
..oo..
..mm..
.mmmm.
"""), 4)
SPR['ROCKET'] = (frames("""
..oooo..
mooowooo
mooowooo
..oooo..
""", """
..oooo..
.ooowooo
mooowooo
..oooo..
"""), 4)
SPR['METEOR'] = (frames("""
..m.m
.mm..
mmmm.
mmom.
.mm..
""", """
.m..m
..mm.
mmmm.
momm.
.mm..
"""), 4)
SPR['GOLDUFO'] = (frames("""
...mm...
..mmmm..
wwwwwwww
wmwmwmww
.wwwwww.
"""), 4)
SPR['EGG'] = (frames("""
.oo.
oooo
owoo
.oo.
"""), 4)
SPR['BEAK'] = (frames("""
...wwwwwwwww
.wwwwwwwwwww
wwwwwwwwwwww
.wwwwwwwwwww
""", """
....wwwwwwww
.wwwwwwwwwww
wwwwwwwwwwww
..wwwwwwwwww
"""), 4)
SPR['CLAW'] = (frames("""
..www..
..www..
..wmw..
..www..
..www..
..wmw..
..www..
..www..
..wmw..
..www..
..www..
..wmw..
.wwwww.
wwwwwww
ww.w.ww
w..w..w
w..w..w
...w...
"""), 4)
SPR['STARS'] = (frames("""
..w.........o...
.www....w.......
..w..........w..
......o.........
...........w....
"""), 4)
CHOOK = """
......................
.........mm...........
........mmmm..........
.......oooooo.........
......oowooooo........
...mmmoooooooo........
....mmooooooooooooo...
......oooooooooooooo..
.....wwwwwwwwwwwwwwww.
....wwwowwwowwwowwwwwm
...wwwwwwwwwwwwwwwwwmm
....wwwowwwowwwowwwwwm
.....wwwwwwwwwwwwwwww.
.......mm......mm.....
......................
......................
"""
SPR['CHOOK'] = (frames(CHOOK, variant(CHOOK, {9: "....wwwowwwowwwowwwww.", 10: "...wwwwwwwwwwwwwwwwwwm", 11: "....wwwowwwowwwowwwww.", 2: ".......mmmm..........."})), 1)
COCKY = """
...............m...m...m........
..............mm..mm..mm..m.....
.............mmm.mmm.mmm.mm.....
............mmmmmmmmmmmmmmm.....
..........oooooooooooooooooo....
........oooooooooooooooooooooo..
.......oooooooooooooooooooooooo.
......ooooowwooooooooooooooooooo
.....ooooowccwoooooooooooooooooo
....wwwoooowwooooooooooooooooooo
..wwwwwwoooooooooooooooooooooooo
wwwwwwwwwooooooooooooooooooooooo
wwwwwwwwwoooooooooooooooooooooo.
.wwwwwwwooooooooooooooooooooooo.
...wwwwooooooooooooooooooooooo..
.....woooooooooooooooooooooo....
.......oooooooooooooooooooo.....
.........ooooooooooooooooo......
...........oooooooooooooo.......
.............ooooooooooo........
................................
................................
"""
SPR['COCKY'] = (frames(COCKY,
    variant(COCKY, {0: "..........m....m...m...m....m...", 1: "...........mm..mm..mm..mm..mm...", 2: "............mmm.mmm.mmm.mmmm....",
                    12: ".........oooooooooooooooooooooo.", 13: "wwwwwwwwooooooooooooooooooooooo.", 14: ".wwwwwwooooooooooooooooooooooo.."}),
    variant(COCKY, {6: ".......oooommmoooooooooooooooooo", 7: "......ooooowwmmooooooooooooooooo"})), 1)
ORDER = ['UFO', 'COMET', 'ALIEN', 'ROVER', 'DISH', 'ROCKET', 'METEOR', 'GOLDUFO', 'EGG', 'BEAK', 'CLAW', 'STARS', 'CHOOK', 'COCKY']

TUNES = {
    # "The Galah Galaxy": the title march, slowed down and spaced out
    'stage': (2, 7, "G3 . B4 . D4 . G4 . E3 . C5 . B4 . A4 . "
                    "D3 . A4 . F#4 . D4 . G3 . B4 . D5 . . . "
                    "C4 . E5 . G4 . E5 . B3 . D5 . G4 . D5 . "
                    "A3 . C5 . F#4 . A4 . G4 . . . G3 . . . "),
    'mid':   (2, 5, "E3 . G3 . B3 . E4 . D4 . B3 . G3 . F#3 . "),
    'boss':  (2, 5, "G3 . G3 . D4 . G3 . A#3 . A3 . G3 . F#3 . "
                    "G3 . D4 . G4 . D4 . D#4 . D4 . C4 . D4 . "),
}

def sky():
    """far off: ringed planets, a crescent moon, stars"""
    rnd = random.Random(66)
    w = SKY_C * 4; cv = canvas(w, SH, C_)
    for i in range(70):
        cv[rnd.randint(0, SH - 1)][rnd.randrange(0, w, 4) + 1] = W_ if i % 3 else O_
    x = 10
    while x < w - 40:
        k = rnd.random()
        if k < 0.45:                                 # ringed planet
            cx = x + 12
            disc(cv, cx, 6, 6, 4, M_); rect(cv, cx - 11, 6, 23, 1, O_); rect(cv, cx - 4, 5, 9, 1, M_); cv[4][cx - 2] = O_
            x += 44
        elif k < 0.75:                               # crescent moon
            cx = x + 6
            disc(cv, cx, 5, 5, 4, O_); disc(cv, cx + 3, 4, 4, 3, C_)
            x += 36
        else:                                        # a little rocket
            rect(cv, x + 2, 4, 10, 3, O_); rect(cv, x, 5, 2, 1, O_); rect(cv, x + 12, 3, 2, 5, M_); cv[5][x + 5] = W_
            x += 40
    return cv

def moon(cv, x0, x1, cheese=False):
    base = M_ if cheese else O_; hole = C_ if cheese else W_
    for x in range(x0, x1):
        top = 5 + (1 if (x // 10) % 3 == 0 else 0)
        for y in range(top, GH): cv[y][x] = base
    for cx in range(x0 + 14, x1 - 8, 26):
        cy = 9 + (cx // 26) % 3 * 3
        disc(cv, cx, cy, 4 if (cx // 26) % 2 else 3, 1, hole)
        if not cheese: rect(cv, cx - 3, cy + 1, 7, 1, W_)

def ground():
    segs = {}
    w = 320 * 4; cv = canvas(w, GH, C_); moon(cv, 0, w)
    for fx in range(100, w - 60, 300):               # flags and a lander
        rect(cv, fx, 0, 1, 6, W_); rect(cv, fx + 1, 0, 5, 3, M_)
        rect(cv, fx + 80, 1, 9, 3, O_); cv[4][fx + 80] = W_; cv[5][fx + 79] = W_; cv[4][fx + 88] = W_; cv[5][fx + 89] = W_
    segs['intro'] = cv
    w = 32 * 4; cv = canvas(w, GH, C_); moon(cv, 0, w); segs['loop'] = cv
    w = 240 * 4; cv = canvas(w, GH, C_); moon(cv, 0, w, True)
    for mx in range(60, w - 30, 200):                # a mouse-sized wedge cut out, and a cracker
        rect(cv, mx, 2, 12, 4, O_)
        for d in (2, 6, 10): cv[3][mx + d] = M_
    segs['cheese'] = cv
    # the nest: woven twigs
    w = 64 * 4; cv = canvas(w, GH, C_)
    for x in range(w):
        for y in range(4, GH):
            cv[y][x] = M_ if ((x + y * 2) // 4) % 2 else O_
        cv[4][x] = O_
        if x % 12 < 2: cv[3][x] = M_; cv[2][x + 1 if x + 1 < w else x] = M_
    segs['nest'] = cv
    return segs
