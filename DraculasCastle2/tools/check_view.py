import sys, re
sys.path.insert(0, '.')
import area
from gfx import show, lz_decompress
from PIL import Image
def parse_map(asmfile, label):
    txt = open(asmfile).read()
    i = txt.index(label + ':')
    rows = re.findall(r'db ([0-9,]+)', txt[i:])[:16]
    return [[int(v) for v in r.split(',')] for r in rows]
DV = [(0, -1), (1, 0), (0, 1), (-1, 0)]
def view_from(mp, x, y, d, door_kind='A', door_decor=2):
    fx, fy = DV[d]; rx, ry = -fy, fx
    view = {}; objs = {}
    for dd in range(4):
        for l in range(-2, 3):
            cx = x + fx * dd + rx * l; cy = y + fy * dd + ry * l
            c = mp[cy][cx] if 0 <= cx < 16 and 0 <= cy < 16 else 1
            t = c & 7; p = c >> 3
            if t == 1: view[(dd, l)] = ('A', p)
            elif t == 2: view[(dd, l)] = ('B', p)
            elif t == 3: view[(dd, l)] = (door_kind, door_decor)
            elif t == 4: view[(dd, l)] = ('B' if p & 1 else 'A', 0)
    return view, objs
if __name__ == '__main__':
    ai, x, y, d, dump, out = int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6]
    ad = area.AREAS[ai]
    p1, p2, ref = area.build_area(ad)
    mp = parse_map('/home/claude/dc2/src/data.asm', 'test_map')
    v, o = view_from(mp, x, y, d)
    exp = area.compose(ref, v, ad.bgdir[d], o)
    m = open(dump, 'rb').read()
    got = [[(m[0xF200 + yy * 32 + xx // 4] >> (6 - 2 * (xx % 4))) & 3 for xx in range(80)] for yy in range(52)]
    diff = sum(1 for yy in range(52) for xx in range(80) if exp[yy][xx] != got[yy][xx])
    print('pixel differences:', diff)
    a = show(exp, 0, 4); b = show(got, 0, 4)
    W = Image.new('RGB', (a.width * 2 + 8, a.height)); W.paste(a, (0, 0)); W.paste(b, (a.width + 8, 0)); W.save(out)
