"""SKYLARKIN' front-end pictures: the title and the ending (VIBED BY BPM 2026).

Each picture is a whole 40 x 25 screen: 1000 glyph codes, 1000 banks,
1000 colours, dw n, then n colour patterns and n mono patterns (8 bytes).
Its glyphs go to the PCG from glyph 128 (bank 1) on; blank cells use
glyph 0 in their own colour."""
import numpy as np
import gfx as G
import art_common as AC
from gfx import Canvas
from gfx import (BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY, DGREY, BRED, BGREEN, YELLOW, BBLUE,
                 BMAGENTA, BCYAN, WHITE)

FIRST = 128


def big_text(c, x, y, text, col_top, col_bot, scale=3, shadow=None):
    """chunky letters: the 5 x 7 font scaled up, two colours top and bottom"""
    for i, ch in enumerate(text):
        rows = G.FD.get(ch, G.FD[' ']).split()
        for r, bits in enumerate(rows):
            for k, b in enumerate(bits):
                if b == '1':
                    px = x + i * 6 * scale + k * scale
                    py = y + r * scale
                    if shadow is not None:
                        c.rect(px + 2, py + 2, scale, scale, shadow)
        for r, bits in enumerate(rows):
            for k, b in enumerate(bits):
                if b == '1':
                    for yy in range(y + r * scale, y + r * scale + scale):
                        # the colour changes on a cell boundary: no clash
                        c.rect(x + i * 6 * scale + k * scale, yy, scale, 1,
                               col_top if yy < (y // 8 + 1) * 8 + 8 else col_bot)


def pilot(c, name, x, y, scale=3, frame=0):
    rows = AC.PILOTS[name][frame]
    craft, rider = AC.PILOT_INK[name]
    for j, r in enumerate(rows):
        for i, ch in enumerate(r):
            if ch == '#' or ch == '*':
                c.rect(x + i * scale, y + j * scale, scale, scale, craft)
            elif ch == 'o':
                c.rect(x + i * scale, y + j * scale, scale, scale, rider)


def picture(c, sky):
    """canvas (200 x 320 colour indices, 0 = the row's sky colour) -> blob"""
    lo, hi, col = bytearray(1000), bytearray(1000), bytearray(1000)
    pats = {}
    order = []
    for cy in range(25):
        for cx in range(40):
            win = c.a[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]
            pat, ink, paper = G.cell_colours(win, sky[cy])
            i = cy * 40 + cx
            if not any(pat):
                g = 0
            else:
                mono = G.mono_of(pat, ink, paper)
                key = (pat, mono)
                if key not in pats:
                    pats[key] = FIRST + len(order)
                    order.append(key)
                g = pats[key]
            lo[i] = 0x80 | (g & 127)
            hi[i] = g >> 7
            col[i] = (paper << 4) | ink
    n = len(order)
    assert FIRST + n <= 10 * 128, 'picture needs %d glyphs' % n
    out = bytes(lo) + bytes(hi) + bytes(col) + n.to_bytes(2, 'little')
    out += b''.join(p for p, m in order) + b''.join(m for p, m in order)
    return out, n


def title():
    c = Canvas(320, 200)
    sky = [BLACK] * 2 + [BLUE] * 9 + [BLUE] * 5 + [BLACK] * 9
    # a dusk sky with a few stars and the moon
    for (sx, sy) in ((20, 20), (70, 12), (130, 26), (210, 10), (300, 30), (250, 22), (40, 60)):
        c.px(sx, sy, WHITE)
    c.ellipse(284, 40, 10, 7, YELLOW)
    c.ellipse(288, 37, 8, 6, 0)
    # the logo
    big_text(c, 16, 24, "SKYLARKIN'!", YELLOW, BRED, scale=3)
    # clouds
    for (cx, cy, rx) in ((40, 92, 26), (150, 100, 34), (270, 92, 28)):
        c.ellipse(cx, cy, rx, 7, WHITE)
        c.ellipse(cx - rx // 2, cy - 4, rx // 2, 5, WHITE)
    # the four pilots, flying in a row
    for i, (n, yy) in enumerate((('BAZZA', 104), ('SHEILA', 96), ('WALLY', 104), ('QUEENIE', 96))):
        pilot(c, n, 12 + i * 78, yy, scale=3)
    return picture(c, sky)


def ending():
    c = Canvas(320, 200)
    sky = [BLUE] * 25
    # the boardroom: a long table, the pilots at the party
    c.rect(0, 160, 320, 40, BROWN)
    c.hatch(0, 161, 320, 39, RED, period=3)
    c.rect(20, 136, 280, 6, BROWN)
    c.rect(30, 142, 6, 18, BROWN)
    c.rect(284, 142, 6, 18, BROWN)
    for i, n in enumerate(('BAZZA', 'SHEILA', 'WALLY', 'QUEENIE')):
        x = 24 + i * 72
        pilot(c, n, x, 92, scale=2)
        # party hats
        for k in range(8):
            c.rect(x + 12 - k // 2, 82 + k, k + 1, 1, BMAGENTA if i % 2 else YELLOW)
    # balloons
    for (bx, by, bc) in ((12, 30, BRED), (300, 26, YELLOW), (160, 18, BGREEN)):
        c.ellipse(bx, by, 7, 9, bc)
        c.line(bx, by + 9, bx + 3, by + 30, WHITE)
    # the stamp: APPROVED, in a red frame
    c.frame(44, 40, 232, 36, BRED)
    c.frame(46, 42, 228, 32, BRED)
    big_text(c, 56, 47, 'APPROVED', BRED, BRED, scale=3)
    # confetti
    rnd = np.random.RandomState(7)
    for k in range(60):
        x, y = int(rnd.randint(0, 320)), int(rnd.randint(0, 130))
        if not (40 <= y <= 80 and 40 <= x <= 280):
            c.px(x, y, int(rnd.choice([YELLOW, BMAGENTA, BCYAN, BGREEN, WHITE])))
    return picture(c, sky)
