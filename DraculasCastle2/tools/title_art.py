# title_art.py - title screen artwork (128x64 CSS0)
import math, random
from PIL import Image, ImageDraw, ImageFont
from monsters import Canvas, G, Y, B, R, T

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'

def big_text(c, text, y, size, x0=None, track=1):
    f = ImageFont.truetype(FONT, size)
    # render each glyph at 4x then box-downsample for clean shapes
    ss = 4
    im = Image.new('L', (128 * ss, 20 * ss), 0)
    d = ImageDraw.Draw(im)
    fs = ImageFont.truetype(FONT, size * ss)
    w = sum(d.textlength(ch, font=fs) for ch in text) + track * ss * (len(text) - 1)
    x = (128 * ss - w) / 2 if x0 is None else x0 * ss
    for ch in text:
        d.text((x, 0), ch, font=fs, fill=255)
        x += d.textlength(ch, font=fs) + track * ss
    im = im.resize((128, 20), Image.BOX)
    p = im.load()
    bb = [(xx, yy) for yy in range(20) for xx in range(128) if p[xx, yy] > 110]
    top = min(yy for _, yy in bb)
    pts = set((xx, yy - top) for xx, yy in bb)
    hgt = max(yy for _, yy in pts) + 1
    for (xx, yy) in pts:
        col = Y if yy < hgt * 0.45 else ((Y, R, 50) if yy < hgt * 0.7 else R)
        c.px(xx, y + yy, c.pat(col, xx, y + yy))
    # blood drips under some letters
    rnd = random.Random(size)
    bottoms = {}
    for (xx, yy) in pts: bottoms[xx] = max(bottoms.get(xx, -1), yy)
    for xx, yy in bottoms.items():
        if yy == hgt - 1 and rnd.random() < 0.18:
            for k in range(1, rnd.choice((2, 2, 3, 4))): c.px(xx, y + yy + k, R)
    # dark outline
    for (xx, yy) in list(pts):
        for dx, dy in ((1, 1), (1, 0), (0, 1)):
            q = (xx + dx, yy + dy)
            if q not in pts and c.p[y + q[1]][q[0]] not in (R,):
                c.px(q[0], y + q[1], B)
    return hgt

def title_screen():
    c = Canvas(128, 64, B)
    rnd = random.Random(7)
    # sky glow towards horizon
    for y in range(22, 47):
        for x in range(128):
            col = (B, R, 25) if y < 28 else ((B, R, 50) if y < 34 else ((R, B, 25) if y < 40 else R))
            c.p[y][x] = c.pat(col, x, y)
    for _ in range(26):
        c.px(rnd.randrange(128), rnd.randrange(0, 24), Y)
    # moon
    c.ellipse(66, 35, 11, 9, Y)
    c.ellipse(62, 32, 2.5, 2, (Y, B, 25)); c.ellipse(71, 38, 2, 1.6, (Y, B, 25)); c.ellipse(69, 31, 1.2, 1, (Y, B, 25))
    # castle silhouette
    base = 49
    c.rect(30, 42, 100, base, B)
    towers = [(33, 36, 3), (47, 33, 3), (64, 29, 4), (81, 33, 3), (97, 37, 3)]
    for tx, th, tw in towers:
        c.rect(tx - tw, th, tx + tw, base, B)
        c.poly([(tx - tw - 1, th), (tx, th - tw * 2 - 1), (tx + tw + 1, th)], B)
    for x in range(30, 101, 3): c.rect(x, 40, x, 41, B)
    for wx, wy in ((33, 39), (47, 36), (64, 33), (64, 38), (81, 36), (97, 40), (55, 44), (73, 44)):
        c.rect(wx, wy, wx, wy + 1, Y)
    c.rect(61, 45, 67, base, R); c.ellipse(64, 45, 3, 2, R)
    # ground
    for y in range(base, 64):
        for x in range(128): c.p[y][x] = c.pat((B, R, 25) if y < base + 2 else B, x, y)
    # bats
    for bx, by in ((58, 30), (72, 27), (84, 31), (100, 25), (40, 27)):
        c.px(bx, by, B); c.px(bx - 1, by - 1, B); c.px(bx + 1, by - 1, B); c.px(bx - 2, by, B); c.px(bx + 2, by, B)
    # logo
    big_text(c, "DRACULA'S", 0, 14, track=0)
    big_text(c, "CASTLE II", 13, 14, track=1)
    return c

if __name__ == '__main__':
    from gfx import PAL
    c = title_screen()
    im = Image.new('RGB', (128, 64))
    for y in range(64):
        for x in range(128): im.putpixel((x, y), PAL[c.p[y][x]])
    im.resize((512, 384), Image.NEAREST).save('/home/claude/dc2/shots/title.png')
