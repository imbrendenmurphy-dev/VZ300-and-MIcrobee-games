"""BILBIES! Microbee HUD: font, the twelve buttons and the panel layout.
Writes build/GFX.BNK (block 3):
  0000  PCG banks 12-15 (8K): bank 12 font (ASCII 32-95) + panel bits,
        banks 13-14 button art, bank 15 minimap (made by the game)
  2000  panel screen codes, rows 10-15 (6 x 64)
  2180  attributes
  2300  colours (colour monitor)
  2480  colours (monochrome)
"""
import os
import sys
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, 'orig'))
import world
import bilby
from world import scale2x

ROOT = os.path.dirname(HERE)
BUILD = os.path.join(ROOT, 'build')
_cwd = os.getcwd()
os.chdir(os.path.join(HERE, 'orig'))
import art as vzart          # the VZ original's 3 x 5 font and icons
os.chdir(_cwd)

BK_HUD = 12
BLK, RED, GRN, BRN, BLU, MAG, CYN, LGR, DGR, LRED, LGRN, YEL, LBLU, LMAG, LCYN, WHT = range(16)


def glyph_bytes(a):
    """16 x 8 bool -> 16 bytes"""
    return bytes(int(''.join('1' if v else '0' for v in r), 2) for r in a)


def font():
    """ASCII 32-95 from the original's 3 x 5 letters, doubled and smoothed:
    6 x 10 in the 8 x 16 cell (rows 3-12)"""
    out = []
    for code in range(32, 96):
        rows = vzart.F.get(chr(code), vzart.F[' '])
        a = np.array([[c == 'Y' for c in r] for r in rows], np.int8)
        big = scale2x(scale2x(a))[::2, ::2]        # smooth diagonals at 2x
        g = np.zeros((16, 8), bool)
        g[3:13, 1:7] = big[:10, :6].astype(bool)
        out.append(g)
    return out


def bilby_icon(gen, frame, flip=False):
    g = gen(frame)
    if flip:
        g = g.mirror()
    on = g.a == 1
    return on


def place(cell_img, icon, ox, oy):
    h, w = icon.shape
    for y in range(h):
        for x in range(w):
            if icon[y, x]:
                yy, xx = oy + y, ox + x
                if 0 <= yy < cell_img.shape[0] and 0 <= xx < cell_img.shape[1]:
                    cell_img[yy, xx] = True


def up2(a):
    return np.repeat(np.repeat(a, 2, 0), 2, 1)


def button_art():
    """12 buttons, each 32 x 48 pixels (4 x 3 cells): rate -, rate +, the
    eight skills (the bilby doing it, twice the size of a playfield bilby),
    pause, nuke"""
    arts = []

    def blank():
        return np.zeros((48, 32), bool)

    a = blank()
    a[22:27, 8:24] = True
    arts.append(a)
    a = blank()
    a[22:27, 8:24] = True
    a[16:33, 14:18] = True
    arts.append(a)
    poses = [(bilby.climb, 2), (bilby.float_, 6), (bilby.ohno, 4), (bilby.block, 1),
             (bilby.build, 4), (bilby.bash, 2), (bilby.mine, 3), (bilby.dig, 2)]
    for gen, fr in poses:
        a = blank()
        on = bilby_icon(gen, fr)
        big = up2(on.astype(np.int8)).astype(bool)          # 36 x 36
        place(a, big[:, 2:34], 0, 8)
        arts.append(a)
    a = blank()
    a[10:38, 8:13] = True
    a[10:38, 19:24] = True
    arts.append(a)
    a = blank()                                            # a mushroom cloud
    yy, xx = np.mgrid[0:48, 0:32]
    a |= ((xx - 16) / 11.0) ** 2 + ((yy - 14) / 7.0) ** 2 <= 1
    a |= (np.abs(xx - 16) <= 3) & (yy >= 18) & (yy < 36)
    a |= ((xx - 16) / 13.0) ** 2 + ((yy - 38) / 4.0) ** 2 <= 1
    a &= ~(((xx - 16) / 6.0) ** 2 + ((yy - 13) / 2.5) ** 2 <= 1)
    arts.append(a)
    return arts


def build():
    pcg = np.zeros((4 * 128, 16, 8), bool)        # banks 12-15
    fnt = font()
    for i, g in enumerate(fnt):
        pcg[i] = g
    # glyph 64: a full block, 65: blank (kept), 66-69: panel edges
    pcg[64][:, :] = True
    # buttons: bank 13 from glyph 0 (128 + ...): 12 per button
    arts = button_art()
    BTN0 = 128
    for b, a in enumerate(arts):
        for r in range(3):
            for c in range(4):
                pcg[BTN0 + b * 12 + r * 4 + c] = a[r * 16:(r + 1) * 16, c * 8:(c + 1) * 8]
    pcgb = b''.join(glyph_bytes(g) for g in pcg)

    # layout rows 10-15
    codes = np.zeros((6, 64), np.uint8)
    attrs = np.zeros((6, 64), np.uint8)
    cols = np.zeros((6, 64), np.uint8)
    mcols = np.zeros((6, 64), np.uint8)

    def setc(r, c, glyph, col, mcol):
        codes[r, c] = 0x80 | (glyph & 127)
        attrs[r, c] = BK_HUD + glyph // 128
        cols[r, c] = col
        mcols[r, c] = mcol
    for r in range(6):
        for c in range(64):
            setc(r, c, 0, (BLK << 4) | WHT, (BLK << 4) | WHT)     # blank (space)
    for c in range(64):
        setc(0, c, 0, (BLU << 4) | YEL, (8 << 4) | WHT)            # status line
    for b in range(12):
        for c in range(4):
            setc(1, b * 4 + c, 0, (BLU << 4) | WHT, (BLK << 4) | WHT)  # counts row
            for r in range(3):
                g = BTN0 + b * 12 + r * 4 + c
                ink = YEL if 2 <= b < 10 else WHT
                setc(2 + r, b * 4 + c, g, (BLU << 4) | ink, (BLK << 4) | LGR)
    for c in range(48):
        setc(5, c, 0, (BLK << 4) | LGR, (BLK << 4) | LGR)          # name line
    # minimap: bank 15 glyphs 0-79, cols 48-63, rows 11-15
    for r in range(5):
        for c in range(16):
            g = 3 * 128 + r * 16 + c
            setc(1 + r, 48 + c, g, (BLK << 4) | LGRN, (BLK << 4) | LGR)
    bank = bytearray(32768)
    bank[0:8192] = pcgb
    bank[0x2000:0x2000 + 384] = codes.tobytes()
    bank[0x2180:0x2180 + 384] = attrs.tobytes()
    bank[0x2300:0x2300 + 384] = cols.tobytes()
    bank[0x2480:0x2480 + 384] = mcols.tobytes()
    open(os.path.join(BUILD, 'GFX.BNK'), 'wb').write(bytes(bank[:0x2600]))
    print('GFX.BNK: HUD font and buttons')


if __name__ == '__main__':
    build()
