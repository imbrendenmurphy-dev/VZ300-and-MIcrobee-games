"""The title scene for the Microbee: the original's title (BILBIES! in chunky
letters as ground to walk on, a plank from the hatch, earth below) made
twice the size, filling the 512 x 160 screen (256 x 80 level pixels)."""
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'orig'))
_cwd = os.getcwd()
os.chdir(os.path.join(HERE, 'orig'))
import levels as L          # noqa: E402
from lvlkit import Level    # noqa: E402
from art import pack        # noqa: E402
os.chdir(_cwd)


def title_level():
    t = Level('Title', n=10, rate=40, save=10, minutes=9, width=256, height=80, bg='dusk')
    rows, wdt = L.logo_bitmap()                 # 128 x 16, chars G Y R .
    big = []
    for r in rows:
        line = ''.join(c * 2 for c in r)
        big += [line, line]                     # 256 x 32
    t.image(0, 26, 64, pack(big))
    t.hatch = (8, 4)
    t.rect('wood', 4, 16, 200, 2)
    t.exit = (238, 69)
    t.ground('earth', 0, 255, 70, rough=1, seed=7)
    t.edges('G', None)
    return t
