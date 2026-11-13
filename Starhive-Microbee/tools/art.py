"""STARHIVE sprites, star field and HUD layout.

Pixels are 40-column dots: about 1.33x wider than a line is tall on a
4:3 screen, so round things are drawn a third taller than wide. Sprites
are colour-index art; each 8-pixel column of a sprite takes one colour
(its most common ink), and the engine clears a one-pixel halo around
every sprite so it reads over anything."""
import numpy as np
import gfx
from gfx import *

K = {'W': WHITE, 'w': GREY, 'd': DGREY, 'C': BCYAN, 'c': CYAN, 'Y': YELLOW, 'y': BROWN,
     'R': BRED, 'r': RED, 'M': BMAGENTA, 'm': MAGENTA, 'G': BGREEN, 'g': GREEN, 'B': BBLUE, 'b': BLUE}


def A(*rows):
    return gfx.parse_art(rows, K)


# ---- the player: the Hornet (facing up), two engine flickers
HORNET1 = A(
    '.......WW.......',
    '.......WW.......',
    '......WCCW......',
    '......WCCW......',
    '.....WWCCWW.....',
    '.....WWWWWW.....',
    'Y...WWWWWWWW...Y',
    'Y...WWWyyWWW...Y',
    'YY.WWWWyyWWWW.YY',
    'YYYWWWWWWWWWWYYY',
    'YYYYWWWWWWWWYYYY',
    '.YYYYWWWWWWYYYY.',
    '..YY.WWWWWW.YY..',
    '.....WW..WW.....',
    '.....RR..RR.....',
    '.....R....R.....',
)
HORNET2 = A(
    '.......WW.......',
    '.......WW.......',
    '......WCCW......',
    '......WCCW......',
    '.....WWCCWW.....',
    '.....WWWWWW.....',
    'Y...WWWWWWWW...Y',
    'Y...WWWyyWWW...Y',
    'YY.WWWWyyWWWW.YY',
    'YYYWWWWWWWWWWYYY',
    'YYYYWWWWWWWWYYYY',
    '.YYYYWWWWWWYYYY.',
    '..YY.WWWWWW.YY..',
    '.....WW..WW.....',
    '.....YY..YY.....',
    '.....RR..RR.....',
    '......R..R......',
)
# ---- Swarm drone (an insectoid fighter, facing down), two wing beats
DRONE1 = A(
    'G..........G',
    '.G........G.',
    '..GGGGGGGG..',
    'GGGGMMMMGGGG',
    'G.GMMMMMMG.G',
    '..GGMMMMGG..',
    '...GGGGGG...',
    '....GMMG....',
    '.....MM.....',
    '.....MM.....',
)
DRONE2 = A(
    '............',
    'GG........GG',
    '..GGGGGGGG..',
    '.GGGMMMMGGG.',
    'GG.MMMMMM.GG',
    '..GGMMMMGG..',
    '...GGGGGG...',
    '....GMMG....',
    '.....MM.....',
    '.....MM.....',
)
SHOT = A('C', 'W', 'W', 'W', 'W', 'C', 'C')
BULLET = A('.M.', 'MWM', 'MWM', 'MWM', '.M.')


SPRITES = [
    ('SP_HORNET1', HORNET1),
    ('SP_HORNET2', HORNET2),
    ('SP_DRONE1', DRONE1),
    ('SP_DRONE2', DRONE2),
    ('SP_SHOT', SHOT),
    ('SP_BULLET', BULLET),
]


def sprite_lib(base=0x2800, limit=0x5800):
    data = bytearray()
    labels = {}
    for name, art in SPRITES:
        labels[name] = base + len(data)
        data += gfx.sprite_frame(art)
    assert base + len(data) <= limit, 'sprite library full'
    return bytes(data), labels


# ---- the far star field: 4 column textures, each 44 lines tall, cut
# into 4 glyphs a column (map row mod 4). They are rotated against the
# scroll each frame so these stars move at half speed.
STAR_FIRST = 624            # glyph numbers 624..639 (bank 4, codes F0-FF)
STAR_COLOUR = BLUE


def star_textures(seed=7):
    rng = np.random.default_rng(seed)
    tex = []
    for v, n in enumerate((1, 1, 0, 2)):
        t = [0] * 44
        for i in range(n):
            y = int(rng.integers(0, 44))
            x = int(rng.integers(0, 8))
            t[y] |= 0x80 >> x
        tex.append(t)
    return tex


def star_glyph(tex, v, p, ph=0):
    return [tex[v][(11 * p + j + ph) % 44] for j in range(11)]


# ---- HUD: one line of text in the top band; each region holds its
# text at all 11 scroll phases (2 cells a column)
class Region:
    def __init__(self, name, col0, ncols, colour, text=''):
        self.name, self.col0, self.ncols, self.colour, self.text = name, col0, ncols, colour, text


def hud_regions():
    return [
        Region('score', 1, 7, WHITE),
        Region('lhi', 10, 2, BRED, 'HI'),
        Region('hi', 13, 7, YELLOW, '0050000'),
        Region('rows', 23, 5, BCYAN),
        Region('idle', 34, 5, BGREEN),
    ]


if __name__ == '__main__':
    from PIL import Image
    imgs = []
    for name, art in SPRITES:
        h, w = art.shape
        rgb = np.zeros((h, w, 3), np.uint8)
        for y in range(h):
            for x in range(w):
                if art[y, x] >= 0:
                    rgb[y, x] = PAL[art[y, x]]
        imgs.append(rgb)
    H = max(i.shape[0] for i in imgs)
    canvas = np.zeros((H + 4, sum(i.shape[1] + 6 for i in imgs), 3), np.uint8) + 30
    x = 0
    for i in imgs:
        canvas[2:2 + i.shape[0], x + 3:x + 3 + i.shape[1]] = i
        x += i.shape[1] + 6
    im = Image.fromarray(canvas)
    im.resize((im.width * 8, im.height * 6), Image.NEAREST).save('/tmp/claude-0/sprites.png')
