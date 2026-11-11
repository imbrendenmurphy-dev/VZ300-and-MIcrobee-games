#!/usr/bin/env python3
"""
mkcar.py - renders the player car from a small 3D model into 5 steering
poses at SCREEN-pixel resolution (80 x 48 = 10 x 3 character cells of 8x16).
ViBED by BPM 2026

Pixel codes
   .  transparent (road shows through)
   K  black body                       (ink 0)
   S  side panel / bonnet: sparse dither of the ground colour
   W  wheel / tyre: fine checker of the ground colour and black
   G  rear window: black with a faint horizontal sheen
   R  tail light (cells holding lights take the light colour)

Screen pixels are 1:1.5 (wide:tall) on a 4:3 monitor at 512x256, so the
renderer squashes y by 1/1.5 to keep the car's real shape.
"""
import math
from PIL import Image, ImageDraw

W, H = 80, 48
SS = 4
YAWS = [-15, -7, 0, 7, 15]          # steering hard left .. hard right


def model():
    """faces: (3D quad, code, kind). x right, y up, z forward."""
    F = []

    def box(x0, x1, y0, y1, z0, z1, side, rear=None, top=None, front=None):
        P = lambda x, y, z: (x, y, z)
        F.append(([P(x0, y0, z0), P(x1, y0, z0), P(x1, y1, z0), P(x0, y1, z0)], rear or side, 'rear'))
        F.append(([P(x1, y0, z1), P(x0, y0, z1), P(x0, y1, z1), P(x1, y1, z1)], front or side, 'front'))
        F.append(([P(x0, y1, z0), P(x1, y1, z0), P(x1, y1, z1), P(x0, y1, z1)], top or side, 'top'))
        F.append(([P(x0, y0, z1), P(x0, y0, z0), P(x0, y1, z0), P(x0, y1, z1)], side, 'left'))
        F.append(([P(x1, y0, z0), P(x1, y0, z1), P(x1, y1, z1), P(x1, y1, z0)], side, 'right'))
    for wx0, wx1 in ((-1.08, -0.70), (0.70, 1.08)):          # tyres
        for wz in (-1.35, 1.35):
            box(wx0, wx1, 0.0, 0.62, wz - 0.38, wz + 0.38, 'W')
    box(-1.0, 1.0, 0.26, 0.80, -2.05, 2.05, 'S', rear='K', top='K')     # body
    box(-0.78, 0.78, 0.80, 1.24, -1.05, 0.85, 'S', rear='G', top='K')   # cabin
    return F


def render(yaw_deg, scale=None, ox=None):
    yaw = math.radians(yaw_deg)
    cy, sy = math.cos(yaw), math.sin(yaw)
    cam = (0.0, 2.3, -7.6)
    pitch = math.radians(12)
    cp, sp = math.cos(pitch), math.sin(pitch)

    def proj(p):
        x, y, z = p
        x, z = x * cy + z * sy, -x * sy + z * cy
        x, y, z = x - cam[0], y - cam[1], z - cam[2]
        y, z = y * cp + z * sp, -y * sp + z * cp
        return (x / z, -y / z, z)

    faces = []
    for quad, code, kind in model():
        pts = [proj(p) for p in quad]
        area = sum(pts[i][0] * pts[(i + 1) % 4][1] - pts[(i + 1) % 4][0] * pts[i][1] for i in range(4))
        if area >= 0:
            continue                          # back face
        depth = sum(p[2] for p in pts) / 4
        faces.append((depth, pts, code, kind))
    faces.sort(key=lambda f: -f[0])           # far first
    if scale is None:
        return faces
    img = Image.new('L', (W * SS, H * SS), 0)
    d = ImageDraw.Draw(img)
    codes = {'K': 1, 'S': 2, 'W': 3, 'G': 4, 'R': 5}
    sx, syy = scale, scale / 1.5
    allp = [p for f in faces for p in f[1]]
    oy = H - 9.0 - max(p[1] for p in allp) * syy     # bottom at line 39: lights and wheels in different cell rows
    for depth, pts, code, kind in faces:
        q = [((ox + p[0] * sx) * SS, (oy + p[1] * syy) * SS) for p in pts]
        d.polygon(q, fill=codes[code])
        if kind == 'rear' and code == 'K':
            def lerp(a, b, t): return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            p0, p1, p2, p3 = q                # bottom-left, bottom-right, top-right, top-left
            for t0, t1 in ((0.07, 0.36), (0.64, 0.93)):
                a0 = lerp(lerp(p0, p3, 0.42), lerp(p1, p2, 0.42), t0)
                a1 = lerp(lerp(p0, p3, 0.42), lerp(p1, p2, 0.42), t1)
                b0 = lerp(lerp(p0, p3, 0.72), lerp(p1, p2, 0.72), t0)
                b1 = lerp(lerp(p0, p3, 0.72), lerp(p1, p2, 0.72), t1)
                d.polygon([a0, a1, b1, b0], fill=codes['R'])
    inv = {v: k for k, v in codes.items()}
    px = img.load()
    rows = []
    for y in range(H):
        row = ''
        for x in range(W):
            cnt = {}
            for yy in range(y * SS, (y + 1) * SS):
                for xx in range(x * SS, (x + 1) * SS):
                    v = px[xx, yy]
                    cnt[v] = cnt.get(v, 0) + 1
            v = max(cnt, key=cnt.get)
            row += inv.get(v, '.')
        rows.append(row)
    return rows


def frames():
    """all poses, scaled so the straight car is 68 px wide and every pose fits"""
    f0 = render(0)
    xs = [p[0] for f in f0 for p in f[1]]
    scale = 68.0 / (max(xs) - min(xs))
    out = []
    for yv in YAWS:
        fs = render(yv)
        xs = [p[0] for f in fs for p in f[1]]
        ox = W / 2 - (min(xs) + max(xs)) / 2 * scale
        out.append(render(yv, scale, ox))
    return out


if __name__ == '__main__':
    for yv, fr in zip(YAWS, frames()):
        print('yaw', yv)
        print('\n'.join(fr))
