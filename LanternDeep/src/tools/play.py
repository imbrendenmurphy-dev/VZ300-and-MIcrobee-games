"""Scripted play-test: walk the corridor, enter the hall, fight, cast,
open the chest. Saves screenshots to out/."""
import sys
import run, sym, ppmodel
S = sym.load()
OUT = '/home/claude/lantern/out/'


def w(pp, a):
    return pp.peek(a) | (pp.peek(a + 1) << 8)


def pos(pp):
    pc = w(pp, S['player_cell'])
    return (pc & 0x7F) - 1, ((pc - 0xC000) >> 7) - 1


def hold(pp, keys, frames):
    pp.keys = set(ppmodel.KEY[k] for k in keys)
    pp.run_frames(frames)
    pp.keys = set()


def tap(pp, key, frames=6):
    hold(pp, [key], 3)
    pp.run_frames(frames)


def walk_to(pp, tx, ty, limit=600):
    for _ in range(limit // 4):
        x, y = pos(pp)
        if (x, y) == (tx, ty):
            return True
        if x != tx:
            k = 'RIGHT' if tx > x else 'LEFT'
        else:
            k = 'DOWN' if ty > y else 'UP'
        hold(pp, [k], 4)
    return pos(pp) == (tx, ty)


if __name__ == '__main__':
    pp = run.boot()
    pp.run_frames(100)
    pp.save_png(OUT + 'p0_start.png', 1)
    walk_to(pp, 20, 10)
    pp.save_png(OUT + 'p1_corridor.png', 1)
    walk_to(pp, 33, 10)
    pp.run_frames(10)
    pp.save_png(OUT + 'p2_door.png', 1)
    walk_to(pp, 40, 10)
    pp.run_frames(40)
    pp.save_png(OUT + 'p3_hall.png', 1)
    print('pos', pos(pp), 'hp', pp.peek(S['hp']), 'mp', pp.peek(S['mp']))
    tap(pp, 'F', 2)
    pp.run_frames(6)
    pp.save_png(OUT + 'p4_fire.png', 1)
    pp.run_frames(30)
    pp.save_png(OUT + 'p5_after.png', 1)
    print('pos', pos(pp), 'hp', pp.peek(S['hp']), 'mp', pp.peek(S['mp']), 'gold', w(pp, S['gold']))


def solid(pp, x, y):
    if not (0 <= x < 80 and 0 <= y < 22):
        return True
    f = pp.peek(0xC000 + (y + 1) * 128 + x + 1)
    return bool(f & 0x0A)


def route(pp, tx, ty):
    from collections import deque
    sx, sy = pos(pp)
    prev = {(sx, sy): None}
    q = deque([(sx, sy)])
    while q:
        c = q.popleft()
        if c == (tx, ty):
            break
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + d[0], c[1] + d[1])
            if n not in prev and not solid(pp, *n):
                prev[n] = c
                q.append(n)
    if (tx, ty) not in prev:
        return None
    path = []
    c = (tx, ty)
    while c != (sx, sy):
        path.append(c)
        c = prev[c]
    return path[::-1]


def nearest_open(pp, tx, ty):
    best = None
    for y in range(22):
        for x in range(80):
            if not solid(pp, x, y):
                d = abs(x - tx) * 0.55 + abs(y - ty)
                if best is None or d < best[0]:
                    best = (d, x, y)
    return best[1], best[2]


def go(pp, tx, ty, fight=True, limit=400):
    if solid(pp, tx, ty):
        tx, ty = nearest_open(pp, tx, ty)
    for _ in range(limit):
        x, y = pos(pp)
        if (x, y) == (tx, ty):
            return True
        p = route(pp, tx, ty)
        if not p:
            pp.run_frames(4)
            continue
        nx, ny = p[0]
        k = 'RIGHT' if nx > x else 'LEFT' if nx < x else 'DOWN' if ny > y else 'UP'
        hold(pp, [k], 3)
        if pos(pp) == (x, y) and fight:
            tap(pp, 'SPACE', 3)          # something in the way: strike it
    return pos(pp) == (tx, ty)


def face(pp, k):
    hold(pp, [k], 10)
    pp.run_frames(10)
