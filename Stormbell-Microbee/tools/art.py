"""STORMBELL pictures: the 8 x 8 font, the HUD glyphs, the five stages,
the title and the ending. Each picture is drawn here as 320 x 200 ink
pixels with an ink and a paper colour for every 8 x 8 cell, then cut
into cells and de-duplicated into at most 128 glyphs (one PCG bank).

Ink is always the lighter colour: an amber monitor shows the ink only,
so every picture reads the same there.
"""
import math
import numpy as np

BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)
PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
       (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]

F57 = {
    'A': "01110,10001,10001,11111,10001,10001,10001", 'B': "11110,10001,10001,11110,10001,10001,11110",
    'C': "01110,10001,10000,10000,10000,10001,01110", 'D': "11110,10001,10001,10001,10001,10001,11110",
    'E': "11111,10000,10000,11110,10000,10000,11111", 'F': "11111,10000,10000,11110,10000,10000,10000",
    'G': "01110,10001,10000,10111,10001,10001,01111", 'H': "10001,10001,10001,11111,10001,10001,10001",
    'I': "01110,00100,00100,00100,00100,00100,01110", 'J': "00111,00010,00010,00010,00010,10010,01100",
    'K': "10001,10010,10100,11000,10100,10010,10001", 'L': "10000,10000,10000,10000,10000,10000,11111",
    'M': "10001,11011,10101,10101,10001,10001,10001", 'N': "10001,11001,10101,10011,10001,10001,10001",
    'O': "01110,10001,10001,10001,10001,10001,01110", 'P': "11110,10001,10001,11110,10000,10000,10000",
    'Q': "01110,10001,10001,10001,10101,10010,01101", 'R': "11110,10001,10001,11110,10100,10010,10001",
    'S': "01111,10000,10000,01110,00001,00001,11110", 'T': "11111,00100,00100,00100,00100,00100,00100",
    'U': "10001,10001,10001,10001,10001,10001,01110", 'V': "10001,10001,10001,10001,10001,01010,00100",
    'W': "10001,10001,10001,10101,10101,11011,10001", 'X': "10001,10001,01010,00100,01010,10001,10001",
    'Y': "10001,10001,01010,00100,00100,00100,00100", 'Z': "11111,00001,00010,00100,01000,10000,11111",
    '0': "01110,10001,10011,10101,11001,10001,01110", '1': "00100,01100,00100,00100,00100,00100,01110",
    '2': "01110,10001,00001,00010,00100,01000,11111", '3': "11110,00001,00001,01110,00001,00001,11110",
    '4': "00010,00110,01010,10010,11111,00010,00010", '5': "11111,10000,11110,00001,00001,10001,01110",
    '6': "00110,01000,10000,11110,10001,10001,01110", '7': "11111,00001,00010,00100,01000,01000,01000",
    '8': "01110,10001,10001,01110,10001,10001,01110", '9': "01110,10001,10001,01111,00001,00010,01100",
    '.': "00000,00000,00000,00000,00000,01100,01100", ',': "00000,00000,00000,00000,01100,00100,01000",
    '!': "00100,00100,00100,00100,00100,00000,00100", '?': "01110,10001,00001,00010,00100,00000,00100",
    '-': "00000,00000,00000,11111,00000,00000,00000", ':': "00000,01100,01100,00000,01100,01100,00000",
    '/': "00001,00010,00010,00100,01000,01000,10000", "'": "00100,00100,01000,00000,00000,00000,00000",
    '(': "00010,00100,01000,01000,01000,00100,00010", ')': "01000,00100,00010,00010,00010,00100,01000",
    '+': "00000,00100,00100,11111,00100,00100,00000", '=': "00000,00000,11111,00000,11111,00000,00000",
    '<': "00010,00100,01000,10000,01000,00100,00010", '>': "01000,00100,00010,00001,00010,00100,01000",
}
# HUD glyphs, printed with the characters ` a b c d (codes 96..)
HUD = [
    ["........", ".######.", ".######.", ".######.", ".######.", ".######.", ".######.", "........"],   # ` a full pip
    ["........", ".######.", ".#....#.", ".#....#.", ".#....#.", ".#....#.", ".######.", "........"],   # a an empty pip
    ["........", "...#....", "..##....", ".#######", ".#######", "..##....", "...#....", "........"],   # b left arrow
    ["........", "....#...", "....##..", "#######.", "#######.", "....##..", "....#...", "........"],   # c right arrow
    ["........", "...##...", "...##...", "...##...", ".######.", "..####..", "...##...", "........"],   # d down arrow
    ["########", "########", "########", "########", "########", "########", "########", "########"],   # e solid
    ["........", "........", "........", "########", "........", "........", "........", "........"],   # f rule
    ["#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#", "#.#.#.#.", ".#.#.#.#"],   # g shade
]
N_FONT = 64
N_HUD = len(HUD)
POOL0 = 96                      # glyphs 96..127 of bank 0: the overlap pool


def font_bytes():
    out = bytearray()
    for c in range(N_FONT):
        src = F57.get(chr(32 + c))
        rows = [0] * 8
        if src:
            for j, r in enumerate(src.split(',')):
                v = 0
                for x, ch in enumerate(r):
                    if ch == '1':
                        v |= 0x40 >> x
                rows[j] = v
        out += bytes(rows)
    for g in HUD:
        out += bytes(sum(128 >> x for x, ch in enumerate(r) if ch == '#') for r in g)
    out += bytes(128 * 8 - len(out))
    return bytes(out)


# ---------------------------------------------------------------------
#  Pictures are painted in full colour (any of the 16, a colour a
#  pixel, with ordered dithering for the in-between shades), then each
#  8 x 8 cell is cut down to the two colours it can really show. The
#  lighter of the two is the ink, so an amber monitor still sees it.
# ---------------------------------------------------------------------
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
LUM = np.array([0.299 * r + 0.587 * g + 0.114 * b for r, g, b in PAL])
LIGHT = {YELLOW, WHITE, BCYAN, GREY, BGREEN}     # a solid cell of these is ink
PIC_GLYPHS = 512


class Pic:
    def __init__(self, bg=BLACK, W=320):
        self.W = W
        self.c = np.full((200, W), bg, np.uint8)
        self.y, self.x = np.mgrid[0:200, 0:W]
        self.bay = BAYER[self.y & 3, self.x & 3]
        self.fix = {}                          # (row, col) -> (ink, paper) forced

    # -- masks
    def rect(self, x0, y0, x1, y1):
        return (self.x >= x0) & (self.x < x1) & (self.y >= y0) & (self.y < y1)

    def disc(self, cx, cy, rx, ry=None):
        ry = rx if ry is None else ry
        return ((self.x + 0.5 - cx) / rx) ** 2 + ((self.y + 0.5 - cy) / ry) ** 2 <= 1.0

    def poly(self, pts):
        inside = np.zeros(self.x.shape, bool)
        n = len(pts)
        px, py = self.x + 0.5, self.y + 0.5
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            if y0 == y1:
                continue
            inside ^= ((y0 > py) != (y1 > py)) & (px < (x1 - x0) * (py - y0) / (y1 - y0) + x0)
        return inside

    def line(self, x0, y0, x1, y1, w=1.0):
        dx, dy = x1 - x0, y1 - y0
        L2 = dx * dx + dy * dy or 1e-6
        t = np.clip(((self.x + 0.5 - x0) * dx + (self.y + 0.5 - y0) * dy) / L2, 0, 1)
        return np.hypot(self.x + 0.5 - (x0 + t * dx), self.y + 0.5 - (y0 + t * dy)) <= w / 2

    def profile(self, base, amp, seed, waves=((31, .5), (13, .3), (7, .2))):
        """y of a ridge line at each x"""
        r = np.random.RandomState(seed)
        h = np.full(self.W, float(base))
        for per, a in waves:
            h += amp * a * np.sin(np.arange(self.W) / per + r.rand() * 6.28)
        return h

    def below(self, h):
        return self.y >= h[self.x]

    # -- paint
    def fill(self, m, col):
        self.c[m] = col

    def dither(self, m, c0, c1, level):
        """level 0..16: how much of c1 shows over c0"""
        self.c[m] = np.where(self.bay < level, c1, c0)[m]

    def grad(self, m, c0, c1, y0, y1, l0=0, l1=16):
        """a vertical ramp from c0 (at y0) to c1 (at y1)"""
        t = np.clip((self.y - y0) / max(1, y1 - y0), 0, 1)
        lev = np.round(l0 + (l1 - l0) * t)
        self.c[m] = np.where(self.bay < lev, c1, c0)[m]

    def bands(self, m, c0, c1, y0, y1, n):
        """sunset stripes: c1 broken by c0 lines that thicken downwards"""
        t = np.clip((self.y - y0) / max(1, y1 - y0), 0, 1)
        per = 6
        gap = np.floor(t * (n + 1)).astype(int)
        on = ((self.y - y0) % per) >= gap
        self.c[m & on] = c1
        self.c[m & ~on] = c0

    def text(self, s, x, y, col, sx=1, sy=1, shadow=None, dx=1, dy=1):
        m = np.zeros(self.c.shape, bool)
        for i, ch in enumerate(s):
            src = F57.get(ch)
            if not src:
                continue
            for j, r in enumerate(src.split(',')):
                for k, c in enumerate(r):
                    if c == '1':
                        m |= self.rect(x + (i * 6 + k) * sx, y + j * sy, x + (i * 6 + k + 1) * sx, y + (j + 1) * sy)
        if shadow is not None:
            self.fill(np.roll(np.roll(m, dy, 0), dx, 1) & ~m, shadow)
        self.fill(m, col)
        return m

    # -- to cells
    def cells(self):
        nc = self.W // 8
        ink = np.zeros(self.c.shape, bool)
        ci = np.zeros((25, nc), np.uint8)
        cp = np.zeros((25, nc), np.uint8)
        pal = np.array(PAL, float)
        for cy in range(25):
            for cx in range(nc):
                blk = self.c[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
                cnt = np.bincount(blk.ravel(), minlength=16)
                order = np.argsort(-cnt, kind='stable')
                a, b = int(order[0]), int(order[1])
                if (cy, cx) in self.fix:
                    a, b = self.fix[(cy, cx)]
                elif cnt[b] == 0:
                    if a in LIGHT:
                        ci[cy, cx], cp[cy, cx] = a, BLACK
                        ink[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8] = True
                    else:
                        ci[cy, cx], cp[cy, cx] = WHITE, a
                    continue
                if LUM[b] > LUM[a]:
                    a, b = b, a                    # a = ink (lighter)
                # every pixel to the nearer of the two
                da = ((pal[blk] - pal[a]) ** 2).sum(-1)
                db = ((pal[blk] - pal[b]) ** 2).sum(-1)
                m = (blk == a) | ((blk != b) & (da <= db))
                ink[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8] = m
                ci[cy, cx], cp[cy, cx] = a, b
        return ink, ci, cp

    def rgb(self, quant=True):
        if not quant:
            return np.array(PAL, np.uint8)[self.c]
        ink, ci, cp = self.cells()
        pal = np.array(PAL, np.uint8)
        fg = pal[np.repeat(np.repeat(ci, 8, 0), 8, 1)]
        bg = pal[np.repeat(np.repeat(cp, 8, 0), 8, 1)]
        return np.where(ink[:, :, None], fg, bg)

    def pack(self, name='', limit=PIC_GLYPHS):
        """-> 1000 codes, 1000 banks (1..4), 1000 colours, 4096 bytes of
        glyphs, the number used; glyph 0 is blank"""
        ink, ci, cp = self.cells()
        glyphs = {bytes(8): 0}
        codes, banks, cols = bytearray(), bytearray(), bytearray()
        for cy in range(25):
            for cx in range(40):
                cell = ink[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
                pat = bytes(int(sum(128 >> x for x in range(8) if cell[y, x])) for y in range(8))
                if pat not in glyphs:
                    glyphs[pat] = len(glyphs)
                g = glyphs[pat]
                codes.append(0x80 | (g & 127))
                banks.append(1 + (g >> 7))
                cols.append((int(cp[cy, cx]) << 4) | int(ci[cy, cx]))
        assert len(glyphs) <= limit, '%s: %d glyphs' % (name, len(glyphs))
        g = bytearray(limit * 8)
        for pat, i in glyphs.items():
            g[i * 8:i * 8 + 8] = pat
        return bytes(codes), bytes(banks), bytes(cols), bytes(g), len(glyphs)


# ---------------------------------------------------------------------
#  scenery pieces
# ---------------------------------------------------------------------
TOP, BOT = 8, 192            # rows 1..23 are picture; 0 and 24 the HUD
FEET = 168                   # the fighters stand on this line


def sky(p, c0, c1, y1, stars_seed=None, nstars=0):
    p.grad(p.rect(0, TOP, p.W, y1), c0, c1, TOP + 8, y1, 0, 12)
    if stars_seed is not None:
        r = np.random.RandomState(stars_seed)
        for i in range(nstars):
            x, y = r.randint(2, p.W - 2), r.randint(TOP + 2, TOP + 30)
            p.fill(p.rect(x, y, x + 1, y + 1), WHITE)


def sun(p, cx, cy, r, col=YELLOW, back=MAGENTA, stripes=True):
    m = p.disc(cx, cy, r * 1.25, r)
    if stripes:
        p.bands(m, back, col, cy - 2, cy + r, 4)
    else:
        p.fill(m, col)


def mountains(p, base, amp, seed, c_far, c_near, snow=False, peaks=None, bottom=None):
    h = p.profile(base, amp, seed)
    if peaks:
        for px, py, w in peaks:
            xs = np.arange(p.W)
            h = np.minimum(h, py + np.abs(xs - px) * (base + amp * 0.3 - py) / w)
    m = p.below(h) & (p.y < (bottom or 200))
    # lit left faces, shaded right faces
    slope = np.gradient(h)
    lit = (slope[p.x] < 0)
    p.dither(m, c_far, c_near, 6)
    p.dither(m & lit, c_far, c_near, 11)
    if snow:
        cap = m & (p.y < h[p.x] + 6 + 3 * np.sin(p.x / 3.0)) & (h[p.x] < base - amp * 0.15)
        p.dither(cap, c_near, WHITE, 13)
    return h


def cloud(p, cx, cy, w, col=WHITE, shade=GREY):
    m = np.zeros(p.c.shape, bool)
    for k in range(5):
        m |= p.disc(cx - w * 0.5 + k * w * 0.25, cy - (3 if k in (1, 2) else 0), w * 0.2, 5)
    m &= p.y < cy + 4
    p.fill(m, col)
    p.dither(m & (p.y > cy), col, shade, 8)


def roof(p, cx, y, w, h, col=YELLOW, dark=BROWN, tiers=1):
    """a curved temple roof: wide eaves turned up at the ends"""
    xs = p.x + 0.5 - cx
    t = np.clip(np.abs(xs) / (w / 2), 0, 1)
    top = y - h + 2 * (1 - t) ** 2 * 0
    curve = y - (t ** 3) * 5
    m = (np.abs(xs) <= w / 2) & (p.y >= y - h + (t * h * 0.55)) & (p.y <= curve + 2)
    p.fill(m, col)
    # tile ribs
    p.fill(m & (((p.x - cx) % 4) == 0) & (p.y > y - h + 3), dark)
    p.fill(m & (p.y >= curve) , dark)
    return m


def gate(p, cx, base, w, h, col=RED, roofc=YELLOW):
    """a two-storey temple gate"""
    pw = 8
    for sx in (-1, 1):
        x0 = cx + sx * (w / 2 - pw) - (pw if sx < 0 else 0)
        p.fill(p.rect(cx + sx * (w / 2) - (pw if sx > 0 else 0), base - h, cx + sx * (w / 2) + (0 if sx > 0 else pw), base), col)
        p.fill(p.rect(cx + sx * (w / 2) - (pw if sx > 0 else 0) - 2, base - 4, cx + sx * (w / 2) + (0 if sx > 0 else pw) + 2, base), GREY)
    # the dark doorway with a bell motif lattice
    door = p.rect(cx - w / 2 + pw, base - h + 12, cx + w / 2 - pw, base)
    p.fill(door, BLACK)
    p.dither(door & (p.y < base - h + 26), BLACK, RED, 4)
    # beams
    p.fill(p.rect(cx - w / 2 - 6, base - h, cx + w / 2 + 6, base - h + 6), col)
    p.fill(p.rect(cx - w / 2 - 6, base - h + 6, cx + w / 2 + 6, base - h + 8), BROWN)
    p.fill(p.rect(cx - 16, base - h + 9, cx + 16, base - h + 16), YELLOW)
    p.fill(p.rect(cx - 14, base - h + 11, cx + 14, base - h + 14) & ((p.x % 3) == 0), BROWN)
    roof(p, cx, base - h - 1, w + 40, 14, roofc, BROWN)
    p.fill(p.rect(cx - w / 2 + 4, base - h - 26, cx + w / 2 - 4, base - h - 14), col)
    p.dither(p.rect(cx - w / 2 + 4, base - h - 26, cx + w / 2 - 4, base - h - 14) & ((p.x % 6) < 2), col, BLACK, 16)
    roof(p, cx, base - h - 25, w + 16, 12, roofc, BROWN)


def lantern(p, cx, base, s=1.0, col=GREY, light=WHITE):
    """a stone lantern"""
    k = lambda v: v * s
    p.fill(p.rect(cx - k(9), base - k(4), cx + k(9), base), col)
    p.fill(p.rect(cx - k(3), base - k(16), cx + k(3), base - k(4)), col)
    p.fill(p.rect(cx - k(7), base - k(19), cx + k(7), base - k(16)), col)
    p.fill(p.rect(cx - k(6), base - k(28), cx + k(6), base - k(19)), light)
    p.fill(p.rect(cx - k(3), base - k(26), cx + k(3), base - k(21)), YELLOW)
    p.fill(p.poly([(cx - k(13), base - k(28)), (cx + k(13), base - k(28)), (cx + k(4), base - k(35)), (cx - k(4), base - k(35))]), col)
    p.fill(p.rect(cx - k(2), base - k(38), cx + k(2), base - k(35)), col)


def blossom_tree(p, x0, base, s=1.0, flip=False, leaf=BMAGENTA, dark=MAGENTA, trunk=BROWN):
    d = -1 if flip else 1
    k = lambda v: v * s
    br = [((x0, base), (x0 + d * k(6), base - k(40))), ((x0 + d * k(6), base - k(40)), (x0 + d * k(26), base - k(70))),
          ((x0 + d * k(6), base - k(40)), (x0 - d * k(10), base - k(66))), ((x0 + d * k(16), base - k(55)), (x0 + d * k(46), base - k(60)))]
    blobs = [(x0 + d * k(26), base - k(78), k(26), k(14)), (x0 - d * k(8), base - k(74), k(22), k(13)),
             (x0 + d * k(50), base - k(64), k(22), k(11)), (x0 + d * k(8), base - k(92), k(24), k(12)),
             (x0 + d * k(36), base - k(92), k(18), k(10))]
    m = np.zeros(p.c.shape, bool)
    for cx, cy, rx, ry in blobs:
        m |= p.disc(cx, cy, rx, ry) & (p.bay < 13) | p.disc(cx, cy, rx * 0.85, ry * 0.85)
    p.dither(m, dark, leaf, 10)
    p.dither(m & (p.y < np.array([b[1] for b in blobs]).min() + 6), dark, leaf, 14)
    for (a, b) in br:
        p.fill(p.line(a[0], a[1], b[0], b[1], k(5) if a[1] == base else k(3)), trunk)


def pine(p, x0, base, s=1.0):
    k = lambda v: v * s
    p.fill(p.line(x0, base, x0 - k(10), base - k(50), k(7)), BROWN)
    p.fill(p.line(x0 - k(10), base - k(50), x0 + k(14), base - k(86), k(5)), BROWN)
    p.fill(p.line(x0 - k(6), base - k(36), x0 - k(40), base - k(54), k(4)), BROWN)
    p.dither(p.line(x0, base, x0 - k(10), base - k(50), k(3)), BROWN, YELLOW, 6)
    for cx, cy, rx in ((x0 + k(16), base - k(90), k(30)), (x0 - k(40), base - k(58), k(24)), (x0 - k(4), base - k(70), k(20)),
                       (x0 + k(36), base - k(76), k(18))):
        m = p.disc(cx, cy, rx, rx * 0.32)
        p.dither(m, GREEN, BGREEN, 7)
        p.dither(m & (p.y < cy - rx * 0.05), GREEN, BGREEN, 13)


def bushes(p, y, xs, col=GREEN, light=BGREEN):
    for x, w in xs:
        m = p.disc(x, y, w, w * 0.45) & (p.y < y + 2)
        p.dither(m, col, light, 8)
        p.dither(m & (p.y < y - w * 0.15), col, light, 13)


def tiled_floor(p, y0, c0=GREY, c1=WHITE, vx=160, vy=-40, rows=(0, 7, 16, 28, 44, 64), cols=26):
    """a stone floor in perspective: dark paper, light joints"""
    m = p.rect(0, y0, 320, BOT)
    p.dither(m, DGREY, c0, 12)
    for r in rows:
        if y0 + r < BOT:
            p.fill(p.rect(0, y0 + r, 320, y0 + r + 1), c1)
    for i in range(-cols, cols + 1):
        x_at = vx + i * 22
        # lines from the vanishing point through (x_at, y0)
        x1 = vx + (x_at - vx) * (BOT - vy) / (y0 - vy)
        p.fill(p.line(x_at, y0, x1, BOT, 1.0) & m, c1)


def plank_floor(p, y0, c0=BROWN, c1=YELLOW):
    m = p.rect(0, y0, 320, BOT)
    t = (p.y - y0) / (BOT - y0)
    p.grad(m, c0, c1, y0, BOT, 6, 11)
    # board joints converging slightly
    for i in range(-16, 17):
        x0 = 160 + i * 14
        x1 = 160 + i * 26
        p.fill(p.line(x0, y0, x1, BOT, 1.0) & m, c0)
    for r in (3, 9, 18, 30):
        p.fill(p.rect(0, y0 + r, 320, y0 + r + 1) & (((p.x + r * 7) % 40) < 30), c0)


def bell(p, cx, top, s=1.0, col=YELLOW, dark=BROWN):
    w = lambda v: v * s * 0.8
    b = p.poly([(cx - w(9), top + 6 * s), (cx + w(9), top + 6 * s), (cx + w(14), top + 34 * s), (cx + w(21), top + 44 * s),
                (cx - w(21), top + 44 * s), (cx - w(14), top + 34 * s)])
    b |= p.disc(cx, top + 8 * s, w(9.5), 6 * s)
    b |= p.rect(cx - w(3), top, cx + w(3), top + 4 * s)
    p.fill(b, col)
    # shading on the right flank
    p.dither(b & (p.x > cx + w(4)), col, dark, 6)
    p.dither(b & (p.x > cx + w(10)), col, dark, 10)
    p.fill(b & (np.abs(p.y - (top + 30 * s)) < 0.8 * s), dark)
    p.fill(b & (np.abs(p.y - (top + 14 * s)) < 0.8 * s), dark)
    p.fill(p.disc(cx, top + 47 * s, w(3.5), 3 * s), col)
    return b


# ---------------------------------------------------------------------
#  the five stages, the title, the ending
# ---------------------------------------------------------------------
def stage_gate():
    p = Pic()
    sky(p, BLUE, MAGENTA, 96, 3, 24)
    sun(p, 268, 42, 18)
    mountains(p, 82, 22, 5, BLUE, MAGENTA, snow=True, peaks=[(250, 48, 50), (60, 58, 40)])
    # the courtyard wall
    wall = p.rect(0, 100, 320, 144)
    p.dither(wall, RED, MAGENTA, 6)
    p.dither(wall & ((p.y % 8) == 0), RED, MAGENTA, 2)
    p.fill(p.rect(0, 94, 320, 100), WHITE)
    p.dither(p.rect(0, 97, 320, 100), WHITE, GREY, 8)
    p.fill(p.rect(0, 92, 320, 94) & ((p.x % 6) < 4), GREY)
    bushes(p, 142, [(30, 18), (72, 14), (250, 16), (292, 20)])
    gate(p, 160, 144, 92, 46)
    lantern(p, 104, 146, 0.9)
    lantern(p, 216, 146, 0.9)
    blossom_tree(p, 14, 150, 1.0)
    tiled_floor(p, 144)
    return p


def stage_bridge():
    p = Pic()
    sky(p, BLUE, CYAN, 70)
    for cx, cy, w in ((50, 24, 40), (120, 32, 30), (210, 22, 44)):
        cloud(p, cx, cy, w)
    mountains(p, 72, 16, 9, BLUE, MAGENTA, snow=True, peaks=[(90, 44, 40)])
    # the cliff and waterfall on the right, a pagoda on top
    cliff = p.poly([(196, 200), (204, 92), (214, 74), (236, 64), (320, 60), (320, 200)])
    p.dither(cliff, DGREY, GREY, 8)
    p.dither(cliff & (((p.x // 5 + p.y // 7) % 3) == 0), DGREY, GREY, 3)
    top = cliff & (p.y < 82)
    p.dither(top, GREEN, BGREEN, 11)
    fall = p.rect(250, 66, 300, 200)
    p.fill(fall, CYAN)
    p.fill(fall & (((p.x * 3 + p.y // 2) % 7) < 2), WHITE)
    p.fill(fall & (p.x % 9 == 0), BCYAN)
    p.dither(p.rect(240, 128, 316, 138), CYAN, WHITE, 10)
    roof(p, 220, 56, 46, 10)
    p.fill(p.rect(206, 56, 234, 66), RED)
    p.fill(p.rect(212, 58, 216, 64) | p.rect(224, 58, 228, 64), YELLOW)
    roof(p, 220, 46, 30, 9)
    # forest on the left bank
    for x, w in ((14, 26), (52, 30), (96, 24), (140, 28), (180, 22)):
        m = p.disc(x, 96, w, 18) & (p.y < 120)
        p.dither(m, GREEN, BGREEN, 7)
        p.dither(m & (p.y < 88), GREEN, BGREEN, 12)
    p.dither(p.rect(0, 100, 250, 124), BLUE, CYAN, 7)
    # the bridge: deck, rail, posts with brass caps
    p.fill(p.rect(0, 118, 320, 121), RED)
    p.fill(p.rect(0, 130, 320, 133), RED)
    p.fill(p.rect(0, 121, 320, 130) & ((p.x % 16) < 3), RED)
    for x in range(8, 320, 72):
        p.fill(p.rect(x, 112, x + 8, 146), RED)
        p.dither(p.rect(x + 5, 112, x + 8, 146), RED, BRED, 8)
        p.fill(p.disc(x + 4, 108, 5, 5), YELLOW)
        p.dither(p.disc(x + 4, 108, 5, 5) & (p.x > x + 4), YELLOW, BROWN, 8)
    plank_floor(p, 146)
    return p


def stage_cliff():
    p = Pic()
    sky(p, BLACK, BLUE, 96, 21, 30)
    sun(p, 220, 36, 15, YELLOW, BLUE, stripes=False)
    p.dither(p.disc(222, 36, 18.5, 15) & ~p.disc(222, 36, 18.5 * 0.82, 15 * 0.82), BLUE, YELLOW, 4)
    mountains(p, 86, 24, 13, BLUE, MAGENTA, peaks=[(120, 52, 46)])
    # a pagoda on the far crag
    crag = p.poly([(30, 120), (46, 70), (70, 66), (88, 120)])
    p.dither(crag, DGREY, GREY, 6)
    p.dither(crag & (p.y < 80), GREEN, BGREEN, 10)
    roof(p, 60, 60, 36, 8)
    p.fill(p.rect(50, 60, 70, 68), RED)
    roof(p, 60, 52, 24, 7)
    # the torii on the path
    tor = 196
    for sx in (-22, 18):
        p.fill(p.rect(tor + sx, 84, tor + sx + 5, 140), RED)
    p.fill(p.poly([(tor - 34, 80), (tor + 34, 80), (tor + 30, 86), (tor - 30, 86)]), RED)
    p.fill(p.rect(tor - 30, 76, tor + 30, 80), BLACK)
    p.fill(p.rect(tor - 26, 92, tor + 26, 96), RED)
    p.fill(p.rect(tor - 2, 86, tor + 2, 92), RED)
    pine(p, 288, 150, 1.0)
    # rocks and the path
    r = np.random.RandomState(4)
    ground = p.rect(0, 136, 320, BOT)
    p.dither(ground, DGREY, GREY, 9)
    for i in range(26):
        x, y, w = r.randint(-10, 330), r.randint(136, 190), r.randint(10, 26)
        m = p.disc(x, y, w, w * 0.4)
        p.dither(m, GREY, WHITE, 5 + r.randint(0, 6))
        p.fill(m & ~np.roll(m, -1, 0) & ~np.roll(m, -2, 0), DGREY)
    p.dither(p.rect(0, 136, 320, 140), DGREY, GREY, 4)
    bushes(p, 138, [(10, 22), (110, 14), (150, 12)])
    return p


def stage_dojo():
    p = Pic()
    p.fill(p.rect(0, TOP, 320, BOT), BLACK)
    wall = p.rect(0, 24, 320, 136)
    p.dither(wall, BROWN, YELLOW, 3)
    # beams and posts
    p.fill(p.rect(0, 14, 320, 24), BROWN)
    p.dither(p.rect(0, 14, 320, 18), BROWN, YELLOW, 6)
    p.fill(p.rect(0, TOP, 320, 14) & ((p.x % 20) < 12), BROWN)
    for x in (0, 52, 262, 312):
        p.fill(p.rect(x, 24, x + 8, 136), BROWN)
        p.dither(p.rect(x, 24, x + 3, 136), BROWN, YELLOW, 8)
    # shoji screens, lit from outside
    for x0 in (8, 270):
        s = p.rect(x0, 30, x0 + 42, 126)
        p.dither(s, GREY, WHITE, 12)
        p.dither(s & (p.y < 62), MAGENTA, WHITE, 9)
        p.fill(s & (((p.x - x0) % 14) == 0), BROWN)
        p.fill(s & (((p.y - 30) % 16) == 0), BROWN)
    # the round window: sky and mountains beyond
    rw = p.disc(160, 70, 42, 36)
    inner = p.disc(160, 70, 38, 32)
    p.fill(rw, BROWN)
    p.grad(inner, CYAN, BLUE, 40, 100, 2, 12)
    h = p.profile(86, 12, 31)
    p.dither(inner & p.below(h), BLUE, MAGENTA, 9)
    p.fill(inner & ((np.abs(p.x - 160) % 19) == 0), BROWN)
    p.fill(inner & (((p.y - 70) % 16) == 0), BROWN)
    # hanging scrolls: the bell crest, and candles
    for x0 in (76, 220):
        s = p.rect(x0, 34, x0 + 24, 92)
        p.fill(s, YELLOW)
        p.fill(p.rect(x0 - 2, 32, x0 + 26, 35) | p.rect(x0 - 2, 91, x0 + 26, 94), BROWN)
        b = p.poly([(x0 + 9, 48), (x0 + 15, 48), (x0 + 18, 70), (x0 + 6, 70)]) | p.disc(x0 + 12, 49, 4, 3)
        p.fill(b, BLACK)
        p.fill(p.rect(x0 + 4, 70, x0 + 20, 73), BLACK)
        p.fill(p.disc(x0 + 12, 76, 2, 2), BLACK)
        cx = x0 + 12
        p.fill(p.rect(cx - 6, 118, cx + 6, 122) | p.rect(cx - 2, 104, cx + 2, 118), YELLOW)
        p.fill(p.rect(cx - 1, 96, cx + 1, 104), WHITE)
        p.fill(p.disc(cx, 94, 2, 3), BRED)
    # the low step and the floor
    p.fill(p.rect(0, 128, 320, 136), BROWN)
    p.dither(p.rect(0, 128, 320, 131), BROWN, YELLOW, 10)
    plank_floor(p, 136)
    return p


def stage_tower():
    p = Pic()
    sky(p, BLACK, BLUE, 110)
    r = np.random.RandomState(2)
    for cx, cy, rx in ((40, 26, 50), (110, 18, 40), (250, 22, 56), (300, 40, 34), (170, 44, 30)):
        m = p.disc(cx, cy, rx, 10) | p.disc(cx + rx * 0.4, cy + 6, rx * 0.7, 8)
        p.dither(m, BLUE, BBLUE, 7)
        p.dither(m & (p.y < cy - 3), BLUE, BBLUE, 11)
    z = p.line(52, 38, 44, 56, 1.8) | p.line(44, 56, 56, 58, 1.8) | p.line(56, 58, 42, 86, 1.8)
    p.fill(z, WHITE)
    p.fill(p.line(270, 46, 278, 64, 1.4) | p.line(278, 64, 270, 80, 1.4), BCYAN)
    # the battlements
    wall = p.rect(0, 112, 320, 148)
    p.dither(wall, DGREY, GREY, 8)
    for x in range(0, 320, 32):
        p.fill(p.rect(x, 100, x + 18, 112), GREY)
        p.dither(p.rect(x + 12, 100, x + 18, 112), GREY, DGREY, 8)
    p.fill(wall & ((p.y % 12) == 0), BLACK)
    p.fill(wall & (((p.x + (p.y // 12) * 16) % 32) == 0), BLACK)
    # the bell frame and bell
    p.fill(p.rect(104, 12, 216, 20), RED)
    p.dither(p.rect(104, 12, 216, 15), RED, BRED, 8)
    roof(p, 160, 12, 140, 8, RED, BRED)
    p.fill(p.rect(110, 20, 118, 148) | p.rect(202, 20, 210, 148), RED)
    p.dither(p.rect(110, 20, 113, 148) | p.rect(202, 20, 205, 148), RED, BRED, 8)
    bell(p, 160, 22, 1.25)
    tiled_floor(p, 148, GREY, WHITE)
    return p


def title():
    p = Pic()
    sky(p, BLUE, MAGENTA, 120, 31, 26)
    sun(p, 150, 70, 34)
    h = mountains(p, 104, 20, 7, BLUE, CYAN, peaks=[(150, 70, 50), (40, 84, 36), (280, 80, 40)], bottom=128)
    # the keep on the peak
    roof(p, 150, 62, 40, 8, CYAN, BLUE)
    p.fill(p.rect(138, 62, 162, 72), CYAN)
    p.fill(p.rect(144, 64, 148, 70) | p.rect(152, 64, 156, 70), BLACK)
    roof(p, 150, 54, 26, 8, CYAN, BLUE)
    p.fill(p.rect(0, 120, 320, 132), BLACK)
    p.dither(p.rect(0, 116, 320, 124), MAGENTA, BLACK, 10)
    blossom_tree(p, 10, 140, 0.95, leaf=BMAGENTA, dark=MAGENTA)
    blossom_tree(p, 312, 140, 0.8, flip=True, leaf=BMAGENTA, dark=MAGENTA)
    p.fill(p.rect(0, 120, 320, 200) & (p.y >= 132), BLACK)
    # the name: heavy letters with a deep shadow
    m = p.text('STORMBELL', 25, 10, YELLOW, 5, 4, shadow=RED, dx=2, dy=2)
    p.fill(m & ((p.y - 10) >= 20), BROWN)
    p.dither(m & ((p.y - 10) >= 14) & ((p.y - 10) < 20), YELLOW, BROWN, 6)
    return p


def ending():
    p = Pic()
    # dawn: the sky lightens to the horizon, the sun rises behind the peaks
    sky(p, BLUE, MAGENTA, 112)
    sun(p, 236, 76, 26, YELLOW, MAGENTA)
    mountains(p, 108, 12, 3, BLUE, MAGENTA, snow=True, peaks=[(300, 88, 40), (150, 92, 40)], bottom=128)
    p.fill(p.rect(0, 120, 320, 200), BLACK)
    p.dither(p.rect(0, 116, 320, 124), MAGENTA, BLACK, 10)
    # the tower on the left: frame, roof, and the bell, ringing
    p.fill(p.rect(40, 30, 48, 124) | p.rect(132, 30, 140, 124), RED)
    p.dither(p.rect(40, 30, 43, 124) | p.rect(132, 30, 135, 124), RED, BRED, 8)
    p.fill(p.rect(34, 26, 146, 32), RED)
    roof(p, 90, 26, 140, 12, YELLOW, BROWN)
    bell(p, 90, 34, 1.3, WHITE, GREY)
    for rr in (40, 52, 64):
        ring = p.disc(90, 66, rr * 1.15, rr) & ~p.disc(90, 66, rr * 1.15 - 1.5, rr - 1.5)
        ring &= (np.abs(p.x - 90) > 26) & (p.y < 112) & (p.y > TOP + 4)
        p.fill(ring & (p.bay < 9), WHITE)
    # a small figure bowing at the foot of the tower
    fig = p.disc(176, 106, 3, 3) | p.poly([(171, 108), (180, 108), (184, 122), (168, 122)])
    p.fill(fig, WHITE)
    return p


def dilate(m):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


PICS = [('title', title), ('gate', stage_gate), ('bridge', stage_bridge), ('cliff', stage_cliff),
        ('dojo', stage_dojo), ('tower', stage_tower), ('ending', ending)]
STAGE_NAMES = ['THE OUTER GATE', 'THE RIVER BRIDGE', 'THE CLIFF PATH', 'THE DOJO HALL', 'THE BELL TOWER']


def preview(path, pics=None, quant=True):
    from PIL import Image
    ims = []
    for name, fn in (pics or PICS):
        p = fn()
        if quant:
            c, bk, k, g, n = p.pack(name)
            print(name, n, 'glyphs')
        ims.append(p.rgb(quant))
    while len(ims) % 2:
        ims.append(np.zeros_like(ims[0]))
    rows = [np.concatenate(ims[i:i + 2], 1) for i in range(0, len(ims), 2)]
    sheet = np.concatenate(rows, 0)
    Image.fromarray(sheet).resize((int(sheet.shape[1] * 1.25 * 1.5), sheet.shape[0] * 3 // 2), Image.NEAREST).save(path)


if __name__ == '__main__':
    import sys
    preview(sys.argv[1])
