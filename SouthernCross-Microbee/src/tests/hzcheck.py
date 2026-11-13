# Render many random flight states and count lit ground pixels above the true horizon
import sys, os, math, random
sys.path.insert(0, os.getcwd()); sys.path.insert(0, os.path.join(os.getcwd(), 'tools'))
import run as R
from z80emu import Bee, Z80
S = R.syms
def w16(m, n, v): m.ram[S[n]:S[n]+2] = (v & 0xffff).to_bytes(2, 'little')
def check(state, save=None):
    m = Bee(); cpu = Z80(m)
    d = open('build/SCROSS_T.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
    flips = 0
    while True:
        if cpu.pc == S['flip']:
            flips += 1
            if flips == 1:
                px, pz, alt, hdg, pit, rol = state
                w16(m,'px',px); w16(m,'pz',pz); w16(m,'alt',alt); w16(m,'hdg',hdg<<8)
                w16(m,'pitch',pit<<8); w16(m,'roll',rol<<8); m.ram[S['crashed']] = 1; m.ram[S['ongnd']] = 0
            if flips == 3: break
        cpu.step()
    # back buffer just rendered = page shown after flip 2 -> render after flip executes
    sp0 = cpu.sp
    while cpu.pc != S['timing']: cpu.step()
    start = (m.crtc[12] << 8 | m.crtc[13]) & 0x7ff
    h = hdg*2*math.pi/256; p = pit*2*math.pi/256; r = rol*2*math.pi/256
    Uy = math.cos(p); Ry = 0.0
    # rolled: R'y = cr*0 - sr*Uy ; U'y = sr*0 + cr*Uy
    Rpy = -math.sin(r)*Uy; Upy = math.cos(r)*Uy; Fy = math.sin(p)
    bad = 0
    for row in range(8):
        for col in range(64):
            o = (start + row*64 + col) & 0x7ff
            code = m.screen[o]; bank = m.attr[o] & 15
            base = bank*2048 + (code-128)*16
            for ln in range(16):
                bits = m.pcg[base+ln]
                if not bits: continue
                for b in range(8):
                    if bits & (0x80 >> b):
                        x = col*8+b; y = row*16+ln
                        if 230 <= x <= 282 and 60 <= y <= 68: continue
                        s = Fy + Rpy*(x-256)/256 + Upy*(64-y)/(0.672*256)
                        if s > 6/(0.672*256): bad += 1
    if save: R.render(m).save(save)
    return bad
random.seed(int(sys.argv[1]) if len(sys.argv) > 1 else 1)
n = int(sys.argv[2]) if len(sys.argv) > 2 else 20
fails = 0
for i in range(n):
    st = (random.randint(-3000,3000), random.randint(-3000,3000), random.randint(40,600),
          random.randint(0,255), random.randint(-20,20), random.randint(-40,40))
    b = check(st)
    if b:
        fails += 1
        print('BAD', st, b)
        if fails == 1: check(st, save='bad.png')
print('fails', fails, 'of', n)
