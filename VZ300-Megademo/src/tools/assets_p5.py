"""Part 5 assets (semigraphics showcase): rotozoom, twister, rolling cylinder logo,
transparency layers. All 64x32 cell frames -> SG4 (512 bytes each)."""
import numpy as np, os
from vzgfx import *

def cells_grid():
    y, x = np.mgrid[0:32, 0:64].astype(float)
    return (x + 0.5 - 32) * 4.0, (y + 0.5 - 16) * 6.0      # physical units (pixels)

def frames_to_bytes(fr):
    return b''.join(sg4_from_index(f) for f in fr)

# ---------------------------------------------------------------- rotozoom
def tile_tex(u, v):
    """4-fold symmetric tile: coloured checker with diamond + dot motif."""
    fu = u - np.floor(u); fv = v - np.floor(v)
    cu = np.floor(u).astype(int); cv = np.floor(v).astype(int)
    du = np.abs(fu - 0.5); dv = np.abs(fv - 0.5)
    base = np.where((cu + cv) % 2 == 0, BLUE, MAGENTA)
    diamond = (du + dv) < 0.30
    dot = (du < 0.10) & (dv < 0.10)
    out = np.where(diamond, np.where((cu + cv) % 2 == 0, YELLOW, CYAN), base)
    out = np.where(dot, RED, out)
    return out

def rotozoom(n=24):
    X, Y = cells_grid()
    fr = []
    for i in range(n):
        t = i / n
        a = t * np.pi / 2
        z = 1.0 / (72.0 + 30.0 * np.sin(2 * np.pi * t))
        c, s = np.cos(a), np.sin(a)
        u = (c * X - s * Y) * z + t * 2
        v = (s * X + c * Y) * z + t * 2
        fr.append(tile_tex(u, v))
    return fr

# ---------------------------------------------------------------- twister
def twister(n=16):
    fr = []
    y, x = np.mgrid[0:32, 0:64].astype(float)
    faces_lit = [RED, YELLOW, MAGENTA, CYAN]
    faces_dark = [MAGENTA, ORANGE, BLUE, BLUE]
    for i in range(n):
        t = i / n
        # background: wobbling checkerboard at char resolution
        cy_, cx_ = np.mgrid[0:16, 0:32].astype(float)
        wob = 1.5 * np.sin(2 * np.pi * (cy_ / 16.0 + t))
        chk = ((np.floor((cx_ + wob) / 3) + np.floor(cy_ / 2 + t * 2)) % 2).astype(int)
        bgc = np.where(chk > 0, BLUE, BLACK)
        img = np.repeat(np.repeat(bgc, 2, 0), 2, 1)
        for row in range(32):
            ang = (np.pi / 2) * t + 0.9 * np.sin(2 * np.pi * (row / 48.0 + t))
            xs = [10.0 * np.sin(ang + k * np.pi / 2) for k in range(4)]
            for k in range(4):
                x0 = xs[k]; x1 = xs[(k + 1) % 4]
                if x1 > x0 + 0.3:
                    th = ang + k * np.pi / 2 + np.pi / 4
                    col = faces_lit[k] if np.cos(th) > 0.55 else faces_dark[k]
                    a0 = int(np.round(32 + x0)); a1 = int(np.round(32 + x1))
                    img[row, max(0, a0):min(64, a1)] = col
            # dark edges
        fr.append(img)
    return fr

# ---------------------------------------------------------------- rolling cylinder logo
def cylinder(n=16, texts=('ViBED', 'BPM')):
    """Rolling drum: the bands around it alternate ViBED / BPM (double width)."""
    bms = []
    for tx_ in texts:
        bm = np.repeat(text_bitmap(tx_, spacing=1), 2, axis=1)   # double width
        bms.append((bm, (64 - bm.shape[1]) // 2))
    shades = [  # per text: (bright, mid, dark, darkest), separator line colour
        ((BUFF, YELLOW, ORANGE, RED), BLUE),
        ((CYAN, CYAN, BLUE, MAGENTA), RED),
    ]
    fr = []
    R = 15.5
    for i in range(n):
        t = i / n
        img = np.full((32, 64), BLACK)
        for row in range(32):
            dy = (row + 0.5 - 16) / R
            if abs(dy) >= 1: continue
            phi = np.arcsin(dy)
            shade = np.cos(phi)
            s_ = (phi + np.pi / 2) * R * 0.75 + t * 18       # surface cells, rolls 2 bands per loop
            band = int(np.floor(s_ / 9)) % 2                # even band ViBED, odd band BPM
            vy = int(np.floor(s_)) % 9
            bm, x0 = bms[band]
            pal, line = shades[band]
            W = bm.shape[1]
            for cx in range(64):
                tx = cx - x0
                on = vy < 7 and 0 <= tx < W and bm[vy, tx]
                if on:
                    img[row, cx] = pal[0] if shade > 0.9 else (pal[1] if shade > 0.7 else (pal[2] if shade > 0.45 else pal[3]))
                elif vy == 8 and shade > 0.6:
                    img[row, cx] = line
        fr.append(img)
    return fr

# ---------------------------------------------------------------- transparency layers
def transparency(n=16):
    fr = []
    y, x = np.mgrid[0:32, 0:64].astype(float)
    bm = text_bitmap('MEGA')
    big = np.zeros((32, 64), bool)
    # 2x scaled MEGA logo centred
    h, w = bm.shape
    for yy in range(h):
        for xx in range(w):
            if bm[yy, xx]:
                big[9 + 2*yy: 11 + 2*yy, 6 + 2*xx: 8 + 2*xx] = True
    for i in range(n):
        t = i / n
        # layer 1: diagonal stripes moving
        cyy, cxx = np.mgrid[0:16, 0:32].astype(float)
        st = ((np.floor((cxx + cyy * 1.5 + t * 8) / 3)) % 4).astype(int)
        bg = np.repeat(np.repeat(np.array([BLUE, BLACK, CYAN, BLACK])[st], 2, 0), 2, 1)
        # layer 2: a ring moving in a circle
        cx = 32 + 18 * np.cos(2 * np.pi * t); cy = 16 + 8 * np.sin(2 * np.pi * t)
        d = np.sqrt(((x - cx) * 4) ** 2 + ((y - cy) * 6) ** 2)
        ring = np.abs(d - 50) < 7
        # transparency: logo cells show logo colour on even checker, background on odd
        checker = ((x + y) % 2 == 0)
        img = bg.copy()
        img = np.where(ring & checker, ORANGE, img)
        img = np.where(ring & ~checker & (bg == BLACK), RED, img)
        logo_col = np.where(ring, YELLOW, BUFF)
        img = np.where(big & (checker | (bg == BLACK)), logo_col, img)
        fr.append(img)
    return fr

def build_a(out):
    os.makedirs(out, exist_ok=True)
    rz = rotozoom(24)
    tw = twister(16)
    open(f'{out}/roto.bin', 'wb').write(frames_to_bytes(rz))
    open(f'{out}/bank1.bin', 'wb').write(frames_to_bytes(tw))
    sg4_preview(sg4_from_index(rz[3])).save(f'{out}/roto_preview.png')
    sg4_preview(sg4_from_index(tw[3])).save(f'{out}/tw_preview.png')

def build_b(out):
    os.makedirs(out, exist_ok=True)
    cy = cylinder(16)
    tr = transparency(16)
    open(f'{out}/cyl.bin', 'wb').write(frames_to_bytes(cy))
    open(f'{out}/bank1.bin', 'wb').write(frames_to_bytes(tr))
    sg4_preview(sg4_from_index(cy[3])).save(f'{out}/cyl_preview.png')
    sg4_preview(sg4_from_index(tr[3])).save(f'{out}/tr_preview.png')
