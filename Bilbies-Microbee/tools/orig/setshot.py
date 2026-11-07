"""Gameplay shots aimed at a spot: python3 tools/setshot.py level x y name
Plays the level by its script, finds when the most bilbies are inside the
128 x 44 window at (x, y), then holds the view there and grabs the screen."""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu
def shot(i, x, y, name, mx=6000, every=20):
    S = emu.syms()
    body = 'vz ../build/BILBIES.VZ\nuntilpc {front_main} 100\npoke {v_lvl} %02X\nsetpc {test_run}\nrununtil {play_level} 900\n' % i
    for f in range(0, mx, every):
        body += 'frames %d\npeek {CRT} 640\n' % every
    out = emu.run(body, 'ss%d' % i)
    pk = [[int(v, 16) for v in m.group(2).split()] for m in re.finditer(r'peek (\w+):((?: \w\w)+)', out)]
    best, bf = -1, 0
    for j, c in enumerate(pk):
        n = 0
        for k in range(40):
            r = c[k * 16:(k + 1) * 16]
            if r[0] in (0, 14, 16, 17): continue
            cx, cy = r[1] | r[2] << 8, r[3]
            if x + 4 <= cx < x + 124 and y + 4 <= cy < y + 44: n += 1
        if n > best: best, bf = n, j
    f = (bf + 1) * every
    sb, sy = x // 4, y
    body = 'vz ../build/BILBIES.VZ\nuntilpc {front_main} 100\npoke {v_lvl} %02X\nsetpc {test_run}\nrununtil {play_level} 900\n' % i
    body += 'frames %d\npoke {v_demo} 00\npoke {v_scrb} %02X\npoke {v_scry} %02X\nframes 6\nscreen %s.ppm\n' % (f - 6, sb, sy, name)
    emu.run(body, 'ss%d' % i)
    print(name, 'bilbies in view', best, 'frame', f)
if __name__ == '__main__':
    a = sys.argv[1:]
    shot(int(a[0]), int(a[1]), int(a[2]), a[3])
