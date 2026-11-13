"""Build-time artwork for VZ FLIGHT: title logo and tribute pictures (mode 1, 128 px wide, 2 bits/pixel).

Pictures are drawn at 8x resolution with the VZ's 1 : 1.5 pixel aspect, then reduced to the
4-colour palette with an ordered dither so that blends come out as VZ-style checker patterns.
"""
import math
from PIL import Image, ImageDraw, ImageFont

CSS0 = [(40, 224, 40), (240, 240, 80), (48, 48, 220), (208, 48, 48)]          # green yellow blue red
CSS1 = [(236, 236, 210), (40, 220, 230), (220, 60, 220), (240, 140, 30)]      # buff cyan magenta orange
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
K = 8


def quantise(img, rows, pal_idx_map):
    """img: RGB image at (128*K, rows*K) whose colours are 'paint' values.
    pal_idx_map: function(rgb) -> (index_a, index_b, mix 0..1) giving a two-colour blend."""
    small = img.resize((128, rows), Image.BOX)
    px = small.load()
    out = []
    for y in range(rows):
        row = []
        for x in range(128):
            a, b, t = pal_idx_map(px[x, y])
            th = (BAYER[y & 3][x & 3] + 0.5) / 16
            row.append(b if t > th else a)
        out.append(row)
    return out


def nearest2(pal):
    """two-colour blend chooser: best pair + mix that reproduces the colour"""
    def f(c):
        best = None
        for i in range(4):
            for j in range(i, 4):
                pa, pb = pal[i], pal[j]
                d = [pb[k] - pa[k] for k in range(3)]
                dd = sum(v * v for v in d)
                if dd == 0:
                    t = 0.0
                else:
                    t = sum((c[k] - pa[k]) * d[k] for k in range(3)) / dd
                    t = max(0.0, min(1.0, t))
                    t = round(t * 4) / 4          # only 0, 1/4, 1/2, 3/4, 1 mixes
                m = [pa[k] + t * d[k] for k in range(3)]
                err = sum((c[k] - m[k]) ** 2 for k in range(3))
                if best is None or err < best[0]:
                    best = (err, i, j, t)
        return best[1], best[2], best[3]
    return f


def tobytes(pix):
    out = []
    for row in pix:
        for xb in range(32):
            b = 0
            for k in range(4):
                b = (b << 2) | row[xb * 4 + k]
            out.append(b)
    return out


def preview(pix, pal, fname, scale=4):
    rows = len(pix)
    im = Image.new('RGB', (128, rows))
    p = im.load()
    for y in range(rows):
        for x in range(128):
            p[x, y] = pal[pix[y][x]]
    im.resize((128 * scale, int(rows * scale * 1.5)), Image.NEAREST).save(fname)


def canvas(rows, col):
    W, H = 128 * K, rows * K
    im = Image.new('RGB', (W, H), col)
    return im, ImageDraw.Draw(im), W, H


# ------------------------------------------------------------------ native pixel helpers
class Pix:
    def __init__(self, rows, col):
        self.rows = rows
        self.p = [[col] * 128 for _ in range(rows)]

    def set(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < 128 and 0 <= y < self.rows:
            self.p[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                self.set(x, y, c)

    def checker(self, y0, y1, a, b, x0=0, x1=127):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, a if (x + y) & 1 else b)

    def line(self, x0, y0, x1, y1, c):
        n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
        for i in range(n + 1):
            t = i / n
            self.set(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.set(x, y, c)


# ------------------------------------------------------------------ title logo
def logo():
    rows = 18
    W, H = 128 * K, rows * K
    try:
        f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 12 * K)
    except OSError:
        f = ImageFont.load_default()
    txt = 'VZ FLIGHT'
    tmp = Image.new('L', (int(ImageDraw.Draw(Image.new('L', (1, 1))).textlength(txt, font=f)) + 4 * K, 16 * K), 0)
    ImageDraw.Draw(tmp).text((2 * K, -2 * K), txt, font=f, fill=255)
    bb = tmp.getbbox()
    tmp = tmp.crop(bb).resize((118, 12), Image.BOX)
    m = tmp.load()
    P = Pix(rows, 2)
    for y in range(12):
        for x in range(118):
            if m[x, y] > 110:
                P.set(x + 6, y + 2, 3)          # red drop shadow
    for y in range(12):
        for x in range(118):
            if m[x, y] > 110:
                P.set(x + 5, y + 1, 1)          # yellow face
    for x in range(4, 124):
        P.set(x, 15, 3)
        if x % 2 == 0:
            P.set(x, 16, 3)
    return P.p


# ------------------------------------------------------------------ Sydney: helicopter under the bridge
def pic_sydney():
    rows = 26
    P = Pix(rows, 2)
    P.checker(3, 4, 2, 1)
    P.rect(0, 5, 127, 9, 1)
    P.checker(10, 11, 1, 3)
    P.rect(0, 12, 127, 16, 3)
    hz = 17
    P.ellipse(18, hz - 1, 7, 4, 1)                # setting sun
    P.rect(0, hz, 127, rows - 1, 2)               # water
    for i in range(7):                            # sun glitter
        w = 7 - i
        for x in range(18 - w, 19 + w, 2):
            P.set(x + (i & 1), hz + 1 + i, 1)
    for i in range(0, 7, 2):                      # red reflections
        for x in range(30 + i * 3, 120 - i * 5, 3):
            P.set(x + (i & 2), hz + 2 + i, 3)
    # Harbour Bridge silhouette (blue)
    deck = 13
    cx, span = 60, 30
    P.rect(4, deck, 112, deck, 2)
    for px in (cx - span - 4, cx + span + 1):
        P.rect(px, deck - 4, px + 3, hz - 1, 2)
    for x in range(cx - span, cx + span + 1):
        u = (x - cx) / span
        P.set(x, deck - 1 - 8 * (1 - u * u), 2)
        P.set(x, hz - 1 - 11 * (1 - u * u), 2)
    for x in range(cx - span + 4, cx + span - 2, 4):
        u = (x - cx) / span
        P.line(x, deck - 1 - 8 * (1 - u * u), x, hz - 1 - 11 * (1 - u * u), 2)
    # helicopter flying under the deck (blue silhouette)
    hx, hy = 48, 15
    P.rect(hx - 2, hy, hx + 2, hy + 1, 2)
    P.line(hx + 2, hy, hx + 8, hy, 2)
    P.set(hx + 8, hy - 1, 2)
    P.line(hx - 5, hy - 1, hx + 5, hy - 1, 2)
    # Opera House sails (yellow on the red horizon)
    for i, h in enumerate((5, 4, 3)):
        bx = 110 + i * 5
        for k in range(h + 1):
            P.line(bx - (h - k) * 0.5, hz - 1 - k, bx + 3 - k * 0.6, hz - 1 - k, 1)
    P.rect(106, hz - 1, 127, hz - 1, 1)
    return P.p


# ------------------------------------------------------------------ North Pole (CSS1)
def pic_pole():
    rows = 24
    P = Pix(rows, 1)                       # cyan sky
    P.checker(0, 2, 2, 1)                  # magenta glow at the top
    hz = 13
    P.rect(0, hz, 127, 23, 0)              # buff ice
    for (x0, y0, w) in ((4, 15, 40), (70, 17, 50), (30, 21, 36)):
        for i in range(w):
            P.set(x0 + i, y0 + ((i // 3) & 1), 1)
    # pole and flag
    px, base = 38, 20
    for i in range(10):
        P.set(px, base - i, 3 if (i // 2) % 2 == 0 else 2)
        P.set(px + 1, base - i, 3 if (i // 2) % 2 == 0 else 2)
    for k in range(4):
        P.line(px + 2, base - 10 + k, px + 8 - k, base - 10 + k, 3)
    for a in range(0, 360, 12):
        P.set(px + 12 * math.cos(math.radians(a)), base + 1.5 * math.sin(math.radians(a)), 2)
    # helicopter
    hx, hy = 92, 7
    P.ellipse(hx, hy, 3, 1.6, 3)
    P.line(hx + 3, hy, hx + 12, hy - 1, 3)
    P.line(hx + 12, hy - 2, hx + 12, hy, 3)
    P.line(hx - 10, hy - 3, hx + 10, hy - 3, 2)
    P.line(hx - 3, hy + 2, hx + 3, hy + 2, 2)
    P.set(hx - 2, hy + 1, 2)
    P.set(hx + 2, hy + 1, 2)
    return P.p


if __name__ == '__main__':
    preview(logo(), CSS0, 'pv_logo.png')
    preview(pic_sydney(), CSS0, 'pv_syd.png')
    preview(pic_pole(), CSS1, 'pv_pole.png')
