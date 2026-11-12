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


def logo(p):
    """FRILLSEEKER in the font's 5 x 7 face, each dot 3 x 4"""
    text = 'FRILLSEEKER'
    x0 = (320 - (len(text) * 18 - 3)) // 2
    for i, ch in enumerate(text):
        rows = font.F57[ch].split(',')
        for j, row in enumerate(rows):
            for k, d in enumerate(row):
                if d == '1':
                    x, y = x0 + i * 18 + k * 3, 6 + j * 4
                    p.c[y:y + 4, x:x + 3] = YELLOW
                    p.m[y:y + 4, x:x + 3] = 15
                    p.c[y + 3, x:x + 3] = BROWN          # a shaded underside
                    p.m[y + 3, x:x + 3] = 0 if j == 6 else 15


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
