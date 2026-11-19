#!/usr/bin/env python3
"""STARWHIRL - the player's ship, rasterised at 16 headings.
The ship is designed in 'visual' units (1 unit = one mode(1) pixel width;
a mode(1) pixel is 1.5 units tall on a 4:3 screen) and supersampled into a
7 x 5 pixel cell for each heading.  Colours by region: nose/body yellow,
cockpit red, wing tips red, engines green.  Heading 0 = nose pointing up,
headings step clockwise by 22.5 degrees.
"""
import math

W, H = 7, 5
ASPECT = 1.5

# polygons in visual units, nose up (-y), centred on (0, 0)
BODY = [(0, -4.4), (1.3, -1.2), (3.6, 2.4), (1.2, 1.6), (0, 2.2), (-1.2, 1.6), (-3.6, 2.4), (-1.3, -1.2)]
COCKPIT = [(0, -2.2), (0.75, -0.4), (0, 0.6), (-0.75, -0.4)]
TIPL = [(-3.7, 2.6), (-2.2, 0.4), (-1.7, 2.3)]
TIPR = [(3.7, 2.6), (2.2, 0.4), (1.7, 2.3)]
ENGINE = [(-1.0, 1.5), (1.0, 1.5), (0.7, 3.0), (-0.7, 3.0)]


def inside(poly, x, y):
    c = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y):
            xi = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if x < xi:
                c = not c
    return c


def render(heading):
    th = heading * math.pi / 8
    ct, st = math.cos(th), math.sin(th)
    out = []
    for py in range(H):
        row = []
        for px in range(W):
            votes = {}
            S = 4
            for sy in range(S):
                for sx in range(S):
                    vx = (px + (sx + 0.5) / S) - W / 2
                    vy = ((py + (sy + 0.5) / S) - H / 2) * ASPECT
                    # rotate back into the ship's frame
                    x = vx * ct + vy * st
                    y = -vx * st + vy * ct
                    c = None
                    if inside(COCKPIT, x, y):
                        c = 'r'
                    elif inside(TIPL, x, y) or inside(TIPR, x, y):
                        c = 'r'
                    elif inside(ENGINE, x, y) and y > 1.9:
                        c = 'g'
                    elif inside(BODY, x, y):
                        c = 'y'
                    votes[c] = votes.get(c, 0) + 1
            best = max(votes.items(), key=lambda kv: kv[1])
            filled = S * S - votes.get(None, 0)
            if filled >= 6:
                cs = {k: v for k, v in votes.items() if k}
                ch = max(cs.items(), key=lambda kv: kv[1])[0]
                # small details win if they cover a fair part of the cell
                if cs.get('r', 0) >= 5:
                    ch = 'r'
                row.append(ch)
            else:
                row.append('.')
        out.append(''.join(row))
    return out


def all_headings():
    return [render(h) for h in range(16)]


if __name__ == '__main__':
    for h, art in enumerate(all_headings()):
        print(h)
        print('\n'.join(art))
