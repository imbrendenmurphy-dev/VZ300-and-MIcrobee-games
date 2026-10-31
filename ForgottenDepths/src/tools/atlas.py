"""Fully-lit atlas of every screen of a chapter (art/layout check)."""
import sys, importlib
from PIL import Image
from levelc import compile_level, SW, SH
from tiles import DEFS
import vzpreview
from screens import ENT, ENTNAMES
def atlas(modname, out):
    mod = importlib.import_module(modname)
    lv = compile_level(mod)
    ims = []
    for (sx, sy), s in sorted(mod.SCREENS.items(), key=lambda k: (k[0][1], k[0][0])):
        v = bytearray(512)
        for y in range(SH):
            for x in range(SW):
                t = lv['tiles'][sy * SH + y][sx * SW + x]
                v[y * 32 + x] = DEFS[t]['g'][4]
        for k, x, y in lv['ents']:
            if sx * SW <= x < sx * SW + SW and sy * SH <= y < sy * SH + SH:
                if k == 'player':
                    g = 0
                elif k == 'boss':
                    g = mod.BOSS['glyphs'][0][0]
                else:
                    g = ENT[ENTNAMES.index(k)][3]
                v[(y - sy * SH) * 32 + x - sx * SW] = g
        v[15 * 32:] = bytes([32]) * 32
        t = s['title'].center(32)
        from glyph import text
        v[15 * 32:] = text(t)
        ims.append(vzpreview.mode0(bytes(v), css=s['css'], scale=1))
    w, h = ims[0].size
    cols = 3
    rows = (len(ims) + cols - 1) // cols
    m = Image.new('RGB', (cols * (w + 4), rows * (h + 4)), (60, 60, 60))
    for i, im in enumerate(ims):
        m.paste(im, ((i % cols) * (w + 4), (i // cols) * (h + 4)))
    m = m.resize((m.width * 2, m.height * 2), Image.NEAREST)
    m.save(out)
if __name__ == '__main__':
    atlas(sys.argv[1], sys.argv[2])
