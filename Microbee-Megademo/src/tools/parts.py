"""The parts' graphics. Each maker returns an assets.Part."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from gfx import *  # noqa
import assets
from assets import Part, tab, pat_cell, K_PCG

POPPINS = '/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf'


def text_bits(s, path, h, w):
    f = ImageFont.truetype(path, 200)
    bb = f.getbbox(s)
    im = Image.new('L', (bb[2] - bb[0] + 10, bb[3] - bb[1] + 10), 0)
    ImageDraw.Draw(im).text((5 - bb[0], 5 - bb[1]), s, font=f, fill=255)
    im = im.resize((w, h), Image.LANCZOS)
    return np.array(im) > 120


def solid_row(scr, addr, colour, mcolour, who, pattern=0x00, mpattern=None):
    """a row of 64 cells: the line-0 pattern glyph, one colour"""
    for i in range(64):
        b, c = pat_cell(pattern)
        scr.put(addr + i, b, c, colour, mcolour, who)


# =====================================================================
#  TITLE: FLD-bouncing logo, copper bars (one-line splits), scroller
# =====================================================================
T_BLANK = 0
T_LOGO = 64
T_COP = 384
T_NCOP = 18
T_SCR = 1536

# copper rows (colour): (pattern, ink, paper) - pattern 00 = all paper
COP_C = [(0, 0, BLUE), (0, 0, BBLUE), (0, 0, BCYAN), (0, 0, WHITE), (0, 0, RED), (0, 0, BRED),
         (0, 0, YELLOW), (0, 0, GREEN), (0, 0, BGREEN), (0, 0, MAGENTA), (0, 0, BMAGENTA), (0, 0, CYAN),
         (0x55, BBLUE, BLUE), (0xAA, BBLUE, BLUE), (0x55, BRED, RED), (0xAA, BRED, RED),
         (0x55, BCYAN, BBLUE), (0xAA, BCYAN, BBLUE)]
# mono rows: brightness steps
COP_M = [(0x00, WHITE, BLACK), (0x88, GREY, BLACK), (0x22, GREY, BLACK), (0xAA, GREY, BLACK), (0x55, GREY, BLACK),
         (0x00, 0, DGREY), (0xAA, GREY, DGREY), (0x55, GREY, DGREY), (0x00, 0, GREY), (0xAA, WHITE, GREY),
         (0x55, WHITE, GREY), (0x00, 0, WHITE), (0x88, WHITE, BLACK), (0x22, WHITE, BLACK), (0xAA, WHITE, BLACK),
         (0x55, WHITE, BLACK), (0xEE, WHITE, BLACK), (0xBB, WHITE, BLACK)]
# bar profiles: row indexes per line (index -1 = the blank row)
BARS_C = [
    [0, 13, 1, 1, 17, 2, 3, 3, 2, 16, 1, 1, 12, 0],            # blue
    [4, 15, 5, 5, 6, 6, 3, 3, 6, 6, 5, 5, 14, 4],               # red
    [7, 7, 8, 8, 6, 3, 3, 6, 8, 8, 7, 7],                       # green
    [9, 9, 10, 10, 3, 3, 10, 10, 9, 9],                         # magenta
    [11, 11, 2, 2, 3, 3, 2, 2, 11, 11],                         # cyan
]
BARS_M = [
    [1, 2, 3, 4, 6, 7, 9, 10, 11, 11, 10, 9, 7, 6, 4, 3, 2, 1][1:-1],
    [12, 13, 14, 15, 16, 17, 11, 11, 17, 16, 15, 14, 13, 12],
    [1, 2, 5, 6, 7, 8, 9, 10, 9, 8, 7, 6, 5, 2],
    [3, 4, 14, 15, 11, 11, 15, 14, 4, 3],
    [5, 6, 7, 8, 11, 11, 8, 7, 6, 5],
]


def title(pk):
    p = Part('title', pk)
    scr = Screen()
    g = Glyphs([0, 1, 2])
    # blank row
    solid_row(scr, T_BLANK, 0, 0, 'blank')
    # ---- the logo, 5 rows x 64
    big = text_bits('MEGADEMO', POPPINS, 58, 500)
    small = text_bits('MICROBEE', POPPINS, 13, 250)
    bits = np.zeros((80, 512), bool)
    bits[1:14, 131:381] = small
    bits[19:77, 6:506] = big
    stripe = np.zeros_like(bits)
    for yy in range(19, 77):
        t = (yy - 19) / 58
        if (t > 0.55 and yy % 3 == 0) or (t > 0.8 and yy % 2 == 0):
            stripe[yy] = True
    bits &= ~stripe
    inks = [YELLOW, WHITE, BCYAN, CYAN, BBLUE]
    minks = [WHITE, WHITE, WHITE, GREY, GREY]
    for cy in range(5):
        for cx in range(64):
            b = bits[cy * 16:(cy + 1) * 16, cx * 8:(cx + 1) * 8]
            gl = np.packbits(b, axis=1)[:, 0]
            bank, code = g.add(gl)
            scr.put(T_LOGO + cy * 64 + cx, bank, code, inks[cy], minks[cy], 'logo')
    # ---- copper rows
    for k in range(T_NCOP):
        pc, ic, papc = COP_C[k]
        pm, im, papm = COP_M[k]
        for i in range(64):
            bank, code = pat_cell(pc)
            scr.put(T_COP + k * 64 + i, bank, code, (papc << 4) | ic, (papm << 4) | im, 'copper')
        # mono needs its own pattern: the code differs too, so mono rows are
        # set up by their own jobs below
    mono_codes = []
    for k in range(T_NCOP):
        pm = COP_M[k][0]
        bank, code = pat_cell(pm)
        mono_codes.append((bank, code))
    # ---- scroller: 4 phases x 128 cells; slot j of phase p = bank 3 + p//2, glyph (p%2)*64 + j
    rainbow = [BRED, YELLOW, BGREEN, BCYAN, BBLUE, BMAGENTA]
    for ph in range(4):
        for i in range(128):
            j = i % 64
            hue = rainbow[(j // 2) % len(rainbow)]
            scr.put(T_SCR + ph * 128 + i, 3 + ph // 2, 0x80 | ((ph % 2) * 64 + j), hue, WHITE, 'scroll')
    p.screen(scr, g.data)
    # mono copper: codes and attributes
    codes = np.array([mono_codes[k // 64][1] for k in range(T_NCOP * 64)], np.uint8)
    attrs = np.array([mono_codes[k // 64][0] for k in range(T_NCOP * 64)], np.uint8)
    p.job(assets.K_SCR, T_COP, codes, assets.F_MONO)
    p.job(assets.K_ATTR, T_COP, attrs, assets.F_MONO)
    # blank scroller glyphs (rendered at run time)
    p.job(K_PCG + 3, 0, bytes(2048))
    p.job(K_PCG + 4, 0, bytes(2048))
    p.consts.update(T_BLANK=T_BLANK, T_LOGO=T_LOGO, T_COP=T_COP, T_SCR=T_SCR)
    # copper index table (page aligned): index k -> R12, R13 of row k; 2 x index
    # in the line program. Entry 0..17 copper rows, 18 the blank row, 19..
    # unused. (The scroller's address is written directly by the last entry:
    # entries 20..83 = scroller phase/offset are filled at run time.)
    rows = [T_COP + 64 * k for k in range(T_NCOP)] + [T_BLANK]
    entries = []
    for a in rows:
        entries += [a >> 8, a & 255]
    entries += [0] * (256 - len(entries))
    p.tables.append('\tALIGN 256\n' + tab('t_coptab', entries))
    nb = len(BARS_C)
    p.consts['T_NBARS'] = nb
    p.consts['T_BLANKIX'] = T_NCOP
    for mode, bars in (('c', BARS_C), ('m', BARS_M)):
        lines = ['t_bars_%s:' % mode]
        for b in bars:
            lines.append('\tdb %d, %s' % (len(b), ','.join(str(2 * x) for x in b)))
        p.tables.append('\n'.join(lines))
    # previews
    pcg = {b: bytes(16 * 128) for b in range(16)}
    pcg.update({b: bytes(d) for b, d in g.data.items()})
    pat0 = bytearray(2048)
    pat1 = bytearray(2048)
    for k in range(128):
        pat0[k * 16] = k
        pat1[k * 16] = 128 + k
    pcg[BK_PAT0], pcg[BK_PAT1] = bytes(pat0), bytes(pat1)
    save_png(PREV / 'title_logo.png', render_cells(scr, pcg, T_LOGO, 5), 2)
    save_png(PREV / 'title_logo_mono.png', render_cells(scr, pcg, T_LOGO, 5, mono=True), 2)
    return p





# =====================================================================
#  helpers: encode a 512-pixel line (palette indexes) as 64 cells of
#  line-0 pattern glyphs, choosing ink / paper per cell
# =====================================================================
def encode_line(px):
    """px: 512 palette indexes -> [(bank, code, colour)] x 64"""
    out = []
    for c in range(64):
        seg = list(px[c * 8:(c + 1) * 8])
        cnt = {}
        for v in seg:
            cnt[v] = cnt.get(v, 0) + 1
        cols = sorted(cnt, key=lambda v: -cnt[v])
        if len(cols) == 1:
            ink = paper = cols[0]
        else:
            a, b = cols[0], cols[1]
            # remaining colours go to the nearer of the two (by brightness)
            ink, paper = (a, b) if LUM[a] >= LUM[b] else (b, a)
        bits = 0
        for i, v in enumerate(seg):
            if v == ink and ink != paper:
                bits |= 0x80 >> i
            elif v != paper and v != ink:
                if abs(int(LUM[v]) - int(LUM[ink])) < abs(int(LUM[v]) - int(LUM[paper])):
                    bits |= 0x80 >> i
        bank, code = pat_cell(bits)
        out.append((bank, code, (paper << 4) | ink))
    return out


def dither_pick(ramp, level, x, y=0):
    """level 0..1 along a colour ramp, ordered dither between two neighbours"""
    n = len(ramp) - 1
    f = max(0.0, min(1.0, level)) * n
    i = int(f)
    if i >= n:
        return ramp[n]
    frac = f - i
    bayer = [0.125, 0.625, 0.375, 0.875]
    th = bayer[(x + 2 * y) % 4]
    return ramp[i + 1] if frac > th else ramp[i]


def text_row(scr, addr, s, col, mcol, who):
    s = s.center(64)[:64]
    for i, ch in enumerate(s):
        scr.put(addr + i, BK_FONT, 0x80 + (ord(ch) - 32), col, mcol, who)


# =====================================================================
#  TWISTER: 30 slices (90 degrees of a square bar), one per row of 64
#  cells; each scanline picks its slice. Rows 30, 31: the text rows.
# =====================================================================
TW_N = 30
TW_S1 = 1920
TW_F = 1984


def twister_slice(a, mono, rd=78.0, cx=256):
    th = np.pi / 2 * a / TW_N
    ramp = [BLACK, BLUE, BBLUE, CYAN, BCYAN, WHITE] if not mono else [BLACK, DGREY, GREY, WHITE]
    bg_ramp = [BLACK, BLUE] if not mono else [BLACK, DGREY]
    px = []
    corners = [th + np.pi / 4 + k * np.pi / 2 for k in range(4)]
    xs = [cx + rd * np.cos(al) for al in corners]
    for x in range(512):
        v = None
        for k in range(4):
            x0, x1 = xs[k], xs[(k + 1) % 4]
            nz = np.sin(corners[k] + np.pi / 4)        # the face's normal toward the viewer
            if nz <= 0:
                continue
            lo, hi = min(x0, x1), max(x0, x1)
            if lo <= x + 0.5 < hi:
                u = (x + 0.5 - lo) / max(hi - lo, 1e-6)
                light = 0.12 + 0.62 * nz ** 1.5
                if u < 0.07 or u > 0.93:
                    light *= 0.4                          # dark seams at the edges
                elif 0.40 < u < 0.60:
                    light = min(1.0, light + 0.28 * nz)   # a highlight down the middle
                v = dither_pick(ramp, light, x)
        if v is None:
            # the background: faint vertical rasters, away from the bar
            d = abs(x - cx) / 256.0
            stripe = 0.5 + 0.5 * np.cos(x / 512 * 2 * np.pi * 8)
            v = dither_pick(bg_ramp, 0.7 * stripe ** 3 * d, x) if d > 0.4 else BLACK
        px.append(v)
    return px


def twister(pk):
    p = Part('twister', pk)
    scr = Screen()
    for a in range(TW_N):
        cc = encode_line(twister_slice(a, False))
        mm = encode_line(twister_slice(a, True))
        for i in range(64):
            scr.put(a * 64 + i, cc[i][0], cc[i][1], cc[i][2], mm[i][2], 'tw')
        if any(cc[i][:2] != mm[i][:2] for i in range(64)):
            p.mono_codes = getattr(p, 'mono_codes', {})
            p.mono_codes[a] = mm
    text_row(scr, TW_S1, 'T H E    T W I S T E R', YELLOW, WHITE, 'tw')
    text_row(scr, TW_F, '1 PIXEL ACCURATE ... 222 SCREENS PER FRAME', BCYAN, WHITE, 'tw')
    p.screen(scr, {})
    # mono: the slices' codes differ
    if getattr(p, 'mono_codes', None):
        codes = scr.code.copy()
        attrs = scr.attr.copy()
        for a, mm in p.mono_codes.items():
            for i in range(64):
                attrs[a * 64 + i], codes[a * 64 + i] = mm[i][0], mm[i][1]
        p.job(assets.K_SCR, 0, codes[:TW_N * 64], assets.F_MONO)
        p.job(assets.K_ATTR, 0, attrs[:TW_N * 64], assets.F_MONO)
    # index table: entries 0-59: angle mod 30; 64: the bottom row
    ent = []
    for i in range(128):
        if i < 60:
            a = (i % TW_N) * 64
        elif i == 64:
            a = TW_F
        elif i == 65:
            a = TW_S1
        else:
            a = 0
        ent += [a >> 8, a & 255]
    p.tables.append('\tALIGN 256\n' + tab('tw_tab', ent))
    p.consts.update(TW_S1=TW_S1, TW_F=TW_F, TW_N=TW_N)
    # twist shapes: 16 amplitudes x 512 entries (2 x index), sin period 256 lines
    shp = bytearray()
    for k in range(16):
        amp = k / 15.0 * 14.5
        for i in range(512):
            v = int(round(14.5 + amp * np.sin(2 * np.pi * i / 256))) % TW_N
            shp.append(2 * v)
    blk, off = pk.add_aligned(bytes(shp), 512)
    p.consts['TW_SHB'] = blk
    p.consts['TW_SHO'] = off
    # preview: a twisted frame
    pcg = {b: bytes(2048) for b in range(16)}
    pat0, pat1 = bytearray(2048), bytearray(2048)
    for k in range(128):
        pat0[k * 16] = k
        pat1[k * 16] = 128 + k
    pcg[BK_PAT0], pcg[BK_PAT1] = bytes(pat0), bytes(pat1)
    for mono in (False, True):
        img = np.zeros((224, 512, 3), np.uint8)
        for y in range(224):
            a = int(round(15 + 8 * np.sin(y / 30.0) + y / 12.0)) % TW_N
            row = render_cells(scr, pcg, a * 64, 1, lines=1, mono=mono)
            img[y] = row[0]
        save_png(PREV / ('twister%s.png' % ('_mono' if mono else '')), img, 1, 1.5)
    return p



# =====================================================================
#  PLASMA: 26 rows x 64 cells of 8 x 8 (lines 16-223), a checker glyph
#  in every cell; the plasma is the colour RAM. Rows: S1 text at P_S1,
#  S2 text row (224-239) at P_S2, F at P_F.
# =====================================================================
P_AREA = 0
P_ROWS = 24
P_S1 = 1664
P_S2 = 1728
P_F = 1792


def plasma(pk):
    p = Part('plasma', pk)
    scr = Screen()
    g = Glyphs([0])
    checker = [0xAA, 0x55] * 4 + [0] * 8
    bank, code = g.add(checker)
    # mono: the plasma is glyph density (codes 81h-89h: 0/8 .. 8/8 lit)
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    for lv in range(9):
        rows = []
        for y in range(8):
            v = 0
            for x in range(8):
                if bayer[y % 4][x % 4] < lv * 2:
                    v |= 0x80 >> x
            rows.append(v)
        g.fixed(0, 1 + lv, rows + [0] * 8)
    for i in range(P_ROWS * 64):
        scr.put(P_AREA + i, bank, code, 0, WHITE, 'pl')
    text_row(scr, P_S1, 'P L A S M A', BMAGENTA, WHITE, 'pl')
    text_row(scr, P_S2, '1536 BLOCKS OF COLOUR, RECOMPUTED 25 TIMES A SECOND', YELLOW, GREY, 'pl')
    text_row(scr, P_F, 'COMPUTED BETWEEN THE MUSIC SAMPLES, INSIDE THE SCANLINES', BCYAN, WHITE, 'pl')
    p.screen(scr, g.data)
    # colour ramp (cyclic): solid and half-mixed steps through a hue circle
    hues = [BLUE, BBLUE, BCYAN, WHITE, YELLOW, BRED, RED, MAGENTA, BMAGENTA, BLUE, BLACK, BLACK]
    hues = [BLACK, BLUE, BBLUE, CYAN, BCYAN, WHITE, YELLOW, BRED, RED, MAGENTA, BLUE]
    steps = []
    for i in range(len(hues)):
        a, b = hues[i], hues[(i + 1) % len(hues)]
        steps.append((a << 4) | a)
        steps.append((b << 4) | a)       # checker: half each
    ramp = [steps[int(i * len(steps) / 256)] for i in range(256)]
    # mono ramp: glyph codes, density 0 -> 8 -> 0
    mlev = list(range(9)) + list(range(7, 0, -1))
    mramp = [0x81 + mlev[int(i * len(mlev) / 256)] for i in range(256)]
    # A patterns: sum of two sines along x (index = column pair), 256 entries
    pats = []
    for k, (f1, f2, a1, a2) in enumerate([(8, 19, 46, 26), (12, 5, 40, 34)]):
        pats.append([int(128 + a1 * np.sin(2 * np.pi * f1 * i / 256) + a2 * np.sin(2 * np.pi * f2 * i / 256 + 1.3)) & 255
                     for i in range(256)])
    p.tables.append('\tALIGN 256\n' + tab('pl_ramp', ramp))
    p.tables.append(tab('pl_mramp', mramp))
    p.tables.append(tab('pl_pat0', pats[0]))
    p.tables.append(tab('pl_pat1', pats[1]))
    p.consts.update(P_AREA=P_AREA, P_S1=P_S1, P_S2=P_S2, P_F=P_F, P_ROWS=P_ROWS)
    return p



# =====================================================================
#  KEFRENS: one row of 64 cells (glyph line 0 = F0: each cell is 4 px of
#  ink, 4 of paper) is shown on every line from 16 to 239, while the CPU
#  paints a bar into its colour RAM on each line.
# =====================================================================
K_ROW = 0           # the line buffer (colour RAM page aligned)
K_S1 = 64
K_F = 128


def kefrens(pk):
    p = Part('kefrens', pk)
    scr = Screen()
    b, c = pat_cell(0xF0)
    for i in range(64):
        scr.put(K_ROW + i, b, c, 0, 0, 'kf')
    text_row(scr, K_S1, 'K E F R E N S   B A R S', BGREEN, WHITE, 'kf')
    text_row(scr, K_F, 'RACING THE BEAM: EVERY LINE IS PAINTED AS IT IS DRAWN', YELLOW, WHITE, 'kf')
    # mono: the bars are glyphs (bank 0, line 0: 0 / 1 in 4 / 1 in 2 / 3 in 4 / all lit)
    mg = bytearray(2048)
    for k, v in enumerate([0x00, 0x88, 0xAA, 0xEE, 0xFF]):
        mg[k * 16] = v
    p.screen(scr, {})
    p.job(K_PCG + 0, 0, bytes(mg[:5 * 16]), assets.F_MONO)
    p.job(assets.K_SCR, K_ROW, bytes([0x80] * 64), assets.F_MONO)
    p.job(assets.K_ATTR, K_ROW, bytes([0] * 64), assets.F_MONO)
    p.job(assets.K_COL, K_ROW, bytes([WHITE] * 64), assets.F_MONO)
    # bar palettes: 4 cells = 8 half-columns, (paper << 4 | ink) = (right, left)
    def bar(cols):
        return [(cols[2 * i + 1] << 4) | cols[2 * i] for i in range(4)]
    bars_c = [bar([BLUE, BBLUE, BCYAN, WHITE, WHITE, BCYAN, BBLUE, BLUE]),
              bar([RED, BRED, YELLOW, WHITE, WHITE, YELLOW, BRED, RED]),
              bar([GREEN, BGREEN, YELLOW, WHITE, WHITE, YELLOW, BGREEN, GREEN]),
              bar([MAGENTA, BMAGENTA, BRED, WHITE, WHITE, BRED, BMAGENTA, MAGENTA])]
    bars_m = [[0x81, 0x83, 0x84, 0x82], [0x82, 0x84, 0x83, 0x81], [0x82, 0x84, 0x84, 0x82], [0x81, 0x84, 0x84, 0x81]]
    flat = []
    for bb in bars_c + bars_m:
        flat += bb
    p.tables.append(tab('kf_bars', flat))
    p.consts.update(K_ROW=K_ROW, K_S1=K_S1, K_F=K_F)
    return p



# =====================================================================
#  CRT: power on / off (one-line screens choosing black, white, grey and
#  the dot). All rows are patterns in white on black: the same in mono.
# =====================================================================
CRT_ROWS = [0x00, 0xFF, 0xAA, 0x55, 0x88, 0x22]     # black, white, grey a/b, dim a/b
C_DOT = 6 * 64          # row 6: the dot (centre cells)
C_DOT2 = 7 * 64         # row 7: a small dot


def crt(pk):
    p = Part('crt', pk)
    scr = Screen()
    for k, pat in enumerate(CRT_ROWS):
        for i in range(64):
            b, c = pat_cell(pat)
            scr.put(k * 64 + i, b, c, WHITE, WHITE, 'crt')
    for row, cells in ((6, {30: 0x07, 31: 0xFF, 32: 0xFF, 33: 0xE0}), (7, {31: 0x03, 32: 0xC0})):
        for i in range(64):
            b, c = pat_cell(cells.get(i, 0))
            scr.put(row * 64 + i, b, c, WHITE, WHITE, 'crt')
    p.screen(scr, {})
    ent = []
    for k in range(128):
        a = k * 64 if k < 8 else 0
        ent += [a >> 8, a & 255]
    p.tables.append('\tALIGN 256\n' + tab('crt_tab', ent))
    return p


# =====================================================================
#  BOOT: a terminal (14 text rows, each its own screen so they can tear)
# =====================================================================
B_BLANK = 14 * 64


def boot(pk):
    p = Part('boottext', pk)
    scr = Screen()
    for r in range(15):
        text_row(scr, r * 64, '', BGREEN, WHITE, 'bt')
    p.screen(scr, {})
    p.consts['B_BLANK'] = B_BLANK
    return p


# =====================================================================
#  CREDITS: a smooth vertical scroller. 16 ring rows (0-15) + copies of
#  rows 0-11 (16-27), then the top row, a blank row and the bottom row.
# =====================================================================
CR_TOP = 28 * 64
CR_BLANK = 29 * 64
CR_F = 30 * 64


CREDITS_TEXT = [
    (YELLOW, 'MICROBEE MEGADEMO 2026'),
    (0, ''),
    (WHITE, 'VIBED BY BPM 2026'),
    (0, ''),
    (0, ''),
    (BMAGENTA, '- THE PARTS -'),
    (0, ''),
    (BCYAN, 'THE TUBE WARMING UP'),
    (BCYAN, 'THE SELF TEST'),
    (BCYAN, 'COPPER BARS AND A SCROLLER'),
    (BCYAN, 'THE TWISTER: 222 SCREENS A FRAME'),
    (BCYAN, 'A PLASMA COMPUTED INSIDE THE SCANLINES'),
    (BCYAN, 'KEFRENS BARS, PAINTED AS THE BEAM PASSES'),
    (BCYAN, 'A LIVE ROTOZOOMER, WORKED OUT AS IT IS DRAWN'),
    (BCYAN, 'A TUNNEL, A FLOOR, A SWIRL AND A TWIST,'),
    (BCYAN, 'PRECOMPUTED INTO HALF A MEGABYTE'),
    (BCYAN, 'A LIT TORUS STREAMED INTO THE PCG RAM'),
    (BCYAN, 'AND THIS SMOOTH SCROLLER'),
    (0, ''),
    (0, ''),
    (BMAGENTA, '- THE MACHINE -'),
    (0, ''),
    (BGREEN, 'MICROBEE PREMIUM PLUS'),
    (BGREEN, 'Z80A AT 3.375 MHZ'),
    (BGREEN, '1 MEGABYTE RAM ... 32K PCG RAM'),
    (BGREEN, 'ONE DOUBLE SIDED 80 TRACK DISK'),
    (BGREEN, 'A 6545 CRTC THAT NEVER SAW IT COMING'),
    (0, ''),
    (WHITE, 'EVERY SCANLINE IS 216 T STATES LONG,'),
    (WHITE, 'AND EVERY ONE OF THEM IS COUNTED.'),
    (WHITE, 'THE TWO VOICE MUSIC PLAYS IN THE GAPS.'),
    (0, ''),
    (0, ''),
    (BMAGENTA, '- GREETINGS -'),
    (0, ''),
    (YELLOW, 'TO THE MICROBEE COMMUNITY'),
    (YELLOW, 'TO APPLIED TECHNOLOGY, WHO BUILT THE BEE'),
    (YELLOW, 'TO EVERYONE KEEPING A BEE ALIVE'),
    (YELLOW, 'TO THE EMULATOR WRITERS AND ARCHIVISTS'),
    (YELLOW, 'AND TO THE DEMOSCENE, THEN AND NOW'),
    (0, ''),
    (0, ''),
    (BMAGENTA, '- HOW IT WAS MADE -'),
    (0, ''),
    (WHITE, 'THE MICROBEE HAS NO SPRITES, NO SCROLL'),
    (WHITE, 'REGISTERS, NO COPPER AND NO BLITTER.'),
    (WHITE, 'IT HAS A 6545 CRTC, AND THE 6545 CAN BE'),
    (WHITE, 'TOLD WHERE TO READ FROM WHILE IT DRAWS.'),
    (0, ''),
    (WHITE, 'SO EVERY EFFECT HERE IS THE CRTC BEING'),
    (WHITE, 'REPROGRAMMED IN THE MIDDLE OF THE PICTURE,'),
    (WHITE, 'LINE BY LINE, IN TIME WITH THE BEAM,'),
    (WHITE, 'WHILE A TWO VOICE BEEPER KEEPS PLAYING.'),
    (0, ''),
    (WHITE, 'TESTED ON A REAL PREMIUM PLUS'),
    (WHITE, 'WITH AN AMBER MONITOR.'),
    (0, ''),
    (0, ''),
    (WHITE, 'THE FIRST MEGADEMO FOR THE MICROBEE'),
    (0, ''),
    (BRED, 'VIBED BY BPM 2026'),
    (0, ''),
    (WHITE, 'THANKS FOR WATCHING'),
] + [(0, '')] * 12


def credits(pk):
    p = Part('credits', pk)
    scr = Screen()
    for r in range(28):
        text_row(scr, r * 64, '', WHITE, WHITE, 'cr')
    text_row(scr, CR_TOP, 'C R E D I T S', YELLOW, WHITE, 'cr')
    text_row(scr, CR_BLANK, '', WHITE, WHITE, 'cr')
    text_row(scr, CR_F, 'MICROBEE MEGADEMO 2026 ... VIBED BY BPM 2026', BCYAN, WHITE, 'cr')
    p.screen(scr, {})
    data = bytearray()
    for col, t in CREDITS_TEXT:
        data += bytes(0x80 + ord(ch) - 32 for ch in t.center(64)[:64])
    blk, off = pk.add(data)
    p.consts.update(CR_TBLK=blk, CR_TOFF=off, CR_N=len(CREDITS_TEXT))
    p.tables.append(tab('cr_cols', [c or WHITE for c, t in CREDITS_TEXT]))
    p.consts.update(CR_TOP=CR_TOP, CR_BLANK=CR_BLANK, CR_F=CR_F)
    return p



# =====================================================================
#  LIVE ROTOZOOMER (src/p_live.asm) and the PRERENDERED EFFECTS
#  (src/p_fx.asm): both on the plasma's layout (24 rows of 32 blocks).
# =====================================================================
import fx  # noqa


def blocks_screen(p, title, s2, f, mono_glyphs):
    scr = Screen()
    for i in range(P_ROWS * 64):
        scr.put(P_AREA + i, 0, 0x80, 0, WHITE, p.name)
    text_row(scr, P_S1, title, BCYAN, WHITE, p.name)
    text_row(scr, P_S2, s2, YELLOW, GREY, p.name)
    text_row(scr, P_F, f, BGREEN, WHITE, p.name)
    p.screen(scr, {})
    checker = bytes([0xAA, 0x55] * 4 + [0] * 8)
    p.job(K_PCG + 0, 0, checker, assets.F_COLOUR)
    p.job(K_PCG + 0, 0, mono_glyphs, assets.F_MONO)


def plasma_mono_glyphs():
    """codes 80h-89h: 0/8 .. 8/8 lit (the plasma's)"""
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    data = bytearray(16)
    for lv in range(9):
        rows = []
        for y in range(8):
            v = 0
            for x in range(8):
                if bayer[y % 4][x % 4] < lv * 2:
                    v |= 0x80 >> x
            rows.append(v)
        data += bytes(rows + [0] * 8)
    return bytes(data)


def live(pk):
    p = Part('live', pk)
    blocks_screen(p, 'L I V E   R O T O Z O O M E R',
                  'COMPUTED AS THE BEAM DRAWS IT: TWO BLOCKS A SCANLINE',
                  'EACH NEXT TEXTURE IS BUILT IN THE BACKGROUND AS IT RUNS', fx.live_mono_glyphs())
    tiles = [fx.live_tile_bytes(fn) for name, fn in fx.LIVE_TILES]
    n0, off = pk.add(fx.live_texture_block(tiles[0]))
    assert off == 0
    tb, toff = pk.add_aligned(b''.join(t.tobytes() for t in tiles[1:]), 256)
    p.consts.update(LVT_BLK0=n0, LVT_TBLK=tb, LVT_TOFF=toff)
    return p


FX_PER = 36
FX_LIST = [
    # name, blocks, frames fn, title, line 2, bottom line
    ('tunnel', 3, lambda n: fx.fx_tunnel(n), 'T H E   T U N N E L',
     '108 PICTURES, EVERY BLOCK OF EVERY ONE PRECOMPUTED', 'THE COLOURS CYCLE AS IT PLAYS: A NEW RAMP EVERY 16 FRAMES'),
    ('floor', 2, lambda n: fx.fx_floor(n), 'P E R S P E C T I V E   F L O O R',
     'A FLOOR AND A CEILING RUSHING AT YOU, 25 TIMES A SECOND', 'NO Z80 COULD DIVIDE THIS FAST: SO IT DID IT EARLIER'),
    ('swirl', 2, lambda n: fx.fx_swirl(n, fx.tile_bpm()), 'S W I R L',
     'THE BPM SIGN, TWIRLED: A SINE AND A COSINE PER BLOCK', 'TOO MUCH MATHS FOR 3.375 MHZ, SO IT LIVES IN THE MEGABYTE'),
    ('twist', 2, lambda n: fx.fx_twist(n), 'T W I S T',
     'EVERY ROW TURNED A LITTLE FURTHER THAN THE ONE ABOVE', '1 MEGABYTE ... 32K PCG ... ONE DISK ... NO EXCUSES'),
]


def fx_part(name, nblk, fn, title, s2, f):
    def mk(pk):
        p = Part(name, pk)
        blocks_screen(p, title, s2, f, plasma_mono_glyphs())
        frames = fn(nblk * FX_PER)
        first = None
        for i, blk in enumerate(fx.fx_blocks(frames, FX_PER)):
            n, off = pk.add(blk)
            assert off == 0
            if first is None:
                first = n
            assert n == first + i
        p.consts.update(**{'FX_%s_BLK' % name.upper(): first, 'FX_%s_N' % name.upper(): nblk})
        return p
    mk.__name__ = name
    return mk


FX_PARTS = [fx_part(*e) for e in FX_LIST]
FX_PER_C = FX_PER


# =====================================================================
#  VECTOR: a lit, dithered torus in a 20 x 6 cell window (160 x 96 px of
#  PCG glyphs). Every frame of it is precomputed (VC_N frames, VC_PER a
#  RAM block, 1920 bytes each) and streamed into the hidden PCG bank by
#  the kernel, 640 bytes a frame, 4 a scanline: a new picture every 3
#  frames. Two screens (A on bank 1, B on bank 2) are flipped.
# =====================================================================
VC_W, VC_H = 20, 6
VC_PER = 17
VC_NBLK = 4
VC_N = VC_PER * VC_NBLK      # 68 pictures, 4.1 s, a seamless loop
VC_A = 0                     # screen A: 14 rows from 0
VC_B = 14 * 64               # screen B
VC_S1 = 28 * 64
VC_F = 29 * 64
VC_R0, VC_C0 = 4, 22         # the window in a screen


def torus_frames():
    W, H = VC_W * 8, VC_H * 16
    bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]])
    thr = np.tile(bayer, (H // 4 + 1, W // 4 + 1))[:H, :W]
    R, r = 1.0, 0.45
    nu, nv = 120, 60
    u = np.linspace(0, 2 * np.pi, nu, endpoint=False)
    v = np.linspace(0, 2 * np.pi, nv, endpoint=False)
    U, V = np.meshgrid(u, v)
    P = np.stack([(R + r * np.cos(V)) * np.cos(U), (R + r * np.cos(V)) * np.sin(U), r * np.sin(V)], -1)
    N = np.stack([np.cos(V) * np.cos(U), np.cos(V) * np.sin(U), np.sin(V)], -1)
    light = np.array([-0.5, -0.6, -0.8])
    light /= np.linalg.norm(light)
    # pixel grid in object units: the pixels are 1.5 times as tall as wide
    scale = 50.0
    out = []
    for f in range(VC_N):
        ph = f / VC_N
        a, b = 2 * np.pi * ph, 4 * np.pi * ph
        rx = np.array([[1, 0, 0], [0, np.cos(a), -np.sin(a)], [0, np.sin(a), np.cos(a)]])
        ry = np.array([[np.cos(b), 0, np.sin(b)], [0, 1, 0], [-np.sin(b), 0, np.cos(b)]])
        m = ry @ rx
        Q = P @ m.T
        M = N @ m.T
        shade = np.clip(-(M @ light), 0, 1) * 0.85 + 0.15
        z = np.full((H, W), -1e9)
        img = np.zeros((H, W))
        # splat the quads as small points, densely (a z-buffer)
        uu = np.linspace(0, 2 * np.pi, nu * 5, endpoint=False)
        vv = np.linspace(0, 2 * np.pi, nv * 5, endpoint=False)
        UU, VV = np.meshgrid(uu, vv)
        PP = np.stack([(R + r * np.cos(VV)) * np.cos(UU), (R + r * np.cos(VV)) * np.sin(UU), r * np.sin(VV)], -1) @ m.T
        NN = np.stack([np.cos(VV) * np.cos(UU), np.cos(VV) * np.sin(UU), np.sin(VV)], -1) @ m.T
        d = np.clip(NN @ light, 0, 1)
        sh = 0.08 + 0.75 * d + 0.25 * d ** 12
        x = (PP[..., 0] * scale + W / 2).astype(int).ravel()
        y = (PP[..., 1] * scale / 1.5 + H / 2).astype(int).ravel()
        zz = PP[..., 2].ravel()
        ss = sh.ravel()
        ok = (x >= 0) & (x < W) & (y >= 0) & (y < H)
        x, y, zz, ss = x[ok], y[ok], zz[ok], ss[ok]
        order = np.argsort(-zz)         # far (large z) first, near overwrite
        img[y[order], x[order]] = ss[order]
        z[y[order], x[order]] = zz[order]
        lit = (img * 16) > thr + 0.5
        lit &= z > -1e8
        g = bytearray()
        for cr in range(VC_H):
            for cc in range(VC_W):
                for yy in range(16):
                    row = lit[cr * 16 + yy, cc * 8:cc * 8 + 8]
                    bv = 0
                    for k in range(8):
                        if row[k]:
                            bv |= 0x80 >> k
                    g.append(bv)
        out.append(bytes(g))
    return out


def vector(pk):
    p = Part('vector', pk)
    scr = Screen()
    grad = [YELLOW, YELLOW, BRED, BRED, RED, MAGENTA]
    for base, bank in ((VC_A, 1), (VC_B, 2)):
        for r in range(14):
            text_row(scr, base + r * 64, '', WHITE, WHITE, 'vc')
        for r in range(VC_H):
            for c in range(VC_W):
                scr.put(base + (VC_R0 + r) * 64 + VC_C0 + c, bank, 0x80 + r * VC_W + c, grad[r], WHITE, 'vc')
        text_row(scr, base + 11 * 64, 'LIT AND DITHERED: 68 PICTURES, 128K OF THE MEGABYTE', BCYAN, WHITE, 'vc')
    text_row(scr, VC_S1, 'V E C T O R   T O R U S', BGREEN, WHITE, 'vc')
    text_row(scr, VC_F, 'STREAMED INTO THE HIDDEN PCG BANK, FOUR BYTES A SCANLINE', YELLOW, WHITE, 'vc')
    p.screen(scr, {1: bytes(2048), 2: bytes(2048)})
    frames = torus_frames()
    first = None
    for b in range(VC_NBLK):
        blk = bytearray(32768)
        for j in range(VC_PER):
            blk[j * 1920:(j + 1) * 1920] = frames[b * VC_PER + j]
        n, off = pk.add(blk)
        assert off == 0
        if first is None:
            first = n
        assert n == first + b
    p.consts.update(VC_BLK0=first, VC_NBLK=VC_NBLK, VC_PER=VC_PER, VC_A=VC_A, VC_B=VC_B, VC_S1=VC_S1, VC_F=VC_F)
    return p

ALL = [title, twister, plasma, kefrens, live, *FX_PARTS, vector, crt, boot, credits]
