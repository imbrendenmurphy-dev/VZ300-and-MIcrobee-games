"""Original two-channel beeper tunes for Blackout Protocol -> src/music.inc

Player (src/sound.asm, mus_play): one loop pass every LOOP_T T-states; each
channel's square wave flips every `period` passes.  An event is
  dw passes ; db period1, period2      (period 0 = silent)   ... dw 0 ends.
Notes are written as 'A4', 'C#5', '-' (rest); durations in sixteenths.
"""
from pathlib import Path

CPU = 3375000
LOOP_T = 120                      # measured: 122 counted, ~2% sharp in practice                      # T-states per pass of mus_play's loop (counted in sound.asm)
PASS_HZ = CPU / LOOP_T
NAMES = {'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5, 'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11}

def freq(n):
    name, octv = n[:-1], int(n[-1])
    return 440.0 * 2 ** ((NAMES[name] + 12 * (octv + 1) - 69) / 12)

def period(n):
    if n == '-': return 0
    p = round(PASS_HZ / (2 * freq(n)))
    assert 2 <= p <= 255, (n, p)
    return p

def tune(bpm, voices, gap=0.12):
    gaps = gap if isinstance(gap, tuple) else (gap, gap)
    """voices: two lists of (note, sixteenths).  Merged into events where either changes;
    each note is cut short by `gap` of its length (a little articulation)."""
    sixteenth = 60 / bpm / 4
    def timeline(v, g):
        out, t = [], 0.0
        for n, d in v:
            length = d * sixteenth
            on = length * (1 - g) if n != '-' and g else length
            out.append((t, n)); out.append((t + on, '-'))
            t += length
        return out, t
    a, ta = timeline(voices[0], gaps[0]); b, tb = timeline(voices[1], gaps[1])
    end = max(ta, tb)
    times = sorted(set([t for t, _ in a] + [t for t, _ in b] + [end]))
    def at(tl, t):
        cur = '-'
        for tt, n in tl:
            if tt <= t + 1e-9: cur = n
        return cur
    ev = []
    for i in range(len(times) - 1):
        t0, t1 = times[i], times[i + 1]
        passes = round((t1 - t0) * PASS_HZ)
        if passes <= 0: continue
        while passes > 65535:
            ev.append((65535, period(at(a, t0)), period(at(b, t0)))); passes -= 65535
        ev.append((passes, period(at(a, t0)), period(at(b, t0))))
    return ev

def seq(s):
    """'A4:2 C5:2 -:4' -> [('A4', 2), ('C5', 2), ('-', 4)]"""
    out = []
    for tok in s.split():
        n, d = tok.split(':'); out.append((n, int(d)))
    return out

TUNES = {
    # wrist-deck: a quiet ticking arpeggio
    'mus_deck': tune(110, [
        seq('C5:2 G4:2 D#5:2 G4:2 D5:2 G4:2 C5:2 G4:2 G#4:2 D#4:2 C5:2 D#4:2 B4:2 D4:2 G4:2 D4:2'),
        seq('C3:8 C3:8 G#2:8 G2:8')]),
    # mission accomplished
    'mus_win': tune(132, [
        seq('C5:2 E5:2 G5:2 C6:6 -:2 A5:2 B5:2 C6:2 D6:4 E6:8'),
        seq('C3:4 G3:4 C4:6 -:2 F3:4 G3:4 C3:8')]),
    # the grid goes dark
    'mus_lose': tune(70, [
        seq('E5:4 D#5:4 D5:4 C#5:4 C5:8 B4:8 A4:16'),
        seq('A2:8 G#2:8 G2:8 F#2:8 F2:16')]),
    # stings: first time into a wing, a key coming online
    'mus_dock': tune(140, [seq('E5:2 G5:2 B5:4 A5:2 E5:6'), seq('E3:4 B2:4 E3:8')]),
    'mus_habitat': tune(120, [seq('G4:2 C5:2 E5:2 G5:6 F5:2 D5:4'), seq('C3:8 G2:8 C3:2')]),
    'mus_core': tune(80, [seq('A4:4 A#4:4 A4:4 G#4:4 A4:8'), seq('D2:8 D#2:8 D2:8')]),
    'mus_keyok': tune(150, [seq('C5:1 E5:1 G5:1 C6:3 G5:1 C6:5'), seq('C4:4 G3:4 C4:4')]),
}

# ---------------------------------------------------------------- the title
# "Halcyon Array", ~90 s, played once on the title page before the attract demo.
# Intro, theme (A), a brighter middle (B), a quiet bridge, the theme again over a
# walking bass, and an ending.  Melody kept low and legato-ish so it sings rather
# than bleeps; the bass alternates octaves so it can run legato too.
def bars(chords, pat):
    """pat: a bass bar using R (root), F (fifth), r/f an octave up."""
    ROOT = {'Am': ('A2', 'E3', 'A3', 'E3'), 'F': ('F2', 'C3', 'F3', 'C3'), 'C': ('C3', 'G2', 'C4', 'G3'),
            'G': ('G2', 'D3', 'G3', 'D3'), 'E': ('E2', 'B2', 'E3', 'B2'), 'Em': ('E2', 'B2', 'E3', 'B2'),
            'Dm': ('D2', 'A2', 'D3', 'A2')}
    out = []
    for ch in chords:
        R, F, r, f = ROOT[ch]
        out += [{'R': R, 'F': F, 'r': r, 'f': f}[c] + ':' + d for c, d in (x.split(':') for x in pat.split())]
    return ' '.join(out)
TITLE_MEL = ' '.join([
    # intro: pings over the pulse
    '-:8 E5:2 -:6  -:8 A5:2 -:6  -:8 C5:2 -:6  B4:2 -:2 G#4:2 -:10',
    # A
    'E5:4 A5:4 G5:2 E5:2 C5:4  D5:6 C5:2 A4:8  G4:4 C5:4 E5:4 G5:4  F5:6 E5:2 D5:8',
    'E5:4 A5:4 B5:2 C6:2 B5:4  A5:6 G5:2 F5:4 E5:4  D5:4 C5:4 B4:4 G#4:4  B4:16',
    # B
    'G5:4 E5:4 C5:4 E5:4  D5:4 B4:4 G4:4 B4:4  C5:4 E5:4 A5:4 E5:4  B4:8 G4:8',
    'A4:2 C5:2 F5:4 A5:4 F5:4  G5:4 E5:4 C5:8  D5:4 F5:4 A5:4 F5:4  G#5:8 E5:8',
    # bridge
    'C5:16  D5:16  B4:16  A4:8 E4:8',
    # A again
    'E5:4 A5:4 G5:2 E5:2 C5:4  D5:6 C5:2 A4:8  G4:4 C5:4 E5:4 G5:4  F5:4 E5:2 F5:2 G5:8',
    'E5:4 A5:4 B5:2 C6:2 B5:4  A5:6 G5:2 F5:4 E5:4  D5:4 C5:4 B4:4 D5:4  C5:4 B4:4 G#4:8',
    # ending
    'E5:8 C5:8  A4:8 C5:8  B4:8 G#4:8  A4:16'])
TITLE_BASS = ' '.join([
    bars(['Am', 'Am', 'F', 'E'], 'R:2 r:2 R:2 r:2 R:2 r:2 R:2 r:2'),
    bars(['Am', 'F', 'C', 'G', 'Am', 'F', 'E', 'E'], 'R:2 r:2 R:2 r:2 R:2 r:2 R:2 r:2'),
    bars(['C', 'G', 'Am', 'Em', 'F', 'C', 'Dm', 'E'], 'R:2 F:2 r:2 F:2 R:2 F:2 r:2 F:2'),
    bars(['F', 'G', 'Em', 'Am'], 'R:8 F:8'),
    bars(['Am', 'F', 'C', 'G', 'Am', 'F', 'E', 'E'], 'R:4 F:4 r:4 F:4'),
    bars(['Am', 'F', 'E', 'Am'], 'R:16')])
title = tune(92, [seq(TITLE_MEL), seq(TITLE_BASS)], gap=(0.1, 0.0))
blob = b''.join(passes.to_bytes(2, 'little') + bytes([p1, p2]) for passes, p1, p2 in title) + b'\0\0'
assert len(blob) <= 2048, len(blob)        # it plays from the 2 KB scratch buffer at D800
Path('build').mkdir(exist_ok=True); Path('build/title.mus').write_bytes(blob)
secs = sum(e[0] for e in title) / PASS_HZ
print(f'title: {len(title)} events, {len(blob)} bytes, {secs:.0f} s')

out = ['; generated by tools/music.py - original tunes for Blackout Protocol']
for name, ev in TUNES.items():
    out.append(f'{name}:')
    for passes, p1, p2 in ev:
        out.append(f'        dw {passes}\n        db {p1},{p2}')
    out.append('        dw 0')
Path('src/music.inc').write_text('\n'.join(out) + '\n')
print({k: len(v) for k, v in TUNES.items()}, 'events;', sum(4 * len(v) + 2 for v in TUNES.values()), 'bytes')
