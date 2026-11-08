"""Tiny vector puppet rasteriser for VZ mode-1 sprites.
Shapes are given in 'square' units (1 unit = 1 horizontal pixel); the y axis is squashed
by ASPECT so shapes look right on a 4:3 screen where mode-1 pixels are 1.5x taller than wide.
Supersampled (SS x SS), resolved by majority, then optionally outlined."""
import math
ASPECT = 1.5          # pixel height / pixel width
SS = 4

class Pose:
    def __init__(self, x=0, y=0, rot=0.0, sx=1.0, sy=1.0):
        self.x, self.y, self.rot, self.sx, self.sy = x, y, rot, sx, sy
    def apply(self, px, py):
        c, s = math.cos(self.rot), math.sin(self.rot)
        px, py = px * self.sx, py * self.sy
        return self.x + px * c - py * s, self.y + px * s + py * c

class Canvas:
    def __init__(self, w, h, ox=None, oy=None):
        """w,h in output pixels; (ox,oy) = origin in output pixels (default centre bottom)"""
        self.w, self.h = w, h
        self.ox = w / 2 if ox is None else ox
        self.oy = h - 1 if oy is None else oy
        self.ss = [[-1] * (w * SS) for _ in range(h * SS)]
        self.stack = [Pose()]
    # transforms -------------------------------------------------------
    def push(self, x=0, y=0, rot=0.0, sx=1.0, sy=1.0):
        self.stack.append(Pose(x, y, math.radians(rot), sx, sy) if not isinstance(rot, Pose) else rot)
    def pop(self): self.stack.pop()
    def xf(self, x, y):
        for p in reversed(self.stack): x, y = p.apply(x, y)
        # to supersampled output coordinates
        return (self.ox + x) * SS, (self.oy + y / ASPECT) * SS
    # primitives (square units) ----------------------------------------
    def poly(self, pts, col):
        P = [self.xf(x, y) for x, y in pts]
        ys = [p[1] for p in P]
        y0 = max(0, int(min(ys))); y1 = min(self.h * SS - 1, int(max(ys)) + 1)
        n = len(P)
        for sy in range(y0, y1 + 1):
            yc = sy + 0.5; xs = []
            for i in range(n):
                (xa, ya), (xb, yb) = P[i], P[(i + 1) % n]
                if (ya <= yc < yb) or (yb <= yc < ya):
                    xs.append(xa + (yc - ya) * (xb - xa) / (yb - ya))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                a = max(0, int(math.ceil(xs[i] - 0.5))); b = min(self.w * SS - 1, int(math.floor(xs[i + 1] - 0.5)))
                row = self.ss[sy]
                for sx in range(a, b + 1): row[sx] = col
    def ellipse(self, cx, cy, rx, ry, col, rot=0, n=28):
        r = math.radians(rot)
        pts = []
        for i in range(n):
            t = 2 * math.pi * i / n
            x, y = rx * math.cos(t), ry * math.sin(t)
            pts.append((cx + x * math.cos(r) - y * math.sin(r), cy + x * math.sin(r) + y * math.cos(r)))
        self.poly(pts, col)
    def circle(self, cx, cy, r, col): self.ellipse(cx, cy, r, r, col)
    def rect(self, x0, y0, x1, y1, col): self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col)
    def capsule(self, x0, y0, x1, y1, r0, col, r1=None):
        r1 = r0 if r1 is None else r1
        dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy) or 1e-6
        nx, ny = -dy / L, dx / L
        self.poly([(x0 + nx * r0, y0 + ny * r0), (x1 + nx * r1, y1 + ny * r1),
                   (x1 - nx * r1, y1 - ny * r1), (x0 - nx * r0, y0 - ny * r0)], col)
        self.circle(x0, y0, r0, col); self.circle(x1, y1, r1, col)
    # resolve ------------------------------------------------------------
    def resolve(self, prio=(3, 2, 1, 0), thresh=None, outline=3):
        """majority resolve; prio breaks ties; thresh = min opaque samples (default half)"""
        th = SS * SS // 2 if thresh is None else thresh
        out = []
        for y in range(self.h):
            row = []
            for x in range(self.w):
                cnt = {}
                for yy in range(y * SS, y * SS + SS):
                    r = self.ss[yy]
                    for xx in range(x * SS, x * SS + SS):
                        c = r[xx]
                        if c >= 0: cnt[c] = cnt.get(c, 0) + 1
                tot = sum(cnt.values())
                if tot < th: row.append(-1); continue
                best = max(cnt.items(), key=lambda kv: (kv[1], -prio.index(kv[0]) if kv[0] in prio else -9))
                row.append(best[0])
            out.append(row)
        if outline is not None: out = add_outline(out, outline)
        return out

def add_outline(g, col=3, diag=False):
    h, w = len(g), len(g[0])
    o = [r[:] for r in g]
    for y in range(h):
        for x in range(w):
            if g[y][x] >= 0: continue
            nb = [(0, 1), (0, -1), (1, 0), (-1, 0)] + ([(1, 1), (1, -1), (-1, 1), (-1, -1)] if diag else [])
            for dx, dy in nb:
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and g[yy][xx] >= 0 and g[yy][xx] != col:
                    o[y][x] = col; break
    return o

def crop(g):
    """trim transparent margins; returns (grid, dx, dy) offsets of the trimmed origin"""
    h, w = len(g), len(g[0])
    ys = [y for y in range(h) if any(c >= 0 for c in g[y])]
    xs = [x for x in range(w) if any(g[y][x] >= 0 for y in range(h))]
    if not ys: return [[-1]], 0, 0
    return [r[xs[0]:xs[-1] + 1] for r in g[ys[0]:ys[-1] + 1]], xs[0], ys[0]

def preview(grids, fn, css=0, scale=6, bg=None, cols=8):
    from PIL import Image
    from vzpal import CSS0, CSS1
    pal = CSS1 if css else CSS0
    bgc = (40, 40, 40) if bg is None else bg
    cw = max(len(g[0]) for g in grids) + 2; ch = max(len(g) for g in grids) + 2
    rows = (len(grids) + cols - 1) // cols
    im = Image.new('RGB', (cols * cw * scale, rows * ch * int(scale * ASPECT)), (20, 20, 20))
    sy = int(scale * ASPECT)
    for i, g in enumerate(grids):
        ox = (i % cols) * cw * scale; oy = (i // cols) * ch * sy
        for y, r in enumerate(g):
            for x, c in enumerate(r):
                col = bgc if c < 0 else pal[c]
                for a in range(scale):
                    for b in range(sy):
                        im.putpixel((ox + x * scale + a, oy + y * sy + b), col)
    im.save(fn)
