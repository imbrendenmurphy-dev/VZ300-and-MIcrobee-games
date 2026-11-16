"""BILBIES! for the Microbee: the bilby, drawn at Microbee resolution.

A bilby: long rabbit's ears, a long pointed snout, a hunched rounded body,
a long thin tail with a tuft at the end, big hind feet.  Each frame is built
from a few shapes (circles, tapering limbs) placed in display space - a
Microbee pixel is about 1.8 times taller than it is wide, so the shapes are
laid out in (x pixels, y rows) and drawn round on the screen - then
rasterised onto the 18 x 18 grid with 3 x 3 supersampling.  One colour plus
the engine's dark outline; holes (-1) are forced outline: the eye, and the
gaps that keep a limb apart from the body.

Facing right.  Anchor: (AX, AY) = the feet on the ground row, at the VZ x
position's left Microbee pixel.  States and frame counts as the original.
"""
import math
import numpy as np

GW, GH = 18, 18
AX, AY = 9, 17
ASP = 1.8           # a pixel's height in pixel widths
SS = 3              # supersampling

_sy, _sx = np.mgrid[0:GH * SS, 0:GW * SS]
SX = (_sx + 0.5) / SS                   # sample points, in pixels
SY = (_sy + 0.5) / SS * ASP             # ... and in display units down


class G:
    def __init__(self):
        self.a = np.zeros((GH, GW), np.int8)     # 1 ink, -1 hole

    def rows(self):
        return [''.join('#' if v == 1 else ('o' if v == -1 else '.') for v in r) for r in self.a]

    def mirror(self):
        g = G()
        # mirror about the anchor column: keep the feet in place
        for y in range(GH):
            for x in range(GW):
                m = 2 * AX - x
                if 0 <= m < GW:
                    g.a[y, m] = self.a[y, x]
        return g

    def shifted(self, dx=0, dy=0, floor=GH):
        g = G()
        for y in range(GH):
            for x in range(GW):
                v = self.a[y, x]
                yy, xx = y + dy, x + dx
                if v and 0 <= yy < min(GH, floor) and 0 <= xx < GW:
                    g.a[yy, xx] = v
        return g


class Shape:
    """a picture built from shapes; coordinates (x px, y rows), radii in px"""
    def __init__(self):
        self.on = np.zeros(SX.shape, bool)
        self.hole = np.zeros(SX.shape, bool)
        self.off = np.zeros(SX.shape, bool)

    def _m(self, k):
        return self.hole if k == 'hole' else (self.off if k == 'off' else self.on)

    def circ(self, x, y, r, k='on', ry=None):
        ry = r if ry is None else ry
        m = ((SX - x) / r) ** 2 + ((SY - y * ASP) / ry) ** 2 <= 1.0
        self._m(k)[...] |= m
        return self

    def ell(self, x, y, rx, ry, rot=0.0, k='on'):
        """ellipse, radii in display units, rot in degrees (clockwise on screen)"""
        c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
        dx, dy = SX - x, SY - y * ASP
        u = dx * c + dy * s
        w = -dx * s + dy * c
        self._m(k)[...] |= (u / rx) ** 2 + (w / ry) ** 2 <= 1.0
        return self

    def limb(self, pts, r0, r1=None, k='on'):
        """a tapering stroke through points (x, row), radius r0 -> r1"""
        r1 = r0 if r1 is None else r1
        P = [(x, y * ASP) for x, y in pts]
        L = [math.hypot(P[i + 1][0] - P[i][0], P[i + 1][1] - P[i][1]) for i in range(len(P) - 1)]
        tot = sum(L) or 1.0
        acc = 0.0
        m = self._m(k)
        for i in range(len(P) - 1):
            (ax, ay), (bx, by) = P[i], P[i + 1]
            ra = r0 + (r1 - r0) * acc / tot
            rb = r0 + (r1 - r0) * (acc + L[i]) / tot
            acc += L[i]
            vx, vy = bx - ax, by - ay
            ll = vx * vx + vy * vy or 1e-9
            t = np.clip(((SX - ax) * vx + (SY - ay) * vy) / ll, 0, 1)
            d = np.hypot(SX - ax - t * vx, SY - ay - t * vy)
            m |= d <= ra + (rb - ra) * t
        return self

    def poly(self, pts, k='on'):
        from matplotlib.path import Path
        p = Path([(x, y * ASP) for x, y in pts])
        inside = p.contains_points(np.c_[SX.ravel(), SY.ravel()]).reshape(SX.shape)
        self._m(k)[...] |= inside
        return self

    eye = None

    def over(self, o, gap=0.55):
        """lay shape o on top, cutting a thin gap in what is under it"""
        k = int(round(gap * SS))
        d = o.on.copy()
        for dy in range(-k, k + 1):
            for dx in range(-k, k + 1):
                d |= np.roll(np.roll(o.on, dy, 0), dx, 1)
        self.off |= d & ~o.on
        self.on |= o.on
        self.off &= ~o.on
        return self

    def g(self, thresh=0.36):
        cov = lambda m: m.reshape(GH, SS, GW, SS).mean(axis=(1, 3))
        on = (cov(self.on & ~self.off) >= thresh)
        hole = cov(self.hole) >= 0.45
        out = G()
        out.a[on] = 1
        out.a[hole] = -1
        if self.eye is not None:
            ex, ey = int(math.floor(self.eye[0])), int(math.floor(self.eye[1]))
            if 0 <= ex < GW and 0 <= ey < GH and out.a[ey, ex] == 1:
                out.a[ey, ex] = -1
        return out


def pix(g, x, y, v=1):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < GW and 0 <= y < GH:
        g.a[y, x] = v


# ---------------------------------------------------------------------------
# the bilby
# ---------------------------------------------------------------------------
def rot(p, c, deg):
    """rotate point p about c (x px, y rows) by deg on the screen (clockwise)"""
    a = math.radians(deg)
    dx, dy = p[0] - c[0], (p[1] - c[1]) * ASP
    x = dx * math.cos(a) - dy * math.sin(a)
    y = dx * math.sin(a) + dy * math.cos(a)
    return (c[0] + x, c[1] + y / ASP)


def ear_pair(s, base, ang, length=5.6, spread=22, flop=0.0, w=1.0):
    """two long ears from base (x, row); ang = direction of the near ear in
    degrees from straight up (negative leans back), spread between them"""
    for k, (a, ln, ww, dx) in enumerate(((ang, length, w, 0.0), (ang + spread, length * 0.92, w * 0.9, 1.1))):
        a2 = math.radians(a)
        bx, by = base[0] + dx, base[1]
        # in display units: up is -y
        tx = bx + math.sin(a2) * ln * ASP * 1.0
        ty = by - math.cos(a2) * ln
        mx = bx + math.sin(a2 + math.radians(flop)) * ln * ASP * 0.55 + 0.25
        my = by - math.cos(a2 + math.radians(flop)) * ln * 0.55
        s.limb([(bx, by), (mx, my), (tx, ty)], ww, 0.6 * ww)
        if k == 0:
            # a sliver of outline keeps the near ear off the far one
            pass
    return s


def bilby_shape(x=0.0, y=0.0, tilt=0.0, crouch=0.0, ears=None, tail=None, head=0.0,
                hind=None, front=None, front2=None, eye=True, mouth=False, body=1.0):
    """the bilby on all fours, feet on row 17.  x, y shift it (px, rows),
    tilt raises the front (degrees), crouch lowers the body (rows), head
    tips the head down (degrees).  ears: (angle, spread, length, flop),
    tail: points relative to the rump, hind / front: foot positions
    (x, row) in grid coordinates (None = standing)."""
    s = Shape()
    hip = (5.8 + x, 13.5 + y + crouch)
    sh = rot((10.5 + x, 14.2 + y + crouch), hip, -tilt)
    hd = rot((12.9 + x, 12.5 + y + crouch * 0.8), hip, -tilt)
    nose0 = rot((17.4 + x, 14.0 + y + crouch * 0.8), hip, -tilt)
    nose = rot(nose0, hd, head)
    # the tail first, behind everything: thin and stiff, a tuft at its end
    if tail is None:
        tail = [(-2.8, -0.3), (-3.9, -1.4), (-4.5, -2.7)]
    tp = [(hip[0] + dx, hip[1] + dy) for dx, dy in tail]
    s.limb([(hip[0] - 1.6, hip[1])] + tp, 0.6, 0.55)
    tx, ty = tp[-1]
    s.circ(tx, ty, 1.05, ry=1.5)
    # legs: a big hind foot flat on the ground, a thin front leg
    hf = hind if hind is not None else (4.4 + x, 17.0)
    knee = (hip[0] + 0.8, hip[1] + 1.6)
    s.limb([knee, (hf[0], hf[1] - 0.2)], 1.0, 0.75)
    s.limb([(hf[0] - 0.3, hf[1]), (hf[0] + 3.8, hf[1] + 0.05)], 0.85, 0.75)
    for fr in (front2, front):
        if fr is None and fr is front2:
            continue
        ff = fr if fr is not None else (11.4 + x, 17.0)
        s.limb([(sh[0] + 0.3, sh[1] + 0.6), ff], 0.75, 0.55)
        s.limb([ff, (ff[0] + 1.0, ff[1])], 0.55)
    # the body: a hunched egg, the haunch high and round
    s.circ(hip[0] + 0.3, hip[1] - 0.4, 3.45 * body)
    s.limb([hip, sh], 3.25 * body, 2.3 * body)
    # head and the long snout
    s.circ(hd[0], hd[1], 2.0, ry=2.15)
    s.limb([hd, ((hd[0] * 0.45 + nose[0] * 0.55), (hd[1] * 0.45 + nose[1] * 0.55) + 0.05), nose], 1.4, 0.7)
    # ears
    ea, sp, ln, fl = ears if ears is not None else (-20, 26, 5.2, 0)
    eb = rot((hd[0] - 0.6, hd[1] - 1.1), hd, head * 0.5)
    ear_pair(s, eb, ea - tilt, ln, sp, fl)
    s.eye = rot((hd[0] + 0.55, hd[1] - 0.5), hd, head * 0.6) if eye else None
    s.hip, s.sh, s.hd, s.nose = hip, sh, hd, nose
    return s


def upright_shape(x=0.0, y=0.0, lean=0.0, ears=None, arms=None, tail=None, feet=None, eye=True,
                  head=0.0, sit=0.0):
    """sitting / standing up on the hind legs (block, shrug, oh no, float).
    lean tips it forward (degrees).  arms: [(x, row), ...] paw positions."""
    s = Shape()
    base = (7.4 + x, 14.6 + y + sit)
    top = rot((8.4 + x, 11.0 + y + sit * 0.8), base, lean)
    hd = rot((10.5 + x, 8.2 + y + sit * 0.7), base, lean)
    nose = rot((15.0 + x, 9.5 + y + sit * 0.7), hd, head)
    if tail is None:
        tail = [(-2.6, 1.4), (-4.6, 1.6), (-5.8, 0.6)]
    tp = [(base[0] + dx, base[1] + dy) for dx, dy in tail]
    s.limb([base] + tp, 0.6, 0.55)
    s.circ(tp[-1][0], tp[-1][1], 1.05, ry=1.5)
    fe = feet if feet is not None else [(5.4 + x, 17.0), (8.6 + x, 17.0)]
    for fx, fy in fe:
        s.limb([(base[0] + (fx - base[0]) * 0.4, base[1] + 0.6), (fx, fy - 0.2)], 1.0, 0.8)
        s.limb([(fx - 0.3, fy), (fx + 3.2, fy)], 0.85, 0.75)
    s.circ(base[0], base[1] - 0.4, 3.3)
    s.limb([base, top], 3.2, 2.3)
    s.circ(hd[0], hd[1], 2.0, ry=2.15)
    s.limb([hd, ((hd[0] * 0.45 + nose[0] * 0.55), (hd[1] * 0.45 + nose[1] * 0.55)), nose], 1.4, 0.7)
    ea, sp, ln, fl = ears if ears is not None else (-10, 30, 5.0, 0)
    ear_pair(s, (hd[0] - 0.6, hd[1] - 1.1), ea - lean, ln, sp, fl)
    for ax, ay in (arms or []):
        s.limb([(top[0] + 0.8, top[1] + 0.6), (ax, ay)], 0.7, 0.55)
        s.circ(ax, ay, 0.85)
    s.eye = rot((hd[0] + 0.55, hd[1] - 0.5), hd, head * 0.6) if eye else None
    s.base, s.top, s.hd, s.nose = base, top, hd, nose
    return s


def leaf(s, lx, ly, w, tilt=0.0):
    """a gum leaf, arched like a little parachute, its stalk down to the paws"""
    pts = []
    for k in range(9):
        t = (k / 8.0) * 2 - 1                       # -1 .. 1
        pts.append((lx + t * w, ly + 1.7 * t * t + tilt * 0.4 * t))
    hw = 0.95 if w > 3 else 0.7
    s.limb(pts[:5], 0.4, hw)
    s.limb(pts[4:], hw, 0.4)
    s.limb([(lx, ly + 0.5), (lx - 0.2, ly + 2.6)], 0.45)


# ---------------------------------------------------------------------------
# the actions
# ---------------------------------------------------------------------------
# a bounding walk: gather, push off, stretch, land - twice
WALK = [  # (dy, tilt, hind foot x, hind lift, front x, front lift, ears)
    (0.3, 0, 5.4, 0.0, 10.4, 0.0, 0),
    (-0.4, 6, 3.4, 0.0, 13.2, -0.9, -6),
    (-0.9, 3, 2.6, -0.6, 13.8, -0.4, -12),
    (-0.3, -4, 4.0, -0.5, 12.4, 0.0, -8),
]


def walk_shape(i, extra_ears=0):
    dy, tilt, hx, hl, fx, fl, ea = WALK[i % 4]
    alt = (i // 4) % 2
    tail = [(-2.8, -0.3 - dy * 0.3), (-3.9, -1.4 - dy * 0.8), (-4.5 - dy * 0.3, -2.7 - dy * 1.3)]
    return bilby_shape(y=dy, tilt=tilt, hind=(hx, 17.0 + hl), front=(fx, 17.0 + fl),
                       front2=(fx - 1.6 + alt, 17.0) if i % 4 in (0, 3) else None,
                       ears=(-22 + ea + extra_ears, 26, 5.4, 0), tail=tail)


def walk(i):
    return walk_shape(i).g()


def fall(i):
    # dropping: legs dangling and spread, paws up, ears streaming up
    w = i & 1
    s = bilby_shape(y=-1.4, tilt=-14, hind=(3.4 - w, 16.8), front=(14.6 + w * 0.6, 12.4 - w),
                    front2=(12.8, 16.4 - w * 0.6), ears=(-2 + w * 10, 16, 5.8, 0),
                    tail=[(-2.6, -1.2), (-3.6, -2.8 - w * 0.6), (-3.8, -4.4 - w)])
    return s.g()


def float_(i):
    # hanging from a gum leaf by the front paws, swaying
    sz, sway = (i, 0) if i < 4 else (3, [0, 1, 0, -1][i - 4])
    s = upright_shape(x=-0.6 + sway * 0.4, y=1.0, lean=-4 + sway * 4, ears=(-50, 26, 4.2, 0),
                      arms=[(10.0 + sway, 4.4)],
                      feet=[(5.6, 16.4), (8.4, 16.9)], tail=[(-2.2, 0.8), (-3.6, 1.8), (-4.6, 1.4)])
    w = [1.6, 3.4, 5.4, 7.2][sz]
    leaf(s, 10.4 + sway * 1.2, 1.6, w, sway)
    return s.g()


def climb(i):
    # up the wall on the right: belly to the wall, nose up, ears laid back
    ph = i % 4
    up = ph < 2
    s = Shape()
    by = 10.8 - (0.6 if up else 0.0)
    # the tail hangs
    s.limb([(10.4, by + 4.0), (9.4, by + 5.6), (8.6, by + 6.6)], 0.6, 0.55)
    s.circ(8.5, by + 7.0, 1.05, ry=1.5)
    # hind feet braced on the wall
    k1 = (15.4, by + 4.8 + (0.0 if up else 0.8))
    s.limb([(12.4, by + 3.0), (13.0, by + 4.8), k1], 1.0, 0.8)
    s.circ(11.8, by + 2.6, 3.1)                                     # haunch
    s.limb([(11.8, by + 2.2), (12.6, by - 1.8)], 3.0, 2.2)          # the body
    hd = (13.1, by - 3.8)
    s.circ(hd[0], hd[1], 2.0, ry=2.15)
    s.limb([hd, (14.8, by - 6.4), (15.6, by - 7.4)], 1.35, 0.7)    # snout up the wall
    ear_pair(s, (hd[0] - 1.2, hd[1] + 0.2), -62, 4.4, -22)
    s.eye = (hd[0] + 0.6, hd[1] - 0.6)
    # front paws reaching up the wall, one then the other
    f1 = (15.8, by - 2.4 - (1.2 if up else 0.0))
    f2 = (15.8, by + 0.2 + (0.0 if up else -0.8))
    s.limb([(13.6, by - 1.4), f1], 0.7, 0.6)
    s.limb([(13.6, by - 0.2), f2], 0.7, 0.6)
    s.limb([(13.0, by + 2.6), (15.6, by + 2.2 - (0.8 if up else 0.0))], 0.8, 0.65)
    return s.g()


def hoist(i):
    if i < 3:
        # hauling itself up over the top
        g = climb(0 if i == 0 else 1)
        return g.shifted(0, -1 - i)
    if i < 6:
        k = i - 3
        s = bilby_shape(x=2.5, y=-4.0 + k * 0.6, tilt=12 - k * 6, crouch=0.6,
                        hind=(9.2 + k, 14.0 + k * 0.5), front=(15.6, 12.0 + k * 0.5),
                        ears=(-40, 20, 5.0, 0))
        return s.g()
    return bilby_shape(x=2.0, y=-1.5, hind=(6.6 + (i - 6) * 1.2, 15.5), front=(13.6, 15.5),
                       ears=(-30, 24, 5.2, 0)).g()


def block(i):
    # up on the hind legs, front paws held out wide, ears up and twitching
    tw = (i % 4) >= 2
    tap = i % 8 >= 4
    s = upright_shape(x=-0.2, ears=(-10 + (6 if tw else 0), 34, 5.3, 0),
                      arms=[(2.2, 9.0 - (i % 2) * 0.6), (16.0, 9.0 - ((i + 1) % 2) * 0.6)],
                      feet=[(5.2, 17.0 - (0.6 if tap else 0)), (9.4, 17.0)])
    return s.g()


def build(i):
    # carry a stick (a little plank) in the front paws, lay it, step up
    lay = 9 <= i <= 11
    st = Shape()
    if lay:
        s = bilby_shape(crouch=0.6, head=26, tilt=-6, ears=(-42, 22, 5.2, 0),
                        front=(12.6, 16.4), hind=(4.6, 17.0))
        st.limb([(12.0, 16.9), (17.4, 16.9)], 0.75)                # the stick, laid
        return s.over(st).g()
    ph = i % 4
    s = bilby_shape(y=[0, -0.3, 0, -0.3][ph], tilt=14, ears=(-24, 26, 5.4, 0),
                    hind=(4.4 + (ph & 1) * 0.8, 17.0), front=(11.8, 17.0))
    y0 = 15.2 if i < 9 else 15.6
    st.limb([(10.2, y0 + 0.3), (16.8, y0 - 0.5)], 0.75)
    st.circ(12.2, y0 + 0.4, 0.8)                                     # the paw on it
    return s.over(st).g()


def shrug(i):
    up = [0, 1, 2, 2, 2, 2, 1, 0][i]
    if up == 0:
        return bilby_shape().g()
    s = upright_shape(y=0.6, sit=0.6, ears=(-30 - up * 14, 40, 4.8, 0),
                      arms=[(5.0 - up, 10.0 - up * 0.9), (14.4 + up, 10.0 - up * 0.9)])
    return s.g()


def bash(i):
    # punching / clawing at the wall in front, dirt flying back
    ph = i % 16
    reach = [0, 1, 2, 3, 2, 1, 0, 0, 0, 1, 2, 3, 2, 1, 0, 0][ph]
    hi = (i // 8) % 2
    s = bilby_shape(tilt=8, crouch=0.2, ears=(-34, 22, 5.2, 0), hind=(4.0, 17.0),
                    front=(12.2, 17.0) if reach < 2 or hi else None, front2=None,
                    tail=[(-2.6, 0.4), (-4.0, -0.6 - (i & 4) / 4.0), (-4.6, -2.4)])
    py = 13.8 if hi else 14.8
    if reach:
        s.limb([(12.0, 14.0), (13.0 + reach * 1.5, py)], 0.75, 0.6)
        s.circ(13.2 + reach * 1.5, py, 1.0)
    g = s.g()
    if reach == 3:
        pix(g, 1, 8 + (ph & 1))
        pix(g, 0, 10)
        pix(g, 2, 6)
    return g


def mine(i):
    # a pick swung over the head and down into the ground ahead
    ph = i % 12
    a = [-110, -95, -70, -30, 20, 45, 45, 25, -10, -50, -90, -110][ph]
    s = bilby_shape(tilt=-4, crouch=0.6, head=12, ears=(-44, 22, 5.0, 0),
                    hind=(4.0 + (ph // 6) * 0.6, 17.0), front=(12.6, 17.0))
    pk = Shape()
    sx, sy = 11.6, 12.6
    r = math.radians(a)
    hx, hy = sx + math.cos(r) * 5.0, sy + math.sin(r) * 5.0 / ASP
    pk.limb([(sx, sy), (hx, hy)], 0.6)
    px, py = math.cos(r + math.pi / 2), math.sin(r + math.pi / 2) / ASP
    pk.limb([(hx - px * 2.4, hy - py * 2.4), (hx, hy), (hx + px * 2.4, hy + py * 2.4)], 0.45, 0.75)
    pk.circ(sx, sy + 0.3, 0.9)
    g = s.over(pk).g()
    if ph in (5, 6):
        pix(g, 1, 9)
        pix(g, 2, 7 + (ph & 1))
    return g


def dig(i):
    # rump up, nose down at the hole, front paws scrabbling, dirt kicked back
    ph = i % 8
    w = ph & 1
    s = bilby_shape(x=-0.6, y=0.2, tilt=-26, head=34, ears=(-62, 20, 5.0, 0),
                    hind=(3.2, 17.0), front=(11.4 + w * 1.4, 17.0 - w * 0.5), front2=(13.4 - w * 1.2, 16.8),
                    tail=[(-2.4, 0.2), (-3.8, -0.2), (-4.6, -1.2)])
    g = s.g()
    k = ph % 4
    for dx, dy in ((0, 0), (1, -2), (-1, 2)):
        pix(g, 1 + dx + (k & 1), 12 + dy - k)
    return g


def splat(i):
    # flat as a pancake, then gone
    s = Shape()
    w = min(4.0 + i * 0.7, 8.5)
    s.ell(8.5, 16.6, w, 1.3)
    if i < 5:
        s.ell(8.5, 15.4, 4.2 - i * 0.6, 1.5)
        ear_pair(s, (10.6, 15.6), 70, 4.0 - i * 0.4, 18)
    if 4 <= i < 12:
        for k in (-1, 1):
            s.limb([(8.5 + k * w, 16.6), (8.5 + k * (w + 1.5), 16.9)], 0.5)
    g = s.g()
    if i >= 10:
        for x in range(GW):
            if (x * 3 + i) % (17 - i) < (i - 9):
                g.a[15:, x] = 0
    return g


def drown(i):
    # paws up, sinking, bubbles
    sink = i // 2
    up = upright_shape(y=0.0, ears=(-20 + (i % 2) * 12, 30, 5.0, 0),
                       arms=[(5.0 - (i % 2), 6.0 + (i % 2)), (14.0 + (i % 2), 6.0 + ((i + 1) % 2))]).g()
    g = up.shifted(0, sink, floor=17)
    for k in range(2):
        by = 14 - ((i * 2 + k * 5) % 12)
        if i >= 3 and by < sink + 4:
            pix(g, 6 + k * 5 + (i % 2), by)
    return g


def exit_(i):
    # a happy hop, then down the burrow nose first
    if i < 5:
        hop = [0, 1.6, 2.6, 1.6, 0][i]
        s = bilby_shape(y=-hop, tilt=8 if hop else 0, ears=(-6 if hop else -18, 30, 5.6, 0),
                        hind=(4.0, 17.0 - hop), front=(12.6, 17.0 - hop * 1.2))
        return s.g()
    k = i - 5
    s = bilby_shape(y=1.0 + k * 2.4, tilt=-40, crouch=0.0, head=20, ears=(-90, 14, 4.8, 0),
                    hind=(4.0, 15.0 + k * 1.5), front=(12.0, 18.0))
    return s.g().shifted(0, 0, floor=17)


def ohno(i):
    # sits up, paws to its cheeks, trembling; flashes at the end
    sh = (i % 2) if i < 12 else 0
    s = upright_shape(x=sh * 0.6, y=0.4, sit=0.4, ears=(-34 + sh * 10, 46, 4.8, 0), head=10,
                      arms=[(10.6 + sh * 0.6, 8.6), (12.8 + sh * 0.6, 8.8)])
    s.limb([(12.2 + sh * 0.6, 9.2), (13.2 + sh * 0.6, 9.4)], 0.35, 0.35, 'hole')     # the open mouth
    g = s.g()
    if i >= 12 and i % 2:
        f = Shape()
        f.circ(9.0, 11.0, 6.0)
        f.circ(9.0, 11.0, 3.6, 'off')
        for k in range(8):
            a = k * math.pi / 4
            f.limb([(9 + 4 * math.cos(a), 11 + 4 * math.sin(a) / ASP), (9 + 8.5 * math.cos(a), 11 + 8.5 * math.sin(a) / ASP)], 0.6, 0.3)
        return f.g()
    return g


# state order (game.asm): 1 walk 2 fall 3 float 4 climb 5 hoist 6 block 7 build
# 8 shrug 9 bash 10 mine 11 dig 12 splat 13 drown 14 exit 15 ohno
ANIMS = [('walk', walk, 8), ('fall', fall, 4), ('float', float_, 8), ('climb', climb, 8),
         ('hoist', hoist, 8), ('block', block, 8), ('build', build, 16), ('shrug', shrug, 8),
         ('bash', bash, 32), ('mine', mine, 24), ('dig', dig, 16), ('splat', splat, 16),
         ('drown', drown, 16), ('exit', exit_, 8), ('ohno', ohno, 16)]


def all_frames():
    """[(name, n, [right G], [left G])] in state order 1..15"""
    out = []
    for name, f, n in ANIMS:
        r = [f(i) for i in range(n)]
        out.append((name, n, r, [g.mirror() for g in r]))
    return out


def sheet(path, scale=4, only=None):
    from PIL import Image
    fr = all_frames()
    if only:
        fr = [f for f in fr if f[0] in only]
    cols = max(n for _, n, _, _ in fr)
    im = np.zeros((len(fr) * 2 * (GH + 4), cols * (GW + 4), 3), np.uint8)
    im[:] = (60, 60, 200)
    from sprites import outline
    for si, (name, n, r, l) in enumerate(fr):
        for d, lst in enumerate((r, l)):
            for i, g in enumerate(lst):
                on = g.a == 1
                p, o = outline(on, foot_row=AY)
                hole = np.pad(g.a == -1, 1)
                y0 = (si * 2 + d) * (GH + 4) + 1
                x0 = i * (GW + 4) + 1
                sub = im[y0:y0 + GH + 2, x0:x0 + GW + 2]
                sub[GH + 1, :] = (170, 85, 0)               # the ground under the feet
                sub[o | hole] = (0, 0, 0)
                sub[p & ~hole] = (255, 255, 85)
    Image.fromarray(im).resize((im.shape[1] * scale, int(im.shape[0] * scale * ASP)), Image.NEAREST).save(path)


if __name__ == '__main__':
    import sys
    only = sys.argv[2:] or None
    sheet(sys.argv[1] if len(sys.argv) > 1 else '/tmp/claude-0/bilby_sheet.png', only=only)
