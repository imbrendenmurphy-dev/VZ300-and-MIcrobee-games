"""ASTEROIDS II (Microbee) artwork.

Re-renders the original VZ300 vector shapes (same polygons, same random seed
for the rocks) at the Microbee's 4x resolution: 512x256, pixels 0.5 x 0.75
'physical units' (a VZ CG2 pixel is 2 x 3 units, so every VZ pixel is 4x4
Microbee pixels and the original proportions are kept exactly).

Each sprite is (pix, mask, opaque):
  pix   - 1 bit image: lit pixels (drawn in the object's colour)
  mask  - silhouette; with opaque=True, bytes fully inside the silhouette are
          stored (background shows through the unlit pixels, hiding stars),
          edge bytes are ORed.  opaque=False -> everything ORed.
"""
import math, random
import numpy as np

UX, UY = 0.5, 0.75
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32


def grid(W, H):
    ys, xs = np.mgrid[0:H, 0:W]
    X = (xs + 0.5) * UX - W * UX / 2
    Y = (ys + 0.5) * UY - H * UY / 2
    return X, Y


def inside(X, Y, pts):
    c = np.zeros(X.shape, bool)
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % n]
        cond = (y1 > Y) != (y2 > Y)
        with np.errstate(divide='ignore', invalid='ignore'):
            xi = (x2 - x1) * (Y - y1) / (y2 - y1 + 1e-12) + x1
        c ^= cond & (X < xi)
    return c


def poly_cov(W, H, pts, ss=3):
    """coverage fraction of polygon per pixel (supersampled)"""
    acc = np.zeros((H, W))
    X, Y = grid(W, H)
    for sy in range(ss):
        for sx in range(ss):
            ox = ((sx + 0.5) / ss - 0.5) * UX
            oy = ((sy + 0.5) / ss - 0.5) * UY
            acc += inside(X + ox, Y + oy, pts)
    return acc / (ss * ss)


def rot(pts, a):
    c, s = math.cos(a), math.sin(a)
    return [(x * c - y * s, x * s + y * c) for x, y in pts]


def dither(b):
    H, W = b.shape
    t = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
    return b > t


def edge_of(m):
    p = np.pad(m, 1)
    e = m & ~(p[:-2, 1:-1] & p[2:, 1:-1] & p[1:-1, :-2] & p[1:-1, 2:])
    return e


def grow(m):
    p = np.pad(m, 1)
    return m | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]


SPRITES = []          # (name, pix, mask, opaque)
INDEX = {}
TOPLEFT = set()       # sprites placed by their top-left corner, one variant


def add(name, pix, mask=None, opaque=False, topleft=False):
    if topleft:
        TOPLEFT.add(name)
    pix = np.asarray(pix, bool)
    mask = pix.copy() if mask is None else (np.asarray(mask, bool) | pix)
    INDEX[name] = len(SPRITES)
    SPRITES.append((name, pix, mask, opaque))
    return INDEX[name]


def ascii_img(rows):
    return np.array([[c not in '. ' for c in r] for r in rows], bool)


# --------------------------------------------------------------- ship
SHIP = [(0, -8.5), (6.5, 6.5), (2.2, 3.6), (0, 4.6), (-2.2, 3.6), (-6.5, 6.5)]


def _seg_dist(X, Y, p, q):
    (x1, y1), (x2, y2) = p, q
    dx, dy = x2 - x1, y2 - y1
    t = np.clip(((X - x1) * dx + (Y - y1) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(X - (x1 + t * dx), Y - (y1 + t * dy))


def ship_img(a, W=32, H=24):
    """the original wedge, with a little more to it: a split spine from the
    canopy to the tail, a canopy with a glint, and engine ports on the
    trailing edge.  Features are a VZ unit wide so they survive rotation."""
    pts = rot(SHIP, a)
    body = poly_cov(W, H, pts, 4) >= 0.42
    X, Y = grid(W, H)
    c, s = math.cos(a), math.sin(a)
    lx, ly = X * c + Y * s, -X * s + Y * c          # ship-local coordinates
    pix = body & ~(_seg_dist(lx, ly, (0, -0.6), (0, 4.6)) < 0.55)      # spine
    for sx in (-1, 1):                                                 # ports
        pix &= ~(_seg_dist(lx, ly, (sx * 3.7, 4.4), (sx * 3.7, 6.2)) < 0.5)
    win = ((lx / 1.05) ** 2 + ((ly + 3.2) / 1.7) ** 2) < 1.0           # canopy
    pix &= ~win
    pix |= win & (((lx + 0.35) ** 2 + (ly + 3.7) ** 2) < 0.18)         # glint
    return pix & body, body


def flame_img(a, k, W=32, H=24):
    X, Y = grid(W, H)
    L = 3.2 + 1.6 * k
    pts = rot([(-1.6, 5.0), (0, 5.0 + L), (1.6, 5.0)], a)
    return poly_cov(W, H, pts, 3) >= 0.4


# --------------------------------------------------------------- rocks
def rock_img(base, feats, R, tname, a, W, H, seed):
    pts = rot(base, a)
    cov = poly_cov(W, H, pts, 3)
    sil = cov >= 0.42
    X, Y = grid(W, H)
    # pseudo-sphere shading: radial distance relative to the outline radius
    ang = np.arctan2(Y, X) - a
    n = len(base)
    rad = np.array([math.hypot(*p) for p in base])
    k = (ang / (2 * math.pi) * n) % n
    i0 = np.floor(k).astype(int) % n
    f = k - np.floor(k)
    rr = rad[i0] * (1 - f) + rad[(i0 + 1) % n] * f
    r = np.hypot(X, Y) / np.maximum(rr, 1e-3)
    r = np.clip(r, 0, 1)
    nz = np.sqrt(1 - r ** 2 * 0.92)
    nx = X / np.maximum(rr, 1e-3)
    ny = Y / np.maximum(rr, 1e-3)
    L = np.array([-0.55, -0.62, 0.56])
    L /= np.linalg.norm(L)
    b = 0.12 + 0.95 * np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0, 1)
    rng = np.random.default_rng(seed)
    # craters / features
    crater_dark = np.zeros_like(b, bool)
    for fr, th in feats:
        fx, fy = fr * math.cos(th + a), fr * math.sin(th + a)
        cr = R * (0.24 if tname != 'CRYSTAL' else 0.0)
        if cr <= 0:
            continue
        d = np.hypot((X - fx) / cr, (Y - fy) / cr)
        inner = d < 1.0
        # rim lit on the side facing away from the light, floor dark
        rim = (d >= 0.75) & (d < 1.25)
        side = ((X - fx) * L[0] + (Y - fy) * L[1]) < 0
        b = np.where(inner, b * 0.35, b)
        b = np.where(rim & ~side, np.minimum(1.0, b + 0.35), b)
        crater_dark |= inner & (d < 0.55)
    pix = dither(b) & sil
    if tname == 'STONE':
        pix &= ~crater_dark
    elif tname == 'ORE':
        # glittering ore seams: bright sparkles in the craters + veins
        for fr, th in feats:
            for kk in range(3):
                vx = fr * (0.4 + 0.3 * kk) * math.cos(th + a + kk * 0.9)
                vy = fr * (0.4 + 0.3 * kk) * math.sin(th + a + kk * 0.9)
                d = np.hypot((X - vx) / 1.1, (Y - vy) / 1.1)
                pix |= (d < 1.0) & sil
                pix &= ~((d >= 1.0) & (d < 1.7) & sil)
    elif tname == 'VOLATILE':
        # glowing fissures from the core: dark cracks with lit edges
        for fr, th in feats:
            t = np.linspace(0, 1, 40)
            for tt in t:
                vx = fr * 1.6 * tt * math.cos(th + a + 0.5 * math.sin(tt * 5))
                vy = fr * 1.6 * tt * math.sin(th + a + 0.5 * math.sin(tt * 5))
                d = np.hypot((X - vx) / 0.7, (Y - vy) / 0.7)
                pix &= ~(d < 1.0)
        pix &= ~(np.hypot(X / (R * 0.18), Y / (R * 0.18)) < 1)
    elif tname == 'CRYSTAL':
        e = edge_of(sil)
        e2 = edge_of(sil & ~e)
        pix = e | (e2 & dither(b * 0.7))
        # facet lines from the centre to alternate vertices
        for kk in range(0, len(base), 2):
            vx, vy = rot([base[kk]], a)[0]
            for tt in np.linspace(0.25, 0.9, 30):
                d = np.hypot((X - vx * tt) / 0.5, (Y - vy * tt) / 0.55)
                pix |= (d < 1.0) & sil
    # silhouette must read against the background: keep a lit rim except
    # where crater floors sit
    pix |= edge_of(sil) & (b > 0.18)
    return pix & sil, sil


# --------------------------------------------------------------- misc shapes
def ellipse_ring(W, H, rx, ry, thick, dash=None, phase=0):
    X, Y = grid(W, H)
    d = np.hypot(X / rx, Y / ry)
    m = np.abs(d - 1) < thick / max(rx, ry)
    if dash:
        ang = (np.arctan2(Y, X) + math.pi) / (2 * math.pi) * dash * 2
        m &= ((np.floor(ang + phase) % 2) == 0)
    return m


def saucer_img(f):
    W, H = 44, 20
    X, Y = grid(W, H)
    dome = ((X / 4.6) ** 2 + ((Y + 2.6) / 4.2) ** 2 < 1) & (Y < -1.2)
    body = ((X / 10.8) ** 2 + ((Y - 0.4) / 2.9) ** 2) < 1
    rim = ((X / 7.5) ** 2 + ((Y - 2.6) / 2.2) ** 2) < 1
    legs = np.zeros_like(body)
    for lx in (-5.0, 5.0):
        legs |= (np.abs(X - lx - (0.6 if lx > 0 else -0.6) * (Y - 3) / 3) < 0.55) & (Y > 2.5) & (Y < 6.6)
    sil = dome | body | rim | legs
    pix = sil.copy()
    # windows on the dome, light strip on the body (animated)
    pix &= ~(((X / 1.8) ** 2 + ((Y + 3.4) / 1.2) ** 2) < 1)
    pix &= ~((np.abs(Y + 0.05) < 0.45) & (np.abs(X) < 9.8))
    for k in range(-4, 5):
        lx = k * 2.3 + (1.15 if f else 0)
        pix |= (np.abs(X - lx) < 0.55) & (np.abs(Y + 0.05) < 0.5) & body
    return pix, sil


def hunter_img(f):
    W, H = 20, 12
    X, Y = grid(W, H)
    dome = ((X / 2.4) ** 2 + ((Y + 1.3) / 2.6) ** 2 < 1) & (Y < 0)
    body = ((X / 4.8) ** 2 + ((Y - 0.4) / 1.6) ** 2) < 1
    claws = np.zeros_like(body)
    for s in (-1, 1):
        cx = s * (3.2 if f == 0 else 3.9)
        claws |= (np.abs(X - cx - s * 0.5 * (Y - 1)) < 0.6) & (Y > 0.5) & (Y < 4.4)
    sil = dome | body | claws
    pix = sil & ~((np.abs(Y - 0.3) < 0.4) & (np.abs(X) < 3.6) & (((X + (1 if f else 0)) % 2.4) < 1.2))
    pix &= ~(((X / 0.9) ** 2 + ((Y + 1.5) / 0.9) ** 2) < 1)
    return pix, sil


STING = [(0, -7.5), (4.8, 5.5), (0, 2.5), (-4.8, 5.5)]


def sting_img(a):
    W, H = 28, 20
    cov = poly_cov(W, H, rot(STING, a), 4)
    sil = cov >= 0.40
    X, Y = grid(W, H)
    (cx, cy), = rot([(0, -1.5)], a)
    eye = (((X - cx) / 1.0) ** 2 + ((Y - cy) / 1.1) ** 2) < 1
    (sx, sy), = rot([(0, 3.4)], a)
    return sil & ~eye & ~((((X - sx) / 1.0) ** 2 + ((Y - sy) / 0.8) ** 2) < 1), sil


def mine_img(f):
    W, H = 20, 20
    X, Y = grid(W, H)
    core = (X / 3.0) ** 2 + (Y / 3.0) ** 2 < 1
    spikes = np.zeros_like(core)
    for k in range(8):
        a = k * math.pi / 4 + (math.pi / 8 if f else 0)
        for t in np.linspace(2.6, 4.8, 12):
            spikes |= np.hypot(X - t * math.cos(a), Y - t * math.sin(a)) < (0.75 if t < 4.4 else 0.95)
    sil = core | spikes
    pix = sil & ~((X / 1.2) ** 2 + (Y / 1.2) ** 2 < 1) if f else sil & ~(np.abs(X) < 0.4) & ~(np.abs(Y) < 0.4) | ((X / 0.8) ** 2 + (Y / 0.8) ** 2 < 1)
    return pix & sil, sil


def jewel_img(f):
    W, H = 20, 20
    X, Y = grid(W, H)
    wf = [1.0, 0.72, 0.22, 0.72][f]
    pts = [(-4.2 * wf, -1.6), (-2.2 * wf, -4.0), (2.2 * wf, -4.0), (4.2 * wf, -1.6), (0, 5.2)]
    sil = poly_cov(W, H, pts, 4) >= 0.4
    pix = sil.copy()
    # table line and facets
    pix &= ~((np.abs(Y + 1.6) < 0.38) & sil)
    if wf > 0.5:
        for s in (-1, 1):
            for t in np.linspace(0, 1, 40):
                x = s * 2.2 * wf * (1 - t) + 0
                y = -1.6 + t * 6.6
                pix &= ~((np.hypot((X - x * (1 - t * 0.0)) / 0.32, (Y - y) / 0.45) < 1) & (Y > -1.2))
    # glint
    gx = [-2.4, -1.2, 0.0, 1.2][f] * wf
    pix &= ~((np.hypot((X - gx) / 0.6, (Y + 2.8) / 0.5) < 1))
    return pix, sil


def capsule(W=28, H=20):
    X, Y = grid(W, H)
    rx, ry = 6.6, 7.0
    # rounded rectangle outline
    dx = np.maximum(np.abs(X) - (rx - 2.2), 0)
    dy = np.maximum(np.abs(Y) - (ry - 2.6), 0)
    d = np.hypot(dx / 2.2, dy / 2.6)
    return (d < 1.0), (d < 1.0) & (d >= 0.62) | ((np.abs(X) > rx - 0.6) & (np.abs(Y) < ry - 2.6))


def pickup_img(kind):
    sil, ring = capsule()
    X, Y = grid(28, 20)
    icon = np.zeros_like(sil)
    if kind == 'SHIELD':
        icon = ellipse_ring(28, 20, 3.0, 3.6, 0.9)
        icon |= np.hypot(X / 1.0, Y / 1.2) < 1
    elif kind == 'BOMB':
        icon = np.hypot((X + 0.4) / 2.6, (Y - 0.9) / 2.8) < 1
        for t in np.linspace(0, 1, 20):
            icon |= np.hypot(X - (1.5 + 1.6 * t), Y - (-2.0 - 1.8 * t + 1.2 * t * t)) < 0.45
        icon |= np.hypot((X - 3.4) / 0.9, (Y + 3.6) / 0.9) < 1
    elif kind == 'SPREAD':
        for ang in (-0.6, 0, 0.6):
            for t in np.linspace(0, 4.2, 18):
                icon |= np.hypot(X - t * math.sin(ang), Y - (3.2 - t * math.cos(ang))) < 0.5
        icon |= np.hypot(X, Y - 3.4) < 0.9
    elif kind == 'RAPID':
        for k in range(3):
            y0 = -3.4 + k * 2.4
            icon |= (np.abs(np.abs(X) * 0.75 - (Y - y0)) < 0.5) & (np.abs(X) < 3.2)
    elif kind == 'LIFE':
        sh = poly_cov(28, 20, [(x * 0.5, y * 0.5) for x, y in SHIP], 4) >= 0.4
        icon = sh
    pix = (ring | icon) & sil
    return pix, sil


def bullet_img(big):
    W, H = (4, 4) if big else (2, 2)
    m = np.ones((H, W), bool)
    if big:
        m[0, 0] = m[0, 3] = m[3, 0] = m[3, 3] = False
    return m, m


# 3x5 font from the original, drawn at 2x (6x10) for score popups
FONT = {
    '0': ["YYY", "Y.Y", "Y.Y", "Y.Y", "YYY"], '1': [".Y.", "YY.", ".Y.", ".Y.", "YYY"],
    '2': ["YYY", "..Y", "YYY", "Y..", "YYY"], '3': ["YYY", "..Y", ".YY", "..Y", "YYY"],
    '4': ["Y.Y", "Y.Y", "YYY", "..Y", "..Y"], '5': ["YYY", "Y..", "YYY", "..Y", "YYY"],
    '6': ["YYY", "Y..", "YYY", "Y.Y", "YYY"], '7': ["YYY", "..Y", ".Y.", ".Y.", ".Y."],
    '8': ["YYY", "Y.Y", "YYY", "Y.Y", "YYY"], '9': ["YYY", "Y.Y", "YYY", "..Y", "YYY"],
    'A': [".Y.", "Y.Y", "YYY", "Y.Y", "Y.Y"], 'B': ["YY.", "Y.Y", "YY.", "Y.Y", "YY."],
    'C': [".YY", "Y..", "Y..", "Y..", ".YY"], 'D': ["YY.", "Y.Y", "Y.Y", "Y.Y", "YY."],
    'E': ["YYY", "Y..", "YY.", "Y..", "YYY"], 'F': ["YYY", "Y..", "YY.", "Y..", "Y.."],
    'G': [".YY", "Y..", "Y.Y", "Y.Y", ".YY"], 'H': ["Y.Y", "Y.Y", "YYY", "Y.Y", "Y.Y"],
    'I': ["YYY", ".Y.", ".Y.", ".Y.", "YYY"], 'J': ["..Y", "..Y", "..Y", "Y.Y", ".Y."],
    'K': ["Y.Y", "Y.Y", "YY.", "Y.Y", "Y.Y"], 'L': ["Y..", "Y..", "Y..", "Y..", "YYY"],
    'M': ["Y.Y", "YYY", "YYY", "Y.Y", "Y.Y"], 'N': ["YY.", "Y.Y", "Y.Y", "Y.Y", "Y.Y"],
    'O': [".Y.", "Y.Y", "Y.Y", "Y.Y", ".Y."], 'P': ["YY.", "Y.Y", "YY.", "Y..", "Y.."],
    'Q': [".Y.", "Y.Y", "Y.Y", "YY.", ".YY"], 'R': ["YY.", "Y.Y", "YY.", "Y.Y", "Y.Y"],
    'S': [".YY", "Y..", ".Y.", "..Y", "YY."], 'T': ["YYY", ".Y.", ".Y.", ".Y.", ".Y."],
    'U': ["Y.Y", "Y.Y", "Y.Y", "Y.Y", "YYY"], 'V': ["Y.Y", "Y.Y", "Y.Y", "Y.Y", ".Y."],
    'W': ["Y.Y", "Y.Y", "YYY", "YYY", "Y.Y"], 'X': ["Y.Y", "Y.Y", ".Y.", "Y.Y", "Y.Y"],
    'Y': ["Y.Y", "Y.Y", ".Y.", ".Y.", ".Y."], 'Z': ["YYY", "..Y", ".Y.", "Y..", "YYY"],
    '+': ["...", ".Y.", "YYY", ".Y.", "..."], '!': [".Y.", ".Y.", ".Y.", "...", ".Y."],
    '-': ["...", "...", "YYY", "...", "..."],
}
GLYPHS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ+!-'


def glyph_img(ch):
    import retrofont
    g = np.zeros((10, 8), bool)
    g[:, :7] = retrofont.G.get(ch, retrofont.G['?'])
    return g


# --------------------------------------------------------------- build list
def build():
    SPRITES.clear(); INDEX.clear()
    for i in range(32):
        p, m = ship_img(i * 2 * math.pi / 32)
        add('ship%d' % i, p, m, opaque=True)
    for i in range(2):
        add('shield%d' % i, ellipse_ring(48, 28, 11.4, 9.6, 0.75, dash=6, phase=i * 0.5))
    random.seed(1984)
    SIZES = [('L', 15, 9, 14.0), ('M', 10, 6, 9.0), ('S', 6, 4, 5.2)]
    NFR = {'L': 8, 'M': 8, 'S': 4}
    TYPES = ['STONE', 'ORE', 'VOLATILE', 'CRYSTAL']
    for t, tname in enumerate(TYPES):
        for sname, w, h, R in SIZES:
            n = 10 if sname != 'S' else 7
            if tname == 'CRYSTAL':
                n = 6 if sname != 'S' else 5
                radii = [R * (0.95 if k % 2 == 0 else 0.62) for k in range(n)]
            else:
                radii = [R * random.uniform(0.72, 1.0) for _ in range(n)]
            base = [(radii[k] * math.cos(2 * math.pi * k / n), radii[k] * math.sin(2 * math.pi * k / n)) for k in range(n)]
            feats = []
            for _ in range(4 if sname == 'L' else 2 if sname == 'M' else 1):
                feats.append((random.uniform(0.15, 0.55) * R, random.uniform(0, 2 * math.pi)))
            for f in range(NFR[sname]):
                a = f * 2 * math.pi / NFR[sname] + 0.2
                p, m = rock_img(base, feats, R, tname, a, 4 * w, 4 * h, seed=t * 100 + f)
                add('rock_%s_%s_%d' % (tname, sname, f), p, m, opaque=True)
    for f in range(2):
        p, m = saucer_img(f); add('saucer%d' % f, p, m, opaque=True)
    for f in range(2):
        p, m = hunter_img(f); add('hunter%d' % f, p, m, opaque=True)
    for i in range(8):
        p, m = sting_img(i * 2 * math.pi / 8); add('sting%d' % i, p, m, opaque=True)
    for f in range(2):
        p, m = mine_img(f); add('mine%d' % f, p, m, opaque=True)
    for c in ('TOPAZ', 'RUBY', 'EMERALD'):
        for f in range(4):
            p, m = jewel_img(f); add('jewel_%s_%d' % (c, f), p, m, opaque=True)
    for k in ('SHIELD', 'BOMB', 'SPREAD', 'RAPID', 'LIFE'):
        p, m = pickup_img(k)
        add('pick_%s_0' % k, p, m, opaque=True)      # 2nd frame: same art, colour blinks
        add('pick_%s_1' % k, p, m, opaque=True)
    add('ring0', ellipse_ring(32, 20, 7.0, 6.4, 0.7))
    add('ring1', ellipse_ring(56, 32, 13.0, 11.0, 0.8))
    add('ring2', ellipse_ring(80, 48, 19.0, 16.6, 0.9, dash=10))
    p, m = bullet_img(True); add('bullet', p, m)
    p, m = bullet_img(False); add('dot', p, m)
    for i in range(16):
        add('flame%d_0' % i, flame_img(i * 2 * math.pi / 16, 0))
        add('flame%d_1' % i, flame_img(i * 2 * math.pi / 16, 1))
    for ch in GLYPHS:
        add('glyph_%s' % ch, glyph_img(ch))
    for i, (p, m) in enumerate(logo_bands()):
        add('logo%d' % i, p, m, opaque=True, topleft=True)
    return SPRITES


def logo_bands():
    """'ASTEROIDS II' title: chunky letters, dithered vertical shading,
    an outline and a drop shadow; cut into 16-line bands so every band can
    have its own colour (one colour per character cell)."""
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype('/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf', 120)
    text = 'ASTEROIDS II'
    bb = font.getbbox(text)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    im = Image.new('L', (tw + 8, th + 8), 0)
    ImageDraw.Draw(im).text((4 - bb[0], 4 - bb[1]), text, font=font, fill=255)
    W, H = 456, 40                      # pixels are 2:3, so this is ~ 1.7:1 visually wider
    face = np.array(im.resize((W, H), Image.Resampling.LANCZOS)) > 110
    out = np.zeros((48, W + 8), bool)
    sil = np.zeros_like(out)
    F = np.zeros_like(out)
    F[2:2 + H, 2:2 + W] = face
    shadow = np.zeros_like(out)
    shadow[5:5 + H, 6:6 + W] = face
    outline = grow(F) & ~F
    ys = np.arange(48)[:, None] * np.ones((1, W + 8))
    shade = 1.0 - np.clip((ys - 2) / H, 0, 1) * 0.55
    body = F & (dither(shade) | (ys < 12))
    # a bright bevel on the top edge of every letter
    top = F & ~np.roll(F, 1, axis=0)
    out = body | top | (shadow & ~grow(F) & dither(np.full(out.shape, 0.45)))
    sil = grow(F) | shadow
    out &= sil
    sil = np.ones_like(out)             # a solid panel: hides the demo behind it
    return [(out[i * 16:(i + 1) * 16], sil[i * 16:(i + 1) * 16]) for i in range(3)]


def sheet(path, scale=2):
    from PIL import Image
    build()
    cols = 16
    cw, ch = 84, 52
    rows = (len(SPRITES) + cols - 1) // cols
    img = np.zeros((rows * ch, cols * cw, 3), np.uint8)
    img[:] = (0, 0, 150)
    for i, (n, p, m, o) in enumerate(SPRITES):
        y0, x0 = (i // cols) * ch + 2, (i % cols) * cw + 2
        h, w = p.shape
        sub = img[y0:y0 + h, x0:x0 + w]
        sub[m & ~p] = (0, 0, 90) if o else sub[m & ~p]
        sub[p] = (120, 255, 120)
    im = Image.fromarray(img)
    im = im.resize((im.width * scale, int(im.height * scale * 1.5)), Image.Resampling.NEAREST)
    im.save(path)


if __name__ == '__main__':
    import sys
    sheet(sys.argv[1] if len(sys.argv) > 1 else 'sheet.png')
    print(len(SPRITES), 'sprites')
