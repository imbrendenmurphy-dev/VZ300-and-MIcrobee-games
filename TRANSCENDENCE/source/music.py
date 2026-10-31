# TRANSCENDENCE soundtrack - compiled to 2-voice sequencer data
# Grid: 32 frames per beat (93.75 bpm), 128 frames per bar, 50 Hz fields.
BEAT = 32
BAR = 128

# envelopes: kind(0 decay/1 swell), A(peak duty), S(sustain), step, period
ENVS = [
    [0, 60, 0, 3, 1],     # 0 pluck soft
    [1, 92, 44, 2, 2],    # 1 pad swell
    [0, 110, 58, 1, 3],   # 2 bass warm
    [0, 34, 10, 1, 4],    # 3 ethereal
    [0, 26, 0, 2, 1],     # 4 echo 1
    [0, 14, 0, 1, 1],     # 5 echo 2
    [0, 72, 20, 2, 2],    # 6 motif
    [0, 128, 0, 8, 1],    # 7 deep pulse
    [1, 118, 70, 1, 3],   # 8 slow pad
    [0, 104, 26, 5, 1],   # 9 bass pluck
    [0, 66, 40, 1, 3],    # 10 lead sustain
    [1, 60, 30, 1, 2],    # 11 soft swell lead
    [0, 46, 0, 1, 2],     # 12 long ethereal tail
]
KICK, HAT, SNARE, HEART, HEARTF = 0, 1, 2, 3, 4

NAMES = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}
def N(s):
    name = s[:-1]; octv = int(s[-1])
    return (octv-1)*12 + NAMES[name]     # C1 = 0

class Ch:
    def __init__(self):
        self.b = []; self.t = 0; self.cur_env = None
    def env(self, e):
        if e != self.cur_env:
            self.b += [0x61, e]; self.cur_env = e
    def note(self, n, fr):
        if isinstance(n, str): n = N(n)
        assert 0 <= n < 96, n
        first = min(fr, 255)
        self.b += [n, first]; fr -= first; self.t += first
        while fr > 0:
            k = min(fr, 255); self.b += [0x67, k]; fr -= k; self.t += k
    def rest(self, fr):
        while fr > 0:
            k = min(fr, 255); self.b += [0x60, k]; fr -= k; self.t += k
    def drum(self, d): self.b += [0x65, d]
    def mark(self, v): self.b += [0x66, v]
    def at(self, fr):
        assert fr >= self.t, (fr, self.t)
        self.rest(fr - self.t)
    def end(self): self.b += [0x68]

    # a note with a delay echo inside its slot
    def echo(self, n, slot, main_env=6, on=None):
        on = on or max(8, slot//3)
        if slot < on + 8:
            self.env(main_env); self.note(n, slot); return
        self.env(main_env); self.note(n, on)
        rem = slot - on
        e1 = min(rem, on)
        self.env(4); self.note(n, e1); rem -= e1
        if rem > 0:
            e2 = min(rem, on)
            self.env(5); self.note(n, e2); rem -= e2
        if rem > 0: self.rest(rem)

MOTIF = ['B4', 'F#5', 'E5', 'G5']
MOTIF_R = [32, 48, 16, 96]           # rhythm (frames), 1.5 bars total = 192
def up(n, k):
    return n[:-1] + str(int(n[-1]) + k)

def motif(ch, start, octave=0, env=6, rhythm=MOTIF_R, notes=MOTIF, echo=True):
    ch.at(start)
    for n, r in zip(notes, rhythm):
        nn = up(n, octave)
        if echo: ch.echo(nn, r, env)
        else:
            ch.env(env); ch.note(nn, r)

def pad(ch, start, notes, bars_each=2, env=8):
    ch.at(start)
    for n in notes:
        ch.env(env); ch.note(n, bars_each*BAR)

def compile_song():
    a = Ch()   # ch1: bass / pulse / kick
    m = Ch()   # ch2: motif / melody / hats
    # ------------------------------------------------ I  THE ARRIVAL (0-24)
    a.env(7); a.note('E1', 20); a.at(BAR); a.note('E1', 20); a.at(2*BAR - 40); a.note('E1', 14)
    pad(a, 2*BAR, ['E2', 'E2'], 2)                      # bars 2-5
    pad(a, 6*BAR, ['E2', 'C2', 'G1', 'D2', 'E2', 'C2'], 2)   # bars 6-17
    pad(a, 18*BAR, ['C2', 'G1', 'A1'], 2)               # sunset bars 18-23
    m.at(int(2.2*BAR))
    motif(m, int(3*BAR), 1, env=3)                      # first, quiet, high
    # sparse pentatonic between motifs
    def sparse(ch, start, seq, step, until=None):
        ch.at(start)
        for n in seq:
            if until and ch.t + step > until: break
            if n: ch.echo(n, step, 0, on=12)
            else: ch.rest(step)
    motif(m, 6*BAR, 0)
    sparse(m, int(7.5*BAR), ['E5', None, 'D5', 'B4', None, 'A4', None, None, 'G4', None, 'B4', None], 32, 10*BAR)
    motif(m, 10*BAR, 0)
    sparse(m, int(11.5*BAR), ['A5', None, 'G5', None, 'E5', None, None, 'D5', 'E5', None, None, None], 32, 14*BAR)
    motif(m, 14*BAR, 0, env=6)
    sparse(m, int(15.5*BAR), ['G5', None, None, 'F#5', None, None, 'D5', None, 'E5', None, None, None], 32, 18*BAR)
    # sunset theme (warm)
    m.at(18*BAR)
    sun = [('G4',64),('A4',32),('B4',32),('D5',96),('B4',32),('A4',64),('G4',32),('E4',160),
           ('G4',32),('B4',32),('D5',64),('E5',96),('D5',32),('B4',64),('A4',64),('B4',128)]
    for n, r in sun[:8]: m.echo(n, r, 10, on=min(r, 48))
    motif(m, 22*BAR, -1, env=3)
    # ------------------------------------------------ II THE SEARCH (24-44)
    b0 = 24*BAR
    roots = ['E', 'C', 'D', 'B']
    a.at(b0)
    for bar in range(20):
        r = roots[(bar//4) % 4]
        lo = r + ('1' if r in 'CDE' else '0') if r != 'B' else 'B0'
        lo = {'E':'E1','C':'C2','D':'D2','B':'B1'}[r]
        hi = up(lo, 1)
        a.at(b0 + bar*BAR)
        a.env(9); a.note(lo, 24); a.rest(56)
        a.note(lo if bar % 2 else hi, 16); a.rest(32)
    m.at(b0)
    notes2 = ['E5','B4',None,'G5',None,'A4','D5',None,'B4',None,'E5',None,'F#5','D5',None,None]
    for bar in range(16):
        base = b0 + bar*BAR
        m.at(base)
        if bar in (4, 10):
            for n, r in zip(MOTIF[:2], [32, 96]): m.echo(n, r, 6)
            continue
        for k in range(4):
            n = notes2[(bar*3 + k*5) % len(notes2)]
            if k == 1 or k == 3:
                m.drum(HAT)
            if n and (bar + k) % 2 == 0: m.echo(n, 32, 0, on=10)
            else: m.rest(32)
    # discovery: full motif then the human theme begins
    motif(m, 40*BAR, 0)
    HUMAN = [('E4',64),('G4',32),('A4',32),('B4',96),('A4',32),('G4',64),('F#4',32),('D4',32),('E4',128)]
    m.at(int(41.5*BAR))
    for n, r in HUMAN[:4]: m.echo(n, r, 10, on=min(r, 48))
    # ------------------------------------------------ III THE ENCOUNTER (44-60)
    pad(a, 44*BAR, ['E2', 'C2', 'A1', 'B1', 'E2', 'C2', 'D2', 'B1'], 2)
    m.at(44*BAR)
    for rep in range(2):
        for n, r in HUMAN: m.echo(n, r, 10, on=min(r, 56))
        m.rest(2*BAR - 0)
    motif(m, 57*BAR, 1, env=3)
    # ------------------------------------------------ IV AWAKENING + TAI CHI (60-84)
    pad(a, 60*BAR, ['C2', 'E2'], 2)
    m.at(60*BAR)
    merged = [('B4',32),('F#5',48),('E5',16),('G5',64),('B4',32),('A4',32),('G4',32),('E4',128)]
    for n, r in merged: m.echo(n, r, 6, on=min(r, 40))
    m.mark(1)                                   # the entity has entered
    # tai chi groove bars 64-84
    prog = [('E2','E3','G2','B1'), ('C2','C3','E2','G1'), ('D2','D3','F#2','A1'), ('B1','B2','D#2','F#1')]
    a.at(64*BAR)
    for bar in range(20):
        r = prog[(bar//2) % 4]
        base = 64*BAR + bar*BAR
        a.at(base)
        pat = [(0, r[0], 16, True), (24, None, 0, False), (40, r[0], 8, True), (56, r[2], 16, False),
               (80, r[1], 8, False), (96, r[0], 16, True), (120, r[3], 8, False)]
        for off, n, ln, kick in pat:
            a.at(base + off)
            if bar >= 2 and kick: a.drum(KICK)
            if n: a.env(9); a.note(n, ln)
        a.at(base + BAR)
    m.at(64*BAR)
    flow = ['B4','F#5','E5','G5','E5','B4','D5','A4']
    for bar in range(20):
        base = 64*BAR + bar*BAR
        m.at(base)
        offs = [0, 48, 96]          # 3+3+2 feel
        for i, off in enumerate(offs):
            m.at(base + off)
            if bar >= 1: m.drum(HAT)
            n = flow[(bar*3 + i) % len(flow)]
            if bar >= 12: n = up(n, 1) if i == 0 else n
            ln = 48 if i < 2 else 32
            m.echo(n, ln, 0 if bar < 8 else 6, on=14)
    # ------------------------------------------------ V SEPARATION (84-94)
    pad(a, 84*BAR, ['E1', 'B1', 'E1', 'C2'], 2)
    a.at(92*BAR); a.env(8); a.note('E2', 2*BAR)
    m.at(84*BAR)
    for n, r in zip(MOTIF, [64, 96, 32, 192]):
        m.echo(up(n, 1), r, 3, on=min(r, 48))
    m.rest(BAR)
    for n, r in zip(MOTIF, [64, 96, 32, 192]):
        m.echo(up(n, 1), r, 12, on=min(r, 64))
    m.at(92*BAR)
    for n in ['B5', 'D6', 'E6', 'F#6']: m.echo(n, 64, 3, on=24)
    # ------------------------------------------------ VI FLIGHT (94-110)
    roots6 = [('E2','E3'), ('C2','C3'), ('G1','G2'), ('D2','D3')]
    for bar in range(16):
        base = 94*BAR + bar*BAR
        lo, hi = roots6[(bar//2) % 4]
        a.at(base)
        for k in range(8):
            a.at(base + k*16)
            if (bar >= 4 and k in (0, 4)) or (bar >= 8 and k in (2, 6) and bar % 2): a.drum(KICK)
            a.env(9); a.note(hi if k in (3, 6) else lo, 10)
        a.at(base + BAR)
    m.at(94*BAR)
    for rep in range(4):
        t0 = 94*BAR + rep*4*BAR
        shift = [0, 2, 3, 5][rep]
        ns = [N(x) + shift for x in MOTIF]
        m.at(t0)
        for k in range(2):
            for n, r in zip(ns, MOTIF_R):
                m.echo(n, r, 6, on=min(r, 32))
            m.at(t0 + (k+1)*2*BAR - 64)
            for hh in range(4):
                m.drum(HAT); m.rest(16)
    # ------------------------------------------------ VII THE PASSAGE (110-130)
    prog7 = ['E2', 'E2', 'C2', 'C2', 'A1', 'A1', 'B1', 'B1']
    for bar in range(19):
        base = 110*BAR + bar*BAR
        r = prog7[bar % 8]
        a.at(base)
        pat = [(0, r, 8), (16, up(r, 1), 8), (40, r, 8), (64, r, 8), (88, up(r, 1), 8), (104, r, 8), (120, up(r,1), 8)]
        for off, n, ln in pat:
            a.at(base + off)
            if off in (0, 32, 64, 96) or (bar >= 10 and off == 88): a.drum(KICK)
            a.env(9); a.note(n, ln)
        a.at(base + BAR)
    a.at(129*BAR); a.env(7); a.note('E1', 40)
    m.at(110*BAR)
    rise = ['E4', 'G4', 'A4', 'B4', 'D5', 'E5', 'G5', 'A5', 'B5', 'D6']
    t = 110*BAR
    for i, n in enumerate(rise):
        m.at(t)
        for h in range(4):
            if i >= 3: m.drum(HAT if h % 2 else SNARE if i >= 6 and h == 2 else HAT)
            m.env(11 if i < 6 else 1); m.note(n, 32)
        t += BAR
        if t >= 120*BAR: break
    m.at(120*BAR)
    for rep in range(4):
        motif(m, 120*BAR + rep*2*BAR, 1 if rep < 3 else 1, env=6)
    m.at(128*BAR)
    for n in ['E6', 'G6', 'B6', 'E7']: m.echo(n, 32, 6, on=10)
    m.at(129*BAR); m.rest(BAR)
    # ------------------------------------------------ VIII REBIRTH (130-146)
    pad(a, 130*BAR, ['E2', 'B1', 'C2', 'A1', 'E2', 'B1'], 2)
    a.at(142*BAR); a.env(8); a.note('E1', 4*BAR)
    m.at(130*BAR)
    RESOLVED = ['B4', 'F#5', 'E5', 'G#5']
    motif(m, 130*BAR + 32, 0, env=10, notes=RESOLVED, rhythm=[48, 64, 32, 160])
    m.at(133*BAR)
    warm = [('G#5',96),('B5',64),('E6',160),('F#5',96),('E5',128)]
    for n, r in warm: m.echo(n, r, 3, on=min(r, 48))
    motif(m, 138*BAR, 0, env=3, notes=RESOLVED, rhythm=[64, 96, 32, 192])
    m.at(141*BAR)
    for n in ['E6', None, 'B5', None, None, 'G#5', None, None, None, 'E5']:
        if n: m.echo(n, 64, 12, on=40)
        else: m.rest(64)
    # ------------------------------------------------ IX SILENCE (146-158)
    EP = 146*BAR
    m.at(EP + 1470)
    m.drum(SNARE); m.env(0); m.note('B5', 10); m.rest(40)
    m.at(EP + 1530)
    m.echo('B4', 40, 3, on=16)
    m.echo('F#5', 120, 3, on=40)
    m.end()
    a.at(146*BAR)
    a.rest(2*BAR)
    beats = [(HEART, 0), (HEART, 76), (HEART, 0), (HEART, 80), (HEARTF, 0), (HEARTF, 90), (HEARTF, 0), (HEARTF, 110)]
    t = 148*BAR
    for i in range(5):
        a.at(t); a.drum(HEART if i < 3 else HEARTF); a.rest(14)
        a.drum(HEART if i < 2 else HEARTF); a.rest(4)
        t += 84 + i*16
    a.at(t + 40); a.drum(HEARTF); a.rest(2)
    # epilogue: the sleeper's heart, then the startle and a racing pulse
    for tt in (1350, 1430):
        a.at(EP + tt); a.drum(HEARTF); a.rest(14); a.drum(HEARTF); a.rest(4)
    a.at(EP + 1470); a.drum(KICK); a.env(7); a.note('E1', 26)
    for tt in (1508, 1540, 1570, 1600, 1634, 1672, 1714):
        a.at(EP + tt); a.drum(HEART); a.rest(12); a.drum(HEART); a.rest(4)
    a.end()
    return a.b, m.b

if __name__ == '__main__':
    a, b = compile_song()
    print(len(a), len(b))
