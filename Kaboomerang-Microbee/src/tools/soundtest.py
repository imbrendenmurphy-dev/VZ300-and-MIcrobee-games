"""Record the soundscape: a bomb fizzing and going KABOOM, then a pickup
ching. -> build/sound_demo.wav"""
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run import boot, peek, BUILD
from mbee import KEY

pp = boot(test=True)
pp.run_frames(130)                     # through GET READY
pp.speaker(clear=True)
t0 = pp.tick
pp.keys = [KEY['SPACE']]
pp.run_frames(4)
pp.keys = [KEY['RIGHT'] if 'RIGHT' in KEY else KEY['P']]
pp.run_frames(14)
pp.keys = []
pp.run_frames(150)                     # fuse hiss ... KABOOM
# a ching: call play_sfx(SFX_PICKUP) by poking the effect in
S = pp.S
tab = S['sfxtab'] + 4 * 8
for i, n in enumerate(['sfxstep', 'sfxstep+1']):
    pass
st = int.from_bytes(bytes(pp.peek(tab + i) for i in range(2)), 'little')
de = int.from_bytes(bytes(pp.peek(tab + 2 + i) for i in range(2)), 'little')
for a, v in ((S['sfxstep'], st & 255), (S['sfxstep'] + 1, st >> 8), (S['sfxdelta'], de & 255),
             (S['sfxdelta'] + 1, de >> 8), (S['sfxleft'], 8), (S['sfxmode'], 5), (S['sfxprio'], 5)):
    pp.poke(a, v)
pp.run_frames(25)
t, v = pp.speaker()
print('speaker events', len(t), 'hearts', peek(pp, 'p_hearts'))
pp.wav(BUILD / 'sound_demo.wav', t0=t0)
# loudness per 40 ms
import wave
w = wave.open(str(BUILD / 'sound_demo.wav'))
x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(float)
seg = 882
env = [int(np.sqrt(np.mean(x[i:i + seg] ** 2))) for i in range(0, len(x) - seg, seg)]
print(' '.join(str(e // 100) for e in env))
