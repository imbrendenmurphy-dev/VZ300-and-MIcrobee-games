"""Measure 50 Hz gating buzz in an emulator wav: energy share of 50/100/150/200 Hz bins (low band)."""
import sys, wave, numpy as np
def buzz(path, t0, t1):
    w = wave.open(path); sr = w.getframerate()
    a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float)[int(t0*sr):int(t1*sr)]
    f = np.abs(np.fft.rfft(a * np.hanning(len(a))))**2
    fr = np.fft.rfftfreq(len(a), 1/sr)
    tot = f[(fr > 20) & (fr < 8000)].sum()
    b = sum(f[(fr > h - 1.5) & (fr < h + 1.5)].sum() for h in (50, 100, 150, 200, 250))
    hi = f[(fr > 2500) & (fr < 8000)].sum()
    return b / tot, hi / tot
if __name__ == '__main__':
    p, t0, t1 = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
    b, h = buzz(p, t0, t1)
    print(f'50Hz-harmonic share {b*100:.1f}%   2.5-8kHz (shrill) share {h*100:.1f}%')
