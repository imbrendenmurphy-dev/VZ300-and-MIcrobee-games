# BIX 2 - THE LOST LEVELS: acts 2 and 3 of every world.
# Same kit and tilesets as the first game; ground surface = row 9, Bix stands
# with his feet on row 9 (spawn y 7).  Every act ends at an exit burrow.
from lvlkit import *


# ---------------------------------------------------------------- shared dressing
def cloud(L, x, y, n=1):
    L.put(x, y, 'cloudL')
    for i in range(n): L.put(x + 1 + i, y, 'cloudM')
    L.put(x + 1 + n, y, 'cloudR')

def moon(L, x, y):
    L.put(x, y, 'moonTL'); L.put(x + 1, y, 'moonTR'); L.put(x, y + 1, 'moonBL'); L.put(x + 1, y + 1, 'moonBR')

def hills(L, x0, x1, top=7, bottom=8, body='hillB', step=3):
    x = x0
    while x < x1:
        w = 3 + (x * 5) % 4
        if x + w + 2 > x1: break
        L.put(x, top, 'hillL')
        for i in range(1, w + 1): L.put(x + i, top, 'hillM')
        L.put(x + w + 1, top, 'hillR')
        for i in range(w + 2):
            for y in range(top + 1, bottom + 1):
                L.put(x + i, y, 'hillBT' if (y == top + 1 and body == 'hillBT') else 'hillB')
        x += w + step

def tree(L, x, base=9, h=4):
    L.put(x, base - 1, 'trunkB')
    for i in range(2, h): L.put(x, base - i, 'trunk')
    top = base - h
    for dx in (-1, 0, 1):
        L.put(x + dx, top - 1, 'leafT'); L.put(x + dx, top, 'leafB')

def bigtree(L, x, base=9, h=5):
    L.put(x, base - 1, 'trunkB')
    for i in range(2, h): L.put(x, base - i, 'trunk')
    top = base - h
    for dx in range(-2, 3):
        L.put(x + dx, top - 2, 'leafT'); L.put(x + dx, top - 1, 'leaf'); L.put(x + dx, top, 'leafB')

def pond(L, x0, x1):
    for x in range(x0, x1):
        L.put(x, 9, 'sky'); L.put(x, 10, 'watert'); L.put(x, 11, 'water')

def bonus(L, x, y):
    L.put(x - 1, y, 'termite'); L.put(x, y, 'bonus'); L.put(x + 1, y, 'termite')
    L.ent(x, y - 1, E_GLOW, 1)

def pocket(L, x0, x1, y0, y1, oneup=True):
    """a hollow under the ground with a 1-UP in it (dig to reach it)"""
    L.fill(x0, x1, y0, y1, 'soilD')
    if oneup: L.ent(x0 + 1, y0, E_ONEUP)

def exitgate(L, x):
    L.put(x, 7, 'exitT'); L.put(x, 8, 'exitB')

def w1_sky(L):
    for x in range(L.W):
        if (x * 13) % 17 == 0: L.put(x, (x * 7) % 5, 'sky_tw')
        if (x * 11) % 29 == 0: L.put(x, (x * 3) % 4 + 1, 'sky_tw2')
    hills(L, 0, L.W, 7)
    x = 3
    while x < L.W - 6:
        cloud(L, x, (x * 7) % 4, 1 + x % 3)
        x += 17 + (x * 3) % 9

def w2_cave(L):
    for x in range(L.W):
        L.put(x, 0, 'rock')
        L.put(x, 1, ('cloudL', 'cloudM', 'cloudR')[x % 3])
        if (x * 7) % 13 == 0: L.put(x, 3 + x % 3, 'sky_tw')
        if (x * 5) % 23 == 0: L.put(x, 2 + x % 4, 'sky_tw2')
    hills(L, 0, L.W, 6, 8, body='hillBT', step=4)

def w3_works(L, girders):
    for x in range(L.W):
        L.put(x, 0, 'rock')
        L.put(x, 1, ('cloudL', 'cloudM', 'cloudM', 'cloudR')[x % 4] if (x // 8) % 3 else 'leafT')
        if (x * 7) % 19 == 0: L.put(x, 3 + x % 3, 'sky_tw')
        if (x * 5) % 31 == 0: L.put(x, 2 + x % 4, 'sky_tw2')
    hills(L, 0, L.W, 6, 8, body='hillBT', step=4)
    for xx in girders:
        for d in range(2, 9): L.put(xx, d, 'trunk')
        L.put(xx, 8, 'trunkB')

def w4_sky(L):
    for x in range(L.W):
        if (x * 7) % 17 == 0: L.put(x, (x * 3) % 6, 'sky_tw')
        if (x * 5) % 29 == 0: L.put(x, 1 + (x * 7) % 5, 'sky_tw2')
    x = 5
    while x < L.W - 6:
        cloud(L, x, (x * 3) % 4, 1 + x % 3)
        x += 19 + (x * 7) % 7
    x = 0
    while x < L.W - 6:
        w = 3 + (x * 5) % 4
        L.put(x, 10, 'hillL')
        for i in range(1, w + 1): L.put(x + i, 10, 'hillM')
        L.put(x + w + 1, 10, 'hillR')
        x += w + 5

def island(L, x0, x1, top):
    for x in range(x0, x1):
        L.put(x, top, 'grass')
        if top + 1 < 12: L.put(x, top + 1, 'soil2' if (x * 3) % 7 == 0 else 'soil')
        if top + 2 < 12: L.put(x, top + 2, 'leafB')

def wind(L, x, y0, y1=11):           # sky updraft / volcano vent column
    for y in range(y0, y1 + 1):
        if L.get(x, y) in ('sky', 'sky_tw', 'sky_tw2', 'hillL', 'hillM', 'hillR', 'hillB', 'hillBT'):
            L.put(x, y, 'fern')

def w5_peaks(L):
    for x in range(L.W):
        if (x * 7) % 13 == 0: L.put(x, (x * 3) % 6, 'sky_tw')
        if (x * 5) % 23 == 0: L.put(x, 1 + (x * 7) % 5, 'sky_tw2')
    x = 6
    while x < L.W - 6:
        cloud(L, x, (x * 5) % 3, 1 + x % 3)
        x += 23 + (x * 3) % 11
    hills(L, 0, L.W, 6, 8, body='hillBT', step=3)

def lava(L, x0, x1):
    pond(L, x0, x1)


# ================================================================= WORLD 1
def level_1_2():
    """BILLABONG BEND - stepping stones, a sunken log, the big billabong"""
    L = Level(256)
    w1_sky(L)
    moon(L, 20, 1)
    # A 0-32 the bank
    L.ground(0, 34)
    L.ent(2, 7, E_START)
    tree(L, 8); bigtree(L, 26)
    L.deco(5, 8, 'flower'); L.deco(12, 8, 'tuft'); L.deco(20, 8, 'bush')
    L.stars(13, 6, 4, [1, 0, 0, 1])
    L.deco(17, 8, 'lantern')
    for xx in (18, 20, 22): L.put(xx, 10, 'bstar')
    L.ent(23, 8, E_ANT)
    L.plateau(29, 34)
    # B 34-64 stepping stones across the reeds
    pond(L, 34, 62)
    for x0 in (38, 44, 50, 56):
        L.ground(x0, x0 + 2)
        L.stars(x0 - 2, 6, 2, [1, 0])
    L.logs(42, 4, 3); L.stars(42, 3, 3)
    L.logs(53, 3, 3); L.stars(53, 2, 3)
    L.ent(47, 3, E_MAG)
    L.ground(62, 100)
    # C 64-96 the hollow log hill: climb the logs or dig straight through
    L.earth(70, 88, 6, 8)
    for xx in range(70, 88): L.put(xx, 6, 'grass')
    L.put(70, 6, 'slopeR'); L.put(87, 6, 'slopeL')
    L.logs(66, 7, 2); L.logs(68, 5, 2)
    L.stars(72, 4, 4); L.stars(80, 4, 4)
    for xx, yy in [(72, 8), (75, 10), (78, 7), (81, 11), (84, 9)]: L.put(xx, yy, 'bstar')
    pocket(L, 77, 80, 10, 11)
    L.ent(76, 5, E_ANT); L.ent(84, 5, E_WORM)
    bigtree(L, 92, 9, 6); L.ent(92, 3, E_DROP)
    L.put(96, 8, 'check')
    # D 98-138 the big billabong: two log rides with a reed island between
    pond(L, 100, 113)
    L.ent(101, 7, E_PLATH, 5)
    L.ground(113, 117)
    L.deco(115, 8, 'tuft')
    pond(L, 117, 136)
    L.ent(118, 7, E_PLATH, 5)
    L.ent(127, 6, E_PLATH, 4)
    L.stars(103, 5, 3); L.stars(120, 5, 3); L.stars(129, 4, 3)
    L.logs(108, 3, 3); L.stars(108, 2, 3)
    L.ent(110, 2, E_MAG); L.ent(124, 2, E_MAG)
    L.ground(136, 176)
    # E 136-176 toad marsh: little puddles, a bonus block, a spring to the high logs
    for x0 in (142, 151, 163): pond(L, x0, x0 + 2)
    L.ent(146, 8, E_TOAD); L.ent(158, 8, E_TOAD); L.ent(169, 8, E_TOAD)
    bonus(L, 148, 5)
    L.put(155, 8, 'shroom')
    L.logs(154, 3, 6); L.stars(154, 2, 6)
    L.deco(139, 8, 'flower'); L.deco(166, 8, 'bush'); L.deco(173, 8, 'fern')
    tree(L, 161)
    # F 176-214 the reed bed: sharp reeds on top, a secret tunnel below
    L.ground(176, 216)
    for xx in range(181, 203): L.put(xx, 8, 'thorn')
    L.logs(183, 5, 3); L.logs(190, 4, 3); L.logs(197, 5, 3)
    L.stars(183, 4, 3); L.stars(190, 3, 3); L.stars(197, 4, 3)
    L.deco(179, 8, 'lantern')
    for xx in range(182, 202, 2): L.put(xx, 10, 'bstar')
    pocket(L, 191, 194, 10, 11)
    L.ent(187, 2, E_MAG)
    L.put(212, 8, 'check')
    L.ent(208, 8, E_ANT)
    # G 216-256 home stretch
    L.ground(216, 256)
    pond(L, 226, 231)
    L.ent(226, 7, E_PLATH, 2)
    L.stars(226, 5, 5, [1, 0, 0, 0, 1])
    bigtree(L, 236, 9, 6); L.ent(236, 3, E_DROP)
    L.ent(242, 8, E_WORM); L.ent(222, 8, E_ANT)
    L.stars(238, 7, 6, [1, 0, 1, 0, 1, 0])
    exitgate(L, 250)
    L.deco(247, 8, 'flower'); L.deco(253, 8, 'bush')
    return L


def level_1_3():
    """TERMITE TOWERS - mounds to burrow through, high termite stacks"""
    L = Level(256)
    w1_sky(L)
    moon(L, 40, 0)

    def mound(x0, x1, top):
        """an earth mound rising from the ground with ramps on both sides"""
        L.earth(x0, x1, top, 8)
        for xx in range(x0, x1): L.put(xx, top, 'grass')
        L.put(x0, top, 'slopeR'); L.put(x1 - 1, top, 'slopeL')
        # stepping logs up the near side
        for i, yy in enumerate(range(8, top, -2)):
            L.logs(x0 - 2, yy, 2)

    def tower(x, top):
        """a termite stack: breakable blocks you can knock out from below"""
        for yy in range(top, 9): L.put(x, yy, 'termite')

    # A 0-34 the meadow
    L.ground(0, 256)
    L.ent(2, 7, E_START)
    tree(L, 7); L.deco(11, 8, 'flower'); L.deco(15, 8, 'tuft')
    L.stars(12, 6, 4, [1, 0, 0, 1])
    L.deco(19, 8, 'lantern')
    for xx in (20, 21, 22): L.put(xx, 11, 'bstar')
    L.put(21, 10, 'bstar')
    L.ent(26, 8, E_ANT)
    L.plateau(28, 33)
    # B 34-70 the first mound: over it, or through it
    mound(38, 56, 5)
    for xx, yy in [(41, 7), (44, 9), (47, 6), (50, 10), (53, 8)]: L.put(xx, yy, 'bstar')
    L.stars(42, 3, 3); L.stars(50, 3, 3)
    pocket(L, 46, 49, 10, 11)
    L.ent(44, 4, E_WORM); L.ent(52, 4, E_ANT)
    L.ent(62, 8, E_TOAD)
    tree(L, 65)
    # C 70-104 termite stacks - knock out a block, or hop over
    for x, top in [(74, 6), (80, 5), (86, 6), (92, 4)]:
        tower(x, top)
        L.stars(x - 1, top - 2, 3)
    L.put(77, 8, 'shroom'); L.put(89, 8, 'shroom')
    L.logs(83, 2, 3); L.stars(83, 1, 3)
    L.ent(83, 8, E_ANT); L.ent(95, 8, E_ANT)
    L.ent(86, 2, E_MAG)
    L.put(101, 8, 'check')
    # D 104-140 the long tunnel: a wall of earth with only a rock lid on top
    L.rock(108, 134, 0, 3, top=False)
    L.earth(108, 134, 4, 11)
    for xx in range(108, 134): L.put(xx, 4, 'grass')
    L.put(108, 4, 'soil'); L.put(133, 4, 'soil')
    for xx, yy in [(110, 6), (113, 9), (116, 7), (119, 10), (122, 6), (125, 9), (128, 7), (131, 10)]:
        L.put(xx, yy, 'bstar')
    pocket(L, 118, 121, 7, 8)
    L.deco(105, 8, 'lantern')
    L.ent(137, 8, E_WORM)
    # E 140-176 the twin mounds and drop-bear trees
    mound(144, 154, 6)
    mound(160, 172, 5)
    bigtree(L, 157, 9, 6); L.ent(157, 3, E_DROP)
    L.stars(146, 4, 3); L.stars(162, 3, 4)
    for xx, yy in [(147, 8), (150, 10), (163, 7), (166, 10), (169, 8)]: L.put(xx, yy, 'bstar')
    L.ent(150, 5, E_ANT); L.ent(166, 4, E_WORM)
    bonus(L, 178, 5)
    # F 176-214 the termite cathedral: a tall stack and a spring
    for x, top in [(184, 5), (186, 3), (188, 5)]: tower(x, top)
    L.put(182, 8, 'shroom')
    L.logs(185, 1, 3); L.stars(185, 0, 3)
    L.stars(190, 6, 4, [1, 0, 0, 1])
    L.ent(194, 8, E_TOAD); L.ent(200, 8, E_ANT); L.ent(197, 3, E_MAG)
    pond(L, 204, 208)
    L.stars(204, 6, 4, [1, 0, 0, 1])
    L.put(212, 8, 'check')
    # G 214-256 the last mound and home
    mound(220, 236, 5)
    for xx, yy in [(222, 8), (225, 10), (228, 7), (231, 9), (234, 11)]: L.put(xx, yy, 'bstar')
    L.stars(224, 3, 8, [1, 0, 0, 0, 0, 0, 0, 1])
    L.ent(226, 4, E_WORM); L.ent(232, 4, E_ANT)
    L.ent(240, 8, E_ANT)
    bigtree(L, 245); exitgate(L, 250)
    L.deco(253, 8, 'flower')
    return L


# ================================================================= WORLD 2
def level_2_2():
    """THE GLOW MINES - minecart rides over the chasms, shafts and stalactites"""
    L = Level(256)
    w2_cave(L)
    # A 0-30 the mine mouth
    L.ground(0, 30)
    for xx in range(0, 24):
        L.put(xx, 2, 'leaf'); L.put(xx, 3, 'leafB')
    L.ent(2, 7, E_START)
    moon(L, 9, 7)
    L.deco(5, 8, 'flower'); L.deco(14, 8, 'rockS'); L.deco(20, 8, 'lantern')
    L.stars(13, 6, 4, [1, 0, 0, 1])
    for xx in (21, 23, 25): L.put(xx, 10, 'bstar')
    L.ent(26, 8, E_ANT)
    # B 30-66 the first chasm: carts on the rails
    L.logs(30, 9, 2)
    pond(L, 30, 64)
    for xx in (30, 31): L.put(xx, 9, 'grass'); L.put(xx, 10, 'soil'); L.put(xx, 11, 'soil')
    L.ent(33, 7, E_PLATH, 6)
    L.ground(45, 48)
    L.ent(49, 7, E_PLATH, 5)
    L.ent(58, 6, E_PLATH, 3)
    L.stars(35, 5, 3); L.stars(51, 5, 3); L.stars(59, 4, 3)
    L.logs(42, 3, 3); L.stars(42, 2, 3)
    L.ent(40, 4, E_MAG); L.ent(55, 3, E_MAG)
    L.ground(64, 98)
    # C 64-96 the stalactite gallery
    L.rock(66, 94, 0, 3, top=False)
    for xx in range(66, 94): L.put(xx, 4, 'leafB')
    for xx in (70, 76, 82, 88): L.ent(xx, 5, E_DROP)
    L.stars(72, 7, 2); L.stars(78, 7, 2); L.stars(84, 7, 2); L.stars(90, 7, 2)
    L.ent(80, 8, E_WORM)
    L.put(96, 8, 'check')
    # D 98-134 the lift shaft
    L.ground(98, 136)
    L.rock(106, 108, 3, 9)
    L.logs(100, 7, 2); L.logs(103, 5, 2); L.logs(100, 3, 2)
    L.stars(100, 6, 2); L.stars(103, 4, 2); L.stars(100, 2, 2)
    L.ent(110, 6, E_PLATV, 4)
    L.logs(114, 2, 5); L.stars(114, 1, 5)
    L.rock(120, 122, 3, 9)
    L.ent(124, 6, E_PLATV, 4)
    L.logs(128, 3, 4); L.stars(128, 2, 4)
    L.ent(117, 8, E_ANT); L.ent(131, 8, E_WORM)
    for xx in (112, 118, 126): L.put(xx, 10, 'bstar')
    # E 136-172 the dig-down seam: a shelf of earth hiding the way on
    L.ground(136, 176)
    L.earth(142, 166, 5, 8)
    for xx in range(142, 166): L.put(xx, 5, 'grass')
    L.put(142, 5, 'slopeR'); L.put(165, 5, 'slopeL')
    L.logs(139, 7, 2)
    L.stars(145, 3, 4); L.stars(157, 3, 4)
    for xx, yy in [(144, 7), (147, 10), (151, 8), (155, 11), (159, 7), (163, 9)]: L.put(xx, yy, 'bstar')
    pocket(L, 150, 153, 10, 11)
    L.ent(148, 4, E_ANT); L.ent(160, 4, E_WORM)
    L.ent(169, 8, E_TOAD)
    bonus(L, 170, 5)
    # F 174-214 the second chasm and the crystal spikes
    pond(L, 176, 196)
    L.ent(177, 7, E_PLATH, 5)
    L.ent(186, 6, E_PLATH, 5)
    L.stars(179, 5, 3); L.stars(188, 4, 3)
    L.ent(184, 2, E_MAG)
    L.ground(196, 216)
    for xx in list(range(200, 204)) + list(range(208, 211)): L.put(xx, 8, 'thorn')
    L.put(198, 8, 'shroom'); L.put(206, 8, 'shroom')
    L.logs(200, 4, 4); L.stars(200, 3, 4)
    L.put(213, 8, 'check')
    # G 216-256 the tunnel out
    L.ground(216, 256)
    for xx in range(222, 244):
        L.put(xx, 2, 'leaf'); L.put(xx, 3, 'leafB')
    L.stars(220, 7, 10, [1, 0, 1, 0, 1, 0, 1, 0, 1, 0])
    L.ent(226, 8, E_WORM); L.ent(234, 8, E_ANT); L.ent(240, 8, E_WORM)
    for xx in (228, 236): L.ent(xx, 4, E_DROP)
    exitgate(L, 250)
    moon(L, 252, 7)
    return L


def level_2_3():
    """THE SUNLESS SEA - an underground lake, islands, bats and lifts"""
    L = Level(256)
    w2_cave(L)
    # A 0-24 the shore
    L.ground(0, 26)
    L.ent(2, 7, E_START)
    L.deco(6, 8, 'flower'); L.deco(12, 8, 'lantern'); L.deco(18, 8, 'rockS')
    for xx in (13, 15): L.put(xx, 10, 'bstar')
    L.stars(8, 6, 4, [1, 0, 0, 1])
    L.ent(20, 8, E_ANT)
    # B 26-64 the shallows: rock islands and two rafts
    pond(L, 26, 64)
    for x0, top in [(31, 8), (38, 7), (45, 8), (55, 8)]:
        L.rock(x0, x0 + 3, top, 11)
        L.stars(x0, top - 2, 3)
    L.ent(49, 6, E_PLATH, 3)
    L.ent(59, 7, E_PLATH, 2)
    L.ent(35, 3, E_MAG); L.ent(52, 2, E_MAG)
    L.ground(64, 100)
    # C 64-100 the grotto: low ceiling, a dig-through mound, crystal blocks
    L.rock(68, 98, 0, 2, top=False)
    for xx in range(68, 98): L.put(xx, 3, 'leafB')
    L.earth(74, 90, 6, 8)
    for xx in range(74, 90): L.put(xx, 6, 'grass')
    L.put(74, 6, 'slopeR'); L.put(89, 6, 'slopeL')
    L.logs(71, 7, 2)
    for xx, yy in [(76, 8), (79, 10), (82, 7), (85, 11), (88, 9)]: L.put(xx, yy, 'bstar')
    pocket(L, 80, 83, 10, 11)
    L.ent(78, 5, E_ANT); L.ent(86, 5, E_WORM)
    L.ent(94, 4, E_DROP)
    L.put(97, 8, 'check')
    # D 100-150 the open sea: a long raft chain with an islet halfway
    pond(L, 100, 122)
    L.ent(101, 7, E_PLATH, 5)
    L.ent(111, 6, E_PLATH, 5)
    L.rock(122, 126, 8, 11)
    L.deco(124, 7, 'rockS')
    pond(L, 126, 150)
    L.ent(127, 7, E_PLATH, 5)
    L.ent(137, 6, E_PLATH, 6)
    L.stars(103, 5, 3); L.stars(113, 4, 3); L.stars(129, 5, 3); L.stars(139, 4, 3)
    L.logs(118, 3, 3); L.stars(118, 2, 3)
    L.ent(106, 2, E_MAG); L.ent(132, 2, E_MAG); L.ent(144, 3, E_MAG)
    L.ground(150, 180)
    # E 150-180 the bat roost: a stalactite ceiling and a bonus
    L.rock(154, 176, 0, 3, top=False)
    for xx in range(154, 176): L.put(xx, 4, 'leafB')
    for xx in (158, 165, 172): L.ent(xx, 5, E_DROP)
    L.stars(156, 7, 3); L.stars(163, 7, 3); L.stars(170, 7, 3)
    L.ent(161, 8, E_TOAD)
    bonus(L, 168, 5)
    L.put(178, 8, 'check')
    # F 180-218 the deep shaft: lifts up out of the sea
    L.ground(180, 186)
    pond(L, 186, 214)
    L.ent(188, 8, E_PLATV, 4)
    L.logs(192, 4, 4); L.stars(192, 3, 4)
    L.ent(198, 8, E_PLATV, 4)
    L.logs(202, 3, 4); L.stars(202, 2, 4)
    L.ent(208, 7, E_PLATH, 3)
    L.ent(196, 1, E_MAG)
    L.ground(214, 256)
    # G 214-256 the far shore
    for xx in list(range(222, 225)) + list(range(232, 235)): L.put(xx, 8, 'thorn')
    L.put(220, 8, 'shroom'); L.put(230, 8, 'shroom')
    L.logs(222, 4, 3); L.logs(232, 4, 3); L.stars(222, 3, 3); L.stars(232, 3, 3)
    L.ent(228, 8, E_WORM); L.ent(240, 8, E_ANT); L.ent(236, 3, E_MAG)
    exitgate(L, 250)
    moon(L, 246, 7)
    return L


# ================================================================= WORLD 3
def level_3_2():
    """CONVEYOR CHAOS - belts everywhere (they all run right), lifts and live floors"""
    L = Level(256)
    w3_works(L, (10, 44, 92, 140, 178, 220))
    # A 0-30 loading bay
    L.ground(0, 32)
    L.ent(2, 7, E_START)
    moon(L, 14, 7)
    L.deco(6, 8, 'bush'); L.deco(20, 8, 'lantern'); L.deco(26, 8, 'rockS')
    L.stars(16, 6, 4, [1, 0, 0, 1])
    for xx in (21, 23): L.put(xx, 10, 'bstar')
    L.logs(24, 8, 6)                       # first belt: a free ride
    L.ent(30, 8, E_ANT)
    # B 32-70 the belt staircase over the live floor
    L.ground(32, 72)
    for xx in range(35, 68): L.put(xx, 8, 'thorn')
    L.logs(34, 7, 6); L.logs(42, 6, 6); L.logs(50, 5, 6); L.logs(58, 6, 6); L.logs(64, 7, 5)
    L.stars(35, 6, 5); L.stars(43, 5, 5); L.stars(51, 4, 5); L.stars(59, 5, 5)
    L.ent(47, 2, E_MAG); L.ent(61, 2, E_MAG)
    # C 72-104 the stamping line: crushers over a belt
    L.ground(72, 106)
    L.rock(74, 102, 0, 3, top=False)
    for xx in range(74, 102): L.put(xx, 4, 'leafB')
    L.logs(76, 8, 24)
    for xx in (80, 87, 94): L.ent(xx, 5, E_DROP)
    L.stars(83, 7, 2); L.stars(90, 7, 2); L.stars(97, 7, 2)
    L.put(104, 8, 'check')
    # D 106-140 the slag ponds and the lifts
    pond(L, 106, 136)
    L.rock(114, 116, 6, 11)
    L.ent(107, 7, E_PLATH, 4)
    L.ent(117, 8, E_PLATV, 4)
    L.logs(121, 4, 5); L.stars(121, 3, 5)
    L.ent(127, 7, E_PLATH, 5)
    L.stars(108, 5, 3); L.stars(128, 5, 3)
    L.ent(112, 2, E_MAG); L.ent(130, 2, E_MAG)
    L.ground(136, 176)
    # E 136-176 the sorting hall: belts on two floors, a bonus, the scrap heap
    L.logs(140, 8, 8); L.logs(152, 8, 8)
    L.logs(144, 4, 10); L.stars(145, 3, 8)
    bonus(L, 160, 5)
    L.earth(164, 174, 6, 8)
    for xx in range(164, 174): L.put(xx, 6, 'grass')
    L.put(164, 6, 'slopeR'); L.put(173, 6, 'slopeL')
    for xx, yy in [(166, 8), (169, 10), (172, 9)]: L.put(xx, yy, 'bstar')
    pocket(L, 167, 170, 10, 11)
    L.ent(149, 8, E_ANT); L.ent(158, 8, E_TOAD); L.ent(170, 5, E_WORM)
    # F 176-214 the tower lift
    L.ground(176, 214)
    L.rock(186, 188, 3, 9)
    L.logs(179, 7, 3); L.logs(182, 5, 3); L.logs(179, 3, 3)
    L.stars(179, 6, 3); L.stars(182, 4, 3); L.stars(179, 2, 3)
    L.ent(190, 6, E_PLATV, 4)
    L.logs(194, 2, 6); L.stars(194, 1, 6)
    L.ent(203, 8, E_ANT); L.ent(198, 3, E_MAG)
    L.put(210, 8, 'check')
    # G 214-256 the shipping belt: ride it to the exit
    L.ground(214, 256)
    for xx in list(range(222, 226)) + list(range(234, 238)): L.put(xx, 8, 'thorn')
    L.logs(218, 8, 3); L.logs(226, 8, 8); L.logs(238, 8, 6)
    L.put(220, 8, 'shroom'); L.put(232, 8, 'shroom')
    L.logs(222, 4, 4); L.stars(222, 3, 4); L.logs(234, 4, 4); L.stars(234, 3, 4)
    L.ent(229, 8, E_TOAD); L.ent(244, 8, E_WORM)
    exitgate(L, 250)
    moon(L, 252, 7)
    return L


def level_3_3():
    """THE FURNACE - slag, crushers and the hot scrap you dig through"""
    L = Level(256)
    w3_works(L, (8, 60, 118, 166, 214))
    # A 0-30 the boiler door
    L.ground(0, 32)
    L.ent(2, 7, E_START)
    moon(L, 12, 7)
    L.deco(5, 8, 'rockS'); L.deco(18, 8, 'lantern'); L.deco(26, 8, 'bush')
    L.stars(14, 6, 4, [1, 0, 0, 1])
    for xx in (19, 21, 23): L.put(xx, 10, 'bstar')
    L.ent(27, 8, E_ANT)
    # B 32-66 the slag channel: stepping blocks and a raft
    pond(L, 32, 64)
    for x0 in (36, 44, 56):
        L.rock(x0, x0 + 2, 8, 11)
        L.stars(x0, 6, 2)
    L.ent(48, 7, E_PLATH, 4)
    L.ent(40, 3, E_MAG); L.ent(52, 3, E_MAG)
    L.ground(64, 102)
    # C 64-100 the hammer room
    L.rock(68, 96, 0, 3, top=False)
    for xx in range(68, 96): L.put(xx, 4, 'leafB')
    for xx in (71, 76, 81, 86, 91): L.ent(xx, 5, E_DROP)
    L.stars(73, 7, 2); L.stars(78, 7, 2); L.stars(83, 7, 2); L.stars(88, 7, 2)
    L.ent(94, 8, E_WORM)
    L.put(99, 8, 'check')
    # D 102-140 the scrap mountain: dig the whole way, or take the high belts
    L.ground(102, 142)
    L.rock(106, 136, 0, 2, top=False)
    L.earth(106, 136, 5, 11)
    for xx in range(106, 136): L.put(xx, 5, 'grass')
    L.put(106, 5, 'slopeR'); L.put(135, 5, 'slopeL')
    L.logs(103, 7, 2)
    L.logs(110, 3, 6); L.logs(122, 3, 6); L.stars(111, 2, 4); L.stars(123, 2, 4)
    for xx, yy in [(108, 7), (111, 10), (114, 8), (117, 11), (120, 6), (124, 9), (128, 11), (132, 7)]:
        L.put(xx, yy, 'bstar')
    pocket(L, 125, 128, 7, 8)
    L.ent(114, 4, E_WORM); L.ent(126, 4, E_ANT); L.ent(133, 4, E_WORM)
    L.ent(139, 8, E_TOAD)
    # E 142-178 the ladle line: rafts over molten slag
    pond(L, 142, 176)
    L.ent(143, 7, E_PLATH, 5)
    L.ground(154, 157)
    L.ent(158, 6, E_PLATH, 5)
    L.ent(167, 7, E_PLATH, 5)
    L.stars(145, 5, 3); L.stars(160, 4, 3); L.stars(169, 5, 3)
    L.logs(162, 2, 3); L.stars(162, 1, 3)
    L.ent(150, 2, E_MAG); L.ent(172, 2, E_MAG)
    L.ground(176, 214)
    # F 176-212 the cooling towers
    L.put(180, 8, 'shroom'); L.put(194, 8, 'shroom')
    L.rock(186, 188, 3, 8)
    L.logs(182, 4, 3); L.stars(182, 3, 3)
    L.ent(190, 6, E_PLATV, 4)
    L.logs(196, 3, 5); L.stars(196, 2, 5)
    bonus(L, 204, 5)
    L.ent(200, 8, E_ANT)
    L.put(210, 8, 'check')
    # G 214-256 the last furnace
    L.ground(214, 256)
    for xx in list(range(218, 223)) + list(range(230, 235)): L.put(xx, 8, 'thorn')
    L.logs(216, 8, 2); L.logs(223, 8, 7); L.logs(235, 8, 5)
    L.logs(219, 4, 4); L.logs(231, 4, 4); L.stars(219, 3, 4); L.stars(231, 3, 4)
    L.put(228, 8, 'shroom')
    L.ent(238, 8, E_TOAD); L.ent(244, 8, E_WORM); L.ent(226, 3, E_MAG)
    exitgate(L, 250)
    moon(L, 252, 7)
    return L


# ================================================================= WORLD 4
def level_4_2():
    """CLOUD NINE - drifting clouds, updrafts and a long wind tunnel"""
    L = Level(256)
    w4_sky(L)
    moon(L, 18, 1)
    # A 0-24 the launch isle
    L.ground(0, 24, 9)
    L.ent(2, 7, E_START)
    L.deco(5, 8, 'flower'); L.deco(10, 8, 'bush'); L.deco(15, 8, 'lantern')
    for xx in (16, 18): L.put(xx, 10, 'bstar')
    L.stars(8, 6, 4, [1, 0, 0, 1])
    L.ent(20, 8, E_ANT)
    # B 24-64 the cloud ferry
    L.ent(25, 7, E_PLATH, 6)
    island(L, 34, 38, 8)
    L.ent(39, 6, E_PLATH, 6)
    island(L, 48, 52, 7)
    L.ent(53, 7, E_PLATH, 6)
    L.stars(27, 5, 3); L.stars(41, 4, 3); L.stars(55, 5, 3)
    L.stars(35, 6, 3); L.stars(49, 5, 3)
    L.ent(44, 2, E_MAG); L.ent(58, 3, E_MAG)
    # C 62-96 the big cloud with a burrow and the wind chimneys
    L.ground(62, 98, 9)
    for xx in (68, 69): wind(L, xx, 2)
    L.logs(66, 1, 5); L.stars(66, 0, 5)
    bonus(L, 76, 5)
    L.fill(82, 86, 10, 11, 'soil'); L.put(82, 10, 'bstar'); L.put(85, 11, 'bstar')
    pocket(L, 83, 85, 10, 11, oneup=True)
    L.ent(80, 8, E_WORM); L.ent(90, 8, E_TOAD)
    L.deco(72, 8, 'flower'); L.deco(88, 8, 'bush')
    L.put(95, 8, 'check')
    # D 98-140 the updraft ladder
    for xx, y0 in [(100, 3), (101, 3), (112, 2), (113, 2), (124, 3), (125, 3)]: wind(L, xx, y0)
    island(L, 104, 109, 6); island(L, 116, 121, 5); island(L, 128, 133, 6)
    L.stars(105, 4, 4); L.stars(117, 3, 4); L.stars(129, 4, 4)
    L.stars(100, 1, 2); L.stars(112, 0, 2); L.stars(124, 1, 2)
    L.ent(107, 5, E_ANT); L.ent(119, 4, E_ANT)
    L.ent(110, 1, E_DROP); L.ent(122, 1, E_DROP)
    for xx in range(98, 140):
        if L.get(xx, 11) in ('sky', 'sky_tw', 'sky_tw2'): pass
    L.ground(138, 146, 9)
    # E 146-186 the thunderheads: drifting clouds in two layers
    L.ent(146, 7, E_PLATH, 6)
    L.ent(150, 4, E_PLATH, 6)
    island(L, 158, 163, 8)
    L.ent(164, 6, E_PLATH, 7)
    island(L, 176, 182, 8)
    L.stars(152, 2, 4); L.stars(166, 4, 3); L.stars(177, 6, 4)
    L.ent(155, 1, E_MAG); L.ent(171, 2, E_MAG)
    L.put(160, 7, 'thorn'); L.put(178, 7, 'thorn')
    L.ground(182, 214, 9)
    # F 182-214 the giant beanstalk
    for d in range(1, 9): L.put(196, d, 'trunk')
    L.put(196, 8, 'trunkB')
    L.logs(188, 7, 3); L.logs(192, 5, 3); L.logs(188, 3, 3); L.logs(193, 1, 3)
    L.stars(188, 6, 3); L.stars(192, 4, 3); L.stars(188, 2, 3); L.stars(193, 0, 3)
    L.ent(199, 6, E_PLATV, 4)
    L.logs(203, 2, 5); L.stars(203, 1, 5)
    L.ent(206, 8, E_WORM); L.ent(186, 8, E_ANT)
    L.put(211, 8, 'check')
    # G 214-256 over the edge of the world
    island(L, 218, 224, 8); island(L, 230, 236, 7)
    wind(L, 215, 4); wind(L, 226, 3); wind(L, 227, 3); wind(L, 238, 4)
    L.ground(240, 256, 9)
    L.stars(219, 6, 4); L.stars(231, 5, 4); L.stars(226, 1, 2)
    L.ent(221, 7, E_ANT); L.ent(233, 2, E_MAG)
    exitgate(L, 250)
    L.deco(245, 8, 'flower'); L.deco(253, 8, 'bush')
    return L


def level_4_3():
    """STORM FRONT - thunder spikes, bouncy clouds and gusts"""
    L = Level(256)
    w4_sky(L)
    # A 0-24 the last calm isle
    L.ground(0, 26, 9)
    L.ent(2, 7, E_START)
    L.deco(5, 8, 'tuft'); L.deco(11, 8, 'flower'); L.deco(16, 8, 'lantern')
    for xx in (17, 19): L.put(xx, 10, 'bstar')
    L.stars(7, 6, 4, [1, 0, 0, 1])
    L.ent(22, 8, E_ANT)
    # B 26-66 bounce isles: springs over the void
    island(L, 30, 34, 9); island(L, 40, 44, 8); island(L, 50, 54, 9); island(L, 60, 66, 8)
    L.put(31, 8, 'shroom'); L.put(51, 8, 'shroom')
    L.logs(34, 3, 4); L.stars(34, 2, 4); L.logs(54, 3, 4); L.stars(54, 2, 4)
    wind(L, 37, 4); wind(L, 47, 4); wind(L, 57, 4)
    L.stars(41, 6, 3); L.stars(61, 6, 4)
    L.put(42, 7, 'thorn')
    L.ent(46, 2, E_MAG)
    # C 66-100 the lightning isle: spiked rocks and hail
    L.ground(66, 100, 9)
    for xx in list(range(72, 75)) + list(range(82, 85)) + list(range(92, 94)): L.put(xx, 8, 'thorn')
    L.put(70, 8, 'shroom'); L.put(80, 8, 'shroom'); L.put(90, 8, 'shroom')
    L.logs(72, 4, 3); L.logs(82, 4, 3); L.stars(72, 3, 3); L.stars(82, 3, 3)
    for xx in (77, 87): L.ent(xx, 1, E_DROP)
    L.ent(96, 8, E_TOAD)
    L.put(98, 8, 'check')
    # D 100-140 the gale: clouds drifting fast past gust columns
    L.ent(101, 7, E_PLATH, 6)
    island(L, 110, 114, 6)
    for xx in (115, 116): wind(L, xx, 2)
    L.ent(117, 5, E_PLATH, 6)
    island(L, 126, 130, 7)
    L.ent(131, 7, E_PLATH, 5)
    L.stars(103, 5, 3); L.stars(119, 3, 3); L.stars(133, 5, 3); L.stars(115, 0, 2)
    L.stars(111, 4, 3); L.stars(127, 5, 3)
    L.ent(108, 2, E_MAG); L.ent(124, 1, E_MAG)
    L.ground(140, 176, 9)
    # E 140-176 the storm cellar: dig under the thunder field
    for xx in range(146, 168): L.put(xx, 8, 'thorn')
    L.logs(148, 5, 3); L.logs(156, 4, 3); L.logs(163, 5, 3)
    L.stars(148, 4, 3); L.stars(156, 3, 3); L.stars(163, 4, 3)
    L.deco(143, 8, 'lantern')
    for xx in range(147, 167, 2): L.put(xx, 10, 'bstar')
    pocket(L, 155, 158, 10, 11)
    L.ent(152, 2, E_MAG); L.ent(171, 8, E_WORM)
    bonus(L, 172, 5)
    # F 176-216 the twin beanstalks in the rain
    L.ground(176, 216, 9)
    for xx in (182, 198):
        for d in range(1, 9): L.put(xx, d, 'trunk')
        L.put(xx, 8, 'trunkB')
    L.logs(183, 7, 2); L.logs(185, 5, 2); L.logs(183, 3, 2); L.logs(186, 1, 3)
    L.stars(183, 6, 2); L.stars(185, 4, 2); L.stars(183, 2, 2); L.stars(186, 0, 3)
    L.ent(190, 6, E_PLATV, 4)
    L.logs(193, 2, 4); L.stars(193, 1, 4)
    L.ent(194, 8, E_ANT); L.ent(203, 8, E_TOAD); L.ent(200, 1, E_DROP)
    L.put(212, 8, 'check')
    # G 216-256 into the eye of the storm
    island(L, 220, 225, 8); island(L, 231, 236, 7)
    wind(L, 217, 4); wind(L, 227, 3); wind(L, 228, 3); wind(L, 238, 4)
    L.put(222, 7, 'thorn'); L.put(234, 6, 'shroom')
    L.ground(240, 256, 9)
    L.stars(220, 6, 3); L.stars(231, 3, 3); L.stars(227, 1, 2)
    L.ent(224, 7, E_ANT); L.ent(236, 2, E_MAG); L.ent(244, 8, E_WORM)
    exitgate(L, 250)
    L.deco(253, 8, 'bush')
    return L


# ================================================================= WORLD 5
def level_5_2():
    """ASHFALL RIDGE - rockfalls, ash drifts to burrow through, geysers"""
    L = Level(256)
    w5_peaks(L)
    moon(L, 16, 3)
    # A 0-30 the ridge path
    L.ground(0, 32)
    L.ent(2, 7, E_START)
    L.deco(5, 8, 'rockS'); L.deco(10, 8, 'tuft'); L.deco(22, 8, 'lantern')
    L.plateau(12, 18)
    L.stars(19, 6, 3)
    for xx in (23, 25, 27): L.put(xx, 10, 'bstar')
    L.ent(29, 8, E_ANT)
    # B 32-70 the first ash drift: under or over
    L.ground(32, 72)
    L.rock(38, 64, 0, 2, top=False)
    L.earth(38, 64, 4, 8)
    for xx in range(38, 64): L.put(xx, 4, 'grass')
    L.put(38, 4, 'slopeR'); L.put(63, 4, 'slopeL')
    L.logs(34, 7, 2); L.logs(35, 5, 2)
    for xx, yy in [(40, 7), (43, 10), (46, 6), (49, 9), (52, 11), (55, 7), (58, 10), (61, 8)]: L.put(xx, yy, 'bstar')
    pocket(L, 50, 53, 6, 7)
    L.ent(44, 3, E_WORM); L.ent(56, 3, E_ANT)
    L.ent(67, 8, E_TOAD)
    # C 72-104 the rockfall gully
    L.ground(72, 106)
    L.rock(74, 102, 0, 3, top=False)
    for xx in range(74, 102): L.put(xx, 4, 'leafB')
    for xx in (77, 82, 87, 92, 97): L.ent(xx, 5, E_DROP)
    L.stars(79, 7, 2); L.stars(84, 7, 2); L.stars(89, 7, 2); L.stars(94, 7, 2)
    L.put(104, 8, 'check')
    # D 106-140 the geyser field: springs and vents over hot pools
    L.ground(106, 142)
    for x0 in (110, 120, 130):
        lava(L, x0, x0 + 4)
        wind(L, x0 + 1, 3); wind(L, x0 + 2, 3)
        L.stars(x0 + 1, 1, 2)
    L.put(108, 8, 'shroom'); L.put(118, 8, 'shroom'); L.put(128, 8, 'shroom')
    L.logs(114, 3, 4); L.logs(124, 3, 4); L.stars(114, 2, 4); L.stars(124, 2, 4)
    L.ent(116, 8, E_ANT); L.ent(126, 8, E_TOAD)
    L.ent(137, 8, E_WORM)
    # E 142-178 the cinder cones: drop-rocks above a dig field
    L.ground(142, 180)
    L.plateau(146, 152); L.plateau(158, 166); L.plateau(170, 176)
    for xx, yy in [(148, 10), (153, 11), (156, 10), (161, 11), (167, 10), (172, 11)]: L.put(xx, yy, 'bstar')
    pocket(L, 162, 165, 10, 11)
    L.stars(147, 6, 4); L.stars(159, 6, 6); L.stars(171, 6, 4)
    L.ent(154, 1, E_MAG); L.ent(168, 2, E_MAG)
    L.ent(156, 8, E_TOAD)
    bonus(L, 162, 4)
    # F 180-214 the scree climb
    L.ground(180, 216)
    L.rock(190, 192, 3, 8)
    L.logs(182, 7, 2); L.logs(185, 5, 2); L.logs(182, 3, 2); L.logs(186, 1, 3)
    L.stars(182, 6, 2); L.stars(185, 4, 2); L.stars(182, 2, 2); L.stars(186, 0, 3)
    L.ent(194, 6, E_PLATV, 4)
    L.logs(198, 2, 5); L.stars(198, 1, 5)
    L.ent(205, 8, E_ANT)
    L.put(212, 8, 'check')
    # G 216-256 the ash flats to the crater rim
    L.ground(216, 256)
    L.rock(222, 240, 0, 2, top=False)
    L.earth(222, 240, 5, 8)
    for xx in range(222, 240): L.put(xx, 5, 'grass')
    L.put(222, 5, 'slopeR'); L.put(239, 5, 'slopeL')
    L.logs(219, 7, 2)
    for xx, yy in [(224, 7), (228, 10), (232, 8), (236, 11)]: L.put(xx, yy, 'bstar')
    L.stars(225, 3, 6)
    L.ent(230, 4, E_WORM); L.ent(244, 8, E_TOAD)
    exitgate(L, 250)
    moon(L, 252, 7)
    return L


def level_5_3():
    """THE CALDERA - the lava lake, vents and the long climb to the dragon"""
    L = Level(256)
    w5_peaks(L)
    # A 0-28 the crater rim
    L.ground(0, 30)
    L.ent(2, 7, E_START)
    moon(L, 10, 4)
    L.deco(6, 8, 'rockS'); L.deco(14, 8, 'lantern'); L.deco(21, 8, 'tuft')
    for xx in (15, 17, 19): L.put(xx, 10, 'bstar')
    L.stars(7, 6, 4, [1, 0, 0, 1])
    L.ent(25, 8, E_ANT)
    # B 30-66 the lava lake: vents lift you between the rafts
    lava(L, 30, 64)
    L.ent(31, 7, E_PLATH, 4)
    for xx in (39, 40): wind(L, xx, 3)
    L.logs(41, 4, 4); L.stars(41, 3, 4)
    L.ent(46, 7, E_PLATH, 4)
    for xx in (53, 54): wind(L, xx, 3)
    L.logs(55, 4, 4); L.stars(55, 3, 4)
    L.ent(59, 7, E_PLATH, 2)
    L.stars(33, 5, 3); L.stars(48, 5, 3); L.stars(39, 1, 2); L.stars(53, 1, 2)
    L.ent(44, 9, E_WORM); L.ent(51, 2, E_MAG)
    L.ground(64, 100)
    # C 64-100 the obsidian halls: crushers of falling rock
    L.rock(68, 96, 0, 3, top=False)
    for xx in range(68, 96): L.put(xx, 4, 'leafB')
    for xx in (72, 78, 84, 90): L.ent(xx, 5, E_DROP)
    L.stars(74, 7, 2); L.stars(80, 7, 2); L.stars(86, 7, 2); L.stars(92, 7, 2)
    L.ent(95, 8, E_TOAD)
    L.put(98, 8, 'check')
    # D 100-140 the magma falls: islands of rock in the lava
    lava(L, 100, 138)
    for x0, top in [(104, 8), (112, 7), (121, 8), (130, 7)]:
        L.rock(x0, x0 + 3, top, 11)
        L.stars(x0, top - 2, 3)
    for xx in (109, 118, 127): wind(L, xx, 3)
    L.stars(108, 1, 3); L.stars(126, 1, 3)
    L.ent(110, 9, E_WORM); L.ent(126, 9, E_WORM)
    L.ent(116, 2, E_MAG); L.ent(134, 2, E_MAG)
    L.ground(138, 178)
    # E 138-178 the last ash hill: through it is the 1-UP, over it the bonus
    L.rock(144, 172, 0, 2, top=False)
    L.earth(144, 172, 4, 8)
    for xx in range(144, 172): L.put(xx, 4, 'grass')
    L.put(144, 4, 'slopeR'); L.put(171, 4, 'slopeL')
    L.logs(140, 7, 2); L.logs(141, 5, 2)
    for xx, yy in [(146, 7), (149, 10), (153, 6), (156, 9), (160, 11), (164, 7), (168, 10)]: L.put(xx, yy, 'bstar')
    pocket(L, 157, 160, 6, 7)
    L.ent(150, 3, E_WORM); L.ent(160, 3, E_ANT); L.ent(166, 3, E_WORM)
    L.ent(175, 8, E_TOAD)
    # F 178-216 the vent chimney
    L.ground(178, 182)
    lava(L, 182, 212)
    for xx in (184, 185, 194, 195, 204, 205): wind(L, xx, 2)
    island(L, 188, 192, 5); island(L, 198, 202, 4)
    L.logs(208, 5, 3)
    L.stars(189, 3, 3); L.stars(199, 2, 3); L.stars(184, 0, 2); L.stars(204, 0, 2)
    L.ent(190, 4, E_ANT); L.ent(196, 1, E_MAG)
    L.ground(212, 256)
    L.put(214, 8, 'check')
    # G 216-256 the dragon's door
    for xx in list(range(220, 224)) + list(range(232, 236)): L.put(xx, 8, 'thorn')
    L.put(218, 8, 'shroom'); L.put(230, 8, 'shroom')
    L.logs(220, 4, 4); L.logs(232, 4, 4); L.stars(220, 3, 4); L.stars(232, 3, 4)
    lava(L, 238, 242)
    L.ent(226, 8, E_TOAD); L.ent(244, 8, E_ANT); L.ent(236, 2, E_MAG)
    L.stars(238, 6, 4, [1, 0, 0, 1])
    exitgate(L, 250)
    moon(L, 252, 7)
    return L
