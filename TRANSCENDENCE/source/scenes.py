# camera tracks for the human chapters
import models
HEAD = [round(v) for v in models.LYING[0][3]]
def track(entries):
    out = []
    for i, (t, tx, ty, tz, yaw, pitch, zoom) in enumerate(entries):
        if i + 1 < len(entries):
            ln = entries[i+1][0] - t
            assert ln >= 257, ('segment too short', t, ln)
            rate = (1 << 24) // ln
            assert rate < 65536
        else:
            rate = 0
        out += [t & 255, t >> 8, rate & 255, rate >> 8, tx & 255, ty & 255, tz & 255, yaw & 255, (yaw >> 8) & 255, pitch, zoom & 255, zoom >> 8]
        out.insert(len(out) - 12 + 12, 0)  # pad to 13
    return out
hx, hy, hz = HEAD
CAM3 = track([
    (0,    hx, hy, hz,   0, 60, 1150),
    (560,  hx, hy, hz,  22, 58, 980),
    (1200, 0, -31, -8,  64, 36, 235),
    (1700, 0, -31, -14, 112, 30, 265),
    (2048, 0, -31, -20, 140, 40, 400),
])
# IV: entity enters (0-380), rising (380-668), tai chi (668-3072) with a full orbit
CAM4 = track([
    (0,    hx, hy, hz,   140, 56, 700),
    (380,  hx, hy, hz,   176, 50, 730),
    (668,  0, -1, 0,     206, 16, 212),
    (1200, 0, 0, 0,      262, 22, 205),
    (1800, 0, 0, 0,      330, 10, 222),
    (2400, 0, 1, 0,      398, 24, 200),
    (3072, 0, 0, 0,      466, 14, 210),
])
# V: stillness, then the camera lifts to follow the rising consciousness
CAM5 = track([
    (0,    0, 0, 0,      466, 14, 210),
    (380,  0, -4, 0,     490, 18, 220),
    (700,  0, 12, 0,     530, 14, 190),
    (1000, 0, 42, 0,     566, 8, 160),
    (1280, 0, 74, 0,     600, 4, 130),
])
