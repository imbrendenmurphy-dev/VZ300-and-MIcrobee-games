#!/usr/bin/env python3
"""Release package media for HAMBURGER SAM II (run after src/build.sh):
  screenshots/gameplay/game_NN_*.png, screenshots/info/info_NN_*.png, showcase/showcase.gif
  python3 tools/release_media.py"""
import os, subprocess, glob
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'release', 'HAMSAM2.VZ')
TMP = os.path.join(ROOT, 'build', 'release_tmp')
GAME = os.path.join(ROOT, 'screenshots', 'gameplay')
INFO = os.path.join(ROOT, 'screenshots', 'info')
SHOW = os.path.join(ROOT, 'showcase')
for d in (TMP, GAME, INFO, SHOW):
    os.makedirs(d, exist_ok=True)
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'hamsam2.sym'))}


def run(name, frames, keys="", shots=(), every=0, pokes=()):
    for f in glob.glob(os.path.join(TMP, name + '_*.ppm')):
        os.remove(f)
    kf = os.path.join(TMP, name + '.keys')
    open(kf, 'w').write(keys)
    a = [EMU, VZ, '-bennvenn', '-frames', str(frames), '-keys', kf, '-out', os.path.join(TMP, name)]
    if shots:
        a += ['-shots', ','.join(map(str, shots))]
    if every:
        a += ['-every', str(every)]
    for (f, s, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, sym[s] if isinstance(s, str) else s, v)]
    subprocess.run(a, capture_output=True)


def frame(name, n, size=(544, 408)):
    # 4:3 like a real screen: the 256x192 picture plus a little border
    im = Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((24, 18, 296, 222))
    return im.resize(size, Image.NEAREST)


def save(name, n, folder, out):
    frame(name, n).save(os.path.join(folder, out + '.png'))


START = "100 104 SPACE\n160 164 SPACE\n"
AUTO = [(5, 'autoplay', 1), (5, 'godmode', 1)]
KITCHENS = ['sams_diner', 'cheese_factory', 'pickle_pantry', 'night_grill',
            'salad_bar', 'fry_up_factory', 'midnight_feast', 'burger_palace']

# ---- info screens (attract cycle) ----
A = [('info_01_title', 400), ('info_03_how_to_cook', 1000), ('info_04_controls', 1300),
     ('info_05_meet_the_menu', 1650), ('info_06_goodies', 1950), ('info_08_top_ten', 4100)]
run('att', 4200, shots=[f for _, f in A], every=3)
for n, f in A:
    save('att', f, INFO, n)
run('menu', 300, keys="100 103 SPACE\n", shots=(290,))
save('menu', 290, INFO, 'info_02_main_menu')

# ---- every kitchen mid-play (autopilot), plus the kitchen card ----
for k in range(8):
    nm = 'k%d' % k
    run(nm, 1300, keys=START, pokes=AUTO + [(170, 'kitchen', k)], every=3, shots=(240, 1251))
    if k == 0:
        save(nm, 240, INFO, 'info_07_kitchen_card')
    save(nm, 1251, GAME, 'game_%02d_%s' % (k + 1, KITCHENS[k]))
# classic 1984 (C on the title, menu line 3)
run('cl', 900, keys="60 63 C\n150 153 SPACE\n200 203 A\n215 218 A\n240 243 SPACE\n", shots=(870,))
save('cl', 870, GAME, 'game_09_classic_1984')
# Order Up! and the ending (kitchen 8 cleared)
run('end', 4500, keys=START, pokes=AUTO + [(170, 'kitchen', 7)], every=3, shots=(2100, 2790, 3100, 3300))
save('end', 2790, GAME, 'game_10_order_up')
save('end', 2100, GAME, 'game_12_kitchen_cleared')
save('end', 3100, INFO, 'info_09_order_tally')
save('end', 3300, INFO, 'info_10_ending')
# demo
save('att', 3000, GAME, 'game_11_demo')
# game over + name entry
run('go', 1300, keys="100 104 SPACE\n160 164 SPACE\n1000 1003 Q\n1010 1013 Q\n1020 1023 SPACE\n1080 1083 RETURN\n",
    pokes=[(300, 'lives', 1), (400, sym['score'] + 1, 0x50)], shots=(850, 1075))
save('go', 850, INFO, 'info_11_game_over')
save('go', 1075, INFO, 'info_12_name_entry')

# ---- showcase GIF: title -> info backplane -> four kitchens -> Order Up! -> ending ----
SZ = (408, 306)
clips = [('att', 60, 420), ('att', 960, 1110),          # title chase, How to Cook specks
         ('k0', 450, 750), ('k3', 450, 690), ('k5', 450, 690), ('k7', 450, 750),
         ('end', 2430, 2600), ('end', 3270, 3420)]
frames = []
black = Image.new('RGB', SZ, (0, 0, 0))
for name, a, b in clips:
    for n in range(a - a % 3, b, 3):
        p = os.path.join(TMP, '%s_%05d.ppm' % (name, n))
        if os.path.exists(p):
            frames.append(frame(name, n, SZ))
    frames += [black, black]
frames = [f.quantize(colors=16, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
frames[0].save(os.path.join(SHOW, 'showcase.gif'), save_all=True, append_images=frames[1:],
               duration=60, loop=0, optimize=True)
print('showcase frames:', len(frames))
