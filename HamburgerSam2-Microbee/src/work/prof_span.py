"""Profile the span from main_menu to main_menu.l (menu entry)."""
import bisect, collections, sys
from test_native import *
labels = sorted((v, k) for k, v in sym.items() if '.' not in k and 0x100 <= v < 0x10000)
addrs = [a for a, _ in labels]
def name(pc):
    i = bisect.bisect_right(addrs, pc) - 1
    return labels[i][1]
a, z = (sys.argv[1], sys.argv[2]) if len(sys.argv) > 2 else ('main_menu', 'main_menu.l')
b = Bee(); b.until('title_screen.l'); b.keys = {55}; b.until(a, 3000); b.keys = set()
t0 = b.elapsed; hits = collections.Counter(); b.m.set_breakpoint(sym[z])
while True:
    b.run(ticks=101); hits[name(b.m.pc)] += 1
    if b.m.pc == sym[z]: break
print('fields', (b.elapsed - t0) / 67500)
tot = sum(hits.values())
for k, v in hits.most_common(15): print(f'{100*v/tot:5.1f}% {k}')
