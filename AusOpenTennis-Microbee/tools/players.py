"""Animated tennis players for MICROBEE AUSTRALIAN OPEN TENNIS.

A jointed puppet is posed for every animation frame, drawn at high
resolution as body-part labels, then reduced to Microbee pixels (pixels
1.5x taller than wide). Cloth is solid ink, skin is a 50% checker (reads
as a lighter tone of the player's colour), racket strings are sparse dots.

Bodies are shared by everyone; each character has its own head sprite
(hair, hats, glasses, beard), drawn at the frame's head point.
Two views: NEAR (seen from behind, big) and FAR (facing us, smaller).
"""
import math
import numpy as np
from PIL import Image, ImageDraw

SS = 4                     # high-res pixels per unit (square)
EMPTY, SHIRT, SHORTS, SKIN, SHOE, FRAME, STRINGS, HAIR, FACE, EYE, SOCK, ARM = range(12)

# body proportions in units (1 unit = 1 screen pixel across at NEAR scale)
FOOT, KNEE, HIP, SHO, NECK = 0, 17, 31, 49, 52
HEADR = 5.0
SHW, HIPW = 7.5, 5.5        # half widths
THIGH, SHIN = 15.5, 15.5
UPPER, FORE = 11.5, 10.5
RLEN, RHW, RHH = 11.0, 4.6, 6.4  # racket handle, head half sizes


def vec(a, r):
    """angle in degrees: 0 = down, 90 = screen right, 180 = up; y up"""
    t = math.radians(a)
    return math.sin(t) * r, -math.cos(t) * r


class Puppet:
    def __init__(self, scale=1.0, mirror=False):
        self.k = scale
        self.mirror = mirror
        self.W, self.H = 72, 84            # units, canvas
        self.ox, self.oy = 36, 6           # feet point in canvas units (from bottom)
        self.img = Image.new('L', (self.W * SS, self.H * SS), EMPTY)
        self.d = ImageDraw.Draw(self.img)

    def P(self, x, y):
        k = self.k
        if self.mirror:
            x = -x
        return ((self.ox + x * k) * SS, (self.H - self.oy - y * k) * SS)

    def seg(self, a, b, w, lab):
        (x0, y0), (x1, y1) = self.P(*a), self.P(*b)
        r = w * self.k * SS / 2
        self.d.line([(x0, y0), (x1, y1)], fill=lab, width=max(1, int(round(2 * r))))
        for x, y in ((x0, y0), (x1, y1)):
            self.d.ellipse([x - r, y - r, x + r, y + r], fill=lab)

    def poly(self, pts, lab):
        self.d.polygon([self.P(*p) for p in pts], fill=lab)

    def ell(self, c, rx, ry, lab, ang=0.0):
        cx, cy = self.P(*c)
        pts = []
        t = math.radians(ang if not self.mirror else -ang)
        for i in range(24):
            u = 2 * math.pi * i / 24
            x, y = rx * math.cos(u), ry * math.sin(u)
            xr, yr = x * math.cos(t) - y * math.sin(t), x * math.sin(t) + y * math.cos(t)
            pts.append((cx + xr * self.k * SS, cy - yr * self.k * SS))
        self.d.polygon(pts, fill=lab)


def draw_pose(pp, pose):
    """pose keys (degrees; 0 = down, + = towards screen right):
       x (hip shift), drop (crouch), lean (torso, + right), legs [(thigh, shin, foot_dir) L, R],
       armR (upper, fore), armL (upper, fore), rack (racket angle), rhand ('R'/'L'/'B' both),
       behind (draw the racket arm behind the body)"""
    x0 = pose.get('x', 0.0)
    hipy = HIP - pose.get('drop', 0.0)
    lean = pose.get('lean', 0.0)
    hip = (x0, hipy)
    tx, ty = vec(180 + lean, SHO - HIP)
    sho = (x0 + tx, hipy + ty)
    neck = (sho[0] + vec(180 + lean, 3)[0], sho[1] + 3)
    head = (neck[0] + vec(180 + lean * 1.2, HEADR + 1)[0] + pose.get('hx', 0), neck[1] + HEADR + 1 + pose.get('hy', 0))
    # legs: L leg at hip - , R leg at hip +
    feet = []
    legs = pose.get('legs', [(-6, -4), (6, 4)])
    knees = []
    for side, (ta, sa) in zip((-1, 1), legs):
        hp = (x0 + side * 2.6, hipy)
        kx, ky = vec(ta, THIGH)
        kn = (hp[0] + kx, hp[1] + ky)
        sx, sy = vec(sa, SHIN)
        ft = (kn[0] + sx, kn[1] + sy)
        knees.append((hp, kn, ft))
    # shoulders
    sL = (sho[0] - SHW + 1.5, sho[1] - 1)
    sR = (sho[0] + SHW - 1.5, sho[1] - 1)

    def arm(s, upper, fore):
        ex, ey = vec(upper, UPPER)
        el = (s[0] + ex, s[1] + ey)
        hx, hy = vec(fore, FORE)
        hd = (el[0] + hx, el[1] + hy)
        return el, hd
    elR, hR = arm(sR, *pose.get('armR', (8, 20)))
    elL, hL = arm(sL, *pose.get('armL', (-8, -20)))
    if pose.get('rhand') == 'B':          # two hands on the racket: left hand joins the right
        hL = (hR[0] - 1.5, hR[1] + 0.5)
        mx, my = (sL[0] + hL[0]) / 2, (sL[1] + hL[1]) / 2
        elL = (mx - 1.0, my - 2.5)
    ra = pose.get('rack', 160)
    rv = vec(ra, 1)
    rhandle = (hR[0] + rv[0] * RLEN, hR[1] + rv[1] * RLEN)
    rcen = (hR[0] + rv[0] * (RLEN + RHH), hR[1] + rv[1] * (RLEN + RHH))
    face = pose.get('face', 1.0)          # 1 face-on, 0.35 edge-on

    def draw_racket():
        pp.seg(hR, rhandle, 1.6, FRAME)
        ang = math.degrees(math.atan2(rv[1], rv[0])) - 90
        pp.ell(rcen, RHW * face + 0.9, RHH + 0.9, FRAME, ang)
        if RHW * face - 0.9 > 0.6:
            pp.ell(rcen, RHW * face - 0.9, RHH - 0.9, STRINGS, ang)

    def draw_arm(s, el, hd, sleeve=True):
        pp.seg(s, el, 3.2, ARM)
        pp.seg(el, hd, 2.8, ARM)
        if sleeve:
            m = (s[0] + (el[0] - s[0]) * 0.4, s[1] + (el[1] - s[1]) * 0.4)
            pp.seg(s, m, 4.0, SHIRT)
        pp.ell(hd, 1.7, 1.7, ARM)

    behind = pose.get('behind', False)
    if behind:
        draw_racket()
        draw_arm(sR, elR, hR)
    if pose.get('larm_behind', False):
        draw_arm(sL, elL, hL)
    # legs
    for hp, kn, ft in knees:
        pp.seg(hp, kn, 4.6, SKIN)
        pp.seg(kn, ft, 3.8, SKIN)
        # sock + shoe
        sv = (ft[0] + (kn[0] - ft[0]) * 0.22, ft[1] + (kn[1] - ft[1]) * 0.22)
        pp.seg(ft, sv, 3.8, SOCK)
        pp.ell((ft[0], ft[1] + 0.6), 3.0, 1.9, SHOE)
    # shorts
    (hpL, knL, _), (hpR, knR, _) = knees
    mL = (hpL[0] + (knL[0] - hpL[0]) * 0.42, hpL[1] + (knL[1] - hpL[1]) * 0.42)
    mR = (hpR[0] + (knR[0] - hpR[0]) * 0.42, hpR[1] + (knR[1] - hpR[1]) * 0.42)
    pp.poly([(hip[0] - HIPW - 0.3, hip[1] + 2.5), (hip[0] + HIPW + 0.3, hip[1] + 2.5),
             (mR[0] + 3.0, mR[1]), (hip[0] + 0.4, hip[1] - 2.5), (hip[0] - 0.4, hip[1] - 2.5), (mL[0] - 3.0, mL[1])], SHORTS)
    # torso
    pp.poly([(sho[0] - SHW, sho[1]), (sho[0] + SHW, sho[1]),
             (hip[0] + HIPW, hip[1] + 2), (hip[0] - HIPW, hip[1] + 2)], SHIRT)
    pp.ell((sho[0], sho[1] - 0.5), SHW, 2.5, SHIRT)
    pp.seg(sho, neck, 3.0, SKIN)
    if not pose.get('larm_behind', False):
        draw_arm(sL, elL, hL)
    if not behind:
        draw_arm(sR, elR, hR)
        draw_racket()
    return head


def lerp(a, b, t):
    if isinstance(a, (tuple, list)):
        return type(a)(lerp(x, y, t) for x, y in zip(a, b))
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return a + (b - a) * t
    return a if t < 0.5 else b


def blend(p, q, t):
    out = dict(p)
    for k, v in q.items():
        out[k] = lerp(p[k], v, t) if k in p else v
    return out


READY = dict(drop=4, legs=[(-14, 2), (14, -2)], armR=(25, 95), armL=(-25, 70), rack=150, rhand='B', face=0.6)


def poses():
    """-> list of (name, pose)"""
    P = []
    P.append(('IDLE0', READY))
    P.append(('IDLE1', blend(READY, dict(drop=5.5, armR=(28, 100), rack=145), 1)))
    # side runs: R = towards screen right (near view; mirrored for far)
    for d, nm in ((1, 'RUNR'), (-1, 'RUNL')):
        for i in range(6):
            ph = 2 * math.pi * i / 6
            s = math.sin(ph)
            c = math.cos(ph)
            legs = [(d * (6 + 22 * s), d * (-6 + 22 * s - 18 * max(0, c))),
                    (d * (6 - 22 * s), d * (-6 - 22 * s - 18 * max(0, -c)))]
            P.append(('%s%d' % (nm, i), dict(drop=2 + 1.5 * abs(c), lean=d * 6, x=0,
                                              legs=legs, armR=(20 + 15 * s, 70 + 25 * s), armL=(-20 - 15 * s, -60 - 25 * s),
                                              rack=150 + d * 20, face=0.5)))
    # straight runs (towards / away)
    for i in range(4):
        s = math.sin(2 * math.pi * i / 4)
        legs = [(-5, -3 + 3 * s), (5, 3 - 3 * s)]
        P.append(('RUNV%d' % i, dict(drop=2 + 2 * abs(s), legs=legs, hy=1.0 * abs(s),
                                    armR=(20, 60 + 30 * s), armL=(-20, -60 + 30 * s), rack=165, face=0.5)))
    # forehand (racket on the player's right)
    FH = [dict(drop=5, lean=-6, legs=[(-16, 4), (12, -6)], armR=(95, 140), armL=(-70, -40), rack=200, face=0.9),
          dict(drop=5, lean=-2, legs=[(-14, 2), (14, -4)], armR=(60, 85), armL=(-60, -30), rack=90, face=1.0),
          dict(drop=4, lean=4, legs=[(-12, 0), (16, -2)], armR=(-30, -100), armL=(-40, -10), rack=-150, face=0.7),
          dict(drop=3, lean=6, legs=[(-10, 0), (16, 0)], armR=(-60, -170), armL=(-30, 10), rack=-200, face=0.5)]
    for i, p in enumerate(FH):
        P.append(('FH%d' % i, p))
    BH = [dict(drop=5, lean=6, legs=[(-12, 6), (16, -4)], armR=(-40, -120), armL=(-50, -110), rack=-210, rhand='B', face=0.9),
          dict(drop=5, lean=2, legs=[(-14, 4), (14, -2)], armR=(-55, -85), armL=(-45, -70), rack=-90, rhand='B', face=1.0),
          dict(drop=4, lean=-4, legs=[(-16, 2), (12, 0)], armR=(40, 120), armL=(30, 110), rack=160, rhand='B', face=0.7),
          dict(drop=3, lean=-6, legs=[(-16, 0), (10, 0)], armR=(70, 170), armL=(60, 165), rack=200, rhand='B', face=0.5)]
    for i, p in enumerate(BH):
        P.append(('BH%d' % i, p))
    SV = [dict(drop=1, legs=[(-8, -4), (10, 2)], armR=(30, 40), armL=(-15, 40), rack=120, face=0.5),
          dict(drop=4, lean=-4, legs=[(-10, -2), (12, 0)], armR=(60, 30), armL=(-175, -178), rack=40, face=0.6, hy=1),
          dict(drop=6, lean=-6, legs=[(-14, 8), (12, -8)], armR=(120, 230), armL=(-165, -170), rack=-10, face=0.7, hy=1, behind=True),
          dict(drop=-2, lean=4, legs=[(-4, -2), (6, 2)], armR=(170, 175), armL=(-60, -20), rack=180, face=1.0, hy=1.5),
          dict(drop=4, lean=10, legs=[(-16, 0), (14, -10)], armR=(-30, -60), armL=(-30, 10), rack=-120, face=0.6)]
    for i, p in enumerate(SV):
        P.append(('SV%d' % i, p))
    P.append(('VLYF', dict(drop=9, lean=8, legs=[(-30, 10), (40, -10)], armR=(80, 80), armL=(-60, -30), rack=95, face=1.0)))
    P.append(('VLYB', dict(drop=9, lean=-8, legs=[(-40, 10), (30, -10)], armR=(-70, -80), armL=(-50, -40), rack=-95, face=1.0)))
    P.append(('JOY0', dict(drop=1, legs=[(-8, -2), (8, 2)], armR=(150, 175), armL=(-20, -30), rack=175, face=0.4)))
    P.append(('JOY1', dict(drop=-1, legs=[(-10, -4), (10, 4)], armR=(160, 170), armL=(-160, -170), rack=175, face=0.4, hy=1.5)))
    P.append(('SAD', dict(drop=1, lean=0, legs=[(-4, -2), (4, 2)], armR=(5, 10), armL=(-5, -10), rack=5, face=0.3, hy=-2)))
    return P


def render(pose, scale, mirror):
    pp = Puppet(scale, mirror)
    head = draw_pose(pp, pose)
    hx = head[0] * (-1 if mirror else 1)
    return np.array(pp.img), (hx * scale, head[1] * scale)


def reduce(lab, ay=1.5):
    """high-res labels -> (rows, cols) labels by majority (non-empty wins ties when >= 40%)"""
    H, W = lab.shape
    fy = int(round(SS * ay))
    rows, cols = H // fy, W // SS
    out = np.zeros((rows, cols), np.uint8)
    for r in range(rows):
        blk = lab[r * fy:(r + 1) * fy]
        for c in range(cols):
            b = blk[:, c * SS:(c + 1) * SS].ravel()
            ne = b[b != EMPTY]
            if len(ne) * 10 >= len(b) * 4:
                vals, cnt = np.unique(ne, return_counts=True)
                # thin things (frame, eye) win if they are there at all
                pri = {FRAME: 1.6, EYE: 3.0, SHOE: 1.2, HAIR: 1.1, ARM: 1.3}
                sc = [cnt[i] * pri.get(int(vals[i]), 1.0) for i in range(len(vals))]
                out[r, c] = vals[int(np.argmax(sc))]
    return out


def to_bits(lab):
    """labels -> ink bits and the sprite's own mask"""
    rows, cols = lab.shape
    yy, xx = np.mgrid[0:rows, 0:cols]
    chk = ((xx + yy) % 2) == 0
    sparse = ((xx % 2) == 0) & ((yy % 2) == 0)
    bits = np.zeros((rows, cols), bool)
    for v in (SHIRT, SHORTS, SHOE, FRAME, HAIR, SOCK, ARM):
        bits |= lab == v
    bits |= (lab == SKIN) & chk
    bits |= (lab == FACE) & chk
    bits |= (lab == STRINGS) & sparse
    # a dark line where the shirt meets the shorts
    edge = (lab == SHORTS) & np.roll(lab == SHIRT, 1, axis=0)
    bits &= ~edge
    # shoes vs socks: a gap row above the shoe
    sh = (lab == SHOE) & np.roll(lab == SOCK, 1, axis=0)
    bits &= ~sh
    own = lab != EMPTY
    return bits, own


def crop(bits, own, ax, ay):
    ys, xs = np.nonzero(own)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    # mask: owned pixels grown by one pixel sideways (a paper outline on the court)
    y0 = max(0, y0 - 1)
    x0 = max(0, x0 - 1)
    b = bits[y0:y1 + 2, x0:x1 + 2]
    o = own[y0:y1 + 2, x0:x1 + 2]
    m = o.copy()
    m[:, 1:] |= o[:, :-1]
    m[:, :-1] |= o[:, 1:]
    m[1:, :] |= o[:-1, :]
    return b, m, ax - x0, ay - y0


def build_view(scale, mirror):
    """-> list of (name, bits, mask, ax, ay, head_dx, head_dy) in screen pixels"""
    out = []
    for name, pose in poses():
        lab, head = render(pose, scale, mirror)
        r = reduce(lab)
        bits, own = to_bits(r)
        # anchor: the feet point
        ax = Puppet.__init__.__defaults__ if False else None
        pp = Puppet(scale, mirror)
        fx, fy = pp.ox * SS / SS, (pp.H - pp.oy) * SS / int(round(SS * 1.5))
        b, m, axx, ayy = crop(bits, own, int(round(pp.ox)), int(round(fy)))
        hdx = int(round(head[0]))
        hdy = int(round(-head[1] / 1.5))
        out.append((name, b, m, axx, ayy, hdx, hdy))
    return out


# ------------------------------------------------------------------ heads
CHARS = ['RUSTY', 'LOU', 'NETTA', 'BAZZA', 'DUSTY', 'RITA', 'PROF', 'MRVZ', 'YOU']


def head_labels(ch, view, scale, up=False):
    """a head at (0,0) centre; view 'F' (face) or 'B' (back of head)"""
    pp = Puppet(scale, False)
    pp.oy = 40
    R = HEADR
    c = (0, 0)
    face = FACE if view == 'F' else HAIR
    sk = SKIN
    pp.ell(c, R, R * 1.05, FACE if view == 'F' else sk)

    def hair_cap(top=1.0, low=0.2, wide=1.05):
        pp.ell((0, R * low + 0.5), R * wide, R * top, HAIR)
        if view == 'F':
            pp.ell((0, -R * 0.35), R * 0.92, R * 0.75, FACE)
    if ch == 'RUSTY':            # peaked cap and a moustache
        hair_cap(0.75, 0.35)
        pp.poly([(-R - 0.5, R * 0.1), (R + 0.5, R * 0.1), (R + 0.5, R * 0.9), (-R - 0.5, R * 0.9)], HAIR)
        if view == 'F':
            pp.poly([(-R * 1.1, R * 0.15), (R * 1.1, R * 0.15), (R * 0.9, -R * 0.1), (-R * 0.9, -R * 0.1)], HAIR)
            pp.ell((0, -R * 0.4), R * 0.6, R * 0.2, HAIR)
    elif ch == 'LOU':            # big curly hair
        hair_cap(1.05, 0.25, 1.3)
        pp.ell((-R * 1.0, -R * 0.4), R * 0.55, R * 0.9, HAIR)
        pp.ell((R * 1.0, -R * 0.4), R * 0.55, R * 0.9, HAIR)
        if view == 'B':
            pp.ell((0, -R * 0.5), R * 1.2, R * 0.9, HAIR)
    elif ch == 'NETTA':          # Viking Vern: horned helmet, braids, big moustache
        pp.ell((0, R * 0.45), R * 1.1, R * 0.75, HAIR)
        pp.seg((-R * 0.9, R * 0.7), (-R * 1.7, R * 1.8), 2.2, HAIR)
        pp.seg((R * 0.9, R * 0.7), (R * 1.7, R * 1.8), 2.2, HAIR)
        pp.seg((-R * 0.9, 0), (-R * 1.0, -R * 1.4), 2.4, HAIR)
        pp.seg((R * 0.9, 0), (R * 1.0, -R * 1.4), 2.4, HAIR)
        if view == 'F':
            pp.ell((0, -R * 0.45), R * 0.75, R * 0.3, HAIR)
    elif ch == 'BAZZA':          # mullet and beard
        hair_cap(0.9, 0.3, 1.12)
        pp.poly([(-R - 1, 0), (R + 1, 0), (R + 1.5, -R * 1.3), (-R - 1.5, -R * 1.3)], HAIR if view == 'B' else EMPTY)
        if view == 'F':
            pp.ell((0, -R * 0.55), R * 0.8, R * 0.55, HAIR)
            pp.ell((0, -R * 0.3), R * 0.45, R * 0.25, FACE)
    elif ch == 'DUSTY':          # flat cap and stubble
        pp.ell((0, R * 0.55), R * 1.15, R * 0.5, HAIR)
        if view == 'F':
            pp.poly([(-R * 0.9, R * 0.35), (R * 0.9, R * 0.35), (R * 1.1, R * 0.15), (-R * 1.1, R * 0.15)], HAIR)
            pp.ell((0, -R * 0.6), R * 0.7, R * 0.35, HAIR)
    elif ch == 'RITA':           # long hair
        hair_cap(0.95, 0.25, 1.15)
        pp.poly([(-R - 1.2, R * 0.3), (R + 1.2, R * 0.3), (R + 1.8, -R * 2.0), (-R - 1.8, -R * 2.0)], HAIR)
        if view == 'F':
            pp.ell((0, -R * 0.3), R * 0.85, R * 0.8, FACE)
    elif ch == 'PROF':           # bald on top, visor, glasses
        pp.ell((0, R * 0.25), R * 1.02, R * 0.35, HAIR)
        pp.poly([(-R - 1, R * 0.25), (R + 1, R * 0.25), (R + 1, R * 0.5), (-R - 1, R * 0.5)], HAIR)
        if view == 'F':
            pp.ell((-2.0, -R * 0.1), 1.6, 1.2, HAIR)
            pp.ell((2.0, -R * 0.1), 1.6, 1.2, HAIR)
    elif ch == 'MRVZ':           # slick hair, headband, sunglasses
        hair_cap(0.9, 0.35)
        pp.poly([(-R - 0.6, R * 0.2), (R + 0.6, R * 0.2), (R + 0.6, R * 0.45), (-R - 0.6, R * 0.45)], EMPTY)
        if view == 'F':
            pp.poly([(-R * 0.85, -R * 0.0), (R * 0.85, -R * 0.0), (R * 0.75, -R * 0.4), (-R * 0.75, -R * 0.4)], HAIR)
    else:                        # YOU: short hair, headband
        hair_cap(0.8, 0.35)
        pp.poly([(-R - 0.6, R * 0.15), (R + 0.6, R * 0.15), (R + 0.6, R * 0.4), (-R - 0.6, R * 0.4)], HAIR)
    if view == 'F' and ch not in ('MRVZ', 'PROF', 'DUSTY'):
        pp.ell((-1.8, -R * 0.05), 0.6, 0.8, EYE)
        pp.ell((1.8, -R * 0.05), 0.6, 0.8, EYE)
    return np.array(pp.img), pp


def build_heads(scale, view):
    out = {}
    for ch in CHARS:
        lab, pp = head_labels(ch, view, scale)
        r = reduce(lab)
        bits, own = to_bits(r)
        bits &= ~(r == EYE)
        cy = (pp.H - pp.oy) * SS / int(round(SS * 1.5))
        b, m, ax, ay = crop(bits, own, int(round(pp.ox)), int(round(cy)))
        out[ch] = (b, m, ax, ay)
    return out


NEAR_SCALE = 1.0
FAR_SCALE = 0.72


def sheet(path):
    from PIL import Image
    views = [(build_view(NEAR_SCALE, False), build_heads(NEAR_SCALE, 'B')),
             (build_view(FAR_SCALE, True), build_heads(FAR_SCALE, 'F'))]
    cw, chh = 40, 60
    n = len(views[0][0])
    img = np.zeros((chh * 2 * 2 + 40, cw * 19, 3), np.uint8)
    img[:] = (40, 70, 200)
    for vi, (frames, heads) in enumerate(views):
        for i, (name, b, m, ax, ay, hdx, hdy) in enumerate(frames):
            ox = (i % 19) * cw + 20
            oy = (vi * 2 + i // 19) * chh + 50
            hb, hm, hax, hay = heads[['YOU', 'RUSTY', 'LOU', 'NETTA', 'BAZZA', 'DUSTY', 'RITA', 'PROF', 'MRVZ'][i % 9]]
            for (bb, mm, x0, y0) in ((b, m, ox - ax, oy - ay), (hb, hm, ox + hdx - hax, oy + hdy - hay)):
                for y in range(bb.shape[0]):
                    for x in range(bb.shape[1]):
                        X, Y = x0 + x, y0 + y
                        if 0 <= X < img.shape[1] and 0 <= Y < img.shape[0] and mm[y, x]:
                            img[Y, X] = (255, 255, 255) if bb[y, x] else (40, 70, 200)
    im = Image.fromarray(img)
    im = im.resize((im.width * 3, int(im.height * 4.5)), Image.NEAREST)
    im.save(path)


if __name__ == '__main__':
    sheet('/home/claude/aot/shots/players.png')
