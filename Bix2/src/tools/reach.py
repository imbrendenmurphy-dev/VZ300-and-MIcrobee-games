# Rough reachability check for a level: can Bix get from the start to the
# exit burrow with ordinary jumps, springs, updrafts, platforms and digging?
# Conservative on jump reach (Bix can do a little better in the game).
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import art
ATTR = {n: a for n, _, a in art.TILES}
SOLID, ONEWAY, DIG, HAZ, SPRING = art.SOLID, art.ONEWAY, art.DIG, art.HAZ, art.SPRING
E_PLATH, E_PLATV = 5, 6

def check(L, world, name='', verbose=False):
    W, H = L.W, 12
    g = L.g
    def a(x, y):
        if x < 0 or x >= W: return SOLID
        if y < 0: return 0
        if y >= H: return 0
        return ATTR[g[x][y]]
    def solid(x, y): return a(x, y) & SOLID
    def floor(x, y):  # can stand on tile (x,y)
        t = a(x, y)
        return bool(t & (SOLID | ONEWAY)) and not (t & HAZ and not t & SOLID)
    def clear(x, y): return not solid(x, y) and not (a(x, y) & HAZ)
    plat = set()
    for (x, y, t, p) in L.ents:
        if t == E_PLATH:
            for xx in range(x, x + p + 3): plat.add((xx, y - 1))
        if t == E_PLATV:
            for k in range(0, p + 1):
                for xx in range(x, x + 3): plat.add((xx, y - 1 - k))
    def stand(x, y):  # Bix's feet cell (x, y): stands on (x, y+1)
        if not (0 <= x < W and 0 <= y < H - 1): return False
        if not clear(x, y) or solid(x, y - 1): return False
        return floor(x, y + 1) or (x, y) in plat
    wind = set((x, y) for x in range(W) for y in range(H) if g[x][y] == 'fern') if world in (4, 5) else set()
    start = tuple(L.start()[:2])
    sx, sy = start[0], start[1] + 1  # spawn y is the top of Bix: feet are a row lower
    if not stand(sx, sy):
        for yy in range(H - 1):
            if stand(sx, yy): sy = yy; break
    exits = [x for x in range(W) for y in range(H) if g[x][y] == 'exitB']
    seen = set(); todo = [(sx, sy)]; seen.add((sx, sy))
    def land(x, y):
        """fall from (x, y) to the first standable cell, or None"""
        while y < H - 1:
            if stand(x, y): return (x, y)
            if solid(x, y + 1) and not stand(x, y): return None
            y += 1
        return None
    while todo:
        x, y = todo.pop()
        # how high can Bix get from here?
        up = 3
        t = a(x, y + 1)
        if t & SPRING: up = 7
        if any((x, yy) in wind for yy in range(0, y + 1)): up = max(up, y)
        cands = []
        for dy in range(-up, 1):
            ty = y + dy
            # head room straight up
            if any(solid(x, yy) for yy in range(ty - 1, y)): continue
            rx = {-3: 4, -2: 5, -1: 6}.get(dy, 7) if dy >= -3 else 3
            for dx in range(-rx, rx + 1):
                for tx in (x + dx,):
                    if not (0 <= tx < W): continue
                    # path along the top of the jump must be clear-ish
                    step = 1 if dx > 0 else -1
                    ok = all(not solid(xx, ty - 1) and not solid(xx, ty) for xx in range(x + step, tx + step, step)) if dx else True
                    if not ok: continue
                    r = land(tx, ty)
                    if r: cands.append(r)
        # updrafts / vents: any wind cell in jump range carries Bix to the top of its column
        if wind:
            for (wx, wy) in wind:
                if abs(wx - x) <= 6 and y - 4 <= wy <= y + 2:
                    yt = wy
                    while (wx, yt - 1) in wind: yt -= 1
                    yt = max(0, yt - 3)
                    for dx in range(-6, 7):
                        r = land(wx + dx, yt)
                        if r: cands.append(r)
        # digging: from soil underfoot, through connected dig tiles, out anywhere above them
        if a(x, y + 1) & DIG:
            comp = set(); st = [(x, y + 1)]
            while st:
                c = st.pop()
                if c in comp: continue
                cx, cy = c
                if not (0 <= cx < W and 0 <= cy < H): continue
                if not (a(cx, cy) & DIG or g[cx][cy] == 'soilD'): continue
                comp.add(c)
                st += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
            for cx, cy in comp:
                for k in range(1, 7):  # burst out
                    if stand(cx, cy - k): cands.append((cx, cy - k))
        for c in cands:
            if c not in seen:
                seen.add(c); todo.append(c)
    got = any(x in exits or x - 1 in exits or x + 1 in exits for x, y in seen)
    far = max(x for x, y in seen)
    if verbose or not got:
        print(f'{name}: exit {"REACHED" if got else "NOT reached"}; furthest column {far}')
    return got, far

def holes(L, name, world):
    """columns with no ground, water or lava under them (pits) outside the sky world"""
    if world == 4: return []
    out = [x for x in range(L.W) if all(L.g[x][y] in ('sky', 'sky_tw', 'sky_tw2', 'fern', 'hillB', 'hillBT', 'hillL', 'hillM', 'hillR') for y in range(9, 12))]
    if out: print(f'{name}: open pits at columns {out}')
    return out

if __name__ == '__main__':
    import levels2, levels3
    tests = [('1-2', 1, levels3.level_1_2), ('1-3', 1, levels3.level_1_3), ('2-2', 2, levels3.level_2_2),
             ('2-3', 2, levels3.level_2_3), ('3-2', 3, levels3.level_3_2), ('3-3', 3, levels3.level_3_3),
             ('4-2', 4, levels3.level_4_2), ('4-3', 4, levels3.level_4_3), ('5-2', 5, levels3.level_5_2),
             ('5-3', 5, levels3.level_5_3),
             ('2-1', 2, levels2.level_2_1), ('3-1', 3, levels2.level_3_1), ('4-1', 4, levels2.level_4_1), ('5-1', 5, levels2.level_5_1)]
    for n, w, f in tests:
        L = f()
        nst = sum(1 for c in L.g for t in c if t == 'star')
        print(f'{n}: W={L.W} ents={len(L.ents)} stars={nst}', end='  ')
        check(L, w, n, verbose=True)
        holes(L, n, w)
