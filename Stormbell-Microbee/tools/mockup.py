"""A still of two fighters on a stage, composed exactly as the game does
(each fighter cell: the fighter's glyph and ink over the stage cell's
paper; where ink would equal paper the paper goes black)."""
import numpy as np
import art
import fighters as F

BAND_ROW = 10


def compose(pic, a, fa, xa, b, fb, xb):
    ink, ci, cp = pic.cells()
    ink = ink.copy(); ci = ci.copy(); cp = cp.copy()
    for k, (f, fr, x, mir) in enumerate(((a, fa, xa, False), (b, fb, xb, True))):
        name, fink, fcol, jt = F.frames(f, mir)[F.NAMES.index(fr)]
        cc = F.cellcol(fink, fcol)
        anchor = F.CW - 1 - F.AC if mir else F.AC
        for cy in range(F.CH):
            for cx in range(F.CW):
                cell = fink[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
                if not cell.any():
                    continue
                X, Y = x - anchor + cx, BAND_ROW + cy
                if not 0 <= X < 40:
                    continue
                ink[Y * 8:Y * 8 + 8, X * 8:X * 8 + 8] = cell
                ci[Y, X] = cc[cy, cx]
                if cp[Y, X] == ci[Y, X]:
                    cp[Y, X] = art.BLACK
    pal = np.array(art.PAL, np.uint8)
    fg = pal[np.repeat(np.repeat(ci, 8, 0), 8, 1)]
    bg = pal[np.repeat(np.repeat(cp, 8, 0), 8, 1)]
    return np.where(ink[:, :, None], fg, bg)


if __name__ == '__main__':
    import sys
    from PIL import Image
    poses = [('stand', 'stand'), ('punch', 'guard'), ('kick', 'hit'), ('stand', 'kick'), ('step2', 'punch')]
    ims = []
    for i, (n, fn) in enumerate(art.PICS[1:6]):
        ims.append(compose(fn(), F.FIGHTERS[0], poses[i][0], 15, F.FIGHTERS[i + 1], poses[i][1], 24))
    ims.append(np.zeros_like(ims[0]))
    rows = [np.concatenate(ims[i:i + 2], 1) for i in range(0, 6, 2)]
    sh = np.concatenate(rows, 0)
    Image.fromarray(sh).resize((int(sh.shape[1] * 1.25 * 1.4), int(sh.shape[0] * 1.4)), Image.NEAREST).save(sys.argv[1])
