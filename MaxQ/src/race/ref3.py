#!/usr/bin/env python3
"""
ref3.py - exact integer reference for the VZ300 3D racer, Stage 3 renderer.
VIBED BY BPM 2026

Every operation here is mirrored instruction-for-instruction by the Z80
engine (same tables, same shifts, same wraparound), so the Z80 output can be
compared byte-for-byte with this model.

World units: 1/8 of a "metre-unit" (call them e). Angles: 0..255 = 2*pi.
A track section is 64 e long, so stepping one section along heading d is
exactly (SIN64[d], COS64[d]): no multiplies.
"""
import math

N = 512                  # sections in the loop
SEGE = 64                # section length (e)
HWE = 72                 # track half-width (e)
CH = 28                  # camera height above the track (e) = 3.5 units
HORIZ = 38               # horizon row at zero pitch
TOPROW = 16              # rows 0..TOPROW-1: static sky image (HUD drawn on it)
NEARZ = 32               # near plane (e)
DEPTH = 18               # sections looked ahead
BIAS = 64
LOGFX = round(64 * math.log2(70))          # horizontal focal length 70 px
LOGFY = round(64 * math.log2(70 / 1.5))    # mode(1) pixels are 1.5x taller than wide
RAIL_E, SKIRT_E, GATEH_E, GATEW_E, GATET_E = 4, 12, 88, 13, 10

# ------------------------------------------------------------- tables
SIN64 = [round(64 * math.sin(2 * math.pi * a / 256)) for a in range(256)]
COS64 = [SIN64[(a + 64) & 255] for a in range(256)]
LOGT = [0] + [round(64 * math.log2(m)) for m in range(1, 2048)]
EXPT = [min(127, round(2 ** ((d - 64) / 64))) for d in range(512)]
EXP88 = [min(65535, round(256 * 2 ** ((d - 512) / 64))) for d in range(1024)]

def sq_tables():
    lo, hi = [], []
    for n in range(512):
        v = ((n - 256) ** 2) // 4
        lo.append(v & 0xFF); hi.append(v >> 8)
    return lo, hi

def mul8(a, b):            # exact signed 8x8 (what the quarter-square code returns)
    return a * b

# colour ids -> pattern pairs (pixel indices a,b: a on even x of even rows)
PAT_PAIRS = {0: (0, 0), 1: (1, 1), 2: (2, 2), 3: (3, 3), 4: (0, 2), 5: (3, 2), 6: (1, 0), 7: (1, 3),
             8: (2, 0), 9: (1, 2), 10: (2, 3)}
def pat_byte(c, parity):
    a, b = PAT_PAIRS.get(c, (2, 2))
    if parity: a, b = b, a
    return (a << 6) | (b << 4) | (a << 2) | b
PATE = [pat_byte(c, 0) for c in range(16)]
PATO = [pat_byte(c, 1) for c in range(16)]
SKY_CSS0 = [2, 10, 3, 7, 1]     # sunset in colour set 0: blue, blue/red, red, red/yellow, yellow
SKY_CSS1 = [1, 9, 2, 10, 3]     # colour set 1: cyan, cyan/magenta, magenta, magenta/orange, orange
SKY_A = [2, 2, 2, 2, 2]          # open blue sky (in game)
SKY_H = [1, 1, 2, 2, 2]          # HUD strip in colour set 1 (cyan), blue sky below
import math as _m
RIDGE = [max(0, min(7, int(round(3.2 + 1.8 * _m.sin(u * 2 * _m.pi / 256 * 3 + 1) + 1.6 * _m.sin(u * 2 * _m.pi / 256 * 7 + 2)
                                  + 1.2 * _m.sin(u * 2 * _m.pi / 256 * 13))))) for u in range(256)]
SKYL_H = 7

def sky_pix(u, h):
    r = RIDGE[u & 255]
    if r >= h + 2: return 1
    if r >= h: return 1 if (u + h) & 1 else 2
    return 2

def skyline(img, fr):
    """Distant mountains on the open sky, panning with heading; only on byte columns clear of track."""
    s = (fr.hc * 2) & 255; split = fr.split
    for y in range(max(TOPROW, split - SKYL_H), split):
        h = split - y; cl, cr = fr.CL[y], fr.CR[y]
        if cl == 255: js = list(range(32))
        else:
            nl = 0 if cl < 64 else min(32, (cl - 64) >> 2)
            st = 0 if cr < 64 else ((cr - 64) >> 2) + 1
            js = list(range(nl)) + list(range(st, 32))
        for j in js:
            img[y * 32 + j] = sum(sky_pix(s + 4 * j + p, h) << (6 - 2 * p) for p in range(4))
SU_A, SU_B, RL_A, RL_B, SK = 0, 4, 1, 7, 5
BOOST_A, BOOST_B = 7, 1
VOID, HAZE = 2, 8

# ------------------------------------------------------------- track
def build_track():
    """Per-section heading H (u8), climb DY (s8, e per section), half-width
    vector (HBX, HBY) for the bank, and flags (bit0 gate)."""
    pieces = [  # length, turn (rad/section), pitch target (rad), bank gain
        (24, 0.000, 0.00), (20, 0.050, 0.00), (14, 0.000, 0.14), (14, 0.000, -0.16),
        (26, -0.055, 0.00), (16, 0.000, 0.00), (22, 0.035, -0.09), (18, -0.040, 0.11),
        (20, 0.000, -0.10), (30, 0.060, 0.04), (16, 0.000, 0.00), (24, -0.045, -0.06),
        (18, 0.000, 0.12), (14, 0.000, -0.12), (28, 0.050, 0.00), (20, -0.030, 0.05),
    ]
    turns, pitches = [], []
    i = 0
    while len(turns) < N:
        L, t, p = pieces[i % len(pieces)]; i += 1
        turns += [t] * L; pitches += [p] * L
    turns, pitches = turns[:N], pitches[:N]
    total = sum(turns)
    corr = (2 * math.pi - total) / N          # make the loop close in heading: total turn = one revolution
    H, DY, HBX, HBY, FL = [], [], [], [], []
    h = 0.0; p = 0.0; b = 0.0
    for k in range(N):
        t = turns[k] + corr
        p += (pitches[k] - p) * 0.10
        b += (-t * 4.5 - b) * 0.10             # bank into the turn (outside edge rises)
        H.append(round(h * 256 / (2 * math.pi)) & 255)
        DY.append(max(-40, min(40, round(SEGE * math.sin(p)))))
        HBX.append(round(HWE * math.cos(b)))
        HBY.append(round(HWE * math.sin(b)))
        FL.append(1 if k % 16 == 0 else 0)
        h += t
    return dict(H=H, DY=DY, HBX=HBX, HBY=HBY, FL=FL)

# ------------------------------------------------------------- helpers
def expt_or(d):
    return 0 if d < 0 else (127 if d > 511 else EXPT[d])

def logm(v):
    return LOGT[min(v, 2047)]

def pxof(v, lz, lf):
    if v == 0: return 0
    m = min(abs(v), 2047)
    e = expt_or(LOGT[m] - lz + lf + BIAS)
    return e if v > 0 else -e

LOD1, LOD2 = 6, 12          # every section up to LOD1, every 2nd up to LOD2, every 4th beyond
SKIRT_ON = False
HALF_ON = True
HALFROW = 36              # screen rows >= HALFROW are built every second row

def is_lod(depth, k):
    if depth < LOD1: return True
    if depth < LOD2: return (k & 1) == 0
    return (k & 3) == 0

# ------------------------------------------------------------- renderer
def transform(T, st):
    """Returns cross-sections: list of dict(k, L=(x,y,z), R=(x,y,z))."""
    i, f, lat, theta = st['i'], st['f'], st['lat'], st['theta']
    hc = (T['H'][i % N] + theta) & 255
    X = -lat
    Z = -(f >> 2)
    Y = -CH - (((f >> 1) * T['DY'][i % N]) >> 7)
    out = []
    k = i
    for depth in range(DEPTH + 1):
        idx = k % N
        d = (T['H'][idx] - hc) & 255
        if is_lod(depth, k):
            hbx = T['HBX'][idx]; hby = T['HBY'][idx]
            ox = mul8(hbx, COS64[d]) >> 6
            oz = -(mul8(hbx, SIN64[d]) >> 6)
            out.append(dict(k=k, L=(X - ox, Y - hby, Z - oz), R=(X + ox, Y + hby, Z + oz)))
        X += SIN64[d]; Z += COS64[d]; Y += T['DY'][idx]
        X = ((X + 32768) & 0xFFFF) - 32768
        Z = ((Z + 32768) & 0xFFFF) - 32768
        Y = ((Y + 32768) & 0xFFFF) - 32768
        k += 1
    return out

def project(p, hz):
    x, y, z = p
    lz = logm(z)
    px = max(-127, min(127, pxof(x, lz, LOGFX)))
    py = pxof(y, lz, LOGFY)
    sx = 128 + px
    sy = max(0, min(255, 64 + hz - py))
    return sx, sy

def clip_point(n, f):
    """Point on segment n->f (n behind the near plane) at z = NEARZ."""
    num = NEARZ - n[2]; den = f[2] - n[2]
    t = min(127, (num * 128) // den)
    dx = max(-128, min(127, f[0] - n[0])); dy = max(-128, min(127, f[1] - n[1]))
    return (n[0] + (mul8(dx, t) >> 7), n[1] + (mul8(dy, t) >> 7), NEARZ)

class Frame:
    def __init__(self):
        self.lists = [[0] * 32 for _ in range(64)]
        self.LP = [16] * 64; self.RP = [16] * 64
        self.CL = [255] * 64; self.CR = [0] * 64
        self.start = [16] * 64
        self.gates = []
        self.XMIN = [255] * 256; self.XMAX = [0] * 256
        self.TMIN = [0] * 256; self.TMAX = [0] * 256

def render(T, st, sky=SKY_A, sky_line=True):
    fr = Frame()
    fr.sky_line = sky_line
    fr.hc = (T['H'][st['i'] % N] + st['theta']) & 255
    hz = HORIZ + ((T['DY'][st['i'] % N] * 7) >> 4)
    secs = transform(T, st)
    ytop = 200
    for j in range(len(secs) - 1):
        A, B = secs[j], secs[j + 1]
        LA, RA, LB, RB = A['L'], A['R'], B['L'], B['R']
        if LB[2] < NEARZ or RB[2] < NEARZ: continue
        if LA[2] < NEARZ: LA = clip_point(LA, LB)
        if RA[2] < NEARZ: RA = clip_point(RA, RB)
        zm = (LA[2] + RA[2]) >> 1
        lzm = logm(zm)
        rw = max(1, min(40, expt_or(LOGT[RAIL_E] - lzm + LOGFX + BIAS)))
        s = min(40, expt_or(LOGT[SKIRT_E] - lzm + LOGFY + BIAS)) if SKIRT_ON else 0
        P = [project(LA, hz), project(RA, hz), project(RB, hz), project(LB, hz)]
        if A['k'] % 16 == 0 and A['L'][2] >= NEARZ and A['R'][2] >= NEARZ:
            if max(P[0][1], P[1][1]) <= ytop + 1:
                fr.gates.append(dict(P0=P[0], P1=P[1],
                    h=expt_or(LOGT[GATEH_E] - lzm + LOGFY + BIAS),
                    w=max(1, expt_or(LOGT[GATEW_E] - lzm + LOGFX + BIAS)),
                    t=max(1, expt_or(LOGT[GATET_E] - lzm + LOGFY + BIAS))))
        top = strip(fr, P, rw, s, A['k'])
        if top is not None: ytop = min(ytop, top)
    if HALF_ON: duplicate_rows(fr)
    finalise(fr, hz, sky)
    return fr, hz

def upd(fr, y, x, tag):
    x = max(63, min(192, x))
    if x < fr.XMIN[y]: fr.XMIN[y] = x; fr.TMIN[y] = tag
    if x > fr.XMAX[y]: fr.XMAX[y] = x; fr.TMAX[y] = tag

def strip(fr, P, rw, s, k):
    ys = [p[1] for p in P]
    ymin, ymax = min(ys), max(ys)
    yr0, yr1 = max(ymin, 64 + TOPROW), min(ymax + s, 127)
    if yr0 > yr1: return None
    ya0, ya1 = max(ymin, 64 + TOPROW - s), min(ymax, 127)
    for y in range(ya0, ya1 + 1):
        fr.XMIN[y] = 255; fr.XMAX[y] = 0
    for e in range(4):
        (xa, ya), (xb, yb) = P[e], P[(e + 1) & 3]
        if ya == yb:
            if ya0 <= ya <= ya1:
                upd(fr, ya, xa, e); upd(fr, ya, xb, e)
            continue
        if ya > yb: xa, ya, xb, yb = xb, yb, xa, ya
        dy = yb - ya; dx = xb - xa
        if dy == 1:
            if ya0 <= ya <= ya1: upd(fr, ya, xa, e)
            if ya0 <= yb <= ya1: upd(fr, yb, xb, e)
            continue
        if dx == 0: slope = 0
        else:
            d2 = max(0, min(1023, LOGT[abs(dx)] - LOGT[dy] + 512))
            slope = EXP88[d2] if dx > 0 else -EXP88[d2]
        x88 = (xa << 8) + 128
        for y in range(ya, yb + 1):
            if y > ya1: break
            if y >= ya0: upd(fr, y, x88 >> 8, e)
            x88 = (x88 + slope) & 0xFFFF
    su = SU_A if ((k >> 2) & 1) == 0 else SU_B
    if (k & 126) == 40: su = BOOST_A if (k & 1) == 0 else BOOST_B    # boost pad: two glowing sections every 128
    rl = RL_B if ((k >> 1) & 1) else RL_A
    top = None
    for y in range(yr0, yr1 + 1):
        if HALF_ON and y >= 64 + HALFROW and (y & 1): continue
        sv = ymin <= y <= ymax and fr.XMIN[y] <= fr.XMAX[y]
        ky = y - s
        kv = s > 0 and ymin <= ky <= ymax and ky >= ya0 and fr.XMIN[ky] <= fr.XMAX[ky]
        if not sv and not kv: continue
        par = 16 if y & 1 else 0
        runs = []
        if sv:
            Sa, Sb = fr.XMIN[y], fr.XMAX[y]
            railL = fr.TMIN[y] == 3; railR = fr.TMAX[y] == 1
            a, b = Sa, Sb
            if kv:
                Ka, Kb = fr.XMIN[ky], fr.XMAX[ky]
                a, b = min(a, Ka), max(b, Kb)
                if Ka < Sa: runs.append((Ka, SK + par))
            l1 = Sa + rw if railL else Sa
            if l1 > Sb + 1: l1 = Sb + 1
            r1 = Sb - rw + 1 if railR else Sb + 1
            if r1 < l1: r1 = l1
            if railL: runs.append((Sa, rl + par))
            if l1 < r1: runs.append((l1, su + par))
            if railR and r1 <= Sb: runs.append((r1, rl + par))
            if kv and Kb > Sb: runs.append((Sb + 1, SK + par))
        else:
            a, b = fr.XMIN[ky], fr.XMAX[ky]
            runs = [(a, SK + par)]
        a, b = max(a, 64), min(b, 191)
        if a > b: continue
        while len(runs) > 1 and runs[1][0] <= 64: runs.pop(0)
        runs[0] = (max(runs[0][0], 64), runs[0][1])
        runs = [r for r in runs if r[0] <= b]
        cover(fr, y - 64, runs, a, b)
        top = y if top is None else min(top, y)
    return top

def cover(fr, r, runs, a, b):
    L = fr.lists[r]
    if fr.CL[r] == 255:
        for x, c in runs:
            if fr.RP[r] <= 27:
                L[fr.RP[r]] = x - 64; L[fr.RP[r] + 1] = c; fr.RP[r] += 2
        fr.CL[r] = a; fr.CR[r] = b
        return
    if a < fr.CL[r]:
        left = [(x, c) for (x, c) in runs if x < fr.CL[r]]
        for x, c in reversed(left):
            if fr.LP[r] >= 4:
                fr.LP[r] -= 2; L[fr.LP[r]] = x - 64; L[fr.LP[r] + 1] = c
        fr.CL[r] = a
    if b > fr.CR[r]:
        cr1 = fr.CR[r] + 1
        c0 = runs[0][1]
        for x, c in runs:
            if x <= cr1: c0 = c
        app = [(cr1, c0)] + [(x, c) for (x, c) in runs if x > cr1]
        for x, c in app:
            if fr.RP[r] <= 27:
                L[fr.RP[r]] = x - 64; L[fr.RP[r] + 1] = c; fr.RP[r] += 2
        fr.CR[r] = b

def duplicate_rows(fr):
    """Odd rows in the half-rate region copy the row above, dither phase flipped."""
    for r in range(HALFROW + 1, 64, 2):
        q = r - 1
        fr.CL[r], fr.CR[r], fr.LP[r], fr.RP[r] = fr.CL[q], fr.CR[q], fr.LP[q], fr.RP[q]
        if fr.CL[q] == 255: continue
        for i in range(fr.LP[q], fr.RP[q], 2):
            fr.lists[r][i] = fr.lists[q][i]
            fr.lists[r][i + 1] = fr.lists[q][i + 1] + 16

def sky_colour(r, split, sky):
    """Rows TOPROW.. : sky bands 2..4 spread down to the horizon, then haze, then void."""
    if r < split: return sky[2 + ((r - TOPROW) * 3) // (split - TOPROW)]
    return HAZE if r < split + 2 else VOID

def sky_top(sky):
    """Static sky image for rows 0..TOPROW-1 (bands 0 and 1)."""
    img = []
    for r in range(TOPROW):
        c = sky[0] if r < TOPROW // 2 else sky[1]
        img += [(PATO if r & 1 else PATE)[c]] * 32
    return img

def finalise(fr, hz, sky):
    split = max(0, min(63, hz))
    fr.split = split
    fr.sky = sky
    for r in range(TOPROW, 64):
        par = 16 if r & 1 else 0
        bg = sky_colour(r, split, sky) + par
        L = fr.lists[r]
        if fr.CL[r] == 255:
            L[14] = 0; L[15] = bg; L[16] = 128; fr.start[r] = 14
            continue
        if fr.CL[r] > 64:
            fr.LP[r] -= 2; L[fr.LP[r]] = 0; L[fr.LP[r] + 1] = bg
        if fr.CR[r] < 191:
            L[fr.RP[r]] = fr.CR[r] + 1 - 64; L[fr.RP[r] + 1] = bg; fr.RP[r] += 2
        L[fr.RP[r]] = 128
        fr.start[r] = fr.LP[r]

def compose(fr):
    """2048 screen bytes, exactly as COMP2 writes them."""
    img = sky_top(fr.sky)
    for r in range(TOPROW, 64):
        L = fr.lists[r]; i = fr.start[r]
        runs = []
        while True:
            x = L[i]
            if x == 128: break
            runs.append((x, L[i + 1])); i += 2
        pix = [0] * 128
        for n, (x, c) in enumerate(runs):
            x1 = runs[n + 1][0] if n + 1 < len(runs) else 128
            P = PATO if c >= 16 else PATE
            for xx in range(x, max(x, x1)): pix[xx] = (c & 15, P)
        for j in range(32):
            b = 0
            for q in range(4):
                c, P = pix[j * 4 + q]
                b |= P[c] & (0xC0 >> (2 * q))
            img.append(b)
    if fr.sky_line: skyline(img, fr)
    return img

def fill_rect(img, x0, x1, y0, y1, colour=3):
    """Solid rectangle (screen coords, inclusive) in pattern colour 3."""
    x0, x1 = max(0, x0), min(127, x1); y0, y1 = max(0, y0), min(63, y1)
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            i = y * 32 + (x >> 2); sh = 6 - 2 * (x & 3)
            img[i] = (img[i] & ~(3 << sh) & 0xFF) | (colour << sh)

def draw_gates(img, fr):
    for g in reversed(fr.gates):
        (x0, y0), (x1, y1) = g['P0'], g['P1']
        for (x, y) in ((x0, y0), (x1, y1)):
            xl = x - 64 - (g['w'] >> 1)
            fill_rect(img, xl, xl + g['w'] - 1, y - 64 - g['h'], y - 64 - 1)
        yb = min(y0, y1) - 64 - g['h']
        fill_rect(img, min(x0, x1) - 64, max(x0, x1) - 64, yb, yb + g['t'] - 1)

if __name__ == '__main__':
    from PIL import Image
    T = build_track()
    CSS0 = [(40, 205, 40), (235, 235, 70), (45, 35, 205), (205, 30, 60)]
    frames = []
    pos = 0; v = 0; lat = 0
    for n in range(200):
        v = min(110, v + 2); pos += v * 3
        i, f = pos >> 8, pos & 255
        curv = ((T['H'][(i + 3) % N] - T['H'][i % N] + 128) & 255) - 128
        lat += ((-curv * 2) - lat) // 8
        st = dict(i=i, f=f, lat=lat, theta=0)
        fr, hz = render(T, st)
        img = compose(fr); draw_gates(img, fr)
        im = Image.new('RGB', (128, 64))
        im.putdata([CSS0[(img[y * 32 + x // 4] >> (6 - 2 * (x % 4))) & 3] for y in range(64) for x in range(128)])
        frames.append(im.resize((512, 384), Image.NEAREST))
    frames[0].save('ref3.gif', save_all=True, append_images=frames[1:], duration=60, loop=0)
    print('ok', len(frames))
