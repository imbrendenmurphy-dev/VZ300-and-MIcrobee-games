#!/usr/bin/env python3
"""
mkroadtest.py - tables for ROADTEST, the OutRun-style road prototype
-> build/roadtest.inc                                   ViBED by BPM 2026

The road is NOT projected.  Every one of its 64 lines (logical lines 64..127,
two screen lines each) has a fixed distance ZT and half width WT, made once
here.  Per frame each line only gets:
  * a sideways offset: the bend accumulated line by line from the bottom
    (dx += curve; x += dx), plus the player's position scaled by the width;
  * a stripe: ((pos + ZT) >> 6) & 1, so the bands roll down as you drive.
"""
import os, sys, math

NL = 64
W0 = 112                     # half width (logical px) on the bottom line
ZB = 96                      # distance (z units) of the bottom line
SEG = 256                    # z units per track segment (curve lookup)

ZT = [int(round(ZB * NL / (l + 1))) for l in range(NL)]        # line 0 = horizon
WT = [max(1, int(round(W0 * (l + 1) / NL))) for l in range(NL)]

def track():
    """256 segments of curve (signed): ease between section targets"""
    secs = [(12, 0), (10, 6), (8, 12), (10, 4), (8, 0), (12, -8), (10, -14), (8, -6),
            (10, 0), (14, 10), (8, 16), (6, 6), (12, 0), (10, -10), (12, -4), (10, 8),
            (8, 14), (10, 0), (12, -12), (8, -16), (10, -6), (12, 0)]
    out = []
    c = 0.0
    while len(out) < 256:
        for n, t in secs:
            for i in range(n):
                c += max(-1.5, min(1.5, t - c))
                out.append(max(-15, min(15, int(round(c)))))
    return out[:256]

# dither patterns per band phase (0 dark, 1 light, 2 far): verge, road (2 scanlines)
PAT = [((0x88, 0x22), (0xDD, 0x77)), ((0xAA, 0x55), (0xFF, 0xFF)), ((0x88, 0x22), (0xDD, 0x77))]
RM = [0xFF, 0x3F, 0x0F, 0x03]          # road right of a left edge at sub-pixel s
LM = [0x00, 0xC0, 0xF0, 0xFC]          # road left of a right edge at sub-pixel s

def mix(v, r, m): return (v & ~m & 0xFF) | (r & m)

def carparts(out):
    """CARPART (16 x (notmask, ink) per partial car cell) from gfx.inc"""
    txt = open(os.path.join(out, 'gfx.inc')).read()
    a = txt.index('CARPART:'); b = txt.index('NCARPART')
    vals = [int(v) for ln in txt[a:b].split('\n')[1:] if 'db' in ln for v in ln.split('db')[1].split(',')]
    return [vals[i:i + 32] for i in range(0, len(vals), 32)]

def cardata(out):
    txt = open(os.path.join(out, 'gfx.inc')).read()
    a = txt.index('CARDATA:'); b = txt.index('CARPART:')
    vals = [int(v) for ln in txt[a:b].split('\n')[1:] if 'db' in ln for v in ln.split('db')[1].split(',')]
    return [[tuple(vals[p_ * 90 + c * 3: p_ * 90 + c * 3 + 3]) for c in range(30)] for p_ in range(5)]

EMIT = """
        align 256
EMIT%(v)d:
        ld a,%(va0)d
        ld (bc),a
        inc c
        ld a,%(va1)d
        ld (bc),a
        inc c
        ld a,%(vb0)d
        ld (bc),a
        inc c
        ld a,%(vb1)d
        ld (bc),a
        ld a,c
        add a,13
        ld c,a
        ld a,%(ra0)d
        ld (bc),a
        inc c
        ld a,%(ra1)d
        ld (bc),a
        inc c
        ld a,%(rb0)d
        ld (bc),a
        inc c
        ld a,%(rb1)d
        ld (bc),a
        ld a,(ix+2)
        or a
        ret z
        ld a,(iy+0)
        sub (ix+1)
        jp c,.rz
        cp (ix+2)
        jr c,.r1
        ld a,(ix+2)
.r1     ld c,a
        ld a,(iy-128)
        sub (ix+0)
        jp c,.nol
        jr z,.pl
        ld b,a
.v1     ld (hl),%(va0)d
        inc l
        ld (hl),%(va1)d
        inc l
        ld (hl),%(vb0)d
        inc l
        ld (hl),%(vb1)d
        add hl,de
        djnz .v1
.pl     cp c
        jp z,.both
        ld b,a
        ld e,(iy-64)
        ld d,high(PLT)
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        ld de,13
        add hl,de
        ld a,c
        sub b
        dec a
        jr z,.pr
.rr     ld b,a
.r2     ld (hl),%(ra0)d
        inc l
        ld (hl),%(ra1)d
        inc l
        ld (hl),%(rb0)d
        inc l
        ld (hl),%(rb1)d
        add hl,de
        djnz .r2
.pr     ld a,c
        cp (ix+2)
        ret nc
        ld e,(iy+64)
        ld d,high(PLT)+1
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        inc l
        inc e
        ld a,(de)
        ld (hl),a
        ld de,13
        add hl,de
        ld a,(ix+2)
        sub c
        dec a
        ret z
.vv     ld b,a
.v3     ld (hl),%(va0)d
        inc l
        ld (hl),%(va1)d
        inc l
        ld (hl),%(vb0)d
        inc l
        ld (hl),%(vb1)d
        add hl,de
        djnz .v3
        ret
.nol    ld a,c
        or a
        jp z,.pr
        jp .rr
.rz     ld a,(ix+2)
        jp .vv
.both   push hl
        ld e,(iy-64)
        ld d,high(PLT)
        ld l,(iy+64)
        ld h,high(PLT)+1
        ld a,(de)
        and (hl)
        ld (BT+0),a
        inc e
        inc l
        ld a,(de)
        and (hl)
        ld (BT+1),a
        inc e
        inc l
        ld a,(de)
        and (hl)
        ld (BT+2),a
        inc e
        inc l
        ld a,(de)
        and (hl)
        pop hl
        ld de,(BT+0)
        ld (hl),e
        inc l
        ld (hl),d
        inc l
        ld de,(BT+2)
        ld (hl),e
        inc l
        ld (hl),a
        ld de,13
        add hl,de
        ld a,(ix+2)
        sub c
        dec a
        ret z
        jp .vv
"""

def main(out):
    L = ['; generated by tools/mkroadtest.py', 'NL equ %d' % NL]
    L.append('        align 256')
    L.append('ZT:')                      # ZT at +0 (dw), WT at +128 (same page)
    for i in range(0, NL, 16): L.append('        dw ' + ','.join(str(v) for v in ZT[i:i + 16]))
    L.append('WT:')
    for i in range(0, NL, 16): L.append('        db ' + ','.join(str(v) for v in WT[i:i + 16]))
    L.append('WP:')
    L.append('        db ' + ','.join(str((WT[2 * p] + WT[2 * p + 1] + 1) // 2) for p in range(NL // 2)))
    L.append('        align 256')
    L.append('TRACKL:')
    t = track()
    for i in range(0, 256, 16): L.append('        db ' + ','.join(str(v & 255) for v in t[i:i + 16]))
    L.append('TRACKH:')
    for i in range(0, 256, 16): L.append('        db ' + ','.join(str(255 if v < 0 else 0) for v in t[i:i + 16]))
    # curve x4 for the line-pair accumulation (sign-extended pages)
    L.append('TRACK4L:')
    for i in range(0, 256, 16): L.append('        db ' + ','.join(str((4 * v) & 255) for v in t[i:i + 16]))
    L.append('TRACK4H:')
    for i in range(0, 256, 16): L.append('        db ' + ','.join(str(255 if v < 0 else 0) for v in t[i:i + 16]))
    # partial edge cells per line pair: v = pa*3+pb, entry (v*4+sub)*4 = 2 lines x 2 scanlines
    # left edges at PLT, right edges at PLT+256
    L.append('        align 256')
    L.append('PLT:')
    for tab in (RM, LM):
        e = []
        for pa in range(3):
            for pb in range(3):
                for sb in range(4):
                    for ph in (pa, pb):
                        (v0, v1), (r0, r1) = PAT[ph]
                        e += [mix(v0, r0, tab[sb]), mix(v1, r1, tab[sb])]
        e += [0] * (256 - len(e))
        for i in range(0, 256, 32): L.append('        db ' + ','.join(map(str, e[i:i + 32])))
    # 2*phase of the upper / lower line of each pair code (for the car)
    L.append('PAB:')
    L.append('        db ' + ','.join('%d,%d' % (2 * (v // 3), 2 * (v % 3)) for v in range(9)))
    # line-pair emitters, one per (upper, lower) band phase, page aligned
    for pa in range(3):
        for pb in range(3):
            (va0, va1), (ra0, ra1) = PAT[pa]
            (vb0, vb1), (rb0, rb1) = PAT[pb]
            L.append(EMIT % dict(v=pa * 3 + pb, va0=va0, va1=va1, vb0=vb0, vb1=vb1,
                                 ra0=ra0, ra1=ra1, rb0=rb0, rb1=rb1))
    # per pose and car row: partial cells (cx, CARROAD page offset, low base, CARPART index),
    # then opaque cells (cx, code)
    cd = cardata(out)
    L.append('CARL:')
    L.append('        dw ' + ','.join('CL_%d_%d' % (p_, r) for p_ in range(5) for r in range(3)))
    for p_ in range(5):
        for r in range(3):
            cells = cd[p_][r * 10:(r + 1) * 10]
            part = [(cx, c[1]) for cx, c in enumerate(cells) if c[0] == 3]
            opq = [(cx, c[1]) for cx, c in enumerate(cells) if c[0] in (1, 2)]
            L.append('CL_%d_%d:' % (p_, r))
            L.append('        db %d' % len(part) + ''.join(',%d,%d,%d,%d' % (cx, i >> 1, (i & 1) * 128, i) for cx, i in part))
            L.append('        db %d' % len(opq) + ''.join(',%d,%d' % (cx, c) for cx, c in opq))
    # car cells pre-composited over plain verge/road: cell*128 + line*12 + surf*6 + ph*2 + scan
    L.append('        align 256')
    L.append('CARROAD:')
    for cp in carparts(out):
        cell = []
        for ln in range(8):
            for surf in range(2):
                for ph in range(3):
                    for sc in range(2):
                        nm, ink = cp[(2 * ln + sc) * 2], cp[(2 * ln + sc) * 2 + 1]
                        cell.append((PAT[ph][surf][sc] & nm) | ink)
        cell += [0] * (128 - len(cell))
        for i in range(0, 128, 32): L.append('        db ' + ','.join(map(str, cell[i:i + 32])))
    open(os.path.join(out, 'roadtest.inc'), 'w').write('\n'.join(L) + '\n')
    print('roadtest: z %d..%d, width %d..%d' % (ZT[-1], ZT[0], WT[0], WT[-1]), file=sys.stderr)

if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'build')
