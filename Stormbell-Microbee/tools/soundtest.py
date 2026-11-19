"""STORMBELL sound check: records the speaker in the emulator.

    python3 tools/soundtest.py OUTDIR

Boots the disk, records the title (thunder, then the two-voice tune),
then plays every effect on its own, and writes a WAV and a spectrogram
picture of each, with its length and the longest silence inside it.
"""
import sys
import wave
from pathlib import Path
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from playtest import Game
import boottest as T
import music

CLK = 3375000
RATE = 44100


def pcm(t, v, t0, t1):
    n = int((t1 - t0) / CLK * RATE)
    buf = np.zeros(max(n, 1), np.float32)
    level, prev = 0, 0
    for tt, vv in zip(t, v):
        if tt < t0:
            level = vv
            continue
        if tt >= t1:
            break
        i = int((tt - t0) / CLK * RATE)
        buf[prev:i] = 1.0 if level else -1.0
        level, prev = vv, i
    buf[prev:] = 1.0 if level else -1.0
    k = min(2205, len(buf))
    return buf - np.convolve(buf, np.ones(k) / k, mode='same')


def save(buf, path):
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(buf, -1, 1) * 9000).astype(np.int16).tobytes())


def spectro(buf, path, fmax=8000, title=''):
    from PIL import Image, ImageDraw
    N, H = 1024, 128
    win = np.hanning(N)
    cols = []
    for i in range(0, max(1, len(buf) - N), H):
        cols.append(np.abs(np.fft.rfft(buf[i:i + N] * win)))
    if not cols:
        return
    sp = np.array(cols).T
    k = int(fmax / (RATE / 2) * sp.shape[0])
    sp = np.log1p(sp[:k][::-1])
    sp = (sp / (sp.max() or 1) * 255).astype(np.uint8)
    im = Image.fromarray(sp).resize((max(200, min(1600, sp.shape[1] * 2)), 256))
    im = im.convert('RGB')
    ImageDraw.Draw(im).text((4, 2), '%s  0-%d Hz, %.2f s' % (title, fmax, len(buf) / RATE), fill=(255, 255, 0))
    im.save(path)


def stats(t, t0):
    t = t[t >= t0]
    if len(t) < 2:
        return 0.0, 0.0
    d = np.diff(t.astype(np.int64))
    return (int(t[-1]) - int(t[0])) / CLK * 1e3, d.max() / CLK * 1e3


if __name__ == '__main__':
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    g = Game(str(out))
    pp = g.pp
    T.launch(pp, 400)
    pp.speaker(clear=True)
    t0 = pp.tick
    pp.run_frames(700)
    t, v = pp.speaker(clear=True)
    b = pcm(t, v, t0, pp.tick)
    save(b, out / 'title.wav')
    spectro(b, out / 'title.png', 3000, 'title')
    print('title: %d speaker edges in 14 s' % len(t))
    # each effect alone, at the title, music off
    for i, (name, pri, hold, steps) in enumerate(music.SFX):
        pp.poke(g.S['mus_on'], 0)
        pp.poke(g.S['ch1'] + 11, 0)
        pp.poke(g.S['ch2'] + 11, 0)
        pp.run_frames(10)
        pp.speaker(clear=True)
        a = g.S['sx_' + name.lower()] + 2
        pp.poke(g.S['sfx_n'], 0)
        pp.poke(g.S['sfx_p'], a & 255)
        pp.poke(g.S['sfx_p'] + 1, a >> 8)
        t0 = pp.tick
        pp.run_frames(40 if name not in ('THUNDER', 'TOLL', 'GONG', 'BELL') else 260)
        t, v = pp.speaker(clear=True)
        ms, gap = stats(t, t0)
        end = int(t[-1]) + CLK // 50 if len(t) else pp.tick
        b = pcm(t, v, t0, min(end, pp.tick))
        save(b, out / ('%s.wav' % name.lower()))
        spectro(b, out / ('%s.png' % name.lower()), 8000, name)
        print('%-8s %6.0f ms, %5d edges, longest silence inside %5.1f ms' % (name, ms, len(t), gap))
