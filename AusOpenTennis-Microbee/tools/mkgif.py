"""The showcase GIF: title rally, menu, the tour, then rallies on every court
and the trophy. 512 x 384 (rows x1.5), 10 frames a second."""
import run, sys
from PIL import Image
from shoot import press
from flow import boot_disk
from capgame import match
OUT = '/home/claude/aot/shots/pkg/showcase.gif'
STEP = 5                 # fields per GIF frame (10 fps)
frames = []


def grab(pp, secs, mono=False):
    for i in range(int(secs * 50 / STEP)):
        pp.run_frames(STEP)
        im = Image.fromarray(pp.screen_rgb(mono))
        frames.append(im.resize((512, 384), Image.NEAREST))


pp = boot_disk()
S = pp.S
pp.run_frames(80)
press(pp, 'C')
pp.run_pp = None
pp.run_until(S['title_screen'], 400)
pp.run_frames(60)
grab(pp, 4.0)                                   # the title and its rally
press(pp, 'SPACE'); pp.run_frames(40)
grab(pp, 1.5)                                   # the menu
press(pp, 'SPACE'); pp.run_until(S['bracket_screen'], 400); pp.run_frames(80)
grab(pp, 1.5)                                   # the Kooyong Classic bracket
press(pp, 'SPACE'); pp.run_frames(100)
grab(pp, 1.5)                                   # your opponent
for v, secs, kw in ((3, 5.0, {}), (0, 4.0, dict(fly=True)), (1, 3.0, {}), (2, 3.0, {}), (4, 2.5, {})):
    m = match(v, frames=300, **kw)
    grab(m, secs)
m = match(3, mono=True, frames=600)
grab(m, 2.5, mono=True)                         # the amber monitor
# the trophy
pp.poke(S['autoplay'], 1)
pp.poke(S['pl0'] + 14, 1)
for t in range(3000):
    pp.poke(S['pl0'] + 14, 1)
    if pp.run_until(S['trophy_screen'], 20):
        break
    if t % 5 == 0:
        press(pp, 'SPACE', 2)
pp.run_frames(80)
grab(pp, 3.0)
sample = Image.new('RGB', (512, 384 * 8))
for i, k in enumerate(range(0, len(frames), max(1, len(frames) // 8))):
    if i < 8:
        sample.paste(frames[k], (0, 384 * i))
pal = sample.quantize(colors=48, method=Image.MEDIANCUT)
fr = [f.quantize(palette=pal, dither=Image.NONE) for f in frames]
fr[0].save(OUT, save_all=True, append_images=fr[1:], duration=STEP * 20, loop=0, optimize=True)
import os
print(len(frames), 'frames', os.path.getsize(OUT) // 1024, 'KB')
