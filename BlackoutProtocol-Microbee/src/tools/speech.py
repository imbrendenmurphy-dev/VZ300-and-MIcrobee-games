"""MERIDIAN's voice: Windows TTS -> processed -> 1-bit "clipped speech" at the player's rate.

Clipped speech: the speaker flips only where the (pre-emphasised, band-limited) voice
crosses zero, so every edge is at an audio frequency and full volume.  The first
version used delta-sigma (a ~28.7 kHz pulse stream whose average is the voice): clean
in the emulator, which low-passes the speaker, but nearly silent on a real Microbee,
whose speaker circuit doesn't average such fast pulses.  MODE = 'sigma' brings it back.

The Z80 player (src/sound.asm, sp_play) outputs one bit every ~118 T-states
(~28.7 kHz).  Each line becomes MSB-first bytes.  A preview
WAV of what the 1-bit speaker will sound like (low-passed) is written too.

python tools/speech.py  -> build/speech/*.bin, build/speech/*_preview.wav, build/speech/lines.json
"""
import json, subprocess, wave
from pathlib import Path
import numpy as np

RATE = 3375000 / 117.75     # sp_play: 112 T a bit + 46 T a byte (SP_DELAY 4)
OUT = Path('build/speech'); OUT.mkdir(parents=True, exist_ok=True)
LINES = {                       # all original to this game
    'welcome':  "Welcome to the Halcyon Array, agent.",
    'eight':    "Eight hours. Then, darkness.",
    'intruder': "Intruder.",
    'again':    "Try again, agent.",
    'denied':   "Access denied.",
    'keyok':    "Override key accepted.",
    'hour':     "Time is running out.",
    'cancel':   "Protocol cancelled.",
    'dark':     "Blackout protocol complete.",
}

def synth(name, text):
    wav = OUT / f'{name}_tts.wav'
    ps = (
        "Add-Type -AssemblyName System.Speech;"
        "$s=New-Object System.Speech.Synthesis.SpeechSynthesizer;"
        "$s.SelectVoice('Microsoft Hazel Desktop');$s.Rate=-2;"
        "$f=New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050,"
        "[System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,[System.Speech.AudioFormat.AudioChannel]::Mono);"
        f"$s.SetOutputToWaveFile('{wav.resolve()}',$f);$s.Speak('{text}');$s.Dispose()")
    subprocess.run(['powershell', '-NoProfile', '-Command', ps], check=True)
    with wave.open(str(wav)) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768
        sr = w.getframerate()
    return x, sr

def process(x, sr):
    # trim silence
    a = np.abs(x); keep = np.where(a > 0.02)[0]
    x = x[max(0, keep[0] - 200):keep[-1] + 400]
    # a station AI: a little ring modulation and a lower, harder edge
    t = np.arange(len(x)) / sr
    x = x * (0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 55 * t)))
    # resample to the player's rate
    n = int(len(x) * RATE / sr)
    x = np.interp(np.linspace(0, len(x) - 1, n), np.arange(len(x)), x)
    # band-limit (speech 200 Hz .. 3.4 kHz) with simple one-pole filters
    def lp(v, fc):
        k = np.exp(-2 * np.pi * fc / RATE); y = np.zeros_like(v); s = 0.0
        for i, s_in in enumerate(v): s = s * k + s_in * (1 - k); y[i] = s
        return y
    x = lp(x, 3400); x = x - lp(x, 200)
    # compress and normalise: a 1-bit speaker needs it loud and even
    x = np.tanh(3.0 * x / (np.max(np.abs(x)) + 1e-9))
    return x / np.max(np.abs(x))

MODE = 'clipped'

def clipped(x):
    """The sign of the voice, with a little hysteresis so silence stays silent."""
    e = np.concatenate([[x[0]], x[1:] - 0.85 * x[:-1]])      # pre-emphasis: crisper consonants
    e = e / (np.max(np.abs(e)) + 1e-9)
    bits = np.zeros(len(e), dtype=np.uint8); b = 0
    for i, v in enumerate(e):
        if v > 0.04: b = 1
        elif v < -0.04: b = 0
        bits[i] = b
    return bits

def sigma_delta(x):
    """First-order delta-sigma: bits whose running average follows x."""
    bits = np.zeros(len(x), dtype=np.uint8); integ = 0.0
    for i, v in enumerate(x):
        integ += v * 0.9
        b = 1 if integ >= 0 else 0
        integ -= 1 if b else -1
        bits[i] = b
    return bits

def preview(bits, path):
    y = bits.astype(np.float64) * 2 - 1
    k = np.exp(-2 * np.pi * (3500 if MODE == 'sigma' else 7000) / RATE); s = 0.0; out = np.zeros_like(y)
    for i, v in enumerate(y): s = s * k + v * (1 - k); out[i] = s
    with wave.open(str(path), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(int(RATE))
        w.writeframes((np.clip(out, -1, 1) * 20000).astype(np.int16).tobytes())

meta = {}
for name, text in LINES.items():
    x, sr = synth(name, text)
    bits = (sigma_delta if MODE == 'sigma' else clipped)(process(x, sr))
    pad = (-len(bits)) % 8
    bits = np.concatenate([bits, np.zeros(pad, dtype=np.uint8)])
    data = np.packbits(bits).tobytes()
    (OUT / f'{name}.bin').write_bytes(data)
    preview(bits, OUT / f'{name}_preview.wav')
    meta[name] = len(data)
    print(f'{name:9s} {len(data):6d} bytes  {len(bits) / RATE:4.2f} s  "{text}"')
(OUT / 'lines.json').write_text(json.dumps(meta))
print('total', sum(meta.values()), 'bytes')
