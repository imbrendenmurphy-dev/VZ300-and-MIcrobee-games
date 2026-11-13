#!/usr/bin/env python3
"""Write the separate screenshots, contact sheet, title and gameplay GIFs
from a showcase_capture.py capture directory.
usage: screens.py capture_dir"""
import os, sys
from PIL import Image
CAP = sys.argv[1]
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'screenshots')
os.makedirs(OUT, exist_ok=True)
SHOTS = [  # (name, capture, frame)
    ('01_title', 'att', 450), ('02_how_to_play', 'att', 1170), ('03_aliens', 'att', 1440),
    ('04_pickups', 'att', 1980), ('05_hall_of_fame', 'att', 2520), ('06_stage_intro', 'w1', 210),
    ('07_world1_space_station', 'w1', 990), ('08_world2_moon_base', 'w2', 1170),
    ('09_world3_mars_mines', 'w3', 870), ('10_world4_mothership', 'w4', 1170),
    ('11_stage_clear', 'w1', 2160), ('12_gem_dig', 'gem', 630), ('13_coffee_break', 'int', 810),
    ('14_ending', 'end', 690), ('15_demo', 'att', 2250),
]


def frame(cap, n, scale=2):
    im = Image.open(os.path.join(CAP, '%s_%05d.ppm' % (cap, n))).crop((32, 24, 288, 216))
    return im.resize((256 * scale, 192 * scale), Image.NEAREST)


ims = []
for name, cap, n in SHOTS:
    im = frame(cap, n)
    im.save(os.path.join(OUT, 'PANIK2_%s.png' % name))
    ims.append(im.resize((256, 192), Image.NEAREST))
cols = 4
sheet = Image.new('RGB', (cols * 256 + (cols - 1) * 4, 4 * 192 + 12), (24, 24, 24))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * 260, (i // cols) * 196))
sheet.save(os.path.join(OUT, 'PANIK2_screens.png'))


def gif(cap, a, b, step, out):
    fr = [frame(cap, n).resize((384, 288), Image.NEAREST) for n in range(a, b, step)
          if os.path.exists(os.path.join(CAP, '%s_%05d.ppm' % (cap, n)))]
    fr[0].save(os.path.join(OUT, out), save_all=True, append_images=fr[1:], duration=60, loop=0, optimize=True)


gif('title', 60, 1000, 3, 'PANIK2_title.gif')
gif('w1', 420, 1260, 3, 'PANIK2_gameplay.gif')
print('done')
