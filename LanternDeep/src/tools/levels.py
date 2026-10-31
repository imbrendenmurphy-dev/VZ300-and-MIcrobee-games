"""THE LANTERN DEEP - the world: regions, rooms, objects, progression.

Story: beneath the old town lie the halls of the Vaunar, who kept a great
Lantern burning at the Heart of the Deep to hold back the Unlight. The
Lantern has gone out. You carry the last flame down to rekindle it.

  Level 1  THE DROWNED TEMPLE     R0-R3   find the Iron Key
  Level 2  THE OSSUARY            R4-R8   defeat the Bone Colossus, take the Glimmer Lantern
  Level 3  THE CRYSTAL CAVERNS    R9-R12  find the Moonsilver Blade
  Level 4  THE EMBER HALLS        R13-R16 take the Ember Ring from the Forge
  Level 5  THE HEART OF THE DEEP  R17-R19 face the Hollow King, rekindle the Heart

Rooms are 80 x 22 cells. East/west exits are always rows 10-12, north/
south exits always columns 38-41, so neighbouring rooms line up.
"""
import math
import random
import numpy as np

W, H = 80, 22

# item numbers (inventory bits 1..4; 5+ are pickups)
IT_KEY, IT_LANTERN, IT_BLADE, IT_RING, IT_POTION, IT_HEART, IT_GOLD = 1, 2, 3, 4, 5, 6, 7

# enemy types (must match game.asm FOE table order, starting at 2)
F_BAT, F_SKEL, F_GHOST, F_SPIDER, F_SLIME, F_IMP, F_SHADE, F_BEETLE = 'bat', 'skel', 'ghost', 'spider', 'slime', 'imp', 'shade', 'beetle'

REGIONS = [
    dict(name='THE DROWNED TEMPLE', style='temple', music='hall'),
    dict(name='THE OSSUARY', style='ossuary', music='ossuary'),
    dict(name='THE CRYSTAL CAVERNS', style='caverns', music='caverns'),
    dict(name='THE EMBER HALLS', style='ember', music='ember'),
    dict(name='THE HEART OF THE DEEP', style='heart', music='heart'),
]


class Spec:
    """one room: semantic map + objects + lights + exits"""

    def __init__(self, rid, region, name):
        self.rid, self.region, self.name = rid, region, name
        self.m = [['#'] * W for _ in range(H)]
        self.objects = []          # (kind, x, y, params dict)
        self.lights = []           # (x, y, tint, max, radius)
        self.spawns = []           # (foe, x, y)
        self.exits = {}            # 'N','S','W','E' -> room id
        self.zones = None          # optional fn(x, y) -> zone 1..3
        self.pool = None           # temple elliptical pool (cx, cy, rx, ry)
        self.dark = False

    # drawing helpers
    def rect(self, x0, y0, x1, y1, ch='.'):
        for y in range(max(0, y0), min(H, y1 + 1)):
            for x in range(max(0, x0), min(W, x1 + 1)):
                self.m[y][x] = ch

    def at(self, x, y):
        return self.m[y][x] if 0 <= x < W and 0 <= y < H else 'E'

    def exit(self, side, target, ch='.'):
        self.exits[side] = target
        if side == 'W':
            self.rect(0, 10, 3, 12, ch)
        elif side == 'E':
            self.rect(76, 10, 79, 12, ch)
        elif side == 'N':
            self.rect(38, 0, 41, 2, ch)
        elif side == 'S':
            self.rect(38, 19, 41, 21, ch)

    def obj(self, kind, x, y, **p):
        self.objects.append((kind, x, y, p))

    def light(self, x, y, tint, mx, rad):
        self.lights.append((x, y, tint, mx, rad))

    def spawn(self, foe, x, y):
        self.spawns.append((foe, x, y))


def cave(spec, seed, fill=0.47, steps=5, keep=()):
    """carve organic caverns (cellular automaton) inside the room, keeping
    the given points open; the caller then joins them with tunnels"""
    rnd = random.Random(seed)
    g = np.array([[1 if (x in (0, 1, W - 2, W - 1) or y in (0, 1, H - 2, H - 1) or rnd.random() < fill) else 0
                   for x in range(W)] for y in range(H)], dtype=np.uint8)
    for _ in range(steps):
        n = sum(np.roll(np.roll(g, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))
        g = ((n >= 5) | (g & (n >= 4))).astype(np.uint8)
        g[:2, :] = 1
        g[-2:, :] = 1
        g[:, :2] = 1
        g[:, -2:] = 1
    # tidy: no lone pillars or one-cell nubs (they make ragged faces)
    for _ in range(2):
        n4 = (np.roll(g, 1, 0) + np.roll(g, -1, 0) + np.roll(g, 1, 1) + np.roll(g, -1, 1))
        g = np.where((g == 1) & (n4 <= 1), 0, g).astype(np.uint8)
        g = np.where((g == 0) & (n4 >= 3), 1, g).astype(np.uint8)
        # walls need to be at least two cells tall (top face + lower face)
        up, dn = np.roll(g, 1, 0), np.roll(g, -1, 0)
        g = np.where((g == 1) & (up == 0) & (dn == 0), 0, g).astype(np.uint8)
        g[:2, :] = 1
        g[-2:, :] = 1
        g[:, :2] = 1
        g[:, -2:] = 1
    for y in range(H):
        for x in range(W):
            if not g[y, x]:
                spec.m[y][x] = '.'
    return spec


def tunnel(spec, a, b, width=1, ch='.'):
    """a wandering tunnel from a to b (keeps caves connected)"""
    (x, y), (tx, ty) = a, b
    rnd = random.Random(x * 131 + y * 17 + tx * 7 + ty)
    while (x, y) != (tx, ty):
        spec.rect(x - (width // 2), y, x + width - 1 - width // 2, y + (1 if width > 1 else 0), ch)
        if rnd.random() < 0.65:
            x += (tx > x) - (tx < x)
        else:
            y += (ty > y) - (ty < y)
    spec.rect(x, y, x, y, ch)


# =====================================================================
# Level 1: THE DROWNED TEMPLE
# =====================================================================
def r0():
    s = Spec(0, 0, 'THE DROWNED HALL')
    s.rect(0, 9, 37, 11)                      # the Lanternless Way
    s.rect(22, 12, 24, 14)                    # collapsed side passage
    s.rect(38, 3, 77, 19, ',')                # the hall
    for x in range(38, 78):
        s.m[3][x] = 'b'
        s.m[19][x] = 'b'
    for y in range(3, 20):
        s.m[y][38] = 'b'
        s.m[y][77] = 'b'
    for y in (9, 10, 11):
        s.m[y][36] = 'd'
        s.m[y][37] = 'd'
    s.rect(78, 10, 79, 12, 'd')               # east door to the cloister
    for y in (10, 11, 12):
        s.m[y][77] = 'd'
    s.exits['E'] = 1
    s.pool = (59.5, 14.0, 9.6, 3.4)
    s.zones = lambda x, y: 1 if x < 36 else 2
    s.zone_names = {1: 'THE LANTERNLESS WAY', 2: 'THE DROWNED HALL'}
    for k, x, y in [('crystal', 39, 4), ('statue', 56, 3), ('brazier', 52, 4), ('brazier', 63, 4),
                    ('pillar', 44, 7), ('pillar', 72, 7), ('pillar', 44, 15), ('pillar', 72, 15),
                    ('bones', 9, 11), ('skull', 10, 10), ('rubble', 23, 13), ('rubble', 24, 14), ('rubble', 22, 14),
                    ('rubble', 25, 11), ('web', 0, 9), ('web', 38, 19), ('web', 77, 3), ('urn', 31, 9),
                    ('bones', 74, 19), ('rubble', 40, 18), ('sconce', 18, 8),
                    ('puddle', 14, 11), ('puddle', 27, 9), ('puddle', 6, 10)]:
        s.obj(k, x, y)
    s.obj('chest', 76, 18, item=IT_HEART)
    s.obj('tablet', 57, 8, msg='WHERE THE LANTERN FAILS, THE DEEP REMEMBERS.')
    s.lights += [(40, 7, 'cool', 7, 13.0), (52, 5, 'warm', 6, 7.5), (63, 5, 'warm', 6, 7.5)]
    s.spawn(F_BAT, 50, 8)
    s.spawn(F_BAT, 68, 9)
    s.spawn(F_SKEL, 62, 19)
    s.spawn(F_BEETLE, 12, 9)
    s.spawn(F_BEETLE, 29, 11)
    s.start = (2, 10)
    return s


def r1():
    s = Spec(1, 0, 'THE FLOODED CLOISTER')
    s.rect(4, 3, 75, 19, ',')
    for x in range(4, 76):
        s.m[3][x] = 'b'
        s.m[19][x] = 'b'
    for y in range(3, 20):
        s.m[y][4] = 'b'
        s.m[y][75] = 'b'
    s.exit('W', 0, 'd')
    s.exit('E', 3, 'd')
    s.exit('N', 2, 'd')
    s.rect(4, 10, 4, 12, 'd')
    s.rect(75, 10, 75, 12, 'd')
    s.rect(38, 3, 41, 3, 'd')
    # the flooded court: a long channel with two bridges
    s.rect(8, 14, 71, 17, '~')
    s.rect(22, 14, 25, 17, ',')
    s.rect(54, 14, 57, 17, ',')
    for x in range(7, 72, 8):
        s.obj('pillar', x, 5)
    s.obj('brazier', 34, 4)
    s.obj('brazier', 45, 4)
    s.light(34, 5, 'warm', 6, 7.0)
    s.light(45, 5, 'warm', 6, 7.0)
    for k, x, y in [('web', 5, 4), ('web', 74, 18), ('rubble', 12, 12), ('rubble', 66, 9), ('bones', 30, 18),
                    ('puddle', 18, 12), ('puddle', 61, 11), ('urn', 6, 18), ('urn', 73, 4), ('skull', 47, 18)]:
        s.obj(k, x, y)
    s.obj('tablet', 40, 18, msg='THE KEEPERS WENT DOWN WITH THE LIGHT. WE STAYED WITH THE WATER.')
    s.obj('chest', 6, 15, item=IT_POTION)
    s.spawn(F_BAT, 30, 9)
    s.spawn(F_BAT, 50, 12)
    s.spawn(F_BAT, 64, 7)
    s.spawn(F_BEETLE, 20, 18)
    return s


def r2():
    s = Spec(2, 0, 'THE SHRINE OF THE KEEPER')
    s.rect(20, 4, 59, 18, ',')
    for x in range(20, 60):
        s.m[4][x] = 'b'
        s.m[18][x] = 'b'
    for y in range(4, 19):
        s.m[y][20] = 'b'
        s.m[y][59] = 'b'
    s.exit('S', 1, 'd')
    s.rect(38, 18, 41, 18, 'd')
    s.obj('altar', 38, 6)
    s.obj('pedestal', 39, 8, item=IT_KEY)
    for (x, y) in ((34, 6), (45, 6), (30, 11), (49, 11), (34, 15), (45, 15)):
        s.obj('candle', x, y)
        s.light(x, y, 'warm', 5, 5.0)
    s.obj('pillar', 24, 6)
    s.obj('pillar', 54, 6)
    s.obj('pillar', 24, 13)
    s.obj('pillar', 54, 13)
    s.obj('crystal', 21, 5, colour='cool')
    s.light(22, 8, 'cool', 6, 8.0)
    s.obj('tablet', 40, 16, msg='THE IRON KEY OPENS THE WAY DOWN. LET THE LANTERN GO BEFORE YOU.')
    for k, x, y in [('web', 58, 5), ('bones', 28, 17), ('skull', 52, 17), ('urn', 21, 17), ('urn', 58, 17)]:
        s.obj(k, x, y)
    s.spawn(F_SKEL, 32, 9)
    s.spawn(F_SKEL, 47, 9)
    return s


def r3():
    s = Spec(3, 0, 'THE IRON GATE')
    s.rect(0, 9, 30, 13, '.')
    s.exit('W', 1, 'd')
    s.rect(30, 4, 68, 18, ',')
    for x in range(30, 69):
        s.m[4][x] = 'b'
        s.m[18][x] = 'b'
    for y in range(4, 19):
        s.m[y][30] = 'b'
        s.m[y][68] = 'b'
    s.rect(30, 9, 30, 13, 'd')
    s.rect(69, 9, 77, 13, '.')                # beyond the gate
    s.rect(68, 9, 68, 13, 'd')
    for y in (9, 10, 11, 12, 13):
        s.obj('gate', 68, y, need=IT_KEY, bit=0)
    s.obj('stairs', 74, 10, to=4, tx=6, ty=11)
    s.obj('statue', 47, 4)
    s.obj('brazier', 43, 5)
    s.obj('brazier', 53, 5)
    s.light(43, 6, 'warm', 6, 7.0)
    s.light(53, 6, 'warm', 6, 7.0)
    s.obj('pillar', 35, 6)
    s.obj('pillar', 35, 14)
    s.obj('pillar', 62, 6)
    s.obj('pillar', 62, 14)
    s.obj('tablet', 48, 10, msg='BELOW LIE THE BONES OF THOSE WHO KEPT THE FLAME.')
    for k, x, y in [('puddle', 10, 11), ('rubble', 20, 9), ('web', 31, 5), ('web', 67, 17), ('bones', 40, 17),
                    ('sconce', 15, 8), ('skull', 76, 13)]:
        s.obj(k, x, y)
    s.obj('chest', 66, 17, item=IT_POTION)
    s.spawn(F_SKEL, 50, 15)
    s.spawn(F_BAT, 40, 12)
    s.spawn(F_BEETLE, 22, 12)
    return s


# =====================================================================
# Level 2: THE OSSUARY
# =====================================================================
def r4():
    s = Spec(4, 1, 'THE BONE STAIR')
    s.rect(3, 6, 22, 16, '.')
    s.obj('stairs_up', 4, 9)
    s.rect(22, 10, 79, 12, '.')
    s.exit('E', 5)
    s.rect(34, 4, 46, 9, ',')
    s.rect(34, 13, 46, 18, ',')
    for (x, y) in ((8, 7), (18, 7), (8, 15), (18, 15), (40, 5), (40, 17), (60, 11)):
        s.obj('candle', x, y)
        s.light(x, y, 'warm', 5, 5.0)
    for k, x, y in [('skull', 12, 16), ('bones', 15, 6), ('bones', 36, 17), ('skull', 45, 5), ('web', 3, 6),
                    ('rubble', 70, 12), ('urn', 22, 16), ('urn', 46, 4)]:
        s.obj(k, x, y)
    s.obj('tablet', 40, 10, msg='HERE THE FLAMEKEEPERS SLEEP. TREAD SOFTLY, BEARER.')
    s.spawn(F_GHOST, 40, 16)
    s.spawn(F_BEETLE, 30, 11)
    return s


def r5():
    s = Spec(5, 1, 'THE HALL OF TOMBS')
    s.rect(4, 3, 75, 19, ',')
    s.exit('W', 4)
    s.exit('E', 8)
    s.exit('S', 6)
    for row in (4, 8, 14):
        for x in range(8, 72, 10):
            if row == 8 and 30 < x < 50:
                continue
            s.obj('sarcophagus', x, row)
    for (x, y) in ((6, 4), (73, 4), (6, 18), (73, 18), (39, 7), (39, 13)):
        s.obj('candle', x, y)
        s.light(x, y, 'warm', 5, 5.5)
    s.obj('tablet', 40, 10, msg='THE COLOSSUS GUARDS THE GLIMMER. ONLY THE GLIMMER FINDS THE HIDDEN WAY.')
    for k, x, y in [('web', 4, 3), ('web', 75, 19), ('skull', 20, 18), ('bones', 55, 18), ('bones', 28, 3)]:
        s.obj(k, x, y)
    s.spawn(F_SKEL, 20, 11)
    s.spawn(F_SKEL, 60, 11)
    s.spawn(F_GHOST, 40, 17)
    return s


def r6():
    s = Spec(6, 1, 'THE CHARNEL WAY')
    s.dark = True
    s.exit('N', 5)
    s.exit('E', 7)
    # a winding passage of niches
    s.rect(38, 0, 41, 6)
    s.rect(12, 5, 41, 7)
    s.rect(12, 5, 14, 17)
    s.rect(12, 15, 60, 17)
    s.rect(58, 9, 60, 17)
    s.rect(58, 9, 79, 12)
    s.rect(24, 9, 30, 13)
    s.rect(24, 9, 26, 15)
    s.rect(46, 9, 52, 13)
    s.rect(50, 13, 52, 15)
    for x in range(16, 40, 4):
        s.obj('skull', x, 5)
    for x in range(16, 58, 5):
        s.obj('bones', x, 17)
    s.obj('chest', 27, 10, item=IT_POTION)
    s.obj('candle', 48, 10)
    s.light(48, 10, 'warm', 4, 4.5)
    s.spawn(F_GHOST, 20, 6)
    s.spawn(F_GHOST, 40, 16)
    s.spawn(F_GHOST, 66, 11)
    s.spawn(F_BEETLE, 13, 12)
    return s


def r7():
    s = Spec(7, 1, 'THE COLOSSUS CRYPT')
    s.exit('W', 6)
    s.rect(0, 10, 12, 12)
    s.rect(12, 3, 75, 19, ',')
    s.obj('colossus', 56, 6, bit=0)
    s.obj('pedestal', 69, 10, item=IT_LANTERN)
    for (x, y) in ((16, 4), (16, 18), (46, 4), (46, 18), (73, 4), (73, 18)):
        s.obj('candle', x, y)
        s.light(x, y, 'warm', 5, 6.0)
    for k, x, y in [('bones', 30, 8), ('skull', 33, 14), ('bones', 24, 16), ('skull', 40, 6), ('bones', 50, 15),
                    ('skull', 62, 17), ('web', 12, 3), ('web', 75, 19)]:
        s.obj(k, x, y)
    s.obj('tablet', 20, 11, msg='IT WAS BUILT FROM THE KEEPERS THEMSELVES. IT STILL KEEPS.')
    s.spawn(F_SKEL, 40, 11)
    return s


def r8():
    s = Spec(8, 1, 'THE SEALED STAIR')
    s.exit('W', 5)
    s.rect(0, 10, 50, 12)
    s.rect(30, 5, 50, 17, ',')
    s.rect(51, 10, 51, 12, 'X')               # a cracked wall hides the way on
    for y in (10, 11, 12):
        s.obj('secret', 51, y, need=IT_LANTERN, bit=0)
    s.rect(52, 7, 72, 15, '.')
    s.obj('stairs', 66, 10, to=9, tx=5, ty=11)
    for (x, y) in ((31, 6), (49, 6), (31, 16), (49, 16)):
        s.obj('candle', x, y)
        s.light(x, y, 'warm', 5, 5.5)
    for k, x, y in [('skull', 40, 6), ('skull', 40, 16), ('bones', 35, 12), ('bones', 60, 14), ('web', 72, 7)]:
        s.obj(k, x, y)
    s.obj('tablet', 44, 9, msg='THE WALL IS NOT A WALL. THE GLIMMER KNOWS.')
    s.spawn(F_GHOST, 40, 14)
    s.spawn(F_SKEL, 36, 8)
    return s


# =====================================================================
# Level 3: THE CRYSTAL CAVERNS
# =====================================================================
def _cave_room(s, seed, points):
    cave(s, seed)
    for a, b in zip(points, points[1:]):
        tunnel(s, a, b, width=2)
    for p in points:
        s.rect(p[0] - 1, p[1] - 1, p[0] + 1, p[1] + 1)


def r9():
    s = Spec(9, 2, 'THE GLITTERING DESCENT')
    s.rect(2, 8, 10, 14)
    _cave_room(s, 9, [(6, 11), (20, 6), (40, 14), (60, 8), (77, 11)])
    s.exit('E', 10)
    s.obj('stairs_up', 3, 9)
    for (x, y, c) in ((18, 3, 'cool'), (44, 17, 'cool'), (62, 4, 'magic')):
        s.obj('shard', x, y, colour=c)
        s.light(x + 1, y + 1, c, 6, 8.0)
    for k, x, y in [('stalagmite', 30, 12), ('stalagmite', 52, 10), ('rubble', 35, 8), ('mushroom', 70, 15)]:
        s.obj(k, x, y)
    s.light(70, 15, 'green', 4, 4.0)
    s.spawn(F_SPIDER, 45, 10)
    s.spawn(F_BEETLE, 25, 9)
    return s


def r10():
    s = Spec(10, 2, 'THE PRISM GROTTO')
    _cave_room(s, 10, [(2, 11), (20, 15), (39, 10), (39, 2), (39, 10), (60, 6), (77, 11)])
    s.exit('W', 9)
    s.exit('N', 11)
    s.exit('E', 12)
    s.rect(30, 6, 50, 15)
    s.obj('crystal', 38, 7, colour='magic')
    s.light(39, 11, 'magic', 7, 12.0)
    for (x, y, c) in ((12, 5, 'cool'), (64, 15, 'green'), (24, 16, 'cool')):
        s.obj('shard', x, y, colour=c)
        s.light(x + 1, y + 1, c, 6, 8.0)
    for k, x, y in [('stalagmite', 33, 13), ('stalagmite', 47, 8), ('rubble', 56, 12), ('mushroom', 8, 14)]:
        s.obj(k, x, y)
    s.obj('tablet', 44, 13, msg='EVERY CRYSTAL HOLDS A LITTLE OF THE OLD LIGHT. TOUCH THEM.')
    s.spawn(F_SPIDER, 20, 12)
    s.spawn(F_SPIDER, 60, 9)
    s.spawn(F_SLIME, 45, 14)
    return s


def r11():
    s = Spec(11, 2, 'THE MUSHROOM HOLLOW')
    _cave_room(s, 11, [(39, 20), (39, 14), (20, 10), (12, 5), (39, 14), (60, 9), (68, 5)])
    s.exit('S', 10)
    s.rect(45, 12, 58, 17, '~')
    s.obj('chest', 68, 5, item=IT_BLADE)
    for (x, y) in ((16, 12), (22, 8), (30, 15), (55, 6), (62, 14), (35, 6), (48, 9), (10, 6)):
        s.obj('mushroom', x, y)
        s.light(x, y, 'green', 4, 4.5)
    s.obj('shard', 12, 3, colour='green')
    s.light(13, 4, 'green', 6, 8.0)
    s.spawn(F_SLIME, 30, 12)
    s.spawn(F_SLIME, 60, 10)
    s.spawn(F_SPIDER, 20, 14)
    return s


def r12():
    s = Spec(12, 2, 'THE RIVER CROSSING')
    _cave_room(s, 12, [(2, 11), (18, 11), (30, 6), (30, 16), (50, 11), (62, 11)])
    s.exit('W', 10)
    s.rect(26, 10, 52, 12, '.')               # the way across
    for y in range(2, 20):                    # the underground river
        for x in range(36, 44):
            if s.m[y][x] == '.' or 3 <= y <= 18:
                s.m[y][x] = '~'
    s.rect(36, 10, 43, 12, '.')               # a natural bridge
    s.rect(56, 1, 78, 20, '#')                # the sealed chamber beyond
    s.rect(50, 9, 61, 13, '.')
    s.rect(62, 9, 63, 13, 'Y')                # crystal barrier
    for y in (9, 10, 11, 12, 13):
        for x in (62, 63):
            s.obj('barrier', x, y, need=IT_BLADE, bit=0)
    s.rect(64, 6, 77, 16)
    s.obj('stairs', 72, 10, to=13, tx=5, ty=11)
    s.obj('shard', 66, 6, colour='cool')
    s.light(67, 7, 'cool', 6, 8.0)
    s.obj('shard', 20, 5, colour='magic')
    s.light(21, 6, 'magic', 6, 8.0)
    s.obj('tablet', 56, 9, msg='ONLY MOONSILVER CUTS THE SINGING STONE.')
    s.spawn(F_SPIDER, 25, 12)
    s.spawn(F_SLIME, 52, 13)
    return s


# =====================================================================
# Level 4: THE EMBER HALLS
# =====================================================================
def r13():
    s = Spec(13, 3, 'THE ASH STAIR')
    s.rect(2, 7, 20, 15)
    s.obj('stairs_up', 3, 9)
    s.rect(20, 10, 79, 12)
    s.exit('E', 14)
    s.rect(30, 4, 56, 18, '.')
    s.rect(36, 7, 41, 9, 'L')
    s.rect(46, 13, 52, 15, 'L')
    for k, x, y in [('anvil', 33, 16), ('rubble', 55, 5), ('skull', 10, 14), ('bones', 15, 8)]:
        s.obj(k, x, y)
    s.obj('tablet', 44, 10, msg='THE VAUNAR FORGED THE LANTERN HERE, IN THE MOUNTAIN\'S HEART.')
    s.spawn(F_IMP, 50, 6)
    s.spawn(F_BEETLE, 25, 11)
    return s


def r14():
    s = Spec(14, 3, 'THE MAGMA BRIDGE')
    s.rect(0, 3, 79, 19, 'L')
    s.rect(0, 9, 14, 13)
    s.rect(14, 10, 66, 12)                    # the bridge
    s.rect(66, 4, 79, 18)
    s.rect(30, 12, 33, 21)                    # south spur to the forge
    s.rect(30, 18, 41, 21)
    s.exit('W', 13)
    s.exit('E', 16)
    s.exit('S', 15)
    s.rect(68, 4, 79, 8, '#')
    for k, x, y in [('rubble', 70, 15), ('skull', 75, 17)]:
        s.obj(k, x, y)
    s.spawn(F_IMP, 70, 11)
    s.spawn(F_IMP, 40, 11)
    return s


def r15():
    s = Spec(15, 3, 'THE FORGE OF THE VAUNAR')
    s.exit('N', 14)
    s.rect(10, 4, 69, 18)
    s.obj('forge', 38, 5)
    s.obj('pedestal', 39, 9, item=IT_RING)
    s.rect(12, 14, 22, 17, 'L')
    s.rect(57, 14, 67, 17, 'L')
    for (x, y) in ((28, 8), (50, 8)):
        s.obj('anvil', x, y)
    for k, x, y in [('rubble', 12, 5), ('rubble', 66, 5), ('bones', 30, 16), ('skull', 48, 16)]:
        s.obj(k, x, y)
    s.obj('tablet', 44, 12, msg='THE RING REMEMBERS THE FIRE. THE FIRE WILL REMEMBER YOU.')
    s.spawn(F_IMP, 20, 9)
    s.spawn(F_IMP, 60, 9)
    s.spawn(F_SLIME, 40, 15)
    return s


def r16():
    s = Spec(16, 3, 'THE FISSURE WALK')
    s.exit('W', 14)
    s.rect(0, 5, 70, 17)
    s.rect(24, 5, 50, 17, 'h')                # hot fissured rock: the Ember Ring protects
    s.rect(18, 2, 22, 4, 'L')
    s.rect(52, 18, 58, 20, 'L')
    s.obj('stairs', 62, 10, to=17, tx=5, ty=11)
    for k, x, y in [('rubble', 10, 6), ('skull', 66, 16), ('anvil', 6, 15)]:
        s.obj(k, x, y)
    s.obj('tablet', 14, 11, msg='THE STONE HERE BURNS. BEAR THE RING, OR TURN BACK.')
    s.spawn(F_IMP, 60, 6)
    return s


# =====================================================================
# Level 5: THE HEART OF THE DEEP
# =====================================================================
def r17():
    s = Spec(17, 4, 'THE THRESHOLD')
    s.rect(2, 7, 18, 15)
    s.obj('stairs_up', 3, 9)
    s.rect(18, 10, 79, 12)
    s.exit('E', 18)
    s.rect(28, 3, 66, 19, ',')
    s.obj('portal', 46, 4)
    s.light(47, 6, 'magic', 7, 10.0)
    for x in range(30, 66, 8):
        s.obj('runestone', x, 3)
        s.obj('runestone', x, 19)
    s.obj('tablet', 40, 14, msg='HE WHO HOLLOWED THE HEART WEARS ITS LIGHT AS A CROWN.')
    s.spawn(F_SHADE, 40, 6)
    s.spawn(F_SHADE, 58, 16)
    return s


def r18():
    s = Spec(18, 4, 'THE HALL OF ECHOES')
    s.rect(2, 3, 77, 19, ',')
    s.exit('W', 17)
    s.exit('E', 19)
    for x in range(8, 72, 9):
        s.obj('pillar', x, 4)
        s.obj('pillar', x, 15)
    for x in range(6, 76, 12):
        s.obj('runestone', x, 2)
    s.obj('shard', 39, 9, colour='magic')
    s.light(40, 10, 'magic', 6, 9.0)
    s.obj('chest', 4, 17, item=IT_POTION)
    s.obj('chest', 75, 4, item=IT_POTION)
    s.obj('tablet', 30, 11, msg='HIS VOICE IS ALL THAT IS LEFT OF HIM. DO NOT ANSWER IT.')
    s.spawn(F_SHADE, 25, 7)
    s.spawn(F_SHADE, 50, 13)
    s.spawn(F_SHADE, 64, 9)
    return s


def r19():
    s = Spec(19, 4, 'THE HEART OF THE DEEP')
    s.exit('W', 18)
    s.rect(0, 10, 10, 12)
    s.rect(10, 2, 77, 19, ',')
    s.obj('king', 48, 4, bit=0)
    s.obj('heart', 66, 8, bit=1)
    for x in range(14, 76, 10):
        s.obj('runestone', x, 1)
    s.obj('portal', 20, 4)
    s.light(21, 6, 'magic', 6, 9.0)
    s.obj('portal', 20, 14)
    s.light(21, 16, 'magic', 6, 9.0)
    return s


ROOMS = [r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19]


def finish(s):
    """carve every exit inward until it meets the room"""
    for side in s.exits:
        if side in 'WE':
            xs = range(0, W) if side == 'W' else range(W - 1, -1, -1)
            for i, x in enumerate(xs):
                if i > 3 and all(s.m[y][x] not in '#X' for y in (10, 11, 12)):
                    break
                for y in (10, 11, 12):
                    if s.m[y][x] in '#':
                        s.m[y][x] = '.'
        else:
            ys = range(0, H) if side == 'N' else range(H - 1, -1, -1)
            for i, y in enumerate(ys):
                if i > 2 and all(s.m[y][x] not in '#X' for x in (38, 39, 40, 41)):
                    break
                for x in (38, 39, 40, 41):
                    if s.m[y][x] in '#':
                        s.m[y][x] = '.'
    return s


def all_rooms():
    return [finish(f()) for f in ROOMS]
