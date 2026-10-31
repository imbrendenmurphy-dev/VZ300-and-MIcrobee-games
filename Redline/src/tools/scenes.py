"""Stage intro pictures (mode 1, 128x64) streamed from SD: RLnP.DAT.
Each is a stylised view of a locality the route passes through - not a race
scene.  Rows 57-63 are left as a slim band for the stage name.
Colour set 0: G=0 Y=1 B=2 R=3   colour set 1: buff=0 cyan=1 magenta=2 orange=3"""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(__file__))
import legs
from PIL import Image

W, H = 128, 64
BAND = 57
PICVAR = 0xCBFF
BAY = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def canvas(c): return [[c] * W for _ in range(H)]
def dith(x, y, t): return BAY[y % 4][x % 4] < t * 16          # t 0..1
def grad(img, y0, y1, a, b, t0=0.0, t1=1.0):
    for y in range(y0, y1):
        t = t0 + (t1 - t0) * (y - y0) / max(1, (y1 - y0 - 1))
        for x in range(W): img[y][x] = b if dith(x, y, t) else a
def ridge(fn, x): return fn(x)
def fill_below(img, top, c, y1=BAND, pat=None):
    for x in range(W):
        for y in range(max(0, int(top(x))), y1):
            img[y][x] = pat(x, y) if pat else c
def disc(img, cx, cy, r, c, ys=1.0, clip_y=None):
    for y in range(int(cy - r / ys) - 1, int(cy + r / ys) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if 0 <= x < W and 0 <= y < H and (clip_y is None or y < clip_y):
                if (x - cx) ** 2 + ((y - cy) * ys) ** 2 <= r * r: img[y][x] = c

def coast():          # headland with lighthouse at sunset, sea and surf
    G, Y, B, R = 0, 1, 2, 3
    img = canvas(B)
    grad(img, 0, 30, B, Y, 0.0, 0.85)
    disc(img, 84, 30, 11, R, 1.0, clip_y=30)
    for y in (22, 25, 28):
        for x in range(70, 99):
            if img[y][x] == R: img[y][x] = Y
    for y in range(30, BAND):                 # sea: blue with glints, sun path
        for x in range(W):
            c = B
            if abs(x - 84) < 10 - (y - 30) * 0.2 and (x + y) % 3 == 0: c = Y
            elif (x * 7 + y * 13) % 61 == 0: c = Y
            img[y][x] = c
    for y in range(40, BAND, 4):              # surf lines
        for x in range(W):
            if (x + y * 3) % 17 < 3: img[y][x] = Y
    head = lambda x: 22 + 0.004 * (x - 10) ** 2 if x < 64 else 99
    for x in range(64):                       # headland: green top, red cliff face
        top = int(26 + 0.0045 * x * x)
        for y in range(top, BAND):
            d = y - top
            img[y][x] = G if d < 3 else (Y if (x * 5 + y * 3) % 29 == 0 else R)
    for x in range(0, 70):                    # the cliff base surf
        y = int(26 + 0.0045 * x * x) + 18
        if 30 < y < BAND: img[y][x] = Y
    lx = 26                                   # lighthouse
    for y in range(8, 30):
        w = 2 + (y - 8) // 7
        for x in range(lx - w, lx + w + 1):
            img[y][x] = R if ((y - 8) // 4) % 2 == 0 else Y
    for x in range(lx - 3, lx + 4): img[7][x] = R
    for x in range(lx - 2, lx + 3): img[6][x] = Y
    for x in range(lx - 1, lx + 2): img[5][x] = R
    for k in range(1, 20):                    # beam
        y = 6 - k // 6
        if 0 <= y: img[y][lx + 3 + k] = Y if k % 2 else img[y][lx + 3 + k]
    for (x, y) in ((100, 10), (108, 8), (116, 12), (60, 6)):   # gulls
        img[y][x] = img[y][x + 2] = R; img[y - 1][x + 1] = R if False else img[y - 1][x + 1]
        img[y + 1][x + 1] = R
    return img

def outback():        # the monolith at dusk, desert oaks, spinifex
    G, Y, B, R = 0, 1, 2, 3
    img = canvas(B)
    grad(img, 0, 34, B, Y, 0.0, 0.9)
    for x in range(W):                        # monolith: rounded loaf
        t = (x - 70) / 38.0
        if abs(t) < 1:
            h = 16 * math.sqrt(1 - t ** 4)
            top = 36 - h
            for y in range(int(top), 37):
                gully = (x * 3 + int(y)) % 17 == 0 and y > top + 3
                img[y][x] = Y if (y - top < 1.5 and t < 0) else (B if gully else R)
    for x in range(W):                        # far mesas
        if 4 < x < 26:
            for y in range(31, 37): img[y][x] = R if (x + y) % 5 else B
    for y in range(37, BAND):                 # red sand with dither ripples
        for x in range(W):
            img[y][x] = Y if dith(x, y, 0.06 + 0.06 * math.sin(x / 6 + y / 2)) else R
    r = random.Random(3)
    for k in range(18):                       # spinifex tufts
        x = r.randint(0, W - 4); y = r.randint(42, BAND - 2)
        for dx, dy in ((0, 0), (1, -1), (2, 0), (3, -1), (1, 0), (2, -1)):
            if 0 <= x + dx < W: img[y + dy][x + dx] = G
    for tx in (18, 112):                      # desert oaks
        for y in range(36, 50): img[y][tx] = R if y % 3 else Y
        disc(img, tx, 34, 6, G, 1.6); disc(img, tx + 3, 32, 4, G, 1.6)
    disc(img, 30, 8, 4, Y, 1.4)               # rising moon
    return img

def rainforest():     # layered ridges in mist, waterfall, tree ferns
    G, Y, B, R = 0, 1, 2, 3
    img = canvas(B)
    grad(img, 0, 22, B, Y, 0.0, 0.5)
    layers = [(18, 6, Y, 0.55), (24, 7, G, 0.35), (32, 8, G, 0.0)]
    for base, amp, c, mist in layers:
        for x in range(W):
            top = base + amp * math.sin(x / 13.0 + base) + 3 * math.sin(x / 5.0 + base * 2)
            for y in range(int(top), BAND):
                img[y][x] = Y if dith(x, y, mist) else c
    for y in range(26, 52):                   # waterfall
        for x in range(60, 66):
            img[y][x] = Y if (y * 2 + x) % 5 else B
    for y in range(50, 56):
        for x in range(54, 72): img[y][x] = Y if (x + y) % 2 else B
    for tx, h in ((8, 30), (26, 20), (104, 28), (120, 22)):   # tall trees in front
        for y in range(BAND - h, BAND): img[y][tx] = R if y % 4 else Y
        disc(img, tx, BAND - h, 7, G, 1.3)
        disc(img, tx - 3, BAND - h + 4, 5, G, 1.3)
        for k in range(6): img[BAND - h - 3 + k][tx + 4 - k % 2] = Y if k % 2 else G
    for fx in (40, 86):                       # tree ferns
        for y in range(44, BAND): img[y][fx] = R
        for a in range(-4, 5):
            x = fx + a * 2
            y = 43 + abs(a) // 2
            if 0 <= x < W: img[y][x] = G; img[y + 1][x] = G if a % 2 else Y
    return img

def snowy():          # alpine peaks at dusk, pines, a hut with a lit window (set 1)
    BF, CY, MG, OR = 0, 1, 2, 3
    img = canvas(MG)
    grad(img, 0, 30, MG, OR, 0.1, 0.8)
    def peak(cx, h, w):
        for x in range(W):
            d = abs(x - cx) / w
            if d < 1:
                top = 34 - h * (1 - d)
                for y in range(int(top), 40):
                    snow = y - top < 4 + 2 * math.sin(x * 1.7)
                    img[y][x] = BF if snow or (x < cx and (x + y) % 4 == 0) else CY
    peak(30, 26, 34); peak(78, 30, 40); peak(112, 20, 26)
    for y in range(38, BAND):                 # snowfield
        for x in range(W):
            img[y][x] = CY if dith(x, y, 0.12) else BF
    for px, h in ((10, 16), (18, 11), (98, 15), (108, 19), (120, 12)):   # pines
        for y in range(BAND - h, BAND):
            w = (y - (BAND - h)) // 2
            for x in range(px - w, px + w + 1):
                if 0 <= x < W: img[y][x] = CY if (x + y) % 5 else BF
        img[BAND - 1][px] = OR
    for y in range(44, 53):                   # hut
        for x in range(54, 72): img[y][x] = OR
    for k in range(9):
        for x in range(52 + k, 74 - k): img[44 - k // 2][x] = BF
    for y in (47, 48):
        for x in (58, 59, 66, 67): img[y][x] = CY
    for y in (35, 36, 37, 38, 39): img[y][69] = OR      # chimney + smoke
    for k, (x, y) in enumerate(((70, 32), (72, 29), (71, 26), (74, 23))): img[y][x] = BF
    return img

def harbour():        # city skyline, the bridge arch, reflections (set 1, night)
    BF, CY, MG, OR = 0, 1, 2, 3
    img = canvas(MG)
    r = random.Random(7)
    for k in range(30): img[r.randint(0, 20)][r.randint(0, W - 1)] = BF
    disc(img, 108, 9, 4, BF, 1.4)
    for x in range(W):                        # skyline
        bw = 6 + (x // 7) % 3
        h = [18, 26, 14, 30, 22, 12, 34, 20, 16, 28, 10, 24, 18, 30, 14, 22, 26, 12, 20][(x // 7) % 19]
        if 40 < x < 92: h = h // 2
        for y in range(40 - h, 40):
            win = (x % 3 == 1) and (y % 3 == 0) and ((x * 5 + y * 3) % 7 != 0)
            img[y][x] = OR if win else CY
    for x in range(W): img[39][x] = CY
    for x in range(20, 112):                  # the arch bridge
        t = (x - 66) / 46.0
        y = int(22 + 14 * t * t)
        img[y][x] = BF; img[y + 1][x] = BF
        if x % 5 == 0:
            for yy in range(y, 34): img[yy][x] = BF
    for x in range(10, 122): img[34][x] = BF; img[35][x] = OR if x % 4 == 0 else BF
    for y in range(40, BAND):                 # water with reflections
        for x in range(W):
            src = img[79 - y][x] if 79 - y > 0 else MG
            ripple = (x + y * 2) % 5 == 0
            img[y][x] = src if (src in (OR, BF) and not ripple and (y % 2 == 0)) else MG
    return img

SCENES = [coast, outback, rainforest, snowy, harbour]

def picture(leg):
    img = SCENES[leg]()
    L = legs.LEGS[leg]
    band = L['big'][1] & 3
    for y in range(BAND, H):
        for x in range(W): img[y][x] = band
    return img

def pack(img):
    out = bytearray()
    for y in range(H):
        for b in range(32):
            v = 0
            for i in range(4): v = (v << 2) | img[y][b * 4 + i]
            out.append(v)
    return bytes(out)

def preview(img, css, fn):
    p0 = [(0x30, 0xd2, 0), (0xc1, 0xe5, 0), (0x4c, 0x3a, 0xb4), (0x9a, 0x32, 0x36)]
    p1 = [(0xbf, 0xc8, 0xad), (0x41, 0xaf, 0x71), (0xc8, 0x4e, 0xf0), (0xd4, 0x7f, 0)]
    p = p1 if css else p0
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W): im.putpixel((x, y), p[img[y][x]])
    im.resize((W * 4, H * 6), Image.NEAREST).save(fn)

def build():
    OUT = os.path.join(os.path.dirname(__file__), '..', 'release')
    B = os.path.join(os.path.dirname(__file__), '..', 'build')
    for leg in range(5):
        L = legs.LEGS[leg]
        img = picture(leg)
        latch = 0x08 | (0x10 if L['css'] else 0)
        d = legs.chunk(3, PICVAR, bytes([latch])) + legs.chunk(3, 0x7000, pack(img)) + b'\x00'
        open(os.path.join(OUT, 'RL%dP.DAT' % (leg + 1)), 'wb').write(d)
        preview(img, L['css'], os.path.join(B, 'scene%d.png' % (leg + 1)))

if __name__ == '__main__':
    build()
