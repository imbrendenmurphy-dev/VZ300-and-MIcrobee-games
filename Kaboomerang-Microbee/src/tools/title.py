"""The KABOOMERANG title picture: bubbly lettering drawn with a fat round pen
(the two O's are lit bombs), bursting out of a spiky explosion, with Wally
and a bomb below. -> bits (250 x 320), ink and paper per 8 x 10 cell."""
import math
import numpy as np
import art as A

W, H, CW, CH = 320, 250, 8, 10
ASPECT = A.ASPECT
PEN = 4.6                       # pen radius (pixels across)


def _segs_to_mask(segs, ox, oy, rx=PEN):
    """thick round-pen strokes: segs = [(x0, y0, x1, y1)] in pixels"""
    ry = rx * ASPECT
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    m = np.zeros((H, W), bool)
    for x0, y0, x1, y1 in segs:
        x0 += ox; x1 += ox; y0 += oy; y1 += oy
        # distance in "round" space: y scaled so the pen looks round on screen
        ax, ay = x0, y0 / ASPECT
        bx, by = x1, y1 / ASPECT
        px, py = xx, yy / ASPECT
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy
        t = np.clip(((px - ax) * dx + (py - ay) * dy) / L, 0, 1) if L else 0
        cx, cy = ax + t * dx, ay + t * dy
        m |= (px - cx) ** 2 + (py - cy) ** 2 <= (rx) ** 2 * (1.0 if True else 1)
    return m


def arc(cx, cy, rx, ry, a0, a1, n=14):
    pts = [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
            cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
    return pts


def poly(pts):
    return [(pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]) for i in range(len(pts) - 1)]


# letter skeletons in a box 28 pixels tall: (width, segments, extra)
def letters():
    L = {}
    L['K'] = (15, poly([(0, 0), (0, 28)]) + poly([(15, 0), (3, 14), (15, 28)]))
    L['A'] = (16, poly([(0, 28), (8, 0), (16, 28)]) + poly([(3.6, 18), (12.4, 18)]))
    L['B'] = (14, poly([(0, 28), (0, 0), (6, 0)] + arc(6, 6.6, 6.6, 6.6, -90, 90) + [(0, 13.2)])
             + poly([(0, 13.2), (7, 13.2)] + arc(7, 20.6, 7.4, 7.4, -90, 90) + [(0, 28)]))
    L['O'] = (17, poly(arc(8.5, 15, 8.5, 13, 0, 360, 24)))
    L['M'] = (20, poly([(0, 28), (0, 0), (10, 15), (20, 0), (20, 28)]))
    L['E'] = (13, poly([(13, 0), (0, 0), (0, 28), (13, 28)]) + poly([(0, 14), (10, 14)]))
    L['R'] = (14, poly([(0, 28), (0, 0), (7, 0)] + arc(7, 6.8, 6.8, 6.8, -90, 90) + [(0, 13.6)])
             + poly([(5, 13.6), (14, 28)]))
    L['N'] = (15, poly([(0, 28), (0, 0), (15, 28), (15, 0)]))
    L['G'] = (16, poly(arc(8, 14, 8, 14, -45, -340, 22) + [(16, 16), (9, 16)]))
    return L


def title_picture():
    bits = np.zeros((H, W), bool)
    ink = np.full((H // CH, W // CW), A.YELLOW, np.uint8)
    paper = np.zeros((H // CH, W // CW), np.uint8)
    # ---- the explosion burst behind the title
    cx, cy = 160, 37
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    th = np.arctan2((yy - cy) * 4.2, xx - cx)
    k = 0.80 + 0.30 * np.abs(np.cos(th * 8.5)) ** 3 + 0.08 * np.cos(th * 23)
    rr = np.sqrt(((xx - cx) / 156) ** 2 + ((yy - cy) / 29) ** 2)
    burst = (rr < k) & (yy < 70)
    core = burst
    # ---- the lettering
    L = letters()
    word = 'KABOOMERANG'
    gap = 1.5
    widths = [L[c][0] for c in word]
    total = sum(widths) + len(word) * (2 * PEN + gap) - gap
    x = (W - total) / 2 + PEN
    lettering = np.zeros((H, W), bool)
    fuses = []
    for i, c in enumerate(word):
        w, segs = L[c]
        oy = 21 + (2 if i % 2 else -2)              # a playful bounce
        lettering |= _segs_to_mask(segs, x, oy)
        if c == 'O':                                # bombs: a fuse and a spark
            fuses.append((x + w * 0.75, oy - 1))
        x += w + 2 * PEN + gap
    # shine: a little hole near the top-left of every stroke (reads as gloss)
    letters_px = lettering
    # fuses and sparks over the bomb O's
    spark = np.zeros((H, W), bool)
    fuse = np.zeros((H, W), bool)
    for fx, fy in fuses:
        for t in range(9):
            px = int(fx + t * 0.9)
            py = int(fy - 2 - t * 0.9 + (t / 3.0) ** 2)
            fuse[py:py + 2, px:px + 2] = True
        sx, sy = int(fx + 9), int(fy - 11)
        for d in range(-4, 5):
            if sy - 4 < 0:
                break
            spark[sy + d, sx] = True
            spark[sy, sx + d] = True
            if abs(d) < 3:
                spark[sy + d, sx + d] = True
                spark[sy - d, sx + d] = True
    # ---- cells: decide each cell's colours and pixels
    ncy, ncx = H // CH, W // CW
    grad = {0: A.WHITE, 1: A.WHITE, 2: A.YELLOW, 3: A.YELLOW, 4: A.YELLOW, 5: A.YELLOW}
    for r in range(ncy):
        for c in range(ncx):
            sl = (slice(r * CH, (r + 1) * CH), slice(c * CW, (c + 1) * CW))
            lp = letters_px[sl] | fuse[sl]
            sp = spark[sl]
            b = burst[sl]
            centre_in = burst[r * CH + 5, c * CW + 4]
            core_in = core[r * CH + 5, c * CW + 4]
            if lp.any() or sp.any():
                bits[sl] = lp | sp
                ink[r, c] = A.WHITE if sp.any() and not lp.any() else grad.get(r, A.YELLOW)
                paper[r, c] = A.RED if centre_in else A.BLACK
            elif b.all():
                paper[r, c] = A.RED
                # embers in the cloud
                e = np.zeros((CH, CW), bool)
                for yy2 in range(CH):
                    for xx2 in range(CW):
                        if A.hsh(c * 8 + xx2, r * 10 + yy2, 5) < 0.035:
                            e[yy2, xx2] = True
                bits[sl] = e
                ink[r, c] = A.YELLOW
            elif b.any():
                bits[sl] = b                       # the spiky edge, pixel by pixel
                ink[r, c] = A.RED
                paper[r, c] = A.BLACK
    # flying debris around the burst
    for i in range(26):
        ang = A.hsh(i, 1, 9) * math.tau
        rad = 1.05 + A.hsh(i, 2, 9) * 0.35
        px = int(cx + math.cos(ang) * 158 * rad)
        py = int(cy + math.sin(ang) * 34 * rad)
        if 0 <= px < W - 2 and 0 <= py < 70 - 2:
            rr_, cc_ = py // CH, px // CW
            sl = (slice(rr_ * CH, (rr_ + 1) * CH), slice(cc_ * CW, (cc_ + 1) * CW))
            if not bits[sl].any() and paper[rr_, cc_] == A.BLACK:
                bits[py:py + 2, px:px + 2] = True
                ink[rr_, cc_] = A.YELLOW if i % 3 else A.WHITE
    # ---- big Wally (2x) and a big bomb, rows 7-11
    import wally as Wl
    wal = A.art(Wl.front('norm', 'wide'))
    big = np.kron(wal, np.ones((2, 2), bool))           # 32 x 48
    wx, wy = 24, 72                                     # hat in row 7, wombat rows 8-11
    bits[wy:wy + 48, wx:wx + 32] |= big
    ink[7, wx // 8:(wx + 32) // 8] = A.YELLOW
    ink[8:12, wx // 8:(wx + 32) // 8] = A.BROWN
    bb = A.resample(A.bomb_bits(1, 1), 'round')
    bigb = np.kron(bb, np.ones((2, 2), bool))           # 32 x 40
    bx, by = 72, 80
    bits[by:by + 40, bx:bx + 32] |= bigb
    ink[8, bx // 8:bx // 8 + 4] = A.YELLOW
    ink[9:12, bx // 8:bx // 8 + 4] = A.BGREEN
    # ---- the ground: a strip of tiles, rows 20-21
    T = {t.name: t for t in A.all_tiles()}
    strip = ['MOUND0', 'FLOOR1', 'PILLAR', 'FLOOR2', 'MOUND0', 'MOUND0', 'FLOOR3', 'BURROW', 'FLOOR0', 'PILLAR',
             'MOUND0', 'FLOOR1', 'IT_FIRE', 'FLOOR2', 'MOUND0', 'PILLAR', 'FLOOR0', 'MOUND0', 'FLOOR3', 'EXIT']
    gy = 20
    for i, n in enumerate(strip):
        t = T[n]
        bits[gy * CH:gy * CH + 20, i * 16:i * 16 + 16] = t.bits
        for q, (qx, qy) in enumerate(((0, 0), (1, 0), (0, 1), (1, 1))):
            ink[gy + qy, i * 2 + qx], paper[gy + qy, i * 2 + qx] = t.cols[q]
    return bits, ink, paper


if __name__ == '__main__':
    import sys
    from PIL import Image
    PAL = [(0, 0, 0), (192, 0, 0), (0, 192, 0), (192, 96, 0), (0, 0, 192), (192, 0, 192), (0, 192, 192), (192, 192, 192),
           (96, 96, 96), (255, 64, 64), (64, 255, 64), (255, 255, 64), (64, 64, 255), (255, 64, 255), (64, 255, 255), (255, 255, 255)]
    bits, ink, paper = title_picture()
    img = np.zeros((H, W, 3), np.uint8)
    for y in range(H):
        for x in range(W):
            r, c = y // CH, x // CW
            img[y, x] = PAL[ink[r, c]] if bits[y, x] else PAL[paper[r, c]]
    im = Image.fromarray(img).resize((int(W * 3 * ASPECT), H * 3), Image.NEAREST)
    im.save(sys.argv[1])
