"""A showcase GIF: the title, then the demo game."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from PIL import Image
from run import boot, peek, BUILD
pp = boot(); S = pp.S
pp.run_frames(20); pp.keys = ['C']; pp.run_frames(4); pp.keys = []
frames = []
def grab(n, every=4):
    for i in range(n // every):
        pp.run_frames(every)
        im = Image.fromarray(pp.screen_rgb())
        frames.append(im.resize((320, 240), Image.LANCZOS).quantize(colors=16, method=Image.Quantize.MEDIANCUT))
pp.run_frames(60); grab(280)
pp.run_frames(1120 - 340 + 1200 + 130)
grab(700)
out = BUILD / 'showcase.gif'
frames[0].save(out, save_all=True, append_images=frames[1:], duration=80, loop=0, optimize=True)
print(out, len(frames), 'frames', out.stat().st_size // 1024, 'KB')
