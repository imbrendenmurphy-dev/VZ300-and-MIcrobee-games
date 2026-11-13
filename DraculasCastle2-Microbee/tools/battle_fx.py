"""Battle effects drawn for the Microbee, replacing the VZ's '/', '*' and '+'
font strokes. Each effect is a list of steps; each step is a list of screen
cells, one ink each, whose pixels are laid OVER whatever is in the cell (the
game merges them into a spare PCG at run time, so the monster and room show
through). Kinds follow fx_kind: 1 slash, 2 fire, 3 holy water, 4 claws (the
hero is hit), 5 level up, 6 the hero falls.

Blob layout (copied to RAM block 3 $1000 when the effect starts):
  dw offset of each step (from the blob start)
  per cell: dw column | row << 6 | ink << 11, 8 bytes of pixels; dw $FFFF ends
"""
import math, random
import numpy as np
from PIL import Image, ImageDraw

W, H = 320, 200
MAX_CELLS = 128         # PCG bank 12 or 13, alternately, per present
BLOB_MAX = 3840         # RAM block 3 $1000..$1EFF (free during a fight)
STEPS = {1: 5, 2: 10, 3: 8, 4: 4, 5: 8, 6: 6}


def canvas():
    return Image.new('L', (W, H), 0)


def star(d, x, y, r, ink):
    """A four-point twinkle: thick at the heart, fine at the tips."""
    d.line((x - r, y, x + r, y), fill=ink)
    d.line((x, y - r - 1, x, y + r + 1), fill=ink)
    if r >= 3:
        d.line((x - r // 2, y - 1, x + r // 2, y - 1), fill=ink)
        d.line((x - r // 2, y + 1, x + r // 2, y + 1), fill=ink)
        d.line((x - 1, y - r // 2, x - 1, y + r // 2), fill=ink)
        d.line((x + 1, y - r // 2, x + 1, y + r // 2), fill=ink)
        d.point([(x - 2, y - 2), (x + 2, y - 2), (x - 2, y + 2), (x + 2, y + 2)], fill=ink)


def bez(p0, p1, p2, t):
    return ((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
            (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1])


def slash(step):
    im = canvas(); d = ImageDraw.Draw(im)
    p0, p1, p2 = (262, 26), (236, 168), (64, 186)
    head = (step + 1) / 5
    tail = max(0.0, head - 0.75)
    n = 90
    for i in range(n):
        t = tail + (head - tail) * i / (n - 1)
        x, y = bez(p0, p1, p2, t)
        k = i / (n - 1)                               # 0 tail .. 1 head
        r = 0.6 + 3.4 * k * k
        ink = 15 if k > 0.55 else 14
        if k < 0.25 and i % 2:                        # the tail breaks up
            continue
        d.ellipse((x - r, y - r, x + r, y + r), fill=ink)
    hx, hy = bez(p0, p1, p2, head)
    star(d, int(hx + 6), int(hy - 6), 4, 15)
    return im


def fire(step):
    im = canvas(); d = ImageDraw.Draw(im); rnd = random.Random(step * 7 + 1)
    cx, cy = 160, 100
    if step < 6:
        y = 182 - 16 * step
        x = cx + int(4 * math.sin(step * 1.7))
        for j in range(6):                            # flickering tail
            tx = x + rnd.randint(-6, 6); ty = y + 12 + j * 7
            r = 7 - j
            if r > 0 and ty < H:
                d.ellipse((tx - r, ty - r, tx + r, ty + r), fill=9 if j < 3 else 1)
        d.ellipse((x - 13, y - 13, x + 13, y + 13), fill=9)
        d.ellipse((x - 9, y - 10, x + 9, y + 7), fill=11)
        d.ellipse((x - 4, y - 6, x + 3, y + 1), fill=15)
    else:
        k = step - 6
        if k == 0:
            d.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), fill=11)
            d.ellipse((cx - 12, cy - 12, cx + 12, cy + 12), fill=15)
        else:
            r = 22 + 16 * k
            for a in range(0, 360, 30 if k < 3 else 40):
                ang = math.radians(a + k * 9)
                for s in range(2 if k < 3 else 1):
                    rr = r - 9 * s + rnd.randint(-3, 3)
                    x = cx + rr * math.cos(ang); y = cy + rr * math.sin(ang) * 1.1
                    sz = (5 if k == 1 else 4 if k == 2 else 2) - s
                    ink = (11, 9, 9, 1)[min(3, k - 1 + s)]
                    d.ellipse((x - sz, y - sz, x + sz, y + sz), fill=ink)
    return im


def holy(step):
    im = canvas(); d = ImageDraw.Draw(im); rnd = random.Random(31)
    drops = [(96 + i * 21, rnd.randint(0, 24)) for i in range(7)]
    if step < 3:
        for x, off in drops:
            y = 22 + off + 26 * step
            d.ellipse((x - 3, y, x + 3, y + 7), fill=14)
            d.polygon([(x - 2, y + 1), (x, y - 6), (x + 2, y + 1)], fill=14)
            d.point([(x - 1, y + 2), (x - 1, y + 3)], fill=15)
    else:
        rnd = random.Random(step * 13)
        if step in (4, 5):
            d.rectangle((159, 36, 161, 160), fill=11)
            d.rectangle((122, 77, 198, 79), fill=11)
        for i in range(10):
            x = rnd.randint(92, 228); y = rnd.randint(28, 186)
            r = rnd.choice((3, 4, 6, 7)) - (2 if step == 7 else 0)
            star(d, x, y, r, (15, 14, 11)[i % 3])
    return im


def claws(step):
    im = canvas(); d = ImageDraw.Draw(im)
    frac = (step + 1) / 4
    for j in range(3):
        x0, y0 = 104 + j * 30, 50 + j * 6
        x1, y1 = x0 + 36, y0 + 92
        n = 40
        for i in range(int(n * frac)):
            t = i / n
            x = x0 + (x1 - x0) * t + 5 * math.sin(t * math.pi); y = y0 + (y1 - y0) * t
            r = 0.8 + 1.7 * math.sin(t * math.pi)
            d.ellipse((x - r, y - r, x + r, y + r), fill=9)
    return im


def levelup(step):
    im = canvas(); d = ImageDraw.Draw(im); rnd = random.Random(5)
    for i in range(12):
        x = 30 + i * 24 + rnd.randint(-6, 6)
        y = 196 - step * 24 - rnd.randint(0, 40)
        if 18 < y < H - 4:
            star(d, x, y, 4 if (i + step) % 3 else 6, 11 if i % 2 else 15)
    return im


def falls(step):
    im = canvas(); d = ImageDraw.Draw(im); rnd = random.Random(9)
    for i in range(8):
        col = 2 + i * 5 + rnd.randint(0, 2)
        x = col * 8 + 3
        length = min(54, (step + 1) * rnd.randint(7, 10))
        d.rectangle((x, 16, x + 2, 16 + length), fill=9)
        d.ellipse((x - 2, 16 + length - 2, x + 4, 16 + length + 4), fill=9)
    return im


DRAW = {1: slash, 2: fire, 3: holy, 4: claws, 5: levelup, 6: falls}


def cells(im):
    a = np.asarray(im)
    out = []
    for cy in range(2, 25):
        for cx in range(40):
            blk = a[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            if not blk.any():
                continue
            inks = blk[blk > 0]
            ink = int(np.bincount(inks).argmax())
            bits = bytes(int(''.join('1' if v else '0' for v in row), 2) for row in blk)
            out.append((cy * 40 + cx, ink, bits))
    return out


def blob(kind):
    steps = [cells(DRAW[kind](s)) for s in range(STEPS[kind])]
    head = 2 * len(steps)
    body = bytearray(); offs = []
    for st in steps:
        assert len(st) <= MAX_CELLS, (kind, len(st))
        offs.append(head + len(body))
        for cell, ink, bits in st:
            body += (cell % 40 | cell // 40 << 6 | ink << 11).to_bytes(2, 'little') + bits
        body += b'\xff\xff'
    data = b''.join(o.to_bytes(2, 'little') for o in offs) + bytes(body)
    data += bytes(-len(data) % 128)
    assert len(data) <= BLOB_MAX, (kind, len(data))
    return data


def sheet(path, background=None):
    """Every step of every effect, for review."""
    from native_art import HW
    rows = []
    for kind in DRAW:
        row = []
        for s in range(STEPS[kind]):
            base = np.zeros((H, W, 3), np.uint8) if background is None else np.asarray(background)[:H].copy()
            a = np.asarray(DRAW[kind](s))
            for cell, ink, bits in cells(DRAW[kind](s)):
                y, x = cell // 40 * 8, cell % 40 * 8
                for r in range(8):
                    for b in range(8):
                        if bits[r] >> (7 - b) & 1:
                            base[y + r, x + b] = HW[ink]
            row.append(base)
        while len(row) < 10:
            row.append(np.zeros((H, W, 3), np.uint8))
        rows.append(np.hstack(row))
    Image.fromarray(np.vstack(rows)).resize((W * 10 // 2, H * len(rows) // 2)).save(path)


if __name__ == '__main__':
    import sys
    sys.path.insert(0, __import__('os').path.dirname(__file__))
    for k in DRAW:
        b = blob(k); print(k, len(b), [len(cells(DRAW[k](s))) for s in range(STEPS[k])])
    sheet('/tmp/claude-0/fx/sheet.png')
