"""espeak-ng -> 1-bit speech bitstream for the VZ (15556 Hz, MSB first)."""
import subprocess, os, wave, numpy as np

ESPEAK = '/home/claude/es/bin/espeak-ng'
ESPEAK_DATA = '/home/claude/es/share/espeak-ng-data'
RATE = 3546900 / 228

def synth(text, path, voice='en-us+m7', speed=125, pitch=38):
    env = dict(os.environ, ESPEAK_DATA_PATH=ESPEAK_DATA)
    subprocess.run([ESPEAK, '-v', voice, '-s', str(speed), '-p', str(pitch), '-a', '180', '-w', path, text],
                   env=env, check=True)
    w = wave.open(path)
    sr = w.getframerate()
    d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float)
    return d, sr

def to_bits(d, sr, rate=RATE, gain=3.0):
    # resample (linear)
    n = int(len(d) * rate / sr)
    t = np.arange(n) * sr / rate
    x = np.interp(t, np.arange(len(d)), d)
    # trim silence
    a = np.abs(x)
    thr = a.max() * 0.02
    idx = np.where(a > thr)[0]
    x = x[max(0, idx[0] - 200): idx[-1] + 400]
    # pre-emphasis (piezo has little bass) + normalise + soft clip
    y = np.append(x[0], x[1:] - 0.85 * x[:-1])
    y = y / (np.percentile(np.abs(y), 99.5) + 1e-9)
    y = np.tanh(y * gain)
    # 2nd order sigma-delta
    out = np.zeros(len(y), dtype=np.uint8)
    e1 = e2 = 0.0
    for i, v in enumerate(y):
        u = v + 1.6 * e1 - 0.64 * e2
        q = 1.0 if u >= 0 else -1.0
        out[i] = 1 if q > 0 else 0
        e2 = e1
        e1 = u - q
        e1 = max(-4, min(4, e1))
    # pack
    pad = (-len(out)) % 8
    out = np.append(out, np.zeros(pad, dtype=np.uint8))
    packed = np.packbits(out)
    return bytes(packed), len(out) / rate

def make(text, path_wav, **kw):
    d, sr = synth(text, path_wav, **kw)
    return to_bits(d, sr)

def preview_wav(bits, path):
    b = np.unpackbits(np.frombuffer(bits, dtype=np.uint8)).astype(float) * 2 - 1
    # simple low-pass like a speaker
    k = np.ones(3) / 3
    y = np.convolve(b, k, mode='same')
    n = int(len(y) * 44100 / RATE)
    y2 = np.interp(np.arange(n) * RATE / 44100, np.arange(len(y)), y)
    w = wave.open(path, 'wb'); w.setnchannels(1); w.setsampwidth(2); w.setframerate(44100)
    w.writeframes((y2 * 12000).astype(np.int16).tobytes()); w.close()

if __name__ == '__main__':
    bits, dur = make('V Z three hundred!', '/tmp/claude-0/s1.wav')
    print(len(bits), dur)
    preview_wav(bits, '/tmp/claude-0/s1_vz.wav')
