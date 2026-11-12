"""STORMBELL fighters: six puppets (torso, head, two-link arms and legs),
posed and rasterised to 1-bit pixels for the 40-column screen.

Every frame of every fighter is computed from the same sixteen poses, so
each move reads the same way whoever throws it; what differs is the build,
the headgear and the colours, which is what makes the silhouettes.

World units are screen lines (y up from the ground). A 40-column pixel is
1.25 times wider than tall, so x is drawn at 0.8.
"""
import math
import numpy as np

SS = 4
CW, CH = 14, 11                 # canvas in cells
W, H = CW * 8, CH * 8
AC = 6                          # the anchor cell (column of the body centre)
AX = AC * 8 + 4
XS = 0.8

BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)


def dilate(m):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


class Cv:
    """ink + a colour per pixel; parts stamped later cut a dark edge into
    the parts under them, so limbs stay readable against the body"""

    def __init__(self):
        self.ink = np.zeros((H, W), bool)
        self.col = np.zeros((H, W), np.uint8)
        y, x = np.mgrid[0:H * SS, 0:W * SS]
        self.gx = ((x + 0.5) / SS - AX) / XS          # world x
        self.gy = H - (y + 0.5) / SS                  # world y (up)

    def _down(self, hi, th=0.45):
        return hi.reshape(H, SS, W, SS).mean(axis=(1, 3)) >= th

    def capsule(self, p, q, r0, r1=None):
        r1 = r0 if r1 is None else r1
        dx, dy = q[0] - p[0], q[1] - p[1]
        L2 = dx * dx + dy * dy or 1e-6
        t = np.clip(((self.gx - p[0]) * dx + (self.gy - p[1]) * dy) / L2, 0, 1)
        d = np.hypot(self.gx - (p[0] + t * dx), self.gy - (p[1] + t * dy))
        return self._down(d <= r0 + (r1 - r0) * t)

    def ellipse(self, c, rx, ry, ang=0.0):
        co, si = math.cos(ang), math.sin(ang)
        u = (self.gx - c[0]) * co + (self.gy - c[1]) * si
        v = -(self.gx - c[0]) * si + (self.gy - c[1]) * co
        return self._down((u / rx) ** 2 + (v / ry) ** 2 <= 1.0)

    def poly(self, pts):
        inside = np.zeros(self.gx.shape, bool)
        n = len(pts)
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            if y0 == y1:
                continue
            c = ((y0 > self.gy) != (y1 > self.gy)) & (self.gx < (x1 - x0) * (self.gy - y0) / (y1 - y0) + x0)
            inside ^= c
        return self._down(inside)

    def stamp(self, m, colour, outline=True):
        if outline:
            edge = dilate(m) & ~m & self.ink
            self.ink &= ~edge
        self.ink |= m
        self.col[m] = colour

    def carve(self, m):
        self.ink &= ~m


def ik(p, t, l1, l2, bend):
    """two links from p to t; bend = +1 / -1 picks the side the joint goes"""
    dx, dy = t[0] - p[0], t[1] - p[1]
    d = math.hypot(dx, dy)
    d = max(1e-3, min(d, l1 + l2 - 0.01))
    a = math.atan2(dy, dx)
    c = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    b = math.acos(max(-1, min(1, c)))
    j = (p[0] + l1 * math.cos(a + bend * b), p[1] + l1 * math.sin(a + bend * b))
    e = (p[0] + d * math.cos(a), p[1] + d * math.sin(a))
    return j, e


# ---------------------------------------------------------------------
#  poses: hip (x, height), lean (degrees forward), feet (x, y) lead and
#  rear, hands relative to the shoulder (x forward, y up) lead and rear,
#  head tilt. Lead = the side nearer the opponent.
# ---------------------------------------------------------------------
def P(hip, lean, lf, rf, lh, rh, head=0, kbl=1, kbr=1):
    return dict(hip=hip, lean=lean, lf=lf, rf=rf, lh=lh, rh=rh, head=head, kbl=kbl, kbr=kbr)


POSES = [
    ('idle',    P((0, 33.5), 0, (2, 0), (-2, 0), (2, -20), (-1, -20))),
    ('bow',     P((-3, 32), 46, (2, 0), (-2, 0), (-3, -19), (-6, -18), head=20)),
    ('stand',   P((0, 30), 7, (9, 0), (-9, 0), (12, -1), (6, -7))),
    ('stand2',  P((0, 29), 8, (9, 0), (-9, 0), (12, -2.5), (6, -8))),
    ('step1',   P((1, 31.5), 5, (5, 0), (-4, 2), (12, -1), (6, -7))),
    ('step2',   P((1, 30.5), 7, (11, 2), (-7, 0), (12, -1), (6, -7))),
    ('guard',   P((-2, 29), -5, (9, 0), (-9, 0), (9, 7), (8, 0), head=-6)),
    ('punch_w', P((-2, 30), -3, (9, 0), (-9, 0), (9, 0), (-7, -4))),
    ('punch',   P((4, 28.5), 15, (12, 0), (-11, 0), (1, -9), (19, 2), head=-8)),
    ('kick_w',  P((-2, 32.5), -8, (7, 17), (-4, 0), (8, -2), (4, -8))),
    ('kick',    P((1, 33.5), -26, (39, 33), (-4, 0), (6, -6), (-9, -4), head=10)),
    ('hit',     P((-4, 30), -20, (7, 0), (-11, 0), (8, 7), (-8, 3), head=-22)),
    ('hit2',    P((-5, 27), 30, (7, 0), (-11, 0), (1, -11), (-2, -12), head=24)),
    ('fall1',   P((-8, 23), -48, (8, 4), (-5, 0), (4, 11), (-9, 6), head=-24)),
    ('fall2',   P((-11, 11), -78, (12, 9), (4, 0), (2, 12), (-7, 4), head=-16, kbl=1, kbr=1)),
    ('down',    P((-9, 4.5), -90, (23, 3), (20, 2.5), (-9, -1.5), (-13, -1.5), head=0, kbl=1, kbr=1)),
]
NAMES = [n for n, p in POSES]


class Fighter:
    def __init__(self, key, name, scale=1.0, bulk=1.0, gi=WHITE, skin=YELLOW, belt=BRED, hair=BROWN,
                 hat=None, extra=None, leg=1.0, arm=1.0, hint=''):
        self.key, self.name = key, name
        self.s, self.bulk = scale, bulk
        self.gi, self.skin, self.belt, self.hair = gi, skin, belt, hair
        self.hat, self.extra = hat, extra
        self.leg, self.arm = leg, arm
        self.hint = hint

    def render(self, pose):
        s, b = self.s, self.bulk
        cv = Cv()
        TH, SH = 17 * s * self.leg, 17 * s * self.leg
        UA, FA = 11 * s * self.arm, 11.5 * s * self.arm
        TOR = 21 * s
        hip = (pose['hip'][0] * s, pose['hip'][1] * s * self.leg + (pose['hip'][1] * s * (1 - self.leg)) * 0.5)
        ln = math.radians(pose['lean'])
        sho = (hip[0] + TOR * math.sin(ln), hip[1] + TOR * math.cos(ln))
        hd = math.radians(pose['lean'] * 0.5 + pose['head'])
        neck = (sho[0] + 2 * s * math.sin(ln), sho[1] + 2 * s * math.cos(ln))
        head = (neck[0] + 6.2 * s * math.sin(hd) + 0.8 * s, neck[1] + 6.2 * s * math.cos(hd))
        lf = (pose['lf'][0] * s, pose['lf'][1] * s)
        rf = (pose['rf'][0] * s, pose['rf'][1] * s)
        lying = pose['lean'] <= -85
        # the knees bend forward (towards the opponent); lying, they stay flat
        lk, la = ik(hip, (lf[0], lf[1] + 2.4 * s), TH, SH, -1 if not lying else 1)
        rk, ra = ik(hip, (rf[0], rf[1] + 2.4 * s), TH, SH, -1 if not lying else 1)
        lh = (sho[0] + pose['lh'][0] * s * self.arm, sho[1] + pose['lh'][1] * s * self.arm)
        rh = (sho[0] + pose['rh'][0] * s * self.arm, sho[1] + pose['rh'][1] * s * self.arm)
        le, lhe = ik(sho, lh, UA, FA, -1)
        re, rhe = ik(sho, rh, UA, FA, -1)
        self.joints = dict(hip=hip, sho=sho, head=head, lfoot=la, rfoot=ra, lhand=lhe, rhand=rhe)

        def foot(a, k):
            # the foot points the way the shin does, turned forward
            dx, dy = a[0] - k[0], a[1] - k[1]
            n = math.hypot(dx, dy) or 1
            dx, dy = dx / n, dy / n
            fx, fy = dy, -dx                      # forward of the shin
            if fx < 0 and not lying:
                fx, fy = -fx, -fy
            if lying:
                fx, fy = 0.3, 1.0
            return (a[0], a[1]), (a[0] + 5.5 * s * fx, a[1] + 5.5 * s * fy)

        # -- rear arm, rear leg (behind the body)
        if self.extra:
            self.extra(self, cv, 'back', locals())
        cv.stamp(cv.capsule(sho, re, 3.3 * s * b, 2.9 * s * b), self.gi)
        cv.stamp(cv.capsule(re, rhe, 2.9 * s * b, 2.5 * s * b), self.gi)
        cv.stamp(cv.ellipse(rhe, 2.9 * s, 2.9 * s), self.skin)
        cv.stamp(cv.capsule(hip, rk, 4.8 * s * b, 3.9 * s * b), self.gi)
        cv.stamp(cv.capsule(rk, ra, 3.9 * s * b, 2.9 * s * b), self.gi)
        f0, f1 = foot(ra, rk)
        cv.stamp(cv.capsule(f0, f1, 2.4 * s, 2.0 * s), self.skin, outline=False)
        # -- torso
        cv.stamp(cv.capsule(hip, sho, 6.2 * s * b, 6.9 * s * b), self.gi)
        if self.extra:
            self.extra(self, cv, 'torso', locals())
        # belt: a dark gap and a knot with its tail
        w = (hip[0] + 5.0 * s * math.sin(ln), hip[1] + 5.0 * s * math.cos(ln))
        nx, ny = math.cos(ln), -math.sin(ln)
        cv.carve(cv.capsule((w[0] - 9 * s * b * nx, w[1] - 9 * s * b * ny), (w[0] + 9 * s * b * nx, w[1] + 9 * s * b * ny), 0.55))
        # -- head
        cv.stamp(cv.ellipse(head, 5.3 * s, 5.9 * s, -hd), self.skin)
        if self.hat:
            self.hat(self, cv, head, hd)
        # -- lead leg, lead arm (in front)
        cv.stamp(cv.capsule(hip, lk, 4.8 * s * b, 3.9 * s * b), self.gi)
        cv.stamp(cv.capsule(lk, la, 3.9 * s * b, 2.9 * s * b), self.gi)
        f0, f1 = foot(la, lk)
        cv.stamp(cv.capsule(f0, f1, 2.4 * s, 2.0 * s), self.skin, outline=False)
        cv.stamp(cv.capsule(sho, le, 3.4 * s * b, 3.0 * s * b), self.gi)
        cv.stamp(cv.capsule(le, lhe, 3.0 * s * b, 2.6 * s * b), self.gi)
        cv.stamp(cv.ellipse(lhe, 3.0 * s, 3.0 * s), self.skin)
        if self.extra:
            self.extra(self, cv, 'front', locals())
        return cv


# ---------------------------------------------------------------------
#  headgear and trimmings: these are the silhouettes
# ---------------------------------------------------------------------
def rot(c, hd, x, y):
    """a point x forward, y up of the head centre, turned with the head"""
    co, si = math.cos(hd), math.sin(hd)
    return (c[0] + x * co + y * si, c[1] - x * si + y * co)


def hat_headband(f, cv, c, hd):
    s = f.s
    cv.stamp(cv.ellipse(rot(c, hd, -0.6 * s, 2.6 * s), 5.6 * s, 3.9 * s, -hd), f.hair)
    cv.stamp(cv.capsule(rot(c, hd, -5.2 * s, 1.2 * s), rot(c, hd, 5.2 * s, 1.6 * s), 1.1 * s), f.belt, outline=True)
    # the two tails of the headband, streaming behind
    k = rot(c, hd, -5.4 * s, 1.0 * s)
    cv.stamp(cv.capsule(k, (k[0] - 7 * s, k[1] + 1.5 * s), 1.0 * s, 0.7 * s), f.belt, outline=False)
    cv.stamp(cv.capsule(k, (k[0] - 6.5 * s, k[1] - 3.0 * s), 1.0 * s, 0.7 * s), f.belt, outline=False)


def hat_bald(f, cv, c, hd):
    s = f.s
    # a heavy brow and a jutting jaw
    cv.stamp(cv.ellipse(rot(c, hd, 2.2 * s, -3.4 * s), 4.2 * s, 2.8 * s, -hd), f.skin, outline=False)
    cv.carve(cv.capsule(rot(c, hd, 1.5 * s, 1.0 * s), rot(c, hd, 5.0 * s, 0.6 * s), 0.5))


def hat_cone(f, cv, c, hd):
    s = f.s
    top = rot(c, hd, 0, 9.5 * s)
    a = rot(c, hd, -11.5 * s, 1.8 * s)
    b = rot(c, hd, 11.5 * s, 1.8 * s)
    cv.stamp(cv.poly([top, b, rot(c, hd, 0, 0.6 * s), a]), f.hair)
    cv.stamp(cv.capsule(a, b, 0.8 * s), f.hair, outline=False)


def hat_hood(f, cv, c, hd):
    s = f.s
    cv.stamp(cv.ellipse(rot(c, hd, -0.8 * s, 0.5 * s), 6.0 * s, 6.3 * s, -hd), f.hair)
    # the eye slit, and the knot's spikes behind
    cv.carve(cv.capsule(rot(c, hd, 1.0 * s, 0.8 * s), rot(c, hd, 5.6 * s, 0.8 * s), 0.8 * s))
    k = rot(c, hd, -5.8 * s, 1.5 * s)
    cv.stamp(cv.capsule(k, (k[0] - 5 * s, k[1] + 4.5 * s), 1.2 * s, 0.5 * s), f.hair, outline=False)
    cv.stamp(cv.capsule(k, (k[0] - 6.5 * s, k[1] + 0.5 * s), 1.2 * s, 0.5 * s), f.hair, outline=False)


def hat_helmet(f, cv, c, hd):
    s = f.s
    cv.stamp(cv.ellipse(rot(c, hd, -0.5 * s, 2.2 * s), 6.3 * s, 4.6 * s, -hd), f.hair)
    # neck guard flaring behind, and a tall crest
    cv.stamp(cv.poly([rot(c, hd, -5.5 * s, 2 * s), rot(c, hd, -9.5 * s, -4.5 * s), rot(c, hd, -3.5 * s, -3.5 * s)]), f.hair, outline=False)
    cv.stamp(cv.poly([rot(c, hd, -2.5 * s, 6 * s), rot(c, hd, -1.0 * s, 13.5 * s), rot(c, hd, 3.5 * s, 12.0 * s), rot(c, hd, 2.0 * s, 6 * s)]), f.belt, outline=False)
    cv.carve(cv.capsule(rot(c, hd, 0.5 * s, 0.4 * s), rot(c, hd, 5.6 * s, 0.4 * s), 0.5))


def hat_horns(f, cv, c, hd):
    s = f.s
    cv.stamp(cv.ellipse(rot(c, hd, -0.5 * s, 2.0 * s), 6.2 * s, 4.8 * s, -hd), f.hair)
    for sx in (-1, 1):
        p0 = rot(c, hd, sx * 4.2 * s, 4.5 * s)
        p1 = rot(c, hd, sx * 8.5 * s, 8.5 * s)
        p2 = rot(c, hd, sx * 7.0 * s, 14.0 * s)
        cv.stamp(cv.capsule(p0, p1, 2.0 * s, 1.5 * s), WHITE, outline=False)
        cv.stamp(cv.capsule(p1, p2, 1.5 * s, 0.5 * s), WHITE, outline=False)
    cv.carve(cv.capsule(rot(c, hd, 0.5 * s, 0.2 * s), rot(c, hd, 5.6 * s, 0.2 * s), 0.5))
    # a beak of a mask
    cv.stamp(cv.poly([rot(c, hd, 3.5 * s, -0.8 * s), rot(c, hd, 9.0 * s, -2.8 * s), rot(c, hd, 3.5 * s, -3.8 * s)]), WHITE, outline=False)


def extra_pauldron(f, cv, where, L):
    s = f.s
    if where == 'front':
        sho = L['sho']
        cv.stamp(cv.ellipse((sho[0] - 0.5 * s, sho[1] + 1.2 * s), 6.0 * s, 4.0 * s), f.hair)
    if where == 'torso':
        hip, sho = L['hip'], L['sho']
        # plate lines across the body
        for t in (0.45, 0.7):
            m = (hip[0] + (sho[0] - hip[0]) * t, hip[1] + (sho[1] - hip[1]) * t)
            ln = L['ln']
            nx, ny = math.cos(ln), -math.sin(ln)
            cv.carve(cv.capsule((m[0] - 9 * s * nx, m[1] - 9 * s * ny), (m[0] + 9 * s * nx, m[1] + 9 * s * ny), 0.5))


def extra_cape(f, cv, where, L):
    s = f.s
    if where == 'back':
        sho, hip = L['sho'], L['hip']
        ln = L['ln']
        # hangs from the shoulders, swinging away from the lean
        sway = -8 * s - 16 * s * math.sin(ln)
        if L['lying']:
            cv.stamp(cv.poly([sho, (sho[0] - 3 * s, 0.5), (hip[0] + 6 * s, 0.5), (hip[0], hip[1] + 2 * s)]), f.hair, outline=False)
            return
        low = max(3.0, hip[1] - 22 * s)
        cv.stamp(cv.poly([(sho[0] + 2 * s, sho[1] + 3 * s), (sho[0] - 6 * s, sho[1] + 2 * s),
                          (hip[0] + sway - 7 * s, low), (hip[0] + sway + 4 * s, low + 1.5 * s), (hip[0] - 3 * s, hip[1])]),
                 f.hair, outline=False)


def extra_bare(f, cv, where, L):
    """the gatekeeper: a bare chest over dark trousers, and wrist bands"""
    s = f.s
    if where == 'torso':
        hip, sho = L['hip'], L['sho']
        m = (hip[0] + (sho[0] - hip[0]) * 0.34, hip[1] + (sho[1] - hip[1]) * 0.34)
        cv.stamp(cv.capsule(m, sho, 6.6 * s * f.bulk, 7.2 * s * f.bulk), f.skin, outline=False)


FIGHTERS = [
    Fighter('WREN', 'WREN', scale=1.04, gi=WHITE, skin=YELLOW, belt=BRED, hair=BROWN, hat=hat_headband),
    Fighter('OX', 'BRAMBLE THE OX', scale=1.15, bulk=1.34, gi=BROWN, skin=BRED, belt=YELLOW, hair=BRED,
            hat=hat_bald, extra=extra_bare, arm=1.05,
            hint=('HE SWINGS SLOW AND HEAVY.', 'STEP BACK. STRIKE AS HE MISSES.')),
    Fighter('REED', 'OLD REED', scale=1.12, bulk=0.8, gi=BGREEN, skin=YELLOW, belt=WHITE, hair=YELLOW,
            hat=hat_cone, leg=1.08,
            hint=('HIS LONG KICKS KEEP TIME.', 'GUARD ONE. THEN STEP IN.')),
    Fighter('SPARROW', 'SPARROW', scale=0.9, bulk=0.92, gi=BCYAN, skin=WHITE, belt=YELLOW, hair=BCYAN,
            hat=hat_hood,
            hint=('SHE DARTS IN, TWICE, AND OUT.', 'GUARD BOTH. THEN ANSWER.')),
    Fighter('GORSE', 'CAPTAIN GORSE', scale=1.1, bulk=1.12, gi=BBLUE, skin=YELLOW, belt=BRED, hair=GREY,
            hat=hat_helmet, extra=extra_pauldron,
            hint=('HE GUARDS AND STRIKES BACK.', 'MAKE HIM MISS. NEVER RUSH.')),
    Fighter('CROW', 'LORD CURRAWONG', scale=1.14, bulk=1.05, gi=BMAGENTA, skin=WHITE, belt=YELLOW, hair=MAGENTA,
            hat=hat_horns, extra=extra_cape,
            hint=('THE STORM LORD KNOWS IT ALL.', 'WATCH. WAIT. THE BELL IS NEAR.')),
]


def frames(f, mirror=False):
    """[(name, ink, col)] for one fighter, mirrored for the right-hand side"""
    out = []
    for name, pose in POSES:
        cv = f.render(pose)
        ink, col = cv.ink, cv.col
        if mirror:
            ink = ink[:, ::-1]
            col = col[:, ::-1]
        out.append((name, ink.copy(), col.copy(), dict(f.joints)))
    return out


def reach(ink, mirror=False, rows=None):
    """how far ink goes towards the opponent, in pixels from the anchor
    (the centre of the anchor cell)"""
    m = ink if rows is None else ink[rows[0]:rows[1]]
    xs = np.where(m.any(axis=0))[0]
    if len(xs) == 0:
        return 0
    if mirror:
        return (W - 1 - AX) - xs.min() if False else (W - AX) - xs.min() - (W - 2 * AX)
    return xs.max() - AX + 1


def sheet(path, scale=2):
    """a contact sheet of every frame of every fighter (for the eye)"""
    from PIL import Image
    PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
    n = len(POSES)
    img = np.zeros((len(FIGHTERS) * H, n * W, 3), np.uint8)
    img[:, :, 2] = 40
    for j, f in enumerate(FIGHTERS):
        for i, (name, ink, col, jt) in enumerate(frames(f, mirror=j > 0)):
            cell = cellcol(ink, col)
            rgb = np.array(PAL, np.uint8)[np.repeat(np.repeat(cell, 8, 0), 8, 1)]
            sub = img[j * H:(j + 1) * H, i * W:(i + 1) * W]
            sub[ink] = rgb[ink]
    im = Image.fromarray(img).resize((int(n * W * scale * 1.25), len(FIGHTERS) * H * scale), Image.NEAREST)
    im.save(path)


def cellcol(ink, col):
    """the ink colour of each cell: the colour most of its pixels have"""
    out = np.zeros((CH, CW), np.uint8)
    for cy in range(CH):
        for cx in range(CW):
            m = ink[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            if m.any():
                c = col[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8][m]
                out[cy, cx] = np.bincount(c, minlength=16).argmax()
    return out


if __name__ == '__main__':
    import sys
    sheet(sys.argv[1])
