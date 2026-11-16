import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art
from PIL import Image, ImageDraw
PAL = {'G': (0x10, 0xC8, 0x10), 'Y': (0xF0, 0xF0, 0x40), '.': (0x30, 0x30, 0xC0), 'R': (0xD0, 0x20, 0x20)}
def sheet(out, which=None):
    fr = art.anim_frames()
    S = 6
    rowsh = []
    for name, n, r, l in fr:
        if which and name not in which: continue
        rowsh.append((name, r))
    W = 70 + 33 * 9 * S // 1
    img = Image.new('RGB', (80 + 32 * 9 * S, len(rowsh) * 8 * 3 * S // 1 + 10), (0, 0, 0))
    d = ImageDraw.Draw(img)
    for j, (name, frames) in enumerate(rowsh):
        y0 = j * 7 * 3 * S // 2 * 2 // 2 + j * 4
        y0 = j * (7 * 3 * S // 2 + 6)
        d.text((2, y0 + 10), name, fill=(255, 255, 255))
        for k, f in enumerate(frames):
            x0 = 80 + k * (8 * 2 * S // 2 + 4)
            for y, row in enumerate(f):
                for x, c in enumerate(row):
                    d.rectangle([x0 + x * S, y0 + y * 3 * S // 2, x0 + x * S + S - 1, y0 + (y + 1) * 3 * S // 2 - 1], fill=PAL[c])
    img.save(out)
if __name__ == '__main__':
    sheet(sys.argv[1], sys.argv[2:] or None)
