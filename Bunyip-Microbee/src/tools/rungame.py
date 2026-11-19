#!/usr/bin/env python3
"""rungame.py - run BUNYIP in the test emulator as the loader leaves the
machine (program at 8000h, data in RAM blocks); PNG frames, frame rate.

usage: rungame.py frames keysfile outdir [--every N] [--first N] [--gif] [--mono-crt] [--poke a,v]
keys file lines: "startframe endframe keycode"
"""
import sys, os, subprocess, glob, argparse
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument('frames', type=int); ap.add_argument('keys'); ap.add_argument('outdir')
ap.add_argument('--every', type=int, default=1)
ap.add_argument('--first', type=int, default=0)
ap.add_argument('--gif', action='store_true')
ap.add_argument('--mono-crt', action='store_true')
ap.add_argument('--poke', action='append', default=[])
ap.add_argument('--peek')
ap.add_argument('--hist', action='store_true')
ap.add_argument('--wav')
ap.add_argument('--at', help='zone,x,y,angle: start there (skips the screens)')
a = ap.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(here, '..', 'build')
os.makedirs(a.outdir, exist_ok=True)
for f in glob.glob(os.path.join(a.outdir, 'f*.p?m')) + glob.glob(os.path.join(a.outdir, 'f*.png')):
    os.remove(f)
prof = os.path.join(a.outdir, 'prof.csv')
cmd = [os.path.join(B, 'beemu'), '-up', os.path.join(B, 'BN.BIN'), '-sym', os.path.join(B, 'main.sym'),
       '-blk', '1:' + os.path.join(B, 'TABLES.BIN'), '-blk', '2:' + os.path.join(B, 'ZONES.BIN'),
       '-blk', '3:' + os.path.join(B, 'ART.BIN'), '-blk', '4:' + os.path.join(B, 'PCG.BIN'),
       '-frames', str(a.frames), '-dump', a.outdir, '-every', str(a.every), '-first', str(a.first),
       '-keys', a.keys, '-prof', prof, '-vwait', '4']
if a.mono_crt: cmd.append('-mono')
if a.hist: cmd.append('-hist')
if a.wav: cmd += ['-wav', a.wav]
if a.at:
    S = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(B, 'main.sym'))}
    z, x, y, ang = [int(v, 0) for v in a.at.split(',')]
    for n, v in (('dbg_on', 1), ('dbg_zone', z - 1), ('dbg_x', x), ('dbg_y', y), ('dbg_a', ang & 255)):
        cmd += ['-poke', '%d,%d' % (S[n], v)]
    cmd += ['-poke', '%d,%d' % (S['dbg_a'] + 1, ang >> 8)]
for p_ in a.poke: cmd += ['-poke', p_]
if a.peek: cmd += ['-peek', a.peek]
r = subprocess.run(cmd, capture_output=True, text=True)
sys.stderr.write(r.stderr[-2000:]); sys.stdout.write(r.stdout[-3000:])

imgs = []
for f in sorted(glob.glob(os.path.join(a.outdir, 'f*.ppm'))):
    im = Image.open(f)
    im = im.resize((640, im.height * 3 // 2), Image.NEAREST)      # a 40-column dot is 1.33 lines wide
    im.save(f[:-4] + '.png'); os.remove(f); imgs.append(im)
if a.gif and imgs:
    imgs[0].save(os.path.join(a.outdir, 'anim.gif'), save_all=True, append_images=imgs[1:],
                 duration=int(1000 / 50 * a.every), loop=0)

rows = [l.strip().split(',') for l in open(prof) if l.strip()]
rows = [r for r in rows if r[2] != 'P_vb']
ft = [int(t) for f, t, n in rows if n == 'P_render']
loops = [y - x for x, y in zip(ft, ft[1:])]
if len(loops) > 4:
    loops = loops[2:]
    avg = sum(loops) / len(loops)
    print('%d frames drawn: avg %.0f T = %.2f fields/frame = %.1f fps  (min %.1f, max %.1f fps)' %
          (len(loops), avg, avg / 67392, 3375000 / avg, 3375000 / max(loops), 3375000 / min(loops)))
