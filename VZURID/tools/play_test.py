#!/usr/bin/env python3
"""Longer 'realistic' gameplay test: a simple bot flies, hunts enemies/turrets and fires.
usage: play_test.py [frames] [seed]"""
import os, sys, time, random
sys.path.insert(0, os.path.dirname(__file__))
from vztest import VZ, FIELD
root = os.path.join(os.path.dirname(__file__), '..')
build = os.path.join(root, 'build')
shots_dir = os.path.join(build, 'play'); os.makedirs(shots_dir, exist_ok=True)
N = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
seed = int(sys.argv[2]) if len(sys.argv) > 2 else 1
rnd = random.Random(seed)
vz = VZ(os.path.join(build, 'vzurid.bin'), os.path.join(build, 'vzurid.sym'))
S = vz.syms
mem = lambda: vz.cpu.mem
def b(name, off=0): return mem()[S[name] + off]
dirn = {'v': 1, 'until': 0}
log = []
def set_keys(want):
    for k in ('M', ',', '.', 'Q', 'A'):
        (vz.keys.add if k in want else vz.keys.discard)(k)
dbg = {}
def ctrl(n, vz):
    m = mem()
    dbg[n] = (m[S['sprCount']], m[S['ringRc']], m[S['ringLc']], m[S['jobSt']], m[S['curSlot']])
    # direction changes every ~400 frames (random)
    if n >= dirn['until']:
        dirn['v'] = rnd.choice([1, 1, -1])
        dirn['until'] = n + rnd.randint(250, 450)
    want = set([',' if dirn['v'] > 0 else 'M'])
    ship_y = m[S['shipY']]
    # steer toward the nearest live mobile enemy / turret on screen
    best = None
    base = S['ENM']
    for i in range(6):
        st = m[base + i*10]
        if st != 1: continue
        sx = m[base+i*10+6] | m[base+i*10+7] << 8
        if sx >= 0x8000: sx -= 65536
        if -10 <= sx < 128:
            y = m[base+i*10+3]
            d = abs(sx - 40)
            if best is None or d < best[0]: best = (d, y)
    if best:
        if best[1] > ship_y + 3: want.add('A')
        elif best[1] < ship_y: want.add('Q')
    # tap fire when anything alive is on screen
    if n % 4 < 2: want.add('.')
    if m[S['pstate']] == 2: want = {'.'} if n % 8 < 4 else set()
    set_keys(want)
shots = set(range(500, N, 500))
PROF = os.environ.get('PROF')
if PROF:
    import bisect, collections
    A, B = [int(x) for x in PROF.split(',')]
    glob = sorted((a, n) for n, a in S.items() if '.' not in n and 0x8000 <= a < 0xB400)
    addrs = [a for a, n in glob]; names = [n for a, n in glob]
    prof = collections.Counter(); cpu = vz.cpu; orig = cpu.step; on = {'v': False}
    def step():
        pc = cpu.pc
        t = orig()
        if on['v']:
            i = bisect.bisect_right(addrs, pc) - 1
            prof[names[i]] += t
        return t
    cpu.step = step
    fin = vz.finish_frame
    def finish():
        n = vz.cur['n']
        if n + 1 == A: on['v'] = True
        if n + 1 == B: on['v'] = False
        fin()
    vz.finish_frame = finish
t0 = time.time()
frames = vz.run(N, {}, shots, shots_dir, controller=ctrl)
print('emulated %d frames in %.1fs' % (len(frames), time.time() - t0))
work = [f['work'] for f in frames if 'work' in f]
work.sort()
def pct(p): return work[int(len(work) * p) - 1]
print('work T/frame: min %d mean %d p95 %d p99 %d max %d (field %d)' % (work[0], sum(work)/len(work), pct(.95), pct(.99), work[-1], FIELD))
over = [f['n'] for f in frames if f.get('work', 0) > FIELD - 400]
print('frames over budget: %d of %d (%.2f%%)' % (len(over), len(frames), 100.0*len(over)/len(frames)), over[:15])
print('frames with rows drawn after the beam:', sum(1 for f in frames if f['late_rows']))
late_conf = [c for c in vz.beam_conflicts if c[0] > 0]
print('VRAM writes while beam inside the row (after frame 0):', len(late_conf), late_conf[:5])
v = lambda n, s=1: vz.var(n, s)
print('end: score %d lives %d energy %d wave %d pstate %d posX %d' % (v('score',2), v('lives'), v('energy'), v('waveNo'), v('pstate'), v('posX',2)))
print('game late counter', v('lateCnt', 2), 'min slack', v('minSlack', 2))
if PROF:
    tot = sum(v for k, v in prof.items() if k != 'frame_wait')
    print('profile frames %d..%d (excluding frame_wait): %.0f T/frame' % (A, B, tot / (B - A)))
    for k, v in prof.most_common(20):
        if k != 'frame_wait': print('  %-16s %7.0f T/frame' % (k, v / (B - A)))
if os.environ.get('DBG'):
    a, b2 = [int(x) for x in os.environ['DBG'].split(',')]
    for f in frames:
        if a <= f['n'] < b2:
            print(f['n'], f.get('work'), 'spr,Rc,Lc,job,slot=', dbg.get(f['n']))
