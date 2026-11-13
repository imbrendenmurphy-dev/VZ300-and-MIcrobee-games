# Bench: median frame T-states for fixed scenes (+ optional PNG dumps)
import sys, os, statistics
sys.path.insert(0, os.getcwd()); sys.path.insert(0, os.path.join(os.getcwd(), 'tools'))
import run as R
from z80emu import Bee, Z80
S = R.syms
SCENES = {
 'runway':   (0, 20, 0, 0, 0, 0),
 'approach': (0, -1500, 100, 0, -3, 0),
 'climb':    (300, 600, 124, 50, 4, 5),
 'turn':     (-1141, -2900, 244, 118, 5, 25),
 'low':      (457, 2946, 69, 113, 8, 23),
}
def bench(name, st, out=None, frames=4):
    m = Bee(); cpu = Z80(m)
    d = open('build/SCROSS_T.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
    w16 = lambda n, v: m.ram.__setitem__(slice(S[n], S[n]+2), (v & 0xffff).to_bytes(2, 'little'))
    fr = 0; ft = []
    while fr < frames + 2:
        if cpu.pc == S['flip']:
            fr += 1; ft.append(cpu.t)
            if fr == 1:
                for n, v in zip(('px','pz','alt','hdg','pitch','roll'), (st[0], st[1], st[2], st[3]<<8, st[4]<<8, st[5]<<8)): w16(n, v)
                m.ram[S['crashed']] = 1; m.ram[S['ongnd']] = 1 if st[2] == 0 else 0
        cpu.step()
    while cpu.pc != S['timing']: cpu.step()
    if out: R.render(m).save(out)
    dts = [b - a for a, b in zip(ft[1:], ft[2:])]
    return statistics.median(dts)
if __name__ == '__main__':
    outdir = sys.argv[1] if len(sys.argv) > 1 else None
    tot = 0
    for n, st in SCENES.items():
        t = bench(n, st, os.path.join(outdir, n + '.png') if outdir else None)
        tot += t
        print('%-9s %7d T  %5.2f fps' % (n, t, 3375000 / t))
    print('average   %5.2f fps' % (3375000 / (tot / len(SCENES))))
