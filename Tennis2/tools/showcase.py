#!/usr/bin/env python3
"""Build the showcase GIF (screenshots/TENNIS2_showcase.gif) from the headless emulator."""
import os, subprocess, glob
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'TENNIS2.VZ')
TMP = os.path.join(ROOT, 'build', 'show_tmp')
os.makedirs(TMP, exist_ok=True)
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'tennis2.sym'))}
STEP = 3


def run(name, frames, keys="", pokes=()):
    for f in glob.glob(os.path.join(TMP, name + '_*.ppm')):
        os.remove(f)
    kf = os.path.join(TMP, name + '.keys')
    open(kf, 'w').write(keys)
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-out', os.path.join(TMP, name), '-every', str(STEP)]
    for (f, s, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, sym[s] if isinstance(s, str) else s, v)]
    subprocess.run(a, capture_output=True)


def find(frames, keys, pokes, var, value, size=2):
    kf = os.path.join(TMP, 'find.keys')
    open(kf, 'w').write(keys)
    tr = os.path.join(TMP, 'find.bin')
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-trace', '%x:%d:%s' % (sym[var], size, tr)]
    for (f, sv, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, sym[sv] if isinstance(sv, str) else sv, v)]
    subprocess.run(a, capture_output=True)
    d = open(tr, 'rb').read()
    for i in range(0, len(d), size):
        if (d[i] if size == 1 else d[i] | d[i + 1] << 8) == value:
            return i // size
    return None


def img(name, n):
    n -= n % STEP
    return Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((24, 18, 296, 222)).resize((408, 306), Image.NEAREST)


frames, durs = [], []


def clip(name, a, b):
    for n in range(a - a % STEP, b, STEP):
        frames.append(img(name, n))
        durs.append(STEP * 20)


def still(name, n, ms):
    frames.append(img(name, n))
    durs.append(ms)


# title and attract pages
run('att', 2300)
clip('att', 120, 330)
# menu
run('menu', 300, keys="100 103 SPACE\n")
still('menu', 290, 1400)
clip('att', 990, 1110)            # How to Play with the drifting backplane
clip('att', 1480, 1560)           # Meet the Tour
# play on each surface
EX = "100 103 SPACE\n200 203 A\n260 263 SPACE\n"
for i, (sname, opp, a, b) in enumerate((('grass', 0, 1900, 2350), ('clay', 2, 2420, 2600),
                                        ('hard', 5, 2620, 2800), ('night', 7, 2820, 3000))):
    k = EX + ''.join('%d %d A\n' % (450 + 80 * j, 458 + 80 * j) for j in range(i))
    k += ''.join('%d %d COMMA\n' % (800 + 60 * j, 808 + 60 * j) for j in range(opp))
    k += "1400 1405 SPACE\n"
    run('ex_' + sname, b + 5, keys=k, pokes=[(1500, 'autoplay', 1)])
    if i == 0:
        still('ex_grass', 1300, 1400)   # opponent / court picker
    clip('ex_' + sname, a, b)
# tour: bracket, opponent card, trophy, Grand Slam
tk2 = "100 103 SPACE\n260 263 SPACE\n" + ''.join('%d %d SPACE\n' % (f, f + 2) for f in (500, 900))
reach = sym['pl0'] + 14
pk = [(300, 'autoplay', 1), (300, 'gamesper', 2), (400, 'tourn', 3), (400, 'round', 2)]
pk += [(f, reach, 0) for f in range(1100, 6000, 200)]
tro = find(9000, tk2, pk, 'infohook', sym['trophy_anim'])
gsl = find(12000, tk2, pk, 'infohook', sym['ending_anim'])
run('gs', gsl + 330, keys=tk2, pokes=pk)
still('gs', 400, 1400)              # bracket
still('gs', 600, 1400)              # opponent card
clip('gs', tro + 60, tro + 200)
clip('gs', gsl + 60, gsl + 320)
out = os.path.join(ROOT, 'screenshots', 'TENNIS2_showcase.gif')
frames[0].save(out, save_all=True, append_images=frames[1:], duration=durs, loop=0, optimize=True)
print(out, len(frames), 'frames', sum(durs) / 1000, 's', os.path.getsize(out) // 1024, 'KB')
