#!/usr/bin/env python3
"""
run.py - run a .COM in beemu, collect frames -> PNG/GIF, and summarise
profile markers (P_* labels) as average T-states per section.

usage: run.py prog.com sym frames keys outdir [--every N] [--gif] [--mono]
"""
import sys, os, subprocess, glob, argparse, collections
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument('com'); ap.add_argument('sym'); ap.add_argument('frames', type=int)
ap.add_argument('keys'); ap.add_argument('outdir')
ap.add_argument('--every', type=int, default=1)
ap.add_argument('--first', type=int, default=0)
ap.add_argument('--gif', action='store_true')
ap.add_argument('--mono', action='store_true')
ap.add_argument('--scale', type=int, default=1)
ap.add_argument('--wav')
ap.add_argument('--poke', action='append', default=[])
ap.add_argument('--vwait', default='0')
a = ap.parse_args()

here = os.path.dirname(os.path.abspath(__file__))
emu = os.path.join(here, '..', 'build', 'beemu')
os.makedirs(a.outdir, exist_ok=True)
for f in glob.glob(os.path.join(a.outdir, 'f*.ppm')): os.remove(f)
prof = os.path.join(a.outdir, 'prof.csv')
cmd = [emu, a.com, '-sym', a.sym, '-frames', str(a.frames), '-dump', a.outdir,
       '-every', str(a.every), '-first', str(a.first), '-keys', a.keys, '-prof', prof]
if a.mono: cmd.append('-mono')
for p_ in a.poke: cmd += ['-poke', p_]
cmd += ['-vwait', a.vwait]
if a.wav: cmd += ['-wav', a.wav]
r = subprocess.run(cmd, capture_output=True, text=True)
sys.stderr.write(r.stderr)

frames = sorted(glob.glob(os.path.join(a.outdir, 'f*.ppm')))
imgs = []
for f in frames:
    im = Image.open(f)
    # display aspect: 512x256 screen pixels; show at 2:1 vertical scale so pixels look as on a 4:3 tube
    w, h = im.size
    im = im.resize((w * a.scale, h * 2 * a.scale), Image.NEAREST)
    png = f[:-4] + '.png'
    im.save(png)
    os.remove(f)
    imgs.append(im)
if a.gif and imgs:
    imgs[0].save(os.path.join(a.outdir, 'anim.gif'), save_all=True, append_images=imgs[1:],
                 duration=int(1000 / 50 * a.every), loop=0)

# profile: sequence of (frame, T, name). Section time = T(next marker) - T(this)
rows = [l.strip().split(',') for l in open(prof) if l.strip()]
rows = [(int(f), int(t), n) for f, t, n in rows]
sec = collections.defaultdict(list)
for (f0, t0, n0), (f1, t1, n1) in zip(rows, rows[1:]):
    sec[n0].append(t1 - t0)
frames_t = [t for f, t, n in rows if n == 'P_frame']
loops = [b - a for a, b in zip(frames_t, frames_t[1:])]
print('section             calls     avg T     min T     max T')
for n, v in sec.items():
    print('%-16s %8d %9d %9d %9d' % (n, len(v), sum(v) // len(v), min(v), max(v)))
if loops:
    skip = loops[5:] if len(loops) > 10 else loops
    avg = sum(skip) / len(skip)
    print('frame loop: avg %.0f T  (%.2f fps at 3.375 MHz, %.2f fields/frame)' %
          (avg, 3375000 / avg, avg / 67608))
