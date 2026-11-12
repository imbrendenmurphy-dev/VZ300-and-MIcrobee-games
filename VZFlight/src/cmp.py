"""render given poses with the Z80 code (calling the draw routines directly) and the float reference; stack images"""
import sys
from PIL import Image
from harness import Sim
from z80emu import PALETTE
import ref
def zrender(s, x, y, z, yaw, pitch, roll):
    vz, S = s.vz, s.S
    s.poke32('px', x); s.poke32('py', y); s.poke32('pz', z)
    s.pokeang('yaw3', yaw); s.pokeang('pitch3', pitch); s.pokeang('roll3', roll)
    vz.iff = 0; tt = {}
    for n in ('calctrig', 'setcam', 'buildmat', 'drawbg', 'drawgrid', 'drawobjs'):
        tt[n] = vz.call(S[n])
    im = Image.new('RGB', (128, 48)); px = im.load(); b0 = S['buf']
    for yy in range(48):
        for xb in range(32):
            b = vz.m[b0 + yy*32 + xb]
            for k in range(4): px[xb*4+k, yy] = PALETTE[(b >> (6-2*k)) & 3]
    return im, tt
def compare(poses, fname, eye=6.0):
    s = Sim(); s.frame(1)
    W, H = 384, 216
    sheet = Image.new('RGB', (W*2 + 6, (H + 6) * len(poses)), (0, 0, 0))
    for i, p in enumerate(poses):
        a, tt = zrender(s, *p); b = ref.render(*p, eye=eye)
        sheet.paste(a.resize((W, H), Image.NEAREST), (0, i*(H+6))); sheet.paste(b.resize((W, H), Image.NEAREST), (W+6, i*(H+6)))
        print(p, {k: v for k, v in tt.items()}, 'sum', sum(tt.values()))
    sheet.save(fname)
if __name__ == '__main__':
    compare([(0, 0, -960, 0, 0, 0), (0, 150, -2500, 0, -5, 0), (300, 400, -3000, 350, -8, 25), (-2000, 800, -1000, 300, 5, -40)], 'cmp1.png', eye=2.5)
