#!/usr/bin/env python3
"""
mktraffic.py - rival car sprites for BEELINE -> build/traffic.inc (+ preview PNG)
ViBED by BPM 2026

The rival car is rendered from the same 3D model as the player's car, straight
on from behind, at NSCALE sizes (screen pixels wide).  For each size there are
4 pre-shifted copies (0, 2, 4, 6 px to the right) because the chunky logical
pixel is 2 screen pixels wide.

Each copy is stored as vertical strips, one per 8-pixel column, of
(notmask, ink) byte pairs per screen line, separated by 16 transparent lines:

    pad(16) col0(H) pad(16) col1(H) pad(16) ...

so a character cell at ANY vertical offset is just a pointer into the strip
(no shifting at run time):  line j of column c is at
    base + 2 * (16 + c * (H + 16) + j),   j = -15 .. H + 14

SCALETAB, 32 bytes per size:
    +0 W (px)   +1 H (lines)   +2 NC (columns incl. shift spill)
    +3 light line (0 = none)   +4,5 column stride (bytes)
    +6..13 base of the 4 shifted copies
    +14..21 per shift: columns that are solid car at the light line (bit c)
SWSCALE[sw] (sw = road half width in logical px at the car, 0..127) -> size
"""
import math, os, sys
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mkcar

WIDTHS = [6, 10, 14, 20, 26, 34, 44, 56]
CAR_WORLD_W = 74.0          # world units (road is 400 wide)
RW = 200.0

def render(width):
    """car straight from behind, `width` screen px wide -> list of strings"""
    faces = mkcar.render(0)
    xs = [p[0] for f in faces for p in f[1]]
    ys = [p[1] for f in faces for p in f[1]]
    sc = width / (max(xs) - min(xs))
    scy = sc / 1.5
    ox = -min(xs) * sc
    oy = -min(ys) * scy
    Wc = width
    Hc = int(math.ceil((max(ys) - min(ys)) * scy)) + 1
    Hc += Hc & 1
    SS = 4
    img = Image.new('L', (Wc * SS, Hc * SS), 0)
    d = ImageDraw.Draw(img)
    codes = {'K': 1, 'S': 2, 'W': 3, 'G': 4, 'R': 5}
    for depth, pts, code, kind in faces:
        q = [((ox + p[0] * sc) * SS, (oy + p[1] * scy) * SS) for p in pts]
        d.polygon(q, fill=codes[code])
        if kind == 'rear' and code == 'K':
            def lerp(a, b, t): return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            p0, p1, p2, p3 = q
            for t0, t1 in ((0.06, 0.36), (0.64, 0.94)):
                a0 = lerp(lerp(p0, p3, 0.40), lerp(p1, p2, 0.40), t0)
                a1 = lerp(lerp(p0, p3, 0.40), lerp(p1, p2, 0.40), t1)
                b0 = lerp(lerp(p0, p3, 0.75), lerp(p1, p2, 0.75), t0)
                b1 = lerp(lerp(p0, p3, 0.75), lerp(p1, p2, 0.75), t1)
                d.polygon([a0, a1, b1, b0], fill=codes['R'])
    inv = {v: k for k, v in codes.items()}
    px = img.load()
    rows = []
    for y in range(Hc):
        row = ''
        for x in range(Wc):
            cnt = {}
            for yy in range(y * SS, (y + 1) * SS):
                for xx in range(x * SS, (x + 1) * SS):
                    v = px[xx, yy]; cnt[v] = cnt.get(v, 0) + 1
            # small cars: lights win if present at all, so they never vanish
            if 5 in cnt and cnt[5] * 4 >= SS * SS: v = 5
            else: v = max(cnt, key=cnt.get)
            row += inv.get(v, '.')
        rows.append(row)
    while rows and set(rows[-1]) == {'.'}: rows.pop()
    while rows and set(rows[0]) == {'.'}: rows.pop(0)
    if len(rows) & 1: rows.insert(0, '.' * Wc)
    return rows

def ink(c, x, y, width):
    if c == 'R': return 1
    if width < 20:                       # too small for dither: lights only
        return 1 if (c == 'W' and (x + y) % 2 == 0 and width >= 14) else 0
    if c == 'S': return 1 if (x % 2 == 0 and y % 2 == 0) else 0
    if c == 'W': return 1 if (x + y) % 2 == 0 else 0
    if c == 'G': return 1 if (y % 6 == 2 and x % 2 == 0) else 0
    return 0

def main(out):
    L = []
    blobs = []          # (label, bytes)
    tab = []
    previews = []
    total = 0
    for si, w in enumerate(WIDTHS):
        rows = render(w)
        H = len(rows)
        NC = (w + 6 + 7) // 8
        lights = [y for y, r in enumerate(rows) if 'R' in r]
        lline = (lights[len(lights) // 2] if lights else 0)
        bases = []
        lmasks = []
        for sh in range(4):
            x0 = sh * 2
            data = [0xFF, 0x00] * 16
            for c in range(NC):
                for y in range(H):
                    nm = ik = 0
                    for b in range(8):
                        x = c * 8 + b - x0
                        ch = rows[y][x] if 0 <= x < w else '.'
                        if ch == '.': nm |= 0x80 >> b
                        elif ink(ch, x, y, w): ik |= 0x80 >> b
                    data += [nm, ik]
                data += [0xFF, 0x00] * 16
            # pad line 0 before each column is never read by a cell: it holds
            # the column's opaque line range (o0, o1) for the fast path
            lm = 0
            for c in range(NC):
                col = [data[2 * (16 + c * (H + 16) + j)] for j in range(H)]
                op = [j for j in range(H) if col[j] == 0]
                o0, o1 = 255, 0
                if op:
                    # longest run of opaque lines
                    best = (0, 0); st = None
                    for j in range(H + 1):
                        if j < H and col[j] == 0:
                            if st is None: st = j
                        elif st is not None:
                            if j - st > best[1] - best[0]: best = (st, j)
                            st = None
                    o0, o1 = best
                data[2 * (c * (H + 16))] = o0
                data[2 * (c * (H + 16)) + 1] = o1
                if lline and w >= 20 and col[lline] == 0: lm |= 1 << c
            lmasks.append(lm)
            lab = 'TRS_%d_%d' % (si, sh)
            blobs.append((lab, data))
            bases.append(lab)
            total += len(data)
        tab.append((w, H, NC, lline, 2 * (H + 16), bases, lmasks))
        previews.append(rows)
    L.append('NSCALE       equ %d' % len(WIDTHS))
    L.append('SCALETAB:')
    for w, H, NC, ll, stride, bases, lm in tab:
        L.append('        db %d,%d,%d,%d' % (w, H, NC, ll))
        L.append('        dw %d,%s' % (stride, ','.join(bases)))
        L.append('        dw %s' % ','.join(str(v) for v in lm))
        L.append('        ds 10')
    # SWSCALE: road half width sw (logical px) at the car -> nearest size
    sws = []
    for sw in range(128):
        wpx = 2 * CAR_WORLD_W * sw / RW          # screen px
        best = min(range(len(WIDTHS)), key=lambda i: abs(WIDTHS[i] - wpx))
        if wpx < 3: best = 255                   # too far to show
        sws.append(best)
    L.append('SWSCALE:')
    for i in range(0, 128, 16):
        L.append('        db ' + ','.join(str(v) for v in sws[i:i + 16]))
    for lab, data in blobs:
        L.append(lab + ':')
        for i in range(0, len(data), 16):
            L.append('        db ' + ','.join('%d' % v for v in data[i:i + 16]))
    open(os.path.join(out, 'traffic.inc'), 'w').write('\n'.join(L) + '\n')
    # unrolled compositors (HL -> strip (notmask, ink) pairs, DE -> 16-aligned dest)
    C = ['; generated by mktraffic.py', 'tcomp:                          ; over plain road: BC -> GRD (ground per scanline)']
    for i in range(16):
        C += ['        ld a,(bc)', '        inc c', '        and (hl)', '        inc hl', '        or (hl)', '        inc hl', '        ld (de),a']
        if i < 15: C.append('        inc e')
    C.append('        ret')
    C.append('topq:                           ; solid car: ink only')
    for i in range(16):
        C += ['        inc hl', '        ld a,(hl)', '        inc hl', '        ld (de),a']
        if i < 15: C.append('        inc e')
    C.append('        ret')
    open(os.path.join(out, 'tcomp.inc'), 'w').write('\n'.join(C) + '\n')
    # preview
    pw = sum(WIDTHS) + 10 * len(WIDTHS)
    ph = max(len(r) for r in previews)
    im = Image.new('RGB', (pw, ph), (60, 120, 60))
    x0 = 0
    col = {'.': None, 'K': (0, 0, 0), 'S': (40, 40, 40), 'W': (80, 80, 80), 'G': (20, 20, 50), 'R': (255, 0, 0)}
    for rows, w in zip(previews, WIDTHS):
        for y, r in enumerate(rows):
            for x, c in enumerate(r):
                if col[c]: im.putpixel((x0 + x, y), col[c])
        x0 += w + 10
    im.resize((pw * 3, ph * 3), Image.NEAREST).save(os.path.join(out, 'traffic_preview.png'))
    print('traffic sprites: %d sizes, %d bytes' % (len(WIDTHS), total), file=sys.stderr)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'build')
