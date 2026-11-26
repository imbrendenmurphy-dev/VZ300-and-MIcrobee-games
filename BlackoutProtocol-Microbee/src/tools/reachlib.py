"""Reachability: can Agent Wren get to every fitting, terminal and door of a room?

Wren stands on a floor row f at column c.  He can walk along solid cells, fall
through a gap to the next floor below (off the bottom is death, not a route),
vault `vault` cells along the same floor (landing on solid, else falling), and
ride a lift pad between any of its floors.  Robots and timed hazards are ignored.
"""
from collections import deque

def check(rm, solid_tiles, vault=9):
    pad_cells = {}
    for c0, fl in rm.pads:
        for f in fl:
            for c in range(c0, c0 + 3): pad_cells[(f, c)] = tuple(fl)
    left, right = rm.doors
    def solid(f, c):
        if (f, c) in pad_cells: return True
        if c in (0, 1): return left == f
        if c in (40, 41): return right == f
        return 0 <= f < 22 and rm.t[f][c] in solid_tiles
    def land(f, c):
        for r in range(f + 1, 22):
            if solid(r, c): return (r, c)
        return None
    def nexts(f, c):
        out = []
        for d in (-1, 1):
            n = c + d
            if 0 <= n <= 41: out.append((f, n) if solid(f, n) else land(f, n))
            n = c + d * vault
            n = max(0 if left == f else 2, min(41 if right == f else 39, n))
            out.append((f, n) if solid(f, n) else land(f, n))
        if (f, c) in pad_cells: out += [(g, c) for g in pad_cells[(f, c)]]
        return [p for p in out if p]
    starts = [(f, 1 if side == 'L' else 40) for side, f in (('L', left), ('R', right)) if f is not None]
    problems = []
    for s in starts:
        seen = {s}; q = deque([s])
        while q:
            p = q.popleft()
            for n in nexts(*p):
                if n not in seen: seen.add(n); q.append(n)
        need = [('fitting', (r + 1, c)) for (r, c) in rm.searchables()]
        need += [('terminal', (r + 1, c)) for r in range(22) for c in range(42) if rm.t[r][c] in ('termb', 'splb')]
        need += [('door', d) for d in starts if d != s]
        for what, (f, c) in need:
            if (f, c) not in seen:
                problems.append(f'{what} at row {f - 1}, col {c} unreachable from the door at row {s[0]}')
    return sorted(set(problems))
