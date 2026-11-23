"""OVERRIDE music: songs for the three-voice pulse player (the engine from
Dracula's Castle II; same stream format). All tunes are original.

Channel string tokens:
  i<n>      instrument n
  u<n>      unit = n ticks (lengths below are multiplied); a tick is one field (1/50 s)
  NOTE:len  e.g. A4:3  C#5:2  Bb3:1   (len in units)
  r:len     rest
  s<+/-n>   pitch slide per tick (raw step units)
  |         bar line (ignored)
  [ ... ]xN repeat
Stream bytes: $00 rest, $01-$5F note (1 = C1), $60-$7F length, $80-$8F instrument,
$90 slide, $91 long length, $FE jump, $FF stop.
"""
import re

NOTES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}
SAMPLE_T = 211                      # T-states a sample in the player's loop
RATE = 3546875 / SAMPLE_T


def note_num(tok):
    name = tok[0]; i = 1; acc = 0
    while i < len(tok) and tok[i] in '#b':
        acc += 1 if tok[i] == '#' else -1; i += 1
    octv = int(tok[i:])
    return (octv - 1) * 12 + NOTES[name] + acc + 1     # C1 = 1


def expand(s):
    s = re.sub(r'\](?!x\d)', ']x1', s)
    while '[' in s:
        n = s
        s = re.sub(r'\[([^\[\]]*)\]x(\d+)', lambda m: ' '.join([m.group(1)] * int(m.group(2))), s)
        assert s != n, 'unbalanced [ ] in song'
    return s.split()


def compile_channel(s):
    out = bytearray(); unit = 1; curlen = None; ticks_total = 0
    for tok in expand(s):
        if tok == '|': continue
        if tok[0] == 'i': out.append(0x80 + int(tok[1:])); continue
        if tok[0] == 'u': unit = int(tok[1:]); continue
        if tok[0] == 's':
            v = int(tok[1:]) & 0xFFFF; out += bytes([0x90, v & 255, v >> 8]); continue
        n, l = tok.split(':')
        ticks = int(round(float(l) * unit))
        assert 0 < ticks < 256, tok
        ticks_total += ticks
        if ticks != curlen:
            if ticks <= 32: out.append(0x5F + ticks)
            else: out += bytes([0x91, ticks])
            curlen = ticks
        out.append(0 if n == 'r' else note_num(n))
    return bytes(out), ticks_total


def note_steps():
    out = []
    for n in range(1, 96):
        f = 32.7032 * 2 ** ((n - 1) / 12.0)
        out.append(min(65535, int(round(f * 65536 / RATE))))
    return out


# instruments: (start duty, decay a tick, min duty, flags: bit0 noise)
INSTR = [
    (44, 1, 14, 0),   # 0 lead: bright, slowly thinning
    (64, 2, 20, 0),   # 1 bass
    (30, 1, 10, 0),   # 2 soft pad
    (96, 18, 0, 1),   # 3 snare (noise)
    (56, 7, 0, 0),    # 4 staccato
    (60, 1, 34, 0),   # 5 organ
    (72, 5, 4, 0),    # 6 bell
    (110, 14, 0, 0),  # 7 kick
    (70, 14, 0, 1),   # 8 hat (noise short)
    (40, 0, 40, 0),   # 9 flat beep
    (80, 3, 22, 0),   # 10 synth brass
    (24, 0, 24, 0),   # 11 thin drone
]

