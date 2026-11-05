# Circus 2 title screen art: 128x64, VZ Mode 1 (CG2), CSS=0 palette
# 0=green 1=yellow 2=blue 3=red.  Produces a list-of-lists of colour indices.
import math

W, H = 128, 64
G, Y, B, R = 0, 1, 2, 3

# big logo letters, 12 wide x 11 tall ('#'=fill)
BIG = {
'C': ["...######...",
      ".##########.",
      "####....####",
      "###......###",
      "###.........",
      "###.........",
      "###.........",
      "###......###",
      "####....####",
      ".##########.",
      "...######..."],
'I': ["#####",
      "#####",
      ".###.",
      ".###.",
      ".###.",
      ".###.",
      ".###.",
      ".###.",
      ".###.",
      "#####",
      "#####"],
'R': ["#########...",
      "##########..",
      "###....####.",
      "###.....###.",
      "###....####.",
      "#########...",
      "#########...",
      "###...####..",
      "###....####.",
      "###.....####",
      "###......###"],
'U': ["###......###",
      "###......###",
      "###......###",
      "###......###",
      "###......###",
      "###......###",
      "###......###",
      "###......###",
      "####....####",
      ".##########.",
      "...######..."],
'S': ["..########..",
      ".##########.",
      "###.....###.",
      "###.........",
      ".#######....",
      "..########..",
      "........###.",
      "#........###",
      "###.....####",
      ".##########.",
      "..#######..."],
}
TWO = ["..#########...",
       ".###########..",
       "####.....####.",
       "###.......###.",
       "..........###.",
       "........####..",
       "......####....",
       "....####......",
       "..####........",
       ".###..........",
       "###...........",
       "##############",
       "##############"]

def make():
    img = [[B] * W for _ in range(H)]
    def px(x, y, c):
        if 0 <= x < W and 0 <= y < H: img[y][x] = c
    def get(x, y):
        return img[y][x] if 0 <= x < W and 0 <= y < H else None
    # --- night sky stars (deterministic)
    import random
    rnd = random.Random(7)
    for _ in range(40):
        x, y = rnd.randrange(W), rnd.randrange(0, 40)
        px(x, y, Y)
    # --- big top tent
    apex = (64, 17)
    roof_y = 33
    L, Rr = 10, 118
    # roof: stripes fanning from apex
    for y in range(apex[1], roof_y + 1):
        t = (y - apex[1]) / (roof_y - apex[1])
        xl = apex[0] - (apex[0] - L) * t ** 0.85
        xr = apex[0] + (Rr - apex[0]) * t ** 0.85
        for x in range(int(xl), int(xr) + 1):
            # angle based stripe
            ang = math.atan2(x - apex[0], (y - apex[1]) + 0.01)
            s = int((ang + 3.2) * 2.9) & 1
            px(x, y, R if s else Y)
    # scalloped valance below roof
    for x in range(L, Rr + 1):
        k = (x - L) % 9
        depth = int(3.4 * math.sin(math.pi * (k + 0.5) / 9) + 0.5)
        col = R if ((x - L) // 9) % 2 == 0 else Y
        px(x, roof_y, col)
        for d in range(1, depth + 1):
            px(x, roof_y + d, col)
        px(x, roof_y + depth + 1, B)
    # tent walls with vertical stripes
    wall_top = roof_y + 1
    for y in range(wall_top, 56):
        for x in range(L + 2, Rr - 1):
            if y > roof_y + 4 or (get(x, y) == B and get(x, y - 1) == B):
                px(x, y, R if ((x - L - 2) // 4) % 2 == 0 else Y)
    # entrance: dark (blue) arch with curtains
    ex0, ex1 = 54, 74
    for y in range(40, 56):
        for x in range(ex0, ex1 + 1):
            # arch
            cx = (ex0 + ex1) / 2
            r = (ex1 - ex0) / 2
            if y < 46:
                if (x - cx) ** 2 / r ** 2 + ((y - 46) / 6.0) ** 2 > 1: continue
            px(x, y, G)
    # curtains drawn open (red folds) at entrance sides
    for y in range(41, 56):
        w = max(0, 4 - (y - 41) // 4)
        for x in range(ex0, ex0 + w): px(x, y, R)
        for x in range(ex1 - w + 1, ex1 + 1): px(x, y, R)
    # flag pole + flag on apex
    for y in range(12, apex[1] + 1): px(64, y, Y)
    for y in range(12, 15):
        for x in range(65, 65 + 6 - (y - 12) * 2): px(x, y, R)
    # ground band (green) with floor line
    for y in range(56, 64):
        for x in range(W): px(x, y, G)
    for x in range(W): px(x, 56, Y if x % 4 < 2 else R)
    # --- right side: juggling clown silhouette area left empty for runtime sprite
    # --- logo
    letters = "CIRCUS"
    xs = []
    x = 15
    for ch in letters:
        xs.append(x)
        x += len(BIG[ch][0]) + 2
    def blit(shape, x0, y0, c):
        for dy, row in enumerate(shape):
            for dx, ch in enumerate(row):
                if ch == '#': px(x0 + dx, y0 + dy, c)
    # clear sky band behind logo a bit (keep stars off letters handled by drawing order)
    for ch, x0 in zip(letters, xs):
        y0 = 1
        # shadow / outline in red
        for ox, oy in [(1, 1), (2, 1), (1, 2), (2, 2)]:
            blit(BIG[ch], x0 + ox, y0 + oy, R)
        for ox, oy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            blit(BIG[ch], x0 + ox, y0 + oy, R)
        blit(BIG[ch], x0, y0, Y)
    # the "2": red with yellow outline, tilted feel by vertical offset
    x2 = x + 3
    for ox, oy in [(-1, 0), (1, 0), (0, -1), (0, 1), (1, 1), (-1, -1), (1, -1), (-1, 1)]:
        blit(TWO, x2 + ox, 0 + oy, Y)
    blit(TWO, x2, 0, R)
    # inner highlight on letters: a green "shine" stripe on first rows
    return img, xs, x2

if __name__ == '__main__':
    from PIL import Image
    img, xs, x2 = make()
    pal = [(0x30, 0xD2, 0), (0xF5, 0xF5, 0x80), (0x4C, 0x3A, 0xB4), (0x9A, 0x32, 0x36)]
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W):
            im.putpixel((x, y), pal[img[y][x]])
    im.resize((512, 384), Image.NEAREST).save('/home/claude/circus2/build/title_preview.png')
    print(xs, x2)
