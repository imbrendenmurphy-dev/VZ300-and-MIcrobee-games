"""Mode(1) title picture, 128 x 64, colour set 0 (G Y B R) -> build/title.bin
Sunset over a road vanishing to the horizon, the REDLINE logo in chrome-red
italic capitals, the player's car on the road."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import art
from PIL import Image
G, Y, B, R = 0, 1, 2, 3
W, H = 128, 64

LOGO = {
 'R': ["#######.", "########", "##....##", "##....##", "########", "#######.", "##..##..", "##...##.", "##....##", "##....##", "##....##"],
 'E': ["########", "########", "##......", "##......", "######..", "######..", "##......", "##......", "##......", "########", "########"],
 'D': ["######..", "#######.", "##...###", "##....##", "##....##", "##....##", "##....##", "##....##", "##...###", "#######.", "######.."],
 'L': ["##......", "##......", "##......", "##......", "##......", "##......", "##......", "##......", "##......", "########", "########"],
 'I': ["..####..", "..####..", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "..####..", "..####.."],
 'N': ["##....##", "###...##", "####..##", "##.#..##", "##.##.##", "##..#.##", "##..####", "##...###", "##....##", "##....##", "##....##"],
}

def picture():
    img = [[B] * W for _ in range(H)]
    hz = 36
    # sky: blue -> dithered gold towards the horizon
    bay = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for y in range(0, hz):
        for x in range(W):
            t = max(0.0, (y - 17) / (hz - 17.0))          # 0 blue .. 1 gold
            img[y][x] = Y if bay[y % 4][x % 4] < t * 16 else B
    # sun with slatted bars
    cx, cy, r = 64, hz, 15
    for y in range(hz - r, hz):
        for x in range(W):
            if (x - cx) ** 2 + ((y - cy) * 1.5) ** 2 < r * r:
                bar = (hz - y) in (2, 3, 6, 7, 10)
                img[y][x] = Y if bar else R
    # distant hills
    for x in range(W):
        h = int(3 + 2 * math.sin(x / 9.0) + 1.5 * math.sin(x / 3.7))
        if 44 < x < 84: h = max(0, h - 3)
        for y in range(hz - h, hz):
            img[y][x] = G if (x + y) % 3 else R
    # ground and road in perspective
    for y in range(hz, H):
        t = (y - hz + 1) / (H - hz)
        half = 2 + t * 58
        rum = max(1, half / 7)
        stripe = int(12 / (t + 0.08)) % 2
        for x in range(W):
            d = abs(x + 0.5 - 64)
            if d < half:
                c = B
                if d < max(0.6, half / 40) and stripe: c = Y
            elif d < half + rum: c = R if stripe else Y
            else: c = G if (x // 2 + y + stripe * 2) % 7 else Y
            img[y][x] = c
    # the car
    car = art.player_frames()[4]
    ox, oy = 48, H - 15
    for y, r in enumerate(car):
        for x, c in enumerate(r):
            if c != '.': img[oy + y][ox + x] = art.CV[c]
    # logo: 8x11 letters stretched to 16 wide, italic, red with yellow rim and blue shadow
    word = "REDLINE"; lx = 4; ly = 3
    mask = [[0] * W for _ in range(H)]
    for i, ch in enumerate(word):
        g = LOGO[ch]
        for y in range(11):
            sh = (10 - y) // 3
            for x in range(8):
                if g[y][x] == '#':
                    for dx in (0, 1):
                        px = lx + i * 17 + x * 2 + dx + sh
                        if px < W: mask[ly + y][px] = 1
    for y in range(H):
        for x in range(W):
            if mask[y][x] and not (y + 1 < H and x + 1 < W and mask[y + 1][x + 1]): pass
    for y in range(H - 1):                       # shadow
        for x in range(W - 1):
            if mask[y][x] and not mask[y + 1][x + 1]: img[y + 1][x + 1] = B
    for y in range(H):
        for x in range(W):
            if mask[y][x]:
                k = y - ly
                if k < 3: c = Y
                elif k < 5: c = Y if (x + y) % 2 else R
                else: c = R
                img[y][x] = c
    # subtitle
    import font as fnt
    txt = "COAST TO COAST"
    tx = (W - len(txt) * 4) // 2; ty = 17
    for i, ch in enumerate(txt):
        g = fnt.F.get(ch, "... ... ... ... ...").split()
        for yy, r in enumerate(g):
            for xx, c in enumerate(r):
                if c == '#':
                    img[ty + yy][tx + i * 4 + xx] = Y
                    if img[ty + yy + 1][tx + i * 4 + xx + 1] != Y: img[ty + yy + 1][tx + i * 4 + xx + 1] = R
    return img

def pack(img):
    out = bytearray()
    for y in range(H):
        for b in range(32):
            v = 0
            for i in range(4): v = (v << 2) | img[y][b * 4 + i]
            out.append(v)
    return bytes(out)

def preview(img, fn):
    pal = [(0x30, 0xd2, 0), (0xc1, 0xe5, 0), (0x4c, 0x3a, 0xb4), (0x9a, 0x32, 0x36)]
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W): im.putpixel((x, y), pal[img[y][x]])
    im.resize((W * 4, H * 3 * 2), Image.NEAREST).save(fn)

if __name__ == '__main__':
    B_ = os.path.join(os.path.dirname(__file__), '..', 'build')
    p = picture()
    open(os.path.join(B_, 'title.bin'), 'wb').write(pack(p))
    preview(p, os.path.join(B_, 'title_preview.png'))
