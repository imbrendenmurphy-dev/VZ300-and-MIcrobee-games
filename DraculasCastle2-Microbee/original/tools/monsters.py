# monsters.py - battle monster artwork (64x44, 4 colours + key) and battle backdrops (128x46)
import math
from PIL import Image, ImageDraw

W, H = 64, 44
T = -1   # transparent

class Canvas:
    def __init__(self, w=W, h=H, fill=T):
        self.w, self.h = w, h
        self.p = [[fill] * w for _ in range(h)]
    def _mask(self, drawfn, ss=4):
        im = Image.new('L', (self.w * ss, self.h * ss), 0)
        d = ImageDraw.Draw(im)
        drawfn(d, ss)
        im = im.resize((self.w, self.h), Image.BOX)
        return im.load()
    def paint(self, m, fill, thresh=128):
        for y in range(self.h):
            for x in range(self.w):
                if m[x, y] >= thresh:
                    self.p[y][x] = self.pat(fill, x, y)
    def pat(self, fill, x, y):
        if isinstance(fill, int): return fill
        a, b = fill[0], fill[1]
        mode = fill[2] if len(fill) > 2 else 50
        if mode == 50: return b if (x + y) & 1 else a
        if mode == 25: return b if (x & 1) and (y & 1) else a
        if mode == 75: return a if (x & 1) and (y & 1) else b
        if mode == 'h': return b if y & 1 else a
        if mode == 'v': return b if x & 1 else a
        return a
    def ellipse(self, cx, cy, rx, ry, fill):
        self.paint(self._mask(lambda d, s: d.ellipse([(cx - rx) * s, (cy - ry) * s, (cx + rx) * s, (cy + ry) * s], fill=255)), fill)
    def poly(self, pts, fill):
        self.paint(self._mask(lambda d, s: d.polygon([(x * s, y * s) for x, y in pts], fill=255)), fill)
    def line(self, x0, y0, x1, y1, fill, w=1.0):
        self.paint(self._mask(lambda d, s: d.line([(x0 * s, y0 * s), (x1 * s, y1 * s)], fill=255, width=max(1, int(w * s)))), fill, 100)
    def rect(self, x0, y0, x1, y1, fill):
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                self.p[y][x] = self.pat(fill, x, y)
    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h: self.p[y][x] = c
    def outline(self, col, only_into=None):
        """add an outline of colour col around opaque pixels"""
        q = [r[:] for r in self.p]
        for y in range(self.h):
            for x in range(self.w):
                if self.p[y][x] != T: continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and self.p[ny][nx] != T and self.p[ny][nx] != col:
                        q[y][x] = col; break
        self.p = q
    def mirror_x(self, cx=32):
        for y in range(self.h):
            for x in range(cx, self.w):
                mx = 2 * cx - 1 - x
                if 0 <= mx < self.w: self.p[y][x] = self.p[y][mx]

G, Y, B, R = 0, 1, 2, 3        # CSS0 names
BU, CY, MA, OR = 0, 1, 2, 3    # CSS1 names

# ----------------------------------------------------------------- BAT
def bat(frame):
    c = Canvas()
    up = {0: 1, 1: -1, 2: 0}[frame]
    cx, cy = 32, 22 if frame != 2 else 24
    # wings (left side, mirrored)
    tip_y = cy - 14 * up if up else cy - 4
    pts = [(cx - 4, cy - 3), (cx - 12, tip_y + 2), (cx - 20, tip_y - 2), (cx - 29, tip_y + 4 + (6 if up < 0 else 0)),
           (cx - 25, cy + 4 + 6 * (up < 0)), (cx - 20, cy + 1 + 4 * (up < 0)), (cx - 15, cy + 7 + 4 * (up < 0)),
           (cx - 10, cy + 2), (cx - 4, cy + 6)]
    c.poly(pts, (R, B, 25))
    for (ex, ey) in ((cx - 12, tip_y + 2), (cx - 20, tip_y - 2), (cx - 29, tip_y + 4 + (6 if up < 0 else 0))):
        c.line(cx - 4, cy - 1, ex, ey, B, 0.8)
    c.mirror_x(32)
    # body + head
    c.ellipse(cx, cy + 3, 6, 9, R)
    c.ellipse(cx, cy + 5, 3, 6, (R, B, 50))
    c.ellipse(cx, cy - 6, 6, 5, R)
    c.poly([(cx - 6, cy - 8), (cx - 7, cy - 16), (cx - 2, cy - 10)], R)    # ears
    c.poly([(cx + 6, cy - 8), (cx + 7, cy - 16), (cx + 2, cy - 10)], R)
    c.px(cx - 6, cy - 13, B); c.px(cx + 6, cy - 13, B)
    # eyes
    for ex in (cx - 3, cx + 2):
        c.rect(ex, cy - 8, ex + 1, cy - 6, Y)
    c.px(cx - 3, cy - 7, B) if frame == 1 else None
    # fangs / mouth
    if frame == 2:
        c.rect(cx - 3, cy - 4, cx + 2, cy - 1, B)
        c.px(cx - 3, cy - 4, Y); c.px(cx + 2, cy - 4, Y); c.px(cx - 3, cy - 3, Y); c.px(cx + 2, cy - 3, Y)
    else:
        c.px(cx - 2, cy - 3, Y); c.px(cx + 1, cy - 3, Y)
    # feet
    c.line(cx - 3, cy + 11, cx - 4, cy + 14, Y); c.line(cx + 2, cy + 11, cx + 3, cy + 14, Y)
    c.outline(B)
    return c, G

# ----------------------------------------------------------------- SKELETON
def skeleton(frame):
    c = Canvas()
    cx = 30
    bob = 1 if frame == 1 else 0
    # legs
    for sx in (-5, 5):
        c.line(cx + sx, 30, cx + sx * 1.2, 37, Y, 1.6)
        c.line(cx + sx * 1.2, 37, cx + sx * 1.1, 42, Y, 1.6)
        c.rect(int(cx + sx * 1.1) - 2, 42, int(cx + sx * 1.1) + 2, 43, Y)
        c.ellipse(cx + sx * 1.2, 37, 1.6, 1.4, (Y, B, 50))
    # pelvis
    c.poly([(cx - 7, 27), (cx + 7, 27), (cx + 5, 31), (cx - 5, 31)], Y)
    c.rect(cx - 1, 28, cx, 30, B)
    # spine + ribs
    c.line(cx, 14 + bob, cx, 27, Y, 1.5)
    for i, ry in enumerate(range(15 + bob, 26, 3)):
        wdt = 8 - abs(i - 1)
        c.line(cx - wdt, ry + 1, cx + wdt, ry + 1, Y, 1.2)
        c.px(cx - wdt, ry + 2, B); c.px(cx + wdt, ry + 2, B)
    # shoulders
    c.line(cx - 9, 14 + bob, cx + 9, 14 + bob, Y, 1.5)
    # skull
    sy = 6 + bob
    c.ellipse(cx, sy, 6, 6, Y)
    c.rect(cx - 4, sy + 4, cx + 4, sy + 8, Y)
    c.rect(cx - 4, sy - 1, cx - 2, sy + 2, B)            # eye sockets
    c.rect(cx + 2, sy - 1, cx + 4, sy + 2, B)
    c.px(cx - 3, sy, R); c.px(cx + 3, sy, R)              # glowing red pupils
    c.px(cx, sy + 3, B)                                     # nose
    for tx in range(cx - 3, cx + 4, 2): c.px(tx, sy + 6 + (1 if frame == 1 else 0), B)   # teeth gaps
    if frame == 1: c.rect(cx - 3, sy + 7, cx + 3, sy + 7, B)  # jaw drops (rattle)
    # shield arm (left)
    c.line(cx - 9, 14 + bob, cx - 13, 21, Y, 1.4)
    c.ellipse(cx - 15, 23, 6, 8, (R, B, 25))
    c.ellipse(cx - 15, 23, 3, 4, Y)
    c.px(cx - 15, 23, R)
    # sword arm (right)
    if frame == 2:      # swing down across
        c.line(cx + 9, 14, cx + 14, 18, Y, 1.4)
        c.line(cx + 14, 18, cx + 26, 30, (Y, B, 50), 2.2)
        c.line(cx + 12, 15, cx + 16, 21, R, 1.5)
    else:
        c.line(cx + 9, 14 + bob, cx + 14, 20 + bob, Y, 1.4)
        c.line(cx + 14, 20 + bob, cx + 15, 1 + bob, (Y, B, 50), 2.2)       # blade up
        c.line(cx + 11, 20 + bob, cx + 18, 20 + bob, R, 1.5)               # crossguard
        c.px(cx + 15, 0 + bob, Y)
    c.outline(B)
    return c, G

# ----------------------------------------------------------------- GHOST (CSS1)
def ghost(frame):
    c = Canvas()
    cx, cy = 32, 16 + (1 if frame == 1 else 0)
    # flowing body: head circle + skirt with wavy hem
    c.ellipse(cx, cy, 11, 11, BU)
    hem = []
    wave = 0 if frame != 1 else 1.5
    for i in range(0, 25):
        x = cx - 14 + i * 28 / 24
        y = 40 + 2.5 * math.sin(i * 0.9 + wave)
        hem.append((x, y))
    body = [(cx - 11, cy), (cx + 11, cy), (cx + 14, cy + 14)] + hem[::-1][:-0 or None] + [(cx - 14, cy + 14)]
    c.poly([(cx - 11, cy), (cx + 11, cy), (cx + 15, 40)] + hem[::-1] + [(cx - 15, 40)], BU)
    # shading
    c.poly([(cx + 6, cy + 4), (cx + 13, cy + 12), (cx + 15, 40), (cx + 8, 40)], (BU, CY, 50))
    c.poly([(cx - 15, 40), (cx - 10, 26), (cx - 6, 40)], (BU, CY, 25))
    # arms
    if frame == 2:
        c.poly([(cx - 10, cy + 8), (cx - 28, cy + 2), (cx - 30, cy + 6), (cx - 12, cy + 14)], BU)
        c.poly([(cx + 10, cy + 8), (cx + 28, cy + 2), (cx + 30, cy + 6), (cx + 12, cy + 14)], BU)
        for fx in (-30, 30):
            for k in range(3): c.px(cx + fx + (k if fx < 0 else -k), cy + 1 + k * 2, CY)
    else:
        c.poly([(cx - 10, cy + 9), (cx - 20, cy + 18 - frame * 2), (cx - 17, cy + 22 - frame * 2), (cx - 9, cy + 16)], BU)
        c.poly([(cx + 10, cy + 9), (cx + 20, cy + 18 + frame * 2), (cx + 17, cy + 22 + frame * 2), (cx + 9, cy + 16)], BU)
    # face
    ey = cy - 2
    c.ellipse(cx - 4, ey, 2.4, 3.4, MA); c.ellipse(cx + 4, ey, 2.4, 3.4, MA)
    c.px(cx - 4, ey - 1, OR); c.px(cx + 4, ey - 1, OR)
    if frame == 2: c.ellipse(cx, cy + 6, 3.5, 4.5, MA)
    else: c.ellipse(cx, cy + 6, 2, 2.5 + frame, MA)
    c.outline(CY)
    return c, OR

# ----------------------------------------------------------------- GARGOYLE (boss)
def gargoyle(frame):
    c = Canvas()
    cx = 32
    spread = {0: 0, 1: 2, 2: 8}[frame]
    # wings: dark membrane with bright bony ribs
    wp = [(cx - 8, 14), (cx - 18 - spread, 2 - spread // 2), (cx - 24 - spread, 4), (cx - 30 - spread // 2, 14 + spread),
          (cx - 26, 22), (cx - 22, 18), (cx - 18, 26), (cx - 12, 22)]
    c.poly(wp, (B, R, 25))
    c.line(cx - 8, 14, cx - 18 - spread, 2 - spread // 2, Y, 1.2)
    c.line(cx - 18 - spread, 2 - spread // 2, cx - 24 - spread, 4, Y, 1)
    c.line(cx - 10, 16, cx - 30 - spread // 2, 14 + spread, Y, 1)
    c.line(cx - 12, 19, cx - 22, 18, Y, 1)
    c.mirror_x(32)
    # pedestal
    c.rect(cx - 14, 40, cx + 13, 43, (Y, B, 50))
    c.rect(cx - 16, 38, cx + 15, 39, Y)
    c.line(cx - 16, 40, cx + 15, 40, B)
    # body
    c.ellipse(cx, 28, 11, 11, (Y, B, 25))
    c.ellipse(cx + 4, 30, 6, 7, (Y, B, 50))
    c.line(cx - 6, 22, cx + 6, 22, B); c.line(cx - 7, 26, cx + 7, 26, B); c.line(cx - 6, 30, cx + 6, 30, B)
    for sx in (-1, 1):
        c.ellipse(cx + sx * 9, 34, 5, 5, Y)
        c.ellipse(cx + sx * 10, 35, 3, 3, (Y, B, 50))
        for k in range(3): c.px(cx + sx * 9 + (k - 1) * 2, 38 + (1 if frame == 2 else 0), R)
    if frame == 2:
        c.line(cx - 8, 22, cx - 17, 33, Y, 2.5); c.line(cx + 8, 22, cx + 17, 33, Y, 2.5)
        for sx in (-19, 15):
            for k in range(4): c.px(cx + sx + k, 35, R)
    else:
        c.line(cx - 8, 22, cx - 6, 33, Y, 2.5); c.line(cx + 8, 22, cx + 6, 33, Y, 2.5)
    hy = 14 - (2 if frame == 2 else 0)
    c.ellipse(cx, hy, 7, 6, Y)
    c.ellipse(cx + 3, hy + 2, 3, 3, (Y, B, 25))
    c.poly([(cx - 5, hy - 3), (cx - 11, hy - 12), (cx - 2, hy - 5)], Y)
    c.poly([(cx + 5, hy - 3), (cx + 11, hy - 12), (cx + 2, hy - 5)], Y)
    c.line(cx - 6, hy - 2, cx - 1, hy - 1, B); c.line(cx + 6, hy - 2, cx + 1, hy - 1, B)   # brow
    c.rect(cx - 4, hy - 1, cx - 2, hy, R); c.rect(cx + 2, hy - 1, cx + 4, hy, R)
    if frame == 0: c.rect(cx - 4, hy - 1, cx - 2, hy - 1, B); c.rect(cx + 2, hy - 1, cx + 4, hy - 1, B)
    c.rect(cx - 3, hy + 3, cx + 3, hy + 4 + (1 if frame == 2 else 0), B)
    c.px(cx - 2, hy + 3, Y); c.px(cx + 2, hy + 3, Y)
    c.outline(B)
    return c, G

# ----------------------------------------------------------------- GRELL (library boss)
def grell(frame):
    c = Canvas()
    cx, cy = 32, 14 + (frame == 1)
    # tentacles hanging below, swaying per frame
    for k in range(7):
        x0 = cx - 12 + k * 4
        sway = (k - 3) * 1.2 + (2 if frame == 1 else -2 if frame == 2 else 0) * (1 if k & 1 else -1)
        pts = [(x0, cy + 8)]
        for j in range(1, 6):
            pts.append((x0 + sway * j / 5 + math.sin(j + k + frame) * 1.5, cy + 8 + j * 5))
        for a, b in zip(pts, pts[1:]): c.line(a[0], a[1], b[0], b[1], (G, Y, 25) if k & 1 else G, 1.6)
        c.px(int(pts[-1][0]), int(pts[-1][1]) + 1, R)
    # brain-like body: lumpy ellipse
    c.ellipse(cx, cy, 17, 12, G)
    for bx, by, r in ((-9, -5, 5), (0, -8, 6), (9, -5, 5), (-5, 0, 5), (5, 0, 5)):
        c.ellipse(cx + bx, cy + by, r, r - 1, (G, Y, 25))
    for bx in (-11, -4, 3, 10):
        c.line(cx + bx, cy - 8, cx + bx + 2, cy + 2, (G, B, 50) if False else G, 1)
    # one great eye
    eo = (frame - 1) * 2
    c.ellipse(cx, cy - 1, 6, 5, Y)
    c.ellipse(cx + eo, cy - 1, 3, 3.5, R)
    c.px(cx + eo, cy - 2, Y)
    # hooked beak
    c.poly([(cx - 4, cy + 6), (cx + 4, cy + 6), (cx + 1, cy + 13 + (frame == 2) * 2), (cx - 1, cy + 11)], Y)
    c.line(cx - 3, cy + 8, cx + 2, cy + 8, R)
    c.outline(Y)
    return c, B

# ----------------------------------------------------------------- ZOMBIE
def zombie(frame):
    c = Canvas()
    cx = 32 + (frame - 1)
    lean = (frame - 1) * 2
    # legs
    c.poly([(cx - 7, 30), (cx - 2, 30), (cx - 3 - lean, 43), (cx - 8 - lean, 43)], R)
    c.poly([(cx + 2, 30), (cx + 7, 30), (cx + 8 + lean, 43), (cx + 3 + lean, 43)], R)
    c.rect(cx - 9 - lean, 42, cx - 2 - lean, 43, Y); c.rect(cx + 2 + lean, 42, cx + 9 + lean, 43, Y)
    # ragged torso
    c.poly([(cx - 10, 13), (cx + 10, 13), (cx + 9, 31), (cx + 5, 33), (cx + 1, 30), (cx - 4, 33), (cx - 9, 31)], (R, Y, 25))
    c.poly([(cx - 3, 14), (cx + 3, 14), (cx + 1, 24), (cx - 1, 24)], G)        # rotten skin showing
    # arms reaching forward
    ay = 15 + (frame == 2) * -3
    c.poly([(cx - 10, 14), (cx - 24, ay + 2), (cx - 25, ay + 6), (cx - 9, 20)], R)
    c.poly([(cx + 10, 14), (cx + 24, ay + 4), (cx + 25, ay + 8), (cx + 9, 20)], R)
    for hx, hy in ((cx - 27, ay + 3), (cx + 27, ay + 5)):
        c.ellipse(hx, hy, 3, 2.5, G)
        for k in range(3): c.px(hx + (-3 if hx < cx else 3), hy - 1 + k, G)
    # head tilted
    hx = cx + (frame - 1) * 2
    c.ellipse(hx, 7, 7, 7, G)
    c.ellipse(hx - 3, 6, 2, 2, R); c.ellipse(hx + 3, 6, 2, 2, R)
    c.px(hx - 3, 6, Y); c.px(hx + 3, 6, Y)
    c.rect(hx - 3, 10, hx + 3, 11, R)
    for k in range(-2, 3, 2): c.px(hx + k, 10, Y)
    c.line(hx - 6, 1, hx - 2, 3, Y); c.line(hx + 1, 0, hx + 5, 2, Y)      # wisps of hair
    c.outline(Y)
    return c, B

# ----------------------------------------------------------------- SLIME
def slime(frame):
    c = Canvas()
    cx = 32; squash = (0, 3, -3)[frame]
    ry = 13 - squash; rx = 21 + squash
    c.ellipse(cx, 43 - ry, rx, ry, G)
    c.rect(cx - rx, 40, cx + rx, 43, G)
    c.ellipse(cx - 6, 43 - ry * 1.4, 6, 4, (G, Y, 25))
    # bubbles and a few swallowed bones
    c.ellipse(cx + 8, 36 - squash, 3, 3, (G, Y, 50)); c.ellipse(cx - 12, 38, 2, 2, (G, Y, 50))
    c.line(cx - 4, 39, cx + 4, 37, Y); c.px(cx - 5, 39, Y); c.px(cx + 5, 37, Y)
    # eyes on stalks
    for ex in (-6, 6):
        top = 43 - ry * 2 - 4 - (frame == 1) * 2
        c.line(cx + ex, 43 - ry * 1.6, cx + ex + ex // 3, top, G, 1.2)
        c.ellipse(cx + ex + ex // 3, top, 3, 3, Y)
        c.px(cx + ex + ex // 3, top, R)
    # drips
    for dx in (-15, -2, 11):
        c.line(cx + dx, 43, cx + dx, 44, G)
    c.outline(Y)
    return c, B

# ----------------------------------------------------------------- GHOUL KING (dungeon boss)
def ghoulking(frame):
    c = Canvas()
    cx = 32; crouch = (0, 1, -1)[frame]
    # cloak
    c.poly([(cx - 14, 14 + crouch), (cx + 14, 14 + crouch), (cx + 20, 43), (cx - 20, 43)], (R, Y, 25))
    c.poly([(cx - 6, 16 + crouch), (cx + 6, 16 + crouch), (cx + 8, 43), (cx - 8, 43)], G)
    for k in range(5): c.line(cx - 6 + k * 3, 20 + crouch, cx - 7 + k * 3.5, 42, (G, R, 50))   # ribs
    # long arms with claws
    ay = 18 + crouch + (frame == 2) * -6
    c.poly([(cx - 13, 16 + crouch), (cx - 26, ay + 10), (cx - 24, ay + 13), (cx - 10, 22 + crouch)], G)
    c.poly([(cx + 13, 16 + crouch), (cx + 26, ay + 10), (cx + 24, ay + 13), (cx + 10, 22 + crouch)], G)
    for sx in (-1, 1):
        for k in range(3): c.line(cx + sx * 25, ay + 12, cx + sx * (27 + k), ay + 16 + k, Y)
    # head: long skull-like face, glowing eyes, fangs
    hy = 9 + crouch
    c.ellipse(cx, hy, 7, 8, G)
    c.ellipse(cx - 3, hy - 1, 2.2, 2, R); c.ellipse(cx + 3, hy - 1, 2.2, 2, R)
    c.px(cx - 3, hy - 1, Y); c.px(cx + 3, hy - 1, Y)
    c.rect(cx - 3, hy + 4, cx + 3, hy + 5, R)
    c.px(cx - 2, hy + 6, Y); c.px(cx + 2, hy + 6, Y)
    c.poly([(cx - 9, 6), (cx - 4, 6), (cx - 2, 1), (cx, 4), (cx + 2, 1), (cx + 4, 6), (cx + 9, 6), (cx + 8, 3), (cx - 8, 3)], Y)  # crown
    c.px(cx, 2, R)
    c.outline(Y)
    return c, B

# ----------------------------------------------------------------- KNIGHT (animated armour)
def knight(frame):
    c = Canvas()
    cx = 32; step = (frame - 1)
    # legs (greaves)
    c.rect(cx - 7, 30, cx - 3, 42 - step, (Y, B, 25)); c.rect(cx + 3, 30, cx + 7, 42 + step, (Y, B, 25))
    c.rect(cx - 8, 41 - step, cx - 2, 43 - step, Y); c.rect(cx + 2, 41 + step, cx + 8, 43, Y)
    # breastplate and tassets
    c.poly([(cx - 10, 13), (cx + 10, 13), (cx + 9, 26), (cx + 6, 31), (cx - 6, 31), (cx - 9, 26)], Y)
    c.poly([(cx - 6, 15), (cx + 6, 15), (cx + 4, 27), (cx - 4, 27)], (Y, B, 25))
    c.line(cx, 15, cx, 28, B)
    c.rect(cx - 9, 29, cx + 9, 31, R)
    # pauldrons + arms; sword raised on frame 2
    c.ellipse(cx - 12, 15, 4, 3, Y); c.ellipse(cx + 12, 15, 4, 3, Y)
    c.rect(cx - 15, 16, cx - 12, 27, (Y, B, 25))
    if frame == 2:
        c.rect(cx + 12, 6, cx + 15, 16, (Y, B, 25))
        c.rect(cx + 13, -1, cx + 14, 6, Y); c.rect(cx + 10, 5, cx + 17, 6, R)
    else:
        c.rect(cx + 12, 16, cx + 15, 27, (Y, B, 25))
        c.rect(cx + 18, 8, cx + 19, 30, Y); c.rect(cx + 15, 27, cx + 22, 28, R)   # sword held upright
    # shield
    c.poly([(cx - 22, 18), (cx - 12, 18), (cx - 12, 30), (cx - 17, 35), (cx - 22, 30)], R)
    c.line(cx - 17, 20, cx - 17, 32, Y); c.line(cx - 21, 24, cx - 13, 24, Y)
    # great helm with glowing slit
    c.rect(cx - 6, 2, cx + 6, 12, Y)
    c.ellipse(cx, 2, 6, 3, Y)
    c.rect(cx - 5, 6, cx + 5, 7, B)
    c.px(cx - 3, 6, R); c.px(cx + 2, 6, R)
    c.line(cx, 0, cx, -1, R)
    c.outline(R)
    return c, G

# ----------------------------------------------------------------- BAT LORD (tower boss)
def batlord(frame):
    c = Canvas()
    up = {0: 1, 1: -1, 2: 0}[frame]
    cx, cy = 32, 20 + (frame == 2) * 2
    tip_y = cy - 16 * up if up else cy - 6
    pts = [(cx - 5, cy - 4), (cx - 14, tip_y + 2), (cx - 22, tip_y - 3), (cx - 31, tip_y + 5 + (7 if up < 0 else 0)),
           (cx - 27, cy + 8 + 6 * (up < 0)), (cx - 21, cy + 4 + 4 * (up < 0)), (cx - 16, cy + 11 + 4 * (up < 0)),
           (cx - 11, cy + 5), (cx - 5, cy + 9)]
    c.poly(pts, (MA, OR, 25))
    for (ex, ey) in ((cx - 14, tip_y + 2), (cx - 22, tip_y - 3), (cx - 31, tip_y + 5 + (7 if up < 0 else 0))):
        c.line(cx - 5, cy - 2, ex, ey, OR, 1.0)
    c.mirror_x(32)
    c.ellipse(cx, cy + 5, 8, 12, OR)
    c.ellipse(cx, cy + 7, 4, 8, (OR, MA, 50))
    c.ellipse(cx, cy - 6, 8, 7, OR)
    c.poly([(cx - 7, cy - 9), (cx - 9, cy - 20), (cx - 2, cy - 12)], OR)
    c.poly([(cx + 7, cy - 9), (cx + 9, cy - 20), (cx + 2, cy - 12)], OR)
    c.poly([(cx - 5, cy - 12), (cx - 3, cy - 16), (cx, cy - 13), (cx + 3, cy - 16), (cx + 5, cy - 12)], CY)  # crown
    for ex in (cx - 4, cx + 3):
        c.rect(ex - 1, cy - 8, ex + 1, cy - 6, CY)
    c.px(cx - 4, cy - 7, MA); c.px(cx + 3, cy - 7, MA)
    c.rect(cx - 3, cy - 3, cx + 3, cy - 1 + (frame == 2) * 2, MA)
    c.px(cx - 3, cy - 3, CY); c.px(cx + 3, cy - 3, CY); c.px(cx - 3, cy - 2, CY); c.px(cx + 3, cy - 2, CY)
    for fx in (-4, 3):
        c.line(cx + fx, cy + 16, cx + fx + (1 if fx > 0 else -1), cy + 20, CY)
    c.outline(MA)
    return c, BU

# ----------------------------------------------------------------- DRACULA (final boss)
def dracula(frame):
    c = Canvas()
    cx = 32
    spread = (4, 14, 10)[frame]
    # cape: dark outside, blood-red lining shown when spread
    c.poly([(cx - 8, 10), (cx - 10 - spread, 6 - spread // 3), (cx - 14 - spread, 43), (cx + 14 + spread, 43),
            (cx + 10 + spread, 6 - spread // 3), (cx + 8, 10)], B)
    if spread > 6:
        c.poly([(cx - 9, 12), (cx - 8 - spread, 9), (cx - 11 - spread, 41), (cx - 7, 41)], R)
        c.poly([(cx + 9, 12), (cx + 8 + spread, 9), (cx + 11 + spread, 41), (cx + 7, 41)], R)
    # body: black suit, white shirt, red medallion
    c.poly([(cx - 7, 12), (cx + 7, 12), (cx + 6, 43), (cx - 6, 43)], B)
    c.poly([(cx - 3, 12), (cx + 3, 12), (cx + 1, 26), (cx - 1, 26)], Y)
    c.ellipse(cx, 18, 1.5, 1.5, R)
    # high collar
    c.poly([(cx - 9, 13), (cx - 13, 1), (cx - 6, 8)], R); c.poly([(cx + 9, 13), (cx + 13, 1), (cx + 6, 8)], R)
    # head: pale face, widow's peak, red eyes, fangs
    hy = 6 - (frame == 2)
    c.ellipse(cx, hy, 5.5, 6.5, Y)
    c.poly([(cx - 6, hy - 2), (cx - 5, hy - 7), (cx, hy - 8), (cx + 5, hy - 7), (cx + 6, hy - 2), (cx, hy - 4)], B)
    c.rect(cx - 3, hy - 1, cx - 2, hy, R); c.rect(cx + 2, hy - 1, cx + 3, hy, R)
    if frame == 2:
        c.rect(cx - 2, hy + 3, cx + 2, hy + 4, R); c.px(cx - 2, hy + 5, Y); c.px(cx + 2, hy + 5, Y)
    else:
        c.line(cx - 2, hy + 3, cx + 2, hy + 3, R); c.px(cx - 1, hy + 4, Y); c.px(cx + 1, hy + 4, Y)
    # hands (claws) at the cape edges
    for sx in (-1, 1):
        hx = cx + sx * (11 + spread); c.ellipse(hx, 12 - spread // 3, 2.5, 2.5, Y)
        for k in range(3): c.px(hx + sx * 2, 10 - spread // 3 + k * 2, Y)
    c.outline(Y)
    c.p = [[T] * W for _ in range(4)] + c.p[:-4]        # sit him lower so the whole head shows
    return c, G

# ----------------------------------------------------------------- VAMPIRE BRIDE
def bride(frame):
    c = Canvas()
    cx = 32; sway = (0, 2, -2)[frame]
    # flowing white gown
    c.poly([(cx - 7, 14), (cx + 7, 14), (cx + 15 + sway, 43), (cx - 15 + sway, 43)], Y)
    for k in range(-12, 13, 6): c.line(cx + k // 3, 18, cx + k + sway, 43, (Y, B, 25))
    # long black hair framing a pale face
    c.ellipse(cx, 8, 8, 9, B)
    c.poly([(cx - 8, 8), (cx - 11 + sway, 26), (cx - 5, 20)], B); c.poly([(cx + 8, 8), (cx + 11 + sway, 26), (cx + 5, 20)], B)
    c.ellipse(cx, 9, 4.5, 5.5, Y)
    c.px(cx - 2, 8, R); c.px(cx + 2, 8, R)
    c.line(cx - 1, 12, cx + 1, 12, R)
    if frame == 2: c.px(cx - 1, 13, Y); c.px(cx + 1, 13, Y)
    # arms reaching
    ay = 18 - (frame == 2) * 4
    c.line(cx - 6, 16, cx - 17, ay, Y, 1.6); c.line(cx + 6, 16, cx + 17, ay, Y, 1.6)
    c.px(cx - 18, ay - 1, R); c.px(cx + 18, ay - 1, R)
    c.ellipse(cx, 15, 1.5, 1.2, R)          # a ruby at the throat
    c.outline(R)
    return c, G

PROPER = {'DRACULA'}          # no 'THE' / 'A' before these names
HOME_BBG = {'GHOST': 1, 'GARGOYLE': 1, 'GRELL': 2, 'ZOMBIE': 3, 'SLIME': 3, 'GHOUL KING': 3, 'KNIGHT': 4, 'BAT LORD': 4, 'DRACULA': 5, 'BRIDE': 5}     # gallery backdrop per monster
MONSTERS = [
    # name, fn, hp, atk, def, xp, gold, flags, css
    ('BAT', bat, 9, 5, 0, 4, 3, 2, 0),
    ('SKELETON', skeleton, 20, 7, 2, 9, 7, 1, 0),
    ('GHOST', ghost, 18, 7, 1, 11, 8, 4, 1),
    ('GARGOYLE', gargoyle, 60, 8, 4, 45, 60, 8, 0),
    ('GRELL', grell, 80, 11, 4, 70, 60, 10, 0),
    ('ZOMBIE', zombie, 34, 14, 4, 16, 10, 1, 0),
    ('SLIME', slime, 28, 12, 8, 14, 12, 0, 0),
    ('GHOUL KING', ghoulking, 140, 20, 7, 120, 100, 9, 1),
    ('KNIGHT', knight, 46, 22, 12, 26, 18, 0, 0),
    ('BAT LORD', batlord, 180, 26, 9, 160, 120, 10, 1),
    ('DRACULA', dracula, 255, 34, 12, 255, 255, 9, 0),
    ('BRIDE', bride, 48, 26, 8, 30, 20, 1, 0),
]

def frame_bytes(c, key):
    out = bytearray()
    for y in range(H):
        for xb in range(16):
            v = 0
            for i in range(4):
                p = c.p[y][xb * 4 + i]
                v = (v << 2) | (key if p == T else p)
            out.append(v)
    return bytes(out)

# ----------------------------------------------------------------- BACKDROPS (128 x 46)
def backdrop_grounds():
    c = Canvas(128, 46, B)
    # sky banding near horizon
    for y in range(22, 30):
        for x in range(128): c.p[y][x] = c.pat((B, R, 25) if y > 25 else B, x, y)
    # stars
    import random
    rnd = random.Random(3)
    for _ in range(40):
        x, y = rnd.randrange(128), rnd.randrange(22)
        c.px(x, y, Y)
    # moon
    c.ellipse(104, 9, 8, 7, Y)
    c.ellipse(101, 8, 2, 2, (Y, B, 25)); c.ellipse(107, 11, 1.5, 1.5, (Y, B, 25))
    # castle silhouette far right
    c.rect(96, 18, 127, 30, R)
    for tx, th in ((98, 10), (110, 6), (122, 12)):
        c.rect(tx - 3, th, tx + 3, 30, R)
        c.poly([(tx - 4, th), (tx, th - 6), (tx + 4, th)], R)
    for wx, wy in ((98, 14), (110, 10), (122, 16), (104, 22), (116, 24)): c.px(wx, wy, Y)
    # dead tree left
    c.line(14, 34, 16, 14, R, 2.5); c.line(15, 22, 6, 12, R, 1.5); c.line(16, 18, 26, 9, R, 1.5); c.line(8, 14, 4, 15, R, 1)
    # rolling hill
    for x in range(128):
        top = int(30 + 3 * math.sin(x / 13.0) + 2 * math.sin(x / 5.3))
        for y in range(top, 46):
            c.p[y][x] = c.pat((G, B, 50) if y < top + 2 else ((G, B, 25) if y < 40 else G), x, y)
    # gravestones
    for gx, gy, gw, gh in ((30, 31, 4, 7), (44, 33, 3, 5), (84, 32, 4, 8), (118, 34, 3, 5), (70, 34, 2, 4)):
        c.ellipse(gx, gy, gw, gw * 0.9, (Y, B, 50)); c.rect(gx - gw, gy, gx + gw, gy + gh, (Y, B, 50))
        c.line(gx - gw, gy + gh, gx + gw, gy + gh, B)
    c.line(84, 26, 84, 32, Y); c.line(81, 28, 87, 28, Y)   # cross
    return c

def backdrop_hall():
    c = Canvas(128, 46, B)
    # back wall stone courses
    for y in range(0, 34):
        for x in range(128):
            row = y // 5; off = 6 if row & 1 else 0
            mortar = (y % 5 == 0) or ((x + off) % 12 == 0)
            c.p[y][x] = c.pat((B, R, 25), x, y) if mortar else B
            if (y % 5 == 1) and not ((x + off) % 12 == 0) and (x * 7 + y) % 5 == 0: c.p[y][x] = R
    # arches with dark recesses and red curtains
    for ax in (16, 64, 112):
        c.rect(ax - 11, 6, ax + 11, 34, (R, B, 50))
        c.ellipse(ax, 8, 11, 7, (R, B, 50))
        c.rect(ax - 9, 8, ax + 9, 34, B)
        c.ellipse(ax, 8, 9, 5, B)
        c.poly([(ax - 9, 6), (ax - 3, 6), (ax - 6, 34), (ax - 9, 34)], (R, B, 25))
        c.poly([(ax + 9, 6), (ax + 3, 6), (ax + 6, 34), (ax + 9, 34)], (R, B, 25))
    # candelabra on pillars
    for px_ in (40, 88):
        c.rect(px_ - 1, 14, px_ + 1, 30, (Y, R, 50))
        c.line(px_ - 5, 16, px_ + 5, 16, Y)
        for k in (-5, 0, 5):
            c.rect(px_ + k, 12, px_ + k, 15, Y)
            c.px(px_ + k, 10, R); c.px(px_ + k, 11, Y)
    # floor: chequer receding + carpet
    for y in range(34, 46):
        for x in range(128):
            zz = (y - 33)
            u = (x - 64) / (zz * 1.6 + 6)
            chk = (int(math.floor(u)) + (y - 34) // 3) & 1
            col = (B, R, 25) if chk else B
            if abs(x - 64) < 12 + (y - 34) * 2: col = R if abs(x - 64) < 10 + (y - 34) * 2 else Y
            c.p[y][x] = c.pat(col, x, y)
    c.line(0, 34, 127, 34, Y)
    return c

def backdrop_library():
    c = Canvas(128, 46, B)
    # wall of bookshelves
    for y in range(0, 34):
        for x in range(128):
            row = y // 8; fy = y % 8
            if fy == 0: c.p[y][x] = R; continue
            col = (x + row * 5) // 3
            n = (col * 2654435761 + row * 97) & 0xFFFF
            if (x + row * 5) % 3 == 0 or fy < 1 + (n % 3): c.p[y][x] = B; continue
            c.p[y][x] = (G, Y, R)[n % 3] if (n >> 4) % 7 else B
    for px_ in range(0, 128, 32):
        c.rect(px_, 0, px_ + 1, 33, R)
    # tall window of night sky in the middle
    c.rect(52, 2, 75, 33, B)
    c.ellipse(64, 6, 12, 6, B)
    c.rect(52, 6, 53, 33, Y); c.rect(74, 6, 75, 33, Y); c.rect(63, 4, 64, 33, Y)
    c.line(54, 18, 73, 18, Y)
    for sx, sy in ((57, 9), (69, 12), (60, 24), (71, 27), (56, 30)): c.px(sx, sy, Y)
    # reading tables with candles
    for tx in (22, 106):
        c.rect(tx - 14, 30, tx + 14, 32, R); c.rect(tx - 12, 33, tx - 11, 38, R); c.rect(tx + 11, 33, tx + 12, 38, R)
        c.rect(tx - 2, 26, tx - 1, 29, Y); c.px(tx - 2, 25, R); c.px(tx - 1, 24, Y)
        c.rect(tx + 4, 28, tx + 9, 29, (G, Y, 50))
    # floor: wooden boards + green rug
    for y in range(34, 46):
        for x in range(128):
            zz = y - 33
            col = (R, B, 50) if (x + zz * 3) % 9 else B
            if abs(x - 64) < 16 + (y - 34) * 2: col = G if abs(x - 64) < 14 + (y - 34) * 2 else Y
            c.p[y][x] = c.pat(col, x, y)
    c.line(0, 34, 127, 34, Y)
    return c

def backdrop_dungeon():
    c = Canvas(128, 46, B)
    # rough stone wall
    for y in range(0, 34):
        for x in range(128):
            row = y // 7; off = 5 if row & 1 else 0
            mortar = (y % 7 == 0) or ((x + off) % 14 == 0)
            if mortar: c.p[y][x] = B
            else: c.p[y][x] = c.pat((Y, B, 75), x, y) if (x * 3 + y * 5 + row) % 11 else Y
            if y > 24 and not mortar and (x * 7 + y) % 5 < 2: c.p[y][x] = c.pat((G, B, 50), x, y)
    # three barred cells
    for ax in (20, 64, 108):
        c.rect(ax - 12, 6, ax + 12, 33, B)
        c.ellipse(ax, 7, 12, 5, B)
        for bx in range(ax - 11, ax + 12, 4): c.rect(bx, 4, bx, 33, R)
        c.line(ax - 12, 12, ax + 12, 12, R); c.line(ax - 12, 30, ax + 12, 30, R)
    # a skeleton slumped in the middle cell, chains on the walls
    c.ellipse(64, 24, 2, 2, Y); c.rect(63, 26, 65, 29, Y); c.line(61, 27, 59, 30, Y); c.line(67, 27, 69, 30, Y)
    for chx in (42, 86):
        for k in range(8): c.px(chx + (k & 1), 8 + k * 2, Y); c.px(chx, 9 + k * 2, R)
    # torches
    for tx in (40, 88):
        c.rect(tx, 22, tx + 1, 26, R); c.rect(tx - 1, 19, tx + 2, 21, Y); c.px(tx, 17, Y); c.px(tx + 1, 18, R)
    # wet flagstone floor with puddles
    for y in range(34, 46):
        for x in range(128):
            zz = y - 33
            u = (x - 64) / (zz * 1.4 + 5)
            joint = (y - 34) % 4 == 0 or abs(u - round(u)) < 0.06
            col = B if joint else (Y, B, 75)
            if ((x // 9) * 7 + (y // 3) * 3) % 13 == 0: col = (G, B, 50)
            c.p[y][x] = c.pat(col, x, y)
    c.line(0, 34, 127, 34, (Y, B, 50))
    return c

def backdrop_tower():
    c = Canvas(128, 46, B)
    # timber-framed walls
    for y in range(0, 34):
        for x in range(128):
            col = (Y, B, 75)
            if x % 32 < 3 or y in (0, 1, 18, 19): col = R
            elif abs((x % 32) - 3 - (y - 2) * 0.9) < 1.5 and y < 18: col = R
            c.p[y][x] = c.pat(col, x, y)
    # the great clock face in the middle, gears to either side
    c.ellipse(64, 15, 15, 13, R); c.ellipse(64, 15, 13, 11, Y)
    for k in range(12):
        a = k * math.pi / 6
        c.px(int(64 + 11 * math.sin(a)), int(15 - 9.5 * math.cos(a)), R)
    c.line(64, 15, 64, 7, R, 1.5); c.line(64, 15, 59, 12, R, 1.5)
    for gx, gy, r in ((22, 22, 10), (106, 20, 11), (36, 9, 6), (92, 8, 6)):
        c.ellipse(gx, gy, r, r, Y)
        for k in range(10):
            a = k * math.pi / 5
            c.rect(int(gx + (r + 1) * math.cos(a)) - 1, int(gy + (r + 1) * math.sin(a)) - 1,
                   int(gx + (r + 1) * math.cos(a)), int(gy + (r + 1) * math.sin(a)), Y)
        c.ellipse(gx, gy, r * 0.6, r * 0.6, (Y, R, 50)); c.ellipse(gx, gy, r * 0.25, r * 0.25, R)
    # floorboards
    for y in range(34, 46):
        for x in range(128):
            zz = y - 33
            u = (x - 64) / (zz * 1.5 + 4)
            c.p[y][x] = c.pat(B if abs(u - round(u)) < 0.07 else (R, B, 50), x, y)
    c.line(0, 34, 127, 34, R)
    return c

def backdrop_throne():
    c = Canvas(128, 46, B)
    # black marble wall with red banners
    for y in range(0, 34):
        for x in range(128):
            c.p[y][x] = R if (abs(math.sin(x * 0.21 + y * 0.13 + math.sin(y * 0.3) * 2)) < 0.05) else B
    for bx in (12, 36, 92, 116):
        c.rect(bx - 6, 0, bx + 6, 26, R)
        c.poly([(bx - 6, 26), (bx + 6, 26), (bx, 31)], R)
        c.rect(bx - 6, 0, bx + 6, 1, Y)
        c.ellipse(bx, 12, 3, 3, Y); c.ellipse(bx, 12, 1.5, 1.5, R)       # dragon sigil
    # great window with the blood moon
    c.rect(52, 2, 75, 30, (R, B, 25)); c.ellipse(64, 4, 12, 6, (R, B, 25))
    c.ellipse(64, 14, 7, 7, R); c.ellipse(66, 12, 2, 2, (R, Y, 25))
    c.rect(52, 4, 53, 30, Y); c.rect(74, 4, 75, 30, Y); c.rect(63, 3, 64, 30, Y); c.line(54, 20, 73, 20, Y)
    # the throne
    c.rect(56, 22, 71, 33, R); c.rect(58, 24, 69, 30, B); c.rect(54, 30, 73, 33, Y)
    c.px(56, 21, Y); c.px(71, 21, Y)
    # floor: red carpet up the middle, checker either side
    for y in range(34, 46):
        for x in range(128):
            zz = y - 33
            u = (x - 64) / (zz * 1.6 + 6)
            chk = (int(math.floor(u)) + (y - 34) // 3) & 1
            col = (R, B, 50) if chk else B
            if abs(x - 64) < 9 + (y - 34) * 2: col = R if abs(x - 64) < 7 + (y - 34) * 2 else Y
            c.p[y][x] = c.pat(col, x, y)
    c.line(0, 34, 127, 34, Y)
    return c

def backdrop_bytes(c):
    out = bytearray()
    for y in range(46):
        for xb in range(32):
            v = 0
            for i in range(4): v = (v << 2) | (c.p[y][xb * 4 + i] & 3)
            out.append(v)
    return bytes(out)

if __name__ == '__main__':
    from gfx import PAL
    sheet = Image.new('RGB', (64 * 3 * 4 + 16, 44 * 6 * 4 + 32), (40, 40, 40))
    for mi, (name, fn, *_rest) in enumerate(MONSTERS):
        css = _rest[-1]
        for f in range(3):
            c, key = fn(f)
            im = Image.new('RGB', (64, 44), (30, 30, 30))
            for y in range(44):
                for x in range(64):
                    p = c.p[y][x]
                    if p != T: im.putpixel((x, y), PAL[css * 4 + p])
            sheet.paste(im.resize((256, 44 * 6), Image.NEAREST), (f * 260, mi * (44 * 6 + 8)))
    sheet.save('/home/claude/dc2/shots/monsters.png')
    for nm, fn in (('grounds', backdrop_grounds), ('hall', backdrop_hall)):
        c = fn()
        for css in (0, 1):
            im = Image.new('RGB', (128, 46))
            for y in range(46):
                for x in range(128): im.putpixel((x, y), PAL[css * 4 + c.p[y][x]])
            im.resize((512, 46 * 6), Image.NEAREST).save('/home/claude/dc2/shots/bd_%s_%d.png' % (nm, css))
