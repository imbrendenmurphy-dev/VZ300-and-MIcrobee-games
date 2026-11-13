"""SPINDRIFT art: every sprite is a small vector drawing, rasterised to 1-bit
pixels at each of the depth sizes (so a far enemy is a real small drawing,
not a squashed big one), then stored eight times, pre-shifted.

The 40-column mode's pixel is about 1.25 times wider than it is tall, so a
shape S lines high is drawn round(S / 1.25) pixels wide.
"""
import math
import numpy as np

PA = 1.25                   # pixel width / line height
CX, CY = 160, 100           # the vanishing point
RIM = 112                   # radius index (rr >> 1) of the player's orbit
RX, RY = 136.0, 92.0        # the orbit's half-axes in pixels / lines (RX: see src/shape.asm)
DEPTH_POW = 1.5             # screen radius = (index / RIM) ** DEPTH_POW
SIZES = [3, 5, 7, 10, 13, 16]
SS = 4                      # supersampling


def radius_frac(i):
    return (i / RIM) ** DEPTH_POW


def polar(a, i):
    """angle 0..255 (0 = bottom, +a anticlockwise on screen), radius index
    0..127 (the game's rr >> 1)"""
    t = a * 2 * math.pi / 256
    f = radius_frac(i)
    return CX + RX * f * math.sin(t), CY + RY * f * math.cos(t)


def size_class(i):
    """radius index -> index into SIZES"""
    s = 16 * radius_frac(i)
    best = 0
    for k, z in enumerate(SIZES):
        if s >= (z + (SIZES[k - 1] if k else 0)) / 2.0:
            best = k
    return best


# ---------------------------------------------------------------- shapes
def ell(u, v, cx, cy, rx, ry):
    return ((u - cx) / rx) ** 2 + ((v - cy) / ry) ** 2 <= 1.0


def poly(u, v, pts):
    """point in polygon (even-odd)"""
    inside = np.zeros(u.shape, bool)
    n = len(pts)
    for k in range(n):
        x1, y1 = pts[k]
        x2, y2 = pts[(k + 1) % n]
        if y1 == y2:
            continue
        c = ((y1 > v) != (y2 > v)) & (u < (x2 - x1) * (v - y1) / (y2 - y1) + x1)
        inside ^= c
    return inside


def seg(u, v, x1, y1, x2, y2, w):
    """a thick line"""
    dx, dy = x2 - x1, y2 - y1
    L2 = dx * dx + dy * dy
    t = np.clip(((u - x1) * dx + (v - y1) * dy) / L2, 0, 1)
    return (u - x1 - t * dx) ** 2 + (v - y1 - t * dy) ** 2 <= w * w


def rot(u, v, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return u * c + v * s, -u * s + v * c


def mirror(pts):
    return pts + [(-x, y) for x, y in reversed(pts)]


def e_skimmer(u, v, f):
    body = ell(u, v, 0, 0.18, 1.0, 0.40)
    dome = ell(u, v, 0, -0.12, 0.52, 0.62) & (v < 0.2)
    if f == 0:
        holes = ell(u, v, -0.55, 0.2, 0.15, 0.15) | ell(u, v, 0.55, 0.2, 0.15, 0.15)
    else:
        holes = ell(u, v, 0, 0.22, 0.17, 0.15)
    legs = seg(u, v, -0.45, 0.5, -0.7, 0.9, 0.1) | seg(u, v, 0.45, 0.5, 0.7, 0.9, 0.1)
    return ((body | dome) & ~holes) | legs


def e_weaver(u, v, f):
    body = ell(u, v, 0, 0, 0.5, 0.56)
    eyes = ell(u, v, -0.2, -0.12, 0.13, 0.15) | ell(u, v, 0.2, -0.12, 0.13, 0.15)
    k = 0.25 if f else -0.15
    legs = np.zeros(u.shape, bool)
    for sx in (-1, 1):
        legs |= seg(u, v, sx * 0.4, -0.2, sx * 0.9, -0.75 - k, 0.11)
        legs |= seg(u, v, sx * 0.45, 0.0, sx * 0.98, 0.0 + k, 0.11)
        legs |= seg(u, v, sx * 0.4, 0.25, sx * 0.85, 0.85 + k * 0.5, 0.11)
    return (body & ~eyes) | legs


def e_shade(u, v, f):
    tip = -0.95 if f == 0 else -0.35
    w = mirror([(0, -0.45), (0.3, -0.15), (1.0, tip), (0.82, 0.25), (0.55, 0.05), (0.32, 0.5), (0.0, 0.9)])
    eyes = ell(u, v, -0.14, 0.0, 0.09, 0.1) | ell(u, v, 0.14, 0.0, 0.09, 0.1)
    return poly(u, v, w) & ~eyes


def e_flare(u, v, f):
    a, b = rot(u, v, 45 * f)
    pts = []
    for k in range(8):
        r = 1.0 if k % 2 == 0 else 0.34
        t = math.radians(k * 45)
        pts.append((r * math.sin(t), -r * math.cos(t)))
    return poly(a, b, pts) & ~ell(u, v, 0, 0, 0.17, 0.17)


def e_swarmer(u, v, f):
    body = poly(u, v, [(0, 1.0), (0.42, -0.1), (0.25, -0.75), (0, -0.95), (-0.25, -0.75), (-0.42, -0.1)])
    stripes = ((v > 0.12) & (v < 0.3)) | ((v > 0.52) & (v < 0.66))
    k = -0.32 if f else 0.12
    wings = ell(u, v, -0.66, -0.1 + k, 0.36, 0.2) | ell(u, v, 0.66, -0.1 + k, 0.36, 0.2)
    return (body & ~stripes) | wings


def e_jewel(u, v, f):
    d = np.abs(u) + np.abs(v)
    if f == 0:
        return (d <= 1.0) & ~(d <= 0.45)
    return ((d <= 1.0) & ~((d > 0.4) & (d <= 0.66)))


def e_rock(u, v, f):
    a, b = rot(u, v, 90 * f)
    pts = [(-0.2, -1.0), (0.5, -0.8), (0.95, -0.25), (0.75, 0.45), (0.9, 0.7), (0.3, 1.0),
           (-0.45, 0.85), (-1.0, 0.3), (-0.7, -0.2), (-0.9, -0.6)]
    crater = ell(a, b, 0.25, -0.2, 0.2, 0.2) | ell(a, b, -0.35, 0.35, 0.14, 0.14)
    return poly(a, b, pts) & ~crater


def e_pod(u, v, f):
    ring = ell(u, v, 0, 0, 1.0, 1.0) & ~ell(u, v, 0, 0, 0.72, 0.72)
    if f == 0:
        core = ell(u, v, 0, 0, 0.4, 0.4)
    else:
        core = seg(u, v, -0.45, 0, 0.45, 0, 0.14) | seg(u, v, 0, -0.45, 0, 0.45, 0.14)
    return ring | core


def e_turret(u, v, f):
    pts = []
    for k in range(8):
        t = math.radians(k * 45 + 22.5)
        pts.append((math.sin(t), -math.cos(t)))
    eye = ell(u, v, 0, 0, 0.5, 0.26 if f == 0 else 0.42)
    pupil = ell(u, v, 0, 0, 0.16, 0.2)
    return (poly(u, v, pts) & ~eye) | pupil


ENEMIES = [e_skimmer, e_weaver, e_shade, e_flare, e_swarmer, e_jewel, e_rock, e_pod, e_turret]
ENEMY_NAMES = ['SKIMMER', 'WEAVER', 'SHADE', 'FLARE', 'SWARMER', 'JEWEL', 'ROCK', 'POD', 'TURRET']


def x_boom(u, v, f):
    r = np.sqrt(u * u + v * v)
    if f == 0:
        return r <= 0.6
    if f == 1:
        out = (r <= 0.92) & (r > 0.55)
        ang = np.arctan2(u, v)
        out &= (np.cos(ang * 6) > -0.55)
        return out | (r <= 0.22)
    out = np.zeros(u.shape, bool)
    n, rr, br = (8, 0.8, 0.17) if f == 2 else (8, 0.9, 0.09)
    for k in range(n):
        t = math.radians(k * 45 + (22.5 if f == 3 else 0))
        out |= ell(u, v, rr * math.sin(t), rr * math.cos(t), br, br)
    if f == 2:
        for k in range(4):
            t = math.radians(k * 90 + 45)
            out |= ell(u, v, 0.4 * math.sin(t), 0.4 * math.cos(t), 0.1, 0.1)
    return out


def s_pshot(u, v, f):
    return ell(u, v, 0, 0, 0.75, 1.0)


def s_ebul(u, v, f):
    d = np.abs(u) + np.abs(v)
    if f == 0:
        return d <= 1.0
    return (d <= 1.0) & ~(d <= 0.42)


def core_shape(u, v, f):
    """the boss core: a big armoured eye. f 0 closed, 1 open, 2 hurt"""
    pts = []
    for k in range(12):
        r = 1.0 if k % 2 == 0 else 0.84
        t = math.radians(k * 30)
        pts.append((r * math.sin(t), -r * math.cos(t)))
    hull = poly(u, v, pts)
    r = np.sqrt(u * u + v * v)
    ang = np.arctan2(u, v)
    if f == 0:
        cut = (r > 0.5) & (r < 0.62)
        cut |= (np.abs(v) < 0.07) & (np.abs(u) < 0.45)
        cut |= (r < 0.8) & (r > 0.62) & (np.cos(ang * 6) > 0.8)
        return hull & ~cut
    if f == 1:
        eye = ell(u, v, 0, 0, 0.62, 0.62)
        pupil = ell(u, v, 0, 0, 0.3, 0.3) & ~ell(u, v, -0.08, -0.08, 0.1, 0.1)
        return (hull & ~eye) | pupil
    cut = (np.cos(ang * 6) > 0.2) & (r > 0.3)
    return hull & ~cut


SHIP = mirror([(0, -7.6), (1.5, -4.0), (2.3, 0.6), (6.9, 4.6), (6.9, 7.2), (3.1, 5.6), (1.6, 7.6)])


# ---------------------------------------------------------------- raster
def raster(fn, w, h, f=0, norm=True, thresh=0.45, min_px=1):
    """sample fn over a w x h pixel box centred on the origin. norm: the
    shape's coordinates run -1..1 over the box height; else they are in
    lines"""
    ys = (np.arange(h * SS) + 0.5) / SS - h / 2.0
    xs = ((np.arange(w * SS) + 0.5) / SS - w / 2.0) * PA
    X, Y = np.meshgrid(xs, ys)
    if norm:
        X, Y = X / (h / 2.0), Y / (h / 2.0)
    m = fn(X, Y, f).astype(np.float32)
    cov = m.reshape(h, SS, w, SS).mean(axis=(1, 3))
    out = cov >= thresh
    if out.sum() < min_px:
        out[h // 2, w // 2] = True
    return out


def dims(s):
    return max(2, int(round(s / PA))), s


def variant(bm, shift):
    """a pre-shifted copy, column-major: ncols, h, then ncols * h bytes"""
    h, w = bm.shape
    ncols = (w + shift + 7) // 8
    rows = np.zeros((h, ncols * 8), bool)
    rows[:, shift:shift + w] = bm
    by = np.packbits(rows, axis=1)          # h x ncols
    while ncols > 1 and not by[:, ncols - 1].any():
        ncols -= 1
    return bytes([ncols, h]) + by[:, :ncols].T.tobytes()


class Bank:
    """a 32K RAM block being filled"""

    def __init__(self, base=0):
        self.d = bytearray()
        self.base = base
        self.sym = {}

    def here(self):
        return self.base + len(self.d)

    def add(self, name, data):
        self.sym[name] = self.here()
        self.d += bytes(data)
        return self.sym[name]

    def family(self, name, bm):
        """eight pre-shifted variants and the record: hotx, hoty, 8 pointers"""
        h, w = bm.shape
        ptrs = []
        for s in range(8):
            ptrs.append(self.here())
            self.d += variant(bm, s)
        a = self.here()
        self.sym[name] = a
        self.d += bytes([w // 2, h // 2])
        for p in ptrs:
            self.d += bytes([p & 255, p >> 8])
        return a


def ship_frame(a):
    """the ship at orbit angle a, nose to the vanishing point: a 16 x 16
    pixel box and where its top left corner goes"""
    x, y = polar(a, RIM)
    xi, yi = int(round(x)), int(round(y))
    # nose to the centre of a round ring (the screen shape is set so the
    # ring looks round): straight along the angle
    t = a * 2 * math.pi / 256
    fx, fy = -math.sin(t), -math.cos(t)

    def fn(X, Y, f):
        ly = -(X * fx + Y * fy)
        lx = X * (-fy) + Y * fx
        hull = poly(lx, ly, SHIP)
        pit = ell(lx, ly, 0, -1.2, 0.85, 1.7)
        return hull & ~pit

    # sample relative to the true (unrounded) centre for smooth rotation
    w = h = 16
    ys = (np.arange(h * SS) + 0.5) / SS - h / 2.0
    xs = ((np.arange(w * SS) + 0.5) / SS - w / 2.0) * PA
    X, Y = np.meshgrid(xs, ys)
    m = fn(X, Y, 0).astype(np.float32)
    bm = m.reshape(h, SS, w, SS).mean(axis=(1, 3)) >= 0.45
    return bm, xi - 8, yi - 8


def sheet(items, path, scale=4, cols=12):
    """a contact sheet of bitmaps, drawn at the tube's pixel shape"""
    from PIL import Image
    cw = max(b.shape[1] for _, b in items) + 2
    ch = max(b.shape[0] for _, b in items) + 2
    rows = (len(items) + cols - 1) // cols
    im = np.zeros((rows * ch, cols * cw), np.uint8)
    for k, (_, b) in enumerate(items):
        y, x = (k // cols) * ch + 1, (k % cols) * cw + 1
        im[y:y + b.shape[0], x:x + b.shape[1]] = b * 255
    img = Image.fromarray(im).resize((int(im.shape[1] * scale * PA), im.shape[0] * scale), Image.NEAREST)
    img.save(path)
