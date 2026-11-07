"""The music: an original tune for the three-voice player (src/music.asm).

(based on the Scramble player data format) - A minor (an octave down, set by TRANS), 125 bpm, driving: an octave-bouncing bass, offbeat
chord stabs played as fast arpeggios, a lead with delayed vibrato, and drums.
Form: intro (4 bars) | A (8) | B (8) | A (8) | breakdown (4) -> back to A.
"""
CLK = 3546900
LOOPT = 175
NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6,
        'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}
def midi(n): return 12 * (int(n[-1]) + 1) + NOTE[n[:-1]]
TRANS = -12                              # the whole tune an octave down
def idx(n): return midi(n) - 24 + TRANS  # C1 = 0
def bidx(n):                             # bass: down too, but never below E2
    i = idx(n)
    return i + 12 if i < idx('E2') - TRANS else i

def freq_table():
    r = []
    for i in range(84):
        f = 440.0 * 2 ** ((i + 24 - 69) / 12.0)
        r.append(int(round(f * 65536 * LOOPT / CLK)))
    return r

# instruments: (envelope, arpeggio, vibrato)
INST = {
  'bass':  ([15, 14, 13, 12, 11, 10, 10, 9, 9, 8], [0], 0),
  'lead':  ([11, 14, 15, 14, 13, 12, 12, 11, 11, 11, 10], [0], 1),
  'leadl': ([10, 13, 14, 13, 13, 12, 12, 12, 11, 11, 11, 10, 10, 10, 9], [0], 1),
  'min':   ([12, 11, 10, 8, 7, 6, 5, 4, 3, 2, 1, 0], [0, 3, 7], 0),
  'maj':   ([12, 11, 10, 8, 7, 6, 5, 4, 3, 2, 1, 0], [0, 4, 7], 0),
  'sus':   ([12, 11, 10, 8, 7, 6, 5, 4, 3, 2, 1, 0], [0, 5, 7], 0),
  'padm':  ([4, 6, 7, 8, 8, 8, 7, 7, 7, 7, 6, 6, 6, 6, 5], [0, 3, 7], 0),
  'padM':  ([4, 6, 7, 8, 8, 8, 7, 7, 7, 7, 6, 6, 6, 6, 5], [0, 4, 7], 0),
  'padS':  ([4, 6, 7, 8, 8, 8, 7, 7, 7, 7, 6, 6, 6, 6, 5], [0, 5, 7], 0),
  'slow':  ([9, 12, 13, 13, 12, 12, 11, 11, 10, 10, 9, 9, 8, 8, 7, 7, 6], [0], 1),
}
INAMES = list(INST)

# ---------------------------------------------------------------------------
# BILBIES! music.
# Title: an arrangement of Grieg's "In the Hall of the Mountain King" (1875,
# public domain) in A minor - a sneaking bass, offbeat stabs and drums.
# Jingles (briefing, well done, oh dear) are original.
# ---------------------------------------------------------------------------
CH = {'Am': ('A2', 'A4', 'm'), 'E': ('E2', 'E4', 'M'), 'Dm': ('D3', 'D4', 'm'),
      'F': ('F2', 'F4', 'M'), 'C': ('C3', 'C4', 'M'), 'G': ('G2', 'G4', 'M'),
      'B7': ('B2', 'B3', 'M')}

def bass_bar(c, fill=False):
    r = bidx(CH[c][0])
    pat = [(0, 2), (12, 2), (0, 2), (12, 2), (0, 2), (12, 2), (7, 2), (12, 2)]
    if fill: pat = [(0, 2), (12, 2), (0, 2), (12, 2), (12, 1), (10, 1), (7, 2), (5, 2), (3, 2)]
    return [('bass', r + o, l) for o, l in pat]

def stab_bar(c):
    q = {'m': 'min', 'M': 'maj', 'S': 'sus'}[CH[c][2]]
    r = idx(CH[c][1])
    return [(None, None, 2), (q, r, 2), (None, None, 2), (q, r, 2),
            (None, None, 2), (q, r, 2), (None, None, 2), (q, r, 2)]

def drum_bar(fill=False):
    K, S, H = 1, 2, 3
    p = [K, 0, H, 0, S, 0, H, 0, K, 0, H, K, S, 0, H, 0]
    if fill: p = [K, 0, H, 0, S, 0, H, 0, K, 0, S, 0, S, S, S, S]
    r = []
    for d in p:
        if d or not r: r.append([d, 1])
        else: r[-1][1] += 1
    return [(None, d if d else None, l) for d, l in r]

# the theme, two bars a line, 16 steps a bar
MK1 = ['A4:2 B4:2 C5:2 D5:2 E5:2 C5:2 E5:4', 'D#5:2 B4:2 D#5:4 D5:2 A#4:2 D5:4',
       'A4:2 B4:2 C5:2 D5:2 E5:2 C5:2 E5:2 A5:2', 'G5:2 E5:2 C5:2 E5:2 G5:8']
MK2 = ['E5:2 F#5:2 G#5:2 A5:2 B5:2 G#5:2 B5:4', 'C6:2 G#5:2 C6:4 B5:2 G#5:2 B5:4',
       'E5:2 F#5:2 G#5:2 A5:2 B5:2 G#5:2 B5:2 E6:2', 'D6:2 B5:2 G#5:2 B5:2 D6:8']
CH1 = ['Am', 'Am', 'E', 'E', 'Am', 'Am', 'C', 'C']
CH2 = ['E', 'E', 'E', 'E', 'E', 'E', 'B7', 'B7']

def mel(s, inst='lead'):
    r = []
    for tok in s.split():
        n, l = tok.split(':')
        r.append((inst, None if n == '.' else idx(n), int(l)))
    return r

def bars(melody):
    out = []
    for line in melody:
        toks = line.split()
        a, b, n = [], [], 0
        for t in toks:
            l = int(t.split(':')[1])
            (a if n < 16 else b).append(t)
            n += l
        out += [' '.join(a), ' '.join(b)]
    return out

def section(chords, melody, kind):
    bass, lead, chd, drm = [], [], [], []
    mb = bars(melody) if melody else None
    for i, c in enumerate(chords):
        last = i == len(chords) - 1
        bass.append(bass_bar(c, fill=last))
        drm.append(drum_bar(fill=last))
        chd.append(stab_bar(c))
        lead.append(mel(mb[i], 'lead') if mb else [(None, None, 16)])
    return bass, lead, chd, drm

def theme():
    parts = [section(['Am', 'Am', 'E', 'Am'], None, 'intro'),
             section(CH1, MK1, 'A'), section(CH1, MK1, 'A'),
             section(CH2, MK2, 'B'), section(CH1, MK1, 'A')]
    chans = [[], [], [], []]
    for p in parts:
        for k in range(4): chans[k] += p[k]
    return chans, 4

def jingle(lead, chords, inst='lead'):
    lb = [mel(x, inst) for x in lead]
    bass = [[('bass', bidx(CH[c][0]), 4), ('bass', bidx(CH[c][0]) + 12, 4), ('bass', bidx(CH[c][0]), 8)] for c in chords]
    chd = [[('maj' if CH[c][2] == 'M' else 'min', idx(CH[c][1]), 16)] for c in chords]
    drm = [[(None, 1, 4), (None, 3, 4), (None, 2, 4), (None, 3, 4)] for c in chords]
    return [bass, lb, chd, drm], None

def song_brief():   # "off we go"
    return jingle(['C5:2 E5:2 G5:2 C6:4 G5:2 A5:2 B5:2', 'C6:4 G5:2 E5:2 C5:8'], ['C', 'G'])
def song_win():
    return jingle(['G5:2 G5:2 A5:2 B5:2 C6:4 E6:4', 'D6:2 C6:2 B5:2 D6:2 C6:8'], ['C', 'G'])
def song_lose():
    return jingle(['E5:4 D5:4 C5:4 B4:4', 'A4:4 G#4:4 A4:8'], ['Am', 'E'], 'slow')

def emit(e, name, chans, loop_bar, frames_per_step):
    """Bars become patterns (shared when identical); each channel calls them in turn."""
    pats = {}
    body = []
    for k, bars in enumerate(chans):
        seq = []
        for b in bars:
            by = []
            cur = None
            for inst, n, l in b:
                fr = l * frames_per_step
                if k < 3 and n is not None and inst != cur:
                    by.append(0x80 + INAMES.index(inst)); cur = inst
                by += [0x60 if n is None else n, fr]
            by.append(0xFC)
            key = tuple(by)
            if key not in pats: pats[key] = '%s_p%d' % (name, len(pats))
            seq.append(pats[key])
        body.append(seq)
    e('%s:  dw %s' % (name, ','.join('%s_c%d' % (name, k) for k in range(4))))
    for k, seq in enumerate(body):
        e('%s_c%d:' % (name, k))
        for i, p in enumerate(seq):
            if loop_bar is not None and i == loop_bar: e('%s_c%d_loop:' % (name, k))
            e('        db $FD : dw %s' % p)
        if loop_bar is None: e('        db $FE')
        else: e('        db $FF : dw %s_c%d_loop' % (name, k))
    for key, lab in pats.items():
        e('%s: db %s' % (lab, ','.join(str(x) for x in key)))
    return len(pats)

def emit_all(e):
    e('FREQ:   dw ' + ','.join(str(x) for x in freq_table()))
    e('INSTS:')
    for n in INAMES:
        e('        dw ins_%s_e, ins_%s_a : db %d, 0' % (n, n, INST[n][2]))
    for n in INAMES:
        env, arp, v = INST[n]
        e('ins_%s_e: db %s,$FF' % (n, ','.join(map(str, env))))
        e('ins_%s_a: db %s,$80' % (n, ','.join(str(x & 255) for x in arp)))
    ch, lb = theme()
    emit(e, 'SONG_T', ch, lb, 6)
    for name, f, fps in (('SONG_J', song_brief, 5), ('SONG_W', song_win, 5), ('SONG_L', song_lose, 7)):
        ch, lb = f()
        emit(e, name, ch, lb, fps)
