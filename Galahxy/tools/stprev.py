"""stprev.py N out.png : preview a stage's sprites and scenery in its palette"""
import sys, os, importlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'stages'))
import scenery
from vzpal import CSS0, CSS1
from PIL import Image
mod = importlib.import_module('st' + sys.argv[1]); P = CSS1 if mod.PAL else CSS0
im = Image.new('RGB', (320, 110), P[2]); x = 2; y = 2; rowh = 0
for n in mod.ORDER:
    for f in mod.SPR[n][0]:
        w = len(f[0]); h = len(f)
        if x + w > 318: x = 2; y += rowh + 2; rowh = 0
        for yy, r in enumerate(f):
            for xx, c in enumerate(r):
                if c >= 0: im.putpixel((x + xx, y + yy), P[c])
        x += w + 3; rowh = max(rowh, h)
im = im.crop((0, 0, 320, y + rowh + 2)).resize((1280, (y + rowh + 2) * 6), Image.NEAREST)
g = mod.ground(); s = mod.sky()
tiles, maps, stiles, smap, _, _ = scenery.build(g, s)
print('ground tiles', len(tiles), {k: len(v) for k, v in maps.items()}, 'sky tiles', len(stiles), 'bytes', len(tiles) * 18 + len(stiles) * 12 + sum(len(v) for v in maps.values()) + 128)
scenery.preview(sys.argv[2] + '.scen.png', g, s, mod.PAL)
sc = Image.open(sys.argv[2] + '.scen.png')
out = Image.new('RGB', (1280, im.height + sc.height + 6)); out.paste(im, (0, 0)); out.paste(sc, (0, im.height + 6)); out.save(sys.argv[2])
