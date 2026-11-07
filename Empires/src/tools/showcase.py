#!/usr/bin/env python3
"""Build a well-developed town in the emulator for screenshots and the
showcase GIF.  Phase 1 dumps a fresh world; phase 2 plans and builds."""
import os, subprocess, sys, json
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build'))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open('empires.sym')}
def tap(k, n=1, hold=4, gap=4):
    o = []
    for _ in range(n): o += ['key %d 1' % k, 'frames %d' % hold, 'key %d 0' % k, 'frames %d' % gap]
    return o
def run(lines):
    return subprocess.run(['../tools/beeemu', 'EMPIRES.COM', 'banked'], input='\n'.join(lines) + '\n',
                          capture_output=True, text=True).stderr
def poke16(n, v): return 'poke %04X %02X %02X' % (sym[n], v & 255, (v >> 8) & 255)
MONO = os.environ.get('MONO') == '1'
PRE = ['frames 60'] + tap(13 if MONO else 3, hold=6, gap=6) + ['frames 340'] + tap(33, hold=6, gap=6) + ['frames 30'] + tap(52, hold=6, gap=6) + ['frames 1500']
def plan():
    run(PRE + ['mem show/s0.bin', 'blk 8 show/s8.bin', 'blk 9 show/s9.bin'])
    m = open('show/s0.bin', 'rb').read()
    MB = [open('show/s8.bin', 'rb').read(), open('show/s9.bin', 'rb').read()]
    t = lambda x, y: MB[y >> 6][(y & 63) * 256 + x] & 31
    o = lambda x, y: MB[y >> 6][0x4000 + (y & 63) * 256 + x]
    sx, sy = m[sym['startxy']], m[sym['startxy'] + 1]
    used = {(sx + a, sy + b) for a in (0, 1) for b in (0, 1)}
    LAND = (3, 4, 5, 13)
    def ok(x, y, land=LAND, r=6.3):
        return (x, y) not in used and o(x, y) == 0 and t(x, y) in land and \
            ((x - sx - .5) ** 2 + (y - sy - .5) ** 2) ** .5 <= r
    P1, P2 = [], []
    roads = set()
    for x in range(sx - 6, sx + 8):
        if ok(x, sy + 2): roads.add((x, sy + 2))
    for y in range(sy - 5, sy + 7):
        if ok(sx + 3, y): roads.add((sx + 3, y))
    for x in range(sx - 4, sx + 3):
        if ok(x, sy - 1): roads.add((x, sy - 1))
    for r in sorted(roads, key=lambda p: abs(p[0] - sx) + abs(p[1] - sy)):
        used.add(r); P1.append((1, r))
    def nb_road(x, y): return any((x + a, y + b) in roads for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    slots = sorted([(x, y) for y in range(sy - 7, sy + 9) for x in range(sx - 7, sx + 9) if ok(x, y) and nb_road(x, y)],
                   key=lambda p: (p[0] - sx - .5) ** 2 + (p[1] - sy - .5) ** 2)
    special = [(2, 'market'), (2, 'market')]
    page2 = ['school', 'temple', 'hospital', 'university']
    n = 0
    for s in slots:
        if n < 2: P1.append((7, s))
        elif n in (4, 9, 14): P1.append((6, s))
        elif 5 <= n and len(P2) < 4 and n % 3 == 2: P2.append(({'school': 2, 'temple': 5, 'hospital': 4, 'university': 6}[page2[len(P2)]], s))
        else: P1.append((2, s))
        used.add(s); n += 1
        if n >= 26: break
    # forum: a free 2x2 near the centre
    for r in range(2, 8):
        done = False
        for y in range(sy - r, sy + r + 1):
            for x in range(sx - r, sx + r + 1):
                if all(ok(x + a, y + b, (3, 4, 5, 13), 7) for a in (0, 1) for b in (0, 1)):
                    P2.append((7, (x, y))); used |= {(x + a, y + b) for a in (0, 1) for b in (0, 1)}; done = True; break
            if done: break
        if done: break
    # farms on open grass, windmill near them
    def grassy(x, y): return sum(1 for a in (-1, 0, 1) for b in (-1, 0, 1) if t(x + a, y + b) in (4, 5) and o(x + a, y + b) == 0 and (x + a, y + b) not in used)
    farms = 0
    for r in (4, 5, 6):
        for y in range(sy - r, sy + r + 2):
            for x in range(sx - r, sx + r + 2):
                if farms < 5 and ok(x, y, (4, 5), 6.8) and grassy(x, y) >= 6:
                    P1.append((3, (x, y))); used |= {(x + a, y + b) for a in (-1, 0, 1) for b in (-1, 0, 1)}; farms += 1
    def near(x, y, types, rr=1): return sum(1 for a in range(-rr, rr + 1) for b in range(-rr, rr + 1) if t(x + a, y + b) in types)
    def best(pred, tool, lst, r=6.8):
        for y in range(sy - 7, sy + 9):
            for x in range(sx - 7, sx + 9):
                if ok(x, y, LAND, r) and pred(x, y):
                    lst.append((tool, (x, y))); used.add((x, y)); return True
    best(lambda x, y: near(x, y, (6, 7)) >= 3, 4, P1)
    best(lambda x, y: near(x, y, (6, 7)) >= 2, 4, P1)
    best(lambda x, y: near(x, y, (8, 9, 14)) >= 2, 5, P1)
    best(lambda x, y: near(x, y, (13,)) >= 1 or near(x, y, (4, 5)) >= 6, 8, P1)
    best(lambda x, y: abs(x - sx) >= 5, 9, P1)
    best(lambda x, y: abs(y - sy) >= 5, 9, P1)
    for y in range(sy - 7, sy + 9):          # mine on hills
        for x in range(sx - 7, sx + 9):
            if ok(x, y, (8, 14), 6.8): P2.append((1, (x, y))); used.add((x, y)); break
        else: continue
        break
    best(lambda x, y: near(x, y, (0, 1)) >= 2, 'harbour', P2)
    P2 = [(3, s) if tl == 'harbour' else (tl, s) for tl, s in P2]
    return sx, sy, P1, P2
if __name__ == '__main__':
    sx, sy, P1, P2 = plan()
    json.dump({'sx': sx, 'sy': sy, 'P1': P1, 'P2': P2}, open('show/plan.json', 'w'))
    print('start', sx, sy, len(P1), 'page1', len(P2), 'page2'); print(P1); print(P2)

def build_cmds(sx, sy, P1, P2):
    L = [poke16('techs', 0x1FFF), poke16('wood', 9000), poke16('stone', 9000), poke16('gold', 9000),
         poke16('food', 4000), poke16('pop', 40), 'poke %04X 1F' % sym['goal_done'], 'poke %04X 00' % sym['speed'], 'frames 2']
    cx, cy = sx, sy
    K = {'up': 23, 'left': 1, 'down': 19, 'right': 4}
    def goto(x, y):
        nonlocal cx, cy
        out = []
        if x > cx: out += tap(K['right'], x - cx, 3, 3)
        if x < cx: out += tap(K['left'], cx - x, 3, 3)
        if y > cy: out += tap(K['down'], y - cy, 3, 3)
        if y < cy: out += tap(K['up'], cy - y, 3, 3)
        cx, cy = x, y
        return out
    def key_for(slot): return 32 if slot == 10 else 32 + slot
    cur = None
    for tool, (x, y) in P1:
        if tool != cur: L += tap(key_for(tool)); cur = tool
        L += goto(x, y) + tap(55) + ['frames 4']
    L += tap(2) + ['frames 6']; cur = None       # B: page 2
    for tool, (x, y) in P2:
        if tool != cur: L += tap(key_for(tool)); cur = tool
        L += goto(x, y) + tap(55) + ['frames 4']
    L += tap(2) + tap(33) + goto(sx + 3, sy + 2)  # back to page 1, road tool, cursor by the hall
    return L
