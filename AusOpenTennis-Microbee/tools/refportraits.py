"""The tour's portraits from BPM's reference art (resources/portraits_ref.png):
nine 241 x 365 panels, reduced to 80 x 80 Microbee pixels (10 x 5 cells).
Black outlines win when they cover enough of a pixel, so the ink lines survive."""
import numpy as np
from PIL import Image
from cells import PAL, PALA, BLK, RED, GRN, BRN, BLU, MAG, CYN, LGR, DGR, BRED, YEL, BBLU, BMAG, WHT, Canvas
import os

REF = os.path.join(os.path.dirname(__file__), '..', 'resources', 'portraits_ref.png')
# panel order in the reference -> character
ORDER = ['YOU', 'LOU', 'RUSTY', 'BAZZA', 'NETTA', 'RITA', 'PROF', 'MRVZ', 'DUSTY']
PW, PH = 80, 80
USE = [BLK, RED, GRN, BRN, BLU, MAG, LGR, DGR, BRED, YEL, BBLU, BMAG, WHT]


def nearest(rgb):
    p = PALA[USE]
    d = ((rgb[..., None, :].astype(int) - p[None, None, :, :]) ** 2).sum(-1)
    return np.array(USE)[d.argmin(-1)]


def panels():
    im = np.array(Image.open(REF).convert('RGB'))
    y0, y1 = 177, 542
    w = im.shape[1] / 9
    out = {}
    for k, ch in enumerate(ORDER):
        x0, x1 = int(round(k * w)) + 6, int(round((k + 1) * w)) - 6
        out[ch] = im[y0:y1, x0:x1]
    return out


def reduce_panel(p):
    lab = nearest(p)
    H, W = lab.shape
    out = np.zeros((PH, PW), np.uint8)
    for y in range(PH):
        a, b = int(y * H / PH), max(int((y + 1) * H / PH), int(y * H / PH) + 1)
        for x in range(PW):
            c, d = int(x * W / PW), max(int((x + 1) * W / PW), int(x * W / PW) + 1)
            blk = lab[a:b, c:d].ravel()
            if (blk == BLK).mean() >= 0.3:
                out[y, x] = BLK
            else:
                v = blk[blk != BLK]
                vals, cnt = np.unique(v, return_counts=True)
                out[y, x] = vals[cnt.argmax()]
    return out


def portrait(ch):
    c = Canvas(BLK, PW, PH)
    c.set(reduce_panel(panels()[ch]))
    return c


if __name__ == '__main__':
    from cells import compile_cells, preview
    P = panels()
    sheet = Canvas(BLK, PW * 9, PH)
    a = sheet.a
    for k, ch in enumerate(['RUSTY', 'LOU', 'NETTA', 'BAZZA', 'DUSTY', 'RITA', 'PROF', 'MRVZ', 'YOU']):
        a[:, k * PW:(k + 1) * PW] = reduce_panel(P[ch])
    sheet.set(a)
    p, i, pa = compile_cells(sheet.a)
    preview(p, i, pa, '/home/claude/aot/shots/portraits2.png', scale=2)
    sheet.save('/home/claude/aot/shots/portraits2_raw.png', scale=2)
