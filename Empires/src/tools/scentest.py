#!/usr/bin/env python3
"""Scenario test: the list, starting gifts, the goals screen, a scenario
victory, a free-play victory and a defeat."""
import os, subprocess
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'build'))
sym = {l.split()[1]: int(l.split()[0], 16) for l in open('empires.sym')}
def tap(k, n=1):
    o = []
    for _ in range(n): o += ['key %d 1' % k, 'frames 6', 'key %d 0' % k, 'frames 6']
    return o
def run(lines):
    return subprocess.run(['../tools/beeemu', 'EMPIRES.COM', 'banked'], input='\n'.join(lines) + '\n',
                          capture_output=True, text=True).stderr
def w(m, n): return m[sym[n]] | m[sym[n] + 1] << 8
def poke16(n, v): return 'poke %04X %02X %02X' % (sym[n], v & 255, v >> 8)
T = ['frames 60'] + tap(3) + ['frames 340'] + tap(33) + ['frames 30', 'shot sc_list0.bin'] + tap(34) + ['frames 20', 'shot sc_list1.bin']
# scenario 2 (THE FIRST SETTLEMENT): start, goals, then 50 people -> victory
L = T + tap(52) + ['frames 1500', 'mem sc_m0.bin'] + tap(22) + ['frames 30', 'shot sc_goals.bin'] + tap(22) + ['frames 20']
L += [poke16('pop', 55), poke16('food', 900), 'poke %04X 03' % sym['speed'], 'frames 900', 'shot sc_win.bin', 'mem sc_m1.bin']
L += tap(3) + ['frames 40', 'mem sc_m2.bin', 'shot sc_after.bin']
print(run(L)[-200:])
m0, m1, m2 = (open(f, 'rb').read() for f in ('sc_m0.bin', 'sc_m1.bin', 'sc_m2.bin'))
print('scen', m0[sym['scen']], 'rivals', m0[sym['nrivals']], 'food', w(m0, 'food'), 'gold', w(m0, 'gold'), 'nexpl', w(m0, 'nexpl'))
print('after: goal_done %02X want %d quit %d' % (m1[sym['goal_done']], m1[sym['want_goal']], m2[sym['quit_flag']]))
# free play: all techs -> science victory
L = T[:T.index('shot sc_list0.bin')] + tap(52) + ['frames 1500', poke16('techs', 0x1FFF), 'poke %04X 03' % sym['speed'], 'frames 900', 'shot sc_sci.bin'] + tap(48) + ['frames 60', 'shot sc_title.bin']
run(L)
import sys
if 'sci' in sys.argv: raise SystemExit
# defeat
L = T + tap(52) + ['frames 1500', poke16('pop', 1), 'poke %04X 03' % sym['speed'], 'frames 900', 'shot sc_lost.bin']
run(L)
for f in ('sc_sci','sc_title') if 0 else ('sc_list0', 'sc_list1', 'sc_goals', 'sc_win', 'sc_after', 'sc_sci', 'sc_title', 'sc_lost'):
    subprocess.run(['python3', '../tools/render.py', f + '.bin', f + '.png'], capture_output=True)
