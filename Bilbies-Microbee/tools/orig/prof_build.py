"""Profile building a level: python3 tools/prof_build.py n"""
import sys, bisect
sys.path.insert(0, 'tools'); import emu
n = int(sys.argv[1]) if len(sys.argv) > 1 else 0
out = emu.run('vz ../build/BILBIES.VZ\nuntilpc {front_main} 100\npoke {v_lvl} %02X\nsetpc {test_run}\nrununtil {level_load} 50\nprof 1\nrununtil {play_level} 900\nprofsave prof.txt\n' % n, 'pb')
print(out.strip().splitlines()[-1])
S = emu.syms(); inv = sorted((v, k) for k, v in S.items() if v >= 0x8000 and v < 0xDE00)
keys = [v for v, k in inv]; tot = {}
for l in open(emu.W + '/run/prof.txt'):
    a, c = l.split(); a = int(a, 16); c = int(c)
    i = bisect.bisect_right(keys, a) - 1
    k = inv[i][1] if i >= 0 else '?'; tot[k] = tot.get(k, 0) + c
s = sum(tot.values()); print('total cycles', s)
for k, v in sorted(tot.items(), key=lambda x: -x[1])[:14]: print('%-24s %6.1f%%' % (k, 100 * v / s))
