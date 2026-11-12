"""Plays DROPBEAR.VZ in the simulator with a bot that explores the whole world; checks it end to end.
usage: python3 play.py [frame limit] [pacifist]"""
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
assert bytes(z.m[0x8100:P['IMGEND']]) == P['image'], 'main unpack mismatch'
assert z.losel == 0 and z.hisel == 0
assert bytes(z.m[0x4000:0x4000+len(P['img1'])]) == P['img1'], 'bank 1 unpack mismatch'
assert bytes(z.lowalt[:len(P['img3'])]) == P['img3'], 'bank 3 unpack mismatch'
assert bytes(z.m[0x7A00:0x7A00+len(P['imglo'])]) == P['imglo'], '$7A00 unpack mismatch'
la = P['LIBADDR']-0xB800
assert bytes(z.highalt[la:la+len(P['imghi'])]) == P['imghi'], 'high bank unpack mismatch'
print('unpacked all five parts OK in %.2f s' % (z.t/3546900))

rd = lambda a: z.m[a]
rd16 = lambda a: z.m[a] | z.m[a+1] << 8
ROW = {'W': (0, 1), 'Q': (0, 4), 'E': (0, 3), 'S': (1, 1), 'A': (1, 4), 'D': (1, 3), ' ': (4, 4), 'M': (4, 5)}
def press(keys):
    k = {}
    for c in keys:
        r, b = ROW[c]; k[r] = k.get(r, 0x7F) & ~(1 << b)
    z.keys = k

LIMIT = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
PACIFIST = len(sys.argv) > 2
ITIN = [0, 1, 2, 1, 3, 4, 5, 6, 7, 8, 255]
itin = 0
EXITS = P['exits']; NAMES = [a['name'] for a in P['areas']]

def los(grid, x0, y0, x1, y1):
    n = int(max(abs(x1-x0), abs(y1-y0))*40)+1
    for i in range(1, n):
        x = x0+(x1-x0)*i/n; y = y0+(y1-y0)*i/n
        if grid[int(y)*16+int(x)] & 0x7F: return False
    return True
def bfs(grid, start, keys, goals):
    """shortest walk to any goal cell; goal cells may be walls (bump targets)"""
    prev = {start: None}; q = deque([start]); hit = None
    while q:
        c = q.popleft()
        if c in goals: hit = c; break
        x, y = c
        for n in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if n in prev or not (0 <= n[0] < 16 and 0 <= n[1] < 16): continue
            v = grid[n[1]*16+n[0]]
            if v in (0, 3, 10) or (v == 6 and keys) or n in goals: prev[n] = c; q.append(n)
    if hit is None: return None
    path = [hit]
    while prev[path[-1]] is not None: path.append(prev[path[-1]])
    return path[::-1]

stuck = [0, None, 0]
def bot(nframe):
    global itin
    area = rd(S['area'])
    if itin+1 < len(ITIN) and area == ITIN[itin+1]: itin += 1
    px, py = rd16(S['px'])/256, rd16(S['py'])/256; ang = rd16(S['pang'])
    grid = z.m[S['MAP']:S['MAP']+256]; keys = rd(S['keys'])
    objs = []
    for i in range(32):
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
    foes = [(math.hypot(o[1]-px, o[2]-py), o) for o in objs if o[0] <= 10 and o[3] & 0x80 and los(grid, px, py, o[1], o[2])]
    if foes and PACIFIST: return ''
    if foes and rd(S['ammo']):
        dist, o = min(foes)
        k, d = steer(o[1], o[2], walk=False)
        if abs(d) < 14: k += ' '
        if dist < 1.6: k += 'S'
        return k
    here = (int(px), int(py))
    want = []
    for o in objs:
        if o[0] == 11 and rd(S['hp']) >= 100: continue
        if o[0] == 12 and rd(S['ammo']) >= 99: continue
        if 11 <= o[0] <= 15: want.append((int(o[1]), int(o[2])))
    path = bfs(grid, here, keys, set(want)) if want else None
    if not path and 9 in grid and 7 in grid:
        path = bfs(grid, here, keys, {(i % 16, i//16) for i in range(256) if grid[i] == 7})
    if not path:
        bosses = [(int(o[1]), int(o[2])) for o in objs if 3 <= o[0] <= 5]
        if bosses: path = bfs(grid, here, keys, set(bosses))
    if not path:
        nxt = ITIN[itin+1] if area == ITIN[itin] else ITIN[itin]
        if not any(a == area and t == nxt for (a, c), (t, _, _) in EXITS.items()):
            prevs = {area: None}; q = deque([area])          # next hop through the area graph
            while q:
                a0 = q.popleft()
                for (a1, c), (t, _, _) in EXITS.items():
                    if a1 == a0 and t != 255 and t not in prevs: prevs[t] = a0; q.append(t)
            hop = nxt
            while prevs.get(hop) not in (area, None): hop = prevs[hop]
            nxt = hop
        cells = [c for (a, c), (t, _, _) in EXITS.items() if a == area and t == nxt]
        path = bfs(grid, here, keys, set(cells))
    if not path:
        return ''
    tx, ty = path[1] if len(path) > 1 else path[0]
    k = steer(tx+0.5, ty+0.5)[0]
    if stuck[1] == here and 'W' in k:
        stuck[0] += 1
    else:
        stuck[0] = 0; stuck[1] = here
    if stuck[0] > 40: k += 'Q' if (nframe//25) % 2 else 'E'
    return k

frames = []; shots = {}; ftimes = []; fstart = None; nframe = 0
watch = {S[n]: n for n in ('gloop', 'wf1', 'wf2', 'tt2', 'main', 'dead', 'changearea')}
titles = 0; done = False; deaths = 0; minhp = 100; wins = 0; pages = 0
log = []; area_frames = {}; lastarea = None; enter_frame = 0; mapshot = False
while not done:
    n = watch.get(z.pc)
    if n == 'tt2':
        titles += 1
        if titles == 2: shots['title'] = shot(z)
        press(' ' if titles > 3 else '')
        if wins: done = True
    elif n == 'wf1': press('')
    elif n == 'wf2':
        shots.setdefault('page%d' % pages, shot(z)); pages += 1
        press(' ')
    elif n == 'dead': deaths += 1; log.append('frame %d: died in %s' % (nframe, NAMES[rd(S['area'])]))
    elif n == 'main' and nframe: wins += 1
    elif n == 'gloop':
        if fstart is not None: ftimes.append((z.t-fstart, rd(S['area'])))
        fstart = z.t; nframe += 1
        area = rd(S['area'])
        if area != lastarea:
            log.append('frame %d: entered %s (keys %d, opals %d, hp %d, ammo %d)' %
                       (nframe, NAMES[area], rd(S['keys']), rd(S['opals']), rd(S['hp']), rd(S['ammo'])))
            lastarea = area; enter_frame = nframe
        area_frames[area] = area_frames.get(area, 0)+1
        if nframe - enter_frame == 6: shots.setdefault('area%d' % area, shot(z))
        minhp = min(minhp, rd(S['hp']))
        if nframe % 4 == 0 and len(frames) < 1500: frames.append(shot(z, 3))
        tz = rd(S['tz'])
        tgt = rd16(S['target'])
        if tgt and z.m[tgt] in (3, 4, 5) and tz > 30: shots.setdefault('boss%d' % z.m[tgt], shot(z))
        if tgt and z.m[tgt] in (2, 6, 7, 8, 9, 10) and tz > 22: shots.setdefault('foe%d' % z.m[tgt], shot(z))
        live = sum(1 for i in range(32) if z.m[S['PART']+i*6+5] > 0)
        if live > 8 and tz > 30 and len([k for k in shots if k.startswith('boom')]) < 8:
            shots['boom%d' % nframe] = shot(z)
        kills = getattr(z, 'kills', 0)
        if rd(S['hurtflash']): shots.setdefault('bitten', shot(z))
        k = bot(nframe)
        if area == 2 and z.m[S['aflags']+2] & 1 and not mapshot:
            k = 'M'; mapshot = nframe
        if mapshot and nframe == mapshot+1:
            shots['map'] = shot(z)
        press(k)
        if nframe >= LIMIT: done = True
    z.step()
    if z.pc == S['drawmap'] and 'mapcall' not in shots: shots['mapcall'] = None
print('\n'.join(log))
print('frames %d, deaths %d, lowest health %d, finished game: %s, opals %d of %d, keys left %d' %
      (nframe, deaths, minhp, bool(wins), rd(S['opals']), P['nopals'], rd(S['keys'])))
ft = sorted(t for t, a in ftimes)
if ft:
    print('frame time: median %d T (%.1f fps), 90th pct %.1f fps, worst %d T' %
          (ft[len(ft)//2], 3546900/ft[len(ft)//2], 3546900/ft[len(ft)*9//10], ft[-1]))
for a in sorted(area_frames):
    ts = sorted(t for t, aa in ftimes if aa == a)
    if ts: print('  %-16s %5d frames, median %.1f fps' % (NAMES[a], area_frames[a], 3546900/ts[len(ts)//2]))
if not wins:
    print('STATE area', NAMES[rd(S['area'])], 'pos %.2f %.2f' % (rd16(S['px'])/256, rd16(S['py'])/256),
          'hp', rd(S['hp']), 'ammo', rd(S['ammo']), 'keys', rd(S['keys']), 'itin', itin)
    g = z.m[S['MAP']:S['MAP']+256]
    for y in range(16): print(''.join(('*' if g[y*16+x] & 0x80 else '.#CDXWLSsG%'[g[y*16+x]]) for x in range(16)))
    for i in range(32):
        a = S['OBJ']+i*8
        if z.m[a]: print('  obj', z.m[a], '%.2f %.2f' % (rd16(a+1)/256, rd16(a+3)/256), 'hp', z.m[a+5], 'flags %02x' % z.m[a+6])
    shot(z).save('shot_stuck.png')
for k, im in shots.items():
    if im is not None: im.save('shot_%s.png' % k)
if frames: frames[0].save('play.gif', save_all=True, append_images=frames[1:], duration=200, loop=0)
print('saved', sorted(k for k in shots if shots[k] is not None))
