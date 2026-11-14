"""Lay out crypt 20, THE TREASURY (40 x 22), by stamping the earlier crypts'
set pieces on a field of earth.  Run once; the result, caves/20_treasury.txt,
is an ordinary cave file and can be edited by hand afterwards."""
import os
W, H = 40, 22
g = [['.'] * W for _ in range(H)]
for x in range(W):
    g[0][x] = g[H - 1][x] = '#'
for y in range(H):
    g[y][0] = g[y][W - 1] = '#'


def stamp(x, y, rows):
    for j, r in enumerate(rows):
        for i, c in enumerate(r):
            if c != '?':
                g[y + j][x + i] = c


BELFRY = ["..o..", ".....", ".W W.", ".WbW.", ".W W.", ".WWW."]
VAULT = ["...o...", ".......", ".WWcWWW", ".W* **W", ".W$ .*W", ".WWWWWW"]
LEDGE = ["..T   W", ".WWWW W", ".W**W W", ".W*+W W", ".WWWWWW"]
GRATE = ["oooooooooo", "..........", "mmmmmmmmmm", "          ", "          ", "WWWW.WWWWW"]
stamp(2, 2, BELFRY)             # pull the clod at (3,3) from (3-1... see the solve line
stamp(9, 2, VAULT)
stamp(18, 2, BELFRY)
stamp(25, 2, LEDGE)
stamp(33, 2, BELFRY[:1] and ["..*..", ".*.*.", "..*..", ".....", ".h...", "....."])
# the knights' gallery across the middle
for x in range(1, W - 1):
    g[9][x] = 'W'
    g[10][x] = ' '
    g[11][x] = 'W'
for x in (6, 20, 34):
    g[9][x] = '.'
for x in (12, 28):
    g[11][x] = '.'
g[10][1] = 'k'
g[10][W - 2] = 'k'
# the south: the grate vault, the locked treasure room, loose gems
stamp(4, 13, GRATE)
g[16][3] = g[17][3] = 'W'
g[16][14] = g[17][14] = 'W'
g[18][3] = g[18][14] = 'W'
stamp(19, 13, ["WWWWWWWWW", "W$.*.*.$W", "D...v...W", "W*.*.*.*W", "WWWWWWWWW"])
stamp(31, 13, ["..y..", ".....", "*...*", ".....", "..*.."])
for x, y in ((16, 19), (30, 19), (36, 16), (2, 19)):
    g[y][x] = '*'
g[1][1] = 'P'
g[20][W - 1] = 'X'
rows = [''.join(r) for r in g]
head = """name:  THE TREASURY
hint:  ALL YOU HAVE LEARNT. TAKE YOUR PICK
quota: 30
time:  360
magic: 40
gem:   30 60
theme: dirt=BROWN wall=RED steel=YELLOW boulder=GREY cracked=BRED grate=BMAGENTA
; The last crypt: two belfries, a cracked vault, a keg ledge, the knights'
; gallery, a grate vault and a locked treasure room.  There are far more
; gems than the gate asks for, so there is more than one way through.
; solve: @3,3 r L w9 @19,3 r L w9 ~3,14 R12 w14 ! X
map:
"""
open(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'caves', '20_treasury.txt'), 'w').write(head + '\n'.join(rows) + '\n')
print('\n'.join(rows))
