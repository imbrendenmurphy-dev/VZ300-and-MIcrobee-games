"""Speaker check: record the title tune and a stretch of the demo to WAV."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
pp = boot(); S = pp.S
pp.run_frames(20); pp.keys = ['C']; pp.run_frames(4); pp.keys = []
pp.speaker(clear=True)
t0 = pp.tick
pp.run_frames(500)
t, v = pp.speaker()
print('title: %d speaker edges in 10 s' % len(t))
pp.wav(BUILD / 'title.wav', t0=t0)
pp.speaker(clear=True)
pp.run_frames(1900 - 500 + 100)
pp.speaker(clear=True)
t0 = pp.tick
pp.run_frames(600)
t, v = pp.speaker()
print('demo: %d speaker edges in 12 s' % len(t))
pp.wav(BUILD / 'demo.wav', t0=t0)
