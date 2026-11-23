"""Record every sound effect from the emulator model's speaker.

    py tools/sfxdemo.py [out.wav]       all effects, music off, 0.6 s apart
    py tools/sfxdemo.py out.wav --step  also: footsteps and turns in play
Effects are started the way the game does (sfx_pend), on the title
screen with the music silenced."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import rd
import audio

ROOT = Path(__file__).resolve().parent.parent
NAMES = ['sfx_step', 'sfx_turn', 'sfx_bump', 'sfx_door', 'sfx_unlock', 'sfx_swing', 'sfx_hit', 'sfx_kill',
         'sfx_hurt', 'sfx_coin', 'sfx_pickup', 'sfx_fanfare', 'sfx_sigil', 'sfx_levelup', 'sfx_lever',
         'sfx_gate', 'sfx_rune', 'sfx_wrong', 'sfx_heal', 'sfx_fire', 'sfx_stairs', 'sfx_fall', 'sfx_portal',
         'sfx_spin']


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'docs' / 'audio' / 'effects.wav'
    pp = rd.boot()
    S = pp.S
    pp.run_frames(100)
    pp.poke(S['snd_mode'], 1)            # effects only
    pp.poke(S['mus_on'], 0)
    pp.run_frames(5)
    t0 = pp.tick
    for n in NAMES:
        a = S[n]
        pp.poke(S['sfx_pend'], a & 255)
        pp.poke(S['sfx_pend'] + 1, a >> 8)
        pp.run_frames(30)
    if '--step' in sys.argv:
        pp.poke(S['snd_mode'], 2)
        pp.keys = {'SPACE'}
        pp.run_frames(3)
        pp.keys = set()
        pp.run_frames(80)
        pp.poke(S['mus_on'], 0)
        pp.poke(S['snd_mode'], 1)
        for k in ['UP', 'RIGHT', 'UP', 'LEFT', 'LEFT', 'UP', 'RIGHT', 'UP']:
            pp.keys = {k}
            pp.run_frames(3)
            pp.keys = set()
            pp.run_frames(25)
    audio.wav(pp, out, t0, pp.tick)
    print('wrote', out, '%.1f s' % ((pp.tick - t0) / 3375000))


if __name__ == '__main__':
    main()
