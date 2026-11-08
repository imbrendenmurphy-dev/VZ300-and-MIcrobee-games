"""The five courts of MICROBEE AUSTRALIAN OPEN TENNIS, drawn in Microbee colours.

draw(v, crowd=0, ump=0) -> Canvas.  crowd: 0 seated, 1 cheering (arms up),
2 standing (the wave).  ump: umpire pose 0 centre, 1 looks left, 2 looks
right, 3 arm up (calls), 4 leans in.
Cell rows (16 px): 0 roof/sky, 1-2 far crowd (scoreboard at the left),
3 advertising boards, 4 run-off, 5-14 court (net mesh = row 8), 15 run-off."""
import math
import random
import numpy as np
from cells import *
import geom as G

VENUES = ['KOOYONG', 'PERTH', 'SYDNEY', 'MELBOURNE', 'CLASSIC']
# per venue: court, surround, line, stripe (grass), stand, seat shade, sky
STYLE = {
    'KOOYONG':   dict(court=GRN, alt=BGRN, sur=GRN, line=WHT, stand=DGR, stand2=BLK, wall=GRN, stripes=True, mesh=DGR),
    'PERTH':     dict(court=BRN, alt=None, sur=RED, line=WHT, stand=BLK, stand2=DGR, wall=RED, stripes=False, mesh=DGR),
    'SYDNEY':    dict(court=CYN, alt=None, sur=BLU, line=WHT, stand=DGR, stand2=BLK, wall=BLU, stripes=False, mesh=DGR),
    'MELBOURNE': dict(court=BBLU, alt=None, sur=BLU, line=WHT, stand=BLK, stand2=DGR, wall=BLU, stripes=False, mesh=DGR),
    'CLASSIC':   dict(court=GRN, alt=None, sur=GRN, line=YEL, stand=BLK, stand2=BLK, wall=BLU, stripes=False, mesh=YEL),
}
SURR_GAP = 22          # px between the doubles side line and the surround edge
BOARD_ROW = 3
NET_TAPE = (126, 127)
NET_MESH = (128, 143)


def court_edges(y, gap=SURR_GAP):
    Y = G.world_y_of_row(y + 0.5)
    return G.sx(0, Y) - gap, G.sx(256, Y) + gap


def draw_court(c, st):
    court, sur, line = st['court'], st['sur'], st['line']
    # surround everywhere below the boards
    c.rect(0, 64, 511, 255, sur)
    for y in range(64, 256):
        a, b = court_edges(y)
        if y >= 64:
            col = court
            if st['stripes']:
                col = court if (y // 16) % 2 else st['alt']
            # behind the baselines the surround starts at cell edges
            c.rect(int(round(a)), y, int(round(b)), y, col)
    if st['stripes']:          # grass: the whole lawn is striped
        for y in range(64, 256):
            col = st['court'] if (y // 16) % 2 else st['alt']
            a, b = court_edges(y)
            c.rect(0, y, 511, y, col)
    lw = lambda Y: 2 if Y < 150 else 3

    def hline(Y, X0, X1):
        y = int(round(G.sy(Y)))
        t = 1 if Y < 100 else 2
        c.rect(int(round(G.sx(X0, Y))) - 1, y, int(round(G.sx(X1, Y))) + 1, y + t - 1, line)

    def vline(X, Y0, Y1):
        for y in range(int(round(G.sy(Y0))), int(round(G.sy(Y1))) + 1):
            Y = G.world_y_of_row(y)
            x = G.sx(X, Y)
            w = lw(Y)
            c.rect(int(round(x - w / 2)), y, int(round(x - w / 2)) + w - 1, y, line)
    if st.get('classic'):
        return
    hline(G.YFAR, 0, 256)
    hline(G.YNEAR, 0, 256)
    hline(G.YSF, G.XL, G.XR)
    hline(G.YSN, G.XL, G.XR)
    for X in (0, 256, G.XL, G.XR):
        vline(X, G.YFAR, G.YNEAR)
    vline(G.XC, G.YSF, G.YSN)
    # centre marks
    vline(G.XC, G.YFAR, G.YFAR + 4)
    vline(G.XC, G.YNEAR - 5, G.YNEAR)


def draw_classic_court(c, st):
    """the 1984 look, at Microbee resolution: stepped side lines, a full-length centre line"""
    line = st['line']
    c.rect(0, 64, 511, 255, st['sur'])
    y0, y1 = int(G.sy(G.YFAR)), int(G.sy(G.YNEAR))
    for y in range(y0, y1 + 1):
        Y = G.world_y_of_row(y)
        # quantise the side lines to 16-px steps
        q = int(G.sx(G.XL, Y)) // 16 * 16
        r = 512 - q
        c.rect(q, y, q + 3, y, line)
        c.rect(r - 4, y, r - 1, y, line)
        c.rect(254, y, 257, y, line)
    c.rect(int(G.sx(G.XL, G.YFAR)) // 16 * 16, y0, 512 - int(G.sx(G.XL, G.YFAR)) // 16 * 16, y0 + 1, line)
    c.rect(int(G.sx(G.XL, G.YNEAR)) // 16 * 16, y1, 512 - int(G.sx(G.XL, G.YNEAR)) // 16 * 16, y1 + 2, line)


def draw_net(c, st):
    a, b = G.sx(-8, G.YNET), G.sx(264, G.YNET)
    a, b = int(round(a)), int(round(b))
    m0, m1 = NET_MESH
    for y in range(m0, m1 + 1):
        for x in range(a, b + 1):
            if (x + y) % 4 == 0 or (x - y) % 4 == 0 or y == m0:
                c.px(x, y, st['mesh'])
    c.rect(a, NET_TAPE[0], b, NET_TAPE[1], WHT if st['line'] == WHT else st['line'])
    for x in (a, b):
        c.rect(x - 3, NET_TAPE[0] - 1, x + 2, m1, BLK)


# ------------------------------------------------------------------ crowd
def person(c, x, y, pose, shirt, rng, face=None, h=8):
    """a 4 px wide spectator whose head top is at y (8 rows tall)"""
    if pose == 2:
        y -= 3                       # standing up
    c.rect(x + 1, y, x + 2, y + 2, shirt)        # head
    c.rect(x, y + 3, x + 3, y + 7 + (3 if pose == 2 else 0), shirt)   # body
    if pose == 1:                    # arms up
        c.px(x, y - 1, shirt)
        c.px(x + 3, y - 1, shirt)
        c.px(x, y, shirt)
        c.px(x + 3, y, shirt)
    if pose == 2:
        c.px(x - 1, y - 2, shirt)
        c.px(x + 4, y - 2, shirt)
        c.px(x - 1, y - 1, shirt)
        c.px(x + 4, y - 1, shirt)


CROWD_COLS = [RED, BRED, YEL, WHT, BCYN, BMAG, BGRN, CYN, MAG, LGR, BBLU, GRN, BRN]


def crowd_block(c, x0, y0, x1, y1, pose, st, seed, cols=None):
    """tiers of spectators filling a cell-aligned block; one shirt colour per cell"""
    rng = random.Random(seed)
    cols = cols or CROWD_COLS
    c.rect(x0, y0, x1, y1, st['stand'])
    for cy in range(y0 // 16, (y1 + 1) // 16):
        for cx in range(x0 // 8, (x1 + 1) // 8):
            col = rng.choice([k for k in cols if k != st['stand']])
            for tier in (0, 1):
                ty = cy * 16 + tier * 8 + 2
                for k in (0, 1):
                    if rng.random() < 0.9:
                        person(c, cx * 8 + k * 4 + (tier & 1) * 0, ty, pose, col, rng)


# ------------------------------------------------------------------ text helpers
_FONT = None


def glyph(ch, font='SPORT'):
    global _FONT
    if _FONT is None:
        import fonts
        _FONT = fonts.FONTS
    g = _FONT[font][ord(ch) - 32]
    return np.array([[(b >> (7 - k)) & 1 for k in range(8)] for b in g], bool)


def cell_text(c, txt, col, row, ink, font='SPORT', wide=1):
    """text on cell boundaries (one ink over whatever paper is there)"""
    a = c.a
    x = col * 8
    for ch in txt:
        g = glyph(ch, font)
        if wide == 2:
            g = np.repeat(g, 2, axis=1)
        h, w = g.shape
        sub = a[row * 16:row * 16 + h, x:x + w]
        sub[g[:, :sub.shape[1]]] = ink
        x += w
    c.set(a)


# ------------------------------------------------------------------ umpire
def draw_umpire(c, st, pose, x=440):
    """a tall chair at the net on the right; the umpire sits at y ~ 90..112"""
    frame = LGR
    base = 143
    seat = 108
    sur = st['sur']
    c.rect(x, seat, x + 2, base, frame)
    c.rect(x + 26, seat, x + 28, base, frame)
    c.line(x + 1, seat + 4, x + 27, base - 4, frame)
    c.line(x + 27, seat + 4, x + 1, base - 4, frame)
    c.rect(x - 2, seat, x + 30, seat + 3, WHT)              # seat platform
    c.rect(x + 22, seat - 18, x + 25, seat, frame)          # chair back
    # sunshade on a pole (venue colour)
    shade = {'KOOYONG': GRN, 'PERTH': BRED, 'SYDNEY': BCYN, 'MELBOURNE': BBLU, 'CLASSIC': YEL}[st['name']]
    c.rect(x + 24, seat - 40, x + 25, seat - 18, frame)
    c.poly([(x + 4, seat - 38), (x + 44, seat - 38), (x + 38, seat - 43), (x + 10, seat - 43)], shade)
    # the umpire: dark blazer, white cap; faces the court (to the left)
    body = BLK if sur not in (BLK,) else DGR
    lean = 3 if pose == 4 else 0
    c.rect(x + 8 - lean, seat - 15, x + 20 - lean, seat - 1, body)     # torso
    c.rect(x + 4, seat - 4, x + 20, seat, body)                         # lap
    c.rect(x + 2, seat, x + 6, seat + 12, body)                         # legs
    hx = x + 13 - lean + (-3 if pose == 1 else 2 if pose == 2 else 0)
    hy = seat - 21 + (1 if pose == 4 else 0)
    c.ellipse(hx, hy, 4, 3, LGR)                                        # head
    c.rect(hx - 4, hy - 4, hx + 3, hy - 3, WHT)                         # cap
    c.rect(hx - 6 if pose != 2 else hx + 3, hy - 3, hx - 3 if pose != 2 else hx + 6, hy - 3, WHT)  # peak
    if pose == 3:
        c.rect(x + 6 - lean, seat - 31, x + 8 - lean, seat - 14, body)  # arm up, pointing
        c.rect(x + 5, seat - 33, x + 9, seat - 31, LGR)
    else:
        c.rect(x + 4 - lean, seat - 12, x + 9 - lean, seat - 8, body)   # arm to the microphone
        c.rect(x + 2 - lean, seat - 12, x + 3 - lean, seat - 9, LGR)


def draw_bench(c, x, y, towel):
    """a player's chair with a towel and a racket bag"""
    c.rect(x, y + 6, x + 10, y + 8, LGR)
    c.rect(x, y, x + 1, y + 12, LGR)
    c.rect(x + 9, y + 8, x + 10, y + 12, LGR)
    c.rect(x + 2, y + 2, x + 6, y + 6, towel)
    c.rect(x + 13, y + 7, x + 22, y + 11, towel)


def draw_ballkid(c, x, y, shirt):
    """a ball kid crouched at the net post"""
    c.ellipse(x + 3, y + 1, 2, 2, LGR)
    c.rect(x + 1, y + 3, x + 5, y + 8, shirt)
    c.rect(x, y + 8, x + 6, y + 10, shirt)


def draw_linejudge(c, x, y, shirt):
    c.rect(x, y + 6, x + 8, y + 7, LGR)                      # chair
    c.rect(x, y + 7, x + 1, y + 12, LGR)
    c.rect(x + 7, y + 7, x + 8, y + 12, LGR)
    c.ellipse(x + 4, y - 1, 2, 2, LGR)                       # judge
    c.rect(x + 2, y + 1, x + 6, y + 6, shirt)
    c.rect(x + 1, y - 4, x + 7, y - 3, WHT)                  # hat


def stand_cols(row, side):
    """cell columns of the side stand on cell row (4..15): left: 0..n-1, right: n..63"""
    y = row * 16
    a0, b0 = court_edges(y)
    a1, b1 = court_edges(y + 15)
    if side == 0:
        return 0, max(0, int(min(a0, a1) - 10) // 8)
    lo = (int(max(b0, b1) + 10) + 7) // 8
    if 4 <= row <= 8:
        lo = max(lo, 62)           # room for the umpire's chair
    if 9 <= row <= 10:
        lo = max(lo, 61)           # the players' chairs
    return min(64, lo), 64


def draw_side_stands(c, st, pose, seed):
    for row in range(4, 16):
        for side in (0, 1):
            a, b = stand_cols(row, side)
            if b - a >= 1:
                crowd_block(c, a * 8, row * 16, b * 8 - 1, row * 16 + 15, pose, st, seed=seed + row * 7 + side * 101)


_GAME_BOARD = True
BOARD_X0, BOARD_X1 = 11 * 8, 53 * 8 - 1     # cells 11..52 (src/board.asm)
BOARDS = {'KOOYONG': (GRN, WHT), 'PERTH': (BLK, YEL), 'SYDNEY': (BLU, WHT), 'MELBOURNE': (BLU, WHT), 'CLASSIC': (BLU, YEL)}


def draw_boards(c, st, venue):
    y = BOARD_ROW * 16
    bg, fg = BOARDS[venue]
    c.rect(0, y, 511, y + 15, bg)
    if _GAME_BOARD:
        # the end wall: the game's LED scroller between the two end stands
        c.rect(BOARD_X0, y, BOARD_X1, y + 15, BLK)
        return
    texts = ['MICROBEE', 'BPM', 'APPLIED TECHNOLOGY', 'VIBED 2026', 'PREMIUM PLUS', 'MICROWORLD']
    col = 1
    k = 0
    while col < 63:
        t = texts[k % len(texts)]
        if col + len(t) > 63:
            break
        cell_text(c, t, col, BOARD_ROW, fg if k % 2 == 0 else (YEL if fg == WHT else WHT))
        col += len(t) + 3
        k += 1


RUNOFF = {'PERTH': ('PERTH', RED), 'SYDNEY': ('SYDNEY', BLU), 'MELBOURNE': ('MELBOURNE', BLU)}


def scenery(c, venue, st, crowd):
    """rows 0-1, columns 16-63: the place"""
    X0 = 128
    rng = random.Random(len(venue) * 31)
    if venue == 'KOOYONG':
        c.rect(X0, 0, 511, 15, BCYN)
        for cx in (170, 260, 330, 420, 480):            # clouds
            for k in range(4):
                c.ellipse(cx + k * 6 - 9, 8 - (k % 2) * 2, 7, 3, WHT)
        c.rect(X0, 16, 511, 31, GRN)                    # trees
        for x in range(X0, 512, 6):
            c.ellipse(x + 3, 18 + rng.randrange(4), 4, 4, BGRN)
        c.rect(260, 16, 380, 31, WHT)                   # the clubhouse
        for x in range(266, 376, 12):
            c.rect(x, 20, x + 5, 27, DGR)
    elif venue == 'PERTH':
        for y in range(16):
            for x in range(X0, 512):
                t = y / 15
                if ((x + y) % 4 == 0 and t > 0.2) or ((x + y * 3) % 7 == 0 and t > 0.55) or t > 0.85:
                    c.px(x, y, BRED)
                else:
                    c.px(x, y, YEL)
        c.ellipse(400, 12, 12, 7, WHT)                  # the setting sun
        c.rect(X0, 16, 511, 31, BRED)
        for x in range(X0, 512):                        # hills and gum trees
            h = 6 + 3 * math.sin(x / 23.0) + 2 * math.sin(x / 7.3)
            c.rect(x, int(31 - h), x, 31, BLK)
        for tx in (150, 215, 300, 345, 452, 495):
            c.rect(tx, 18, tx + 1, 31, BLK)
            c.ellipse(tx, 18, 7, 3, BLK)
            c.ellipse(tx + 4, 21, 5, 2, BLK)
    elif venue == 'SYDNEY':
        c.rect(X0, 0, 511, 15, BBLU)
        # the bridge: an arch and its deck
        for x in range(330, 506):
            t = (x - 418) / 88.0
            y = int(4 + 9 * t * t)
            c.rect(x, y, x, y + 1, DGR)
            if x % 8 == 0:
                c.rect(x, y, x, 13, DGR)
        c.rect(320, 13, 511, 15, DGR)
        # the sails
        for k, (sx, h) in enumerate(((180, 12), (196, 15), (214, 11), (230, 13), (246, 9))):
            c.poly([(sx, 15), (sx + 14, 15), (sx + 3, 15 - h)], WHT)
        c.rect(X0, 16, 511, 31, BLU)                    # the harbour
        for k in range(90):
            x, y = rng.randrange(X0, 512), rng.randrange(17, 31)
            c.rect(x, y, x + rng.randrange(1, 4), y, BCYN if k % 3 else WHT)
        for bx in (160, 290, 455):                      # ferries
            c.rect(bx, 22, bx + 14, 25, WHT)
            c.rect(bx + 4, 19, bx + 9, 21, WHT)
    elif venue == 'MELBOURNE':
        c.rect(X0, 0, 511, 31, BLK)
        for k in range(60):
            c.px(rng.randrange(X0, 512), rng.randrange(0, 10), WHT if k % 2 else LGR)
        for x in range(X0, 512, 3):                     # the roof's edge
            c.px(x, 11, DGR)
        for x in range(136, 512, 48):                   # floodlights
            c.rect(x, 2, x + 13, 6, WHT)
            c.rect(x + 2, 7, x + 11, 8, YEL)
        # the upper tier, dark, with camera flashes
        crowd_block(c, X0, 16, 511, 31, crowd, dict(st, stand=BLK), seed=99, cols=[DGR, BLU, LGR, MAG])
        for k in range(14):
            x, y = rng.randrange(X0, 512), rng.randrange(17, 31)
            c.px(x, y, WHT)
    else:   # CLASSIC: the 1984 green screen
        c.rect(X0, 0, 511, 31, GRN)
        cell_text(c, 'VZ TENNIS 1984', 30, 0, YEL)
        cell_text(c, 'RECREATED FOR THE MICROBEE', 24, 1, YEL)


def draw(venue, crowd=0, ump=0):
    st = dict(STYLE[venue])
    st['name'] = venue
    if venue == 'CLASSIC':
        st['classic'] = True
    c = Canvas(st['stand'])
    seed = sum(map(ord, venue)) * 77
    scenery(c, venue, st, crowd)
    cols = [YEL, BRED, BBLU] if venue == 'CLASSIC' else None
    crowd_block(c, 128, 32, 511, 47, crowd, st, seed=seed, cols=cols)
    draw_boards(c, st, venue)
    if _GAME_BOARD:              # end stands either side of the board
        cc = [YEL, BRED, BBLU] if venue == 'CLASSIC' else None
        crowd_block(c, 0, 48, BOARD_X0 - 1, 63, crowd, st, seed=seed + 5, cols=cc)
        crowd_block(c, BOARD_X1 + 1, 48, 511, 63, crowd, st, seed=seed + 9, cols=cc)
    if st.get('classic'):
        draw_classic_court(c, st)
    else:
        draw_court(c, st)
    if venue in RUNOFF:
        t, ink = RUNOFF[venue]
        cell_text(c, t, 32 - len(t), 4, ink, wide=2)
        cell_text(c, t, 32 - len(t), 15, ink, wide=2)
    if venue == 'CLASSIC':
        crowd_cols = [YEL, BRED, BBLU]
        for row in range(4, 16):
            for side in (0, 1):
                a, b = stand_cols(row, side)
                if b - a >= 1:
                    crowd_block(c, a * 8, row * 16, b * 8 - 1, row * 16 + 15, crowd, st, seed=seed + row * 7 + side * 101, cols=crowd_cols)
    else:
        draw_side_stands(c, st, crowd, seed)
    draw_net(c, st)
    draw_umpire(c, st, ump)
    sur = st['sur']
    kitc = {'KOOYONG': WHT, 'PERTH': YEL, 'SYDNEY': YEL, 'MELBOURNE': YEL, 'CLASSIC': YEL}[venue]
    draw_bench(c, 444, 148, kitc)
    draw_bench(c, 444, 166, BRED if venue != 'PERTH' else WHT)
    draw_ballkid(c, int(G.sx(-8, G.YNET)) - 16, 132, kitc)
    draw_linejudge(c, int(G.sx(0, G.YFAR)) - 18, 82, kitc)
    draw_linejudge(c, int(G.sx(256, G.YNEAR)) + 10, 214, kitc)
    # scoreboard (top-left; the text is written by the game)
    c.rect(0, 0, 127, 47, BLK)
    return c


if __name__ == '__main__':
    import sys
    for v in VENUES:
        c = draw(v)
        a = c.a
        pats, ink, paper = compile_cells(a)
        preview(pats, ink, paper, '/home/claude/aot/shots/venue_%s.png' % v.lower(), scale=2)
        c.save('/home/claude/aot/shots/raw_%s.png' % v.lower())
