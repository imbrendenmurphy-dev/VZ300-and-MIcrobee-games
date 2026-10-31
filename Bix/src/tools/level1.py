# Level 1-1  GUMLEAF GULLY  - built procedurally with stamps so it is easy to edit.
# Grid: W columns x 12 rows (row 0 = top). Normal ground surface = row 9.
from art import TID

W = 288
H = 12
g = [['sky'] * H for _ in range(W)]   # g[x][y]
ents = []   # (x, y, type, param)

E_ANT, E_MAG, E_DROP, E_TOAD, E_PLATH, E_PLATV, E_GLOW, E_ONEUP, E_START = range(1, 10)

def put(x, y, t):
    if 0 <= x < W and 0 <= y < H: g[x][y] = t
def ground(x0, x1, top=9, kind='grass'):
    for x in range(x0, x1):
        put(x, top, kind)
        for y in range(top + 1, H):
            put(x, y, 'soil2' if (x * 7 + y * 3) % 11 == 0 else 'soil')
def rockcol(x0, x1, top, bottom=H - 1):
    for x in range(x0, x1):
        put(x, top, 'rocktop')
        for y in range(top + 1, bottom + 1): put(x, y, 'rock')
def logs(x, y, n):
    for i in range(n): put(x + i, y, 'log')
def stars(x, y, n, dy=None):
    for i in range(n):
        yy = y + (dy[i] if dy else 0)
        put(x + i, yy, 'star')
def tree(x, base=9, h=4):
    # trunk from base-1 upward h tiles, canopy 3 wide 2 tall above
    put(x, base - 1, 'trunkB')
    for i in range(2, h): put(x, base - i, 'trunk')
    top = base - h
    for dx in (-1, 0, 1):
        put(x + dx, top - 1, 'leafT')
        put(x + dx, top, 'leafB')
def bigtree(x, base=9, h=5):
    put(x, base - 1, 'trunkB')
    for i in range(2, h): put(x, base - i, 'trunk')
    top = base - h
    for dx in range(-2, 3):
        put(x + dx, top - 2, 'leafT')
        put(x + dx, top - 1, 'leaf')
        put(x + dx, top, 'leafB')
def cloud(x, y, n=1):
    put(x, y, 'cloudL')
    for i in range(n): put(x + 1 + i, y, 'cloudM')
    put(x + 1 + n, y, 'cloudR')
def hills(x0, x1, top=7):
    # distant dithered range in the lower sky (pure decoration)
    x = x0
    while x < x1:
        w = 3 + (x * 5) % 4
        if x + w + 2 > x1: break
        put(x, top, 'hillL')
        for i in range(1, w + 1): put(x + i, top, 'hillM')
        put(x + w + 1, top, 'hillR')
        for i in range(0, w + 2):
            for y in range(top + 1, 9): put(x + i, y, 'hillB')
        x += w + 3
def decor_ground(x, t):  # put decoration on the sky tile just above ground row 9
    if g[x][8] in ('sky', 'hillB'): put(x, 8, t)
def pit(x0, x1):
    for x in range(x0, x1):
        for y in range(9, H): put(x, y, 'sky')
def pond(x0, x1):
    for x in range(x0, x1):
        put(x, 9, 'sky'); put(x, 10, 'watert'); put(x, 11, 'water')
def ent(x, y, t, p=0): ents.append((x, y, t, p))

# --- sky dressing everywhere
for x in range(W):
    if (x * 13) % 17 == 0: put(x, (x * 7) % 5, 'sky_tw')
    if (x * 11) % 29 == 0: put(x, (x * 3) % 4 + 1, 'sky_tw2')
hills(0, W, 7)
for x, y, n in [(4, 1, 2), (19, 3, 1), (33, 0, 3), (52, 2, 1), (70, 1, 2), (95, 3, 2), (118, 0, 1),
                (140, 2, 3), (163, 1, 1), (190, 3, 2), (214, 0, 2), (236, 2, 1), (258, 1, 3), (276, 3, 1)]:
    cloud(x, y, n)
for (mx, my) in [(26, 1)]:
    put(mx, my, 'moonTL'); put(mx + 1, my, 'moonTR'); put(mx, my + 1, 'moonBL'); put(mx + 1, my + 1, 'moonBR')

# ---------------- A: 0-30  first steps, first dig
ground(0, 36)
ent(3, 7, E_START)
tree(9); decor_ground(5, 'flower'); decor_ground(6, 'tuft'); decor_ground(12, 'bush')
stars(14, 6, 4, [1, 0, 0, 1])
# buried treasure pocket: lantern marks a dig spot
decor_ground(17, 'lantern')
for x in range(18, 23): put(x, 10, 'bstar' if x % 2 == 0 else 'soil')
put(20, 11, 'bstar')
ent(24, 8, E_ANT)
decor_ground(27, 'fern'); decor_ground(30, 'rockS'); decor_ground(33, 'tuft')

# ---------------- B: 36-62  log steps, termite blocks, bonus
ground(36, 62)
logs(38, 7, 3); logs(43, 5, 3); logs(48, 3, 4)
stars(43, 4, 3); stars(48, 2, 4)
put(54, 5, 'termite'); put(55, 5, 'bonus'); put(56, 5, 'termite')
ent(55, 4, E_GLOW, 1)    # param 1 = hidden in bonus block (spawned by block)
ent(46, 6, E_MAG)
ent(58, 8, E_ANT)
bigtree(40); decor_ground(52, 'flower'); decor_ground(60, 'bush')

# ---------------- C: 62-92  the wall: dig under it, or spring over it
ground(62, 92)
rockcol(72, 76, 3, 9)        # rock wall rows 3..9 resting on soil (dig below it!)
for x in range(72, 76):
    put(x, 10, 'soil'); put(x, 11, 'soil')
put(70, 10, 'bstar'); put(77, 11, 'bstar'); put(74, 11, 'bstar')
decor_ground(69, 'lantern')
put(66, 8, 'shroom')         # spring route up and over
stars(66, 3, 1); stars(67, 1, 5, [1, 0, 0, 0, 1])
logs(68, 4, 3)
stars(72, 2, 4)
ent(80, 6, E_MAG)
ent(84, 8, E_ANT)
decor_ground(64, 'tuft'); tree(87); decor_ground(90, 'fern')
put(89, 8, 'check')

# ---------------- D: 92-124  the billabong (pond + moving logs)
ground(92, 96)
pond(96, 116)
ent(97, 7, E_PLATH, 6)       # log 1: stays in view from the bank
ent(107, 6, E_PLATH, 5)      # log 2: a different period, so the two drift in and out of step
stars(99, 5, 3); stars(108, 4, 3)
logs(105, 3, 2); stars(105, 2, 2)
ground(116, 124)
decor_ground(117, 'flower'); decor_ground(119, 'bush'); decor_ground(122, 'tuft')
ent(121, 8, E_TOAD)

# ---------------- E: 124-160  drop-bear forest
ground(124, 160)
for tx in (127, 134, 141, 149, 156): bigtree(tx, 9, 6)
for tx in (127, 141, 156): ent(tx, 3, E_DROP)
put(131, 8, 'thorn'); put(132, 8, 'thorn'); put(145, 8, 'thorn'); put(146, 8, 'thorn')
logs(130, 5, 3); logs(144, 5, 3)
stars(130, 4, 3); stars(144, 4, 3)
put(138, 8, 'shroom'); stars(138, 2, 1); stars(137, 1, 3)
ent(152, 8, E_ANT)

# ---------------- F: 160-200  thorn field over a secret tunnel
ground(160, 200)
for x in range(165, 192): put(x, 8, 'thorn')
logs(168, 5, 3); logs(176, 4, 3); logs(184, 5, 3)
stars(168, 4, 3); stars(176, 3, 3); stars(184, 4, 3)
decor_ground(163, 'lantern')
# tunnel of buried stars along row 10, secret chamber at 178-181 rows 10-11
for x in range(166, 191, 2): put(x, 10, 'bstar')
for x in range(178, 182):
    put(x, 10, 'soilD'); put(x, 11, 'soilD')
ent(179, 10, E_ONEUP)
ent(171, 3, E_MAG); ent(187, 3, E_MAG)
put(196, 8, 'check')

# ---------------- G: 200-240  the climb (vertical)
ground(200, 240)
rockcol(214, 216, 2, 9)
logs(203, 7, 2); logs(206, 5, 2); logs(203, 3, 2); logs(207, 1, 3)
stars(203, 6, 2); stars(206, 4, 2); stars(203, 2, 2); stars(207, 0, 3)
ent(210, 6, E_PLATV, 5)
logs(216, 2, 4); stars(217, 1, 3)
put(222, 8, 'shroom')
stars(222, 3, 1)
ent(226, 8, E_TOAD); ent(233, 8, E_TOAD)
tree(230); decor_ground(236, 'bush')
put(225, 10, 'bstar'); put(226, 11, 'bstar'); put(227, 10, 'bstar')

# ---------------- H: 240-288  the gully run (speed!)
ground(240, 252)
pit(252, 256)
ground(256, 288)
stars(244, 7, 8, [1, 1, 0, 0, 0, 0, 1, 1])
stars(252, 6, 4, [1, 0, 0, 1])
ent(262, 8, E_ANT); ent(268, 8, E_ANT); ent(272, 6, E_MAG)
stars(260, 7, 12, [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0])
put(281, 7, 'exitT'); put(281, 8, 'exitB')
bigtree(285); decor_ground(278, 'flower'); decor_ground(283, 'flower')

def build():
    m = bytearray()
    for x in range(W):
        for y in range(H):
            m.append(TID[g[x][y]])
    e = bytearray()
    for (x, y, t, p) in sorted(ents):
        e += bytes([x & 255, x >> 8, y, t, p])
    e += b'\xff\xff'
    return m, e

# v0.2: witchetty grubs
ents.append((34, 8, 10, 0))
ents.append((259, 8, 10, 0))

# v0.6: gentle hills with slopes
def plateau(x0, x1, top=8):
    put(x0, top, 'slopeR')
    for x in range(x0 + 1, x1 - 1):
        put(x, top, 'grass'); put(x, top + 1, 'soil')
    put(x1 - 1, top, 'slopeL')
plateau(29, 35)
plateau(262, 268)
