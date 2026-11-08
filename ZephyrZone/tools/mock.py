import sys, math
sys.path.insert(0, 'tools')
from geom import *
from vzpal import to_img
import creatures as CR, hero as HE
from draw import crop
A, B, SKY, ACC = 0, 1, 2, 3
def ground(pix, zs, camx, hz):
    for y in range(hz, 64):
        d = y - hz + 1; z = ground_z(d); w = FX * TX / z
        par = int((z + zs) // TZ) & 1
        dz = ground_z(d) - ground_z(d + 1)
        for x in range(128):
            X = camx + (x - 64) * TX / w
            sx = int(math.floor(X / TX)) & 1
            if dz > TZ * 0.75:
                c = (A if ((x + y) & 1) else B) if (sx or w < 1.6) else B
            else: c = A if sx ^ par else B
            pix[y][x] = c
def blit(pix, g, sx, sy, ax, ay):
    for yy, r in enumerate(g):
        for xx, c in enumerate(r):
            X = int(sx) - ax + xx; Y = int(sy) - ay + yy
            if c >= 0 and 0 <= X < 128 and 0 <= Y < 64: pix[Y][X] = c
def sprite(name, f, z):
    k = level_of(z); g = CR.render(name, f, LEV_S[k])
    return g, len(g[0]) // 2, len(g) - 1
def frame(t, px, py):
    camx = 0.45 * px; hz = int(20 + py / 10)
    pix = [[SKY] * 128 for _ in range(64)]
    zs = t * 26
    ground(pix, zs, camx, hz)
    objs = []
    for i in range(8):     # trees and columns in rows
        z = (i * 220 - zs) % 1760 + 100
        objs.append(('lolly' if i % 2 else 'column', 0, (-170 if i % 3 else 140), 0, z))
    objs.append(('blobbit', t % 3, 30, 60, 500 - t * 20))
    objs.append(('blobbit', (t + 1) % 3, -40, 70, 700 - t * 20))
    objs.append(('spindle', t % 3, 80, 40, 1200 - t * 30))
    objs.append(('hopcap', t % 3, -20, 0, 900 - t * 25))
    objs.append(('fireball', t % 2, 10, 50, 300))
    objs.sort(key=lambda o: -o[4])
    for n, f, x, y, z in objs:
        if z < 60: continue
        sx, sy = proj(x, y, z, camx, hz)
        g, ax, ay = sprite(n, f, z)
        blit(pix, g, sx, sy, ax, ay)
    # hero + shadow
    hsx, hsy = proj(px, py, ZP, camx, hz)
    gsx, gsy = proj(px, 0, ZP, camx, hz)
    for dx in range(-6, 7):
        for dy in (-1, 0, 1):
            if abs(dx) < 6 - abs(dy) * 3 and ((dx + dy) & 1) == 0:
                X, Y = int(gsx) + dx, int(gsy) + dy
                if 0 <= X < 128 and 0 <= Y < 64: pix[Y][X] = ACC
    hg = crop(HE.hero(flame=1 + t % 2, wave=t))[0]
    blit(pix, hg, hsx, hsy, len(hg[0]) // 2, len(hg) - 1)
    return pix
from PIL import Image
ims = [to_img(frame(t, px, py), 0, 3, 4) for t, (px, py) in enumerate([(0, 30), (60, 60), (-100, 10), (120, 95)])]
W, H = ims[0].size
out = Image.new('RGB', (W * 2 + 6, H * 2 + 6))
for i, im in enumerate(ims): out.paste(im, ((i % 2) * (W + 6), (i // 2) * (H + 6)))
out.save('build/mock.png')
