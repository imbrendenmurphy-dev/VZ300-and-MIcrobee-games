"""RUNE AMOK - wall, door and floor art, rendered into view cells.

Every face is rendered per pixel from a texture (luminance) and a material
id per pixel, lit by the torch (brightness falls with depth), then put on
the cell grid: each cell takes the ink of its highest-priority material;
pixels of other materials in that cell are cleared (a dark recess - the
style's "one ink on black" rule). The ink of a material comes from its
depth ramp (near, mid, far, farthest).
"""
import numpy as np
import views as V

# Premium palette indexes
BLACK, RED, GREEN, BROWN, BLUE, MAGENTA, CYAN, GREY = range(8)
DGREY, BRED, BGREEN, YELLOW, BBLUE, BMAGENTA, BCYAN, WHITE = range(8, 16)
# how bright each ink looks (for the dither density)
INKLUM = {WHITE: 1.0, GREY: 0.72, DGREY: 0.36, BGREEN: 0.82, GREEN: 0.48, BCYAN: 0.92, CYAN: 0.58,
          BLUE: 0.30, BBLUE: 0.55, YELLOW: 0.95, BROWN: 0.5, BRED: 0.68, RED: 0.38, MAGENTA: 0.42,
          BMAGENTA: 0.7, BLACK: 0.0}

# animation classes (high nibble of a colour byte in the tile data; the
# Z80 lists such cells and cycles their ink each frame)
ANIM_FLAME, ANIM_RUNE, ANIM_WATER, ANIM_PORTAL = 1, 2, 3, 4


def light(z):
    return np.clip(1.12 / np.power(np.maximum(z, 1.0), 0.62), 0, 1)


def band(z):
    return np.where(z < 2.05, 0, np.where(z < 3.05, 1, np.where(z < 4.6, 2, 3)))


def hash2(a, b, s=0):
    h = (np.asarray(a, np.int64) * 374761393 + np.asarray(b, np.int64) * 668265263 + s * 1442695041) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return (h & 0xFFFF) / 65535.0


# ---------------------------------------------------------------- textures
# tex(u, v, pu, pv, side) -> lum (0..1); pu/pv = pixels per unit (to keep
# lines at least a pixel wide). Front-face textures must repeat every 0.5 in
# u so equal cells share glyphs.

def line_w(p, world, minpx=1.15):
    return np.maximum(world, minpx / np.maximum(p, 1e-3))


def ashlar(u, v, pu, pv, side, courses=4, seed=1, rough=0.0):
    row = np.floor(v * courses)
    fv = v * courses - row
    off = np.where(row % 2 == 1, 0.25, 0.0)
    uu = (u + off) * 2.0
    col = np.floor(uu)
    fu = uu - col
    colid = 0 if not side else col
    mw_u = line_w(pu * 0.5, 0.04)
    mw_v = line_w(pv / courses, 0.07)
    mortar = (fu < mw_u) | (fv < mw_v)
    n = hash2(colid + 7 * row, row, seed)
    face = 0.78 + 0.22 * n
    # chisel: lit top, dark lower edge of each block
    face = np.where(fv > 1 - mw_v * 1.6, face * 0.55, face)
    face = np.where((fv > mw_v) & (fv < mw_v * 2.2), np.minimum(1.0, face + 0.2), face)
    # speckle
    us = (u % 0.5) if not side else u
    sp = hash2(np.floor(us * 61), np.floor(v * 77), seed + 3)
    face = np.where(sp > 0.975, face * 0.35, face)
    if rough:
        cr = hash2(np.floor((u % 0.5 if not side else u) * 9 + v * 3), np.floor(v * 13), seed + 9)
        face = np.where(cr > 1 - rough, face * 0.5, face)
    return np.where(mortar, 0.0, face)


def cave(u, v, pu, pv, side, seed=2):
    """rough rock: irregular slabs (a jittered grid), cracks dark"""
    sc_u, sc_v = 4.0, 3.0
    U = u * sc_u
    Vv = v * sc_v
    best = np.full(u.shape, 9.0)
    second = np.full(u.shape, 9.0)
    cid = np.zeros(u.shape)
    iu0 = np.floor(U)
    iv0 = np.floor(Vv)
    for du in (-1, 0, 1):
        for dv in (-1, 0, 1):
            iu = iu0 + du
            iv = iv0 + dv
            ku = iu if side else iu % 2
            px = iu + 0.2 + 0.6 * hash2(ku, iv, seed)
            py = iv + 0.2 + 0.6 * hash2(ku, iv, seed + 1)
            d = np.hypot((U - px) * 1.0, (Vv - py) * 0.8)
            closer = d < best
            second = np.where(closer, best, np.minimum(second, d))
            cid = np.where(closer, hash2(ku, iv, seed + 2), cid)
            best = np.where(closer, d, best)
    edge = second - best
    ew = line_w(np.minimum(pu / sc_u, pv / sc_v), 0.06, 1.1)
    face = 0.62 + 0.35 * cid + 0.25 * (edge - 0.2)
    face = np.clip(face, 0.3, 1.0)
    us = (u % 0.5) if not side else u
    sp = hash2(np.floor(us * 53), np.floor(v * 71), seed + 5)
    face = np.where(sp > 0.9, face * 0.4, face)
    return np.where(edge < ew, 0.0, face)


def brick(u, v, pu, pv, side, seed=4):
    courses = 8
    row = np.floor(v * courses)
    fv = v * courses - row
    off = np.where(row % 2 == 1, 0.125, 0.0)
    uu = (u + off) * 4.0
    col = np.floor(uu)
    fu = uu - col
    mw_u = line_w(pu * 0.25, 0.03)
    mw_v = line_w(pv / courses, 0.10)
    mortar = (fu < mw_u) | (fv < mw_v)
    n = hash2((col % 2) if not side else col, row, seed)
    face = 0.7 + 0.3 * n
    face = np.where(fv > 1 - mw_v * 1.5, face * 0.6, face)
    us = (u % 0.5) if not side else u
    sp = hash2(np.floor(us * 57), np.floor(v * 83), seed + 3)
    face = np.where(sp > 0.92, face * 0.4, face)
    return np.where(mortar, 0.0, face)


def library(u, v, pu, pv, side, seed=6):
    """dressed stone below and above, shelves of books between"""
    st = ashlar(u, v, pu, pv, side, courses=6, seed=seed)
    shelf0, shelf1 = 0.22, 0.86
    inb = (v > shelf0) & (v < shelf1)
    nsh = 3
    sv = (v - shelf0) / (shelf1 - shelf0) * nsh
    srow = np.floor(sv)
    fv = sv - srow
    plank = fv < line_w(pv * (shelf1 - shelf0) / nsh, 0.10)
    # books: varying widths from a hash per slot
    bw = 0.045
    bu = u / bw
    bid = np.floor(bu)
    key = (bid % (0.5 / bw)) if not side else bid
    h = hash2(key, srow, seed)
    top = 0.18 + 0.3 * h
    book = (fv > top) & ~plank
    gap = (bu - bid) < line_w(pu * bw, 0.12)
    lum = np.where(book & ~gap, 0.55 + 0.45 * hash2(key, srow, seed + 1), 0.0)
    band_ = (fv > top + 0.12) & (fv < top + 0.2)
    lum = np.where(book & band_, lum * 0.4, lum)
    lum = np.where(plank, 0.9, lum)
    upright = (u % 0.5) < line_w(pu * 0.5, 0.03) if not side else (u < 0.04) | (u > 0.96)
    lum = np.where(inb & upright, 0.95, lum)
    return np.where(inb, lum, st)


TEXTURES = {'ashlar': ashlar, 'cave': cave, 'brick': brick, 'library': library}


# ---------------------------------------------------------------- themes
class Theme:
    def __init__(self, name, wall, ramp, ramp_b, floor_ink, floor_style, door_ramp, metal_ramp):
        self.name, self.wall = name, wall
        self.ramp, self.ramp_b = ramp, ramp_b
        self.floor_ink, self.floor_style = floor_ink, floor_style
        self.door_ramp, self.metal_ramp = door_ramp, metal_ramp


THEMES = [
    Theme('gate', 'ashlar', [WHITE, GREY, DGREY, DGREY], [BGREEN, GREEN, GREEN, DGREY], [DGREY, DGREY, DGREY], 'flag',
          [YELLOW, BROWN, BROWN, RED], [BCYAN, CYAN, BLUE, BLUE]),
    Theme('grotto', 'cave', [BGREEN, GREEN, GREEN, DGREY], [BCYAN, CYAN, BLUE, BLUE], [GREEN, GREEN, DGREY], 'flag',
          [YELLOW, BROWN, BROWN, RED], [WHITE, GREY, DGREY, DGREY]),
    Theme('archive', 'ashlar', [BCYAN, CYAN, BLUE, BLUE], [YELLOW, BROWN, BROWN, RED], [BLUE, BLUE, BLUE], 'flag',
          [YELLOW, BROWN, BROWN, RED], [WHITE, GREY, DGREY, DGREY]),
    Theme('ember', 'brick', [YELLOW, BRED, RED, RED], [BMAGENTA, MAGENTA, MAGENTA, BLUE], [RED, RED, MAGENTA], 'flag',
          [WHITE, GREY, DGREY, DGREY], [WHITE, GREY, DGREY, DGREY]),
]


# ---------------------------------------------------------------- face rendering
def face_pixels(slot, theme, kind):
    """-> (lum, mat, inside, u, v, z) arrays over the view. mat: 1 wall,
    2 feature (door wood / bars / carving), 3 accent (handle, rune)"""
    inside, u, v, z = slot.coverage()
    pu = np.abs(np.gradient(u, axis=1)) ** -1
    pv = np.abs(np.gradient(v, axis=0)) ** -1
    pu = np.where(np.isfinite(pu), pu, 1000)
    pv = np.where(np.isfinite(pv), pv, 1000)
    side = slot.kind == 'S'
    tex = TEXTURES['library' if kind == 'B' and theme.name == 'archive' and not side else theme.wall]
    lum = tex(u, v, pu, pv, side)
    mat = np.where(inside, 1, 0)
    if slot.kind == 'F' and kind in ('D', 'G', 'V', 'X'):
        lum, mat = feature(slot, theme, kind, u, v, pu, pv, lum, mat, inside)
    return lum, mat, inside, z


def door_cols(slot):
    """door opening in whole cells: the middle half of the face"""
    w = slot.x1 - slot.x0
    cells = w // 8
    k = {12: 3, 8: 2, 6: 1, 4: 1}[cells]
    return (k * 8) / w, 1 - (k * 8) / w


def feature(slot, theme, kind, u, v, pu, pv, lum, mat, inside):
    a, b = door_cols(slot)
    top = 0.22
    du = (u - a) / (b - a)
    # round arch head
    ar = 0.5
    arch_v = top + 0.18 * (1 - np.sqrt(np.clip(1 - ((du - 0.5) / ar) ** 2, 0, 1)))
    opening = (u >= a) & (u < b) & (v >= arch_v)
    if kind == 'D':        # oak door: planks, iron straps, a ring
        planks = 5
        pf = du * planks - np.floor(du * planks)
        seam = pf < line_w(pu * (b - a) / planks, 0.06)
        grain = 0.75 + 0.25 * hash2(np.floor(du * planks), np.floor(v * 40), 11)
        w = np.where(seam, 0.0, grain)
        strap = (np.abs(v - 0.42) < line_w(pv, 0.035)) | (np.abs(v - 0.80) < line_w(pv, 0.035))
        w = np.where(strap, 0.0, w)
        rivet = (np.abs(v - 0.42) < line_w(pv, 0.05)) & (pf > 0.4) & (pf < 0.6)
        w = np.where(rivet, 1.0, w)
        lum = np.where(opening, w, lum)
        mat = np.where(opening & inside, 2, mat)
        ring = np.abs(np.hypot((du - 0.78) * (b - a) * 1.2, (v - 0.62)) - 0.035) < line_w(pv, 0.012)
        lum = np.where(ring & opening, 0.0, lum)
    elif kind == 'G':      # portcullis: bars over darkness
        nb = 5
        bf = du * nb - np.floor(du * nb)
        bar = (bf > 0.5 - 0.5 * line_w(pu * (b - a) / nb, 0.22)) & (bf < 0.5 + 0.5 * line_w(pu * (b - a) / nb, 0.22))
        cross = (np.abs(v - 0.45) < line_w(pv, 0.03)) | (np.abs(v - 0.75) < line_w(pv, 0.03))
        spike = v > 0.95
        g = np.where(bar | cross, 0.95, 0.0)
        g = np.where(spike & ~bar, 0.0, g)
        lum = np.where(opening, g, lum)
        mat = np.where(opening & inside, 2, mat)
    elif kind == 'V':      # the sealed vault door: carved stone, a rune circle
        c = np.hypot((du - 0.5) * (b - a) * 1.33, (v - 0.6))
        carve = 0.8 - 0.3 * hash2(np.floor(du * 9), np.floor(v * 14), 5)
        rim = (c > 0.16) & (c < 0.16 + line_w(pv, 0.03))
        lum2 = np.where(rim, 0.0, carve)
        seam = np.abs(du - 0.5) < line_w(pu * (b - a), 0.02)
        lum2 = np.where(seam, 0.0, lum2)
        lum = np.where(opening, lum2, lum)
        mat = np.where(opening & inside, 2, mat)
        rune = (c < 0.14) & (((np.floor(np.arctan2(v - 0.6, du - 0.5) * 2.5) % 2) == 0) | (c < 0.05))
        mat = np.where(rune & opening & inside, 3, mat)
        lum = np.where(rune & opening, 1.0, lum)
    return lum, mat


def face_cells(slot, theme, kind):
    """-> dict (col, row) -> (pattern bytes(10), colour byte) for one face"""
    lum, mat, inside, z = face_pixels(slot, theme, kind)
    zl = light(z)
    bd = band(z)
    out = {}
    ramp = theme.ramp_b if kind == 'B' and theme.name == 'archive' and slot.kind == 'F' else theme.ramp
    recol = theme.ramp_b if kind == 'B' and theme.name != 'archive' else None
    for c in range(slot.c0, slot.c1):
        xs = slice(c * 8, c * 8 + 8)
        for r in range(V.VH):
            ys = slice(r * 10, r * 10 + 10)
            m = mat[ys, xs]
            if not m.any():
                continue
            top = m.max()
            zz = z[ys, xs][m > 0]
            b_ = int(np.round(np.median(band(zz))))
            if top == 1:
                ink = ramp[b_]
                anim = 0
                if recol:
                    ink2 = recol[b_]
            elif top == 2:
                ink = (theme.door_ramp if kind == 'D' else theme.metal_ramp if kind == 'G' else ramp)[b_]
                anim = 0
            else:
                if kind == 'D':
                    ink, anim = theme.metal_ramp[min(b_, 1)], 0
                else:
                    ink, anim = BMAGENTA, 0
            sel = (m == top)
            dens = lum[ys, xs] * zl[ys, xs] / INKLUM[ink]
            if top == 1 and slot.kind == 'S':
                dens = dens * 1.0
            th = V.BAYER8[np.arange(r * 10, r * 10 + 10)[:, None] % 8, np.arange(c * 8, c * 8 + 8)[None, :] % 8]
            on = sel & (dens > th) & (lum[ys, xs] > 0)
            pat = bytes(int(sum(int(on[i, j]) << (7 - j) for j in range(8))) for i in range(10))
            if top == 1 and recol:
                ink = ink2
            out[(c, r)] = (pat, (anim << 4) | ink)
    return out


def floor_cells(theme):
    """the backdrop: dark ceiling, a flagstone floor in the dim floor ink"""
    ys, xs = np.mgrid[0:V.PH, 0:V.PW]
    px, py = xs + 0.5, ys + 0.5
    out = {}
    with np.errstate(divide='ignore', invalid='ignore'):
        z = (V.FY * 0.5) / (py - V.CY)
    floor = (py > V.CY + 2) & np.isfinite(z) & (z > 0)
    z = np.where(floor, z, 99)
    X = (px - V.CX) * z / V.FX
    # depth in square units measured with the snapped boundaries
    zq = np.interp(z, V.ZB, [0, 1, 2, 3, 4])
    if theme.floor_style == 'flag':
        gx = (X + 0.5) * 2
        gz = zq * 2
        fx = gx - np.floor(gx)
        fz = gz - np.floor(gz)
        pxu = V.FX / z / 2
        pzu = np.abs(np.gradient(gz, axis=0)) ** -1
        ln = (fx < line_w(pxu, 0.05)) | (fz < line_w(np.where(np.isfinite(pzu), pzu, 99), 0.06))
        lum = np.where(ln, 0.9, 0.0)
        sp = hash2(np.floor(gx), np.floor(gz), 3)
        pass
    else:
        sp = hash2(np.floor(X * 14), np.floor(zq * 9), 8)
        lum = np.where(sp > 0.8, 0.8, 0.0)
        lum = np.where(hash2(np.floor(X * 5), np.floor(zq * 3), 9) > 0.9, 0.9, lum)
    for c in range(V.VW):
        for r in range(V.VH):
            ys_, xs_ = slice(r * 10, r * 10 + 10), slice(c * 8, c * 8 + 8)
            f = floor[ys_, xs_]
            if not f.any():
                continue
            zz = np.median(z[ys_, xs_][f])
            ink = theme.floor_ink[0 if zz < 2.2 else 1 if zz < 3.5 else 2]
            dens = lum[ys_, xs_] * np.clip(1.4 / zz, 0.35, 1.0)
            th = V.BAYER4[np.arange(r * 10, r * 10 + 10)[:, None] % 4, np.arange(c * 8, c * 8 + 8)[None, :] % 4]
            on = f & (dens > th)
            pat = bytes(int(sum(int(on[i, j]) << (7 - j) for j in range(8))) for i in range(10))
            if any(pat):
                out[(c, r)] = (pat, ink)
    return out
