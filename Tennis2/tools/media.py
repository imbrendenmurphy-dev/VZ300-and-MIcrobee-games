#!/usr/bin/env python3
"""Capture README screenshots, GIFs and audio from the headless emulator (TENNIS II)."""
import os, subprocess, glob
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'TENNIS2.VZ')
TMP = os.path.join(ROOT, 'build', 'media_tmp')
SHOTS = os.path.join(ROOT, 'screenshots')
MEDIA = os.path.join(ROOT, 'media')
for d in (TMP, SHOTS, MEDIA):
    os.makedirs(d, exist_ok=True)
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'tennis2.sym'))}


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
        a += ['-poke', '%d:%x:%x' % (f, sym[s] if isinstance(s, str) else s, v)]
    if wav:
        a += ['-wav', wav]
    subprocess.run(a, capture_output=True)


def find(frames, keys, pokes, var, value, after, size=1):
    # first frame where memory variable == value (traced each frame), plus 'after' frames
    kf = os.path.join(TMP, 'find.keys')
    open(kf, 'w').write(keys)
    tr = os.path.join(TMP, 'find.bin')
    a = [EMU, VZ, '-frames', str(frames), '-keys', kf, '-trace', '%x:%d:%s' % (sym[var], size, tr)]
    for (f, sv, v) in pokes:
        a += ['-poke', '%d:%x:%x' % (f, sym[sv] if isinstance(sv, str) else sv, v)]
    subprocess.run(a, capture_output=True)
    d = open(tr, 'rb').read()
    for i in range(0, len(d), size):
        v = d[i] if size == 1 else d[i] | d[i + 1] << 8
        if v == value:
            return i // size + after
    return None


def frame(name, n):
    # 4:3 like the user's screen: the 256x192 picture plus a little border
    im = Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((24, 18, 296, 222))
    return im.resize((544, 408), Image.NEAREST)


def gif(name, start, end, step, out):
    fr = [frame(name, n).resize((408, 306), Image.NEAREST) for n in range(start, end, step)
          if os.path.exists(os.path.join(TMP, '%s_%05d.ppm' % (name, n)))]
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=int(step * 20), loop=0, optimize=True)


def mp3(wav, out, secs):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav, '-t', str(secs), '-ac', '1', '-b:a', '96k', out])


AUTO = [(430, 'autoplay', 1), (430, 'gamesper', 2)]
# attract pages
hof = find(9000, "", [], 'infohook', sym['hof_anim'], 120, 2)
run('att', hof + 10, shots=(400, 1040, 1500, 1750, 2000, 2250, hof))
for n, f in (('01_title', 400), ('03_how_to_play', 1040), ('04_meet_the_tour', 1500), ('05_meet_the_tour2', 2250),
             ('15_hall_of_fame', hof)):
    frame('att', f).save(os.path.join(SHOTS, 'TENNIS2_%s.png' % n))
run('tit', 760, every=3, wav=os.path.join(TMP, 'title.wav'))
gif('tit', 60, 700, 3, os.path.join(SHOTS, 'TENNIS2_title.gif'))
mp3(os.path.join(TMP, 'title.wav'), os.path.join(MEDIA, 'title_music.mp3'), 15)
# menu
run('menu', 300, keys="100 103 SPACE\n", shots=(290,))
frame('menu', 290).save(os.path.join(SHOTS, 'TENNIS2_02_menu.png'))
# exhibition on each surface: down to EXHIBITION, pick the court with U/D (A = down)
EX = "100 103 SPACE\n200 203 A\n260 263 SPACE\n"
for i, (sname, opp) in enumerate((('grass', 0), ('clay', 2), ('hard', 5), ('night', 7))):
    k = EX + ''.join('%d %d A\n' % (450 + 80 * j, 458 + 80 * j) for j in range(i))
    k += ''.join('%d %d COMMA\n' % (800 + 60 * j, 808 + 60 * j) for j in range(opp))
    k += "1400 1405 SPACE\n"
    nm = 'ex_' + sname
    run(nm, 4000, keys=k, pokes=[(1500, 'autoplay', 1)], every=10,
        wav=os.path.join(TMP, 'game.wav') if i == 0 else None)
    if i == 0:
        frame(nm, 1300).save(os.path.join(SHOTS, 'TENNIS2_06_exhibition.png'))
        gif(nm, 1800, 3300, 3, os.path.join(SHOTS, 'TENNIS2_gameplay.gif'))
        mp3(os.path.join(TMP, 'game.wav'), os.path.join(MEDIA, 'gameplay_sound.mp3'), 40)
# pick lively frames (ball in play) for the surface shots
picks = {'grass': 2300, 'clay': 2500, 'hard': 2700, 'night': 2900}
for k, (sname, f) in enumerate(picks.items()):
    frame('ex_' + sname, f).save(os.path.join(SHOTS, 'TENNIS2_%02d_%s.png' % (7 + k, sname)))
# classic court (C on the menu, exhibition, court 5)
k = "100 103 SPACE\n150 153 C\n200 203 A\n260 263 SPACE\n" + ''.join('%d %d A\n' % (450 + 80 * j, 458 + 80 * j) for j in range(4)) + "1400 1405 SPACE\n"
run('classic', 3000, keys=k, pokes=[(1500, 'autoplay', 1)], shots=(2700,))
frame('classic', 2700).save(os.path.join(SHOTS, 'TENNIS2_11_classic_1984.png'))
# tour: bracket, opponent card, practice, trophy (opponent can't reach anything so we win fast)
tk = "100 103 SPACE\n260 263 SPACE\n" + ''.join('%d %d SPACE\n' % (f, f + 2) for f in range(500, 60000, 450))
reach = sym['pl0'] + 14
prac = find(40000, tk, AUTO, 'mode', 4, 900)
run('tour', max(prac + 60, 10000), keys=tk, pokes=AUTO, every=50, shots=(prac,))
print('tour frames', len(glob.glob(os.path.join(TMP, 'tour_*.ppm'))))
for n, f in (('12_bracket', 400), ('14_target_practice', prac)):
    frame('tour', f).save(os.path.join(SHOTS, 'TENNIS2_%s.png' % n))
# trophy + Grand Slam: jump to the Night Masters final and stop the opponent reaching anything
tk2 = "100 103 SPACE\n260 263 SPACE\n" + ''.join('%d %d SPACE\n' % (f, f + 2) for f in (500, 900))
reach = sym['pl0'] + 14
pk = [(300, 'autoplay', 1), (300, 'gamesper', 2), (400, 'tourn', 3), (400, 'round', 2)]
pk += [(f, reach, 0) for f in range(1100, 6000, 200)]
run('gs', 9000, keys=tk2, pokes=pk, every=50)
for n, f in (('13_opponent', 600), ('16_trophy', 3650), ('17_grand_slam', 4400)):
    frame('gs', f).save(os.path.join(SHOTS, 'TENNIS2_%s.png' % n))
# contact sheet for the README
fs = sorted(glob.glob(os.path.join(SHOTS, 'TENNIS2_[0-9]*.png')))
ims = [Image.open(f).resize((272, 204), Image.NEAREST) for f in fs]
cols = 4
sheet = Image.new('RGB', (cols * 272, ((len(ims) + cols - 1) // cols) * 204), (30, 30, 30))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * 272, (i // cols) * 204))
sheet.save(os.path.join(SHOTS, 'TENNIS2_screens.png'))
