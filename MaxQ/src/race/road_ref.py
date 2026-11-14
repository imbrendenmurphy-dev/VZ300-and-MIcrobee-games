#!/usr/bin/env python3
"""
road_ref.py - exact integer model of the MAX Q raster road (v0.11).  VIBED BY BPM 2026

The road is not 3D geometry.  Each screen row below the horizon is one fixed
"depth slot" d (1 = far .. 32 = near) with a fixed width.  Per frame, walking
from the near row to the far row:
    curve:  dx += CURV[section];  x += dx        (road centre slides sideways)
    hill:   dh += SLP[section] - SLP[here];  h += dh   (rows squeeze / stretch)
The light/dark bands come from the section number at each row, so they flow
down the road as the craft moves.  The Z80 code mirrors every step.
"""
import math
import ref3 as R

N = 512
TOPROW = R.TOPROW
HZ0 = 31                    # row d sits on screen row HZ0 + d on flat ground
ND = 32
ZK = 54 * 256               # slot d is ZK / d (1/256 section) from the eye, which sits 2 sections behind the craft
ZOFF = 256                  # ... and one section behind the game camera (the craft lands on d = 27)
YMIN = TOPROW + 4
ZT = [0] + [ZK // d - ZOFF for d in range(1, ND + 1)]
WT = [0] + [max(2, round(d * 1.875)) for d in range(1, ND + 1)]        # road half-width (px)
RWT = [0] + [max(1, round(WT[d] / 6)) for d in range(1, ND + 1)]       # rumble strip width
WSPR = [0] + [max(1, round(d * 15 / 16)) for d in range(1, ND + 1)]    # craft width at slot d
DIDX = [max(1, min(ND, round(ZK / (i * 16 + 8 + ZOFF)))) for i in range(256)]     # slot of an object zo/16 ahead of the camera

# colour ids used in the row lists; two pattern pages give the two band phases
G_ID, R_ID, C_ID, PAD_ID, PAD2_ID, RAMP_ID, RAMP2_ID, LINE_ID = 0, 1, 2, 3, 4, 5, 6, 7
BAND0 = {G_ID: 0, R_ID: 3, C_ID: 2, PAD_ID: 7, PAD2_ID: 1, RAMP_ID: 3, RAMP2_ID: 5, LINE_ID: 9}
BAND1 = {G_ID: 6, R_ID: 1, C_ID: 10, PAD_ID: 7, PAD2_ID: 1, RAMP_ID: 3, RAMP2_ID: 5, LINE_ID: 9}
def page(band):
    ev = [R.PATE[band.get(i, 2)] for i in range(16)]
    od = [R.PATO[band.get(i, 2)] for i in range(16)]
    return ev + od
PAGE0, PAGE1 = page(BAND0), page(BAND1)
STDPAGE = R.PATE + R.PATO

def s8(v): return max(-127, min(127, int(round(v))))

def build_track():
    T = R.build_track()
    pieces = [
        (24, 0.000, 0.00), (20, 0.050, 0.00), (14, 0.000, 0.14), (14, 0.000, -0.16),
        (26, -0.055, 0.00), (16, 0.000, 0.00), (22, 0.035, -0.09), (18, -0.040, 0.11),
        (20, 0.000, -0.10), (30, 0.060, 0.04), (16, 0.000, 0.00), (24, -0.045, -0.06),
        (18, 0.000, 0.12), (14, 0.000, -0.12), (28, 0.050, 0.00), (20, -0.030, 0.05),
    ]
    turns, pit = [], []
    i = 0
    while len(turns) < N:
        L, t, p = pieces[i % len(pieces)]; i += 1
        turns += [t] * L; pit += [p] * L
    turns, pit = turns[:N], pit[:N]
    c = 0.0; p = 0.0; CURV, SLP = [], []
    for k in range(N):
        c += (turns[k] - c) * 0.30          # ease into and out of bends
        p += (pit[k] - p) * 0.12
        CURV.append(s8(c * 420))
        SLP.append(s8(p * 95))
    T['CURV'] = [v & 255 for v in CURV]; T['SLP'] = [v & 255 for v in SLP]
    return T

def sx(v): return v - 256 if v & 128 else v
def s16(v): v &= 0xFFFF; return v - 65536 if v & 0x8000 else v

class Frame: pass

def road(T, cam_i, cam_f, lat):
    """Per-slot tables and the row map, exactly as RD_BUILD computes them."""
    fr = Frame()
    fr.XC = [0] * (ND + 1); fr.CX = [0] * (ND + 1); fr.YOF = [0] * (ND + 1); fr.TOPV = [0] * (ND + 1)
    fr.SEC = [0] * (ND + 1); fr.ROWMAP = [0] * 64
    P = ((cam_i & 255) << 8) | cam_f; hi = cam_i >> 8
    s0 = sx(T['SLP'][cam_i])
    dx = x = dh = h = 0
    LX = s16(-lat * 256); lstep = s16(lat * 8)
    top = 64
    for d in range(ND, 0, -1):
        s = P + ZT[d]
        k = ((s >> 8) + (hi << 8)) & 511
        fr.SEC[d] = k
        fr.CX[d] = sx((x >> 8) & 255)
        fr.XC[d] = (128 + (s16(x + LX) >> 8)) & 255
        y = HZ0 + d - (h >> 10)
        fr.YOF[d] = y & 255; fr.TOPV[d] = top
        if y < top:
            if y < YMIN: y = YMIN
            for r in range(y, top): fr.ROWMAP[r] = d
            top = y
        dx = s16(dx + sx(T['CURV'][k])); x = s16(x + dx)
        dh = s16(dh + sx(T['SLP'][k]) - s0); h = s16(h + dh)
        LX = s16(LX + lstep)
    fr.split = top
    return fr

def road_id(k):
    if k & 126 == 40: return PAD_ID if k & 1 == 0 else PAD2_ID
    if k & 254 == 228: return RAMP_ID if k & 1 == 0 else RAMP2_ID
    if k == 0: return LINE_ID
    return C_ID

def row_list(fr, r):
    """(runs, page) for a road row: runs = [(x, id)], x strictly increasing from 0."""
    d = fr.ROWMAP[r]; k = fr.SEC[d]
    cx = fr.XC[d]; w = WT[d]; rw = RWT[d]
    b = [cx - w - rw, cx - w, cx + w, cx + w + rw]
    b = [max(64, min(192, v)) - 64 for v in b]
    cols = [G_ID, R_ID, road_id(k), R_ID, G_ID]
    runs = [[0, cols[0]]]
    for i in range(4):
        if b[i] >= 128: break
        if b[i] == runs[-1][0]: runs[-1][1] = cols[i + 1]
        else: runs.append([b[i], cols[i + 1]])
    return runs, (PAGE1 if (k >> 1) & 1 else PAGE0)

def sky_colour(r, split, sky):
    return sky[2 + ((r - TOPROW) * 3) // (split - TOPROW)]

def compose(T, st, sky=R.SKY_A, sky_line=True):
    fr = road(T, st['i'], st['f'], st['lat'])
    img = R.sky_top(sky)
    for r in range(TOPROW, 64):
        par = 16 if r & 1 else 0
        if r < fr.split:
            img += [STDPAGE[sky_colour(r, fr.split, sky) + par]] * 32
            continue
        runs, pg = row_list(fr, r)
        px = []
        for i, (x, c) in enumerate(runs):
            x1 = runs[i + 1][0] if i + 1 < len(runs) else 128
            byte = pg[c + par]
            px += [(byte >> (6 - 2 * (xx & 3))) & 3 for xx in range(x, x1)]
        img += [px[j] << 6 | px[j + 1] << 4 | px[j + 2] << 2 | px[j + 3] for j in range(0, 128, 4)]
    if sky_line:
        f = Frame(); f.split = fr.split; f.CL = [255] * 64; f.CR = [255] * 64
        h0 = T['H'][st['i']]; h1 = T['H'][(st['i'] + 1) & 511]
        f.hc = (h0 + ((sx((h1 - h0) & 255) * (st['f'] >> 1) * 2) >> 8)) & 255
        R.skyline(img, f)
    return img, fr

if __name__ == '__main__':
    import sys
    from PIL import Image
    T = build_track()
    P0 = [(0, 224, 0), (240, 240, 64), (32, 48, 224), (224, 40, 32)]
    frames = []
    pos = 0; lat = 0.0
    for n in range(260):
        i, f = (pos >> 8) & 511, pos & 255
        tgt = -3 * sx((T['H'][(i + 4) & 511] - T['H'][i]) & 255)
        lat += max(-3, min(3, tgt - lat))
        img, fr = compose(T, dict(i=i, f=f, lat=int(lat)))
        im = Image.new('RGB', (128, 64)); px = im.load()
        for y in range(64):
            for xb in range(32):
                b = img[y * 32 + xb]
                for q in range(4): px[xb * 4 + q, y] = P0[(b >> (6 - 2 * q)) & 3]
        frames.append(im.resize((512, 256), Image.NEAREST))
        pos += 110        # 55/256 section per field, 2 fields per frame
    frames[0].save(sys.argv[1], save_all=True, append_images=frames[1:], duration=40, loop=0)
    W = Image.new('RGB', (1024, 768))
    for j, n in enumerate((0, 40, 70, 100, 130, 180)): W.paste(frames[n], ((j % 2) * 512, (j // 2) * 256))
    W.save(sys.argv[2])
