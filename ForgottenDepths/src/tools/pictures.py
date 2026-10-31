"""Mode 1 (128x64, 4 colour) illustrations: boss introductions and the ending.
Drawn on a 256x192 canvas (square screen pixels) then sampled to 128x64
(each VZ mode(1) pixel is 2 wide x 3 tall on screen)."""
import math
from PIL import Image, ImageDraw

F35 = {
    'A': '###,#.#,###,#.#,#.#', 'B': '##.,#.#,##.,#.#,##.', 'C': '###,#..,#..,#..,###', 'D': '##.,#.#,#.#,#.#,##.',
    'E': '###,#..,##.,#..,###', 'F': '###,#..,##.,#..,#..', 'G': '###,#..,#.#,#.#,###', 'H': '#.#,#.#,###,#.#,#.#',
    'I': '###,.#.,.#.,.#.,###', 'J': '..#,..#,..#,#.#,###', 'K': '#.#,#.#,##.,#.#,#.#', 'L': '#..,#..,#..,#..,###',
    'M': '#.#,###,###,#.#,#.#', 'N': '##.,#.#,#.#,#.#,#.#', 'O': '###,#.#,#.#,#.#,###', 'P': '###,#.#,###,#..,#..',
    'Q': '###,#.#,#.#,###,..#', 'R': '##.,#.#,##.,#.#,#.#', 'S': '###,#..,###,..#,###', 'T': '###,.#.,.#.,.#.,.#.',
    'U': '#.#,#.#,#.#,#.#,###', 'V': '#.#,#.#,#.#,#.#,.#.', 'W': '#.#,#.#,###,###,#.#', 'X': '#.#,#.#,.#.,#.#,#.#',
    'Y': '#.#,#.#,###,.#.,.#.', 'Z': '###,..#,.#.,#..,###', ' ': '...,...,...,...,...', '.': '...,...,...,...,.#.',
}


def text35(px, s, y, col, x=None, band=None):
    w = len(s) * 4 - 1
    if x is None:
        x = (128 - w) // 2
    if band is not None:
        for yy in range(y - 2, min(64, y + 7)):
            for xx in range(x - 3, x + w + 3):
                px[xx, yy] = band
    for ch in s:
        g = F35[ch].split(',')
        for yy in range(5):
            for xx in range(3):
                if g[yy][xx] == '#':
                    px[x + xx, y + yy] = col
        x += 4


def sample(img):
    out = Image.new('P', (128, 64))
    a, b = img.load(), out.load()
    for y in range(64):
        for x in range(128):
            # majority of the 2x3 block
            c = {}
            for dy in range(3):
                for dx in range(2):
                    v = a[2 * x + dx, 3 * y + dy]
                    c[v] = c.get(v, 0) + 1
            b[x, y] = max(c, key=c.get)
    return out


def pack(img):
    px = img.load()
    out = bytearray()
    for y in range(64):
        for xb in range(32):
            v = 0
            for k in range(4):
                v = (v << 2) | (px[xb * 4 + k, y] & 3)
            out.append(v)
    return bytes(out)


def canvas(bg):
    im = Image.new('P', (256, 192), bg)
    return im, ImageDraw.Draw(im)


GRN, YEL, BLU, RED = 0, 1, 2, 3          # CSS0
BUF, CYN, MAG, ORA = 0, 1, 2, 3          # CSS1


def warden():
    im, d = canvas(BLU)
    for i in range(0, 256, 16):                          # crypt arches behind
        d.arc([i - 20, 20, i + 36, 120], 180, 360, fill=GRN, width=2)
    d.polygon([(40, 192), (70, 120), (186, 120), (216, 192)], fill=YEL)     # shoulders
    d.polygon([(52, 192), (78, 132), (178, 132), (204, 192)], fill=RED)
    d.rectangle([118, 132, 138, 192], fill=YEL)
    d.polygon([(70, 40), (50, 0), (90, 30)], fill=YEL)                       # horns
    d.polygon([(186, 40), (206, 0), (166, 30)], fill=YEL)
    d.ellipse([78, 18, 178, 118], fill=YEL)                                  # skull
    d.rectangle([96, 96, 160, 128], fill=YEL)
    d.ellipse([94, 52, 122, 82], fill=BLU)                                   # sockets
    d.ellipse([134, 52, 162, 82], fill=BLU)
    d.ellipse([102, 60, 114, 74], fill=RED)
    d.ellipse([142, 60, 154, 74], fill=RED)
    d.polygon([(128, 82), (120, 98), (136, 98)], fill=BLU)
    for x in range(100, 160, 10):                                            # teeth
        d.rectangle([x, 106, x + 5, 120], fill=BLU)
    for x in range(0, 256, 12):                                              # ghost fog
        d.ellipse([x, 168 + (x * 7) % 12, x + 26, 196], fill=GRN)
    s = sample(im)
    text35(s.load(), 'THE BONE WARDEN', 57, YEL, band=BLU)
    return s, 0


def king():
    im, d = canvas(BLU)
    for y in range(140, 192, 10):                                            # water
        for x in range(0, 256, 24):
            d.arc([x + (y % 20), y, x + 22 + (y % 20), y + 10], 200, 340, fill=GRN, width=2)
    d.polygon([(76, 54), (86, 10), (104, 44), (128, 4), (152, 44), (170, 10), (180, 54)], fill=YEL)  # crown
    d.rectangle([76, 46, 180, 62], fill=YEL)
    d.ellipse([86, 50, 170, 140], fill=GRN)                                  # face
    d.ellipse([100, 76, 120, 92], fill=RED)
    d.ellipse([136, 76, 156, 92], fill=RED)
    d.line([(118, 112), (128, 118), (138, 112)], fill=BLU, width=3)
    for i, x in enumerate(range(90, 170, 12)):                               # tentacle beard
        pts = [(x + 6 * math.sin((y + i * 9) / 9.0), y) for y in range(120, 190, 4)]
        d.line(pts, fill=YEL if i % 2 else GRN, width=6)
    for k in range(24, 64, 8):
        d.ellipse([128 - 8, k, 128 + 8, k + 6], fill=RED) if k == 40 else None
    s = sample(im)
    text35(s.load(), 'THE DROWNED KING', 57, YEL, band=BLU)
    return s, 0


def wyrm():
    im, d = canvas(BLU)
    for x in range(0, 256, 8):                                               # lava floor
        d.rectangle([x, 172 + (x * 13) % 10, x + 6, 192], fill=RED)
    d.polygon([(250, 30), (150, 40), (110, 70), (60, 80), (40, 100), (70, 112), (120, 104), (150, 130),
               (250, 150)], fill=RED)                                        # head + neck
    d.polygon([(150, 40), (200, 2), (186, 46)], fill=YEL)                    # horns
    d.polygon([(176, 36), (238, 6), (214, 46)], fill=YEL)
    d.ellipse([140, 54, 164, 70], fill=YEL)                                  # eye
    d.ellipse([150, 57, 158, 67], fill=BLU)
    d.polygon([(40, 100), (70, 112), (120, 104), (100, 124), (56, 126)], fill=RED)   # jaw
    d.polygon([(44, 104), (0, 70), (0, 150), (60, 120)], fill=YEL)           # fire breath
    d.polygon([(30, 106), (0, 92), (0, 128)], fill=RED)
    for x in range(64, 120, 10):                                             # teeth
        d.polygon([(x, 100), (x + 4, 108), (x + 8, 100)], fill=YEL)
    for y in range(80, 150, 14):                                             # scales
        for x in range(170, 250, 16):
            d.arc([x, y, x + 14, y + 12], 0, 180, fill=YEL, width=2)
    s = sample(im)
    text35(s.load(), 'THE EMBER WYRM', 57, YEL, band=BLU)
    return s, 0


def dawn():
    im, d = canvas(BUF)
    d.pieslice([78, 70, 178, 170], 180, 360, fill=ORA)                       # sun
    for a in range(190, 360, 15):
        r = math.radians(a)
        d.line([(128 + 60 * math.cos(r), 120 + 60 * math.sin(r)), (128 + 120 * math.cos(r), 120 + 120 * math.sin(r))],
               fill=ORA, width=3)
    d.polygon([(0, 120), (50, 96), (100, 116), (150, 100), (210, 112), (256, 98), (256, 192), (0, 192)], fill=MAG)
    for x, h in ((40, 20), (64, 26), (92, 18), (170, 24), (196, 30)):        # village
        d.rectangle([x, 128 - h, x + 18, 140], fill=MAG)
        d.polygon([(x - 4, 128 - h), (x + 9, 116 - h), (x + 22, 128 - h)], fill=MAG)
        d.rectangle([x + 6, 132 - h, x + 11, 138 - h], fill=ORA)
    d.polygon([(110, 192), (122, 150), (134, 150), (156, 192)], fill=CYN)    # river
    s = sample(im)
    text35(s.load(), 'THE EMBER BURNS AGAIN', 3, ORA, band=BUF)
    return s, 1


PICS = {'warden': warden, 'king': king, 'wyrm': wyrm, 'dawn': dawn}

if __name__ == '__main__':
    import sys
    PAL0 = [(7, 255, 0), (255, 255, 0), (59, 8, 255), (204, 0, 59)]
    PAL1 = [(255, 255, 255), (7, 227, 153), (255, 28, 255), (255, 129, 0)]
    ims = []
    for n, f in PICS.items():
        s, css = f()
        pal = PAL1 if css else PAL0
        rgb = Image.new('RGB', (128, 64))
        a, b = s.load(), rgb.load()
        for y in range(64):
            for x in range(128):
                b[x, y] = pal[a[x, y]]
        ims.append(rgb.resize((256, 192), Image.NEAREST))
    m = Image.new('RGB', (516, 388), (40, 40, 40))
    for i, im in enumerate(ims):
        m.paste(im, ((i % 2) * 260, (i // 2) * 196))
    m.resize((1032, 776), Image.NEAREST).save(sys.argv[1])
