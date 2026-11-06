#!/usr/bin/env python3
"""Capture README screenshots, GIFs and audio from the headless emulator.
needs: tools/vzemu/vzemu built, build/ROBOGEDN.VZ + build/robogedn.sym, Pillow, ffmpeg (for mp3)"""
import os, subprocess, glob, re
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'ROBOGEDN.VZ')
TMP = os.path.join(ROOT, 'build', 'media_tmp')
SHOTS = os.path.join(ROOT, 'screenshots')
MEDIA = os.path.join(ROOT, 'media')
for d in (TMP, SHOTS, MEDIA):
    os.makedirs(d, exist_ok=True)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'robogedn.sym')):
    m = re.match(r'(\S+): EQU 0x([0-9A-F]+)', l)
    if m:
        sym[m.group(1)] = int(m.group(2), 16)
P = 'ROBOGEDDON_'


def run(name, frames, keys="", shots=(), every=0, pokes=(), wav=None):
    for f in glob.glob(os.path.join(TMP, name + '_*.ppm')):
        os.remove(f)
    kf = os.path.join(TMP, name + '.keys')
    open(kf, 'w').write(keys)
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-out', os.path.join(TMP, name), '-bennvenn']
    if shots:
        a += ['-shots', ','.join(map(str, shots))]
    if every:
        a += ['-every', str(every)]
    for (f, addr, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, addr, v)]
    if wav:
        a += ['-wav', wav]
    return subprocess.run(a, capture_output=True, text=True).stderr


def frame(name, n, scale=2):
    im = Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((32, 24, 288, 216))
    return im.resize((256 * scale, 192 * scale), Image.NEAREST)


def gif(name, frames, out, size=(384, 288), dur=80):
    fr = [frame(name, n).resize(size, Image.NEAREST) for n in frames
          if os.path.exists(os.path.join(TMP, '%s_%05d.ppm' % (name, n)))]
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=dur, loop=0, optimize=True)


def mp3(wav, out, start=0, dur=None):
    a = ['ffmpeg', '-y', '-loglevel', 'error', '-ss', str(start), '-i', wav]
    if dur:
        a += ['-t', str(dur)]
    a += ['-ac', '1', '-b:a', '64k', out]
    subprocess.run(a)


def wave_row(row, *vals):
    w = sym['wavetab'] + row * 10
    return [(0, w + i, v) for i, v in enumerate(vals)]


def play_keys(start=40, rounds=10, trainer=True):
    ev = ['20 22 T'] if trainer else []
    ev.append('%d %d SPACE' % (start, start + 2))
    dirs = [('D', 'L'), ('S', 'I'), ('A', 'J'), ('W', 'K')]
    f = start + 100
    for r in range(rounds):
        for mv, fr in dirs:
            ev.append('%d %d %s' % (f, f + 36, mv))
            ev.append('%d %d %s' % (f, f + 36, fr))
            f += 36
    return '\n'.join(ev) + '\n'


# ---- attract cycle + title music: find each screen from the game's own state
tr = os.path.join(TMP, 'att.trace')
NF = 5600
subprocess.run([EMU, VZ, '-frames', str(NF), '-bennvenn', '-out', os.path.join(TMP, 'x'),
                '-trace', '%x:1:%s' % (sym['att_step'], tr + '.s')], capture_output=True)
subprocess.run([EMU, VZ, '-frames', str(NF), '-bennvenn', '-out', os.path.join(TMP, 'x'),
                '-trace', '%x:1:%s' % (sym['demo'], tr + '.d')], capture_output=True)
st = open(tr + '.s', 'rb').read()
dm = open(tr + '.d', 'rb').read()
def first(step):
    return next(i for i, v in enumerate(st) if v == step)
ATT = {'01_title': 300, '02_story': first(1) + 650, '03_gallery': first(2) + 560,
       '04_high_scores': first(3) + 100, '05_controls': first(5) + 100,
       '06_demo': next(i for i, v in enumerate(dm) if v == 1) + 300}
DEMO0 = ATT['06_demo'] - 240
run('att', max(ATT.values()) + 2, shots=tuple(ATT.values()), wav=os.path.join(TMP, 'title.wav'))
for n, f in ATT.items():
    if os.path.exists(os.path.join(TMP, 'att_%05d.ppm' % f)):
        frame('att', f).save(os.path.join(SHOTS, P + n + '.png'))
mp3(os.path.join(TMP, 'title.wav'), os.path.join(MEDIA, 'title_music.mp3'), 0.3, 24)
run('tit', 300, every=2)
gif('tit', range(4, 300, 2), os.path.join(SHOTS, P + 'title.gif'), dur=80)

# ---- the demo (computer player) as a gameplay GIF
run('dem', DEMO0 + 900, every=2)
gif('dem', range(DEMO0 + 60, DEMO0 + 860, 2), os.path.join(SHOTS, P + 'gameplay.gif'), dur=80)

# ---- waves (wave 1's row swapped for the wave we want, trainer on)
waves = [
    ('07_wave_start', [], (80,)),
    ('08_droids', [], (420,)),
    ('09_crushers', wave_row(0, 18, 0, 10, 0, 2, 0, 3, 2, 2, 6), (520,)),
    ('10_mindbots', wave_row(0, 14, 5, 3, 7, 0, 0, 3, 3, 3, 6), (620,)),
    ('11_tanks', wave_row(0, 10, 4, 3, 0, 0, 4, 2, 2, 2, 5), (900,)),
]
for name, pokes, shots in waves:
    run('w' + name, max(shots) + 2, keys=play_keys(), shots=shots, pokes=pokes,
        wav=os.path.join(TMP, 'game.wav') if name == '10_mindbots' else None)
    for s in shots:
        frame('w' + name, s).save(os.path.join(SHOTS, P + name + '.png'))
mp3(os.path.join(TMP, 'game.wav'), os.path.join(MEDIA, 'gameplay_sound.mp3'), 2.0, 20)

# ---- game over -> name entry -> table
sc = sym['score']
keys = '40 42 SPACE\n' + ''.join('%d %d %s\n' % (1500 + i * 12, 1502 + i * 12, k)
                                 for i, k in enumerate(['W', 'W', 'SPACE', 'W', 'SPACE', 'SPACE']))
run('ent', 1700, keys=keys, shots=(1000, 1480, 1646, 1654), pokes=[(150, sc, 0x07), (150, sc + 1, 0x25)])
for n, f in (('12_game_over', 1000), ('13_enter_initials', 1480)):
    frame('ent', f).save(os.path.join(SHOTS, P + n + '.png'))
# the new entry blinks: keep the frame where it's lit
best = max((1646, 1654), key=lambda f: sum(1 for p in frame('ent', f, 1).get_flattened_data() if p != (7, 255, 0)))
frame('ent', best).save(os.path.join(SHOTS, P + '14_new_high_score.png'))

# ---- contact sheet of the stills
names = sorted(glob.glob(os.path.join(SHOTS, P + '[0-9]*.png')))
ims = [Image.open(n).resize((256, 192), Image.NEAREST) for n in names]
cols = 4
rows = (len(ims) + cols - 1) // cols
sheet = Image.new('RGB', (cols * 260, rows * 196), (0, 0, 0))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * 260 + 2, (i // cols) * 196 + 2))
sheet.save(os.path.join(SHOTS, P + 'screens.png'))
print('done:', len(names), 'stills')
