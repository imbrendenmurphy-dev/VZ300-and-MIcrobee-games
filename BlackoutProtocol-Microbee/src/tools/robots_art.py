"""MERIDIAN's security robots, drawn 8x oversized and reduced to 24-pixel-wide sprites.

WARDEN unit (20 rows): a domed head with a glowing visor slot, a boxy body with a
chest light, and a tracked base whose links move as it rolls.  Frames: four tread
phases (eye open), one asleep (visor dark, head dipped).
SPARK (6 rows): a crackling bolt, two frames.

python tools/robots_art.py  -> build/robots_preview.png
"""
from PIL import Image, ImageDraw

S = 8
W = 24

def shrink(img, h, thr=110):
    small = img.resize((W, h), Image.BOX)
    return [[1 if small.getpixel((x, y)) >= thr else 0 for x in range(W)] for y in range(h)]

def warden(phase, asleep=False):
    H = 20
    img = Image.new('L', (W * S, H * S), 0); d = ImageDraw.Draw(img)
    def R(x0, y0, x1, y1, c=255): d.rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], fill=c)
    def E(x0, y0, x1, y1, c=255): d.ellipse([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], fill=c)
    dip = 1 if asleep else 0
    E(6, 0 + dip, 18, 10 + dip)                       # dome
    R(6, 5 + dip, 18, 8 + dip)
    if not asleep:
        R(8, 4, 17, 6, 0)                             # visor slot (dark), eye bright in it
        R(13 + (phase % 2), 4, 15 + (phase % 2), 6)
    else:
        R(8, 5 + dip, 17, 6 + dip, 0)
    R(11, 9, 13, 11)                                  # neck
    R(4, 10, 20, 15)                                  # body
    R(5, 11, 19, 14, 0); R(6, 11, 18, 14)             # body panel line
    R(10, 12, 14, 14, 0)                              # chest light socket
    if not asleep: R(11, 12, 13, 13)
    R(2, 11, 4, 14); R(20, 11, 22, 14)                # arms
    E(1, 15, 23, 20)                                  # tracks
    for k in range(5):                                # track links, moving with phase
        x = 3 + k * 4 + phase
        R(x, 17, x + 2, 18, 0)
    return shrink(img, H)

def spark(phase):
    H = 6
    img = Image.new('L', (W * S, H * S), 0); d = ImageDraw.Draw(img)
    pts = [(1, 3), (4, 1 + phase), (7, 5 - phase), (10, 1 + phase), (13, 4), (15, 2)]
    d.line([(x * S, y * S) for x, y in pts], fill=255, width=int(1.6 * S))
    d.ellipse([12 * S, 0, 17 * S, 6 * S], fill=255)
    return shrink(img, H)

def steam(phase):
    """A vent firing: a billowing column 24 high, two frames."""
    H = 24
    img = Image.new('L', (W * S, H * S), 0); d = ImageDraw.Draw(img)
    import math
    for k in range(9):
        y = H - 2 - k * 2.6
        r = 2.2 + k * 0.45 + (0.6 if (k + phase) % 2 else 0)
        x = 12 + 1.8 * math.sin(k * 1.3 + phase * 1.7)
        d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], fill=255)
        if k % 2 == phase:
            d.ellipse([(x - r * 0.45) * S, (y - r * 0.45) * S, (x + r * 0.45) * S, (y + r * 0.45) * S], fill=0)
    return shrink(img, H, 100)

def laser(phase):
    """A laser gate: a two-pixel beam with sparks along it, two frames."""
    H = 24
    bm = [[0] * W for _ in range(H)]
    for y in range(H):
        bm[y][11] = bm[y][12] = 1
        if (y + phase * 3) % 6 == 0: bm[y][10] = bm[y][13] = 1
        if (y + phase * 3) % 12 == 3: bm[y][9] = bm[y][14] = 1
    return bm

def canvas(H):
    img = Image.new('L', (W * S, H * S), 0); d = ImageDraw.Draw(img)
    R = lambda x0, y0, x1, y1, c=255: d.rectangle([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], fill=c)
    E = lambda x0, y0, x1, y1, c=255: d.ellipse([x0 * S, y0 * S, x1 * S - 1, y1 * S - 1], fill=c)
    L = lambda pts, w, c=255: d.line([(x * S, y * S) for x, y in pts], fill=c, width=int(w * S))
    return img, d, R, E, L

def warden8(k, mode='move'):
    """Patrol: the tracked WARDEN.  Move frames: treads roll (4) x eye sweeps (2)."""
    H = 20
    img, d, R, E, L = canvas(H)
    asleep = mode == 'sleep'; dip = 1 if asleep else 0
    E(6, dip, 18, 10 + dip); R(6, 5 + dip, 18, 8 + dip)
    R(8, 4 + dip, 17, 6 + dip, 0)
    if not asleep:
        ex = 9 + (k // 4) * 5 + (k % 2)                   # the eye sweeps the visor
        R(ex, 4, ex + 2, 6)
    R(11, 9, 13, 11); R(4, 10, 20, 15); R(5, 11, 19, 14, 0); R(6, 11, 18, 14); R(10, 12, 14, 14, 0)
    if not asleep: R(11, 12, 13, 13)
    if mode == 'zap':                                  # arms thrown up, crackling
        R(1, 6, 3, 13); R(21, 6, 23, 13); L([(2, 6), (1, 3), (3, 2), (2, 0)], 0.9); L([(22, 6), (23, 3), (21, 2), (22, 0)], 0.9)
    else:
        R(2, 11, 4, 14); R(20, 11, 22, 14)
    E(1, 15, 23, 20)
    for q in range(5):
        x = 3 + q * 4 + (k % 4)
        R(x, 17, x + 2, 18, 0)
    return shrink(img, H)

def arc8(k, mode='move'):
    """Zapper: the ARC unit, a two-legged walker with a discharge coil on its head."""
    H = 20
    img, d, R, E, L = canvas(H)
    import math
    asleep = mode == 'sleep'; slump = 2 if asleep else 0
    ph = 2 * math.pi * k / 8
    for c in range(3):                                 # the coil
        y = 1 + c * 1.6 + slump
        E(9, y, 15, y + 1.6); E(10, y + 0.3, 14, y + 1.3, 0)
    R(11, 5 + slump, 13, 7 + slump)
    E(6, 6 + slump, 18, 13 + slump)                    # body
    E(9, 8 + slump, 15, 11 + slump, 0)
    if not asleep: E(10.5, 8.8, 13.5, 10.4)            # its eye glows
    if mode == 'zap':
        L([(12, 1), (9, -1), (14, -2), (11, -4)], 0.9); L([(6, 8), (2, 6), (4, 4), (0, 3)], 0.8); L([(18, 8), (22, 6), (20, 4), (24, 3)], 0.8)
    for side in (-1, 1):                                # legs stepping
        a = (math.sin(ph) * 3 * side) if not asleep else side * 2
        hx = 12 + side * 3
        kx, ky = hx + a * 0.5, 16 + slump * 0.5
        L([(hx, 13 + slump), (kx, ky), (hx + a, 19.5)], 1.6)
        R(hx + a - 2, 18.6, hx + a + 2, 20)
    return shrink(img, H)

def dart8(k, mode='move'):
    """Hunter: the DART drone, hovering on a thruster, fins out; it bobs as it flies."""
    H = 20
    img, d, R, E, L = canvas(H)
    import math
    asleep = mode == 'sleep'
    bob = 0 if asleep else round(1.2 * math.sin(2 * math.pi * k / 8), 1)
    y0 = 9 if asleep else 3 + bob
    E(4, y0, 20, y0 + 9)                               # the pod
    R(13, y0 + 2.5, 19, y0 + 4.5, 0)                   # its visor (facing forward)
    if not asleep: R(15 + (k % 2), y0 + 3, 17 + (k % 2), y0 + 4)
    L([(6, y0 + 2), (1, y0 - 1), (4, y0 + 4)], 1.1)    # fins
    L([(6, y0 + 7), (1, y0 + 10), (5, y0 + 8)], 1.1)
    if mode == 'zap':                                  # a lunge: prongs forward
        L([(19, y0 + 4), (24, y0 + 3)], 0.9); L([(19, y0 + 6), (24, y0 + 7)], 0.9)
    if not asleep:                                     # the thruster flame flickers
        fl = 3 + (k % 3)
        L([(12, y0 + 9), (12, y0 + 9 + fl)], 1.6 - 0.3 * (k % 2))
    else:
        R(6, 18, 18, 20)                               # resting on the floor
    return shrink(img, H)

def turret8(k, mode='move'):
    """Sentry: the TURRET, a pedestal gun that sweeps its barrel up and down."""
    H = 20
    img, d, R, E, L = canvas(H)
    import math
    asleep = mode == 'sleep'
    R(7, 16, 17, 20); R(9, 12, 15, 16)                 # base and column
    E(6, 5, 18, 14); E(8, 7, 16, 12, 0)                # the turret head
    if not asleep: E(10, 8, 14, 11)
    ang = -40 if asleep else (math.sin(2 * math.pi * k / 8) * 14)
    a = math.radians(ang)
    bx, by = 16, 9.5
    L([(bx, by), (bx + 7 * math.cos(a), by + 7 * math.sin(a))], 1.8)
    if mode == 'zap':                                  # muzzle flash
        fx, fy = bx + 7 * math.cos(a), by + 7 * math.sin(a)
        E(fx - 2, fy - 2.5, fx + 2.5, fy + 2.5)
    R(5, 14, 19, 16)                                   # its mounting ring
    return shrink(img, H)

ROBOT_KINDS = (warden8, arc8, dart8, turret8)          # patrol, zapper, hunter, sentry

def frames():
    """[(name, height, bitmap)] in the order the game uses: per robot kind, 8 move
    frames, a firing pose and an asleep pose (objects.asm picks kind * 10 + n)."""
    out = []
    for fn in ROBOT_KINDS:
        out += [(fn.__name__, 20, fn(k)) for k in range(8)]
        out.append((fn.__name__ + '_zap', 20, fn(0, 'zap')))
        out.append((fn.__name__ + '_sleep', 20, fn(0, 'sleep')))
    out += [('spark', 6, spark(p)) for p in range(2)]
    out += [('steam', 24, steam(p)) for p in range(2)]
    out += [('laser', 24, laser(p)) for p in range(2)]
    return out

if __name__ == '__main__':
    fr = frames(); Z = 8
    cols = 10; rows = (len(fr) + cols - 1) // cols
    sheet = Image.new('RGB', ((W + 3) * Z * cols, 26 * Z * rows), (40, 20, 20))
    for k, (n, h, bm) in enumerate(fr):
        ox, oy = (k % cols) * (W + 3) * Z, (k // cols) * 26 * Z
        for y in range(h):
            for x in range(W):
                if bm[y][x]:
                    for a in range(Z - 1):
                        for b in range(Z - 1): sheet.putpixel((ox + x * Z + a, oy + y * Z + b), (255, 90, 90))
    sheet.save('build/robots_preview.png')
