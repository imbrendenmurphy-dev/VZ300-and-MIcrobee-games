#!/usr/bin/env python3
"""SOUTHERN CROSS - front-end pack (SCROSS00): title art, its animation tables,
and the three-voice title tune.  Imported by mkassets.py.
"""
import math, random
from PIL import Image, ImageDraw
from mkassets import pack, F35, G, Y, B, R, CH, note_index, FS_HZ

W, H = 128, 64
TITLE_T = 188                      # T-states per pass of the three-voice loop
FS3 = FS_HZ / TITLE_T

T55 = {
 'S':["01111","11000","01110","00011","11110"],'O':["01110","11011","11011","11011","01110"],
 'U':["11011","11011","11011","11011","01110"],'T':["11111","00100","00100","00100","00100"],
 'H':["11011","11011","11111","11011","11011"],'E':["11111","11000","11110","11000","11111"],
 'R':["11110","11011","11110","11011","11011"],'N':["11001","11101","11111","10111","10011"],
 'C':["01111","11000","11000","11000","01111"],
}
CRUX = ["...yy...", "...bb...", "..yyyy..", ".ryyyyr.", "ryyrryyr", "y.yyyy.y", "...yy...", "..r..r.."]

STARS = [(98, 4, 3), (98, 19, 3), (90, 11, 2), (106, 9, 2), (102, 15, 1),   # the Cross
         (68, 15, 2), (78, 17, 2)]                                      # the Pointers
PRESS = (10, 47)              # PRESS FIRE text origin (x multiple of 4)
HI_X, HI_Y = 92, 57           # 8 digits, byte aligned

def title_image():
    img = [[B] * W for _ in range(H)]
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            img[y][x] = c
    rnd = random.Random(7)
    for _ in range(60):
        x, y = rnd.randrange(W), rnd.randrange(0, 26)
        put(x, y, G if rnd.random() < 0.75 else Y)
    def star(x, y, s):
        put(x, y, Y)
        for d in range(1, s + 1):
            put(x + d, y, Y); put(x - d, y, Y)
        for d in range(1, max(1, s // 2) + 1):
            put(x, y + d, Y); put(x, y - d, Y)
    for x, y, s in STARS:
        star(x, y, s)
    # the continent, squashed for tall pixels
    pts = [(0.00,0.45),(0.05,0.30),(0.20,0.18),(0.30,0.05),(0.42,0.10),(0.48,0.00),(0.58,0.08),
           (0.62,0.22),(0.70,0.25),(0.72,0.00),(0.78,0.15),(0.85,0.35),(0.95,0.50),(1.00,0.65),
           (0.95,0.80),(0.85,0.95),(0.75,0.90),(0.68,0.78),(0.62,0.82),(0.55,0.70),(0.45,0.70),
           (0.30,0.75),(0.12,0.85),(0.03,0.80),(0.02,0.65)]
    m = Image.new('L', (W, H), 0)
    d = ImageDraw.Draw(m)
    ox, oy, sw, sh = 74, 33, 50, 20
    d.polygon([(ox + x * sw, oy + y * sh) for x, y in pts], fill=1)
    d.ellipse((ox + 0.80 * sw, oy + 1.06 * sh, ox + 0.88 * sw, oy + 1.16 * sh), fill=1)
    mp = m.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y]:
                inner = all(mp[min(W-1, max(0, x+a)), min(H-1, max(0, y+b))] for a, b in ((1,0),(-1,0),(0,1),(0,-1)))
                img[y][x] = G if inner else Y
                if inner and (x - 104) ** 2 + ((y - 43) * 2) ** 2 < 64 and (x + y) % 2 == 0:
                    img[y][x] = R
    # logo
    def logo(s, ox, oy):
        on = set()
        for i, ch in enumerate(s):
            g = T55[ch]
            for j in range(5):
                for k in range(5):
                    if g[j][k] == '1':
                        for a in range(2):
                            for b in range(2):
                                on.add((ox + i * 12 + k * 2 + a, oy + j * 2 + b))
        for (x, y) in on:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    put(x + dx, y + dy, Y)
        for (x, y) in on:
            put(x, y, R)
            if y - oy in (4, 5) and (x + y) % 3:
                put(x, y, Y if y - oy == 4 else R)
    logo("SOUTHERN", (W - 94) // 2, 21)
    logo("CROSS", 8, 34)
    # the Crux climbing past the stars
    for j, row in enumerate(CRUX):
        for i, ch in enumerate(row):
            if ch != '.':
                put(12 + i, 3 + j, CH[ch])
    for y in range(12, 19, 2):
        put(16, y, R)
    def text(x, y, s, c):
        for i, ch in enumerate(s):
            g = F35[ch]
            for j in range(5):
                for k in range(3):
                    if g[j * 3 + k] == '1':
                        put(x + i * 4 + k, y + j, c)
    text(4, 57, "VIBED BY BPM 2026", G)
    text(HI_X - 12, HI_Y, "HI", R)
    return img

def press_rows(on):
    """PRESS FIRE region (7 rows x 11 bytes) with and without the text"""
    img = title_image()
    x0, y0 = PRESS
    if on:
        s = "PRESS FIRE"
        pix = set()
        for i, ch in enumerate(s):
            g = F35[ch]
            for j in range(5):
                for k in range(3):
                    if g[j * 3 + k] == '1':
                        pix.add((x0 + 1 + i * 4 + k, y0 + 1 + j))
        for (x, y) in pix:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    img[y + dy][x + dx] = B
        for (x, y) in pix:
            img[y][x] = Y
    out = []
    for y in range(y0, y0 + 7):
        out += [pack(img[y][x:x + 4]) for x in range(x0, x0 + 44, 4)]
    return out

def twinkle_tables():
    """per star: VRAM address, then 3 rows x 2 bytes for 'bright' and 'dim'"""
    img = title_image()
    t = []
    for x, y, s in STARS:
        bx = (x - 2) // 4
        addr = 0x7000 + (y - 1) * 32 + bx
        bright = []
        dim = []
        for yy in range(y - 1, y + 2):
            row = img[yy][bx * 4: bx * 4 + 8]
            bright += [pack(row[0:4]), pack(row[4:8])]
            d = list(row)
            for i in range(8):
                if d[i] == Y and not (bx * 4 + i == x and yy == y):
                    d[i] = G
            dim += [pack(d[0:4]), pack(d[4:8])]
        t.append((addr, bright, dim))
    return t

def rle(data):
    out = []
    i = 0
    while i < len(data):
        b = data[i]
        n = 1
        while i + n < len(data) and data[i + n] == b and n < 255:
            n += 1
        out += [n, b]
        i += n
    out.append(0)
    return out

# ------------------------------------------------------------------ title tune
NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
U = 6     # fields per 16th note

INS = [   # (name, duty envelope, arpeggio)  $FF hold last duty; arp $80 loop, $81 hold
    ('lead',  [96, 92, 86, 80, 74, 68, 62, 58, 54, 50, 48, 0xFF], None),
    ('stac',  [100, 84, 66, 48, 30, 0, 0xFF], None),
    ('minor', [64, 62, 60, 58, 56, 54, 52, 0xFF], [0, 3, 7, 0x80]),
    ('major', [64, 62, 60, 58, 56, 54, 52, 0xFF], [0, 4, 7, 0x80]),
    ('bass',  [120, 112, 104, 96, 88, 76, 0, 0xFF], None),
    ('kick',  [128, 120, 100, 70, 0, 0xFF], [0, 0xFC, 0xF8, 0xF4, 0xF0, 0xEC, 0x81]),
    ('long',  [90, 88, 86, 84, 82, 80, 78, 76, 74, 72, 70, 0xFF], None),
]
INSNUM = {n: i for i, (n, *_) in enumerate(INS)}

LEAD_A = [
 "D5 - - - A4 - D5 - F5 - E5 - D5 - - -",
 "C5 - D5 - A4 - - - - - - - - - - -",
 "F5 - - - D5 - F5 - G5 - F5 - D5 - - -",
 "E5 - - - C5 - E5 - G5 - - - E5 - - -",
 "D5 - - - A4 - D5 - F5 - G5 - A5 - - -",
 "A5 - G5 - F5 - E5 - D5 - - - - - - -",
 "D5 - F5 - A#5 - - - A5 - G5 - F5 - - -",
 "E5 - - - C#5 - - - A4 - - - - - - -",
]
LEAD_B = [
 "A5 - - - C6 - A5 - F5 - - - A5 - - -",
 "G5 - - - E5 - G5 - C6 - - - G5 - - -",
 "F5 - - - D5 - F5 - A5 - - - F5 - E5 -",
 "E5 - - - - - - - C#5 - E5 - A5 - - -",
 "G5 - - - A#5 - - - D6 - - - A#5 - - -",
 "A5 - - - F5 - - - D5 - - - F5 - - -",
 "F5 - E5 - D5 - C#5 - E5 - - - A4 - - -",
 "D5 - - - - - - - - - - - - - - -",
]
CHORDS_A = [('D4', 'minor'), ('D4', 'minor'), ('A#3', 'major'), ('C4', 'major'),
            ('D4', 'minor'), ('D4', 'minor'), ('A#3', 'major'), ('A3', 'major')]
CHORDS_B = [('F4', 'major'), ('C4', 'major'), ('D4', 'minor'), ('A3', 'major'),
            ('G3', 'minor'), ('D4', 'minor'), (('A#3', 'major'), ('A3', 'major')), ('D4', 'minor')]

def lower(n, octs):
    return n[:-1] + str(int(n[-1]) - octs)

def tune():
    ch1, ch2, ch3, dr = [], [], [], []
    def notes(chan, s, ins):
        chan.append(('ins', INSNUM[ins]))
        for tok in s.split():
            if tok == '-':
                chan[-1] = (chan[-1][0], chan[-1][1] + U) if chan[-1][0] != 'ins' else chan[-1]
            else:
                chan.append((note_index(tok), U))
    # intro: two bars of arps and bass only
    bars = [('A', i) for i in range(8)] + [('B', i) for i in range(8)]
    seq = [('I', 0), ('I', 1)] + bars + bars
    for sec, i in seq:
        if sec == 'I':
            ch1.append(('ins', INSNUM['lead'])); ch1.append((0, 16 * U))
        else:
            notes(ch1, (LEAD_A if sec == 'A' else LEAD_B)[i], 'lead')
        ch = CHORDS_A[0 if sec == 'I' else i] if sec != 'B' else CHORDS_B[i]
        if isinstance(ch[0], tuple):
            for root, kind in ch:
                ch2.append(('ins', INSNUM[kind])); ch2.append((note_index(root), 8 * U))
        else:
            ch2.append(('ins', INSNUM[ch[1]])); ch2.append((note_index(ch[0]), 16 * U))
        root = (ch[0][0] if isinstance(ch[0], tuple) else ch[0])
        r2 = lower(root, 2) if int(root[-1]) >= 4 else lower(root, 1)
        o3 = lower(r2, -1)
        pat = [('kick', 'D2'), ('bass', r2), None, ('bass', r2), ('bass', o3), None, ('bass', r2), ('bass', r2)]
        for p in pat:
            if p is None:
                ch3.append((0, 2 * U))
            else:
                ch3.append(('ins', INSNUM[p[0]])); ch3.append((note_index(p[1]), 2 * U))
        if sec == 'I':
            dr += [(0, 2 * U), (2, 2 * U)] * 4
        else:
            dr += [(0, 2 * U), (2, 2 * U), (1, 2 * U), (2, 2 * U)] * 2
    return ch1, ch2, ch3, dr

def chan_bytes(ch):
    out = []
    for ev in ch:
        if ev[0] == 'ins':
            out.append(0x80 | ev[1])
        else:
            n, d = ev
            while d > 255:
                out += [n, 255]; d -= 255; n = 0
            out += [n, d]
    out.append(0xFF)
    return out

def gen_front():
    t = []
    t.append('        db "F",0\n')
    img = title_image()
    raw = []
    for y in range(H):
        raw += [pack(img[y][x:x + 4]) for x in range(0, W, 4)]
    r = rle(raw)
    t.append('FR_ART:                 ; RLE (count, byte) pairs, 0 ends - %d bytes from 2048\n' % len(r))
    for i in range(0, len(r), 16):
        t.append('        db ' + ','.join('$%02X' % b for b in r[i:i + 16]) + '\n')
    t.append('FR_PRESS_ON:\n')
    d = press_rows(True)
    for i in range(0, len(d), 11):
        t.append('        db ' + ','.join('$%02X' % b for b in d[i:i + 11]) + '\n')
    t.append('FR_PRESS_OFF:\n')
    d = press_rows(False)
    for i in range(0, len(d), 11):
        t.append('        db ' + ','.join('$%02X' % b for b in d[i:i + 11]) + '\n')
    t.append('FR_PRESS_VRAM equ $%04X\n' % (0x7000 + PRESS[1] * 32 + PRESS[0] // 4))
    t.append('FR_HI_VRAM equ $%04X\n' % (0x7000 + HI_Y * 32 + HI_X // 4))
    t.append('FR_NSTARS equ %d\nFR_TWINKLE:             ; vram address, 6 bright bytes, 6 dim bytes\n' % len(STARS))
    for addr, br, dm in twinkle_tables():
        t.append('        dw $%04X\n        db %s\n        db %s\n' % (addr, ','.join('$%02X' % b for b in br),
                                                                   ','.join('$%02X' % b for b in dm)))
    # three-voice tune
    t.append('FR_NOTE3:                ; phase steps for the 188 T loop (%.0f Hz)\n        dw 0\n' % FS3)
    for i in range(1, 73):
        midi = 24 + (i - 1)
        f = 440.0 * 2 ** ((midi - 69) / 12)
        t.append('        dw %d\n' % min(65535, int(round(f * 65536 / FS3))))
    t.append('FR_INS:                  ; envelope, arpeggio\n')
    for name, env, arp in INS:
        t.append('        dw .e_%s,%s\n' % (name, ('.a_' + name) if arp else '0'))
    for name, env, arp in INS:
        t.append('.e_%s: db %s\n' % (name, ','.join('$%02X' % v for v in env)))
        if arp:
            t.append('.a_%s: db %s\n' % (name, ','.join('$%02X' % (v & 255) for v in arp)))
    ch1, ch2, ch3, dr = tune()
    for name, ch in (('FR_CH1', ch1), ('FR_CH2', ch2), ('FR_CH3', ch3)):
        b = chan_bytes(ch)
        t.append('%s:\n' % name)
        for i in range(0, len(b), 16):
            t.append('        db ' + ','.join('$%02X' % v for v in b[i:i + 16]) + '\n')
    t.append('FR_DRUMS:                ; 0 rest, 1 snare, 2 hat; then duration\n')
    db = []
    for e, dd in dr:
        db += [e, dd]
    db.append(0xFF)
    for i in range(0, len(db), 16):
        t.append('        db ' + ','.join('$%02X' % v for v in db[i:i + 16]) + '\n')
    t.append('FR_END:\n')
    return ''.join(t), img

def preview(img, path):
    pal = [(48, 210, 0), (193, 229, 0), (76, 58, 180), (154, 50, 54)]
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W):
            im.putpixel((x, y), pal[img[y][x]])
    im.resize((W * 4, H * 6), Image.NEAREST).save(path)
