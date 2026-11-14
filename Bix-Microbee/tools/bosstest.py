"""Fight King Cane by script: python3 tools/bosstest.py outdir"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import tour, run
from mbee import FRAME_T

def to_boss(mono=False, world=1):
    b = tour.Bot(mono, stage=world * 3 - 1)
    b.loops = b.fields = b.slow = 0
    return b

def boss(b):
    """the boss's entity -> (x, y, state, hp) or None"""
    g = b.g; P = b.S['POOL']
    for i in range(10):
        if g[P + i * 16] == 13:
            return int(g[P + i * 16 + 2]) | int(g[P + i * 16 + 3]) << 8, int(g[P + i * 16 + 4]), int(g[P + i * 16 + 1]), int(g[P + i * 16 + 14])
    return None

if __name__ == '__main__':
    out = sys.argv[1]
    b = to_boss()
    b.go((), 60); b.shot(out + '/boss1.png')
    hits = 0
    for k in range(400):
        B = boss(b)
        if B is None or b.v('stage') != 2 or b.v('gameover'):
            break
        bx, by, bs, hp = B
        px, py = b.v('ppx', 2), b.v('ppy')
        # stay off the ground when he lands; drop on his head while he sits
        keys = []
        if bs == 1:
            keys.append('SPACE')                 # in the air while he is
        else:
            if px < bx + 8: keys.append('RIGHT')
            else: keys.append('LEFT')
            if abs(px - (bx + 8)) < 30 and b.v('onground'):
                keys.append('SPACE')
        b.go(keys, 4)
        if k == 40: b.shot(out + '/boss2.png')
    print('boss', boss(b), b.state(), 'stage', b.v('stage'), 'levdone', b.v('levdone'))
    print('%d frames in %d fields: %.1f fps, %d slow' % (b.loops, b.fields, 50.0 * b.loops / max(1, b.fields), b.slow))
    b.go((), 400); b.shot(out + '/boss3.png')
