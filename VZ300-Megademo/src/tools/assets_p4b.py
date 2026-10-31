"""Part 4b assets: 3D madness II - semigraphics tunnel (24 frames, 50fps loop) and a
spinning shaded torus (mode 1 window, frames in SRAM bank 1)."""
import numpy as np, os
from vzgfx import *
from render3d import *
import assets_p4a as P4A

NT = 24

def tunnel_frames():
    out = bytearray(); prev = None
    y, x = np.mgrid[0:32, 0:64].astype(float)
    px = (x + 0.5 - 32) * 4.0; py = (y + 0.5 - 16) * 6.0
    r = np.sqrt(px ** 2 + py ** 2) + 1e-3
    ang = np.arctan2(py, px) / (2 * np.pi)
    depth = 1400.0 / r
    hues = [RED, ORANGE, YELLOW, GREEN, CYAN, BLUE, MAGENTA, BUFF]
    thr = np.tile(BAYER4, (8, 16))[:32, :64]
    for f in range(NT):
        t = f / NT
        u = ang * 8 + t * 1
        v = 220.0 / r + t * 2
        chk = ((np.floor(u * 2) + np.floor(v * 2)) % 2).astype(int)
        ring = np.floor(v).astype(int) % len(hues)
        col = np.array(hues)[ring]
        alt = np.array(hues)[(ring + 4) % len(hues)]
        idx = np.where(chk > 0, col, alt)
        fog = np.clip((r - 10) / 45.0, 0, 1)         # 0 = centre (dark)
        idx = np.where(fog > thr, idx, BLACK)
        out += sg4_from_index(idx)
        if f == 5: prev = bytes(out[-512:])
    return out, prev

def build(out):
    os.makedirs(out, exist_ok=True)
    tun, prev = tunnel_frames()
    open(f'{out}/tunnel.bin', 'wb').write(tun)
    sg4_preview(prev).save(f'{out}/tunnel_preview.png')
    # seamless tumble: half a turn end-over-end (a torus is symmetric under 180 deg about an
    # in-plane axis) plus one segment of spin about its own axis (14 segments)
    v, f = torus()
    tor = bytearray(); pt = []
    NF = 12
    for i in range(NF):
        t = i / NF
        R = rotmat(0.35, 0.0, 0.25) @ axis_rot((1, 0, 0), np.pi * t) @ axis_rot((0, 0, 1), 2 * np.pi / 14 * t)
        idx = P4A.shade_to_index(render(v, f, R, 64, 48, 34))
        pt.append(idx); tor += cg2_from_index(idx)
    open(f'{out}/bank1.bin', 'wb').write(tor)
    cg2_preview(cg2_from_index(np.hstack([pt[1], pt[6]])), cset=0, rows=48).save(f'{out}/torus_preview.png')
    # starfield background with title
    rnd = np.random.RandomState(9)
    bg = np.full((64, 128), P4A.BG, int)
    for k in range(80):
        bg[rnd.randint(4, 64), rnd.randint(128)] = rnd.choice([1, 0, 1, 3])
    bg[4:52, 32:96] = P4A.BG
    bm = text_bitmap('TORUS')
    x0 = (128 - bm.shape[1]) // 2
    for yy in range(7):
        for xx in range(bm.shape[1]):
            if bm[yy, xx]: bg[56 + yy, x0 + xx] = 3
    open(f'{out}/bg.bin', 'wb').write(cg2_from_index(bg))
    print(f'p4b: tunnel {len(tun)} torus {len(tor)}')

if __name__ == '__main__':
    import sys
    build(sys.argv[1])
