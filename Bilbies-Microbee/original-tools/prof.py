import sys, os, re, bisect
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu
def prof(lvl, start, n):
    out = emu.run('''vz ../build/BILBIES.VZ
untilpc {front_main} 100
poke {v_lvl} %02X
setpc {test_run}
frames %d
peek {v_loop} 1
prof 1
frames %d
peek {v_loop} 1
profsave prof.txt
''' % (lvl, start, n))
    loops = [int(x, 16) for x in re.findall(r'peek \w+: (\w\w)', out)]
    print('loops in %d frames: %d' % (n, (loops[1] - loops[0]) & 255))
    S = sorted((v, k) for k, v in emu.syms().items() if '.' not in k)
    keys = [s[0] for s in S]
    agg = {}; tot = 0
    for l in open(emu.W + '/run/prof.txt'):
        a, c = l.split(); a = int(a, 16); c = int(c); tot += c
        i = bisect.bisect_right(keys, a) - 1
        agg[S[i][1]] = agg.get(S[i][1], 0) + c
    for k, c in sorted(agg.items(), key=lambda x: -x[1])[:18]:
        print('%-20s %5.1f%%' % (k, 100 * c / tot))
if __name__ == '__main__':
    prof(int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]))
