"""Agent Wren's animation, posed on a jointed skeleton and rendered to 24 x 24 sprites.

Angles are degrees from straight down; positive swings a limb forward (the way
Wren faces).  Knees flex backwards, elbows forwards.  Each pose is drawn 8x
oversized with thick limbs and round joints, the far-side limbs first and the
near-side limbs with a dark outline so overlapping limbs stay readable, then
box-filtered down to 24 x 24 and thresholded.

python tools/wren_anim.py   -> writes build/wren_preview.png
"""
import math
from PIL import Image, ImageDraw

S = 8                          # oversampling
W = H = 24
# segment lengths (pixels at 1x)
# Lithe proportions: a small head, long legs, slim limbs (the first set read as a blob).
HEAD_R, NECK, TORSO, THIGH, SHIN, FOOT = 2.45, 0.7, 6.3, 5.9, 5.9, 2.2
UARM, FARM = 4.3, 4.1
WID = dict(torso=3.9, thigh=2.35, shin=1.85, foot=1.5, uarm=1.6, farm=1.35)

def vec(angle, length):
    a = math.radians(angle)
    return math.sin(a) * length, math.cos(a) * length          # +x forward, +y down

class Pose:
    def __init__(s, lean=0, hipA=0, kneeA=0, hipB=0, kneeB=0, shA=0, elA=0, shB=0, elB=0,
                 footA=90, footB=90, rot=0, ground=True, bob=0, head=0, dx=0):
        s.__dict__.update(locals()); del s.__dict__['s']

def joints(p):
    """Skeleton points with the hip at the origin."""
    hip = (0.0, 0.0)
    tx, ty = vec(180 - p.lean, TORSO)                            # torso points up, leaning forward
    sh = (hip[0] + tx, hip[1] + ty)
    nx, ny = vec(180 - p.lean - p.head, NECK + HEAD_R)
    head = (sh[0] + nx, sh[1] + ny)
    out = dict(hip=hip, sh=sh, head=head)
    for side in 'AB':
        ha, ka, fa = getattr(p, 'hip' + side), getattr(p, 'knee' + side), getattr(p, 'foot' + side)
        x, y = vec(ha, THIGH); knee = (hip[0] + x, hip[1] + y)
        x, y = vec(ha - ka, SHIN); ankle = (knee[0] + x, knee[1] + y)
        x, y = vec(ha - ka + fa, FOOT); toe = (ankle[0] + x, ankle[1] + y)
        sa, ea = getattr(p, 'sh' + side), getattr(p, 'el' + side)
        x, y = vec(sa, UARM); elbow = (sh[0] + x, sh[1] + y)
        x, y = vec(sa + ea, FARM); hand = (elbow[0] + x, elbow[1] + y)
        out.update({'knee' + side: knee, 'ankle' + side: ankle, 'toe' + side: toe,
                    'elbow' + side: elbow, 'hand' + side: hand})
    if p.rot:                                                    # spin about the body's centre
        cx = sum(v[0] for v in out.values()) / len(out)
        cy = sum(v[1] for v in out.values()) / len(out)
        a = math.radians(p.rot); c, s_ = math.cos(a), math.sin(a)
        out = {k: (cx + (x - cx) * c - (y - cy) * s_, cy + (x - cx) * s_ + (y - cy) * c) for k, (x, y) in out.items()}
    return out

def render(p):
    j = joints(p)
    xs = [v[0] for v in j.values()]; ys = [v[1] for v in j.values()]
    if p.ground:      # lowest point on the bottom row, centred on x = 12 + dx
        oy = (H - 0.6) - max(ys) - p.bob
    else:             # airborne: centre the whole figure
        oy = H / 2 - (min(ys) + max(ys)) / 2
    ox = W / 2 + p.dx - (j['hip'][0] if p.ground else (min(xs) + max(xs)) / 2)
    img = Image.new('L', (W * S, H * S), 0)
    d = ImageDraw.Draw(img)
    P = lambda q: ((q[0] + ox) * S, (q[1] + oy) * S)
    def limb(a, b, w, col=255, outline=False, gap=0.9):
        if outline:
            limb(a, b, w + gap, 0)
        d.line([P(a), P(b)], fill=col, width=int(w * S))
        for q in (a, b):
            r = w * S / 2; x, y = P(q); d.ellipse([x - r, y - r, x + r, y + r], fill=col)
    near_ok = not p.rot            # no outlines on the tucked spin: it's a ball
    def side(sd, near):
        near = near and near_ok
        limb(j['hip'], j['knee' + sd], WID['thigh'], outline=near)
        limb(j['knee' + sd], j['ankle' + sd], WID['shin'], outline=near)
        limb(j['ankle' + sd], j['toe' + sd], WID['foot'], outline=near)
    def arm(sd, near):
        limb(j['sh'], j['elbow' + sd], WID['uarm'], outline=near, gap=1.15)
        limb(j['elbow' + sd], j['hand' + sd], WID['farm'], outline=near, gap=1.15)
    arm('B', False); side('B', False)                            # far side
    limb(j['hip'], j['sh'], WID['torso'])
    x, y = P(j['head']); r = HEAD_R * S
    d.ellipse([x - r, y - r * 1.08, x + r, y + r * 1.08], fill=255)
    # visor slit, facing forward along the body's heading
    a = math.radians(180 - p.lean - p.head + (p.rot or 0) * -1)
    fx, fy = math.sin(a + math.pi / 2), math.cos(a + math.pi / 2)
    hx, hy = j['head']
    eye = (hx + fx * 0.4 + math.sin(a) * 0.3, hy + fy * 0.4 + math.cos(a) * 0.3)
    d.line([P(eye), P((eye[0] + fx * 2.6, eye[1] + fy * 2.6))], fill=0, width=int(0.9 * S))
    if not p.rot:                                                # belt: a dark band at the hips
        bx, by = j['hip']; sx, sy = j['sh']
        ux, uy = (sx - bx) / TORSO, (sy - by) / TORSO               # along the torso
        c = (bx + ux * 1.3, by + uy * 1.3); n = (-uy, ux)
        w = WID['torso'] / 2 + 0.2
        d.line([P((c[0] - n[0] * w, c[1] - n[1] * w)), P((c[0] + n[0] * w, c[1] + n[1] * w))], fill=0, width=int(0.85 * S))
    side('A', True); arm('A', True)                              # near side
    small = img.resize((W, H), Image.BOX)
    bm = [[1 if small.getpixel((x, y)) >= 96 else 0 for x in range(W)] for y in range(H)]
    # tidy: fill pin-holes, drop lone pixels (they shimmer at 50 Hz)
    def n4(x, y): return sum(bm[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                             if 0 <= x + dx < W and 0 <= y + dy < H)
    for y in range(H):
        for x in range(W):
            k = n4(x, y)
            if not bm[y][x] and k >= 3: bm[y][x] = 1
            elif bm[y][x] and k == 0: bm[y][x] = 0
    return bm

# --------------------------------------------------------------- the moves
def run_pose(t):
    f = 2 * math.pi * t
    def leg(ph):
        hip = 30 * math.sin(ph)
        knee = 14 + 78 * max(0.0, math.cos(ph - 0.5)) ** 1.6
        foot = 92 - 25 * max(0.0, -math.sin(ph))
        return hip, knee, foot
    hA, kA, fA = leg(f); hB, kB, fB = leg(f + math.pi)
    return Pose(lean=11, hipA=hA, kneeA=kA, footA=fA, hipB=hB, kneeB=kB, footB=fB,
                shA=-34 * math.sin(f), elA=78 + 12 * math.cos(f),
                shB=34 * math.sin(f), elB=78 - 12 * math.cos(f),
                bob=1.3 * abs(math.sin(f)) - 0.3, head=-6)

STAND = Pose(lean=1, hipA=4, kneeA=4, hipB=-3, kneeB=3, shA=6, elA=14, shB=-4, elB=10)
TURN = Pose(lean=-6, hipA=18, kneeA=10, hipB=-12, kneeB=24, shA=-30, elA=40, shB=25, elB=40)
CROUCH = Pose(lean=34, hipA=64, kneeA=104, hipB=52, kneeB=100, shA=-40, elA=30, shB=-28, elB=30, footA=96, footB=96)
TAKEOFF = Pose(lean=22, hipA=34, kneeA=60, hipB=-22, kneeB=12, shA=150, elA=10, shB=135, elB=15, footB=60, ground=False)
def tuck(rot):
    return Pose(lean=30, hipA=124, kneeA=146, hipB=124, kneeB=146, shA=96, elA=40, shB=96, elB=40,
                footA=70, footB=70, head=22, rot=rot, ground=False)
OPEN = Pose(lean=8, hipA=46, kneeA=48, hipB=24, kneeB=40, shA=80, elA=20, shB=60, elB=25, ground=False)
LAND = Pose(lean=30, hipA=58, kneeA=96, hipB=40, kneeB=88, shA=55, elA=30, shB=40, elB=30, footA=96, footB=96)
FALL = Pose(lean=-4, hipA=14, kneeA=34, hipB=-8, kneeB=40, shA=150, elA=20, shB=165, elB=15, ground=False)
KNEEL = [Pose(lean=26, hipA=86, kneeA=92, hipB=-6, kneeB=96, footB=150, shA=78, elA=18, shB=62, elB=30, head=10),
         Pose(lean=30, hipA=86, kneeA=92, hipB=-6, kneeB=96, footB=150, shA=62, elA=42, shB=86, elB=14, head=16)]

# ------------------------------------------------ rotoscoped from Muybridge (1887)
# Joint angles read by hand off Eadweard Muybridge's Animal Locomotion (public domain;
# ref/, tools/trace.py makes the gridded enlargements).  Same conventions as above.
#
# Plate 60, "running at a half-mile gait", frames 1-5 of the side-on row.  Frames 6-10
# are the same with the legs and arms swapped, so the 10-frame loop is exact.
#             lean (hip, knee, foot) near   (hip, knee, foot) far   (sh, el) near (sh, el) far  bob
RUN_KEYS = [(12, (60, 64, 92),   (-45, 22, 135),  (-50, 78), (16, 62),  0.0),
            (10, (39, 19, 90),   (-38, 57, 140),  (-45, 80), (20, 66),  0.0),
            (8,  (22, 7, 92),    (-22, 102, 125), (-30, 88), (10, 72),  0.3),
            (5,  (4, 12, 120),   (20, 121, 100),  (-15, 86), (-5, 78),  0.6),
            (8,  (-11, 24, 135), (54, 144, 95),   (5, 80),   (-25, 80), 1.4)]
def run_key(k):
    lean, a, b, sa, sb, bob = RUN_KEYS[k % 5]
    if k >= 5: a, b, sa, sb = b, a, sb, sa
    return Pose(lean=lean, hipA=a[0], kneeA=a[1], footA=a[2], hipB=b[0], kneeB=b[1], footB=b[2],
                shA=sa[0], elA=sa[1], shB=sb[0], elB=sb[1], bob=bob, head=-6)
RUN_FRAMES = 10
# Plate 363, "running somersault", side-on rows 1 and 3 (12 frames).  rot = how far the
# whole body has turned forward (0 upright, 90 head first, 180 upside down).
SOM = [Pose(lean=8, hipA=5, kneeA=15, hipB=-3, kneeB=10, shA=20, elA=30, shB=10, elB=20, head=10),          # 1 stand
       Pose(lean=15, hipA=25, kneeA=35, hipB=22, kneeB=32, shA=35, elA=30, shB=25, elB=30, head=10),         # 2 dip
       Pose(lean=30, hipA=45, kneeA=60, hipB=40, kneeB=55, shA=50, elA=20, shB=40, elB=25, head=15,
            footA=100, footB=100),                                                                            # 3 crouch
       Pose(lean=0, rot=90, hipA=65, kneeA=6, hipB=60, kneeB=8, shA=80, elA=10, shB=72, elB=14,
            footA=140, footB=140, head=10, ground=False),                                                     # 4 dive
       Pose(lean=0, rot=112, hipA=87, kneeA=50, hipB=80, kneeB=60, shA=150, elA=20, shB=140, elB=25,
            footA=130, footB=130, head=15, ground=False),                                                     # 5 arch over
       Pose(lean=0, rot=160, hipA=95, kneeA=95, hipB=70, kneeB=110, shA=95, elA=35, shB=80, elB=40,
            footA=110, footB=110, head=20, ground=False),                                                     # 6 inverted, tucking
       Pose(lean=0, rot=227, hipA=70, kneeA=88, hipB=78, kneeB=95, shA=90, elA=5, shB=60, elB=40,
            footA=120, footB=120, head=10, ground=False),                                                     # 7 legs over
       Pose(lean=0, rot=282, hipA=60, kneeA=105, hipB=72, kneeB=112, shA=85, elA=10, shB=110, elB=30,
            footA=100, footB=100, head=5, ground=False),                                                      # 8 on the back
       Pose(lean=0, rot=321, hipA=45, kneeA=90, hipB=52, kneeB=96, shA=40, elA=60, shB=50, elB=55,
            footA=95, footB=95, head=0, ground=False),                                                        # 9 sitting up
       Pose(lean=8, hipA=87, kneeA=102, hipB=78, kneeB=98, shA=37, elA=67, shB=45, elB=60, footA=96, footB=96),  # 10 landing
       Pose(lean=5, hipA=75, kneeA=95, hipB=60, kneeB=80, shA=60, elA=40, shB=50, elB=45, footA=96, footB=96),   # 11 rising
       Pose(lean=20, hipA=84, kneeA=125, hipB=-10, kneeB=10, shA=70, elA=30, shB=60, elB=35)]                     # 12 striding out
def airborne(p):
    q = Pose(**{k: v for k, v in p.__dict__.items()}); q.ground = False; return q

FRAMES = {}
FRAMES['stand'] = [SOM[0]]
FRAMES['run'] = [run_key(k) for k in range(RUN_FRAMES)]
FRAMES['turn'] = [TURN]
# the game's vault slots: crouch, takeoff, 7 spin frames, opening out, landing
FRAMES['vault'] = [SOM[2], SOM[3], SOM[4], SOM[5], SOM[6], SOM[7], SOM[8], airborne(SOM[9]), airborne(SOM[10]),
                   airborne(SOM[11]), SOM[9]]
FRAMES['fall'] = [FALL]
FRAMES['search'] = KNEEL

def all_frames():
    order = []
    for name in ('stand', 'run', 'turn', 'vault', 'fall', 'search'):
        for i, p in enumerate(FRAMES[name]):
            order.append((name, i, render(p)))
    return order

if __name__ == '__main__':
    fr = all_frames()
    Z = 6
    sheet = Image.new('RGB', ((W + 4) * Z * len(fr) // 2 + 8, (H + 6) * Z * 2), (25, 25, 60))
    for k, (name, i, bm) in enumerate(fr):
        ox = (k % ((len(fr) + 1) // 2)) * (W + 4) * Z + 8; oy = (k // ((len(fr) + 1) // 2)) * (H + 6) * Z + 8
        for y in range(H):
            for x in range(W):
                c = (255, 255, 255) if bm[y][x] else (0, 0, 0)
                for a in range(Z - 1):
                    for b in range(Z - 1):
                        sheet.putpixel((ox + x * Z + a, oy + y * Z + b), c)
    sheet.save('build/wren_preview.png'); print(len(fr), 'frames')
