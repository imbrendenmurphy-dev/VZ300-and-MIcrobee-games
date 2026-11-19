#!/usr/bin/env python3
"""run.py - run RAY.COM in the test emulator (tools/beemu.c), save frames
as PNG (and optionally a GIF) at 4:3, and report the frame rate.

usage: run.py frames keysfile outdir [--every N] [--first N] [--gif] [--mono-crt] [--vwait N] [--poke a,v]
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
ap.add_argument('--vwait', default='4')
ap.add_argument('--poke', action='append', default=[])
ap.add_argument('--peek')
a = ap.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
B = os.path.join(here, '..', 'build')
os.makedirs(a.outdir, exist_ok=True)
for f in glob.glob(os.path.join(a.outdir, 'f*.p?m')) + glob.glob(os.path.join(a.outdir, 'f*.png')):
    os.remove(f)
prof = os.path.join(a.outdir, 'prof.csv')
cmd = [os.path.join(B, 'beemu'), os.path.join(B, 'RAY.COM'), '-sym', os.path.join(B, 'ray.sym'),
       '-frames', str(a.frames), '-dump', a.outdir, '-every', str(a.every), '-first', str(a.first),
       '-keys', a.keys, '-prof', prof, '-vwait', a.vwait]
if a.mono_crt: cmd.append('-mono')
for p_ in a.poke: cmd += ['-poke', p_]
if a.peek: cmd += ['-peek', a.peek]
r = subprocess.run(cmd, capture_output=True, text=True)
sys.stderr.write(r.stderr); sys.stdout.write(r.stdout)

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
sec = {}
for (f0, t0, n0), (f1, t1, n1) in zip(rows, rows[1:]):
    sec.setdefault(n0, []).append(int(t1) - int(t0))
for n, v in sec.items():
    v = v[2:] if len(v) > 4 else v
    print('  %-10s avg %7d T  min %7d  max %7d' % (n[2:], sum(v) // len(v), min(v), max(v)))
ft = [int(t) for f, t, n in rows if n == 'P_frame']
loops = [y - x for x, y in zip(ft, ft[1:])]
if len(loops) > 4:
    loops = loops[2:]
    avg = sum(loops) / len(loops)
    print('%d frames drawn: avg %.0f T = %.2f fields/frame = %.1f fps  (min %.1f, max %.1f fps)' %
          (len(loops), avg, avg / 67392, 3375000 / avg, 3375000 / max(loops), 3375000 / min(loops)))
