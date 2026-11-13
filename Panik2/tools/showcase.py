#!/usr/bin/env python3
"""Build the captioned showcase GIF from emulator frame captures.
usage: showcase.py capture_dir work_dir out.gif"""
import os, sys, subprocess
from PIL import Image, ImageDraw
CAP, WORK, OUT = sys.argv[1:4]
HERE = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(HERE, '..', 'src', 'gen.py')).read()
ns = {}
exec(src[src.index("FONT = {"):src.index("FONT['['] =")], ns)
FONT = ns['FONT']
BG, FG, HI = (20, 6, 70), (255, 255, 0), (255, 255, 255)  # deep-space blue bar, VZ yellow, white


def text(dr, s, x, y, col, k=3):
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for j in range(5):
            for i in range(3):
                if g[j][i] == '#':
                    dr.rectangle([x + i * k, y + j * k, x + i * k + k - 1, y + j * k + k - 1], fill=col)
        x += 4 * k


def card(cap1, cap2):
    im = Image.new('RGB', (512, 432), BG)
    dr = ImageDraw.Draw(im)
    for s, y, c in ((cap1, 393, HI), (cap2, 414, FG)):
        w = len(s) * 12 - 3
        text(dr, s, (512 - w) // 2, y, c)
    return im


SEG = [  # (capture, first, last, caption, sub-caption)
    ('title', 150, 450, 'PANIK 2 - DIG DEEPER!', 'DICK SMITH VZ300  BENNVENN SD + 128K'),
    ('w1', 450, 860, 'DIG, TRAP, BASH, DROP!', 'THE ORIGINAL GAME, EVOLVED'),
    ('w1', 930, 1010, 'DROP ONE ON ANOTHER: 1000', 'GRUBS, BRUTES AND KINGS'),
    ('w2', 600, 800, 'MOON BASE', '4 WORLDS - 16 NEW STAGES'),
    ('w3', 630, 900, 'MARS MINES', 'STEEL GIRDERS CAN\'T BE DUG'),
    ('w4', 570, 800, 'THE MOTHERSHIP', 'PICK-UPS, ANGRY ALIENS, COMBOS'),
    ('w1', 1990, 2180, 'STAGE CLEAR - OXYGEN BONUS', 'SNOW-FREE 50 FPS SPRITES'),
    ('gem', 330, 660, 'GEM DIG BONUS ROUNDS', 'BEAT THE OXYGEN CLOCK'),
    ('int', 600, 880, 'COFFEE BREAK!', 'TWO-VOICE BEEPER MUSIC'),
    ('end', 600, 780, 'MISSION DONE... THEN LAP 2', 'VIBED BY BPM 2026'),
]
os.makedirs(WORK, exist_ok=True)
for f in os.listdir(WORK):
    os.remove(os.path.join(WORK, f))
n = 0
for (cap, a, b, c1, c2) in SEG:
    base = card(c1, c2)
    for fr in range(a, b + 1, 3):
        p = os.path.join(CAP, '%s_%05d.ppm' % (cap, fr))
        if not os.path.exists(p):
            continue
        im = base.copy()
        im.paste(Image.open(p).crop((32, 24, 288, 216)).resize((512, 384), Image.NEAREST), (0, 0))
        im.save(os.path.join(WORK, 'f%05d.png' % n))
        n += 1
print("frames", n)
pal = os.path.join(WORK, 'pal.png')
subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', '50/3', '-i', os.path.join(WORK, 'f%05d.png'),
                '-vf', 'palettegen=max_colors=16:reserve_transparent=0', pal], check=True)
subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-framerate', '50/3', '-i', os.path.join(WORK, 'f%05d.png'),
                '-i', pal, '-lavfi', 'paletteuse=dither=none:diff_mode=rectangle', '-loop', '0', OUT], check=True)
print(OUT, os.path.getsize(OUT))
