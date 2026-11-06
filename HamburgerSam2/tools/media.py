#!/usr/bin/env python3
"""Capture README screenshots, GIFs and audio from the headless emulator (HAMBURGER SAM II).
Run after src/build.sh:  python3 tools/media.py"""
import os, subprocess, glob, sys
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'release', 'HAMSAM2.VZ')
TMP = os.path.join(ROOT, 'build', 'media_tmp')
SHOTS = os.path.join(ROOT, 'screenshots')
MEDIA = os.path.join(ROOT, 'media')
for d in (TMP, SHOTS, MEDIA):
    os.makedirs(d, exist_ok=True)
sym = {l.split()[1]: int(l.split()[0], 16) for l in open(os.path.join(ROOT, 'build', 'hamsam2.sym'))}
PICK = '--pick' in sys.argv          # just dump contact sheets to choose frames


def run(name, frames, keys="", shots=(), every=0, pokes=(), wav=None):
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
    if wav:
        a += ['-wav', wav]
    subprocess.run(a, capture_output=True)


def frame(name, n):
    # 4:3 like the user's screen: the 256x192 picture plus a little border
    im = Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((24, 18, 296, 222))
    return im.resize((544, 408), Image.NEAREST)


def save(name, n, out):
    frame(name, n).save(os.path.join(SHOTS, 'HAMSAM2_%s.png' % out))


def gif(name, start, end, step, out):
    fr = [frame(name, n).resize((408, 306), Image.NEAREST) for n in range(start, end, step)
          if os.path.exists(os.path.join(TMP, '%s_%05d.ppm' % (name, n)))]
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=int(step * 20), loop=0, optimize=True)


def mp3(wav, out, secs, start=0):
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-ss', str(start), '-i', wav, '-t', str(secs),
                    '-ac', '1', '-b:a', '96k', out])


def sheet(name, every, out):
    fs = sorted(glob.glob(os.path.join(TMP, name + '_*.ppm')))
    ims = [Image.open(f).crop((24, 18, 296, 222)).resize((136, 102)) for f in fs]
    cols = 10
    s = Image.new('RGB', (cols * 136, ((len(ims) + cols - 1) // cols) * 102))
    for i, im in enumerate(ims):
        s.paste(im, ((i % cols) * 136, (i // cols) * 102))
    s.save(out)


START = "100 104 SPACE\n160 164 SPACE\n"
AUTO = [(5, 'autoplay', 1), (5, 'godmode', 1)]
if PICK:
    run('att', 4400, every=50)
    sheet('att', 50, os.path.join(TMP, 'pick_att.png'))
    run('long', 9000, keys=START, pokes=AUTO, every=50)
    sheet('long', 50, os.path.join(TMP, 'pick_long.png'))
    run('end', 4500, keys=START, pokes=AUTO + [(170, 'kitchen', 7)], every=50)
    sheet('end', 50, os.path.join(TMP, 'pick_end.png'))
    sys.exit()

# attract pages
A = dict(title=400, how=1000, ctl=1300, meet=1650, good=1950, demo=3000, top=4100)
run('att', 4200, shots=tuple(A.values()))
for n, k in (('01_title', 'title'), ('03_how_to_cook', 'how'), ('04_controls', 'ctl'),
             ('05_meet_the_menu', 'meet'), ('06_goodies', 'good'), ('07_demo', 'demo'), ('15_top_ten', 'top')):
    save('att', A[k], n)
run('tit', 760, every=3, wav=os.path.join(TMP, 'title.wav'))
gif('tit', 60, 700, 3, os.path.join(SHOTS, 'HAMSAM2_title.gif'))
mp3(os.path.join(TMP, 'title.wav'), os.path.join(MEDIA, 'title_music.mp3'), 15)
# menu + kitchen card
run('menu', 300, keys="100 103 SPACE\n", shots=(290,))
save('menu', 290, '02_menu')
# every kitchen, mid-play (autopilot)
for k in range(8):
    nm = 'k%d' % k
    run(nm, 1300, keys=START, pokes=AUTO + [(170, 'kitchen', k)],
        shots=(240, 1250), wav=os.path.join(TMP, 'game.wav') if k == 0 else None)
    if k == 0:
        save(nm, 240, '08_kitchen_card')
    save(nm, 1250, '%02d_kitchen%d' % (20 + k, k + 1))
mp3(os.path.join(TMP, 'game.wav'), os.path.join(MEDIA, 'gameplay_sound.mp3'), 18, 6)
run('play', 1700, keys=START, pokes=AUTO, every=3)
gif('play', 501, 1600, 3, os.path.join(SHOTS, 'HAMSAM2_gameplay.gif'))
# Order Up!, kitchen 8 cleared -> ending
run('end', 4500, keys=START, pokes=AUTO + [(170, 'kitchen', 7)], shots=(2300, 2600, 3100, 3300))
# classic 1984 (C on the title, menu line 3)
for f, n in ((2300, '09_order_up'), (2600, '10_order_catch'), (3100, '14_order_tally'), (3300, '16_ending')):
    save('end', f, n)
run('cl', 900, keys="60 63 C\n150 153 SPACE\n200 203 A\n215 218 A\n240 243 SPACE\n", shots=(870,))
save('cl', 870, '13_classic_1984')
# game over + name entry
run('go', 1300, keys="100 104 SPACE\n160 164 SPACE\n1000 1003 Q\n1010 1013 Q\n1020 1023 SPACE\n1080 1083 RETURN\n",
    pokes=[(300, 'lives', 1), (400, sym['score'] + 1, 0x50)], shots=(850, 1075))
save('go', 850, '11_game_over')
save('go', 1075, '12_name_entry')
