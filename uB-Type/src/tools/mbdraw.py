"""Drawing toolkit for uB-TYPE artwork.

Images are drawn at Microbee resolution (each VZ pixel = 4 x 4 Premium
pixels; a Premium pixel looks about 1.8x taller than wide). A canvas holds
a colour (0 = empty) and a brightness level per pixel: 3 = solid, 2 = 50%
dither, 1 = 25% dither. The sprite packer turns lit pixels into PCG bits
and the dominant colour of each 8x16 cell into its ink."""
import math
import numpy as np

ASPECT = 1.8          # a pixel's height / width on the monitor


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.col = np.zeros((h, w), np.uint8)
        self.lev = np.zeros((h, w), np.uint8)

    def put(self, x, y, c, lev=3):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.col[y, x] = c
            self.lev[y, x] = lev

    def clear(self, x, y):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.col[y, x] = 0
            self.lev[y, x] = 0

    # ---- shapes -------------------------------------------------------
    def ellipse(self, cx, cy, rx, ry, c, shade=True, lev=3, hollow=None):
        for y in range(self.h):
            for x in range(self.w):
                dx = (x + 0.5 - cx) / rx
                dy = (y + 0.5 - cy) / ry
                d = dx * dx + dy * dy
                if d <= 1.0:
                    if hollow is not None and d < hollow:
                        continue
                    L = lev
                    if shade:
                        lit = -(dx * 0.7 + dy * 0.7)          # light from the top left
                        L = 3 if lit > -0.15 else (2 if lit > -0.75 else 1)
                        if d > 0.82 and lit < -0.4:
                            L = 1
                    self.put(x, y, c, min(L, lev) if not shade else L)

    def rect(self, x0, y0, x1, y1, c, lev=3):
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                self.put(x, y, c, lev)

    def poly(self, pts, c, shade=True, lev=3):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        cx, cy = sum(xs) / len(xs), sum(ys) / len(ys)
        x0, x1 = int(min(xs)), int(math.ceil(max(xs)))
        y0, y1 = int(min(ys)), int(math.ceil(max(ys)))
        n = len(pts)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                px, py = x + 0.5, y + 0.5
                inside = False
                j = n - 1
                for i in range(n):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi:
                        inside = not inside
                    j = i
                if inside:
                    L = lev
                    if shade:
                        dx = (px - cx) / max(1, (x1 - x0) / 2)
                        dy = (py - cy) / max(1, (y1 - y0) / 2)
                        lit = -(dx * 0.6 + dy * 0.8)
                        L = 3 if lit > -0.2 else (2 if lit > -0.7 else 1)
                    self.put(x, y, c, L)

    def line(self, x0, y0, x1, y1, c, lev=3):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / max(1, n)
            self.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c, lev)

    def blit(self, other, ox, oy):
        for y in range(other.h):
            for x in range(other.w):
                if other.col[y, x]:
                    self.put(ox + x, oy + y, other.col[y, x], other.lev[y, x])

    def from_ascii(self, rows, cmap, ox=0, oy=0):
        """rows of chars: '.' empty; cmap: char -> (colour, level)"""
        for y, r in enumerate(rows):
            for x, ch in enumerate(r):
                if ch in cmap:
                    c, l = cmap[ch]
                    self.put(ox + x, oy + y, c, l)

    def bits(self):
        """lit pixels after dithering (absolute pattern, so shifted copies match)"""
        y, x = np.mgrid[0:self.h, 0:self.w]
        on = (self.lev >= 3) | ((self.lev == 2) & ((x + y) % 2 == 0)) | ((self.lev == 1) & (x % 2 == 0) & (y % 2 == 0))
        return on & (self.col > 0)

    def solid(self):
        return self.col > 0

    def flip_v(self):
        c = Canvas(self.w, self.h)
        c.col = self.col[::-1].copy()
        c.lev = self.lev[::-1].copy()
        return c

    def shear(self, k):
        """vertical shear (banking): rows shift by k * (x - centre)"""
        c = Canvas(self.w, self.h)
        cx = self.w / 2
        for y in range(self.h):
            for x in range(self.w):
                if self.col[y, x]:
                    c.put(x, y + k * (x - cx), self.col[y, x], self.lev[y, x])
        return c
