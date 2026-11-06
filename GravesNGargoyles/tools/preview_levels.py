#!/usr/bin/env python3
"""render the generated levels with objects and reachable standing spots marked"""
import sys
from PIL import Image, ImageDraw
import stages
PALS = {0: {'g': (40, 200, 40), 'y': (230, 230, 80), 'b': (30, 30, 150), 'r': (200, 40, 40)},
        0x10: {'g': (230, 230, 220), 'y': (60, 210, 210), 'b': (170, 40, 170), 'r': (240, 130, 30)}}
COL = {1: ('W', (255, 255, 255)), 2: ('T', (255, 160, 0)), 3: ('F', (0, 255, 255)), 4: ('G', (200, 200, 255)),
       5: ('D', (255, 0, 255)), 6: ('M', (255, 0, 0)), 7: ('S', (0, 255, 0)), 8: ('C', (255, 255, 0)),
       9: ('i', (255, 220, 120)), 10: ('K', (0, 255, 128))}
def render(n, out):
    M, objs = stages.build_level(n)
    L = stages.build_level.last
    th = stages.THEMES[n]; P = PALS[th['css']]
    S = 3
    im = Image.new('RGB', (176 * 8 * S, 56 * S * 2))
    for r in range(7):
        for c in range(176):
            t = th['tiles'][M[r][c]]
            for yy in range(8):
                for xx in range(8):
                    col = P[t[yy][xx]]
                    for a in range(S):
                        for b in range(2 * S):
                            im.putpixel(((c * 8 + xx) * S + a, (r * 8 + yy) * 2 * S + b), col)
    d = ImageDraw.Draw(im)
    for (x, y) in L.stands:
        d.rectangle([(x + 5) * S, (y + 15) * 2 * S, (x + 7) * S, (y + 16) * 2 * S], fill=(255, 255, 255))
    for (c, y, t, p) in objs:
        if t in COL:
            ch, col = COL[t]
            d.text((c * 8 * S + 4, y * 2 * S - 12), ch, fill=col)
    for k in range(0, 176, 10):
        d.text((k * 8 * S, 0), str(k), fill=(255, 255, 255))
    # split into two halves for viewing
    w = im.width // 2
    out_im = Image.new('RGB', (w, im.height * 2 + 4))
    out_im.paste(im.crop((0, 0, w, im.height)), (0, 0))
    out_im.paste(im.crop((w, 0, im.width, im.height)), (0, im.height + 4))
    out_im.save(out)
for n in map(int, sys.argv[1:]):
    render(n, '/tmp/claude-0/lv%d.png' % n)
