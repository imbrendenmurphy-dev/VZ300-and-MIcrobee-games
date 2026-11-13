# gfx.py - shared art helpers for Dracula's Castle II (VZ300 mode 1)
import math, random
from PIL import Image

PAL = [(7,255,0),(255,255,0),(59,8,255),(204,0,59),(255,255,255),(7,227,153),(255,28,255),(255,129,0)]
BAYER4 = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]
BAYER8 = None
def _b8():
    b = [[0]*8 for _ in range(8)]
    for y in range(8):
        for x in range(8):
            v = 0
            xx, yy = x, y ^ x
            for bit in range(3):
                v = (v << 2) | (((yy >> bit) & 1) << 1) | ((xx >> bit) & 1)
            # standard bayer via recursion instead
    m = [[0]]
    for _ in range(3):
        n = len(m); mm = [[0]*(2*n) for _ in range(2*n)]
        for y in range(n):
            for x in range(n):
                v = m[y][x]*4
                mm[y][x] = v; mm[y][x+n] = v+2; mm[y+n][x] = v+3; mm[y+n][x+n] = v+1
        m = mm
    return m
BAYER8 = _b8()

def lin(c): return [((v/255.0)**2.2) for v in c]

class Quant:
    """pattern-dither quantiser to a 4-colour palette"""
    def __init__(self, css, allowed_pairs=None):
        self.cols = PAL[css*4:css*4+4]
        self.lc = [lin(c) for c in self.cols]
        self.cache = {}
        self.pairs = allowed_pairs
    def pick(self, rgb, x, y, levels=16):
        key = (int(rgb[0])>>2, int(rgb[1])>>2, int(rgb[2])>>2)
        if key in self.cache: a, b, t = self.cache[key]
        else:
            tl = lin(rgb); best = None
            for a in range(4):
                for b in range(a, 4):
                    if self.pairs and (a, b) not in self.pairs and a != b: continue
                    la, lb = self.lc[a], self.lc[b]
                    for k in range(levels+1):
                        t = k/levels
                        m = [la[i]*(1-t)+lb[i]*t for i in range(3)]
                        # perceptual-ish weighting on gamma-encoded values
                        e = sum(((m[i]**(1/2.2)) - (tl[i]**(1/2.2)))**2 * w for i, w in enumerate((0.30, 0.59, 0.11)))
                        e += 0.004 * (min(t, 1-t))  # slight preference for solid colours
                        if best is None or e < best[0]: best = (e, a, b, t)
            _, a, b, t = best
            self.cache[key] = (a, b, t)
        th = (BAYER4[y & 3][x & 3] + 0.5) / 16.0
        return b if t > th else a

def mixc(c1, c2, t):
    return tuple(c1[i]*(1-t)+c2[i]*t for i in range(3))

def to_bytes_rect(img, x0, y0, wbytes, h):
    """img: dict/2D list of colour indices (row major), returns bytes of rect starting at byte column x0"""
    out = []
    for y in range(y0, y0+h):
        for xb in range(x0, x0+wbytes):
            v = 0
            for i in range(4):
                v = (v << 2) | (img[y][xb*4+i] & 3)
            out.append(v)
    return bytes(out)

def show(pix, css, scale=4, path=None):
    h = len(pix); w = len(pix[0])
    im = Image.new('RGB', (w, h))
    p = im.load()
    for y in range(h):
        for x in range(w):
            v = pix[y][x]
            p[x, y] = (40, 40, 40) if v < 0 else PAL[css*4+v]
    im = im.resize((w*scale, h*scale*3//2), Image.NEAREST)
    if path: im.save(path)
    return im

# ---------------- LZ compression ----------------
# format: control byte c:
#   c < $80 : literal run of c+1 bytes follow
#   c >= $80: match: length = (c & $7F) + 3 (3..130), next byte = offset-1 (1..256)
#   c == $FF with next 0..? we reserve: c=$FF -> end marker (so max match len = 129)
def lz_compress(data):
    data = bytes(data)
    out = bytearray(); lit = bytearray(); i = 0; n = len(data)
    def flush():
        nonlocal lit
        while lit:
            chunk = lit[:128]; lit = lit[128:]
            out.append(len(chunk)-1); out.extend(chunk)
    while i < n:
        best_len = 0; best_off = 0
        for off in range(1, min(256, i)+1):
            l = 0
            while l < 129 and i+l < n and data[i+l] == data[i+l-off]: l += 1
            if l > best_len: best_len, best_off = l, off
        if best_len >= 3:
            flush()
            out.append(0x80 | (best_len-3)); out.append(best_off-1)
            i += best_len
        else:
            lit.append(data[i]); i += 1
    flush()
    out.append(0xFF)
    return bytes(out)

def lz_decompress(c):
    out = bytearray(); i = 0
    while True:
        b = c[i]; i += 1
        if b == 0xFF: break
        if b < 0x80:
            out += c[i:i+b+1]; i += b+1
        else:
            l = (b & 0x7F)+3; off = c[i]+1; i += 1
            for _ in range(l): out.append(out[-off])
    return bytes(out)
