"""World + shape data for the VZ flight sim (shared by the Z80 build and the float reference renderer)."""
GRN, YEL, BLU, RED = 0x00, 0x55, 0xAA, 0xFF


def box(w, h, d, col):
    v = [(-w, 0, -d), (w, 0, -d), (w, 0, d), (-w, 0, d), (-w, h, -d), (w, h, -d), (w, h, d), (-w, h, d)]
    e = [(0, 1), (1, 2), (2, 3), (3, 0), (4, 5), (5, 6), (6, 7), (7, 4), (0, 4), (1, 5), (2, 6), (3, 7)]
    return dict(verts=v, edges=[(a, b, col) for a, b in e])


def swapxz(sh):
    return dict(verts=[(z, y, x) for x, y, z in sh['verts']], edges=list(sh['edges']))


rwy = dict(
    verts=[(-2, 0, -64), (2, 0, -64), (2, 0, 64), (-2, 0, 64),
           (0, 0, -48), (0, 0, -32), (0, 0, -8), (0, 0, 8), (0, 0, 32), (0, 0, 48)],
    edges=[(0, 1, RED), (1, 2, RED), (2, 3, RED), (3, 0, RED), (4, 5, YEL), (6, 7, YEL), (8, 9, YEL)])

pyr = dict(
    verts=[(-64, 0, -64), (64, 0, -64), (64, 0, 64), (-64, 0, 64), (0, 48, 0)],
    edges=[(0, 1, YEL), (1, 2, YEL), (2, 3, YEL), (3, 0, YEL), (0, 4, YEL), (1, 4, YEL), (2, 4, YEL), (3, 4, YEL)])

lake = dict(
    verts=[(-40, 0, -16), (-16, 0, -40), (16, 0, -40), (40, 0, -16), (40, 0, 16), (16, 0, 40), (-16, 0, 40), (-40, 0, 16)],
    edges=[(i, (i + 1) % 8, BLU) for i in range(8)])

mast = dict(
    verts=[(0, 0, 0), (0, 40, 0), (-8, 0, 0), (8, 0, 0), (0, 0, -8), (0, 0, 8)],
    edges=[(0, 1, RED), (2, 1, YEL), (3, 1, YEL), (4, 1, YEL), (5, 1, YEL)])

SHAPES = {
    'rwy_ns': rwy,
    'rwy_ew': swapxz(rwy),
    'pyr': pyr,
    'lake': lake,
    'mast': mast,
    'hangar': box(6, 4, 8, RED),
    'tower': box(2, 10, 2, YEL),
    'bld_a': box(4, 6, 4, RED),
    'bld_b': box(3, 12, 3, YEL),
    'bld_c': box(6, 4, 3, RED),
}

# (shape, x, z, scale shift s (vertex unit = 2^s m), vis (x256 m), fl (fine-mode limit x256 m, 0 = never))
OBJECTS = [
    ('rwy_ns', 0, 0, 4, 44, 3),
    ('hangar', 140, -500, 2, 20, 6),
    ('tower', 140, -300, 2, 20, 6),
    ('pyr', -6000, 4000, 5, 62, 0),
    ('pyr', -3200, 6600, 4, 62, 0),
    ('pyr', -7200, 600, 4, 62, 0),
    ('pyr', 6500, 6800, 5, 62, 0),
    ('pyr', 5200, -6200, 4, 62, 0),
    ('rwy_ew', 5120, 2560, 4, 44, 3),
    ('hangar', 4700, 2720, 2, 20, 6),
    ('tower', 4900, 2720, 2, 20, 6),
    ('lake', -2600, -4200, 5, 40, 0),
    ('bld_a', 3000, -2600, 3, 28, 5),
    ('bld_b', 3200, -2900, 3, 28, 5),
    ('bld_c', 2800, -3000, 3, 28, 5),
    ('mast', 3500, -2500, 3, 28, 5),
]

# mountains for collision: x, z, half-base R (height = 0.75 * (R - max(|dx|,|dz|)))
MOUNTAINS = [(x, z, 64 << s) for (n, x, z, s, v, f) in OBJECTS if n == 'pyr']
