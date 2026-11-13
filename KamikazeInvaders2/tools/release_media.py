#!/usr/bin/env python3
"""Release package media for KAMIKAZE INVADERS 2 (run after src/build.sh):
  screenshots/gameplay/game_NN_*.png, screenshots/info/info_NN_*.png, showcase/showcase.gif
  python3 tools/release_media.py            (needs tools/vzemu/vzemu built, Pillow)"""
import os, re, subprocess, glob, random
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'release', 'KAMI2.VZ')
TMP = os.path.join(ROOT, 'build', 'release_tmp')
GAME = os.path.join(ROOT, 'screenshots', 'gameplay')
INFO = os.path.join(ROOT, 'screenshots', 'info')
SHOW = os.path.join(ROOT, 'showcase')
for d in (TMP, GAME, INFO, SHOW):
    os.makedirs(d, exist_ok=True)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'kami2.sym')):
    m = re.match(r'(\S+): EQU 0x([0-9A-F]+)', l)
    if m:
        sym[m.group(1)] = int(m.group(2), 16)


def run(name, frames, keys="", shots=(), every=0, pokes=()):
    for f in glob.glob(os.path.join(TMP, name + '_*.ppm')):
        os.remove(f)
    kf = os.path.join(TMP, name + '.keys')
    open(kf, 'w').write(keys)
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-out', os.path.join(TMP, name)]
    if shots:
        a += ['-shots', ','.join(map(str, shots))]
    if every:
        a += ['-every', str(every)]
    for (f, s, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, sym[s] if isinstance(s, str) else s, v)]
    subprocess.run(a, capture_output=True)


def path(name, n):
    return os.path.join(TMP, '%s_%05d.ppm' % (name, n))


def frame(name, n, size=(544, 408)):
    # 4:3 like a real screen: the 256x192 picture plus a little border
    im = Image.open(path(name, n)).crop((24, 18, 296, 222))
    return im.resize(size, Image.NEAREST)


def save(name, n, folder, out):
    frame(name, n).save(os.path.join(folder, out + '.png'))


def count(name, n, box, test):
    """pixels in box (x0,y0,x1,y1 in 128x64 game pixels) whose colour passes test"""
    im = Image.open(path(name, n))
    x0, y0, x1, y1 = box
    c = 0
    for y in range(y0, y1):
        for x in range(x0, x1):
            if test(im.getpixel((32 + x * 2, 24 + y * 3))):
                c += 1
    return c


def best(name, frames, box, test):
    sc = [(count(name, n, box, test), n) for n in frames if os.path.exists(path(name, n))]
    return max(sc)[1]


def human_keys(start, end, seed):
    """scripted 'human-ish' play: random runs left/right with bursts of fire"""
    random.seed(seed)
    ev, f = [], start
    while f < end:
        d = random.randint(8, 40)
        ev.append("%d %d %s" % (f, f + d, random.choice(("M", "COMMA"))))
        for g in range(f, f + d, 9):
            if random.random() < 0.6:
                ev.append("%d %d SPACE" % (g, g + 2))
        f += d + random.randint(0, 20)
    return "\n".join(ev) + "\n"


GOD = [(150, 'godmode', 1)]
AUTO = [(150, 'autoplay', 1), (150, 'godmode', 1)]
SECTORS = ['outer_rim', 'ion_storm', 'red_nebula', 'the_hive']
not_space = lambda p: p not in ((59, 8, 255), (255, 28, 255))   # the two space colours

# ---- attract cycle: title, three info pages, demo, Top Ten ----
run('att', 4500, every=3)
for n, f in [('info_01_title', 402), ('info_02_how_to_play', 1101), ('info_03_the_enemy', 1701),
             ('info_04_capsules', 2202), ('info_05_top_ten', 4452)]:
    save('att', f, INFO, n)
save('att', best('att', range(2700, 4200, 3), (0, 13, 128, 40), not_space), GAME, 'game_10_demo')

# ---- the four sectors: scripted play, invulnerable so the columns fill ----
for s, key in enumerate('1234'):
    nm = 's%d' % (s + 1)
    run(nm, 2700, keys="100 103 %s\n" % key + human_keys(450, 2700, 7 + s), pokes=GOD, every=3)
    save(nm, best(nm, range(1200, 2700, 3), (0, 13, 128, 40), not_space), GAME,
         'game_%02d_%s' % (s + 1, SECTORS[s]))
    if s == 0:
        save(nm, 222, INFO, 'info_06_sector_intro')
        save(nm, 360, INFO, 'info_07_get_ready')
# the bomb: most bomb-coloured pixels in the centre lane (sector 3, red bomb on blue)
red = lambda p: p[0] > 200 and p[1] < 80 and p[2] < 80
bombf = best('s3', range(450, 2700, 3), (61, 20, 68, 56), red)
save('s3', bombf, GAME, 'game_05_bomb')

# ---- BREACH: empty the hold early in sector 2 and watch the core open, then blow ----
run('br', 1150, keys="100 103 2\n", pokes=AUTO + [(700, 'ms_cargo', 0)], every=3)
save('br', 801, GAME, 'game_06_breach')
save('br', best('br', range(819, 1000, 3), (0, 3, 128, 16), lambda p: p != (255, 28, 255)), GAME,
     'game_07_core_destroyed')

# ---- sector 4 to the end: forced mothership finishes -> sector clear, bonus round, ending ----
pk = list(AUTO) + [(f, 'forceclear', 1) for f in range(1500, 3700, 700)]
run('end', 6500, keys="100 103 4\n", pokes=pk, every=3)
names = {}
print('end run frames:', len(glob.glob(os.path.join(TMP, 'end_*.ppm'))))
save('end', 3870, GAME, 'game_09_sector_clear')
save('end', best('end', range(4200, 4740, 3), (0, 13, 128, 56), red), GAME, 'game_08_kamikaze_rain')
save('end', 4050, INFO, 'info_08_bonus_intro')
save('end', 4800, INFO, 'info_09_bonus_tally')
save('end', 5040, INFO, 'info_10_ending')

# ---- game over, name entry on the letter grid, and the new entry in the Top Ten ----
keys = ("100 103 SPACE\n1700 1702 SPACE\n1720 1722 COMMA\n1740 1742 SPACE\n1760 1762 A\n"
        "1780 1782 COMMA\n1790 1792 COMMA\n1800 1802 SPACE\n1820 1822 A\n1840 1842 A\n"
        "1850 1852 COMMA\n1860 1862 COMMA\n1870 1872 COMMA\n1880 1882 COMMA\n1890 1892 COMMA\n1900 1902 SPACE\n")
run('go', 2200, keys=keys, pokes=[(400, 'score', 0x02), (400, sym['score'] + 1, 0x34), (400, 'lives', 1)], every=3)
save('go', 1212, INFO, 'info_11_game_over')
save('go', 1836, INFO, 'info_12_name_entry')
save('go', 1980, INFO, 'info_13_new_top_ten')

# ---- showcase GIF: title -> info pages -> four sectors, bomb, breach -> Kamikaze Rain -> ending -> Top Ten ----
SZ = (408, 306)
b0 = max(450, bombf - 150) // 3 * 3
clips = [('att', 60, 420), ('att', 1101, 1200), ('att', 1701, 1800), ('att', 2202, 2280),
         ('s1', 1500, 1800), ('s2', 1500, 1740), ('s3', b0, b0 + 300), ('s4', 1800, 2100),
         ('br', 702, 960), ('end', 4200, 4440), ('end', 5040, 5130), ('go', 1980, 2040)]
frames = []
black = Image.new('RGB', SZ, (0, 0, 0))
for name, a, b in clips:
    for n in range(a - a % 3, b, 3):
        if os.path.exists(path(name, n)):
            frames.append(frame(name, n, SZ))
    frames += [black, black]
frames = [f.quantize(colors=16, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE) for f in frames]
frames[0].save(os.path.join(SHOW, 'showcase.gif'), save_all=True, append_images=frames[1:],
               duration=60, loop=0, optimize=True)
print('showcase frames:', len(frames))
