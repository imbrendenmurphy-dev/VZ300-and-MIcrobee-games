#!/usr/bin/env python3
"""Generate song.inc + drums.bin for the VZ300 megademo line-kernel player.
Original composition. 64-row patterns, 16 rows per bar, SPEED frames/row."""
import math, random, sys, os
random.seed(1985)
OUT = sys.argv[1] if len(sys.argv) > 1 else 'build'
LINES = 312
PAIRS = (LINES - 18) // 2
FPS = 3546900 / (LINES * 228)
RATE = PAIRS * FPS          # voice update rate (Hz)
SPEED = 6

# note numbers: C1 = 0
NN = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
def n(s):
    s = s.strip()
    name = s[:-1]; octv = int(s[-1])
    return NN[name] + (octv - 1) * 12
def freq(k): return 440.0 * 2 ** ((k - 45) / 12)

# encoding: 0 = continue, 1 = off, 2+ = note+2  (bit7 = use instrument B)
def enc(note, alt=False):
    v = note + 2
    assert 2 <= v < 128
    return v | (0x80 if alt else 0)

patterns = []          # list of 64-byte lists
pat_index = {}
def pat(name, rows):
    assert len(rows) == 64, (name, len(rows))
    pat_index[name] = len(patterns)
    patterns.append(rows)

def empty(): return [0]*64

def from_events(events, length=64):
    r = empty()
    for row, val in events:
        r[row] = val
    return r

# ---------------- chords ----------------
PROG = {
  'A': [('A2', True), ('F2', False), ('C3', False), ('G2', False)],   # Am F C G   (True = minor)
  'B': [('A2', True), ('G2', False), ('F2', False), ('E2', False)],   # Am G F E
  'C': [('D2', True), ('G2', False), ('C3', False), ('A2', True)],    # Dm G C Am
  'D': [('F2', False), ('G2', False), ('E2', True), ('A2', True)],    # F G Em Am
}

# ---------------- bass patterns ----------------
def bass_bounce(prog, fill=False):
    ev = []
    for b, (root, minor) in enumerate(PROG[prog]):
        r = n(root)
        for k in range(8):
            note = r + (12 if k % 2 else 0)
            if fill and b == 3 and k >= 4:
                note = r + [0, 12, 7, 19][k - 4]
            ev.append((b*16 + k*2, enc(note)))
    return from_events(ev)

def bass_drive(prog):
    ev = []
    patt = [0, 0, 12, 0, 0, 12, 0, 10, 0, 0, 12, 0, 7, 0, 12, 0]
    gate = [1, 0, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1]
    for b, (root, minor) in enumerate(PROG[prog]):
        r = n(root)
        for k in range(16):
            if gate[k]:
                ev.append((b*16 + k, enc(r + patt[k])))
            elif k % 4 == 1:
                ev.append((b*16 + k, 1))
    return from_events(ev)

def bass_long(prog):
    ev = []
    for b, (root, minor) in enumerate(PROG[prog]):
        ev.append((b*16, enc(n(root))))
        ev.append((b*16 + 12, enc(n(root) + 12)))
    return from_events(ev)

def bass_pulse(prog):      # quarter notes, octave down feel
    ev = []
    for b, (root, minor) in enumerate(PROG[prog]):
        r = n(root)
        for k in range(4):
            ev.append((b*16 + k*4, enc(r)))
            ev.append((b*16 + k*4 + 2, 1))
    return from_events(ev)

# ---------------- lead: arpeggio chords ----------------
def lead_arp(prog, octave_up=0, stabs=False):
    ev = []
    for b, (root, minor) in enumerate(PROG[prog]):
        r = n(root) + 24 + octave_up
        if stabs:
            for k in (0, 3, 6, 10, 12):
                ev.append((b*16 + k, enc(r, minor)))
                ev.append((b*16 + k + 2, 1))
        else:
            ev.append((b*16, enc(r, minor)))
    return from_events(ev)

# ---------------- lead melodies (original) ----------------
def mel(bars):
    ev = []
    for b, bar in enumerate(bars):
        for row, note in bar:
            ev.append((b*16 + row, 1 if note == '-' else enc(n(note) - 12)))   # one octave lower = less shrill
    return from_events(ev)

M1 = mel([
  [(0,'E5'),(6,'A5'),(8,'G5'),(10,'E5'),(12,'D5'),(14,'E5')],
  [(0,'C5'),(4,'A4'),(6,'C5'),(8,'D5'),(10,'C5'),(12,'A4'),(15,'-')],
  [(0,'E5'),(4,'G5'),(6,'E5'),(8,'C5'),(10,'D5'),(12,'E5'),(14,'G5')],
  [(0,'D5'),(4,'B4'),(6,'D5'),(10,'G5'),(12,'E5'),(14,'D5')],
])
M2 = mel([
  [(0,'A5'),(4,'C6'),(6,'B5'),(8,'A5'),(10,'G5'),(12,'E5'),(14,'G5')],
  [(0,'A5'),(2,'-'),(4,'F5'),(6,'A5'),(8,'C6'),(12,'A5'),(14,'F5')],
  [(0,'G5'),(4,'E5'),(6,'G5'),(8,'C6'),(10,'B5'),(12,'G5'),(14,'E5')],
  [(0,'D5'),(2,'E5'),(4,'G5'),(8,'B5'),(10,'A5'),(12,'G5'),(14,'D5')],
])
M3 = mel([
  [(0,'A4'),(2,'C5'),(4,'E5'),(6,'A5'),(10,'G5'),(12,'E5'),(14,'C5')],
  [(0,'B4'),(2,'D5'),(4,'G5'),(6,'B5'),(10,'A5'),(12,'G5'),(14,'D5')],
  [(0,'A4'),(2,'C5'),(4,'F5'),(6,'A5'),(10,'G5'),(12,'F5'),(14,'C5')],
  [(0,'G#4'),(2,'B4'),(4,'E5'),(6,'G#5'),(8,'B5'),(12,'G#5'),(14,'E5')],
])
M4 = mel([   # over Dm G C Am
  [(0,'D5'),(2,'F5'),(4,'A5'),(8,'G5'),(10,'F5'),(12,'E5'),(14,'D5')],
  [(0,'B4'),(4,'D5'),(6,'G5'),(8,'F5'),(10,'D5'),(12,'B4'),(14,'D5')],
  [(0,'E5'),(2,'G5'),(4,'C6'),(8,'B5'),(10,'G5'),(12,'E5'),(14,'G5')],
  [(0,'A5'),(6,'E5'),(8,'C5'),(10,'E5'),(12,'A5'),(15,'-')],
])
M5 = mel([   # over F G Em Am - soaring
  [(0,'A5'),(4,'C6'),(8,'F6'),(12,'E6'),(14,'C6')],
  [(0,'D6'),(4,'B5'),(8,'G5'),(12,'B5'),(14,'D6')],
  [(0,'E6'),(4,'B5'),(8,'G5'),(10,'E5'),(12,'G5'),(14,'B5')],
  [(0,'A5'),(8,'E6'),(12,'C6'),(14,'A5')],
])

# ---------------- drums ----------------
K, S, H, O, C = 1, 2, 3, 4, 5
def drum_bar(style, bar, fill=False):
    if style == 'four':
        b = {0:K, 2:H, 4:S, 6:H, 8:K, 10:K, 12:S, 14:H}
    elif style == 'break':
        b = {0:K, 2:H, 4:S, 7:K, 8:H, 10:K, 12:S, 14:O}
    elif style == 'hats':
        b = {0:H, 4:H, 8:H, 12:H, 14:H}
    elif style == 'kick':
        b = {0:K, 8:K}
    elif style == 'kick4':
        b = {0:K, 4:K, 8:K, 12:K}
    elif style == 'drive':
        b = {0:K, 2:H, 3:H, 4:S, 6:K, 8:H, 10:K, 11:H, 12:S, 14:H, 15:H}
    else:
        b = {}
    if fill:
        b = {0:K, 2:S, 4:S, 6:K, 8:S, 9:S, 10:S, 11:S, 12:S, 13:S, 14:S, 15:S}
    return b

def drums(style, fill=False, crash=True):
    ev = []
    for bar in range(4):
        d = drum_bar(style, bar, fill and bar == 3)
        for k, v in d.items():
            ev.append((bar*16 + k, v))
    if crash:
        ev = [e for e in ev if e[0] != 0] + [(0, C)]
    return from_events(ev)

# build pattern bank
pat('silent', empty())
for p in 'ABCD':
    pat('bb'+p, bass_bounce(p)); pat('bbf'+p, bass_bounce(p, True))
    pat('bd'+p, bass_drive(p)); pat('bl'+p, bass_long(p)); pat('bp'+p, bass_pulse(p))
    pat('la'+p, lead_arp(p)); pat('ls'+p, lead_arp(p, 0, True)); pat('lh'+p, lead_arp(p, 12))
pat('M1', M1); pat('M2', M2); pat('M3', M3); pat('M4', M4); pat('M5', M5)
for st in ['four', 'break', 'hats', 'kick', 'kick4', 'drive']:
    pat('d_'+st, drums(st, crash=False))
    pat('dc_'+st, drums(st, crash=True))
    pat('df_'+st, drums(st, fill=True, crash=False))
    pat('dcf_'+st, drums(st, fill=True, crash=True))

# ---------------- instruments ----------------
# (arp0, arp1, arp2, duty table)
instruments = [
    (0, 0, 0, 1),     # 0 lead, pwm sweep
    (0, 4, 7, 0),     # 1 major arp, square
    (0, 3, 7, 0),     # 2 minor arp, square
    (0, 12, 0, 2),    # 3 octave, thin
    (0, 4, 7, 3),     # 4 major arp, pluck pwm
    (0, 3, 7, 3),     # 5 minor arp, pluck pwm
    (0, 0, 0, 2),     # 6 lead thin
    (0, 0, 12, 1),    # 7 lead with octave shimmer
]
def tri(a, b):
    return [int(a + (b - a) * (1 - abs(1 - 2 * i / 15))) for i in range(16)]
duty_tables = [
    [128] * 16,                                  # 0 square
    tri(72, 128),                                # 1 gentle pwm sweep
    [80] * 16,                                   # 2 mellow
    [128, 120, 112, 104, 96, 90, 84, 80, 76, 72, 70, 68, 66, 64, 64, 64],   # 3 pluck
]

# ---------------- arrangement ----------------
# order: (lead, bass, drums, insA, insB, transpose)
orders = []
def o(lead, bass, dr, ia=0, ib=0, tr=0):
    orders.append((pat_index[lead], pat_index[bass], pat_index[dr], ia, ib, tr))
# --- P1 boot / glitch / logo (orders 0-5)
o('silent', 'blA', 'silent')                 # 0 boot screen
o('silent', 'blA', 'd_kick')                 # 1 glitch + speech
o('laA', 'bpA', 'dc_kick4', 1, 2)            # 2 logo slam
o('laA', 'bbA', 'df_four', 1, 2)             # 3
o('M1', 'bbA', 'dc_four', 0)                 # 4
o('M2', 'bbfA', 'df_four', 7)                # 5
# --- P2 plasma (orders 6-13)
o('lsB', 'bdB', 'dc_break', 4, 5)            # 6
o('lsB', 'bdB', 'd_break', 4, 5)             # 7
o('M3', 'bdB', 'dc_drive', 0)                # 8
o('M3', 'bdB', 'df_drive', 7)                # 9
o('laA', 'bbA', 'dc_four', 1, 2)             # 10
o('M1', 'bbA', 'd_four', 0)                  # 11
o('M2', 'bbA', 'd_four', 7)                  # 12
o('lhA', 'bbfA', 'df_four', 1, 2)            # 13
# --- P3 raster insanity (14-21)
o('laC', 'blC', 'd_hats', 4, 5)              # 14 breakdown
o('laC', 'bpC', 'dc_kick4', 4, 5)            # 15
o('M4', 'bdC', 'dc_drive', 0)                # 16
o('M4', 'bdC', 'df_drive', 7)                # 17
o('lsC', 'bdC', 'd_break', 1, 2)             # 18
o('lsC', 'bbC', 'df_break', 1, 2)            # 19
o('M3', 'bdB', 'dc_drive', 6)                # 20
o('M3', 'bdB', 'df_drive', 0)                # 21
# --- P4 3D madness (22-29)
o('laD', 'blD', 'dc_hats', 1, 2)             # 22
o('lsD', 'bpD', 'd_kick4', 1, 2)             # 23
o('M5', 'bbD', 'dc_four', 7)                 # 24
o('M5', 'bbD', 'df_four', 0)                 # 25
o('lhD', 'bdD', 'dc_drive', 1, 2)            # 26
o('lhD', 'bdD', 'df_drive', 1, 2)            # 27
o('M1', 'bbA', 'dc_four', 0)                 # 28
o('M2', 'bbfA', 'df_four', 7)                # 29
# --- P5 semigraphics showcase (30-37)
o('lsB', 'bdB', 'dc_break', 4, 5)            # 30
o('M3', 'bdB', 'd_break', 0)                 # 31
o('M3', 'bdB', 'df_drive', 7)                # 32
o('laC', 'bbC', 'dc_four', 1, 2)             # 33
o('M4', 'bdC', 'd_drive', 0)                 # 34
o('M4', 'bdC', 'df_drive', 7)                # 35
o('lsD', 'bdD', 'dc_break', 1, 2)            # 36
o('M5', 'bbD', 'df_four', 7)                 # 37
# --- P6 finale (38-45)
o('laA', 'bdA', 'dc_drive', 1, 2, 0)         # 38
o('M1', 'bdA', 'd_drive', 0)                 # 39
o('M2', 'bdA', 'df_drive', 7)                # 40
o('M5', 'bbD', 'dc_four', 7)                 # 41
o('M5', 'bbD', 'df_four', 0)                 # 42
o('lhA', 'bbA', 'dc_four', 1, 2)             # 43
o('laA', 'blA', 'dc_kick', 1, 2)             # 44 closing logo
o('silent', 'blA', 'silent')                 # 45 end
LOOP_ORDER = 44

# ---------------- drum samples (1-bit, RATE Hz) ----------------
def bits_from_density(env_fn, length, tone_fn=None, seed=0):
    rnd = random.Random(seed)
    out = []
    for i in range(length):
        t = i / RATE
        v = 0
        if tone_fn:
            v = tone_fn(t, i)
        d = env_fn(t)
        if d > 0 and rnd.random() < d:
            v ^= 1
        out.append(v)
    return out

def kick():
    L = int(0.085 * RATE); out = []; ph = 0
    for i in range(L):
        t = i / RATE
        f = 50 + 160 * math.exp(-t * 45)
        ph += f / RATE
        frac = ph % 1.0
        width = 0.5 * math.exp(-t * 18) + 0.08
        out.append(1 if frac < width else 0)
    return out

def snare():
    L = int(0.09 * RATE)
    def tone(t, i): return 1 if (t * 210) % 1.0 < 0.5 * math.exp(-t * 60) else 0
    return bits_from_density(lambda t: 0.32 * math.exp(-t * 32), L, tone, 7)

def hat():
    L = int(0.03 * RATE)
    return bits_from_density(lambda t: 0.22 * math.exp(-t * 110), L, None, 11)

def ohat():
    L = int(0.07 * RATE)
    return bits_from_density(lambda t: 0.2 * math.exp(-t * 40), L, None, 13)

def crash():
    L = int(0.16 * RATE)
    return bits_from_density(lambda t: 0.28 * math.exp(-t * 16), L, None, 17)

samples = [kick(), snare(), hat(), ohat(), crash()]
TAIL = 152

def main():
    os.makedirs(OUT, exist_ok=True)
    global patterns
    used = sorted({x for od in orders for x in od[:3]})
    remap = {u: i for i, u in enumerate(used)}
    orders[:] = [(remap[a], remap[b], remap[c], d, e, f) for (a, b, c, d, e, f) in orders]
    patterns = [patterns[u] for u in used]
    L = []
    L.append(f'; generated by song.py  RATE={RATE:.1f}Hz  orders={len(orders)}')
    L.append(f'SONG_SPEED EQU {SPEED}')
    L.append(f'SONG_ORDERS EQU {len(orders)}')
    L.append(f'SONG_RATE EQU {int(RATE)}')
    L.append('freq_table:')
    fr = []
    for k in range(96):
        inc = int(round(freq(k) * 65536 / RATE))
        fr.append(min(inc, 32000))
    for i in range(0, 96, 12):
        L.append('        dw ' + ','.join(str(x) for x in fr[i:i+12]))
    L.append('instruments:')
    for ins in instruments:
        L.append('        db ' + ','.join(str(x & 255) for x in ins))
    L.append('duty_tables:')
    for t in duty_tables:
        L.append('        db ' + ','.join(str(x) for x in t))
    L.append('song_orders:')
    for i, od in enumerate(orders):
        if i == LOOP_ORDER:
            L.append('song_loop:')
        L.append('        db ' + ','.join(str(x & 255) for x in od) + f'   ; {i}')
    L.append('        db $FF')
    L.append('        dw song_loop')
    L.append('drum_table:')
    for k in range(len(samples)):
        L.append(f'        dw drum{k}, drum{k}_end')
    L.append('pat_ptrs:')
    for i in range(len(patterns)):
        L.append(f'        dw patterns+{64*i}')
    L.append('patterns:')
    for i, p in enumerate(patterns):
        L.append('        db ' + ','.join(str(x) for x in p))
    for k, s in enumerate(samples):
        L.append(f'drum{k}:')
        bs = [0x21 if b else 0 for b in s]
        for i in range(0, len(bs), 32):
            L.append('        db ' + ','.join(str(x) for x in bs[i:i+32]))
        L.append(f'drum{k}_end:')
        L.append(f'        ds {TAIL},0')
    open(os.path.join(OUT, 'song.inc'), 'w').write('\n'.join(L) + '\n')
    tot = sum(len(s) + TAIL for s in samples)
    print(f'song: {len(orders)} orders, {len(patterns)} patterns ({len(patterns)*64} bytes), drums {tot} bytes, RATE {RATE:.1f}')
    print(f'duration {len(orders)*64*SPEED/FPS:.1f}s')
    # export pattern index for demo script timing
    open(os.path.join(OUT, 'song_meta.txt'), 'w').write(f'{len(orders)} {SPEED} {FPS}\n')

main()
