#!/usr/bin/env python3
"""Capture README screenshots, GIFs and audio from the headless emulator.
needs: tools/vzemu/vzemu built, build/KAMI2.VZ + build/kami2.sym, Pillow, ffmpeg (for mp3)"""
import os, re, subprocess, glob, shutil
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EMU = os.path.join(ROOT, 'tools', 'vzemu', 'vzemu')
VZ = os.path.join(ROOT, 'build', 'KAMI2.VZ')
TMP = os.path.join(ROOT, 'build', 'media_tmp')
SHOTS = os.path.join(ROOT, 'screenshots')
MEDIA = os.path.join(ROOT, 'media')
for d in (TMP, SHOTS, MEDIA):
    os.makedirs(d, exist_ok=True)
sym = {}
for l in open(os.path.join(ROOT, 'build', 'kami2.sym')):
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
        a += ['-poke', '%d:%x:%x' % (f, sym[s] if isinstance(s, str) else s, v)]
    if wav:
        a += ['-wav', wav]
    r = subprocess.run(a, capture_output=True, text=True)
    return r.stderr


def frame(name, n):
    im = Image.open(os.path.join(TMP, '%s_%05d.ppm' % (name, n))).crop((32, 24, 288, 216))
    return im.resize((512, 384), Image.NEAREST)


def gif(name, start, end, step, out, size=(384, 288)):
    fr = [frame(name, n).resize(size, Image.NEAREST) for n in range(start, end, step)
          if os.path.exists(os.path.join(TMP, '%s_%05d.ppm' % (name, n)))]
    fr[0].save(out, save_all=True, append_images=fr[1:], duration=int(step * 20), loop=0, optimize=True)


def mp3(wav, out, start=0, dur=None):
    a = ['ffmpeg', '-y', '-loglevel', 'error', '-ss', str(start), '-i', wav]
    if dur:
        a += ['-t', str(dur)]
    a += ['-ac', '1', '-b:a', '64k', out]
    subprocess.run(a)


def busiest(name, frames):
    best, bf = -1, frames[0]
    for n in frames:
        p = os.path.join(TMP, '%s_%05d.ppm' % (name, n))
        if not os.path.exists(p):
            continue
        im = Image.open(p).crop((32, 24 + 13 * 3, 288, 24 + 40 * 3))
        bgc = im.getpixel((255, 30))
        c = sum(1 for px in im.get_flattened_data() if px != bgc) if hasattr(im, 'get_flattened_data') \
            else sum(1 for px in im.getdata() if px != bgc)
        if c > best:
            best, bf = c, n
    return bf


AUTO = [(150, 'autoplay', 1), (150, 'godmode', 1)]
# title + attract pages
run('att', 2900, shots=(400, 1100, 1650, 2200), wav=os.path.join(TMP, 'title.wav'))
for n, f in zip(['01_title', '02_how_to_play', '03_enemy', '04_capsules'], (400, 1100, 1650, 2200)):
    frame('att', f).save(os.path.join(SHOTS, 'KAMI2_%s.png' % n))
mp3(os.path.join(TMP, 'title.wav'), os.path.join(MEDIA, 'title_music.mp3'), 0.6, 16)
run('tit', 760, every=4)
gif('tit', 40, 760, 4, os.path.join(SHOTS, 'KAMI2_title.gif'))
# gameplay in each sector: scripted "human-ish" play (random moves, fire bursts),
# invulnerable so the columns fill up; sector chosen with keys 1-4
import random
random.seed(7)
def human_keys(start, end):
    ev = []
    f = start
    while f < end:
        d = random.randint(8, 40)
        ev.append("%d %d %s" % (f, f + d, random.choice(("M", "COMMA"))))
        for g in range(f, f + d, 9):
            if random.random() < 0.6:
                ev.append("%d %d SPACE" % (g, g + 2))
        f += d + random.randint(0, 20)
    return "\n".join(ev) + "\n"
for s, key in enumerate(('1', '2', '3', '4')):
    nm = 's%d' % (s + 1)
    run(nm, 2600, keys="100 103 %s\n" % key + human_keys(450, 2600), pokes=[(150, 'godmode', 1)], every=2,
        wav=os.path.join(TMP, 'game.wav') if s == 2 else None)
    f = busiest(nm, list(range(1200, 2600, 20)))
    frame(nm, f).save(os.path.join(SHOTS, 'KAMI2_%02d_sector%d.png' % (5 + s, s + 1)))
frame('s1', 330).save(os.path.join(SHOTS, 'KAMI2_09_sector_intro.png'))
gif('s3', 1400, 2400, 4, os.path.join(SHOTS, 'KAMI2_gameplay.gif'))
mp3(os.path.join(TMP, 'game.wav'), os.path.join(MEDIA, 'gameplay_sound.mp3'), 24, 30)
# breach, bonus round, ending: start at sector 4 and force the motherships to finish
pk = list(AUTO) + [(f, 'forceclear', 1) for f in range(1500, 7000, 700)]
run('end', 9000, keys="100 103 4\n", pokes=pk, every=10)
print("end frames:", len(glob.glob(os.path.join(TMP, 'end_*.ppm'))))
# top ten + name entry: a scored game that ends quickly
keys = "100 103 SPACE\n1700 1702 SPACE\n1720 1722 COMMA\n1740 1742 SPACE\n"
run('hs', 2300, keys=keys, pokes=[(400, 'score', 0x02), (400, sym['score'] + 1, 0x34), (400, 'lives', 1)],
    shots=(1745, 2150))
frame('hs', 1745).save(os.path.join(SHOTS, 'KAMI2_12_name_entry.png'))
print("done")

# breach: empty the mothership's hold early in sector 2 and watch the core open
run('br', 1100, keys="100 103 2\n", pokes=AUTO + [(700, 'ms_cargo', 0)], every=5)
gif('br', 700, 1100, 5, os.path.join(SHOTS, 'KAMI2_breach.gif'))
# bonus round and ending (frames from the forced sector-4 run above)
frame('end', busiest('end', list(range(4100, 4400, 10)))).save(os.path.join(SHOTS, 'KAMI2_10_bonus_round.png'))
frame('end', 4600).save(os.path.join(SHOTS, 'KAMI2_11_ending.png'))
frame('br', busiest('br', list(range(760, 900, 5)))).save(os.path.join(SHOTS, 'KAMI2_breach.png'))
# contact sheet for the README
names = ['01_title', '02_how_to_play', '03_enemy', '04_capsules', '05_sector1', '06_sector2',
         '07_sector3', '08_sector4', '10_bonus_round', '12_name_entry', '11_ending', 'breach']
ims = [Image.open(os.path.join(SHOTS, 'KAMI2_%s.png' % n)).resize((256, 192), Image.NEAREST) for n in names]
sheet = Image.new('RGB', (256 * 4, 192 * 3))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % 4) * 256, (i // 4) * 192))
sheet.save(os.path.join(SHOTS, 'KAMI2_screens.png'))
print("sheet done")
