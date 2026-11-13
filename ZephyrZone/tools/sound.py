"""Sound effects and blip-music data (original tunes).
The ISR plays one sample per copied row: fs = 3546900 / ROW_T Hz.
SFX entry: db fields, dw step, db mask (bit5 = half/speaker-B, bit0 = speaker-A, bit7 = noise); db 0 ends.
Music entry: db fields-to-next, db note (MIDI; 0 = rest); db 0 loops."""
# the ISR plays one sample per two copied rows (64 LDIs + the sample code = 1097 T), and
# present()'s idle loop is paced to match; nothing sounds while the game logic runs
ROW_T = 1097
FS = 3546900 / ROW_T
FS_SFX = 3546900 / 585          # the effects were tuned against this figure: keep their sound
WAIT_D = 60                     # wait_sound's delay loop (with the loop round it, ~1097 T)
def step(f): return max(1, min(65535, round(f * 65536 / FS)))
def step_sfx(f): return max(1, min(65535, round(f * 65536 / FS_SFX)))
def midi(n): return 440 * 2 ** ((n - 69) / 12)
NOTE = {n: i for i, n in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}
def nm(s):
    if s in ('.', '-'): return 0
    o = int(s[-1]); return 12 * (o + 1) + NOTE[s[:-1]]
FULL, HALF, NOISE = 0x21, 0x20, 0x80
SFX = {
    'SHOT':  [(1, 1500, FULL), (1, 950, FULL)],
    'TINK':  [(1, 1250, FULL)],
    'BOOM':  [(2, 0, FULL | NOISE), (2, 0, HALF | NOISE), (1, 90, FULL)],
    'CLINK': [(1, 1600, FULL), (1, 1350, HALF)],
    'SPIT':  [(1, 330, HALF), (1, 260, HALF)],
    'HURT':  [(2, 220, FULL), (2, 160, FULL), (2, 120, FULL)],
    'DIE':   [(3, 0, FULL | NOISE), (2, 400, FULL), (2, 300, FULL), (2, 220, FULL), (2, 160, FULL), (3, 0, HALF | NOISE)],
    'POWER': [(2, midi(72), FULL), (2, midi(76), FULL), (2, midi(79), FULL), (3, midi(84), FULL)],
    'WARN':  [(3, 620, FULL), (3, 470, FULL), (3, 620, FULL), (3, 470, FULL)],
    'BIG':   [(3, 0, FULL | NOISE), (3, 70, FULL), (3, 0, FULL | NOISE), (3, 55, FULL), (4, 0, HALF | NOISE)],
    'START': [(2, midi(67), FULL), (2, midi(72), FULL), (4, midi(79), FULL)],
    'THUD':  [(1, 0, FULL | NOISE), (1, 140, FULL), (1, 1700, FULL)],
    'SIZZLE':[(1, 0, HALF | NOISE), (1, 240, HALF)],
    'CLEAR': [(3, midi(72), FULL), (3, midi(76), FULL), (3, midi(79), FULL), (3, midi(84), FULL), (6, midi(88), FULL)],
    'MENU':  [(1, 1100, HALF)],
    # an enemy shot down: a bright crack, a burst, then a whistling fall
    'KILL':  [(1, 2400, FULL), (2, 0, FULL | NOISE), (1, 1500, FULL), (1, 1100, FULL), (1, 820, FULL),
              (1, 600, FULL), (1, 440, FULL), (1, 320, FULL), (1, 0, HALF | NOISE)],
    # a hit that doesn't kill (tough creatures, scenery): a sharp knock
    'KNOCK': [(1, 1900, FULL), (1, 0, FULL | NOISE), (1, 700, HALF)],
}
ORDER = list(SFX)
# tunes: (notes, beat length in fields); each note is a short blip
TUNES = {
    # CHECKER PLAINS - a jaunty, slow-stepping major tune
    'plains': (8, "C5 . E5 G5 A5 . G5 E5 D5 . E5 C5 D5 . . . "
                  "C5 . E5 G5 C6 . A5 G5 E5 . D5 E5 C5 . . . "
                  "A4 . C5 A4 G4 . C5 E5 F5 . E5 D5 E5 . . . "
                  "A4 . C5 D5 E5 G5 E5 D5 C5 . G4 . C5 . . . "),
    # COILWYRM - tense minor stomp
    'boss':   (6, "A3 . A3 C4 A3 . E4 . A3 . A3 C4 D4 . C4 B3 "
                  "A3 . A3 C4 A3 . E4 . F4 . E4 D4 C4 . B3 . "),
    # title - written for the engine's short blips: a bass pluck on the beat and the tune
    # dancing above it, so one blip voice implies two (A minor, a heroic lift at the end)
    'title':  (4, "A3 . E5 . A4 . C5 E5 A3 . D5 . C5 . B4 . "
                  "F3 . C5 . F4 . A4 C5 F3 . D5 . C5 . A4 . "
                  "G3 . B4 . G4 . D5 G5 G3 . F5 . E5 . D5 . "
                  "E3 . G#4 . B4 . E5 . G#5 . . . E5 . B4 . "
                  "A3 . A5 . A3 . G5 . A3 . E5 . A3 . C5 . "
                  "F3 . A5 . F3 . G5 . F3 . F5 . F3 . E5 . "
                  "D3 . F5 . D3 . E5 . D3 . D5 . E3 . C5 . "
                  "E3 . B4 . E3 . G#4 . E3 . B4 . E5 . . . "),
    # the finale - a broad, ringing hymn: bass pluck on the beat, the tune above (C major)
    'finale': (5, "C3 . E5 . G4 . C5 . F3 . A5 . C5 . F5 . G3 . G5 . D5 . B4 . C3 . C5 . E5 . G5 . "
                  "A2 . C6 . E5 . A5 . F3 . A5 . F5 . C5 . D3 . D5 . F5 . A5 . G3 . B5 . . . D6 . . . "
                  "C3 . E6 . C6 . G5 . A2 . E6 . C6 . A5 . F3 . F5 . A5 . C6 . G3 . D6 . B5 . G5 . "
                  "C3 . C6 . G5 . E5 . C4 . G5 . E5 . C5 . C3 . . . C5 . . . C6 . . . . . . . "),
    # SUNSET DUNES - a lazy, snake-charmer minor swing
    'dunes':  (8, "D4 . F4 G4 A4 . G4 F4 E4 . F4 D4 E4 . . . "
                  "D4 . F4 G4 A4 . C5 A4 A#4 . A4 G4 A4 . . . "
                  "D5 . C5 A#4 A4 . G4 F4 G4 . A4 F4 E4 . . . "
                  "D4 . A3 D4 F4 E4 D4 C#4 D4 . . . . . . . "),
    # SUN TOTEM - pounding drum-like pattern
    'totem':  (6, "D3 . D3 D3 F3 . D3 . G3 . F3 D3 C3 . D3 . "
                  "D3 . D3 D3 F3 . A3 . G#3 . G3 F3 D3 . . . "),
    # CRYSTAL NIGHT - glassy, wide-spaced arpeggios
    'crystal':(8, "E5 . B4 . G5 . B4 . F#5 . B4 . D5 . . . "
                  "C5 . G4 . E5 . G4 . D5 . A4 . B4 . . . "
                  "A4 . E5 . C6 . E5 . B5 . G5 . E5 . . . "
                  "F#5 . D#5 . B4 . F#4 . B4 . . . . . . . "),
    # SHARDWYRM - fast chromatic menace
    'shard':  (5, "E3 . F3 E3 G3 . F#3 . E3 . F3 E3 A#3 . A3 . "
                  "E3 . F3 E3 G3 . B3 . C4 . B3 A#3 A3 . G3 . "),
    # NEON CITY - driving synth-pop bass line feel
    'city':   (6, "A3 . A4 . A3 E4 . G4 A3 . A4 . G4 . E4 . "
                  "F3 . F4 . F3 C4 . E4 G3 . G4 . F4 . D4 . "
                  "A3 . A4 . A3 E4 . G4 A3 . C5 . B4 . A4 . "
                  "F3 . A4 . G3 . B4 . E4 . . . E4 G#4 B4 . "),
    # MEGAMECH - mechanical march
    'mech':   (5, "C3 . C3 . G3 . C3 . D#3 . D3 . C3 . G2 . "
                  "C3 . C3 . G3 . C3 . F3 . D#3 . D3 . B2 . "),
    # MUSHROOM MARSH - a bouncy, whimsical waltz-ish tune
    'marsh':  (7, "G4 . . B4 D5 . G5 . . F#5 E5 . D5 . . . "
                  "C5 . . E5 G5 . C6 . . B5 A5 . G5 . . . "
                  "A4 . . C5 E5 . A5 . . G5 F#5 . E5 . D5 . "
                  "G4 . B4 . D5 . F#5 . G5 . . . . . . . "),
    # BOGAPEDE - creeping, scuttling minor
    'pede':   (5, "D3 F3 D3 . C#3 . D3 F3 A3 . G#3 . A3 . . . "
                  "D3 F3 D3 . C#3 . D3 A#3 A3 . G3 . F3 . E3 . "),
    'over':   (9, "E5 . D5 . C5 . A4 . B4 . G4 . C4 . . . "),
}
def tune_bytes(beat, txt):
    out = []
    toks = txt.split()
    i = 0
    while i < len(toks):
        n = nm(toks[i]); j = i + 1
        while j < len(toks) and toks[j] == '.' : j += 1
        if n == 0: n = 0
        out += [beat * (j - i), n]
        i = j
    return out + [0]
def asm():
    s = ['; generated by tools/sound.py', 'WAIT_D equ %d' % WAIT_D]
    for i, k in enumerate(ORDER): s.append('SFX_%s equ %d' % (k, i))
    s.append('sfx_tab:    dw ' + ','.join('sfx_%s' % k.lower() for k in ORDER))
    for k in ORDER:
        b = []
        for d, f, m in SFX[k]: st = step_sfx(f) if f else 0x5555; b += [d, st & 255, st >> 8, m]
        s.append('sfx_%s: db %s,0' % (k.lower(), ','.join(map(str, b))))
    # note steps for MIDI 36..96
    s.append('NOTE0 equ 36')
    s.append('note_steps:')
    v = [step(midi(n)) for n in range(36, 97)]
    for i in range(0, len(v), 12): s.append('            dw ' + ','.join(map(str, v[i:i + 12])))
    for k in ('title', 'over'):
        beat, txt = TUNES[k]
        s.append('tune_%s: db %s' % (k, ','.join(map(str, tune_bytes(beat, txt)))))
    return '\n'.join(s) + '\n'
WORLD_TUNES = {1: ('plains', 'boss'), 2: ('dunes', 'totem'), 3: ('crystal', 'shard'), 4: ('city', 'mech'), 5: ('marsh', 'pede')}
def world_asm(n):
    st, bo = WORLD_TUNES[n]
    s = ['; generated by tools/sound.py: world %d tunes' % n]
    for lab, k in (('tune_stage', st), ('tune_wboss', bo)):
        beat, txt = TUNES[k]
        s.append('%s: db %s' % (lab, ','.join(map(str, tune_bytes(beat, txt)))))
    return '\n'.join(s) + '\n'
def end_asm():
    beat, txt = TUNES['finale']
    return 'tune_end: db %s\n' % ','.join(map(str, tune_bytes(beat, txt)))
if __name__ == '__main__':
    print(asm()[:600])
