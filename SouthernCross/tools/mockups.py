"""SOUTHERN CROSS - true-palette mockups at VZ300 mode(1) resolution.
Draws 128x64 indexed images (2 bits per pixel), then scales to a 4:3 TV
picture (each pixel 6 wide x 9 tall = 3 scanlines of 3) with a border.
"""
from PIL import Image, ImageDraw
import math, random, os

OUT = os.path.join(os.path.dirname(__file__), '..', 'mockups')
os.makedirs(OUT, exist_ok=True)

# approximate MC6847 mode-1 colours
CSS0 = [(48, 210, 0), (193, 229, 0), (76, 58, 180), (154, 50, 54)]      # green yellow blue red
CSS1 = [(191, 200, 173), (65, 175, 113), (154, 50, 137), (191, 115, 48)]  # buff cyan magenta orange
G, Y, B, R = 0, 1, 2, 3          # set 0 indices
BU, CY, MA, OR = 0, 1, 2, 3      # set 1 indices

W, H = 128, 64

def blank(c):
    return [[c] * W for _ in range(H)]

def put(img, x, y, c):
    if 0 <= x < W and 0 <= y < H and c is not None:
        img[y][x] = c

def sprite(img, x, y, rows, cmap):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in cmap:
                put(img, x + i, y + j, cmap[ch])

# 3x5 font
F35 = {
 'A':["010","101","111","101","101"],'B':["110","101","110","101","110"],
 'C':["011","100","100","100","011"],'D':["110","101","101","101","110"],
 'E':["111","100","110","100","111"],'F':["111","100","110","100","100"],
 'G':["011","100","101","101","011"],'H':["101","101","111","101","101"],
 'I':["111","010","010","010","111"],'K':["101","101","110","101","101"],
 'L':["100","100","100","100","111"],'M':["101","111","111","101","101"],
 'N':["110","101","101","101","101"],'O':["010","101","101","101","010"],
 'P':["110","101","110","100","100"],'R':["110","101","110","101","101"],
 'S':["011","100","010","001","110"],'T':["111","010","010","010","010"],
 'U':["101","101","101","101","111"],'V':["101","101","101","101","010"],
 'W':["101","101","111","111","101"],'X':["101","101","010","101","101"],
 'Y':["101","101","010","010","010"],'0':["111","101","101","101","111"],
 '1':["010","110","010","010","111"],'2':["110","001","010","100","111"],
 '3':["110","001","010","001","110"],'4':["101","101","111","001","001"],
 '5':["111","100","110","001","110"],'6':["011","100","111","101","111"],
 '7':["111","001","010","010","010"],'8':["111","101","111","101","111"],
 '9':["111","101","111","001","110"],' ':["000"]*5,'-':["000","000","111","000","000"],
}
# 3x4 HUD digits
F34 = {
 '0':["111","101","101","111"],'1':["010","110","010","111"],'2':["110","001","110","111"],
 '3':["111","011","001","111"],'4':["101","111","001","001"],'5':["111","110","001","110"],
 '6':["100","111","101","111"],'7':["111","001","010","010"],'8':["111","111","101","111"],
 '9':["111","101","111","001"],
}

def text(img, x, y, s, c, font=F35, sx=1, sy=1):
    for ch in s:
        g = font.get(ch, font.get(' ', ["000"] * 5))
        for j, row in enumerate(g):
            for i, bit in enumerate(row):
                if bit == '1':
                    for a in range(sx):
                        for b in range(sy):
                            put(img, x + i * sx + a, y + j * sy + b, c)
        x += (len(g[0]) + 1) * sx
    return x

def text_w(s, font=F35, sx=1):
    return sum((len(font.get(ch, font[' '])[0]) + 1) * sx for ch in s) - sx

# 5x5 bold title font
T55 = {
 'S':["01111","11000","01110","00011","11110"],'O':["01110","11011","11011","11011","01110"],
 'U':["11011","11011","11011","11011","01110"],'T':["11111","00100","00100","00100","00100"],
 'H':["11011","11011","11111","11011","11011"],'E':["11111","11000","11110","11000","11111"],
 'R':["11110","11011","11110","11011","11011"],'N':["11011","11111","11111","11011","11011"],
 'C':["01111","11000","11000","11000","01111"],
}

def outlined_text(img, x, y, s, fill, edge, sx=2, sy=2):
    # draw edge by offsetting, then fill
    for dx, dy in ((-1,0),(1,0),(0,-1),(0,1),(-1,-1),(1,1),(1,-1),(-1,1)):
        text(img, x + dx, y + dy, s, edge, T55, sx, sy)
    text(img, x, y, s, fill, T55, sx, sy)

def noise(x, y, seed=0):
    # smooth value noise
    def h(ix, iy):
        n = ix * 374761393 + iy * 668265263 + seed * 2147483647
        n = (n ^ (n >> 13)) * 1274126177
        return ((n ^ (n >> 16)) & 0xffff) / 65535.0
    x0, y0 = math.floor(x), math.floor(y)
    fx, fy = x - x0, y - y0
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a, b = h(x0, y0), h(x0 + 1, y0)
    c, d = h(x0, y0 + 1), h(x0 + 1, y0 + 1)
    return (a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy

def fbm(x, y, seed):
    return 0.6 * noise(x, y, seed) + 0.3 * noise(x * 2.1, y * 2.1, seed + 7) + 0.1 * noise(x * 4.3, y * 4.3, seed + 13)

def render(img, pal_rows, name, scale_x=6, scale_y=9, border=40):
    """pal_rows: list of palettes, one per pixel row (lets the HUD use the other colour set)."""
    out = Image.new('RGB', (W * scale_x + border * 2, H * scale_y + border * 2), pal_rows[-1][0])
    px = out.load()
    for y in range(H):
        pal = pal_rows[y]
        for x in range(W):
            col = pal[img[y][x]]
            for sy in range(scale_y):
                dim = 0.80 if sy % 3 == 2 else 1.0       # scanline gap: 3 lines per pixel row
                c = tuple(int(v * dim) for v in col)
                for sx in range(scale_x):
                    px[border + x * scale_x + sx, border + y * scale_y + sy] = c
    path = os.path.join(OUT, name)
    out.save(path)
    # also a raw 1:1 copy for reference
    raw = Image.new('RGB', (W, H))
    rp = raw.load()
    for y in range(H):
        for x in range(W):
            rp[x, y] = pal_rows[y][img[y][x]]
    raw.save(path.replace('.png', '_raw.png'))
    return path

# ---------------------------------------------------------------- sprites
CRUX = [            # player 9x8: yellow body, red wingtips, blue canopy, white-ish core dot via yellow
 "....y....",
 "...yby...",
 "...yby...",
 "r.yyyyy.r",
 "ryyyyyyyr",
 "y.yyryy.y",
 "...y.y...",
 "...r.r...",
]
STAR = [".y.", "yyy", ".y."]
DRONE = [           # Rust drone 7x6
 "r.....r",
 "rr.y.rr",
 ".rryrr.",
 "..ryr..",
 "..r.r..",
 ".r...r.",
]
GUNBOAT = [         # surfacing gunboat 11x6 (yellow deck, red turret)
 "....rrr....",
 "....ryr....",
 ".yyyyryyyy.",
 "yyggyyyggyy",
 ".yyyyyyyyy.",
 "..bbbbbbb..",
]
SHARD = [".y.", "y.y", ".y."]
EXPL = [
 "..y.r.y..",
 ".r.yyy.r.",
 "y.yrrry.y",
 ".yrr.rry.",
 "r.yr.ry.r",
 ".yrrrrry.",
 "y.y.r.y.y",
 ".r..y..r.",
]

def stage1():
    img = blank(B)
    seed = 3
    for y in range(4, H):
        for x in range(W):
            n = fbm(x / 22.0, y / 11.0, seed) - 0.16 * math.exp(-((x - 64) / 22.0) ** 2)  # channel
            if n > 0.72:                                # sand cay
                c = Y
                if fbm(x / 4.0, y / 2.0, seed + 30) > 0.62 and n > 0.75:
                    c = G                               # vegetation on the cay
            elif n > 0.66:                              # reef top
                c = G
                if (x + y) % 2 == 0 and fbm(x / 3.0, y / 1.5, seed + 9) > 0.6:
                    c = Y
            elif n > 0.61:                              # shallow edge: checker dither
                c = G if (x + y) % 2 == 0 else B
            elif n > 0.57:                              # deeper fringe: sparse dither
                c = G if (x % 2 == 0 and y % 2 == 0) else B
            else:
                c = B
                # little ripple dashes in open water
                if fbm(x / 6.0, y / 2.0, seed + 50) > 0.72 and x % 4 != 3:
                    c = G if y % 3 == 0 else B
            img[y][x] = c
    # wrecked trawler on a sandbar
    sprite(img, 92, 12, [
        "..yyyy.....",
        ".yggggyy...",
        "yggyyggyyy.",
        ".yyyyyyyyyy",
        "...g..g....",
    ], {'y': Y, 'g': G})
    # gunboat surfacing
    sprite(img, 20, 15, GUNBOAT, {'y': Y, 'r': R, 'g': G, 'b': B})
    # drone wave curving in
    for (x, y) in ((52, 9), (62, 13), (72, 17), (82, 21)):
        sprite(img, x, y, DRONE, {'r': R, 'y': Y})
    # explosion where a drone was hit
    sprite(img, 40, 24, EXPL, {'r': R, 'y': Y})
    # star shard drifting
    sprite(img, 44, 34, SHARD, {'y': Y})
    # enemy bullets (2x2 red)
    for (x, y) in ((65, 22), (70, 30), (80, 30), (88, 36)):
        for dx in (0, 1):
            for dy in (0, 1):
                put(img, x + dx, y + dy, R)
    # player and its stars in the cross
    px, py = 60, 50
    sprite(img, px, py, CRUX, {'y': Y, 'r': R, 'b': B})
    cx = px + 4
    for (sx, sy) in ((cx - 1, py - 7), (cx - 9, py + 2), (cx + 7, py + 2), (cx - 1, py + 10)):
        sprite(img, sx, sy, STAR, {'y': Y})
    # player shots: twin pulses from ship and stars
    for x in (cx - 1, cx + 1):
        for y in range(py - 18, py - 14):
            put(img, x, y, Y)
        for y in range(py - 28, py - 25):
            put(img, x, y, Y)
    for x in (cx - 8, cx + 8):
        for y in range(py - 8, py - 5):
            put(img, x, y, Y)
    for y in range(py - 16, py - 13):
        put(img, cx, y, Y)

    # HUD strip rows 0..3 in colour set 1 (experiment): magenta band, buff digits
    for y in range(4):
        for x in range(W):
            img[y][x] = MA
    text(img, 1, 0, "0012450", BU, F34)
    # stars carried (cyan) and weapon letter
    for i in range(4):
        sprite(img, 40 + i * 4, 0, ["010", "111", "010"], {'1': CY})
    sprite(img, 60, 0, ["111", "101", "111", "100"], {'1': OR})        # P(ulse)
    for i in range(3):
        sprite(img, 64 + i * 3, 1, ["11", "11"], {'1': OR})            # weapon level pips
    # lives: little crux icons
    for i in range(3):
        sprite(img, 104 + i * 8, 0, ["..1..", ".111.", "11111", "1.1.1"], {'1': BU})
    pal_rows = [CSS1] * 4 + [CSS0] * (H - 4)
    return render(img, pal_rows, 'stage1_coral_sea.png')

def title():
    img = blank(B)
    random.seed(7)
    # faint starfield
    for _ in range(70):
        x, y = random.randrange(W), random.randrange(0, 20)
        img[y][x] = G if random.random() < 0.7 else Y
    # the Southern Cross: 5 stars (Alpha, Beta, Gamma, Delta, Epsilon), plus pointers
    def bigstar(x, y, s):
        put(img, x, y, Y)
        for d in range(1, s + 1):
            put(img, x + d, y, Y); put(img, x - d, y, Y)
        for d in range(1, max(1, s // 2) + 1):
            put(img, x, y + d, Y); put(img, x, y - d, Y)
    bigstar(64, 2, 3)     # gamma (top)
    bigstar(64, 16, 3)    # alpha (bottom)
    bigstar(56, 9, 2)     # beta (left)
    bigstar(72, 7, 2)     # delta (right)
    bigstar(68, 12, 1)    # epsilon
    bigstar(34, 13, 2)    # pointers
    bigstar(44, 15, 2)
    # Australia silhouette, bottom right, squashed for tall pixels
    pts = [(0.00,0.45),(0.05,0.30),(0.20,0.18),(0.30,0.05),(0.42,0.10),(0.48,0.00),(0.58,0.08),
           (0.62,0.22),(0.70,0.25),(0.72,0.00),(0.78,0.15),(0.85,0.35),(0.95,0.50),(1.00,0.65),
           (0.95,0.80),(0.85,0.95),(0.75,0.90),(0.68,0.78),(0.62,0.82),(0.55,0.70),(0.45,0.70),
           (0.30,0.75),(0.12,0.85),(0.03,0.80),(0.02,0.65)]
    m = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m)
    ox, oy, sw, sh = 74, 35, 50, 21
    d.polygon([(ox + x * sw, oy + y * sh) for x, y in pts], fill=1)
    d.ellipse((ox + 0.80 * sw, oy + 1.04 * sh, ox + 0.88 * sw, oy + 1.14 * sh), fill=1)
    mp = m.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y]:
                inner = all(mp[min(W-1,max(0,x+a)), min(H-1,max(0,y+b))] for a, b in ((1,0),(-1,0),(0,1),(0,-1)))
                img[y][x] = G if inner else Y
    # red centre dithering
    for y in range(H):
        for x in range(W):
            if img[y][x] == G and (x - 104) ** 2 + ((y - 45) * 2) ** 2 < 60 and (x + y) % 2 == 0:
                img[y][x] = R
    # title lettering
    s1, s2 = "SOUTHERN", "CROSS"
    w1 = len(s1) * 12 - 2
    outlined_text(img, (W - w1) // 2, 21, s1, R, Y)
    w2 = len(s2) * 12 - 2
    outlined_text(img, 8, 35, s2, R, Y)
    # the Crux streaking up with its stars
    sprite(img, 8, 4, CRUX, {'y': Y, 'r': R, 'b': B})
    for y in range(12, 19):
        if y % 2 == 0:
            put(img, 12, y, R)
    t = "VIBED BY BPM 2026"
    text(img, 4, 54, t, Y)
    return render(img, [CSS0] * H, 'title.png')

if __name__ == '__main__':
    print(stage1())
    print(title())
