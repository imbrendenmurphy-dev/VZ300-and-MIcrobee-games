"""World 1 (CHECKER PLAINS) creatures and scenery - original designs in the MZ-700 spirit:
bold outlines, saturated fills, chunky exaggerated shapes. Each def draws into a Canvas at
'scale' (1.0 = size at the hero's depth). Coordinates in square units, origin bottom centre
(for flyers: origin at the centre of the body, see ANCHOR)."""
import math, sys
sys.path.insert(0, 'tools')
from draw import Canvas
G, Y, B, R = 0, 1, 2, 3

def blobbit(c, f):
    """BLOBBIT: a fluffy yellow puff with one huge blue eye and flapping red wings"""
    wa = [-35, 0, 30][f % 3]
    for sgn in (-1, 1):
        c.push(sgn * 7, -11, sgn * wa)
        c.ellipse(sgn * 5, -3, 6, 2.6, R)
        c.ellipse(sgn * 4.5, -3.4, 3.6, 1.2, Y)
        c.pop()
    for i in range(10):                       # scalloped fluff
        a = 2 * math.pi * i / 10
        c.circle(6.8 * math.cos(a), -10 + 6.8 * math.sin(a), 3.2, Y)
    c.circle(0, -10, 7.5, Y)
    c.ellipse(0, -10, 4.6, 4.2, B)
    c.circle(0.8, -10.5, 2.0, R)
    c.circle(-1.6, -12.2, 1.1, Y)             # glint
    c.ellipse(0, -2.2, 2.4, 1.6, R)           # little mouth / feet tuft

def spindle(c, f):
    """SPINDLE: a spinning top drone with a striped skirt and a glowing tip"""
    c.poly([(-9, -12), (9, -12), (2, 0), (-2, 0)], B)
    for k in range(3):                        # rotating stripes
        o = ((k * 6 + f * 2) % 18) - 9
        c.poly([(o, -12), (o + 3, -12), (o * 0.2 + 0.6, 0), (o * 0.2, 0)], R)
    c.ellipse(0, -12.5, 9.5, 3.2, Y)
    c.ellipse(0, -13.2, 6, 1.7, R)
    c.rect(-1.2, -21, 1.2, -14, B)
    c.circle(0, -22, 2.3 if f % 2 else 1.6, Y)

def hopcap(c, f):
    """HOPCAP: a bouncing toadstool with a one-eyed stem (ground creature)"""
    sq = [1.0, 0.8, 1.2][f % 3]
    c.push(0, 0, 0, 1.0 / math.sqrt(sq), sq)
    c.rect(-4, -10, 4, 0, Y)
    c.ellipse(0, -1, 5.5, 1.8, R)
    c.ellipse(0, -6, 2.6, 2.4, B)
    c.circle(0.4, -6.3, 1.2, R)
    c.ellipse(0, -12, 10, 6, R)
    c.rect(-10.5, -12, 10.5, -10, R)
    for x, y, r in ((-5, -14, 1.8), (2, -16, 2.0), (6.5, -12.5, 1.5), (-1.5, -11.5, 1.2)):
        c.circle(x, y, r, Y)
    c.pop()

def lollytree(c, f):
    """LOLLY TREE: a round bushy canopy on a thin red trunk"""
    c.rect(-1.6, -30, 1.6, 0, R)
    c.ellipse(0, 0, 4, 1.2, R)
    for i in range(12):
        a = 2 * math.pi * i / 12
        c.circle(9.5 * math.cos(a), -38 + 10 * math.sin(a), 4.4, G)
    c.circle(0, -38, 10.5, G)
    for x, y in ((-4, -43), (3, -45), (6, -38), (-6, -36), (0, -34), (-1, -40), (4, -31), (-8, -42)):
        c.circle(x, y, 1.4, Y)

def column(c, f):
    """CANDY COLUMN: a tall striped pillar with a blue capital (obstacle)"""
    c.rect(-5, -58, 5, 0, Y)
    for k in range(6):
        y = -6 - k * 9
        c.poly([(-5, y), (5, y - 5), (5, y - 9), (-5, y - 4)], R)
    c.rect(-7.5, -64, 7.5, -57, B)
    c.rect(-6.5, -66, 6.5, -63, Y)
    c.rect(-7.5, 0, 7.5, -3, B)

def bush(c, f):
    """a low round shrub (decoration, harmless)"""
    for x, r in ((-6, 4.5), (6, 4.5), (0, 6)):
        c.circle(x, -4.5, r, G)
    c.circle(-2, -7, 1.2, Y); c.circle(4, -5, 1.0, Y)

def fireball(c, f):
    """enemy shot: a slow, glowing orb with a pulsing ring - easy to see coming"""
    r = [7.0, 6.2][f % 2]
    c.circle(0, -8, r, R)
    c.circle(0, -8, r * 0.72, B)
    c.circle(0, -8, r * 0.48, Y)
    c.circle(-1.2, -9.4, r * 0.18, R)

def spark(c, f):
    """impact sparks (boss hits): a burst of short rays"""
    n = 6; L = [5, 9, 7][f]
    for i in range(n):
        a = math.pi * 2 * i / n + f * 0.5
        c.capsule(math.cos(a) * 2, -8 + math.sin(a) * 2, math.cos(a) * L, -8 + math.sin(a) * L, 1.1, Y)
    c.circle(0, -8, [3, 2, 1][f], R)

def flame(c, f):
    """flickering flames (burning creatures, fires on the ground)"""
    sway = [-1.5, 1.0, 0.0][f]
    c.poly([(-6, 0), (-7 + sway, -8), (-3 + sway, -6), (0 + sway, -16), (3 + sway, -7), (6 + sway, -10), (6, 0)], R)
    c.poly([(-3.5, 0), (-3 + sway * 0.6, -5), (0 + sway * 0.6, -10), (3 + sway * 0.6, -5), (3.5, 0)], Y)

def bolt(c, f):
    """the hero's blaster bolt"""
    c.ellipse(0, -5, 3.2, 5.0, Y)
    c.ellipse(0, -5, 1.4, 3.0, G)

def shadow(c, f):
    """a dithered dark ellipse on the ground (drawn in colour 2, key 0)"""
    c.ellipse(0, -2, 9, 3.2, B)

def orb(c, f):
    """power-up orb: a spinning star in a bubble"""
    c.circle(0, -7, 6.5, B)
    c.circle(0, -7, 5.0, Y)
    w = [3.5, 0.8][f % 2]
    c.poly([(-w, -7), (0, -11.5), (w, -7), (0, -2.5)], R)
    c.poly([(-3.2, -7), (0, -7 - w * 0.5), (3.2, -7), (0, -7 + w * 0.5)], R)

def boom(c, f):
    """explosion starburst, 3 frames"""
    n = 8; r0 = [5, 9, 11][f]; r1 = [2.5, 5, 7][f]
    pts = []
    for i in range(2 * n):
        a = math.pi * i / n + f * 0.3
        rr = r0 if i % 2 == 0 else r1
        pts.append((rr * math.cos(a), -10 + rr * math.sin(a)))
    c.poly(pts, R if f == 2 else Y)
    if f < 2: c.circle(0, -10, r1 * 0.7, G if f == 0 else R)
    else:
        c.circle(0, -10, r1 * 0.55, B)

def wyrmhead(c, f):
    """COILWYRM's head (boss): a blue-scaled serpent with swept-back red horns,
    a long snout, yellow slit eyes and a fanged jaw that snaps open"""
    jaw = [0, 6, 3][f % 3]
    hot = f == 2                              # hit flash: the scales glow
    B_ = Y if hot else B
    for sgn in (-1, 1):                       # horns sweep outwards and back
        c.poly([(sgn * 8, -24), (sgn * 22, -30), (sgn * 26, -36), (sgn * 18, -26), (sgn * 9, -19)], R)
        c.poly([(sgn * 12, -10), (sgn * 21, -6), (sgn * 12, -4)], Y)      # whisker frills
    c.poly([(-9, -12), (9, -12), (6, -2 + jaw), (-6, -2 + jaw)], R)       # lower jaw
    c.poly([(-7, -11), (7, -11), (4, -4 + jaw), (-4, -4 + jaw)], Y)       # inside of the mouth
    for x in (-5, -1.5, 1.5, 5):
        c.poly([(x - 1.2, -12), (x + 1.2, -12), (x, -8)], Y)              # fangs
    c.ellipse(0, -20, 12, 8, B_)                                           # skull
    c.poly([(-6, -16), (6, -16), (4, -9), (-4, -9)], B_)                  # snout
    c.ellipse(-2, -11, 1.2, 0.8, R); c.ellipse(2, -11, 1.2, 0.8, R)       # nostrils
    for sgn in (-1, 1):
        c.ellipse(sgn * 6.5, -21, 3.6, 2.4, B if hot else Y)
        c.ellipse(sgn * 6.5, -21, 0.9, 2.2, R)                             # slit pupils
    for x in (-5, 0, 5):
        c.poly([(x - 2, -27), (x, -31), (x + 2, -27)], R)                  # brow spikes

def wyrmbody(c, f):
    """a body segment: a scaly ball with a yellow belly band and red dorsal spikes"""
    for k in range(3):
        x = -7 + k * 7
        c.poly([(x - 3, -20), (x, -29), (x + 3, -20)], R)
    c.circle(0, -12, 10, B)
    c.ellipse(0, -8, 9, 4, Y)
    c.circle(-3.5, -16, 2, Y)

def wyrmtail(c, f):
    c.poly([(-10, -22), (0, -6), (10, -22), (0, -14)], R)
    c.circle(0, -8, 6, B)
    c.ellipse(0, -5, 5, 2, Y)

# ------------------------------------------------------------ WORLD 2: SUNSET DUNES
def sandray(c, f):
    """SANDRAY: a gliding manta with curling wing tips and a stinger tail"""
    tip = [-4, 0, 4][f % 3]
    c.poly([(-15, -10 + tip), (-6, -14), (0, -16), (6, -14), (15, -10 + tip), (6, -6), (0, -5), (-6, -6)], B)
    c.poly([(-15, -10 + tip), (-12, -13 + tip), (-9, -11)], R)
    c.poly([(15, -10 + tip), (12, -13 + tip), (9, -11)], R)
    c.capsule(0, -6, 0, 2, 0.9, R)
    c.ellipse(-3, -12, 1.6, 1.2, Y); c.ellipse(3, -12, 1.6, 1.2, Y)
    c.ellipse(0, -9, 4, 1.5, Y)

def cactoid(c, f):
    """CACTOID: a stomping one-eyed cactus (ground creature)"""
    st = [0, 3, 0][f % 3]
    c.rect(-4, -26, 4, -4, Y)
    c.ellipse(0, -26, 4, 3, Y)
    c.capsule(-4, -16, -9, -18, 2, Y); c.capsule(-9, -18, -9, -24 + st, 2, Y)
    c.capsule(4, -14, 9, -16, 2, Y); c.capsule(9, -16, 9, -22 - st, 2, Y)
    c.capsule(-2, -4, -3 - st * 0.5, 0, 1.6, B); c.capsule(2, -4, 3 + st * 0.5, 0, 1.6, B)
    c.ellipse(0, -20, 2.6, 2.2, B); c.circle(0.5, -20, 1.1, R)
    for y in (-11, -7): c.rect(-4, y, 4, y + 1, B)

def sundisc(c, f):
    """SUNDISC: a spinning sun-faced saucer with flaring rays"""
    for i in range(8):
        a = math.pi * 2 * i / 8 + f * 0.26
        c.poly([(math.cos(a) * 7, -9 + math.sin(a) * 7), (math.cos(a + 0.2) * 12, -9 + math.sin(a + 0.2) * 12), (math.cos(a + 0.4) * 7, -9 + math.sin(a + 0.4) * 7)], R)
    c.circle(0, -9, 7.5, Y)
    c.circle(-2.6, -10.5, 1.3, B); c.circle(2.6, -10.5, 1.3, B)
    c.ellipse(0, -6.5, 3, 1.1, B)

def saguaro(c, f):
    """a tall many-armed cactus (obstacle)"""
    c.rect(-4, -60, 4, 0, Y)
    c.ellipse(0, -60, 4, 3, Y)
    c.capsule(-4, -30, -11, -32, 2.5, Y); c.capsule(-11, -32, -11, -46, 2.5, Y)
    c.capsule(4, -38, 11, -40, 2.5, Y); c.capsule(11, -40, 11, -52, 2.5, Y)
    for x in (-2, 1.5): c.rect(x, -58, x + 0.8, -2, B)

def obelisk(c, f):
    """a carved sandstone obelisk with an eye glyph (shootable obstacle)"""
    c.poly([(-6, 0), (6, 0), (4, -50), (0, -56), (-4, -50)], Y)
    c.poly([(-6, 0), (-2, 0), (-1.5, -50), (-4, -50)], R)
    c.ellipse(0.5, -38, 2.4, 1.6, B); c.circle(0.5, -38, 0.8, Y)
    for y in (-26, -18, -10): c.rect(-2, y, 4, y + 1.2, B)

def rock(c, f):
    c.ellipse(0, -5, 10, 5.5, G)
    c.ellipse(-3, -7, 4, 2, Y)
    c.ellipse(4, -3, 3, 1.5, R)

def totemcore(c, f):
    """SUN TOTEM's core (boss): a great carved face with a flaming crown"""
    hot = f == 2
    face = G if hot else Y
    for i in range(7):
        x = -12 + i * 4
        c.poly([(x - 2, -36), (x, -48 - (i % 2) * 5), (x + 2, -36)], R)
    c.rect(-14, -38, 14, 0, face)
    c.rect(-14, -38, -10, 0, R)
    m = [0, 4, 2][f % 3]
    D = R if hot else B
    c.rect(-10, -30, -3, -24, D); c.rect(3, -30, 10, -24, D)
    c.rect(-7, -28, -5, -26, Y if not hot else G); c.rect(5, -28, 7, -26, Y if not hot else G)
    c.rect(-2, -22, 2, -14, R)
    c.rect(-9, -10 - m, 9, -5, D)
    for x in (-6, -2, 2, 6): c.rect(x - 1, -10 - m, x + 1, -8 - m, Y)

def firepod(c, f):
    """an orbiting fire pod"""
    c.circle(0, -7, 6, R)
    c.circle(0, -7, 4, Y)
    s = [1, -1][f % 2]
    c.poly([(-2, -12), (0, -17 + s), (2, -12)], R)

def podlink(c, f):
    c.circle(0, -4, 3, B)

# ------------------------------------------------------------ WORLD 3: CRYSTAL NIGHT
def glowmoth(c, f):
    """GLOWMOTH: a fat moth with glowing eye-spot wings"""
    w = [1.0, 0.55, 0.2][f % 3]
    for sgn in (-1, 1):
        c.push(sgn * 3, -10, 0, w, 1)
        c.ellipse(sgn * 7, -3, 8, 6, B)
        c.circle(sgn * 8, -3, 2.5, Y)
        c.circle(sgn * 8, -3, 1.0, R)
        c.pop()
    c.ellipse(0, -9, 3, 7, Y)
    c.capsule(-1, -16, -4, -21, 0.6, Y); c.capsule(1, -16, 4, -21, 0.6, Y)
    c.circle(-1.2, -14, 0.9, R); c.circle(1.2, -14, 0.9, R)

def prism(c, f):
    """PRISM: a spinning crystal shard"""
    w = [8, 5, 2, 5][f % 3]
    c.poly([(0, -24), (w, -12), (0, 0), (-w, -12)], B)
    c.poly([(0, -24), (w * 0.4, -12), (0, 0), (-w * 0.5, -12)], Y)
    c.poly([(-w, -12), (w, -12), (0, -10)], R)

def jellybell(c, f):
    """JELLYBELL: a bobbing jellyfish bell trailing tendrils (low flyer)"""
    sq = [1.0, 0.85, 1.1][f % 3]
    c.push(0, 0, 0, 1 / sq, sq)
    c.ellipse(0, -16, 9, 7, Y)
    c.rect(-9, -16, 9, -12, Y)
    c.ellipse(0, -18, 5, 3, R)
    for x in (-6, -2, 2, 6):
        c.capsule(x, -12, x + [1, -1, 1][f % 3], -3, 0.8, B)
    c.circle(-3, -15, 1, R); c.circle(3, -15, 1, R)
    c.pop()

def spire(c, f):
    """a tall cluster of crystal spires (obstacle)"""
    for x, h, w in ((-5, 52, 4), (2, 64, 5), (8, 40, 3)):
        c.poly([(x - w, 0), (x - w, -h + 10), (x, -h), (x + w, -h + 10), (x + w, 0)], B)
        c.poly([(x, 0), (x, -h), (x + w, -h + 10), (x + w, 0)], Y)

def gemrock(c, f):
    """a boulder studded with gems (shootable)"""
    c.ellipse(0, -9, 12, 9, G)
    for x, y, r in ((-5, -12, 2.5), (3, -8, 3), (6, -14, 2), (-2, -5, 1.8)):
        c.poly([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], Y)

def glowcap(c, f):
    """glowing mushrooms (decoration)"""
    for x, h, r in ((-6, 8, 5), (5, 12, 6)):
        c.rect(x - 1, -h, x + 1, 0, B)
        c.ellipse(x, -h, r, r * 0.6, Y)
        c.circle(x - 1, -h - 1, 1, R)

def shardhead(c, f):
    """SHARDWYRM's head (boss): an angular crystal serpent, jaw of spikes"""
    hot = f == 2
    jaw = [0, 6, 3][f % 3]
    B_ = Y if hot else B
    c.poly([(-12, -18), (0, -34), (12, -18), (8, -10), (-8, -10)], B_)
    c.poly([(-12, -18), (-22, -30), (-9, -24)], R); c.poly([(12, -18), (22, -30), (9, -24)], R)
    c.poly([(-8, -10), (8, -10), (0, -2 + jaw)], R)
    for x in (-4, 0, 4): c.poly([(x - 1.2, -10), (x + 1.2, -10), (x, -6)], Y)
    c.poly([(-8, -22), (-3, -20), (-7, -18)], Y if not hot else R)
    c.poly([(8, -22), (3, -20), (7, -18)], Y if not hot else R)

def shardbody(c, f):
    c.poly([(0, -24), (10, -12), (0, 0), (-10, -12)], B)
    c.poly([(0, -24), (4, -12), (0, 0), (-3, -12)], Y)

def shardtail(c, f):
    c.poly([(0, -20), (6, -8), (0, 0), (-6, -8)], B)
    c.poly([(-8, -18), (0, -8), (8, -18), (0, -12)], R)

# ------------------------------------------------------------ WORLD 4: NEON CITY
def dartjet(c, f):
    """DARTJET: a stubby delta-wing jet fighter, nose on, twin intakes and tail fin"""
    bank = [0, -10, 10][f % 3]
    c.push(0, -10, bank)
    c.poly([(-16, 2), (0, -4), (16, 2), (0, 5)], B)          # delta wing
    c.poly([(-16, 2), (-13, 0), (-10, 3)], R); c.poly([(16, 2), (13, 0), (10, 3)], R)
    c.poly([(-1.5, -12), (1.5, -12), (2.5, -3), (-2.5, -3)], Y)   # fin
    c.ellipse(0, 0, 5, 4.2, Y)                                 # fuselage
    c.circle(0, -0.5, 2.6, B)                                  # canopy
    c.circle(-3.8, 3, 1.5, R); c.circle(3.8, 3, 1.5, R)        # intakes
    c.pop()

def copsaucer(c, f):
    """COPSAUCER: a chunky police saucer with a flashing siren dome"""
    c.ellipse(0, -8, 14, 4.2, Y)
    c.ellipse(0, -6.5, 14, 2.2, B)
    for i, x in enumerate((-9, -3, 3, 9)):
        c.circle(x, -6.5, 1.1, Y if (i + f) % 2 else R)
    c.ellipse(0, -12, 6, 4, B)
    c.ellipse(-1.5, -13, 2.5, 1.6, Y)
    c.rect(-2, -18, 2, -15.5, R if f % 2 else Y)            # siren
    c.ellipse(0, -2.5, 4, 1.4, R)

def gunmech(c, f):
    """GUNMECH: a hulking neo-city walker robot with an arm cannon (big, takes hits)"""
    st = [3, -3][f % 2]
    # legs
    for sgn, s in ((-1, st), (1, -st)):
        c.poly([(sgn * 4, -26), (sgn * 11, -26), (sgn * 12 + s, -12), (sgn * 6 + s, -12)], B)
        c.poly([(sgn * 6 + s, -12), (sgn * 12 + s, -12), (sgn * 13 + s * 1.5, 0), (sgn * 4 + s * 1.5, 0)], Y)
        c.rect(sgn * 2 + s * 1.5 - (6 if sgn > 0 else 9), -2, sgn * 2 + s * 1.5 + (9 if sgn > 0 else 6), 0, R)
    # hull
    c.poly([(-15, -50), (15, -50), (17, -34), (12, -24), (-12, -24), (-17, -34)], Y)
    c.rect(-15, -38, 15, -35, B)
    c.poly([(-6, -50), (6, -50), (4, -56), (-4, -56)], B)     # head
    c.rect(-4, -54, 4, -52, R)                                # visor
    for x in (-10, -5, 0, 5, 10): c.rect(x - 1, -31, x + 1, -27, B)
    # cannon arm (right) and claw (left)
    c.rect(15, -46, 30, -40, B); c.rect(28, -47, 34, -39, R)
    c.circle(33, -43, 2, Y if f % 2 else B)
    c.capsule(-15, -44, -22, -34, 3, B); c.poly([(-25, -34), (-19, -34), (-22, -28)], R)

def tower(c, f):
    """a neon skyscraper slab with lit windows (tall obstacle)"""
    c.rect(-9, -80, 9, 0, B)
    c.rect(-9, -80, -5, 0, R)
    for y in range(-76, -4, 6):
        for x in (-2, 3, 7):
            c.rect(x - 1, y, x + 0.6, y + 2.5, Y)
    c.rect(-6, -86, 6, -80, Y); c.rect(-1, -94, 1, -86, R)

def neonsign(c, f):
    """a lamp pylon carrying a neon sign board (shootable)"""
    c.rect(-1.5, -40, 1.5, 0, R)
    c.rect(-9, -64, 9, -40, B)
    c.rect(-7, -62, 7, -42, Y)
    for y in (-58, -51, -45): c.rect(-5, y, 5, y + 2, B)
    c.ellipse(0, 0, 5, 1.4, R)

def barrier(c, f):
    """a striped road barrier (small, shootable)"""
    c.rect(-12, -12, 12, -6, Y)
    for x in (-10, -2, 6): c.poly([(x, -12), (x + 4, -12), (x + 2, -6), (x - 2, -6)], R)
    c.rect(-10, -6, -8, 0, B); c.rect(8, -6, 10, 0, B)

def mechhead(c, f):
    """MEGAMECH's head (boss): a colossal helmeted robot face, visor and horns"""
    hot = f == 2
    S = Y if not hot else B
    c.poly([(-18, -10), (18, -10), (16, -40), (8, -50), (-8, -50), (-16, -40)], S)
    c.poly([(-18, -38), (-28, -56), (-14, -44)], R); c.poly([(18, -38), (28, -56), (14, -44)], R)
    c.rect(-14, -36, 14, -26, R if hot else B)
    v = [0, 4, 2][f % 3]
    c.rect(-12 + v, -34, -6 + v, -28, Y if not hot else R)
    c.rect(4, -10, 4, -10, R)
    c.rect(-10, -20, 10, -12, B if not hot else R)
    for x in (-7, -3, 1, 5): c.rect(x, -19, x + 2, -13, Y)
    c.rect(-3, -50, 3, -56, B)

def gunpod(c, f):
    """an orbiting gun pod"""
    c.circle(0, -7, 6, B)
    c.circle(0, -7, 3.5, Y)
    c.circle(0, -7, 1.6, R if f % 2 else B)
    c.rect(-8, -8, -5, -6, R); c.rect(5, -8, 8, -6, R)

# ------------------------------------------------------------ WORLD 5: MUSHROOM MARSH
def stoneface(c, f):
    """STONEFACE: a floating carved stone head, heavy brow and glowing eyes"""
    jaw = [0, 3, 1][f % 3]
    c.poly([(-10, -30), (10, -30), (12, -8), (8, -2 - jaw), (-8, -2 - jaw), (-12, -8)], G)
    c.poly([(-10, -30), (-6, -30), (-8, -6), (-12, -8)], Y)
    c.rect(-11, -24, 11, -20, R)                              # brow
    c.rect(-8, -19, -3, -16, Y if f % 3 != 1 else R); c.rect(3, -19, 8, -16, Y if f % 3 != 1 else R)
    c.poly([(-1.5, -16), (1.5, -16), (2.5, -10), (-2.5, -10)], Y)
    c.rect(-6, -7 - jaw, 6, -5 - jaw, R)
    c.ellipse(0, -31, 9, 2.5, Y)

def dragonfly(c, f):
    """BUZZWING: a giant dragonfly, four glassy wings and a long tail"""
    w = [1.0, 0.4, -0.4][f % 3]
    for sgn in (-1, 1):
        for dy, ln in ((-14, 15), (-10, 13)):
            c.push(sgn * 2, dy, sgn * 18 * w)
            c.ellipse(sgn * ln / 2, 0, ln / 2, 2.2, Y)
            c.pop()
    c.capsule(0, -14, 0, 4, 1.6, B, 1.0)
    c.ellipse(0, -15, 3, 3, B)
    c.circle(-2, -17, 1.6, R); c.circle(2, -17, 1.6, R)

def snailops(c, f):
    """SNAILOPS: a huge cyclops snail - one stalked eye, spiral shell (big, takes hits)"""
    s = [0, 3][f % 2]
    c.poly([(-26, 0), (24 + s, 0), (24 + s, -6), (-20, -8)], Y)     # foot
    c.circle(-4, -22, 17, R)                                         # shell
    c.circle(-4, -22, 15, B)
    c.circle(-5, -23, 10, Y); c.circle(-6, -24, 6.5, B); c.circle(-7, -25, 3, Y)
    c.capsule(16 + s, -6, 20 + s, -30, 3, Y)                         # neck / stalk
    c.circle(21 + s, -34, 7, Y)                                      # the eye
    c.circle(22 + s, -34, 4.5, B)
    c.circle(23 + s, -35, 1.8, R)
    c.capsule(14 + s, -8, 26 + s, -12, 1.4, R)

def toadstool(c, f):
    """a giant spotted toadstool (tall obstacle)"""
    c.rect(-5, -50, 5, 0, Y)
    c.ellipse(0, 0, 8, 2, Y)
    c.ellipse(0, -52, 22, 13, R)
    c.rect(-22, -52, 22, -46, R)
    for x, y, r in ((-12, -54, 3.5), (2, -58, 4), (13, -52, 3), (-4, -49, 2.4)):
        c.ellipse(x, y, r, r * 0.75, Y)

def mosspillar(c, f):
    """a mossy standing stone (shootable obstacle)"""
    c.poly([(-8, 0), (8, 0), (7, -50), (0, -58), (-7, -50)], Y)
    c.poly([(-8, 0), (-3, 0), (-3, -52), (-7, -50)], R)
    for y in (-42, -28, -14): c.ellipse(2, y, 6, 2.5, G)
    c.ellipse(0, -2, 10, 2.5, G)

def puffballs(c, f):
    """a clump of puffball fungi (small, shootable)"""
    for x, r in ((-6, 5), (4, 6.5), (11, 3.5)):
        c.circle(x, -r, r, Y)
        c.circle(x - r * 0.3, -r * 1.3, r * 0.3, G)

def pedehead(c, f):
    """BOGAPEDE's head (boss): a huge centipede head with snapping mandibles"""
    hot = f == 2
    m = [0, 7, 3][f % 3]
    c.ellipse(0, -20, 15, 12, Y if not hot else G)
    c.poly([(-12, -12), (-16 - m, -2), (-6, -8)], R); c.poly([(12, -12), (16 + m, -2), (6, -8)], R)
    c.circle(-6, -24, 3.5, R); c.circle(6, -24, 3.5, R)
    c.circle(-6, -25, 1.4, Y if not hot else G); c.circle(6, -25, 1.4, Y if not hot else G)
    c.capsule(-6, -31, -14, -42, 1.2, R); c.capsule(6, -31, 14, -42, 1.2, R)

def pedebody(c, f):
    c.ellipse(0, -12, 12, 9, R)
    c.ellipse(0, -13, 10, 7, Y)
    c.rect(-10, -14, 10, -12, R)
    for sgn in (-1, 1):
        for dx in (4, 9): c.capsule(sgn * dx, -6, sgn * (dx + 4), 2, 1.1, R)

def pedetail(c, f):
    c.ellipse(0, -10, 8, 7, Y)
    c.poly([(-3, -16), (0, -30), (3, -16)], R)
    c.capsule(-6, -4, -9, 2, 1, R); c.capsule(6, -4, 9, 2, 1, R)

# name: (draw, frames, canvas w, canvas h at scale 1, transparent fill threshold, outlined)
OBJECTS = {
    'blobbit': (blobbit, 3, 30, 20),
    'spindle': (spindle, 3, 22, 18),
    'hopcap':  (hopcap, 3, 24, 22),
    'lolly':   (lollytree, 1, 28, 34),
    'column':  (column, 1, 18, 46),
    'bush':    (bush, 1, 22, 10),
    'fireball':(fireball, 2, 12, 9),
    'bolt':    (bolt, 1, 8, 8),
    'boom':    (boom, 3, 26, 18),
    'shadow':  (shadow, 1, 22, 6),
    'sandray': (sandray, 3, 34, 24), 'cactoid': (cactoid, 3, 24, 30), 'sundisc': (sundisc, 3, 28, 24),
    'saguaro': (saguaro, 1, 28, 66), 'obelisk': (obelisk, 1, 16, 60), 'rock': (rock, 1, 24, 12),
    'totemcore': (totemcore, 3, 34, 52), 'firepod': (firepod, 2, 16, 20), 'podlink': (podlink, 1, 10, 8),
    'glowmoth': (glowmoth, 3, 36, 26), 'prism': (prism, 3, 20, 28), 'jellybell': (jellybell, 3, 22, 24),
    'spire': (spire, 1, 28, 68), 'gemrock': (gemrock, 1, 28, 20), 'glowcap': (glowcap, 1, 24, 18),
    'shardhead': (shardhead, 3, 48, 38),
    'dartjet': (dartjet, 3, 36, 26), 'copsaucer': (copsaucer, 2, 30, 22), 'gunmech': (gunmech, 2, 72, 60),
    'tower': (tower, 1, 20, 96), 'neonsign': (neonsign, 1, 20, 66), 'barrier': (barrier, 1, 26, 14),
    'mechhead': (mechhead, 3, 58, 58), 'gunpod': (gunpod, 2, 18, 16),
    'stoneface': (stoneface, 3, 26, 36), 'dragonfly': (dragonfly, 3, 36, 26), 'snailops': (snailops, 2, 60, 52),
    'toadstool': (toadstool, 1, 46, 68), 'mosspillar': (mosspillar, 1, 22, 60), 'puffballs': (puffballs, 1, 32, 16),
    'pedehead': (pedehead, 3, 40, 44), 'pedebody': (pedebody, 1, 28, 22), 'pedetail': (pedetail, 1, 20, 32), 'shardbody': (shardbody, 1, 24, 28), 'shardtail': (shardtail, 1, 20, 24),
    'wyrmhead':(wyrmhead, 3, 44, 44),
    'spark':   (spark, 2, 20, 16),
    'flame':   (flame, 2, 16, 18),
    'wyrmbody':(wyrmbody, 1, 26, 32),
    'wyrmtail':(wyrmtail, 1, 24, 26),
    'orb':     (orb, 2, 16, 12),
}

def render(name, f, s):
    fn, nf, w, h = OBJECTS[name]
    W = max(2, int(math.ceil(w * s)) + 2); Hh = max(2, int(math.ceil(h * s)) + 2)
    c = Canvas(W, Hh, W / 2, Hh - 1)
    c.push(0, 0, 0, s, s)
    fn(c, f)
    c.pop()
    if name == 'shadow':
        g = c.resolve(prio=(R, B, Y, G), outline=None)
        return [[(v if (x + y) & 1 else -1) for x, v in enumerate(r)] for y, r in enumerate(g)]
    return c.resolve(prio=(R, B, Y, G), outline=3 if s > 0.3 else None)

if __name__ == '__main__':
    from draw import crop, preview
    gs = []
    for n in OBJECTS:
        for f in range(OBJECTS[n][1]): gs.append(crop(render(n, f, 1.0))[0])
    preview(gs, 'build/creatures.png', cols=9, scale=5)
