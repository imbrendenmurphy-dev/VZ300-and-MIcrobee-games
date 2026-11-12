"""GROOVY GHOULIES: the twelve monsters, redrawn as cartoon characters.

Every monster is built from named parts. Each part is a flat colour with a
shaded side (dithered towards its darker partner ink, light from the upper
left) and the painter adds the black ink lines itself: two pixels round the
silhouette, one pixel wherever two parts meet. That keeps most 8x8 cells to
"one colour plus black", which is what the Microbee can show.

Canvas: 160x176, pasted at (80,18) on the 320x256 battle screen, so screen
cell rows start at sprite y = 6, 14, 22 ... and columns at x = 0, 8, 16 ...

Frames: 0 idle, 1 idle variation (blink, bob), 2 attack. The ghost also has
eight idle phases for the expanded-RAM animation.
"""
import math
import numpy as np
from PIL import Image, ImageDraw

W, H = 160, 176
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 + 1 / 32.0
# darker partner ink used for the shaded side of a part
DARKER = {15: 7, 7: 8, 8: 0, 14: 6, 6: 0, 13: 5, 5: 0, 9: 1, 1: 0, 10: 2, 2: 0, 11: 3, 3: 0, 12: 4, 4: 0, 0: 0}


class Toon:
    def __init__(self):
        self.ink = np.full((H, W), -1, np.int16)
        self.pid = np.zeros((H, W), np.int32)
        self.parts = {}
        self.n = 0
        self.decals = []

    # ---- geometry -------------------------------------------------------------
    @staticmethod
    def mask(kind, geo, width=1):
        im = Image.new('L', (W, H))
        d = ImageDraw.Draw(im)
        if kind == 'line':
            d.line(geo, fill=255, width=width, joint='curve')
            r = width // 2
            if width > 2:
                for x, y in (geo[0], geo[-1]):
                    d.ellipse((x - r, y - r, x + r, y + r), fill=255)
        elif kind in ('pieslice', 'chord'):
            box, a0, a1 = geo
            getattr(d, kind)(box, a0, a1, fill=255)
        elif kind == 'arc':
            box, a0, a1 = geo
            d.arc(box, a0, a1, fill=255, width=width)
        else:
            getattr(d, kind)(geo, fill=255)
        return np.asarray(im) > 127

    def part(self, kind, geo, ink, shade=None, width=1, line=True, light=(-.7, -.7), gloss=None, under=False,
             tex=None):
        """Paint a part. shade: None = darker partner ink, 0 = black, False = flat.
        under=True paints only where the canvas is still empty."""
        m = self.mask(kind, geo, width)
        if under:
            m &= self.ink < 0
        if not m.any():
            return None
        self.n += 1
        self.ink[m] = ink
        self.pid[m] = self.n
        self.parts[self.n] = dict(ink=ink, shade=DARKER.get(ink, 0) if shade is None else shade, line=line,
                                  light=light, gloss=gloss, tex=tex)
        return self.n

    def decal(self, kind, geo, ink, width=1):
        """Detail painted after shading and lines (pupils, teeth, glints)."""
        self.decals.append((kind, geo, ink, width))

    # ---- finishing ----------------------------------------------------------------
    def finish(self, outline=2):
        from scipy import ndimage as nd
        ink = self.ink.copy()
        yy, xx = np.indices((H, W))
        lit = BAYER[yy % 4, xx % 4]
        for n, p in self.parts.items():
            m = self.pid == n
            if not m.any() or p['shade'] is False:
                continue
            ys, xs = np.nonzero(m)
            x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
            # roundness: distance to the part's own edge, 0 at the rim, 1 deep inside
            depth = nd.distance_transform_edt(np.pad(m, 1))[1:-1, 1:-1]
            depth = np.clip(depth / max(2.0, min(x1 - x0, y1 - y0) * .32), 0, 1)
            u = (xx - (x0 + x1) / 2) / max(1, (x1 - x0) / 2)
            v = (yy - (y0 + y1) / 2) / max(1, (y1 - y0) / 2)
            lx, ly = p['light']
            facing = -(u * lx + v * ly) / math.hypot(lx, ly)     # +1 = away from the light
            s = .55 * facing + .55 * (1 - depth) - .1
            band1 = s > .28                                     # dithered towards the shade ink
            band2 = s > .62                                     # solid shade
            shade = p['shade']
            dark = m & ((band2) | (band1 & (lit < (s - .28) * 2.4)))
            if p['tex'] == 'fur':
                dark |= m & (((xx + (yy // 3) * 2) % 6) == 0) & (((yy + xx // 4) % 3) != 0) & (s > -.25)
            elif p['tex'] == 'stone':
                dark |= m & ((((xx * 7 + yy * 13) % 23) == 0) | (((xx * 11 + yy * 5) % 37) == 0))
            elif p['tex'] == 'cloth':
                dark |= m & (((xx - yy // 2) % 9) == 0) & (s > -.35)
            elif p['tex'] == 'membrane':
                dark |= m & (((xx + yy) % 2) == 0) & (s > .05)
            ink[dark] = shade
            if shade and p.get('deep', True):
                deep = m & (s > .95) & (lit < (s - .95) * 3)
                ink[deep] = 0
            if p['gloss'] is not None:
                g = m & (facing < -.35) & (depth > .25) & (depth < .75) & (lit < (-.35 - facing) * 2.2)
                ink[g] = p['gloss']
        # inner lines where a later part overlaps an earlier one
        lines = np.zeros((H, W), bool)
        pid = self.pid
        ok = np.zeros((H, W), bool)
        for n, p in self.parts.items():
            if p['line']:
                ok |= pid == n
        for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
            nb = np.roll(np.roll(pid, dy, 0), dx, 1)
            nbok = np.roll(np.roll(ok, dy, 0), dx, 1)
            lines |= (pid > 0) & (nb > pid) & ok & nbok
        ink[lines] = 0
        # outer silhouette
        solid = ink >= 0
        for _ in range(outline):
            grow = solid.copy()
            grow[1:, :] |= solid[:-1, :]; grow[:-1, :] |= solid[1:, :]
            grow[:, 1:] |= solid[:, :-1]; grow[:, :-1] |= solid[:, 1:]
            ink[grow & ~solid] = 0
            solid = grow
        self.feature = np.zeros((H, W), bool)
        for kind, geo, c, width in self.decals:
            m = self.mask(kind, geo, width)
            ink[m] = c
            self.feature |= m
        return ink

    def cells(self, ink, pal, top=6):
        """Make every 8x8 screen cell the monster touches hold two colours at most.
        Empty pixels in those cells become black (a halo that keeps the room's
        colours out of the monster's cells); then any cell still holding three or
        more colours keeps the pair that costs least, counting feature pixels
        (eyes, teeth, mouths) four times over."""
        pal = np.asarray(pal, np.int64)
        out = ink.copy()
        for y0 in range(top - 8, H, 8):
            for x0 in range(0, W, 8):
                ys, xs = slice(max(0, y0), y0 + 8), slice(x0, x0 + 8)
                blk = out[ys, xs]
                if not (blk >= 0).any():
                    continue
                blk[blk < 0] = 0
                cols = np.unique(blk)
                if len(cols) > 2:
                    wgt = np.where(self.feature[ys, xs], 4, 1)
                    best = None
                    for i in range(len(cols)):
                        for j in range(i + 1, len(cols)):
                            a, b = cols[i], cols[j]
                            da = ((pal[blk] - pal[a]) ** 2).sum(-1)
                            db = ((pal[blk] - pal[b]) ** 2).sum(-1)
                            cost = (np.minimum(da, db) * wgt).sum()
                            if best is None or cost < best[0]:
                                best = (cost, a, b, da <= db)
                    _, a, b, near_a = best
                    blk[:] = np.where(near_a, a, b)
                out[ys, xs] = blk
        return out

    def image(self, pal, outline=2):
        ink = self.cells(self.finish(outline), pal)
        out = np.zeros((H, W, 4), np.uint8)
        m = ink >= 0
        out[m, :3] = np.asarray(pal)[ink[m]]
        out[m, 3] = 255
        return Image.fromarray(out, 'RGBA')

    # ---- features ---------------------------------------------------------------
    def eye(self, cx, cy, rx, ry, look=(0, 0), white=15, pupil=0, lid=0, skin=None, glint=True, iris=None):
        """Cartoon eye. lid 0..1 closes from the top in the skin ink."""
        self.part('ellipse', (cx - rx, cy - ry, cx + rx, cy + ry), white, shade=False)
        if lid >= .95:
            self.part('ellipse', (cx - rx, cy - ry, cx + rx, cy + ry), skin, shade=False, line=False)
            self.decal('arc', ((cx - rx + 1, cy - ry * .6, cx + rx - 1, cy + ry * .5), 15, 165), 0, 3)
            for k in (-1, 0, 1):
                self.decal('line', [(cx + k * rx * .55, cy + ry * .45), (cx + k * rx * .75, cy + ry * .8)], 0, 1)
            return
        px, py = cx + look[0] * rx * .45, cy + look[1] * ry * .45
        pr = max(2, int(min(rx, ry) * .52))
        if iris is not None:
            ir = max(3, int(min(rx, ry) * .78))
            self.decal('ellipse', (px - ir, py - ir, px + ir, py + ir), iris)
        self.decal('ellipse', (px - pr, py - pr, px + pr, py + pr), pupil)
        if glint:
            self.decal('rectangle', (px - pr + 1, py - pr + 1, px - pr + 2, py - pr + 2), 15)
        if lid > 0:
            top = cy - ry + 2 * ry * lid
            self.decal('rectangle', (cx - rx, cy - ry - 1, cx + rx, top), skin)
            self.decal('line', [(cx - rx, top), (cx + rx, top)], 0, 2)

    def grin(self, cx, cy, w, h, teeth=11, ink=0, fangs=False, open_=False, tongue=None, gap=None):
        """A wide cartoon grin: black mouth, a row of teeth along the top."""
        if open_:
            self.decal('chord', ((cx - w, cy - h, cx + w, cy + h * 1.6), 0, 180), ink)
            if tongue is not None:
                self.decal('ellipse', (cx - w * .45, cy + h * .4, cx + w * .45, cy + h * 1.5), tongue)
        else:
            self.decal('chord', ((cx - w, cy - h, cx + w, cy + h), 0, 180), ink)
        if teeth is None:
            return
        step = max(4, w // 3)
        x = cx - w + 3
        i = 0
        while x < cx + w - 4:
            if gap is None or i not in gap:
                self.decal('rectangle', (x, cy + 1, x + step - 2, cy + 3), teeth)
            x += step
            i += 1
        if fangs:
            for fx in (cx - w * .55, cx + w * .55):
                self.decal('polygon', [(fx - 3, cy + 1), (fx + 3, cy + 1), (fx, cy + 9)], 15)


def cellfix(img, pal, top=0):
    """Two-colours-per-cell pass with a black halo for any RGBA sprite that will
    be pasted with its top-left corner on the cell grid."""
    a = np.asarray(img)
    pal = np.asarray(pal, np.int64)
    idx = ((a[:, :, None, :3].astype(np.int64) - pal) ** 2).sum(3).argmin(2).astype(np.int16)
    idx[a[:, :, 3] == 0] = -1
    t = Toon.__new__(Toon)
    t.feature = np.zeros(idx.shape, bool)
    h, w = idx.shape
    global H, W
    keep = H, W
    H, W = h, w
    try:
        out = t.cells(idx, pal, top)
    finally:
        H, W = keep
    rgba = np.zeros((h, w, 4), np.uint8)
    m = out >= 0
    rgba[m, :3] = pal[out[m]]
    rgba[m, 3] = 255
    return Image.fromarray(rgba, 'RGBA')


def mirror(pts, cx=80):
    return [(2 * cx - x, y) for x, y in pts]


def sym(fn, *args, **kw):
    """Call fn for the left side, then its mirror image."""
    for side in (-1, 1):
        fn(side, *args, **kw)


def smooth(points, n=8):
    """Closed Catmull-Rom curve through points."""
    out = []
    k = len(points)
    for i in range(k):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % k], points[(i + 2) % k]
        for j in range(n):
            t = j / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(.5 * ((2 * p1[a]) + (-p0[a] + p2[a]) * t + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t2 +
                                   (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t3) for a in (0, 1)))
    return out


# =============================================================================
# The ghoulies
# =============================================================================

def bend(p0, p1, bulge, n=8):
    """Points from p0 to p1 along an arc pushed sideways by bulge pixels."""
    mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy) or 1
    cx, cy = mx - dy / L * bulge, my + dx / L * bulge
    out = []
    for i in range(n + 1):
        t = i / n
        out.append(((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * cx + t * t * p1[0],
                    (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * cy + t * t * p1[1]))
    return out


def bat_wing(t, side, flap, span, ink, lord):
    sx = lambda x, y: (80 + side * x, y)
    shoulder = sx(22, 70)
    wrist = sx(46, 34 + flap)
    tips = [sx(56, 6 + flap * 1.2), sx(span, 26 + flap), sx(span + 2, 66 + flap * .6), sx(span - 12, 96 + flap * .2)]
    hip = sx(24, 112)
    pts = [shoulder, wrist, tips[0]]
    prev = tips[0]
    for tip in tips[1:]:
        pts += bend(prev, tip, side * 7)[1:]
        prev = tip
    pts += bend(prev, hip, side * 10)[1:]
    t.part('polygon', pts, ink, shade=5, tex='membrane', light=(-side * .2, -1))
    # finger bones: dark rod with a lit top edge
    bone = 5 if not lord else 1
    for tip in [wrist] + tips:
        a = shoulder if tip == wrist else wrist
        t.decal('line', [a, tip], 0, 4)
        t.decal('line', [a, tip], bone, 2)
    t.decal('ellipse', (wrist[0] - 4, wrist[1] - 4, wrist[0] + 4, wrist[1] + 4), 0)
    t.decal('polygon', [(wrist[0] - 2, wrist[1] - 2), (wrist[0] + side * 7, wrist[1] - 9), (wrist[0] + 3, wrist[1])], 15)


def bat(frame, lord=False):
    t = Toon()
    flap = (0, -12, 10)[frame]
    span = 79 if lord else 72
    fur = 5
    for side in (-1, 1):
        bat_wing(t, side, flap, span, 13, lord)
    # ears with pink insides
    for side in (-1, 1):
        tip = 6 if lord else 12
        t.part('polygon', [(80 + side * 6, 54), (80 + side * 24, tip), (80 + side * 32, 50)], fur, shade=False)
        t.part('polygon', [(80 + side * 13, 48), (80 + side * 23, tip + 12), (80 + side * 27, 48)],
               9 if lord else 13, shade=False, line=False)
    # round furry body, cream tummy, fluffy head
    t.part('ellipse', (52, 86, 108, 152), fur, shade=0, tex='fur')
    t.part('ellipse', (62, 100, 98, 144), 13, shade=5, line=True, tex='fur')
    head = [(50, 66), (54, 50), (66, 40), (80, 44), (94, 40), (106, 50), (110, 66), (106, 84), (92, 96), (68, 96), (54, 84)]
    t.part('polygon', smooth(head, 5), fur, shade=0, tex='fur')
    for x in range(56, 106, 7):                           # fluffy chest ruff
        t.part('polygon', [(x - 4, 92), (x + 3, 92), (x, 102)], fur, shade=False, under=False, line=False)
    # little feet
    for side in (-1, 1):
        x = 80 + side * 12
        t.part('polygon', [(x - 6, 148), (x + 6, 148), (x + side * 10, 162), (x, 158), (x - side * 4, 162)], 11, shade=3)
    if lord:
        t.part('polygon', [(60, 46), (58, 22), (69, 33), (80, 14), (91, 33), (102, 22), (100, 46)], 11, shade=3,
               gloss=15)
        for x, y in ((69, 38), (80, 32), (91, 38)):
            t.decal('ellipse', (x - 3, y - 3, x + 3, y + 3), 9)
    look = (0, .35) if frame != 2 else (0, .7)
    if lord:
        # narrow glowing eyes under a heavy scowl
        for side in (-1, 1):
            cx = 80 + side * 15
            t.part('polygon', [(cx - 10, 58 - side * 4), (cx + 10, 58 + side * 4), (cx + 8, 72), (cx - 8, 72)], 9,
                   shade=1, gloss=11)
            if frame != 1:
                t.decal('rectangle', (cx - 2, 63, cx + 2, 69), 15)
            t.decal('line', [(cx - 12, 53 - side * 6), (cx + 12, 55 + side * 6)], 0, 3)
    else:
        for side in (-1, 1):
            t.eye(80 + side * 14, 64, 11, 13, look=look, lid=1 if frame == 1 else (.3 if frame == 2 else 0),
                  skin=fur, iris=11)
        if frame != 2:
            for side in (-1, 1):                         # rosy cheeks
                t.decal('ellipse', (80 + side * 26 - 4, 78, 80 + side * 26 + 4, 82), 13)
    t.decal('polygon', [(76, 78), (84, 78), (80, 83)], 0)
    if frame == 2:
        w = 18 if lord else 14
        t.grin(80, 86, w, 6, teeth=None, open_=True, tongue=9)
        for fx in (80 - w * .55, 80 + w * .55):
            t.decal('polygon', [(fx - 3, 85), (fx + 3, 85), (fx, 97)], 15)
    else:
        t.decal('arc', ((64, 76, 96, 92), 25, 155), 0, 2)
        for fx in (73, 87):
            t.decal('polygon', [(fx - 2, 89), (fx + 2, 89), (fx, 95)], 15)
    return t


def bone(t, a, b, w=6, ink=15, knob=True):
    """A cartoon bone from a to b with knobbly ends."""
    t.part('line', [a, b], ink, shade=7, width=w)
    if knob:
        r = w * .75
        for x, y in (a, b):
            t.part('ellipse', (x - r, y - r, x + r, y + r), ink, shade=7)


def skull(t, cx, cy, s=1.0, jaw=0, glow=9, ink=15, crack=True, frown=False, sockets=0):
    """Big round cartoon skull. jaw = how far the jaw drops (pixels)."""
    r = 23 * s
    t.part('ellipse', (cx - r, cy - r, cx + r, cy + r * .9), ink, shade=7, gloss=None, light=(-.8, -.6))
    jw = 15 * s
    t.part('polygon', smooth([(cx - jw, cy + 8 * s + jaw), (cx + jw, cy + 8 * s + jaw), (cx + jw * .8, cy + 26 * s + jaw),
                              (cx, cy + 30 * s + jaw), (cx - jw * .8, cy + 26 * s + jaw)], 4), ink, shade=7)
    for side in (-1, 1):
        ex = cx + side * 10 * s
        t.decal('ellipse', (ex - 8 * s, cy - 6 * s, ex + 8 * s, cy + 9 * s), 0)
        if frown:
            t.decal('polygon', [(ex - 9 * s, cy - 8 * s - side * 3), (ex + 9 * s, cy - 8 * s + side * 3),
                                (ex + 9 * s, cy - 3 * s + side * 3), (ex - 9 * s, cy - 3 * s - side * 3)], 0)
        if glow is not None:
            t.decal('ellipse', (ex - 2 * s + sockets, cy + 0, ex + 2 * s + sockets, cy + 4 * s), glow)
            t.decal('rectangle', (ex - 1 * s + sockets, cy + 1, ex + sockets, cy + 2), 15)
    t.decal('polygon', [(cx - 4 * s, cy + 10 * s), (cx + 4 * s, cy + 10 * s), (cx, cy + 17 * s)], 0)
    # teeth: a row on the skull, a row on the jaw, one missing
    y = cy + 20 * s
    t.decal('rectangle', (cx - 12 * s, y - 1, cx + 12 * s, y + 1 + jaw), 0)
    for k in range(-3, 3):
        x = cx + k * 4 * s
        if k != 1:
            t.decal('rectangle', (x + 1, y - 4 * s, x + 3 * s, y - 1), ink)
        t.decal('rectangle', (x + 1, y + 2 + jaw, x + 3 * s, y + 5 * s + jaw), ink)
    if crack:
        t.decal('line', [(cx + 6 * s, cy - r + 2), (cx + 3 * s, cy - r + 9 * s), (cx + 8 * s, cy - r + 14 * s)], 0, 1)


def skeleton(frame, knight=False, king=False):
    t = Toon()
    lean = (0, 2, -2)[frame]
    x = 76 + lean
    jaw = (2, 7, 4)[frame]
    # legs and pelvis
    for side in (-1, 1):
        hip, knee, foot = (x + side * 9, 116), (x + side * 15, 142), (x + side * 17, 166)
        bone(t, hip, knee, 6)
        bone(t, knee, foot, 6)
        t.part('polygon', [(foot[0] - 7, foot[1] - 2), (foot[0] + 3 + side * 9, foot[1]), (foot[0] + 4 + side * 10, foot[1] + 6),
                           (foot[0] - 7, foot[1] + 6)], 15, shade=7)
    t.part('polygon', smooth([(x - 18, 106), (x, 100), (x + 18, 106), (x + 14, 122), (x, 118), (x - 14, 122)], 3), 15,
           shade=7)
    t.decal('ellipse', (x - 10, 108, x - 4, 114), 0)
    t.decal('ellipse', (x + 4, 108, x + 10, 114), 0)
    # spine and ribs
    for k in range(6):
        y = 62 + k * 7
        t.part('ellipse', (x - 4, y, x + 4, y + 6), 15, shade=7)
    for k in range(4):
        y = 66 + k * 9
        w = 22 - k * 2
        t.part('arc', ((x - w, y - 5, x + w, y + 14), 195, 345), 15, shade=7, width=4)
        t.part('arc', ((x - w, y - 2, x + w, y + 16), 195, 250), 15, shade=7, width=4)
        t.part('arc', ((x - w, y - 2, x + w, y + 16), 290, 345), 15, shade=7, width=4)
    # shield arm (behind the shield) and sword arm
    sh = (x - 26, 66)
    bone(t, (x - 14, 60), sh, 5)
    bone(t, sh, (x - 30, 92), 5)
    # sword
    if frame == 2:
        hand = (x + 30, 30)
        bone(t, (x + 14, 60), (x + 30, 52), 5)
        bone(t, (x + 30, 52), hand, 5)
        tip, guard = (x + 60, -2 + 6), (x + 32, 26)
        blade = [(hand[0] + 1, hand[1] - 4), (hand[0] + 8, hand[1] - 10), (x + 66, 2), (x + 70, 6), (hand[0] + 12, hand[1] - 4)]
        t.part('polygon', blade, 7, shade=8, gloss=15, light=(-.3, -1))
        t.part('line', [(hand[0] - 2, hand[1] - 12), (hand[0] + 12, hand[1] + 4)], 11, shade=3, width=5)
    else:
        hand = (x + 36, 92 - frame * 3)
        bone(t, (x + 14, 60), (x + 30, 76), 5)
        bone(t, (x + 30, 76), hand, 5)
        hx = hand[0]
        t.part('polygon', [(hx - 4, hand[1] - 8), (hx - 4, 6), (hx + 1, 0), (hx + 6, 6), (hx + 6, hand[1] - 8)], 7, shade=8,
               gloss=15, light=(-1, -.2))
        t.part('line', [(hx - 10, hand[1] - 7), (hx + 12, hand[1] - 7)], 11, shade=3, width=5)
        t.part('line', [(hx + 1, hand[1] - 7), (hx + 1, hand[1] + 6)], 3, shade=0, width=4)
        t.part('ellipse', (hx - 3, hand[1] + 5, hx + 5, hand[1] + 12), 9, shade=1)
        t.decal('line', [(hx + 1, 10), (hx + 1, hand[1] - 14)], 15, 1)
    t.part('ellipse', (hand[0] - 5, hand[1] - 5, hand[0] + 5, hand[1] + 5), 15, shade=7)
    # round wooden shield, dented, with an iron rim and a skull boss
    sx, sy, r = x - 36, 96 + (frame == 1) * 2, 22
    t.part('ellipse', (sx - r, sy - r, sx + r, sy + r), 7, shade=8, gloss=15)
    t.part('ellipse', (sx - r + 4, sy - r + 4, sx + r - 4, sy + r - 4), 3, shade=1, tex='cloth')
    for k in (-1, 1):
        t.decal('line', [(sx + k * 7, sy - r + 4), (sx + k * 7, sy + r - 4)], 0, 1)
    t.part('ellipse', (sx - 7, sy - 7, sx + 7, sy + 7), 7, shade=8, gloss=15)
    t.decal('line', [(sx + 10, sy + 8), (sx + 15, sy + 14), (sx + 12, sy + 17)], 0, 1)   # dent
    skull(t, x + 2, 34, 1.0, jaw=jaw, glow=9 if frame != 1 else 11, frown=frame == 2)
    if frame == 1:
        for k, (dx, dy) in enumerate(((-34, 18), (34, 12))):      # rattle marks
            t.decal('arc', ((x + dx - 6, dy - 6, x + dx + 6, dy + 6), 200 if dx < 0 else -20, 340 if dx < 0 else 120), 15, 2)
    return t


def ghost_shape(sway, wave, arms, bob):
    top = 10 + bob
    pts = [(80, top), (102, top + 6), (116, top + 26), (120, top + 58)]
    if arms:
        pts += [(132, top + 44), (148, top + 34), (150, top + 46), (134, top + 72), (122, top + 86)]
    else:
        pts += [(132, top + 78), (140, top + 96), (126, top + 96), (122, top + 104)]
    hem = top + 140
    n = 5
    for k in range(n + 1):
        xk = 122 - k * (84 / n) + sway * (k / n)
        yk = hem + (8 if k % 2 == 0 else -6) + math.sin(wave + k * 1.3) * 4
        pts.append((xk, yk))
    if arms:
        pts += [(38, top + 86), (26, top + 72), (10, top + 46), (12, top + 34), (28, top + 44)]
    else:
        pts += [(38, top + 104), (34, top + 96), (20, top + 96), (28, top + 78)]
    pts += [(40, top + 58), (44, top + 26), (58, top + 6)]
    return smooth(pts, 4)


def ghost(frame, phase=None):
    t = Toon()
    if phase is None:
        bob, wave, blink, sway = (0, -4, -2)[frame], frame * 1.4, frame == 1, (0, 4, -4)[frame]
    else:
        bob = (0, -1, -2, -3, -2, -1, 0, 1)[phase]
        wave = phase * math.pi / 4
        blink = phase == 4
        sway = (0, 2, 4, 2, 0, -2, -4, -2)[phase]
    arms = frame == 2
    t.part('polygon', ghost_shape(sway, wave, arms, bob), 15, shade=14, light=(-.8, -.5))
    # inner folds: cyan creases
    for k, x0 in enumerate((58, 74, 92, 106)):
        y0 = 92 + bob
        t.decal('line', [(x0, y0), (x0 + sway * .4 + math.sin(wave + k) * 2, y0 + 30), (x0 + sway * .7, y0 + 50)], 14, 2)
    cy = 52 + bob
    for side in (-1, 1):
        cx = 80 + side * 15
        if blink:
            t.decal('arc', ((cx - 9, cy - 4, cx + 9, cy + 10), 200, 340), 0, 3)
            continue
        t.decal('ellipse', (cx - 9, cy - 14, cx + 9, cy + 12), 0)
        t.decal('ellipse', (cx - 5 + side, cy - 10, cx - 1 + side, cy - 4), 15)
        t.decal('rectangle', (cx + 2, cy + 4, cx + 3, cy + 5), 12)
        if arms:
            t.decal('line', [(cx - side * 10, cy - 22), (cx + side * 9, cy - 16)], 0, 3)   # cross brows
    my = 80 + bob
    if arms:
        t.decal('ellipse', (66, my - 4, 94, my + 26), 0)
        t.decal('ellipse', (72, my + 12, 88, my + 24), 9)
    else:
        t.decal('ellipse', (73, my, 87, my + 14 + (phase or 0) % 2), 0)
        t.decal('ellipse', (76, my + 7, 84, my + 13), 9)
    for side in (-1, 1):
        t.decal('ellipse', (80 + side * 30 - 4, cy + 14, 80 + side * 30 + 4, cy + 18), 13)   # blush
    return t


def gargoyle(frame):
    t = Toon()
    lift = (0, 0, -8)[frame]
    # wings: tattered stone-bat wings in charcoal purple
    for side in (-1, 1):
        sx = lambda x, y: (80 + side * x, y)
        root, wrist = sx(20, 72), sx(48, 30 + lift)
        tips = [sx(52, 4 + lift), sx(78, 30 + lift), sx(78, 80 + lift // 2), sx(58, 104)]
        pts = [root, wrist, tips[0]]
        prev = tips[0]
        for tip in tips[1:]:
            pts += bend(prev, tip, side * 6)[1:]
            prev = tip
        pts += bend(prev, sx(30, 112), side * 8)[1:]
        t.part('polygon', pts, 5, shade=0, tex='membrane', light=(-side * .2, -1))
        for tip in [wrist] + tips:
            a = root if tip == wrist else wrist
            t.decal('line', [a, tip], 0, 4)
            t.decal('line', [a, tip], 8, 2)
    # plinth
    t.part('polygon', [(30, 152), (130, 152), (138, 160), (22, 160)], 7, shade=8, tex='stone', gloss=15)
    t.part('rectangle', (26, 160, 134, 175), 8, shade=0, tex='stone')
    for x in (44, 80, 116):
        t.decal('ellipse', (x - 5, 163, x + 5, 172), 0)
        t.decal('ellipse', (x - 3, 165, x + 3, 170), 7)
    # haunches and feet
    for side in (-1, 1):
        t.part('ellipse', (80 + side * 30 - 22, 108, 80 + side * 30 + 22, 152), 7, shade=8, tex='stone', gloss=15)
        for k in range(3):
            fx = 80 + side * (22 + k * 8)
            t.part('polygon', [(fx - 4, 146), (fx + 4, 146), (fx + side * 2, 156)], 7, shade=8)
            t.decal('polygon', [(fx - 1 + side * 2, 154), (fx + 2 + side * 2, 154), (fx + side * 3, 158)], 15)
    # barrel chest with carved muscles
    t.part('polygon', smooth([(56, 70), (80, 64), (104, 70), (110, 104), (96, 136), (64, 136), (50, 104)], 4), 7,
           shade=8, tex='stone', gloss=15)
    for y in (100, 112, 124):
        t.decal('arc', ((66, y - 6, 94, y + 6), 20, 160), 8, 2)
    t.decal('arc', ((58, 72, 80, 98), 0, 180), 8, 2)
    t.decal('arc', ((80, 72, 102, 98), 0, 180), 8, 2)
    # arms with big claws
    reach = 12 if frame == 2 else 0
    for side in (-1, 1):
        sh = (80 + side * 26, 76)
        el = (80 + side * (38 + reach), 104 - reach)
        hd = (80 + side * (32 + reach), 132 - reach * 3)
        t.part('line', [sh, el], 7, shade=8, width=12, tex='stone')
        t.part('line', [el, hd], 7, shade=8, width=10, tex='stone')
        for k in range(3):
            cx = hd[0] + (k - 1) * 6
            tip = (cx + side * (2 + k), hd[1] + 14 if frame != 2 else hd[1] - 14)
            t.part('polygon', [(cx - 3, hd[1]), (cx + 3, hd[1]), tip], 15, shade=7)
    # head: horns, pointed ears, heavy brow, fangs
    hy = 30
    for side in (-1, 1):
        t.part('polygon', smooth([(80 + side * 12, hy - 8), (80 + side * 30, hy - 30), (80 + side * 38, hy - 24),
                                  (80 + side * 24, hy - 2)], 3), 15, shade=7)
        t.part('polygon', [(80 + side * 18, hy + 4), (80 + side * 40, hy - 6), (80 + side * 24, hy + 20)], 7, shade=8)
    t.part('polygon', smooth([(60, hy - 10), (80, hy - 16), (100, hy - 10), (106, hy + 14), (98, hy + 34), (80, hy + 42),
                              (62, hy + 34), (54, hy + 14)], 4), 7, shade=8, tex='stone', gloss=15)
    t.part('polygon', [(60, hy + 2), (80, hy + 8), (100, hy + 2), (100, hy + 8), (80, hy + 14), (60, hy + 8)], 8, shade=0)
    for side in (-1, 1):
        cx = 80 + side * 11
        t.decal('polygon', [(cx - 7, hy + 9), (cx + 7, hy + 9), (cx + 5, hy + 16), (cx - 5, hy + 16)], 0)
        if frame != 1:
            t.decal('polygon', [(cx - 5, hy + 10), (cx + 5, hy + 10), (cx + 3, hy + 14), (cx - 3, hy + 14)], 9)
            t.decal('rectangle', (cx - 1, hy + 11, cx, hy + 12), 11)
    t.part('polygon', [(76, hy + 16), (84, hy + 16), (86, hy + 24), (74, hy + 24)], 7, shade=8)
    t.decal('ellipse', (75, hy + 21, 78, hy + 24), 0)
    t.decal('ellipse', (82, hy + 21, 85, hy + 24), 0)
    if frame == 2:
        t.decal('chord', ((64, hy + 22, 96, hy + 42), 0, 180), 0)
        t.decal('ellipse', (72, hy + 32, 88, hy + 40), 1)
    else:
        t.decal('chord', ((66, hy + 24, 94, hy + 34), 0, 180), 0)
    for fx in (69, 91):
        t.decal('polygon', [(fx - 3, hy + 27), (fx + 3, hy + 27), (fx, hy + 36)], 15)
    if frame == 1:                                     # stone dust falling
        for k, (dx, dy) in enumerate(((-40, 60), (44, 50), (-36, 92), (40, 118))):
            t.decal('rectangle', (80 + dx, dy, 80 + dx + 1, dy + 1), 7)
    return t


def grell(frame):
    t = Toon()
    # tentacles behind the eye, each a wriggling tube with suckers
    for k in range(7):
        base = 40 + k * 13
        pts = []
        for j in range(15):
            y = 92 + j * 5.4
            reach = (k - 3) * j * (.9 if frame == 2 else .35)
            x = base + reach + math.sin(j * .45 + k * 1.7 + frame * .9) * (3 + j * .5)
            pts.append((x, y))
        t.part('line', pts, 13, shade=5, width=9)
        for j in range(3, 15, 3):
            x, y = pts[j]
            t.decal('ellipse', (x - 2, y - 1, x + 1, y + 2), 15 if (j + k) % 2 else 9)
        x, y = pts[-1]
        t.part('ellipse', (x - 3, y - 2, x + 3, y + 4), 13, shade=5)
    # fleshy body: lumpy rim with veins
    rim = []
    for a in range(16):
        ang = a * math.pi / 8
        r = 56 + (6 if a % 2 else 0)
        rim.append((80 + math.cos(ang) * r, 58 + math.sin(ang) * r * .92))
    t.part('polygon', smooth(rim, 4), 13, shade=5, gloss=15, tex='scales')
    # the eyeball, big and glossy
    t.part('ellipse', (34, 14, 126, 102), 15, shade=7, light=(-.6, -.8))
    for k, (x0, y0, x1, y1) in enumerate(((38, 52, 54, 46), (40, 70, 56, 74), (120, 50, 106, 44), (118, 72, 104, 78))):
        t.decal('line', [(x0, y0), ((x0 + x1) / 2, y0 + (2 if k % 2 else -3)), (x1, y1)], 9, 1)
    look = (-8, 0, 0)[frame], (0, -2, 6)[frame]
    ix, iy = 80 + look[0], 58 + look[1]
    ir = 26 if frame != 2 else 30
    t.decal('ellipse', (ix - ir, iy - ir, ix + ir, iy + ir), 0)
    t.decal('ellipse', (ix - ir + 2, iy - ir + 2, ix + ir - 2, iy + ir - 2), 9)
    t.decal('ellipse', (ix - ir + 8, iy - ir + 8, ix + ir - 8, iy + ir - 8), 1)
    pw = 6 if frame != 2 else 10
    t.decal('ellipse', (ix - pw, iy - 20, ix + pw, iy + 20), 0)
    t.decal('ellipse', (ix - 16, iy - 18, ix - 6, iy - 8), 15)
    t.decal('rectangle', (ix + 8, iy + 10, ix + 10, iy + 12), 15)
    if frame == 1:                                   # heavy lid half shut
        t.decal('chord', ((34, 14, 126, 102), 180, 360), 13)
        t.decal('rectangle', (34, 50, 126, 58), 13)
        t.decal('line', [(36, 58), (124, 58)], 0, 3)
        for x in range(44, 120, 9):
            t.decal('line', [(x, 59), (x - 2, 64)], 0, 1)
    # a drip of goo
    if frame != 1:
        t.decal('ellipse', (110, 104, 116, 112), 10)
        t.decal('rectangle', (112, 98, 114, 106), 10)
    return t


def zombie(frame):
    t = Toon()
    sway = (0, 4, -3)[frame]
    skin, rags = 10, 5
    # legs: one ragged trouser leg, one bare shin with bone showing
    t.part('polygon', [(56, 118), (76, 118), (74, 162), (54, 162)], rags, shade=0, tex='cloth')
    t.part('polygon', [(54, 160), (76, 160), (78, 170), (48, 170)], 3, shade=0)
    t.part('polygon', [(84, 118), (102, 118), (106, 160), (88, 162)], skin, shade=2)
    t.part('line', [(94, 130), (96, 152)], 15, shade=7, width=4)
    t.part('polygon', [(86, 160), (108, 158), (114, 170), (84, 170)], skin, shade=2)
    # torn shirt
    torso = [(52, 62), (108, 58), (114, 104), (106, 122), (98, 112), (90, 126), (80, 114), (70, 128), (62, 114), (50, 122),
             (46, 100)]
    t.part('polygon', torso, rags, shade=0, tex='cloth', light=(-.9, -.4))
    t.part('polygon', [(70, 62), (90, 60), (84, 92), (78, 86)], skin, shade=2)     # open collar, ribs
    for y in (70, 76, 82):
        t.decal('line', [(76, y), (86, y - 1)], 2, 1)
    t.decal('rectangle', (60, 80, 66, 86), 13)                                        # patch
    t.decal('rectangle', (60, 80, 66, 81), 0)
    # long arms, huge hands
    reach = 16 if frame == 2 else 0
    for side in (-1, 1):
        sh = (80 + side * 26, 66)
        hd = (80 + side * (50 + reach), 70 + side * sway - reach)
        t.part('line', [sh, ((sh[0] + hd[0]) / 2, (sh[1] + hd[1]) / 2 + 6)], rags, shade=0, width=13, tex='cloth')
        t.part('line', [((sh[0] + hd[0]) / 2, (sh[1] + hd[1]) / 2 + 6), hd], skin, shade=2, width=9)
        hx, hy = hd
        t.part('ellipse', (hx - 11, hy - 9, hx + 11, hy + 9), skin, shade=2)
        for k in range(4):
            fx = hx - 9 + k * 6
            t.part('line', [(fx, hy + 4), (fx + side * 2, hy + 18 + (k % 2) * 3)], skin, shade=2, width=5)
    t.part('line', [(36, 76), (42, 80)], 15, shade=7, width=4)                        # bone poking out
    # head: lumpy, lopsided, with stitches and a tuft of hair
    hx = 80 + sway
    head = [(hx - 22, 20), (hx - 6, 8), (hx + 14, 10), (hx + 26, 24), (hx + 24, 46), (hx + 10, 60), (hx - 12, 60),
            (hx - 26, 44)]
    t.part('polygon', smooth(head, 4), skin, shade=2, gloss=11, tex='scales')
    t.part('polygon', [(hx - 18, 16), (hx - 8, 2), (hx - 2, 12), (hx + 6, 0), (hx + 10, 12), (hx + 20, 6), (hx + 20, 18),
                       (hx - 16, 22)], 3, shade=0)
    t.decal('line', [(hx + 4, 24), (hx + 18, 22)], 0, 1)
    for x in range(hx + 6, hx + 18, 4):
        t.decal('line', [(x, 21), (x, 25)], 0, 1)
    t.eye(hx - 10, 34, 9, 10, look=(.4, .2), skin=skin, lid=.5 if frame == 1 else 0)
    t.eye(hx + 11, 33, 5, 5, look=(-.3, .3), skin=skin, iris=9, glint=False)
    if frame == 2:
        t.grin(hx, 50, 13, 4, teeth=11, open_=True, tongue=9, gap={1, 3})
    else:
        t.grin(hx + 1, 49, 12, 4, teeth=11, gap={2})
    return t


def slime(frame):
    t = Toon()
    sq = (0, -8, 10)[frame]         # + squash, - stretch
    top = 46 - sq * 1.6
    w = 64 + sq * 1.8
    pts = [(80 - w, 168), (80 - w + 6, 140), (80 - w * .8, 100 + sq), (80 - w * .5, top + 12), (80, top),
           (80 + w * .5, top + 14), (80 + w * .82, 102 + sq), (80 + w - 4, 142), (80 + w, 168)]
    drips = [(80 + w * .55, 170), (80 + w * .3, 176), (80, 170), (80 - w * .35, 176), (80 - w * .6, 170)]
    t.part('polygon', smooth(pts + drips, 5), 10, shade=2, gloss=15, light=(-.7, -.8))
    # bubbles and a swallowed bone inside
    for x, y, r in ((52, 128, 7), (106, 112, 9), (92, 148, 6), (64, 152, 4), (116, 140, 4)):
        t.decal('ellipse', (x - r, y - r + sq, x + r, y + r + sq), 2)
        t.decal('ellipse', (x - r + 2, y - r + 2 + sq, x + r - 2, y + r - 2 + sq), 10)
        t.decal('rectangle', (x - r + 2, y - r + 2 + sq, x - r + 3, y - r + 3 + sq), 15)
    t.decal('line', [(70, 136 + sq), (88, 128 + sq)], 15, 3)
    for x, y in ((68, 135), (88, 127)):
        t.decal('ellipse', (x - 3, y - 3 + sq, x + 3, y + 3 + sq), 15)
    # eyes on wobbly stalks
    for side in (-1, 1):
        bx = 80 + side * 20
        ex, ey = bx + side * (6 - sq * .3), top - 24 - (frame == 1) * 8
        t.part('line', [(bx, top + 14), (bx + side * 2, top - 4), (ex, ey + 8)], 10, shade=2, width=6)
        t.eye(ex, ey, 11, 12, look=(-side * .3, .4), skin=10, lid=1 if frame == 1 else 0)
    my = top + 46 + sq
    if frame == 2:
        t.grin(80, my, 26, 8, teeth=15, open_=True, tongue=9)
    else:
        t.grin(80, my, 22, 7, teeth=None)
        t.decal('ellipse', (72, my + 1, 88, my + 7), 9)
    return t


def ghoul_king(frame):
    t = Toon()
    x = 76
    # royal robe with ermine trim and gold edging
    robe = [(56, 60), (96, 60), (128, 166), (24, 166)]
    flutter = (0, 3, 7)[frame]
    robe = [(56, 60), (96, 60), (124 + flutter, 150), (130 + flutter, 170), (22 - flutter, 170), (28 - flutter, 150)]
    t.part('polygon', robe, 5, shade=0, tex='cloth', gloss=13)
    for k in range(5):
        t.decal('line', [(64 + k * 6, 70), (36 + k * 20 - flutter + k * flutter // 2, 166)], 0, 1)
    t.part('polygon', [(66, 64), (86, 64), (98, 166), (54, 166)], 15, shade=7)          # bone-white undertunic
    for y in range(76, 160, 14):
        t.decal('line', [(68 + (y - 64) * .12, y), (84 - (y - 64) * .12 + (y - 64) * .25, y)], 7, 1)
    t.part('polygon', [(22 - flutter, 162), (130 + flutter, 162), (132 + flutter, 172), (20 - flutter, 172)], 15, shade=7)
    for k in range(9):                                                              # ermine spots
        sx = 26 + k * 13
        t.decal('rectangle', (sx, 165, sx + 2, 168), 0)
    t.part('polygon', smooth([(38, 54), (60, 46), (92, 46), (114, 54), (104, 70), (48, 70)], 3), 15, shade=7)  # fur collar
    for k in range(7):
        t.decal('rectangle', (48 + k * 9, 58, 50 + k * 9, 61), 0)
    t.part('polygon', [(40, 66), (112, 66), (112, 70), (40, 70)], 11, shade=3)
    # staff with an orb
    sx = 122 + (frame == 2) * 6
    top = 14 if frame != 2 else 2
    t.part('line', [(sx, top + 18), (sx - 2, 168)], 11, shade=3, width=5)
    t.part('ellipse', (sx - 13, top, sx + 13, top + 26), 13, shade=5, gloss=15)
    t.part('polygon', [(sx - 10, top + 22), (sx + 10, top + 22), (sx + 6, top + 30), (sx - 6, top + 30)], 11, shade=3)
    if frame == 2:
        for a in range(8):
            ang = a * math.pi / 4
            t.decal('line', [(sx + math.cos(ang) * 16, top + 13 + math.sin(ang) * 16),
                             (sx + math.cos(ang) * 24, top + 13 + math.sin(ang) * 24)], 11, 2)
    # bony hands
    t.part('ellipse', (sx - 8, 90, sx + 6, 102), 15, shade=7)
    t.part('line', [(100, 72), (sx - 4, 94)], 5, shade=0, width=10, tex='cloth')
    t.part('line', [(52, 72), (36, 104)], 5, shade=0, width=10, tex='cloth')
    t.part('ellipse', (28, 100, 42, 114), 15, shade=7)
    for k in range(3):
        t.part('line', [(30 + k * 5, 110), (28 + k * 5, 120)], 15, shade=7, width=3)
    # skull face with a pompous moustache-less grin and a big crown
    skull(t, x, 30, 1.0, jaw=(2, 6, 3)[frame], glow=11 if frame == 2 else 9, crack=False)
    crown = [(x - 26, 16), (x - 30, -4 + 6), (x - 16, 4 + 4), (x - 8, -6 + 6), (x, 6), (x + 8, -6 + 6), (x + 16, 4 + 4),
             (x + 30, -4 + 6), (x + 26, 16)]
    t.part('polygon', crown, 11, shade=3, gloss=15)
    t.part('rectangle', (x - 27, 13, x + 27, 20), 11, shade=3)
    for k, c in enumerate((9, 12, 10, 12, 9)):
        cx = x - 20 + k * 10
        t.decal('ellipse', (cx - 3, 14, cx + 3, 19), c)
    for cx in (x - 30, x - 8, x + 8, x + 30):
        t.decal('ellipse', (cx - 2, 0, cx + 2, 4), 9)
    return t


def knight(frame):
    t = Toon()
    x = 74
    steel, dark = 7, 8
    # legs in plate
    for side in (-1, 1):
        lx = x + side * 13
        t.part('polygon', [(lx - 8, 112), (lx + 8, 112), (lx + 7, 160), (lx - 7, 160)], steel, shade=dark, gloss=15)
        t.part('ellipse', (lx - 9, 128, lx + 9, 142), steel, shade=dark, gloss=15)
        t.part('polygon', [(lx - 9, 158), (lx + 8 + side * 4, 158), (lx + 12 + side * 6, 170), (lx - 10, 170)], steel,
               shade=dark)
    # skirt of plates and a belt
    t.part('polygon', [(x - 24, 100), (x + 24, 100), (x + 28, 120), (x - 28, 120)], steel, shade=dark, gloss=15)
    for k in range(-2, 3):
        t.decal('line', [(x + k * 10, 102), (x + k * 11, 119)], dark, 1)
    t.part('rectangle', (x - 24, 98, x + 24, 104), 3, shade=0)
    t.decal('rectangle', (x - 4, 97, x + 4, 105), 11)
    # breastplate with a blue tabard
    t.part('polygon', smooth([(x - 26, 54), (x + 26, 54), (x + 24, 84), (x, 100), (x - 24, 84)], 3), steel, shade=dark,
           gloss=15, light=(-.8, -.6))
    t.part('polygon', [(x - 12, 58), (x + 12, 58), (x + 10, 98), (x - 10, 98)], 12, shade=4)
    t.decal('rectangle', (x - 2, 64, x + 2, 90), 11)
    t.decal('rectangle', (x - 8, 70, x + 8, 73), 11)
    # pauldrons
    for side in (-1, 1):
        cx = x + side * 28
        t.part('ellipse', (cx - 13, 46, cx + 13, 68), steel, shade=dark, gloss=15)
        t.decal('arc', ((cx - 11, 52, cx + 11, 72), 200, 340), dark, 1)
    # sword arm
    if frame == 2:
        hand = (x + 34, 30)
        t.part('line', [(x + 28, 58), hand], steel, shade=dark, width=10)
        # blade swung up and back over the shoulder
        hx, hy = hand
        t.part('polygon', [(hx - 6, hy - 8), (hx - 1, hy - 12), (hx + 44, hy - 30), (hx + 52, hy - 30), (hx + 44, hy - 22)],
               15, shade=7, light=(-.3, -1))
        t.decal('line', [(hx + 2, hy - 12), (hx + 44, hy - 27)], 7, 1)
        t.part('line', [(hx - 8, hy - 18), (hx + 4, hy + 2)], 11, shade=3, width=5)
        t.part('ellipse', (hx - 8, hy, hx, hy + 8), 9, shade=1)
    else:
        hand = (x + 40, 96 - frame * 2)
        t.part('line', [(x + 30, 60), (x + 38, 80), hand], steel, shade=dark, width=10)
        hx = hand[0]
        t.part('polygon', [(hx - 4, hand[1] - 8), (hx - 4, 10), (hx + 1, 2), (hx + 6, 10), (hx + 6, hand[1] - 8)], 15,
               shade=7, light=(-1, -.2))
        t.decal('line', [(hx + 1, 12), (hx + 1, hand[1] - 12)], 7, 1)
        t.part('line', [(hx - 11, hand[1] - 7), (hx + 13, hand[1] - 7)], 11, shade=3, width=5)
        t.part('ellipse', (hx - 3, hand[1] + 6, hx + 5, hand[1] + 13), 9, shade=1)
    t.part('ellipse', (hand[0] - 7, hand[1] - 6, hand[0] + 7, hand[1] + 7), dark, shade=0)
    # kite shield
    sx, sy = x - 32, 70 + (frame == 1) * 2
    shield = [(sx - 22, sy), (sx + 22, sy), (sx + 20, sy + 34), (sx, sy + 58), (sx - 20, sy + 34)]
    t.part('polygon', shield, 7, shade=8, gloss=15)
    inner = [(sx - 17, sy + 5), (sx + 17, sy + 5), (sx + 15, sy + 32), (sx, sy + 51), (sx - 15, sy + 32)]
    t.part('polygon', inner, 12, shade=4, light=(-.8, -.8))
    t.decal('rectangle', (sx - 3, sy + 8, sx + 3, sy + 46), 15)
    t.decal('rectangle', (sx - 13, sy + 18, sx + 13, sy + 24), 15)
    t.decal('line', [(sx + 10, sy + 34), (sx + 6, sy + 40)], 0, 1)
    # great helm with a plume and glowing eyes in the slit
    t.part('polygon', smooth([(x - 14, 46), (x - 20, 24), (x - 14, 8), (x, 4), (x + 14, 8), (x + 20, 24), (x + 14, 46)], 3),
           steel, shade=dark, gloss=15)
    plume = [(x + 2, 6), (x + 10, -2 + 6), (x + 28, 0), (x + 40, 12), (x + 34, 14), (x + 22, 8), (x + 8, 12)]
    sway = (0, 4, 8)[frame]
    t.part('polygon', smooth([(px + (sway if px > x + 15 else 0), py) for px, py in plume], 3), 9, shade=1, tex='fur')
    t.decal('rectangle', (x - 16, 22, x + 16, 28), 0)
    t.decal('line', [(x, 8), (x, 44)], dark, 2)
    for k in range(-2, 3):
        if k:
            t.decal('rectangle', (x + k * 5 - 1, 32, x + k * 5, 38), 0)
    glow = 14 if frame != 1 else 15
    t.decal('rectangle', (x - 11, 24, x - 6, 26), glow)
    t.decal('rectangle', (x + 6, 24, x + 11, 26), glow)
    if frame == 1:
        t.decal('polygon', [(x - 10, 12), (x - 8, 6), (x - 6, 12), (x - 12, 9), (x - 4, 9)], 15)   # glint
    return t


def dracula(frame):
    t = Toon()
    spread = (0, 2, 26)[frame]
    # cape: purple-black outside, crimson lining, high scalloped collar
    cape = [(52, 48), (108, 48), (120 + spread, 90), (136 + spread, 166), (114, 160), (96, 170), (80, 164), (64, 170),
            (46, 160), (24 - spread, 166), (40 - spread, 90)]
    t.part('polygon', cape, 4, shade=0, tex='cloth', gloss=12, light=(-.8, -.4))
    lining = [(62, 58), (98, 58), (106 + spread * .9, 100), (118 + spread * .9, 160), (42 - spread * .9, 160),
              (54 - spread * .9, 100)]
    t.part('polygon', lining, 9, shade=1, tex='cloth')
    for side in (-1, 1):
        col = [(80 + side * 14, 54), (80 + side * 30, 14), (80 + side * 46, 8), (80 + side * 40, 30), (80 + side * 50, 34),
               (80 + side * 30, 62)]
        t.part('polygon', col, 9, shade=1)
        t.part('polygon', [(80 + side * 18, 52), (80 + side * 30, 22), (80 + side * 38, 18), (80 + side * 28, 56)], 1,
               shade=0, line=False)
    # suit: black jacket, white shirt front, red medallion
    t.part('polygon', [(60, 60), (100, 60), (104, 160), (56, 160)], 8, shade=0, gloss=7)
    t.part('polygon', [(70, 60), (90, 60), (86, 104), (74, 104)], 15, shade=7)
    t.decal('polygon', [(72, 62), (80, 70), (88, 62), (86, 68), (80, 72), (74, 68)], 0)
    t.decal('polygon', [(73, 66), (80, 70), (87, 66), (87, 72), (80, 70), (73, 72)], 9)
    t.part('line', [(64, 62), (80, 92), (96, 62)], 11, shade=3, width=2)
    t.part('ellipse', (73, 88, 87, 102), 11, shade=3, gloss=15)
    t.decal('ellipse', (77, 92, 83, 98), 9)
    # hands: claws up when the cape opens, held by the cape's edge
    for side in (-1, 1):
        if frame == 2:
            hx, hy = 80 + side * 58, 70
            t.part('line', [(80 + side * 22, 62), (80 + side * 42, 76), (hx, hy + 6)], 8, shade=0, width=11, tex='cloth')
            t.part('rectangle', (hx - 8, hy + 5, hx + 8, hy + 10), 15, shade=7)
        else:
            hx, hy = 80 + side * 26, 118
        t.part('ellipse', (hx - 8, hy - 7, hx + 8, hy + 8), 15, shade=7)
        for k in range(4):
            fx = hx - 6 + k * 4
            ty = hy - 14 if frame == 2 else hy + 15
            t.part('line', [(fx, hy), (fx + side * 1, ty)], 15, shade=7, width=3)
            t.decal('rectangle', (fx, ty - 1, fx + 1, ty + 1), 9)
    # head: pale, pointy ears, widow's peak
    for side in (-1, 1):
        t.part('polygon', [(80 + side * 16, 26), (80 + side * 32, 12), (80 + side * 22, 38)], 15, shade=7)
    face = [(64, 18), (80, 10), (96, 18), (100, 34), (92, 50), (80, 56), (68, 50), (60, 34)]
    t.part('polygon', smooth(face, 4), 15, shade=7, light=(-.6, -.8))
    hair = [(60, 26), (60, 10), (70, 2), (80, 0), (90, 2), (100, 10), (100, 26), (92, 16), (80, 26), (68, 16)]
    t.part('polygon', hair, 8, shade=0, gloss=7)
    for side in (-1, 1):
        cx = 80 + side * 10
        t.decal('line', [(cx - side * 8, 23), (cx + side * 7, 28)], 0, 3)          # arched brows
        if frame == 1:
            t.decal('arc', ((cx - 6, 30, cx + 6, 37), 200, 340), 7, 2)
        else:
            t.decal('polygon', [(cx - 6 * side, 31), (cx + 6 * side, 32), (cx + 4 * side, 36), (cx - 5 * side, 35)], 9)
            t.decal('rectangle', (cx - 1, 32, cx, 33), 15)
    t.decal('line', [(80, 34), (78, 41), (82, 41)], 7, 1)
    if frame == 2:
        t.grin(80, 44, 11, 4, teeth=None, open_=True, tongue=1)
        t.grin(80, 44, 11, 4, teeth=15, fangs=True)
    else:
        t.decal('arc', ((70, 38, 90, 48), 20, 160), 0, 2)
        for fx in (74, 86):
            t.decal('polygon', [(fx - 2, 46), (fx + 2, 46), (fx, 51)], 15)
    return t


def bride(frame):
    t = Toon()
    s = (0, 3, -2)[frame]
    # veil: long, translucent (cyan dither) and drifting
    veil = [(60 + s, 18), (80 + s, 4), (100 + s, 18), (118 + s * 2, 70), (140 + s * 3, 160), (128 + s * 3, 170),
            (32 + s * 2, 170), (20 + s, 160), (42, 70)]
    t.part('polygon', smooth(veil, 3), 14, shade=6, tex='membrane', light=(-.7, -.7))
    # hair falling down both sides
    hair = [(58 + s, 26), (66 + s, 12), (80 + s, 8), (94 + s, 12), (102 + s, 26), (106 + s, 70), (96 + s, 84), (98 + s, 46),
            (62 + s, 46), (64 + s, 84), (54 + s, 70)]
    t.part('polygon', smooth(hair, 3), 5, shade=0, tex='fur', gloss=13)
    # gown: wide skirt with folds, fitted bodice
    gown = [(68, 60), (92, 60), (98, 98), (132, 166), (110, 172), (90, 166), (70, 172), (48, 166), (28, 172), (62, 98)]
    t.part('polygon', gown, 15, shade=7, tex='cloth', light=(-.9, -.3))
    for k in range(5):
        x0 = 70 + k * 5
        t.decal('line', [(x0, 104), (36 + k * 22, 166)], 7, 1)
    t.part('polygon', [(66, 96), (94, 96), (98, 104), (62, 104)], 13, shade=5)
    t.decal('ellipse', (76, 96, 84, 104), 9)                                       # rose
    # arms reaching out, ghostly hands
    reach = 16 if frame == 2 else 0
    for side in (-1, 1):
        sh = (80 + side * 12, 66)
        hd = (80 + side * (44 + reach), (88, 84, 64)[frame])
        t.part('line', [sh, ((sh[0] + hd[0]) / 2, sh[1] + 16), hd], 15, shade=14, width=7)
        t.part('ellipse', (hd[0] - 6, hd[1] - 5, hd[0] + 6, hd[1] + 6), 15, shade=14)
        for k in range(4):
            t.part('line', [(hd[0] - 5 + k * 3, hd[1] + 2), (hd[0] - 5 + k * 3 + side * 2, hd[1] + 12)], 15, shade=14,
                   width=2)
    # bouquet held at the waist in frames 0 and 1
    if frame != 2:
        t.part('line', [(80, 110), (78, 132)], 2, shade=0, width=3)
        for dx, dy, c in ((-8, 104, 9), (0, 100, 13), (8, 104, 9), (-4, 112, 13), (4, 112, 9)):
            t.part('ellipse', (80 + dx - 5, dy - 5, 80 + dx + 5, dy + 5), c, shade=1 if c == 9 else 5)
    # face: pale, heavy-lidded, a sly little smile
    face = [(68 + s, 22), (80 + s, 16), (92 + s, 22), (94 + s, 38), (86 + s, 52), (80 + s, 54), (74 + s, 52), (66 + s, 38)]
    t.part('polygon', smooth(face, 4), 15, shade=7, light=(-.6, -.8))
    t.part('polygon', [(64 + s, 26), (70 + s, 14), (80 + s, 12), (90 + s, 14), (96 + s, 26), (88 + s, 20), (80 + s, 24),
                       (72 + s, 20)], 5, shade=0)
    for k in range(5):                                                             # tiara
        x = 68 + k * 6 + s
        t.decal('ellipse', (x - 2, 9, x + 2, 13), 11)
    for side in (-1, 1):
        cx = 80 + side * 7 + s
        if frame == 1:
            t.decal('arc', ((cx - 4, 30, cx + 4, 36), 200, 340), 0, 2)
        else:
            t.decal('ellipse', (cx - 4, 31, cx + 4, 37), 0)
            t.decal('rectangle', (cx - 2, 32, cx - 1, 33), 15)
        t.decal('line', [(cx + side * 4, 31), (cx + side * 7, 30)], 0, 1)          # lashes
    if frame == 2:
        t.decal('ellipse', (76 + s, 40, 84 + s, 47), 9)
    else:
        t.decal('arc', ((74 + s, 38, 86 + s, 45), 20, 160), 9, 2)
    return t


REDRAWS = {0: bat, 1: skeleton, 2: ghost, 3: gargoyle, 4: grell, 5: zombie, 6: slime, 7: ghoul_king, 8: knight,
           9: lambda f: bat(f, lord=True), 10: dracula, 11: bride}


def monster(i, frame, pal):
    return REDRAWS[i](frame).image(pal)


if __name__ == '__main__':
    import sys
    sys.path.insert(0, __import__('os').path.dirname(__file__))
    import native_art as NA
    ids = [int(a) for a in sys.argv[1:]] or sorted(REDRAWS)
    S = Image.new('RGB', (len(ids) * 3 * 164, 180), (30, 30, 30))
    for k, i in enumerate(ids):
        for f in range(3):
            im = monster(i, f, NA.PAL)
            bg = Image.new('RGB', im.size, (0, 0, 0)); bg.paste(im, (0, 0), im)
            S.paste(bg, ((k * 3 + f) * 164, 0))
    S.resize((S.width * 2, S.height * 2), Image.NEAREST).save('/home/claude/dc2mb/shots/rev/toon.png')
    # the same frames over a grey card, so the ink lines show
    G2 = Image.new('RGB', (len(ids) * 3 * 164, 180), (30, 30, 30))
    for k, i in enumerate(ids):
        for f in range(3):
            im = monster(i, f, NA.PAL)
            bg = Image.new('RGB', im.size, (80, 80, 96)); bg.paste(im, (0, 0), im)
            G2.paste(bg, ((k * 3 + f) * 164, 0))
    G2.resize((G2.width * 2, G2.height * 2), Image.NEAREST).save('/home/claude/dc2mb/shots/rev/toon_grey.png')
