"""contact sheet of every room: static light, plus a torch at the start"""
import sys
FULL = len(sys.argv) > 1
import numpy as np
from PIL import Image
import art, world as W, gen, levels as L

def render_room(b, torch=None):
    lv, tint = gen.static_light(b)
    tm = b.tm
    dyn = {}
    if torch:
        tr = W.LightTree(W.torch_intensity(torch[2]), 24, 12)
        dyn = gen.cast(tr, tm, torch[0], torch[1], {}, b.groups)
    img = np.zeros((L.H * 8, L.W * 8, 3), dtype=np.uint8)
    for y in range(L.H):
        for x in range(L.W):
            t = tm[y][x]
            d = dyn.get((x, y), 0)
            s = lv[y, x]
            if d >= s:
                l, tn = d, 'warm'
            else:
                l, tn = s, gen.TINTS[tint[y, x]]
            if FULL and l < 5:
                l, tn = 5, 'warm'
            var, fg, bg = gen.RAMPS[t.ramp][tn][l]
            g = t.frames[0] if t.frames else t.glyph
            a = art.g_to_array(art.variant(g, var))
            img[y*8:y*8+8, x*8:x*8+8] = np.where(a[..., None] == 1, W.PALETTE[fg], W.PALETTE[bg])
    return img

def main():
    specs = L.all_rooms()
    for s in specs:
        for (kind, x0, y0, p) in s.objects:
            pass
    out = []
    for ri in range(len(L.REGIONS)):
        rs = [s for s in specs if s.region == ri]
        st = gen.style_art(L.REGIONS[ri]['style'])
        ts = gen.TileSet()
        for s in rs:
            b = gen.build_room(s, st, ts)
            ent = getattr(s, 'start', None) or (40, 11)
            img = render_room(b, None)
            im = Image.fromarray(img).resize((640, 22*8*2), Image.NEAREST)
            im.save('/tmp/claude-0/-home-claude/2162cf8c-b593-5d1e-822e-aa3709259a18/scratchpad/room%02d.png' % s.rid)
main()
