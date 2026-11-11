"""Plays DROPBEAR.VZ in the simulator with a simple bot; checks it end to end."""
import math, pickle, sys
from collections import deque
from z80tools import Z80
from PIL import Image

P = pickle.load(open('image.pkl', 'rb')); S = P['syms']
PAL = {0: [(48, 210, 0), (193, 229, 0), (76, 58, 180), (170, 50, 54)],
       1: [(214, 206, 160), (60, 190, 160), (190, 60, 190), (220, 110, 30)]}
def shot(z, scale=6):
    pal = PAL[(z.latch >> 4) & 1]; im = Image.new('RGB', (128, 64))
    for y in range(64):
        for xb in range(32):
            b = z.m[0x7000+y*32+xb]
            for i in range(4): im.putpixel((xb*4+i, y), pal[(b >> (6-2*i)) & 3])
    return im.resize((128*scale, 96*scale), Image.NEAREST)

z = Z80(bytearray(65536)); z.m[0x8000:0x8000+len(P['body'])] = P['body']; z.pc = 0x8000
while z.pc != S['start']: z.step()
assert bytes(z.m[0x8100:P['IMGEND']]) == P['image'], 'unpack mismatch'
print('unpacked OK in %d T-states (%.2f s)' % (z.t, z.t/3546900))

rd = lambda a: z.m[a]
rd16 = lambda a: z.m[a] | z.m[a+1] << 8
ROW = {'W': (0, 1), 'Q': (0, 4), 'E': (0, 3), 'S': (1, 1), 'A': (1, 4), 'D': (1, 3), ' ': (4, 4)}
def press(keys):
    k = {}
    for c in keys:
        r, b = ROW[c]; k[r] = k.get(r, 0x7F) & ~(1 << b)
    z.keys = k

def los(grid, x0, y0, x1, y1):
    n = int(max(abs(x1-x0), abs(y1-y0))*40)+1
    for i in range(1, n):
        x = x0+(x1-x0)*i/n; y = y0+(y1-y0)*i/n
        if grid[int(y)*16+int(x)]: return False
    return True
def bfs(grid, start, goal):
    prev = {start: None}; q = deque([start])
    while q:
        c = q.popleft()
        if c == goal: break
        x, y = c
        for n in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if n in prev: continue
            v = grid[n[1]*16+n[0]]
            if v in (0, 3) or n == goal: prev[n] = c; q.append(n)
    if goal not in prev: return None
    path = [goal]
    while prev[path[-1]] is not None: path.append(prev[path[-1]])
    return path[::-1]

def bot():
    px, py = rd16(S['px'])/256, rd16(S['py'])/256; ang = rd16(S['pang'])
    grid = z.m[S['MAP']:S['MAP']+256]
    objs = []
    for i in range(16):
        a = S['OBJ']+i*8
        if z.m[a]: objs.append((z.m[a], rd16(a+1)/256, rd16(a+3)/256, z.m[a+6]))
    def steer(tx, ty, walk=True):
        want = math.atan2(ty-py, tx-px)*1024/(2*math.pi)
        d = (want-(ang+0.5)+512) % 1024-512
        k = ''
        if d > 6: k += 'D'
        elif d < -6: k += 'A'
        if walk and abs(d) < 60: k += 'W'
        return k, d
    foes = [(math.hypot(o[1]-px, o[2]-py), o) for o in objs if o[0] < 3 and o[3] & 0x80 and los(grid, px, py, o[1], o[2])]
    if foes and PACIFIST: return ''
    if foes and rd(S['ammo']):
        dist, o = min(foes)
        k, d = steer(o[1], o[2], walk=False)
        if abs(d) < 14: k += ' '
        if dist < 1.6: k += 'S'
        return k
    goal = None
    if rd(S['hp']) < 45:
        hs = [o for o in objs if o[0] == 3]
        if hs: goal = (int(hs[0][1]), int(hs[0][2]))
    if goal is None and not rd(S['key']):
        ks = [o for o in objs if o[0] == 5]
        if ks: goal = (int(ks[0][1]), int(ks[0][2]))
    if goal is None:
        e = [i for i in range(256) if grid[i] == 4][0]; goal = (e % 16, e//16)
    path = bfs(grid, (int(px), int(py)), goal)
    if not path or len(path) < 2: return steer(goal[0]+0.5, goal[1]+0.5)[0]
    return steer(path[1][0]+0.5, path[1][1]+0.5)[0]

frames = []; stats = []; shots = {}; fstart = None; ftimes = []; nframe = 0; lvlframes = 0
LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 4000
PACIFIST = len(sys.argv) > 2
watch = {S[n]: n for n in ('gloop', 'wf1', 'wf2', 'tt2', 'main', 'lvl', 'dead')}
titles = 0; done = False; deaths = 0; minhp = 100; wins = 0; lastpage = None
while not done:
    n = watch.get(z.pc)
    if n == 'tt2':
        titles += 1
        if titles == 1: shots['title'] = shot(z)
        if titles == 6: shots['title2'] = shot(z)
        press(' ' if titles > 8 else '')
        if wins and titles > 2: done = True
    elif n == 'wf1': press('')
    elif n == 'wf2':
        if lastpage != z.t//2000000: pass
        key = 'page%d' % len([k for k in shots if k.startswith('page')])
        if not z.keys: pass
        if getattr(z, 'pagepc', None) != nframe: shots[key] = shot(z); z.pagepc = nframe
        press(' ')
    elif n == 'dead':
        deaths += 1
        if deaths == 2: done = True
    elif n == 'main' and nframe: wins += 1
    elif n == 'lvl':
        if lvlframes: stats.append((rd(S['level']), lvlframes, sum(ftimes[-lvlframes:])/lvlframes)); lvlframes = 0
    elif n == 'gloop':
        if fstart is not None: ftimes.append(z.t-fstart)
        fstart = z.t; nframe += 1; lvlframes += 1
        minhp = min(minhp, rd(S['hp']))
        if nframe > 1 and nframe % 4 == 0 and len(frames) < 900: frames.append(shot(z, 3))
        if nframe in (3, 40, 120, 300, 600): shots['game%d' % nframe] = shot(z)
        if rd(S['nvis']) and rd(S['tz']) > 44 and len([k for k in shots if k.startswith('close')]) < 6 and nframe % 7 == 0: shots['close%d' % nframe] = shot(z)
        if rd(S['hurtflash']): shots.setdefault('bitten', shot(z))
        if rd(S['nvis']) and rd16(S['target']) and 'aim' not in shots and nframe > 20: shots['aim'] = shot(z)
        press(bot())
        if nframe >= LIMIT: done = True
    z.step()
print('frames %d, deaths %d, lowest health %d, finished game: %s' % (nframe, deaths, minhp, bool(wins)))
ft = sorted(ftimes)
print('frame time: median %d T (%.1f fps), 90th pct %d T (%.1f fps), worst %d T' %
      (ft[len(ft)//2], 3546900/ft[len(ft)//2], ft[len(ft)*9//10], 3546900/ft[len(ft)*9//10], ft[-1]))
for lv, n, avg in stats: print('  level %d: %d frames, %.1f fps average, %.0f s of play' % (lv-1 if lv > 1 else lv, n, 3546900/avg, n*avg/3546900))
for k, im in shots.items(): im.save('shot_%s.png' % k)
if frames: frames[0].save('play.gif', save_all=True, append_images=frames[1:], duration=200, loop=0)
print('saved', sorted(shots))
if not wins:
    print('STATE level', rd(S['level']), 'pos %.2f %.2f ang %d' % (rd16(S['px'])/256, rd16(S['py'])/256, rd16(S['pang'])), 'hp', rd(S['hp']), 'ammo', rd(S['ammo']), 'key', rd(S['key']), 'bears', rd(S['bears']), 'keys', z.keys)
    for i in range(16):
        a = S['OBJ']+i*8
        if z.m[a]: print('  obj', z.m[a], '%.2f %.2f' % (rd16(a+1)/256, rd16(a+3)/256), 'hp', z.m[a+5], 'flags %02x' % z.m[a+6])
    g = z.m[S['MAP']:S['MAP']+256]
    for y in range(16): print(''.join('.#CDXM'[g[y*16+x]] for x in range(16)))
    shot(z).save('shot_stuck.png')
