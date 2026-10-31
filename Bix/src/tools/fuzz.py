# random-play fuzzer: drive the real game with random inputs, flag impossible states
import random, subprocess, sys, os
EMU = os.path.join(os.path.dirname(__file__), 'vzemu')
VZ = sys.argv[1]; seeds = range(int(sys.argv[2]), int(sys.argv[3])); fields = int(sys.argv[4]) if len(sys.argv) > 4 else 12000
MOVES = ['R', 'R', 'R', 'RJ', 'RJ', 'L', 'LJ', 'J', 'D', 'DR', 'DL', 'U', '-', 'RU', 'D']
bad = 0
for seed in seeds:
    r = random.Random(seed)
    ks = ['0 -', '115 J', '121 -', '145 J', '151 -']
    f = 240
    while f < fields:
        ks.append(f'{f} {r.choice(MOVES)}'); f += r.randint(4, 40)
        if r.random() < 0.02: ks.append(f'{f} J'); f += 6; ks.append(f'{f} -'); f += 6   # menus / continues
    open('/tmp/fz.keys', 'w').write('\n'.join(ks) + '\n')
    subprocess.run([EMU, VZ, str(fields), '/tmp/fzout', '/tmp/fz.keys'], env=dict(os.environ, TRACE='/tmp/fz.trace'),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    prev = None; issues = []; offrun = 0
    for line in open('/tmp/fz.trace'):
        fld, px, py, st, cx, cy, lives, lev, hp, keys = map(int, line.split())
        if fld < 300: continue
        if st in (0, 1) and px < 4000:
            sx = px - cx
            if not (-40 <= sx <= 168):
                offrun += 1
                if offrun == 3: issues.append((fld, 'bix off-screen x', px, cx, st, lev))
            else: offrun = 0
        if prev and prev[3] in (0, 1) and st in (0, 1) and prev[7] == lev and abs(px - prev[1]) > 120 and abs(px-prev[1]) < 4000:
            issues.append((fld, 'teleport', prev[1], px, st, lev))
        prev = (fld, px, py, st, cx, cy, lives, lev)
    if issues:
        bad += 1
        print('seed', seed, len(issues), issues[:6])
print('done, bad seeds:', bad)
