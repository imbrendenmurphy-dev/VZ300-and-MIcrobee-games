# mul168 (HL*A>>7 toward zero), mulw and smul8 against exact arithmetic
import sys, os, random
sys.path.insert(0, os.getcwd()); sys.path.insert(0, 'tools')
import run as R
from z80emu import Bee, Z80
S = R.syms
m = Bee(); cpu = Z80(m)
d = open('build/SCROSS_T.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
while cpu.pc != S['mloop']: cpu.step()
def call(addr, **r):
    for k, v in r.items(): setattr(cpu, k, v & 0xff)
    cpu.sp = 0x7000; m.ram[0x7000:0x7002] = b'\0\0'; cpu.pc = addr; t = cpu.t
    while cpu.pc != 0: cpu.step()
    v = cpu.h << 8 | cpu.l
    return (v - 65536 if v > 32767 else v), cpu.t - t
def tz(n, k): q = abs(n) // k; return q if n >= 0 else -q
random.seed(7); bad = 0; tt = []
cases = [(x, a) for x in (0, 1, -1, 255, 256, -256, 32767, -32768, 128, -129) for a in (0, 1, -1, 127, -127, 64)]
cases += [(random.randint(-32768, 32767), random.randint(-127, 127)) for _ in range(4000)]
for x, a in cases:
    want = tz(x * a, 128)
    if not -32768 <= want <= 32767: continue
    got, t = call(S['mul168'], h=x >> 8, l=x, a=a); tt.append(t)
    if got != want:
        bad += 1
        if bad < 8: print('mul168 BAD', x, a, got, want)
for _ in range(2000):
    a, b = random.randint(-127, 127), random.randint(-127, 127)
    got, _ = call(S['smul8'], a=a, b=b)
    if got != a * b:
        bad += 1
        if bad < 8: print('smul8 BAD', a, b, got)
print('bad', bad, 'mul168 average %.0f T' % (sum(tt) / len(tt)))
