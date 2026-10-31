"""Distant scenery panoramas, 256 x 16, rows 12-27 of the screen.
pack(): 2 phases (0, shifted 2 px) x 16 rows x 64 bytes."""
import math, os

def pack(img):
    out = bytearray()
    for ph in (0, 2):
        for y in range(16):
            row = [img[y][(x + ph) % 256] for x in range(256)]
            for b in range(64):
                v = 0
                for i in range(4): v = (v << 2) | row[b * 4 + i]
                out.append(v)
    return out

def blank(c): return [[c] * 256 for _ in range(16)]
def wave(x, *terms):
    return sum(a * math.sin(x / p + ph) for a, p, ph in terms)

def sky_bands(img, top, bands):
    """bands: list of (rows, colour a, colour b, density 0..4)"""
    y = top
    for rows, a, b, d in bands:
        for _ in range(rows):
            if y >= 16: return
            for x in range(256):
                img[y][x] = b if d and ((x + y * 2) % 4) < d else a
            y += 1

def leg_pano(leg):
    G, Y, B, R = 0, 1, 2, 3
    if leg == 0:        # sunset coast: blue sky -> golden haze, sun, headlands, sea
        img = blank(B)
        sky_bands(img, 0, [(3, B, B, 0), (2, B, Y, 1), (2, B, Y, 2), (2, Y, B, 1), (2, Y, Y, 0)])
        cx = 150
        for y in range(4, 11):
            for x in range(256):
                if (x - cx) ** 2 * 0.6 + (y - 11) ** 2 * 6 < 60: img[y][x] = R
        for y in (7, 9):
            for x in range(cx - 10, cx + 11): img[y][x] = Y
        for x in range(256):   # headlands (green with red cliff faces) left/right
            h = int(4 + wave(x, (2.5, 11, 0), (1.5, 4.7, 1)))
            if not (60 < x < 210): h += 3
            else: h -= 3
            for y in range(16 - max(0, h), 14):
                img[y][x] = G if (y - (16 - h)) < 2 else (R if (x // 3 + y) % 5 else G)
            for y in (14, 15):  # sea with glints
                img[y][x] = Y if (x * 7 + y * 13) % 11 == 0 else B
        return pack(img)
    if leg == 1:        # red centre: deep blue sky, the monolith, mesas
        img = blank(B)
        sky_bands(img, 0, [(9, B, B, 0), (2, B, Y, 1), (1, Y, B, 2)])
        for x in range(256):
            h = int(2 + wave(x, (1, 9, 0)))
            if 90 < x < 150:   # monolith: rounded loaf
                t = (x - 120) / 30.0
                h = int(9 * math.sqrt(max(0, 1 - t ** 4)))
            if 200 < x < 230: h = 5 if 204 < x < 226 else 3
            if 20 < x < 40: h = 4
            for y in range(16 - h, 16):
                img[y][x] = R if (x + y) % 7 else Y
            img[15][x] = R
        return pack(img)
    if leg == 2:        # rainforest: layered green ranges in mist
        img = blank(B)
        sky_bands(img, 0, [(4, B, B, 0), (2, B, Y, 1)])
        for x in range(256):
            h1 = int(10 + wave(x, (2.5, 13, 0), (1.5, 5.1, 2)))
            h2 = int(6 + wave(x, (2, 7, 1), (1, 3.1, 0)))
            for y in range(16 - h1, 16): img[y][x] = Y if (x + y) % 2 else G   # far: misty
            for y in range(16 - h2, 16): img[y][x] = G if (x * 3 + y) % 9 else Y
        return pack(img)
    if leg == 3:        # snowy range at dusk (set 1: 0 buff 1 cyan 2 magenta 3 orange)
        img = blank(2)
        sky_bands(img, 0, [(3, 2, 2, 0), (2, 2, 3, 1), (2, 3, 2, 1), (2, 3, 3, 0)])
        for x in range(256):
            h = int(9 + wave(x, (4, 17, 0), (2, 6.3, 1), (1, 2.9, 2)))
            top = 16 - h
            for y in range(top, 16):
                d = y - top
                img[y][x] = 0 if d < 2 + (x % 3 == 0) else (1 if (x + y) % 3 else 0)
        return pack(img)
    # harbour lights at night (set 1)
    img = blank(2)
    sky_bands(img, 0, [(6, 2, 2, 0), (2, 2, 3, 1)])
    for k in range(40):
        x = (k * 53) % 256; y = (k * 7) % 5
        img[y][x] = 0
    r = 7
    for x in range(256):
        h = 3 + ((x // 9) * 37 % 9)
        if 120 < x < 200: h = max(2, h - 4)
        for y in range(16 - h, 16):
            img[y][x] = 3 if ((x % 3 == 1) and (y % 2 == 0)) else 1 if (x // 9) % 2 else 2
            if img[y][x] == 2: img[y][x] = 1
    for x in range(120, 200):   # the bridge arch
        t = (x - 160) / 40.0
        y = int(4 + 7 * t * t)
        if 0 <= y < 16: img[y][x] = 0
        if 0 <= y + 1 < 16: img[y + 1][x] = 0
        if x % 6 == 0:
            for yy in range(y, 13): img[yy][x] = 0
    for x in range(256): img[13][x] = 0 if x % 2 else 3
    for y in (14, 15):
        for x in range(256): img[y][x] = 3 if (x * 5 + y) % 13 == 0 else 2
    return pack(img)

if __name__ == '__main__':
    B = os.path.join(os.path.dirname(__file__), '..', 'build')
    open(os.path.join(B, 'pano_test.bin'), 'wb').write(leg_pano(0))
