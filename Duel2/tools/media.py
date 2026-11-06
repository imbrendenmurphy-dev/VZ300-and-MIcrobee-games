#!/usr/bin/env python3
"""Capture README screenshots, GIFs and audio from the headless emulator.
needs: tools/vzemu/vzemu built, build/DUEL2.VZ + build/duel2.sym, Pillow, ffmpeg (for mp3)
The campaign is flown by the built-in computer pilot (test hooks autoplay + godmode)."""
import os, subprocess, glob
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'DUEL2.VZ')
TMP = os.path.join(ROOT, 'build', 'media_tmp')
SHOTS = os.path.join(ROOT, 'screenshots')
MEDIA = os.path.join(ROOT, 'media')
for d in (TMP, SHOTS, MEDIA):
    os.makedirs(d, exist_ok=True)
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'duel2.sym'))}
P = 'DUEL2_'


def run(name, frames, keys="", shots=(), every=0, pokes=(), wav=None, trace=None):
    for f in glob.glob(os.path.join(TMP, name + '_*.ppm')):
        os.remove(f)
    kf = os.path.join(TMP, name + '.keys')
    open(kf, 'w').write(keys)
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-out', os.path.join(TMP, name), '-bennvenn']
    if shots:
        a += ['-shots', ','.join(map(str, shots))]
    if every:
        a += ['-every', str(every)]
    for (f, s, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, sym[s], v)]
    if wav:
        a += ['-wav', wav]
    if trace:
        a += ['-trace', trace]
    return subprocess.run(a, capture_output=True, text=True).stderr


def frame(name, n, scale=2):
    im = Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((32, 24, 288, 216))
    return im.resize((256 * scale, 192 * scale), Image.NEAREST)


def gif(name, frames, out, size=(384, 288), dur=60):
    fr = [frame(name, n).resize(size, Image.NEAREST) for n in frames
          if os.path.exists(os.path.join(TMP, '%s_%05d.ppm' % (name, n)))]
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=dur, loop=0, optimize=True)


def mp3(wav, out, start=0, dur=None):
    a = ['ffmpeg', '-y', '-loglevel', 'error', '-ss', str(start), '-i', wav]
    if dur:
        a += ['-t', str(dur)]
    a += ['-ac', '1', '-b:a', '64k', out]
    subprocess.run(a)


AUTO = [(5, 'autoplay', 1), (5, 'godmode', 1)]
CAMP_KEYS = "50 52 SPACE\n90 92 SPACE\n"

# ---- attract cycle (title, how to play, meet the aces, demo, hall of fame) + title music
run('att', 4200, shots=(300, 900, 1400, 1700, 2600, 3800), wav=os.path.join(TMP, 'title.wav'))
for n, f in zip(['01_title', '02_how_to_play', '03_meet_aces', '04_meet_aces2', '05_demo', '06_hall_of_fame'],
                (300, 900, 1400, 1700, 2600, 3800)):
    if os.path.exists(os.path.join(TMP, 'att_%05d.ppm' % f)):
        frame('att', f).save(os.path.join(SHOTS, P + n + '.png'))
mp3(os.path.join(TMP, 'title.wav'), os.path.join(MEDIA, 'title_music.mp3'), 0.5, 18)
run('tit', 520, every=3)
gif('tit', range(30, 520, 3), os.path.join(SHOTS, P + 'title.gif'))

# ---- menu
run('menu', 120, keys="50 52 SPACE\n", shots=(110,))
frame('menu', 110).save(os.path.join(SHOTS, P + '07_menu.png'))

# ---- campaign flown by the computer: trace the variables to find good moments
tr = os.path.join(TMP, 'camp.trace')
VB = 0x7800; VL = 0x340
run('campt', 80000, keys=CAMP_KEYS, pokes=AUTO, trace='%x:%x:%s' % (VB, VL, tr))
d = open(tr, 'rb').read()
NF = len(d) // VL


def v(f, name, off=0):
    return d[f * VL + sym[name] - VB + off]


picks = {}
for f in range(200, NF):
    mode, th, gun = v(f, 'mode'), v(f, 'theatre'), v(f, 'guns_on')
    if mode == 1 and gun and v(f, 'pl0', 7) == 1 and v(f, 'pl1', 7) == 1 and v(f, 'banner_t') == 0:
        dx = abs(((v(f, 'pl0', 1) - v(f, 'pl1', 1) + 64) & 127) - 64)
        dy = abs(v(f, 'pl0', 3) - v(f, 'pl1', 3))
        key = 'th%d' % th
        score = -(dx + dy * 2)
        if v(f, 'popup_t') and th >= 2:
            score += 20             # gust / lightning messages
        if key not in picks or score > picks[key][0]:
            picks[key] = (score, f)
    if mode == 4 and v(f, 'bn_got') >= 8 and 'bonus' not in picks:
        picks['bonus'] = (0, f)
    if mode == 1 and v(f, 'pl1', 7) == 2 and 'down' not in picks and v(f, 'banner_t') > 60:
        picks['down'] = (0, f + 20)
want = sorted(set(p[1] for p in picks.values()))
run('camp', max(want) + 2, keys=CAMP_KEYS, pokes=AUTO, shots=want)
names = {'th0': '08_meadows', 'th1': '09_ocean', 'th2': '10_desert', 'th3': '11_night_storm',
         'bonus': '12_balloon_bust', 'down': '13_shot_down'}
for k, (s, f) in picks.items():
    frame('camp', f).save(os.path.join(SHOTS, P + names[k] + '.png'))
print('picked', picks)

# ---- theatre intro, ace card, ending medal
end = next((f for f in range(NF) if v(f, 'acen') == 8), None)
pages = [160, 420] + ([end + 120] if end else [])
run('pages', max(pages) + 2, keys=CAMP_KEYS, pokes=AUTO, shots=pages)
for n, f in zip(['14_theatre_intro', '15_ace_card', '16_ace_of_aces'], pages):
    frame('pages', f).save(os.path.join(SHOTS, P + n + '.png'))

# ---- gameplay gif + gameplay sound: 2 players flown by the computer in the ocean
run('play', 2600, keys="50 52 SPACE\n80 82 Z\n90 92 Z\n100 102 S\n130 132 W\n140 142 SPACE\n300 302 SPACE\n",
    pokes=[(5, 'autoplay', 1)], every=3, wav=os.path.join(TMP, 'play.wav'))
gif('play', range(702, 1602, 3), os.path.join(SHOTS, P + 'gameplay.gif'))
mp3(os.path.join(TMP, 'play.wav'), os.path.join(MEDIA, 'gameplay_sound.mp3'), 6, 30)

# ---- contact sheet
fs = sorted(glob.glob(os.path.join(SHOTS, P + '[0-9]*.png')))
ims = [Image.open(f).resize((256, 192)) for f in fs]
W = Image.new('RGB', (256 * 4 + 12, 196 * ((len(ims) + 3) // 4)), (20, 20, 20))
for i, im in enumerate(ims):
    W.paste(im, ((i % 4) * 259, (i // 4) * 196))
W.save(os.path.join(SHOTS, P + 'screens.png'))
print('done', len(fs), 'screenshots')
