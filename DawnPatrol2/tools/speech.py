# Tiny formant voice for the prisoners: "HI!" and "BYE!" -> 1-bit clips
import numpy as np, math

RATE = 8000


def resonator(x, f, bw):
    r = math.exp(-math.pi * bw / RATE)
    a1 = 2 * r * math.cos(2 * math.pi * f / RATE)
    a2 = -r * r
    y = np.zeros_like(x)
    y1 = y2 = 0.0
    g = 1 - r
    for i, v in enumerate(x):
        yy = g * v + a1 * y1 + a2 * y2
        y[i] = yy
        y2, y1 = y1, yy
    return y


def voice(segments, f0=(260, 200)):
    """segments: list of (dur_s, kind, (F1,F2,F3) start, end, amp start, amp end)"""
    total = sum(s[0] for s in segments)
    n = int(total * RATE)
    out = np.zeros(n)
    t0 = 0
    phase = 0.0
    rng = np.random.default_rng(3)
    for dur, kind, fa, fb, aa, ab in segments:
        m = int(dur * RATE)
        src = np.zeros(m)
        for i in range(m):
            k = (t0 + i) / n
            f = f0[0] + (f0[1] - f0[0]) * k
            phase += f / RATE
            if kind == 'v':
                src[i] = 1.0 if phase % 1.0 < 0.08 else 0.0
            else:
                src[i] = rng.uniform(-0.5, 0.5)
        fr = [np.linspace(fa[j], fb[j], m) for j in range(3)]
        y = src.copy()
        # time-varying formants: filter in short blocks
        blk = 80
        seg = np.zeros(m)
        for s in range(0, m, blk):
            e = min(m, s + blk)
            part = src[max(0, s - 160):e]
            z = part
            for j, bw in zip(range(3), (90, 110, 170)):
                z = resonator(z, fr[j][s], bw)
            seg[s:e] = z[-(e - s):]
        env = np.linspace(aa, ab, m)
        out[t0:t0 + m] = seg * env
        t0 += m
    out /= (np.max(np.abs(out)) + 1e-9)
    return out


A = (760, 1250, 2550)
I = (300, 2250, 3000)
B = (250, 800, 2200)


def hi():
    return voice([
        (0.06, 'n', A, A, 0.6, 0.9),     # h: breath shaped like the vowel
        (0.14, 'v', A, A, 1.0, 1.0),
        (0.12, 'v', A, I, 1.0, 0.8),
        (0.04, 'v', I, I, 0.6, 0.0),
    ], f0=(280, 230))


def bye():
    return voice([
        (0.02, 'v', B, B, 0.2, 0.5),      # b: voiced burst opening up
        (0.05, 'v', B, A, 0.6, 1.0),
        (0.12, 'v', A, A, 1.0, 1.0),
        (0.13, 'v', A, I, 1.0, 0.7),
        (0.05, 'v', I, I, 0.6, 0.0),
    ], f0=(240, 190))


def onebit(x):
    bits = []
    prev = 0
    for v in x:
        if abs(v) < 0.04:
            b = prev                     # gate: hold the speaker still in quiet bits
        else:
            b = 1 if v > 0 else 0
        bits.append(b)
        prev = b
    out = []
    for i in range(0, len(bits), 8):
        byte = 0
        for k in range(8):
            byte = (byte << 1) | (bits[i + k] if i + k < len(bits) else 0)
        out.append(byte)
    return out


def speech_asm():
    lines = []
    for name, fn in (('SPEECH_HI', hi), ('SPEECH_BYE', bye)):
        data = onebit(fn())
        lines.append('%s: dw %d' % (name, len(data)))
        for i in range(0, len(data), 24):
            lines.append('        db ' + ','.join('$%02X' % b for b in data[i:i + 24]))
    return '\n'.join(lines) + '\n'


if __name__ == '__main__':
    import wave
    for name, fn in (('hi', hi), ('bye', bye)):
        x = fn()
        bits = onebit(x)
        # write the 1-bit version as a wav to check by eye/ear
        samp = []
        for byte in bits:
            for k in range(8):
                samp.append(9000 if (byte >> (7 - k)) & 1 else -9000)
        w = wave.open('/home/claude/dp2/test/%s.wav' % name, 'wb')
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(np.array(samp, dtype=np.int16).tobytes()); w.close()
        print(name, len(bits), 'bytes')
