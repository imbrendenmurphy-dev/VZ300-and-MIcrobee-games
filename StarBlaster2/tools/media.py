#!/usr/bin/env python3
"""Capture the audio clips from the headless emulator.
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
# speaker output: the title music, and a stretch of sector 1 played by the AI
# (screenshots and the showcase GIF: showcase_capture.py, export_shots.py, showcase.py)
run('tit', 800, wav=os.path.join(TMP, 'title.wav'))
mp3(os.path.join(TMP, 'title.wav'), os.path.join(MEDIA, 'title_music.mp3'))
run('s1', 1900, keys="100 103 SPACE\n", pokes=[(50, 'startsec', 0)] + AUTO, wav=os.path.join(TMP, 'game.wav'))
mp3(os.path.join(TMP, 'game.wav'), os.path.join(MEDIA, 'gameplay_sound.mp3'))
print("media done")
