"""A showcase GIF: the title, robots beaming into the gallery, and the demo."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image
from run import boot, peek, BUILD

pp = boot()
S = pp.S
frames = []


def grab(n, every=4):
    for i in range(n // every):
        pp.run_frames(every)
        im = Image.fromarray(pp.screen_rgb())
        frames.append(im.resize((320, 240), Image.NEAREST).quantize(colors=16, method=Image.Quantize.MEDIANCUT))


pp.run_frames(40)
grab(240)                                       # the title
while peek(pp, 'att') != 2:
    pp.run_frames(4)
grab(520)                                       # the gallery
while peek(pp, 'demo') != 1:
    pp.run_frames(4)
pp.run_frames(130)
grab(480)                                       # the demo
out = BUILD / 'showcase.gif'
frames[0].save(out, save_all=True, append_images=frames[1:], duration=80, loop=0, optimize=True)
print(out, len(frames), 'frames', out.stat().st_size // 1024, 'KB')
