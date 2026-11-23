#!/usr/bin/env python3
"""OCTOCHROME build:  py octo/build.py  ->  octo/out/OCTO.VZ

Generates the cycle-exact raster kernel (gen/kernel.inc), checking every
unit is exactly 456 T (two scanlines of 228 T), plus data and the tune."""
import os, sys, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
sys.path.insert(0, HERE)
import gfx, song

GEN = os.path.join(HERE, 'gen')
OUT = os.path.join(HERE, 'out')
os.makedirs(GEN, exist_ok=True)
os.makedirs(OUT, exist_ok=True)

LINE_T = 228
UNIT_T = 2 * LINE_T
SLOTS = 16                      # split positions: W2 sits at slot d (0..16) of a 17-byte region


class Code:
    def __init__(self):
        self.lines = []
        self.t = 0

    def i(self, text, t, label=None):
        if label:
            self.lines.append('%s:' % label)
        self.lines.append('            ' + text)
        self.t += t

    def label(self, name):
        self.lines.append('%s:' % name)

    def region(self, name, w2):
        """17 one-byte slots: 16 NOPs (4 T) and one 7 T byte = 71 T whatever d is.
        w2 = True: the 7 T byte is LD (HL),C (the mid-line latch write); else LD E,(HL) (harmless)."""
        self.label(name)
        b = 0x71 if w2 else 0x5E
        self.lines.append('            db $%02X' % b + ',0' * SLOTS)
        self.t += 7 + 4 * SLOTS

    def pad(self, t, free='e'):
        """Exactly t T-states of filler that touches only register `free` (nop 4, ld r,0 7)."""
        assert t >= 0 and t not in (1, 2, 3, 5, 6, 9, 10, 13, 17), t
        while t > 0 and t % 4:
            self.i('ld %s,0' % free, 7)
            t -= 7
        assert t >= 0
        while t >= 4:
            self.i('nop', 4)
            t -= 4


def unit(n, w2):
    """One kernel unit = two scanlines. Entered by RET at T0 of line A.
    HL = LATCH, B = left/W1 latch value, C = W2 or flick value (both include speaker bits).
    IX, IY = voice 1, 2 phases; HL' = voice 3 phase (or noise LFSR in L'), E' = $1D.
    A' = voice mask accumulator. At the end it pops the next unit's data (E = W1 base, D = W2 base)
    into B and C with this sample's speaker bit, then RETs to the next unit."""
    c = Code()
    c.label(n)
    # ---- line A
    c.i('ld (hl),c', 7)                     # W1: flick (AG off) or split value, in the blanking
    c.i('ld (hl),b', 7)                     # W1: the line's left value
    c.i('ld de,0', 10, n + '_s1')           # voice 1
    c.i('add ix,de', 15)
    c.i('ld a,ixh', 8)
    c.i('cp 0', 7, n + '_d1')
    c.i('sbc a,a', 4)
    c.i("ex af,af'", 4)
    c.i('ld de,0', 10, n + '_s2')           # voice 2, first half
    c.i('add iy,de', 15)
    c.i('ld e,0', 7)
    ra = c.t
    c.region(n + '_ra', w2)
    c.i('ld a,iyh', 8)                      # voice 2, second half
    c.i('cp 0', 7, n + '_d2')
    c.i('sbc a,a', 4)
    c.i('ld e,a', 4)
    c.i("ex af,af'", 4)
    c.i('or e', 4)
    c.i("ex af,af'", 4)
    c.pad(LINE_T - c.t)
    assert c.t == LINE_T, (n, c.t)
    # ---- line B
    c.i('ld (hl),c', 7)
    c.i('ld (hl),b', 7)
    c.i('exx', 4)                           # voice 3: tone or noise (42 T each)
    c.i('jp %s_tone' % n, 10, n + '_v3')
    t0 = c.t
    c.lines.append('%s_tone:' % n)
    c.lines.append('            ld bc,0')
    c.lines.append('            add hl,bc')
    c.lines.append('            ld a,h')
    c.lines.append('%s_d3t:' % n)
    c.lines.append('            cp 0')
    c.lines.append('            sbc a,a')
    c.lines.append('            inc bc')
    c.lines.append('            jp %s_v3x' % n)  # 10+11+4+7+4+6 = 42, +10
    c.lines.append('%s_noise:' % n)
    c.lines.append('            sla l')
    c.lines.append('            sbc a,a')
    c.lines.append('            and e')
    c.lines.append('            xor l')
    c.lines.append('            ld l,a')
    c.lines.append('%s_d3n:' % n)
    c.lines.append('            cp 0')
    c.lines.append('            sbc a,a')
    c.lines.append('            ld d,0')
    c.lines.append('            jp %s_v3x' % n)  # 8+4+4+4+4+7+4+7 = 42, +10
    c.t += 42 + 10
    c.i('exx', 4, n + '_v3x')
    c.i('jp $+3', 10)
    rb = c.t - LINE_T
    assert rb == ra, (n, ra, rb)            # both lines' W2 at the same place
    c.region(n + '_rb', w2)
    c.i('ld e,a', 4)                        # mix: any voice on = speaker bit 5
    c.i("ex af,af'", 4)
    c.i('or e', 4)
    c.i('and $20', 7)
    c.i('ld c,a', 4)
    c.i('pop de', 10)                       # next unit's latch bases
    c.i('or e', 4)
    c.i('ld b,a', 4)
    c.i('ld a,c', 4)
    c.i('or d', 4)
    c.i('ld c,a', 4)
    c.i('ret', 10)
    assert c.t == UNIT_T, (n, c.t)
    return c.lines, ra


def delays(prefix, back):
    """Entry points prefix_0..15: jp to one gives 26 + x T, then jp back."""
    L = []
    instr = {0: ['inc de'], 1: ['ld d,0'], 2: ['nop', 'nop'], 3: ['ld a,i']}   # 6 7 8 9 T
    for x in range(16):
        L.append('%s_%d:' % (prefix, x))
        for s in instr[x & 3]:
            L.append('            ' + s)
        L.append('            jp %s_slide+%d' % (prefix, 3 - (x >> 2)))
    L.append('%s_slide:' % prefix)
    L.append('            nop')
    L.append('            nop')
    L.append('            nop')
    L.append('            jp %s' % back)
    return L


def pad_loop(c, t):
    """t T of delay using B (djnz loop) and nops / ld d,0."""
    if t >= 60:
        n = (t - 15) // 13            # ld b,n (7) + djnz: 13*(n-1) + 8
        n = min(n, 255)
        used = 7 + 13 * (n - 1) + 8
        rest = t - used
        while rest in (1, 2, 3, 5, 6, 9, 10, 13, 17) or rest < 0:
            n -= 1
            used = 7 + 13 * (n - 1) + 8
            rest = t - used
        c.i('ld b,%d' % n, 7)
        c.i('djnz $', 13 * (n - 1) + 8)
        c.pad(rest, 'd')
    else:
        c.pad(t, 'd')


def fsync_unit(p1, p2):
    """The fine-sync unit (see octo.asm). Length on the 'late' path = 216 + p1 + p2."""
    c = Code()
    c.label('fsu')
    c.i('ld hl,(fs_prep)', 16)
    c.i('jp (hl)', 4)
    c.t += 26                                  # + x
    c.label('fs_preb')
    pad_loop(c, p1)
    c.i('ld a,(FSREAD)', 13, 'fs_sample')
    c.i('rla', 4)
    c.i('jp c,fs_hi', 10)
    c.i('inc de', 6)                           # early: 2 T more
    c.i('jp fs_join', 10)
    c.lines.append('fs_hi:')
    c.lines.append('            nop')
    c.lines.append('            jp fs_join')
    c.t += 4 + 10 - 6 - 10                     # count the late path
    c.i('ld hl,(fs_postp)', 16, 'fs_join')
    c.i('jp (hl)', 4)
    c.t += 26 + 15                             # + (15 - x)
    c.label('fs_postb')
    c.i('ld hl,LATCH', 10)
    pad_loop(c, p2)
    c.i('pop de', 10)
    c.i('ld b,e', 4)
    c.i('ld c,d', 4)
    c.i('ret', 10)
    assert c.t == 186 + p1 + p2, c.t
    return c.lines + delays('fs_pre', 'fs_preb') + delays('fs_post', 'fs_postb')


COPIES = [('u_plain', False), ('u_scr', True), ('u_bara', True), ('u_barb', True)]
FS_P1 = 254              # sample threshold j >= 2 when the fine phase is 14
FS_P2 = 326


def gen_kernel():
    L = ['; generated by octo/build.py - the cycle-exact raster kernel', '; every unit is 456 T']
    ra = None
    for n, w2 in COPIES:
        lines, ra = unit(n, w2)
        L += lines
    L.append('W2_FIRST_T  equ %d          ; T of slot 0 in each line (from the unit start)' % ra)
    L += fsync_unit(FS_P1, FS_P2)
    # m_patch: copy the three voices into every unit copy
    P = ['m_patch:']
    P.append('            ld hl,(m_chan1+CH_STEP)')
    for n, _ in COPIES:
        P.append('            ld (%s_s1+1),hl' % n)
    P.append('            ld hl,(m_chan2+CH_STEP)')
    for n, _ in COPIES:
        P.append('            ld (%s_s2+1),hl' % n)
    P.append('            ld hl,(m_chan3+CH_STEP)')
    for n, _ in COPIES:
        P.append('            ld (%s_tone+1),hl' % n)
    for ch, lab in ((1, 'd1'), (2, 'd2')):
        P.append('            ld a,(m_chan%d+CH_DUTY)' % ch)
        P.append('            call m_mute')
        for n, _ in COPIES:
            P.append('            ld (%s_%s+1),a' % (n, lab))
    P.append('            ld a,(m_chan3+CH_DUTY)')
    P.append('            call m_mute')
    for n, _ in COPIES:
        P.append('            ld (%s_d3t+1),a' % n)
        P.append('            ld (%s_d3n+1),a' % n)
    P.append('            ld a,(m_chan3+CH_FLAGS)')
    P.append('            rra')
    P.append('            jr c,.noise')
    for n, _ in COPIES:
        P.append('            ld hl,%s_tone' % n)
        P.append('            ld (%s_v3+1),hl' % n)
    P.append('            ret')
    P.append('.noise:')
    for n, _ in COPIES:
        P.append('            ld hl,%s_noise' % n)
        P.append('            ld (%s_v3+1),hl' % n)
    P.append('            ld a,(m_ph3)')
    P.append('            or 1')
    P.append('            ld (m_ph3),a')
    P.append('            ret')
    # set_splits: A = slot for the scroller, B = bar band A, C = bar band B
    P.append('; set_split: HL = copy (its _ra), A = new slot, (old slot in (IX+0))')
    return '\n'.join(L + P) + '\n'


def db(data, per=16):
    data = bytes(data)
    return '\n'.join('            db ' + ','.join('$%02X' % b for b in data[i:i + per])
                     for i in range(0, len(data), per))


SCROLL = ("     HELLO DAVE!   THIS ONE IS FOR YOU AND THE WHOLE VZ200 VZ300 LASER 210 310 CREW.   "
          "OCTOCHROME SHOWS ALL 8 COLOURS AT ONCE IN THE 128X64 MODE, BY SWITCHING THE COLOUR SET "
          "(CSS0 TO CSS1) IN THE MIDDLE OF EVERY SCANLINE - INSPIRED BY DAVE'S SPLIT CSS EXPERIMENTS.   "
          "THE BOUNCE IS REAL FLD: A QUICK MODE FLICK IN THE BORDER MAKES THE 6847 REPEAT A LINE, "
          "SO THE TEXT DROPS WITHOUT MOVING A BYTE.   THE MUSIC IS MIXED INTO THE SAME CYCLE-EXACT "
          "LOOP, ONE SAMPLE EVERY TWO SCANLINES.   VIBED BY BPM 2026.   KEEP THOSE VZS ALIVE!        ")


def font2x():
    """Each glyph: 4 byte-columns x 8 rows (the 8x8 mode 1 font doubled sideways).
    Letter colour 1, shadow 3, background 2."""
    f1 = gfx.font_mode1()
    out = bytearray()
    for g in range(len(gfx.FONT_CHARS)):
        px = [[0] * 8 for _ in range(8)]
        for col in range(2):
            for y in range(8):
                b = f1[g * 16 + col * 8 + y]
                for k in range(4):
                    px[y][col * 4 + k] = (b >> (6 - 2 * k)) & 3
        for bc in range(4):
            for y in range(8):
                b = 0
                for k in range(4):
                    p = px[y][(bc * 4 + k) // 2]
                    if p == 0:
                        p = 2
                    b = (b << 2) | p
                out.append(b)
    return bytes(out)


def screen():
    """The mode 1 picture (2K): logo, held blank rows, scroller band, bars, bottom title."""
    v = bytearray(2048)
    f1 = gfx.font_mode1()

    def text(row, s, bg):
        x0 = (16 - len(s)) // 2 * 2
        for i, ch in enumerate(s):
            g = gfx.font_index(ch)
            for col in range(2):
                for y in range(8):
                    b = f1[g * 16 + col * 8 + y]
                    m = 0
                    for k in range(4):
                        p = (b >> (6 - 2 * k)) & 3
                        m = (m << 2) | (p if p else bg)
                    v[(row + y) * 32 + x0 + i * 2 + col] = m
    for r in range(0, 16):
        for x in range(32):
            v[r * 32 + x] = 0x00
    text(0, 'VZ200 VZ300', 0)
    text(8, 'LASER 210 310', 0)
    for r in range(16, 26):
        for x in range(32):
            v[r * 32 + x] = 0xAA
    for r in range(26, 42):
        for x in range(32):
            v[r * 32 + x] = ((x >> 1) & 3) * 0x55
    for r in range(42, 64):
        for x in range(32):
            v[r * 32 + x] = 0x00
    text(43, 'OCTOCHROME', 0)
    return bytes(v)


def gen_data():
    L = ['; generated by octo/build.py']
    L.append('font2:')
    L.append(db(font2x()))
    L.append('scr_text:')
    L.append(db(gfx.text_codes(SCROLL) + b'\xFF'))
    L.append('screen_img:')
    L.append(db(screen()))
    L.append('sintab:')
    L.append(db(gfx.sin_table()))
    L.append('digits1:')                       # font indices of 0-9 for the phase readout
    L.append(db(bytes(gfx.font_index(str(d)) for d in range(10))))
    L.append('font1:')
    L.append(db(gfx.font_mode1()))
    return '\n'.join(L) + '\n'


def main():
    open(os.path.join(GEN, 'kernel.inc'), 'w').write(gen_kernel())
    open(os.path.join(GEN, 'data.inc'), 'w').write(gen_data())
    open(os.path.join(GEN, 'song.inc'), 'w').write(song.asm())
    binf = os.path.join(OUT, 'octo.bin')
    r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'zasm.py'), os.path.join(HERE, 'octo.asm'),
                        '-o', binf, '--sym', os.path.join(OUT, 'octo.sym'), '--lst', os.path.join(OUT, 'octo.lst')],
                       capture_output=True, text=True)
    print(r.stdout.strip(), r.stderr.strip())
    if r.returncode:
        sys.exit(1)
    syms = {}
    for line in open(os.path.join(OUT, 'octo.sym')):
        a, n = line.split()
        syms[n] = int(a, 16)
    print('code+data $8000-$%04X, variables to $%04X' % (0x8000 + os.path.getsize(binf) - 1, syms['vars_end']))
    assert syms['vars_end'] <= 0xB400, 'variables run into the stack'
    subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'mkvz.py'), binf, os.path.join(OUT, 'OCTO.VZ'),
                    '0x8000', 'OCTOCHROME'], check=True)


if __name__ == '__main__':
    main()
