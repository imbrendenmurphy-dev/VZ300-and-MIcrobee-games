"""Pictures of whole crypts (docs/gallery/NN.png and a contact sheet), drawn
from the cave text files with the game's own tile pictures and colours."""
import os
import sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np
from PIL import Image
import art as A
import tiles as TL
import caves as C

PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
       (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
S = A.slots()
TALL = {n: A.tall(S[n].frames)[0] for n in TL.ARTS}
TALL['INBOX'] = A.tall(S['PLAYER'].frames)[0]


def render(c, mono=False):
    w, h = c['w'], c['h']
    img = np.zeros((h * 20, w * 16, 3), np.uint8)
    cols = {}
    for k, col in c['theme'].items():
        n = TL.THEME[k]
        for t in [n] + TL.THEME_ALSO.get(n, []):
            cols[t] = col
    for y in range(h):
        for x in range(w):
            n, ch, art, fl = TL.TILES[C.CH[c['rows'][y][x]]]
            if art is None:
                continue
            f = TALL[art]
            cc = TL.COLOURS.get(n) or S[art].cols
            for q in range(4):
                col = cols.get(n, cc[q])
                ink = col & 15
                rgb = np.array(PAL[ink], np.uint8)
                if mono:
                    v = int(0.3 * rgb[0] + 0.59 * rgb[1] + 0.11 * rgb[2])
                    rgb = np.array((v, v * 0.7, 0), np.uint8)
                blk = f[(q // 2) * 10:(q // 2) * 10 + 10, (q % 2) * 8:(q % 2) * 8 + 8]
                img[y * 20 + (q // 2) * 10:y * 20 + (q // 2) * 10 + 10, x * 16 + (q % 2) * 8:x * 16 + (q % 2) * 8 + 8][blk] = rgb
    return Image.fromarray(img)


def main(out=None, which=None, scale=1):
    out = out or os.path.join(HERE, '..', 'docs', 'gallery')
    os.makedirs(out, exist_ok=True)
    allc = C.load_all()
    ims = []
    for i, (p, c) in enumerate(allc):
        if which and i + 1 not in which:
            continue
        im = render(c)
        im = im.resize((im.size[0] * scale, int(im.size[1] * 0.92 * scale)), Image.NEAREST)
        im.save(os.path.join(out, '%02d.png' % (i + 1)))
        ims.append(im)
    return ims


def sheet(path, cols=4, tw=300):
    from PIL import ImageDraw
    allc = C.load_all()
    thumbs = []
    for p, c in allc:
        im = render(c)
        th = im.resize((tw, int(im.size[1] * 0.92 * tw / im.size[0])), Image.LANCZOS)
        thumbs.append((c, th))
    th_h = max(t.size[1] for c, t in thumbs) + 18
    rows = (len(thumbs) + cols - 1) // cols
    out = Image.new('RGB', (cols * (tw + 8) + 8, rows * (th_h + 8) + 8), (16, 16, 16))
    d = ImageDraw.Draw(out)
    for i, (c, t) in enumerate(thumbs):
        x = 8 + (i % cols) * (tw + 8)
        y = 8 + (i // cols) * (th_h + 8)
        d.text((x, y), '%d  %s%s' % (i + 1, c['name'], '  (bonus)' if c['bonus'] else ''), fill=(230, 200, 120))
        out.paste(t, (x, y + 16))
    out.save(path)


if __name__ == '__main__':
    if sys.argv[1:] == ['sheet']:
        sheet(os.path.join(HERE, '..', 'docs', 'crypts.png'))
    else:
        main(which=[int(a) for a in sys.argv[1:]] or None)
