"""SPINDRIFT's title music for the SWIRL engine (src/mus.asm) -> build/MUS.BNK

"Spiral Arms": A minor, 127 BPM, on the descending Am - G - F - E that
psychedelic rock loves. Original music.

The engine plays a tick of 255 samples (218 T each), about 59 ticks a
second; a sixteenth note here is 7 ticks. Each tick the stream gives the
voices' new settings:

  BASS   step + duty: squelch notes that start a fifth up and dive, duty
         swelling and decaying like a filter
  PHASE  two steps: a pad of two oscillators a hair apart, exclusive-or'd,
         so the tone sweeps as they drift through each other
  ARP    step + duty: chord arpeggios at tick rate, or the lead line with
         a delayed vibrato
  drums  1-bit pulse trains: kick, snare, closed and open hats, toms
"""
import math
import random
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLOCK = 3375000
SAMPLE_T = 218
SR = CLOCK / SAMPLE_T
TICK_SAMPLES = 255
TPS = 7                      # ticks a sixteenth
UNIT_T = 51                  # pulse_play's wait unit

NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
        'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def midi(n):
    """'A4' -> 69"""
    if isinstance(n, int):
        return n
    name, octv = n[:-1], int(n[-1])
    return 12 * (octv + 1) + NOTE[name]


def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def step(f):
    return max(0, min(65535, int(round(f * 65536.0 / SR))))


# ------------------------------------------------------------- drums
rng = random.Random(1987)


def train(segments):
    """[(level_flip, T)] -> pulse_play bytes; long waits are split"""
    out = bytearray()
    total = 0
    for flip, t in segments:
        u = max(1, int(round(t / UNIT_T)))
        total += u * UNIT_T
        first = True
        while u > 0:
            n = min(u, 127)
            if n == 0:
                break
            out.append(n | (0 if (flip and first) else 0x80))
            u -= n
            first = False
    out.append(0)
    return bytes(out), total


def kick():
    seg = [(True, 60), (True, 60)]                  # the beater click
    hp = 1100.0
    while hp < 11000:
        seg.append((True, hp))
        hp *= 1.32
    return train(seg)


def noise(dur_t, lo, hi, decay_from=None, decay_gap=0):
    seg = []
    t = 0
    while t < dur_t:
        u = rng.randint(lo, hi)
        if decay_from is not None and t > decay_from:
            # the tail thins out: more and longer silences
            frac = (t - decay_from) / (dur_t - decay_from)
            if rng.random() < frac * 0.8:
                seg.append((False, u * UNIT_T + decay_gap * frac))
                t += u * UNIT_T + decay_gap * frac
                continue
        seg.append((True, u * UNIT_T))
        t += u * UNIT_T
    return seg


def snare():
    seg = [(True, 2600), (True, 2900)]              # the shell
    seg += noise(24000, 1, 4, decay_from=6000, decay_gap=400)
    return train(seg)


def hat():
    return train(noise(2600, 1, 2))


def ohat():
    return train(noise(12000, 1, 2, decay_from=3000, decay_gap=250))


def tom(top):
    seg = [(True, 60)]
    hp = top
    for _ in range(7):
        seg.append((True, hp))
        hp *= 1.12
    return train(seg)


DRUMS = {'K': kick(), 'S': snare(), 'h': hat(), 'o': ohat(), 'T': tom(1500), 't': tom(2300)}
DRUM_IDS = {k: i + 1 for i, k in enumerate(DRUMS)}


def samples_of(total_t):
    return min(255, int(math.ceil(total_t / SAMPLE_T)))


# ------------------------------------------------------------- the score
# chords of the sequence: root, and the arpeggio's notes
CH = {
    'Am': ('A1', ['A4', 'C5', 'E5', 'A5']),
    'G':  ('G1', ['G4', 'B4', 'D5', 'G5']),
    'F':  ('F1', ['F4', 'A4', 'C5', 'F5']),
    'E':  ('E1', ['E4', 'G#4', 'B4', 'E5']),
    'Dm': ('D2', ['D4', 'F4', 'A4', 'D5']),
    'C':  ('C2', ['C4', 'E4', 'G4', 'C5']),
}

# the bass: sixteen steps against the root (semitones; None = rest;
# '>' marks an accent)
BASS_A = [0, '>0', 12, 0, 7, 0, '>12', 10, 0, 0, '>12', 0, 7, 12, 10, 7]
BASS_B = ['>0', None, 12, 0, '>7', None, 12, 0, '>0', 0, 12, None, '>10', 7, 12, 3]
BASS_LONG = ['>0', None, None, None, None, None, None, None, 0, None, None, None, None, None, None, None]

# drums, sixteen steps
DR_GROOVE = 'K.h.KSh.K.hoKSh.'
DR_GROOVE2 = 'K.h.KSh.K.hoKSht'
DR_FILL = 'K.h.KSh.KTTtStSS'
DR_INTRO = '....h...h...h.h.'
DR_INTRO2 = 'K...h...K...h.hh'
DR_BREAK = 'K.......K.......'
DR_BUILD = 'K.S.K.S.KSKSSSSS'

# the lead (16ths): (note or None to hold, length in 16ths)
LEAD_1 = [('A4', 3), ('C5', 2), ('E5', 3), ('D5', 2), ('C5', 2), ('A4', 4),
          ('B4', 3), ('D5', 2), ('G5', 3), ('F5', 2), ('D5', 2), ('B4', 4),
          ('A4', 3), ('C5', 2), ('F5', 3), ('E5', 2), ('C5', 2), ('A4', 4),
          ('G#4', 3), ('B4', 2), ('E5', 3), ('D5', 2), ('B4', 2), ('G#4', 2), ('E4', 2)]
LEAD_2 = [('E5', 4), ('D5', 2), ('C5', 2), ('B4', 2), ('C5', 4), ('A4', 2),
          ('D5', 4), ('C5', 2), ('B4', 2), ('A4', 2), ('B4', 4), ('G4', 2),
          ('C5', 4), ('B4', 2), ('A4', 2), ('G4', 2), ('A4', 2), ('F4', 2), ('A4', 2),
          ('G#4', 6), ('B4', 2), ('E5', 8)]
# the breakdown's phaser hook: slow, half time
HOOK = [('E5', 8), ('C5', 8), ('D5', 8), ('B4', 8), ('C5', 8), ('A4', 8), ('B4', 12), ('G#4', 4)]


class Score:
    def __init__(self):
        self.bars = []

    def bar(self, chord, bass, drums, arp=None, lead=None, pad='root', phase_mode=1, swirl=2, hook=None):
        self.bars.append(dict(chord=chord, bass=bass, drums=drums, arp=arp, lead=lead, pad=pad,
                              mode=phase_mode, swirl=swirl, hook=hook))


SEQ = ['Am', 'G', 'F', 'E']


def build_score():
    s = Score()
    # INTRO: the pad swells in, hats creep in, the bass arrives
    for i, c in enumerate(SEQ):
        s.bar(c, None if i < 3 else BASS_LONG, DR_INTRO if i < 2 else DR_INTRO2, swirl=1)
    loop_bar = len(s.bars)
    # GROOVE A: squelch bass, drums, shimmering arps
    for rep in range(2):
        for i, c in enumerate(SEQ):
            s.bar(c, BASS_A, DR_FILL if (rep == 1 and i == 3) else (DR_GROOVE2 if i == 3 else DR_GROOVE), arp='up')
    # GROOVE B: the lead
    for rep, lead in enumerate((LEAD_1, LEAD_2)):
        for i, c in enumerate(SEQ):
            s.bar(c, BASS_B, DR_GROOVE2 if i == 3 else DR_GROOVE, lead=(lead, i))
    # BREAK: the phaser takes the hook and swirls; kick only
    for i, c in enumerate(['Am', 'F', 'Dm', 'E']):
        s.bar(c, BASS_LONG, DR_BREAK if i < 3 else DR_BUILD, pad='hook', phase_mode=1, swirl=9, hook=i)
    # GROOVE A': arps and the lead's answer by turns
    for rep in range(2):
        for i, c in enumerate(SEQ):
            last = rep == 1 and i == 3
            if rep == 0:
                s.bar(c, BASS_A, DR_GROOVE2 if i == 3 else DR_GROOVE, arp='updown')
            else:
                s.bar(c, BASS_B, DR_FILL if last else DR_GROOVE, lead=(LEAD_2, i))
    return s, loop_bar


def lead_bar(lead, bar_index):
    """the notes of one bar of a lead phrase (each phrase is four bars)"""
    pos = 0
    out = []
    for n, l in lead:
        b0 = pos // 16
        if b0 == bar_index:
            out.append((pos % 16, n, l))
        pos += l
    return out


def hook_bar(i):
    pos = 0
    out = []
    for n, l in HOOK:
        if pos // 16 == i:
            out.append((pos % 16, n, l))
        pos += l
    return out


# ------------------------------------------------------------- render
def render():
    score, loop_bar = build_score()
    ticks = []
    bass_note = None
    bass_age = 0
    bass_acc = False
    lead_note = None
    lead_age = 0
    loop_tick = loop_bar * 16 * TPS
    for bi, b in enumerate(score.bars):
        root, arpnotes = CH[b['chord']]
        rootm = midi(root)
        leads = {}
        if b['lead']:
            for p, n, l in lead_bar(*b['lead']):
                leads[p] = (n, l)
        hooks = {}
        if b['hook'] is not None:
            for p, n, l in hook_bar(b['hook']):
                hooks[p] = (n, l)
        for st in range(16):
            # this sixteenth's events
            if b['bass']:
                ev = b['bass'][st]
                if ev is not None:
                    acc = isinstance(ev, str)
                    semis = int(ev.lstrip('>')) if acc else ev
                    bass_note = rootm + semis
                    bass_age = 0
                    bass_acc = acc
            else:
                bass_note = None
            if b['drums'][st] != '.':
                drum = DRUM_IDS[b['drums'][st]]
            else:
                drum = 0
            if st in leads:
                lead_note = midi(leads[st][0])
                lead_age = 0
            if st in hooks:
                hook_note = midi(hooks[st][0])
                b['_hook_note'] = hook_note
                b['_hook_age0'] = len(ticks)
            for tk in range(TPS):
                t = len(ticks)
                v = {}
                # ---- BASS: dive from a fifth up, duty swells then decays
                if bass_note is not None:
                    dive = 7.0 * math.exp(-bass_age / 1.6)
                    v['bass'] = step(freq(bass_note + dive))
                    top = 150 if bass_acc else 112
                    d = top * math.exp(-bass_age / (9.0 if bass_acc else 6.0))
                    v['bduty'] = max(18, int(d)) if b['bass'] is not BASS_LONG else max(10, int(top * math.exp(-bass_age / 40.0)))
                else:
                    v['bass'], v['bduty'] = 0, 0
                bass_age += 1
                # ---- PHASE
                if b['pad'] == 'hook' and '_hook_note' in b:
                    hn = b['_hook_note']
                    a = step(freq(hn))
                    # the swirl: the second oscillator wanders a little
                    wob = b['swirl'] * (1.0 + 0.6 * math.sin((t - b['_hook_age0']) / 22.0))
                    v['pa'], v['pb'] = a, a + int(wob)
                else:
                    # the pad: the chord's root two octaves up and a hair sharp
                    pm = rootm + 24 + (0 if b['chord'] != 'E' else 0)
                    a = step(freq(pm))
                    v['pa'], v['pb'] = a, a + b['swirl']
                    if bi < 2:
                        # fade in: the second oscillator starts far off and
                        # closes in, so the sweep grows slower and deeper
                        v['pb'] = a + b['swirl'] + int(40 * (1 - (bi * 16 * TPS + st * TPS + tk) / (32.0 * TPS)))
                v['mode'] = b['mode']
                # ---- ARP / LEAD
                if b['arp']:
                    seq = [midi(n) for n in arpnotes]
                    if b['arp'] == 'updown':
                        seq = seq + seq[-2:0:-1]
                    n = seq[t % len(seq)]
                    v['arp'] = step(freq(n))
                    v['aduty'] = max(16, 72 - 7 * tk)
                elif b['lead'] and lead_note is not None:
                    vib = 0.0
                    if lead_age > 10:
                        vib = 0.28 * math.sin((lead_age - 10) * 2 * math.pi / 9.0) * min(1.0, (lead_age - 10) / 12.0)
                    slide = -1.0 * math.exp(-lead_age / 1.2)      # a scoop up into the note
                    v['arp'] = step(freq(lead_note + vib + slide))
                    v['aduty'] = max(52, int(118 * math.exp(-lead_age / 30.0)))
                else:
                    v['arp'], v['aduty'] = 0, 0
                lead_age += 1
                v['drum'] = drum if tk == 0 else 0
                ticks.append(v)
    return ticks, loop_tick


def encode(ticks, loop_tick):
    out = bytearray()
    prev = {'pa': None, 'pb': None, 'bass': None, 'bduty': None, 'arp': None, 'aduty': None, 'mode': None}
    loop_addr = None
    for i, v in enumerate(ticks):
        if i == loop_tick:
            loop_addr = 4 + len(out)
            prev = {k: None for k in prev}          # everything again at the loop
        m = 0
        f = bytearray()
        if v['pa'] != prev['pa']:
            m |= 1
            f += struct.pack('<H', v['pa'])
        if v['pb'] != prev['pb']:
            m |= 2
            f += struct.pack('<H', v['pb'])
        if v['bass'] != prev['bass']:
            m |= 4
            f += struct.pack('<H', v['bass'])
        if v['bduty'] != prev['bduty']:
            m |= 8
            f.append(v['bduty'])
        if v['arp'] != prev['arp']:
            m |= 16
            f += struct.pack('<H', v['arp'])
        if v['aduty'] != prev['aduty']:
            m |= 32
            f.append(v['aduty'])
        if v['drum']:
            m |= 64
            f.append(v['drum'])
        if v['mode'] != prev['mode']:
            m |= 128
            f.append(v['mode'])
        out.append(m)
        out += f
        prev.update({k: v[k] for k in prev})
    out += bytes([128, 0])                          # back to the loop point
    return out, loop_addr


def build():
    ticks, loop_tick = render()
    stream, loop_addr = encode(ticks, loop_tick)
    data = bytearray(4) + stream
    drumtab = len(data)
    trains = []
    data += bytes(3 * len(DRUMS))
    for k, (tr, tot) in DRUMS.items():
        trains.append((len(data), samples_of(tot)))
        data += tr
    for i, (addr, n) in enumerate(trains):
        data[drumtab + 3 * i:drumtab + 3 * i + 3] = struct.pack('<HB', addr, n)
    data[0:4] = struct.pack('<HH', loop_addr, drumtab)
    # the in-game music and effects (tools/mkmusic.py) at GAMESND
    gs = (ROOT / 'build' / 'GAMESND.BIN').read_bytes()
    assert len(data) <= 0x6000, len(data)
    data += bytes(0x6000 - len(data)) + gs
    assert len(data) <= 0x8000, len(data)
    (ROOT / 'build' / 'MUS.BNK').write_bytes(bytes(data))
    secs = len(ticks) * (TICK_SAMPLES * SAMPLE_T + 1200) / CLOCK
    print('MUS.BNK %d bytes: %d ticks (~%.0f s), loop at tick %d; drums %s' % (
        len(data), len(ticks), secs, loop_tick,
        ', '.join('%s %d smp' % (k, samples_of(t)) for k, (_, t) in DRUMS.items())))


if __name__ == '__main__':
    build()
