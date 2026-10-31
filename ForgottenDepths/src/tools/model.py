"""Python reference model of the lighting + rendering (mirrors the Z80 engine) for art previews."""
import math
import sys
import rays as R
from tiles import DEFS, LIGHTS, TILES, MEM, CDIM, DIM, COOL, LIT
from levelc import compile_level, SW, SH
import vzpreview
import importlib

DIRS = {'right': 0.0, 'down': math.pi / 2, 'left': math.pi, 'up': -math.pi / 2}


def light_tables():
    t = {}
    for kind, (name, near, far) in LIGHTS.items():
        r = int(name[4:])
        rn = r * 0.62
        t[kind] = R.omni(rn, r, near, far)
    return t


def cast(tiles, light, ox, oy, rays):
    for ray in rays:
        stop = False
        for lv, cells in ray:
            for dx, dy in cells:
                x, y = ox + dx, oy + dy
                if not (0 <= x < 128 and 0 <= y < 60):
                    stop = True
                    break
                if light[y][x] < lv:
                    light[y][x] = lv
                if DEFS[tiles[y][x]]['opaque']:
                    stop = True
                    break
            if stop:
                break


def render(lv, sx, sy, px, py, facing, seed=0, ents=True, extra=None):
    tiles = lv['tiles']
    light = [[0] * 128 for _ in range(60)]
    lt = light_tables()
    wx, wy = sx * SW, sy * SH
    for y in range(wy, wy + SH):
        for x in range(wx, wx + SW):
            d = DEFS[tiles[y][x]]
            if d['light']:
                light[y][x] = LIGHTS[d['light']][1]
                cast(tiles, light, x, y, lt[d['light']])
    cast(tiles, light, px, py, R.cone(DIRS[facing], seed, LIT, DIM, lit_len=8.0, dim_len=12.0, amb_near=2.2, amb_far=3.6))
    light[py][px] = LIT
    v = bytearray(512)
    for y in range(SH):
        for x in range(SW):
            t = tiles[wy + y][wx + x]
            l = light[wy + y][wx + x]
            v[y * 32 + x] = DEFS[t]['g'][l] if l else 0x80
    if ents:
        for k, x, y in lv['ents']:
            if wx <= x < wx + SW and wy <= y < wy + SH and light[y][x] and k != 'player':
                v[(y - wy) * 32 + x - wx] = ENTG.get(k, 0x80)
    v[(py - wy) * 32 + px - wx] = 0  # '@'
    return v


from glyph import T, V, S, Y, W, M, C, G, R as RED, B as BLUE, O
ENTG = {'skeleton': V('&'), 'bat': S(M, 'x..x'), 'slime': S(G, '..xx'), 'ghost': S(C, 'x.x.'),
        'staff': T('/'), 'key': T('?'), 'gem': S(C, '.xx.'), 'potion': S(RED, '..xx'), 'heart': S(RED, 'x.xx')}

if __name__ == '__main__':
    import level1
    lv = compile_level(level1)
    out = sys.argv[1]
    shots = [((0, 0), 4, 2, 'right'), ((0, 0), 20, 10, 'right'), ((1, 0), 33, 10, 'right'),
             ((1, 0), 47, 9, 'up'), ((1, 1), 50, 18, 'down'), ((0, 1), 25, 23, 'left')]
    for i, (s, px, py, f) in enumerate(shots):
        v = render(lv, s[0], s[1], px, py, f, seed=i)
        css = lv['screens'][s]['css']
        vzpreview.mode0(bytes(v) + b'\x20' * 32, css=css).save(f'{out}/m{i}.png')
