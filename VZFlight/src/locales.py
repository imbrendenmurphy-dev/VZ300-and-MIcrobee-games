"""Locales, scenery shapes and missions for VZ FLIGHT v0.2.

Coordinates: metres, x = east, z = north, y = up.  Headings in degrees (0 = north).
Colour codes are mode(1) pixel bytes: in CSS0 $00 green $55 yellow $AA blue $FF red,
in CSS1 $00 buff $55 cyan $AA magenta $FF orange.
"""
import math

C0, C1, C2, C3 = 0x00, 0x55, 0xAA, 0xFF


# ------------------------------------------------------------------ shape helpers
class Shape:
    def __init__(self):
        self.verts = []
        self.edges = []

    def v(self, x, y, z):
        p = (int(round(x)), int(round(y)), int(round(z)))
        assert all(-64 <= k <= 64 for k in p), p
        if p in self.verts:
            return self.verts.index(p)
        self.verts.append(p)
        return len(self.verts) - 1

    def e(self, a, b, col):
        if a != b:
            self.edges.append((a, b, col))

    def line(self, p, q, col):
        self.e(self.v(*p), self.v(*q), col)

    def poly(self, pts, col, closed=False):
        idx = [self.v(*p) for p in pts]
        for i in range(len(idx) - 1):
            self.e(idx[i], idx[i + 1], col)
        if closed:
            self.e(idx[-1], idx[0], col)

    def box(self, x0, x1, y0, y1, z0, z1, col, top=True, bottom=True, sides=True):
        b = [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)]
        t = [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]
        if bottom:
            self.poly(b, col, True)
        if top:
            self.poly(t, col, True)
        if sides:
            for i in range(4):
                self.line(b[i], t[i], col)

    def octagon(self, cx, y, cz, rx, rz, col):
        pts = [(cx + rx * math.cos(math.radians(22.5 + 45 * i)), y, cz + rz * math.sin(math.radians(22.5 + 45 * i)))
               for i in range(8)]
        self.poly(pts, col, True)
        return pts


def runway(axis, half_len, half_w, col, dash):
    s = Shape()
    L, W = half_len, half_w
    if axis == 'ns':
        s.poly([(-W, 0, -L), (W, 0, -L), (W, 0, L), (-W, 0, L)], col, True)
        for a in (-0.75, -0.25, 0.25):
            s.line((0, 0, a * L), (0, 0, (a + 0.25) * L), dash)
    else:
        s.poly([(-L, 0, -W), (L, 0, -W), (L, 0, W), (-L, 0, W)], col, True)
        for a in (-0.75, -0.25, 0.25):
            s.line((a * L, 0, 0), ((a + 0.25) * L, 0, 0), dash)
    return s


def boxshape(hx, h, hz, col):
    s = Shape()
    s.box(-hx, hx, 0, h, -hz, hz, col, bottom=False)
    return s


def helipad(col, r=8):
    s = Shape()
    s.poly([(-r, 0, -r), (r, 0, -r), (r, 0, r), (-r, 0, r)], col, True)
    s.line((-r / 2, 0, -r / 2), (-r / 2, 0, r / 2), col)
    s.line((r / 2, 0, -r / 2), (r / 2, 0, r / 2), col)
    s.line((-r / 2, 0, 0), (r / 2, 0, 0), col)
    return s


def hoop(axis, c_side, c_top):
    """gate frame 64 wide x 32 tall.  axis = direction you fly through it"""
    s = Shape()
    if axis == 'z':
        a, b, c, d = (-32, 0, 0), (32, 0, 0), (32, 32, 0), (-32, 32, 0)
    else:
        a, b, c, d = (0, 0, -32), (0, 0, 32), (0, 32, 32), (0, 32, -32)
    s.line(a, d, c_side)
    s.line(b, c, c_side)
    s.line(d, c, c_top)
    s.line(a, b, c_top)
    return s


# ------------------------------------------------------------------ scenery shapes
SHAPES = {}

# --- generic
SHAPES['hoop_x'] = hoop('x', C3, C1)
SHAPES['hoop_z'] = hoop('z', C3, C1)
SHAPES['hoop_x1'] = hoop('x', C3, C2)     # polar colours
SHAPES['hoop_z1'] = hoop('z', C3, C2)

# --- aircraft models for the title screen (s=0, 1 m units)
cess = Shape()
Y, R_ = C1, C3
cess.poly([(0, 0, 14), (-2, 1, 8), (-2, 3, 4), (-1, 2, -22), (1, 2, -22), (2, 3, 4), (2, 1, 8)], R_, True)
cess.line((0, 0, 14), (0, 4, 6), Y)                   # windscreen line
cess.poly([(-32, 5, 6), (32, 5, 6), (32, 5, 0), (-32, 5, 0)], Y, True)   # high wing
cess.line((-2, 3, 4), (-12, 5, 3), R_)                # struts
cess.line((2, 3, 4), (12, 5, 3), R_)
cess.poly([(-10, 2, -18), (10, 2, -18), (10, 2, -22), (-10, 2, -22)], Y, True)  # tailplane
cess.poly([(0, 2, -16), (0, 9, -21), (0, 9, -24), (0, 2, -22)], Y)       # fin
cess.line((-3, -4, 8), (3, -4, 8), R_)                # undercarriage
cess.line((-3, -4, 8), (-2, 1, 8), R_)
cess.line((3, -4, 8), (2, 1, 8), R_)
SHAPES['cessna'] = cess

heli = Shape()
heli.poly([(0, 2, 12), (-4, 4, 8), (-4, 9, 2), (-4, 9, -6), (-4, 2, -6), (-4, 0, 2)], R_, True)
heli.poly([(0, 2, 12), (4, 4, 8), (4, 9, 2), (4, 9, -6), (4, 2, -6), (4, 0, 2)], R_, True)
heli.line((-4, 0, 2), (4, 0, 2), R_)
heli.line((-4, 9, 2), (4, 9, 2), R_)
heli.line((-1, 7, -6), (0, 8, -30), Y)               # tail boom
heli.line((-1, 3, -6), (0, 7, -30), Y)
heli.poly([(0, 7, -30), (0, 13, -34), (0, 4, -33)], Y, True)   # tail fin
heli.line((0, 11, -2), (0, 9, -2), Y)               # mast
heli.line((-30, 11, -2), (30, 11, -2), Y)           # rotor
heli.line((0, 11, -32), (0, 11, 28), Y)
heli.line((-6, -3, 10), (-6, -3, -10), R_)          # skids
heli.line((6, -3, 10), (6, -3, -10), R_)
heli.line((-6, -3, 4), (-4, 0, 2), R_)
heli.line((6, -3, 4), (4, 0, 2), R_)
SHAPES['heli'] = heli

# --- SYDNEY ------------------------------------------------------
SHAPES['rwy_bank'] = runway('ew', 64, 2, C3, C1)        # s=4: 2 km x 64 m
SHAPES['hangar'] = boxshape(6, 4, 8, C3)               # s=2
SHAPES['ctower'] = boxshape(2, 10, 2, C1)              # s=2

br = Shape()     # Sydney Harbour Bridge, spans north-south, s=3 (8 m units)
for xx in (-3, 3):
    br.line((xx, 6, -64), (xx, 6, 64), C1)              # deck edges, 48 m
for zz in (-32, 32):
    for xx in (-3, 3):
        br.line((xx, 0, zz), (xx, 11, zz), C1)          # pylons, 89 m
arch = [(0, 2 + 15 * (1 - (z / 32.0) ** 2), z) for z in range(-32, 33, 8)]
br.poly(arch, C3)                                       # the coathanger
for z in (-16, -8, 0, 8, 16):
    yy = 2 + 15 * (1 - (z / 32.0) ** 2)
    br.line((0, yy, z), (0, 6, z), C3)                  # hangers
SHAPES['bridge'] = br

op = Shape()     # Opera House, s=2 (4 m units)
op.poly([(-14, 3, -22), (14, 3, -22), (14, 3, 22), (-14, 3, 22)], C1, True)   # podium
for xc in (-6, 6):
    for (zk, hk) in ((14, 17), (4, 14), (-6, 10)):
        op.poly([(xc - 5, 3, zk), (xc, hk, zk + 6), (xc + 5, 3, zk)], C1)
SHAPES['opera'] = op

tw = Shape()     # Sydney Tower, s=3
tw.line((0, 0, 0), (0, 30, 0), C1)
tw.poly([(-2, 30, -2), (2, 30, -2), (2, 30, 2), (-2, 30, 2)], C3, True)
tw.poly([(-2, 33, -2), (2, 33, -2), (2, 33, 2), (-2, 33, 2)], C3, True)
tw.line((0, 33, 0), (0, 39, 0), C1)
SHAPES['sydtower'] = tw
SHAPES['bld_tall'] = boxshape(5, 22, 5, C3)            # s=3
SHAPES['bld_mid'] = boxshape(6, 12, 4, C1)             # s=3

hb = Shape()     # harbour shoreline, s=6 (64 m units)
north = [(-4000, 320), (-2000, 380), (-800, 300), (0, 260), (900, 420), (2200, 700), (4000, 950)]
south = [(-4000, -180), (-1100, -280), (-950, -1150), (-600, -1150), (-450, -330), (150, -300), (300, -560),
         (500, -560), (620, -250), (900, -480), (1600, -350), (2600, -600), (4000, -720)]
hb.poly([(x / 64.0, 0, z / 64.0) for x, z in north], C2)
hb.poly([(x / 64.0, 0, z / 64.0) for x, z in south], C2)
SHAPES['harbour'] = hb
SHAPES['pad'] = helipad(C3)                             # s=2: 64 m square

# --- MID-PACIFIC -------------------------------------------------
sh = Shape()     # cargo ship heading north, s=2 (4 m units): 48 m beam, ~350 m long
deck = [(-6, 4, -40), (6, 4, -40), (6, 4, 32), (0, 4, 44), (-6, 4, 32)]
wl = [(x, 0, z) for x, y, z in deck]
sh.poly(deck, C3, True)
sh.poly(wl, C3, True)
for p, q in zip(deck, wl):
    sh.line(p, q, C3)
sh.box(-5, 5, 4, 12, -40, -32, C1, bottom=False)       # bridge house
sh.line((0, 12, -36), (0, 16, -36), C1)                 # mast
for z in (-24, -12, 8):                                 # container stacks
    sh.line((-5, 6, z), (5, 6, z), C0)
sh.poly([(-4, 4.01, 14), (4, 4.01, 14), (4, 4.01, 26), (-4, 4.01, 26)], C1, True)   # deck pad
sh.line((-2, 4, 17), (-2, 4, 23), C1)
sh.line((2, 4, 17), (2, 4, 23), C1)
sh.line((-2, 4, 20), (2, 4, 20), C1)
SHAPES['ship'] = sh

cl = Shape()     # flat cloud, s=4
cl.octagon(0, 0, 0, 40, 24, C0)
cl.octagon(0, 3, 0, 26, 14, C0)
SHAPES['cloud'] = cl

# --- RED CENTRE --------------------------------------------------
ul = Shape()     # Uluru, s=5 (32 m units): 3.6 km x 1.9 km, 350 m
ul.octagon(0, 0, 0, 56, 30, C3)
ul.octagon(2, 11, 0, 44, 20, C3)
for i in range(8):
    a = math.radians(22.5 + 45 * i)
    ul.line((56 * math.cos(a), 0, 30 * math.sin(a)), (2 + 44 * math.cos(a), 11, 20 * math.sin(a)), C3)
SHAPES['uluru'] = ul

dm = Shape()     # Kata Tjuta dome, s=4
o1 = dm.octagon(0, 0, 0, 30, 30, C3)
o2 = dm.octagon(0, 18, 0, 18, 18, C3)
dm.line((0, 18, 0), (0, 24, 0), C3)
for i in (0, 2, 4, 6):
    dm.line(o1[i], o2[i], C3)
SHAPES['dome'] = dm
SHAPES['rwy_ayers'] = runway('ns', 64, 2, C2, C0)      # s=4
SHAPES['rwy_dirt'] = runway('ns', 64, 3, C3, C3)       # s=3: 1 km dirt strip
SHAPES['shed'] = boxshape(5, 3, 8, C2)                 # s=2
SHAPES['resort'] = boxshape(10, 3, 4, C2)              # s=3
SHAPES['pad_rc'] = helipad(C2)

# --- NORTH POLE (CSS1) --------------------------------------------
pole = Shape()   # s=0 (1 m units)
for i in range(4):
    pole.line((0, i * 3, 0), (0, i * 3 + 3, 0), C3 if i % 2 == 0 else C2)
pole.poly([(0, 12, 0), (0, 12, 8), (0, 9, 8), (0, 9, 0)], C3)          # flag
pole.octagon(0, 0, 0, 40, 40, C2)                                        # landing ring
SHAPES['pole'] = pole
SHAPES['hut'] = boxshape(4, 3, 6, C3)                  # s=2
SHAPES['drums'] = boxshape(3, 1, 3, C2)                # s=2
SHAPES['mast'] = Shape()
SHAPES['mast'].line((0, 0, 0), (0, 40, 0), C2)
SHAPES['mast'].line((-8, 0, 0), (0, 40, 0), C2)
SHAPES['mast'].line((8, 0, 0), (0, 40, 0), C2)
SHAPES['rwy_ice'] = runway('ns', 64, 3, C3, C2)        # s=3
SHAPES['pad_ice'] = helipad(C3)
rd = Shape()     # pressure ridge, s=4
rd.poly([(-60, 0, 0), (-40, 2, 6), (-20, 0, -4), (0, 3, 4), (20, 0, -6), (40, 2, 2), (60, 0, 0)], C2)
SHAPES['ridge'] = rd


# ------------------------------------------------------------------ locales
def O(shape, x, z, s, vis, fl=0, yoff=0):
    """scenery object: vis = cull distance x256 m, fl = fine-mode distance x256 m (0 = never)"""
    return (shape, x, z, s, vis, fl, yoff)


def gate(x, z, axis, s, bottom, polar=False):
    r = 32 << s
    return dict(type=1, x=x, z=z, r=r, ylo=bottom - 10, yhi=bottom + (32 << s) + 10,
                shape='hoop_%s%s' % (axis, '1' if polar else ''), s=s, yoff=bottom // 8)


def under(x, z, r, yhi):
    return dict(type=1, x=x, z=z, r=r, ylo=-50, yhi=yhi, shape=None, s=0, yoff=0)


def land(x, z, r):
    return dict(type=2, x=x, z=z, r=r, ylo=0, yhi=0, shape=None, s=0, yoff=0)


def shipland(dx, dz, r):
    return dict(type=3, x=dx, z=dz, r=r, ylo=0, yhi=0, shape=None, s=0, yoff=0)


def shipgate(dx, dz, r, yhi):
    return dict(type=4, x=dx, z=dz, r=r, ylo=-50, yhi=yhi, shape=None, s=0, yoff=0)


def M(title, brief, craft, x, z, y, hdg, spd, thr, gnd, fuel, par, goals):
    assert len(title) <= 18, title
    for l in brief:
        assert len(l) <= 30, l
    assert len(brief) <= 7
    return dict(title=title, brief=brief, craft=craft, x=x, z=z, y=y, hdg=hdg, spd=spd, thr=thr,
                gnd=gnd, fuel=fuel, par=par, goals=goals)


PLANE, HELI = 0, 1

LOCALES = []

# ---------------------------------------------------------------- SYDNEY
LOCALES.append(dict(
    key='syd', name='SYDNEY', year='BANKSTOWN TO THE BRIDGE',
    desc=['HARBOUR, BRIDGE, OPERA HOUSE,', 'TOWER AND BANKSTOWN AIRPORT.'],
    css=0, sky=C2, gnd=C0, grid=C1, water=0, ink=C1,
    objects=[
        O('rwy_bank', -6000, 0, 4, 44, 3),
        O('hangar', -5600, -300, 2, 20, 6),
        O('hangar', -5400, -300, 2, 20, 6),
        O('ctower', -6200, -280, 2, 20, 6),
        O('harbour', 0, 0, 6, 62),
        O('bridge', 0, 0, 3, 40, 5),
        O('opera', 680, -330, 2, 32, 5),
        O('sydtower', 250, -1050, 3, 44, 5),
        O('bld_tall', 450, -800, 3, 30, 5),
        O('bld_mid', 0, -900, 3, 30, 5),
        O('bld_tall', -150, -1300, 3, 30, 5),
        O('pad', -750, -1300, 2, 20, 6),
    ],
    obstacles=[
        ('box', 0, 0, 26, 520, 42, 58),          # bridge deck
        ('box', 0, 0, 20, 230, 58, 140),         # arch
        ('box', 0, 256, 30, 20, 0, 90),          # pylons
        ('box', 0, -256, 30, 20, 0, 90),
        ('box', 250, -1050, 18, 18, 0, 310),     # Sydney Tower
        ('box', 450, -800, 38, 38, 0, 175),
        ('box', 0, -900, 46, 30, 0, 95),
        ('box', -150, -1300, 38, 38, 0, 175),
        ('box', 680, -330, 45, 70, 0, 60),       # Opera House
    ],
    platforms=[],
    ship=None,
    missions=[
        M('FIRST SOLO', [
            '1972: DICK SMITH LEARNED TO',
            'FLY AT BANKSTOWN. YOUR TURN!',
            'TAKE OFF EASTBOUND, FLY THE',
            'CIRCUIT GATES, THEN LAND',
            'BACK ON THE RUNWAY.',
            'FULL THROTTLE (W), THEN HOLD',
            'Q TO LIFT OFF AT 55 KNOTS.'],
          PLANE, -6900, 0, 0, 90, 0, 0, 1, 0, 300,
          [gate(-4000, 0, 'x', 3, 120), gate(-3300, 2400, 'z', 3, 150), gate(-8000, 2600, 'x', 3, 150),
           gate(-9200, 0, 'z', 3, 60), land(-6000, 0, 1100)]),
        M('HARBOUR HOMECOMING', [
            'ON HIS 1982-83 SOLO FLIGHT',
            'AROUND THE WORLD, DICK SMITH',
            'FLEW HIS HELICOPTER UNDER THE',
            'HARBOUR BRIDGE, THEN LANDED',
            'AT DARLING HARBOUR.',
            'STAY BELOW 44M UNDER THE',
            'DECK, THEN SET DOWN ON THE H.'],
          HELI, 3200, 40, 120, 270, 15, 128, 0, 0, 150,
          [under(0, 0, 80, 44), land(-750, -1300, 40)]),
        M('HARBOUR SCENIC', [
            'A SCENIC FLIGHT OVER THE',
            'HARBOUR CITY. FLY THROUGH',
            'EVERY GATE: OVER THE BRIDGE,',
            'PAST THE OPERA HOUSE, AROUND',
            'SYDNEY TOWER AND BACK UP THE',
            'HARBOUR. NO LANDING NEEDED.'],
          PLANE, -3200, 0, 300, 90, 50, 180, 0, 0, 200,
          [gate(0, 0, 'x', 2, 180), gate(800, -420, 'x', 2, 100), gate(2600, -900, 'z', 3, 150),
           gate(1400, -2600, 'x', 3, 150), gate(-200, -1700, 'z', 2, 200), gate(-2000, -300, 'x', 3, 150),
           gate(-3600, 0, 'x', 2, 60)]),
        M('FREE FLIGHT', [
            'NO GATES, NO CLOCK. TAKE OFF',
            'FROM BANKSTOWN AND EXPLORE.',
            'TRY FLYING UNDER THE BRIDGE!',
            '',
            'P PAUSES. RETURN IN THE PAUSE',
            'MENU GOES BACK TO THE MENU.'],
          PLANE, -6900, 0, 0, 90, 0, 0, 1, 0, 0, []),
    ]))

# ---------------------------------------------------------------- MID-PACIFIC
LOCALES.append(dict(
    key='pac', name='MID-PACIFIC', year='SHIP DECK REFUEL',
    desc=['OPEN OCEAN AT SUNSET AND A', 'CARGO SHIP STEAMING NORTH.'],
    css=0, sky=C1, gnd=C2, grid=C0, water=1, ink=C3,
    objects=[
        O('ship', 0, 0, 2, 40, 5),
        O('cloud', -3000, 2000, 4, 40, 0, 110),
        O('cloud', 2500, -1500, 4, 40, 0, 130),
        O('cloud', 4000, 5000, 4, 40, 0, 100),
        O('cloud', -5000, -4000, 4, 40, 0, 120),
        O('cloud', 1000, 7000, 4, 40, 0, 140),
    ],
    obstacles=[
        ('shipbox', 0, -144, 22, 18, 16, 50),
    ],
    platforms=[('ship', 0, 0, 24, 150, 16)],
    ship=dict(obj=0, speed=6),
    missions=[
        M('SHIP DECK REFUEL', [
            '1983: CROSSING THE PACIFIC,',
            'DICK SMITH REFUELLED BY',
            'LANDING ON A CARGO SHIP,',
            'FOUND WITH A HOME-MADE RADIO',
            'BEACON. FOLLOW THE ARROW AND',
            'LAND ON THE DECK PAD BEFORE',
            'YOUR FUEL RUNS OUT.'],
          HELI, -2500, -3200, 300, 40, 25, 140, 0, 5000, 200,
          [shipland(0, 80, 30)]),
        M('LOW PASS', [
            'PRACTISE YOUR NAVIGATION.',
            'FLY THROUGH THE CLOUD GATES,',
            'THEN MAKE A LOW PASS OVER',
            'THE SHIP BELOW 100 METRES.',
            '',
            'THE SHIP KEEPS MOVING!'],
          PLANE, -6000, -3000, 500, 60, 50, 180, 0, 0, 200,
          [gate(-3000, 0, 'z', 3, 400), gate(1500, 2500, 'x', 3, 500), gate(4000, -1000, 'z', 3, 300),
           shipgate(0, 0, 200, 100)]),
        M('FREE FLIGHT', [
            'UNLIMITED FUEL. PRACTISE',
            'LANDING THE HELICOPTER ON',
            'THE MOVING SHIP. MATCH ITS',
            'SPEED AND COME DOWN GENTLY.'],
          HELI, -600, -600, 150, 0, 0, 140, 0, 0, 0, []),
    ]))

# ---------------------------------------------------------------- RED CENTRE
LOCALES.append(dict(
    key='rc', name='RED CENTRE', year='ULURU AND KATA TJUTA',
    desc=['DESERT, SPINIFEX AND THE ROCK.', 'PLEASE DO NOT OVERFLY ULURU.'],
    css=0, sky=C2, gnd=C1, grid=C0, water=0, ink=C3,
    objects=[
        O('uluru', 0, 0, 5, 62),
        O('dome', -6200, 1800, 4, 62),
        O('dome', -5600, 2600, 4, 62),
        O('dome', -6900, 2500, 3, 62),
        O('rwy_ayers', 1500, 7000, 4, 44, 3),
        O('shed', 1800, 6600, 2, 20, 6),
        O('shed', 1800, 6800, 2, 20, 6),
        O('resort', 2600, 5200, 3, 30, 5),
        O('pad_rc', -4700, 900, 2, 20, 6),
        O('pad_rc', 1300, 6100, 2, 20, 6),
        O('rwy_dirt', -2000, -6000, 3, 36, 5),
        O('shed', -1700, -6200, 2, 20, 6),
    ],
    obstacles=[
        ('box', 0, 0, 1650, 880, -100, 345),
        ('pyr', -6200, 1800, 480),
        ('pyr', -5600, 2600, 480),
        ('pyr', -6900, 2500, 240),
    ],
    platforms=[],
    ship=None,
    missions=[
        M('ROCK CIRCUIT', [
            'FLY A RESPECTFUL CIRCUIT OF',
            'ULURU THROUGH THE FOUR GATES,',
            'THEN LAND AT THE AIRPORT TO',
            'THE NORTH.',
            '',
            'DO NOT FLY OVER THE ROCK.'],
          PLANE, 1500, 4500, 500, 180, 50, 180, 0, 0, 330,
          [gate(0, 2600, 'x', 3, 300), gate(3200, 0, 'z', 3, 300), gate(0, -2600, 'x', 3, 300),
           gate(-3200, 0, 'z', 3, 300), land(1500, 7000, 1100)]),
        M('KATA TJUTA HOP', [
            'A HELICOPTER SCENIC FLIGHT.',
            'LIFT OFF FROM THE AIRPORT PAD',
            '(HOLD W), FLY OUT TO KATA',
            'TJUTA AND LAND ON THE',
            'LOOKOUT PAD BY THE DOMES.'],
          HELI, 1300, 6100, 0, 225, 0, 100, 1, 0, 240,
          [gate(-2500, 3000, 'x', 3, 150), land(-4700, 900, 40)]),
        M('OUTBACK STRIP', [
            'THE STATION NEEDS THE MAIL.',
            'TAKE OFF FROM AYERS ROCK',
            'AIRPORT AND LAND ON THE',
            'SHORT DIRT STRIP 13 KM SOUTH',
            'WEST, PAST THE ROCK.'],
          PLANE, 1500, 6200, 0, 180, 0, 0, 1, 0, 300,
          [land(-2000, -6000, 600)]),
        M('FREE FLIGHT', [
            'NO GATES, NO CLOCK.',
            'EXPLORE THE RED CENTRE FROM',
            'AYERS ROCK AIRPORT.'],
          PLANE, 1500, 6200, 0, 180, 0, 0, 1, 0, 0, []),
    ]))

# ---------------------------------------------------------------- NORTH POLE
LOCALES.append(dict(
    key='np', name='NORTH POLE', year='TOP OF THE WORLD',
    desc=['SEA ICE, PRESSURE RIDGES AND', 'A FUEL CAMP 7 KM FROM THE POLE.'],
    css=0x10, sky=C1, gnd=C0, grid=C2, water=0, ink=C3,
    objects=[
        O('pole', 0, 0, 0, 30, 6),
        O('hut', 300, -7300, 2, 20, 6),
        O('hut', 380, -7200, 2, 20, 6),
        O('drums', 220, -7050, 2, 16, 6),
        O('mast', 450, -7350, 1, 20, 6),
        O('pad_ice', 0, -7000, 2, 20, 6),
        O('rwy_ice', -500, -7000, 3, 36, 5),
        O('rwy_ice', -400, 1200, 3, 36, 5),
        O('ridge', -2000, -3000, 4, 40),
        O('ridge', 1500, -4500, 4, 40),
        O('ridge', 1000, -1500, 4, 40),
        O('ridge', -1800, 2500, 4, 40),
        O('ridge', 2500, 3000, 4, 40),
    ],
    obstacles=[('box', 340, -7250, 60, 90, 0, 14), ('box', 450, -7350, 10, 10, 0, 42)],
    platforms=[],
    ship=None,
    missions=[
        M('TOP OF THE WORLD', [
            '1987: ON HIS THIRD ATTEMPT,',
            'DICK SMITH MADE THE FIRST',
            'SOLO HELICOPTER FLIGHT TO',
            'THE NORTH POLE. LIFT OFF',
            'FROM THE CAMP (HOLD W), FLY',
            'DUE NORTH AND LAND INSIDE',
            'THE RING. WATCH YOUR FUEL!'],
          HELI, 0, -7000, 0, 0, 0, 100, 1, 7000, 240,
          [land(0, 0, 45)]),
        M('POLE TO POLE', [
            '1988-89: DICK SMITH AND',
            'GILES KERSHAW FLEW A TWIN',
            'OTTER AROUND THE WORLD',
            'VIA BOTH POLES. FLY FROM',
            'THE CAMP STRIP AND LAND ON',
            'THE ICE STRIP BY THE POLE.'],
          PLANE, -500, -7400, 0, 0, 0, 0, 1, 0, 300,
          [gate(-400, -2000, 'z', 3, 200, polar=True), land(-400, 1200, 520)]),
        M('FREE FLIGHT', [
            'UNLIMITED FUEL. EVERY WAY',
            'FROM THE POLE IS SOUTH!',
            'EXPLORE THE ICE BY',
            'HELICOPTER.'],
          HELI, 0, -7000, 0, 0, 0, 100, 1, 0, 0, []),
    ]))

# demo flight (attract mode): Sydney, autopilot waypoints (x, z, altitude)
DEMO = dict(loc=0, x=-1900, z=40, y=210, hdg=90, spd=52, thr=190,
            wps=[(400, 0, 210), (1500, -500, 230), (2200, -1500, 260), (900, -2300, 280),
                 (-1300, -1800, 260), (-2600, -300, 230)])
