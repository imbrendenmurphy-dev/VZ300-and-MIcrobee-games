# compare the emulator's viewport with the Python reference for the live game state
import sys; sys.path.insert(0, '.')
import area, maps
from gfx import show
from PIL import Image
def syms():
    return {l.split()[1]: int(l.split()[0], 16) for l in open('/home/claude/dc2/build/DRACULA2.sym')}
DV = [(0, -1), (1, 0), (0, 1), (-1, 0)]
def main(dump, out):
    S = syms(); m = open(dump, 'rb').read()
    ai = m[S['cur_area']]; x, y, d = m[S['px']], m[S['py']], m[S['pdir']]
    A = maps.AREA_MAPS[ai]; ad = area.AREAS[ai]
    cells = m[0x7C00 + ai * 256: 0x7C00 + ai * 256 + 256]
    _, events, exits = maps.compile_area(ai)
    flags = m[0x7E40:0x7E40 + 64]
    p1, p2, ref = area.build_area(ad)
    fx, fy = DV[d]; rx, ry = -fy, fx
    view = {}; objs = {}
    for dd in range(4):
        for l in range(-2, 3):
            cx = x + fx * dd + rx * l; cy = y + fy * dd + ry * l
            c = cells[cy * 16 + cx] if 0 <= cx < 16 and 0 <= cy < 16 else 1
            t = c & 7; p = c >> 3
            if t == 1: view[(dd, l)] = ('A', p)
            elif t == 2: view[(dd, l)] = ('B', p)
            elif t == 3: view[(dd, l)] = ('AB'[A['door_kind'] - 1], A['door_decor'])
            elif t == 4: view[(dd, l)] = ('B' if p & 1 else 'A', 0)
            elif t == 5: ex = exits[p]; view[(dd, l)] = ('AB'[ex['kind'] - 1], ex['decor'])
            elif t == 0 and p:
                ev = events[p - 1]
                print('event at', dd, l, ev)
    exp = area.compose(ref, view, ad.bgdir[d], objs)
    got = [[(m[0xF800 + yy * 32 + xx // 4] >> (6 - 2 * (xx % 4))) & 3 for xx in range(80)] for yy in range(52)]
    print('area', ai, 'pos', x, y, d, 'diff', sum(1 for yy in range(52) for xx in range(80) if exp[yy][xx] != got[yy][xx]))
    a = show(exp, 0, 4); b = show(got, 0, 4)
    W = Image.new('RGB', (a.width * 2 + 8, a.height)); W.paste(a, (0, 0)); W.paste(b, (a.width + 8, 0)); W.save(out)
main(sys.argv[1], sys.argv[2])
