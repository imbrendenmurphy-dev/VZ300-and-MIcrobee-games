"""Run a script that saves screens every N fields and assemble a GIF.
usage: gif.py VZ out.gif nframes step [warmup] [extra script lines file]"""
import sys, subprocess, os
from PIL import Image
vz, out, n, step = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
warm = int(sys.argv[5]) if len(sys.argv) > 5 else 10
pre = open(sys.argv[6]).read() if len(sys.argv) > 6 else ''
os.makedirs('out/g', exist_ok=True)
scr = 'mapper 1\nvz %s\n%sframes %d\n' % (vz, pre, warm)
for i in range(n): scr += 'frames %d\nscreen out/g/%03d.ppm\n' % (step, i)
open('out/g.scr', 'w').write(scr)
subprocess.run(['emu/vzemu', 'out/g.scr'], stderr=subprocess.DEVNULL)
fr = [Image.open('out/g/%03d.ppm' % i).convert('P', palette=Image.ADAPTIVE) for i in range(n)]
fr[0].save(out, save_all=True, append_images=fr[1:], duration=step * 20, loop=0)
