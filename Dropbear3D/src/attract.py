"""Runs one whole attract cycle untouched: title + music, gallery, demo. Saves screens and the music as a WAV."""
import pickle, wave, struct, sys
import numpy as np
from z80tools import Z80
from PIL import Image
P = pickle.load(open('image.pkl', 'rb')); S = P['syms']
PAL = {0: [(48, 210, 0), (193, 229, 0), (76, 58, 180), (170, 50, 54)],
       1: [(214, 206, 160), (60, 190, 160), (190, 60, 190), (220, 110, 30)]}
def shot(z, scale=6):
    pal = PAL[(z.latch >> 4) & 1]; im = Image.new('RGB', (128, 64))
    for y in range(64):
        for xb in range(32):
            b = z.m[0x7000+y*32+xb]
            for i in range(4): im.putpixel((xb*4+i, y), pal[(b >> (6-2*i)) & 3])
    return im.resize((128*scale, 96*scale), Image.NEAREST)
z = Z80(bytearray(65536)); z.m[0x8000:0x8000+len(P['body'])] = P['body']; z.pc = 0x8000
spk = []; orig = z.wr
def wr(a, v):
    if 0x6800 <= a < 0x7000: spk.append((z.t, (v & 1) - ((v >> 5) & 1)))
    orig(a, v)
z.wr = wr
marks = {S[n]: n for n in ('titlescreen', 'playmus', 'gallery', 'gdraw', 'demo', 'gameframe', 'newgame2')}
log = []; shots = {}; ntitle = 0; gcount = 0; frames = 0; mus_t = [None, None]; gal_t0 = None; demo_frames = []
while True:
    n = marks.get(z.pc)
    if n == 'titlescreen':
        ntitle += 1; log.append('%.1f s: title %d' % (z.t/3546900, ntitle))
        if ntitle == int(sys.argv[1] if len(sys.argv) > 1 else 2): break
    elif n == 'playmus':
        mus_t[0] = z.t; shots['title'] = shot(z)
    elif n == 'gallery':
        mus_t[1] = z.t; log.append('%.1f s: gallery (music lasted %.1f s)' % (z.t/3546900, (z.t-mus_t[0])/3546900))
    elif n == 'gdraw':
        gcount += 1
        if gcount % 8 == 2: shots['gal%02d' % (gcount//8)] = None; pend = z.t
    elif n == 'demo': log.append('%.1f s: demo' % (z.t/3546900))
    elif n == 'gameframe':
        frames += 1
        if frames % 5 == 0 and len(demo_frames) < 250: demo_frames.append(shot(z, 3))
        if z.m[S['area']] != getattr(z, 'lastarea', -1): z.lastarea = z.m[S['area']]; log.append('   demo in area %d' % z.lastarea)
        if frames % 420 in (60, 200, 360): shots['demo%d' % frames] = shot(z)
    z.step()
    for k in [k for k, v in shots.items() if v is None]:
        if z.t - pend > 400000: shots[k] = shot(z)
print('\n'.join(log)); print('demo frames played:', frames, ' demo area:', P['areas'][z.m[S['dsa']]]['name'] if False else z.m[S['dsa']])
for k, im in shots.items():
    if im is not None: im.save('att_%s.png' % k)
if demo_frames: demo_frames[0].save('att_demo.gif', save_all=True, append_images=demo_frames[1:], duration=300, loop=0)
# render the speaker to audio
t0, t1 = mus_t; rate = 44100; clk = 3546900
ev = [(t, l) for t, l in spk if t0 <= t <= t1]
n = int((t1-t0)/clk*rate)+1
lev = np.zeros(n); cur = 0; last = t0; idx = 0
ts = np.array([t for t, l in ev], dtype=np.float64); ls = np.array([l for t, l in ev], dtype=np.float64)
# exact box-filter integration of the speaker level over each sample
edges = t0 + np.arange(n+1)*clk/rate
cum_t = np.concatenate([[t0], ts, [t1]]); cum_l = np.concatenate([[0], ls])
seg_area = np.diff(cum_t)*cum_l
cum = np.concatenate([[0], np.cumsum(seg_area)])
def area_at(x):
    i = np.searchsorted(cum_t, x, side='right')-1; i = np.clip(i, 0, len(cum_l)-1)
    return cum[i] + (x-cum_t[i])*cum_l[i]
a = area_at(edges); lev = np.diff(a)/(clk/rate)
lev = lev - np.mean(lev)
b_ = np.ones(4)/4; lev = np.convolve(lev, b_, mode='same')
lev = lev/ (np.max(np.abs(lev))+1e-9)*0.8
with wave.open('title_music.wav', 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
    w.writeframes(b''.join(struct.pack('<h', int(x*32767)) for x in lev))
# check pitch of the opening heartbeat (A1, 55 Hz expected)
seg = lev[int(0.05*rate):int(0.17*rate)]
sp = np.abs(np.fft.rfft(seg*np.hanning(len(seg)), 1 << 16)); fr = np.fft.rfftfreq(1 << 16, 1/rate)
m = (fr > 30) & (fr < 400); print('opening note peak at %.1f Hz' % fr[m][np.argmax(sp[m])])
seg = lev[int(21*rate):int(22.5*rate)]
sp = np.abs(np.fft.rfft(seg*np.hanning(len(seg)), 1 << 16))
pk = sorted(fr[m][np.argsort(sp[m])[-40:]]); print('stinger strongest components:', [round(x) for x in pk[::8]])
