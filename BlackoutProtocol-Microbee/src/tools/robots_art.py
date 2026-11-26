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

def frames():
    """[(name, height, bitmap)] in the order the game uses."""
    out = [('warden', 20, warden(p)) for p in range(4)]
    out.append(('warden_sleep', 20, warden(0, asleep=True)))
    out += [('spark', 6, spark(p)) for p in range(2)]
    out += [('steam', 24, steam(p)) for p in range(2)]
    out += [('laser', 24, laser(p)) for p in range(2)]
    return out

if __name__ == '__main__':
    fr = frames(); Z = 8
    sheet = Image.new('RGB', ((W + 3) * Z * len(fr), 26 * Z), (40, 20, 20))
    for k, (n, h, bm) in enumerate(fr):
        for y in range(h):
            for x in range(W):
                if bm[y][x]:
                    for a in range(Z - 1):
                        for b in range(Z - 1): sheet.putpixel((k * (W + 3) * Z + x * Z + a, y * Z + b), (255, 90, 90))
    sheet.save('build/robots_preview.png')
