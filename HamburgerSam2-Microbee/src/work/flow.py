"""Full flow: real keys into a game, autopilot plays it to the end.
flow.py fields step [godmode]   (screens -> outputs/flow/)"""
import sys, collections
from test_native import *
Path('outputs/flow').mkdir(parents=True, exist_ok=True)
for f in Path('outputs/flow').glob('*.png'): f.unlink()
fields = int(sys.argv[1]); step = int(sys.argv[2]); god = len(sys.argv) > 3
b = Bee(); M = b.m.memory
labels = sorted((v, k) for k, v in sym.items() if '.' not in k)
import bisect
addrs = [a for a, _ in labels]
def where(pc):
    i = bisect.bisect_right(addrs, pc) - 1
    return labels[i][1]
def press(k, n=30):
    b.keys = {k}; b.run(n); b.keys = set(); b.run(n)
b.until('title_screen.l')
press(55)                       # SPACE -> menu
b.run(60); b.shot('flow/menu')
press(55)                       # play from kitchen 1
seen = collections.Counter(); last = None
for i in range(fields):
    b.run()
    if b.peek(sym['mode']) == 1:
        M[sym['autoplay']] = 1
        if god: M[sym['godmode']] = 1
    w = where(b.m.pc)
    if i % step == 0:
        info = f"{i} {w} mode={b.peek(sym['mode'])} kit={b.peek(sym['kitchen'])} lives={b.peek(sym['lives'])} score={M[sym['score']]:02x}{M[sym['score']+1]:02x}{M[sym['score']+2]:02x}"
        print(info, flush=True)
        b.shot(f'flow/f{i:06d}')
    if not (0x100 <= b.m.pc < 0x8000 or 0xEC00 <= b.m.pc < 0xEF00):
        print('PC OUT OF RANGE', hex(b.m.pc)); b.shot('flow/crash'); break
