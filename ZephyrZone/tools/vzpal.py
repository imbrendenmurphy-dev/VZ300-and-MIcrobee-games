# VZ300 mode 1 palettes (as the emulator renders them) and helpers
CSS0 = [(0x30,0xd2,0x00),(0xc1,0xe5,0x00),(0x4c,0x3a,0xb4),(0x9a,0x32,0x36)]
CSS1 = [(0xbf,0xc8,0xad),(0x41,0xaf,0x71),(0xc8,0x4e,0xf0),(0xd4,0x7f,0x00)]
from PIL import Image
def to_img(pix, css=0, sx=4, sy=6):
    """pix: list of 64 rows of 128 ints -> PIL image with 4:3-ish pixel aspect"""
    pal = CSS1 if css else CSS0
    h = len(pix); w = len(pix[0])
    im = Image.new('RGB', (w, h))
    im.putdata([pal[c & 3] for row in pix for c in row])
    return im.resize((w * sx, h * sy), Image.NEAREST)
def pack_rows(pix):
    out = bytearray()
    for row in pix:
        for xb in range(0, len(row), 4):
            b = 0
            for i in range(4): b |= (row[xb + i] & 3) << (6 - 2 * i)
            out.append(b)
    return bytes(out)
def unpack(data, w=128, h=64):
    pix = []
    for y in range(h):
        row = []
        for xb in range(w // 4):
            b = data[y * (w // 4) + xb]
            for i in range(4): row.append((b >> (6 - 2 * i)) & 3)
        pix.append(row)
    return pix
