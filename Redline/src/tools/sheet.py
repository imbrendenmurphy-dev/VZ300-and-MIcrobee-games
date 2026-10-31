"""run the game with a pre-script, grab N screens every STEP fields, make a contact sheet
usage: sheet.py out.png N STEP [prescript] [cols]"""
import sys, subprocess, os
from PIL import Image
out, n, step = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
pre = open(sys.argv[4]).read() if len(sys.argv) > 4 else ''
cols = int(sys.argv[5]) if len(sys.argv) > 5 else 4
os.makedirs('out/g', exist_ok=True)
scr = 'mapper 1\nsd release\nvz release/REDLINE.VZ\n' + pre
for i in range(n): scr += 'frames %d\nscreen out/g/%03d.ppm\n' % (step, i)
open('out/s.scr', 'w').write(scr)
subprocess.run(['emu/vzemu', 'out/s.scr'], stderr=subprocess.DEVNULL)
fr = [Image.open('out/g/%03d.ppm' % i) for i in range(n)]
W, H = fr[0].size
rows = (n + cols - 1) // cols
s = Image.new('RGB', (W * cols + (cols - 1) * 4, H * rows + (rows - 1) * 4), (40, 40, 40))
for k, f in enumerate(fr): s.paste(f, ((k % cols) * (W + 4), (k // cols) * (H + 4)))
s.save(out)
