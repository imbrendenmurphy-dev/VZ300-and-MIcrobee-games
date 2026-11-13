#!/usr/bin/env python3
"""Southern Cross locale files (e.g. CORAL.LOC), assembled to load at LOCBUF.

World units: metres, x east, z north, y up.  Object vertices are in half metres.
Layout at LOCBUF:
  db 'S','C',3                    magic + version
  db name (16 chars)
  dw objtab, rwytab
  db number of runways
objtab, 10 bytes an entry, 0 ends:
  db type (1 lattice, 2 series, +128 lies flat on the ground), min detail, cull (x256 m), radius (x16 m)
  dw centre x, centre z (m), data pointer
rwytab, 20 bytes a runway:
  dw x0, z0 (threshold at the south / west end, on the centreline)
  db axis (0 runs north, 1 runs east), dw length, db half width, dw aim point
  db name (9 chars) + ' '
"""
import math

class Locale:
    def __init__(self, name):
        self.name = name
        self.objs = []      # (type, mindet, cull, rad, cx, cz, label, asm lines)
        self.rwys = []
        self.n = 0

    def _label(self):
        self.n += 1
        return 'o%d' % self.n

    # ---- lattice object: vertices (x, y, z) half metres from origin (m, half m, m)
    def mesh(self, origin, verts, edges, det=1, cull=24, centre=None, size=None, far=None):
        """far: edges (as vertex pairs) drawn when the object is small on screen"""
        ox, oy, oz = origin
        far = [tuple(e) for e in far] if far else list(edges)
        rest = [e for e in edges if tuple(e) not in far and tuple(e[::-1]) not in far]
        fv = []
        for a, b in far:
            for v in (a, b):
                if v not in fv: fv.append(v)
        order = fv + [i for i in range(len(verts)) if i not in fv]
        remap = {old: new for new, old in enumerate(order)}
        nvf = len(fv)
        verts = [verts[i] for i in order]
        edges = [(remap[a], remap[b]) for a, b in far + rest]
        nef = len(far)
        axes = []
        for k in range(3):          # values the far set uses come first
            fvals = sorted(set(v[k] for v in verts[:nvf]))
            axes.append((fvals + sorted(set(v[k] for v in verts) - set(fvals)), len(fvals)))
        (xs, nxf), (ys, nyf), (zs, nzf) = axes
        assert len(xs) <= 8 and len(ys) <= 8 and len(zs) <= 8, (len(xs), len(ys), len(zs))
        assert len(verts) <= 24 and len(edges) <= 255
        lab = self._label()
        L = ['%s:   dw %d,%d,%d' % (lab, ox, oy, oz)]
        for vals, nf in axes:
            L.append('        db %d,%d' % (len(vals), nf))
            L.append('        dw ' + ','.join(str(v) for v in vals))
        L.append('        db %d,%d' % (len(verts), nvf))
        for v in verts:
            L.append('        db %d,%d,%d' % (xs.index(v[0]), ys.index(v[1]), zs.index(v[2])))
        L.append('        db %d,%d' % (len(edges), nef))
        L.append('        db ' + ','.join('%d,%d' % e for e in edges))
        r = max(max(math.hypot(v[0], v[2]), v[1]) for v in verts) / 2
        if size: r = size          # landmarks: seen from further than their size says
        cx, cz = centre if centre else (ox, oz)
        flat = 128 if all(v[1] == 0 for v in verts) else 0     # lies on the ground
        self.objs.append((1 | flat, det, cull, r + 20, cx, cz, lab, L))

    # ---- series: S (m, half m, m), step T and length L (half m), n segments
    def series(self, s, t, l, n, det=2, cull=16):
        lab = self._label()
        L = ['%s:   dw %d,%d,%d, %d,%d,%d, %d,%d,%d' % ((lab,) + tuple(s) + tuple(t) + tuple(l)), '        db %d' % n]
        ex = ((t[0] * (n - 1) + l[0]) / 2, (t[2] * (n - 1) + l[2]) / 2)   # extent in m
        cx, cz = s[0] + ex[0] / 2, s[2] + ex[1] / 2
        self.objs.append((2 | 128, det, cull, math.hypot(*ex) / 2 + 20, cx, cz, lab, L))

    # ---- flat outline at sea level through points (x, z) in metres
    def outline(self, pts, closed=True, det=1, cull=40):
        cx = sum(p[0] for p in pts) / len(pts); cz = sum(p[1] for p in pts) / len(pts)
        cx, cz = int(round(cx)), int(round(cz))
        verts = [((x - cx) * 2, 0, (z - cz) * 2) for x, z in pts]
        n = len(pts)
        edges = [(i, (i + 1) % n) for i in range(n if closed else n - 1)]
        self.mesh((cx, 0, cz), verts, edges, det, cull)

    def box(self, x, z, w, h, d, det=2, cull=12):
        """w (x) by d (z) metres, h high, centred on x, z"""
        a, b, c = w, h * 2, d
        verts = [(-a, 0, -c), (a, 0, -c), (a, 0, c), (-a, 0, c), (-a, b, -c), (a, b, -c), (a, b, c), (-a, b, c)]
        edges = [(0,1),(1,2),(2,3),(3,0),(4,5),(5,6),(6,7),(7,4),(0,4),(1,5),(2,6),(3,7)]
        self.mesh((x, 0, z), verts, edges, det, cull, far=[(4,5),(5,6),(6,7),(7,4),(0,4),(2,6)])

    def runway(self, name, x0, z0, axis, length, hw, aim=None, marks=True):
        aim = aim if aim else max(60, length // 6)
        self.rwys.append((x0, z0, axis, length, hw, aim, name))
        L2, W2 = length * 2, hw * 2
        if axis == 0:
            verts = [(-W2, 0, 0), (W2, 0, 0), (W2, 0, L2), (-W2, 0, L2)]
            cen = (x0, z0 + length // 2)
        else:
            verts = [(0, 0, -W2), (L2, 0, -W2), (L2, 0, W2), (0, 0, W2)]
            cen = (x0 + length // 2, z0)
        self.mesh((x0, 0, z0), verts, [(0, 1), (1, 2), (2, 3), (3, 0)], det=1, cull=40, centre=cen)
        if not marks:
            return
        nd = (length - 200) // 100
        if axis == 0:
            self.series((x0, 0, z0 + 100), (0, 0, 200), (0, 0, 80), nd)                       # centreline
            self.series((x0 - hw, 0, z0 + 30), (0, 0, (length - 60) * 2), (W2 * 2, 0, 0), 2)  # thresholds
            if length >= 1000:
                self.series((x0 - hw // 2, 0, z0 + aim - 30), (hw * 2, 0, 0), (0, 0, 120), 2)  # aim markers
        else:
            self.series((x0 + 100, 0, z0), (200, 0, 0), (80, 0, 0), nd)
            self.series((x0 + 30, 0, z0 - hw), ((length - 60) * 2, 0, 0), (0, 0, W2 * 2), 2)
            if length >= 1000:
                self.series((x0 + aim - 30, 0, z0 - hw // 2), (0, 0, hw * 2), (120, 0, 0), 2)

    def asm(self, base):
        out = ['        org %d' % base,
               "        db 'S','C',3",
               '        db "%-16s"' % self.name[:16],
               '        dw objtab,rwytab',
               '        db %d' % len(self.rwys),
               'objtab:']
        for typ, det, cull, rad, cx, cz, lab, _ in self.objs:
            out.append('        db %d,%d,%d,%d' % (typ, det, cull, min(255, int(rad / 16) + 1)))
            out.append('        dw %d,%d,%s' % (int(cx), int(cz), lab))
        out.append('        db 0')
        out.append('rwytab:')
        for x0, z0, axis, length, hw, aim, name in self.rwys:
            assert len(name) <= 9
            out.append('        dw %d,%d' % (x0, z0))
            out.append('        db %d' % axis)
            out.append('        dw %d' % length)
            out.append('        db %d' % hw)
            out.append('        dw %d' % aim)
            out.append('        db "%-10s"' % name)
        for o in self.objs:
            out += o[7]
        return '\n'.join(out) + '\n'


def home_field(loc):
    loc.runway('CORAL BAY', 0, 0, 0, 1200, 15, aim=180)
    loc.box(75, 310, 30, 8, 20, det=2, cull=12)                    # hangar 30 x 20 x 8 m


def coral():
    loc = Locale('CORAL COAST')
    home_field(loc)
    # resort on the beach road and the jetty
    loc.box(1150, -500, 60, 12, 20, det=2, cull=16)
    loc.box(1150, -440, 20, 6, 16, det=3, cull=10)
    loc.mesh((1560, 0, 800), [(0, 0, -6), (420, 0, -6), (420, 0, 6), (0, 0, 6)], [(0, 1), (1, 2), (2, 3)], det=2, cull=12,
             centre=(1660, 800))
    # mainland coast: sea to the east, headland with the lighthouse
    coast = [(1500, -7000), (1650, -4500), (1350, -2500), (1550, -800), (1600, 600), (1500, 1800), (1950, 2600),
             (2650, 2950), (2300, 3500), (1850, 4600), (2050, 6400), (1750, 8500), (1900, 10500)]
    for i in range(0, len(coast) - 1, 3):
        loc.outline(coast[i:i + 4], closed=False, det=1, cull=40)
    # lighthouse on the headland: tapering tower, lantern roof
    t = [(-8, 0, -8), (8, 0, -8), (8, 0, 8), (-8, 0, 8), (-5, 60, -5), (5, 60, -5), (5, 60, 5), (-5, 60, 5), (0, 74, 0)]
    e = [(0, 1), (1, 2), (2, 3), (3, 0), (0, 4), (1, 5), (2, 6), (3, 7), (4, 5), (5, 6), (6, 7), (7, 4), (4, 8), (5, 8), (6, 8), (7, 8)]
    loc.mesh((2600, 0, 2950), t, e, det=1, cull=32, size=110, far=[(0, 8), (0, 1)])
    # cargo ship at anchor, bow to the north
    s = [(-20, 0, -120), (20, 0, -120), (20, 0, 60), (0, 0, 120), (-20, 0, 60),
         (-20, 16, -120), (20, 16, -120), (20, 16, 60), (0, 16, 120), (-20, 16, 60),
         (-12, 36, -110), (12, 36, -110), (12, 36, -80), (-12, 36, -80)]
    e = [(5, 6), (6, 7), (7, 8), (8, 9), (9, 5), (0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (0, 5), (1, 6), (3, 8),
         (10, 11), (11, 12), (12, 13), (13, 10)]
    loc.mesh((3600, 0, 1200), s, e, det=2, cull=20, far=[(5, 6), (6, 7), (7, 8), (8, 9), (9, 5), (10, 13)])
    # islands with their airstrips
    def isle(cx, cz, r, n, wobble):
        pts = []
        for k in range(n):
            a = 2 * math.pi * k / n
            rr = r * (1 + wobble[k % len(wobble)])
            pts.append((int(cx + rr * math.sin(a)), int(cz + rr * math.cos(a))))
        loc.outline(pts, closed=True, det=1, cull=40)
    isle(6000, 2200, 450, 6, [0.1, -0.15, 0.2, 0, -0.1, 0.15])
    loc.runway('TURTLE IS', 5750, 2200, 1, 500, 10)
    loc.box(6050, 2290, 5, 3, 4, det=2, cull=8)
    isle(4800, 7000, 380, 6, [0, 0.2, -0.1, 0.1, -0.2, 0.15])
    loc.runway('HOPE IS', 4800, 6775, 0, 450, 10)
    loc.box(4870, 7050, 4, 3, 6, det=2, cull=8)
    isle(8000, -3000, 420, 6, [0.2, 0, -0.15, 0.1, 0.25, -0.1])
    loc.runway('LIZARD IS', 7775, -3000, 1, 450, 10)
    loc.box(8000, -2900, 6, 3, 4, det=2, cull=8)
    # the reef: broken line of breakers offshore
    for z in (-2500, 0, 2500, 5000):
        loc.series((3900, 0, z), (60, 0, 1000), (0, 0, 300), 3, det=3, cull=16)
    return loc


def home():
    loc = Locale('HOME FIELD')
    home_field(loc)
    return loc


LOCALES = {'CORAL': coral, 'HOME': home}
