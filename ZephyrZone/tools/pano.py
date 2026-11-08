"""Panoramas: 256 x 12 pixels, wrapping, opaque (sky colour behind)."""
import math, random
def world1():
    """CHECKER PLAINS: rolling green hills, round trees and far candy towers"""
    W, H = 256, 12
    SKY, G, Y, R = 2, 0, 1, 3
    p = [[SKY] * W for _ in range(H)]
    rnd = random.Random(7)
    # far hills (yellow-dithered)
    for x in range(W):
        h = 4 + 2.2 * math.sin(x * 2 * math.pi / 256 * 3 + 0.5) + 1.4 * math.sin(x * 2 * math.pi / 256 * 7)
        for y in range(H):
            if y >= H - int(h + 3):
                p[y][x] = G if ((x + y) & 1) else Y
    # near hills (green)
    for x in range(W):
        h = 2.5 + 1.8 * math.sin(x * 2 * math.pi / 256 * 5 + 2) + 1.0 * math.sin(x * 2 * math.pi / 256 * 11 + 1)
        for y in range(H):
            if y >= H - int(h):
                p[y][x] = G
    # little round trees and two candy towers
    for tx in (14, 40, 73, 121, 150, 188, 230):
        base = H - 3
        for yy in range(base - 4, base + 1):
            for xx in range(tx - 2, tx + 3):
                if (xx - tx) ** 2 + (yy - (base - 2)) ** 2 * 1.6 <= 5:
                    p[yy][xx % W] = G
        p[base + 1][tx % W] = R
    for tx in (95, 205):
        for yy in range(1, H - 2):
            for xx in (tx, tx + 1):
                p[yy][xx] = R if (yy % 3) else Y
        for xx in range(tx - 1, tx + 3): p[1][xx] = Y
        p[0][tx] = R; p[0][tx + 1] = R
    return p
def world2():
    """SUNSET DUNES: a low red sun, rolling dunes and far pyramids (CSS1: 0 buff 1 cyan 2 magenta 3 orange)"""
    W, H = 256, 12
    SKY, BF, MG, OR = 1, 0, 2, 3
    p = [[SKY] * W for _ in range(H)]
    # the sun, half sunk behind the dunes, with stripes across it
    for y in range(H):
        for x in range(W):
            if (x - 60) ** 2 + ((y - 9) * 1.5) ** 2 <= 64:
                p[y][x] = OR if (y % 3) else SKY
    # far pyramids
    for px_, h in ((120, 9), (134, 6), (212, 8)):
        for y in range(H - h, H):
            hw = y - (H - h)
            for x in range(px_ - hw, px_ + hw + 1):
                p[y][x % W] = MG if x < px_ else OR
    # dunes: two layers
    for x in range(W):
        h = 3 + 1.6 * math.sin(x * 2 * math.pi / 256 * 4 + 1) + 1.0 * math.sin(x * 2 * math.pi / 256 * 9)
        for y in range(H):
            if y >= H - int(h + 2): p[y][x] = OR if ((x + y) & 1) else BF
    for x in range(W):
        h = 2 + 1.2 * math.sin(x * 2 * math.pi / 256 * 6 + 3)
        for y in range(H):
            if y >= H - int(h): p[y][x] = BF
    # a few cactus silhouettes
    for tx in (24, 90, 170, 240):
        for y in range(H - 6, H): p[y][tx] = MG
        p[H - 4][tx - 1] = MG; p[H - 5][tx - 1] = MG; p[H - 3][tx + 1] = MG; p[H - 4][tx + 1] = MG
    return p
def world3():
    """CRYSTAL NIGHT: jagged crystal ranges under a red sky, a pale moon (CSS0: 0 green 1 yellow 2 blue 3 red)"""
    W, H = 256, 12
    SKY, G, Y, B = 3, 0, 1, 2
    p = [[SKY] * W for _ in range(H)]
    rnd = random.Random(11)
    for y in range(4):
        for x in range(W):
            if (x - 180) ** 2 + ((y - 1.5) * 1.5) ** 2 <= 6: p[y][x] = Y
    for _ in range(18):
        x, y = rnd.randrange(W), rnd.randrange(5)
        if p[y][x] == SKY: p[y][x] = Y
    # far ridge of crystal spikes
    x = 0
    while x < W:
        h = rnd.randint(4, 10); w = rnd.randint(3, 6)
        for i in range(-w, w + 1):
            top = H - h + abs(i) * h // (w + 1)
            for y in range(max(0, top), H):
                p[y][(x + i) % W] = B if i <= 0 else G
        x += rnd.randint(5, 12)
    # near ground glow line
    for x in range(W):
        p[H - 1][x] = G if (x & 1) else B
    return p
def world4():
    """NEON CITY: a jagged skyline with lit windows against an orange dusk (CSS1)"""
    W, H = 256, 12
    BF, CY, MG, SKY = 0, 1, 2, 3
    p = [[SKY] * W for _ in range(H)]
    rnd = random.Random(4)
    x = 0
    while x < W:
        w = rnd.randint(4, 9); h = rnd.randint(4, 12); col = MG if rnd.random() < 0.6 else BF
        for xx in range(x, x + w):
            for y in range(H - h, H):
                p[y][xx % W] = col
        for y in range(H - h + 1, H - 1, 2):
            for xx in range(x + 1, x + w - 1, 2):
                if rnd.random() < 0.5: p[y][xx % W] = CY
        if h > 9: p[H - h - 1][(x + w // 2) % W] = CY
        x += w + rnd.randint(0, 2)
    return p
def world5():
    """MUSHROOM MARSH: giant toadstool silhouettes over soft hills (CSS0, yellow sky)"""
    W, H = 256, 12
    G, SKY, B, R = 0, 1, 2, 3
    p = [[SKY] * W for _ in range(H)]
    for x in range(W):
        h = 3 + 1.5 * math.sin(x * 2 * math.pi / 256 * 5) + math.sin(x * 2 * math.pi / 256 * 13 + 1)
        for y in range(H):
            if y >= H - int(h + 1): p[y][x] = B if (x + y) & 1 else G
    for cx, h, r in ((20, 10, 5), (70, 8, 4), (112, 11, 6), (170, 9, 4), (215, 10, 5)):
        for y in range(H - h, H): p[y][cx] = G; p[y][cx + 1] = G
        for y in range(H - h - 2, H - h + 2):
            for xx in range(cx - r, cx + r + 2):
                if ((xx - cx - 0.5) / (r + 0.5)) ** 2 + ((y - (H - h)) / 2.2) ** 2 <= 1 and y < H - h + 1:
                    p[y][xx % W] = R
    for x in range(W): p[H - 1][x] = G
    return p
def pack(p, SKYB=None):
    """2 phases x 12 rows x 96 bytes (384 px: the 256 wrap + 128 more)"""
    out = bytearray()
    for ph in (0, 2):
        for row in p:
            px = [row[(i + ph) % 256] for i in range(384)]
            for b in range(96):
                v = 0
                for i in range(4): v |= px[b * 4 + i] << (6 - 2 * i)
                out.append(v)
    return bytes(out)
