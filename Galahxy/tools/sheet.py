import sys, glob
from PIL import Image
fs = sorted(sys.argv[2:]) if len(sys.argv) > 2 else sorted(glob.glob('build/shots/*.ppm'))
ims = [Image.open(f) for f in fs]
cols = 4; W, H = 256, 192
rows = (len(ims) + cols - 1) // cols
sh = Image.new('RGB', (cols * (W + 4), rows * (H + 4)), (0, 0, 0))
for i, im in enumerate(ims): sh.paste(im, ((i % cols) * (W + 4), (i // cols) * (H + 4)))
sh.save(sys.argv[1])
