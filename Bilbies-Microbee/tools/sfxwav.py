"""Render every sound effect, played during a running level in the model,
into one WAV file (build/sfx.wav), with a gap between effects."""
import run
from savetest import call
import savetest


def main(out=run.BUILD / 'sfx.wav'):
    pp = run.boot(level=5, mode=2)
    S = pp.S
    savetest.S = S
    pp.run_frames(150)
    t0 = pp.tick
    for n in range(1, 12):
        pp.cpu.a = n
        call(pp, 'sfx_play', 5)
        pp.run_frames(60)
    pp.wav(out, t0)
    print('wrote', out)


if __name__ == '__main__':
    main()
