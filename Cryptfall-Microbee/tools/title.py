"""CRYPTFALL title picture (VIBED BY BPM 2026): 40 x 25 cells with their own
glyphs in PCG banks 2 and up, plus a strip of real game tiles (bank 0) that
twinkle and flap with the game's own tile animation.

Writes src/title.inc and build/title_preview.png.
"""
import os
import math
import numpy as np
import art as A

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
W, H = 320, 200


def jewel_letter(ch, sx=4, sy=5):
    """a big letter cut like a gemstone, grown from the game font's own shape:
    the single stroke becomes a thick rounded band with a solid rim, and the
    inside of the band is cut into diamond facets"""
    rows = A.RF[ch].split()
    gw = len(rows[0])
    w, h = gw * sx + 4, 7 * sy + 3
    pts = [(x, y) for y, r in enumerate(rows) for x, c in enumerate(r) if c == '#']
    on = set(pts)
    segs = []
    for (x, y) in pts:
        segs.append(((x, y), (x, y)))
        for dx, dy in ((1, 0), (0, 1), (1, 1), (-1, 1)):
            if (x + dx, y + dy) in on:
                # diagonals only where the corner is not already joined squarely
                if dx and dy and ((x + dx, y) in on or (x, y + dy) in on):
                    continue
                segs.append(((x, y), (x + dx, y + dy)))

    def dist(px, py):
        best = 1e9
        for (x0, y0), (x1, y1) in segs:
            ax, ay = x0 * sx + sx / 2 + 1.5, y0 * sy + sy / 2 + 1.0
            bx, by = x1 * sx + sx / 2 + 1.5, y1 * sy + sy / 2 + 1.0
            vx, vy = bx - ax, by - ay
            L = vx * vx + vy * vy
            t = 0 if L == 0 else max(0, min(1, ((px - ax) * vx + (py - ay) * vy) / L))
            dx, dy = px - (ax + t * vx), (py - (ay + t * vy)) * 0.85
            best = min(best, (dx * dx + dy * dy) ** 0.5)
        return best
    R = 3.3
    body = np.array([[dist(x, y) <= R for x in range(w)] for y in range(h)], bool)
    a = body.copy()
    for y in range(h):
        for x in range(w):
            if not body[y, x]:
                continue
            rim = (y == 0 or y == h - 1 or x == 0 or x == w - 1 or not body[y - 1, x] or not body[y + 1, x]
                   or not body[y, x - 1] or not body[y, x + 1])
            if not rim and ((x + y) % 5 == 0 or (x - y) % 5 == 0):
                a[y, x] = False             # the facet cuts
    return a


def compose():
    bits = np.zeros((H, W), bool)
    ink = np.full((25, 40), A.GREY, np.uint8)
    paper = np.zeros((25, 40), np.uint8)
    tiles = {}                                  # (cy, cx) -> (slot name, quadrant)

    # ---- stars
    for i in range(70):
        x, y = A.hsh(i, 3, 11) % W, A.hsh(i, 7, 12) % 150
        bits[y, x] = True
        if i % 9 == 0:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= x + dx < W and 0 <= y + dy < H:
                    bits[y + dy, x + dx] = True
    ink[:, :] = A.GREY
    for cy in range(25):
        for cx in range(40):
            ink[cy, cx] = (A.WHITE, A.GREY, A.BCYAN, A.GREY)[A.hsh(cx, cy, 2) % 4]

    # ---- the moon, low on the right, behind the castle
    mx, my, mr = 258, 96, 26
    for y in range(my - mr, my + mr + 1):
        for x in range(mx - mr, mx + mr + 1):
            d = math.hypot((x - mx) * 1.0, (y - my) * 1.15)
            if d <= mr:
                crater = any(math.hypot(x - cx, (y - cy) * 1.15) < r for cx, cy, r in ((250, 88, 5), (268, 104, 4), (262, 84, 2.5), (246, 104, 3)))
                bits[y, x] = not crater or (x + y) % 2 == 0
    for cy in range((my - mr) // 8, (my + mr) // 8 + 1):
        for cx in range((mx - mr) // 8, (mx + mr) // 8 + 1):
            ink[cy, cx] = A.YELLOW

    # ---- the castle on its hill (a silhouette; windows are holes with a lit paper)
    sil = np.zeros((H, W), bool)

    def box(x0, y0, x1, y1):
        sil[y0:y1, x0:x1] = True

    def crenel(x0, x1, y):
        for x in range(x0, x1):
            if ((x - x0) // 3) % 2 == 0:
                sil[y - 3:y, x] = True

    def roof(xc, y, hw, hh):
        for i in range(hh):
            w_ = int(round(hw * (hh - i) / hh))
            sil[y - i - 1, xc - w_:xc + w_ + 1] = True

    for x in range(W):                          # the hill
        top = 160 - int(34 * math.exp(-((x - 150) / 95.0) ** 2)) - int(3 * math.sin(x / 9.0))
        sil[top:160, x] = True
    box(104, 96, 200, 132)                      # curtain wall
    crenel(104, 200, 96)
    box(138, 70, 170, 132)                      # the keep
    crenel(138, 170, 70)
    box(96, 80, 114, 134)                       # left tower
    roof(105, 80, 11, 16)
    box(190, 74, 210, 134)                      # right tower
    roof(200, 74, 12, 20)
    box(60, 112, 76, 150)                       # a ruined outer tower
    sil[108:112, 60:64] = True
    sil[110:112, 68:71] = True
    # gate
    gate = np.zeros((H, W), bool)
    for y in range(112, 132):
        for x in range(146, 162):
            if y > 118 or math.hypot(x - 153.5, y - 119) < 8:
                gate[y, x] = True
    wins = [(100, 90), (106, 104), (196, 84), (202, 100), (144, 80), (160, 80), (120, 108), (180, 108), (66, 122)]
    win = np.zeros((H, W), bool)
    for wx, wy in wins:
        win[wy:wy + 6, wx:wx + 3] = True
        win[wy - 1, wx + 1] = True
    hole = win | gate
    bits |= sil
    # where a cell holds a window, the lit pixels are holes in a blue wall
    for cy in range(25):
        for cx in range(40):
            c_s = sil[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            c_h = hole[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            if c_h.any():
                bits[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8] = c_s & ~c_h
                ink[cy, cx] = A.BLUE
                g = gate[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8].any()
                paper[cy, cx] = A.BRED if g else A.YELLOW
            elif c_s.any():
                moon = ink[cy, cx] == A.YELLOW and not c_s.all()
                if moon:
                    # castle against the moon: the moon is the paper
                    cell = bits[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
                    bits[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8] = c_s
                    paper[cy, cx] = A.YELLOW
                ink[cy, cx] = A.BLUE
    # texture on the hill
    for y in range(128, 160):
        for x in range(W):
            if sil[y, x] and y > 150 - int(34 * math.exp(-((x - 150) / 95.0) ** 2)) + 12 and A.hsh(x, y, 4) % 5 == 0:
                cy, cx = y // 8, x // 8
                if paper[cy, cx] == 0:
                    bits[y, x] = False

    # ---- the name in jewels: CRYPT stands, FALL comes down.  Each letter
    # sits in its own four columns of cells, so each is its own gemstone.
    GEMS = [A.BRED, A.YELLOW, A.BGREEN, A.BCYAN, A.BMAGENTA, A.YELLOW, A.BGREEN, A.BCYAN, A.BRED]
    drop = {5: 2, 6: 6, 7: 12, 8: 18}
    for i, ch in enumerate('CRYPTFALL'):
        L = jewel_letter(ch)
        x0 = 16 + i * 32 + (32 - L.shape[1]) // 2
        y0 = 4 + drop.get(i, 0)
        cx0, cx1 = 2 + i * 4, 6 + i * 4
        cy0, cy1 = y0 // 8, (y0 + L.shape[0] - 1) // 8
        bits[cy0 * 8:(cy1 + 1) * 8, cx0 * 8:cx1 * 8] = False      # no stars behind the stone
        bits[y0:y0 + L.shape[0], x0:x0 + L.shape[1]] |= L
        for cy in range(cy0, cy1 + 1):
            for cx in range(cx0, cx1):
                ink[cy, cx] = A.WHITE if cy == cy0 else GEMS[i]    # a glint along the top
                paper[cy, cx] = 0
        # a sparkle at the stone's shoulder
        sx_, sy_ = x0 + L.shape[1] - 1, y0 + 1
        for k in range(-2, 3):
            if 0 <= sy_ + k < H:
                bits[sy_ + k, sx_] = True
            if cx0 * 8 <= sx_ + k < cx1 * 8:
                bits[sy_, sx_ + k] = True

    # ---- the ground: a strip of the game's own tiles (rows 20-21)
    strip = ['DIRT1', 'BOULDER', 'DIRT1', 'GEM', 'DIRT1', 'RUBY', 'WALL1', 'PLAYER', None, 'EMERALD', 'BOULDER', 'DIRT1',
             'KEG', 'DIRT1', 'CRACKED', None, 'GHOST', None, 'SKULL', 'GEM']
    for i, n in enumerate(strip):
        for q in range(4):
            cy, cx = 20 + q // 2, i * 2 + q % 2
            bits[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8] = False
            paper[cy, cx] = 0
            if n:
                tiles[(cy, cx)] = (n, q)
    bits[176:200, :] = False                    # text rows: empty
    paper[22:25, :] = 0
    return bits, ink, paper, tiles, wins


def build():
    bits, ink, paper, tiles, wins = compose()
    S = A.slots()
    import tiles as TL
    idx = {n: i for i, n in enumerate(TL.FE_SLOTS)}
    lo = bytearray(1000)
    hi = bytearray(1000)
    col = bytearray(1000)
    pats = {}
    order = []
    for cy in range(25):
        for cx in range(40):
            o = cy * 40 + cx
            if (cy, cx) in tiles:
                n, q = tiles[(cy, cx)]
                s = S[n]
                lo[o] = 0x80 | (4 + idx[n] * 4 + q)
                hi[o] = 0
                col[o] = s.cols[q]
                continue
            p = bytes(int(''.join('1' if b else '0' for b in bits[cy * 8 + y, cx * 8:cx * 8 + 8]), 2) for y in range(8))
            if not any(p):
                lo[o], hi[o], col[o] = 0x80, 0, int(paper[cy, cx]) << 4
                continue
            if p not in pats:
                pats[p] = len(order)
                order.append(p)
            g = pats[p]
            lo[o] = 0x80 | (g & 127)
            hi[o] = 2 + (g >> 7)
            col[o] = (int(paper[cy, cx]) << 4) | int(ink[cy, cx])
    n = len(order)
    assert n <= 14 * 128, n
    L = ['; generated by tools/title.py: the title picture', 'TITLE_NG equ %d' % n]

    def dbs(label, data):
        L.append(label + ':')
        for i in range(0, len(data), 16):
            L.append('\tdb ' + ','.join('$%02X' % b for b in data[i:i + 16]))
    dbs('title_lo', lo)
    dbs('title_hi', hi)
    dbs('title_col', col)
    dbs('title_pcg', b''.join(A.pic10(g) for g in order))
    # the lit windows (cells) for the flicker
    cells = sorted({(wy // 8) * 40 + wx // 8 for wx, wy in wins})
    L.append('TITLE_NWIN equ %d' % len(cells))
    L.append('title_win:')
    L.append('\tdw ' + ','.join(str(c) for c in cells))
    open(os.path.join(ROOT, 'src', 'title.inc'), 'w').write('\n'.join(L) + '\n')
    print('title: %d glyphs (banks 2-%d), %d bytes' % (n, 2 + (n - 1) // 128, 3000 + n * 10))
    # preview
    from PIL import Image
    PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
    img = np.zeros((H, W, 3), np.uint8)
    for cy in range(25):
        for cx in range(40):
            if (cy, cx) in tiles:
                n_, q = tiles[(cy, cx)]
                s = S[n_]
                f = s.frames[0][(q // 2) * 8:(q // 2) * 8 + 8, (q % 2) * 8:(q % 2) * 8 + 8]
                for y in range(8):
                    for x in range(8):
                        img[cy * 8 + y, cx * 8 + x] = PAL[s.cols[q]] if f[y, x] else (0, 0, 0)
                continue
            for y in range(8):
                for x in range(8):
                    img[cy * 8 + y, cx * 8 + x] = PAL[ink[cy, cx]] if bits[cy * 8 + y, cx * 8 + x] else PAL[paper[cy, cx]]
    os.makedirs(os.path.join(ROOT, 'build'), exist_ok=True)
    Image.fromarray(img).resize((640, 480), Image.NEAREST).save(os.path.join(ROOT, 'build', 'title_preview.png'))


if __name__ == '__main__':
    import sys
    sys.path.insert(0, HERE)
    build()
