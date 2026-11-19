"""VZ300 mode 1 palette + preview helpers"""
from PIL import Image

CSS0 = [(0x30, 0xd2, 0x00), (0xc1, 0xe5, 0x00), (0x4c, 0x3a, 0xb4), (0x9a, 0x32, 0x36)]
CSS1 = [(0xbf, 0xc8, 0xad), (0x41, 0xaf, 0x71), (0xc8, 0x4e, 0xf0), (0xd4, 0x7f, 0x00)]


def pix_image(rows, css=0, sx=2, sy=3):
    """rows: list of lists of colour indices -> PIL image at TV aspect"""
    pal = CSS1 if css else CSS0
    h = len(rows); w = max(len(r) for r in rows)
    im = Image.new('RGB', (w * sx, h * sy))
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            col = pal[c & 3]
            for yy in range(sy):
                for xx in range(sx):
                    px[x * sx + xx, y * sy + yy] = col
    return im


def pack_row(px):
    """list of colour indices (multiple of 4) -> bytes, pixel 0 in bits 7-6"""
    out = bytearray()
    for i in range(0, len(px), 4):
        b = 0
        for k in range(4):
            b = (b << 2) | (px[i + k] & 3)
        out.append(b)
    return bytes(out)


def unpack_screen(data, w=128, h=64):
    rows = []
    for y in range(h):
        r = []
        for x in range(w // 4):
            b = data[y * (w // 4) + x]
            for k in range(4):
                r.append((b >> (6 - 2 * k)) & 3)
        rows.append(r)
    return rows
