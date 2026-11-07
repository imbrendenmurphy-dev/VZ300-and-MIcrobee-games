#!/usr/bin/env python3
"""Save/load round trip: play scenario 4 (three rivals) for a while, save to
slot 1, then in a fresh machine load it from the title and compare state."""
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
if os.path.exists('SAVE1.EMP'): os.remove('SAVE1.EMP')
L = ['frames 60'] + tap(3) + ['frames 340'] + tap(33) + ['frames 30'] + tap(36) + ['frames 20'] + tap(52) + ['frames 1500']
L += ['poke %04X 03' % sym['speed'], 'frames 3000', 'poke %04X 00' % sym['speed'], 'frames 10', 'mem sv_a.bin']
for b in (8, 9): L.append('blk %d sv_a%d.bin' % (b, b))
L += tap(6) + ['frames 30'] + tap(19) + ['frames 30'] + tap(33) + ['frames 600', 'shot sv_saved.bin']
print(run(L)[-200:])
print('save file', os.path.getsize('SAVE1.EMP') if os.path.exists('SAVE1.EMP') else None)
L = ['frames 60'] + tap(3) + ['frames 340'] + tap(39) + ['frames 60'] + tap(33) + ['frames 900', 'mem sv_b.bin', 'shot sv_loaded.bin']
for b in (8, 9): L.append('blk %d sv_b%d.bin' % (b, b))
run(L)
a = open('sv_a.bin', 'rb').read(); b = open('sv_b.bin', 'rb').read()
s0, s1 = sym['sv_start'], sym['sv_end']
diff = [hex(i) for i in range(s0, s1) if a[i] != b[i]]
print('state bytes', s1 - s0, 'differ', len(diff), diff[:10])
for k in ('scen', 'nrivals', 'goal_done'): print(k, a[sym[k]], b[sym[k]])
for bk in (8, 9):
    x = open('sv_a%d.bin' % bk, 'rb').read(); y = open('sv_b%d.bin' % bk, 'rb').read()
    print('block', bk, 'differ', sum(1 for i in range(32768) if x[i] != y[i]))
