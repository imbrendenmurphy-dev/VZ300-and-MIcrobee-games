#!/usr/bin/env python3
"""Capture README screenshots, GIFs and audio from the headless emulator."""
import os, re, subprocess, glob, shutil
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'PENGUIN2.VZ')
TMP = os.path.join(ROOT, 'build', 'media_tmp')
SHOTS = os.path.join(ROOT, 'screenshots')
MEDIA = os.path.join(ROOT, 'media')
for d in (TMP, SHOTS, MEDIA):
    os.makedirs(d, exist_ok=True)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'penguin2.sym')):
    m = re.match(r'(\S+): EQU 0x([0-9A-F]+)', l)
    if m:
        sym[m.group(1)] = int(m.group(2), 16)


def run(name, frames, keys="", shots=(), every=0, pokes=(), wav=None):
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
        a += ['-poke', '%d:%x:%x' % (f, sym[s], v)]
    if wav:
        a += ['-wav', wav]
    subprocess.run(a, capture_output=True)


def frame(name, n):
    im = Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((32, 24, 288, 216))
    return im.resize((512, 384), Image.NEAREST)


def gif(name, start, end, step, out):
    fr = [frame(name, n).resize((384, 288), Image.NEAREST) for n in range(start, end, step)
          if os.path.exists(os.path.join(TMP, '%s_%05d.ppm' % (name, n)))]
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=int(step * 20), loop=0, optimize=True)


AUTO = [(150, 'autoplay', 1), (150, 'godmode', 1)]
# title + attract pages
run('att', 2050, shots=(300, 560, 1000, 1350, 1700), every=0)
names = ['01_title', '02_how_to_play', '03_monsters', '04_goodies']
for n, f in zip(names, (560, 1000, 1350, 1700)):
    frame('att', f).save(os.path.join(SHOTS, 'PENGUIN2_%s.png' % n))
run('tit', 700, every=4, wav=os.path.join(TMP, 'title.wav'))
gif('tit', 40, 700, 4, os.path.join(SHOTS, 'PENGUIN2_title.gif'))
# gameplay in each world (AI plays, invulnerable for capture), world chosen with keys 1-4
for w, key in enumerate(('1', '2', '3', '4')):
    nm = 'w%d' % (w + 1)
    run(nm, 1500, keys="100 103 %s\n" % key, pokes=AUTO, every=10,
        wav=os.path.join(TMP, 'game.wav') if w == 0 else None)
# pick the busiest frames by a simple score: count of non-white playfield pixels changing? use fixed frames
for w, f in ((1, 700), (2, 900), (3, 1100), (4, 1200)):
    frame('w%d' % w, f).save(os.path.join(SHOTS, 'PENGUIN2_%02d_world%d.png' % (4 + w, w)))
frame('w1', 230).save(os.path.join(SHOTS, 'PENGUIN2_09_stage_intro.png'))
gif('w1', 300, 1300, 3, os.path.join(SHOTS, 'PENGUIN2_gameplay.gif'))
# gold rush, intermission, ending: start at world 1 and force clears
pk = list(AUTO) + [(f, 'forceclear', 1) for f in range(1150, 26000, 1000)]
run('soak', 26000, keys="100 103 SPACE\n", pokes=pk, every=50)
print("soak frames:", len(glob.glob(os.path.join(TMP, 'soak_*.ppm'))))
