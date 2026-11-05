"""Build the front-end data for uB-TYPE.

  build/TITLE.BNK  (memory block 5, 32K)
      0000-3FFF  PCG banks 2-9 for the front end:
                   banks 2-3  title picture (logo, planet horizon)
                   banks 4-5  big two-cell font
                   bank 6     the crossing ship (4 x-phases x 2 exhaust frames)
                   bank 7     capsule icons
      4000-43FF  title picture codes   (64 x 16, 0 = empty)
      4400-47FF  title picture banks
      4800-4BFF  title picture colours
  build/front.inc  strings, tunes, pitch tables, font/ship/capsule tables
"""
import sys
from pathlib import Path
import numpy as np
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / 'vz'))
import mbtitle as T
import mbsprart
import mbart as A

BUILD = HERE.parent / 'build'
out = []


def emit(s):
    out.append(s)


def db(lst, per=16):
    for i in range(0, len(lst), per):
        emit('\tdb ' + ','.join('$%02x' % (v & 255) for v in lst[i:i + per]))


class Glyphs:
    """glyph allocator over consecutive PCG banks (128 codes each)"""
    def __init__(self, bank0, nbanks):
        self.bank0, self.n = bank0, nbanks
        self.gl = []
        self.idx = {}

    def get(self, g):
        if g not in self.idx:
            self.idx[g] = len(self.gl)
            self.gl.append(g)
            assert len(self.gl) <= 128 * self.n, 'out of glyphs'
        i = self.idx[g]
        return 0x80 | (i & 127), self.bank0 + (i >> 7)


def text_codes(s):
    """a string in the bank-0 font: ASCII 32..95, '~' is the mu glyph"""
    r = []
    for ch in s:
        if ch == '~':
            r.append(0x80 + 79)
        else:
            c = ord(ch.upper())
            assert 32 <= c < 96, s
            r.append(0x80 + c - 32)
    return r


def canvas_pic(c, ox, oy, w, h):
    """a sprite canvas -> colour picture (lit pixels in their colour)"""
    img = np.zeros((h, w), np.uint8)
    on = c.bits()
    for y in range(c.h):
        for x in range(c.w):
            if on[y, x] and 0 <= oy + y < h and 0 <= ox + x < w:
                img[oy + y, ox + x] = c.col[y, x]
    return img


def build():
    bnk = bytearray(0x8000)
    # ---- title picture: banks 2-3
    img, (lc0, lc1) = T.title_picture()
    cells = T.to_cells(img)
    G = Glyphs(2, 2)
    for (r, c), (g, col) in sorted(cells.items()):
        code, bank = G.get(g)
        i = r * 64 + c
        bnk[0x4000 + i] = code
        bnk[0x4400 + i] = bank
        bnk[0x4800 + i] = col
    for k, g in enumerate(G.gl):
        bnk[k * 16:k * 16 + 16] = g
    print('title picture: %d cells, %d glyphs, logo columns %d-%d' % (len(cells), len(G.gl), lc0, lc1))
    emit('LOGO_C0 equ %d' % lc0)
    emit('LOGO_C1 equ %d' % lc1)
    emit('LOGO_R0 equ %d' % T.LOGO_ROW0)
    emit('LOGO_NR equ %d' % (len(T.LOGO_BANDS)))
    emit('HZ_R0 equ %d' % T.HZ_ROW0)

    # ---- big font: banks 4-5
    chars, bf = T.big_font()
    BF = Glyphs(4, 2)
    tab_code, tab_bank = [], []
    for ch in chars:
        for g in bf[ch]:
            code, bank = BF.get(g)
            tab_code.append(code)
            tab_bank.append(bank)
    for k, g in enumerate(BF.gl):
        bnk[0x1000 + k * 16:0x1000 + k * 16 + 16] = g
    print('big font: %d chars, %d glyphs' % (len(chars), len(BF.gl)))
    emit('; big font: 4 cells per character (top-left, top-right, bottom-left, bottom-right)')
    emit('bf_code:')
    db(tab_code)
    emit('bf_bank:')
    db(tab_bank)

    def big(label, s):
        emit(label + ':')
        db([chars.index(ch) for ch in s.upper()] + [255])

    # ---- crossing ship: bank 6. 4 phases (2 px apart) x 2 exhaust frames,
    # 7 x 2 cells each
    art = mbsprart.build()
    SH = Glyphs(6, 1)
    ship_tab = []
    for f in range(2):
        for p in range(4):
            W = 56
            pic = np.zeros((32, W), np.uint8)
            ex = canvas_pic(art['exhb%d' % f], 2 * p + 0, 10, W, 32)
            sh = canvas_pic(art['ship0'], 2 * p + 14, 2, W, 32)
            pic = np.where(sh > 0, sh, ex)
            full = np.zeros((32, 512), np.uint8)
            full[:, :W] = pic
            cl = T.to_cells(np.pad(full, ((0, 224), (0, 0))), rows=range(2))
            for r in range(2):
                for c in range(7):
                    if (r, c) in cl:
                        g, col = cl[(r, c)]
                        code, bank = SH.get(g)
                        ship_tab += [code, col]
                    else:
                        ship_tab += [0, 0]
    for k, g in enumerate(SH.gl):
        bnk[0x2000 + k * 16:0x2000 + k * 16 + 16] = g
    print('ship: %d glyphs' % len(SH.gl))
    emit('; crossing ship: [exhaust frame][phase][row][7 cells] of (code, colour); 0 = empty')
    emit('ship_tab:')
    db(ship_tab)

    # ---- capsule icons: bank 7, 4 x 2 cells each
    CP = Glyphs(7, 1)
    cap_tab = []
    for name in ('capw0', 'capw1', 'capw2', 'caps', 'caph'):
        c = art[name]
        full = np.zeros((256, 512), np.uint8)
        full[:32, :32] = canvas_pic(c, 2, 2, 32, 32)
        cl = T.to_cells(full, rows=range(2))
        for r in range(2):
            for cc in range(4):
                if (r, cc) in cl:
                    g, col = cl[(r, cc)]
                    code, bank = CP.get(g)
                    cap_tab += [code, col]
                else:
                    cap_tab += [0, 0]
    for k, g in enumerate(CP.gl):
        bnk[0x2800 + k * 16:0x2800 + k * 16 + 16] = g
    print('capsules: %d glyphs' % len(CP.gl))
    emit('; capsule icons S L C + H: [5][row][4 cells] of (code, colour)')
    emit('cap_tab:')
    db(cap_tab)

    (BUILD / 'TITLE.BNK').write_bytes(bytes(bnk))

    # ---- text
    def S(label, s):
        emit(label + ':')
        db(text_codes(s) + [0])

    S('s_sub', 'A MICROBEE PREMIUM PLUS SHOOT-EM-UP')
    S('s_cred1', 'DIRECTED AND PLAYTESTED BY BPM')
    S('s_cred2', 'CODE, GRAPHICS AND MUSIC BY CLAUDE')
    S('s_conv', 'CONVERTED FROM VZ-TYPE FOR THE VZ300')
    S('s_hi', 'HI SCORE ')
    S('s_press', 'PRESS SPACE OR FIRE TO PLAY')
    S('s_trn_on', 'TRAINER MODE ON - NO HIGH SCORES')
    S('s_trn_off', 'PRESS T FOR TRAINER MODE')
    S('s_mono', 'C COLOUR   M MONOCHROME')
    big('b_hof', 'HALL OF FAME')
    big('b_howto', 'HOW TO PLAY')
    big('b_power', 'POWER-UPS')
    big('b_stage', 'STAGE ')
    big('b_ready', 'GET READY')
    big('b_game', 'GAME OVER')
    big('b_great', 'NEW HIGH SCORE')
    big('b_well', 'WELL DONE')
    emit('help_txt:')
    for line in ['Q A O P OR CURSOR KEYS MOVE THE SHIP',
                 'SPACE FIRES - HOLD IT TO CHARGE THE BEAM',
                 'M OR Z LAUNCHES AND RECALLS THE POD',
                 'SHOOT CARRIERS TO RELEASE CAPSULES',
                 'H PAUSES   X WHILE PAUSED OR ESC QUITS',
                 'A JOYSTICK ON THE PARALLEL PORT WORKS TOO']:
        db(text_codes(line) + [0])
    emit('\tdb 255')
    emit('cap_txt:')
    for line in ['SPREAD', 'LANCE', 'CROSSFIRE', 'SPEED UP', 'HELPERS']:
        db(text_codes(line) + [0])
    S('s_capinfo', 'WEAPON CAPSULES ARM THE POD - M LAUNCHES IT')
    S('s_enter', 'ENTER YOUR INITIALS')
    S('s_ent2', 'UP DOWN CHANGE   FIRE OR RIGHT NEXT')
    S('s_cong1', 'THE CORE IS DESTROYED')
    S('s_cong2', 'BUT THE HORDE RETURNS')
    S('s_cong3', 'THE NEXT WAVE BEGINS')
    S('s_score', 'SCORE ')
    S('s_trnover', 'TRAINER MODE - NOT RECORDED')
    S('s_demo', 'DEMO')
    S('s_mtitle', 'WHICH MONITOR ARE YOU USING?')
    S('s_mc', 'C   COLOUR')
    S('s_mm', 'M   MONOCHROME (AMBER, GREEN OR WHITE)')
    S('s_mret', 'RETURN ALSO PICKS COLOUR')
    emit('stage_names:')
    for nm in ['OUTER HULL', 'THE HIVE', 'ROCK BELT', 'CRYSTAL VEIN',
               'DREADNOUGHT', 'GUT CAVERNS', 'DEEP FIELD', 'THE CORE']:
        db(text_codes(nm) + [0])
    msg = ('~B-TYPE ... EIGHT STAGES OF BIOMECHANICAL MAYHEM ON THE MICROBEE PREMIUM PLUS ... '
           'HOLD FIRE TO CHARGE YOUR BEAM, LAUNCH THE POD TO SHIELD YOUR SHIP OR SEND IT AHEAD TO CLEAR THE WAY ... '
           'RED CAPSULES SPREAD, BLUE CAPSULES LANCE, YELLOW CAPSULES CROSSFIRE ... '
           'CONVERTED FROM VZ-TYPE FOR THE DICK SMITH VZ300 ... DIRECTED AND PLAYTESTED BY BPM, '
           'CODE GRAPHICS AND MUSIC BY CLAUDE ... 2026 ... GOOD LUCK PILOT ...')
    emit('scroll_txt:')
    db(text_codes(' ' * 64 + msg + ' ' * 64) + [0])
    # default hall of fame (BCD score, initials, 2 spare)
    emit('def_hi:')
    for b0, b1, nm in [(0x02, 0x00, 'BPM'), (0x01, 0x50, 'POD'), (0x01, 0x00, 'ACE'), (0x00, 0x50, 'ZAP'), (0x00, 0x25, 'VZT')]:
        emit('\tdb $%02x,$%02x,$00,"%s",0,0' % (b0, b1, nm))

    # ---- music: VZ-TYPE's tunes, pitch tables for the Microbee player loop
    LOOP_T = 122                  # T-states per pass of mplay's loop
    R = 3375000 / LOOP_T
    pt1, pt2 = [1], [1]
    for m in range(1, 128):
        fr = 440 * 2 ** ((m - 69) / 12)
        pt1.append(max(2, min(255, round(R / fr))))
        pt2.append(max(1, min(255, round(R / (2 * fr)))))
    emit('ptab1:')
    db(pt1)
    emit('ptab2:')
    db(pt2)
    import re
    src = (HERE.parent / 'vz' / 'fgen.py').read_text()
    a = src.index('# ---- tunes')
    b = src.index('# ---- mode(1) logo')
    tune_src = src[a:b]
    env = {'emit': emit, 'db': db}
    exec(tune_src, env)

    (BUILD / 'front.inc').write_text('; generated by tools/mkfront.py\n' + '\n'.join(out) + '\n')


if __name__ == '__main__':
    build()
