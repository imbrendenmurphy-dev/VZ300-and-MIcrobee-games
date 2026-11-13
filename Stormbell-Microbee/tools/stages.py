"""STORMBELL scrolling stages (VIBED BY BPM 2026).

Each stage is a run along a mountain road, in three layers, the way
Tiger Gate layers its scenery:

  rows 1..7    the far layer: sky, sun or moon, mountains, distant roofs.
               Scrolls at a quarter of the run speed, a cell at a time.
  rows 8..15   the midground: walls, railings, gates, trees, the bell
               frame. Scrolls with the run, a cell at a time.
  rows 16..23  the floor: eight strips, one per cell row, each a
               pattern that repeats every k cells. The game rewrites the
               strips' glyphs every frame, so the floor slides smoothly,
               the near rows faster than the far ones (perspective).

Row 0 and row 24 belong to the HUD.

A stage's world is MIDW cells wide (the camera goes 0..END_C). The duel
is fought with the camera at DUEL_C; the arena's centrepiece stands at
x = (DUEL_C + 20) * 8 in the midground canvas.
"""
import math
import numpy as np
import art
from art import (Pic, BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW,
                 BBLUE, BMAGENTA, BCYAN, WHITE, TOP, sky, sun, mountains, cloud, roof, lantern, blossom_tree,
                 pine, bushes, bell)

MIDW = 112                   # midground width in cells
END_C = MIDW - 40            # the camera's last position
DUEL_C = 36                  # the camera during the duel
FARW = 40 + END_C // 4 + 1   # far layer width in cells
CX = (DUEL_C + 20) * 8       # the arena centre in the midground canvas
FY0, FY1 = 8, 64             # far rows 1..7
MY0, MY1 = 64, 128           # midground rows 8..15
FLOOR_ROWS = 8
T = 48                       # floor tile width (pixels) at the fighters' feet
KS = [4, 4, 5, 5, 6, 6, 7, 7]   # cells per strip, rows 16..23 (perspective)
NAMES = ['THE OUTER GATE', 'THE RIVER BRIDGE', 'THE CLIFF PATH', 'THE DOJO HALL', 'THE BELL TOWER']


def far_pic():
    return Pic(BLACK, FARW * 8)


def mid_pic():
    return Pic(BLACK, MIDW * 8)


def base_fill(p, c0, c1, level, y0=MY0, y1=MY1):
    p.dither(p.rect(0, y0, p.W, y1), c0, c1, level)


def floor_bottom(p, y=56):
    """the far layer's mountains fill solidly below y, so the midground can
    carry on with the same dither and no seam shows where they meet"""
    return p.rect(0, y, p.W, FY1)


# ---------------------------------------------------------------------
#  floors: a texture function of (x, y) within one strip of P pixels
# ---------------------------------------------------------------------
class Floor:
    def __init__(self, ink, paper, seams, kind, rows_ink=None, rows_paper=None, speck=2, seed=1):
        self.ink, self.paper = ink, paper
        self.seams = seams          # screen y of the tile rows' front edges
        self.kind = kind
        self.rows_ink = rows_ink or [ink] * FLOOR_ROWS
        self.rows_paper = rows_paper or [paper] * FLOOR_ROWS
        self.speck = speck
        self.seed = seed

    def strip(self, r):
        """-> 8 x P bool for cell row 16 + r"""
        k = KS[r]
        P = k * 8
        y0 = 128 + r * 8
        out = np.zeros((8, P), bool)
        rnd = np.random.RandomState(self.seed * 31 + r)
        noise = rnd.rand(8, P)
        for ly in range(8):
            y = y0 + ly
            # which tile row (depth band) this line is in
            band = sum(1 for s in self.seams if y >= s)
            on_seam = y in self.seams
            for x in range(P):
                v = False
                if self.kind == 'flags':
                    stag = (P // 2) if band % 2 else 0
                    v = on_seam or ((x + stag) % P == 0) or noise[ly, x] < self.speck / 64
                elif self.kind == 'planks':
                    # boards across the path; joints staggered board by board
                    stag = (band * P * 3 // 8) % P
                    v = on_seam or (((x + stag) % P) == 0) or (noise[ly, x] < self.speck / 64 and ly % 3 == 1)
                elif self.kind == 'boards':
                    # polished boards running towards you: close joints
                    v = (x % (P // 2) == 0) or (on_seam and x % 2 == 0) or noise[ly, x] < self.speck / 64
                elif self.kind == 'rock':
                    stag = (P * band * 5 // 11) % P
                    crack = ((x + stag) % P) in (0, 1) and (ly + band) % 3 != 0
                    v = crack or noise[ly, x] < self.speck / 64 or (on_seam and noise[ly, x] < 0.6)
                out[ly, x] = v
        return out


def stage_floor(i):
    if i == 0:   # the outer gate: grey stone flags
        return Floor(GREY, DGREY, [128, 133, 139, 146, 154, 163, 173, 184], 'flags', speck=3, seed=1,
                     rows_ink=[GREY] * 5 + [WHITE] * 3)
    if i == 1:   # the river bridge: wooden planks
        return Floor(YELLOW, BROWN, [128, 131, 135, 139, 144, 149, 155, 161, 168, 175, 183], 'planks', speck=6, seed=2)
    if i == 2:   # the cliff path: rock
        return Floor(GREY, DGREY, [128, 134, 141, 149, 158, 168, 179], 'rock', speck=9, seed=3,
                     rows_ink=[GREY] * 4 + [WHITE] * 4)
    if i == 3:   # the dojo hall: polished boards
        return Floor(YELLOW, BROWN, [128, 140, 156, 176], 'boards', speck=4, seed=4)
    return Floor(GREY, DGREY, [128, 132, 137, 143, 150, 158, 167, 177, 188], 'flags', speck=4, seed=5,
                 rows_ink=[BBLUE] * 3 + [GREY] * 5)


# ---------------------------------------------------------------------
#  stage 1: THE OUTER GATE - dusk, a temple court wall, the gate
# ---------------------------------------------------------------------
def gate_small(p, cx, base, w=96, h=40, col=BRED, roofc=YELLOW):
    pw = 8
    for sx in (-1, 1):
        x0 = cx - w / 2 if sx < 0 else cx + w / 2 - pw
        p.fill(p.rect(x0, base - h, x0 + pw, base), col)
        p.dither(p.rect(x0 + pw - 3, base - h, x0 + pw, base), col, RED, 10)
        p.fill(p.rect(x0 - 2, base - 4, x0 + pw + 2, base), GREY)
    door = p.rect(cx - w / 2 + pw, base - h + 8, cx + w / 2 - pw, base)
    p.fill(door, BLACK)
    p.dither(door & (p.y < base - h + 18), BLACK, RED, 4)
    p.fill(p.rect(cx - w / 2 - 6, base - h, cx + w / 2 + 6, base - h + 6), col)
    p.fill(p.rect(cx - w / 2 - 6, base - h + 6, cx + w / 2 + 6, base - h + 8), BROWN)
    p.fill(p.rect(cx - 14, base - h + 9, cx + 14, base - h + 15), YELLOW)
    p.fill(p.rect(cx - 12, base - h + 11, cx + 12, base - h + 13) & ((p.x % 3) == 0), BROWN)
    roof(p, cx, base - h - 1, w + 40, 16, roofc, BROWN)


def stage0():
    f = far_pic()
    sky(f, BLUE, MAGENTA, FY1, 3, 30)
    sun(f, 300, 34, 15)
    mountains(f, 54, 12, 5, BLUE, MAGENTA, snow=True, peaks=[(150, 22, 46), (330, 26, 52), (430, 30, 40)])
    f.dither(floor_bottom(f), BLUE, MAGENTA, 6)
    m = mid_pic()
    base_fill(m, BLUE, MAGENTA, 6)
    # the court wall: tiled coping, dithered plaster
    wall = m.rect(0, 80, m.W, MY1)
    m.dither(wall, RED, MAGENTA, 6)
    m.dither(wall & ((m.y % 8) == 0), RED, MAGENTA, 2)
    m.fill(m.rect(0, 74, m.W, 80), WHITE)
    m.dither(m.rect(0, 77, m.W, 80), WHITE, GREY, 8)
    m.fill(m.rect(0, 72, m.W, 74) & ((m.x % 6) < 4), GREY)
    for x in (40, 312, 660, 860):
        blossom_tree(m, x, 126, 0.52)
    bushes(m, 126, [(150, 16), (232, 12), (560, 14), (760, 18)])
    for x in (96, 232, 360, 536, 664, 800):
        lantern(m, x, 128, 0.85)
    gate_small(m, 200 - 96, 128, 72, 34)
    gate_small(m, CX, 128, 104, 42)
    return f, m


# ---------------------------------------------------------------------
#  stage 2: THE RIVER BRIDGE - night, waterfalls, a red railing
# ---------------------------------------------------------------------
def moon(p, cx, cy, r):
    m = p.disc(cx, cy, r) & ~p.disc(cx + r * 0.45, cy - r * 0.2, r * 0.85)
    p.fill(m, YELLOW)


def pagoda(p, cx, base, tiers=3, w=26):
    for t in range(tiers):
        y = base - t * 9
        ww = w - t * 6
        p.fill(p.rect(cx - ww / 2 + 3, y - 6, cx + ww / 2 - 3, y), BRED)
        roof(p, cx, y - 6, ww + 6, 5, YELLOW, BROWN)


def waterfall(p, x0, x1, y0, y1):
    m = p.rect(x0, y0, x1, y1)
    p.dither(m, BCYAN, WHITE, 6)
    p.fill(m & (((p.x * 3 + p.y // 3) % 7) == 0), WHITE)
    p.fill(m & (((p.x * 5 + p.y // 2) % 11) == 3), BLUE)
    foam = p.disc((x0 + x1) / 2, y1, (x1 - x0) * 0.8, 5) & (p.y <= y1 + 2)
    p.dither(foam, WHITE, BCYAN, 4)


def stage1():
    f = far_pic()
    sky(f, BLACK, BLUE, FY1, 7, 40)
    moon(f, 330, 26, 11)
    for x, y, w in ((70, 26, 60), (230, 18, 46), (420, 30, 52)):
        cloud(f, x, y, w, WHITE, GREY)
    h = mountains(f, 52, 12, 9, BLUE, BBLUE, snow=True, peaks=[(250, 24, 40), (90, 32, 44)])
    pagoda(f, 250, 26, 3, 26)
    f.dither(floor_bottom(f), BLUE, BBLUE, 6)
    m = mid_pic()
    base_fill(m, BLUE, BBLUE, 6)
    # dark forest on the far bank
    trees = m.rect(0, 70, m.W, 96) & (m.y >= 74 + 4 * np.sin(m.x / 9.0) + 2 * np.sin(m.x / 3.3))
    m.dither(trees, BLACK, GREEN, 7)
    # cliffs with waterfalls
    for cx, w in ((140, 70), (600, 90)):
        cl = m.poly([(cx - w, MY1), (cx - w + 12, 72), (cx - 10, 66), (cx + w - 20, 70), (cx + w, MY1)])
        m.dither(cl, DGREY, GREY, 7)
        m.dither(cl & (m.x < cx - w + 30), DGREY, GREY, 11)
        waterfall(m, cx - 12, cx + 14, 70, 106)
    # the river
    river = m.rect(0, 100, m.W, MY1)
    m.dither(river, BLUE, BBLUE, 6)
    m.fill(river & (((m.x + 3 * m.y) % 13) < 2) & ((m.y % 4) == 0), BCYAN)
    # the red railing
    m.fill(m.rect(0, 104, m.W, 108), BRED)
    m.fill(m.rect(0, 108, m.W, 109), RED)
    m.fill(m.rect(0, 117, m.W, 120), BRED)
    for x in range(24, m.W, 80):
        m.fill(m.rect(x - 4, 100, x + 4, MY1), BRED)
        m.dither(m.rect(x + 1, 100, x + 4, MY1), BRED, RED, 10)
        m.fill(m.disc(x, 99, 6, 5), YELLOW)
        m.dither(m.disc(x, 99, 6, 5) & (m.x > x + 1), YELLOW, BROWN, 8)
    return f, m


# ---------------------------------------------------------------------
#  stage 3: THE CLIFF PATH - sunset, rock faces, pines, a torii
# ---------------------------------------------------------------------
def torii(p, cx, base, w=96, h=50, col=BRED):
    for sx in (-1, 1):
        x = cx + sx * (w / 2 - 12)
        p.fill(p.rect(x - 4, base - h + 8, x + 4, base), col)
        p.fill(p.rect(x - 6, base - 4, x + 6, base), BLACK)
    p.fill(p.rect(cx - w / 2, base - h + 14, cx + w / 2, base - h + 18), col)
    top = p.poly([(cx - w / 2 - 10, base - h), (cx + w / 2 + 10, base - h), (cx + w / 2 + 4, base - h + 7), (cx - w / 2 - 4, base - h + 7)])
    p.fill(top, col)
    p.fill(p.rect(cx - w / 2 - 10, base - h - 2, cx + w / 2 + 10, base - h), BLACK)
    p.fill(p.rect(cx - 5, base - h + 7, cx + 5, base - h + 14), YELLOW)


def stage2():
    f = far_pic()
    sky(f, BLUE, MAGENTA, FY1, 11, 18)
    sun(f, 280, 36, 16)
    mountains(f, 52, 14, 13, BLUE, MAGENTA, peaks=[(120, 24, 40), (400, 28, 48)])
    pagoda(f, 120, 26, 2, 22)
    f.dither(floor_bottom(f), BLUE, MAGENTA, 6)
    m = mid_pic()
    base_fill(m, BLUE, MAGENTA, 6)
    # rock faces along the path's back edge
    r = np.random.RandomState(4)
    xs = np.arange(m.W)
    h = 84 + 10 * np.sin(xs / 23.0) + 6 * np.sin(xs / 9.0 + 1) + 3 * np.sin(xs / 4.0)
    rock = m.y >= h[m.x]
    m.dither(rock, DGREY, GREY, 7)
    lit = np.gradient(h) < 0
    m.dither(rock & lit[m.x], DGREY, GREY, 11)
    m.fill(rock & (m.y < h[m.x] + 1.5), WHITE)
    for k in range(40):
        x, y = r.randint(0, m.W), r.randint(90, MY1)
        if rock[y, x]:
            m.fill(m.line(x, y, x + r.randint(-6, 7), y + r.randint(3, 9), 1.0) & rock, BLACK)
    for x in (120, 330, 690, 840):
        pine(m, x, 124, 0.62)
    bushes(m, 126, [(60, 18), (250, 14), (520, 16), (760, 20)])
    torii(m, CX, 128, 104, 52)
    return f, m


# ---------------------------------------------------------------------
#  stage 4: THE DOJO HALL - beams overhead, shoji, a round window
# ---------------------------------------------------------------------
def stage3():
    f = far_pic()
    f.fill(f.rect(0, FY0, f.W, FY1), BLACK)
    # the roof's underside: rafters and two great beams, lanterns hanging
    f.dither(f.rect(0, FY0, f.W, FY1), BLACK, BROWN, 5)
    for x in range(0, f.W, 24):
        f.fill(f.rect(x, FY0, x + 4, FY1), BROWN)
    for y0 in (12, 44):
        f.fill(f.rect(0, y0, f.W, y0 + 7), BROWN)
        f.dither(f.rect(0, y0, f.W, y0 + 3), BROWN, YELLOW, 8)
    for x in range(36, f.W, 96):
        f.fill(f.rect(x, 19, x + 1, 30), YELLOW)
        lamp = f.disc(x, 37, 6, 7)
        f.fill(lamp, BRED)
        f.dither(lamp & (f.x < x - 1), BRED, YELLOW, 8)
        f.fill(f.rect(x - 5, 29, x + 6, 31) | f.rect(x - 5, 43, x + 6, 45), BLACK)
    f.dither(floor_bottom(f, 58), BLACK, BROWN, 5)
    m = mid_pic()
    m.dither(m.rect(0, MY0, m.W, MY1), BLACK, BROWN, 5)
    # the lintel
    m.fill(m.rect(0, 66, m.W, 72), BROWN)
    m.dither(m.rect(0, 66, m.W, 68), BROWN, YELLOW, 10)
    # bays between pillars: shoji screens
    for x0 in range(0, m.W, 96):
        bay = m.rect(x0 + 10, 74, x0 + 86, 122)
        m.dither(bay, GREY, WHITE, 12)
        m.fill(bay & ((((m.x - x0 - 10) % 12) == 0) | (((m.y - 74) % 12) == 0)), BROWN)
        m.fill(m.rect(x0, 66, x0 + 10, MY1), BROWN)
        m.dither(m.rect(x0 + 6, 66, x0 + 10, MY1), BROWN, YELLOW, 6)
    # the round window over the arena: mountains at dusk
    win = m.disc(CX, 96, 28, 24)
    m.fill(m.disc(CX, 96, 32, 28), BROWN)
    m.grad(win, BLUE, MAGENTA, 74, 112, 0, 12)
    mt = win & (m.y > 104 - 12 * np.exp(-((m.x - CX + 8) / 10.0) ** 2) - 6 * np.exp(-((m.x - CX - 14) / 8.0) ** 2))
    m.dither(mt, BLUE, BMAGENTA, 8)
    m.fill(win & ((((m.x - CX) % 14) == 0) | (((m.y - 96) % 12) == 0)), BROWN)
    # scrolls with the bell crest, and candles
    for x in (CX - 96, CX + 96, 120, 780):
        sc = m.rect(x - 10, 76, x + 10, 112)
        m.fill(m.rect(x - 10, 76, x + 10, 112), WHITE)
        m.fill(m.rect(x - 12, 74, x + 12, 77) | m.rect(x - 12, 111, x + 12, 114), BROWN)
        bl = bell(m, x, 82, 0.42, BRED, RED)
    for x in (CX - 60, CX + 60, 60, 300, 640, 860):
        m.fill(m.rect(x - 2, 112, x + 2, 126), YELLOW)
        m.fill(m.rect(x - 5, 124, x + 5, 128), BROWN)
        m.fill(m.rect(x - 1, 106, x + 1, 112), WHITE)
        m.fill(m.disc(x, 104, 1.6, 3), YELLOW)
    m.fill(m.rect(0, 122, m.W, MY1), BLACK)
    m.dither(m.rect(0, 122, m.W, 124), BROWN, YELLOW, 4)
    return f, m


# ---------------------------------------------------------------------
#  stage 5: THE BELL TOWER - a storm, the parapet, the bell
# ---------------------------------------------------------------------
def bolt(p, pts, col=WHITE):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        p.fill(p.line(x0, y0, x1, y1, 1.6), col)


def stage4():
    f = far_pic()
    f.fill(f.rect(0, FY0, f.W, FY1), BLACK)
    for cx, cy, rx in ((40, 18, 60), (170, 24, 70), (300, 16, 64), (430, 26, 60)):
        c = f.disc(cx, cy, rx, 9) | f.disc(cx + rx * 0.4, cy + 6, rx * 0.7, 7)
        f.dither(c, BLACK, BBLUE, 7)
        f.dither(c & (f.y < cy - 3), BLACK, BBLUE, 11)
    bolt(f, [(110, 22), (100, 34), (112, 37), (98, 56)])
    bolt(f, [(352, 26), (362, 38), (350, 42), (360, 58)])
    mountains(f, 54, 10, 21, BLACK, BLUE, peaks=[(200, 34, 50)])
    f.dither(floor_bottom(f), BLACK, BLUE, 6)
    m = mid_pic()
    base_fill(m, BLACK, BLUE, 6)
    # the parapet: merlons and a stone wall
    wall = m.rect(0, 100, m.W, MY1)
    m.dither(wall, DGREY, GREY, 9)
    m.fill(wall & (((m.y - 100) % 8) == 0), DGREY)
    m.fill(wall & ((((m.x + ((m.y - 100) // 8) * 8) % 16) == 0)), DGREY)
    for x in range(0, m.W, 32):
        mer = m.rect(x + 4, 88, x + 20, 100)
        m.dither(mer, DGREY, GREY, 10)
        m.fill(m.rect(x + 4, 88, x + 20, 89), WHITE)
    m.fill(m.rect(0, 99, m.W, 100), WHITE)
    # the bell frame over the arena
    for sx in (-1, 1):
        x = CX + sx * 64
        m.fill(m.rect(x - 5, 68, x + 5, MY1), BRED)
        m.dither(m.rect(x + 1, 68, x + 5, MY1), BRED, RED, 10)
    m.fill(m.rect(CX - 80, 64, CX + 80, 70), BRED)
    m.fill(m.rect(CX - 80, 70, CX + 80, 72), RED)
    m.fill(m.rect(CX - 1, 72, CX + 1, 76), YELLOW)
    bell(m, CX, 74, 0.95, YELLOW, BROWN)
    # torches on the merlons
    for x in (60, 252, 700, 860):
        m.fill(m.rect(x - 1, 78, x + 2, 90), BROWN)
        m.fill(m.disc(x, 75, 3, 5), YELLOW)
        m.fill(m.disc(x, 77, 2, 2.5), BRED)
    return f, m


STAGES = [stage0, stage1, stage2, stage3, stage4]


def preview(path):
    """the five stages at the duel camera, floor at phase 0 (for the eye)"""
    from PIL import Image
    pal = np.array(art.PAL, np.uint8)
    ims = []
    for i, fn in enumerate(STAGES):
        f, m = fn()
        fi, fc, fp = f.cells()
        mi, mc, mp = m.cells()
        img = np.zeros((200, 320, 3), np.uint8)
        fo, mo = DUEL_C // 4, DUEL_C
        def put(ink, ci, cp, r0, r1, off):
            for r in range(r0, r1):
                for c in range(40):
                    sub = ink[r * 8:r * 8 + 8, (off + c) * 8:(off + c) * 8 + 8]
                    img[r * 8:r * 8 + 8, c * 8:c * 8 + 8] = np.where(sub[:, :, None], pal[ci[r, off + c]], pal[cp[r, off + c]])
        put(fi, fc, fp, 1, 8, fo)
        put(mi, mc, mp, 8, 16, mo)
        fl = stage_floor(i)
        for r in range(FLOOR_ROWS):
            s = fl.strip(r)
            P = s.shape[1]
            for x in range(320):
                img[128 + r * 8:136 + r * 8, x] = np.where(s[:, x % P][:, None], pal[fl.rows_ink[r]], pal[fl.rows_paper[r]])
        ims.append(img)
    sheet = np.concatenate([np.concatenate(ims[:2], 1), np.concatenate(ims[2:4], 1), np.concatenate([ims[4], np.zeros_like(ims[4])], 1)], 0)
    Image.fromarray(sheet).resize((int(640 * 1.25 * 1.5), 600 * 3 // 2), Image.NEAREST).save(path)


if __name__ == '__main__':
    import sys
    preview(sys.argv[1])
