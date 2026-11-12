import json
from z80emu import VZ, screenshot, FIELD
import build
from PIL import Image

class Sim:
    def __init__(self):
        import os
        if os.environ.get('PREBUILT'):
            d = open('VZFLIGHT.VZ', 'rb').read()
            self.org = d[22] | d[23] << 8
            self.code = d[24:]
            self.S = json.load(open('syms.json'))
        else:
            self.org, self.code, self.S = build.build(False)
        vz = self.vz = VZ(); vz.load(self.org, self.code); vz.pc = self.org
    def fields(self, n):
        self.vz.run_t(n * FIELD)
    def until(self, label, maxt=200_000_000):
        return self.vz.run_until(self.S[label], maxt)
    def shot(self, f):
        return screenshot(self.vz, f, scale=2)
    def tap(self, key, fields=4, after=6):
        self.vz.press(key); self.fields(fields); self.vz.release(key); self.fields(after)
    def s32(self, name):
        a = self.S[name]; return int.from_bytes(self.vz.m[a:a+4], 'little', signed=True) / 65536
    def ang(self, name):
        a = self.S[name]; return int.from_bytes(self.vz.m[a+1:a+3], 'little', signed=True) * 360 / 65536
    def b(self, name): return self.vz.m[self.S[name]]
    def w(self, name): return self.vz.ws(self.S[name])
    def state(self):
        return dict(x=round(self.s32('px')), y=round(self.s32('py'),1), z=round(self.s32('pz')), spd=round(self.s32('spd'),1),
                    hdg=round(self.ang('yaw3') % 360), pit=round(self.ang('pitch3'),1), rol=round(self.ang('roll3'),1),
                    thr=self.b('thr'), gnd=self.b('ongnd'), crash=self.b('crash'), goal=self.b('goalidx'),
                    t=self.w('msec'), fuel=self.w('fuel'), mdone=self.b('mdone'), nf=self.b('nf'))

def sheet(files, out, cols=2):
    ims = [Image.open(f) for f in files]
    w, h = ims[0].size
    rows = (len(ims) + cols - 1) // cols
    s = Image.new('RGB', (cols * (w + 6), rows * (h + 6)), (0, 0, 0))
    for i, im in enumerate(ims):
        s.paste(im, ((i % cols) * (w + 6), (i // cols) * (h + 6)))
    s.save(out)
