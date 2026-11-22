"""RUNEDEEP - the first-person view, built offline.

The view is 24 x 16 cells (192 x 160 pixels) of the Microbee's 8 x 10 PCG
cells. Every vertical edge of the 3D geometry falls on an 8-pixel cell
boundary (the half-widths of the square boundaries are 96, 48, 32, 24 and
16 pixels), so a column of cells only ever shows one wall surface, and the
ceiling and floor are dark: a cell never needs more than one ink on black.

Every cell a wall, door, floor, creature or item can put on the screen is
rendered here, once, and stored as a glyph in a per-level tile dictionary.
The Z80 composes a view from tile lists and never draws a pixel.

Slots: a slot is one face of one map square relative to the viewer,
(dx, dz) with dz = 0 the viewer's own square. Depth keys order them near
to far: front face of square dz = 4*dz, side face of square dz = 4*dz+2,
a sprite standing in square dz = 4*dz+1.
"""
import numpy as np

VW, VH = 24, 16          # view in cells
PW, PH = VW * 8, VH * 10  # 192 x 160 pixels
CX, CY = 96, 80          # centre, horizon
FX = 192.0               # x: pixels per unit at z = 1
FY = 230.4               # y: walls are 1.2 x as tall (in pixels) as wide
ZB = [1.0, 2.0, 3.0, 4.0, 6.0]   # boundaries: own square near edge .. far wall (snapped)
MAXDZ = 4

BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0
BAYER8 = None


def bayer8():
    b = np.array([[0, 2], [3, 1]])
    for _ in range(2):
        b = np.block([[4 * b, 4 * b + 2], [4 * b + 3, 4 * b + 1]])
    return (b + 0.5) / 64.0


BAYER8 = bayer8()


def sx_of(X, z):
    return CX + FX * X / z


def sy_of(Y, z):
    return CY + FY * Y / z


class Slot:
    def __init__(self, kind, dx, dz):
        self.kind, self.dx, self.dz = kind, dx, dz      # kind 'F' front, 'S' side
        if kind == 'F':
            z = ZB[dz]
            self.x0 = int(round(sx_of(dx - 0.5, z)))
            self.x1 = int(round(sx_of(dx + 0.5, z)))
            self.key = 4 * dz
        else:
            X = dx + 0.5 if dx < 0 else dx - 0.5
            a = sx_of(X, ZB[dz])
            b = sx_of(X, ZB[dz + 1])
            self.X = X
            self.x0, self.x1 = int(round(min(a, b))), int(round(max(a, b)))
            self.key = 4 * dz + 2
        assert self.x0 % 8 == 0 and self.x1 % 8 == 0, (kind, dx, dz, self.x0, self.x1)
        self.c0 = max(0, self.x0 // 8)
        self.c1 = min(VW, self.x1 // 8)

    def visible(self):
        return self.c1 > self.c0

    def name(self):
        return '%s%+d%d' % (self.kind, self.dx, self.dz)

    def coverage(self):
        """per pixel of the view: inside (bool), u, v, z"""
        ys, xs = np.mgrid[0:PH, 0:PW]
        px = xs + 0.5
        py = ys + 0.5
        inside = (xs >= self.c0 * 8) & (xs < self.c1 * 8)
        if self.kind == 'F':
            z = np.full(px.shape, ZB[self.dz])
            X = (px - CX) * z / FX
            Y = (py - CY) * z / FY
            u = X - (self.dx - 0.5)
            v = Y + 0.5
        else:
            with np.errstate(divide='ignore', invalid='ignore'):
                z = FX * self.X / (px - CX)
            z = np.where(np.isfinite(z) & (z > 0), z, 99)
            u = (z - ZB[self.dz]) / (ZB[self.dz + 1] - ZB[self.dz])
            if self.dx > 0:
                pass
            Y = (py - CY) * z / FY
            v = Y + 0.5
        inside &= (v >= 0) & (v < 1) & (u >= -1e-6) & (u <= 1 + 1e-6)
        return inside, np.clip(u, 0, 0.99999), np.clip(v, 0, 0.99999), z


def all_slots():
    out = []
    for dz in range(0, MAXDZ + 1):
        for dx in range(-3, 4):
            if dz >= 1:
                s = Slot('F', dx, dz)
                if s.visible():
                    out.append(s)
            if dx != 0 and dz < MAXDZ:
                s = Slot('S', dx, dz)
                if s.visible():
                    out.append(s)
    out.sort(key=lambda s: (s.key, abs(s.dx)))
    return out


SLOTS = all_slots()

# where a sprite standing in square (dx, dz) is drawn: depth, lateral step in cells, floor line
SPR_Z = {1: 2.05, 2: 3.1, 3: 4.3}
SPR_LAT = {1: 12, 2: 8, 3: 6}     # cells per square sideways


def spr_floor(dz):
    return sy_of(0.5, SPR_Z[dz])


def spr_scale(dz):
    """pixels per world unit, x and y"""
    z = SPR_Z[dz]
    return FX / z, FY / z


if __name__ == '__main__':
    for s in SLOTS:
        print(s.name(), s.key, s.c0, s.c1)
    print(len(SLOTS), 'slots')
