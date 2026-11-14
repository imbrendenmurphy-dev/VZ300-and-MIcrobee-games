# Level 1-2 (boss arena: KING CANE) and Level 2-1 (CRYSTAL CAVERNS)
from lvlkit import *

def level_1_2():
    L = Level(16)
    # dusk sky dressing
    for x, y in [(2, 1), (6, 3), (9, 0), (13, 2), (4, 4), (11, 5)]: L.put(x, y, 'sky_tw')
    L.put(7, 1, 'cloudL'); L.put(8, 1, 'cloudM'); L.put(9, 1, 'cloudR')
    L.put(12, 0, 'moonTL'); L.put(13, 0, 'moonTR'); L.put(12, 1, 'moonBL'); L.put(13, 1, 'moonBR')
    for x in range(1, 15):
        L.put(x, 7, 'hillM' if x % 4 else 'hillL')
        L.put(x, 8, 'hillB')
    L.ground(0, 16)
    L.rock(0, 1, 0, 8, top=False)
    L.rock(15, 16, 0, 8, top=False)
    L.logs(3, 5, 2); L.logs(11, 5, 2)
    L.put(2, 8, 'tuft'); L.put(13, 8, 'flower'); L.put(7, 8, 'lantern')
    L.ent(2, 7, E_START)
    L.ent(9, 6, E_BOSS)
    return L

def level_2_1():
    W = 256
    L = Level(W)
    # ceiling everywhere (row 0 rock, row 1 rubble drips) and distant back wall
    for x in range(W):
        L.put(x, 0, 'rock')
        L.put(x, 1, ('cloudL', 'cloudM', 'cloudR')[x % 3])
        if (x * 7) % 13 == 0: L.put(x, 3 + x % 3, 'sky_tw')
        if (x * 5) % 23 == 0: L.put(x, 2 + x % 4, 'sky_tw2')
    x = 0
    while x < W - 6:
        w = 3 + (x * 3) % 3
        L.put(x, 6, 'hillL')
        for i in range(1, w + 1): L.put(x + i, 6, 'hillM')
        L.put(x + w + 1, 6, 'hillR')
        for i in range(w + 2):
            L.put(x + i, 7, 'hillBT'); L.put(x + i, 8, 'hillB')
        x += w + 4

    # low cave ceilings (rows 2-3) over the sections without high platforms
    for x0, x1 in [(0, 34), (60, 64), (86, 96), (206, 228), (236, 256)]:
        for xx in range(x0, x1):
            L.put(xx, 2, 'leaf'); L.put(xx, 3, 'leaf'); L.put(xx, 4, 'leafB')
    # A 0-30 entry cavern
    L.ground(0, 32)
    L.ent(2, 7, E_START)
    L.put(10, 7, 'moonTL'); L.put(11, 7, 'moonTR'); L.put(10, 8, 'moonBL'); L.put(11, 8, 'moonBR')
    L.deco(6, 8, 'flower'); L.deco(14, 8, 'bush'); L.deco(19, 8, 'tuft'); L.deco(25, 8, 'flower')
    L.stars(15, 6, 4, [1, 0, 0, 1])
    L.plateau(13, 19)
    L.deco(21, 8, 'lantern')
    for xx in (22, 24, 26): L.put(xx, 10, 'bstar')
    L.ent(28, 8, E_ANT)
    L.logs(17, 6, 3); L.stars(17, 5, 3)

    # B 32-62 low passage with stalactites
    L.ground(32, 62)
    L.rock(34, 60, 0, 3, top=False)
    for xx in range(34, 60): L.put(xx, 4, 'leafB')
    for xx in (39, 46, 53): L.ent(xx, 5, E_DROP)
    L.stars(36, 7, 3); L.stars(43, 7, 3); L.stars(50, 7, 3)
    L.deco(41, 8, 'rockS'); L.deco(48, 8, 'flower'); L.deco(57, 8, 'bush')
    L.ent(57, 8, E_ANT)

    # C 62-90 the earth wall: dig through it
    L.ground(62, 92)
    L.rock(64, 86, 0, 2, top=False)
    L.earth(64, 86, 3, 11)
    for xx in range(64, 86): L.put(xx, 3, 'grass')
    L.deco(62, 8, 'lantern')
    for xx, yy in [(66, 9), (68, 6), (71, 10), (74, 5), (76, 8), (79, 11), (82, 7), (84, 9)]:
        L.put(xx, yy, 'bstar')
    L.fill(73, 76, 9, 10, 'soilD')       # a little hollow with a 1-up
    L.ent(74, 9, E_ONEUP)
    L.put(89, 8, 'check')
    L.ent(88, 8, E_WORM)

    # D 92-130 the underground river
    L.ground(92, 96)
    for xx in range(96, 126):
        L.put(xx, 9, 'sky'); L.put(xx, 10, 'watert'); L.put(xx, 11, 'water')
    L.ent(97, 7, E_PLATH, 7)
    L.ent(107, 6, E_PLATH, 6)
    L.ent(116, 7, E_PLATH, 7)
    L.stars(99, 5, 3); L.stars(109, 4, 3); L.stars(118, 5, 3)
    L.logs(105, 3, 3); L.stars(105, 2, 3)
    L.ent(103, 4, E_MAG); L.ent(120, 3, E_MAG)
    L.ground(126, 132)

    # E 132-170 crystal spike field and bouncy crystals
    L.ground(132, 170)
    for xx in list(range(136, 141)) + list(range(148, 154)) + list(range(160, 165)):
        L.put(xx, 8, 'thorn')
    L.put(134, 8, 'shroom'); L.put(146, 8, 'shroom'); L.put(158, 8, 'shroom')
    L.logs(137, 4, 3); L.logs(149, 3, 4); L.logs(161, 4, 3)
    L.stars(137, 3, 3); L.stars(149, 2, 4); L.stars(161, 3, 3)
    L.ent(143, 8, E_TOAD); L.ent(156, 8, E_TOAD)
    L.ent(167, 8, E_ANT)
    L.put(144, 6, 'bonus'); L.put(143, 6, 'termite'); L.put(145, 6, 'termite')
    L.ent(144, 5, E_GLOW, 1)

    # F 170-206 the tall shaft
    L.ground(170, 206)
    L.rock(178, 180, 3, 9)
    L.logs(172, 7, 2); L.logs(175, 5, 2); L.logs(172, 3, 2)
    L.stars(172, 6, 2); L.stars(175, 4, 2); L.stars(172, 2, 2)
    L.ent(182, 6, E_PLATV, 4)
    L.logs(186, 2, 4); L.stars(186, 1, 4, t='star')
    L.ent(190, 4, E_MAG)
    L.put(193, 7, 'moonTL'); L.put(194, 7, 'moonTR'); L.put(193, 8, 'moonBL'); L.put(194, 8, 'moonBR')
    L.ent(198, 8, E_WORM)
    L.put(203, 8, 'check')
    for xx in (185, 189, 197): L.put(xx, 10, 'bstar')

    # G 206-256 the run to the mine exit
    L.ground(206, 230)
    L.ground(234, 256)
    for xx in range(230, 234):
        L.put(xx, 9, 'sky'); L.put(xx, 10, 'watert'); L.put(xx, 11, 'water')
    L.stars(210, 7, 10, [1, 0, 1, 0, 1, 0, 1, 0, 1, 0])
    L.stars(229, 5, 6, [2, 1, 0, 0, 1, 2])
    L.ent(214, 8, E_WORM); L.ent(222, 8, E_WORM); L.ent(240, 8, E_WORM)
    L.ent(218, 8, E_ANT); L.ent(244, 8, E_ANT); L.ent(236, 4, E_MAG)
    L.deco(212, 8, 'flower'); L.deco(226, 8, 'bush'); L.deco(238, 8, 'rockS'); L.deco(246, 8, 'flower')
    L.put(250, 7, 'exitT'); L.put(250, 8, 'exitB')
    L.put(253, 7, 'moonTL'); L.put(254, 7, 'moonTR'); L.put(253, 8, 'moonBL'); L.put(254, 8, 'moonBR')
    return L

def level_2_2():
    """THE GEODE GOLEM - cavern boss arena"""
    L = Level(16)
    for x in range(16):
        L.put(x, 0, 'rock'); L.put(x, 1, ('cloudL', 'cloudM', 'cloudR')[x % 3])
    for x in range(1, 15):
        L.put(x, 6, 'hillM' if x % 5 else 'hillL'); L.put(x, 7, 'hillBT'); L.put(x, 8, 'hillB')
    for x, y in [(3, 3), (7, 2), (12, 4), (5, 5), (10, 3)]: L.put(x, y, 'sky_tw')
    L.ground(0, 16)
    L.rock(0, 1, 0, 8, top=False)
    L.rock(15, 16, 0, 8, top=False)
    L.logs(2, 5, 2); L.logs(12, 5, 2)
    L.put(4, 7, 'moonTL'); L.put(5, 7, 'moonTR'); L.put(4, 8, 'moonBL'); L.put(5, 8, 'moonBR')
    L.put(11, 8, 'flower'); L.put(8, 8, 'lantern')
    L.ent(2, 7, E_START)
    L.ent(9, 6, E_BOSS)
    return L

def level_3_1():
    """CLOCKWORK WORKS - the factory"""
    W = 256
    L = Level(W)
    for x in range(W):
        L.put(x, 0, 'rock')
        L.put(x, 1, ('cloudL', 'cloudM', 'cloudM', 'cloudR')[x % 4] if (x // 8) % 3 else 'leafT')
        if (x * 7) % 19 == 0: L.put(x, 3 + x % 3, 'sky_tw')
        if (x * 5) % 31 == 0: L.put(x, 2 + x % 4, 'sky_tw2')
    # distant girders
    x = 0
    while x < W - 6:
        w = 4 + (x * 3) % 3
        L.put(x, 6, 'hillL')
        for i in range(1, w + 1): L.put(x + i, 6, 'hillM')
        L.put(x + w + 1, 6, 'hillR')
        for i in range(w + 2):
            L.put(x + i, 7, 'hillBT'); L.put(x + i, 8, 'hillB')
        x += w + 4
    for xx in (8, 30, 66, 120, 150, 190, 230):
        for d in range(2, 9): L.put(xx, d, 'trunk')
        L.put(xx, 8, 'trunkB')

    # A 0-36 the intake hall
    L.ground(0, 36)
    L.ent(2, 7, E_START)
    L.put(12, 7, 'moonTL'); L.put(13, 7, 'moonTR'); L.put(12, 8, 'moonBL'); L.put(13, 8, 'moonBR')
    L.deco(5, 8, 'bush'); L.deco(18, 8, 'flower'); L.deco(25, 8, 'rockS'); L.deco(33, 8, 'tuft')
    L.plateau(31, 36)
    L.stars(15, 6, 4, [1, 0, 0, 1])
    L.deco(20, 8, 'lantern')
    for xx in (21, 23, 25): L.put(xx, 10, 'bstar')
    L.put(23, 11, 'bstar')
    L.ent(28, 8, E_ANT)

    # B 36-72 conveyors over the live floor
    L.ground(36, 72)
    for xx in range(40, 68): L.put(xx, 8, 'thorn')
    L.logs(39, 7, 8); L.logs(50, 6, 7); L.logs(60, 7, 8)
    L.stars(41, 6, 5); L.stars(52, 5, 4); L.stars(62, 6, 5)
    L.logs(46, 3, 4); L.stars(46, 2, 4)
    L.ent(47, 4, E_MAG); L.ent(63, 3, E_MAG)
    L.put(38, 8, 'shroom')

    # C 72-104 the crusher corridor
    L.ground(72, 106)
    L.rock(74, 102, 0, 3, top=False)
    for xx in range(74, 102): L.put(xx, 4, 'leafB')
    for xx in (78, 84, 90, 96): L.ent(xx, 5, E_DROP)
    L.stars(80, 7, 2); L.stars(86, 7, 2); L.stars(92, 7, 2); L.stars(98, 7, 2)
    L.put(104, 8, 'check')
    L.ent(101, 8, E_WORM)

    # D 106-140 slag pits
    for xx in range(106, 136):
        L.put(xx, 9, 'sky'); L.put(xx, 10, 'watert'); L.put(xx, 11, 'water')
    for xx in (115, 116, 126, 127):
        L.put(xx, 9, 'rocktop'); L.put(xx, 10, 'rock'); L.put(xx, 11, 'rock')
    L.ent(107, 7, E_PLATH, 6)
    L.ent(118, 6, E_PLATH, 6)
    L.ent(129, 7, E_PLATH, 5)
    L.stars(108, 5, 3); L.stars(119, 4, 3); L.stars(130, 5, 3)
    L.ent(112, 3, E_MAG); L.ent(124, 3, E_MAG)
    L.ground(136, 140)

    # E 140-176 the scrap mountain (dig it!)
    L.ground(140, 176)
    L.earth(146, 170, 5, 11)
    for xx in range(146, 170): L.put(xx, 5, 'grass')
    for xx, yy in [(148, 7), (151, 10), (154, 6), (157, 9), (160, 11), (163, 7), (166, 10)]:
        L.put(xx, yy, 'bstar')
    L.fill(156, 159, 9, 10, 'soilD'); L.ent(157, 9, E_ONEUP)
    L.ent(152, 4, E_WORM); L.ent(161, 4, E_WORM)
    L.ent(173, 8, E_TOAD)
    L.stars(148, 3, 3); L.stars(164, 3, 3)
    L.deco(143, 8, 'lantern')

    # F 176-212 the lift shaft
    L.ground(176, 212)
    L.rock(184, 186, 3, 9)
    L.logs(177, 7, 3); L.logs(180, 5, 3); L.logs(177, 3, 3)
    L.stars(177, 6, 3); L.stars(180, 4, 3); L.stars(177, 2, 3)
    L.ent(188, 6, E_PLATV, 4)
    L.logs(192, 2, 5); L.stars(192, 1, 5)
    L.ent(198, 3, E_MAG)
    L.ent(203, 8, E_ANT)
    L.put(208, 8, 'check')

    # G 212-256 the final assembly line
    L.ground(212, 256)
    for xx in list(range(216, 222)) + list(range(228, 234)) + list(range(240, 244)):
        L.put(xx, 8, 'thorn')
    L.put(214, 8, 'shroom'); L.put(226, 8, 'shroom'); L.put(238, 8, 'shroom')
    L.logs(217, 4, 4); L.logs(229, 4, 4); L.stars(217, 3, 4); L.stars(229, 3, 4)
    L.ent(224, 8, E_TOAD); L.ent(236, 8, E_ANT); L.ent(246, 8, E_WORM)
    L.put(250, 7, 'exitT'); L.put(250, 8, 'exitB')
    L.put(253, 7, 'moonTL'); L.put(254, 7, 'moonTR'); L.put(253, 8, 'moonBL'); L.put(254, 8, 'moonBR')
    return L

def level_3_2():
    """RUST-O-TRON - factory boss arena"""
    L = Level(16)
    for x in range(16):
        L.put(x, 0, 'rock'); L.put(x, 1, ('cloudL', 'cloudM', 'cloudM', 'cloudR')[x % 4])
    for x in range(1, 15):
        L.put(x, 6, 'hillM' if x % 5 else 'hillL'); L.put(x, 7, 'hillBT'); L.put(x, 8, 'hillB')
    for xx in (4, 11):
        for d in range(2, 9): L.put(xx, d, 'trunk')
        L.put(xx, 8, 'trunkB')
    L.ground(0, 16)
    L.rock(0, 1, 0, 8, top=False)
    L.rock(15, 16, 0, 8, top=False)
    L.put(7, 7, 'moonTL'); L.put(8, 7, 'moonTR'); L.put(7, 8, 'moonBL'); L.put(8, 8, 'moonBR')
    L.put(13, 8, 'lantern')
    L.ent(2, 7, E_START)
    L.ent(9, 1, E_BOSS)
    return L

def island(L, x0, x1, top):
    for x in range(x0, x1):
        L.put(x, top, 'grass')
        if top + 1 < 12: L.put(x, top + 1, 'soil2' if (x * 3) % 7 == 0 else 'soil')
        if top + 2 < 12: L.put(x, top + 2, 'leafB')

def updraft(L, x, y0, y1=11):
    for y in range(y0, y1 + 1):
        if L.get(x, y) == 'sky': L.put(x, y, 'fern')

def level_4_1():
    """SKYWARD ISLES"""
    W = 256
    L = Level(W)
    for x in range(W):
        if (x * 7) % 17 == 0: L.put(x, (x * 3) % 6, 'sky_tw')
        if (x * 5) % 29 == 0: L.put(x, 1 + (x * 7) % 5, 'sky_tw2')
    for x, y, n in [(5, 1, 2), (22, 3, 1), (40, 0, 3), (61, 2, 1), (85, 1, 2), (108, 3, 2), (131, 0, 1),
                    (150, 2, 3), (172, 1, 1), (195, 3, 2), (218, 0, 2), (240, 2, 1)]:
        L.put(x, y, 'cloudL')
        for i in range(n): L.put(x + 1 + i, y, 'cloudM')
        L.put(x + 1 + n, y, 'cloudR')
    # distant cloud banks low in the sky
    x = 0
    while x < W - 6:
        w = 3 + (x * 5) % 4
        L.put(x, 10, 'hillL')
        for i in range(1, w + 1): L.put(x + i, 10, 'hillM')
        L.put(x + w + 1, 10, 'hillR')
        x += w + 5
    L.put(14, 1, 'moonTL'); L.put(15, 1, 'moonTR'); L.put(14, 2, 'moonBL'); L.put(15, 2, 'moonBR')

    # A 0-30 the landing isle
    L.ground(0, 26, 9)
    L.ent(2, 7, E_START)
    L.deco(6, 8, 'flower'); L.deco(10, 8, 'bush'); L.deco(17, 8, 'tuft'); L.deco(22, 8, 'flower')
    L.stars(12, 6, 4, [1, 0, 0, 1])
    L.plateau(4, 10)
    L.deco(19, 8, 'lantern')
    for xx in (20, 22): L.put(xx, 10, 'bstar')
    L.ent(24, 8, E_ANT)

    # B 26-70 island hops with updrafts
    island(L, 30, 36, 8); island(L, 41, 46, 7); island(L, 52, 58, 8); island(L, 63, 70, 9)
    updraft(L, 27, 3); updraft(L, 28, 3); updraft(L, 48, 2); updraft(L, 49, 2)
    L.logs(26, 3, 3); L.stars(26, 2, 3); L.logs(47, 1, 4); L.stars(47, 0, 4)
    L.stars(31, 6, 3); L.stars(42, 5, 3); L.stars(53, 6, 3)
    L.ent(38, 4, E_MAG); L.ent(60, 3, E_MAG)
    L.ent(55, 7, E_ANT)
    L.ground(63, 70, 9)

    # C 70-100 the big island: bonus, dig pocket, checkpoint
    L.ground(70, 100, 9)
    L.put(78, 5, 'termite'); L.put(79, 5, 'bonus'); L.put(80, 5, 'termite')
    L.ent(79, 4, E_GLOW, 1)
    L.deco(84, 8, 'lantern')
    L.fill(86, 89, 10, 11, 'soil'); L.put(86, 10, 'bstar'); L.put(88, 11, 'bstar')
    L.ent(92, 8, E_WORM)
    L.deco(74, 8, 'bush'); L.deco(95, 8, 'flower')
    L.put(98, 8, 'check')
    for d in range(3, 9): L.put(76, d, 'trunk')
    L.put(76, 8, 'trunkB')

    # D 100-150 the open sky: drifting clouds and updrafts
    L.ent(102, 7, E_PLATH, 8)
    L.ent(114, 5, E_PLATH, 7)
    L.ent(126, 7, E_PLATH, 8)
    L.ent(138, 5, E_PLATH, 6)
    for xx in (111, 112, 123, 124, 135, 136): updraft(L, xx, 4)
    L.stars(104, 5, 3); L.stars(116, 3, 3); L.stars(128, 5, 3); L.stars(140, 3, 3)
    L.stars(111, 1, 2); L.stars(123, 1, 2); L.stars(135, 1, 2)
    L.ent(108, 1, E_DROP); L.ent(120, 1, E_DROP); L.ent(132, 1, E_DROP)
    island(L, 118, 121, 10)

    # E 150-190 thunder isles and bouncy clouds
    L.ground(148, 156, 9)
    island(L, 160, 168, 8); island(L, 172, 180, 9); island(L, 184, 190, 8)
    for xx in (151, 152, 163, 164, 176, 177): L.put(xx, L.get(xx, 8) == 'sky' and 8 or 7, 'thorn')
    L.put(154, 8, 'shroom'); L.put(166, 7, 'shroom'); L.put(178, 8, 'shroom')
    L.logs(157, 4, 3); L.logs(169, 3, 3); L.logs(181, 4, 3)
    L.stars(157, 3, 3); L.stars(169, 2, 3); L.stars(181, 3, 3)
    updraft(L, 157, 5); updraft(L, 170, 4); updraft(L, 182, 5)
    L.ent(162, 7, E_TOAD); L.ent(175, 8, E_TOAD)
    L.ent(186, 3, E_MAG)

    # F 190-222 the beanstalk climb
    L.ground(190, 222, 9)
    for xx in (195, 205):
        for d in range(1, 9): L.put(xx, d, 'trunk')
        L.put(xx, 8, 'trunkB')
    L.logs(196, 7, 2); L.logs(198, 5, 2); L.logs(196, 3, 2); L.logs(199, 1, 3)
    L.stars(196, 6, 2); L.stars(198, 4, 2); L.stars(196, 2, 2); L.stars(199, 0, 3)
    L.ent(207, 6, E_PLATV, 4)
    L.logs(210, 2, 5); L.stars(210, 1, 5)
    L.ent(214, 8, E_WORM); L.ent(201, 8, E_ANT)
    L.put(219, 8, 'check')

    # G 222-256 the last isles and the sky gate
    island(L, 225, 231, 8); island(L, 235, 241, 7)
    updraft(L, 223, 4); updraft(L, 232, 3); updraft(L, 233, 3)
    L.ground(244, 256, 9)
    L.stars(226, 6, 4); L.stars(236, 5, 4); L.stars(232, 1, 2)
    L.ent(228, 7, E_ANT); L.ent(238, 4, E_MAG); L.ent(247, 8, E_WORM)
    L.put(251, 7, 'exitT'); L.put(251, 8, 'exitB')
    L.deco(246, 8, 'flower'); L.deco(254, 8, 'bush')
    return L

def level_4_2():
    """THUNDERHAWK - sky boss arena"""
    L = Level(16)
    for x, y in [(2, 1), (6, 3), (9, 0), (13, 2), (4, 4), (11, 5)]: L.put(x, y, 'sky_tw')
    L.put(2, 2, 'cloudL'); L.put(3, 2, 'cloudM'); L.put(4, 2, 'cloudR')
    L.put(10, 1, 'cloudL'); L.put(11, 1, 'cloudM'); L.put(12, 1, 'cloudM'); L.put(13, 1, 'cloudR')
    L.put(12, 3, 'moonTL'); L.put(13, 3, 'moonTR'); L.put(12, 4, 'moonBL'); L.put(13, 4, 'moonBR')
    L.ground(0, 16)
    for x in (1, 2, 13, 14): L.put(x, 8, 'tuft')
    L.put(5, 8, 'flower'); L.put(10, 8, 'bush')
    L.logs(3, 5, 2); L.logs(11, 5, 2)
    L.ent(2, 7, E_START)
    L.ent(9, 1, E_BOSS)
    return L

def level_5_1():
    """MOLTEN PEAKS"""
    W = 256
    L = Level(W)
    for x in range(W):
        if (x * 7) % 13 == 0: L.put(x, (x * 3) % 6, 'sky_tw')
        if (x * 5) % 23 == 0: L.put(x, 1 + (x * 7) % 5, 'sky_tw2')
    for x, y, n in [(6, 1, 2), (30, 0, 3), (58, 2, 1), (90, 1, 2), (118, 0, 2), (150, 2, 3), (180, 1, 1), (214, 0, 2), (240, 2, 2)]:
        L.put(x, y, 'cloudL')
        for i in range(n): L.put(x + 1 + i, y, 'cloudM')
        L.put(x + 1 + n, y, 'cloudR')
    x = 0
    while x < W - 6:
        w = 3 + (x * 5) % 4
        L.put(x, 6, 'hillL')
        for i in range(1, w + 1): L.put(x + i, 6, 'hillM')
        L.put(x + w + 1, 6, 'hillR')
        for i in range(w + 2):
            L.put(x + i, 7, 'hillBT'); L.put(x + i, 8, 'hillB')
        x += w + 3
    def lava(x0, x1):
        for xx in range(x0, x1):
            L.put(xx, 9, 'sky'); L.put(xx, 10, 'watert'); L.put(xx, 11, 'water')
    def vent(xx, y0):
        for y in range(y0, 10):
            if L.get(xx, y) in ('sky', 'hillB', 'hillBT', 'hillM', 'hillL', 'hillR', 'sky_tw', 'sky_tw2'):
                L.put(xx, y, 'fern')

    # A 0-34 base camp
    L.ground(0, 34)
    L.ent(2, 7, E_START)
    L.put(12, 4, 'moonTL'); L.put(13, 4, 'moonTR'); L.put(12, 5, 'moonBL'); L.put(13, 5, 'moonBR')
    L.deco(6, 8, 'flower'); L.deco(9, 8, 'bush'); L.deco(17, 8, 'tuft'); L.deco(26, 8, 'rockS')
    L.plateau(5, 11)
    L.stars(15, 6, 4, [1, 0, 0, 1])
    L.deco(20, 8, 'lantern')
    for xx in (21, 23, 25): L.put(xx, 10, 'bstar')
    L.ent(28, 8, E_ANT)

    # B 34-70 the lava river
    lava(34, 66)
    for x0 in (38, 46, 54, 62): L.logs(x0, 7, 2)
    L.ent(41, 6, E_PLATH, 3); L.ent(57, 5, E_PLATH, 3)
    L.stars(38, 6, 2); L.stars(46, 6, 2); L.stars(54, 6, 2); L.stars(62, 6, 2)
    L.ent(44, 9, E_WORM); L.ent(52, 9, E_WORM); L.ent(60, 9, E_WORM)
    L.ent(48, 3, E_MAG)
    L.ground(66, 72)

    # C 72-102 the rockfall gully
    L.ground(72, 104)
    L.rock(74, 100, 0, 3, top=False)
    for xx in range(74, 100): L.put(xx, 4, 'leafB')
    for xx in (78, 84, 90, 96): L.ent(xx, 5, E_DROP)
    L.stars(80, 7, 2); L.stars(86, 7, 2); L.stars(92, 7, 2)
    L.put(102, 8, 'check')
    L.ent(99, 8, E_ANT)

    # D 104-140 the heat vents over the lava lake
    lava(104, 136)
    for xx in (108, 109, 118, 119, 128, 129): vent(xx, 3)
    L.logs(112, 4, 3); L.logs(122, 3, 3); L.logs(132, 4, 3)
    L.stars(112, 3, 3); L.stars(122, 2, 3); L.stars(132, 3, 3)
    L.stars(108, 1, 2); L.stars(118, 1, 2); L.stars(128, 1, 2)
    L.ent(114, 2, E_MAG); L.ent(126, 1, E_MAG)
    L.ground(136, 142)

    # E 142-176 the ash mountain (dig through)
    L.ground(142, 176)
    L.rock(146, 172, 0, 2, top=False)
    L.earth(146, 172, 3, 11)
    for xx in range(146, 172): L.put(xx, 3, 'grass')
    for xx, yy in [(148, 9), (151, 6), (154, 10), (158, 7), (161, 11), (165, 8), (169, 9)]:
        L.put(xx, yy, 'bstar')
    L.fill(158, 161, 9, 10, 'soilD'); L.ent(159, 9, E_ONEUP)
    L.deco(144, 8, 'lantern')
    L.ent(174, 8, E_TOAD)

    # F 176-212 geysers and the climb
    L.ground(176, 212)
    L.put(180, 8, 'shroom'); L.put(190, 8, 'shroom')
    L.rock(194, 196, 3, 8)
    L.logs(182, 4, 3); L.logs(186, 2, 3); L.stars(182, 3, 3); L.stars(186, 1, 3)
    L.ent(198, 6, E_PLATV, 4)
    L.logs(200, 2, 4); L.stars(200, 1, 4)
    L.ent(204, 8, E_TOAD)
    L.put(209, 8, 'check')
    for xx in (179, 189, 203): L.put(xx, 10, 'bstar')

    # G 212-256 to the crater
    L.ground(212, 256)
    lava(224, 230)
    for xx in list(range(216, 221)) + list(range(236, 241)): L.put(xx, 8, 'thorn')
    L.put(214, 8, 'shroom'); L.put(234, 8, 'shroom')
    vent(226, 3); vent(227, 3)
    L.logs(217, 4, 4); L.logs(237, 4, 4); L.stars(217, 3, 4); L.stars(237, 3, 4)
    L.ent(228, 9, E_WORM); L.ent(222, 8, E_ANT); L.ent(244, 8, E_ANT); L.ent(232, 3, E_MAG)
    L.put(250, 7, 'exitT'); L.put(250, 8, 'exitB')
    L.put(252, 7, 'moonTL'); L.put(253, 7, 'moonTR'); L.put(252, 8, 'moonBL'); L.put(253, 8, 'moonBR')
    return L

def level_5_2():
    """THE MAGMA DRAGON - final arena inside the crater"""
    L = Level(16)
    for x in range(16):
        if x % 3 == 0: L.put(x, (x * 5) % 4, 'sky_tw2')
    L.put(4, 1, 'cloudL'); L.put(5, 1, 'cloudM'); L.put(6, 1, 'cloudR')
    for x in range(1, 15):
        L.put(x, 6, 'hillM' if x % 4 else 'hillL'); L.put(x, 7, 'hillBT'); L.put(x, 8, 'hillB')
    L.ground(0, 16)
    L.rock(0, 1, 0, 8, top=False)
    L.rock(15, 16, 0, 8, top=False)
    L.logs(3, 5, 2); L.logs(11, 5, 2)
    L.put(7, 8, 'lantern'); L.put(2, 8, 'tuft'); L.put(13, 8, 'flower')
    L.ent(2, 7, E_START)
    L.ent(9, 6, E_BOSS)
    return L
