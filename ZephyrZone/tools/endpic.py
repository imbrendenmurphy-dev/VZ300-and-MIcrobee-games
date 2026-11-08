"""The finale picture (128 x 64, CSS0): CONGRATULATIONS over a dawn sky, Zephyr waving on a
golden podium in the middle of the checker plain with friends from every world around him.
Fireworks and the message lines are drawn over it at run time."""
import math, random
import creatures as CR, font70
from draw import Canvas, crop
from titlepic import zephyr_waving
G, Y, B, R = 0, 1, 2, 3
W, H, HZ = 128, 64, 40
def picture():
    rnd = random.Random(5)
    HZ = 37
    p = [[B] * W for _ in range(H)]
    for _ in range(36):                                  # stars
        x, y = rnd.randrange(W), rnd.randrange(0, 30)
        p[y][x] = Y
    for y in range(33, HZ):                              # a thin dawn glow on the horizon
        for x in range(W):
            if (x + y * 2) % (5 - (y - 33)) == 0 or y == HZ - 1: p[y][x] = R
    for y in range(HZ, H):                               # the checker plain
        d = y - HZ + 1
        z = 160.0 * 26 / d
        for x in range(W):
            u = (x - 64) * z / 64.0
            a = int(math.floor(u / 64.0)) + int(math.floor(z / 90.0))
            p[y][x] = Y if a & 1 else G
    def put(g, cx, by, ax=None):
        h = len(g); w = len(g[0]); ax = w // 2 if ax is None else ax
        for yy in range(h):
            for xx in range(w):
                v = g[yy][xx]
                X = cx - ax + xx; Yy = by - h + 1 + yy
                if v >= 0 and 0 <= X < W and 0 <= Yy < H: p[Yy][X] = v
    def blit(name, f, s, cx, by): put(crop(CR.render(name, f, s))[0], cx, by)
    def shadow(cx, by, rx):
        for yy in (-1, 0, 1):
            for xx in range(-rx, rx + 1):
                if (xx / rx) ** 2 + (yy / 1.6) ** 2 <= 1 and (cx + xx + by + yy) & 1: p[by + yy][cx + xx] = B
    # friends from the five worlds, gathered round
    shadow(13, 49, 11); blit('snailops', 0, 0.42, 13, 49)
    shadow(114, 49, 11); blit('gunmech', 1, 0.42, 113, 49)
    shadow(36, 48, 6); blit('cactoid', 1, 0.55, 36, 48)
    shadow(92, 48, 6); blit('hopcap', 0, 0.55, 92, 48)
    blit('blobbit', 1, 0.42, 30, 27)
    blit('glowmoth', 0, 0.42, 98, 27)
    # the golden podium and ZEPHYR, waving
    for y in range(45, 51):
        w = 11 + (y - 45)
        for x in range(64 - w, 64 + w):
            p[y][x] = R if y in (45, 50) or x in (64 - w, 64 + w - 1) else (Y if (x + y) % 4 else R)
    c = Canvas(44, 44, 22, 30)
    zephyr_waving(c)
    z = c.resolve(prio=(R, B, Y, G), outline=3)
    put(z, 64, 45 + (len(z) - 1 - 30) - 6, ax=22)
    # CONGRATULATIONS
    rows = [0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 7]
    g = font70.styled(font70.text_mask('CONGRATULATIONS', 1, rows), split=6)
    put(g, 64, 2 + len(g) - 1)
    return p
def pack(p):
    out = bytearray()
    for row in p:
        for b in range(32):
            v = 0
            for i in range(4): v |= row[b * 4 + i] << (6 - 2 * i)
            out.append(v)
    return bytes(out)
