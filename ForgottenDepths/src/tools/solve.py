"""Static completability check for each chapter (no dead ends)."""
import importlib
from collections import deque
from levelc import compile_level, W, H
from tiles import DEFS, TILES

def special(t):
    return DEFS[t]['special']

def check(n, inv0):
    mod = importlib.import_module(f'level{n}')
    lv = compile_level(mod)
    T = lv['tiles']
    items = {(x, y): k for k, x, y in lv['ents'] if k in ('staff', 'key', 'boots', 'sunstone', 'ring', 'blade', 'gem', 'potion', 'heart', 'mana')}
    start = next((x, y) for k, x, y in lv['ents'] if k == 'player')
    boss = next((x, y) for k, x, y in lv['ents'] if k == 'boss')
    inv = set(inv0)
    keys = 0
    opened = set()
    boss_dead = False
    log = []
    for it in range(60):
        # flood fill with current abilities
        seen = {start}
        q = deque([start])
        doors = set()
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H) or (nx, ny) in seen:
                    continue
                t = T[ny][nx]
                d = DEFS[t]
                sp = special(t)
                ok = not d['solid']
                if sp == 5: ok = True                      # hidden wall: breakable
                if sp == 7 and 'boots' in inv: ok = True
                if sp == 6 and 'ring' in inv: ok = True
                if sp == 8 and boss_dead: ok = True
                if sp == 4:
                    if (nx, ny) in opened: ok = True
                    else: doors.add((nx, ny)); ok = False
                if ok:
                    seen.add((nx, ny)); q.append((nx, ny))
        progress = False
        for p, k in list(items.items()):
            if p in seen:
                del items[p]
                if k == 'key': keys += 1
                elif k in ('staff', 'boots', 'sunstone', 'ring', 'blade'):
                    if k not in inv: log.append(k)
                    inv.add(k)
                progress = True
        bx, by = boss
        if not boss_dead and any((bx + dx, by + dy) in seen for dx in range(-1, 4) for dy in range(-1, 4)):
            boss_dead = True; log.append('boss'); progress = True
        if keys and doors:
            d = sorted(doors)[0]; opened.add(d); keys -= 1; log.append(f'door{d}'); progress = True
        goal = [(x, y) for y in range(H) for x in range(W) if special(T[y][x]) == 2]
        if any(g in seen for g in goal):
            return True, log, inv
        if not progress:
            return False, log, inv
    return False, log, inv

inv = set()
for n in (1, 2, 3):
    ok, log, inv = check(n, inv)
    print(f'chapter {n}:', 'COMPLETABLE' if ok else 'STUCK', log)
