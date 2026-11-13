#!/usr/bin/env python3
"""
craft2.py - MAX Q hovercraft sprites, hand-tidied pixel art (VIBED BY BPM 2026)

Drawn from behind and above.  Symbols:
  D deck (team colour)     B flank (team colour / blue dither, shading)
  K hover skirt (blue)     C canopy        G thruster glow     F tail fins
  . transparent
Left-turn views are drawn by hand; right-turn views are their mirror images.
The craft yaws and banks into the turn: the nose swings across, the outer
flank comes into view and the rear tilts.  Nose-up / nose-down views are for
climbs and dips.  The shadow is a separate 2-row sprite so the craft can bob.
"""

# ------------------------------------------------------------ player / near rival: 24 x 8
S = ["..........DDDD..........",
     "........DDCCCCDD........",
     "......DDDCCCCCCDDD......",
     "..F.DDDDDDCCCCDDDDDD.F..",
     ".FFDDDDDDDDDDDDDDDDDDFF.",
     ".BBBGGGGGGGGGGGGGGGGBBB.",
     "..BBBBBBBBBBBBBBBBBBBB..",
     "....KKKKKKKKKKKKKKKK...."]

L1 = [".........DDDD...........",
      ".......DDCCCCDD.........",
      ".....DDDCCCCCCDDD.......",
      "..F.DDDDDCCCCDDDDDDD..F.",
      ".FFDDDDDDDDDDDDDDDDDDDFF",
      ".BBGGGGGGGGGGGGGGGGBBBBB",
      "..BBBBBBBBBBBBBBBBBBBBB.",
      "....KKKKKKKKKKKKKKKKK..."]

L2 = ["........DDD.............",
      "......DDCCCDD..........F",
      "....DDDCCCCCDDDD......FF",
      ".F.DDDDDCCCCDDDDDDDDDBBB",
      "FFDDDDDDDDDDDDDDDDDBBBB.",
      ".BGGGGGGGGGGGGGGGBBBBB..",
      "..BBBBBBBBBBBBBBBBBB....",
      "...KKKKKKKKKKKKKKK......"]

L3 = [".......DDD..............",
      ".....DDCCCDD.........F..",
      "...DDDCCCCCDDDD.....FF..",
      "F.DDDDDCCCCDDDDDDDDBBBB.",
      "FFDDDDDDDDDDDDDDDBBBBB..",
      ".BGGGGGGGGGGGGGBBBBB....",
      ".BBBBBBBBBBBBBBBBB......",
      "..KKKKKKKKKKKKKK........"]

UP = ["........................",
      "........................",
      "..........CCCC..........",
      "..F...DDDCCCCCCDDD...F..",
      ".FFDDDDDDDDDDDDDDDDDDFF.",
      ".BBBGGGGGGGGGGGGGGGGBBB.",
      ".BBBBBBBBBBBBBBBBBBBBBB.",
      "...KKKKKKKKKKKKKKKKKK..."]

DOWN = [".........DDDDDD.........",
        "........DDCCCCDD........",
        ".......DDCCCCCCDD.......",
        "......DDDCCCCCCDDD......",
        "..F.DDDDDDCCCCDDDDDD.F..",
        ".FFDDDDDDDDDDDDDDDDDDFF.",
        ".BBBGGGGGGGGGGGGGGGGBBB.",
        "....KKKKKKKKKKKKKKKK...."]

SHADOW = ["...S.S.S.S.S.S.S.S.S.S..",
          "....S.S.S.S.S.S.S.S.S..."]

# ------------------------------------------------------------ mid-distance rival: 16 x 6
MS = ["......DDDD......",
      "....DDCCCCDD....",
      ".F.DDDDDDDDDD.F.",
      "FBBGGGGGGGGGGBBF",
      ".BBBBBBBBBBBBBB.",
      "...KKKKKKKKKK..."]
ML1 = [".....DDDD.......",
       "...DDCCCCDD....F",
       ".F.DDDDDDDDDDBBF",
       "FBGGGGGGGGGBBBB.",
       ".BBBBBBBBBBBB...",
       "..KKKKKKKKKK...."]
ML2 = ["....DDD.........",
       "..DDCCCDD.....F.",
       "F.DDDDDDDDDBBBF.",
       "FBGGGGGGGGBBBB..",
       ".BBBBBBBBBBB....",
       "..KKKKKKKKK....."]

def mirror(fr): return [r[::-1] for r in fr]

PLAYER_VIEWS = [L3, L2, L1, S, mirror(L1), mirror(L2), mirror(L3), UP, DOWN]   # 9 frames
NEAR_VIEWS = [L2, L1, S, mirror(L1), mirror(L2)]                               # rivals: 5
MID_VIEWS = [ML2, ML1, MS, mirror(ML1), mirror(ML2)]

for f in PLAYER_VIEWS: assert len(f) == 8 and all(len(r) == 24 for r in f), f
for f in MID_VIEWS: assert len(f) == 6 and all(len(r) == 16 for r in f), f

# colours: a value or a (even, odd) dither pair.  0 green 1 yellow 2 blue 3 red
TEAMS = {
    'player': dict(D=1, B=(1, 2), K=2, C=2, G=3, F=3, rim=None),
    'red':    dict(D=3, B=(3, 2), K=2, C=2, G=1, F=2, rim=None),
    'blue':   dict(D=2, B=2, K=2, C=(2, 0), G=3, F=1, rim=1),
}

def colourise(fr, team):
    t = TEAMS[team]
    out = []
    for y, row in enumerate(fr):
        o = []
        for x, ch in enumerate(row):
            if ch == '.': o.append(None); continue
            if ch == 'S': o.append(2); continue
            c = t[ch]
            o.append(c[(x + y) & 1] if isinstance(c, tuple) else c)
        out.append(o)
    if t['rim'] is not None:      # bright edge along the top of the silhouette
        for y in range(len(fr)):
            for x in range(len(fr[0])):
                if fr[y][x] not in '.G' and (y == 0 or fr[y - 1][x] == '.'):
                    out[y][x] = t['rim']
    return out

def pack(px):
    """Rows of colours/None -> rows of (mask, data) byte pairs, plus one spare byte for shifting."""
    w = len(px[0]); nb = (w + 3) // 4 + 1
    out = []
    for row in px:
        cells = row + [None] * (nb * 4 - w)
        for b in range(nb):
            m = d = 0
            for q in range(4):
                c = cells[b * 4 + q]; s = 6 - 2 * q
                if c is None: m |= 3 << s
                else: d |= c << s
            out += [m, d]
    return out, nb

# ------------------------------------------------------------ layout
BANKB = 0x4000

def build(src_base):
    """Packed source frames (mirror images are made at start-up, not stored), per-frame
    expander descriptors (7 bytes) and the bank-B address of each named frame."""
    src = []; desc = []; syms = {}; stored = {}
    dst = BANKB
    def add(name, fr, team, nshift, step, mirror_of=None):
        nonlocal dst
        key = (id(mirror_of) if mirror_of is not None else id(fr), team)
        if mirror_of is not None:
            s_addr, rows, nb = stored[key]
        else:
            data, nb = pack(colourise(fr, team)); rows = len(fr)
            s_addr = src_base + len(src); src.extend(data)
            stored[key] = (s_addr, rows, nb)
        syms[name] = dst
        desc.extend([s_addr & 255, s_addr >> 8, dst & 255, dst >> 8, rows, nb,
                 nshift | (step << 4) | (0x80 if mirror_of is not None else 0)])
        dst += rows * nb * 2 * nshift
    P = [L3, L2, L1, S, None, None, None, UP, DOWN]
    MIR = {4: L1, 5: L2, 6: L3}
    for i in range(9):
        if i in MIR: add(f'P{i}', None, 'player', 4, 1, MIR[i])
        else: add(f'P{i}', P[i], 'player', 4, 1)
    add('SH', SHADOW, 'player', 4, 1)
    for team in ('red', 'blue'):
        for i, (f, m) in enumerate(((L2, None), (L1, None), (S, None), (None, L1), (None, L2))):
            add(f'N_{team}{i}', f, team, 2, 2, m)
        for i, (f, m) in enumerate(((ML2, None), (ML1, None), (MS, None), (None, ML1), (None, ML2))):
            add(f'M_{team}{i}', f, team, 2, 2, m)
    assert dst <= 0x6800, hex(dst)
    return src, desc + [0, 0, 0, 0, 0], syms, dst

if __name__ == '__main__':
    src, desc, syms, end = build(0xA700)
    print(len(src), 'source bytes;', len(desc), 'descriptor bytes;', hex(end), 'end of bank B data')
