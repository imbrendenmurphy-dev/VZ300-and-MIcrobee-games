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


# ---- Dart: a fast red diver (facing down)
DART = A(
    '...R..R...',
    '..RRRRRR..',
    '.RRYYYYRR.',
    'RR.RYYR.RR',
    'R..RYYR..R',
    '...RYYR...',
    '....RR....',
    '....WW....',
)
# ---- Pod: an armoured mine riding the scroll; fires aimed shots
POD1 = A(
    '...CCCC...',
    '.CCwwwwCC.',
    'CwwBBBBwwC',
    'CwBBWWBBwC',
    'CwBBWWBBwC',
    'CwwBBBBwwC',
    '.CCwwwwCC.',
    '...CCCC...',
)
POD2 = A(
    '...CCCC...',
    '.CCwwwwCC.',
    'CwwBBBBwwC',
    'CwBBRRBBwC',
    'CwBBRRBBwC',
    'CwwBBBBwwC',
    '.CCwwwwCC.',
    '...CCCC...',
)
# ---- explosion, three frames
EXPL1 = A(
    '..........',
    '...Y..Y...',
    '....YY....',
    '..YYWWYY..',
    '...YWWY...',
    '..YYWWYY..',
    '....YY....',
    '...Y..Y...',
    '..........',
)
EXPL2 = A(
    '.Y..R..Y..',
    '..YRYYRY..',
    'R.YYWWYY.R',
    '.RYWWWWYR.',
    'YYWWWWWWYY',
    '.RYWWWWYR.',
    'R.YYWWYY.R',
    '..YRYYRY..',
    '.Y..R..Y..',
)
EXPL3 = A(
    'r...r...r.',
    '..r..R..r.',
    '.R..r..R..',
    'r..R...r.r',
    '..r..r....',
    'r...R..r..',
    '.R.r...R.r',
    '..r..r....',
    'r...R...r.',
)
# ---- the Hive Queen (level 1 boss), 40 x 24, facing down. Drawn in
# colour bands to suit one colour per 8-pixel column: claws magenta at the
# sides, wings green, the body red in the middle.
def _queen():
    h, w = 24, 40
    q = np.full((h, w), -1, np.int16)
    yy, xx = np.mgrid[0:h, 0:w]
    cx = 19.5
    band = np.where(np.abs(xx - cx) < 4.5, BRED, np.where(np.abs(xx - cx) < 12.5, BGREEN, BMAGENTA))
    wings = ((xx - cx) / 17.0) ** 2 + ((yy - 7) / 5.5) ** 2 <= 1
    body = ((xx - cx) / 6.0) ** 2 + ((yy - 12) / 10.5) ** 2 <= 1
    q[wings | body] = band[wings | body]
    # wing veins and the body's segments (holes)
    q[(yy == 7) & (np.abs(xx - cx) > 7) & (np.abs(xx - cx) < 15) & ((xx % 3) == 0)] = -1
    q[((yy == 11) | (yy == 15) | (yy == 19)) & body & (np.abs(xx - cx) < 4)] = -1
    q[(yy == 5) & ((np.abs(xx - cx - 2.5) < 1) | (np.abs(xx - cx + 2.5) < 1))] = -1   # eyes
    # claws: down and out from the wing tips, and up for antennae
    for t in range(10):
        for sx in (-1, 1):
            x = int(round(cx + sx * (15 + t * 0.5)))
            y = 9 + t
            if 0 <= x < w and y < h:
                q[y, x] = BMAGENTA
                if 0 <= x - sx < w:
                    q[y, x - sx] = BMAGENTA
            x2 = int(round(cx + sx * (3 + t * 0.6)))
            if t < 5:
                q[4 - t, x2] = BMAGENTA if abs(x2 - cx) > 4.5 else BRED
    return q


QUEEN = _queen()


# ---- Sweeper: a wasp that crosses the screen (yellow and black)
SWEEP1 = A(
    '.ww......ww.',
    '..ww....ww..',
    '..YYYYYYYY..',
    '.YYddYYddYY.',
    'YYYYYYYYYYYY',
    '.YYddYYddYY.',
    '..YYYYYYYY..',
    '....YddY....',
    '.....YY.....',
)
SWEEP2 = A(
    'ww........ww',
    '.ww......ww.',
    '..YYYYYYYY..',
    '.YYddYYddYY.',
    'YYYYYYYYYYYY',
    '.YYddYYddYY.',
    '..YYYYYYYY..',
    '....YddY....',
    '.....YY.....',
)
# ---- Spitter: a wall turret riding the scenery (three-way spread)
SPIT = A(
    '..rRRRRr..',
    '.rRRYYRRr.',
    'rRRYRRYRRr',
    'RRYRWWRYRR',
    'RRYRWWRYRR',
    'rRRYRRYRRr',
    '.rRRYYRRr.',
    '..rRRRRr..',
)


def _banded(mask, bands, cx):
    """colour a boss mask in vertical bands: bands = [(half-width, colour)]"""
    h, w = mask.shape
    q = np.full((h, w), -1, np.int16)
    xx = np.mgrid[0:h, 0:w][1]
    col = np.full((h, w), bands[-1][1], np.int16)
    for hw_, c in reversed(bands):
        col = np.where(np.abs(xx - cx) < hw_, c, col)
    q[mask] = col[mask]
    return q


def _ell(h, w, cx, cy, rx, ry):
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1


def _rockmite():
    """level 2: an armoured crab of rock, 40 x 22"""
    h, w = 22, 40
    cx = 19.5
    m = _ell(h, w, cx, 9, 11, 9)                       # shell
    yy, xx = np.mgrid[0:h, 0:w]
    for sx in (-1, 1):                                 # claws
        m |= _ell(h, w, cx + sx * 15, 16, 4.5, 5)
        m &= ~_ell(h, w, cx + sx * 15, 19, 2, 3)
        for t in range(8):                             # legs
            m[3 + t * 2 // 2, int(cx + sx * (11 + t))] = True
    m[(yy % 4 == 0) & _ell(h, w, cx, 9, 9, 7)] = False  # shell plates
    m[_ell(h, w, cx - 4, 13, 1.2, 1.5) | _ell(h, w, cx + 4, 13, 1.2, 1.5)] = False
    return _banded(m, [(4.5, BRED), (12.5, GREY), (99, BROWN)], cx)


def _warden():
    """level 3 (two of them): a hive guardian, 24 x 16"""
    h, w = 16, 24
    cx = 11.5
    m = _ell(h, w, cx, 7, 5, 7)
    m |= _ell(h, w, cx - 8, 5, 4, 4) | _ell(h, w, cx + 8, 5, 4, 4)
    yy, xx = np.mgrid[0:h, 0:w]
    m &= ~((yy == 7) & (np.abs(xx - cx) < 3))
    m[13:16, int(cx) - 1:int(cx) + 2] = True
    return _banded(m, [(4.5, BCYAN), (99, YELLOW)], cx)


def _hulk():
    """level 4: the wrecked dreadnought, 48 x 20"""
    h, w = 20, 48
    cx = 23.5
    yy, xx = np.mgrid[0:h, 0:w]
    m = (np.abs(xx - cx) < 22 - yy * 0.4) & (yy < 14)
    m |= (np.abs(xx - cx) < 6) & (yy < 20)              # the prow, pointing down
    m &= ~((yy % 5 == 2) & (np.abs(xx - cx) > 7))         # deck lines
    m &= ~(_ell(h, w, cx + 12, 6, 3, 2.5))                # battle damage
    return _banded(m, [(6.5, BRED), (14.5, WHITE), (99, GREY)], cx)


def _hivemind():
    """level 5: the Hive Mind, 40 x 26"""
    h, w = 26, 40
    cx = 19.5
    yy, xx = np.mgrid[0:h, 0:w]
    m = _ell(h, w, cx, 11, 13, 11)
    m &= ~((np.sin(xx * 0.9 + yy * 0.4) > 0.75) & _ell(h, w, cx, 11, 11, 9))  # folds
    for sx in (-1, 1):
        for t in range(9):                                 # tendrils
            x = int(cx + sx * (8 + t * 1.3))
            y = 18 + t
            if y < h and 0 <= x < w:
                m[y, x] = True
                if 0 <= x - sx < w:
                    m[y, x - sx] = True
    m[_ell(h, w, cx, 12, 3, 3)] = True                     # the eye
    return _banded(m, [(4.5, BRED), (12.5, BMAGENTA), (99, MAGENTA)], cx)


ROCKMITE = _rockmite()
WARDEN = _warden()
HULK = _hulk()
HIVEMIND = _hivemind()

# common to every level (same addresses in each level's library), then
# the level's boss
COMMON = [
    ('SP_HORNET1', HORNET1), ('SP_HORNET2', HORNET2),
    ('SP_DRONE1', DRONE1), ('SP_DRONE2', DRONE2),
    ('SP_DART', 'even', DART), ('SP_POD1', 'even', POD1), ('SP_POD2', 'even', POD2),
    ('SP_EXPL1', 'even', EXPL1), ('SP_EXPL2', 'even', EXPL2), ('SP_EXPL3', 'even', EXPL3),
    ('SP_SWEEP1', 'even', SWEEP1), ('SP_SWEEP2', 'even', SWEEP2), ('SP_SPIT', 'even', SPIT),
]
BOSSES = [QUEEN, ROCKMITE, WARDEN, HULK, HIVEMIND]


def level_lib(n, base=0x1600, limit=0x6000):
    """the sprite library of level n (0-4): common sprites, then its boss"""
    data = bytearray()
    labels = {}
    for item in COMMON + [('SP_BOSS', 'even', BOSSES[n])]:
        name, a = item[0], item[-1]
        labels[name] = base + len(data)
        data += gfx.sprite_frame(a, even=len(item) == 3)
    assert base + len(data) <= limit, 'level %d sprites: %d bytes' % (n + 1, len(data))
    return bytes(data), labels


SPRITES = [
    ('SP_HORNET1', HORNET1),
    ('SP_HORNET2', HORNET2),
    ('SP_DRONE1', DRONE1),
    ('SP_DRONE2', DRONE2),
    ('SP_DART', 'even', DART),
    ('SP_POD1', 'even', POD1),
    ('SP_POD2', 'even', POD2),
    ('SP_EXPL1', 'even', EXPL1),
    ('SP_EXPL2', 'even', EXPL2),
    ('SP_EXPL3', 'even', EXPL3),
    ('SP_QUEEN', 'even', QUEEN),
]


def sprite_lib(base=0x2800, limit=0x5800):
    """frames 'even' are pre-shifted to even pixels only (4 copies)"""
    data = bytearray()
    labels = {}
    for item in SPRITES:
        name, art = item[0], item[-1]
        labels[name] = base + len(data)
        data += gfx.sprite_frame(art, even=len(item) == 3)
    assert base + len(data) <= limit, 'sprite library full: %d' % len(data)
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
