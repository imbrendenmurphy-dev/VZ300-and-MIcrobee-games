"""Tiny flat-shaded polygon renderer for pre-computed VZ animation frames."""
import numpy as np

def rotmat(ax, ay, az):
    cx, sx = np.cos(ax), np.sin(ax)
    cy, sy = np.cos(ay), np.sin(ay)
    cz, sz = np.cos(az), np.sin(az)
    Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return Rz @ Ry @ Rx

def axis_rot(axis, ang):
    axis = np.asarray(axis, float); axis /= np.linalg.norm(axis)
    x, y, z = axis; c, s = np.cos(ang), np.sin(ang); C = 1 - c
    return np.array([[c + x*x*C, x*y*C - z*s, x*z*C + y*s],
                     [y*x*C + z*s, c + y*y*C, y*z*C - x*s],
                     [z*x*C - y*s, z*y*C + x*s, c + z*z*C]])

def cube():
    v = np.array([[x, y, z] for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)], float)
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return v, faces

def octahedron():
    v = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], float) * 1.35
    faces = [[0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4], [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]]
    return v, faces

def torus(R=1.0, r=0.42, nu=14, nv=8):
    v = []
    for i in range(nu):
        u = 2 * np.pi * i / nu
        for j in range(nv):
            w = 2 * np.pi * j / nv
            v.append([(R + r * np.cos(w)) * np.cos(u), (R + r * np.cos(w)) * np.sin(u), r * np.sin(w)])
    faces = []
    for i in range(nu):
        for j in range(nv):
            a = i * nv + j; b = ((i + 1) % nu) * nv + j
            c = ((i + 1) % nu) * nv + (j + 1) % nv; d = i * nv + (j + 1) % nv
            faces.append([a, b, c, d])
    return np.array(v), faces

def render(verts, faces, R, W, H, scale, light=(-0.4, -0.6, -1.0), sx=2.0, sy=3.0, dist=7.0):
    """Returns intensity image (H x W) in [0,1], -1 = background. Pixel aspect sx:sy."""
    L = np.asarray(light, float); L /= np.linalg.norm(L)
    P = verts @ R.T
    zb = np.full((H, W), 1e9); img = np.full((H, W), -1.0)
    yy, xx = np.mgrid[0:H, 0:W].astype(float)
    # physical coords of pixel centres
    px = (xx + 0.5 - W / 2) * sx; py = (yy + 0.5 - H / 2) * sy
    def proj(p):
        f = dist / (dist + p[2])
        return p[0] * f * scale, p[1] * f * scale
    for f in faces:
        q = P[f]
        n = np.cross(q[1] - q[0], q[2] - q[0])
        if np.linalg.norm(n) == 0: continue
        n /= np.linalg.norm(n)
        c = q.mean(0)
        if np.dot(n, c) < 0: n = -n           # outward normal (object centred at origin)
        if np.dot(n, c - np.array([0, 0, -dist])) >= 0: continue   # faces away from camera
        inten = max(0.0, np.dot(n, L)) * 0.8 + 0.2
        pts = [proj(p) for p in q]
        zc = c[2]
        # rasterise polygon via half-planes (convex)
        inside = np.ones((H, W), bool)
        k = len(pts)
        area = 0
        for i in range(k):
            x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % k]
            area += x0 * y1 - x1 * y0
        sgn = 1 if area > 0 else -1
        for i in range(k):
            x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % k]
            e = (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0)
            inside &= (e * sgn >= 0)
        m = inside & (zc < zb)
        zb[m] = zc; img[m] = inten
    return img
