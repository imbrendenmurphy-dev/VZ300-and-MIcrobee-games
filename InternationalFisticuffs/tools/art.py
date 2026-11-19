#!/usr/bin/env python3
"""RED DUST RUMBLE art generator.

Fighters are posed skeletons drawn as thick capsules, so every frame keeps the
same proportions.  Units: 1 unit = 1 pixel wide; a mode 1 row is 1.5 units
tall on a 4:3 screen, so rows = units / 1.5.

Colours in the frames: 0 = see-through, 1 = yellow, 2 = body.  Body colour 2
is blue; player 2's copy is turned red (3) by a table when drawn.

Outputs (in the directory given):
  fighters.asm   frame headers + unshifted 2bpp frame data for both fighters
  backdrop.asm   the Showground Tent arena, 64 rows x 32 bytes
  font.asm       3x5 font, one nibble-row per byte
and preview PNGs in ../screenshots/art_*.png
"""
import sys, os, math
from PIL import Image

ASPECT = 1.5
CANVAS_W, CANVAS_H = 96, 48          # pixels, rows (working canvas)
OX, OY = 48, 44                      # feet origin on the canvas (row 44 = ground row)

# ------------------------------------------------------------------ geometry
def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0 if l2 == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / l2))
    qx, qy = ax + t * dx, ay + t * dy
    return math.hypot(px - qx, py - qy)

def ang(deg, length):
    """vector for a bone: 0 deg = straight down, +90 = forward (+x), 180 = up"""
    r = math.radians(deg)
    return (math.sin(r) * length, -math.cos(r) * length)

class Canvas:
    def __init__(self):
        self.px = [[0] * CANVAS_W for _ in range(CANVAS_H)]
        self.part = [[-1] * CANVAS_W for _ in range(CANVAS_H)]
        self.nparts = 0

    def shape(self, inside, colour, carve=True):
        """stamp a shape; carve a 1px see-through gap where it crosses a
        different earlier part of the same colour"""
        pid = self.nparts
        self.nparts += 1
        cells = set()
        for r in range(CANVAS_H):
            for c in range(CANVAS_W):
                x = c + 0.5 - OX
                y = (OY - r + 0.5) * ASPECT      # units above the ground line
                if inside(x, y):
                    cells.add((r, c))
        if carve:
            for (r, c) in cells:
                for dr, dc in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    rr, cc = r + dr, c + dc
                    if (rr, cc) in cells or not (0 <= rr < CANVAS_H and 0 <= cc < CANVAS_W):
                        continue
                    if self.px[rr][cc] == colour and self.part[rr][cc] >= 0:
                        self.px[rr][cc] = 0
                        self.part[rr][cc] = -1
        for (r, c) in cells:
            self.px[r][c] = colour
            self.part[r][c] = pid

    def capsule(self, a, b, rad, colour, carve=True):
        self.shape(lambda x, y: seg_dist(x, y, a[0], a[1], b[0], b[1]) < rad, colour, carve)

    def ellipse(self, cx, cy, rx, ry, colour, carve=True):
        self.shape(lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1, colour, carve)

    def poly(self, pts, colour, carve=True):
        def inside(x, y):
            n, ins = len(pts), False
            for i in range(n):
                x1, y1 = pts[i]; x2, y2 = pts[(i + 1) % n]
                if (y1 > y) != (y2 > y):
                    if x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
                        ins = not ins
            return ins
        self.shape(inside, colour, carve)

# ------------------------------------------------------------------ fighters
Y, B = 1, 2

FLICK = dict(name='FLICK', thigh=9.5, shin=10, torso=14, neck=2.5, head=4.6,
             uarm=8, farm=8, leg_r=2.7, arm_r=2.5, torso_r=6.2, fist_r=3.1,
             stance=5)
DUSTY = dict(name='DUSTY', thigh=12, shin=12.5, torso=16.5, neck=2.5, head=4.0,
             uarm=9.5, farm=9.5, leg_r=2.2, arm_r=2.1, torso_r=5.0, fist_r=2.3,
             stance=6)

def pose_base(**kw):
    p = dict(lean=0, hipdy=0, lf=(10, 0), lb=(-10, 0), af=(30, 100), ab=(20, 90),
             air=False, lift=0, head_dy=0, extra=None, lie=False)
    p.update(kw)
    return p

def solve(f, p):
    """joint positions for pose p of fighter f (units, feet origin, +y up)"""
    # legs from a hip at (0,0) first, then shift so the lowest foot is on the ground
    def leg(a):
        th, sh = a
        k = ang(th, f['thigh'])
        fo = ang(sh, f['shin'])
        return (k, (k[0] + fo[0], k[1] + fo[1]))
    kf, ff = leg(p['lf'])
    kb, fb = leg(p['lb'])
    low = min(ff[1], fb[1])
    hip = (0.0, -low + p['lift'])
    if p['air']:
        hip = (0.0, -low + p['lift'])
    add = lambda a, b: (a[0] + b[0], a[1] + b[1])
    J = {}
    J['hip'] = hip
    J['kf'], J['ff'] = add(hip, kf), add(hip, ff)
    J['kb'], J['fb'] = add(hip, kb), add(hip, fb)
    t = ang(180 - p['lean'], f['torso'])  # lean + = forward
    J['neck'] = add(hip, t)
    sh = add(hip, ang(180 - p['lean'], f['torso'] - 2))
    J['sh'] = sh
    hd = ang(180 - p['lean'] * 0.7, f['neck'] + f['head'])
    J['head'] = add(J['neck'], (hd[0], hd[1] + p['head_dy']))
    def arm(a):
        u, fo = a
        e = add(sh, ang(u, f['uarm']))
        h = add(e, ang(fo, f['farm']))
        return e, h
    J['ef'], J['hf'] = arm(p['af'])
    J['eb'], J['hb'] = arm(p['ab'])
    return J

def boot(cv, f, knee, foot, colour, carve=True):
    # a short foot pointing forward (+x)
    cv.capsule(foot, (foot[0] + 3.2, foot[1] - 0.2), 1.9, colour, carve)

def draw_flick(cv, f, J, p):
    # back arm, back leg, torso (singlet), front leg, head, front arm
    cv.capsule(J['sh'], J['eb'], f['arm_r'], Y, False)
    cv.capsule(J['eb'], J['hb'], f['arm_r'] - 0.2, Y)
    cv.ellipse(J['hb'][0], J['hb'][1], f['fist_r'], f['fist_r'], Y)
    cv.capsule(J['hip'], J['kb'], f['leg_r'] + 0.4, B)
    cv.capsule(J['kb'], J['fb'], f['leg_r'], B)
    boot(cv, f, J['kb'], J['fb'], Y)
    # torso: singlet from hip to chest, broad
    cv.capsule(J['hip'], (J['neck'][0] * 0.9, J['neck'][1] - 3), f['torso_r'], B)
    cv.capsule(J['hip'], J['kf'], f['leg_r'] + 0.4, B)
    cv.capsule(J['kf'], J['ff'], f['leg_r'], B)
    boot(cv, f, J['kf'], J['ff'], Y)
    # belt
    hx, hy = J['hip']
    cv.capsule((hx - 4.5, hy + 1.2), (hx + 4.5, hy + 1.2), 0.8, Y, False)
    # head: skin with a blue hair cap and a yellow neck
    cv.capsule(J['neck'], J['head'], 2.2, Y, False)
    hx, hy = J['head']
    cv.ellipse(hx, hy, f['head'], f['head'] * 1.05, Y)
    cv.shape(lambda x, y: ((x - hx) / (f['head'] + 0.6)) ** 2 + ((y - hy - 1.4) / (f['head'] * 0.8)) ** 2 < 1
             and (y > hy + 1.5 or x < hx - 1.0), B, False)
    # front arm last (bare, yellow)
    cv.capsule(J['sh'], J['ef'], f['arm_r'], Y)
    cv.capsule(J['ef'], J['hf'], f['arm_r'] - 0.2, Y)
    cv.ellipse(J['hf'][0], J['hf'][1], f['fist_r'], f['fist_r'], Y)

def draw_dusty(cv, f, J, p):
    # back arm (coat sleeve), back leg, coat, front leg, head + hat, front arm
    cv.capsule(J['sh'], J['eb'], f['arm_r'], B, False)
    cv.capsule(J['eb'], J['hb'], f['arm_r'], B)
    cv.ellipse(J['hb'][0], J['hb'][1], f['fist_r'], f['fist_r'], Y)
    cv.capsule(J['hip'], J['kb'], f['leg_r'], B)
    cv.capsule(J['kb'], J['fb'], f['leg_r'], B)
    boot(cv, f, J['kb'], J['fb'], Y)
    cv.capsule(J['hip'], J['kf'], f['leg_r'], B)
    cv.capsule(J['kf'], J['ff'], f['leg_r'], B)
    boot(cv, f, J['kf'], J['ff'], Y)
    # drover's coat: torso plus tails flaring to the knees
    hx, hy = J['hip']
    nx, ny = J['neck']
    kfx, kfy = J['kf']; kbx, kby = J['kb']
    tail_y = min(kfy, kby) + 2.5
    lean = p['lean']
    sway = -2.0 if not p['lie'] else 0
    if not p['lie']:
        cv.poly([(nx - 4.2, ny - 1.5), (nx + 4.2, ny - 1.5),
                 (max(hx + 5.5, kfx + 1.5), tail_y), (min(hx - 6.5, kbx - 2.5) + sway, tail_y + 1.0)], B)
    cv.capsule(J['hip'], (nx, ny - 2), f['torso_r'], B, False)
    # head, then the hat
    cv.capsule(J['neck'], J['head'], 1.8, Y, False)
    qx, qy = J['head']
    cv.ellipse(qx, qy, f['head'] * 0.95, f['head'] * 1.1, Y)
    tilt = -p['lean'] * 0.03
    cv.ellipse(qx + 0.5, qy + 2.6, 8.5, 1.6, B, False)               # brim
    cv.ellipse(qx, qy + 4.8, 4.2, 3.0, B, False)                     # crown
    cv.capsule((qx - 4.0, qy + 3.4), (qx + 4.0, qy + 3.4), 0.6, Y, False)  # hat band
    # front arm in the coat sleeve
    cv.capsule(J['sh'], J['ef'], f['arm_r'], B)
    cv.capsule(J['ef'], J['hf'], f['arm_r'], B)
    cv.ellipse(J['hf'][0], J['hf'][1], f['fist_r'], f['fist_r'], Y)
    if p['extra'] == 'whip_coil':
        # coiled whip hanging from the front hand
        h = J['hf']
        cv.ellipse(h[0] - 1.0, h[1] - 4.5, 3.0, 3.5, Y, False)
        cv.ellipse(h[0] - 1.0, h[1] - 4.5, 1.6, 2.0, 0, False)
    if p['extra'] == 'whip_up':
        h = J['hf']
        cv.capsule(h, (h[0] - 9, h[1] + 9), 0.7, Y, False)
        cv.capsule((h[0] - 9, h[1] + 9), (h[0] - 15, h[1] + 5), 0.7, Y, False)

def draw_extra_flick(cv, f, J, p):
    if p['extra'] == 'speed':
        hx, hy = J['hip']
        for dy, l in ((8, 10), (14, 14), (20, 9)):
            cv.capsule((hx - 9 - l, hy + dy - 8), (hx - 9, hy + dy - 8), 0.5, Y, False)

# pose tables: (frame id, name, pose)  -- shared frame numbering for both fighters
FRAME_NAMES = ['IDLE', 'WALK1', 'WALK2', 'CROUCH', 'JUMP', 'BLOCK', 'CBLOCK',
               'SA_W', 'SA_S', 'SB_W', 'SB_S', 'CA_S', 'CB_S', 'JA', 'JB',
               'HIT', 'DOWN', 'SP1_W', 'SP1_S', 'SP2_W', 'SP2_S', 'WIN']

def flick_poses():
    P = {}
    guard = dict(af=(40, 150), ab=(25, 140))
    P['IDLE'] = pose_base(lean=8, lf=(22, -4), lb=(-16, -10), **guard)
    P['WALK1'] = pose_base(lean=10, lf=(30, 4), lb=(-6, -20), **guard)
    P['WALK2'] = pose_base(lean=10, lf=(4, -18), lb=(-24, -6), **guard)
    P['CROUCH'] = pose_base(lean=22, lf=(70, -15), lb=(10, -70), af=(60, 150), ab=(40, 150))
    P['JUMP'] = pose_base(lean=15, lf=(95, 0), lb=(60, -40), af=(70, 160), ab=(50, 150), air=True)
    P['BLOCK'] = pose_base(lean=-4, lf=(16, -6), lb=(-18, -12), af=(10, 170), ab=(30, 175))
    P['CBLOCK'] = pose_base(lean=12, lf=(70, -15), lb=(10, -70), af=(20, 175), ab=(35, 170))
    P['SA_W'] = pose_base(lean=4, lf=(22, -4), lb=(-16, -10), af=(-10, 140), ab=(30, 150))
    P['SA_S'] = pose_base(lean=14, lf=(26, -2), lb=(-20, -14), af=(92, 92), ab=(20, 140))
    P['SB_W'] = pose_base(lean=-8, lf=(14, -10), lb=(-22, -14), af=(-40, 60), ab=(40, 150))
    P['SB_S'] = pose_base(lean=24, lf=(36, 4), lb=(-26, -18), af=(100, 96), ab=(-10, 60))
    P['CA_S'] = pose_base(lean=24, lf=(70, -15), lb=(10, -70), af=(90, 90), ab=(40, 150))
    P['CB_S'] = pose_base(lean=30, lf=(100, 92), lb=(20, -80), af=(40, 140), ab=(10, 120))
    P['JA'] = pose_base(lean=20, lf=(95, 0), lb=(60, -40), af=(110, 105), ab=(40, 150), air=True)
    P['JB'] = pose_base(lean=-10, lf=(105, 100), lb=(40, -40), af=(150, 150), ab=(-20, 90), air=True)
    P['HIT'] = pose_base(lean=-24, lf=(14, -6), lb=(-22, -10), af=(-40, 20), ab=(-60, -20), head_dy=-1)
    P['DOWN'] = pose_base(lean=-90, lf=(95, 90), lb=(80, 70), af=(-120, -150), ab=(-140, -170), lie=True)
    P['SP1_W'] = pose_base(lean=30, lf=(60, -10), lb=(-10, -60), af=(-30, 100), ab=(40, 150))
    P['SP1_S'] = pose_base(lean=38, lf=(60, 20), lb=(-60, -60), af=(98, 94), ab=(-40, 10), extra='speed')
    P['SP2_W'] = pose_base(lean=20, lf=(80, -10), lb=(10, -80), af=(10, 120), ab=(40, 150))
    P['SP2_S'] = pose_base(lean=-6, lf=(10, -20), lb=(-25, -40), af=(170, 178), ab=(10, 60), air=True)
    P['WIN'] = pose_base(lean=0, lf=(14, 4), lb=(-14, -4), af=(160, 175), ab=(-30, 10))
    return P

def dusty_poses():
    P = {}
    guard = dict(af=(35, 120), ab=(15, 100))
    P['IDLE'] = pose_base(lean=4, lf=(14, 0), lb=(-12, -8), extra='whip_coil', **guard)
    P['WALK1'] = pose_base(lean=5, lf=(22, 6), lb=(-4, -14), extra='whip_coil', **guard)
    P['WALK2'] = pose_base(lean=5, lf=(2, -12), lb=(-18, -4), extra='whip_coil', **guard)
    P['CROUCH'] = pose_base(lean=18, lf=(80, -10), lb=(15, -75), af=(50, 110), ab=(30, 120), extra='whip_coil')
    P['JUMP'] = pose_base(lean=8, lf=(80, -10), lb=(40, -50), af=(60, 150), ab=(40, 140), air=True)
    P['BLOCK'] = pose_base(lean=-6, lf=(12, -2), lb=(-16, -10), af=(15, 165), ab=(30, 170))
    P['CBLOCK'] = pose_base(lean=10, lf=(80, -10), lb=(15, -75), af=(20, 170), ab=(35, 165))
    P['SA_W'] = pose_base(lean=0, lf=(14, 0), lb=(-12, -8), af=(10, 120), ab=(15, 100))
    P['SA_S'] = pose_base(lean=10, lf=(20, 2), lb=(-16, -10), af=(90, 90), ab=(10, 90))
    P['SB_W'] = pose_base(lean=-10, lf=(8, -4), lb=(-16, -12), af=(-30, -10), ab=(20, 100))
    P['SB_S'] = pose_base(lean=8, lf=(80, 82), lb=(-10, -10), af=(60, 80), ab=(-30, 30))
    P['CA_S'] = pose_base(lean=20, lf=(80, -10), lb=(15, -75), af=(88, 88), ab=(30, 120))
    P['CB_S'] = pose_base(lean=24, lf=(98, 94), lb=(25, -80), af=(40, 100), ab=(10, 120))
    P['JA'] = pose_base(lean=12, lf=(80, -10), lb=(40, -50), af=(100, 100), ab=(40, 140), air=True)
    P['JB'] = pose_base(lean=-8, lf=(100, 98), lb=(30, -40), af=(140, 150), ab=(-20, 60), air=True)
    P['HIT'] = pose_base(lean=-22, lf=(12, -4), lb=(-20, -10), af=(-40, 10), ab=(-60, -30), head_dy=-1)
    P['DOWN'] = pose_base(lean=-90, lf=(95, 90), lb=(80, 70), af=(-120, -150), ab=(-140, -170), lie=True)
    P['SP1_W'] = pose_base(lean=-12, lf=(10, -4), lb=(-18, -12), af=(135, 165), ab=(20, 100))
    P['SP1_S'] = pose_base(lean=14, lf=(22, 2), lb=(-18, -12), af=(95, 92), ab=(-10, 60))
    P['SP2_W'] = pose_base(lean=10, lf=(70, -10), lb=(10, -70), af=(-60, -20), ab=(20, 110))
    P['SP2_S'] = pose_base(lean=26, lf=(80, -10), lb=(15, -75), af=(75, 70), ab=(10, 100))
    P['WIN'] = pose_base(lean=0, lf=(10, 2), lb=(-12, -6), af=(165, 170), ab=(15, 100), extra='whip_coil')
    return P

# extra per-frame tweaks: lift (units) for airborne frames is set by the game, frames sit on 0
def render(f, p, drawer):
    cv = Canvas()
    J = solve(f, p)
    if p['lie']:
        # lying on the back: rotate the standing skeleton -90 and lay it on the ground
        pass
    drawer(cv, f, J, p)
    if f is FLICK:
        draw_extra_flick(cv, f, J, p)
    render.hand = (int(round(J['hf'][0])), int(round(J['hf'][1] / ASPECT)))
    return cv.px

def render_lying(f, drawer):
    """lying flat: draw an upright pose and rotate it 90 degrees backwards"""
    p = pose_base(lean=0, lf=(4, 0), lb=(-4, 0), af=(170, 175), ab=(160, 170))
    up = render(f, p, drawer)
    # rotate the upright figure (feet at the origin) so the head points to -x
    out = [[0] * CANVAS_W for _ in range(CANVAS_H)]
    for r in range(CANVAS_H):
        for c in range(CANVAS_W):
            # destination point in units
            x = c + 0.5 - OX
            y = (OY - r + 0.5) * ASPECT
            # source: rotate back. lying: source up-axis maps to -x, so
            # src_y (height) = -x + 8 (feet at x = +8), src_x = y - 4.5 (body thickness)
            sy = -(x - 18)
            sx = y - 4.0
            sc = int(math.floor(sx + OX))
            sr = int(math.floor(OY + 0.5 - sy / ASPECT))
            if 0 <= sr < CANVAS_H and 0 <= sc < CANVAS_W:
                out[r][c] = up[sr][sc]
    return out

def crop(px):
    """-> (rows, ax, w_bytes): rows bottom-aligned to the ground row, ax = anchor
    column (feet origin) inside the frame, width padded to whole bytes"""
    cols = [c for c in range(CANVAS_W) if any(px[r][c] for r in range(CANVAS_H))]
    rws = [r for r in range(CANVAS_H) if any(px[r])]
    c0, c1 = min(cols), max(cols)
    r0 = min(rws)
    r1 = OY  # keep the ground row as the bottom row
    if max(rws) > OY:
        r1 = max(rws)
    w = c1 - c0 + 1
    wb = (w + 3) // 4
    rows = [px[r][c0:c0 + wb * 4] + [0] * max(0, c0 + wb * 4 - CANVAS_W) for r in range(r0, r1 + 1)]
    rows = [row[:wb * 4] for row in rows]
    return rows, OX - c0, wb, r1 - OY

def pack(rows):
    out = []
    for row in rows:
        for i in range(0, len(row), 4):
            b = 0
            for j in range(4):
                b = (b << 2) | row[i + j]
            out.append(b)
    return out

def fighter_frames(f, poses, drawer):
    frames = []
    for name in FRAME_NAMES:
        if name == 'DOWN':
            px = render_lying(f, drawer)
            hand = (0, 0)
        else:
            px = render(f, poses[name], drawer)
            hand = render.hand
        rows, ax, wb, below = crop(px)
        frames.append(dict(name=name, rows=rows, ax=ax, wb=wb, h=len(rows), below=below,
                           hx=max(-60, min(60, hand[0])), hy=max(0, min(60, hand[1]))))
    return frames

# ------------------------------------------------------------------ backdrop
HUDROWS = 10          # rows 0-9: the HUD band
GROUND_ROW = 58       # the fighters' feet

def backdrop():
    """Main street of a dusty outback town at sunset.
    Colours: 0 green, 1 yellow, 2 blue, 3 red.  Blue and red belong to the
    fighters, so in the play area they only appear as thin lines and dots;
    the big areas are green, yellow and green/yellow dithers."""
    import random
    G, YY, BL, R = 0, 1, 2, 3
    W, H = 128, 64
    px = [[G] * W for _ in range(H)]
    rnd = random.Random(11)

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            px[y][x] = c

    def hline(x0, x1, y, c):
        for x in range(x0, x1 + 1):
            put(x, y, c)

    def vline(x, y0, y1, c):
        for y in range(y0, y1 + 1):
            put(x, y, c)

    def dither(x0, y0, x1, y1, a, b, density=0.5):
        """ordered dither of colours a/b; density = share of b"""
        bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                put(x, y, b if bayer[y & 3][x & 3] < density * 16 else a)

    # ---- HUD band
    for y in range(HUDROWS):
        hline(0, W - 1, y, BL)
    # ---- sky: dusk at the top, sunset glow at the horizon
    dither(0, 10, W - 1, 10, G, BL, 0.5)
    dither(0, 11, W - 1, 11, G, BL, 0.25)
    dither(0, 12, W - 1, 12, G, BL, 0.12)
    # long flat clouds
    for (cx, cy, w) in ((20, 15, 22), (70, 13, 28), (104, 17, 18), (52, 19, 16)):
        dither(cx - w // 2, cy, cx + w // 2, cy, G, YY, 0.5)
        dither(cx - w // 2 + 3, cy + 1, cx + w // 2 - 3, cy + 1, G, YY, 0.25)
    # glow above the horizon, around the sun
    for y in range(27, 41):
        for x in range(W):
            d = max(0.0, 1 - abs(x - 64) / 44.0) * (y - 26) / 14.0
            if d > 0.05:
                bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
                if bayer[y & 3][x & 3] < d * 12:
                    put(x, y, YY)
    # sun sinking behind the mesas
    for y in range(24, 41):
        for x in range(50, 80):
            if (x - 64.5) ** 2 + ((y - 38) * 1.5) ** 2 < 120:
                put(x, y, YY)
    # ---- mesas: red rim, olive (green/yellow checker) faces, green gullies
    def mesa(x0, x1, top, base, slope):
        for y in range(top, base + 1):
            k = int((y - top) * slope)
            a, b = x0 - k, x1 + k
            for x in range(a, b + 1):
                put(x, y, YY if (x + y) % 2 == 0 else G)
            put(a, y, R)
            put(b, y, R)
        hline(x0, x1, top, R)
        hline(x0 + 1, x1 - 1, top + 1, YY)
        for gx in range(x0 + 2, x1 - 1, 4):
            vline(gx, top + 3, base, G)
    mesa(30, 46, 28, 40, 0.9)
    mesa(80, 94, 26, 40, 0.8)
    # far street edge
    hline(0, W - 1, 41, R)
    # ---- the street: yellow, with red dust drifting toward the viewer
    for y in range(42, H):
        d = 0.02 + 0.16 * (y - 42) / (H - 42)
        for x in range(W):
            put(x, y, R if rnd.random() < d else YY)
    for (y, x0, x1) in ((46, 50, 70), (52, 20, 34), (55, 88, 110), (61, 40, 76)):
        for x in range(x0, x1, 2):
            put(x, y, R)
    # ---- saloon verandah on the left
    for y in range(11, 18):
        x1 = 30 - (y - 11) // 2
        for x in range(0, x1 + 1):
            put(x, y, R if ((x + y) // 2) % 2 == 0 else YY)
        put(x1, y, YY)
    hline(0, 27, 18, YY)
    for y in range(19, 41):
        for x in range(0, 26):
            put(x, y, YY if y % 3 == 0 else G)
    dither(6, 21, 18, 30, G, BL, 0.5)
    for hx in (8, 12, 16):
        put(hx, 23, YY); put(hx + 1, 23, YY)
        put(hx, 24, YY); put(hx + 1, 24, YY)
        vline(hx, 25, 28, BL); vline(hx + 1, 25, 28, BL)
    put(12, 22, R); put(13, 22, R)
    hline(5, 19, 20, YY); hline(5, 19, 31, YY)
    vline(5, 20, 31, YY); vline(19, 20, 31, YY)
    for x in (1, 13, 25):
        vline(x, 19, 42, YY)
        vline(x + 1, 19, 42, G)
    hline(0, 27, 35, YY)
    for x in range(0, 27, 3):
        vline(x, 36, 40, YY)
    hline(0, 28, 41, YY)
    hline(0, 28, 42, R)
    vline(22, 19, 20, YY)
    for (dx, dy) in ((0, 0), (1, 0), (-1, 0), (0, 1), (1, 1), (-1, 1), (0, 2)):
        put(22 + dx, 21 + dy, YY)
    for (x, hat) in ((4, R), (9, BL), (21, R)):
        put(x, 32, hat); put(x + 1, 32, hat); put(x - 1, 33, hat); put(x + 2, 33, hat)
        put(x, 33, YY); put(x + 1, 33, YY)
        vline(x, 34, 40, BL); vline(x + 1, 34, 40, BL)
    # barrel on the boardwalk edge
    for y in range(44, 53):
        for x in range(1, 8):
            put(x, y, R if y in (45, 50) else (YY if x in (1, 7) else G))
    hline(2, 6, 43, YY)
    # ---- windmill, far right: a lattice tower and a wheel of blades
    for y in range(19, 41):
        k = (y - 19) // 6
        put(117 - k, y, BL)
        put(121 + k, y, BL)
        if y in (27, 36):
            hline(117 - k, 121 + k, y, BL)
    for a in range(0, 360, 45):
        r = math.radians(a)
        for t in range(2, 6):
            put(119 + int(round(math.cos(r) * t)), 15 + int(round(math.sin(r) * t / 1.5)), BL)
    put(119, 15, YY)
    hline(120, 126, 15, YY)              # tail vane
    vline(126, 13, 17, YY)
    # ---- hitching rail and a horse (yellow, red blanket) on the right
    hline(96, 126, 36, R)
    for x in (97, 125):
        vline(x, 36, 41, R)
    def horse(x, y):
        for dx in range(0, 15):
            for dy in range(0, 5):
                if not ((dx in (0, 14)) and dy in (0, 4)):
                    put(x + dx, y + dy, YY)
        for k in range(6):
            for o in (-1, 0, 1):
                put(x + o - k // 2, y - k, YY)
        for dx in range(-7, -2):
            put(x + dx, y - 6, YY); put(x + dx, y - 5, YY)
        put(x - 7, y - 4, YY)
        put(x - 3, y - 8, YY); put(x - 3, y - 7, YY)
        for k in range(6):
            put(x + 1 + k // 2, y - 6 + k, R)  # mane
        for lx in (1, 3, 11, 13):
            vline(x + lx, y + 5, y + 10, YY)
        for k in range(6):
            put(x + 15 + k // 3, y + k, R)    # tail
        for dx in range(5, 9):
            for dy in range(0, 3):
                put(x + dx, y + dy, R)          # saddle blanket
        put(x - 6, y - 6, G)                    # eye
    horse(103, 31)
    # outline the horse against the glow
    snap = [row[:] for row in px]
    for y in range(20, 42):
        for x in range(92, 124):
            if snap[y][x] == G:
                for (dx, dy) in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    pass
    # spinifex near the street edge
    for x in (36, 58, 76, 90):
        put(x, 41, G); put(x + 1, 40, G); put(x + 2, 41, G)
    return px

def bd_bytes(px):
    out = []
    for row in px:
        for i in range(0, 128, 4):
            b = 0
            for j in range(4):
                b = (b << 2) | row[i + j]
            out.append(b)
    return out

# ------------------------------------------------------------------ font 3x5
FONT = {
 ' ': ['   ', '   ', '   ', '   ', '   '],
 'A': ['###', '# #', '###', '# #', '# #'], 'B': ['## ', '# #', '## ', '# #', '## '],
 'C': ['###', '#  ', '#  ', '#  ', '###'], 'D': ['## ', '# #', '# #', '# #', '## '],
 'E': ['###', '#  ', '## ', '#  ', '###'], 'F': ['###', '#  ', '## ', '#  ', '#  '],
 'G': ['###', '#  ', '# #', '# #', '###'], 'H': ['# #', '# #', '###', '# #', '# #'],
 'I': ['###', ' # ', ' # ', ' # ', '###'], 'J': ['  #', '  #', '  #', '# #', '###'],
 'K': ['# #', '# #', '## ', '# #', '# #'], 'L': ['#  ', '#  ', '#  ', '#  ', '###'],
 'M': ['# #', '###', '###', '# #', '# #'], 'N': ['## ', '# #', '# #', '# #', '# #'],
 'O': ['###', '# #', '# #', '# #', '###'], 'P': ['###', '# #', '###', '#  ', '#  '],
 'Q': ['###', '# #', '# #', '###', '  #'], 'R': ['## ', '# #', '## ', '# #', '# #'],
 'S': ['###', '#  ', '###', '  #', '###'], 'T': ['###', ' # ', ' # ', ' # ', ' # '],
 'U': ['# #', '# #', '# #', '# #', '###'], 'V': ['# #', '# #', '# #', '# #', ' # '],
 'W': ['# #', '# #', '###', '###', '# #'], 'X': ['# #', '# #', ' # ', '# #', '# #'],
 'Y': ['# #', '# #', '###', ' # ', ' # '], 'Z': ['###', '  #', ' # ', '#  ', '###'],
 '0': ['###', '# #', '# #', '# #', '###'], '1': [' # ', '## ', ' # ', ' # ', '###'],
 '2': ['###', '  #', '###', '#  ', '###'], '3': ['###', '  #', '###', '  #', '###'],
 '4': ['# #', '# #', '###', '  #', '  #'], '5': ['###', '#  ', '###', '  #', '###'],
 '6': ['###', '#  ', '###', '# #', '###'], '7': ['###', '  #', '  #', '  #', '  #'],
 '8': ['###', '# #', '###', '# #', '###'], '9': ['###', '# #', '###', '  #', '###'],
 '.': ['   ', '   ', '   ', '   ', ' # '], '!': [' # ', ' # ', ' # ', '   ', ' # '],
 ':': ['   ', ' # ', '   ', ' # ', '   '], '-': ['   ', '   ', '###', '   ', '   '],
 '?': ['###', '  #', ' ##', '   ', ' # '], "'": [' # ', ' # ', '   ', '   ', '   '],
 '/': ['  #', '  #', ' # ', '#  ', '#  '], '$': [' ##', '## ', ' # ', ' ##', '## '],
 '+': ['   ', ' # ', '###', ' # ', '   '], '>': ['#  ', ' # ', '  #', ' # ', '#  '],
 '<': ['  #', ' # ', '#  ', ' # ', '  #'], '=': ['   ', '###', '   ', '###', '   '],
 '(': [' # ', '#  ', '#  ', '#  ', ' # '], ')': [' # ', '  #', '  #', '  #', ' # '],
 ',': ['   ', '   ', '   ', ' # ', '#  '], '*': ['# #', ' # ', '###', ' # ', '# #'],
}
FONT_ORDER = [chr(c) for c in range(32, 96)]

def font_asm():
    lines = ['; 3x5 font, ASCII 32-95, 5 bytes per glyph: pixels in bits 3..1 (bit 3 = left)']
    lines.append('font:')
    for ch in FONT_ORDER:
        g = FONT.get(ch, FONT['?'])
        bs = []
        for row in g:
            v = 0
            for i, c in enumerate(row):
                if c == '#':
                    v |= 8 >> i
            bs.append(v)
        lines.append('        db ' + ','.join('$%02X' % b for b in bs) + '   ; ' + repr(ch))
    return '\n'.join(lines) + '\n'

# ------------------------------------------------------------------ output
PAL = {0: (40, 160, 40), 1: (240, 230, 70), 2: (40, 60, 220), 3: (220, 40, 40)}

def preview(frames_list, fn):
    scale = 4
    cellw, cellh = 64, 40
    n = len(FRAME_NAMES)
    img = Image.new('RGB', (cellw * scale * 8, int(cellh * ASPECT * scale) * ((n + 7) // 8) * len(frames_list)), (30, 30, 30))
    for fi, frames in enumerate(frames_list):
        for i, fr in enumerate(frames):
            gx = (i % 8) * cellw * scale
            gy = ((i // 8) + fi * ((n + 7) // 8)) * int(cellh * ASPECT * scale)
            for r, row in enumerate(fr['rows']):
                for c, v in enumerate(row):
                    col = PAL[v if not (fi == 1 and v == 2) else 3] if v else PAL[0]
                    x0 = gx + (c + 32 - fr['ax']) * scale
                    y0 = gy + int((cellh - fr['h'] + r - 2) * ASPECT * scale)
                    for yy in range(int(ASPECT * scale)):
                        for xx in range(scale):
                            if 0 <= x0 + xx < img.width and 0 <= y0 + yy < img.height:
                                img.putpixel((x0 + xx, y0 + yy), col)
    img.save(fn)

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'gen'
    shots = sys.argv[2] if len(sys.argv) > 2 else None
    os.makedirs(out, exist_ok=True)
    fl = fighter_frames(FLICK, flick_poses(), draw_flick)
    du = fighter_frames(DUSTY, dusty_poses(), draw_dusty)
    lines = ['; generated by tools/art.py - do not edit',
             '; frame header (8 bytes): dw data, db width_bytes, height, anchor_x, rows_below_ground, hand_x, hand_y',
             'NFRAMES equ %d' % len(FRAME_NAMES)]
    for i, n in enumerate(FRAME_NAMES):
        lines.append('FR_%s equ %d' % (n, i))
    total = {}
    for tag, frames in (('flick', fl), ('dusty', du)):
        lines.append('%s_hdr:' % tag)
        for fr in frames:
            lines.append('        dw %s_%s\n        db %d,%d,%d,%d,%d,%d' % (tag, fr['name'].lower(), fr['wb'], fr['h'], fr['ax'], fr['below'], fr['hx'] & 255, fr['hy']))
        lines.append('%s_data:' % tag)
        size = 0
        for fr in frames:
            data = pack(fr['rows'])
            size += len(data)
            lines.append('%s_%s:' % (tag, fr['name'].lower()))
            for i in range(0, len(data), 16):
                lines.append('        db ' + ','.join('$%02X' % b for b in data[i:i + 16]))
        lines.append('%s_end:' % tag)
        total[tag] = size
        # bytes needed in the bank: unshifted + shifted (one byte wider)
        bank = sum(fr['wb'] * fr['h'] + (fr['wb'] + 1) * fr['h'] for fr in frames)
        print('%s: %d frames, %d bytes packed, %d bytes in bank' % (tag, len(frames), size, bank))
    open(os.path.join(out, 'fighters.asm'), 'w').write('\n'.join(lines) + '\n')
    bd = bd_bytes(backdrop())
    bl = ['; generated by tools/art.py - Showground Tent backdrop, 64 rows x 32 bytes', 'backdrop:']
    for i in range(0, len(bd), 16):
        bl.append('        db ' + ','.join('$%02X' % b for b in bd[i:i + 16]))
    open(os.path.join(out, 'backdrop.asm'), 'w').write('\n'.join(bl) + '\n')
    open(os.path.join(out, 'font.asm'), 'w').write(font_asm())
    if shots:
        preview([fl, du], os.path.join(shots, 'art_frames.png'))
        px = backdrop()
        img = Image.new('RGB', (128 * 4, int(64 * ASPECT * 4)))
        for r in range(64):
            for c in range(128):
                for yy in range(6):
                    for xx in range(4):
                        img.putpixel((c * 4 + xx, r * 6 + yy), PAL[px[r][c]])
        img.save(os.path.join(shots, 'art_backdrop.png'))

if __name__ == '__main__':
    main()
