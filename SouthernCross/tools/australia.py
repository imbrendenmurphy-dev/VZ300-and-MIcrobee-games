#!/usr/bin/env python3
"""A stylised, exaggerated 'satellite view' of Australia in the VZ300's four
colours (green, yellow, blue, red on a blue sea).

Coastline from real longitude/latitude points; land colour from a made-up
rainfall field: rainforest green on the wet east and tropical north, savanna
dithered into ochre desert, red dunes in the centre, Lake Eyre in blue, the
reef as green specks off Queensland.  Ordered (Bayer) dithering gives smooth
satellite-style gradients at 128 x 64.
"""
import math
from PIL import Image, ImageDraw

G, Y, B, R = 0, 1, 2, 3

MAINLAND = [
    (142.5, -10.7), (143.5, -12.5), (143.8, -14.4), (145.3, -15.0), (145.5, -16.4), (145.8, -16.9),
    (146.1, -18.2), (146.8, -19.3), (148.4, -20.3), (149.2, -21.1), (150.1, -22.2), (150.8, -23.0),
    (151.3, -23.9), (152.4, -24.7), (153.1, -25.6), (153.1, -27.5), (153.6, -28.6), (153.1, -30.3),
    (152.5, -32.0), (151.8, -32.9), (151.2, -33.9), (150.7, -35.1), (150.1, -36.3), (149.9, -37.5),
    (148.3, -37.8), (147.0, -38.2), (146.4, -39.1), (145.5, -38.6), (144.9, -38.3), (144.0, -38.7),
    (142.5, -38.4), (141.6, -38.3), (140.4, -37.9), (139.8, -37.2), (139.6, -36.6), (138.9, -35.6),
    (138.1, -35.6), (138.5, -34.9), (138.0, -34.0), (137.8, -33.0), (137.4, -33.8), (136.9, -35.0),
    (135.9, -34.7), (135.5, -33.9), (134.2, -32.8), (133.7, -32.1), (132.4, -32.0), (131.1, -31.5),
    (128.9, -31.7), (126.0, -32.3), (124.0, -33.0), (121.9, -33.9), (119.9, -33.9), (117.9, -35.0),
    (116.0, -34.9), (115.1, -34.4), (115.0, -33.6), (115.7, -32.0), (115.1, -30.0), (114.6, -28.8),
    (114.0, -27.3), (113.5, -26.0), (113.6, -24.9), (113.4, -23.6), (113.9, -22.3), (114.1, -21.8),
    (115.9, -21.1), (117.2, -20.7), (118.6, -20.3), (120.2, -19.7), (121.5, -18.6), (122.2, -18.0),
    (122.4, -17.0), (122.9, -16.4), (123.7, -16.0), (124.6, -15.0), (125.6, -14.2), (126.8, -13.8),
    (127.9, -14.5), (128.1, -15.5), (129.0, -15.0), (129.6, -14.9), (130.0, -13.2), (130.8, -12.4),
    (131.9, -11.3), (132.6, -11.5), (133.6, -11.8), (135.0, -12.0), (136.0, -12.0), (136.8, -12.2),
    (136.5, -13.3), (135.9, -13.8), (135.5, -15.0), (136.5, -15.9), (137.7, -16.6), (139.3, -17.4),
    (140.8, -17.5), (141.4, -16.4), (141.6, -14.5), (141.5, -13.5), (141.9, -12.6), (142.1, -11.4),
]
TASMANIA = [(144.6, -40.7), (146.5, -41.1), (148.3, -40.9), (148.3, -42.2), (147.9, -43.2),
            (146.9, -43.6), (146.0, -43.6), (145.2, -42.2), (144.7, -41.2)]
KANGAROO_IS = [(136.6, -35.7), (137.6, -35.6), (138.1, -35.8), (137.4, -36.1), (136.6, -36.0)]
LAKE_EYRE = (137.3, -28.4)
REEF = [(146.0, -16.5), (146.6, -17.5), (147.5, -18.6), (148.6, -19.6), (150.0, -20.9),
        (151.3, -21.8), (152.4, -22.8), (145.3, -14.8), (144.2, -13.0)]

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

def _dist_to(lon, lat, pts):
    return min(math.hypot((lon - a) * 0.9, lat - b) for a, b in pts)

def aridity(lon, lat):
    """0 = wet rainforest .. 1 = red centre"""
    east = [p for p in MAINLAND if p[0] > 145.0 and p[1] > -38.0]
    north = [p for p in MAINLAND if p[1] > -16.5]
    rain = 0.0
    rain = max(rain, 1.05 * math.exp(-_dist_to(lon, lat, east) / 2.6))
    rain = max(rain, 0.95 * math.exp(-_dist_to(lon, lat, north) / 4.0) * (1 if lat > -19 else 0.6))
    rain = max(rain, 0.80 * math.exp(-math.hypot(lon - 116.0, lat + 34.0) / 2.4))       # south-west
    rain = max(rain, 0.70 * math.exp(-math.hypot((lon - 143.5) * 0.9, lat + 37.8) / 2.5))  # Victoria
    rain = max(rain, 0.55 * math.exp(-math.hypot(lon - 138.7, lat + 35.0) / 1.6))       # Adelaide
    if lat < -40:
        rain = 1.1                                                                      # Tasmania
    a = 0.68 * (1.0 - min(1.0, rain))                                                   # ochre at most
    a += 0.42 * math.exp(-((lon - 134.0) ** 2 + ((lat + 24.5) * 1.3) ** 2) / 22.0)      # the red centre
    if lat < -29.5 and 125.0 < lon < 133.5:
        a = min(a, 0.55)                                                                # Nullarbor
    return max(0.0, min(1.0, a))

def draw(img, ox, oy, width, scale_y=1.5):
    """Draw into img (rows of colour indices) with the continent's west edge at
    ox, Cape York's latitude at oy, width pixels across.  scale_y: pixels are
    taller than wide on the VZ, so latitude is squashed by this factor."""
    H = len(img); W = len(img[0])
    lon0, lon1, lat0 = 113.2, 153.7, -10.6
    kx = width / (lon1 - lon0)
    ky = kx * 1.07 / scale_y                       # (a degree of latitude is longer)
    def to_px(lon, lat):
        return (ox + (lon - lon0) * kx * 0.92, oy + (lat0 - lat) * ky)
    SS = 4
    m = Image.new('L', (W * SS, H * SS), 0)
    d = ImageDraw.Draw(m)
    for poly in (MAINLAND, TASMANIA, KANGAROO_IS):
        d.polygon([(x * SS, y * SS) for x, y in (to_px(*p) for p in poly)], fill=255)
    m = m.resize((W, H), Image.BOX)
    mp = m.load()
    def from_px(x, y):
        return (lon0 + (x - ox) / (kx * 0.92), lat0 - (y - oy) / ky)
    land = [[mp[x, y] >= 120 for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if not land[y][x]:
                # shallow water and the reef: green specks just off the coast
                near = any(0 <= x + a < W and 0 <= y + b < H and land[y + b][x + a]
                           for a in (-1, 0, 1) for b in (-1, 0, 1))
                lon, lat = from_px(x + 0.5, y + 0.5)
                if any(math.hypot((lon - a) * 0.9, lat - b) < 0.75 for a, b in REEF) and (x + y) % 2 == 0:
                    img[y][x] = G
                elif near and (x * 3 + y) % 4 == 0 and lon > 140:
                    img[y][x] = G
                continue
            lon, lat = from_px(x + 0.5, y + 0.5)
            a = aridity(lon, lat)
            t = (BAYER[y & 3][x & 3] + 0.5) / 16.0
            # four bands: green | green/yellow | yellow | yellow/red | red
            v = a * 4.0
            band = int(v)
            frac = v - band
            pal = [G, Y, Y, R, R]
            if band == 0:
                c = Y if frac > t + 0.25 else G
            elif band == 1:
                c = Y if frac * 0.8 + 0.2 > t else G
            elif band == 2:
                c = R if frac > t + 0.45 else Y
            else:
                c = R if (frac * 0.7 + 0.3) > t else Y
            # dune streaks across the central deserts (NNW-SSE)
            if a > 0.6 and (x - y * 2) % 5 == 0 and c == Y:
                c = R
            # salt lakes
            if math.hypot((lon - LAKE_EYRE[0]) * 0.9, lat - LAKE_EYRE[1]) < 1.0:
                c = B if (x + y) % 3 else Y
            if math.hypot((lon - 135.6) * 0.9, lat + 31.0) < 0.6 or math.hypot((lon - 138.0) * 0.9, lat + 30.5) < 0.5:
                c = B if (x + y) % 2 else Y
            img[y][x] = c
    return img

if __name__ == '__main__':
    import sys
    W, H = 128, 64
    img = [[B] * W for _ in range(H)]
    draw(img, 58, 25, 68)
    pal = [(48, 210, 0), (193, 229, 0), (76, 58, 180), (154, 50, 54)]
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W):
            im.putpixel((x, y), pal[img[y][x]])
    im.resize((W * 6, H * 9), Image.NEAREST).save(sys.argv[1])
