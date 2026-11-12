#!/usr/bin/env python3
"""art.py - sprite masters and the title logo for BUNYIP
VIBED BY BPM 2026

Every sprite is a small 1-bit picture with a mask: transparent, ink (drawn in
the creature's colour) or black (opaque).  Each is drawn here with simple
shapes, then given a one-pixel black outline so it stands out from walls.

The game shrinks every master to 16 sizes at start-up (src/prescale.asm);
this file also works out, for each size, the width and which source column
each output dot comes from, so the Z80 only copies bits.

  build/ART.BIN    RAM block 3
  build/artsym.inc image numbers and the directory layout
  build/art_*.png  previews
"""
import math, sys
from pathlib import Path
from PIL import Image, ImageDraw

T, K, I = 0, 1, 2          # transparent, black, ink
NS = 16
HS = [round(8 * 1.2 ** s) for s in range(NS)]     # heights of the 16 sizes (scanlines)
ASPECT = 0.75              # dots per scanline for a square shape


def canvas(w, h):
    return [[T] * w for _ in range(h)]


def from_draw(w, h, fn, ss=4):
    """draw at ss x size with PIL: fill 255 = ink, 128 = black; downsample"""
    im = Image.new('L', (w * ss, h * ss), 0)
    d = ImageDraw.Draw(im)
    fn(d, ss)
    c = canvas(w, h)
    px = im.load()
    for y in range(h):
        for x in range(w):
            ink = blk = 0
            for yy in range(ss):
                for xx in range(ss):
                    v = px[x * ss + xx, y * ss + yy]
                    if v >= 200:
                        ink += 1
                    elif v >= 64:
                        blk += 1
            n = ss * ss
            if ink * 2 >= n:
                c[y][x] = I
            elif (ink + blk) * 2 >= n:
                c[y][x] = K
    return c


def outline(c):
    h, w = len(c), len(c[0])
    o = [r[:] for r in c]
    for y in range(h):
        for x in range(w):
            if c[y][x] == T:
                for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < h and 0 <= xx < w and c[yy][xx] == I:
                        o[y][x] = K
                        break
    return o


def dither(c, box, every=2, phase=0, val=K):
    """turn ink in box to a checker of ink and val (shading)"""
    x0, y0, x1, y1 = box
    for y in range(max(0, y0), min(len(c), y1)):
        for x in range(max(0, x0), min(len(c[0]), x1)):
            if c[y][x] == I and (x + y + phase) % every == 0:
                c[y][x] = val


def S(v, ss):
    return [p * ss for p in v] if isinstance(v, (list, tuple)) else v * ss


# ------------------------------------------------------------------ creatures
def redback(frame):
    W, H = 32, 22

    def fn(d, ss):
        # legs: four each side, knees up, feet down
        for i in range(4):
            sw = 2 if (i + frame) % 2 else -1
            for side in (-1, 1):
                hx, hy = 16 + side * 3, 11 + i * 1.2
                kx, ky = 16 + side * (8 + i * 1.5), 3 + i * 2 + sw
                fx, fy = 16 + side * (12 + i * 1.2), 21 - abs(i - 1.5) * 1.5 + (sw if i % 2 else 0) * 0.5
                d.line(S([hx, hy, kx, ky], ss), fill=255, width=int(1.4 * ss))
                d.line(S([kx, ky, fx, fy], ss), fill=255, width=int(1.2 * ss))
        # abdomen behind, head in front
        d.ellipse(S([8.5, 3, 23.5, 15], ss), fill=255)
        d.ellipse(S([11.5, 10, 20.5, 18.5], ss), fill=255)
    c = from_draw(W, H, fn)
    dither(c, (8, 3, 24, 11))                  # dark abdomen ...
    for y, (a, b) in enumerate([(15, 17), (14, 18), (15, 17), (15, 17), (14, 18), (15, 17)]):
        for x in range(a, b):                   # ... with the bright hourglass
            c[4 + y][x] = I
    for x, y in ((13, 13), (18, 13), (14, 12), (17, 12)):
        c[y][x] = K                             # eyes
    for x in range(14, 18):
        c[16][x] = K                            # fangs line
    return outline(c)


def flyingfox(frame):
    W, H = 32, 22

    def fn(d, ss):
        if frame == 0:      # wings up and out
            wing = [(16, 9), (9, 2), (3, 5), (0, 12), (4, 10), (7, 14), (11, 11), (14, 15)]
        else:               # wings down
            wing = [(16, 9), (10, 11), (4, 13), (1, 20), (5, 17), (8, 20), (11, 16), (14, 17)]
        d.polygon([S(p, ss) for p in wing], fill=255)
        d.polygon([S((32 - x, y), ss) for x, y in wing], fill=255)
        d.ellipse(S([12.5, 6, 19.5, 18], ss), fill=255)        # body
        d.ellipse(S([12.5, 3, 19.5, 9.5], ss), fill=255)       # head
        d.polygon([S(p, ss) for p in ((12.5, 5), (13, 0.5), (15, 4))], fill=255)   # ears
        d.polygon([S(p, ss) for p in ((19.5, 5), (19, 0.5), (17, 4))], fill=255)
    c = from_draw(W, H, fn)
    for y in range(H):                          # wing membranes shaded, bones bright
        for x in range(W):
            if c[y][x] == I and not 12 <= x <= 19 and (x + y) % 2 == 0 and x % 5 != 2:
                c[y][x] = K
    for x, y in ((14, 6), (17, 6)):
        c[y][x] = K                             # eyes
    return outline(c)


def yowie(frame):
    W, H = 24, 32

    def fn(d, ss):
        d.ellipse(S([8.5, 1, 15.5, 8], ss), fill=255)          # head
        d.polygon([S(p, ss) for p in ((5, 9), (19, 9), (21, 20), (17, 22), (7, 22), (3, 20))], fill=255)  # torso
        d.rectangle(S([7, 21, 11, 31], ss), fill=255)          # legs
        d.rectangle(S([13, 21, 17, 31], ss), fill=255)
        d.ellipse(S([5, 29, 11.5, 32], ss), fill=255)           # feet
        d.ellipse(S([12.5, 29, 19, 32], ss), fill=255)
        d.line(S([5, 10, 2, 24], ss), fill=255, width=3 * ss)    # left arm
        if frame == 0:
            d.line(S([19, 10, 22, 24], ss), fill=255, width=3 * ss)
            d.ellipse(S([20, 22, 24, 26], ss), fill=255)
        else:                                                   # right arm up with a rock
            d.line(S([19, 10, 22, 1], ss), fill=255, width=3 * ss)
            d.ellipse(S([19, -1, 24, 4], ss), fill=128)
        d.ellipse(S([0, 22, 4, 26], ss), fill=255)
    c = from_draw(W, H, fn)
    import random
    rnd = random.Random(7)
    for y in range(9, H):                        # shaggy fur
        for x in range(W):
            if c[y][x] == I and rnd.random() < 0.18:
                c[y][x] = K
    for x, y in ((10, 4), (13, 4)):
        c[y][x] = K                              # eyes
    for x in range(10, 14):
        c[6][x] = K                              # mouth
    return outline(c)


def bunyip(frame):
    W, H = 40, 32

    def fn(d, ss):
        d.ellipse(S([3, 10, 37, 31], ss), fill=255)             # body
        d.ellipse(S([1, 26, 11, 32], ss), fill=255)             # flippers
        d.ellipse(S([29, 26, 39, 32], ss), fill=255)
        d.ellipse(S([10, 1, 30, 20], ss), fill=255)             # head
        d.polygon([S(p, ss) for p in ((11, 6), (6, 0), (14, 3))], fill=255)    # ears
        d.polygon([S(p, ss) for p in ((29, 6), (34, 0), (26, 3))], fill=255)
        if frame == 1:
            d.ellipse(S([14, 12, 26, 20], ss), fill=128)        # mouth open
    c = from_draw(W, H, fn)
    dither(c, (0, 21, 40, 32), every=2)          # dark belly
    for y in range(11, 21):
        for x in range(3, 37):
            if c[y][x] == I and (x * 3 + y * 5) % 7 == 0:
                c[y][x] = K                      # mottled hide
    for ex in (15, 24):                          # glowing eyes in dark sockets
        for y in range(6, 10):
            for x in range(ex - 2, ex + 3):
                c[y][x] = K
        c[7][ex] = c[8][ex] = I
        c[7][ex + 1] = I
    for tx in (16, 23):                          # tusks
        for y in range(13, 18 if frame else 16):
            c[y][tx] = I
            c[y][tx + 1] = I
    if frame == 1:
        for x in range(15, 26, 2):
            c[13][x] = I                         # teeth
    return outline(c)


# ------------------------------------------------------------------ items
def key(frame):
    c = from_draw(16, 16, lambda d, ss: (
        d.ellipse(S([1, 1, 9, 9], ss), fill=255),
        d.ellipse(S([3.5, 3.5, 6.5, 6.5], ss), fill=0),
        d.line(S([7, 7, 14, 14], ss), fill=255, width=2 * ss),
        d.line(S([10, 13, 12, 11], ss), fill=255, width=2 * ss),
        d.line(S([12, 15, 14.5, 12.5], ss), fill=255, width=2 * ss)))
    return outline(c)


def pie(frame):
    def fn(d, ss):
        d.ellipse(S([0, 5, 16, 15], ss), fill=255)
        d.ellipse(S([1, 3, 15, 11], ss), fill=255)
    c = from_draw(16, 16, fn)
    dither(c, (0, 4, 16, 9), every=3)           # flaky top
    for x in range(1, 15):
        if c[11][x] == I:
            c[11][x] = K                         # crust line
    for x, y in ((6, 6), (8, 5), (10, 6)):
        c[y][x] = K                              # steam holes
    return outline(c)


def charges(frame):
    def fn(d, ss):
        for i, x in enumerate((2, 6.5, 11)):
            top = 2 if i == 1 else 4
            d.polygon([S(p, ss) for p in ((x, top + 3), (x + 1.5, top), (x + 3, top + 3), (x + 3, 15), (x, 15))], fill=255)
    c = from_draw(16, 16, fn)
    for y in range(9, 16, 2):
        for x in range(16):
            if c[y][x] == I:
                c[y][x] = K                      # bands
    return outline(c)


def opal(frame):
    def fn(d, ss):
        d.polygon([S(p, ss) for p in ((8, 1), (15, 7), (8, 15), (1, 7))], fill=255)
    c = from_draw(16, 16, fn)
    dither(c, (0, 8, 16, 16), every=2)           # facets
    for x, y in ((6, 4), (5, 5), (7, 5), (6, 6)):
        if c[y][x] != T:
            c[y][x] = K
    c[5][6] = I                                   # sparkle
    return outline(c)


def rock(frame):
    c = from_draw(16, 16, lambda d, ss: d.ellipse(S([3, 3, 13, 13], ss), fill=255))
    dither(c, (0, 8, 16, 16), every=2)
    return outline(c)


def fireball(frame):
    def fn(d, ss):
        d.ellipse(S([2, 4, 14, 16], ss), fill=255)
        d.polygon([S(p, ss) for p in ((3, 9), (5, 0), (8, 6), (10, 1), (13, 9))], fill=255)
    c = from_draw(16, 16, fn)
    for y in range(16):
        for x in range(16):
            if c[y][x] == I and 6 <= x <= 9 and 8 <= y <= 12:
                c[y][x] = K                      # hot core (shown dark against the ink)
    return outline(c)


def weapon(frame):
    """the player's opal zapper, seen from behind, bottom centre of the view"""
    W, H = 32, 24

    def fn(d, ss):
        d.polygon([S(p, ss) for p in ((11, 24), (13, 9), (19, 9), (21, 24))], fill=255)   # barrel
        d.rectangle(S([12, 6, 20, 10], ss), fill=255)                                     # muzzle
        d.ellipse(S([6, 16, 26, 26], ss), fill=255)                                       # hands
        if frame:
            d.polygon([S(p, ss) for p in ((16, 0), (18.5, 4), (24, 3), (20, 7), (12, 7), (8, 3), (13.5, 4))], fill=255)
    c = from_draw(W, H, fn)
    for y in range(16, H):
        for x in range(W):
            if c[y][x] == I and (x + y) % 2:
                c[y][x] = K                      # gloves darker
    for y in range(10, 16):
        c[y][16] = K                             # barrel line
    c[7][16] = K if not frame else I
    return outline(c)


IMAGES = [   # name, function, frame
    ('KEY', key, 0), ('PIE', pie, 0), ('CHARGES', charges, 0), ('OPAL', opal, 0),
    ('ROCK', rock, 0), ('FIRE', fireball, 0), ('WEAP0', weapon, 0), ('WEAP1', weapon, 1),
    ('RB_A', redback, 0), ('RB_B', redback, 1), ('FF_A', flyingfox, 0), ('FF_B', flyingfox, 1),
    ('YW_A', yowie, 0), ('YW_B', yowie, 1), ('BN_A', bunyip, 0), ('BN_B', bunyip, 1),
]
WEAPON_H = 30          # the zapper is drawn at one size: 30 scanlines tall


def sizes_for(name, W0, H0):
    """widths in dots of the 16 sizes (the weapon has one size, repeated)"""
    if name.startswith('WEAP'):
        w = round(W0 * WEAPON_H / H0 * ASPECT)
        return [w] * NS
    return [max(1, round(W0 * h / H0 * ASPECT)) for h in HS]


def build(out):
    """ART.BIN layout (block 3)
       0000  directory, 16 images x 8 bytes:
             master offset (w), W0 bytes per row, H0 rows, xmap offset (w),
             column size shift (6 = 64-byte columns, 7 = 128), spare
       0080  widths: 16 images x 16 sizes (bytes, dots)
       0180  masters: H0 rows of [mask bytes][data bytes]
       then  xmaps: for each image, for each size, w bytes (source column of each
             dot) padded to whole bytes with W0, which is always a clear pixel
    """
    blob = bytearray(0x180)
    previews = []
    for i, (name, fn, fr) in enumerate(IMAGES):
        c = fn(fr)
        H0, W0 = len(c), len(c[0])
        assert W0 % 8 == 0 and H0 <= 64
        nb = W0 // 8
        off = len(blob)
        for y in range(H0):
            m = [0] * nb
            d = [0] * nb
            for x in range(W0):
                if c[y][x] != T:
                    m[x >> 3] |= 0x80 >> (x & 7)
                if c[y][x] == I:
                    d[x >> 3] |= 0x80 >> (x & 7)
            blob += bytes(m) + bytes(d)
        ws = sizes_for(name, W0, H0)
        blob[0x80 + i * 16:0x80 + i * 16 + 16] = bytes(ws)
        xoff = len(blob)
        for w in ws:
            nb8 = (w + 7) // 8 * 8          # padded to whole bytes with W0 (a clear pixel)
            blob += bytes(min(W0 - 1, (ox * W0) // w) if ox < w else W0 for ox in range(nb8))
        colsh = 6 if H0 <= 32 else 7
        blob[i * 8:i * 8 + 8] = off.to_bytes(2, 'little') + bytes([nb, H0]) + xoff.to_bytes(2, 'little') + bytes([colsh, 0])
        previews.append((name, c))
    assert len(blob) <= 0x8000
    (out / 'ART.BIN').write_bytes(blob)
    S = ['; generated by tools/art.py']
    for i, (name, _, _) in enumerate(IMAGES):
        S.append('IMG_%-8s equ %d' % (name, i))
    S.append('NIMAGES      equ %d' % len(IMAGES))
    S.append('NSIZES       equ %d' % NS)
    S.append('WEAPON_H     equ %d' % WEAPON_H)
    S.append('HSIZES:      db ' + ','.join(str(h) for h in HS))
    # h (scanlines, 0..255) / 2 -> nearest size
    hts = []
    for h2 in range(128):
        h = max(1, h2 * 2)
        s = min(range(NS), key=lambda k: abs(math.log(HS[k] / h)))
        hts.append(s)
    S.append('HTOS:')
    for i in range(0, 128, 32):
        S.append('        db ' + ','.join(str(v) for v in hts[i:i + 32]))
    (out / 'artsym.inc').write_text('\n'.join(S) + '\n')
    # previews
    cols = {T: (40, 40, 60), K: (0, 0, 0), I: (255, 200, 60)}
    x = 0
    sheet = Image.new('RGB', (sum(len(c[0]) * 4 + 8 for _, c in previews), 64 * 4 + 8), (40, 40, 60))
    for name, c in previews:
        im = Image.new('RGB', (len(c[0]), len(c)))
        im.putdata([cols[v] for r in c for v in r])
        im = im.resize((len(c[0]) * 4, len(c) * 4), Image.NEAREST)
        sheet.paste(im, (x, 4))
        x += len(c[0]) * 4 + 8
    sheet.save(out / 'art_sheet.png')
    print('ART.BIN: %d bytes, %d images' % (len(blob), len(IMAGES)))


# ------------------------------------------------------------------ title logo
LOGO_W, LOGO_H = 40, 15        # cells (rows 1..15 of the title screen)

BIG = {
 'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
 'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
 'N': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
 'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
 'I': ['###', '.#.', '.#.', '.#.', '.#.', '.#.', '###'],
 'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
}


def title_logo(CH):
    """The word BUNYIP in big bevelled block letters over a large Bunyip.
    Returns (glyphs, map): up to 384 unique 8 x CH glyphs, and per cell
    (code, bank) pairs for LOGO_W x LOGO_H cells."""
    W, H = LOGO_W * 8, LOGO_H * CH
    pix = [[0] * W for _ in range(H)]
    # letters: each font pixel is a 7 x 7 block with a bright top-left bevel
    word = 'BUNYIP'
    widths = [len(BIG[ch][0]) for ch in word]
    bw, bh = 7, 7
    total = sum(w * bw for w in widths) + (len(word) - 1) * bw
    x0 = (W - total) // 2
    y0 = 4
    x = x0
    for ch, w in zip(word, widths):
        for r, row in enumerate(BIG[ch]):
            for cidx, v in enumerate(row):
                if v != '#':
                    continue
                for yy in range(bh):
                    for xx in range(bw):
                        px, py = x + cidx * bw + xx, y0 + r * bh + yy
                        edge = yy == 0 or xx == 0
                        shade = yy >= bh - 2 or xx >= bw - 2
                        if edge:
                            on = 1
                        elif shade:
                            on = (px + py) % 2
                        else:
                            on = 1 if (px // 2 + py) % 4 else 0
                        pix[py][px] = on
        x += (w + 1) * bw
    # the Bunyip below, scaled up 2 x 2 (dots), centred
    c = bunyip(1)
    bx0 = (W - len(c[0]) * 2) // 2
    by0 = y0 + 7 * bh + 12
    for y, row in enumerate(c):
        for xx, v in enumerate(row):
            for dy in range(2):
                for dx in range(2):
                    py, px = by0 + y * 2 + dy, bx0 + xx * 2 + dx
                    if py < H:
                        pix[py][px] = 1 if v == I else 0
    glyphs, idx, cmap = [], {}, []
    for cy in range(LOGO_H):
        for cx in range(LOGO_W):
            g = tuple(sum(pix[cy * CH + y][cx * 8 + b] << (7 - b) for b in range(8)) for y in range(CH))
            if not any(g):
                cmap += [0, 255]          # blank: use a space
                continue
            if g not in idx:
                idx[g] = len(glyphs)
                glyphs.append(list(g))
            n = idx[g]
            cmap += [0x80 + (n & 127), 13 + (n >> 7)]
    assert len(glyphs) <= 384, len(glyphs)
    while len(glyphs) < 384:
        glyphs.append([0] * CH)
    return glyphs, cmap


if __name__ == '__main__':
    build(Path(sys.argv[1] if len(sys.argv) > 1 else 'build'))
