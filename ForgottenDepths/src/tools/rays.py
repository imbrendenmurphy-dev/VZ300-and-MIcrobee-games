"""Precomputed light ray tables.

Cells are 8x12 pixels on screen, so distances use dy*1.5 to give round light pools.
A ray is a list of segments [(level, [(dx,dy),...]), ...]; the engine walks
each ray cell by cell, lights the cell (max) and stops after an opaque cell.
"""
import math
import random

ASPECT = 1.5


def trace(angle, length, step=0.25):
    """cells along a ray from the centre of (0,0) in screen space (cell-width units)"""
    cells = []
    ca, sa = math.cos(angle), math.sin(angle)
    t = 0.0
    while t <= length:
        x = ca * t
        y = sa * t / ASPECT
        c = (int(math.floor(x + 0.5)), int(math.floor(y + 0.5)))
        if c != (0, 0) and (not cells or cells[-1][0] != c):
            cells.append((c, t))
        t += step
    return cells


def make_rays(angles, levels_fn, length):
    """levels_fn(dist, angle) -> level (0 = stop the ray here)"""
    rays = []
    for a in angles:
        segs = []
        for c, t in trace(a, length):
            d = math.hypot(c[0], c[1] * ASPECT)
            lv = levels_fn(d, a)
            if lv == 0:
                break
            if segs and segs[-1][0] == lv:
                segs[-1][1].append(c)
            else:
                segs.append((lv, [c]))
        if segs:
            rays.append(segs)
    return rays


def omni(r_near, r_far, near, far, n=None):
    n = n or max(16, int(2 * math.pi * r_far * 1.3))
    angles = [2 * math.pi * i / n for i in range(n)]

    def lv(d, a):
        if d <= r_near + 0.01:
            return near
        if d <= r_far + 0.01:
            return far
        return 0
    return make_rays(angles, lv, r_far + 0.6)


def cone(facing, seed, near, far, lit_len=6.0, dim_len=9.5, half=0.62, amb_near=1.6, amb_far=3.0):
    """player lantern: bright cone in facing direction + ambient pool.
    facing: angle (0 right, pi/2 down)."""
    rnd = random.Random(seed)
    rays = []
    # forward cone
    n = 15
    angles = [facing - half + 2 * half * i / (n - 1) for i in range(n)]
    for a in angles:
        off = abs(a - facing) / half          # 0 centre .. 1 edge
        ll = lit_len * (1.0 - 0.35 * off * off) + rnd.uniform(-0.7, 0.5)
        dl = dim_len * (1.0 - 0.45 * off * off) + rnd.uniform(-0.9, 0.6)
        rays += make_rays([a], lambda d, aa, ll=ll, dl=dl: near if d <= ll else (far if d <= dl else 0), dl + 0.6)
    # ambient all round
    m = 16
    ang = [2 * math.pi * i / m for i in range(m)]
    an = amb_near + rnd.uniform(-0.25, 0.2)
    af = amb_far + rnd.uniform(-0.5, 0.3)
    rays += make_rays(ang, lambda d, aa: near if d <= an else (far if d <= af else 0), af + 0.6)
    return prune(rays)


def prune(rays):
    """drop rays whose every cell is already covered with >= level by earlier rays
    and which would not reach further (keeps behaviour identical when unblocked;
    the engine handles occlusion per ray so keep rays with distinct paths)."""
    seen = set()
    out = []
    for r in rays:
        key = tuple((lv, tuple(cs)) for lv, cs in r)
        if key in seen:
            continue
        seen.add(key)
        out.append(r)
    return out


def steps(rays):
    return sum(len(cs) for r in rays for lv, cs in r)


def cellmap(rays):
    """max level per cell over all rays (no occlusion)"""
    m = {(0, 0): 0}
    for r in rays:
        for lv, cs in r:
            for c in cs:
                if m.get(c, 0) < lv:
                    m[c] = lv
    return m


def line(t):
    """cells from origin to target t (screen-space straight line)"""
    tx, ty = t
    n = int(max(abs(tx), abs(ty)) * 4) + 2
    out = []
    for i in range(n + 1):
        f = i / n
        c = (int(math.floor(tx * f + 0.5)), int(math.floor(ty * f + 0.5)))
        if not out or out[-1] != c:
            out.append(c)
    return out


def tree(m, origin_level):
    """shadow-casting tree: each cell's parent is the previous cell on its line from the origin.
    Returns preorder list of (dx, dy, level, nsub)."""
    m = dict(m)
    m[(0, 0)] = origin_level
    parent = {}
    todo = [c for c in m if c != (0, 0)]
    while todo:
        c = todo.pop()
        ln = line(c)
        p = ln[-2] if len(ln) >= 2 else (0, 0)
        if p not in m:
            m[p] = m[c]
            todo.append(p)
        parent[c] = p
    kids = {c: [] for c in m}
    for c, p in parent.items():
        kids[p].append(c)
    out = []

    def walk(c):
        i = len(out)
        out.append(None)
        for k in sorted(kids[c], key=lambda k: (abs(k[0]) + abs(k[1]), k)):
            walk(k)
        out[i] = (c[0], c[1], m[c], len(out) - i - 1)
    import sys
    sys.setrecursionlimit(10000)
    walk((0, 0))
    return out
