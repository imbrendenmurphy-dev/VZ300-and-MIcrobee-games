import json, struct
from z80emu import VZ, screenshot, FIELD
import build

class Sim:
    def __init__(self, rebuild=True):
        self.org, self.code, self.S = build.build(False)
        vz = self.vz = VZ(); vz.load(self.org, self.code); vz.pc = self.org
        S = self.S
        # title: wait until it polls for SPACE, then press
        vz.run_until(S['title__w2'], 20_000_000)
        screenshot(vz, 'title.png')
        vz.press('SPACE'); vz.run_until(S['mainloop'], 20_000_000); vz.release('SPACE')
        self.frames = 0
    def frame(self, n=1):
        """run n main-loop frames; returns list of T-states per frame"""
        vz, S = self.vz, self.S
        out = []
        for i in range(n):
            t0 = vz.t
            vz.step()
            vz.run_until(S['mainloop'], 30_000_000)
            out.append(vz.t - t0); self.frames += 1
        return out
    def s32(self, name):
        a = self.S[name]; v = int.from_bytes(self.vz.m[a:a+4], 'little', signed=True); return v / 65536
    def ang(self, name):
        a = self.S[name]; v = int.from_bytes(self.vz.m[a+1:a+3], 'little', signed=True); return v * 360 / 65536
    def state(self):
        vz, S = self.vz, self.S
        return dict(x=self.s32('px'), y=self.s32('py'), z=self.s32('pz'), spd=self.s32('spd'),
                    yaw=self.ang('yaw3') % 360, pitch=self.ang('pitch3'), roll=self.ang('roll3'),
                    thr=vz.m[S['thr']], gnd=vz.m[S['ongnd']], stall=vz.m[S['stall']], crash=vz.m[S['crash']],
                    vs=vz.ws(S['vs88']) / 256, nf=vz.m[S['nf']])
    def poke32(self, name, val):
        a = self.S[name]; self.vz.m[a:a+4] = int(val * 65536).to_bytes(4, 'little', signed=True)
    def pokeang(self, name, deg):
        a = self.S[name]; v = int(deg * 65536 / 360) & 0xFFFF
        self.vz.m[a] = 0; self.vz.m[a+1] = v & 255; self.vz.m[a+2] = v >> 8
    def shot(self, fname):
        return screenshot(self.vz, fname)
