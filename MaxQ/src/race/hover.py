"""MAX Q hovercraft: a tiny flat-shaded 3D model rendered into VZ mode(1) sprites.

Colours (colour set 0): 0 green, 1 yellow, 2 blue, 3 red.  A face colour can be a
pair (a, b) for a checker dither.  VZ pixels are about 1.5x taller than wide.
"""
import math
from PIL import Image, ImageDraw

# ---------------------------------------------------------------- model
# x right, y up, z forward (nose).  Units roughly: craft 10 long, 8 wide.
V = {
    'rtl': (-3.0, 1.7, -4.0), 'rtr': (3.0, 1.7, -4.0),      # rear deck corners
    'rbl': (-4.2, 0.3, -4.0), 'rbr': (4.2, 0.3, -4.0),      # rear skirt corners
    'fbl': (-1.5, 0.3, 5.5), 'fbr': (1.5, 0.3, 5.5),        # nose skirt
    'ftl': (-0.7, 0.8, 5.5), 'ftr': (0.7, 0.8, 5.5),        # nose deck
    'cbl': (-1.4, 1.8, -2.2), 'cbr': (1.4, 1.8, -2.2),      # canopy back
    'ctl': (-1.0, 2.6, -1.4), 'ctr': (1.0, 2.6, -1.4),      # canopy top
    'cfl': (-0.6, 1.3, 2.0), 'cfr': (0.6, 1.3, 2.0),        # canopy front
    'fin_lb': (-3.0, 1.7, -4.0), 'fin_lt': (-3.2, 3.4, -4.6), 'fin_lf': (-3.0, 1.7, -2.4),
    'fin_rb': (3.0, 1.7, -4.0), 'fin_rt': (3.2, 3.4, -4.6), 'fin_rf': (3.0, 1.7, -2.4),
    'tl': (-2.6, 1.4, -4.05), 'tr': (2.6, 1.4, -4.05),      # thruster bar
    'bl': (-2.6, 0.7, -4.05), 'br': (2.6, 0.7, -4.05),
}

def faces(var):
    body, deck, canopy, glow, fin = var['body'], var['deck'], var['canopy'], var['glow'], var['fin']
    return [
        (('rbl', 'rbr', 'rtr', 'rtl'), body),           # rear plate
        (('tl', 'tr', 'br', 'bl'), glow),               # thruster glow (the "tail light")
        (('rtl', 'rtr', 'ftr', 'ftl'), deck),           # deck
        (('rbl', 'rtl', 'ftl', 'fbl'), body),           # left flank
        (('rtr', 'rbr', 'fbr', 'ftr'), body),           # right flank
        (('fbl', 'ftl', 'ftr', 'fbr'), body),           # nose
        (('cbl', 'cbr', 'ctr', 'ctl'), canopy),         # canopy back
        (('ctl', 'ctr', 'cfr', 'cfl'), canopy),         # canopy top
        (('cbl', 'ctl', 'cfl'), canopy), (('cbr', 'cfr', 'ctr'), canopy),
        (('fin_lb', 'fin_lt', 'fin_lf'), fin), (('fin_rb', 'fin_rf', 'fin_rt'), fin),
    ]

PLAYER = dict(body=1, deck=1, canopy=2, glow=3, fin=3, rim=None)
RIVAL_A = dict(body=3, deck=3, canopy=2, glow=1, fin=2, rim=None)
RIVAL_B = dict(body=2, deck=2, canopy=(2, 0), glow=3, fin=1, rim=1)

# ---------------------------------------------------------------- render
def rot(p, yaw, pitch, roll, elev):
    x, y, z = p
    c, s = math.cos(roll), math.sin(roll);  x, y = x * c - y * s, x * s + y * c          # bank
    c, s = math.cos(pitch), math.sin(pitch); y, z = y * c + z * s, -y * s + z * c       # nose up +
    c, s = math.cos(yaw), math.sin(yaw);    x, z = x * c + z * s, -x * s + z * c        # turn right +
    c, s = math.cos(elev), math.sin(elev);  y, z = y * c + z * s, -y * s + z * c        # camera above
    return x, y, z

def render(var, yaw=0.0, pitch=0.0, roll=0.0, width=24, height=10, lift=0, elev=0.30):
    """Returns rows of colour indices (None = transparent) plus a shadow mask."""
    pts = {k: rot(p, yaw, pitch, roll, elev) for k, p in V.items()}
    xs = [p[0] for p in pts.values()]; ys = [p[1] for p in pts.values()]
    span = 10.6                                   # model units across the sprite
    sx = width / span; sy = sx / 1.5
    anchor = rot((0.0, 0.3, -4.0), yaw, pitch, 0.0, elev)       # rear skirt centre sits above the shadow
    cx = width / 2 - anchor[0] * sx; cy = height - 1.6 - lift + anchor[1] * sy
    def scr(p): return (cx + p[0] * sx, cy - p[1] * sy)
    img = [[None] * width for _ in range(height)]
    zb = [[1e9] * width for _ in range(height)]
    for idx, col in faces(var):
        P = [pts[i] for i in idx]
        S = [scr(p) for p in P]
        for t in range(1, len(P) - 1):                     # triangle fan, z-buffered
            tri = (S[0], S[t], S[t + 1]); zs = (P[0][2], P[t][2], P[t + 1][2])
            (x0, y0), (x1, y1), (x2, y2) = tri
            den = (y1 - y2) * (x0 - x2) + (x2 - x1) * (y0 - y2)
            if abs(den) < 1e-9: continue
            for y in range(height):
                for x in range(width):
                    px, py = x + 0.5, y + 0.5
                    a1 = ((y1 - y2) * (px - x2) + (x2 - x1) * (py - y2)) / den
                    a2 = ((y2 - y0) * (px - x2) + (x0 - x2) * (py - y2)) / den
                    a3 = 1 - a1 - a2
                    if min(a1, a2, a3) < -1e-6: continue
                    z = a1 * zs[0] + a2 * zs[1] + a3 * zs[2]
                    if z < zb[y][x] - 0.05:
                        zb[y][x] = z
                        img[y][x] = col[(x + y) & 1] if isinstance(col, tuple) else col
    if var.get('rim') is not None:
        for y in range(height):
            for x in range(width):
                if img[y][x] is not None and img[y][x] != var['glow'] and (y == 0 or img[y - 1][x] is None):
                    img[y][x] = var['rim']
    return img

def inside(px, py, S):
    n = len(S); c = False
    for i in range(n):
        x1, y1 = S[i]; x2, y2 = S[(i + 1) % n]
        if (y1 > py) != (y2 > py) and px < (x2 - x1) * (py - y1) / (y2 - y1) + x1: c = not c
    return c

def shadow(width, height, w_frac=0.8):
    """Dithered shadow ellipse on the bottom two rows."""
    sh = [[False] * width for _ in range(height)]
    a = width * w_frac / 2; cx = width / 2
    for y, k in ((height - 2, 0.85), (height - 1, 1.0)):
        for x in range(width):
            if abs(x + 0.5 - cx) <= a * k and (x + y) & 1: sh[y][x] = True
    return sh

# 7 views: hard left .. hard right (yaw + bank), and nose up / down for crests and dips
VIEWS = [(-0.48, 0.30), (-0.32, 0.20), (-0.16, 0.10), (0.0, 0.0), (0.16, -0.10), (0.32, -0.20), (0.48, -0.30)]
PITCH = {'level': 0.0, 'nose up': -0.22, 'nose down': 0.22}

def frame(var, view, pitch='level', width=24, height=10, lift=1):
    yaw, roll = VIEWS[view]
    img = render(var, yaw, PITCH[pitch], roll, width, height, lift)
    if width >= 12:
        sh = shadow(width, height)
        for y in range(height):
            for x in range(width):
                if img[y][x] is None and sh[y][x]: img[y][x] = 'sh'
    return img

# hand-drawn distant views (rendering is too coarse at this size); G = team glow colour
FAR10 = {'L': ["...22.....", "..2222....", ".222222...", "2GGGGGG2..", ".........."],
         'S': ["....22....", "...2222...", "..222222..", ".2GGGGGG2.", ".........."],
         'R': [".....22...", "....2222..", "...222222.", "..2GGGGGG2", ".........."]}
FAR6 = {'L': [".22...", "2222..", "GGGG.."], 'S': ["..22..", ".2222.", ".GGGG."], 'R': ["...22.", "..2222", "..GGGG"]}

def far(sz, view, glow, body=2):
    rows = (FAR10 if sz == 10 else FAR6)[view]
    return [[None if c == '.' else (glow if c == 'G' else body) for c in r] for r in rows]

# ---------------------------------------------------------------- sheet
CSS0 = [(40, 205, 40), (235, 235, 70), (45, 35, 205), (205, 30, 60)]

def paint(draw, img, ox, oy, px=6, py=9, bg=True):
    for y, row in enumerate(img):
        for x, c in enumerate(row):
            X, Y = ox + x * px, oy + y * py
            if c is None:
                if not bg: continue
                col = CSS0[0]                                  # track surface behind
            elif c == 'sh':
                col = CSS0[2]
            else:
                col = CSS0[c]
            draw.rectangle([X, Y, X + px - 1, Y + py - 1], fill=col)

if __name__ == '__main__':
    W = 1180; H = 1100
    im = Image.new('RGB', (W, H), (24, 24, 30)); d = ImageDraw.Draw(im)
    d.text((16, 10), 'MAX Q hovercraft - sprite sheet (VZ mode 1, colour set 0, shown at real pixel shape)', fill=(230, 230, 230))
    y0 = 40
    for title, var in (('PLAYER', PLAYER), ('RIVAL A', RIVAL_A), ('RIVAL B', RIVAL_B)):
        d.text((16, y0), title + ' - 24x10, 7 views hard left .. hard right (banking into the turn)', fill=(230, 230, 230))
        for v in range(7):
            paint(d, frame(var, v), 16 + v * 160, y0 + 18)
        y0 += 18 + 100
    d.text((16, y0), 'PLAYER - straight / slight turn: nose up (cresting), level, nose down (dipping); hover bob = 1 px lift over the shadow', fill=(230, 230, 230))
    x = 16
    for v in (3, 4):
        for p in ('nose up', 'level', 'nose down'):
            paint(d, frame(PLAYER, v, p), x, y0 + 18); x += 160
    for lift in (0, 2):
        paint(d, frame(PLAYER, 3, 'level', lift=lift), x, y0 + 18); x += 160
    y0 += 18 + 110
    d.text((16, y0), 'RIVALS further away - 16x7 rendered (2-4 sections ahead), then 10x5 and 6x3 hand-drawn (4-15 sections): red team, blue team', fill=(230, 230, 230))
    x = 16
    for var in (RIVAL_A, RIVAL_B):
        for v in (1, 3, 5):
            paint(d, frame(var, v, width=16, height=7), x, y0 + 18); x += 112
    y0 += 18 + 76
    x = 16
    for glow, body in ((1, 3), (3, 2)):
        for v in 'LSR':
            paint(d, far(10, v, glow, body), x, y0); x += 72
        for v in 'LSR':
            paint(d, far(6, v, glow, body), x, y0); x += 50
    y0 += 64
    # in context: a real rendered track frame with the craft dropped in
    import ref3 as R
    T = R.build_track()
    for n, (i, lat) in enumerate(((60, 0), (150, 10))):
        fr, hz = R.render(T, dict(i=i, f=0, lat=lat, theta=0)); scr = R.compose(fr)
        pix = [[(scr[y * 32 + x // 4] >> (6 - 2 * (x % 4))) & 3 for x in range(128)] for y in range(64)]
        def put(img, ox, oy):
            for yy, row in enumerate(img):
                for xx, c in enumerate(row):
                    if c is not None and 0 <= oy + yy < 64 and 0 <= ox + xx < 128:
                        pix[oy + yy][ox + xx] = 2 if c == 'sh' else c
        put(far(6, 'S', 3, 2), 70, 38); put(far(10, 'R', 1, 3), 52, 41); put(frame(RIVAL_B if n else RIVAL_A, 4, width=16, height=7), 74, 43)
        put(frame(PLAYER, 3 if n == 0 else 5), 52, 52)
        paint(d, pix, 16 + n * 580, y0 + 18, px=4, py=6, bg=False)
    d.text((16, y0), 'IN CONTEXT - mock-ups on real rendered track frames (positions placed by hand)', fill=(230, 230, 230))
    im.save('hover_sheet.png')
    print('ok')
