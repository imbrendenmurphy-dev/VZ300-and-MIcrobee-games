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
    # keep the high score, ticker and PRESS FIRE band (rows 45-63) clear of stars
    for y in range(45, 64):
        for x in range(128): px[y][x] = B
    # a frame for the ticker: rules at rows 51 and 57
    for x in range(128):
        px[51][x] = G if x % 2 == 0 else B
        px[57][x] = G if x % 2 == 0 else B
    return px


def pic_bytes(px):
    out = bytearray()
    for r in px:
        out += pack_row(r)
    return bytes(out)


STORY = [
    "FIVE SHIPS OF THE KESTREL LINE",
    "DRIFT DARK AT THE BELT'S EDGE.",
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
    "DECK OF ALL FIVE SHIPS.",
    "CONTROLS",
    "MOVE      Q A O P  OR  JOYSTICK",
    "SHOOT     FIRE (SPACE OR M)",
    "LINK      HOLD FIRE, STAND STILL",
    "          THEN TOUCH A DROID",
    "LIFT      FIRE ON A LIFT PAD",
    "CONSOLE   PUSH INTO A TERMINAL",
    "PAUSE     RETURN     MUSIC  N",
    "SOUND OUT C: SPEAKER/BOTH/TAPE",
]

STORY3 = [
    "THE LINK DUEL",
    "PICK A SIDE (LEFT/RIGHT), FIRE.",
    "UP/DOWN PICKS A WIRE. FIRE SENDS",
    "A PULSE: ITS NODE TURNS YOUR",
    "COLOUR AND LOCKS FOR A MOMENT.",
    "CAPPED WIRES ARE BROKEN. GREEN",
    "CROSSES HAND NODES TO THE DROID.",
    "YELLOW DIAMONDS LOCK FOR LONGER.",
    "HOLD MORE NODES AT THE END.",
    "THE PROBE CAN TAKE CLASSES 1-3.",
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


def _canvas():
    return [[B] * 44 for _ in range(14)]


def _rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if 0 <= x < 44 and 0 <= y < 14: px[y][x] = c


def liner_art():
    """the Arcadia: a long white-yellow liner, three decks of windows, two funnels"""
    px = _canvas()
    for y in range(7, 12):                          # hull with a raked bow
        x0 = 1 + max(0, 11 - y) * 0 + (y - 7) * 2 if y > 7 else 1
        _rect(px, x0, y, 39 - (y - 7), y, Y)
        px[y][x0] = G
    _rect(px, 3, 11, 36, 11, G)
    _rect(px, 2, 9, 38, 9, R)                       # the line's red band
    _rect(px, 8, 4, 35, 6, Y)                       # superstructure
    _rect(px, 12, 2, 31, 3, Y)
    for x in range(9, 35, 2): px[5][x] = B
    for x in range(13, 31, 2): px[3][x] = B
    for x in range(3, 38, 3): px[8][x] = B
    for fx in (17, 24):                             # funnels
        _rect(px, fx, 0, fx + 2, 1, R)
        px[0][fx] = G
    _rect(px, 40, 8, 42, 10, R)                     # screws
    px[9][43] = Y
    return px


def science_art():
    """the Halcyon: a round lab hull, a ring of pods and a long sensor boom"""
    px = _canvas()
    for y in range(2, 12):                          # the disc
        d = abs(y - 6.5)
        h = int(round((5.5 ** 2 - d ** 2) ** 0.5 * 1.8)) if d < 5.5 else 0
        _rect(px, 20 - h, y, 20 + h, y, Y)
        if h: px[y][20 - h] = G; px[y][20 + h] = G
    _rect(px, 11, 6, 29, 7, B)                      # the ring gap
    for x in range(11, 30, 3): _rect(px, x, 6, x + 1, 7, R)
    _rect(px, 0, 6, 10, 7, G)                       # sensor boom and dish
    _rect(px, 0, 4, 1, 9, Y)
    px[3][0] = G; px[10][0] = G
    _rect(px, 31, 5, 37, 8, G)                      # drive section
    _rect(px, 38, 5, 41, 8, R)
    px[6][42] = Y; px[7][43] = Y
    for x in (17, 20, 23): px[4][x] = B
    return px


def hauler_art():
    """the Grindstone: a boxy ore hauler, cargo pods slung under a spine, a crane"""
    px = _canvas()
    _rect(px, 2, 5, 38, 6, G)                       # spine girder
    for x in range(3, 38, 4): px[5][x] = B
    for k, x in enumerate(range(6, 34, 7)):         # ore pods
        _rect(px, x, 7, x + 5, 11, R if k % 2 else Y)
        _rect(px, x, 7, x + 5, 7, G)
    _rect(px, 0, 2, 7, 8, Y)                        # bridge block at the bow
    _rect(px, 1, 3, 6, 3, B)
    px[2][0] = G
    _rect(px, 20, 1, 21, 4, G)                      # the crane
    _rect(px, 21, 1, 29, 1, G)
    px[2][29] = Y; px[3][29] = Y
    _rect(px, 36, 3, 40, 9, Y)                      # engine block
    _rect(px, 41, 4, 43, 8, R)
    return px


def warship_art():
    """the Leviathan: an armoured wedge with gun turrets"""
    px = _canvas()
    for y in range(3, 12):                          # wedge: sharp bow on the left
        d = abs(y - 7)
        x0 = 2 + d * 3
        _rect(px, x0, y, 40 - d, y, Y)
        px[y][x0] = G
    _rect(px, 6, 7, 38, 7, R)                       # armour seam
    for x in range(10, 37, 4): px[9][x] = B
    for tx in (12, 22):                             # turrets and barrels
        _rect(px, tx, 1, tx + 3, 2, G)
        _rect(px, tx - 4, 1, tx - 1, 1, G)
    _rect(px, 28, 0, 33, 2, Y)                      # command tower
    px[1][30] = B; px[1][31] = B
    _rect(px, 41, 5, 43, 9, R)                      # drives
    return px


SHIP_ARTS = [ship_art, liner_art, science_art, hauler_art, warship_art]


def ship_shifts(art=None):
    """4 phases x 14 rows x 12 bytes, opaque (blue padding)"""
    art = art or ship_art(); out = bytearray()
    for p in range(4):
        for r in art:
            row = [B] * p + r + [B] * 48
            out += pack_row(row[:48])
    return bytes(out)


def strings_asm(label, lines):
    out = ['%s:' % label]
    for l in lines:
        # 32 columns of 4 pixels: a 33rd character would wrap into the next
        # pixel row at the left edge
        assert len(l) <= 32, (label, len(l), l)
        out.append('            db "%s",0' % l)
    out.append('            db $FF')
    return out


# ---------------------------------------------------------------------------
# the OVERRIDE display font: 6x8, two-pixel strokes, square corners cut,
# drawn with a two-tone fill (top / bottom) and a drop shadow
BIG = {
    'A': [".#####", "##..##", "##..##", "######", "##..##", "##..##", "##..##", "##..##"],
    'B': ["#####.", "##..##", "##..##", "#####.", "##..##", "##..##", "##..##", "#####."],
    'C': [".#####", "##....", "##....", "##....", "##....", "##....", "##....", ".#####"],
    'D': ["#####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "#####."],
    'E': ["######", "##....", "##....", "#####.", "##....", "##....", "##....", "######"],
    'F': ["######", "##....", "##....", "#####.", "##....", "##....", "##....", "##...."],
    'G': [".#####", "##....", "##....", "##.###", "##..##", "##..##", "##..##", ".#####"],
    'H': ["##..##", "##..##", "##..##", "######", "##..##", "##..##", "##..##", "##..##"],
    'I': ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
    'J': ["....##", "....##", "....##", "....##", "....##", "##..##", "##..##", ".####."],
    'K': ["##..##", "##.##.", "####..", "###...", "####..", "##.##.", "##..##", "##..##"],
    'L': ["##....", "##....", "##....", "##....", "##....", "##....", "##....", "######"],
    'M': ["##..##", "######", "######", "##..##", "##..##", "##..##", "##..##", "##..##"],
    'N': ["##..##", "###.##", "######", "##.###", "##..##", "##..##", "##..##", "##..##"],
    'O': [".####.", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    'P': ["#####.", "##..##", "##..##", "#####.", "##....", "##....", "##....", "##...."],
    'Q': [".####.", "##..##", "##..##", "##..##", "##..##", "##.###", "##..##", ".###.#"],
    'R': ["#####.", "##..##", "##..##", "#####.", "##.##.", "##..##", "##..##", "##..##"],
    'S': [".#####", "##....", "##....", ".####.", "....##", "....##", "....##", "#####."],
    'T': ["######", "..##..", "..##..", "..##..", "..##..", "..##..", "..##..", "..##.."],
    'U': ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####."],
    'V': ["##..##", "##..##", "##..##", "##..##", "##..##", "##..##", ".####.", "..##.."],
    'W': ["##..##", "##..##", "##..##", "##..##", "##..##", "######", "######", "##..##"],
    'X': ["##..##", "##..##", ".####.", "..##..", ".####.", "##..##", "##..##", "##..##"],
    'Y': ["##..##", "##..##", "##..##", ".####.", "..##..", "..##..", "..##..", "..##.."],
    'Z': ["######", "....##", "...##.", "..##..", ".##...", "##....", "##....", "######"],
    '0': [".####.", "##..##", "##.###", "######", "###.##", "##..##", "##..##", ".####."],
    '1': ["..##..", ".###..", "..##..", "..##..", "..##..", "..##..", "..##..", "######"],
    '2': [".####.", "##..##", "....##", "...##.", "..##..", ".##...", "##....", "######"],
    '3': ["#####.", "....##", "....##", ".####.", "....##", "....##", "....##", "#####."],
    '4': ["##..##", "##..##", "##..##", "######", "....##", "....##", "....##", "....##"],
    '5': ["######", "##....", "##....", "#####.", "....##", "....##", "##..##", ".####."],
    '6': [".####.", "##....", "##....", "#####.", "##..##", "##..##", "##..##", ".####."],
    '7': ["######", "....##", "....##", "...##.", "..##..", "..##..", "..##..", "..##.."],
    '8': [".####.", "##..##", "##..##", ".####.", "##..##", "##..##", "##..##", ".####."],
    '9': [".####.", "##..##", "##..##", "##..##", ".#####", "....##", "....##", ".####."],
    '!': ["..##..", "..##..", "..##..", "..##..", "..##..", "......", "..##..", "..##.."],
    ':': ["......", "..##..", "..##..", "......", "......", "..##..", "..##..", "......"],
    '.': ["......", "......", "......", "......", "......", "......", "..##..", "..##.."],
    '-': ["......", "......", "......", ".####.", ".####.", "......", "......", "......"],
    '?': [".####.", "##..##", "....##", "...##.", "..##..", "......", "..##..", "..##.."],
    "'": ["..##..", "..##..", ".##...", "......", "......", "......", "......", "......"],
}


def bigfont_asm():
    """bf_map: 64 entries (ASCII 32-95) -> glyph offset/8 ($FF blank);
    bf_glyphs: 8 bytes a glyph, a row a byte, bits 7..2 = columns 0..5"""
    chars = sorted(BIG)
    m = [0xFF] * 64
    L = ['; generated by tools/fedata.py: the display font', 'bf_map:']
    for i, ch in enumerate(chars):
        m[ord(ch) - 32] = i
    for i in range(0, 64, 16):
        L.append('            db ' + ','.join('$%02X' % v for v in m[i:i + 16]))
    L.append('bf_glyphs:')
    for ch in chars:
        g = BIG[ch]
        assert len(g) == 8 and all(len(r) == 6 for r in g), ch
        bs = [sum(0x80 >> x for x in range(6) if r[x] == '#') for r in g]
        L.append('            db ' + ','.join('$%02X' % b for b in bs) + '   ; ' + ch)
    return '\n'.join(L) + '\n'


def big_preview(text, path):
    W = len(text) * 7 + 2
    px = [[B] * W for _ in range(11)]
    for k, ch in enumerate(text):
        g = BIG.get(ch)
        if not g: continue
        for pas in (0, 1):
            for y in range(8):
                for x in range(6):
                    if g[y][x] == '#':
                        if pas == 0: px[y + 2][k * 7 + x + 2] = R
                        else: px[y + 1][k * 7 + x + 1] = Y if y < 4 else G
    pix_image(px, sx=8, sy=12).save(path)


def ov_asm():
    """the overlay's data: the title picture and the briefing"""
    L = ['; generated by tools/fedata.py: overlay data']
    L.append('title_pic:')
    b = rle(pic_bytes(title_picture()))
    for i in range(0, len(b), 16):
        L.append('            db ' + ','.join('$%02X' % v for v in b[i:i + 16]))
    L += strings_asm('story1', STORY)
    L += strings_asm('story2', STORY2)
    L += strings_asm('story3', STORY3)
    L.append('ship_art:')
    b = ship_shifts()
    for i in range(0, len(b), 16):
        L.append('            db ' + ','.join('$%02X' % v for v in b[i:i + 16]))
    return '\n'.join(L) + '\n'


def asm():
    L = ['; generated by tools/fedata.py']
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
    # the whole fleet for the ending: each ship's silhouette, phase 0 only
    # (drawn at x multiple of 4), 14 rows x 12 bytes
    L.append('fleet_art:')
    for f in SHIP_ARTS:
        b = ship_shifts(f())[:168]
        for i in range(0, len(b), 24):
            L.append('            db ' + ','.join('$%02X' % v for v in b[i:i + 24]))
    return '\n'.join(L) + '\n'


if __name__ == '__main__':
    pix_image(title_picture(), sx=4, sy=6).save('build/title_preview.png')
