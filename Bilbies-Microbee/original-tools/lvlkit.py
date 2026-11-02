"""BILBIES! level kit: describe a level, compile it to the shape stream that
level.asm builds, and a Python copy of the builder (same integer rules) for
previews and checks. Levels are up to 512 x 80 pixels."""
import math
from art import TEXNAMES, TEX, COL
import stamps as _st

LW, LH = 512, 80
SKILLS = ['climb', 'float', 'bomb', 'block', 'build', 'bash', 'mine', 'dig', 'nuke']
SOLID, DECOR, OVER, ERASE = 0, 1, 2, 3
SQT = [int(round(255 * math.sqrt(max(0.0, 1 - (i / 64.0) ** 2)))) for i in range(65)]

def w16(v):
    return [v & 255, (v >> 8) & 255]

def tex(name):
    return TEXNAMES.index(name)

class Level:
    def __init__(self, name, n=10, rate=50, save=5, minutes=5, width=512, height=80, bg='sky', **sk):
        self.name = name.upper()
        self.n, self.rate, self.save, self.minutes = n, rate, save, minutes
        self.width, self.height = width, height
        self.skills = [sk.get(s, 0) for s in SKILLS[:8]]
        self.hatch = (8, 2)
        self.exit = (230, 30)
        self.brick = 'YYRY'
        self.water = None
        self.steel = []
        self.ops = []
        self.script = []
        self.rating = 0
        self.bg = bg
        self.edge = None

    # --- shapes (mode: SOLID, DECOR, OVER, ERASE) ------------------------------
    def rect(self, t, x, y, w, h, mode=SOLID):
        assert w >= 1 and h >= 1
        self.ops.append([1, mode, tex(t)] + w16(x) + [y] + w16(w) + [h])
        return self

    def spans(self, t, y, sp, mode=SOLID):
        b = [3, mode, tex(t), y, len(sp)]
        for xl, xr in sp:
            if xl > xr:
                b += w16(1) + w16(0)
            else:
                b += w16(max(0, xl)) + w16(min(511, xr))
        self.ops.append(b)
        return self

    def cspans(self, t, x, top, hws, mode=SOLID):
        """rows from `top` down, each x - hw .. x + hw"""
        assert 0 < len(hws) < 80 and all(0 <= h < 256 for h in hws)
        self.ops.append([12, mode, tex(t)] + w16(x) + [top, len(hws)] + list(hws))
        return self

    def ellipse(self, t, cx, cy, rx, ry, mode=SOLID):
        assert 0 <= rx < 256 and 0 <= ry < 40
        self.ops.append([9, mode, tex(t)] + w16(cx) + [cy & 255, rx, ry])
        return self

    def ground(self, t, x0, x1, y, rough=0, seed=1, mode=SOLID):
        self.ops.append([10, mode, tex(t)] + w16(x0) + w16(x1) + [y, rough, seed & 255])
        return self

    def stamp(self, name, x, base, flip=False):
        """a scenery picture standing on row `base` (its bottom row at base - 1)"""
        h = len(_st.S[name])
        y = base - h
        assert 0 <= y and y + h <= 80, '%s: stamp %s off the map' % (self.name, name)
        self.ops.append([11, _st.NAMES.index(name) | (128 if flip else 0)] + w16(x) + [y])
        return self

    def strata(self, a, b):
        self.ops.append([8, tex(a), tex(b)])
        return self

    def edges(self, top, bot):
        def fill(c):
            return 0xAA if c is None else COL[c] * 0x55
        self.edge = [4, fill(top), fill(bot)]
        return self

    def image(self, xb, y, wb, data):
        self.ops.append(('img', xb, y, wb, len(data) // wb, data))
        return self

    def steel_rect(self, x0, y0, x1, y1, t='steel'):
        self.steel.append((x0, y0, x1, y1))
        self.rect(t, x0, y0, x1 - x0 + 1, y1 - y0 + 1)
        return self

    def solve(self, *ev):
        self.script = sorted(ev, key=lambda e: e[0])
        return self

    # --- checks + output -------------------------------------------------------
    def fix(self):
        hx, hy = self.hatch
        ex, ey = self.exit
        hx -= hx % 4
        ex -= (ex - 2) % 4
        self.hatch, self.exit = (hx, hy), (ex, ey)

    def check(self, g=None, m=None):
        self.fix()
        if m is None:
            g, m = raster(self)
        hx, hy = self.hatch
        ex, ey = self.exit
        # snap: the exit drops onto the ground below it, the hatch to a safe height
        while ey + 1 < self.height and not m[ey + 1][ex]:
            ey += 1
        while ey >= 0 and m[ey][ex]:
            ey -= 1
        x, y = hx + 5, hy + 5
        while y + 1 < self.height and not m[y + 1][x]:
            y += 1
        if y - (hy + 5) >= 22 and self.skills[1] == 0 and self.name != 'TITLE':
            hy = y - 5 - 18
        self.hatch, self.exit = (hx, hy), (ex, ey)
        assert self.width % 4 == 0 and 128 <= self.width <= 512
        assert 44 <= self.height <= 80
        x, y = hx + 5, hy + 5
        d = 0
        while y + 1 < self.height and not m[y + 1][x]:
            y += 1; d += 1
        assert d < 24 or self.skills[1] > 0 or self.name == 'TITLE', \
            '%s: the drop from the hatch is fatal (%d rows)' % (self.name, d)
        assert ey + 1 < self.height and m[ey + 1][ex], '%s: no ground under the exit' % self.name

    def compile(self, lab):
        self.check()
        b = list(self.name.encode()) + [0]
        b += [self.n, self.rate, self.save, self.minutes] + self.skills
        b += [self.width // 4, self.height]
        hx, hy = self.hatch
        ex, ey = self.exit
        b += w16(hx) + [hy] + w16(ex) + [ey]
        b += [pattern_byte(self.brick)]
        if self.water:
            wy, wx0, wx1 = self.water
            b += [wy] + w16(wx0) + w16(wx1)
        else:
            b += [0] + w16(0) + w16(0)
        b += [tex(self.bg)]
        b += [len(self.steel)]
        for x0, y0, x1, y1 in self.steel:
            b += w16(x0) + [y0] + w16(x1) + [y1]
        imgs = []
        for op in self.ops:
            if op[0] == 'img':
                _, xb, y, wb, h, data = op
                b += [6, xb, y, wb, h, 0, 0]
                imgs.append((len(b) - 2, data))
            else:
                b += op
        if self.edge:
            b += self.edge
        b += [0]
        for at, data in imgs:
            off = len(b)
            b[at], b[at + 1] = off & 255, off >> 8
            b += list(data)
        return b

    def script_asm(self, lab):
        lines = ['%s:' % lab]
        for ev in self.script:
            t, c, s = ev[:3]
            if c == 'all': c = 255
            x0, x1 = (ev[3], ev[4]) if len(ev) > 3 else (0, 1023)
            lines.append('        dw %d : db %d,%d : dw %d,%d' % (t, c, SKILLS.index(s), x0, x1))
        lines.append('        db $FF')
        return lines

def pattern_byte(s):
    v = 0
    for c in s:
        v = (v << 2) | COL[c]
    return v

# ---------------------------------------------------------------------------
# the builder in Python (the same integer rules as level.asm)
# ---------------------------------------------------------------------------
def texpix(t, x, y):
    return COL[TEX[TEXNAMES[t]][y & 7][x & 7]]

def raster(lv):
    """-> (picture 80 x 512 colours, mask 80 x 512 bools)"""
    bgt = tex(lv.bg)
    g = [[texpix(bgt, x, y) for x in range(512)] for y in range(80)]
    m = [[False] * 512 for _ in range(80)]
    LHv = lv.height

    def span(mode, t, y, xl, xr):
        if not (0 <= y < 80): return
        xr = min(xr, 511)
        for x in range(max(0, xl), xr + 1):
            if mode == 0:
                g[y][x] = texpix(t, x, y); m[y][x] = True
            elif mode == 1:
                if not m[y][x]: g[y][x] = texpix(t, x, y)
            elif mode == 2:
                if m[y][x]: g[y][x] = texpix(t, x, y)
            else:
                g[y][x] = texpix(bgt, x, y); m[y][x] = False

    lf = [0]
    def lfsr():
        v = lf[0]
        c = v & 1
        v >>= 1
        if c: v ^= 0xB400
        lf[0] = v
        return v

    def band(y, x, k):
        if y + 1 < k: return False
        return all(m[y - i][x] for i in range(k))

    for op in lv.ops:
        k = op[0]
        if k == 1:
            _, mode, t, xl, xh, y, wl, wh, h = op
            x = xl | xh << 8; w = wl | wh << 8
            for r in range(h): span(mode, t, y + r, x, x + w - 1)
        elif k == 3:
            mode, t, y, n = op[1], op[2], op[3], op[4]
            for i in range(n):
                xl = op[5 + 4 * i] | op[6 + 4 * i] << 8
                xr = op[7 + 4 * i] | op[8 + 4 * i] << 8
                span(mode, t, y + i, xl, xr)
        elif k == 9:
            _, mode, t, cl, ch, cy, rx, ry = op
            cx = cl | ch << 8
            for dy in range(-ry, ry + 1):
                tt = min(64, (abs(dy) * 128) // (2 * ry + 1))
                hw = (rx * SQT[tt]) >> 8
                row = (cy + dy) & 255
                if row >= 80: continue
                span(mode, t, row, max(0, cx - hw), cx + hw)
        elif k == 10:
            _, mode, t, al, ah, bl, bh, y, rough, seed = op
            x0 = al | ah << 8; x1 = bl | bh << 8
            lf[0] = seed | 0xA5 << 8
            hs = []
            h = y
            for x in range(x0, x1 + 1):
                hs.append(h)
                v = lfsr()
                l = v & 255
                if rough and (l & 3) == 0:
                    cand = h + 1 if (l & 4) else h - 1
                    if cand <= y + rough and cand >= y - rough:
                        h = cand
            r = max(0, y - rough)
            while r < LHv:
                if r > y + rough:
                    span(mode, t, r, x0, x1)
                else:
                    run = None
                    for i, hh in enumerate(hs):
                        if hh <= r:
                            if run is None: run = i
                        elif run is not None:
                            span(mode, t, r, x0 + run, x0 + i - 1); run = None
                    if run is not None:
                        span(mode, t, r, x0 + run, x0 + len(hs) - 1)
                r += 1
        elif k == 12:
            mode, t, xl, xh, top, n = op[1:7]
            x = xl | xh << 8
            for i, hw in enumerate(op[7:7 + n]):
                span(mode, t, top + i, max(0, x - hw), x + hw)
        elif k == 11:
            _, sid, xl, xh, y = op
            rows = _st.S[_st.NAMES[sid & 127]]
            w = len(rows[0])
            x0 = xl | xh << 8
            for r, row in enumerate(rows):
                for i, ch in enumerate(row):
                    if ch == '.': continue
                    x = x0 + (w - 1 - i if sid & 128 else i)
                    yy = y + r
                    if 0 <= x < lv.width and yy < LHv and not m[yy][x]:
                        g[yy][x] = COL[ch]
        elif k == 8:
            _, ta, tb = op
            for y in range(LHv):
                for x in range(512):
                    b1 = band(y, x, 6) and not band(y, x, 8)
                    b2 = band(y, x, 11) and not band(y, x, 13)
                    if b1: g[y][x] = texpix(ta, x, y)
                    if b2: g[y][x] = texpix(tb, x, y)
        elif k == 'img':
            _, xb, y, wb, h, data = op
            for r in range(h):
                for i in range(wb):
                    v = data[r * wb + i]
                    for p in range(4):
                        c = (v >> (6 - 2 * p)) & 3
                        g[y + r][(xb + i) * 4 + p] = c
                        if c != 2: m[y + r][(xb + i) * 4 + p] = True
    if lv.edge:
        _, top, bot = lv.edge
        if bot != 0xAA:
            for y in range(LHv - 1):
                for x in range(512):
                    if m[y][x] and not m[y + 1][x]: g[y][x] = bot & 3
        if top != 0xAA:
            for y in range(LHv):
                for x in range(512):
                    if m[y][x] and (y == 0 or not m[y - 1][x]): g[y][x] = top & 3
    return g, m

PAL = [(0x10, 0xC8, 0x10), (0xF0, 0xF0, 0x40), (0x20, 0x20, 0xD0), (0xD0, 0x20, 0x20)]

def preview(lv, fn, scale=1):
    from PIL import Image
    g, m = raster(lv)
    im = Image.new('RGB', (512 * 2, 80 * 3))
    px = im.load()
    for y in range(80):
        for x in range(512):
            c = PAL[g[y][x]]
            if x >= lv.width or y >= lv.height: c = tuple(v // 4 for v in c)
            for dy in range(3):
                for dx in range(2):
                    px[x * 2 + dx, y * 3 + dy] = c
    hx, hy = lv.hatch
    ex, ey = lv.exit
    for dx in range(24): px[hx * 2 + dx, hy * 3] = (255, 255, 255)
    for dy in range(9): px[ex * 2, max(0, ey * 3 - dy)] = (255, 255, 255)
    if scale != 1:
        im = im.resize((int(im.width * scale), int(im.height * scale)))
    im.save(fn)
