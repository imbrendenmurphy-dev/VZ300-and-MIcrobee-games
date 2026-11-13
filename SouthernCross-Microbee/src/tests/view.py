# Render one frozen view: python3 tests/view.py px,pz,alt,hdg,pitch,roll out.png [detail]
import sys, os
sys.path.insert(0, os.getcwd()); sys.path.insert(0, os.path.join(os.getcwd(), 'tools'))
import run as R
from z80emu import Bee, Z80
S = R.syms
def view(st, out, det=3):
    m = Bee(); cpu = Z80(m)
    d = open('build/SCROSS_T.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
    w16 = lambda n, v: m.ram.__setitem__(slice(S[n], S[n]+2), (v & 0xffff).to_bytes(2, 'little'))
    fr = 0; ft = []
    while fr < 4:
        if cpu.pc == S['flip']:
            fr += 1; ft.append(cpu.t)
            if fr == 1:
                for n, v in zip(('px','pz','alt','hdg','pitch','roll'), (st[0], st[1], st[2], st[3]<<8, st[4]<<8, st[5]<<8)): w16(n, v)
                m.ram[S['crashed']] = 1; m.ram[S['crtimer']] = 0; m.ram[S['detail']] = det
                m.ram[S['ongnd']] = 1 if st[2] == 0 else 0
        cpu.step()
    while cpu.pc != S['timing']: cpu.step()
    R.render(m).save(out)
    return ft[-1] - ft[-2]
if __name__ == '__main__':
    st = tuple(int(x) for x in sys.argv[1].split(','))
    t = view(st, sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 3)
    print('%d T  %.2f fps' % (t, 3375000 / t))
