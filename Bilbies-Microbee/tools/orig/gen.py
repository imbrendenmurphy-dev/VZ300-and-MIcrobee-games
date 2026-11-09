"""Generate src/data.asm: tables, font, sprites, objects, panel, textures, levels, music."""
import os, sys, subprocess
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art, music, lvlkit
from art import pack
import levels

W = os.path.dirname(os.path.abspath(__file__)) + '/..'
L = []
e = L.append

def db(lab, bs, per=32):
    if lab: e('%s:' % lab)
    for i in range(0, len(bs), per):
        e('        db ' + ','.join(str(x) for x in bs[i:i + per]))

# ---- page-aligned tables -------------------------------------------------------
e('        ALIGN 256')
e('BROW:')
for y in range(44):
    e('        dw BACK+%d' % (y * 36))
e('        ALIGN 256')
e('VROW:')
for y in range(44):
    e('        dw VRAM+%d-2' % (y * 32))
e('PMSK:   db $C0,$30,$0C,$03')
e('BITT:   db $80,$40,$20,$10,$08,$04,$02,$01')
e('NIB2:   db ' + ','.join(str(sum((3 << (6 - 2 * i)) for i in range(4) if n & (8 >> i))) for n in range(16)))
e('SQT:    db ' + ','.join(str(v) for v in __import__('lvlkit').SQT))
e('        ASSERT (PMSK & 255) < 252')

# ---- font ----------------------------------------------------------------------
db('FONT', art.font_bytes())

# ---- bilby animations ----------------------------------------------------------
frames = art.anim_frames()
e('ANIMT:  db 1,0 : dw SPR_none,SPR_none')
for name, n, r, l in frames:
    e('        db %d,0 : dw SPR_%s_r,SPR_%s_l' % (n, name, name))
e('        db 1,0 : dw SPR_none,SPR_none')
e('        db 1,0 : dw SPR_none,SPR_none')
db('SPR_none', pack(['........'] * 7))
for name, n, r, l in frames:
    bs = []
    for f in r: bs += pack(f)
    db('SPR_%s_r' % name, bs, 28)
    bs = []
    for f in l: bs += pack(f)
    db('SPR_%s_l' % name, bs, 28)
bs = []
for d in '012345':
    bs += pack(art.digit_sprite(d))
db('DIGSPR', bs, 28)
db('CURS0', pack(art.CURS0))
db('CURS1', pack(art.CURS1))

# ---- objects ---------------------------------------------------------------------
bs = []
for i in range(8): bs += pack(art.hatch(i))
db('HATCHF', bs, 18)
bs = []
for i in range(4): bs += pack(art.burrow(i))
db('EXITF', bs, 24)
bs = []
for row in art.WATER:
    bs += pack(row)
db('WATERP', bs)

# ---- textures ---------------------------------------------------------------------
e('TEXT:')
for n in art.TEXNAMES:
    db(None, art.tex_bytes(n), 16)

# ---- panel ---------------------------------------------------------------------------
db('PANELIMG', pack(art.panel_image()))
e('STNAMES:')
for i, n in enumerate(art.STNAMES):
    e('        dw stn_%d' % i)
for i, n in enumerate(art.STNAMES):
    e('stn_%d:  db "%s",0' % (i, n))

# ---- levels: their designs go to SRAM bank B (build/levels.bin, at $4000) ------
lv = levels.LEVELS
e('LVCOUNT equ %d' % len(lv))
e('PERRATE equ %d' % levels.PERRATE)
e('LV_TITLE equ %d' % len(lv))
blob = bytearray(b'BL')
# scenery stamps first: a table of addresses at $4002, then each one as
# bytes-across, rows, ZX0 data
import stamps
blob += bytes(2 * len(stamps.NAMES))
for k, n in enumerate(stamps.NAMES):
    rows = stamps.S[n]
    open(W + '/build/st.raw', 'wb').write(bytes(pack(rows)))
    subprocess.run(['zx0', '-f', W + '/build/st.raw', W + '/build/st.zx0'], capture_output=True, check=True)
    z = open(W + '/build/st.zx0', 'rb').read()
    a = 0x4000 + len(blob)
    blob[2 + 2 * k], blob[3 + 2 * k] = a & 255, a >> 8
    blob += bytes([len(rows[0]) // 4, len(rows)]) + z
print('stamps: %d, %d bytes' % (len(stamps.NAMES), len(blob) - 2))
e('LVTAB:')
for i, l in enumerate(lv + [levels.TITLE]):
    b = l.compile('LV%d' % i)
    assert len(b) <= 1584, '%s is too big (%d)' % (l.name, len(b))
    open(W + '/build/lv.raw', 'wb').write(bytes(b))
    subprocess.run(['zx0', '-f', W + '/build/lv.raw', W + '/build/lv.zx0'], capture_output=True, check=True)
    z = open(W + '/build/lv.zx0', 'rb').read()
    e('        dw $%04X,%d' % (0x4000 + len(blob), len(z)))
    blob += z
e('NOSCRIPT: db $FF')
# the solution scripts (attract mode + tests) also live in bank B
e('SCRTAB:')
for i, l in enumerate(lv):
    if l.script:
        sb = bytearray()
        for ev in l.script:
            t, c, sk = ev[:3]
            if c == 'all': c = 255
            x0, x1 = (ev[3], ev[4]) if len(ev) > 3 else (0, 1023)
            sb += bytes([t & 255, t >> 8, c, lvlkit.SKILLS.index(sk), x0 & 255, x0 >> 8, x1 & 255, x1 >> 8])
        sb += b'\xFF'
        assert len(sb) <= 125, '%s: script too long' % l.name
        e('        dw $%04X' % (0x4000 + len(blob)))
        blob += bytes([len(sb)]) + sb
    else:
        e('        dw 0')
assert len(blob) <= 10240, 'bank B: %d bytes' % len(blob)
open(W + '/build/levels.bin', 'wb').write(blob)
print('bank B: %d bytes (levels, scripts, scenery)' % len(blob))
dem = levels.DEMOS
e('NDEMO   equ %d' % len(dem))
e('DEMOS:  db ' + ','.join(str(i) for i in dem))

# ---- music ---------------------------------------------------------------------------------
music.emit_all(e)

open(W + '/src/data.asm', 'w').write('\n'.join(L) + '\n')
print('data.asm: %d lines, %d levels' % (len(L), len(lv)))
