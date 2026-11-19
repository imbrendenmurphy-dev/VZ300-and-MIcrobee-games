"""wav.py - record the sound chip in the simulator and write a WAV file.

    py tools/wav.py [seconds] [out.wav]

Runs the attract mode from power-on (title music) and renders the 8253
counter-0 square wave, gated by E008h, at 22050 Hz.
"""
import os
import struct
import sys
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from run import Game  # noqa: E402
from mzsim import CPU_HZ  # noqa: E402

secs = float(sys.argv[1]) if len(sys.argv) > 1 else 30
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'build', 'title_music.wav')
g = Game()
m = g.m
m.sound_log = []
t0 = m.cpu.t
g.run(secs * 50)
log = m.sound_log
RATE = 22050
CLK = 1108800
n = int(secs * RATE)
samples = bytearray()
i = 0
gate, div = 0, 0
phase = 0.0
for k in range(n):
    t = t0 + k * CPU_HZ / RATE
    while i < len(log) and log[i][0] <= t:
        _, gate, div = log[i]
        i += 1
    if gate and div > 1:
        f = CLK / div
        phase = (phase + f / RATE) % 1.0
        v = 90 if phase < 0.5 else -90
    else:
        v = 0
    samples.append((v + 128) & 0xFF)
with wave.open(out, 'wb') as w:
    w.setnchannels(1)
    w.setsampwidth(1)
    w.setframerate(RATE)
    w.writeframes(bytes(samples))
print('wrote', out, len(samples) / RATE, 's,', len(log), 'events')
