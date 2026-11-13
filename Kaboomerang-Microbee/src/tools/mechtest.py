"""Mechanics: a bomb beats a toad; the Kaboomerang carries a lit bomb away."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
out = BUILD / 'shots'
out.mkdir(exist_ok=True)


def start():
    pp = boot(test=True)
    pp.run_frames(140)          # past GET READY
    S = pp.S
    for i in range(8):
        pp.poke(S['actors'] + i * 16, 0)
    pp.poke(S['nenemy'], 1)
    return pp, S


def hold(pp, keys, fields):
    pp.keys = keys
    pp.run_frames(fields)
    pp.keys = []


# A: toad below the bomb's column
pp, S = start()
a = S['actors']
for o, v in ((0, 1), (1, 8), (2, 24), (5, 255)):
    pp.poke(a + o, v)
hold(pp, ['SPACE'], 4)
hold(pp, ['RIGHT'], 34)
hold(pp, ['DOWN'], 18)
print('A: bomb placed fuse', peek(pp, 'bombs', 4)[3], 'Wally at', peek(pp, 'p_hx'), peek(pp, 'p_hy'))
pp.run_frames(150)
pp.png(out / 'mech_a.png', aspect=1.1)
print('A: toad type', pp.peek(a), 'enemies', peek(pp, 'nenemy'), 'allclear', peek(pp, 'allclear'),
      'hearts', peek(pp, 'p_hearts'), 'score', ''.join('%02X' % b for b in peek(pp, 'score', 3)))
assert pp.peek(a) == 0 and peek(pp, 'allclear') == 1 and peek(pp, 'p_hearts') == 3

# B: drop a bomb, face right, throw: the boomerang carries the bomb off
pp, S = start()
hold(pp, ['SPACE'], 4)
hold(pp, ['RIGHT'], 2)          # face right (a tap)
before = peek(pp, 'bombs', 3)
hold(pp, ['X'], 4)
pp.run_frames(6)
print('B: carrying', peek(pp, 'bm_carry'), 'boomerang at', peek(pp, 'bm_hx'), peek(pp, 'bm_hy'))
pp.png(out / 'mech_b1.png', aspect=1.1)
pp.run_frames(40)
after = peek(pp, 'bombs', 6)
print('B: bomb before', before[1:3], 'after', after[1:3], 'carried', after[5], 'boomerang on', peek(pp, 'bm_on'))
pp.png(out / 'mech_b2.png', aspect=1.1)
assert after[1] != before[1] and after[5] == 0
print('ok')
