"""Record the attract-mode demo: play a crypt's solution in the model and
write the keys of every cave step to build/DEMO.DAT (crypt number, then
pairs of pad value and number of steps, ended by a zero count).  The game
replays it exactly, because a crypt always plays the same for the same keys."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import caves as C
from bot import Game, rle
from solve import solution
from emu import BUILD

DEMO_CAVE = 1


def build(cave=DEMO_CAVE):
    allc = C.load_all()
    path, c = allc[cave - 1]
    g = Game(cave - 1)
    g.run(solution(path))
    assert g.done(), 'the demo crypt was not cleared'
    log = g.log
    while len(rle(log)) > 500 or len(log) > 900:        # a big crypt: the demo shows the first part
        log = log[:-10]
    data = bytes([cave - 1]) + rle(log) + bytes([0, 0])
    assert len(data) <= 510, len(data)
    (BUILD / 'DEMO.DAT').write_bytes(data)
    print('demo: crypt %d (%s), %d steps, %d bytes' % (cave, c['name'], len(log), len(data)))


if __name__ == '__main__':
    build()
