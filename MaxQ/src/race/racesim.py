"""Automated race: SPACE starts it, the autopilot drives; prints the race state and saves stills."""
import subprocess, sys, build_race as B, vlog2gif as V
B.RACE_AUTOPILOT = 1
secs = int(sys.argv[1]) if len(sys.argv) > 1 else 100
src, _ = B.source(); asm, org, data, vz = B.assemble(src, 'SIM.VZ')
subprocess.run([B.EMU, vz, str(70630 * 50 * secs), '--memdump', 'race.bin', '--vramlog', 'race.log', str(int(sys.argv[2]) if len(sys.argv) > 2 else 10),
                '--key', '420', '440', 'EF', '4'], capture_output=True, text=True)
d_ = open('race.log', 'rb').read()
print('frames with mode(1) off:', sum(1 for i in range(len(d_) // 2049) if not d_[i * 2049 + 2048] & 8))
m = open('race.bin', 'rb').read()
v = lambda n, s=1: m[asm.sym[n]] if s == 1 else m[asm.sym[n]] | m[asm.sym[n] + 1] << 8
for n in ['GSTATE', 'LAPN', 'POS', 'SHIELD', 'FINPOS', 'NEWBEST']: print(n, v(n))
print('RTIME', v('RTIME', 2), 'BESTLAP', v('BESTLAP', 2), 'fps', 50 * v('FRAMES', 2) / max(1, v('FIELDS', 2)))
t = asm.sym['TOPT']; print('TOPT', [m[t + 2 * i] | m[t + 2 * i + 1] << 8 for i in range(4)])
