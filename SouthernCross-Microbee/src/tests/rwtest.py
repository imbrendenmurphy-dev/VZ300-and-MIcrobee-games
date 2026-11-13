# Check the runway selection maths in the emulator: position + heading -> chosen runway, range, offset
import sys, os
sys.path.insert(0, os.getcwd()); sys.path.insert(0, 'tools')
import run as R
from z80emu import Bee, Z80
S = R.syms
m = Bee(); cpu = Z80(m)
d = open('build/SCROSS_T.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
while cpu.pc != S['mloop']: cpu.step()
def w16(n, v): m.ram[S[n]:S[n]+2] = (v & 0xffff).to_bytes(2, 'little')
def r16(n): v = m.ram[S[n]] | m.ram[S[n]+1] << 8; return v - 65536 if v > 32767 else v
def sel(px, pz, hdg, gnd=0):
    w16('px', px); w16('pz', pz); w16('hdg', hdg << 8); m.ram[S['ongnd']] = gnd
    cpu.sp = 0x7000; m.ram[0x7000:0x7002] = b'\0\0'; cpu.pc = S['rwsel']
    while cpu.pc != 0: cpu.step()
    if not m.ram[S['selok']]: return None
    p = r16('selp'); name = bytes(m.ram[p+10:p+19]).decode().strip()
    num = ['36','18','09','27'][m.ram[S['sax']]*2 + (1 if m.ram[S['srev']] else 0)]
    return name + ' ' + num, r16('srng'), r16('sac')
cases = [((0, -1500, 0), 'CORAL BAY 36', 1680, 0),
         ((10, -1500, 0), 'CORAL BAY 36', 1680, 10),      # 10 m east of the line, heading north: right
         ((0, 2700, 128), 'CORAL BAY 18', 1680, 0),       # from the north, heading south
         ((10, 2700, 128), 'CORAL BAY 18', 1680, -10),    # 10 m east heading south: left
         ((4400, 2200, 64), 'TURTLE IS 09', 1433, 0),
         ((4400, 2190, 64), 'TURTLE IS 09', 1433, 10),    # south of the line heading east: right
         ((7600, 2200, 192), 'TURTLE IS 27', 1433, 0),
         ((4800, 5500, 0), 'HOPE IS 36', 1350, 0),
         ((7775 - 1300, -3000, 64), 'LIZARD IS 09', 1375, 0),
         ((0, -1500, 64), 'LIZARD IS 09', 7850, -1500),    # heading east from final: Turtle is 32 deg off, Lizard is ahead
         ((1500, 2000, 64), 'TURTLE IS 09', 4333, 200),   # lined up with Turtle from the coast
         ((0, -1500, 192), None, 0, 0)]                    # heading west, out to sea: nothing
bad = 0
for (px, pz, h), name, rng, off in cases:
    r = sel(px, pz, h)
    ok = (r is None and name is None) or (r and r[0] == name and abs(r[1] - rng) <= 1 and r[2] == off)
    bad += not ok
    print('ok ' if ok else 'BAD', (px, pz, h), r)
r = sel(0, 600, 0, gnd=1); print('on ground mid-runway:', r)
print('bad', bad)
