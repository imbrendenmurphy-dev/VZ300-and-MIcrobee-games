"""SPINDRIFT's in-game music and effects -> build/GAMESND.BIN + src/snd.inc

They live in RAM block 7 from GAMESND (6000h), after the title music;
src/snd.inc names their addresses. snd_tick (src/sound.asm) reads them once
a frame; the voices sound while the frame waits for the vertical blanking.

The voices (src/sound.asm) step 16-bit phase counters once a sample:
a step is f * 65536 / SR, SR = 3375000 / SAMPLE_T.
  MELODY  the note and a hair over its octave, exclusive-or'd (a shimmer)
  BASS    a pulse; its duty plucks over the note's first frames
  FX      a pulse with a duty and a pitch glide (every 16 samples), or
          pitched noise (a new random bit each time its counter wraps)

An effect is frames: (kind, start Hz, duty or None, end Hz). Each frame
the pitch starts again from 'start' and glides toward 'end' at the rate
that gets there in a typical frame's idle time, so a dive, a squelch or a
wucka comes out smooth however busy the frame is.

All the music is original. A frame is 1/25 s.
"""
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLOCK = 3375000
SAMPLE_T = 264                  # the in-game loop (src/sound.asm), glide included
SR = CLOCK / SAMPLE_T
GAMESND = 0x6000
GLIDE_SAMPLES = 16
IDLE_SAMPLES = 90               # a typical frame's idle time, in samples
BASE_MIDI = 28                  # note index 1 = E1 (41 Hz)
NOTES = 72

NOTE = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8,
        'A': 9, 'A#': 10, 'B': 11}


def midi(name):
    return 12 * (int(name[-1]) + 1) + NOTE[name[:-1]]


def step(f):
    return max(0, min(65535, int(round(f * 65536.0 / SR))))


def idx(name):
    i = midi(name) - BASE_MIDI + 1
    assert 1 <= i <= NOTES, name
    return i


class Out:
    def __init__(self):
        self.d = bytearray()
        self.sym = {}

    def here(self):
        return GAMESND + len(self.d)

    def label(self, name):
        self.sym[name] = self.here()


O = Out()
O.label('NOTETAB')
for i in range(NOTES):
    O.d += struct.pack('<H', step(440.0 * 2 ** ((BASE_MIDI + i - 69) / 12.0)))


def chan(seq, unit):
    out = []
    for n, d in seq:
        out += [0 if n == 'R' else idx(n), d * unit]
    return out


def tune(name, mel, bass, unit, gate, loop=True, check=None):
    la = sum(d for _, d in mel)
    lb = sum(d for _, d in bass)
    if check:
        assert la == lb == check, (name, la, lb, check)
    end = [0xFE] if loop else [0xFF]
    a, b = chan(mel, unit) + end, chan(bass, unit) + end
    O.label(name)
    hdr = len(O.d)
    O.d += bytes(5)
    pa = O.here()
    O.d += bytes(a)
    pb = O.here()
    O.d += bytes(b)
    O.d[hdr:hdr + 5] = struct.pack('<HHB', pa, pb, gate)


# ---- in the waves: slow and suspenseful ("dink, dink-dink-dink") over a
# plucked bass on the title's Am - G - F - E
mel = [('A3', 6), ('A3', 2), ('C4', 2), ('E4', 6),
       ('G3', 6), ('G3', 2), ('B3', 2), ('D4', 6),
       ('F3', 6), ('F3', 2), ('A3', 2), ('C4', 6),
       ('E3', 6), ('E3', 2), ('G#3', 2), ('B3', 4), ('E4', 2)]
bass = [('A1', 8), ('A1', 4), ('E2', 4), ('G1', 8), ('G1', 4), ('D2', 4),
        ('F1', 8), ('F1', 4), ('C2', 4), ('E1', 8), ('E1', 4), ('B1', 4)]
tune('tune_wave', mel, bass, 3, 2, check=64)

# ---- the Guardian: lower, quicker, uneasy
mel = [('D3', 2), ('D3', 1), ('F3', 1), ('G#3', 2), ('A3', 2),
       ('D3', 2), ('D3', 1), ('F3', 1), ('A#3', 2), ('A3', 2),
       ('D3', 2), ('D3', 1), ('F3', 1), ('G#3', 2), ('A3', 1), ('C4', 1),
       ('D4', 2), ('C4', 1), ('A#3', 1), ('A3', 2), ('G#3', 2)]
bass = ([('D2', 2), ('D3', 2)] * 3 + [('A#1', 2), ('A1', 2)] + [('D2', 2), ('D3', 2)] * 2 +
        [('A#1', 2), ('A1', 2), ('G#1', 2), ('A1', 2)])
tune('tune_boss', mel, bass, 3, 2, check=32)

# ---- the chance stage: bright and bouncy
mel = [('C5', 1), ('E5', 1), ('G5', 1), ('C6', 1), ('G5', 1), ('E5', 1), ('G5', 2),
       ('F5', 1), ('A5', 1), ('C6', 1), ('F5', 1), ('E5', 1), ('G5', 1), ('C6', 2),
       ('D5', 1), ('F5', 1), ('A5', 1), ('D6', 1), ('B5', 1), ('G5', 1), ('B5', 2),
       ('C6', 2), ('G5', 1), ('E5', 1), ('C5', 2), ('R', 2)]
bass = [('C2', 2), ('G2', 2), ('C2', 2), ('G2', 2), ('F2', 2), ('C3', 2), ('C2', 2), ('G2', 2),
        ('D2', 2), ('A2', 2), ('G2', 2), ('D2', 2), ('C2', 2), ('G2', 2), ('C2', 4)]
tune('tune_bonus', mel, bass, 3, 2, check=32)

# ---- jingles
mel = [('E4', 1), ('A4', 1), ('C5', 1), ('E5', 2), ('D5', 1), ('E5', 4)]
bass = [('A1', 2), ('E2', 2), ('A2', 6)]
tune('tune_sector', mel, bass, 4, 0, loop=False, check=10)
mel = [('C5', 1), ('E5', 1), ('G5', 1), ('C6', 3)]
bass = [('C2', 3), ('C3', 3)]
tune('tune_clear', mel, bass, 4, 0, loop=False, check=6)
mel = [('A4', 3), ('G4', 3), ('F4', 3), ('E4', 3), ('D4', 2), ('C#4', 2), ('D4', 6)]
bass = [('D2', 6), ('A1', 6), ('D2', 10)]
tune('tune_over', mel, bass, 4, 0, loop=False, check=22)
mel = [('E5', 2), ('G5', 2), ('A5', 4), ('G5', 2), ('E5', 2), ('D5', 4),
       ('C5', 2), ('D5', 2), ('E5', 4), ('G5', 4), ('A5', 4)]
bass = [('A2', 4), ('E2', 4), ('G2', 4), ('D2', 4), ('C2', 4), ('G2', 4), ('A2', 8)]
tune('tune_hi', mel, bass, 4, 0, check=32)


# ---- effects
def sfx(name, frames):
    """frames: ('t', start Hz, duty, end Hz) a tone gliding start -> end;
    ('n', rate Hz, None, end rate) pitched noise; ('-',) a silent frame"""
    O.label(name)
    for fr in frames:
        if fr[0] == '-':
            O.d += struct.pack('<BBHh', 1, 0, 0, 0)
            continue
        kind, f0, duty, f1 = fr
        s0, s1 = step(f0), step(f1)
        glide = int(round((s1 - s0) / (IDLE_SAMPLES / GLIDE_SAMPLES)))
        # never past zero, however long the idle time (at most ~15 glides)
        while s0 + 16 * glide < 8 and glide < 0:
            glide += 1
        while s0 + 16 * glide > 60000 and glide > 0:
            glide -= 1
        mode = 0x80 if kind == 'n' else max(1, min(127, duty))
        O.d += struct.pack('<BBHh', 1, mode, s0, glide)
    O.d += bytes([0])


def dive(f0, f1, n, duty0, duty1, kind='t'):
    """n frames gliding f0 -> f1 (exponentially), duty duty0 -> duty1"""
    out = []
    for i in range(n):
        a = f0 * (f1 / f0) ** (i / n)
        b = f0 * (f1 / f0) ** ((i + 1) / n)
        d = int(duty0 + (duty1 - duty0) * i / max(1, n - 1))
        out.append((kind, a, d, b))
    return out


def wucka(lo, hi, n, duty, kind='t'):
    """a wah: the pitch swings lo -> hi -> lo, a frame each way"""
    out = []
    for i in range(n):
        out.append((kind, lo, duty, hi) if i % 2 == 0 else (kind, hi, duty, lo))
    return out


# the shot: a spurt - a wet fizz, then a squelchy zip down
sfx('sfx_shot', [('n', 9000, None, 4000), ('t', 1700, 70, 600), ('t', 700, 40, 260)])
# enemy fire: a short rubbery bwip
sfx('sfx_efire', [('t', 330, 80, 760), ('t', 700, 40, 400)])
# an enemy bursts: a squelch - a fat dive, then the splat of noise
sfx('sfx_boom', [('t', 900, 110, 220), ('t', 260, 100, 70), ('n', 2600, None, 900), ('n', 1200, None, 500),
                 ('n', 600, None, 300)])
# armour: a bright ping
sfx('sfx_tink', [('t', 2600, 40, 2400), ('-',), ('t', 3100, 30, 2900)])
# an attack is coming: wucka-wucka, rising
sfx('sfx_warn', wucka(260, 420, 2, 100) + wucka(330, 540, 2, 100) + wucka(420, 700, 2, 90) + wucka(540, 900, 2, 80))
# the shield takes a hit: a crunch and a low squelch
sfx('sfx_shield', [('n', 1800, None, 600), ('t', 300, 120, 90), ('n', 700, None, 300), ('t', 160, 110, 60),
                   ('n', 400, None, 200)])
# the ship is lost: a long, sad squelch into rumble
sfx('sfx_die', [('n', 3000, None, 1000), ('n', 1400, None, 600)] + dive(700, 60, 8, 120, 60) +
    [('n', 900, None, 300), ('n', 500, None, 200), ('n', 300, None, 120), ('n', 200, None, 90)])
# an extra ship: rising wuckas
sfx('sfx_life', wucka(523, 600, 2, 70) + wucka(659, 760, 2, 70) + wucka(784, 900, 2, 70) + wucka(1046, 1200, 4, 60))
# a bonus: sparkling upward zips
sfx('sfx_bonus', [('t', 900, 50, 1400), ('t', 1100, 50, 1700), ('t', 1400, 45, 2100), ('t', 1800, 40, 2700),
                  ('t', 2100, 30, 3000)])
# the Guardian's siren: slow, deep wuckas
sfx('sfx_siren', wucka(180, 330, 10, 110))
# the warp: one long zip up
sfx('sfx_warp', [('t', 120 * 1.18 ** i, 90 - 2 * i, 120 * 1.18 ** (i + 1)) for i in range(24)])
# the eye opens: a gloopy wobble
sfx('sfx_eye', wucka(200, 320, 3, 120) + wucka(260, 420, 3, 110))
# the core is hit: a thud and a squelch
sfx('sfx_core', [('t', 500, 120, 120), ('n', 1500, None, 500), ('t', 300, 100, 80)])
# a menu blip
sfx('sfx_menu', [('t', 1500, 50, 1700)])

assert len(O.d) < 0x2000, len(O.d)
(ROOT / 'build').mkdir(exist_ok=True)
(ROOT / 'build' / 'GAMESND.BIN').write_bytes(bytes(O.d))
L = ['; generated by tools/mkmusic.py - do not edit (in RAM block 7)']
L.append('GAMESND     EQU $%04X' % GAMESND)
for k, v in O.sym.items():
    L.append('%-11s EQU $%04X' % (k, v))
(ROOT / 'src' / 'snd.inc').write_text('\n'.join(L) + '\n')
print('snd.inc written: in-game music and effects, %d bytes at %04Xh in block 7' % (len(O.d), GAMESND))
