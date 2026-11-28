"""BILBIES! levels - all original designs for 512 x 80 maps (4 screens across,
nearly 2 down) so the bilbies are in the same proportion to the land as in
the classic games of the genre."""
from lvlkit import Level, SOLID, DECOR, OVER, ERASE
import lvlkit
from art import pack
import random as _r

PERRATE = 6
LEVELS = []

def add(l, rating):
    l.rating = rating
    LEVELS.append(l)
    return l

# ---------------------------------------------------------------------------
# scenery helpers (decor never changes the ground the bilbies walk on)
# ---------------------------------------------------------------------------
def gum(l, x, gy, h=26, w=22):
    """a gum tree behind the action: pale trunk, airy crown"""
    l.rect('trunk', x - 2, gy - h, 5, h, DECOR)
    l.ellipse('canopy', x, gy - h, w, 7, DECOR)
    l.ellipse('canopy', x - w // 2, gy - h + 4, w // 2, 4, DECOR)
    return l

def hills(l, xs, base, far=True):
    for i, x in enumerate(xs):
        if far:
            l.ellipse('farhill', x, base, 70 + 13 * (i % 3), 18 + 3 * (i % 2), DECOR)
        else:
            l.ellipse('hill', x, base, 50 + 11 * (i % 3), 12 + 2 * (i % 2), DECOR)
    return l

def clouds(l, xs, y):
    for i, x in enumerate(xs):
        l.ellipse('cloud', x, y + 3 * (i % 2), 18 + 5 * (i % 3), 3, DECOR)
    return l

def drips(l, x0, x1, top, seed=1, t='rock', maxlen=9):
    """stalactites hanging from row `top` (solid)"""
    r = _r.Random(seed)
    x = x0
    while x < x1:
        n = r.randint(3, maxlen)
        w = r.randint(2, 4)
        l.cspans(t, x, top, [max(0, w - i * w // n) for i in range(n)])
        x += r.randint(14, 30)
    return l

def bumps(l, x0, x1, gy, seed=1, t='rock', maxh=5):
    """stalagmites / rocks standing on row gy (solid, low enough to walk over)"""
    r = _r.Random(seed)
    x = x0
    while x < x1:
        h = r.randint(1, maxh)
        l.cspans(t, x, gy - h, [i // 2 for i in range(h)])
        x += r.randint(18, 40)
    return l

def gems(l, pts):
    for x, y in pts:
        l.ellipse('cryst', x, y, 9, 5, DECOR)
    return l

def reeds(l, x0, x1, wy):
    l.rect('reed', x0, wy - 9, x1 - x0, 9, DECOR)
    return l

def streaks(l, x0, x1, y0, y1, t='rock', step=11, seed=1):
    """weathering lines painted over solid faces (picture only)"""
    r = _r.Random(seed)
    x = x0 + r.randint(0, step // 2)
    while x < x1:
        a = y0 + r.randint(0, (y1 - y0) // 3)
        l.rect(t, x, a, 2, max(2, y1 - a - r.randint(0, (y1 - y0) // 3)), OVER)
        x += step + r.randint(-3, 3)
    return l

def bushes(l, x0, x1, gy, seed=1, t='canopy'):
    """low scrub along the ground line, behind the bilbies"""
    r = _r.Random(seed)
    x = x0 + r.randint(0, 20)
    while x < x1:
        l.ellipse(t, x, gy - 2, r.randint(5, 11), r.randint(2, 4), DECOR)
        x += r.randint(26, 60)
    return l

def columns(l, x0, x1, top, bot, seed=1, t='redhill'):
    """faint rock columns and flowstone at the back of a cave"""
    r = _r.Random(seed)
    x = x0 + r.randint(0, 30)
    while x < x1:
        w = r.randint(4, 9)
        l.rect(t, x - w // 2, top, w, bot - top, DECOR)
        l.ellipse(t, x, top + 4, w + 4, 4, DECOR)
        l.ellipse(t, x, bot - 3, w + 5, 3, DECOR)
        x += r.randint(50, 90)
    return l

import stamps as _stamps
def scenery(l, *items, start=0):
    """Australiana stamps.  Each item is (name, x) or (name, x, flip) or
    (name, x, flip, y): with no y the stamp stands on the first ground below
    the top of the map at its middle; with y it hangs with its top row at y
    (birds, stars, bats, lamps)."""
    g, m = lvlkit.raster(l)
    for it in items:
        name, x = it[0], it[1]
        flip = len(it) > 2 and it[2]
        rows = _stamps.S[name]
        w, h = len(rows[0]), len(rows)
        if len(it) > 3:
            l.stamp(name, x, it[3] + h, flip)
            continue
        cx = min(l.width - 1, x + w // 2)
        y = max(h, start)
        while y < l.height and m[y][cx]:
            y += 1                  # (out of the rock we started in)
        while y < l.height and not m[y][cx]:
            y += 1
        l.stamp(name, x, min(y, l.height), flip)
    return l

def pillars(l, xs, y0, y1, t='stone', w=6, mode=DECOR):
    """ruined columns: behind the action unless mode=SOLID"""
    for x in xs:
        l.rect(t, x, y0, w, y1 - y0, mode)
        l.rect('ruin', x - 9, y0 + 4, 18 + w, y1 - y0 - 4, DECOR)
        l.rect(t, x - 3, y0, w + 6, 3, mode)
    return l

# ===========================================================================
# the levels
# ===========================================================================
exec(open(__file__.replace('levels.py', 'levels_data.py')).read())

# ===========================================================================
# the title scene: the logo letters are ground to walk on
# ===========================================================================
LOGO = {
 'B': ['YYYY.', 'Y...Y', 'Y...Y', 'YYYY.', 'Y...Y', 'Y...Y', 'YYYY.'],
 'I': ['YYY', '.Y.', '.Y.', '.Y.', '.Y.', '.Y.', 'YYY'],
 'L': ['Y...', 'Y...', 'Y...', 'Y...', 'Y...', 'Y...', 'YYYY'],
 'E': ['YYYY', 'Y...', 'Y...', 'YYY.', 'Y...', 'Y...', 'YYYY'],
 'S': ['.YYY', 'Y...', 'Y...', '.YY.', '...Y', '...Y', 'YYY.'],
 '!': ['Y', 'Y', 'Y', 'Y', 'Y', '.', 'Y'],
}

def logo_bitmap():
    """BILBIES! in chunky letters 2 px x 2 rows a cell, yellow faces, red
    shadows, a green lit top -> rows of 128 pixel chars"""
    word = 'BILBIES!'
    W, Hh = 128, 16
    g = [['.'] * W for _ in range(Hh)]
    x = 4
    cells = []
    for ch in word:
        a = LOGO[ch]
        for j, r in enumerate(a):
            for i, c in enumerate(r):
                if c == 'Y':
                    cells.append((x + i * 3, j * 2))
        x += len(a[0]) * 3 + 3
    filled = set()
    for cx, cy in cells:
        for dx in range(3):
            for dy in range(2):
                filled.add((cx + dx, cy + dy))
    # shadow (down-right), then faces
    for (px, py) in filled:
        for sx, sy in ((1, 1), (2, 1), (1, 2)):
            q = (px + sx, py + sy)
            if q not in filled and q[0] < W and q[1] < Hh:
                g[q[1]][q[0]] = 'R'
    for (px, py) in filled:
        if px < W and py < Hh:
            top = (px, py - 1) not in filled
            g[py][px] = 'G' if top else ('Y' if (px + py) % 5 else 'R' if False else 'Y')
    return [''.join(r) for r in g], x

def title_level():
    t = Level('Title', n=40, rate=70, save=40, minutes=9, width=128, height=44, bg='sky')
    rows, wdt = logo_bitmap()
    data = pack(rows)
    t.image(0, 10, 32, data)
    t.hatch = (4, 0)
    t.rect('wood', 2, 8, 98, 1)
    t.exit = (118, 37)
    t.ground('earth', 0, 127, 38, rough=0, seed=7)
    t.edges('G', None)
    return t

TITLE = title_level()
DEMOS = [0, 3, 14, 19, 8]
