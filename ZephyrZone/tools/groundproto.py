import math, sys
sys.path.insert(0, 'tools')
from vzpal import to_img
from PIL import Image
FX, FY, CAMH, TX, TZ = 96, 64, 96, 32, 64
A, B, SKY, ACC = 0, 1, 2, 3
def frame(zs, camx, hz, variant):
    pix = [[SKY] * 128 for _ in range(64)]
    for y in range(hz, 64):
        d = y - hz + 1
        z = FY * CAMH / d
        w = FX * TX / z            # = d/2
        par = int((z + zs) // TZ) & 1
        row = pix[y]
        dz = FY * CAMH / d - FY * CAMH / (d + 1)
        for x in range(128):
            X = camx + (x - 64) * TX / w
            sx = int(math.floor(X / TX)) & 1
            if variant == 'raw':
                c = A if sx ^ par else B
            else:
                if dz > TZ * 0.75:           # aliasing band: stripes only, dithered
                    if w < 1.6: c = A if ((x + y) & 1) else B
                    else: c = (A if ((x + y) & 1) else B) if sx else B
                else:
                    c = A if sx ^ par else B
            row[x] = c
    for y in range(hz - 1, hz):
        for x in range(128): pix[y][x] = B if (x & 1) else SKY
    return pix
for variant in ('raw', 'haze'):
    ims = []
    for f in range(6):
        ims.append(to_img(frame(f * 26, f * 7, 20, variant), 0, 2, 3))
    W, H = ims[0].size
    out = Image.new('RGB', (W * 3 + 8, H * 2 + 4))
    for i, im in enumerate(ims): out.paste(im, ((i % 3) * (W + 4), (i // 3) * (H + 4)))
    out.save('build/proto_%s.png' % variant)
