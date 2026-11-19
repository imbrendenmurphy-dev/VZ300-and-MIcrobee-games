"""The showcase: screenshots of play and of the attract sequence, a GIF of
the game playing itself, and an MP4 (with its sound) of the attract
sequence, all from the Premium Plus model.

    python3 tools/media.py [shots] [gif] [mp4]       (all three by default)

Writes screenshots/gameplay/, screenshots/attract/, showcase/."""
import os
import subprocess
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from PIL import Image
import run
from mbee import FRAME_T

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / 'screenshots' / 'gameplay'
ATTR = ROOT / 'screenshots' / 'attract'
SHOW = ROOT / 'showcase'
W, H = 960, 622                 # the picture and a little border, 4:3 as the tube shows it
CPU = 3375000.0


def frame(pp, mono=False, size=(W, H)):
    return run.view(pp, mono).resize(size, Image.LANCZOS if size[0] < 672 else Image.NEAREST)


def demo_pp(region, mono=False):
    """the model, playing region's demonstration as the attract sequence does"""
    pp = run.title(mono)
    S = pp.S
    pp.keys = []
    pp.out(0x50, run.blk_port(22))
    a = pp.peekw(S['demos'] + 2 * region)
    pp.out(0x50, run.blk_port(1))
    pp.poke(S['region'], region)
    pp.poke(S['dm_ptr'], a & 255)
    pp.poke(S['dm_ptr'] + 1, a >> 8)
    pp.cpu.pc = S['demo_go'] - 2
    pp.cpu.sp = 0xEFF0
    return pp


def save(im, path):
    im.save(path)
    print('  ', path.relative_to(ROOT))


# ---------------------------------------------------------------------
GAMEPLAY = [   # region, fields into its demonstration, name, monochrome
    (0, 150, 'the_red_dirt', False),
    (0, 330, 'billabong', False),
    (0, 800, 'mound_city', False),
    (0, 1130, 'the_old_gum', False),
    (1, 250, 'escarpment', False),
    (1, 700, 'the_gorge', False),
    (1, 1000, 'rock_art_cave', False),
    (1, 1000, 'rock_art_cave_amber', True),
    (2, 520, 'the_drop_riding_the_vent', False),
    (2, 1250, 'the_drive', False),
    (2, 1500, 'up_the_drive_vent', False),
    (2, 1500, 'up_the_drive_vent_amber', True),
    (3, 300, 'the_floodplain_in_the_rain', False),
    (3, 650, 'paperbark_swamp', False),
    (4, 350, 'the_larder_shelves', False),
    (4, 600, 'king_bufo', False),
    (4, 600, 'king_bufo_amber', True),
]


def shots():
    GAME.mkdir(parents=True, exist_ok=True)
    ATTR.mkdir(parents=True, exist_ok=True)
    print('gameplay')
    n = 0
    for region, f, name, mono in GAMEPLAY:
        pp = demo_pp(region, mono)
        pp.run_frames(f)
        if 'bufo' in name:                      # wait for the King to be in view
            S = pp.S
            for i in range(60):
                st = [pp.peek(S['ENTS'] + 16 * k + 1) for k in range(8) if pp.peek(S['ENTS'] + 16 * k) == 9]
                if st and st[0] in (0, 2, 3):
                    break
                pp.run_frames(2)
        n += 1
        im = run.view(pp, mono)
        save(im.resize((1008, 652), Image.NEAREST), GAME / ('game_%02d_%s.png' % (n, name)))
    print('attract')
    pp = run.boot()
    S = pp.S
    seen, n = [], 0
    names = {(0, 0): 'title', (1, 0): 'the_story_so_far', (1, 1): 'whos_who', (1, 2): 'the_moves'}
    got = set()
    for i in range(1400):
        pp.run_frames(10)
        if pp.peek(S['cur_blk']) != 22 and pp.peek(S['demo']) == 1:
            key = ('demo', pp.peek(S['region']))
        elif pp.peek(S['cur_blk']) == 22:
            stg = int(pp.blocks[22][S['fa_stage']]) - 1
            kind = int(pp.blocks[22][S['stages'] + 2 * stg])
            arg = int(pp.blocks[22][S['stages'] + 2 * stg + 1])
            key = ('card', arg) if kind == 2 else (kind, arg)
        else:
            continue
        if key in got:
            if len([k for k in got if k[0] == 'demo']) >= 5:
                break
            continue
        got.add(key)
        pp.run_frames(60 if key[0] != 'demo' else 300)
        n += 1
        if key[0] == 'demo':
            name = 'demo_%d_%s' % (key[1] + 1, ['the_red_dirt', 'stone_country', 'the_diggings', 'the_wet',
                                                'king_bufos_court'][key[1]])
        elif key[0] == 'card':
            name = 'region_card_%d' % (key[1] + 1)
        else:
            name = names[key]
        save(run.view(pp).resize((1008, 652), Image.NEAREST), ATTR / ('attract_%02d_%s.png' % (n, name)))
    save(run.view(run.title(True), True).resize((1008, 652), Image.NEAREST), ATTR / ('attract_%02d_title_amber.png' % (n + 1)))
    # the screens around the game: keys, region clear, game over, the ending
    # (the model has no disk controller: the disk routines are told to
    # succeed, so the screens say what they say on the machine)
    pp = run.title()
    S = pp.S
    for r in ('sv_dir', 'sv_read', 'sv_write'):
        pp.blocks[22][S[r]] = 0xAF
        pp.blocks[22][S[r] + 1] = 0xC9
    pp.keys = ['K']
    pp.run_frames(8)
    pp.keys = []
    pp.run_frames(30)
    for k in ('Z', 'X', 'F', 'D', 'SPACE'):
        pp.keys = [k]
        pp.run_frames(12)
        pp.keys = []
        pp.run_frames(12)
    pp.run_frames(20)
    save(run.view(pp).resize((1008, 652), Image.NEAREST), ATTR / 'screen_01_choose_your_keys.png')
    pp.run_frames(200)
    pp.keys = ['SPACE']
    pp.run_frames(8)
    pp.keys = []
    pp.run_frames(60)
    pp.poke(S['bugs'], 23)
    pp.poke(S['game_end'], 1)
    pp.run_frames(90)
    save(run.view(pp).resize((1008, 652), Image.NEAREST), ATTR / 'screen_02_region_clear.png')
    pp.keys = ['SPACE']
    pp.run_frames(8)
    pp.keys = []
    pp.run_frames(60)
    pp.poke(S['game_end'], 2)
    pp.run_frames(90)
    save(run.view(pp).resize((1008, 652), Image.NEAREST), ATTR / 'screen_03_game_over.png')
    pp.keys = ['SPACE']
    pp.run_frames(8)
    pp.keys = []
    pp.run_frames(60)
    pp.poke(S['region'], 4)
    pp.poke(S['bugs'], 98)
    pp.poke(S['game_end'], 1)
    pp.run_frames(400)
    save(run.view(pp).resize((1008, 652), Image.NEAREST), ATTR / 'screen_04_the_end_long_live_nobody.png')
    pp.run_frames(1700)
    save(run.view(pp).resize((1008, 652), Image.NEAREST), ATTR / 'screen_05_the_end_thanks_for_playing.png')


# ---------------------------------------------------------------------
def audio(chunks, t0, t1, rate=44100):
    """the speaker's level, averaged into samples, a little filtered"""
    n = int((t1 - t0) / CPU * rate)
    edges = t0 + np.arange(n + 1) * (CPU / rate)
    level0 = 0
    # one pass over all the events: the high time in each sample
    t = np.concatenate([c[0] for c in chunks]).astype(np.float64)
    v = np.concatenate([c[1] for c in chunks]).astype(np.float64)
    v = (v != 0).astype(np.float64)
    keep = (t >= t0) & (t < t1)
    t, v = t[keep], v[keep]
    # integral of the level up to each edge
    pts = np.concatenate([[t0], t, [t1]])
    lv = np.concatenate([[level0], v])
    cum = np.concatenate([[0], np.cumsum(np.diff(pts) * lv)])
    idx = np.searchsorted(pts, edges, side='right') - 1
    idx = np.clip(idx, 0, len(lv) - 1)
    at = cum[idx] + (edges - pts[idx]) * lv[idx]
    out = np.diff(at) / (CPU / rate)
    from scipy.signal import butter, lfilter
    b, a = butter(1, 20 / (rate / 2), 'highpass')      # take the DC out
    out = lfilter(b, a, out)
    b, a = butter(2, 7000 / (rate / 2))                 # and the little speaker's top end
    out = lfilter(b, a, out)
    out = np.clip(out * (0.8 / max(np.percentile(np.abs(out), 99.9), 1e-6)), -1, 1)
    return (out * 30000).astype(np.int16)


def record(pp, path, fields, size=(W, H), keep_audio=True, step=2, stop=None):
    """step fields a frame to an MP4 (H.264, AAC)"""
    fps = CPU / (FRAME_T * step)
    tmp = str(path) + '.video.mp4'
    ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24',
                           '-s', '%dx%d' % size, '-r', '%.5f' % fps, '-i', '-',
                           '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', '-preset', 'slow', tmp],
                          stdin=subprocess.PIPE)
    pp.speaker(clear=True)
    t0 = pp.tick
    chunks = []
    n = 0
    for i in range(0, fields, step):
        pp.run_frames(step)
        ff.stdin.write(frame(pp, size=size).convert('RGB').tobytes())
        n += 1
        if n % 50 == 0:
            chunks.append(pp.speaker(clear=True))
        if stop and stop(pp):
            break
    chunks.append(pp.speaker(clear=True))
    t1 = pp.tick
    ff.stdin.close()
    ff.wait()
    if not keep_audio:
        os.replace(tmp, path)
        return n
    import wave
    wv = str(path) + '.wav'
    a = audio(chunks, t0, t1)
    with wave.open(wv, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(44100)
        w.writeframes(a.tobytes())
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-i', tmp, '-i', wv, '-c:v', 'copy',
                           '-c:a', 'aac', '-b:a', '160k', '-shortest', '-movflags', '+faststart', str(path)])
    os.remove(tmp)
    os.remove(wv)
    return n


def mp4():
    """the attract sequence from the title, until Bluff has played every region"""
    SHOW.mkdir(exist_ok=True)
    pp = run.boot()
    S = pp.S
    pp.run_frames(4)
    state = {'regions': set(), 'last': None}

    def stop(pp):
        if pp.peek(S['cur_blk']) != 22 and pp.peek(S['demo']) == 1:
            state['regions'].add(pp.peek(S['region']))
            state['last'] = 'demo'
        elif state['last'] == 'demo' and len(state['regions']) >= 5:
            return True                 # back to the title after the last one
        else:
            state['last'] = 'front'
        return False
    n = record(pp, SHOW / 'attract.mp4', 50 * 60 * 9, stop=stop)
    print('   showcase/attract.mp4: %d frames, %.0f seconds' % (n, n * 2 * FRAME_T / CPU))


def gif():
    """a minute of the game playing itself: a stretch of every region"""
    SHOW.mkdir(exist_ok=True)
    parts = []
    for region, start, fields in ((0, 240, 330), (0, 1000, 260), (1, 280, 330), (1, 620, 240),
                                  (2, 400, 300), (2, 1380, 260), (3, 200, 330), (4, 250, 300), (4, 560, 300)):
        pp = demo_pp(region)
        pp.run_frames(start)
        p = SHOW / ('part%d.mp4' % len(parts))
        record(pp, p, fields, size=(480, 312), keep_audio=False, step=3)
        parts.append(p)
    lst = SHOW / 'parts.txt'
    lst.write_text(''.join("file '%s'\n" % p.name for p in parts))
    cat = SHOW / 'cat.mp4'
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', str(lst),
                           '-c', 'copy', str(cat)])
    subprocess.check_call(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(cat), '-vf',
                           'fps=16.6,split[a][b];[a]palettegen=max_colors=48:stats_mode=full[p];'
                           '[b][p]paletteuse=dither=none', '-loop', '0', str(SHOW / 'showcase.gif')])
    for p in parts + [lst, cat]:
        os.remove(p)
    print('   showcase/showcase.gif: %.1f MB' % ((SHOW / 'showcase.gif').stat().st_size / 1e6))


if __name__ == '__main__':
    what = sys.argv[1:] or ['shots', 'gif', 'mp4']
    if 'shots' in what:
        shots()
    if 'gif' in what:
        gif()
    if 'mp4' in what:
        mp4()
