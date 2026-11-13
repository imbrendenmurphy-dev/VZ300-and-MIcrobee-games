"""stage 3: TOY BOX TOWERS (main palette: o green, w yellow, c blue sky, m red)
Nobody put the toys away."""
from art import *
ASM = 'stage3.asm'
PAL = 0
SPR = {}
SPR['PLANE'] = (frames("""
...m....
mmmmmmmw
.wmmmmm.
...m....
""", """
...o....
mmmmmmmw
.wmmmmm.
...o....
"""), 4)
SPR['SOLDIER'] = (frames("""
.mmm.
.mmm.
.www.
omwmo
.mmm.
.ooo.
.o.o.
oo.oo
""", """
.mmm.
.mmm.
.www.
omwmo
.mmm.
.ooo.
.o.o.
.ooo.
"""), 4)
SPR['BLOCK'] = (frames("""
mmmmmmmm
mwwwwwwm
mwmmmmwm
mwmmmmwm
mwwwwwwm
mmmmmmmm
""", """
oooooooo
owwwwwwo
owwmmwwo
owwwmwwo
owwwwwwo
oooooooo
"""), 4)
SPR['MARBLE'] = (frames("""
.ooo.
owooo
ooomo
ooooo
.ooo.
""", """
.ooo.
ooowo
omooo
ooooo
.ooo.
"""), 4)
SPR['ROBOT'] = (frames("""
.w..w.
oooooo
omoomo
oooooo
.wwww.
owmmwo
.wwww.
.o..o.
""", """
w....w
oooooo
omoomo
oooooo
.wwww.
owmmwo
.wwww.
.o..o.
"""), 4)
SPR['YOYO'] = (frames("""
..w..
.mmm.
mmwmm
mmwmm
.mmm.
""", """
.w...
.mmm.
mwmwm
mmwmm
.mmm.
"""), 4)
SPR['KITE'] = (frames("""
..m...
.mmm..
mmwmm.
.mmm..
..m.o.
...o..
""", """
..m...
.mmm..
mmwmm.
.mmm..
..mo..
....o.
"""), 4)
SPR['WALNUT'] = (frames("""
.oo.
owoo
oooo
.oo.
"""), 4)
SPR['SABRE'] = (frames("""
...wwwwwwwww
mmowwwwwwwww
...wwwwwwwww
""", """
....wwwwwwww
mmowwwwwwwww
....wwwwwwww
"""), 4)
JACK0 = """
................
................
................
................
................
................
................
................
.mmmmmmmmmmmmmm.
.mwwwwwwwwwwwwm.
.mwmmwwwwwwmmwmo
.mwwwwmmmmwwwwmo
.mwwwwmmmmwwwwm.
.mwmmwwwwwwmmwm.
.mwwwwwwwwwwwwm.
.mmmmmmmmmmmmmm.
"""
JACK1 = """
.....m....m.....
....mmm..mmm....
....wwwwwwww....
...wwcwwwwcww...
...wwwwmmwwww...
....wmmmmmmw....
.....wwwwww.....
......o..o......
.mmmmmmoommmmmm.
.mwwwwwwwwwwwwm.
.mwmmwwwwwwmmwmo
.mwwwwmmmmwwwwmo
.mwwwwmmmmwwwwm.
.mwmmwwwwwwmmwm.
.mwwwwwwwwwwwwm.
.mmmmmmmmmmmmmm.
"""
SPR['JACK'] = (frames(JACK0, JACK1), 1)
NC = """
...........mmmmmmmmmm...........
...........mmmmmmmmmm...........
...........mmmwoowmmm...........
...........mmmmmmmmmm...........
..........oooooooooooo..........
...........wwwwwwwwww...........
...........wccwwwwccw...........
...........wwwwmmwwww...........
..........mmmmwwwwmmmm..........
...........wcwcwcwcww...........
...........wwwwwwwwww...........
............wwwwwwww............
.......mmmmmmmmmmmmmmmmmm.......
.....oommmmmmwwmmmmmmmmmoo......
.....oommmmmmwwmmmmmmmmmoo......
.....wwmmmmmmwwmmmmmmmmmww......
.....wwmmmmmmwwmmmmmmmmmww......
.......mmmmmmoommmmmmmmm........
.......ooooooooooooooooo........
.......mmmmmmmm.mmmmmmmm........
.......mmmmmmmm.mmmmmmmm........
......ooooooooo.ooooooooo.......
"""
SPR['NUTCRACKER'] = (frames(NC,
    variant(NC, {10: "................................", 11: "...........wcwcwcwcww...........", 12: ".......mmmmmwwwwwwwwmmmmm......."}),
    variant(NC, {5: "...........wmmwwwwmmw...........", 6: "...........wccwwwwccw..........."})), 1)
ORDER = ['PLANE', 'SOLDIER', 'BLOCK', 'MARBLE', 'ROBOT', 'YOYO', 'KITE', 'WALNUT', 'SABRE', 'JACK', 'NUTCRACKER']

TUNES = {
    # "Tin Soldier March"
    'stage': (2, 6, "G3 . D4 . G4 . D4 . G3 . B4 . D4 . B4 . "
                    "C4 . E4 . G4 . E4 . D4 . F#4 . A4 . . . "
                    "G3 . D4 . G4 . B4 . C4 . E4 . C5 . . . "
                    "D4 . A4 . F#4 . D4 . G4 . . . . . . . "),
    'mid':   (2, 5, "C4 . . E4 . G4 . . C5 . . G4 . E4 . . D4 . . F4 . A4 . . D5 . . A4 . F4 . . "),
    'boss':  (2, 6, "A3 . A3 . E4 . A3 . C4 . B3 . A3 . G#3 . "
                    "A3 . A3 . E4 . A3 . F4 . E4 . D4 . E4 . "),
}

def letter_block(cv, x, y, c, s=6):
    rect(cv, x, y, s, s - 1, c); rect(cv, x + 1, y + 1, s - 2, s - 3, W_); cv[y + 2][x + 2] = c; cv[y + 2][x + 3] = c

def sky():
    """far off: towers of letter blocks, a toy castle, kites"""
    rnd = random.Random(33)
    w = SKY_C * 4; cv = canvas(w, SH, C_)
    x = 3
    while x < w - 30:
        k = rnd.random()
        if k < 0.5:                                # a block tower
            n = rnd.choice([1, 2]); h = rnd.choice([1, 2])
            for i in range(n):
                hh = h if i == 0 else max(1, h - 1)
                for j in range(hh):
                    letter_block(cv, x + i * 7, SH - 6 - j * 5 + 1, rnd.choice([M_, O_]))
            x += n * 7 + 8
        elif k < 0.75:                             # toy castle
            rect(cv, x, 5, 24, 7, W_)
            for t in (0, 9, 18): rect(cv, x + t, 2, 6, 3, W_); cv[1][x + t] = W_; cv[1][x + t + 2] = W_; cv[1][x + t + 4] = W_
            rect(cv, x + 10, 8, 4, 4, M_); cv[0][x + 12] = M_; cv[0][x + 13] = M_
            for wx in (3, 20): rect(cv, x + wx, 7, 2, 2, C_)
            x += 32
        else:                                      # a kite
            for i in range(4): rect(cv, x + 4 - i, 1 + i, 2 * i + 1, 1, M_)
            for i in range(3): rect(cv, x + 2 + i, 5 + i, 5 - 2 * i, 1, M_)
            cv[8][x + 5] = W_; cv[9][x + 6] = W_; cv[10][x + 5] = W_
            x += 18
    return cv

def crayons(cv, x0, x1):
    """a row of crayons standing along the back of the floor"""
    for x in range(x0, x1):
        k = (x // 6) % 3; c = (M_, W_, O_)[k]; p = x % 6
        if p < 4:
            top = 1 + (1 if p in (0, 3) else 0) + (x // 6) % 2
            for y in range(top, 6): cv[y][x] = c
            if p in (1, 2): cv[top - 1][x] = c

def floor(cv, x0, x1, rug=False):
    for x in range(x0, x1):
        for y in range(6, GH):
            if rug: cv[y][x] = W_ if ((x // 4) + (y // 2)) % 4 == 0 else M_
            else: cv[y][x] = O_ if (y in (6, 12) or (x % 32 == (0 if y < 12 else 16))) else W_

def ground():
    segs = {}
    w = 320 * 4; cv = canvas(w, GH, C_); crayons(cv, 0, w); floor(cv, 0, w)
    for bx in range(80, w - 60, 280):              # stray blocks and a ball
        letter_block(cv, bx, 1, M_); letter_block(cv, bx + 7, 1, O_)
        disc(cv, bx + 60, 9, 3, 2, M_); cv[8][bx + 59] = W_
    for tx in range(180, w - 100, 400):            # a length of train track
        for x in range(tx, tx + 64):
            cv[14][x] = M_; cv[16][x] = M_
            if x % 4 == 0: cv[15][x] = M_
    segs['intro'] = cv
    w = 32 * 4; cv = canvas(w, GH, C_); crayons(cv, 0, w); floor(cv, 0, w); segs['loop'] = cv
    # BLOCK CITY: on the rug
    w = 240 * 4; cv = canvas(w, GH, C_); crayons(cv, 0, w); floor(cv, 0, w, True)
    for x in range(w): cv[6][x] = W_
    segs['city'] = cv
    # the toy chest lid
    w = 64 * 4; cv = canvas(w, GH, C_)
    for x in range(w):
        for y in range(0, 6): cv[y][x] = M_ if y in (0, 5) else (W_ if x % 16 < 2 else C_)
        for y in range(6, GH): cv[y][x] = M_ if ((x // 8) + ((y - 6) // 4)) % 2 else W_
    segs['chest'] = cv
    return segs
