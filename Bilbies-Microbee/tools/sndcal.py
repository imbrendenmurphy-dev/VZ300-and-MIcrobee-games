"""Calibrate the speaker service (src/sound.asm): with the service forced
on, every SND call site is watched and the mean time since the previous
call (any site) is reported, in 64-T units, for the SND constants. Also
the speaker pitch check: a long tone is played and the toggles timed."""
import sys
import collections
import statistics
import run

SITES = None


def sites(S):
    return {v: k for k, v in S.items() if '.snd' in k and k.split('.snd')[1].isdigit()}


def measure(level=5, frames=100, warm=300, mode=2):
    pp = run.boot(level=level, mode=mode)
    S = pp.S
    pp.run_frames(warm)
    st = sites(S)
    # a long effect playing (tones and noise, as in the game)
    buf = S['BOUNCE']
    script = []
    for i in range(120):
        script += [1, (40, 20, 100, 60)[i % 4]] if i % 3 else [2, 30]
    for i, b in enumerate(script + [0]):
        pp.poke(buf + i, b)
    pp.poke(S['sfx_ptr'], buf & 255)
    pp.poke(S['sfx_ptr'] + 1, buf >> 8)
    for a in st:
        pp.watch(a)
    pp.run_frames(frames)
    ev = pp.events()
    gaps = collections.defaultdict(list)
    for (t0, _), (t1, p1) in zip(ev, ev[1:]):
        gaps[st[p1]].append(t1 - t0)
    return gaps, len(ev) / frames


if __name__ == '__main__':
    lv = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    g, per = measure(lv)
    print('level', lv, '%.0f calls per field' % per)
    for k in sorted(g, key=lambda k: int(k.split('.snd')[1])):
        d = g[k]
        print('%-22s n=%5d mean %6.0f T = %5.1f units  median %5.0f  max %6d' %
              (k, len(d), statistics.mean(d), statistics.mean(d) / 64, statistics.median(d), max(d)))
