"""'AAARGH!' - a formant-synthesised yell, infinitely clipped to 1 bit
(the classic intelligible beeper-speech trick), packed 8 samples a byte.
Played by say_argh: one sample every 51 + 16*DLY T-states."""
import numpy as np
CPU = 3546900
def build(nbytes, fs_target=6000):
    dly = round((CPU / fs_target - 51) / 16)
    fs = CPU / (51 + 16 * dly)
    n = nbytes * 8
    t = np.arange(n) / fs
    T = n / fs
    u = t / T
    # pitch: a strained yell rising then sliding down, with roughness
    f0 = np.interp(u, [0, 0.12, 0.45, 0.8, 1.0], [230, 330, 300, 200, 140])
    f0 *= 1 + 0.03 * np.sin(2 * np.pi * 7 * t) + 0.02 * np.random.default_rng(3).standard_normal(n)
    ph = np.cumsum(f0 / fs)
    src = (ph % 1.0) * 2 - 1                      # buzzy sawtooth glottis
    src += 0.25 * np.random.default_rng(5).standard_normal(n) * (u > 0.65)   # growl breath
    # formants: 'aaa' moving to a throaty 'rgh'
    F1 = np.interp(u, [0, 0.6, 0.8, 1.0], [800, 780, 520, 420])
    F2 = np.interp(u, [0, 0.6, 0.8, 1.0], [1250, 1200, 1050, 1300])
    F3 = np.interp(u, [0, 0.6, 0.8, 1.0], [2500, 2450, 1700, 2200])
    y = np.zeros(n)
    for F, bw, g in ((F1, 110, 1.0), (F2, 140, 0.7), (F3, 220, 0.35)):
        r = np.exp(-np.pi * bw / fs)
        out = np.zeros(n); y1 = y2 = 0.0
        for i in range(n):
            th = 2 * np.pi * F[i] / fs
            v = src[i] + 2 * r * np.cos(th) * y1 - r * r * y2
            out[i] = v; y2, y1 = y1, v
        y += g * out / (np.max(np.abs(out)) + 1e-9)
    env = np.interp(u, [0, 0.04, 0.7, 0.9, 1.0], [0, 1, 1, 0.6, 0])
    y *= env
    y -= np.convolve(y, np.ones(9) / 9, mode='same')      # high-pass a touch
    bits = (y > 0.02 * np.max(np.abs(y))).astype(int)
    bits[env < 0.05] = 0
    out = bytearray()
    for i in range(0, n, 8):
        v = 0
        for b in bits[i:i + 8]: v = (v << 1) | int(b)
        out.append(v)
    return bytes(out), dly, fs
if __name__ == '__main__':
    d, dly, fs = build(340)
    print(len(d), dly, round(fs))

# ---------------------------------------------------------------------
# general phrase synth: segments of (ms, voiced amp, noise amp, F1, F2, F3, f0)
# parameters glide linearly across each segment towards the next one
# ---------------------------------------------------------------------
GET_READY = [
    # ms  voice noise  F1    F2    F3    f0
    (30,  0.0, 0.0,  300, 1600, 2500, 200),   # g closure
    (14,  0.3, 0.6,  350, 1900, 2500, 210),   # g release
    (110, 1.0, 0.0,  620, 1850, 2550, 240),   # e
    (40,  0.0, 0.0,  620, 1850, 2550, 240),   # t closure
    (28,  0.0, 1.0, 2600, 2900, 2950, 240),   # t burst
    (70,  0.9, 0.0,  420, 1150, 1550, 250),   # r
    (100, 1.0, 0.0,  600, 1800, 2500, 255),   # e
    (30,  0.15, 0.0, 300, 1700, 2500, 230),   # d closure (voice bar)
    (12,  0.4, 0.5,  350, 1900, 2600, 230),   # d release
    (200, 1.0, 0.0,  300, 2250, 2900, 220),   # y (ee), falling
    (40,  0.0, 0.0,  300, 2250, 2900, 160),
]
def build_phrase(segs, fs_target=6000, seed=9):
    dly = round((CPU / fs_target - 51) / 16)
    fs = CPU / (51 + 16 * dly)
    # sample-by-sample targets
    keys_t = [0.0]
    for s in segs: keys_t.append(keys_t[-1] + s[0] / 1000)
    T = keys_t[-1]
    n = int(T * fs) // 8 * 8
    t = np.arange(n) / fs
    def track(k):
        # step-wise target with 15 ms glides between segments
        v = np.zeros(n)
        for i, s in enumerate(segs):
            m = (t >= keys_t[i]) & (t < keys_t[i + 1])
            v[m] = s[k]
        w = max(1, int(0.015 * fs))
        return np.convolve(np.pad(v, (w, w), mode='edge'), np.ones(w) / w, mode='same')[w:-w]
    va, na, F1, F2, F3, f0 = (track(k) for k in range(1, 7))
    rng = np.random.default_rng(seed)
    ph = np.cumsum(f0 / fs)
    src = ((ph % 1.0) * 2 - 1) * va + rng.standard_normal(n) * na * 0.8
    y = np.zeros(n)
    for F, bw, g in ((F1, 100, 1.0), (F2, 130, 0.8), (F3, 200, 0.4)):
        r = np.exp(-np.pi * bw / fs)
        out = np.zeros(n); y1 = y2 = 0.0
        for i in range(n):
            th = 2 * np.pi * F[i] / fs
            v = src[i] + 2 * r * np.cos(th) * y1 - r * r * y2
            out[i] = v; y2, y1 = y1, v
        y += g * out / (np.max(np.abs(out)) + 1e-9)
    y -= np.convolve(y, np.ones(9) / 9, mode='same')
    energy = np.convolve(np.abs(src), np.ones(40) / 40, mode='same')
    bits = (y > 0.02 * np.max(np.abs(y))).astype(int)
    bits[energy < 0.08] = 0
    out = bytearray()
    for i in range(0, n, 8):
        v = 0
        for b in bits[i:i + 8]: v = (v << 1) | int(b)
        out.append(v)
    return bytes(out), dly, fs
