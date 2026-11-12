#!/usr/bin/env python3
# compose stage screens exactly as the engine will, for checking the art
import sys
sys.path.insert(0, 'tools')
from art import *
from PIL import Image

def compose(st, scroll, foe=None, hero=None):
    scr = [[B]*128 for _ in range(64)]
    fo = (scroll >> 2)*4; so = scroll*4
    for y in range(32):
        for x in range(128): scr[y][x] = st.farrows[y][fo+x]
    for y in range(24):
        for x in range(128):
            v = st.midrows[y][so+x]
            if y >= 12 or v != B: scr[20+y][x] = v
    fl = st.floor[scroll & 3]
    for y in range(14): scr[44+y] = fl[y][:]
    for spr, sx in ((foe, 70), (hero, 30)):
        if spr:
            for r in range(24):
                for c in range(32):
                    if spr[r][c]: scr[32+r][sx+c] = spr[r][c]
    for y in range(58, 64): scr[y] = [B]*128
    for i in range(12):
        for y in range(59, 63):
            for x in range(4+i*4, 7+i*4): scr[y][x] = Y
            for x in range(80+i*4, 83+i*4): scr[y][x] = R
    return scr

if __name__ == '__main__':
    import art
    hero = frames(HERO)
    sts = [stage1(), stage2(), stage3(), stage4(), stage5(), stage6()]
    foes = ['keeper', 'guard', 'monk', 'scout', 'oni', 'kuro']
    tiles = []
    for i, st in enumerate(sts):
        f = mirror(frames(STYLES[foes[i]])[pidx('FIGHT1')])
        for s in (0, 40, 80):
            tiles.append(compose(st, s, f, hero[pidx('FIGHT1')]))
    M = Image.new('RGB', (3*520, 6*392), (40, 40, 40))
    for k, t in enumerate(tiles):
        im = Image.new('RGB', (128, 64))
        for y in range(64):
            for x in range(128): im.putpixel((x, y), PAL[t[y][x]])
        M.paste(im.resize((512, 384), Image.NEAREST), ((k % 3)*520, (k//3)*392))
    M.save(sys.argv[1] if len(sys.argv) > 1 else 'gen/stages.png')
