"""Play a crypt's contraptions and explore it in the model, then print the
map as it ends up (for designing crypts).   python3 tools/peekcave.py 13"""
import sys
sys.path.insert(0, __import__('os').path.dirname(__file__))
from bot import Game, poke, Dead
import tiles as TL
import crypts


def show(g):
    G = g.grid()
    x0, y0 = g.pos()
    for y, r in enumerate(G):
        print(''.join('@' if (x, y) == (x0, y0) else (TL.TILES[t][1] or '?') for x, t in enumerate(r)))


if __name__ == '__main__':
    i = int(sys.argv[1]) - 1
    c = crypts.build_all()[i]
    g = Game(i, 'build/TUNE.DS8')
    poke(g.pp, 'quota', 255)
    try:
        g.run(c.solve_script().replace(' X', ''), explore=True)
    except (Dead, RuntimeError) as e:
        print('!!', e)
    print(c.name, 'gems', g.v('gems'), 'skipped', g.skipped, 'time used', 999)
    show(g)
