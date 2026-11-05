#!/usr/bin/env python3
"""STAR BLASTER II data generator -> data.inc
font, scaled + pre-shifted sprite library (packed), z->size tables,
title logo, music (music.py). Writes previews to ../build/preview/."""
import os
from PIL import Image
import art

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


def save_img(pix, name, css=0, scale=(4, 6)):
    pal = CSS0 if css == 0 else CSS1
    w = len(pix[0]); h = len(pix)
    im = Image.new("RGB", (w, h))
    for y in range(h):
        for x in range(w):
            v = pix[y][x]
            im.putpixel((x, y), pal[2] if v is None else pal[v])
    im.resize((w * scale[0], h * scale[1]), Image.NEAREST).save(os.path.join(PREV, name))


# ---------------------------------------------------------------- 3x5 font
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
    '%': ["#.#", "..#", ".#.", "#..", "#.#"], ';': ["...", ".#.", "...", ".#.", "#.."],
    '_': ["...", "...", "...", "...", "###"],
}
FONT['^'] = [".#.", ".#.", "###", "###", "#.#"]   # ship icon
FONT['@'] = [".#.", "###", "###", "###", ".#."]   # nova icon
FONT['['] = ["###", "#.#", "#.#", "#.#", "###"]
L.append("; ---- 3x5 font, ASCII 32..95, 5 bytes/glyph, bit2 = left pixel")
L.append("font3:")
for c in range(32, 96):
    g = FONT.get(chr(c), FONT[' '])
    db([int(r.replace('#', '1').replace('.', '0'), 2) for r in g])

# ---------------------------------------------------------------- sprites
CM = {'.': None, 'g': 0, 'y': 1, 'b': 2, 'r': 3}


def grid(s):
    rows = [r for r in s.strip('\n').split('\n')]
    W = max(len(r) for r in rows)
    return [[CM[c] for c in r.ljust(W, '.')] for r in rows]


def scale(src, w):
    H = len(src); W = len(src[0])
    h = max(1, int(round(H * w / W)))
    out = []
    for y in range(h):
        y0 = y * H / h; y1 = (y + 1) * H / h
        row = []
        for x in range(w):
            x0 = x * W / w; x1 = (x + 1) * W / w
            cnt = {}; tot = 0; opq = 0
            yy = int(y0)
            while yy < y1 and yy < H:
                xx = int(x0)
                while xx < x1 and xx < W:
                    tot += 1
                    v = src[yy][xx]
                    if v is not None:
                        opq += 1
                        cnt[v] = cnt.get(v, 0) + 1 + (0.6 if v in (1, 3) else 0)
                    xx += 1
                yy += 1
            if tot and opq / tot >= 0.34:
                row.append(max(cnt, key=cnt.get))
            else:
                row.append(None)
        out.append(row)
    return out


def shifted(img, sh):
    """-> (b, rows of (mask,data) pairs) with the image shifted right by sh pixels"""
    h = len(img); w = len(img[0]); b = (w + 3 + 3) // 4
    rows = []
    for y in range(h):
        px = [None] * (b * 4)
        for x in range(w):
            px[x + sh] = img[y][x]
        r = []
        for bx in range(b):
            m = 0; d = 0
            for k in range(4):
                v = px[bx * 4 + k]
                m <<= 2; d <<= 2
                if v is None:
                    m |= 3
                else:
                    d |= v
            r += [m, d]
        rows.append(r)
    return b, rows


SIZES = [3, 5, 7, 9, 12, 16, 21, 28]
# name, art, px wide at z=8 (true size), allowed sizes
TYPES = [
    ("FHT", art.FHT, 14, None),
    ("ACE", art.ACE, 16, None),
    ("TNK", art.TNK, 28, None),
    ("FRT", art.FRT, 30, None),
    ("TRP", art.TRP, 26, None),
    ("ROCK", art.ROCK, 20, None),
    ("MINE", art.MINE, 10, None),
    ("POD", art.POD, 9, None),
    ("PLANET", art.PLANET, 40, [40]),
    ("BOSS", art.BOSS, 64, [16, 32, 64]),
]
entries = []          # (typeidx, sizeidx, bytes)
ztab = {}
sizeinfo = {}
sheet = []
for ti, (name, a, true_w, allowed) in enumerate(TYPES):
    src = grid(a)
    W = len(src[0])
    sz = allowed if allowed else [s for s in SIZES if s <= W]
    sizeinfo[name] = []
    for si, w in enumerate(sz):
        img = scale(src, w) if w != W else src
        if w == W:
            img = src
        h = len(img)
        blob = []
        b = None
        for sh in range(4):
            b, rows = shifted(img, sh)
            for r in rows:
                blob += r
        realw = len(img[0])
        hdr = [b, h, realw // 2, h // 2]
        entries.append((name, si, hdr + blob))
        sizeinfo[name].append((realw, h))
        if si == len(sz) - 1 or w in (9, 16):
            sheet.append(img)
    # z -> size index: desired = true_w*8/z ; pick largest size <= desired*1.1
    t = []
    for z in range(64):
        zz = max(z, 1) + 0.5
        want = true_w * 8.0 / zz
        if allowed and len(allowed) == 1:
            t.append(0); continue
        if want < 1.5:
            t.append(0xFF if want >= 0.6 else 0xFE)   # FF = dot, FE = invisible
            continue
        k = 0
        for si, w in enumerate(sz):
            if w <= want * 1.1:
                k = si
        t.append(k)
    ztab[name] = t

# preview sheet
maxh = max(len(i) for i in sheet)
totw = sum(len(i[0]) + 2 for i in sheet)
pix = [[None] * totw for _ in range(maxh)]
x = 0
for i in sheet:
    for yy in range(len(i)):
        for xx in range(len(i[0])):
            pix[yy][x + xx] = i[yy][xx]
    x += len(i[0]) + 2
save_img(pix, "sprites.png")

# place entries: bank 3 window first ($4000-$67FF), then high RAM (LIBHI..)
BANK_LO, BANK_HI = 0x4000, 0x6800
LIBHI, LIBHI_END = 0xD700, 0xE900
blob3 = []; blobh = []
ptr = {}
for (name, si, data) in entries:
    if BANK_LO + len(blob3) + len(data) <= BANK_HI:
        ptr[(name, si)] = BANK_LO + len(blob3); blob3 += data
    else:
        ptr[(name, si)] = LIBHI + len(blobh); blobh += data
assert LIBHI + len(blobh) <= LIBHI_END, "sprite library too big: %d" % (LIBHI + len(blobh) - LIBHI_END)
print("sprite library: bank3 %d bytes, high %d bytes (to $%04X)" % (len(blob3), len(blobh), LIBHI + len(blobh)))
L.append("; ---- sprite library")
L.append("LIBHI equ $%04X" % LIBHI)
L.append("LIBHI_END equ $%04X" % (LIBHI + len(blobh)))
for ti, (name, a, tw, allowed) in enumerate(TYPES):
    L.append("SPR_%s equ %d" % (name, ti))
    L.append("NSIZE_%s equ %d" % (name, len(sizeinfo[name])))
L.append("sprtab:   ; per type: pointer to size pointer list")
L.append("    dw " + ",".join("spr_%s" % n for (n, a, t, al) in TYPES))
for (name, a, tw, allowed) in TYPES:
    L.append("spr_%s:" % name)
    L.append("    dw " + ",".join("$%04X" % ptr[(name, si)] for si in range(len(sizeinfo[name]))))
L.append("ztabtab:")
L.append("    dw " + ",".join("ztab_%s" % n for (n, a, t, al) in TYPES))
for (name, a, tw, allowed) in TYPES:
    L.append("ztab_%s:" % name)
    db(ztab[name])
# boot-time library source: shift-0 images only; the other 3 shifts are
# generated by build_library at start-up. Entry: dw dest : db b,h,xo,yo : pairs
L.append("libsrc:")
raw = 0
for (name, si, data) in entries:
    b, h = data[0], data[1]
    n = 2 * b * h
    L.append("    dw $%04X" % ptr[(name, si)])
    db(data[:4] + data[4:4 + n])
    raw += 6 + n
L.append("    dw 0")
print("library source in .VZ: %d bytes" % raw)

# ---------------------------------------------------------------- logo letters
LET = {
    'S': [".####", "##...", ".###.", "...##", "####."],
    'T': ["#####", "..#..", "..#..", "..#..", "..#.."],
    'A': [".###.", "##.##", "#####", "##.##", "##.##"],
    'R': ["####.", "##.##", "####.", "##.#.", "##.##"],
    'B': ["####.", "##.##", "####.", "##.##", "####."],
    'L': ["##...", "##...", "##...", "##...", "#####"],
    'E': ["#####", "##...", "####.", "##...", "#####"],
    'I': ["##", "##", "##", "##", "##"],
}


def big_letter(ch):
    m = LET[ch]
    w = len(m[0]) * 2
    rows = []
    for yy, r in enumerate(m):
        for k in range(2):
            line = []
            for c in r:
                line += [c == '#'] * 2
            rows.append(line)
    h = len(rows)                     # 10
    col = []
    for y in range(h):
        c = 1 if y < 4 else (0 if y < 5 else 3)
        col.append(c)
    img = [[col[y] if rows[y][x] else None for x in range(w)] for y in range(h)]
    # drop shadow (red) one pixel right/down where empty
    out = [[None] * (w + 1) for _ in range(h + 1)]
    for y in range(h):
        for x in range(w):
            if img[y][x] is not None:
                if out[y + 1][x + 1] is None:
                    out[y + 1][x + 1] = 3
    for y in range(h):
        for x in range(w):
            if img[y][x] is not None:
                out[y][x] = img[y][x]
    return out


# letters stored byte aligned (x multiple of 4), unshifted, as (mask,data) pairs
L.append("; ---- logo letters: b, h, then (mask,data) pairs")
logo_letters = {}
for ch in "STARBLEI":
    img = big_letter(ch)
    b, rows = shifted(img, 0)
    logo_letters[ch] = (b, len(rows))
    L.append("let_%s:" % ch)
    data = [b, len(rows)]
    for r in rows:
        data += r
    db(data)
# letter layout: (char, final byte col, final row)
LAYOUT = [('S', 7, 2), ('T', 10, 2), ('A', 13, 2), ('R', 16, 2), ('I', 21, 2), ('I', 23, 2)]
for i, ch in enumerate("BLASTER"):
    LAYOUT.append((ch, 5 + 3 * i, 15))
L.append("logo_layout:   ; ptr, col, row")
for (ch, c, r) in LAYOUT:
    L.append("    dw let_%s : db %d,%d" % (ch, c, r))
L.append("    dw 0")

# ---------------------------------------------------------------- sine
import math
L.append("sintab:   ; 256 entries, signed, amplitude 127")
db([int(round(127 * math.sin(i * 2 * math.pi / 256))) & 255 for i in range(256)])

# ---------------------------------------------------------------- music
exec(open(os.path.join(HERE, "music.py")).read())

open(OUT, "w").write("\n".join(L) + "\n")
print("wrote", OUT)
