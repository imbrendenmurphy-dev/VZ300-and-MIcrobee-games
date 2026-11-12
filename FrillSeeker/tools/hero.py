"""BLUFF the frilled-neck lizard: a small puppet (torso, tail, two-link
legs and arms, a hand-drawn head, a parametric frill) posed and rendered
straight to 1-bit logical pixels. Every pose is computed, so the megabyte
can hold as many in-between frames as the animation wants.

A frame = (ink, cut, ox, oy): ink pixels, forced-dark pixels (outlines and
features), and the hot spot (the point between the feet).
"""
import math
import numpy as np
from art import dilate, parse

SS = 4
W, H = 48, 40
OX, OY = 22, 37          # the hot spot inside the canvas
K = 1                    # drawing scale (3 for the title picture)


class Cv:
    def __init__(self):
        self.ink = np.zeros((H * K, W * K), bool)
        self.cut = np.zeros((H * K, W * K), bool)

    # -- rasterisers: hi-res coverage -> low-res mask
    def _grid(self):
        y, x = np.mgrid[0:H * K * SS, 0:W * K * SS]
        return (x + 0.5) / SS / K - OX, (y + 0.5) / SS / K - OY

    def _down(self, hi, th=0.5):
        return hi.reshape(H * K, SS, W * K, SS).mean(axis=(1, 3)) >= th

    def ellipse(self, cx, cy, rx, ry, ang=0.0):
        x, y = self._grid()
        c, s = math.cos(ang), math.sin(ang)
        u = (x - cx) * c + (y - cy) * s
        v = -(x - cx) * s + (y - cy) * c
        return self._down((u / rx) ** 2 + (v / ry) ** 2 <= 1.0)

    def capsule(self, x0, y0, x1, y1, r0, r1=None, th=0.5):
        r1 = r0 if r1 is None else r1
        x, y = self._grid()
        dx, dy = x1 - x0, y1 - y0
        L2 = dx * dx + dy * dy or 1e-6
        t = np.clip(((x - x0) * dx + (y - y0) * dy) / L2, 0, 1)
        d = np.hypot(x - (x0 + t * dx), y - (y0 + t * dy))
        return self._down(d <= r0 + (r1 - r0) * t, th)

    def chain(self, pts, r0, r1, th=0.5):
        m = np.zeros((H * K, W * K), bool)
        n = len(pts) - 1
        for i in range(n):
            a = r0 + (r1 - r0) * i / n
            b = r0 + (r1 - r0) * (i + 1) / n
            m |= self.capsule(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], a, b, th)
        return m

    def fan(self, cx, cy, a0, a1, R, scallop=0.0, k=9, sq=1.0):
        """a pie slice from angle a0 to a1 (radians, screen coords, measured
        clockwise from +x), vertical radius R * sq"""
        x, y = self._grid()
        yy = (y - cy) / sq
        r = np.hypot(x - cx, yy)
        th = np.arctan2(yy, x - cx)
        span = a1 - a0
        rel = (th - a0) % (2 * math.pi)
        inside = rel <= span
        rad = R * (1 + scallop * np.cos(k * rel * (2 * math.pi) / max(span, 1e-6) / (2 * math.pi) * span))
        if scallop:
            rad = R * (1 - scallop + scallop * np.abs(np.cos(rel / span * math.pi * k)))
        return self._down(inside & (r <= rad))

    # -- compositing
    def stamp(self, m, outline=True):
        if outline:
            edge = dilate(m, diag=False) & ~m & self.ink
            self.cut |= edge
            self.ink &= ~edge
        self.ink |= m
        self.cut &= ~m

    def carve(self, m):
        self.cut |= m & self.ink
        self.ink &= ~m

    def bitmap(self, rows, x, y, outline=True):
        ink, cut = parse(rows)
        h, w = ink.shape
        mi = np.zeros((H * K, W * K), bool)
        mc = np.zeros((H * K, W * K), bool)
        if K > 1:
            ink = np.kron(ink, np.ones((K, K), bool))
            cut = np.kron(cut, np.ones((K, K), bool))
        mi[(OY + y) * K:(OY + y) * K + h * K, (OX + x) * K:(OX + x) * K + w * K] = ink
        mc[(OY + y) * K:(OY + y) * K + h * K, (OX + x) * K:(OX + x) * K + w * K] = cut
        self.stamp(mi | mc, outline)
        self.ink &= ~mc
        self.cut |= mc


# ------------------------------------------------------------------ parts
HEAD = [
    "....######......",
    "..##########....",
    ".####oo#######..",
    ".####oo#########",
    ".####oo######o##",
    ".###############",
    "..#####ooooooooo",
    "...############.",
    ".....########...",
]
HEAD_BLINK = [
    "....######......",
    "..##########....",
    ".#############..",
    ".###ooo#########",
    ".############o##",
    ".###############",
    "..#####ooooooooo",
    "...############.",
    ".....########...",
]
HEAD_HISS = [          # mouth wide open, tongue
    "....######......",
    "..##########....",
    ".###ooo#######..",
    ".####oo#########",
    ".####oo######o##",
    ".######ooooooooo",
    ".#####oooo###oo.",
    "..####oooooooo..",
    "...###########..",
    ".....########...",
]
HEAD_OUCH = [
    "....######......",
    "..##########....",
    ".###o#o#######..",
    ".####o##########",
    ".###o#o######o##",
    ".###############",
    "..####oooooooo##",
    "...###o#o#o#o##.",
    ".....########...",
]
HEAD_HAPPY = [
    "....######......",
    "..##########....",
    ".####oo#######..",
    ".###o##o########",
    ".############o##",
    ".###############",
    "..####o#######o#",
    "...####ooooooo#.",
    ".....########...",
]


def ik(hx, hy, ax, ay, l1, l2, fwd=1):
    dx, dy = ax - hx, ay - hy
    d = max(0.5, min(l1 + l2 - 0.05, math.hypot(dx, dy)))
    a = math.atan2(dy, dx)
    b = math.acos(max(-1, min(1, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d))))
    k = a - fwd * b
    return hx + l1 * math.cos(k), hy + l1 * math.sin(k)


def leg(c, hip, ankle, toe=3.0, th=0.5, foot_ang=0.0):
    kx, ky = ik(hip[0], hip[1], ankle[0], ankle[1], 4.2, 4.2, 1)
    m = c.capsule(hip[0], hip[1], kx, ky, 1.9, 1.3, th)
    m |= c.capsule(kx, ky, ankle[0], ankle[1], 1.2, 0.9, th)
    fx = ankle[0] + toe * math.cos(foot_ang)
    fy = ankle[1] + toe * math.sin(foot_ang)
    m |= c.capsule(ankle[0], ankle[1], fx, fy, 0.9, 0.7, th)
    return m


def arm(c, sh, hand):
    ex, ey = ik(sh[0], sh[1], hand[0], hand[1], 2.6, 2.6, -1)
    m = c.capsule(sh[0], sh[1], ex, ey, 0.95, 0.8)
    m |= c.capsule(ex, ey, hand[0], hand[1], 0.8, 0.9)
    return m


def frill_geom(nx, ny, t):
    cx = nx - 1.5 + 3.0 * t
    cy = ny - 2.5 + 0.8 * t
    a0 = 115 - 170 * t
    a1 = 215 + 112 * t
    R = 6.6 + 4.6 * t
    return cx, cy, a0, a1, R


def frill(c, nx, ny, t):
    """t = 0 folded (a spiky cape behind the neck) .. 1 a full scalloped
    disc behind the head"""
    cx, cy, a0, a1, R = frill_geom(nx, ny, t)
    k = max(3, int(round(3 + 8 * t)))
    return c.fan(cx, cy, math.radians(a0), math.radians(a1), R, 0.2, k)


def spokes(c, nx, ny, t):
    cx, cy, a0, a1, R = frill_geom(nx, ny, t)
    m = np.zeros((H * K, W * K), bool)
    n = max(3, int(round(3 + 8 * t)))
    for i in range(1, n):
        a = math.radians(a0 + (a1 - a0) * i / n)
        m |= c.capsule(cx + 0.55 * R * math.cos(a), cy + 0.55 * R * math.sin(a),
                       cx + (R - 1.9) * math.cos(a), cy + (R - 1.9) * math.sin(a), 0.36, 0.36, 0.28)
    return m


def pose(head=HEAD, lean=0.0, bob=0.0, legs=((1.5, 0), (-1.5, 0)), tail=0.0, tailup=0.0,
         frill_t=0.0, arms=None, head_dy=0, head_dx=0, foot=(0.0, 0.0), chute=False, crouch=0.0):
    """lean: forward lean of the torso (pixels at the shoulder); bob: body
    height offset; legs: ankle positions (near, far) relative to the hot
    spot; tail: wag; tailup: 0 on the ground .. 1 raised"""
    c = Cv()
    hip = (-1.0, -7.2 + bob + crouch)
    sh = (0.6 + lean, -13.2 + bob + crouch)
    # tail (behind everything)
    tx, ty = hip[0] - 1.0, hip[1] + 0.6
    lift = tailup
    pts = [(tx, ty),
           (tx - 4.5, ty + 2.6 - 3.6 * lift),
           (tx - 8.5, ty + 4.6 - 8.5 * lift + tail * 0.6),
           (tx - 11.5, ty + 4.9 - 13.0 * lift + tail * 1.4),
           (tx - 13.5, ty + 3.4 - 16.5 * lift + tail * 2.2)]
    if not chute:
        c.stamp(c.chain(pts, 2.2, 0.55), False)
    else:
        pts = [(tx, ty), (tx - 2.5, ty + 4), (tx - 3.5 + tail, ty + 8), (tx - 2.5 + 2 * tail, ty + 11.5)]
        c.stamp(c.chain(pts, 2.0, 0.55), False)
    # far leg, far arm
    c.stamp(leg(c, (hip[0] + 0.8, hip[1]), (legs[1][0], -1.0 + legs[1][1]), foot_ang=foot[1]), False)
    nx, ny = sh[0] + 0.6 + head_dx, sh[1] - 2.4 + head_dy
    # frill behind the head
    if chute:
        ccx, ccy = nx + 2.0, ny - 9.6
        fm = c.ellipse(ccx, ccy, 14.0, 6.4)
        fm &= ~c.ellipse(ccx, ccy + 5.4, 13.4, 5.6)
        c.stamp(fm, True)
        sp = np.zeros((H * K, W * K), bool)
        for a in (-152, -128, -106, -90, -74, -52, -28):
            r = math.radians(a)
            sp |= c.capsule(ccx + 5 * math.cos(r), ccy + 1.6 * math.sin(r) + 1.0,
                            ccx + 12.6 * math.cos(r), ccy + 5.4 * math.sin(r), 0.36, 0.36, 0.28)
        c.carve(sp & fm)
        # the frill's stays, down to the neck
        st = c.capsule(ccx - 11.5, ccy + 1.5, nx - 1, ny - 1, 0.45, 0.45, 0.3)
        st |= c.capsule(ccx + 11.5, ccy + 1.5, nx + 6, ny - 3, 0.45, 0.45, 0.3)
        c.stamp(st, False)
    else:
        fm = frill(c, nx, ny, frill_t)
        c.stamp(fm, True)
        c.carve(spokes(c, nx, ny, frill_t) & fm)
    # torso
    c.stamp(c.capsule(hip[0], hip[1], sh[0], sh[1], 3.3, 2.7), True)
    # belly line
    # near leg
    c.stamp(leg(c, hip, (legs[0][0], -1.0 + legs[0][1]), foot_ang=foot[0]), True)
    # head
    c.bitmap(head, int(round(nx - 4)), int(round(ny - 6)) + (0 if len(head) == 9 else 0), True)
    # arms
    if arms is None:
        arms = ((sh[0] + 3.6, sh[1] + 4.2), (sh[0] + 4.4, sh[1] + 3.2))
    c.stamp(arm(c, (sh[0] + 1.4, sh[1] + 1.6), arms[1]), False)
    c.stamp(arm(c, (sh[0] + 0.6, sh[1] + 1.8), arms[0]), True)
    return c


def trim(c):
    solid = c.ink | c.cut
    ys = np.where(solid.any(axis=1))[0]
    xs = np.where(solid.any(axis=0))[0]
    x0, x1 = max(0, xs[0] - 1), min(W, xs[-1] + 2)
    y0, y1 = max(0, ys[0] - 1), min(H, ys[-1] + 2)
    return c.ink[y0:y1, x0:x1], c.cut[y0:y1, x0:x1], OX - x0, OY - y0


def frames():
    F = {}

    def add(name, c):
        F[name] = trim(c)

    # idle: breathing, a blink, a tail flick
    add('IDLE0', pose(tail=0.0))
    add('IDLE1', pose(bob=0.5, tail=0.5))
    add('IDLE2', pose(head=HEAD_BLINK, bob=0.5, tail=1.0))
    add('IDLE3', pose(bob=0.0, tail=-0.6))
    # run: the frillie sprint, upright on the hind legs, tail out behind
    N = 8
    for i in range(N):
        ph = 2 * math.pi * i / N
        ank = []
        for off in (0, math.pi):
            p = ph + off
            ax = 0.3 + 4.6 * math.cos(p)
            ay = -max(0.0, 3.4 * math.sin(p))
            ank.append((ax, ay))
        bob = -0.9 * abs(math.sin(ph))
        sw = 2.2 * math.cos(ph)
        arms = ((4.2 + 2.6 - sw, -13.2 + bob + 3.6), (4.2 + 2.6 + sw, -13.2 + bob + 3.2))
        add('RUN%d' % i, pose(lean=2.6, bob=bob, legs=ank, tailup=0.62, tail=1.3 * math.sin(ph * 2),
                              arms=arms, head_dx=0.6, foot=(0.5 * math.sin(ph), 0.5 * math.sin(ph + math.pi))))
    # the sprint: reared up, head down, arms swept back, tail straight out
    for i in range(N):
        ph = 2 * math.pi * i / N
        ank = []
        for off in (0, math.pi):
            p = ph + off
            ank.append((1.0 + 5.8 * math.cos(p), -max(0.0, 3.2 * math.sin(p))))
        bob = -1.1 * abs(math.sin(ph))
        sw = 0.9 * math.cos(ph)
        add('SPR%d' % i, pose(lean=4.4, bob=bob, legs=ank, tailup=0.82, tail=0.5 * math.sin(ph * 2),
                              arms=((3.2 + sw, -10.6 + bob), (3.8 - sw, -11.0 + bob)), head_dx=1.6, head_dy=0.8,
                              foot=(0.5 * math.sin(ph), 0.5 * math.sin(ph + math.pi))))
    # jump (rising) and fall
    add('JUMP', pose(lean=1.2, legs=((2.8, -2.6), (0.4, -1.6)), tailup=0.2, tail=-1.0,
                     arms=((5.6, -17.0), (6.6, -15.6)), foot=(0.9, 0.9)))
    add('FALL', pose(lean=0.6, legs=((2.2, -0.2), (-1.8, -0.6)), tailup=0.95, tail=1.0,
                     arms=((5.0, -16.4), (6.4, -15.2)), head=HEAD_HISS, frill_t=0.25, foot=(0.5, 0.7)))
    # glide: the frill is a parachute
    add('GLIDE0', pose(legs=((1.8, -1.4), (-0.6, -0.8)), chute=True, tail=0.0, foot=(0.8, 1.0)))
    add('GLIDE1', pose(legs=((1.0, -1.0), (-1.2, -1.6)), chute=True, tail=0.8, foot=(1.0, 0.8)))
    # the BLUFF: frill pops, mouth opens
    add('FLARE0', pose(frill_t=0.35, lean=0.4, crouch=0.6, tail=0.6, tailup=0.15,
                       arms=((5.6, -9.4), (6.4, -10.4))))
    add('FLARE1', pose(head=HEAD_HISS, frill_t=0.75, lean=1.0, tailup=0.45, tail=1.2,
                       arms=((7.4, -11.6), (8.0, -12.8)), legs=((2.6, 0), (-2.4, 0))))
    add('FLARE2', pose(head=HEAD_HISS, frill_t=1.0, lean=1.6, tailup=0.7, tail=1.8, bob=-0.6,
                       arms=((8.2, -14.0), (8.6, -15.4)), legs=((3.0, 0), (-2.8, 0))))
    add('FLARE3', pose(head=HEAD_HISS, frill_t=0.93, lean=1.4, tailup=0.62, tail=-0.4, bob=0.0,
                       arms=((8.0, -13.2), (8.6, -14.6)), legs=((3.0, 0), (-2.8, 0))))
    # ouch
    add('HURT', pose(head=HEAD_OUCH, lean=-1.8, legs=((3.2, -1.6), (-2.6, -0.4)), tailup=0.35, tail=2.0,
                     arms=((4.0, -17.2), (-4.4, -15.2)), frill_t=0.3, foot=(-0.4, 0.3)))
    return F


if __name__ == '__main__':
    import sys
    from PIL import Image
    F = frames()
    names = list(F)
    S = 6
    cw, ch = 46, 42
    per = 6
    sheet = np.zeros((((len(names) + per - 1) // per) * ch, per * cw, 3), np.uint8)
    sheet[:] = (0, 0, 80)
    for i, n in enumerate(names):
        ink, cut, ox, oy = F[n]
        h, w = ink.shape
        x0 = (i % per) * cw + 22 - ox
        y0 = (i // per) * ch + 39 - oy
        sub = sheet[y0:y0 + h, x0:x0 + w]
        sub[ink] = (255, 230, 80)
        sub[cut] = (0, 0, 0)
        sheet[(i // per) * ch + 40, (i % per) * cw + 2:(i % per) * cw + cw - 2] = (0, 120, 0)
    im = Image.fromarray(sheet).resize((sheet.shape[1] * S, int(sheet.shape[0] * S * 0.9)), Image.NEAREST)
    im.save(sys.argv[1] if len(sys.argv) > 1 else 'hero_sheet.png')
    print(len(names), 'frames', {n: F[n][0].shape for n in names})
