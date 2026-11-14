"""The crypts of CRYPTFALL (VIBED BY BPM 2026).

Forty crypts in eight wings of the castle.  Each wing brings in one idea
gently, the crypts after it play with that idea, and the later wings bring
the earlier ideas back and combine them.  Every wing has a jewel storm (a
bonus crypt: failing it costs no life) and a crypt painted as a picture,
best seen whole on the pause map.

Written out to caves/*.txt by tools/tune.py, which plays each one in the
model to set its quota and clock.
"""
from paint import Cave, DIRT, SOFT


# ---------------------------------------------------------------- helpers
def ground(c, bands='.,', x0=1, y0=1, x1=None, y1=None, hollows=0.0, gems=0.05, stones=0.06, wobble=2):
    c.strata(bands, x0, y0, x1, y1, on=DIRT, wobble=wobble)
    if hollows:
        c.cavern(x0, y0, x1 or c.w - 2, y1 or c.h - 2, p=hollows)
    c.scatter('o', stones, x0, y0, x1, y1, on=DIRT)
    c.scatter('*', gems, x0, y0, x1, y1, on=DIRT)


def headstone(c, x, y, kind):
    """standing on row y (its foot)"""
    if kind == 0:
        c.rows(x - 1, y - 2, ['~H~', 'HHH', '~H~'])
    elif kind == 1:
        c.rows(x, y - 1, ['N', 'N'])
    else:
        c.rows(x - 1, y - 1, ['NNN', 'NNN'])


def coffin(c, x, y, l=6, inside='*', wall='N', open_end=1):
    c.fill(x, y, x + l - 1, y + 2, wall)
    c.fill(x + 1, y + 1, x + l - 2, y + 1, inside)
    c.put(x if open_end < 0 else x + l - 1, y + 1, '.')


def storm_cell(c, x0, y0, x1, y1, table):
    """a cloud of things hanging in the air"""
    c.mix(x0, y0, x1, y1, table)


def pins(c, x0, y0, x1, y1, dx=4, dy=3, ch='V'):
    """staggered round pegs, for things to tumble through"""
    j = 0
    for y in range(y0, y1 + 1, dy):
        off = (dx // 2) * (j & 1)
        for x in range(x0 + off, x1 + 1, dx):
            c.put(x, y, ch)
        j += 1


def vault(c, x0, y0, x1, y1, wall='B', inside='*'):
    c.fill(x0, y0, x1, y1, wall)
    c.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, inside)


def treasure(c, n=2, kinds='$h+', **kw):
    for ch in kinds[:n]:
        c.scatter(ch, 1, **kw)


# ============================================================ I THE GRAVEYARD
def graveyard_gate():
    c = Cave('THE GRAVEYARD GATE', 48, 24, 'DIG DOWN AMONG THE GRAVES FOR GEMS',
             theme='dirt2=BROWN block2=GREY block3=WHITE', frac=0.65)
    ground(c, '..,,', y0=5, hollows=0.30, gems=0.06, stones=0.05)
    c.fill(1, 1, 46, 3, ' ')
    c.hl(1, 46, 4, '.')
    for i, x in enumerate(range(6, 44, 5)):
        headstone(c, x, 3, i % 3)
    for i, x in enumerate((8, 24, 36)):
        coffin(c, x, 9 + 4 * i, 6, '*', 'N', 1 if i != 1 else -1)
    c.scatter('$', 1, 30, 18, 46, 22)
    c.start(2, 3)
    c.gate(47, 21)
    return c


def rolling_stones():
    c = Cave('ROLLING STONES', 52, 26, 'STONES ROLL OFF ROUND THINGS. STAND BACK',
             theme='wall2=GREY dirt1=BROWN dirt2=BROWN', frac=0.7)
    ground(c, '.,', hollows=0.32, gems=0.06, stones=0.05)
    # ridges of cobbles with stones heaped on them: dig beside one and the heap spills
    for k, (x, y) in enumerate(((8, 8), (22, 6), (36, 9), (14, 18), (30, 19), (44, 17))):
        for i in range(-3, 4):
            c.put(x + i, y + abs(i), 'V')
        c.fill(x - 2, y - 2, x + 2, y - 1, ' ')
        c.rows(x - 1, y - 2, ['ooo', '~o~'])
        c.rows(x - 2, y - 1, ['o~~~o'])
        c.put(x, y + 1, '*')
        c.put(x - 1, y + 2, '*')
        c.put(x + 1, y + 2, '*')
    c.scatter('h', 1)
    c.start(2, 2)
    c.gate(50, 25)
    return c


def sands_of_time():
    """the hourglass: a jewel storm"""
    W, H = 33, 32
    c = Cave('SANDS OF TIME', W, H, 'A STORM OF JEWELS. CATCH ALL YOU CAN!', fill=' ',
             theme='block3=BROWN wall1=YELLOW dirt1=BROWN', frac=0.6, bonus=1, time=150)
    cx = W // 2
    c.fill(1, 1, W - 2, 2, 'H')                  # the wooden top and foot
    c.fill(1, H - 3, W - 2, H - 2, 'H')
    top, neck, bot = 3, 15, H - 4
    for y in range(top, bot + 1):
        d = abs(y - neck)
        hw = max(1, int(d * 13 / 12) + 1) if y != neck else 1
        hw = min(hw, 14)
        for x in range(1, W - 1):
            if abs(x - cx) > hw:
                c.put(x, y, '.')
            elif abs(x - cx) == hw:
                c.put(x, y, 'W')
            else:
                c.put(x, y, '*' if y < neck else ' ')
    c.put(cx, neck, ' ')
    c.put(cx, neck - 1, '*')
    # jewels of three kinds in the sand, and the odd hourglass charm
    for x, y in c.cells(1, top, W - 2, neck - 1, on='*'):
        r = c.r.random()
        if r < 0.08:
            c.put(x, y, 'r')
        elif r < 0.11:
            c.put(x, y, 'e')
    # the way in: an alcove in the foot of the glass, out of the stream
    c.fill(1, bot - 2, 3, bot, '.')
    for y in range(bot - 6, bot + 1):
        for x in range(1, W - 1):
            if c.get(x, y) == 'W' and x < cx and y >= bot - 1:
                c.put(x, y, '.')
    c.put(cx - 13, bot, '.')
    c.start(2, bot - 1, clear=0)
    c.hl(2, 6, bot, '.')
    c.gate(W - 1, bot)
    c.fill(W - 6, bot - 1, W - 2, bot, '.')
    c.vl(W - 2, 3, bot, '.')
    c.put(W - 3, 5, 'h')
    return c


def grinning_skull():
    """a picture: a great skull in the earth, eyes of rubies"""
    W, H = 60, 30
    c = Cave('THE GRINNING SKULL', W, H, 'SEE ME WHOLE ON THE PAUSE MAP',
             theme='dirt3=WHITE dirt1=BROWN dirt2=BROWN block1=GREY slab=WHITE', frac=0.7)
    ground(c, '.,', hollows=0.2, gems=0.03, stones=0.05)
    cx, cy = 30, 12
    c.ellipse(cx, cy, 15, 9.5, ':')                       # the dome
    c.fill(cx - 8, cy + 6, cx + 8, cy + 12, ':')           # the jaw
    c.ellipse(cx, cy, 15, 9.5, 'N', ring=True)
    for ex in (cx - 6, cx + 6):                            # eyes full of rubies
        c.ellipse(ex, cy + 1, 3.5, 2.6, 'N')
        c.ellipse(ex, cy + 1, 2.5, 1.7, 'r')
    c.rows(cx - 1, cy + 5, ['~*~', '***'])                 # the nose
    for i, x in enumerate(range(cx - 7, cx + 8)):          # teeth
        c.put(x, cy + 9, 'q' if i % 2 == 0 else ' ')
        c.put(x, cy + 10, '*' if i % 2 == 0 else ':')
    c.vl(cx - 9, cy + 6, cy + 12, 'N')
    c.vl(cx + 9, cy + 6, cy + 12, 'N')
    c.hl(cx - 9, cx + 9, cy + 12, 'N')
    c.put(cx, cy + 12, '.')
    for ex in (cx - 6, cx + 6):                            # a way into each eye
        c.put(ex, cy - 2, ':')
        c.put(ex, cy - 1, ':')
    c.scatter('o', 0.06, cx - 12, cy - 8, cx + 12, cy - 3, on=':')
    c.put(cx, cy - 6, 'C')
    c.start(2, 2)
    c.gate(W - 1, H - 3)
    return c


def crypt_stairs():
    W, H = 56, 30
    c = Cave('THE CRYPT STAIRS', W, H, 'A JEWEL UNDER EACH STEP. MIND THE STONES',
             theme='block1=GREY dirt2=BROWN', frac=0.7)
    ground(c, '.,', hollows=0.15, gems=0.03, stones=0.04)
    x, y = 3, 4
    while x < W - 8 and y < H - 4:
        c.hl(x, x + 5, y, 'B')
        c.fill(x + 1, y - 2, x + 4, y - 1, ' ')
        c.put(x + 2, y - 2, 'o')
        c.put(x + 3, y - 1, '.')
        c.put(x + 2, y - 1, '.')
        c.rows(x + 1, y + 1, ['*r*'])
        x += 5
        y += 2
    c.scatter('v', 1, 30, 1, 54, 10)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


# ============================================================ II THE BELFRY
def belfry():
    W, H = 44, 30
    c = Cave('THE BELFRY', W, H, 'DROP A STONE ON A BAT. SEE WHAT FALLS',
             theme='wall1=BROWN wall3=GREY dirt1=BROWN', frac=0.6)
    ground(c, '.,', gems=0.03, stones=0.03)
    # the tower: walls up the middle, an open bell chamber with bats
    c.fill(14, 3, 29, 26, 'W')
    c.fill(15, 4, 28, 12, ' ')
    c.ellipse(21.5, 8, 4, 3, 'H')                          # the bell
    c.ellipse(21.5, 9, 3, 2, ' ')
    c.put(21, 12, 'b')
    c.put(23, 12, 'b')
    for x in (15, 28):
        c.vl(x, 4, 12, 'A')
    c.hl(15, 28, 13, '.')
    c.fill(16, 14, 27, 25, '.')
    c.scatter('*', 0.12, 16, 14, 27, 25)
    # cages left and right of the tower, each with a stone over it
    for i, (x, y) in enumerate(((5, 6), (9, 14), (5, 21), (36, 5), (39, 13), (35, 20))):
        c.bat_cage(x, y, 'W', -1 if i < 3 else 1)
    c.put(21, 2, '.')
    c.start(2, 2)
    c.gate(W - 1, H - 3)
    return c


def bat_caves():
    W, H = 60, 26
    c = Cave('THE BAT CAVES', W, H, 'BATS LOOSE IN THE CAVES. STONES ABOVE',
             theme='dirt1=DGREY dirt2=BROWN wall2=GREY', frac=0.6)
    ground(c, ',.', hollows=0.47, gems=0.04, stones=0.05)
    for x, y in c.scatter('b', 7, 6, 4, 56, 22, on=' '):
        pass
    for i, (x, y) in enumerate(((10, 3), (24, 4), (40, 3), (52, 6))):
        c.bat_cage(x, y, 'V', -1)
    c.start(2, 2)
    c.gate(W - 1, 13)
    return c


def jewel_rain():
    """a jewel storm through pegs"""
    W, H = 64, 24
    c = Cave('JEWEL RAIN', W, H, 'JEWELS TUMBLE THROUGH THE PEGS. GATHER!', fill=' ',
             theme='wall2=CYAN block3=BROWN dirt1=BROWN', frac=0.6, bonus=1, time=150)
    storm_cell(c, 4, 1, W - 5, 3, {'*': 70, 'r': 10, 'e': 5, ' ': 15})
    pins(c, 5, 6, W - 6, 15, 4, 3, 'V')
    c.hl(1, W - 2, 19, '.')
    for x in range(4, W - 4, 6):                           # bins
        c.vl(x, 17, 18, 'H')
    c.fill(1, 20, W - 2, H - 2, '.')
    c.fill(1, 1, 3, 18, '.')
    c.fill(W - 4, 1, W - 2, 18, '.')
    c.vl(3, 1, 18, 'H')
    c.vl(W - 4, 1, 18, 'H')
    for y in (8, 14):
        c.put(3, y, '.')
        c.put(W - 4, y, '.')
    c.start(2, 9, clear=0)
    c.gate(W - 1, 21)
    c.scatter('h', 1, 2, 20, W - 3, H - 2)
    return c


def ghost_walk():
    W, H = 50, 28
    c = Cave('THE GHOST WALK', W, H, 'GHOSTS KEEP TO THE WALLS. TIME YOUR DIGS',
             theme='wall1=BLUE dirt1=BROWN dirt3=GREY', frac=0.7)
    c.fill(1, 1, W - 2, H - 2, ' ')
    # a grid of earth blocks, each with a heart of jewels, walked round by ghosts
    for j, y in enumerate(range(3, H - 4, 6)):
        for i, x in enumerate(range(4, W - 6, 7)):
            c.fill(x, y, x + 4, y + 3, ':')
            c.fill(x + 1, y + 1, x + 3, y + 2, '*')
            if (i + j) % 3 == 0:
                c.put(x + 2, y + 1, 'r')
    c.box(1, 1, W - 2, H - 2, 'W')
    c.fill(2, 2, 3, 3, '.')
    for k, (x, y) in enumerate(c.r.sample([(x, y) for x, y in c.cells(2, 2, W - 3, H - 3, on=' ')
                                            if (x - 2) ** 2 + (y - 2) ** 2 > 120], 6)):
        c.put(x, y, 'g')
    c.start(2, 2, clear=0)
    c.put(W - 3, H - 3, '.')
    c.put(W - 2, H - 3, '.')
    c.gate(W - 1, H - 3)
    c.scatter('o', 4, 4, 2, W - 5, 2, on=' ')
    return c


def knights_hall():
    W, H = 58, 28
    c = Cave("THE KNIGHTS' HALL", W, H, 'KNIGHTS MARCH TO AND FRO. DROP STONES',
             theme='block1=GREY wall3=WHITE dirt1=BROWN dirt2=BROWN', frac=0.65)
    ground(c, '.,', gems=0.02, stones=0.02)
    for k, y in enumerate((6, 13, 20)):
        c.hl(2, W - 3, y - 2, 'B')
        c.fill(2, y - 1, W - 3, y, ' ')
        c.hl(2, W - 3, y + 1, 'B')
        for x in range(4, W - 4, 3):
            c.put(x, y, '*')
        c.put(10 + k * 9, y - 1, 'k')
        c.put(40 - k * 7, y - 1, 'k')
        for x in range(6 + k * 3, W - 6, 12):                  # stones held over the hall
            c.put(x, y - 2, '.')
            c.put(x, y - 3, 'o')
        for x in (3, W - 4):
            c.put(x, y - 2, '.')
            c.put(x, y + 1, '.')
    for x in range(8, W - 6, 10):
        c.vl(x, 22, H - 3, 'A')
    c.scatter('+', 1, 2, 22, W - 3, H - 2)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


# ============================================================ III THE POWDER STORE
def powder_store():
    W, H = 52, 28
    c = Cave('THE POWDER STORE', W, H, 'A FALLING KEG BLASTS WALLS AWAY',
             theme='block2=BROWN block1=GREY dirt1=BROWN dirt2=BROWN', frac=0.65)
    ground(c, '.,', hollows=0.2, gems=0.03, stones=0.04)
    for i, (x, y) in enumerate(((8, 6), (24, 5), (40, 7), (12, 17), (30, 18), (44, 19))):
        vault(c, x - 3, y + 2, x + 3, y + 6, 'N', '*')
        c.put(x, y + 4, 'r' if i % 2 else 'e')
        c.drop(x, y, 'T', -1 if i % 2 == 0 else 1, 10)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def cracked_foundations():
    W, H = 54, 28
    c = Cave('CRACKED FOUNDATIONS', W, H, 'A FALLING STONE BREAKS A CRACKED WALL',
             theme='cracked=GREY dirt1=BROWN dirt2=BROWN wall1=RED', frac=0.65)
    ground(c, '.,', hollows=0.15, gems=0.03, stones=0.03)
    for i, x in enumerate(range(5, W - 6, 8)):
        y = 6 + (i % 3) * 6
        c.fill(x - 2, y, x + 2, y + 5, 'W')
        c.fill(x - 1, y + 1, x + 1, y + 4, '*')
        c.vl(x, y + 1, y + 4, ' ')
        c.put(x, y, 'c')
        c.put(x, y - 1, ' ')
        c.drop(x, y - 3, 'o', -1, 12)
    c.scatter('v', 1)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def chain_reaction():
    W, H = 60, 26
    c = Cave('CHAIN REACTION', W, H, 'ONE KEG SETS OFF THE NEXT...',
             theme='block1=GREY block2=BLUE dirt1=BROWN dirt3=DGREY', frac=0.65)
    ground(c, '.:', gems=0.03, stones=0.03)
    y = 12
    c.fill(4, y - 2, W - 5, y + 3, 'B')
    c.fill(5, y + 1, W - 6, y + 2, '*')
    c.hl(7, W - 7, y - 1, 'T')                         # a fuse of kegs in the roof
    c.put(7, y - 2, ' ')
    c.drop(7, y - 4, 'o', -1, 24)
    for x, y2 in ((14, 21), (34, 21), (48, 6)):
        vault(c, x - 2, y2 - 2, x + 2, y2 + 1, 'N', 'r')
        c.put(x, y2 - 3, ' ')
        c.drop(x, y2 - 5, 'T', -1, 10)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def treasure_chest():
    """a picture: a great chest of jewels, locked"""
    W, H = 56, 30
    c = Cave('THE TREASURE CHEST', W, H, 'A KEY OR A KEG WILL OPEN THE CHEST',
             theme='block2=BROWN block3=YELLOW dirt1=BROWN dirt2=BROWN door=YELLOW', frac=0.7)
    ground(c, '.,', hollows=0.25, gems=0.02, stones=0.05)
    x0, y0, x1, y1 = 14, 8, 41, 22
    c.ellipse(27.5, y0 + 1, 13.5, 3, 'N')                 # the lid
    c.fill(x0, y0 + 1, x1, y1, 'N')
    c.fill(x0 + 1, y0 + 3, x1 - 1, y1 - 1, '*')
    for x in (x0 + 4, x1 - 4):                              # iron bands
        c.vl(x, y0 - 2, y1, 'H')
    c.hl(x0, x1, y0 + 2, 'H')
    for x, y in c.cells(x0 + 1, y0 + 3, x1 - 1, y1 - 1, on='*'):
        r = c.r.random()
        c.put(x, y, 'r' if r < 0.12 else 'e' if r < 0.18 else 'o' if r < 0.24 else '*')
    c.put(27, y0 + 5, 'D')                                 # the lock
    c.put(27, y0 + 4, '.')
    c.rows(26, y0 + 4, ['H.H'])
    c.put(27, y0 + 3, '.')
    c.put(27, y0 + 2, '.')
    c.vl(27, y0 - 3, y0 + 1, '.')
    c.put(27, y0 + 6, 'C')
    c.put(50, 26, 'y')
    c.vl(17, y0 - 2, y0 + 1, ' ')
    c.drop(17, y0 - 4, 'T', -1, 12)
    c.start(2, 2)
    c.gate(W - 1, 3)
    return c


def moonlit_storm():
    """a jewel storm with stones in it"""
    W, H = 50, 30
    c = Cave('MOONLIT STORM', W, H, 'JEWELS AND STONES FALL TOGETHER!', fill=' ',
             theme='wall2=GREY dirt1=BROWN block3=YELLOW', frac=0.55, bonus=1, time=160)
    storm_cell(c, 3, 1, W - 4, 7, {'*': 64, 'r': 8, 'e': 4, 'o': 9, ' ': 15})
    c.ellipse(W // 2, 4, 4, 2.5, 'H')                      # the moon among them
    pins(c, 4, 11, W - 5, 20, 5, 3, 'V')
    c.fill(1, 23, W - 2, H - 2, '.')
    c.fill(1, 1, 2, 22, '.')
    c.fill(W - 3, 1, W - 2, 22, '.')
    c.start(1, 12, clear=0)
    c.put(2, 12, '.')
    c.gate(W - 1, H - 3)
    return c


# ============================================================ IV THE URN GALLERY
def urn_gallery():
    W, H = 56, 26
    c = Cave('THE URN GALLERY', W, H, 'URNS BREAK OPEN WHEN THEY FALL',
             theme='urn=YELLOW block1=GREY dirt1=BROWN dirt2=BROWN', frac=0.6)
    ground(c, '.,', gems=0.02, stones=0.03)
    for k, y in enumerate((6, 13, 20)):
        c.hl(2, W - 3, y + 3, 'B')
        c.fill(2, y + 1, W - 3, y + 2, ' ')
        for i, x in enumerate(range(5 + k * 2, W - 5, 6)):
            c.drop(x, y - 1, 'u', -1, 8)
            c.put(x, y + 1, ' ')
        c.put(3, y + 3, '.')
        c.put(W - 4, y + 3, '.')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def slab_stairs():
    W, H = 52, 28
    c = Cave('THE SLAB STAIRS', W, H, 'SLABS NEVER ROLL. THEY CRACK WALLS',
             theme='slab=GREY cracked=BROWN dirt1=BROWN dirt3=DGREY', frac=0.65)
    ground(c, '.:', hollows=0.2, gems=0.03, stones=0.02)
    # towers of slabs stand on round walls without falling off
    for x in range(6, W - 6, 7):
        top = 3 + c.r.randrange(6)
        c.vl(x, top, top + 6, 'q')
        c.put(x, top + 7, 'V')
        c.put(x - 1, top + 7, ' ')
        c.put(x + 1, top + 7, ' ')
    for i, x in enumerate(range(9, W - 6, 10)):
        y = 17 + (i % 2) * 3
        c.fill(x - 2, y, x + 2, y + 4, 'W')
        c.fill(x - 1, y + 1, x + 1, y + 3, '*')
        c.vl(x, y + 1, y + 3, ' ')
        c.put(x - 1, y + 3, 'r')
        c.put(x, y, 'c')
        c.put(x, y - 1, ' ')
        c.drop(x, y - 3, 'q', 1, 12)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def catacombs():
    W, H = 63, 31
    c = Cave('THE CATACOMBS', W, H, 'URNS IN THE NICHES. JEWELS IN THE DARK',
             theme='wall2=GREY dirt1=BROWN urn=YELLOW', frac=0.6, fill=' ')
    ends = c.maze(1, 1, 15, 7, 3, 3, 'V', '.', 0.12)
    c.scatter('*', 0.1, on='.')
    for x, y in ends:                                       # an urn in every niche
        c.fill(x, y, x + 2, y + 2, '.')
        c.put(x + 1, y, 'u')
        c.put(x + 1, y + 2, ' ')
        c.do('~%d,%d r w8' % (x, y + 1))
    c.scatter(' ', 0.15, 1, 1, W - 2, H - 2, on='.')
    c.scatter('g', 4, 10, 10, W - 3, H - 3, on=' ')
    c.scatter('$', 1, 30, 1, W - 2, H - 2, on='.')
    c.start(2, 2, clear=0)
    c.gate(W - 1, H - 3)
    c.put(W - 2, H - 3, '.')
    return c


def pipe_organ():
    """a picture: the castle organ"""
    W, H = 60, 30
    c = Cave('THE PIPE ORGAN', W, H, 'URNS ON THE PIPES. EMERALDS BELOW',
             theme='slab=YELLOW block3=BROWN dirt1=BROWN dirt3=DGREY urn=WHITE', frac=0.6)
    ground(c, '.:', gems=0.02, stones=0.03)
    base = 22
    c.fill(6, base, 53, base + 5, 'H')                      # the console
    c.fill(8, base + 1, 51, base + 2, ' ')
    for x in range(9, 51, 3):
        c.put(x, base + 1, '*')
    c.hl(8, 51, base + 3, 'N')
    for i, x in enumerate(range(8, 52, 3)):
        hgt = 6 + int(9 * (1 - abs(i - 7) / 8.0))
        c.vl(x, base - hgt, base - 1, 'q')
        c.put(x, base - hgt - 1, '.')
        c.put(x + 1, base - hgt + 1, 'e' if i % 3 == 0 else '*')
    for x in (12, 30, 47):
        c.drop(x, 3, 'u', -1, 8)
    c.put(7, base, '.')
    c.put(52, base, '.')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def falling_urns():
    """a storm of urns, every one a jewel when it lands"""
    W, H = 56, 28
    c = Cave('A RAIN OF URNS', W, H, 'EVERY URN THAT FALLS BECOMES A JEWEL', fill=' ',
             theme='urn=YELLOW wall3=GREY dirt1=BROWN', frac=0.55, bonus=1, time=160)
    storm_cell(c, 4, 1, W - 5, 6, {'u': 45, '*': 30, 'r': 6, ' ': 19})
    pins(c, 5, 10, W - 6, 18, 6, 4, 'A')
    c.fill(1, 22, W - 2, H - 2, '.')
    c.fill(1, 1, 2, 21, '.')
    c.fill(W - 3, 1, W - 2, 21, '.')
    c.start(1, 14, clear=0)
    c.put(2, 14, '.')
    c.gate(W - 1, H - 3)
    return c


# ============================================================ V THE ALCHEMIST
def alchemist():
    W, H = 52, 28
    c = Cave("THE ALCHEMIST'S GRATE", W, H, 'STONES THROUGH THE GRATE TURN TO GEMS',
             theme='grate=CYAN wall1=MAGENTA dirt1=BROWN dirt2=BROWN', frac=0.6, magic=30)
    ground(c, '.,', gems=0.02, stones=0.03)
    y = 14
    c.hl(4, W - 5, y, 'W')
    c.fill(4, y + 1, W - 5, y + 6, ' ')
    c.hl(4, W - 5, y + 7, 'W')
    c.vl(4, y, y + 7, 'W')
    c.vl(W - 5, y, y + 7, 'W')
    for i, x in enumerate(range(9, W - 8, 8)):
        c.put(x, y, 'm')
        c.shaft(x, y - 1, 'oooo')
    c.put(5, y + 7, '.')
    c.put(5, y + 8, '.')
    c.put(W - 6, y, '.')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def lead_into_gold():
    W, H = 56, 28
    c = Cave('LEAD INTO GOLD', W, H, 'SLABS MAKE RUBIES. URNS MAKE EMERALDS',
             theme='grate=CYAN slab=GREY urn=YELLOW wall3=MAGENTA dirt1=BROWN dirt3=DGREY', frac=0.6, magic=40)
    ground(c, '.:', gems=0.02, stones=0.02)
    y = 13
    c.hl(3, W - 4, y, 'A')
    c.fill(3, y + 1, W - 4, y + 5, ' ')
    c.hl(3, W - 4, y + 6, 'A')
    things = 'qouqouq'
    for i, x in enumerate(range(7, W - 6, 7)):
        c.put(x, y, 'm')
        c.shaft(x, y - 1, things[i % len(things)] * 3, 'A')
    c.vl(3, y, y + 6, 'A')
    c.vl(W - 4, y, y + 6, 'A')
    c.put(4, y + 6, '.')
    c.put(4, y + 7, '.')
    c.scatter('h', 1)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def cauldron():
    """a picture: the witch's cauldron"""
    W, H = 54, 30
    c = Cave('THE CAULDRON', W, H, 'STIR THE POT: STONES IN, JEWELS OUT',
             theme='block1=DGREY grate=GREEN dirt1=BROWN dirt2=BROWN dirt4=GREEN', frac=0.6, magic=40)
    ground(c, '.,', gems=0.02, stones=0.03)
    cx, cy = 27, 18
    c.ellipse(cx, cy, 14, 8, 'B')
    c.ellipse(cx, cy, 12.5, 6.5, ' ')
    c.fill(cx - 15, cy - 8, cx + 15, cy - 4, '.')
    c.hl(cx - 15, cx + 15, cy - 4, 'B')
    for x in range(cx - 12, cx + 13):
        c.put(x, cy - 4, 'm' if (x - cx) % 3 == 0 else 'B')
    c.fill(cx - 13, cy - 9, cx + 13, cy - 5, ';')          # the brew, green and bubbling with stones
    c.scatter('o', 0.3, cx - 13, cy - 9, cx + 13, cy - 5, on=';')
    c.scatter('*', 0.15, cx - 13, cy - 9, cx + 13, cy - 5, on=';')
    for x in (cx - 10, cx + 10):
        c.rows(x - 1, cy + 7, ['BBB', 'B~B'])
    c.put(cx - 13, cy - 1, '.')
    c.put(cx - 14, cy - 1, '.')
    c.vl(cx, cy - 12, cy - 10, '.')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def transmutation():
    W, H = 60, 30
    c = Cave('TRANSMUTATION', W, H, 'BLAST THE STORE OPEN OVER THE GRATE',
             theme='grate=CYAN block1=GREY block2=BROWN wall1=MAGENTA dirt1=BROWN', frac=0.6, magic=40)
    ground(c, '.,', hollows=0.15, gems=0.03, stones=0.03)
    # a store of stones whose floor is a fuse of powder kegs, over a row of
    # grates: light the fuse and the whole store comes down as jewels
    c.box(18, 4, 42, 12, 'N')
    c.fill(19, 5, 41, 11, 'o')
    c.hl(16, 41, 12, 'T')
    c.hl(15, 45, 13, '.')
    c.hl(16, 44, 14, 'm')
    c.fill(16, 15, 44, 21, ' ')
    c.box(15, 14, 45, 22, 'W')
    c.hl(16, 44, 14, 'm')
    c.put(16, 22, '.')
    c.put(16, 23, '.')
    c.hl(14, 15, 13, 'W')
    c.hl(43, 46, 13, 'W')
    c.put(16, 11, ' ')
    c.drop(16, 9, 'o', -1, 40)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def glittering_abyss():
    W, H = 46, 32
    c = Cave('THE GLITTERING ABYSS', W, H, 'ALL THREE JEWELS FALL. AND A BAT...', fill=' ',
             theme='wall2=BLUE dirt1=BROWN block3=MAGENTA', frac=0.55, bonus=1, time=170)
    storm_cell(c, 3, 1, W - 4, 9, {'*': 50, 'r': 14, 'e': 10, 'o': 6, ' ': 20})
    pins(c, 4, 13, W - 5, 24, 4, 3, 'V')
    c.fill(1, 27, W - 2, H - 2, '.')
    c.fill(1, 1, 2, 26, '.')
    c.fill(W - 3, 1, W - 2, 26, '.')
    c.put(W // 2, 26, 'b')
    c.put(W // 2 - 1, 26, ' ')
    c.start(1, 16, clear=0)
    c.put(2, 16, '.')
    c.gate(W - 1, H - 3)
    return c


# ============================================================ VI THE LOCKED WING
def locked_wing():
    W, H = 58, 28
    c = Cave('THE LOCKED WING', W, H, 'EACH KEY OPENS ONE DOOR. SEEK THEM OUT',
             theme='block1=GREY door=YELLOW dirt1=BROWN dirt2=BROWN', frac=0.7)
    ground(c, '.,', hollows=0.2, gems=0.04, stones=0.04)
    rooms = ((6, 5, 16, 11), (24, 4, 34, 10), (42, 6, 53, 12), (10, 17, 20, 24), (30, 16, 40, 23), (45, 18, 54, 24))
    for i, (x0, y0, x1, y1) in enumerate(rooms):
        c.box(x0, y0, x1, y1, 'B')
        c.fill(x0 + 1, y0 + 1, x1 - 1, y1 - 1, '.')
        c.scatter('*', 0.35, x0 + 1, y0 + 1, x1 - 1, y1 - 1)
        c.scatter('o', 0.08, x0 + 1, y0 + 1, x1 - 1, y1 - 2)
        c.put((x0 + x1) // 2, y1, 'D')
        c.put((x0 + x1) // 2, y1 + 1, '.')
    for x, y in c.scatter('y', 6, on=DIRT):
        pass
    c.put(29, 7, 'C')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def labyrinth():
    W, H = 64, 32
    c = Cave('THE LABYRINTH', W, H, 'JEWELS WAIT IN THE DEAD ENDS',
             theme='wall1=GREEN dirt1=BROWN dirt4=GREEN', frac=0.7, fill=' ')
    ends = c.maze(1, 1, 31, 15, 1, 1, 'W', ' ', 0.08)
    for x, y in ends:
        c.put(x, y, c.r.choice('**re'))
    c.scatter('.', 0.25, on=' ')
    c.scatter(';', 0.05, on=' ')
    c.fill(26, 12, 37, 19, 'W')                            # the heart of the maze
    c.fill(27, 13, 36, 18, '*')
    c.fill(29, 15, 34, 16, 'e')
    c.put(31, 14, 'C')
    c.put(31, 12, 'D')
    c.put(31, 11, ' ')
    c.put(31, 10, ' ')
    for k, (x, y) in enumerate(c.r.sample([e for e in ends if abs(e[0] - 31) > 10], 2)):
        c.put(x, y, 'y')
    c.scatter('h', 1, on=' ')
    c.start(2, 2, clear=0)
    c.put(W - 2, H - 2, '.')
    c.gate(W - 1, H - 2)
    return c


def library():
    """a picture: bookshelves, three storeys high"""
    W, H = 58, 30
    c = Cave('THE LIBRARY', W, H, 'THE KEY IS ON A HIGH SHELF',
             theme='block1=RED block2=BLUE block3=GREEN wall3=BROWN dirt1=BROWN door=YELLOW', frac=0.65)
    ground(c, '.,', gems=0.02, stones=0.02)
    for k, y in enumerate((4, 12, 20)):
        c.hl(3, W - 4, y + 6, 'A')
        for x in range(3, W - 3):
            if c.get(x, y + 6) != 'A':
                continue
            if (x - 3) % 9 == 8:
                c.vl(x, y, y + 5, 'A')
                continue
            hgt = 3 + c.r.randrange(4)
            book = c.r.choice('BNH')
            c.vl(x, y + 6 - hgt, y + 5, book)
        c.scatter('*', 0.25, 3, y, W - 4, y + 5, on='.')
    c.box(24, 21, 33, 25, 'A')
    c.fill(25, 22, 32, 24, '*')
    c.put(28, 24, 'C')
    c.put(28, 25, 'D')
    c.put(28, 26, '.')
    c.put(W - 6, 5, 'y')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def chapel():
    """a picture: a rose window of jewels"""
    W, H = 56, 32
    c = Cave('THE CHAPEL WINDOW', W, H, 'A WINDOW OF JEWELS. SEE IT ON THE MAP',
             theme='wall3=GREY block1=BLUE block2=MAGENTA dirt1=BROWN dirt3=DGREY', frac=0.65)
    ground(c, '.:', gems=0.01, stones=0.03)
    cx, cy = 28, 14
    c.fill(cx - 13, cy, cx + 13, H - 3, 'A')               # the arch
    c.ellipse(cx, cy, 13, 11, 'A')
    c.fill(cx - 11, cy, cx + 11, H - 4, ':')
    c.ellipse(cx, cy, 11, 9.5, ':')
    c.ellipse(cx, cy, 9, 7.5, 'B', ring=True)
    import math
    for a in range(8):                                     # spokes
        ang = a * math.pi / 4
        for r in range(1, 9):
            c.put(int(round(cx + r * math.cos(ang) * 1.2)), int(round(cy + r * math.sin(ang) * 0.85)), 'N')
    for x, y in c.cells(cx - 10, cy - 8, cx + 10, cy + 8, on=':'):
        d = ((x - cx) / 9.0) ** 2 + ((y - cy) / 7.5) ** 2
        if d < 1:
            c.put(x, y, 'r' if d < 0.15 else 'e' if (x + y) % 2 else '*')
    for a in range(8):                                     # a way into each pane
        ang = (a + 0.5) * math.pi / 4
        for k in range(14, 26):
            t = k / 20.0
            x, y = int(round(cx + t * 9 * math.cos(ang))), int(round(cy + t * 7.5 * math.sin(ang)))
            if c.get(x, y) in 'BN':
                c.put(x, y, ':')
    c.vl(cx, cy + 9, H - 4, 'N')
    c.hl(cx - 3, cx + 3, cy + 12, 'N')
    c.put(cx - 11, H - 4, '.')
    c.put(cx - 12, H - 4, '.')
    c.put(cx - 13, H - 4, '.')
    c.vl(cx, cy - 11, cy - 9, '.')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


# ============================================================ VII THE SLIME PITS
def slime_pits():
    W, H = 54, 28
    c = Cave('THE SLIME PITS', W, H, 'PENNED-IN SLIME HARDENS INTO JEWELS',
             theme='dirt4=GREEN wall1=GREY dirt1=BROWN', frac=0.6, slmax=120, slow=30)
    ground(c, '.,', gems=0.02, stones=0.03)
    pens = ((8, 8), (24, 7), (40, 9), (14, 19), (32, 20), (46, 19))
    for i, (x, y) in enumerate(pens):
        c.fill(x - 3, y - 2, x + 3, y + 2, 'W')
        c.fill(x - 2, y - 1, x + 2, y + 1, ' ')
        c.put(x, y, 's')
        c.vl(x + 4, y - 1, y, ' ')                 # a keg beside each pen...
        c.put(x + 4, y + 1, 'W')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    c.do('S')                                      # ...to blow it open once the slime has set
    for i, (x, y) in enumerate(pens):
        c.drop(x + 4, y - 3, 'T', 1, 12)
    return c


def ooze():
    W, H = 60, 28
    c = Cave('THE OOZE', W, H, 'TOO MUCH OOZE AND IT TURNS TO STONE',
             theme='dirt4=GREEN dirt1=BROWN dirt3=DGREY wall1=GREY', frac=0.55, slmax=70, slow=25)
    ground(c, '.:', hollows=0.3, gems=0.05, stones=0.04)
    # the ooze pen: it may creep into the side pockets and still harden into
    # jewels - but dig into a pocket from outside and it gets loose
    c.fill(22, 9, 38, 19, 'W')
    c.fill(26, 11, 34, 17, ' ')
    c.put(30, 14, 's')
    for (x0, y0, x1, y1, gx, gy) in ((23, 12, 24, 16, 25, 14), (36, 12, 37, 16, 35, 14), (28, 10, 32, 10, 30, 10),
                                     (28, 18, 32, 18, 30, 18)):
        c.fill(x0, y0, x1, y1, ';')
        c.put(gx, gy, ' ')
    c.scatter('*', 0.25, 1, 1, 20, H - 2)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    c.do('S')
    return c


def raven():
    """a picture: the raven on its branch"""
    W, H = 58, 30
    c = Cave('THE RAVEN', W, H, 'NEVERMORE. A JEWEL FOR AN EYE',
             theme='block1=DGREY block3=BROWN dirt1=BLUE dirt2=BLUE dirt3=DGREY', frac=0.65)
    ground(c, '.,', gems=0.04, stones=0.04)
    c.ellipse(28, 15, 11, 6, 'B')                          # body
    c.ellipse(40, 10, 4.5, 3.5, 'B')                       # head
    c.rows(44, 9, ['BBBB', 'BBB', 'B'])                    # beak
    c.put(41, 9, 'e')
    for i in range(10):                                    # tail
        c.fill(14 - i, 16 + i // 2, 18 - i, 17 + i // 2, 'B')
    c.ellipse(24, 13, 7, 3.5, 'N')                         # wing
    c.hl(6, 52, 23, 'H')                                   # the branch
    c.rows(26, 21, ['H~~H', 'H~~H'])
    c.scatter('*', 0.2, 14, 9, 44, 21, on='BN')
    c.scatter('.', 0.05, 14, 9, 44, 21, on='B')
    c.fill(2, 24, W - 3, H - 2, ',')
    c.scatter('*', 0.08, 2, 24, W - 3, H - 2, on=',')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def slime_and_stone():
    W, H = 60, 30
    c = Cave('SLIME AND STONE', W, H, 'SLIME, A GRATE, AND STONES TO FEED IT',
             theme='dirt4=GREEN grate=CYAN wall1=GREY dirt1=BROWN', frac=0.55, slmax=50, magic=30)
    ground(c, '.,', hollows=0.2, gems=0.03, stones=0.04)
    for x, y in ((12, 8), (46, 8)):
        c.fill(x - 3, y - 2, x + 3, y + 2, 'W')
        c.fill(x - 2, y - 1, x + 2, y + 1, ' ')
        c.put(x, y, 's')
    y = 18
    c.hl(18, 42, y, 'W')
    for x in range(20, 41, 5):
        c.put(x, y, 'm')
        c.shaft(x, y - 1, 'ooo', wait=20)
    c.fill(18, y + 1, 42, y + 5, ' ')
    c.box(17, y, 43, y + 6, 'W')
    c.hl(18, 42, y, 'W')
    for x in range(20, 41, 5):
        c.put(x, y, 'm')
    c.put(18, y + 6, '.')
    c.put(18, y + 7, '.')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def coffin_storm():
    """a storm with haunters in it"""
    W, H = 52, 32
    c = Cave('THE COFFIN STORM', W, H, 'JEWELS, STONES - AND THINGS THAT FLY', fill=' ',
             theme='wall3=GREY block2=BROWN dirt1=BROWN', frac=0.5, bonus=1, time=180)
    storm_cell(c, 3, 1, W - 4, 8, {'*': 55, 'r': 10, 'e': 6, 'o': 10, ' ': 19})
    pins(c, 4, 12, W - 5, 21, 6, 3, 'A')
    for x in (12, 26, 40):
        coffin(c, x - 3, 23, 7, '*', 'N', 1)
    c.fill(1, 27, W - 2, H - 2, '.')
    c.fill(1, 1, 2, 26, '.')
    c.fill(W - 3, 1, W - 2, 26, '.')
    for x, y in ((10, 10), (40, 10)):
        c.put(x, y, 'b')
    c.put(26, 22, 'g')
    c.start(1, 16, clear=0)
    c.put(2, 16, '.')
    c.gate(W - 1, H - 3)
    return c


# ============================================================ VIII THE KEEP
def the_hunter():
    W, H = 56, 28
    c = Cave('THE HUNTER', W, H, 'THE SKULL HUNTS YOU. DROP A STONE ON IT',
             theme='dirt1=BROWN dirt3=DGREY wall2=GREY', frac=0.6)
    ground(c, '.:', hollows=0.35, gems=0.05, stones=0.07)
    c.put(40, 18, 'z')
    c.fill(39, 17, 41, 19, ' ')
    c.scatter('+', 1, 2, 2, 10, 10)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def great_hall():
    W, H = 62, 30
    c = Cave('THE GREAT HALL', W, H, 'KNIGHTS, KEGS AND A LOCKED DOOR',
             theme='block1=GREY block2=BROWN door=YELLOW dirt1=BROWN dirt2=BROWN', frac=0.6)
    ground(c, '.,', hollows=0.15, gems=0.03, stones=0.03)
    c.fill(6, 8, W - 7, 20, ' ')
    c.box(5, 7, W - 6, 21, 'B')
    for x in range(10, W - 9, 8):                          # pillars
        c.vl(x, 8, 16, 'A')
    for x in range(8, W - 8, 2):
        c.put(x, 20, '*')
    for x in (14, 30, 46):
        c.put(x, 19, 'k')
    c.put(5, 14, 'D')
    vault(c, 26, 22, 34, 26, 'N', '*')
    c.put(30, 24, 'C')
    for x in (18, 42):
        c.put(x, 6, '.')
        c.drop(x, 3, 'o', -1, 8)
        c.put(x, 7, '.')
    c.scatter('y', 1, 2, 22, 20, H - 2)
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def witching_hour():
    """a picture: the castle clock at midnight"""
    W, H = 56, 32
    c = Cave('THE WITCHING HOUR', W, H, 'THE CLOCK STRIKES TWELVE. HURRY!',
             theme='block3=YELLOW block1=GREY wall3=BROWN dirt1=BROWN dirt3=DGREY', frac=0.6)
    ground(c, '.:', gems=0.02, stones=0.03)
    import math
    cx, cy = 28, 15
    c.ellipse(cx, cy, 13, 11, 'A')
    c.ellipse(cx, cy, 11.5, 9.6, ':')
    for h in range(12):
        a = h * math.pi / 6
        c.put(int(round(cx + 10 * math.sin(a))), int(round(cy - 8.4 * math.cos(a))), 'r' if h == 0 else 'H')
    c.vl(cx, cy - 7, cy, 'N')                              # hands at midnight
    c.vl(cx + 1, cy - 5, cy, 'N')
    c.put(cx, cy + 1, 'e')
    for r in range(3, 9):
        for a in range(0, 360, 30):
            ang = math.radians(a + 15)
            x, y = int(round(cx + r * math.sin(ang) * 1.1)), int(round(cy - r * math.cos(ang) * 0.9))
            if c.get(x, y) == ':' and c.r.random() < 0.5:
                c.put(x, y, '*')
    c.scatter('o', 0.08, cx - 10, cy - 9, cx + 10, cy - 2, on=':')
    c.vl(cx, cy - 13, cy - 9, ':')
    c.hl(cx - 13, cx - 10, cy + 3, ':')
    c.scatter('h', 2)
    c.put(cx - 12, cy + 2, 'z')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def throne_room():
    W, H = 62, 30
    c = Cave('THE THRONE ROOM', W, H, 'GHOSTS, GRATES, KEGS... AND A CROWN',
             theme='block2=MAGENTA block3=YELLOW grate=CYAN wall1=RED dirt1=BROWN', frac=0.55, magic=35)
    ground(c, '.,', hollows=0.2, gems=0.03, stones=0.04)
    # the throne
    c.rows(26, 6, ['NN~~~~~~NN', 'NN~~~~~~NN', 'NNNNNNNNNN', 'NH~~~~~~HN', 'NH~~~~~~HN', 'NNNNNNNNNN'])
    c.fill(28, 6, 33, 7, ' ')
    c.fill(28, 9, 33, 10, '*')
    c.put(30, 9, 'C')
    c.put(31, 5, '.')
    c.drop(31, 2, 'T', 1, 10)
    # grates with stones over them to the left
    y = 21
    c.hl(4, 22, y, 'W')
    for x in range(6, 21, 5):
        c.put(x, y, 'm')
        c.shaft(x, y - 1, 'ooo', wait=20)
    c.fill(4, y + 1, 22, y + 4, ' ')
    c.box(3, y, 23, y + 5, 'W')
    for x in range(6, 21, 5):
        c.put(x, y, 'm')
    c.put(4, y + 5, '.')
    # ghosts round the jewel blocks on the right
    for x in range(38, 56, 6):
        c.fill(x, 14, x + 3, 17, ':')
        c.fill(x + 1, 15, x + 2, 16, 'r')
    c.fill(36, 12, 58, 12, ' ')
    c.fill(36, 19, 58, 19, ' ')
    for x in range(36, 59, 6):
        c.vl(x, 12, 19, ' ')
    c.put(37, 12, 'g')
    c.put(55, 19, 'g')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


def treasure_storm():
    W, H = 60, 32
    c = Cave('THE TREASURE STORM', W, H, 'THE CASTLE GIVES UP ITS JEWELS!', fill=' ',
             theme='wall2=YELLOW block3=BROWN dirt1=BROWN', frac=0.5, bonus=1, time=200)
    storm_cell(c, 3, 1, W - 4, 10, {'*': 50, 'r': 12, 'e': 8, 'o': 8, 'u': 6, ' ': 16})
    pins(c, 4, 14, W - 5, 23, 4, 3, 'V')
    c.fill(1, 27, W - 2, H - 2, '.')
    c.fill(1, 1, 2, 26, '.')
    c.fill(W - 3, 1, W - 2, 26, '.')
    for x in (15, 45):
        c.put(x, 25, 'b')
        c.put(x, 26, ' ')
    c.put(30, 26, 'z')
    c.start(1, 18, clear=0)
    c.put(2, 18, '.')
    c.gate(W - 1, H - 3)
    return c


def crown_of_crypt():
    W, H = 64, 32
    c = Cave('THE CROWN OF THE CRYPT', W, H, 'EVERYTHING YOU HAVE LEARNED. GOOD LUCK',
             theme='block3=YELLOW block1=GREY grate=CYAN door=YELLOW dirt1=BROWN dirt2=BROWN dirt4=GREEN', frac=0.55, magic=35, slmax=40)
    ground(c, '.,', hollows=0.22, gems=0.03, stones=0.05)
    # the crown itself, drawn in gold blocks, with the real crown inside
    c.rows(22, 3, ['H~~~~H~~~~H~~~~H~~~H',
                   'HH~~HHH~~HHH~~HHH~HH',
                   'HHHHHHHHHHHHHHHHHHHH',
                   'Hr*e*r*e*r*e*r*e*r*H',
                   'HHHHHHHHHDHHHHHHHHHH'])
    c.put(31, 6, 'C')
    c.put(31, 8, '.')
    # a bat cage, a keg vault, a grate, a slime pen, a locked door, a hunter
    c.bat_cage(8, 12, 'W', 1)
    vault(c, 46, 14, 52, 18, 'N', '*')
    c.drop(49, 11, 'T', -1, 10)
    y = 25
    c.hl(18, 34, y, 'W')
    for x in (21, 26, 31):
        c.put(x, y, 'm')
        c.shaft(x, y - 1, 'ooo', wait=20)
    c.fill(18, y + 1, 34, y + 4, ' ')
    c.box(17, y, 35, y + 5, 'W')
    for x in (21, 26, 31):
        c.put(x, y, 'm')
    c.put(18, y + 5, '.')
    c.fill(43, 23, 49, 27, 'W')
    c.fill(44, 24, 48, 26, ' ')
    c.put(46, 25, 's')
    c.put(56, 22, 'y')
    c.put(58, 8, 'z')
    c.start(2, 2)
    c.gate(W - 1, H - 2)
    return c


CRYPTS = [
    graveyard_gate, rolling_stones, sands_of_time, grinning_skull, crypt_stairs,
    belfry, bat_caves, jewel_rain, ghost_walk, knights_hall,
    powder_store, cracked_foundations, chain_reaction, treasure_chest, moonlit_storm,
    urn_gallery, slab_stairs, catacombs, pipe_organ, falling_urns,
    alchemist, lead_into_gold, cauldron, transmutation, glittering_abyss,
    locked_wing, labyrinth, library, chapel, coffin_storm,
    slime_pits, ooze, raven, slime_and_stone, the_hunter,
    great_hall, witching_hour, throne_room, treasure_storm, crown_of_crypt,
]


def build_all():
    out = []
    for f in CRYPTS:
        c = f()
        out.append(c)
    return out


if __name__ == '__main__':
    import os, sys
    HERE = os.path.dirname(os.path.abspath(__file__))
    import caves as C
    for c in build_all():
        p = os.path.join(HERE, '..', 'build', 'chk.txt')
        open(p, 'w').write(c.text(1, 200))
        try:
            k = C.check(C.parse(p), p)
            print('%-24s %2dx%2d gems %3d pictures %2d' % (c.name, c.w, c.h, k['gems'], len(k['arts'])))
        except SystemExit as e:
            print(c.name, 'ERROR', e)
