"""A simple autopilot in Python for tests: keeps the pilot on the height of
the nearest enemy ahead and fires. Usage: autoplay.py [pilot] [fields]"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game, BUILD

def enemies(pp):
    S = pp.S; out = []
    for i in range(18):
        a = S['enemies'] + i * 20
        if pp.peek(a):
            x = pp.peek(a + 2) | pp.peek(a + 3) << 8
            if x >= 32768: x -= 65536
            out.append((pp.peek(a), x, pp.peek(a + 5)))
    return out

def score(pp):
    a = pp.S['score']
    return ''.join('%02X' % pp.peek(a + i) for i in range(4))

def step(pp, n=4, extra=()):
    px = peekw(pp, 'px'); py = peek(pp, 'py')
    en = [e for e in enemies(pp) if e[1] > px - 8]
    k = ['SPACE'] + list(extra)
    if peek(pp, 'boss_on') and peek(pp, 'boss_st') == 5:
        en = [(0, 0, peek(pp, 'boss_y') + 46)]
    if en:
        tx, ty = min((e[1], e[2]) for e in en)
        if ty + 4 < py - 3: k.append('UP')
        elif ty + 4 > py + 3: k.append('DOWN')
    if px < 60: k.append('RIGHT')
    elif px > 110: k.append('LEFT')
    pp.keys = k
    pp.run_frames(n)

if __name__ == '__main__':
    pilot = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    fields = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
    pp = boot(); to_game(pp, pilot=pilot)
    for t in range(fields // 4):
        step(pp, 4, ['X'] if t % 50 == 0 else ())
        if t % 125 == 0:
            print('t', t * 4, 'scroll', peekw(pp, 'scrollx'), 'score', score(pp), 'hearts', peek(pp, 'hearts'), 'lives', peek(pp, 'lives'), 'gstate', peek(pp, 'gstate'), 'en', len(enemies(pp)))
    pp.png(BUILD / 'shots' / 'auto.png', scale=2, aspect=1.2)
