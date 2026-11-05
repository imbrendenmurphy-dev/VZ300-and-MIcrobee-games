#!/usr/bin/env python3
# Circus 2 asset generator -> build/gfx.inc (sjasmplus source)
# Sprites are designed in LOGICAL colours against a colour-0 background:
#   '.' transparent, 'g'=0 (background colour), 'y'=1, 'b'=2, 'r'=3
# At run time every act picks a physical background colour and the engine
# XOR-recolours sprite data so the palette rotates while staying distinct.
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import title as titlemod

OUT = sys.argv[1] if len(sys.argv) > 1 else '../build/gfx.inc'
L = []
def emit(s): L.append(s)
def db(bs, per=16):
    for i in range(0, len(bs), per):
        emit('    db ' + ','.join('$%02X' % b for b in bs[i:i + per]))

# ---------------------------------------------------------------- font 3x5
F = {
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
'+': ["...", ".#.", "###", ".#.", "..."], '-': ["...", "...", "###", "...", "..."],
'.': ["...", "...", "...", "...", ".#."], ':': ["...", ".#.", "...", ".#.", "..."],
"'": [".#.", ".#.", "...", "...", "..."], '/': ["..#", "..#", ".#.", "#..", "#.."],
'%': ["#.#", "..#", ".#.", "#..", "#.#"], '*': ["#.#", ".#.", "#.#", "...", "..."],
'=': ["...", "###", "...", "###", "..."], '(': [".#.", "#..", "#..", "#..", ".#."],
')': [".#.", "..#", "..#", "..#", ".#."], ',': ["...", "...", "...", ".#.", "#.."],
# specials (lower case letters used as glyph codes)
'h': ["#.#", "###", "###", ".#.", "..."],   # heart
'c': [".#.", "###", "#.#", "###", ".#."],   # clown head-ish / life icon
'x': ["...", "#.#", ".#.", "#.#", "..."],   # small times sign
'l': ["..#", ".##", "###", ".##", "..#"],   # left arrow
'r': ["#..", "##.", "###", "##.", "#.."],   # right arrow
's': [".#.", "###", ".#.", "#.#", "..."],   # star
'n': [".##", ".#.", ".#.", "##.", "##."],   # musical note
'u': [".#.", "###", ".#.", ".#.", "..."],   # up arrow
'd': [".#.", ".#.", ".#.", "###", ".#."],   # down arrow
'b': ["###", "###", "###", "###", "###"],   # solid block
}
FONTCH = ''.join(chr(c) for c in range(32, 127))
emit('; ---- 3x5 font, 5 bytes per glyph, ASCII 32..126, pixel value 3')
emit('font:')
for ch in FONTCH:
    g = F.get(ch)
    if g is None:
        g = F.get(ch.upper()) if ch.islower() and ch not in F else F[' ']
    bs = []
    for row in g:
        b = 0
        for i, p in enumerate(row):
            if p == '#': b |= 3 << (6 - 2 * i)
        bs.append(b)
    db(bs, 5)

# ---------------------------------------------------------------- sprites
CMAP = {'.': None, 'g': 0, 'y': 1, 'b': 2, 'r': 3}
SPR = {}
def S(name, rows): SPR[name] = rows

S('CL_UP', ["y.....y",
            ".y.b.y.",
            "..yyy..",
            "..yry..",
            "..rrr..",
            "..ryr..",
            "..r.r..",
            ".y...y.",
            "yy...yy"])
S('CL_FALL1', ["...b...",
               "..yyy..",
               "y.yry.y",
               ".yrrry.",
               "..ryr..",
               "..r.r..",
               ".y...y.",
               "yy...yy",
               "......."])
S('CL_FALL2', ["...b...",
               "..yyy..",
               "..yry..",
               "yyrrryy",
               "..ryr..",
               "..r.r..",
               "..y.y..",
               ".yy.yy.",
               "......."])
S('CL_FLIP', list(reversed(SPR['CL_FALL1'][:8])))
S('CL_SIT', ["...b...",
             "..yyy..",
             "..yry..",
             ".yrrry.",
             "y.ryr.y",
             ".rr.rr.",
             "yy...yy"])
S('CL_SIT2', ["..bbb..",
              "..yyy..",
              "y.yry.y",
              ".yrrry.",
              "..ryr..",
              ".rr.rr.",
              "yy...yy"])

S('CL_WAVE', ["...b..y",
              "..yyyy.",
              "..yry..",
              ".yrrr..",
              "y.ryr..",
              "..r.r..",
              "..r.r..",
              ".yy.yy."])
S('CL_SPLAT', [".y..b..y.",
               "yyrrrrryy",
               ".yyryryy."])
S('CL_DIZZY', ["y.s.y", ".y.y."])  # unused placeholder (replaced below)
del SPR['CL_DIZZY']
S('UMBRELLA', ["...rrr...",
               ".rryyyrr.",
               "rryyryyrr",
               "....b....",
               "....b...."])
S('MONKEY1', ["b......b",
              ".b.rr.b.",
              "..ryyr..",
              "..ybby..",
              "..yryy..",
              "...rr...",
              "..r..r..",
              ".r....r."])
S('MONKEY2', [".b....b.",
              "..brrb..",
              "..ryyr..",
              "..ybby..",
              "..yyry..",
              "...rr...",
              "...rr...",
              "..r..r.."])

S('PIE', [".yy.",
          "yyyy",
          "rrrr"])
S('PIE_SPLAT', ["y.yy.y",
                "yyyyyy"])
S('HOOP1', ["..r..y...r..y...",
            ".ryr.yr.ryr.yr..",
            ".rrrrrrrrrrrrrr.",
            "r..............r",
            "r..............r",
            ".rrrrrrrrrrrrrr."])
S('HOOP2', ["...y..r...y..r..",
            "..ryryr..ryryr..",
            ".rrrrrrrrrrrrrr.",
            "r..............r",
            "r..............r",
            ".rrrrrrrrrrrrrr."])
S('BAL_Y', [".yy.", "yyyy", "yyyy", ".yy.", "..b."])
S('BAL_B', [".bb.", "bbbb", "bbbb", ".bb.", "..y."])
S('BAL_R', [".rr.", "rrrr", "rrrr", ".rr.", "..y."])
S('BAL_GIFT1', [".ry.", "ryyr", "yrry", ".yr.", "..b."])
S('BAL_GIFT2', [".yr.", "yrry", "ryyr", ".ry.", "..b."])
S('BAL_BOMB1', ["..y.", ".bb.", "bbbb", "bybb", ".bb."])
S('BAL_BOMB2', ["..r.", ".bb.", "bbbb", "bybb", ".bb."])
S('BAL_STEEL', [".bb.", "bybb", "bbbb", ".bb.", "..y."])
S('BAL_GOLD', [".rr.", "ryyr", "ryyr", ".rr.", "..r."])
S('BAL_ERASE', [".gg.", "gggg", "gggg", ".gg.", "..g."])

S('STAR', ["..y..", ".yry.", "..y.."])

# peeking clown (title / how-to), 11x11
S('BIGCLOWN1', ["...bbbbb...",
                "..bbbbbbb..",
                ".bb.....bb.",
                "bb.yyyyy.bb",
                "..yybyby...",
                "..yyyyyyy..",
                "..yyyrryy..",
                "...yrrry...",
                "..r.yyy.r..",
                ".rrr...rrr.",
                "..r.....r.."])
S('BIGCLOWN2', ["...bbbbb...",
                "..bbbbbbb..",
                ".bb.....bb.",
                "bb.yyyyy.bb",
                "..yyyyyy...",
                "..yybyby...",
                "..yyyrryy..",
                "...yryry...",
                "..r.yyy.r..",
                ".rrr...rrr.",
                "..r.....r.."])

# power-up tokens 7x7: frame in r with letter in y (and b variant for flashing)
TOKENS = [('W', 'TOK_WIDE'), ('S', 'TOK_SLOW'), ('N', 'TOK_NET'), ('2', 'TOK_X2'),
          ('U', 'TOK_UMB'), ('F', 'TOK_FIRE'), ('1', 'TOK_1UP')]
for ch, nm in TOKENS:
    for v, fc in ((1, 'r'),):
        rows = ['.' + fc * 5 + '.']
        for r in F[ch]:
            rows.append(fc + 'g' + ''.join('y' if p == '#' else 'g' for p in r) + 'g' + fc)
        rows.append('.' + fc * 5 + '.')
        S(nm + str(v), rows)

# seesaw sprites, generated.  Plank from end to end, pivot at centre bottom.
def seesaw(halfw, tilt):
    w = halfw * 2 + 1
    h = 9
    rows = [['.'] * w for _ in range(h)]
    # pivot triangle (b) rows 6..8
    cx = halfw
    for i, y in enumerate((6, 7, 8)):
        for x in range(cx - i - 1, cx + i + 2):
            if 0 <= x < w: rows[y][x] = 'b'
    rows[5][cx] = 'b'
    # plank: tilt -1 = left end low, +1 = right end low, 0 = flat
    for x in range(w):
        t = (x - cx) / halfw
        if tilt == 0: yy = 4
        elif tilt < 0: yy = 4 - t * 3.4
        else: yy = 4 + t * 3.4
        yy = int(round(yy))
        rows[yy][x] = 'y'
        if yy + 1 < h and rows[yy + 1][x] == '.': rows[yy + 1][x] = 'r'
    # seat handles at ends
    return [''.join(r) for r in rows]
for nm, hw in (('SEE', 10), ('SEEW', 15)):
    S(nm + '_L', seesaw(hw, -1))
    S(nm + '_R', seesaw(hw, 1))

# ---------------------------------------------------------------- emit pre-shifted
ONESHIFT = {'BIGCLOWN1': 3, 'BIGCLOWN2': 3}
emit('; ---- sprite headers: db nbytes,height / dw shift0..3 data pointers')
order = list(SPR.keys())
for nm in order:
    rows = SPR[nm]
    w = max(len(r) for r in rows); h = len(rows)
    nb = (w + 6) // 4
    emit(f'{nm}: db {nb},{h}')
    if nm in ONESHIFT:
        emit('    dw ' + ','.join(f'{nm}_s{ONESHIFT[nm]}' for k in range(4)))
    else:
        emit('    dw ' + ','.join(f'{nm}_s{k}' for k in range(4)))
emit('; ---- sprite data region (mask,data) pairs; recoloured as one block')
emit('sprdata_start:')
for nm in order:
    rows = SPR[nm]
    w = max(len(r) for r in rows); h = len(rows)
    nb = (w + 6) // 4
    for k in (range(4) if nm not in ONESHIFT else [ONESHIFT[nm]]):
        out = []
        for r in rows:
            r = r.ljust(w, '.')
            pix = [None] * k + [CMAP[c] for c in r] + [None] * (nb * 4 - k - w)
            for bi in range(nb):
                m = 0; d = 0
                for j in range(4):
                    p = pix[bi * 4 + j]
                    sh = 6 - 2 * j
                    if p is None: m |= 3 << sh
                    else: d |= p << sh
                out += [m, d]
        emit(f'{nm}_s{k}:')
        db(out)
emit('sprdata_end:')

# ---------------------------------------------------------------- RLE screens
def rle2(data):
    # format: n<$80: copy n+1 literals ; $80<=n<$FF: repeat next byte n-$7D times (3..129); $FF end
    out = []; i = 0; n = len(data); lit = []
    def flush():
        while lit:
            chunk = lit[:128]; del lit[:128]
            out.append(len(chunk) - 1); out.extend(chunk)
    while i < n:
        j = i
        while j < n and data[j] == data[i] and j - i < 129: j += 1
        run = j - i
        if run >= 3:
            flush(); out.append(0x7D + run); out.append(data[i]); i = j
        else:
            lit.append(data[i]); i += 1
    flush(); out.append(0xFF)
    return out

def lz(data):
    # n<$80: n+1 literals ; $80..$FE: copy n-$7D (3..129) bytes from offset (1 byte) back ; $FF end
    out = []; i = 0; lit = []
    def fl():
        while lit:
            c = lit[:128]; del lit[:128]; out.append(len(c) - 1); out.extend(c)
    while i < len(data):
        best = (0, 0)
        for off in range(1, min(i, 255) + 1):
            l = 0
            while i + l < len(data) and l < 129 and data[i + l - off] == data[i + l]: l += 1
            if l > best[0]: best = (l, off)
        if best[0] >= 3:
            fl(); out.append(0x7D + best[0]); out.append(best[1]); i += best[0]
        else:
            lit.append(data[i]); i += 1
    fl(); out.append(0xFF)
    return out

def pack(img):
    b = []
    for y in range(64):
        for xb in range(32):
            v = 0
            for k in range(4): v = (v << 2) | img[y][xb * 4 + k]
            b.append(v)
    return b

timg, xs, x2 = titlemod.make()
tb = pack(timg)
emit('; ---- title screen (physical CSS0), RLE')
emit('title_lz:')
tr = lz(tb); db(tr)
emit(f'; title raw 2048 -> {len(tr)} bytes')

# game background template (logical colours)
def bgtemplate():
    img = [[0] * 128 for _ in range(64)]
    def px(x, y, c):
        if 0 <= x < 128 and 0 <= y < 64: img[y][x] = c
    # candy-stripe poles (4px) from top to tower tops
    for y in range(0, 30):
        c = 3 if (y // 2) % 2 == 0 else 1
        for x in list(range(0, 4)) + list(range(124, 128)): px(x, y, c)
    # towers: ladders 6 wide
    for side in (0, 122):
        for y in range(30, 57):
            px(side, y, 2); px(side + 5, y, 2)
            if y % 3 == 0:
                for x in range(side + 1, side + 5): px(x, y, 1)
        for x in range(side, side + 6): px(x, 30, 3); px(x, 31, 3)
    # bunting garland (rows 26..31): sagging rope with alternating pennants
    import math as _m
    for x in range(4, 124):
        seg = (x - 4) % 30
        sag = int(round(2.2 * _m.sin(_m.pi * seg / 30)))
        px(x, 26 + sag, 2)
        if (x - 4) % 6 < 3 and 2 <= seg <= 27:
            k = (x - 4) % 6
            col = 1 if ((x - 4) // 6) % 2 == 0 else 3
            for d in range(3 - (1 if k != 1 else 0)):
                px(x, 27 + sag + d, col)
    # floor band
    for y in range(57, 64):
        for x in range(128): px(x, y, 3)
    for x in range(128): px(x, 57, 1 if (x // 2) % 2 == 0 else 3)
    return img
bb = pack(bgtemplate())
emit('bgtemplate_lz:')
br = lz(bb); db(br)

# ---------------------------------------------------------------- tables
emit('; ---- pixel masks / colour patterns')
emit('pixmask: db $C0,$30,$0C,$03')
emit('colpat_log: db $00,$55,$AA,$FF')
# byte doubler for big text: each 2bpp pixel duplicated => 2 bytes
emit('dbl16:')
db([((n >> 2) * 0x50) | ((n & 3) * 0x05) for n in range(16)])
# sine table 64 entries amplitude 127 signed
emit('sintab:')
db([(int(round(127 * math.sin(2 * math.pi * i / 64)))) & 0xFF for i in range(64)])

# title animation: marquee light positions = scallop centres along valance
lights = []
for k in range(12):
    x = 10 + k * 9 + 4
    if x <= 118: lights.append((x, 37))
emit('title_lights:')
for (x, y) in lights: emit(f'    db {x},{y}')
emit('    db $FF')
# star positions (sky pixels that are yellow in title)
stars = [(x, y) for y in range(0, 40) for x in range(128) if timg[y][x] == 1 and all(
    timg[yy][xx] == 2 for xx, yy in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)) if 0 <= xx < 128 and 0 <= yy < 64)]
emit('title_stars:')
for (x, y) in stars[:32]: emit(f'    db {x},{y}')
emit('    db $FF')

open(OUT, 'w').write('\n'.join(L) + '\n')
print('sprites:', len(SPR), 'title rle', len(tr), 'bg rle', len(br), 'stars', len(stars))
