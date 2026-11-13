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
BG, FG, HI = (24, 16, 40), (255, 255, 255), (255, 129, 0)    # dark caption bar, buff, orange


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


SEG = [  # (capture, first, last, caption, sub-caption); capture '@file.ppm' = still held for `last` frames
    ('title', 120, 480, 'PENGUIN 2 - ICE AGE RAMPAGE', 'DICK SMITH VZ300  BENNVENN SD + 128K'),
    ('@att_how.ppm', 0, 30, 'FULL ATTRACT SEQUENCE', 'HOW TO PLAY'),
    ('@att_mon.ppm', 0, 30, 'FULL ATTRACT SEQUENCE', 'MEET THE MONSTERS'),
    ('@att_good.ppm', 0, 30, 'FULL ATTRACT SEQUENCE', 'ICE GOODIES'),
    ('w1', 380, 800, 'PUSH ICE  CRUSH MONSTERS', 'THE ORIGINAL GAME, EVOLVED'),
    ('w2', 450, 740, 'CHOMPERS MUNCH THROUGH ICE', 'SMASH EGGS BEFORE THEY HATCH'),
    ('w3', 500, 800, 'ROCKS, CRYSTALS AND FLITTERS', '4 WORLDS - 16 NEW STAGES'),
    ('w4', 500, 770, 'WISPS FLOAT THROUGH ICE', 'WALL SHAKE, ITEMS, COMBOS'),
    ('soak', 4280, 4420, 'STAGE CLEAR - TIME BONUS', 'SNOW-FREE 50 FPS SPRITES'),
    ('soak', 4730, 5010, 'GOLD RUSH BONUS ROUNDS', 'IN THE ORIGINAL GREEN PALETTE'),
    ('mid', 10400, 10560, 'DANCE INTERMISSION', 'TWO-VOICE BEEPER MUSIC'),
    ('end', 20420, 20700, 'AN ENDING... THEN LAP 2', 'VIBED BY BPM 2026'),
    ('@hs_bpm.ppm', 0, 30, 'HIGH SCORES WITH INITIALS', 'HALL OF FAME'),
    ('hof', 2260, 2437, 'HALL OF FAME', 'VIBED BY BPM 2026'),
]
os.makedirs(WORK, exist_ok=True)
for f in os.listdir(WORK):
    os.remove(os.path.join(WORK, f))
n = 0
for (cap, a, b, c1, c2) in SEG:
    base = card(c1, c2)
    seq = [os.path.join(CAP, cap[1:])] * b if cap.startswith('@') else \
        [os.path.join(CAP, '%s_%05d.ppm' % (cap, fr)) for fr in range(a, b + 1, 3)]
    for p in seq:
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
