# Checks the packed DROPBEAR.MZT: once its unpacker has run, memory from 1200h up must match
# DROPBEAR_FULL.MZT exactly. Run from src after build_game.py.
from mzemu import MZ
p = open('DROPBEAR.MZT', 'rb').read()
f = open('DROPBEAR_FULL.MZT', 'rb').read()
w = lambda d, o: int.from_bytes(d[o:o+2], 'little')
lo, exe, full = w(f, 20), w(f, 22), f[128:]
m = MZ(w(p, 20), p[128:], w(p, 22))
for junk in range(0x1200, w(p, 20)):           # real RAM isn't blank at power-on: fill below the load with junk
    m.mem[junk] = (junk * 37 + 11) & 255
ok = m.run_until(exe, 20_000_000)
t = m.cpu.t
same = bytes(m.mem[lo:lo+len(full)]) == full
print('packed %d bytes (plain %d), loads at %04X, unpacker at %04X' % (len(p)-128, len(full), w(p, 20), w(p, 22)))
print('reached the program start: %s, after %.2f s' % (ok, t/3546895))
print('memory matches the plain build: %s' % same)
if not (ok and same): raise SystemExit('FAIL')
print('all passed')
