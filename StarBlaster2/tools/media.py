#!/usr/bin/env python3
"""Capture README screenshots, GIFs and audio from the headless emulator.
Run after building (src/build.sh). Needs Pillow; ffmpeg for the mp3s."""
import os, re, subprocess, glob, shutil
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'STARBLS2.VZ')
TMP = os.path.join(ROOT, 'build', 'media_tmp')
SHOTS = os.path.join(ROOT, 'screenshots')
MEDIA = os.path.join(ROOT, 'media')
for d in (TMP, SHOTS, MEDIA):
    os.makedirs(d, exist_ok=True)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'sb2.sym')):
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


def mp3(wav, out):
    if shutil.which('ffmpeg'):
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-b:a', '96k', out])


AUTO = [(150, 'autoplay', 1), (150, 'godmode', 1)]
# title + attract pages
run('att', 2700, every=0, shots=(900, 1500, 2100, 2500))
for n, f in zip(('01_title', '02_briefing', '03_fleet', '04_controls'), (900, 1500, 2100, 2500)):
    frame('att', f).save(os.path.join(SHOTS, 'SB2_%s.png' % n))
run('tit', 800, every=4, wav=os.path.join(TMP, 'title.wav'))
gif('tit', 40, 800, 4, os.path.join(SHOTS, 'SB2_title.gif'))
mp3(os.path.join(TMP, 'title.wav'), os.path.join(MEDIA, 'title_music.mp3'))
# gameplay: sectors 1, 2, 4, 5, 6, 8 (AI plays, invulnerable for capture)
for i, sec in enumerate((0, 1, 3, 4, 5, 7)):
    nm = 's%d' % (sec + 1)
    run(nm, 1900, keys="100 103 SPACE\n", pokes=[(50, 'startsec', sec)] + AUTO, every=4,
        wav=os.path.join(TMP, 'game.wav') if sec == 0 else None)
picks = {1: 1200, 2: 1400, 4: 1300, 5: 1500, 6: 1400, 8: 1700}
for k, f in picks.items():
    best = f
    frame('s%d' % k, best).save(os.path.join(SHOTS, 'SB2_sector%d.png' % k))
frame('s1', 220).save(os.path.join(SHOTS, 'SB2_warp_in.png'))
gif('s1', 400, 1300, 4, os.path.join(SHOTS, 'SB2_gameplay.gif'))
gif('s8', 900, 1800, 4, os.path.join(SHOTS, 'SB2_mothership.gif'))
mp3(os.path.join(TMP, 'game.wav'), os.path.join(MEDIA, 'gameplay_sound.mp3'))
# contact sheet of the main screens
names = ['SB2_01_title', 'SB2_03_fleet', 'SB2_sector1', 'SB2_sector4', 'SB2_sector5', 'SB2_sector8']
ims = [Image.open(os.path.join(SHOTS, n + '.png')).resize((256, 192), Image.NEAREST) for n in names]
sheet = Image.new('RGB', (256 * 3 + 8, 192 * 2 + 4), (30, 30, 30))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % 3) * 260, (i // 3) * 196))
sheet.save(os.path.join(SHOTS, 'SB2_screens.png'))
print("media done")
