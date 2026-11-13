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
BG, FG, HI = (0, 0, 40), (255, 255, 0), (255, 255, 255)  # deep-space blue bar, VZ yellow, white


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


SEG = [  # (capture, first, last, caption, sub-caption[, step])
    ('title', 30, 330, 'STAR BLASTER II', 'DICK SMITH VZ300  BENNVENN SD + 128K'),
    ('s1', 120, 420, 'THE ENERMY RETURNS', 'WARP INTO 8 SECTORS'),
    ('s1', 660, 900, 'SCAN 360 DEGREES - WATCH THE RADAR', 'TWIN LASERS, COMBO CHAINS'),
    ('s2', 960, 1200, 'THE ROCK BELT', 'SCALED SPRITES, SNOW-FREE'),
    ('s3', 1290, 1500, 'THE MINEFIELD', 'THE BEZEL WARNS WHERE THREATS COME FROM'),
    ('s4', 1080, 1260, 'THE INVASION', 'STOP THE TROOP CARRIERS'),
    ('s5', 840, 1020, 'NEBULA X', 'CLOAKED FIGHTERS'),
    ('s6', 1110, 1320, 'ACE SQUADRON', 'SHOOT DOWN THEIR PLASMA'),
    ('s8', 690, 960, 'THE ENERMY MOTHERSHIP', 'KNOCK OUT THE TURRETS...'),
    ('s8', 1710, 1890, '...THEN THE CORE', 'BOSS THEME ON THE BEEPER'),
    ('clear', 960, 1560, 'SECTOR CLEAR - REFUEL - WARP OUT', 'TWO-VOICE BEEPER MUSIC'),
    ('s8', 2550, 2700, 'MISSION COMPLETE... THEN LAP 2', 'VIBED BY BPM 2026'),
    ('attract', 2000, 2060, 'MEET THE FLEET', 'FREE, WITH FULL SOURCE', 10),
]
os.makedirs(WORK, exist_ok=True)
for f in os.listdir(WORK):
    os.remove(os.path.join(WORK, f))
n = 0
for sg in SEG:
    cap, a, b, c1, c2 = sg[:5]
    base = card(c1, c2)
    st = sg[5] if len(sg) > 5 else 3
    reps = 1 if st == 3 else 6  # hold static pages (captured every 10th frame)
    for fr in [x for x in range(a, b + 1, st) for _ in range(reps)]:
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
