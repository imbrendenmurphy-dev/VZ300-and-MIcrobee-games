"""Pack sprites: scaled levels, 2 pre-shifted phases.
Scenery: colour 2 transparent (mask tables in bank 3).
Cars / player car: explicit (mask, data) byte pairs."""
import math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import art

NLEV = 12
WREF = 96.0
COMMON = 0xD400
SCENERY = 0xCC00

def level_of_w(w):
    if w < 3: return 255
    L = int(round(math.log(w / WREF) / math.log(0.7)))
    return max(0, min(NLEV - 1, L))

def pix(c): return {'G': 0, 'Y': 1, 'B': 2, 'R': 3}.get(c, None)

def layout(rows):
    W = max(len(r) for r in rows); H = len(rows)
    wb = int(math.ceil(1 + W / 4.0))
    o0 = 2 * (wb - 1) - W // 2
    if o0 & 1: o0 -= 1
    return W, H, wb, max(0, o0)

def enc_trans(rows):
    W, H, wb, o0 = layout(rows)
    out = bytearray([wb, H, (wb * H) & 255, (wb * H) >> 8])
    for ph in (0, 2):
        for r in rows:
            line = [2] * (wb * 4)
            for x, c in enumerate(r):
                v = pix(c)
                if v is not None and v != 2:
                    p = x + o0 + ph
                    if p < wb * 4: line[p] = v
            for b in range(wb):
                v = 0
                for i in range(4): v = (v << 2) | line[b * 4 + i]
                out.append(v)
    return bytes(out)

def enc_masked(rows, phases=(0, 2)):
    W, H, wb, o0 = layout(rows)
    out = bytearray([wb, H, (wb * H * 2) & 255, (wb * H * 2) >> 8])
    for ph in phases:
        for r in rows:
            line = [None] * (wb * 4)
            for x, c in enumerate(r):
                v = pix(c)
                if v is not None:
                    p = x + o0 + ph
                    if p < wb * 4: line[p] = v
            for b in range(wb):
                m = 0; d = 0
                for i in range(4):
                    v = line[b * 4 + i]
                    m <<= 2; d <<= 2
                    if v is None: m |= 3
                    else: d |= v
                out += bytes([m, d])
    return bytes(out)

def levels(rows, h0, enc, min_px=2):
    """frames for levels 0..11 of an object whose height at w=96 is h0 px"""
    Hm = len(rows)
    frames = {}
    L0 = None
    for L in range(NLEV):
        f = (0.7 ** L) * h0 / Hm
        if f > 1.05: continue
        if L0 is None: L0 = L
        sr = art.scale_rows(rows, f)
        if len(sr) < min_px or max(len(r) for r in sr) < 2: break
        frames[L] = enc(sr)
    return L0, frames

class Blob:
    def __init__(s, base): s.base = base; s.data = bytearray(); s.cache = {}
    def add(s, b):
        if b in s.cache: return s.cache[b]
        a = s.base + len(s.data); s.data += b; s.cache[b] = a; return a
    def here(s): return s.base + len(s.data)

def common():
    """upper bank 0 from COMMON: CAR_LV (3 types x 2 frames x 12 levels),
    PCAR_TAB (32 pointers), frames"""
    hdr = 144 + 64
    blob = Blob(COMMON + hdr)
    carlv = bytearray(144)
    for t in range(3):
        f0, f1 = art.traffic_frames(t)
        for fi, fr in enumerate((f0, f1)):
            L0, frames = levels(fr, 31 * 12 / 28.0, enc_masked)
            for L in range(NLEV):
                src = frames.get(max(L, L0)) if L >= L0 else frames.get(L0)
                if L > max(frames) if frames else True: src = None
                if fi == 1 and L >= 3: src = None   # far: share frame 0
                a = blob.add(src) if src else 0
                if fi == 1 and L >= 3:
                    a = carlv[t * 48 + L * 2] | carlv[t * 48 + L * 2 + 1] << 8
                carlv[t * 48 + fi * 24 + L * 2] = a & 255
                carlv[t * 48 + fi * 24 + L * 2 + 1] = a >> 8
    ptab = bytearray(64)
    pf = art.player_frames()
    for i, fr in enumerate(pf):
        a = blob.add(enc_masked(fr, phases=(0,)))
        ptab[i * 2] = a & 255; ptab[i * 2 + 1] = a >> 8
    # 20 = brake overlay (rows 5-8), 21..24 dust (rows 9-13)
    br = art.brake_overlay()[5:9]
    a = blob.add(enc_masked(br, phases=(0,)))
    ptab[40] = a & 255; ptab[41] = a >> 8
    for k, d in enumerate(art.dust_overlays()):
        a = blob.add(enc_masked(d[9:14], phases=(0,)))
        ptab[42 + k * 2] = a & 255; ptab[43 + k * 2] = a >> 8
    data = bytes(carlv) + bytes(ptab) + bytes(blob.data)
    return data

LEG_SCENERY = [
    ['palm', 'bush', 'chevl', 'chevr', 'lighthouse', 'rock', 'sign', 'grass'],
    ['rock', 'bush', 'grass', 'chevl', 'chevr', 'sign', 'gum', 'cactus'],
    ['gum', 'bush', 'palm', 'chevl', 'chevr', 'rock', 'sign', 'grass'],
    ['pine', 'snowrock', 'chevl', 'chevr', 'sign', 'bush', 'rock'],
    ['lamp', 'lampr', 'tower', 'sign', 'chevl', 'chevr', 'palm', 'bush'],
]
SOLID = {'palm': 1, 'gum': 1, 'rock': 1, 'lighthouse': 1, 'sign': 1, 'pine': 1,
         'snowrock': 1, 'lamp': 1, 'lampr': 1, 'tower': 1, 'cactus': 1}

def scenery(leg):
    names = LEG_SCENERY[leg]
    hdr = 16 * 24
    blob = Blob(SCENERY + hdr)
    tab = bytearray(hdr)
    for t, nm in enumerate(names):
        h0, rows = art.SCEN[nm]
        L0, frames = levels(rows, h0, enc_trans)
        last = max(frames)
        for L in range(NLEV):
            if L > last: a = 0
            else: a = blob.add(frames[max(L, L0)])
            tab[t * 24 + L * 2] = a & 255; tab[t * 24 + L * 2 + 1] = a >> 8
    data = bytes(tab) + bytes(blob.data)
    solid = bytes([SOLID.get(nm, 0) for nm in names] + [0] * (16 - len(names)))
    return data, solid

if __name__ == '__main__':
    c = common()
    print('common', len(c), hex(COMMON + len(c)))
    for leg in range(5):
        d, s = scenery(leg)
        print('scenery', leg, len(d), hex(SCENERY + len(d)))
