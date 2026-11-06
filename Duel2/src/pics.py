# executed inside gen.py: title picture (CSS1), ace portraits + medal (CSS0 pages)
# all original pixel art, BPM 2026
# CSS1 physical: 0 buff/white, 1 cyan, 2 magenta, 3 orange
W_, C_, M_, O_ = 0, 1, 2, 3
G_, Y_, B_, R_ = 0, 1, 2, 3


def canvas(w=128, h=64, c=0):
    return [[c] * w for _ in range(h)]


def put(P, x, y, c):
    if 0 <= y < len(P) and 0 <= x < len(P[0]):
        P[y][x] = c


# ---------------------------------------------------------------- logo lettering
# rounded block letters sized for Mode 1's tall pixels: strokes 4 px wide, 3 rows tall
def rr_inside(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    cx = min(max(x, x0 + r * 1.5), x1 - r * 1.5)
    cy = min(max(y, y0 + r), y1 - r)
    dx = (x - cx) / 1.5; dy = y - cy
    return dx * dx + dy * dy <= r * r + 0.3


def letter(ch, w=14, h=16):
    m = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            xx, yy = x + 0.5, y + 0.5
            o = rr_inside(xx, yy, 0, 0, w, h, 3.2)
            if ch == 'D':
                o = rr_inside(xx, yy, -6, 0, w, h, 3.2)
                hole = rr_inside(xx, yy, 4.5, 3.2, w - 4.5, h - 3.2, 1.6)
                v = o and not hole
            elif ch == 'U':
                hole = rr_inside(xx, yy, 4.5, -4, w - 4.5, h - 3.2, 1.6)
                v = o and not hole
            elif ch == 'E':
                v = o and not (x >= 4 and (3 <= y < 6.5 or 9.5 <= y < 13)) and not (x >= w - 3 and 6.5 <= y < 9.5)
            elif ch == 'L':
                v = rr_inside(xx, yy, 0, 0, w, h, 2.0) and not (x >= 4 and y < h - 3.2)
            elif ch == 'I':
                v = rr_inside(xx, yy, 0, 0, 5, h, 1.4)
            else:
                v = False
            m[y][x] = 1 if v else 0
    if ch == 'I':
        m = [r[:5] for r in m]
    return m


def stamp_word(P, word, x0, y0, face, hi, edge, shadow, gap=3):
    mask = {}
    x = x0
    for ch in word:
        if ch == ' ':
            x += 6
            continue
        g = letter(ch)
        for gy, row in enumerate(g):
            for gx, v in enumerate(row):
                if v:
                    mask[(x + gx, y0 + gy)] = gy
        x += len(g[0]) + gap
    for (px, py) in mask:
        put(P, px + 2, py + 2, shadow)
    for (px, py) in mask:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if (px + dx, py + dy) not in mask:
                    put(P, px + dx, py + dy, edge)
    for (px, py), gy in mask.items():
        put(P, px, py, hi if gy < 3 and (px + py) % 5 else face)
    return x


TP = canvas(c=C_)
# soft cloud bank along the bottom and a couple of high clouds (buff)
for (cx, cy, rx, ry) in ((10, 60, 16, 6), (34, 63, 14, 6), (60, 61, 18, 6), (90, 63, 16, 6), (118, 60, 15, 6),
                         (16, 30, 10, 3), (24, 28, 7, 3), (108, 34, 11, 3), (100, 32, 6, 3)):
    for y in range(64):
        for x in range(128):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                put(TP, x, y, W_)
stamp_word(TP, "DUEL", 10, 4, O_, W_, M_, M_)
stamp_word(TP, "II", 88, 4, W_, W_, M_, M_, gap=3)
title_bytes = bitmap_to_bytes(TP)
d = packbits(title_bytes)
L.append("title_pic: ; %d bytes (CSS1)" % len(d))
db(d)
save_preview(TP, "title.png", CSS1)


# ---------------------------------------------------------------- portraits (24 x 20, CSS0)
def portrait(helmet=R_, goggles='up', tash=False, beard=False, scarf=R_, mood='grin', patch=False,
             mask=False, hat=None, skin=Y_, bgc=G_):
    P = canvas(24, 20, bgc)
    for y in range(20):
        for x in range(24):
            dx = (x - 11.5) / 1.5; dy = y - 9.5
            if dx * dx / 36.0 + dy * dy / 64.0 <= 1.0 and y >= 3:
                P[y][x] = skin
    # leather flying helmet over the top and the ears
    for y in range(0, 20):
        for x in range(24):
            dx = (x - 11.5) / 1.5; dy = y - 9.0
            if dx * dx / 50.0 + dy * dy / 70.0 <= 1.0:
                if y < 6 or (y < 14 and abs(x - 11.5) > 7.5):
                    P[y][x] = helmet
    if hat == 'cap':
        for x in range(3, 21):
            put(P, x, 4, B_); put(P, x, 3, B_)
        for x in range(5, 19):
            put(P, x, 2, B_); put(P, x, 1, B_)
        put(P, 11, 2, Y_); put(P, 12, 2, Y_)
    if hat == 'turban':
        for y in range(0, 5):
            for x in range(4 + y // 2, 20 - y // 2):
                put(P, x, 4 - y, Y_ if (x + y) % 3 else R_)
    eye_y = 8
    if goggles == 'up':
        for x in (6, 7, 8, 15, 16, 17):
            put(P, x, 4, B_); put(P, x, 5, B_)
        for x in range(9, 15):
            put(P, x, 4, B_)
    if goggles == 'on' or mask:
        for x in range(5, 19):
            put(P, x, eye_y - 1, B_); put(P, x, eye_y, B_); put(P, x, eye_y + 1, B_)
        for x in (7, 8, 15, 16):
            put(P, x, eye_y, Y_ if not mask else R_)
    else:
        for x in (8, 15):
            put(P, x, eye_y, B_); put(P, x, eye_y + 1, B_)
        if patch:
            for x in range(13, 18):
                put(P, x, eye_y, B_); put(P, x, eye_y + 1, B_)
            for x in range(5, 13):
                put(P, x, 6 + (x - 5) // 3, B_)
    # nose
    put(P, 11, 11, R_); put(P, 12, 11, R_)
    my = 14
    if mood == 'grin':
        for x in range(9, 15):
            put(P, x, my, R_)
        put(P, 8, my - 1, R_); put(P, 15, my - 1, R_)
    elif mood == 'grim':
        for x in range(9, 15):
            put(P, x, my, R_)
    elif mood == 'sneer':
        for x in range(10, 15):
            put(P, x, my, R_)
        put(P, 15, my - 1, R_)
    elif mood == 'oh':
        put(P, 11, my, R_); put(P, 12, my, R_); put(P, 11, my + 1, R_); put(P, 12, my + 1, R_)
    if tash:
        for x in range(7, 17):
            put(P, x, 12, B_ if helmet != B_ else R_)
        put(P, 6, 13, B_); put(P, 17, 13, B_)
    if beard:
        for y in range(15, 19):
            for x in range(7 + (y - 15), 17 - (y - 15)):
                put(P, x, y, B_)
    if mask:
        for y in range(11, 18):
            for x in range(6, 18):
                if P[y][x] == Y_:
                    P[y][x] = B_
    # scarf
    for x in range(4, 20):
        put(P, x, 19, scarf)
    for x in range(14, 22):
        put(P, x, 18, scarf)
    return P


ACES = [  # name, portrait
    ("ROOKIE RUDY", dict(helmet=R_, goggles='up', mood='oh', scarf=B_)),
    ("FARMER FRITZ", dict(helmet=R_, goggles='up', tash=True, mood='grin', hat='cap', scarf=R_)),
    ("SALTY SUE", dict(helmet=B_, goggles='up', mood='grin', scarf=R_)),
    ("CAPTAIN KRAKEN", dict(helmet=R_, goggles='up', beard=True, patch=True, mood='sneer', scarf=B_)),
    ("DUNE RAIDER", dict(helmet=Y_, goggles='on', mood='grim', hat='turban', scarf=B_)),
    ("SCORPION", dict(helmet=R_, goggles='on', tash=True, mood='sneer', scarf=R_)),
    ("NIGHT OWL", dict(helmet=B_, goggles='on', mood='grim', scarf=Y_)),
    ("THE PHANTOM", dict(helmet=B_, mask=True, mood='grim', scarf=R_)),
    ("YOU", dict(helmet=R_, goggles='up', mood='grin', scarf=Y_)),
]
L.append("portraits: ; 9 x (6 bytes x 20 rows), CSS0")
psheet = canvas(9 * 26, 20, G_)
for i, (n, kw) in enumerate(ACES):
    P = portrait(**kw)
    db(bitmap_to_bytes(P, 0, 24))
    for y in range(20):
        for x in range(24):
            psheet[y][i * 26 + x] = P[y][x]
save_preview(psheet, "portraits.png")

# ---------------------------------------------------------------- medal (32 x 30, CSS0)
MP = canvas(32, 30, G_)
for y in range(0, 12):
    for x in range(8 + y // 2, 24 - y // 2):
        put(MP, x, y, R_ if (x // 3) % 2 else B_)
for y in range(12, 30):
    for x in range(32):
        dx = (x - 15.5) / 1.5; dy = y - 20.5
        r2 = dx * dx + dy * dy
        if r2 <= 81:
            put(MP, x, y, Y_)
        if 49 <= r2 <= 60:
            put(MP, x, y, R_)
# star
for (sx, sy) in ((15, 16), (16, 16), (15, 17), (16, 17), (13, 19), (14, 19), (15, 19), (16, 19), (17, 19), (18, 19),
                 (14, 20), (15, 20), (16, 20), (17, 20), (14, 22), (15, 21), (16, 21), (17, 22), (13, 23), (18, 23)):
    put(MP, sx, sy, R_)
L.append("medal_pic: ; 8 bytes x 30 rows")
db(bitmap_to_bytes(MP, 0, 32))
save_preview(MP, "medal.png")
