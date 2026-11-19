"""STORMBELL sound tables -> src/snd.inc

Effects are built here as chains of 2 ms slices for the two generators
in src/sound.asm:

* the toggler flips the speaker every P + (random & M) counts. tog() turns "this pitch, this much grit, this long" into
  P, M, N; sweeping pitch and grit over a run of slices shapes a sound.
  (Half cycle: 223 + 13 counts, or 218 + 55 counts, T-states.)
* the mixer plays two pulse voices at about 109.5 T-states a sample. ring()
  strikes them (a bell is two tones a little out of tune with each
  other) and lets them fade.

Tunes are in the hirajoshi scale (A B C E F): a melody voice over a
bass voice on the title and ending, single plucked notes in the duels.
"""
import math
import random

CLK = 3375000.0
SRATE = CLK / 109.5             # the mixer's sample rate (97 T a sample + its checks)
SLICE_MS = 2.2
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}


def freq(name):
    n, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NAMES[n] + 12 * (o - 4) - 9) / 12.0)


def inc(f):
    return int(round(f * 65536.0 / SRATE))


# ---------------------------------------------------------------------
#  slices
# ---------------------------------------------------------------------
def tog(f, grit, ms):
    """one toggler slice: pitch f Hz, grit 0 (clean) .. 1 (noise)"""
    half = CLK / (2.0 * f)
    if half <= 3300:
        kind, ov, unit = 1, 223.0, 13.0
    else:
        kind, ov, unit = 2, 218.0, 55.0
    b = max(1.0, (half - ov) / unit)
    span = 2.0 * grit * b
    m = 0
    while m * 2 + 1 <= span and m < 255:
        m = m * 2 + 1
    p = int(round(b - m / 2.0))
    p = max(1, min(255, p))
    real = ov + unit * (p + m / 2.0)
    n = int(round(ms * 1e-3 * CLK / real))
    return (kind, p, m, max(1, min(255, n)))


def sweep(f0, f1, g0, g1, ms, curve=1.0, step=SLICE_MS):
    """pitch f0 -> f1 and grit g0 -> g1 over ms"""
    out = []
    t = 0.0
    while t < ms:
        k = (t / ms) ** curve
        f = f0 * (f1 / f0) ** k
        g = g0 + (g1 - g0) * k
        s = tog(f, g, step)
        out.append(s)
        kind, p, m, n = s
        ov, unit = (223.0, 13.0) if kind == 1 else (218.0, 55.0)
        t += n * (ov + unit * (p + m / 2.0)) / CLK * 1e3
    return out


def strike(f1, f2, w1, w2, fade1, fade2):
    return [(3, inc(f1), inc(f2), w1, w2, fade1, fade2)]


def ring(slices):
    out = []
    while slices > 0:
        out.append((4, min(255, slices)))
        slices -= 255
    return out


def thunder(seed=7):
    """a crack, then a rumble that rolls and dies away"""
    r = random.Random(seed)
    out = sweep(5200, 1600, 1.0, 1.0, 45, step=3.0)
    f = 420.0
    for i in range(170):
        k = i / 170.0
        # the rumble wanders, with a second and third roll
        swell = 1.0 + 0.9 * math.sin(k * 9.0) ** 2
        f = max(130.0, min(700.0, f * r.uniform(0.80, 1.22)))
        out.append(tog(f * swell * (1.0 - 0.55 * k), 1.0, 5.0))
    out += sweep(190, 125, 1.0, 0.6, 260, step=6.0)
    return out


# ---------------------------------------------------------------------
#  the effects: (name, priority, ticks the music waits, slices)
# ---------------------------------------------------------------------
SFX = [
    # a foot shifting in the duel: a soft scuff
    ('STEP', 1, 0, sweep(1500, 800, 1.0, 1.0, 5)),
    # a punch thrown: a quick bright swish
    ('PUNCH', 2, 0, sweep(5600, 2600, 1.0, 1.0, 13)),
    # a kick thrown: a longer swish that swells and falls
    ('KICK', 2, 0, sweep(2400, 5200, 1.0, 1.0, 9) + sweep(5200, 1500, 1.0, 1.0, 16)),
    # a punch lands: crack, a falling thump, a short dull tail
    ('HIT', 4, 0, sweep(6500, 4500, 1.0, 1.0, 3) + sweep(360, 125, 0.35, 0.12, 46, curve=0.7)
     + sweep(650, 300, 1.0, 1.0, 12)),
    # a kick lands: the same, heavier and longer
    ('HITK', 4, 0, sweep(5200, 3000, 1.0, 1.0, 6) + sweep(300, 120, 0.45, 0.15, 72, curve=0.6)
     + sweep(520, 200, 1.0, 1.0, 24)),
    # a blow blocked: a dry wooden knock
    ('BLOCK', 3, 0, sweep(7500, 7000, 1.0, 1.0, 1.5) + sweep(1250, 760, 0.10, 0.05, 9)
     + sweep(2200, 1400, 1.0, 1.0, 4)),
    # falling: the air going out
    ('FALL', 4, 0, sweep(3600, 700, 1.0, 1.0, 130, curve=0.8)),
    # the body lands: a boom and a rumble
    ('THUD', 5, 0, sweep(4000, 2500, 1.0, 1.0, 3) + sweep(240, 120, 0.5, 0.25, 85, curve=0.6)
     + sweep(420, 150, 1.0, 1.0, 60)),
    # the stage gong: a mallet stroke, then a long shimmer
    ('GONG', 6, 26, sweep(2600, 1200, 1.0, 1.0, 7) + strike(146.8, 146.8 * 2.71, 60, 44, 20, 13)
     + ring(250)),
    # the bell that starts a duel
    ('BELL', 6, 12, sweep(6000, 5000, 1.0, 1.0, 2) + strike(587.3, 587.3 * 2.76, 46, 30, 9, 6)
     + ring(120)),
    # a running foot: a low pat
    ('FOOT', 1, 0, sweep(900, 420, 1.0, 1.0, 7)),
    # thunder over the mountain
    ('THUNDER', 7, 44, thunder()),
    # the storm bell itself: three slow tolls
    ('TOLL', 7, 70, (sweep(3000, 1500, 1.0, 1.0, 6) + strike(220.0, 220.0 * 2.74, 62, 46, 22, 14)
                     + ring(330)) * 3),
]

# ---------------------------------------------------------------------
#  tunes
# ---------------------------------------------------------------------
NOTES = []


def track(s):
    out = []
    for tok in s.split():
        if tok == '|':
            continue
        n, t = tok.split(':')
        if n != '.' and n not in NOTES:
            NOTES.append(n)
        out.append((0 if n == '.' else NOTES.index(n) + 1, int(t)))
    return out


def length(t):
    return sum(n for _, n in t)


# name: (melody, bass or None, melody width, fade, bass width, fade)
TUNES = {
    'title': (track("E4:4 F4:4 E4:8 | C4:4 B3:4 A3:8 | A3:4 B3:4 C4:4 E4:4 | F4:8 E4:8 | "
                    "A4:4 F4:4 E4:8 | C4:4 E4:4 B3:8 | C4:4 B3:4 A3:4 F3:4 | A3:12 .:4 | "
                    "E4:4 F4:4 A4:8 | B4:4 A4:4 F4:8 | E4:4 C4:4 B3:4 C4:4 | E4:8 .:8 | "
                    "A4:4 B4:4 C5:8 | B4:4 A4:4 F4:8 | E4:4 F4:4 E4:4 B3:4 | A3:12 .:4"),
              track("A2:8 E3:8 | A2:8 E3:8 | F2:8 C3:8 | F2:8 E3:8 | "
                    "A2:8 E3:8 | C3:8 E3:8 | F2:8 E2:8 | A2:8 A2:4 E3:4 | "
                    "A2:8 E3:8 | F2:8 C3:8 | C3:8 E3:8 | E2:8 B2:4 E3:4 | "
                    "A2:8 E3:8 | F2:8 C3:8 | E2:8 B2:8 | A2:8 A2:4 E3:4"),
              40, 6, 50, 9),
    'end': (track("A3:4 C4:4 E4:8 | F4:4 E4:4 C4:8 | E4:4 A4:4 B4:8 | C5:8 B4:4 A4:4 | "
                  "F4:4 A4:4 C5:8 | B4:4 A4:4 E4:8 | F4:4 E4:4 C4:4 B3:4 | A3:12 .:4"),
            track("A2:8 E3:8 | F2:8 C3:8 | A2:8 E3:8 | A2:8 E3:8 | "
                  "F2:8 C3:8 | E2:8 B2:8 | F2:8 E2:8 | A2:8 A2:4 E3:4"),
            40, 7, 50, 10),
    # in a duel: single low plucks, slow and spaced
    'fight': (track("A2:10 .:6 A2:4 B2:4 C3:10 .:10 A2:10 .:6 A2:4 C3:4 E3:10 .:14 "
                    "F3:10 .:6 E3:4 C3:4 B2:10 .:10 C3:8 B2:8 A2:8 E2:10 .:18"),
              None, 44, 1, 0, 1),
    'boss': (track("A2:6 A2:6 .:4 B2:6 A2:6 .:10 A2:6 A2:6 .:4 C3:6 B2:6 .:10 "
                   "E3:6 E3:6 .:4 F3:6 E3:6 .:6 C3:4 B2:4 A2:12 .:16"),
             None, 44, 1, 0, 1),
    'win': (track("A3:4 C4:4 E4:4 A4:12 .:6 F4:4 E4:4 A4:16 .:200"),
            track("A2:12 E3:12 .:6 F2:8 A2:16 .:200"), 40, 5, 50, 8),
    'lose': (track("E4:8 C4:8 B3:8 A3:20 .:250"),
             track("A2:16 F2:8 E2:20 .:250"), 40, 6, 50, 9),
}


def build(out):
    L = ['; generated by tools/music.py']
    for i, (n, pri, hold, steps) in enumerate(SFX):
        L.append('SFX_%s equ %d' % (n, i))
    L.append('sfxtab:')
    L.append('\tdw ' + ','.join('sx_' + s[0].lower() for s in SFX))
    total = 0
    for n, pri, hold, steps in SFX:
        L.append('sx_%s:\tdb %d,%d' % (n.lower(), pri, hold))
        total += 3
        for s in steps:
            if s[0] == 3:
                L.append('\tdb 3\n\tdw %d,%d\n\tdb %d,%d,%d,%d' % s[1:])
                total += 9
            else:
                L.append('\tdb ' + ','.join(str(v) for v in s))
                total += len(s)
        L.append('\tdb 0')
    L.append('; notes: the mixer\'s phase step')
    L.append('notetab:')
    for nm in NOTES:
        L.append('\tdw %d\t; %s' % (inc(freq(nm)), nm))
    for name, (mel, bass, w1, f1, w2, f2) in TUNES.items():
        if bass:
            assert length(mel) == length(bass), (name, length(mel), length(bass))
        L.append('tune_%s:' % name)
        L.append('\tdw tm_%s,%s' % (name, 'tb_%s' % name if bass else '0'))
        L.append('\tdb %d,%d,%d,%d' % (w1, f1, w2, f2))
        L.append('tm_%s:\tdb ' % name + ','.join('%d,%d' % nt for nt in mel) + ',$FF')
        if bass:
            L.append('tb_%s:\tdb ' % name + ','.join('%d,%d' % nt for nt in bass) + ',$FF')
            total += len(bass) * 2
        total += len(mel) * 2 + 10
    open(out, 'w').write('\n'.join(L) + '\n')
    print('  sound tables: %d effects, %d tunes, about %d bytes' % (len(SFX), len(TUNES), total))
