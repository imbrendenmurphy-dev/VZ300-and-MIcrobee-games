"""The silent 'MZ-700 style' title picture: ZEPHYR in a scene with a GUNMECH,
a SNAILOPS and a BLOBBIT on the checker plain (128 x 64, CSS0), packed 4 px/byte.
The logo is not in the picture: it rolls in over it at run time."""
import math
import creatures as CR, hero as HE, pano, font
from draw import crop
G, Y, B, R = 0, 1, 2, 3
W, H, HZ = 128, 64, 31
def zephyr_waving(c):
    """ZEPHYR face on, chibi-style, sitting with his legs dangling, waving (origin = seat)"""
    # jet-pack nozzles behind the shoulders
    c.rect(-7, -15, -4, -6, R); c.rect(4, -15, 7, -6, R)
    c.rect(-6.5, -6, -4.5, -4, Y); c.rect(4.5, -6, 6.5, -4, Y)
    # dangling legs and boots
    c.capsule(-2.5, -1, -5, 1.5, 1.9, B); c.capsule(2.5, -1, 5, 1.5, 1.9, B)      # thighs, knees apart
    c.capsule(-5, 1.5, -4.5, 7, 1.7, B); c.capsule(5, 1.5, 5.5, 6, 1.7, B)        # shins swinging
    c.ellipse(-4.5, 8.5, 2.6, 1.6, Y); c.ellipse(5.8, 7.5, 2.6, 1.6, Y)
    # body, belt
    c.poly([(-5, -12), (5, -12), (4.5, 0), (-4.5, 0)], B)
    c.rect(-4.5, -3, 4.5, -1.5, Y)
    # resting arm (left) and the waving arm (right), gloves
    c.capsule(-5, -11, -7.5, -4, 1.5, B); c.circle(-7.5, -3.5, 1.8, Y)
    c.capsule(5, -11, 9.5, -19, 1.5, B); c.circle(10, -20.5, 2.2, Y)
    c.poly([(11.5, -23), (13, -24.5), (12.4, -21.5)], Y)            # wiggle
    # scarf streaming out to the left
    c.poly([(-3, -13), (3, -13), (2, -11), (-2, -11)], R)
    c.poly([(-3, -13), (-11, -15), (-12, -12), (-9, -13), (-3, -11)], R)
    # the bubble helmet with a grinning face inside
    c.circle(0, -18.5, 6.4, B)
    c.circle(0, -18.5, 5.2, Y)
    c.rect(-4.5, -24, 4.5, -21.5, R)                                  # hair fringe
    c.circle(-1.9, -19, 0.9, B); c.circle(1.9, -19, 0.9, B)
    c.poly([(-2.6, -16.5), (2.6, -16.5), (1.6, -14.6), (-1.6, -14.6)], R)   # big smile
    c.circle(3.8, -22.8, 0.9, Y)                                       # glint
LOGO_X, LOGO_Y = 1, 6          # final byte column and row of the one-line logo
def logo():
    """'ZEPHYR ZONE' on one line in the 70s face; green (0) = transparent"""
    import font70
    rows = [0, 0, 1, 2, 2, 3, 4, 4, 5, 6, 6, 7]
    g = font70.styled(font70.text_mask('ZEPHYR ZONE', 1, rows), split=7)
    w = (len(g[0]) + 3) // 4 * 4
    return [[(v if v >= 0 else 0) for v in r] + [0] * (w - len(r)) for r in g]
def picture():
    from draw import Canvas
    p = [[B] * W for _ in range(H)]
    HZ = 40
    pn = pano.world1()
    for y in range(12):
        for x in range(W):
            v = pn[y][(x + 40) % 256]
            if v != 2: p[HZ - 12 + y][x] = v
    for y in range(HZ, H):
        d = y - HZ + 1
        z = 160.0 * 30 / d
        for x in range(W):
            u = (x - 64) * z / 64.0
            a = int(math.floor(u / 64.0)) + int(math.floor(z / 90.0))
            p[y][x] = B if a & 1 else G
    def put(g, cx, by, ax=None, ay=None):
        h = len(g); w = len(g[0])
        ax = w // 2 if ax is None else ax
        ay = h - 1 if ay is None else ay
        for yy in range(h):
            for xx in range(w):
                v = g[yy][xx]
                X = cx - ax + xx; Yy = by - ay + yy
                if v >= 0 and 0 <= X < W and 0 <= Yy < H: p[Yy][X] = v
    def blit(g, cx, by): put(crop(g)[0], cx, by)
    def shadow(cx, by, rx):
        for yy in range(-1, 2):
            for xx in range(-rx, rx + 1):
                if (xx / rx) ** 2 + (yy / 1.6) ** 2 <= 1:
                    X, Yy = cx + xx, by + yy
                    if 0 <= X < W and 0 <= Yy < H and (X + Yy) & 1: p[Yy][X] = B
    blit(CR.render('lolly', 0, 0.6), 6, 48)
    blit(CR.render('bush', 0, 0.9), 48, 46)
    shadow(27, 58, 16); blit(CR.render('snailops', 0, 0.74), 26, 58)
    blit(CR.render('blobbit', 1, 0.5), 64, 44)
    shadow(104, 58, 14)
    mech = crop(CR.render('gunmech', 0, 0.72))[0]
    put(mech, 104, 58)
    c = Canvas(44, 44, 22, 30)
    c.push(0, 0, 0, 0.8, 0.8)
    zephyr_waving(c)
    c.pop()
    z = c.resolve(prio=(R, B, Y, G), outline=3)
    hull_top = 58 - int(50 * 0.72) + 2
    put(z, 114, hull_top + 3, ax=22, ay=30)
    txt = 'VIBED BY BPM 2026'
    for y in range(59, 64):
        for x in range(W): p[y][x] = R
    x0 = (W - len(txt) * 4 + 1) // 2
    for i, ch in enumerate(txt):
        gl = font.G[ch]
        for r in range(5):
            for cc in range(3):
                if gl[r][cc] == '1': p[59 + r][x0 + i * 4 + cc] = Y
    return p
def packed():
    """ZZTTL payload: picture (2048) + logo: db width (bytes), rows, then rows of bytes"""
    lg = logo()
    out = bytearray(pack(picture()))
    out += bytes([len(lg[0]) // 4, len(lg)])
    for r in lg:
        for b in range(len(r) // 4):
            v = 0
            for i in range(4): v |= r[b * 4 + i] << (6 - 2 * i)
            out.append(v)
    return bytes(out)
def pack(p):
    out = bytearray()
    for row in p:
        for b in range(32):
            v = 0
            for i in range(4): v |= row[b * 4 + i] << (6 - 2 * i)
            out.append(v)
    return bytes(out)
if __name__ == '__main__':
    from vzpal import to_img
    p = picture(); to_img(p).resize((128 * 4, 64 * 6)).save('build/titlepic.png')
