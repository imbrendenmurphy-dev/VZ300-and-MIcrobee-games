#!/usr/bin/env python3
"""HAMBURGER SAM II data generator -> data.inc
font, sprites (8 px wide, explicit masks, shifted at run time), ingredient art,
kitchen layouts (validated: every ingredient and spawn point reachable),
title picture (pics.py) and music (music.py).
Also writes preview PNGs into ../build/preview/ ."""
import os
from collections import deque
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


exec(open(os.path.join(HERE, "font.py")).read())
FONT['['] = ["###", "###", ".#.", "#.#", "#.#"]   # chef (lives)
FONT[']'] = [".#.", "###", "#.#", "#.#", "###"]   # pepper pot
FONT['@'] = [".#.", "###", "...", "###", ".#."]   # burger
FONT['^'] = [".#.", "###", "###", "...", "..."]   # up arrow (cursor)
L.append("; ---- 3x5 font, ASCII 32..95, 5 bytes/glyph, bit2 = left pixel")
L.append("font3:")
for c in range(32, 96):
    g = FONT.get(chr(c), FONT[' '])
    db([int(r.replace('#', '1').replace('.', '0'), 2) for r in g])

# ---------------------------------------------------------------- sprites
exec(open(os.path.join(HERE, "art.py")).read())
CMAP = {'.': None, 'g': 0, 'Y': 1, 'B': 2, 'R': 3}
SPRS = []


def rows_of(art, h=8):
    rows = art.split("\n")[1:]
    rows = [r for r in rows][:h]
    while len(rows) < h:
        rows.append("")
    return [[CMAP[ch] for ch in r.ljust(8, '.')[:8]] for r in rows]


def spr(name, art, mirror=False):
    r = rows_of(art)
    SPRS.append((name, r))
    if mirror:
        SPRS.append((name + "_L", [row[::-1] for row in r]))


for n, a in (("SAM_A", SAM_A), ("SAM_B", SAM_B), ("SAM_THROW", SAM_THROW)):
    spr(n, a, True)
for n, a in (("SAM_CLIMB_A", SAM_CLIMB_A), ("SAM_CLIMB_B", SAM_CLIMB_B), ("SAM_FRONT", SAM_FRONT),
             ("SAM_CHEER", SAM_CHEER), ("SAM_DIZZY", SAM_DIZZY), ("SAM_PLATE", SAM_PLATE)):
    spr(n, a)
spr("SAM_UPSIDE", "\n" + "\n".join(SAM_FRONT.strip("\n").split("\n")[::-1]) + "\n")
ENEMIES = [("HOTDOG", HOTDOG_A, HOTDOG_B), ("EGG", EGG_A, EGG_B), ("PICKLE", PICKLE_A, PICKLE_B),
           ("CHILLI", CHILLI_A, CHILLI_B)]
# per enemy: A, A_L, B, B_L, STUN, SQUASH  (6 consecutive ids)
for n, a, b in ENEMIES:
    spr(n + "_A", a, True)
    spr(n + "_B", b, True)
    spr(n + "_STUN", STUN[n])
    spr(n + "_SQUASH", SQUASH[n])
for n, a in (("PEPPER_A", PEPPER_A), ("PEPPER_B", PEPPER_B), ("COFFEE", COFFEE), ("FRIES", FRIES),
             ("ICECREAM", ICECREAM), ("SPATULA", SPATULA), ("SPARK_A", SPARK_A), ("SPARK_B", SPARK_B),
             ("ARROW", ARROW)):
    spr(n, a)

ONESHIFT = {"SAM_DIZZY", "SAM_UPSIDE", "SAM_CHEER", "SAM_PLATE", "COFFEE", "FRIES", "ICECREAM", "SPATULA", "SPARK_A", "SPARK_B", "ARROW", "PEPPER_A", "PEPPER_B"}
L.append("NSPR equ %d" % len(SPRS))
for i, (n, _) in enumerate(SPRS):
    L.append("SPR_%s equ %d" % (n, i))
# sprite sources go in their own file, included LAST: at start-up they are copied to
# STATBG and the shifted sprites are built over the space they loaded into.
S = ["; ---- sprite sources (relocated to STATBG at start-up): per row d0,d1,m0,m1",
     "spr_src_start:", "sprsrc:"]
for n, rows in SPRS:
    S.append("    dw ss_%s-spr_src_start+STATBG : db %d,%d" % (n, len(rows), 1 if n in ONESHIFT else 0))
for n, rows in SPRS:
    S.append("ss_%s:" % n)
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
    for i in range(0, len(bs), 16):
        S.append("    db " + ",".join("$%02X" % v for v in bs[i:i + 16]))
S.append("spr_src_end:")
open(os.path.join(HERE, "sprdata.inc"), "w").write("\n".join(S) + "\n")
L.append("SHIFTSIZE equ %d" % (sum(len(r) * (6 if n in ONESHIFT else 24) for n, r in SPRS)))
sheet = [[0] * 160 for _ in range(60)]
for i, (n, rows) in enumerate(SPRS):
    ox = (i % 16) * 10; oy = (i // 16) * 10
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c is not None and oy + y < 60:
                sheet[oy + y][ox + x] = c
save_preview(sheet, "sprites.png")

# ---------------------------------------------------------------- ingredients
L.append("; ---- ingredients: 16x2 px; per type: row0 d0-d3, row1 d0-d3, row0 m0-m3, row1 m0-m3")
L.append("piecegfx:")
PTYPE = {}
for i, t in enumerate(PIECE_ORDER):
    PTYPE[t] = i
    nm, rows = PIECES[t]
    ds = []; ms = []
    for r in rows:
        for bx in range(4):
            d = m = 0
            for k in range(4):
                ch = r[bx * 4 + k]
                d <<= 2; m <<= 2
                if ch == '.':
                    m |= 3
                else:
                    d |= CMAP[ch]
            ds.append(d); ms.append(m)
    db(ds + ms)
L.append("piecenames: dw " + ",".join("pn_%s" % t for t in PIECE_ORDER))
for t in PIECE_ORDER:
    L.append('pn_%s: db "%s",0' % (t, PIECES[t][0]))

# ---------------------------------------------------------------- kitchens
exec(open(os.path.join(HERE, "levels.py")).read())
FY = [14, 23, 32, 41, 50]
L.append("NFLOOR equ 5")
L.append("fy_tab: db " + ",".join(map(str, FY)))
ROSTER = {'H': 0, 'E': 1, 'P': 2, 'C': 3}
COLB = [0x00, 0x55, 0xAA, 0xFF]


def check_kitchen(k, idx):
    name = k['name']
    G = [list(s) for s in k['girders']]
    assert len(G) == 5 and all(len(g) == 32 for g in G), name
    pieces = []
    for ci, c in enumerate(k['cols']):
        col = k['pieces'][ci]
        assert len(col) == 5, name
        seq = [ch for ch in col if ch != '.']
        assert seq[0] == 'T' and seq[-1] == 'B' and len(seq) <= 5, (name, col)
        for f in range(5):
            for cc in range(c, c + 4):
                assert G[f][cc] == '=', "%s: no girder under column %d floor %d" % (name, ci, f)
            if col[f] != '.':
                pieces.append((c, f, col[f], ci))
    # cells under walkers' centres: 1..30 only (sprites stay on screen)
    walk = lambda f, c: 1 <= c <= 30 and G[f][c] == '='
    adj = {}
    for f in range(5):
        for c in range(32):
            if walk(f, c):
                adj[(f, c)] = [(f, d) for d in (c - 1, c + 1) if 0 <= d < 32 and walk(f, d)]
    for f, lst in enumerate(k['ladders']):
        for c in lst:
            assert 0 <= c <= 29, (name, c)
            cc = c + 1
            assert walk(f, cc) and walk(f + 1, cc), "%s: ladder %d floor %d not on girders" % (name, c, f)
            for (pc, pf, t, ci) in pieces:
                if pf == f + 1 and not (c + 1 < pc or c > pc + 3):
                    raise AssertionError("%s: ladder %d (floor %d) runs through a piece" % (name, c, f))
            adj[(f, cc)].append((f + 1, cc)); adj[(f + 1, cc)].append((f, cc))
    sx, sf = k['sam']
    start = (sf, (sx + 4) // 4)
    assert start in adj, (name, 'sam')
    seen = {start}; q = deque([start])
    while q:
        n = q.popleft()
        for m in adj[n]:
            if m not in seen:
                seen.add(m); q.append(m)
    for (pc, pf, t, ci) in pieces:
        for cc in range(pc, pc + 4):
            assert (pf, cc) in seen, "%s: piece at col %d floor %d unreachable" % (name, ci, pf)
    for (x, f) in k['spawns'] + [k['item']]:
        assert (f, (x + 4) // 4) in seen, "%s: spawn/item %d,%d unreachable" % (name, x, f)
    return pieces


def kitchen_pic(k, pieces):
    """preview of the static kitchen + pieces (what draw_kitchen builds at run time)"""
    P = [[0] * 128 for _ in range(64)]
    for f in range(5):
        for c in range(32):
            if k['girders'][f][c] == '=':
                for x in range(c * 4, c * 4 + 4):
                    P[FY[f]][x] = k['gcol']
    for f, lst in enumerate(k['ladders']):
        for c in lst:
            X = c * 4
            for y in range(FY[f], FY[f + 1]):
                P[y][X + 1] = P[y][X + 6] = k['lcol']
                if (y - FY[f]) % 3 == 2:
                    for x in range(X + 1, X + 7):
                        P[y][x] = k['lcol']
    for c in k['cols']:
        for x in range(c * 4 - 4, c * 4 + 20):
            P[62][x] = 2
            if c * 4 - 2 <= x < c * 4 + 18:
                P[63][x] = 2
    for (pc, pf, t, ci) in pieces:
        rows = PIECES[t][1]
        for r in range(2):
            for x in range(16):
                ch = rows[r][x]
                if ch != '.':
                    P[FY[pf] - 2 + r][pc * 4 + x] = CMAP[ch]
    return P


ALLK = KITCHENS + [CLASSIC]
L.append("NKITCHEN equ %d" % len(KITCHENS))
L.append("lvtab: dw " + ",".join("lv_%d" % i for i in range(len(ALLK))))
for i, k in enumerate(ALLK):
    pieces = check_kitchen(k, i)
    P = kitchen_pic(k, pieces)
    save_preview(P, "kitchen_%d.png" % i, CSS1 if k['css'] else CSS0)
    L.append("lv_%d: ; %s" % (i, k['name']))
    L.append("    dw lvn_%d, lvl_%d, lvp_%d" % (i, i, i))
    db([0x10 if k['css'] else 0, COLB[k['gcol']], k['lcol'], k['sam'][0], k['sam'][1],
        k['item'][0], k['item'][1], k['maxen'], k['speed']])
    cols = [c * 4 for c in k['cols']]
    db([len(cols)] + (cols + [0, 0, 0, 0])[:4])
    sp = []
    for (x, f) in k['spawns']:
        sp += [x, f]
    db(sp)
    db([ROSTER[r] for r in k['roster']])
    fm = []
    for f in range(5):
        for b in range(4):
            v = 0
            for j in range(8):
                v = (v << 1) | (1 if k['girders'][f][b * 8 + j] == '=' else 0)
            fm.append(v)
    db(fm)
    L.append('lvn_%d: db "%s",0' % (i, k['name']))
    lad = []
    for f, lst in enumerate(k['ladders']):
        for c in lst:
            lad += [c * 4, f]
    L.append("lvl_%d:" % i)
    db([len(lad) // 2] + lad)
    L.append("lvp_%d:" % i)
    pc = []
    for (c, f, t, ci) in pieces:
        pc += [c * 4, f, PTYPE[t], ci]
    db([len(pieces)] + pc)
L.append("LVHSIZE equ 54")

# plate: 24 px (6 bytes) x 2 rows, colour 2
L.append("plategfx:")
db([0x0A, 0xAA, 0xAA, 0xAA, 0xAA, 0xA0, 0x00, 0xAA, 0xAA, 0xAA, 0xAA, 0x00])

# contact sheet of kitchens
ims = [Image.open(os.path.join(PREV, "kitchen_%d.png" % i)) for i in range(len(ALLK))]
w, h = ims[0].size
sh = Image.new("RGB", (3 * w + 20, 3 * h + 20), (40, 40, 40))
for i, im in enumerate(ims):
    sh.paste(im, ((i % 3) * (w + 10), (i // 3) * (h + 10)))
sh.resize((sh.width // 2, sh.height // 2)).save(os.path.join(PREV, "kitchens.png"))

# page-aligned VRAM row address table (used by dl_pixel in core.asm)
L.append("    align 256")
L.append("rowaddr:")
L.append("    dw " + ",".join("$%04X" % (0x7000 + y * 32) for y in range(64)))

# ---------------------------------------------------------------- pictures + music
exec(open(os.path.join(HERE, "pics.py")).read())
exec(open(os.path.join(HERE, "music.py")).read())

open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT, "sprites:", len(SPRS), "kitchens:", len(ALLK))
