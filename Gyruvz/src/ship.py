"""STARWHIRL - the player's ship at 16 headings (hand drawn: N, NNE, NE, ENE, E;
the rest are mirror images).  Heading 0 = nose up, clockwise in 22.5 degree steps."""
BASE = [
"""
...y...
..yry..
.yyyyy.
ryyyyyr
r.g.g.r
""", """
....y..
...yry.
..yyyy.
ryyyyr.
.r.g...
""", """
.....yy
r..yyy.
.yyry..
..yyy..
..g.r..
""", """
.......
r..yyyy
.yyrry.
gyyy...
.r.....
""", """
rr.....
.yyy...
gyyryyy
.yyy...
rr.....
"""]

def parse(a):
    return [r for r in a.strip().split('\n')]

def vflip(a):
    return list(reversed(a))

def hflip(a):
    return [r[::-1] for r in a]

def headings():
    b = [parse(a) for a in BASE]
    h = b[:]                                  # 0..4
    h += [vflip(b[3]), vflip(b[2]), vflip(b[1]), vflip(b[0])]   # 5..8
    for k in range(9, 16):
        h.append(hflip(h[16 - k]))
    return h
