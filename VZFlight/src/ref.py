"""Float reference renderer (what the picture should look like) for comparison with the Z80 output."""
import math
from PIL import Image, ImageDraw
import world
from z80emu import PALETTE
COL = {0x00: 0, 0x55: 1, 0xAA: 2, 0xFF: 3}

def matrix(yaw, pitch, roll):
    sy, cy = math.sin(yaw), math.cos(yaw); sp, cp = math.sin(pitch), math.cos(pitch); sr, cr = math.sin(roll), math.cos(roll)
    r = (cy*cr + sy*sp*sr, -cp*sr, -sy*cr + cy*sp*sr)
    u = (-sy*sp*cr + cy*sr, cp*cr, -cy*sp*cr - sy*sr)
    f = (sy*cp, sp, cy*cp)
    return r, u, f

def render(x, y, z, yaw, pitch, roll, eye=6.0, grid=True, gridmode='inf'):
    yaw, pitch, roll = [math.radians(a) for a in (yaw, pitch, roll)]
    r, u, f = matrix(yaw, pitch, roll)
    cam = (x, y + eye, z)
    im = Image.new('RGB', (128, 48)); px = im.load()
    up = (r[1], u[1], f[1])
    for py in range(48):
        for pxx in range(128):
            d = ((pxx + 0.5 - 64) / 96, (24 - py - 0.5) / 64, 1)
            px[pxx, py] = PALETTE[2] if d[0]*up[0] + d[1]*up[1] + d[2]*up[2] > 0 else PALETTE[0]
    dr = ImageDraw.Draw(im)
    def view(p):
        d = (p[0]-cam[0], p[1]-cam[1], p[2]-cam[2])
        return tuple(sum(m[i]*d[i] for i in range(3)) for m in (r, u, f))
    def seg(p, q, col):
        a, b = view(p), view(q)
        near = 0.5
        if a[2] < near and b[2] < near: return
        if a[2] < near: a, b = b, a
        if b[2] < near:
            t = (near - a[2]) / (b[2] - a[2]); b = tuple(a[i] + t*(b[i]-a[i]) for i in range(3))
        pa = (64 + 96*a[0]/a[2], 24 - 64*a[1]/a[2]); pb = (64 + 96*b[0]/b[2], 24 - 64*b[1]/b[2])
        # crude clip of huge coords
        def clampseg(pa, pb):
            for _ in range(2):
                dx, dy = pb[0]-pa[0], pb[1]-pa[1]; L = max(abs(dx), abs(dy))
                if L > 4000:
                    # shorten pb toward pa while keeping it far off screen
                    k = 4000 / L; pb = (pa[0] + dx*k, pa[1] + dy*k)
                pa, pb = pb, pa
            return pa, pb
        if max(abs(pa[0]), abs(pa[1])) > 3000 and max(abs(pb[0]), abs(pb[1])) > 3000: 
            pass
        pa, pb = clampseg(pa, pb)
        dr.line([pa, pb], fill=PALETTE[COL[col]])
    if grid:
        gx = math.floor((x + 512) / 1024) * 1024 - 512; gz = math.floor((z + 512) / 1024) * 1024 - 512
        L = 60000 if gridmode == 'inf' else 4096
        for j in range(-3, 5):
            X = gx + j*1024 + 1024 - 1024
            X = math.floor((x + 512) / 1024) * 1024 + j*1024 - 512
            seg((X, 0, z - L), (X, 0, z + L), 0xAA)
            Z = math.floor((z + 512) / 1024) * 1024 + j*1024 - 512
            seg((x - L, 0, Z), (x + L, 0, Z), 0xAA)
    for (n, ox, oz, s, vis, fl) in world.OBJECTS:
        sh = world.SHAPES[n]; sc = 1 << s
        vs = [(ox + k[0]*sc, k[1]*sc, oz + k[2]*sc) for k in sh['verts']]
        for a, b, c in sh['edges']:
            seg(vs[a], vs[b], c)
    return im

if __name__ == '__main__':
    render(0, 0, -960, 0, 0, 0).resize((512, 288), Image.NEAREST).save('ref0.png')
