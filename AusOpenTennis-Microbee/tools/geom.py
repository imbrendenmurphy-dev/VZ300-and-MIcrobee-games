"""Court geometry for MICROBEE AUSTRALIAN OPEN TENNIS.

World coordinates are the VZ TENNIS II engine's (10.6 fixed point in the
game, integers here): X 0..256 (singles XL 32..XR 224, doubles 0..256),
Y 24 far baseline .. 232 near baseline, net at 128.

Screen: 512 x 256 (64 x 16 cells of 8 x 16). A pinhole perspective with the
horizon above the screen; ground rows chosen so that the net mesh fills cell
row 8 exactly (net foot at y = 143) and the near baseline sits in row 14."""
YFAR, YNEAR, YNET = 24, 232, 128
YSF, YSN = 72, 184
XL, XR, XC = 32, 224, 128
CX = 256
S_NEAR = 1.55          # px per world unit across at the near baseline
NETH = 14              # net height, world units

# solve sy(232)=228, sy(128)=143, sy(24)=84 for  sy = HZ + U / d(Y)
_A = None


def _solve():
    import math
    y_near, y_net, y_far = 228.0, 143.0, 84.0
    # u*a/(1+a) = y_near-y_far ; u*a/(2+a) = y_near-y_net
    r = (y_near - y_far) / (y_near - y_net)
    a = (2 - r) / (r - 1)
    u = (y_near - y_far) * (1 + a) / a
    return a, u, y_near - u


A, U, HZ = _solve()


def depth(Y):
    return 1.0 + A * (YNEAR - Y) / (YNEAR - YFAR)


def sy(Y):
    return HZ + U / depth(Y)


def scale(Y):
    """px per world unit horizontally at depth Y"""
    return S_NEAR / depth(Y)


def zscale(Y):
    """px per world unit of height (pixels are ~1.5x taller than wide)"""
    return 0.9 * scale(Y)


def sx(X, Y):
    return CX + (X - 128) * scale(Y)


def proj(X, Y, Z=0.0):
    return sx(X, Y), sy(Y) - Z * zscale(Y)


def world_y_of_row(y):
    """inverse of sy (for drawing)"""
    d = U / (y - HZ)
    return YNEAR - (d - 1.0) * (YNEAR - YFAR) / A


if __name__ == '__main__':
    print('A %.4f U %.1f HZ %.1f' % (A, U, HZ))
    for Y in (10, 24, 72, 128, 184, 232, 250):
        print(Y, 'sy %.1f scale %.3f  singles %.0f..%.0f doubles %.0f..%.0f' % (
            sy(Y), scale(Y), sx(XL, Y), sx(XR, Y), sx(0, Y), sx(256, Y)))
