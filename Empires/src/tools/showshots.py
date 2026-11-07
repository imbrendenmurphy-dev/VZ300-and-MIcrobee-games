#!/usr/bin/env python3
"""Screenshots and showcase GIF frames.  Writes show/*.bin, renders PNGs."""
import sys, os, json, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import showcase as S
tap, sym, poke16 = S.tap, S.sym, S.poke16
p = json.load(open('show/plan.json'))
P1 = [(a, tuple(b)) for a, b in p['P1']]; P2 = [(a, tuple(b)) for a, b in p['P2']]
sx, sy = p['sx'], p['sy']
G = []        # gif frame list: (bin name, duration ms)
def shot(name, gif=0):
    if gif: G.append((name, gif))
    return ['shot show/%s.bin' % name]
# ---- A: title in colour, scenario list, help
L = ['frames 60'] + tap(3, hold=6, gap=6) + ['frames 300']
for i in range(14): L += ['frames 5'] + shot('g_title%02d' % i, 160)
L += shot('title')
L += tap(33, hold=6, gap=6) + ['frames 30'] + shot('scenarios', 1800)
L += tap(36, hold=6, gap=6) + ['frames 20'] + shot('scenarios2', 1500)
L += tap(48, hold=6, gap=6) + ['frames 60'] + tap(37, hold=6, gap=6) + ['frames 60'] + shot('help')
S.run(L)
# ---- B: title in amber
S.run(['frames 60'] + tap(13, hold=6, gap=6) + ['frames 340'] + shot('title_amber', 1300))
# ---- C: the game
B = S.build_cmds(sx, sy, P1, P2)
L = list(S.PRE) + shot('start', 1600)
# a few build steps in the GIF
L += B[:len(B) // 3] + shot('g_build1', 500) + B[len(B) // 3:2 * len(B) // 3] + shot('g_build2', 500) + B[2 * len(B) // 3:]
L += ['frames 20'] + shot('built', 700)
VX, VY = max(0, sx + 2 - 20), max(0, sy + 1 - 9)
def centre(vx, vy, cx, cy):
    return ['poke %04X %02X %02X' % (sym['viewx'], vx, vy), 'poke %04X %02X %02X' % (sym['curx'], cx, cy),
            'frames 2'] + tap(13, hold=6, gap=6) + ['frames 20'] + tap(13, hold=6, gap=6) + ['frames 20']
L += centre(VX, VY, sx + 3, sy + 2)
L += ['poke %04X 03' % sym['speed']]
# grow for a while, then a year of seasons
for i in range(4): L += ['frames 800', poke16('food', 4000), poke16('wood', 9000)]
names = ['spring', 'summer', 'autumn', 'winter']
# wait for the next spring
L += ['frames 10']
for k in range(52):
    L += ['frames 30', poke16('food', 4000)] + (shot('g_year%02d' % k, 110) if k % 2 == 0 else [])
    if k == 30:
        L += ['poke %04X 00' % sym['speed']] + tap(3, hold=6, gap=6) + ['frames 40'] + shot('town_amber', 1300) + tap(3, hold=6, gap=6) + ['frames 40', 'poke %04X 03' % sym['speed']]
L += ['mem show/cal.bin']
c = open('show/cal.bin', 'rb').read() if os.path.exists('show/cal.bin') else None
L += ['poke %04X 00' % sym['speed'], 'frames 4']
L += centre(VX, VY, sx + 3, sy + 2) + shot('town', 1600)
L += tap(13, hold=6, gap=6) + ['frames 30'] + shot('worldmap', 1600) + tap(13, hold=6, gap=6) + ['frames 30']
L += tap(18, hold=6, gap=6) + ['frames 40'] + shot('research', 1600) + tap(48, hold=6, gap=6) + ['frames 40']
L += tap(2, hold=6, gap=6) + ['frames 20'] + shot('tools2', 1300) + tap(2, hold=6, gap=6) + ['frames 20']
if c:
    for i in range(c[sym['nrivals']]):
        b = sym['rivals'] + 16 * i
        L += ['poke %04X 01' % (b + 8), 'poke %04X %02X' % (b + 7, 45 + 15 * i)]
L += tap(5, hold=6, gap=6) + ['frames 40'] + shot('envoys', 1500) + tap(20, hold=6, gap=6) + ['frames 30'] + shot('envoys_trade', 1500)
L += tap(5, hold=6, gap=6) + ['frames 40']
L += tap(22, hold=6, gap=6) + ['frames 40'] + shot('goals', 1600) + tap(48, hold=6, gap=6) + ['frames 40']
L += tap(6, hold=6, gap=6) + ['frames 40'] + shot('filemenu', 1300) + tap(48, hold=6, gap=6) + ['frames 40']
# a rival town, revealed
if c:
    rx, ry = c[sym['rivals'] + 1], c[sym['rivals'] + 2]
    for y in range(ry - 9, ry + 10):
        for x in range(rx - 16, rx + 17):
            if 0 <= x < 128 and 0 <= y < 128: L.append('bor %d %X 80' % (8 + (y >> 6), (y & 63) * 256 + x))
    L += centre(max(0, min(88, rx - 19)), max(0, min(108, ry - 9)), rx, ry) + shot('rival_town', 1500)
    L += centre(VX, VY, sx + 3, sy + 2)
# victory: prosperity is due at the next month's check
L += ['poke %04X 1E' % sym['goal_done'], poke16('gold', 13000), 'poke %04X 03' % sym['speed'], 'frames 240'] + shot('victory', 2200)
L += tap(3, hold=6, gap=6) + ['frames 40']
S.run(L + ['quit'])
m = open('show/cal.bin', 'rb').read()
print('after year: season', m[sym['season']], 'week', m[sym['week']], 'year', m[sym['year']])

# ---- render everything and make the GIF
AMBER = {'town_amber', 'title_amber'}
import glob
for f in glob.glob('show/*.bin'):
    n = os.path.basename(f)[:-4]
    if n in ('s0', 's8', 's9', 'cal', 'rv', 'rv8', 't_m') or len(open(f, 'rb').read()) < 30000: continue
    subprocess.run(['python3', '../tools/render.py', f, 'show/%s.png' % n] + (['amber'] if n in AMBER else []), capture_output=True)
from PIL import Image
order = [g for g in G if g[0].startswith('g_title')] + [g for g in G if g[0] == 'title_amber'] + \
        [g for g in G if not g[0].startswith('g_title') and g[0] != 'title_amber']
frames, durs = [], []
for n, d in order:
    im = Image.open('show/%s.png' % n).convert('RGB')
    frames.append(im.quantize(colors=64, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)); durs.append(d)
frames[0].save('show/EMPIRES_showcase.gif', save_all=True, append_images=frames[1:], duration=durs, loop=0, optimize=True, disposal=1)
print('gif frames', len(frames), 'seconds', sum(durs) / 1000, 'bytes', os.path.getsize('show/EMPIRES_showcase.gif'))
