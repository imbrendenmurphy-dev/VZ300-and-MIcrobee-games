"""Compare the Z80 level builder with lvlkit.raster: python3 tools/verify.py [level...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import emu, levels, lvlkit
def verify(i):
    lv = (levels.LEVELS + [levels.TITLE])[i]
    body = 'vz ../build/BILBIES.VZ\nuntilpc {front_main} 100\npoke {v_lvl} %02X\nsetpc {test_run}\nrununtil {play_level} 600\ndump v%d.bin\n' % (i, i)
    out = emu.run(body, 'ver%d' % i)
    hit = 'hit=1' in out
    mem = open(emu.W + '/run/v%d.bin' % i, 'rb').read()
    g, m = lvlkit.raster(lv)
    S = emu.syms()
    bad = 0; first = None
    for y in range(lv.height):
        for x in range(lv.width):
            b = mem[0x4000 + y * 128 + x // 4]
            c = (b >> (6 - 2 * (x & 3))) & 3
            mk = (mem[S['MASK'] + y * 64 + x // 8] >> (7 - (x & 7))) & 1
            if c != g[y][x] or mk != m[y][x]:
                bad += 1
                if first is None: first = (x, y, c, g[y][x], mk, m[y][x])
    print('%2d %-24s reached=%s mismatches %d first %s' % (i, lv.name, hit, bad, first))
if __name__ == '__main__':
    for a in sys.argv[1:]: verify(int(a))
