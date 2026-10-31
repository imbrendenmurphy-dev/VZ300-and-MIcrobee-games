#!/usr/bin/env python3
# Dawn Patrol 2 build: generates src/gen.asm, assembles, writes DP2.VZ
import sys, os, subprocess, random
sys.path.insert(0, os.path.dirname(__file__))
from art import *
from music import music_asm
from speech import speech_asm

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
OUT = os.path.join(ROOT, 'out')
os.makedirs(OUT, exist_ok=True)


# ------------------------------------------------------------ helpers
def pack_row(row):
    """row of colours/None -> list of bytes (4 px per byte, MSB first)"""
    out = []
    for i in range(0, len(row), 4):
        b = 0
        for k in range(4):
            c = row[i + k] if i + k < len(row) else 0
            b = (b << 2) | (c or 0)
        out.append(b)
    return out


def pack_masked(g):
    """grid -> (wb, h, interleaved mask/data bytes)"""
    w = len(g[0]); h = len(g)
    wb = (w + 3) // 4
    out = []
    for row in g:
        for i in range(wb):
            m = 0; d = 0
            for k in range(4):
                x = i * 4 + k
                c = row[x] if x < w else None
                m <<= 2; d <<= 2
                if c is None:
                    m |= 3
                else:
                    d |= c
            out += [m, d]
    return wb, h, out


def lz(data):
    out = []
    i = 0; n = len(data)
    lit = []
    def flush():
        while lit:
            k = min(127, len(lit))
            out.append(k); out.extend(lit[:k]); del lit[:k]
    # hash chains for speed
    from collections import defaultdict
    table = defaultdict(list)
    while i < n:
        best = 0; bd = 0
        if i + 2 < n:
            key = bytes(data[i:i + 3])
            for j in reversed(table[key][-64:]):
                l = 0
                while i + l < n and data[j + l] == data[i + l] and l < 130:
                    l += 1
                if l > best:
                    best = l; bd = i - j
                    if l == 130:
                        break
        if best >= 3:
            flush()
            out += [0x80 | (best - 3), bd & 255, bd >> 8]
            for k in range(best):
                if i + k + 2 < n:
                    table[bytes(data[i + k:i + k + 3])].append(i + k)
            i += best
        else:
            lit.append(data[i])
            if i + 2 < n:
                table[bytes(data[i:i + 3])].append(i)
            i += 1
    flush()
    out.append(0)
    return out


def unlz(c):
    out = []; i = 0
    while True:
        t = c[i]; i += 1
        if t == 0:
            return out
        if t < 128:
            out += c[i:i + t]; i += t
        else:
            l = (t & 127) + 3; d = c[i] | c[i + 1] << 8; i += 2
            for k in range(l):
                out.append(out[-d])


def dbs(label, data, per=24):
    lines = ['%s:' % label] if label else []
    for i in range(0, len(data), per):
        lines.append('        db ' + ','.join('$%02X' % b for b in data[i:i + per]))
    return '\n'.join(lines)


def asm_str(label, s):
    return '%s: db "%s",0' % (label, s)


# ------------------------------------------------------------ sprites
def gen_sprites():
    lines = []
    jobs = []
    main_ptr = 0xE000; main_end = 0x10000
    bank_ptr = 0x6400; bank_end = 0x6400
    tab = []
    src_lines = []
    sizes = []
    for idx, (name, g) in enumerate(SPRITES):
        wb, h, data = pack_masked(g)
        sizes.append((h * (wb + 1) * 2 * 4, idx))
    place = {}
    for size, idx in sorted(sizes, reverse=True):
        if main_ptr + size <= main_end:
            place[idx] = main_ptr; main_ptr += size
        elif bank_ptr + size <= bank_end:
            place[idx] = bank_ptr; bank_ptr += size
        else:
            raise SystemExit('sprite memory full at %s (need %d more)' % (SPRITES[idx][0], sum(s for s, i in sizes) - 0x1400 - 0x400))
    for idx, (name, g) in enumerate(SPRITES):
        wb, h, data = pack_masked(g)
        blk = h * (wb + 1) * 2
        dst = place[idx]
        jobs.append((name, dst, wb, h))
        tab.append((dst, wb + 1, h, blk))
        src_lines.append(dbs('SS_' + name, data))
        lines.append('SPR_%s equ %d' % (name, idx))
        lines.append('SPRW_%s equ %d' % (name, len(g[0])))
        lines.append('SPRH_%s equ %d' % (name, h))
    print('sprites: main used %d of %d, bank used %d of %d' % (main_ptr - 0xE000, 0x2000, bank_ptr - 0x6400, 0))
    lines.append('SPR_END equ $%04X' % main_ptr)
    # helicopter frame metadata: left offset, rotor hub dx/dy, glint dx/dy, rotor slope (1/8 px per px)
    slopes = {'HELI_L0': 2, 'HELI_L1': 0, 'HELI_L2': -2, 'HELI_L3': -3,
              'HELI_R0': -2, 'HELI_R1': 0, 'HELI_R2': 2, 'HELI_R3': 3}
    names = dict(SPRITES)
    lines.append('HELI_META:')
    for n in HELI_FRAMES:
        g = names[n]; w = len(g[0])
        hub = None
        for y, row in enumerate(g):
            xs = [x for x in range(2, w - 2) if row[x] == 3]
            if len(xs) >= 2 and hub is None:
                hub = ((xs[0] + xs[-1]) // 2, y)
        glass = [(y, x) for y, row in enumerate(g) for x, c in enumerate(row) if c == 0]
        gy = min(y for y, x in glass)
        gxs = [x for y, x in glass if y == gy]
        gx = max(gxs) if n.startswith('HELI_R') else min(gxs)
        lines.append('        db %d,%d,%d,%d,%d,%d' % (w // 2, hub[0], hub[1], gx, gy, slopes.get(n, 0)))
    lines.append('SPRTAB:')
    for (dst, wb1, h, blk) in tab:
        lines.append('        dw $%04X : db %d,%d : dw %d' % (dst, wb1, h, blk))
    lines.append('PSJOBS: db %d' % len(jobs))
    for (name, dst, wb, h) in jobs:
        lines.append('        dw SS_%s,$%04X : db %d,%d' % (name, dst, wb, h))
    lines += src_lines
    return '\n'.join(lines)


# ------------------------------------------------------------ levels
def raw_band(g, period_px):
    out = []
    for row in g:
        assert len(row) == period_px
        out += pack_row(row)
    return out


def sun_data(core, rim, sky):
    g = grid(SUN)
    out = []
    for y, row in enumerate(g):
        for i in range(3):
            s = 0; d = 0
            for k in range(4):
                x = i * 4 + k
                c = row[x]
                s <<= 2; d <<= 2
                if c is not None:
                    s |= 3
                    edge = False
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if not (0 <= xx < 12 and 0 <= yy < 12) or g[yy][xx] is None:
                            edge = True
                    d |= rim if edge else core
            out += [s, d]
    return out


OT_AA = 5; OT_SAM = 6
LEVEL_ENEMIES = [
    # tank_int, tank_max, jet_int, trans_int, gun_int, balloon_int, plane3d_int, missiles allowed
    dict(tank=320, tmax=2, jet=420, trans=640, gun=0, bal=0, p3d=330),
    dict(tank=260, tmax=3, jet=320, trans=520, gun=0, bal=0, p3d=400),
    dict(tank=300, tmax=2, jet=360, trans=0, gun=560, bal=200, p3d=420),
    dict(tank=230, tmax=3, jet=260, trans=520, gun=440, bal=0, p3d=460),
]
LEVEL_STATICS = [
    [],
    [(OT_AA, 152), (OT_AA, 312), (OT_AA, 470)],
    [(OT_AA, 160), (OT_AA, 470)],
    [(OT_AA, 150), (OT_SAM, 310), (OT_AA, 470), (OT_SAM, 610)],
]
OT_AA = 5; OT_SAM = 6


MOVE = []
def gen_levels():
    T = themes()
    lines = []
    total_comp = 0
    for i, t in enumerate(T):
        b = build_theme(t, i)
        bands = (raw_band(b['clouds'], CLOUD_W) + raw_band(b['mount'], MOUNT_W) +
                 raw_band(b['hills'], HILL_W) + raw_band(b['ground'], GROUND_W) + raw_band(b['fg'], FG_W))
        assert len(bands) == 1488, len(bands)
        world = raw_band(b['world'], WORLD_W)
        assert len(world) == 2304
        cb = lz(bands); cw = lz(world)
        assert unlz(cb) == bands and unlz(cw) == world
        total_comp += len(cb) + len(cw)
        MOVE.append(dbs('LV%d_BANDS' % i, cb))
        MOVE.append(dbs('LV%d_WORLD' % i, cw))
        lines.append(asm_str('LV%d_NAME' % i, t['name']))
        lines.append(asm_str('LV%d_OP' % i, t['op']))
        if t['css'] == 0:
            sd = sun_data(1, 3, 2)
        else:
            sd = sun_data(0, 3, 1)
        lines.append(dbs('LV%d_SUN' % i, sd))
        st = LEVEL_STATICS[i]
        lines.append('LV%d_STAT:' % i)
        for ty, x in st:
            lines.append('        db %d : dw %d' % (ty, x))
        lines.append('        db 0')
    print('level data compressed: %d bytes' % total_comp)
    # level table
    lines.append('LVTAB:')
    for i, t in enumerate(T):
        e = LEVEL_ENEMIES[i]
        cc = [c for c, l in t['camps']]; cl = [l for c, l in t['camps']]
        lines.append('        db %d,%d,%d,%d,%d,%d' % (t['css'], t['sky'], t['star'], t['hud_bg'], t['hud_fg'], t['map_bg']))
        lines.append('        dw LV%d_NAME,LV%d_OP,LV%d_BANDS,LV%d_WORLD,LV%d_SUN,LV%d_STAT' % (i, i, i, i, i, i))
        lines.append('        db %s' % ','.join(str(x) for x in cc + cl))
        lines.append('        dw %d,%d,%d,%d,%d,%d : db %d' % (e['tank'], e['jet'], e['trans'], e['gun'], e['bal'], e['p3d'], e['tmax']))
    lines.append('LV_SIZE equ 6+12+8+13')
    lines.append('LV_CSS equ 0\nLV_SKY equ 1\nLV_STAR equ 2\nLV_HUDBG equ 3\nLV_HUDFG equ 4\nLV_MAPBG equ 5')
    lines.append('LV_NAME equ 6\nLV_OP equ 8\nLV_BANDS equ 10\nLV_WORLD equ 12\nLV_SUN equ 14\nLV_STAT equ 16')
    lines.append('LV_CAMPS equ 18\nLV_LOCKS equ 22\nLV_INT equ 26\nLV_TMAX equ 38')
    lines.append('CAMP0X equ %d\nCAMP1X equ %d\nCAMP2X equ %d\nCAMP3X equ %d\nBASEX equ %d' % tuple(CAMP_X + [BASE_X]))
    return '\n'.join(lines)


# ------------------------------------------------------------ title picture
LOGO_FONT = {
 'D': ["#######.", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", "#######."],
 'A': [".######.", "##....##", "##....##", "########", "##....##", "##....##", "##....##", "##....##"],
 'W': ["##....##", "##....##", "##....##", "##.##.##", "##.##.##", "########", "###..###", "##....##"],
 'N': ["##....##", "###...##", "####..##", "##.##.##", "##..####", "##...###", "##....##", "##....##"],
 'P': ["#######.", "##....##", "##....##", "#######.", "##......", "##......", "##......", "##......"],
 'T': ["########", "...##...", "...##...", "...##...", "...##...", "...##...", "...##...", "...##..."],
 'R': ["#######.", "##....##", "##....##", "#######.", "##..##..", "##...##.", "##....##", "##....##"],
 'O': [".######.", "##....##", "##....##", "##....##", "##....##", "##....##", "##....##", ".######."],
 'L': ["##......", "##......", "##......", "##......", "##......", "##......", "##......", "########"],
 ' ': ["...."] * 8,
}
BIG2 = [
 "..########....",
 ".##########...",
 "####....####..",
 "###......###..",
 "..........###.",
 ".........####.",
 "........####..",
 "......#####...",
 ".....####.....",
 "...####.......",
 "..####........",
 ".####.........",
 "####..........",
 "##############",
 "##############",
]


def title_picture():
    T = themes()[0]
    b = build_theme(T, 0)
    W, H = 128, 40
    c = canvas(W, H, 2)
    rnd = random.Random(7)
    for k in range(18):
        x = rnd.randrange(W); y = rnd.randrange(0, 22)
        c[y][x] = 1
    # big sun behind everything
    cx, cy, r = 100, 30, 13
    for y in range(H):
        for x in range(W):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d < r - 1.2:
                c[y][x] = 1
            elif d < r:
                c[y][x] = 3
    # rays dither
    for y in range(H):
        for x in range(W):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if r + 1 < d < r + 4 and c[y][x] == 2 and (x + y) % 3 == 0:
                c[y][x] = 3
    # mountains + hills from jungle
    m = b['mount']; hl = b['hills']
    for y in range(10):
        for x in range(W):
            if m[y][x] != 2:
                c[24 + y][x] = m[y][x]
    for y in range(6):
        for x in range(W):
            c[34 + y][x] = hl[y][(x + 40) % 256]
    # logo
    def draw_word(word, x, y, fg, sh):
        for ch in word:
            g = LOGO_FONT[ch]
            for j, row in enumerate(g):
                for i, p in enumerate(row):
                    if p == '#':
                        if 0 <= y + j + 1 < H and x + i + 1 < W:
                            c[y + j + 1][x + i + 1] = sh
            for j, row in enumerate(g):
                for i, p in enumerate(row):
                    if p == '#':
                        c[y + j][x + i] = fg if j > 0 else 1
            x += len(g[0]) + 1
        return x
    # highlight letter tops
    draw_word('DAWN', 6, 3, 1, 3)
    draw_word('PATROL', 6, 14, 1, 3)
    # big 2
    for j, row in enumerate(BIG2):
        for i, p in enumerate(row):
            if p == '#':
                for dy in (0, 1):
                    yy = 2 + j + dy * 0
                for (ox, oy, col) in ((2, 2, 2), (1, 1, 3), (0, 0, 3)):
                    xx = 66 + i + ox; yy = 4 + j + oy
                    if 0 <= yy < H and xx < W and col == 2:
                        c[yy][xx] = 3
        pass
    for j, row in enumerate(BIG2):
        for i, p in enumerate(row):
            if p == '#':
                c[4 + j + 1][66 + i + 1] = 1
    for j, row in enumerate(BIG2):
        for i, p in enumerate(row):
            if p == '#':
                c[4 + j][66 + i] = 1 if (j < 2 or i < 2) else 3
    return c


def gameover_picture():
    W, H = 128, 40
    c = canvas(W, H, 2)
    rnd = random.Random(11)
    for k in range(14):                     # stars, kept clear of the letters
        x = rnd.choice(list(range(0, 24)) + list(range(106, 128))); y = rnd.randrange(0, 15)
        c[y][x] = 1
    # sunset glow
    for y in range(15, 30):
        for x in range(W):
            k = y - 15
            if k < 3:
                c[y][x] = 3 if (x % 4 == 0 and y % 2 == 0) else 2
            elif k < 6:
                c[y][x] = dither(x, y, 3, 2)
            elif k < 9:
                c[y][x] = 3 if (x + y) % 4 else 1
            else:
                c[y][x] = dither(x, y, 3, 1) if (x // 2 + y) % 3 else 1
    # setting sun
    cx, cy, r = 88, 27, 11
    for y in range(H):
        for x in range(W):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d < r - 1:
                c[y][x] = 1
            elif d < r:
                c[y][x] = 3
    # mountain silhouettes against the glow
    nz = smooth_noise(0, W, random.Random(5), ((64, 1.0), (32, 0.5), (8, 0.15)))
    for x in range(W):
        top = int(29 + 4 - nz[x] * 5)
        for y in range(top, H):
            c[y][x] = 2
        c[top][x] = 3 if x % 3 else 2
    # dark jungle and ground
    for y in range(33, H):
        for x in range(W):
            c[y][x] = dither(x, y, 0, 2) if y < 36 else (0 if (x + y) % 5 else 1)
    # the wreck: our chopper nose-down in the dirt, blade snapped
    g = HELI_LS[3]
    for j, row in enumerate(g):
        for i, p in enumerate(row):
            if p is not None and 30 + j < H:
                c[30 + j][34 + i] = p
    for i in range(9):
        c[37][50 + i] = 3 if i % 3 else 1
    c[36][58] = 3
    return c


def gen_gameover():
    pic = gameover_picture()
    raw = []
    for row in pic:
        raw += pack_row(row)
    cp = lz(raw)
    print('game over picture: %d -> %d' % (len(raw), len(cp)))
    return dbs('GOPIC', cp)


def gen_title():
    pic = title_picture()
    raw = []
    for row in pic:
        raw += pack_row(row)
    cp = lz(raw)
    print('title picture: %d -> %d' % (len(raw), len(cp)))
    return dbs('TITLEPIC', cp)


# ------------------------------------------------------------ main
def main():
    g = []
    g.append('; generated by tools/build.py - do not edit')
    g.append('    align 256')
    g.append('BROW: dw ' + ','.join('$%04X' % (0xD400 + r * 48) for r in range(64)))
    g.append('    align 256')
    g.append('PIXT: db $00,$00,$00,$00, $40,$10,$04,$01, $80,$20,$08,$02, $C0,$30,$0C,$03')
    g.append('      db $3F,$CF,$F3,$FC')
    g.append(gen_sprites())
    g.append(dbs('FONT', font_bytes()))
    g.append(gen_levels())
    g.append('SUN0 equ LV0_SUN')
    MOVE.append(gen_title())
    MOVE.append(gen_gameover())
    open(os.path.join(SRC, 'gen_assets.asm'), 'w').write(music_asm())
    open(os.path.join(SRC, 'gen_speech.asm'), 'w').write(speech_asm())
    open(os.path.join(SRC, 'gen.asm'), 'w').write('\n'.join(g) + '\n')
    open(os.path.join(SRC, 'gen_move.asm'), 'w').write('\n'.join(MOVE) + '\n')
    r = subprocess.run([os.path.join(ROOT, '..', 'sjasmplus', 'sjasmplus'), '--nologo', '--msg=war',
                        '--lst=' + os.path.join(OUT, 'dp2.lst'), '--sym=' + os.path.join(OUT, 'dp2.sym'),
                        'main.asm'] + (['-DDEBUG=1'] if os.environ.get('DEBUG') else []), cwd=SRC, capture_output=True, text=True)
    print(r.stdout[-3000:], r.stderr[-3000:])
    if r.returncode:
        raise SystemExit('assembly failed')
    binf = os.path.join(OUT, 'dp2.bin')
    data = open(binf, 'rb').read()
    start = 0x8000
    end = start + len(data)
    print('code+data: $%04X-$%04X (%d bytes)' % (start, end - 1, len(data)))
    assert end <= 0xFA00, 'file too big for the SD loader'
    sym = open(os.path.join(OUT, 'dp2.sym')).read()
    import re
    m = re.search(r'RESIDENT_END:\s*EQU\s*0x([0-9A-F]+)', sym, re.I)
    print('resident code ends $%s (buffer at $D400)' % m.group(1))
    hdr = b'  \x00\x00' + b'DAWNPATROL2'.ljust(17, b'\0') + bytes([0xF1, start & 255, start >> 8])
    open(os.path.join(OUT, 'DP2.VZ'), 'wb').write(hdr + data)
    print('wrote DP2.VZ', len(hdr + data))


if __name__ == '__main__':
    main()
