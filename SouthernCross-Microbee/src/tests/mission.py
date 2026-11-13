# Fly a mission through the real menus: python3 tests/mission.py N OUTDIR [maxframes]
# Presses the mission number at the menu and SPACE at the briefing, flies with a
# gate-chasing autopilot (gates only), presses SPACE at the debrief.  Each text
# screen is printed and saved as screenN.png.  DIVE=frame flies into the sea
# at that frame once, to test the restart at the last gate.
import sys, os, math
sys.path.insert(0, os.getcwd()); sys.path.insert(0, 'tools')
import run as R
from z80emu import Bee, Z80
S = R.syms
K = {'Q':17,'A':1,'O':15,'P':16,'T':20,'G':7,' ':55,'ESC':48}
mis = int(sys.argv[1]); out = sys.argv[2]; os.makedirs(out, exist_ok=True)
maxfr = int(sys.argv[3]) if len(sys.argv) > 3 else 3000
m = Bee(); cpu = Z80(m)
d = open('build/SCROSS.COM','rb').read(); m.ram[0x100:0x100+len(d)] = d
def r8(n, o=0): return m.ram[S[n]+o]
def s8(v): return v - 256 if v > 127 else v
def r16a(a): v = m.ram[a] | m.ram[a+1] << 8; return v - 65536 if v > 32767 else v
def r16(n): return r16a(S[n])
def msg(): return bytes(m.ram[S['msgbuf']:S['msgbuf']+62]).decode('latin1').rstrip()
def text(): return '\n'.join(''.join(chr(m.screen[r*64+c]) if 32 <= m.screen[r*64+c] < 127 else '#' for c in range(64)).rstrip() for r in range(16))
prompts = [str(mis), ' ', ' ']
GKRET = S['gk1'] + 7
pi = 0; seen = -1; fr = 0; last = ''; shots = 0; tele = -1
def w16(n, v): m.ram[S[n]:S[n]+2] = (v & 0xffff).to_bytes(2, 'little')
def teleport(ri):
    # onto final for runway ri, as F would (the test pilot can't navigate the sea)
    e = r16('rwyp') + 20 * ri
    x0, z0, ax, aim = r16a(e), r16a(e+2), m.ram[e+4], r16a(e+8)
    if ax == 0: w16('px', x0); w16('pz', z0 + aim - 1500); w16('hdg', 0)
    else: w16('px', x0 + aim - 1500); w16('pz', z0); w16('hdg', 64 << 8)
    w16('alt', 80); w16('vel', 35 << 8); w16('pitch', -3 << 8); w16('roll', 0)
    m.ram[S['thr']] = 22; m.ram[S['ongnd']] = 0; m.ram[S['altf']] = 0
while fr < maxfr:
    pc = cpu.pc
    if pc == S['getkey'] and seen != pi:
        m.keys = set()                  # let go of the flying keys at a prompt
    if pc == S['gk1']:
        if seen != pi:
            seen = pi
            R.render(m).save(os.path.join(out, 'screen%d.png' % pi))
            print('---- screen %d' % pi); print(text())
            if pi >= len(prompts): break
        k = prompts[pi]
        m.keys = {K[k]} if k in K else {32 + int(k)}
    elif pc == GKRET:
        pi += 1; m.keys = set()
    elif pc == S['flip']:
        fr += 1
        if r8('mact') and not r8('mdone'):
            g = r16('gptr'); typ = m.ram[g]
            gx, gz, lo, hi = r16a(g+2), r16a(g+4), r16a(g+6), r16a(g+8)
            px, pz, alt = r16('px'), r16('pz'), r16('alt'); hdg = r8('hdg', 1)
            roll = s8(r8('roll', 1)); pit = s8(r8('pitch', 1))
            keys = set()
            dive = int(os.environ.get('DIVE', '0'))
            if dive and dive <= fr < dive + 400 and not r8('crashed') and r16('mpen') == 0:
                m.keys = {K['Q']}               # test: fly into the sea
                keys = None
            elif typ == 1:
                want = math.atan2(gx - px, gz - pz) * 128 / math.pi
                e = (want - hdg + 128) % 256 - 128
                rt = max(-18, min(18, e * 1.5))
                if roll < rt - 1: keys.add('P')
                elif roll > rt + 1: keys.add('O')
                tp = max(-4, min(5, ((lo + hi) / 2 - alt) / 10)) + abs(roll) / 8
                if pit < tp - 0.5: keys.add('A')
                if pit > tp + 0.5: keys.add('Q')
                v = r8('vel', 1)
                if v < 33 and r8('thr') < 100: keys.add('T')
                if v > 38 and r8('thr') > 20: keys.add('G')
            elif typ == 2:
                if tele != r8('mgi'):
                    tele = r8('mgi'); teleport(m.ram[g+1]); print('  (test: teleported onto final for runway', m.ram[g+1], ')')
                if not r8('ongnd'):
                    rng = r16('srng') if r8('selok') else 1500
                    want = rng * 0.0524
                    tp = -3 + max(-3, min(3, (want - alt) / 4)) if alt > 3 else -1
                    if pit < tp - 0.5: keys.add('A')
                    if pit > tp + 0.5: keys.add('Q')
                    if alt < 4 and r8('thr') > 0: keys.add('G')
                    sac = r16('sac') if r8('selok') else 0
                    if sac > 1: keys.add('O')
                    elif sac < -1: keys.add('P')
                else:
                    if r8('thr') < 100: keys.add('T')
            if keys is not None: m.keys = set(K[k] for k in keys)
        cur = msg()
        if cur != last and r8('mact'):
            print('frame %4d t %3ds pen %2d px %5d pz %5d alt %4d | %s' % (fr, r16('mts'), r16('mpen'), r16('px'), r16('pz'), r16('alt'), cur)); last = cur
        if r8('mact') and fr % 200 == 0 and shots < 3:
            while cpu.pc != S['timing']: cpu.step()
            R.render(m).save(os.path.join(out, 'fly%d.png' % fr)); shots += 1
            continue
    cpu.step()
print('end frame', fr, 'logbook file:', os.path.exists('build/CORAL.LOG'))
