#!/usr/bin/env python3
"""TENNIS II - GRAND SLAM data generator -> data.inc
font, sprites (8 px wide, explicit masks, shifted/recoloured at run time),
court backdrops (logical colours, recoloured per surface at run time),
projection tables, portraits, title + trophy pictures (pics.py), music (music.py).
Also writes preview PNGs into ../build/preview/ ."""
import os
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "data.inc")
PREV = os.path.join(HERE, "..", "build", "preview")
os.makedirs(PREV, exist_ok=True)
CSS0 = [(7, 255, 0), (255, 255, 0), (59, 8, 255), (204, 0, 59)]
CSS1 = [(255, 255, 255), (7, 227, 153), (255, 28, 255), (255, 129, 0)]
L = []


def db(vals, per=16):
    vals = list(vals)
    for i in range(0, len(vals), per):
        L.append("    db " + ",".join("$%02X" % (v & 255) for v in vals[i:i + per]))


def packbits(data):
    """0..127 -> n+1 literals; 129..255 -> repeat next byte 257-n times; 128 = end"""
    out = []; i = 0; n = len(data)
    while i < n:
        j = i
        while j < n and j - i < 128 and data[j] == data[i]:
            j += 1
        if j - i >= 3:
            out += [257 - (j - i), data[i]]; i = j; continue
        lit = []
        while i < n and len(lit) < 128:
            if i + 2 < n and data[i] == data[i + 1] == data[i + 2]:
                break
            lit.append(data[i]); i += 1
        out += [len(lit) - 1] + lit
    out.append(128)
    return out


def bitmap_to_bytes(pix, x0=0, w=128):
    out = []
    for y in range(len(pix)):
        for bx in range(w // 4):
            v = 0
            for k in range(4):
                v = (v << 2) | (pix[y][x0 + bx * 4 + k] & 3)
            out.append(v)
    return out


def save_preview(pix, name, pal=CSS0, sx=4, sy=6):
    w = len(pix[0]); h = len(pix)
    im = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            im.putpixel((x, y), pal[pix[y][x] & 3])
    im.resize((w * sx, h * sy), Image.NEAREST).save(os.path.join(PREV, name))


# ---------------------------------------------------------------- 3x5 font (from Penguin 2)
FONT = {
    ' ': ["...", "...", "...", "...", "..."],
    '0': ["###", "#.#", "#.#", "#.#", "###"], '1': [".#.", "##.", ".#.", ".#.", "###"],
    '2': ["###", "..#", "###", "#..", "###"], '3': ["###", "..#", ".##", "..#", "###"],
    '4': ["#.#", "#.#", "###", "..#", "..#"], '5': ["###", "#..", "###", "..#", "###"],
    '6': ["###", "#..", "###", "#.#", "###"], '7': ["###", "..#", ".#.", ".#.", ".#."],
    '8': ["###", "#.#", "###", "#.#", "###"], '9': ["###", "#.#", "###", "..#", "###"],
    'A': [".#.", "#.#", "###", "#.#", "#.#"], 'B': ["##.", "#.#", "##.", "#.#", "##."],
    'C': [".##", "#..", "#..", "#..", ".##"], 'D': ["##.", "#.#", "#.#", "#.#", "##."],
    'E': ["###", "#..", "##.", "#..", "###"], 'F': ["###", "#..", "##.", "#..", "#.."],
    'G': [".##", "#..", "#.#", "#.#", ".##"], 'H': ["#.#", "#.#", "###", "#.#", "#.#"],
    'I': ["###", ".#.", ".#.", ".#.", "###"], 'J': ["..#", "..#", "..#", "#.#", ".#."],
    'K': ["#.#", "#.#", "##.", "#.#", "#.#"], 'L': ["#..", "#..", "#..", "#..", "###"],
    'M': ["#.#", "###", "###", "#.#", "#.#"], 'N': ["##.", "#.#", "#.#", "#.#", "#.#"],
    'O': [".#.", "#.#", "#.#", "#.#", ".#."], 'P': ["##.", "#.#", "##.", "#..", "#.."],
    'Q': [".#.", "#.#", "#.#", "##.", ".##"], 'R': ["##.", "#.#", "##.", "#.#", "#.#"],
    'S': [".##", "#..", ".#.", "..#", "##."], 'T': ["###", ".#.", ".#.", ".#.", ".#."],
    'U': ["#.#", "#.#", "#.#", "#.#", "###"], 'V': ["#.#", "#.#", "#.#", "#.#", ".#."],
    'W': ["#.#", "#.#", "###", "###", "#.#"], 'X': ["#.#", "#.#", ".#.", "#.#", "#.#"],
    'Y': ["#.#", "#.#", ".#.", ".#.", ".#."], 'Z': ["###", "..#", ".#.", "#..", "###"],
    '!': [".#.", ".#.", ".#.", "...", ".#."], '?': ["##.", "..#", ".#.", "...", ".#."],
    '.': ["...", "...", "...", "...", ".#."], ',': ["...", "...", "...", ".#.", "#.."],
    ':': ["...", ".#.", "...", ".#.", "..."], '-': ["...", "...", "###", "...", "..."],
    '+': ["...", ".#.", "###", ".#.", "..."], '/': ["..#", "..#", ".#.", "#..", "#.."],
    "'": [".#.", ".#.", "...", "...", "..."], '&': [".#.", "#.#", ".#.", "#.#", ".##"],
    '=': ["...", "###", "...", "###", "..."], '<': ["..#", ".#.", "#..", ".#.", "..#"],
    '>': ["#..", ".#.", "..#", ".#.", "#.."], '*': ["#.#", ".#.", "###", ".#.", "#.#"],
    '(': [".#.", "#..", "#..", "#..", ".#."], ')': [".#.", "..#", "..#", "..#", ".#."],
    '"': ["#.#", "#.#", "...", "...", "..."], '#': ["#.#", "###", "#.#", "###", "#.#"],
    '^': [".#.", "###", "...", "...", "..."], '_': ["...", "...", "...", "...", "###"],
    '%': ["#.#", "..#", ".#.", "#..", "#.#"], ';': ["...", ".#.", "...", ".#.", "#.."],
    '$': [".#.", "###", "###", "###", ".#."],
    '\\': ["#..", "#..", ".#.", "..#", "..#"],
}
FONT['@'] = ["...", ".#.", "###", ".#.", "..."]   # ball icon (serve marker)
FONT['['] = [".#.", "###", ".#.", ".#.", "###"]   # trophy icon
FONT[']'] = ["#..", "##.", "###", "##.", "#.."]   # cursor arrow
L.append("; ---- 3x5 font, ASCII 32..95, 5 bytes/glyph, bit2 = left pixel")
L.append("font3:")
for c in range(32, 96):
    g = FONT.get(chr(c), FONT[' '])
    db([int(r.replace('#', '1').replace('.', '0'), 2) for r in g])

# ---------------------------------------------------------------- sprites
exec(open(os.path.join(HERE, "art.py")).read())
LOGI = {'.': None, 'D': 0, 'L': 1}
SPRS = []           # (name, rows of logical colours or None)


def spr(name, art, team=2):
    rows = [r.strip() for r in art.strip("\n").split("\n")]
    out = []
    for r in rows:
        out.append([None if ch == '.' else (team if ch == 'T' else LOGI[ch]) for ch in r.ljust(8, '.')[:8]])
    SPRS.append((name, out))


# one player set per court end: far frames use logical 2 (the far player's team colour),
# near frames logical 3 (the near player's) - rebuilt in the right colours when ends change
for side, frames, team in (('F', FAR, 2), ('N', NEAR, 3)):
    for fn, art in zip(PLAYER_FRAMES, frames):
        spr("%s_%s" % (side, fn), art, team)
for name, art in (("BALL", BALL), ("BALLS", BALLS), ("SHADOW", SHADOW), ("PUFF1", PUFF1), ("PUFF2", PUFF2),
                  ("CONE", CONE), ("CONEHIT", CONE_HIT), ("MACHINE", MACHINE), ("FLAG", FLAG),
                  ("FIRE1", FIRE1), ("FIRE2", FIRE2)):
    spr(name, art, 3)
spr("CONEA", CONE, 2)
# props drawn byte-aligned (no pre-shifted copies)
ONESHIFT = {"PUFF1", "PUFF2", "CONE", "CONEHIT", "CONEA", "MACHINE", "FLAG"}

L.append("; ---- sprite sources: per row d0,d1,m0,m1 (mask bits 11 = transparent)")
L.append("NSPR equ %d" % len(SPRS))
for i, (n, _) in enumerate(SPRS):
    L.append("SPR_%s equ %d" % (n, i))
L.append("SPR_F equ SPR_F_IDLE")
L.append("SPR_N equ SPR_N_IDLE")
for i, f in enumerate(PLAYER_FRAMES):
    L.append("FR_%s equ %d" % (f, i))
L.append("sprsrc:")
for n, rows in SPRS:
    L.append("    dw ss_%s : db %d,%d" % (n, len(rows), 1 if n in ONESHIFT else 0))
tot = 0
for n, rows in SPRS:
    L.append("ss_%s:" % n)
    bs = []
    for r in rows:
        d = [0, 0]; m = [0, 0]
        for x in range(8):
            c = r[x]
            b = x // 4; sh = 6 - 2 * (x % 4)
            if c is None:
                m[b] |= 3 << sh
            else:
                d[b] |= c << sh
        bs += d + m
    db(bs)
    tot += len(rows) * (6 if n in ONESHIFT else 24)
L.append("SHIFTSIZE equ %d" % tot)
# preview sheet of the sprites (grass colours)
GRASS_SPR = {0: 2, 1: 1, 2: 2, 3: 3}
sheet = [[0] * 160 for _ in range(48)]
for i, (n, rows) in enumerate(SPRS):
    ox = (i % 16) * 10; oy = (i // 16) * 12
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c is not None and oy + y < 48:
                sheet[oy + y][ox + x] = GRASS_SPR[c]
save_preview(sheet, "sprites.png")

# ---------------------------------------------------------------- court geometry
YFAR, YNEAR, YNET = 24, 232, 128
YSF, YSN = 72, 184
XL, XR, XC = 32, 224, 128
CX = 75
SYF, SYN = 12, 56
HWF, HWN = 32, 44


def sy_of(Y):
    return SYF + (Y - YFAR) * (SYN - SYF) / (YNEAR - YFAR)


def hw_of(Y):
    return HWF + (Y - YFAR) * (HWN - HWF) / (YNEAR - YFAR)


def sx_of(X, Y):
    return CX + (X - 128) * hw_of(Y) / 96.0


for k, v in (("YFAR", YFAR), ("YNEAR", YNEAR), ("YNET", YNET), ("YSF", YSF), ("YSN", YSN),
             ("XL", XL), ("XR", XR), ("XC", XC), ("CX", CX)):
    L.append("%s equ %d" % (k, v))


# crowd: 27 spectators, one per 4-px byte, across x 20..127 (rows 0-3, logical colours)
# frame A sitting, frame B jumping with arms up. bg = 2 (surround), heads 1, bodies 3 (some 1)
import random as _cr
_cr.seed(11)
CROWD_A = [[2] * 108 for _ in range(4)]
CROWD_B = [[2] * 108 for _ in range(4)]
for i in range(27):
    x = i * 4 + 1
    head, body = (1, 3) if (i * 5) % 7 else (3, 1)
    tall = _cr.random() < 0.35
    hx = x + (1 if _cr.random() < 0.5 else 0)
    # sitting (tall ones sit a row higher)
    top = 0 if tall else 1
    CROWD_A[top][hx] = head
    for y in range(top + 1, 4):
        CROWD_A[y][x] = body
        CROWD_A[y][x + 1] = body
    # jumping: up in the air, arms raised
    CROWD_B[0][x - 1] = head
    CROWD_B[0][hx] = head
    CROWD_B[0][x + 2] = head
    CROWD_B[1][x] = body
    CROWD_B[1][x + 1] = body
    CROWD_B[2][x] = body
    CROWD_B[2][x + 1] = body


def crowd_bytes(F):
    out = []
    for y in range(4):
        for bx in range(27):
            v = 0
            for k in range(4):
                v = (v << 2) | F[y][bx * 4 + k]
            out.append(v)
    return out


def court_pic(style):
    """logical: 0 court, 1 line, 2 surround, 3 accent (net mesh / crowd)"""
    P = [[2] * 128 for _ in range(64)]
    # panel
    for y in range(64):
        for x in range(20):
            P[y][x] = 0
        P[y][19] = 1
    # court surface
    for y in range(64):
        for x in range(20, 128):
            P[y][x] = 2
    for Y in range(YFAR, YNEAR + 1):
        y = round(sy_of(Y))
        a = round(sx_of(XL, Y)); b = round(sx_of(XR, Y))
        for x in range(a, b + 1):
            P[y][x] = 0

    def hline(Y, X0, X1):
        y = round(sy_of(Y))
        for x in range(round(sx_of(X0, Y)), round(sx_of(X1, Y)) + 1):
            P[y][x] = 1

    def vline(X, Y0, Y1):
        for Y in range(Y0, Y1 + 1):
            P[round(sy_of(Y))][round(sx_of(X, Y))] = 1
    if style == 'classic':
        # the 1984 look: stepped side lines, full-length centre line, no service boxes
        y0 = round(sy_of(YFAR)); y1 = round(sy_of(YNEAR)); yn = round(sy_of(YNET))
        steps = [(y0, 44, 106), (y0 + 8, 42, 108), (yn + 1, 40, 110), (yn + 13, 38, 112)]
        for y in range(y0, y1 + 1):
            a, b = 44, 106
            for (ys, aa, bb) in steps:
                if y >= ys:
                    a, b = aa, bb
            for x in range(a, b + 1):
                P[y][x] = 0
            P[y][a] = 1; P[y][b] = 1
            P[y][CX] = 1
        for x in range(44, 107):
            P[y0][x] = 1
        for x in range(38, 113):
            P[y1][x] = 1
    else:
        hline(YFAR, XL, XR); hline(YNEAR, XL, XR)
        hline(YSF, XL, XR); hline(YSN, XL, XR)
        vline(XL, YFAR, YNEAR); vline(XR, YFAR, YNEAR)
        vline(XC, YSF, YSN)
        # centre marks on the baselines
        P[round(sy_of(YFAR)) + 1][CX] = 1
        P[round(sy_of(YNEAR)) - 1][CX] = 1
    # net: posts beyond the side lines, band 3 rows tall above the net line
    yn = round(sy_of(YNET))
    a = round(sx_of(XL - 14, YNET)); b = round(sx_of(XR + 14, YNET))
    for x in range(a, b + 1):
        P[yn - 3][x] = 1
        P[yn - 2][x] = 3 if x % 2 else 0
        P[yn - 1][x] = 3 if x % 2 == 0 else 0
        P[yn][x] = 1
    for y in range(yn - 4, yn + 1):
        P[y][a] = 1; P[y][b] = 1
    # crowd strip along the top (frame A: sitting) + advertising board
    for y in range(4):
        for x in range(20, 128):
            P[y][x] = CROWD_A[y][x - 20]
    for x in range(20, 128):
        P[4][x] = 1
    return P


COURTS = [("std", court_pic('std')), ("classic", court_pic('classic'))]
for n, P in COURTS:
    data = packbits(bitmap_to_bytes(P))
    L.append("court_%s: ; %d bytes" % (n, len(data)))
    db(data)
    save_preview([[{0: 0, 1: 1, 2: 0, 3: 2}[c] for c in r] for r in P], "court_%s_grass.png" % n)
    save_preview([[{0: 3, 1: 0, 2: 3, 3: 2}[c] for c in r] for r in P], "court_%s_clay.png" % n, CSS1)

L.append("crowd_a: ; 27 bytes x 4 rows, logical colours")
db(crowd_bytes(CROWD_A))
L.append("crowd_b:")
db(crowd_bytes(CROWD_B))
save_preview([[{0: 0, 1: 1, 2: 0, 3: 3}[c] for c in r] for r in CROWD_A + [[1] * 108] + CROWD_B], "crowd.png", sx=8, sy=12)

# projection tables (page aligned): screen row and x-scale for each world Y
L.append("    align 256")
L.append("ysy:")
db([max(0, min(63, round(sy_of(Y)))) for Y in range(256)])
L.append("yscale:")      # px per world unit * 256 (signed multiply by X-128)
db([max(1, min(255, round(hw_of(Y) / 96.0 * 256))) for Y in range(256)])
L.append("rowaddr:")      # VRAM row address for pixel rows 0..63
L.append("    dw " + ",".join("$%04X" % (0x7000 + y * 32) for y in range(64)))

# ---------------------------------------------------------------- pictures + music
exec(open(os.path.join(HERE, "pics.py")).read())
exec(open(os.path.join(HERE, "music.py")).read())

open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT, "sprites:", len(SPRS))
