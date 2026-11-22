# Runs the DROPBEAR MZ attract sequence in the simulator: title + music (rendered to WAV),
# the gallery (a screenshot per creature), and the autopilot demo. Run from src after build_game.py.
from mzemu import MZ, FIELD
d = open('DROPBEAR.MZT', 'rb').read()
sym = {l.split()[0]: int(l.split()[1], 16) for l in open('game.sym')}
m = MZ(int.from_bytes(d[20:22], 'little'), d[128:], int.from_bytes(d[22:24], 'little'))   # load, exec from the header
fails = []
def check(what, ok):
    print(('ok   ' if ok else 'FAIL ') + what)
    if not ok: fails.append(what)

check('title music starts', m.run_until(sym['tm1'], 50_000_000))
t0 = m.cpu.t
m.run_t(FIELD*50); m.shot('a_title.png', 2)
check('music reaches the gallery', m.run_until(sym['gallery'], FIELD*60*50))
secs = (m.cpu.t - t0)/3546895
print('  title + music + pause: %.1f s' % secs)
m.wav('title_music.wav', t0, m.cpu.t - FIELD*150)
for i in range(10):
    check('gallery card %d' % (i+1), m.run_until(sym['gw1'], FIELD*20*50))
    m.run_t(FIELD*8); m.shot('a_gallery%d.png' % i, 2)
    m.run_until(sym['ga0'], FIELD*20*50)
check('demo starts', m.run_until(sym['demo'], FIELD*30*50))
m.run_until(sym['gloop'] if 'gloop' in sym else sym['frame'], 1)
px0 = m.mem[sym['px']] | m.mem[sym['px']+1] << 8; py0 = m.mem[sym['py']] | m.mem[sym['py']+1] << 8
a0 = m.mem[sym['area']]; ammo0 = m.mem[sym['ammo']]; moved = False; shots = False
for k in range(12):
    for f in range(50):
        m.run_t(FIELD)
        shots |= m.mem[sym['gunflash']] > 0
    px = m.mem[sym['px']] | m.mem[sym['px']+1] << 8; py = m.mem[sym['py']] | m.mem[sym['py']+1] << 8
    moved |= abs(px-px0) > 256 or abs(py-py0) > 256
    if k in (2, 6, 10): m.shot('a_demo%d.png' % k, 2)
check('demo is in area 0 first', a0 == 0)
check('the autopilot gets about', moved)
print('  autopilot fired' if shots else '  autopilot did not fire in 12 s')
m.held = {'SPACE'}
check('SPACE leaves the demo for the intro page', m.run_until(sym['ws1'], FIELD*5*50))
m.held = set(); m.run_until(sym['ws2'], FIELD*50); m.shot('a_intro.png', 2)
print('FAILED: %d' % len(fails) if fails else 'all passed')
