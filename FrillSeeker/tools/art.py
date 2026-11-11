"""FRILLSEEKER art helpers.

The game runs in the Premium Plus's 40-column mode: 40 x 25 PCG cells of
8 x 8 pixels (320 x 200) at half the dot clock, so a pixel is a little
wider than it is tall and a cell is very nearly square, right across the
tube. A cell carries one ink and one paper colour.
"""
import numpy as np

CW, CH = 8, 8            # cell size, pixels
COLS, ROWS = 40, 25
PF_ROW0 = 2              # playfield starts at cell row 2
PF_ROWS = 22

PALETTE = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(16)
LUM = [0.299 * r + 0.587 * g + 0.114 * b for r, g, b in PALETTE]


def dilate(m, diag=True):
    o = m.copy()
    o[1:, :] |= m[:-1, :]
    o[:-1, :] |= m[1:, :]
    o[:, 1:] |= m[:, :-1]
    o[:, :-1] |= m[:, 1:]
    if diag:
        o[1:, 1:] |= m[:-1, :-1]
        o[1:, :-1] |= m[:-1, 1:]
        o[:-1, 1:] |= m[1:, :-1]
        o[:-1, :-1] |= m[1:, 1:]
    return o


def byte_rows(bits):
    """bool array (h, w) -> (h, w/8) bytes, leftmost pixel in bit 7"""
    h, w = bits.shape
    assert w % 8 == 0
    b = bits.astype(np.uint8).reshape(h, w // 8, 8)
    return (b * (1 << (7 - np.arange(8)))).sum(axis=2).astype(np.uint8)


def cells_from_images(imgs):
    """imgs: a list of (h, w) colour-index pictures of the same scene (the
    animation phases). -> patterns [phase](rows, cols, 6), ink, paper.
    Each cell keeps the two commonest colours over all phases; the rest go
    to the nearer. Paper is the darker of the two."""
    h, w = imgs[0].shape
    rows, cols = h // CH, w // CW
    pats = [np.zeros((rows, cols, CH), np.uint8) for _ in imgs]
    ink = np.zeros((rows, cols), np.uint8)
    pap = np.zeros((rows, cols), np.uint8)
    pal = np.array(PALETTE, np.float32)
    st = np.stack(imgs)
    for r in range(rows):
        for c in range(cols):
            blk = st[:, r * CH:(r + 1) * CH, c * CW:(c + 1) * CW]
            vals, cnt = np.unique(blk, return_counts=True)
            order = vals[np.argsort(-cnt, kind='stable')]
            if len(order) == 1:
                ink[r, c] = pap[r, c] = int(order[0])
                continue
            a, b = int(order[0]), int(order[1])
            if LUM[a] > LUM[b]:
                a, b = b, a          # a = paper (darker), b = ink
            d_a = ((pal[blk] - pal[a]) ** 2).sum(axis=3)
            d_b = ((pal[blk] - pal[b]) ** 2).sum(axis=3)
            bits = d_b < d_a
            for k in range(len(imgs)):
                pats[k][r, c] = byte_rows(bits[k])[:, 0]
            ink[r, c] = b
            pap[r, c] = a
    return pats, ink, pap


def cells_from_image(img):
    pats, ink, pap = cells_from_images([img])
    return pats[0], ink, pap


def image_from_cells(pat, ink, pap, mono=False):
    rows, cols = ink.shape
    out = np.zeros((rows * CH, cols * 8, 3), np.uint8)
    pal = np.array(PALETTE, np.uint8)
    for r in range(rows):
        for c in range(cols):
            for y in range(CH):
                v = pat[r, c, y]
                for x in range(8):
                    on = (v >> (7 - x)) & 1
                    if mono:
                        col = (255, 176, 0) if on else (0, 0, 0)
                    else:
                        col = pal[ink[r, c]] if on else pal[pap[r, c]]
                    out[r * CH + y, c * 8 + x] = col
    return out


def save_png(rgb, path, scale=3, aspect=0.8):
    """a 40-column pixel is about 1.25 times wider than it is tall"""
    from PIL import Image
    im = Image.fromarray(rgb)
    im = im.resize((im.width * scale, int(round(im.height * scale * aspect))), Image.NEAREST)
    im.save(path)
    return im


# ---------------------------------------------------------------- sprites
def sprite_variants(ink, cut):
    """ink, cut: bool (h, w) logical. The mask clears the background under
    the sprite and in a one-pixel halo round it.
    -> 8 pre-shifted variants (x & 7): bytes [ncols, then for each cell
    column: first line, lines n, n x (mask, image)] with mask bits
    1 = keep the background. A column holds only its used lines."""
    h, w = ink.shape
    solid = dilate(ink | cut, diag=False)
    out = []
    for sh in range(8):
        wp = ((w + sh + 2 + 7) // 8) * 8
        i2 = np.zeros((h, wp), bool)
        s2 = np.zeros((h, wp), bool)
        i2[:, sh:sh + w] = ink
        s2[:, sh:sh + w] = solid
        img = byte_rows(i2)
        msk = byte_rows(~s2)
        ncols = wp // 8
        while ncols > 1 and (msk[:, ncols - 1] == 0xFF).all():
            ncols -= 1
        d = bytearray([ncols])
        for c in range(ncols):
            used = np.where(msk[:, c] != 0xFF)[0]
            if len(used) == 0:
                d += bytes([0, 0])
                continue
            y0, y1 = int(used[0]), int(used[-1]) + 1
            d += bytes([y0, y1 - y0])
            for y in range(y0, y1):
                d.append(int(msk[y, c]))
                d.append(int(img[y, c]))
        out.append(bytes(d))
    return out


def parse(rows):
    """'#' ink, 'o' cut (forced dark), anything else transparent"""
    w = max(len(r) for r in rows)
    ink = np.zeros((len(rows), w), bool)
    cut = np.zeros((len(rows), w), bool)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch == '#':
                ink[y, x] = True
            elif ch == 'o':
                cut[y, x] = True
    return ink, cut
