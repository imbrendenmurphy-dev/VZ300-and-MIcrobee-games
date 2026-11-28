"""Contact sheet of sprites as the Microbee would show them (cells, one ink
on black), for judging the art without running the game.

    py tools/sheet.py [out.png] [names...]     default: every creature
Each sprite is shown at depth 1 (idle, attack) and depths 2 and 3.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from PIL import Image, ImageDraw
import views as V
import sprites as S

PAL = [(0, 0, 0), (170, 0, 0), (0, 170, 0), (170, 85, 0), (0, 0, 170), (170, 0, 170), (0, 170, 170), (170, 170, 170),
       (85, 85, 85), (255, 85, 85), (85, 255, 85), (255, 255, 85), (85, 85, 255), (255, 85, 255), (85, 255, 255),
       (255, 255, 255)]


def cells_img(cells):
    im = np.zeros((V.PH, V.PW, 3), np.uint8)
    for c, r, pat, col in cells:
        ink = PAL[col & 15]
        for i in range(10):
            for j in range(8):
                if pat[i] >> (7 - j) & 1:
                    im[r * 10 + i, c * 8 + j] = ink
    return im


def crop(im):
    return im[:, 24:168]


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('build/sheet.png')
    names = sys.argv[2:] or list(S.CREATURES)
    rows = []
    for n in names:
        f, mats = S.CREATURES[n]
        tiles = [S.render(f, 'billboard', 1, mats),
                 S.render(lambda c: f(c, 'attack'), 'billboard', 1, mats),
                 S.render(f, 'billboard', 2, mats),
                 S.render(f, 'billboard', 3, mats)]
        row = np.concatenate([crop(cells_img(t)) for t in tiles], 1)
        rows.append(row)
    im = np.concatenate(rows, 0)
    img = Image.fromarray(im).resize((im.shape[1] * 2, im.shape[0] * 2), Image.NEAREST)
    d = ImageDraw.Draw(img)
    for i, n in enumerate(names):
        d.text((4, i * V.PH * 2 + 4), n, fill=(255, 255, 255))
    img.save(out)
    print('wrote', out)


if __name__ == '__main__':
    main()
