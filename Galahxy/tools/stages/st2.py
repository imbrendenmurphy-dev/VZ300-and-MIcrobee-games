"""stage 2: BATH-TIME NEBULA (pastel palette: o buff, w cyan, c magenta sky, m orange)
Someone left the bath running... in space."""
from art import *
ASM = 'stage2.asm'
PAL = 1
SPR = {}
SPR['DUCK'] = (frames("""
..ooo...
mmowo...
..oooooo
.ooooooo
.oooooo.
..oooo..
""", """
..ooo...
mmowo...
..oooooo
.oowwooo
.oooooo.
..oooo..
"""), 4)
SPR['BUBBLE'] = (frames("""
..www..
.w...w.
w.o...w
w.....w
.w...w.
..www..
""", """
..www..
.w...w.
w..o..w
w.....w
.w...w.
..www..
"""), 4)
SPR['SOAP'] = (frames("""
.mmmmm.
mmommmm
mmmmmmm
.mmmmm.
""", """
.mmmmm.
mmmmomm
mmmmmmm
.mmmmm.
"""), 4)
SPR['SHAMPOO'] = (frames("""
..w..
.www.
.ooo.
.omo.
.omo.
.ooo.
""", """
.w...
.www.
.ooo.
.omo.
.omo.
.ooo.
"""), 4)
SPR['BRUSH'] = (frames("""
ow......
owmmmmmm
ow......
""", """
wo......
wommmmmm
wo......
"""), 4)
SPR['FLANNEL'] = (frames("""
.ooooo.
ooooooo
owowooo
ooooooo
o.o.o.o
""", """
.ooooo.
ooooooo
owowooo
ooooooo
.o.o.o.
"""), 4)
SPR['BATHBOMB'] = (frames("""
.mmm.
mwmmm
mmmmm
mmmom
.mmm.
""", """
.mmm.
mmmwm
mmmmm
mommm
.mmm.
"""), 4)
SPR['PLUG'] = (frames("""
...w...
..w.w..
...w...
.mmmmm.
ooooooo
"""), 4)
SPR['DROP'] = (frames("""
.w.
www
wow
.w.
"""), 4)
SPR['JET'] = (frames("""
.wowowowowow
wwwwwwwwwwww
.owowowowowo
""", """
.owowowowowo
wwwwwwwwwwww
.wowowowowow
"""), 4)
SHOWER = """
..................ooo..
................ooooo..
..............oooo.....
............oooo.......
.....mmmmmmmooo........
...mmooooooooomm.......
..moowwooooowwoom......
.mooowwooooowwooom.....
.moooooooooooooooom....
mooooommmmmmmoooooom...
moooooooooooooooooom...
.mmmmmmmmmmmmmmmmmm....
..w..w..w..w..w..w.....
.w..w..w..w..w..w......
..w..w..w..w..w..w.....
.......................
"""
SPR['SHOWER'] = (frames(SHOWER, variant(SHOWER, {12: ".w..w..w..w..w..w......", 13: "..w..w..w..w..w..w.....", 14: ".w..w..w..w..w..w......"})), 1)
ADM = """
...........mmmmmmmmmmm..........
.........mmmmmmwwwmmmmmm........
........mmmmmmmmmmmmmmmmm.......
..........oooooooooooo..........
.........oooooooooooooo.........
........ooowwooooooooooo........
........ooowcooooooooooo........
...mmmmmmooooooooooooooo........
..mmmmmmmmoooooooooooooo........
...mmmmmmooooooooooooooo........
.........oooooooooooooo.........
.......oooooooooooooooooooo.....
.....ooooooooooooooooooooooooo..
....oooooooooowwwwwwoooooooooooo
...oooooooooowwwwwwwwooooooooooo
...ooooooooooowwwwwwooooooooooo.
...oooooooooooooooooooooooooooo.
....oooooooooooooooooooooooooo..
.....oooooooooooooooooooooooo...
..wwwwwwwwwwwwwwwwwwwwwwwwwwwwww
.w.ww.ww.ww.ww.ww.ww.ww.ww.ww.w.
................................
"""
SPR['ADMIRAL'] = (frames(ADM,
    variant(ADM, {6: "..mmmmmmooowcooooooooooo........", 7: ".mmmmmmmmooooooooooooooo........",
                  8: "..........oooooooooooooo........", 9: "..mmmmmmmooooooooooooooo........",
                  10: "...mmmmmmoooooooooooooo........."}),
    variant(ADM, {4: ".........ommmmooooooooo.........", 5: "........ooowwmmooooooooo........",
                  7: "..mmmmmmmooooooooooooooo........", 8: ".mmmmmmmmmoooooooooooooo........"})), 1)
ORDER = ['DUCK', 'BUBBLE', 'SOAP', 'SHAMPOO', 'BRUSH', 'FLANNEL', 'BATHBOMB', 'PLUG', 'DROP', 'JET', 'SHOWER', 'ADMIRAL']

TUNES = {
    # "Bath-time Waltz": three slow blips to the bar
    'stage': (2, 7, "C4 . E4 G4 . . C4 . F4 A4 . . D4 . F4 A4 . . G3 . D4 G4 . . "
                    "C4 . E4 G4 . . A3 . E4 A4 . . D4 . F4 B4 . . C5 . G4 E4 . . "),
    'mid':   (2, 6, "A3 . C4 . E4 . A3 . D4 . F4 . G#3 . B3 . E4 . A3 . . . . . "),
    'boss':  (2, 6, "E3 . E3 . B3 . E3 . G3 . F#3 . E3 . D3 . "
                    "E3 . E3 . B3 . E3 . C4 . B3 . A3 . B3 . "),
}

def sky():
    """far off: drifting bubbles, a claw-foot bath, a bar of soap, a towel on a rail"""
    rnd = random.Random(22)
    w = SKY_C * 4; cv = canvas(w, SH, C_)
    x = 4
    while x < w - 30:
        k = rnd.random()
        if k < 0.4:                                   # a bubble cluster
            for i in range(3):
                r = rnd.choice([2, 3]); cx = x + 4 + i * 7; cy = rnd.randint(3, 8)
                disc(cv, cx, cy, r, r - 1, W_); disc(cv, cx, cy, r - 1, max(0, r - 2), C_); cv[cy - 1][cx - 1] = O_
            x += 28
        elif k < 0.7:                                 # claw-foot bath
            rect(cv, x, 5, 26, 2, O_); rect(cv, x + 1, 7, 24, 3, O_); rect(cv, x + 3, 10, 20, 1, O_)
            rect(cv, x + 4, 11, 2, 1, M_); rect(cv, x + 20, 11, 2, 1, M_)
            rect(cv, x + 22, 1, 1, 4, W_); rect(cv, x + 19, 1, 3, 1, W_)
            for d in (5, 9, 13): disc(cv, x + d, 4, 2, 1, W_)
            x += 34
        else:                                         # towel on a rail
            rect(cv, x, 3, 22, 1, W_); rect(cv, x + 4, 4, 12, 7, M_)
            for yy in range(5, 11, 2): rect(cv, x + 4, yy, 12, 1, O_)
            x += 30
    return cv

def tiles(cv, x0, x1):
    """bathroom floor: a tiled rim, then big tiles with grout"""
    for x in range(x0, x1):
        for y in range(0, 6):
            cv[y][x] = O_ if y in (1, 4) else (W_ if (x // 4 + y // 3) % 2 else C_)
        for y in range(6, GH):
            cv[y][x] = W_ if (x % 16 == 0 or (y - 6) % 6 == 0) else O_

def foam(cv, x, n):
    for i in range(n): disc(cv, x + i * 5, 4 - (i % 2), 4, 3, O_)

def ground():
    segs = {}
    w = 320 * 4; cv = canvas(w, GH, C_); tiles(cv, 0, w)
    for fx in range(40, w - 60, 200): foam(cv, fx, 5)
    for sx in range(140, w - 60, 320):                 # a sponge
        rect(cv, sx, 0, 14, 6, M_)
        for d in (2, 6, 10): cv[2][sx + d] = O_; cv[4][sx + d + 1] = O_
    for tx in range(260, w - 60, 400):                 # a tap
        rect(cv, tx, 0, 3, 6, W_); rect(cv, tx - 6, 0, 9, 2, W_); rect(cv, tx - 6, 2, 2, 2, W_); cv[5][tx - 5] = O_
    segs['intro'] = cv
    w = 32 * 4; cv = canvas(w, GH, C_); tiles(cv, 0, w); segs['loop'] = cv
    # THE DEEP END: open bath water with foam caps
    w = 240 * 4; cv = canvas(w, GH, C_)
    for x in range(w):
        top = 4 + int(1.6 * math.sin(x * math.pi / 16))
        cv[top][x] = O_; cv[top + 1][x] = O_ if x % 8 < 5 else W_
        for y in range(top + 2, GH): cv[y][x] = W_
        if x % 8 == 3: cv[9 + (x // 8) % 3 * 3][x] = O_; cv[9 + (x // 8) % 3 * 3][x + 1] = O_
    for fx in range(70, w - 40, 160): foam(cv, fx, 3)
    segs['deep'] = cv
    # the plughole
    w = 64 * 4; cv = canvas(w, GH, C_); tiles(cv, 0, w)
    for px in range(20, w, 128):
        disc(cv, px + 20, 12, 18, 5, M_); disc(cv, px + 20, 12, 15, 4, C_)
        for d in range(-12, 13, 6): rect(cv, px + 20 + d, 9, 2, 7, M_)
    segs['drain'] = cv
    return segs
