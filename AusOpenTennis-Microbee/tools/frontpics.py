"""Front-end pictures: title, information page backdrop, trophy, portraits."""
import math
import random
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from cells import *
import geom as G
import players

FONT_BIG = '/usr/share/fonts/truetype/google-fonts/Poppins-BoldItalic.ttf'
FONT_SERIF = '/usr/share/fonts/truetype/google-fonts/Lora-Italic-Variable.ttf'


def text_mask(txt, font, size, track=0, ay=1.5):
    """text rendered square, then squashed for the tall Microbee pixels -> bool array"""
    f = ImageFont.truetype(font, size)
    try:
        f.set_variation_by_name('Bold Italic')
    except Exception:
        pass
    w = sum(f.getbbox(ch)[2] for ch in txt) + track * len(txt) + size
    im = Image.new('L', (w, int(size * 1.6)), 0)
    d = ImageDraw.Draw(im)
    x = 0
    for ch in txt:
        d.text((x, 0), ch, font=f, fill=255)
        x += f.getbbox(ch)[2] + track
    a = np.array(im) > 110
    ys, xs = np.nonzero(a)
    a = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    h = max(1, int(round(a.shape[0] / ay)))
    im = Image.fromarray((a * 255).astype(np.uint8)).resize((a.shape[1], h), Image.LANCZOS)
    return np.array(im) > 100


def stamp(c, mask, x, y, col, shadow=None, outline=None):
    a = c.a
    h, w = mask.shape
    if outline is not None:
        m = np.zeros((h + 2, w + 2), bool)
        for dy in (0, 1, 2):
            for dx in (0, 1, 2):
                m[dy:dy + h, dx:dx + w] |= mask
        _paint(a, m, x - 1, y - 1, outline)
    if shadow is not None:
        _paint(a, mask, x + 2, y + 1, shadow)
    _paint(a, mask, x, y, col)
    c.set(a)


def _paint(a, m, x, y, col):
    h, w = m.shape
    for yy in range(h):
        Y = y + yy
        if not 0 <= Y < a.shape[0]:
            continue
        for xx in range(w):
            X = x + xx
            if 0 <= X < a.shape[1] and m[yy, xx]:
                a[Y, X] = col


def centre_x(mask):
    return (512 - mask.shape[1]) // 2


def ball_icon(c, cx, cy, r):
    c.ellipse(cx, cy, r, r / 1.5, YEL)
    for t in range(-6, 7):
        u = t / 6
        c.px(cx - r * 0.55 + u * 2, cy + u * r / 1.5 * 0.8, WHT)
        c.px(cx + r * 0.55 - u * 2, cy + u * r / 1.5 * 0.8, WHT)


# ------------------------------------------------------------------ title
def title():
    c = Canvas(BLU)
    # night sky with stars, stadium roof arcs
    rng = random.Random(7)
    c.rect(0, 0, 511, 15, BLK)
    for i in range(70):
        c.px(rng.randrange(512), rng.randrange(14), WHT if rng.random() < 0.6 else LGR)
    # header band: MICROBEE
    m = text_mask('MICROBEE', FONT_SERIF, 30, track=6)
    c.rect(0, 16, 511, 31, BLK)
    stamp(c, m, centre_x(m), 17, YEL)
    # AUSTRALIAN OPEN in big italics, white on blue with a deep shadow
    c.rect(0, 32, 511, 111, BLU)
    for y in range(32, 112, 4):
        pass
    m = text_mask('AUSTRALIAN', FONT_BIG, 74, track=2)
    stamp(c, m, centre_x(m), 34, WHT, shadow=BLK)
    m = text_mask('OPEN', FONT_BIG, 74, track=4)
    stamp(c, m, centre_x(m), 74, WHT, shadow=BLK)
    # TENNIS in yellow on a cyan bar
    c.rect(0, 112, 511, 143, BBLU)
    m = text_mask('T E N N I S', FONT_BIG, 44, track=0)
    stamp(c, m, centre_x(m), 114, YEL, shadow=BLU)
    # a court in perspective at the bottom
    c.rect(0, 144, 511, 255, BBLU)
    top, bot = 150, 236
    for y in range(top, bot + 1):
        t = (y - top) / (bot - top)
        hw = 120 + 110 * t
        c.rect(0, y, 511, y, BBLU)
    for y in (top, bot):
        t = (y - top) / (bot - top)
        hw = 120 + 110 * t
        c.rect(int(256 - hw), y, int(256 + hw), y + (1 if y == bot else 0), WHT)
    for y in range(top, bot + 1):
        t = (y - top) / (bot - top)
        hw = 120 + 110 * t
        for s in (-1, 1):
            c.rect(int(256 + s * hw) - 1, y, int(256 + s * hw), y, WHT)
            c.rect(int(256 + s * hw * 0.75) - 1, y, int(256 + s * hw * 0.75), y, WHT)
    ys1, ys2 = 166, 214
    for y in (ys1, ys2):
        t = (y - top) / (bot - top)
        hw = (120 + 110 * t) * 0.75
        c.rect(int(256 - hw), y, int(256 + hw), y, WHT)
    c.rect(255, ys1, 256, ys2, WHT)
    # net (mesh at a whole cell row: rows 176..191)
    t = (188 - top) / (bot - top)
    hw = 120 + 110 * t + 8
    for y in range(178, 192):
        for x in range(int(256 - hw), int(256 + hw)):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0:
                c.px(x, y, BLK)
    c.rect(int(256 - hw), 176, int(256 + hw), 177, WHT)
    c.rect(0, 240, 511, 255, BLK)
    return c


# ------------------------------------------------------------------ info page
def info():
    c = Canvas(BLU)
    c.rect(0, 0, 511, 31, BLK)               # heading band, rows 0-1
    c.rect(0, 30, 511, 31, YEL)
    c.rect(0, 240, 511, 255, BLK)            # foot band, row 15
    c.rect(0, 240, 511, 241, YEL)
    # faint court lines down the sides
    for x in (16, 24, 487, 495):
        for y in range(40, 232, 2):
            c.px(x, y, BBLU)
    for i in range(6):
        ball_icon(c, 12 if i % 2 else 500, 48 + i * 32, 3)
    return c


# ------------------------------------------------------------------ trophy
def trophy():
    c = info()
    cx = 256
    # the cup: gold bowl, handles, stem, base (round things squashed for the tall pixels)
    G1, G2 = YEL, BRN
    c.ellipse(cx, 70, 46, 9, G2)
    c.poly([(cx - 46, 70), (cx + 46, 70), (cx + 30, 130), (cx - 30, 130)], G1)
    c.ellipse(cx, 130, 30, 8, G1)
    c.ellipse(cx, 70, 44, 7, G1)
    c.ellipse(cx, 71, 38, 5, G2)
    for s in (-1, 1):
        for t in range(40):
            a = math.pi * t / 39
            x = cx + s * (46 + 18 * math.sin(a))
            y = 78 + 30 * (1 - math.cos(a)) / 2
            c.rect(int(x) - 2, int(y), int(x) + 2, int(y) + 1, G1)
    c.rect(cx - 6, 136, cx + 6, 168, G1)
    c.rect(cx - 2, 136, cx + 1, 168, G2)
    c.rect(cx - 34, 168, cx + 34, 175, G1)
    c.rect(cx - 42, 176, cx + 42, 199, BRN)
    c.rect(cx - 36, 180, cx + 36, 195, BLK)
    for i in range(5):
        c.px(cx - 20 + i * 10, 187, YEL)
    # sparkle
    for (x, y) in ((cx - 30, 90), (cx + 20, 100), (cx - 8, 116)):
        c.rect(x, y - 2, x, y + 2, WHT)
        c.rect(x - 2, y, x + 2, y, WHT)
    return c


# ------------------------------------------------------------------ portraits
PORTRAIT_W, PORTRAIT_H = 8, 4                # cells: 64 x 64 pixels
SKIN = {'RUSTY': YEL, 'LOU': BMAG, 'NETTA': YEL, 'BAZZA': BRN, 'DUSTY': YEL,
        'RITA': BRN, 'PROF': YEL, 'MRVZ': YEL, 'YOU': YEL}


def portrait(ch):
    """64 x 64 (8 x 4 cells): a big-headed cartoon caricature.
    (pixels are tall: round things are drawn wide)"""
    W, H = 64, 64
    kit = {'RUSTY': BRED, 'LOU': BMAG, 'NETTA': BCYN, 'BAZZA': YEL, 'DUSTY': LGR,
           'RITA': BRN, 'PROF': WHT, 'MRVZ': YEL, 'YOU': WHT}[ch]
    bg = {'RUSTY': BLU, 'LOU': MAG, 'NETTA': BLU, 'BAZZA': GRN, 'DUSTY': DGR,
          'RITA': RED, 'PROF': BLU, 'MRVZ': MAG, 'YOU': BLU}[ch]
    skin = BRN if ch in ('BAZZA', 'RITA') else YEL
    c = Canvas(bg, W, H)
    cx = 32
    E = c.ellipse

    def eyes(y, r=4, gap=10, look=0, lash=False):
        for s in (-1, 1):
            E(cx + s * gap, y, r, r * 0.75 + 0.5, BLK)
            c.px(cx + s * gap - 1 + look, y - 1, skin)
            if lash:
                c.line(cx + s * gap - 4, y - 4, cx + s * gap - 6, y - 7, BLK)
                c.line(cx + s * gap + 4, y - 4, cx + s * gap + 6, y - 7, BLK)

    def grin(y, w=14, h=6, teeth=True):
        E(cx, y, w, h, BLK)
        c.rect(cx - w - 2, y - h - 2, cx + w + 2, y - 2, skin)   # cut the top: a big D
        if teeth:
            c.rect(cx - w + 4, y - 1, cx + w - 4, y + 1, skin)
            for x in range(cx - w + 7, cx + w - 4, 5):
                c.rect(x, y - 1, x, y + 1, BLK)

    # shirt and neck at the bottom
    E(cx, 70, 30, 14, kit)
    c.rect(cx - 6, 50, cx + 5, 58, skin)
    if ch == 'BAZZA':
        E(cx, 31, 27, 23, skin)                           # big square head
        c.rect(cx - 28, 4, cx + 28, 13, BLK)              # mullet on top
        c.rect(cx - 30, 10, cx - 22, 46, BLK)             # ... and long at the back
        c.rect(cx + 22, 10, cx + 30, 46, BLK)
        E(cx, 46, 24, 13, BLK)                            # the beard
        c.rect(cx - 12, 36, cx + 11, 39, skin)
        grin(41, 9, 3, teeth=True)
        eyes(22, r=2, gap=9)
        c.rect(cx - 4, 25, cx + 3, 33, WHT)               # zinc cream on the nose
        c.rect(cx - 16, 15, cx - 5, 17, BLK)              # bushy brows
        c.rect(cx + 4, 15, cx + 15, 17, BLK)
    elif ch == 'RUSTY':
        E(cx - 26, 30, 6, 8, skin)                        # sticky-out ears
        E(cx + 26, 30, 6, 8, skin)
        E(cx, 31, 22, 20, skin)
        E(cx, 8, 24, 7, BRED)                             # cap, backwards
        c.rect(cx + 14, 11, cx + 30, 14, BRED)
        for x in (cx - 22, cx - 16, cx + 18):            # ginger tufts
            c.line(x, 14, x - 3, 8, BRN)
        eyes(27, r=3, gap=9, look=1)
        for (x, y) in ((cx - 14, 33), (cx - 11, 35), (cx + 11, 33), (cx + 14, 35), (cx - 17, 35), (cx + 17, 34)):
            c.px(x, y, BRN)                               # freckles
        grin(41, 13, 7)
        c.rect(cx - 3, 39, cx + 2, 44, WHT)               # buck teeth
    elif ch == 'LOU':
        E(cx + 22, 14, 12, 10, WHT)                       # the enormous ponytail
        E(cx + 28, 30, 5, 13, WHT)
        E(cx, 32, 21, 20, skin)
        E(cx, 10, 22, 8, WHT)                             # fringe
        c.rect(cx - 21, 15, cx + 21, 18, WHT)             # sweatband
        eyes(27, r=3, gap=9, lash=True)
        c.line(cx - 8, 42, cx + 10, 39, BLK)              # a lopsided smile
        c.line(cx - 8, 43, cx + 10, 40, BLK)
        c.px(cx + 11, 38, BLK)
    elif ch == 'NETTA':
        E(cx, 31, 20, 21, skin)
        E(cx, 32, 20, 6, skin)
        E(cx, 9, 20, 7, BRN)                              # hair and bun
        E(cx, 2, 7, 4, BRN)
        c.rect(cx - 20, 13, cx + 20, 16, BCYN)            # headband
        for s in (-1, 1):                                 # narrowed, determined eyes
            c.rect(cx + s * 9 - 5, 25, cx + s * 9 + 4, 27, BLK)
            c.line(cx + s * 9 - 5 * s, 21, cx + s * 9 + 5 * s, 24, BLK)
        grin(42, 12, 5)                                   # gritted teeth
        E(cx, 50, 9, 3, skin)                             # a big chin
    elif ch == 'DUSTY':
        E(cx, 34, 18, 22, skin)                           # long face
        E(cx, 14, 28, 6, LGR)                             # bucket hat brim, low
        E(cx, 8, 16, 8, LGR)
        c.rect(cx - 12, 22, cx - 5, 23, BLK)              # sleepy eyes
        c.rect(cx + 4, 22, cx + 11, 23, BLK)
        c.rect(cx - 13, 37, cx + 12, 40, BLK)             # droopy moustache
        c.rect(cx - 13, 41, cx - 10, 46, BLK)
        c.rect(cx + 9, 41, cx + 12, 46, BLK)
        c.rect(cx - 5, 47, cx + 4, 47, BLK)               # deadpan mouth
        for k in range(14):                               # stubble
            c.px(cx - 12 + (k * 7) % 25, 49 + (k % 3), BLK)
    elif ch == 'RITA':
        for k in range(6):                                # hair streaming in the wind
            c.line(cx - 4, 8 + k * 6, cx + 30, 4 + k * 7, BLK)
            c.line(cx - 4, 9 + k * 6, cx + 30, 5 + k * 7, BLK)
        E(cx - 2, 31, 20, 20, skin)
        E(cx - 2, 12, 20, 8, BLK)
        for k in range(3):                                # speed lines
            c.rect(1, 22 + k * 8, 7, 22 + k * 8, WHT)
        eyes(26, r=5, gap=9)
        E(cx - 2, 42, 6, 5, BLK)                          # 'whoa!'
    elif ch == 'PROF':
        E(cx, 30, 24, 23, skin)                           # the great dome
        c.rect(cx - 25, 30, cx - 20, 40, LGR)             # grey tufts at the side
        c.rect(cx + 19, 30, cx + 24, 40, LGR)
        for s in (-1, 1):                                 # enormous round glasses
            E(cx + s * 10, 31, 9, 7, BLK)
            E(cx + s * 10, 31, 6, 4, skin)
            E(cx + s * 10, 31, 2, 1.5, BLK)
        c.rect(cx - 2, 30, cx + 1, 31, BLK)
        c.rect(cx - 4, 45, cx + 3, 46, BLK)               # a small knowing mouth
        c.poly([(cx - 8, 54), (cx, 57), (cx - 8, 60)], RED)   # bow tie
        c.poly([(cx + 7, 54), (cx, 57), (cx + 7, 60)], RED)
    elif ch == 'MRVZ':
        E(cx, 32, 22, 21, skin)
        E(cx + 4, 9, 20, 8, BLK)                          # a slick quiff
        E(cx + 14, 5, 10, 4, BLK)
        c.rect(cx - 22, 21, cx + 22, 29, BLK)             # wraparound shades
        c.rect(cx - 15, 22, cx - 11, 23, WHT)
        c.rect(cx + 8, 22, cx + 12, 23, WHT)
        grin(42, 15, 7)                                   # the champion's grin
        c.rect(cx - 1, 0, cx + 1, 3, YEL)                 # a twinkle
        c.rect(cx - 3, 1, cx + 3, 1, YEL)
    else:   # YOU
        E(cx, 31, 21, 21, skin)
        E(cx, 11, 22, 8, BRN)
        c.rect(cx - 21, 14, cx + 21, 17, BRED)            # headband
        eyes(27, r=4, gap=9, look=1)
        grin(41, 14, 7)
        E(cx + 21, 22, 2, 3, BCYN)                        # a bead of sweat
    return c


def compile_any(c, mono, level=None):
    a = c.a
    if mono:
        from mkcourts import MONO_LEVEL
        bits = mono_bits(a, level or MONO_LEVEL)
        pats = compile_mono(bits)
        ink = np.full(pats.shape[:2], 15, np.uint8)
        paper = np.zeros(pats.shape[:2], np.uint8)
        return pats, ink, paper
    return compile_cells(a)


if __name__ == '__main__':
    for name, f in (('title', title), ('info', info), ('trophy', trophy)):
        p, i, pa = compile_any(f(), False)
        preview(p, i, pa, '/home/claude/aot/shots/pic_%s.png' % name)
        p, i, pa = compile_any(f(), True)
        preview_mono(p, '/home/claude/aot/shots/pic_%s_mono.png' % name)
    sheet = Canvas(BLK, 64 * 9, 64)
    a = sheet.a
    for k, ch in enumerate(players.CHARS):
        a[:, k * 64:(k + 1) * 64] = portrait(ch).a
    sheet.set(a)
    p, i, pa = compile_cells(sheet.a)
    preview(p, i, pa, '/home/claude/aot/shots/portraits.png')
