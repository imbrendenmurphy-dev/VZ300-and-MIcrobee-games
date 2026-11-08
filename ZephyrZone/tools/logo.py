"""ZEPHYR ZONE title logo: chunky 3x-scaled letters, yellow with stripe shading,
red outline and a blue drop shadow (colour 0 transparent). Two 64-px halves."""
import sys
sys.path.insert(0, 'tools')
from font import G
def logo():
    text = 'ZEPHYR ZONE'
    W, H = 128, 19
    g = [[-1] * W for _ in range(H)]
    x0 = 3
    fill = [[False] * W for _ in range(H)]
    for ch in text:
        if ch == ' ':
            x0 += 6; continue
        rows = G[ch]
        for r, bits in enumerate(rows):
            for c, b in enumerate(bits):
                if b == '1':
                    for yy in range(3):
                        for xx in range(3):
                            X, Y = x0 + c * 3 + xx, 1 + r * 3 + yy
                            if 0 <= X < W and 0 <= Y < H: fill[Y][X] = True
        x0 += 11
    # shadow (down-right), outline, fill with stripes (yellow / red shading lower down)
    for y in range(H):
        for x in range(W):
            if fill[y][x]:
                for dx, dy in ((1, 2), (2, 2), (2, 1)):
                    X, Y = x + dx, y + dy
                    if X < W and Y < H and not fill[Y][X]: g[Y][X] = 2
    for y in range(H):
        for x in range(W):
            if fill[y][x]:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        X, Y = x + dx, y + dy
                        if 0 <= X < W and 0 <= Y < H and not fill[Y][X]: g[Y][X] = 3
    for y in range(H):
        for x in range(W):
            if fill[y][x]:
                g[y][x] = 1
    return g
def halves():
    g = logo()
    return [[r[:64] for r in g], [r[64:] for r in g]]
if __name__ == '__main__':
    from draw import preview
    preview([logo()], 'build/logo.png', cols=1, scale=4)
