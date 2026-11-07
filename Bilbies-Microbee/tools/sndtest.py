"""Speaker pitch test in a running level: each VZ tone rate is played for
6 game updates and the speaker toggles are counted; the measured
frequency is compared with the VZ's (rate * 6300 / 65536 Hz)."""
import sys
import run

RATES = [1900, 3000, 5200, 7800, 9000, 12000, 14000, 16000, 20000]


def tone_test(level=5, rates=RATES, wav=None):
    pp = run.boot(level=level, mode=2)
    S = pp.S
    pp.run_frames(150)
    buf = S['BOUNCE']
    res = []
    for r in rates:
        k = 274289 * 10 // 15 if r > 13000 else 274289 * 10 // 12 if r > 10000 else 274289 * 112 // 100 if r < 4000 else 274289
        units = (k + r // 2) // r      # as the TN macro in src/sound.asm
        script = [1, units] * 6 + [0]
        for i, b in enumerate(script):
            pp.poke(buf + i, b)
        pp.poke(S['sfx_ptr'], buf & 255)
        pp.poke(S['sfx_ptr'] + 1, buf >> 8)
        pp.speaker(clear=True)
        t0 = pp.tick
        pp.run_frames(4 * 6)
        t, v = pp.speaker()
        t = [x for x in t if x >= t0]
        if len(t) > 4:
            dur = (t[-1] - t[0]) / 3375000
            f = (len(t) - 1) / 2 / dur
        else:
            f = 0
        want = r * 6300 / 65536
        res.append((r, want, f))
        print('rate %5d  VZ %6.0f Hz  Microbee %6.0f Hz  (%+.0f%%)' % (r, want, f, 100 * (f / want - 1)))
        pp.run_frames(8)
    return res


if __name__ == '__main__':
    tone_test(int(sys.argv[1]) if len(sys.argv) > 1 else 5)
