"""Visit every stage by script: python3 tools/alltest.py outdir [first stage]"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tour, bosstest

def stage_run(st, out):
    b = tour.Bot(stage=st)
    b.go((), 20)
    b.shot('%s/s%02d_a.png' % (out, st))
    w = b.v('levw', 2)
    if w <= 20:                         # a boss: keep Bix alive, drop him on its head (or burst up for the golem)
        P = b.S['POOL']
        hits = 0
        for t in range(6000):
            b.poke('health', 3); b.poke('invuln', 50)
            b.go((), 2)
            if t == 100: b.shot('%s/s%02d_b.png' % (out, st))
            B = bosstest.boss(b)
            if B is None or B[2] == 9: break
            bx, by, bs, hp = B
            bid = b.v('lv_bossid')
            slot = [i for i in range(10) if b.g[P + i * 16] == 13][0]
            if b.g[P + slot * 16 + 15]: continue
            flying = bid in (3, 4) or (bid == 5 and hp < 5)
            if flying and bs != 2: continue
            if not flying and bid != 2 and bs != 0: continue
            b.poke('ppx', bx + 8, 2); b.poke('px16', (bx + 8) * 16, 2); b.poke('pstate', 0)
            if bid == 2:                # the golem: only a burst from below hurts him
                b.poke('ppy', by + 10); b.poke('py16', (by + 10) * 16, 2); b.poke('burstt', 10); b.poke('vy', 256 - 60)
            else:
                b.poke('ppy', (by - 14) & 255); b.poke('py16', (by - 14) * 16, 2); b.poke('vy', 30)
            b.go((), 8); hits += 1
            if hits == 2: b.shot('%s/s%02d_d.png' % (out, st))
        for i in range(30):
            b.poke('health', 3); b.go((), 10)
        print('stage %d boss %d: after: boss %s, levdone %d, score %02x%02x%02x, %d frames in %d fields, %d slow' % (
            st, b.v('lv_bossid'), bosstest.boss(b), b.v('levdone'), b.v('score'), b.v('score') if 0 else b.g[b.S['score'] + 1], b.g[b.S['score'] + 2], b.loops, b.fields, b.slow))
        b.shot('%s/s%02d_c.png' % (out, st))
        return
    k = 0
    xs = [3, 40, 90, 150, 200, w - 30]
    if b.g[b.S['LVHDR'] + 7] if 'LVHDR' in b.S else (st % 3 == 1):
        xs = [w - 4, w - 40, w - 90, 100, 50, 30]
    for tx in xs:
        b.warp(tx)
        b.go((), 50)
        d = ('LEFT',) if st % 3 == 1 else ('RIGHT',)
        b.go(d, 50)
        b.go(d + ('SPACE',), 20)
        b.go((), 10)
        b.shot('%s/s%02d_%d.png' % (out, st, k)); k += 1
    print('stage %d world %d: %s; %d frames in %d fields: %.1f fps, %d slow' % (
        st, b.v('lv_world'), b.state(), b.loops, b.fields, 50.0 * b.loops / b.fields, b.slow))

if __name__ == '__main__':
    out = sys.argv[1]
    for st in ([int(a) for a in sys.argv[2:]] or range(15)):
        stage_run(st, out)
