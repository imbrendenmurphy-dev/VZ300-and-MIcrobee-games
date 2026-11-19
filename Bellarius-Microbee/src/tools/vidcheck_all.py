"""Video discipline over the whole game (raster model): the front end from
power-on (monitor choice, title, attract cycle, demo, pilot select), every
stage's boss fight, pause, stage clear, game over and name entry. Lists any
video RAM access made while the picture is displayed."""
import os, sys, bisect
os.environ['RASTER'] = '1'
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, peekw, to_game, tap, BUILD, symbols
from autoplay import step

S0 = symbols()
syms = [(v, k) for k, v in S0.items() if 0x8000 <= v < 0xC000]
for f in ['front'] + ['stage%d' % i for i in range(1, 6)]:
    p = BUILD / (f + '.sym')
    if p.exists():
        syms += [(v, f + ':' + k) for k, v in symbols(p).items() if 0xC000 <= v < 0xD000]
syms.sort()
addrs = [a for a, _ in syms]


def where(pc):
    i = bisect.bisect_right(addrs, pc) - 1
    return syms[i][1].split('.')[0] if i >= 0 else '%04X' % pc


def report(pp, what):
    d = pp.vdisp()
    by = {}
    for pc, c in d.items():
        k = where(pc)
        by[k] = by.get(k, 0) + c
    tot = sum(d.values())
    print('%-28s %6d display-time accesses %s' % (what, tot, ' '.join('%s:%d' % kv for kv in sorted(by.items(), key=lambda x: -x[1])[:6])))
    return tot


bad = 0
pp = boot()
pp.vdisp()
pp.run_frames(30)
bad += report(pp, 'monitor choice')
tap(pp, 'C')
pp.run_frames(1400)                     # title, hall of fame, how to play, the demo
bad += report(pp, 'title + attract + demo')
pp = boot(); to_game(pp)
bad += report(pp, 'to the game')
for st in (1, 2, 3, 4, 5):
    pp = boot(); to_game(pp); S = pp.S
    pp.vdisp()
    while peek(pp, 'stage') != st:
        pp.run_frames(20)
        if peek(pp, 'gstate') == 0 and peek(pp, 'stage') < st:
            pp.poke(S['stage'], st - 1); pp.poke(S['gstate'], S['GS_CLEAR'])
    pp.run_frames(100)
    bad += report(pp, 'stage %d start' % st)
    pp.poke(S['scrollx'], 0x80); pp.poke(S['scrollx'] + 1, 0x11)
    n = 0
    while peek(pp, 'gstate') != 1 and n < 400:
        step(pp, 8); n += 1
    for i in range(150):
        step(pp); pp.poke(S['lives'], 3)
    bad += report(pp, 'stage %d boss' % st)
    if st == 2:
        tap(pp, 'H'); pp.run_frames(60); tap(pp, 'H'); pp.run_frames(30)
        bad += report(pp, 'pause')
# game over and name entry
pp.poke(S['lives'], 0); pp.poke(S['hearts'], 1)
pp.poke(S['gstate'], S['GS_OVER'])
pp.run_frames(600)
bad += report(pp, 'game over + name entry')
print('TOTAL', bad)
