#!/usr/bin/env python3
"""zflood.py N - show what is reachable in zone N with every gate, door and key open"""
import sys; sys.path.insert(0, 'tools')
import zones
from collections import deque
z = zones.ZONES[int(sys.argv[1]) - 1]
cells, ents, levers, gates, start = zones.parse(z)
gate_at = {(x, y) for x, y, g, c in gates}
seen = {start}; q = deque([start])
while q:
    x, y = q.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (x + dx, y + dy)
        c = cells[n[1] * 32 + n[0]]
        if n not in seen and (n in gate_at or c in (0, 5, 6, 7, 8, 13, 14)):
            seen.add(n); q.append(n)
for y, row in enumerate(z['map']):
    print(''.join('+' if (x, y) in seen and ch == '.' else ch for x, ch in enumerate(row)), y)
