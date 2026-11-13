# Scripted pilot: python3 tests/fly.py mode outdir frames   (mode: takeoff | land | next | hard | crash)
# 'next' presses N once (next airfield) and lands there, steering by the panel's approach readout
import sys, os
sys.path.insert(0, os.getcwd()); sys.path.insert(0, os.path.join(os.getcwd(), 'tools'))
import run as R
from z80emu import Bee, Z80
S = R.syms
K = {'N':14,'Q':17,'A':1,'O':15,'P':16,'T':20,'G':7,'R':18,'F':6,' ':55}
mode = sys.argv[1]; out = sys.argv[2]; os.makedirs(out, exist_ok=True)
m = Bee(); cpu = Z80(m)
d = open('build/SCROSS_T.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
def r8(n, o=0): return m.ram[S[n]+o]
def s8(n): v = r8(n); return v - 256 if v > 127 else v
def r16(n): v = m.ram[S[n]] | m.ram[S[n]+1] << 8; return v - 65536 if v > 32767 else v
def msg(): return bytes(m.ram[S['msgbuf']:S['msgbuf']+62]).decode('latin1').rstrip()
def row(r):
    start = (m.crtc[12] << 8 | m.crtc[13]) & 0x7ff
    return ''.join(chr(m.screen[(start + r*64 + c) & 0x7ff]) for c in range(64))
fr = 0; last = ''; t0 = None; shots = {}
maxfr = int(sys.argv[3]) if len(sys.argv) > 3 else 700
while fr < maxfr:
    if cpu.pc == S['flip']:
        fr += 1
        alt = r16('alt'); v = r8('vel', 1); pit = s8('pitch'+'') if False else (r16('pitch') >> 8)
        pz = r16('pz'); px = r16('px'); vs = r16('vs'); hd = r8('hdg', 1); gnd = r8('ongnd'); cr = r8('crashed')
        keys = set()
        if fr < 3:
            if mode != 'takeoff': keys.add('F')
        elif fr in (4, 5) and mode.startswith('next'):
            keys.add('N') if fr == 4 else None
        elif mode == 'takeoff':
            if r8('thr') < 100: keys.add('T')
            if gnd and v >= 28 and pit < 7: keys.add('A')
            if not gnd and pit < 6: keys.add('A')
            if not gnd and pit > 8: keys.add('Q')
        else:
            # approach autopilot: aim for 3 degree path to z=180, flare below 6 m
            rng = r16('srng') if r8('selok') else 180 - pz
            want = rng * 0.0524
            px = r16('sac') if r8('selok') else px
            if mode == 'crash':
                tp = -14
            elif alt > 3:
                tp = -3 + max(-3, min(3, (want - alt) / 4))
            else:
                tp = -1 if mode != 'hard' else -6
            if mode == 'hard' and alt < 12: tp = -5
            if pit < tp - 0.5: keys.add('A')
            if pit > tp + 0.5: keys.add('Q')
            if alt < 4 and mode in ('land', 'next') and r8('thr') > 0: keys.add('G')
            if px > 1: keys.add('O')
            elif px < -1: keys.add('P')
        m.keys = set(K[k] for k in keys)
        cur = msg()
        if cur != last:
            print('frame %4d alt %4d v %2d px %5d pz %5d hdg %3d vs %5d gnd %d crashed %d | %s' % (fr, alt, v, r16('px'), pz, hd, vs, gnd, cr, cur))
            last = cur
            shots[fr] = True
        if fr % 40 == 0 or fr in shots:
            pass
    cpu.step()
    if fr in shots and cpu.pc == S['timing'] and shots[fr]:
        R.render(m).save(os.path.join(out, 'f%04d.png' % fr)); shots[fr] = False
print('end: alt', r16('alt'), 'pz', r16('pz'), 'v', r8('vel',1), 'gnd', r8('ongnd'))
for r in range(8, 16): print('|' + row(r) + '|')
R.render(m).save(os.path.join(out, 'last.png'))
