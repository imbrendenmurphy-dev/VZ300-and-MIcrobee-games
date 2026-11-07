#!/usr/bin/env python3
"""Rival test: rivals placed far from the player, drawn on the map, weekly AI
runs without crashing, envoys screen (E) with gift / trade / alliance."""
import os, subprocess
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build'))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open('empires.sym')}
TW = int(os.environ.get('TW', '340'))
def tap(k, n=1, hold=6, gap=6):
    o = []
    for _ in range(n): o += ['key %d 1' % k, 'frames %d' % hold, 'key %d 0' % k, 'frames %d' % gap]
    return o
PRE = ['frames 60'] + tap(3) + ['frames %d' % TW] + tap(33) + ['frames 30'] + tap(52) + ['frames 1500']
def run(lines):
    return subprocess.run(['../tools/beeemu', 'EMPIRES.COM', 'banked'], input='\n'.join(lines) + '\n',
                          capture_output=True, text=True).stderr
def rivals(m):
    n = m[sym['nrivals']]; out = []
    for i in range(n):
        r = m[sym['rivals'] + 16 * i: sym['rivals'] + 16 * i + 16]
        out.append(dict(act=r[0], x=r[1], y=r[2], rad=r[3], pop=r[4] | r[5] << 8, nb=r[6],
                        att=r[7] - 256 * (r[7] > 127), stat=r[8], pers=r[9], name=r[10]))
    return out
run(PRE + ['mem rv0.bin', 'blk 8 rm8.bin', 'blk 9 rm9.bin', 'blk 10 rm10.bin', 'blk 11 rm11.bin'])
m = open('rv0.bin', 'rb').read()
MB = [open('rm%d.bin' % b, 'rb').read() for b in (8, 9, 10, 11)]
sx, sy = m[sym['startxy']], m[sym['startxy'] + 1]
print('player', sx, sy, 'worldsize', m[sym['worldsize']])
R = rivals(m)
for r in R: print(r, 'dist', max(abs(r['x'] - sx), abs(r['y'] - sy)))
objs = {}
for y in range(256):
    for x in range(256):
        o = MB[y >> 6][0x4000 + (y & 63) * 256 + x]
        if o >= 0x20: objs[o] = objs.get(o, 0) + 1
print('rival objects', {hex(k): v for k, v in sorted(objs.items())})
# mark all met and friendly, a market, plenty of gold; run 40 weeks of AI
L = list(PRE)
for i in range(len(R)):
    b = sym['rivals'] + 16 * i
    L += ['poke %04X %02X' % (b + 8, 1), 'poke %04X %02X' % (b + 7, 30 + 20 * i)]
L += ['poke %04X %02X %02X' % (sym['gold'], 0xE8, 3), 'poke %04X 01' % sym['nmarket'], 'frames 2']
L += tap(5) + ['frames 30', 'shot rv_env1.bin']
L += tap(7) + ['frames 30', 'shot rv_gift.bin']        # G on rival 0
L += tap(20) + ['frames 30', 'shot rv_trade.bin']      # T on rival 0 (att 30+12) -> trade
L += tap(19) + ['frames 10'] + tap(19) + ['frames 10'] # down twice -> rival 2 (att 70)
L += tap(20) + ['frames 20'] + tap(1) + ['frames 30', 'shot rv_ally.bin']
L += tap(5) + ['frames 30', 'shot rv_back.bin']
L += ['poke %04X 03' % sym['speed'], 'frames 1000','mem rq1.bin','frames 1000','mem rq2.bin','frames 1000','mem rq3.bin','frames 3000', 'mem rv1.bin', 'shot rv_late.bin'] + tap(13) + ['frames 30', 'shot rv_ov.bin']
print(run(L)[-600:])
m = open('rv1.bin', 'rb').read()
for r in rivals(m): print(r)
print('week', m[sym['week']] if 'week' in sym else '?', 'gold', m[sym['gold']] | m[sym['gold'] + 1] << 8)

for f in ('rq1.bin','rq2.bin','rq3.bin'):
    m=open(f,'rb').read(); print(f,[ (r['att'],r['stat']) for r in rivals(m)], 'week',m[sym['week']],'gold',m[sym['gold']]|m[sym['gold']+1]<<8)
