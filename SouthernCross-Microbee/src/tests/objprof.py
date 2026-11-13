# Per-object cost for one frozen view: python3 tests/objprof.py px,pz,alt,hdg,pitch,roll [LOC]
import sys, os, re
sys.path.insert(0, os.getcwd()); sys.path.insert(0, 'tools')
import run as R
from z80emu import Bee, Z80
S = R.syms
st = tuple(int(x) for x in sys.argv[1].split(','))
loc = sys.argv[2] if len(sys.argv) > 2 else 'CORAL'
labs = {}; cmt = {}
src = open('build/%s.asm' % loc).read().splitlines()
# label addresses: re-assemble listing is not kept, so walk the binary layout via a quick assemble
import subprocess
subprocess.run([sys.executable, 'tools/z80asm.py', 'build/%s.asm' % loc, '/dev/null', 'build/%s.lst' % loc], capture_output=True)
for l in open('build/%s.lst' % loc):
    m = re.match(r'^(o\d+)\s+([0-9A-F]{4})$', l.strip())
    if m: labs[int(m.group(2), 16)] = m.group(1)
m = Bee(); cpu = Z80(m)
d = open('build/SCROSS.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
w16 = lambda n, v: m.ram.__setitem__(slice(S[n], S[n]+2), (v & 0xffff).to_bytes(2, 'little'))
ents = {S['dobj']: 'dobj', S['dser']: 'dser', S['ggrid']: 'grid', S['horizon']: 'horizon', S['panel']: 'panel', S['dlcull']: 'cull'}
fr = 0; stack = []; rows = []
while fr < 4:
    if cpu.pc == S['flip']:
        fr += 1
        if fr == 1:
            for n, v in zip(('px','pz','alt','hdg','pitch','roll'), (st[0], st[1], st[2], st[3]<<8, st[4]<<8, st[5]<<8)): w16(n, v)
            m.ram[S['crashed']] = 1; m.ram[S['crtimer']] = 0; m.ram[S['ongnd']] = 1 if st[2] == 0 else 0
        if fr == 3: t0 = cpu.t
    if fr == 3 and cpu.pc in ents and not stack:
        stack.append((ents[cpu.pc], cpu.t, cpu.sp, cpu.h << 8 | cpu.l))
    cpu.step()
    if stack and cpu.sp > stack[-1][2]:
        n, t, _, hl = stack.pop(); rows.append((n, labs.get(hl, ''), cpu.t - t))
tot = cpu.t - t0
agg = {}
for n, l, t in rows: agg[n] = agg.get(n, 0) + t
print('frame %d T (%.2f fps)' % (tot, 3375000 / tot), {k: v for k, v in agg.items()})
for n, l, t in sorted(rows, key=lambda r: -r[2]):
    if n in ('dobj', 'dser'): print('  %-5s %-4s %6d' % (n, l, t))
