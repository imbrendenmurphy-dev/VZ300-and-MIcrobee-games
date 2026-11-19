"""Showcase captures: the title (colour and amber) and gameplay on several
waves, played by a simple autopilot that shoots the nearest robot."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD

OUT = BUILD / 'capture'
OUT.mkdir(exist_ok=True)
A = 0.96
ASZ, NACT = 12, 44


def actors(pp):
    base = pp.S['actors']
    for i in range(NACT):
        t = pp.peek(base + i * ASZ)
        if 1 <= t <= 6:
            yield t, pp.peek(base + i * ASZ + 1), pp.peek(base + i * ASZ + 2)


def sgn(v):
    return (v > 0) - (v < 0)


def autopilot(pp, fields, keep_safe=True):
    for f in range(0, fields, 2):
        px, py = peek(pp, 'px'), peek(pp, 'py')
        best = None
        for t, x, y in actors(pp):
            if t == 6:
                continue
            d = max(abs(x - px), abs(y - py))
            if best is None or d < best[0]:
                best = (d, x, y)
        keys = []
        if best:
            d, x, y = best
            dx, dy = sgn(x - px), sgn(y - py)
            if abs(x - px) > 3 * abs(y - py):
                dy = 0
            if abs(y - py) > 3 * abs(x - px):
                dx = 0
            keys += [{1: 'L', -1: 'J'}[dx]] if dx else []
            keys += [{1: 'K', -1: 'I'}[dy]] if dy else []
            mx, my = (-dx, -dy) if d < 14 else (0, 0)
            if (f // 40) % 2:
                mx, my = (dy, -dx) if d >= 14 else (mx, my)   # strafe
            keys += [{1: 'D', -1: 'A'}[mx]] if mx else []
            keys += [{1: 'S', -1: 'W'}[my]] if my else []
        pp.keys = keys
        if keep_safe:
            pp.poke(pp.S['pcells'], 3)
            pp.poke(pp.S['lives'], 3)
        pp.run_frames(2)
    pp.keys = []


def goto_wave(pp, w):
    S = pp.S
    pp.run_until(S['game_loop'], 10)
    pp.poke(S['wave'], w - 1)
    pp.poke(S['state'], 2)
    pp.poke(S['stimer'], 1)
    pp.run_frames(140)


# ---- the title, colour and amber
pp = boot()
pp.run_frames(300)
pp.png(OUT / 'title.png', aspect=A)
pp = boot(mono=True)
pp.run_frames(300)
pp.png(OUT / 'title_amber.png', aspect=A, mono=True)
while peek(pp, 'att') != 2:
    pp.run_frames(4)
pp.run_frames(620)
pp.png(OUT / 'gallery_amber.png', aspect=A, mono=True)

# ---- gameplay
pp = boot(test=True)
pp.run_frames(150)
autopilot(pp, 60)
pp.png(OUT / 'play_wave1.png', aspect=A)
for w, fields, name in ((3, 70, 'play_wave3_zappers'), (6, 60, 'play_wave6_whirlers'),
                        (10, 50, 'play_wave10_meltdown'), (12, 60, 'play_wave12_crusher_colony'),
                        (13, 50, 'play_wave13_node_maze'), (15, 40, 'play_wave15_stampede'),
                        (16, 50, 'play_wave16_final_riot')):
    goto_wave(pp, w)
    autopilot(pp, fields)
    pp.png(OUT / (name + '.png'), aspect=A)
    if w == 12:
        pp.png(OUT / 'play_wave12_amber.png', aspect=A, mono=True)
print('captured:', sorted(p.name for p in OUT.iterdir()))
