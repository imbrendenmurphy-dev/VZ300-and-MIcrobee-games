"""REDBACK sprites: the Redback fighter (banking, 180-degree reversal), drones,
interceptors and shots. Each frame is pre-shifted 8 ways and stored as
column strips of (keep, data) byte pairs for the Z80 compositor:

    result line = (background line AND keep) OR data

The outline is the sprite's mask grown by one pixel, so a dark halo
separates it from the deck.
"""
import math
import numpy as np
from PIL import Image, ImageDraw

SS = 8                       # supersampling for polygon edges


def raster(polys, w, h):
    im = Image.new('L', (w * SS, h * SS), 0)
    d = ImageDraw.Draw(im)
    for p in polys:
        d.polygon([(x * SS, y * SS) for x, y in p], fill=255)
    a = np.asarray(im, np.float32).reshape(h, SS, w, SS).mean((1, 3)) / 255.0
    return a >= 0.5


def ellipse(cx, cy, rx, ry, w, h):
    yy, xx = np.mgrid[0:h, 0:w]
    return ((xx + .5 - cx) / rx) ** 2 + ((yy + .5 - cy) / ry) ** 2 <= 1.0


def dilate(m):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    return o


# ------------------------------------------------------------ the fighter
PW_, PH_ = 28, 14
BODY = [(27, 7), (17, 3.4), (7, 0.8), (2.6, 0.8), (6.5, 5.6), (3.6, 7), (6.5, 8.4), (2.6, 13.2), (7, 13.2), (17, 10.6)]
CY = 7.0


def fighter(face=0, turn=None, bank=0):
    """face 0 = nose right; turn = angle 0..180 (a flip about the vertical
    axis); bank -1 / 0 / +1 foreshortens the upper / lower wing"""
    pts = []
    for x, y in BODY:
        dy = y - CY
        if bank < 0 and dy < 0:
            dy *= 0.5
        if bank > 0 and dy > 0:
            dy *= 0.5
        yy = CY + dy
        if turn is not None:
            c = math.cos(math.radians(turn))
            if abs(c) < 0.14:
                c = 0.14 if c >= 0 else -0.14
            xx = 14 + (x - 14) * c
        else:
            xx = x if face == 0 else 27.0 - x
        pts.append((xx, yy))
    m = raster([pts], PW_, PH_)
    body = m.copy()
    # canopy (dark) and engine glow; shading by dithering the lower wing
    can = 6.0 if face == 0 else 8.0
    if turn is None:
        cxp = 17.5 if face == 0 else 27 - 17.5
        body &= ~ellipse(cxp, CY, 3.0, 1.3, PW_, PH_)
        for y in range(PH_):
            for x in range(PW_):
                if m[y, x] and y >= 9 and (x + y) % 2 == 0 and not (face == 0 and x > 20) and not (face == 1 and x < 7):
                    body[y, x] = False
    else:
        for y in range(PH_):
            for x in range(PW_):
                if m[y, x] and y >= 9 and (x + y) % 2 == 0:
                    body[y, x] = False
    return dilate(m), body


def drone(f):
    w, h = 18, 9
    m = ellipse(9, 5.2, 8.5, 3.6, w, h) | ellipse(9, 3, 4.5, 2.8, w, h)
    d = m.copy()
    d &= ~ellipse(9, 3.2, 2.2, 1.2, w, h)
    for x in (3, 6, 9, 12, 15):
        d[6, x] = ((x // 3 + f) % 2 == 0)
    return dilate(m), d


def interceptor(f):
    w, h = 26, 12
    pts = [(0.5, 6), (8, 3), (22, 0.8), (25.5, 2.5), (19, 6), (25.5, 9.5), (22, 11.2), (8, 9)]
    m = raster([pts], w, h)
    d = m.copy()
    d &= ~ellipse(8.5, 6, 2.5, 1.2, w, h)
    for y in range(h):
        for x in range(w):
            if m[y, x] and y >= 8 and (x + y) % 2 == 0:
                d[y, x] = False
    d[6, 21 + (f & 1)] = True
    mm = m.copy()
    mm[6, 21 + (f & 1)] = True
    return dilate(mm), d


def shot():
    w, h = 12, 4
    m = np.zeros((h, w), bool)
    m[1:3, 1:11] = True
    d = m.copy()
    d[1, 1:3] = False
    return dilate(m), d


def bullet():
    """enemy bullet: a small diamond"""
    m = np.zeros((5, 5), bool)
    for y, row in enumerate(('..#..', '.###.', '#####', '.###.', '..#..')):
        for x, ch in enumerate(row):
            m[y, x] = ch == '#'
    return dilate(m), m


def explosion(f):
    """4 frames of a burst, 18 x 14: hot core -> flame ball -> broken ring -> sparks"""
    w, h = 18, 14
    cx, cy = 9, 7
    rng = np.random.default_rng(40 + f)
    if f == 0:
        d = ellipse(cx, cy, 3.5, 2.6, w, h)
        for dx, dy in ((5, 0), (-6, 0), (0, 4), (0, -5), (4, 3), (-5, -3)):
            d[cy + dy, cx + dx] = True
    elif f == 1:
        d = ellipse(cx, cy, 6.5, 4.8, w, h)
        d &= ~(ellipse(cx, cy, 2.2, 1.5, w, h))
        yy, xx = np.mgrid[0:h, 0:w]
        d &= ~((((xx + yy) % 3) == 0) & ~ellipse(cx, cy, 4.5, 3.2, w, h))
    elif f == 2:
        d = ellipse(cx, cy, 8.5, 6.5, w, h) & ~ellipse(cx, cy, 6.0, 4.4, w, h)
        yy, xx = np.mgrid[0:h, 0:w]
        d &= ((xx * 7 + yy * 3) % 5) < 3
        d |= ellipse(cx - 2, cy + 1, 1.3, 1.0, w, h) | ellipse(cx + 3, cy - 1, 1.3, 1.0, w, h)
    else:
        d = np.zeros((h, w), bool)
        for a in range(0, 360, 30):
            r = 7.5 + rng.random() * 1.0
            x = int(round(cx - 0.5 + r * math.cos(math.radians(a + 15))))
            y = int(round(cy - 0.5 + r * 0.75 * math.sin(math.radians(a + 15))))
            if 0 <= x < w and 0 <= y < h:
                d[y, x] = True
    return dilate(d), d


def crop(data):
    ys, xs = np.nonzero(data)
    return data[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()


def shifted(data):
    """8 pre-shifted versions of the lit pixels: (ncols, bytes) per shift,
    column-major, one byte (8 pixels) per line"""
    h, w = data.shape
    out = []
    for s in range(8):
        cols = (w + s + 7) // 8
        dm = np.zeros((h, cols * 8), bool)
        dm[:, s:s + w] = data
        buf = bytearray()
        for c in range(cols):
            for y in range(h):
                v = 0
                for b in range(8):
                    v |= (1 if dm[y, c * 8 + b] else 0) << (7 - b)
                buf.append(v)
        out.append((cols, bytes(buf)))
    return out


FRAMES = []          # (name, ink, data)


def add(name, ink, mask, data):
    assert not (data & ~mask).any(), name
    FRAMES.append((name, ink, data))


def build_frames():
    FRAMES.clear()
    WHITE, BCYAN, BRED, YELLOW = 15, 14, 9, 11
    add('P_R', WHITE, *fighter(0, None, 0))
    add('P_RU', WHITE, *fighter(0, None, -1))
    add('P_RD', WHITE, *fighter(0, None, 1))
    for a in (30, 60, 90, 120, 150):
        add('P_T%d' % a, WHITE, *fighter(0, a, 0))
    add('P_L', WHITE, *fighter(1, None, 0))
    add('P_LU', WHITE, *fighter(1, None, -1))
    add('P_LD', WHITE, *fighter(1, None, 1))
    add('D_0', BCYAN, *drone(0))
    add('D_1', BCYAN, *drone(1))
    add('I_0', BRED, *interceptor(0))
    add('I_1', BRED, *interceptor(1))
    for f in (0, 1):                         # the interceptor flying right (nose right)
        m, d = interceptor(f)
        add('J_%d' % f, BRED, m[:, ::-1].copy(), d[:, ::-1].copy())
    m, d = shot()
    add('S_R', YELLOW, m, d)
    add('S_L', YELLOW, m[:, ::-1].copy(), d[:, ::-1].copy())
    add('B_0', 13, *bullet())                # bright magenta
    for f, ink in enumerate((WHITE, YELLOW, BRED, 1)):
        add('X_%d' % f, ink, *explosion(f))
    # crop each family to the union of its frames, so banking and the turn
    # keep their registration
    fam = {}
    for name, ink, d in FRAMES:
        key = name.split('_')[0]
        ys, xs = np.nonzero(d)
        b = fam.setdefault(key, [99, -1, 99, -1])
        b[0], b[1] = min(b[0], ys.min()), max(b[1], ys.max())
        b[2], b[3] = min(b[2], xs.min()), max(b[3], xs.max())
    out = [(n, i, d[fam[n.split('_')[0]][0]:fam[n.split('_')[0]][1] + 1, fam[n.split('_')[0]][2]:fam[n.split('_')[0]][3] + 1].copy())
           for n, i, d in FRAMES]
    FRAMES[:] = out
    FAMILY.clear()
    for k, (y0, y1, x0, x1) in fam.items():
        FAMILY[k] = (x1 - x0 + 1, y1 - y0 + 1)      # (width, height) after the crop
    return FRAMES


FAMILY = {}          # family -> (w, h) of its cropped frames (for collision boxes)


def variants(data):
    """all (shift, line offset) placements of one frame, as cell lists:
    {(s, yo): [(dcol, row, 10 bytes)]} - column-major, empty cells left out"""
    h, w = data.shape
    out = {}
    for s in range(8):
        cols = (w + s + 7) // 8
        for yo in range(10):
            rows = (yo + h + 9) // 10
            img = np.zeros((rows * 10, cols * 8), bool)
            img[yo:yo + h, s:s + w] = data
            cells = []
            for c in range(cols):
                for r in range(rows):
                    blk = img[r * 10:(r + 1) * 10, c * 8:(c + 1) * 8]
                    if not blk.any():
                        continue
                    bs = bytes(int(sum(int(blk[y, x]) << (7 - x) for x in range(8))) for y in range(10))
                    cells.append((c, r, bs))
            out[(s, yo)] = cells
    return out


BLK_SPR0 = 13
# RAM blocks for the sprite streams: block 16 holds CP/M's saved video state, so skip it
SPR_BLOCKS = [13, 14, 15, 17, 18, 19]
SPRIDX = 0x4000


def mv(blk):
    return ((blk & 0x1C) << 3) | ((blk & 3) ^ 2) | 4


def pack():
    """-> (index bytes for 4000h of the PAIRS block, [sprite blocks], {name: id}, frames)
    index: for frame f, shift s, line offset yo, entry 4 bytes at SPRIDX + 4 * (80 f + 10 s + yo):
    port value of the block, pointer lo/hi, ink. stream: N, then N x (dcol, delta, row, 10 bytes)."""
    frames = build_frames()
    blocks = [bytearray()]
    idx = bytearray(4 * 80 * len(frames))
    ids = {}
    for i, (name, ink, d) in enumerate(frames):
        ids[name] = i
        for (s, yo), cells in variants(d).items():
            rec = bytearray([len(cells)])
            for (c, r, bs) in cells:
                rec += bytes([c, r * 40 + c, r]) + bs
            if len(blocks[-1]) + len(rec) > 0x8000:
                blocks.append(bytearray())
                assert len(blocks) <= len(SPR_BLOCKS), 'sprite data needs more RAM blocks'
            b = len(blocks) - 1
            p = len(blocks[-1])
            blocks[-1] += rec
            e = 4 * (80 * i + 10 * s + yo)
            idx[e:e + 4] = bytes([mv(SPR_BLOCKS[b]), p & 255, p >> 8, ink])
    return bytes(idx), [bytes(b) for b in blocks], ids, frames


def preview(path):
    frames = build_frames()
    from mbee import PALETTE
    pal = np.array(PALETTE, np.uint8)
    rows = (len(frames) + 7) // 8
    img = np.zeros((rows * 18, 8 * 34, 3), np.uint8)
    img[:] = pal[8]
    for i, (name, ink, dat) in enumerate(frames):
        ox, oy = (i % 8) * 34 + 2, (i // 8) * 18 + 2
        h, w = dat.shape
        for y in range(h):
            for x in range(w):
                img[oy + y, ox + x] = pal[ink] if dat[y, x] else pal[0]
    im = Image.fromarray(img).resize((img.shape[1] * 4, img.shape[0] * 6), Image.NEAREST)
    im.save(path)


if __name__ == '__main__':
    import sys
    sys.path.insert(0, '.')
    idx, blocks, ids, frames = pack()
    print(len(frames), 'frames', len(idx), 'index bytes', [len(b) for b in blocks], 'sprite bytes', ids)
    preview('/tmp/claude-0/sprites.png')
