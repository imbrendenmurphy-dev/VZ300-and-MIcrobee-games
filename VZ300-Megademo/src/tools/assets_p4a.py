"""Part 4a assets: 3D madness I - spinning flat-shaded cube and octahedron in a 64x48 mode(1)
window over a starfield, FLD bounce tables."""
import numpy as np, os
from vzgfx import *
from render3d import *

from vzcfg import D
WIN_ROW = 4          # first VRAM row of the window
WIN_X = 8            # first byte of the window (16 bytes wide)
NF = 16

# colour indices in CSS0: 0 green, 1 yellow, 2 blue, 3 red
RAMP = [2, 3, 0, 1]      # dark -> bright : blue, red, green, yellow
BG = 2

def shade_to_index(img):
    H, W = img.shape
    thr = np.tile(BAYER4, (H // 4 + 1, W // 4 + 1))[:H, :W]
    out = np.full((H, W), BG, int)
    m = img >= 0
    v = np.clip(img, 0, 0.999) * (len(RAMP) - 1)
    lo = np.floor(v).astype(int); fr = v - lo
    idx = np.where(fr > thr, lo + 1, lo)
    idx = np.clip(idx, 0, len(RAMP) - 1)
    out[m] = np.array(RAMP)[idx[m]]
    return out

def frames(obj, axis, period, scale, tilt, nf=NF):
    v, f = obj
    out = bytearray(); prev = []
    for i in range(nf):
        R = rotmat(*tilt) @ axis_rot(axis, period * i / nf)
        img = render(v, f, R, 64, 48, scale)
        idx = shade_to_index(img)
        prev.append(idx)
        out += cg2_from_index(idx)
    return out, prev

def build(out):
    os.makedirs(out, exist_ok=True)
    cub, pc = frames(cube(), (0, 1, 0), np.pi / 2, 30, (0.55, 0.0, 0.18))
    octa, po = frames(octahedron(), (0, 1, 0), np.pi / 2, 34, (0.45, 0.0, 0.3), nf=12)   # 4-fold axis: seamless loop
    open(f'{out}/cube.bin', 'wb').write(cub)
    open(f'{out}/bank1.bin', 'wb').write(octa)
    # background: starfield on blue, with a title strip
    rnd = np.random.RandomState(7)
    bg = np.full((64, 128), BG, int)
    for k in range(70):
        y, x = rnd.randint(4, 64), rnd.randint(128)
        bg[y, x] = rnd.choice([1, 0, 1, 3])
    # clear the window area (rows 8..55, x 32..95)
    bg[WIN_ROW:WIN_ROW + 48, WIN_X * 4:WIN_X * 4 + 64] = BG
    # title: "3D" small at bottom
    bm = text_bitmap('3D MADNESS')
    x0 = (128 - bm.shape[1]) // 2
    for yy in range(7):
        for xx in range(bm.shape[1]):
            if bm[yy, xx]:
                bg[57 + yy, x0 + xx] = 1
    open(f'{out}/bg.bin', 'wb').write(cg2_from_index(bg))
    # preview
    sheet = np.full((64, 128), BG)
    sheet[WIN_ROW:WIN_ROW + 48, 32:96] = pc[3]
    cg2_preview(cg2_from_index(np.where(sheet == BG, bg, sheet)), cset=0).save(f'{out}/preview.png')
    cg2_preview(cg2_from_index(np.hstack([po[2], po[9]])), cset=0, rows=48).save(f'{out}/preview2.png')
    # raster tables: FLD hold region then normal mode(1) lines with border CSS bars
    fld = bytearray()
    for i in range(120):
        fld += bytes((0x20, 0x28))              # hold (A then G)
    for ln in range(320):
        v = 0x28
        if (ln % 64) in (20, 21, 22, 24, 26):
            v = 0x38
        fld += bytes((v, v))
    open(f'{out}/fld.bin', 'wb').write(fld)
    # bounce trajectory (lines pushed), 2 loops of bouncing
    traj = []
    for k in range(300):
        t = (k % 75) / 75.0
        h = 4 * t * (1 - t)            # parabola 0..1..0
        traj.append(int(round(18 * h)))
    open(f'{out}/bounce.bin', 'wb').write(bytes(traj))
    print(f'p4a: cube {len(cub)} octa {len(octa)}')

if __name__ == '__main__':
    import sys
    build(sys.argv[1])
