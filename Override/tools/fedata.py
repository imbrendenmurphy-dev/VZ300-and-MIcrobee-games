"""OVERRIDE front-end data: the title picture, text pages, roster info."""
import random
import gfx, roster
from vzpal import pack_row, pix_image

# 7x10 logo letters (doubled to 14x20)
LOGO = {
    'O': [".#####.", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".#####."],
    'V': ["##...##", "##...##", "##...##", "##...##", "##...##", "##...##", ".##.##.", ".##.##.", "..###..", "...#..."],
    'E': ["#######", "##.....", "##.....", "##.....", "######.", "##.....", "##.....", "##.....", "##.....", "#######"],
    'R': ["######.", "##...##", "##...##", "##...##", "######.", "##.##..", "##..##.", "##...##", "##...##", "##...##"],
    'I': ["#######", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "..###..", "#######"],
    'D': ["######.", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "##...##", "######."],
}
G, Y, B, R = 0, 1, 2, 3


def blank(c=B):
    return [[c] * 128 for _ in range(64)]


def stars(px, rng, rows, n):
    for _ in range(n):
        x = rng.randrange(128); y = rng.randrange(*rows)
        px[y][x] = Y if rng.random() < 0.6 else G


def text(px, s, x, y, col):
    for k, ch in enumerate(s):
        g = gfx.glyph_rows(ch)
        for gy in range(5):
            for gx in range(3):
                if g[gy][gx] == '#':
                    px[y + gy][x + k * 4 + gx] = col


def logo(px, word, y0):
    mask = [[0] * 128 for _ in range(22)]
    for k, ch in enumerate(word):
        g = LOGO[ch]
        for gy in range(10):
            for gx in range(7):
                if g[gy][gx] == '#':
                    for dy in (0, 1):
                        for dx in (0, 1):
                            mask[1 + gy * 2 + dy][k * 16 + 1 + gx * 2 + dx] = 1
    # outline
    for y in range(22):
        for x in range(128):
            if mask[y][x]: continue
            if any(0 <= y + dy < 22 and 0 <= x + dx < 128 and mask[y + dy][x + dx] == 1
                   for dy in (-1, 0, 1) for dx in (-1, 0, 1)):
                mask[y][x] = 2
    band = {}
    for r in range(1, 21):
        gy = r - 1
        band[r] = Y if gy < 8 else (G if gy < 10 else R)
    # drop shadow (red, one pixel right and one row down), then the letters
    for y in range(21):
        for x in range(127):
            if mask[y][x] == 1 and mask[y + 1][x + 1] != 1:
                px[y0 + y + 1][x + 1] = R
    for y in range(22):
        for x in range(128):
            if mask[y][x] == 1:
                c = band[y]
                if c == Y and x > 0 and mask[y][x - 1] != 1: c = G     # lit left edges
                px[y0 + y][x] = c
    return px


def title_picture():
    rng = random.Random(77)
    px = blank(B)
    stars(px, rng, (0, 64), 60)
    # clear the logo box and the text lines of stars
    for y in list(range(2, 26)) + list(range(27, 33)):
        for x in range(128): px[y][x] = B
    logo(px, 'OVERRIDE', 2)
    text(px, 'THE ROGUE FLEET', (128 - 15 * 4) // 2, 27, G)
    # a thin rule under the droid lane
    for x in range(128):
        if x % 4 != 3: px[44][x] = R
    return px


def pic_bytes(px):
    out = bytearray()
    for r in px:
        out += pack_row(r)
    return bytes(out)


STORY = [
    "THE KESTREL FREIGHTERS DRIFT",
    "DARK AT THE EDGE OF THE BELT.",
    "A ROGUE SHIP MIND, THE OVERMIND,",
    "HAS SEIZED EVERY DROID ABOARD.",
    "",
    "YOU ARE THE LINK PROBE: A SMALL",
    "UNARMED UNIT THAT CAN TAKE OVER",
    "ANY DROID IT TOUCHES.",
    "",
    "BORROW THEIR BODIES. CLEAR EVERY",
]
STORY2 = [
    "DECK OF ALL THREE SHIPS.",
    "",
    "CONTROLS",
    "MOVE      Q A O P  OR  JOYSTICK",
    "SHOOT     FIRE (SPACE OR M)",
    "LINK      HOLD FIRE, STAND STILL,",
    "          THEN TOUCH A DROID",
    "LIFT      FIRE ON A LIFT PAD",
    "CONSOLE   PUSH INTO A TERMINAL",
    "PAUSE     RETURN",
]


def rle(data):
    """n < $80: n+1 literal bytes follow; n >= $80: repeat the next byte n-$7D times (3..130)"""
    out = bytearray(); i = 0; lit = bytearray()
    def flush():
        while lit:
            chunk = lit[:128]; del lit[:128]
            out.append(len(chunk) - 1); out.extend(chunk)
    while i < len(data):
        j = i
        while j < len(data) and data[j] == data[i] and j - i < 130: j += 1
        if j - i >= 3:
            flush(); out.append(0x7D + (j - i)); out.append(data[i]); i = j
        else:
            lit.append(data[i]); i += 1
    flush()
    out.append(0xFF); out.append(0)    # (0xFF = run of 130 of 0... never reached: length known)
    return bytes(out)


def ship_art():
    """the Kestrel freighter, side view, nose to the left: 44 x 14 on blue"""
    W, H = 44, 14
    px = [[B] * W for _ in range(H)]
    # hull: a long capsule, rows 4-10
    for y in range(4, 11):
        d = abs(y - 7)
        x0 = 1 + d * 2; x1 = 37 - d
        for x in range(x0, x1 + 1):
            px[y][x] = Y
        px[y][x0] = G
        if y in (4, 10):
            for x in range(x0, x1 + 1): px[y][x] = G
    for x in range(6, 35, 2): px[6][x] = B          # windows
    for x in range(4, 36): px[8][x] = R             # the line's red stripe
    # bridge tower
    for y in range(1, 4):
        for x in range(12 + (3 - y), 24):
            px[y][x] = G if y == 1 else Y
    for x in range(14, 23, 2): px[2][x] = B
    # fins and engines
    for y in (2, 3, 11, 12):
        for x in range(29, 36): px[y][x] = G
    for y in range(5, 10):
        for x in range(38, 38 + (3 if y in (5, 9) else 5)): px[y][x] = R
        px[y][37] = G
    px[7][43] = Y                                    # exhaust spark
    return px


def ship_shifts():
    """4 phases x 14 rows x 12 bytes, opaque (blue padding)"""
    art = ship_art(); out = bytearray()
    for p in range(4):
        for r in art:
            row = [B] * p + r + [B] * 48
            out += pack_row(row[:48])
    return bytes(out)


def strings_asm(label, lines):
    out = ['%s:' % label]
    for l in lines:
        out.append('            db "%s",0' % l)
    out.append('            db $FF')
    return out


def asm():
    L = ['; generated by tools/fedata.py']
    L.append('title_pic:')
    b = rle(pic_bytes(title_picture()))
    for i in range(0, len(b), 16):
        L.append('            db ' + ','.join('$%02X' % v for v in b[i:i + 16]))
    L += strings_asm('story1', STORY)
    L += strings_asm('story2', STORY2)
    # roster: name, weapon name, blurb (split into two 32-char lines)
    L.append('r_names:')
    for r in roster.ROSTER:
        L.append('            db "%s",0' % r[1])
    L.append('r_wnames:')
    for w in roster.WEAPON_NAMES:
        L.append('            db "%s",0' % w)
    L.append('r_blurbs:')
    for r in roster.ROSTER:
        words = r[6].split(); lines = ['']
        for w in words:
            if len(lines[-1]) + len(w) + 1 > 32: lines.append('')
            lines[-1] = (lines[-1] + ' ' + w).strip()
        lines = (lines + ['', ''])[:2]
        L.append('            db "%s",0,"%s",0' % tuple(lines))
    return '\n'.join(L) + '\n'


if __name__ == '__main__':
    pix_image(title_picture(), sx=4, sy=6).save('build/title_preview.png')
