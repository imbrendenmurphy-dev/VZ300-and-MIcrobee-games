"""The title picture: 320 x 176 (cell rows 0-21; rows 22-24 are left black
for text), painted like a room - sky, sun, range, a gum, red dirt - with
Bluff in full bluff, drawn three times the size by the same puppet, and
two cane toads flung on to their backs. In colour and for amber.

Record (16K): npat (word) at 0, screen codes at $100, banks at $500,
colours at $900, glyph patterns at $D00 (up to 1408, PCG banks 0-10)."""
import numpy as np
import rooms as R
import hero
import critters
import font
from art import *

T_SCR, T_ATTR, T_COL, T_PAT, T_SIZE = 0x100, 0x500, 0x900, 0xD00, 0x4000
SCENE = dict(name='TITLE', sun=(266, 100, 30),
             mesa=[(0, 120), (40, 120), (48, 104), (110, 104), (118, 128), (200, 128), (208, 112), (320, 112)],
             trees=[(28, 144, 90)])


def stamp(p, ink, cut, x0, y0, col):
    h, w = ink.shape
    ys, xs = slice(y0, y0 + h), slice(x0, x0 + w)
    p.c[ys, xs][cut] = BLACK
    p.m[ys, xs][cut] = 0
    p.c[ys, xs][ink] = col
    p.m[ys, xs][ink] = 15


# ---- the logo: its own heavy, slanted, chamfered letters (not the font)
TX, TY = 0.30, 0.20         # stroke: stem width, bar height, of the letter box


def _bar(y0, x1=1.0, slant=0.12):
    """a bar from the stem to x1, its free end cut on the slant"""
    return [(0, y0), (x1, y0), (x1 - slant, y0 + TY), (0, y0 + TY)]


STEM = [(0, 0), (TX, 0), (TX, 1), (0, 1)]
LETTERS = {
    'F': ([STEM, _bar(0), _bar(0.41, 0.80)], []),
    'I': ([[(0, 0), (1, 0), (1, 1), (0, 1)]], []),
    'L': ([STEM, [(0, 1 - TY), (0.86, 1 - TY), (1.0, 1), (0, 1)]], []),
    'E': ([STEM, _bar(0), _bar(0.39, 0.76), [(0, 1 - TY), (0.88, 1 - TY), (1.0, 1), (0, 1)]], []),
    'R': ([STEM, [(0, 0), (0.84, 0), (1, 0.14), (1, 0.46), (0.84, 0.60), (0, 0.60)],
           [(0.36, 0.56), (0.70, 0.56), (1.06, 1), (0.70, 1)]],
          [[(TX, TY), (1 - TX, TY), (1 - TX, 0.60 - TY), (TX, 0.60 - TY)]]),
    'K': ([STEM, [(TX - 0.02, 0.40), (0.62, 0), (1.02, 0), (TX + 0.14, 0.64), (TX - 0.02, 0.64)],
           [(0.30, 0.50), (0.54, 0.36), (1.06, 1), (0.70, 1)]], []),
    'S': ([[(0.14, 0), (1, 0), (0.88, TY), (0, TY), (0, 0.14)],
           [(0, 0.10), (TX, 0.10), (TX, 0.61), (0.14, 0.61), (0, 0.47)],
           [(0, 0.39), (0.86, 0.39), (1, 0.53), (1, 0.61), (0, 0.61)],
           [(1 - TX, 0.45), (1, 0.45), (1, 0.86), (0.86, 1), (1 - TX, 1)],
           [(0, 1 - TY), (0.12, 1 - TY), (1, 1 - TY), (1, 0.90), (0.86, 1), (0, 1)]],
          [[(0, 1 - TY), (0.12, 1 - TY), (0, 1)]]),
}
SHEAR = 0.24
LOGO_BANDS = [WHITE, YELLOW, YELLOW, BROWN, BRED, RED]      # a cell row each, top to bottom


def letter(ch, w, h):
    """-> (h, w + slant) boolean"""
    from PIL import Image, ImageDraw
    S = 8
    ex = int(h * SHEAR) + 3
    im = Image.new('L', ((w + ex) * S, h * S), 0)
    d = ImageDraw.Draw(im)
    polys, cuts = LETTERS[ch]

    def tr(pts):
        return [((x * w + (1 - y) * h * SHEAR) * S, y * h * S) for x, y in pts]
    for pl in polys:
        d.polygon(tr(pl), fill=255)
    for pl in cuts:
        d.polygon(tr(pl), fill=0)
    a = np.asarray(im, np.float32).reshape(h, S, w + ex, S).mean(axis=(1, 3))
    return a > 127


def logo_mask():
    """the logo as a 48 x 320 mask"""
    m = np.zeros((48, 320), np.uint8)
    text = 'FRILLSEEKER'
    W, H, GAP, WI = 20, 28, 5, 8
    BW, BH = 27, 40                      # the F and the last R stand taller
    widths = [BW if i in (0, len(text) - 1) else (WI if ch == 'I' else W) for i, ch in enumerate(text)]
    total = sum(widths) + GAP * (len(text) - 1) + int(H * SHEAR)
    x = (320 - total) // 2
    top = 5
    ink = np.zeros((48, 320), bool)
    edges = []
    for i, ch in enumerate(text):
        big = i in (0, len(text) - 1)
        w, h = widths[i], (BH if big else H)
        g = letter(ch, w, h)
        # a taller letter leans from the same baseline slope: line its top up
        dx = 0 if big else int((BH - H) * SHEAR)
        ink[top:top + h, x + dx - (int((BH - H) * SHEAR) if big else 0) + 4:][:, :g.shape[1]] |= g
        edges.append(x)
        x += w + GAP
    # the frill's edge, under the letters between the two tall ones
    x0, x1 = edges[1] + 2, edges[-1] + 2
    for xx in range(x0, x1):
        k = (xx - x0) % 10
        depth = 2 + (k if k < 5 else 9 - k)
        ink[top + H + 3:top + H + 3 + depth, xx] = True
    # speed lines trailing off the F
    fx = edges[0]
    for k, (yy, ln) in enumerate(((top + 9, 16), (top + 17, 26), (top + 25, 12), (top + 33, 20))):
        x1 = fx + int((BH - (yy - top)) * SHEAR) - 2
        ink[yy:yy + 2, max(0, x1 - ln):x1] = True
    m[ink] = 1
    return m


def logo(p):
    m = logo_mask()
    p.c[:48, :] = BLACK
    p.m[:48, :] = 0
    for r in range(6):
        ys = slice(r * 8, r * 8 + 8)
        on = m[ys] > 0
        p.c[ys][on] = LOGO_BANDS[r]
        p.m[ys][on] = 15
    # a few stars in the gaps
    rng = np.random.RandomState(7)
    for i in range(26):
        x, y = rng.randint(2, 318), rng.randint(1, 47)
        if not m[max(0, y - 3):y + 4, max(0, x - 4):x + 5].any():
            p.c[y, x] = WHITE if i % 3 else BCYAN
            p.m[y, x] = 15


def paint(ph=0):
    p = R.Paint(4242, ph)
    R.sky(p, SCENE)
    R.mesa(p, SCENE)
    for t in SCENE['trees']:
        R.gum_tree(p, *t)
    mp = ['.' * 20] * 9 + ['#' * 20] * 2
    for ty in (10, 9):
        for tx in range(20):
            R.dirt(p, mp, tx, ty)
    logo(p)
    # Bluff, three times the size, frill wide open
    hero.K = 3
    c = hero.pose(head=hero.HEAD_HISS, frill_t=1.0, lean=1.6, tailup=0.7, tail=1.8, bob=-0.6,
                  arms=((8.2, -14.0), (8.6, -15.4)), legs=((3.0, 0), (-2.8, 0)))
    hero.K = 1
    ink, cut = c.ink, c.cut
    stamp(p, ink, cut, 128 - hero.OX * 3, 145 - hero.OY * 3, YELLOW)
    # the toads he has seen off
    F = critters.frames()
    for name, x, y, col in (('TOAD_BACK0', 236, 144, BGREEN), ('TOAD_EEK', 204, 92, BGREEN), ('BUG0', 92, 60, WHITE),
                            ('BUG1', 300, 70, WHITE), ('BUG0', 180, 50, WHITE)):
        ink, cut, ox, oy = F[name]
        stamp(p, ink, cut, x - ox, y - oy, col)
    return p


def compile_title(mono):
    p = paint()
    img = p.m if mono else p.c
    pat, ink, pap = cells_from_image(img, solid=mono)
    glyphs = {bytes(8): 0}
    scr = np.full(1000, 0x80, np.uint8)
    att = np.zeros(1000, np.uint8)
    col = np.full(1000, 0x0F, np.uint8)
    for r in range(22):
        for c in range(40):
            k = bytes(pat[r, c])
            if k not in glyphs:
                glyphs[k] = len(glyphs)
            g = glyphs[k]
            i = r * 40 + c
            scr[i] = 0x80 | (g & 0x7F)
            att[i] = g >> 7
            col[i] = 0x0F if mono else (int(pap[r, c]) << 4) | int(ink[r, c])
    n = len(glyphs)
    assert n <= 1408, n
    d = bytearray(T_SIZE)
    d[0], d[1] = n & 255, n >> 8
    d[T_SCR:T_SCR + 1000] = scr.tobytes()
    d[T_ATTR:T_ATTR + 1000] = att.tobytes()
    d[T_COL:T_COL + 1000] = col.tobytes()
    for k, g in glyphs.items():
        d[T_PAT + g * 8:T_PAT + g * 8 + 8] = k
    return bytes(d), n, image_from_cells(pat, ink, pap, mono)


if __name__ == '__main__':
    import sys
    for mono in (False, True):
        d, n, rgb = compile_title(mono)
        save_png(rgb, '%s/title%s.png' % (sys.argv[1], 'm' if mono else ''))
        print('mono' if mono else 'colour', n, 'glyphs')
