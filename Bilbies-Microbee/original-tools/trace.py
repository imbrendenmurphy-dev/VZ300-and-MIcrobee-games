"""Where are the bilbies? python3 tools/trace.py level [every_frames] [max_frames] [idx,idx..]
Prints, every so often, the game tick and each live bilby: idx:state@x,y"""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu, art
ST = ['-', 'walk', 'fall', 'float', 'climb', 'hoist', 'block', 'build', 'shrug', 'bash', 'mine', 'dig',
      'splat', 'drown', 'exit', 'ohno', 'gone', 'HOME']
def trace(i, every=50, mx=6000, only=None):
    S = emu.syms()
    body = 'vz ../build/BILBIES.VZ\nuntilpc {front_main} 100\npoke {v_lvl} %02X\nsetpc {test_run}\nrununtil {play_level} 900\n' % i
    for f in range(0, mx, every):
        body += 'frames %d\npeek {v_gtick} 2\npeek {CRT} 640\npeek {v_saved} 1\n' % every
    out = emu.run(body, 'tr%d' % i)
    pk = [[int(x, 16) for x in m.group(2).split()] for m in re.finditer(r'peek (\w+):((?: \w\w)+)', out)]
    for j in range(0, len(pk) - 2, 3):
        t = pk[j][0] | pk[j][1] << 8
        c = pk[j + 1]
        row = []
        for k in range(40):
            r = c[k * 16:(k + 1) * 16]
            if r[0] in (0, 16, 17) or r[0] >= len(ST): continue
            if only and k not in only: continue
            row.append('%d:%s@%d,%d%s%s' % (k, ST[r[0]], r[1] | r[2] << 8, r[3], '<' if r[4] else '>', ('f%x' % r[6]) if r[6] else ''))
        print('t%4d s%d  %s' % (t, pk[j + 2][0], ' '.join(row)))
        if t > 50 and pk[j][0:2] == pk[j - 3][0:2] and not row: break
if __name__ == '__main__':
    a = sys.argv[1:]
    only = set(int(x) for x in a[3].split(',')) if len(a) > 3 else None
    trace(int(a[0]), int(a[1]) if len(a) > 1 else 50, int(a[2]) if len(a) > 2 else 6000, only)
