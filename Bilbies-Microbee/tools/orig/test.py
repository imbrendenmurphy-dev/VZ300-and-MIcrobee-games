"""Play levels with their solution scripts in the emulator: python3 tools/test.py [level...]"""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu, levels
def test(i, shots=()):
    S = emu.syms()
    body = 'vz ../build/BILBIES.VZ\nuntilpc {front_main} 100\npoke {v_lvl} %02X\nsetpc {test_run}\n' % i
    t = 0
    for f in sorted(shots):
        body += 'frames %d\nscreen L%d_%d.ppm\n' % (f - t, i, f); t = f
    body += 'frames %d\n' % max(1, 30000 - t)
    body += 'peek {v_res} 1\npeek {v_saved} 1\npeek {v_lost} 1\npeek {v_released} 1\npeek {v_gtick} 2\npeek {v_tleft} 2\n'
    out = emu.run(body, 'test%d' % i)
    pk = {m.group(1): [int(x, 16) for x in m.group(2).split()] for m in re.finditer(r'peek (\w+):((?: \w\w)+)', out)}
    vals = [pk.get('%04X' % S[n], [0]) for n in ('v_res', 'v_saved', 'v_lost', 'v_released', 'v_gtick', 'v_tleft')]
    res, saved, lost, rel = vals[0][0], vals[1][0], vals[2][0], vals[3][0]
    lv = levels.LEVELS[i]
    ok = res == 0xAA and saved >= lv.save
    print('%2d %-30s saved %2d/%2d (need %2d) lost %2d  ticks %d  %s' % (i, lv.name, saved, lv.n, lv.save, lost,
          vals[4][0] | vals[4][1] << 8, 'OK' if ok else 'FAIL' + ('' if res == 0xAA else ' (not ended)')))
    if shots:
        emu.png(['L%d_%d' % (i, f) for f in sorted(shots)], 'L%d.png' % i)
    return ok
if __name__ == '__main__':
    args = [int(a) for a in sys.argv[1:] if a.isdigit()]
    shots = [int(a[1:]) for a in sys.argv[1:] if a.startswith('s')]
    for i in (args or range(len(levels.LEVELS))):
        test(i, shots)
