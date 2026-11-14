"""Render the Premium Plus model's speaker to a WAV the way a small
speaker hears it: the 1-bit level is averaged over each output sample
(so time-slot mixing comes out as real mixing, without aliasing), then
gently low-passed and DC-blocked.

    import audio; audio.wav(pp, path, t0, t1)
    audio.levels(pp, t0, t1)  -> per-band energy, for checking a mix
"""
import wave
import numpy as np

CLOCK = 3375000


def pcm(pp, t0, t1, rate=44100):
    t, v = pp.speaker()
    t = np.asarray(t, np.int64)
    v = np.asarray(v, np.int8)
    n = int((t1 - t0) * rate / CLOCK)
    # the level as a step function; integrate it exactly per output sample
    edges = t0 + (np.arange(n + 1) * CLOCK / rate)
    # level just before t0
    k = np.searchsorted(t, t0, side='right') - 1
    lvl0 = int(v[k]) if k >= 0 else 0
    sel = (t >= t0) & (t < t1)
    tt = np.concatenate(([t0], t[sel], [t1])).astype(np.float64)
    vv = np.concatenate(([lvl0], v[sel])).astype(np.float64)
    # cumulative "time high" at each transition
    dur = np.diff(tt)
    cum = np.concatenate(([0.0], np.cumsum(dur * vv)))

    def high_until(x):
        i = np.searchsorted(tt, x, side='right') - 1
        i = np.clip(i, 0, len(vv) - 1)
        return cum[i] + (x - tt[i]) * vv[i]
    h = high_until(edges)
    duty = np.diff(h) / (CLOCK / rate)          # 0..1 per output sample
    x = duty * 2 - 1
    # a small speaker: one-pole low-pass ~7 kHz, DC blocker ~40 Hz
    a = np.exp(-2 * np.pi * 7000 / rate)
    y = np.empty_like(x)
    s = 0.0
    for i in range(len(x)):
        s = a * s + (1 - a) * x[i]
        y[i] = s
    r = np.exp(-2 * np.pi * 40 / rate)
    out = np.empty_like(y)
    px = py = 0.0
    for i in range(len(y)):
        py = y[i] - px + r * py
        px = y[i]
        out[i] = py
    return out


def wav(pp, path, t0, t1, rate=44100, gain=0.8):
    y = pcm(pp, t0, t1, rate)
    pk = max(1e-6, np.percentile(np.abs(y), 99.9))
    y = np.clip(y / pk * gain, -1, 1)
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((y * 32767).astype(np.int16).tobytes())
    return y


def bands(y, rate=44100):
    """energy in a few bands (dB relative to the total)"""
    f = np.fft.rfftfreq(len(y), 1.0 / rate)
    p = np.abs(np.fft.rfft(y * np.hanning(len(y)))) ** 2
    tot = p.sum() + 1e-12
    out = {}
    for lo, hi in ((20, 150), (150, 500), (500, 2000), (2000, 6000), (6000, 22050)):
        m = (f >= lo) & (f < hi)
        out['%d-%d Hz' % (lo, hi)] = 10 * np.log10(p[m].sum() / tot + 1e-12)
    return out
