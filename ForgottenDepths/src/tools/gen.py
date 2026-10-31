"""THE FORGOTTEN DEPTHS - data generator.

build/consts.inc   shared EQUs (tiles, entity types, memory layout)
build/data.inc     hot data (main RAM): glyph pages + tile tables, light trees, entity tables
build/cold.inc     common cold data (SRAM bank 1 at $4000): pages, texts, common music, sfx
build/levelN.asm   chapter blocks: cold part at LSLOT (bank 1) + hot part copied to LVBUF
"""
import math
import os
import subprocess
import sys
import importlib
import rays as R
from tiles import DEFS, TILES, LIGHTS, MEM, CDIM, DIM, COOL, LIT
from levelc import compile_level, SW, SH, W as MW, H as MH
from glyph import text, T, V, S, BLK
import music
import screens
import pictures

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, '..', 'build')
os.makedirs(OUT, exist_ok=True)

LSLOT = 0x5A40            # chapter block in bank 3 ($5A40-$67FF)
LSLOT_END = 0x6800
COLD_END = LSLOT          # common cold must fit $4000-$4FFF
LVBUF_SIZE = 1024
NLEVELS = 3


def dbl(dst, vals, per=16):
    vals = list(vals)
    for i in range(0, len(vals), per):
        dst.append('        db ' + ','.join(str(v & 255) for v in vals[i:i + per]))


def zx0bytes(name, data):
    raw = os.path.join(OUT, name + '.raw')
    open(raw, 'wb').write(bytes(data))
    subprocess.run([os.path.join(HERE, 'zx0'), '-f', raw, raw + '.zx0'], check=True, capture_output=True)
    return open(raw + '.zx0', 'rb').read()


# ================================================================ constants
K = []
K.append(f'LSLOT EQU ${LSLOT:04X}')
K.append(f'LVBUF_SIZE EQU {LVBUF_SIZE}')
K.append('LVBUF EQU $C800')
for name, tid in TILES.items():
    K.append(f'TL_{name.upper()} EQU {tid}')
for i, nm in enumerate(screens.ENTNAMES):
    K.append(f'E_{nm.upper()} EQU {i}')
K += music.consts()
# chapter hot buffer layout
K += ['LV_NUM EQU 0', 'LV_SX EQU 1', 'LV_SY EQU 2', 'LV_SDIR EQU 3', 'LV_SCREENS EQU 4', 'LV_BOSS EQU 52',
      'LV_TITLE EQU 100', 'LV_PORTALS EQU 132', 'LV_SPAWNS EQU 140']
K += ['BD_NAME EQU 0', 'BD_SIZE EQU 12', 'BD_HP EQU 13', 'BD_SPEED EQU 14', 'BD_SHOT EQU 15', 'BD_PAT EQU 16',
      'BD_MINION EQU 17', 'BD_MEVERY EQU 18', 'BD_ALIVE EQU 19', 'BD_X EQU 20', 'BD_Y EQU 21', 'BD_SHOTG EQU 22',
      'BD_GLY EQU 24']
# chapter block header (at LSLOT)
K += ['LB_HOTSRC EQU LSLOT+0', 'LB_HOTLEN EQU LSLOT+2', 'LB_MAP EQU LSLOT+4', 'LB_MSGS EQU LSLOT+6',
      'LB_PIC EQU LSLOT+8', 'LB_TRK EQU LSLOT+10', 'LB_SMSG EQU LSLOT+12', 'LB_PIC2 EQU LSLOT+14']
open(os.path.join(OUT, 'consts.inc'), 'w').write('\n'.join(K) + '\n')

# ================================================================ hot common data
L = []
ANIMSPD = {'water': 15, 'pool': 7, 'mote': 0x80, 'portal': 3, 'rune': 7, 'candle': 3, 'shroom': 15,
           'torch': 3, 'brazier': 1, 'crystal': 7, 'lava': 7, 'seal': 3, 'ember': 1, 'gear': 7}
tprop, tanim, tlite = [], [], []
lkinds = list(LIGHTS.keys())
for t in range(128):
    d = DEFS.get(t)
    if d is None:
        tprop.append(1)
        tanim.append(0)
        tlite.append(0)
        continue
    p = 1 if d['solid'] else 0
    base = d['name'].rstrip('0123456789')
    sp = ANIMSPD.get(base, 0) if d['name'][-1].isdigit() and base in ANIMSPD else 0
    if sp:
        p |= 2
    p |= d['special'] << 4
    tprop.append(p)
    tanim.append(sp)
    tlite.append(lkinds.index(d['light']) + 1 if d['light'] else 0)
mapcol = screens.mapcol()
L.append('        ALIGN 256')
L.append('GPAGES:')
lower = {1: tprop, 2: tanim, 3: tlite, 4: mapcol}
for lv in range(5):
    page = []
    for i in range(256):
        t = i & 127
        d = DEFS.get(t)
        if i < 128:
            page.append(BLK if lv == 0 else lower[lv][i])
        else:
            page.append(d['g'][lv] if d else BLK)
    dbl(L, page)
L += ['TPROP EQU GPAGES+256', 'TANIM EQU GPAGES+512', 'TLITE EQU GPAGES+768', 'MAPCOL EQU GPAGES+1024']

uniq = {}


def emit_tree(dst, label, rays, origin_level):
    t = R.tree(R.cellmap(rays), origin_level)
    dst.append(f'{label}:')
    for i, (dx, dy, lv, nsub) in enumerate(t):
        assert nsub < 256 or i == 0
        if i == 0:
            nsub = 0
        dst.append(f'        dw {(dy * 256 + dx) & 0xFFFF}')
        dst.append(f'        db {lv},{nsub}')
    dst.append('        dw $8080')
    uniq[label] = len(t)
    return t


STATIC = []      # static light trees go to cold (only used at room entry, bank 1 mapped)
for kind, (name, near, far) in LIGHTS.items():
    r = int(name[4:])
    emit_tree(STATIC, f'RL_{kind}', R.omni(r * 0.62, r, near, far), near)
STATIC.append('LITETAB: dw 0,' + ','.join(f'RL_{k}' for k in lkinds))
emit_tree(L, 'RL_fball', R.omni(1.4, 3.0, LIT, DIM), LIT)
emit_tree(L, 'RL_boom', R.omni(3.6, 6.5, LIT, DIM), LIT)
NV = 2
pmax = 0
for setn, (ll, dl, an, af, hf) in enumerate([(8.0, 12.0, 2.2, 3.6, 0.70), (10.5, 15.5, 2.8, 4.6, 0.80)]):
    for di, ang in enumerate([0.0, math.pi / 2, math.pi, -math.pi / 2]):
        nv = NV if setn == 0 else 1
        for v in range(nv):
            t = emit_tree(L, f'RL_p{setn}{di}{v}', R.cone(ang, di * 10 + v + setn * 50, LIT, DIM, lit_len=ll,
                                                           dim_len=dl, half=hf, amb_near=an, amb_far=af), LIT)
            pmax = max(pmax, len(t))
    nv = NV if setn == 0 else 1
    L.append(f'PRAYS{setn}: dw ' + ','.join(f'RL_p{setn}{d}{v % nv}' for d in range(4) for v in range(NV)))
L.append(f'NVAR EQU {NV}')
cap = pmax + uniq['RL_boom'] + uniq['RL_fball']
print(f'light trees: lantern max {pmax} cells, boom {uniq["RL_boom"]}, fireball {uniq["RL_fball"]} -> list {cap}/384')
assert cap <= 384
screens.emit_hot(L)
open(os.path.join(OUT, 'data.inc'), 'w').write('\n'.join(L) + '\n')

# ================================================================ cold common data
C = list(STATIC)
TEXTS = dict(
    T_STAFF='THE EMBER STAFF!  M CASTS FIRE', T_KEY='A KEY! IT MUST OPEN SOMETHING',
    T_GEM='A GLITTERING GEM', T_POTION='A POTION. YOU FEEL RESTORED', T_HEART='HEART CRYSTAL! LIFE INCREASED',
    T_LOCKED='THE DOOR IS SEALED. A KEY...', T_OPEN='THE KEY TURNS. CLICK.', T_HIDDEN='THE WALL CRUMBLES AWAY!',
    T_NOMP='YOUR STAFF FLICKERS... NO MANA', T_STAIRUP='THE WAY BACK HAS COLLAPSED', T_DIED='YOU HAVE FALLEN',
    T_LEVEL='YOU FEEL STRONGER. LEVEL UP!', T_BOOTS='REED BOOTS! YOU CAN WADE NOW',
    T_SUN='THE SUNSTONE! YOUR LIGHT GROWS', T_RING='RING OF EMBERS! LAVA IS SAFE',
    T_BLADE='THE RUNEBLADE! IT HUMS', T_MANA='A MANA CRYSTAL. MORE MAGIC',
    T_WATER='TOO DEEP TO WADE...', T_LAVA='THE LAVA WOULD BURN YOU',
    T_SEALS='THE SEALS FADE. THE WAY OPENS', T_SEALED='A MAGIC SEAL BARS THE WAY',
    T_NODAT='DEPTHS.DAT NOT FOUND ON SD CARD', T_BADPW='THAT PASSWORD IS NOT KNOWN',
    T_GATE='AN IRON GATE. NO WAY TO LIFT IT', T_GRIND='SOMETHING GRINDS OPEN NEARBY',
    T_PORTAL='THE PORTAL PULLS YOU THROUGH!',
)
for k, v in TEXTS.items():
    assert len(v) <= 32, v
    C.append(f'{k}:')
    dbl(C, list(text(v.center(32))))
C += music.emit_cold()
C += music.emit_hot()
screens.emit_cold(C, zx0bytes)
open(os.path.join(OUT, 'cold.inc'), 'w').write('\n'.join(C) + '\n')

# ================================================================ chapter blocks
for n in range(1, NLEVELS + 1):
    mod = importlib.import_module(f'level{n}')
    lv = compile_level(mod)
    B = ['        DEVICE NOSLOT64K', '        INCLUDE "consts.inc"', '        ORG $1000', '        DISP LSLOT',
         'LB: dw LB_HOT, LB_HOTE-LB_HOTS, LBM, LBMSG, LBPIC, LBTRK, LBSM, LBPIC2']
    tracks = music.LEVELTRACKS[n]
    B.append('LBTRK: dw ' + ','.join(f'L_{t}_a,L_{t}_b,L_{t}_c,L_{t}_d' for t in tracks))
    B.append('LBSM:')
    dbl(B, list(text(mod.START_MSG.center(32))))
    raw = bytearray()
    for row in lv['tiles']:
        raw += bytes(row) + bytes(128)
    z = zx0bytes(f'map{n}', raw)
    B.append('LBM:')
    dbl(B, z)
    B.append('LBMSG:')
    for (x, y), m in lv['msgs']:
        dbl(B, [x, y])
        dbl(B, list(text(m.center(32))))
    dbl(B, [255])
    s, css = pictures.PICS[mod.BOSS['pic']]()
    z = zx0bytes(f'pic{n}', pictures.pack(s))
    B.append('LBPIC:')
    dbl(B, [css])
    dbl(B, z)
    if n == NLEVELS:
        s, css = pictures.dawn()
        z = zx0bytes('picend', pictures.pack(s))
        B.append('LBPIC2:')
        dbl(B, [css])
        dbl(B, z)
    else:
        B.append('LBPIC2 EQU 0')
    B += music.emit_tracks(tracks, 'L_')
    B.append('LB_HOT:')
    B.append('        ENT')
    B.append('        DISP LVBUF')
    B.append('LB_HOTS:')
    # header
    start = None
    boss_pos = None
    spawns = []
    for k, x, y in lv['ents']:
        if k == 'player':
            start = (x, y)
        elif k == 'boss':
            boss_pos = (x, y)
        else:
            spawns.append((screens.ENTNAMES.index(k), x, y))
    dbl(B, [n, start[0], start[1], 1])
    # screens (12)
    for sy in range(3):
        for sx in range(4):
            sc = mod.SCREENS.get((sx, sy))
            if sc:
                tr = sc.get('music', sc['region'])
                if tr not in tracks:
                    tr = tracks[0]
                B.append(f'        db {sc["css"]},{0x10 + tracks.index(tr)}')
                B.append(f'        dw LN_{sx}{sy}')
            else:
                B.append('        db 1,$10')
                B.append('        dw LN_NONE')
    # boss def (48 bytes)
    bd = mod.BOSS
    boss = list(text(bd['name'].ljust(12)[:12]))
    minion = screens.ENTNAMES.index(bd['minion']) if bd.get('minion') else 0
    boss += [bd['size'], bd['hp'], bd['speed'], bd['shot'], bd['pattern'], minion, bd['minion_every'] // 4, 1,
             boss_pos[0], boss_pos[1], bd['shot_glyph'], 0]
    g0, g1 = bd['glyphs']
    g0 = (g0 + [BLK] * 9)[:9]
    g1 = (g1 + [BLK] * 9)[:9]
    if bd['size'] == 2:
        g0 = [g0[0], g0[1], BLK, g0[2], g0[3], BLK, BLK, BLK, BLK]
        g1 = [g1[0], g1[1], BLK, g1[2], g1[3], BLK, BLK, BLK, BLK]
    boss += g0 + g1
    boss += [0] * (48 - len(boss))
    assert len(boss) == 48
    dbl(B, boss)
    dbl(B, list(text(f'CHAPTER {"I" * n if n < 4 else n}: {mod.NAME}'.center(32))))
    pt = []
    for (x, y) in lv['portals']:
        pt += [x, y]
    pt = (pt + [255] * 8)[:8]
    dbl(B, pt)
    for t, x, y in spawns:
        dbl(B, [t, x, y, 1])
    dbl(B, [0])
    for (sx, sy), sc in mod.SCREENS.items():
        assert len(sc['title']) <= 17, sc['title']
        B.append(f'LN_{sx}{sy}:')
        dbl(B, list(text(sc['title'].center(17))))
    B.append('LN_NONE:')
    dbl(B, list(text(' ' * 17)))
    B.append('LB_HOTE:')
    B.append('        ENT')
    B.append('LB_PEND:')
    B.append('        ASSERT LB_HOTE-LB_HOTS <= LVBUF_SIZE')
    B.append('        ASSERT LB_PEND-$1000 <= $6800-LSLOT')
    B.append('        ASSERT LB_HOT + (LB_HOTE-LB_HOTS) <= $6800')
    B.append(f'        DISPLAY "chapter {n}: cold ", LB_HOT-LSLOT, " hot ", LB_HOTE-LB_HOTS, " total ", LB_PEND-$1000')
    B.append(f'        SAVEBIN "level{n}.bin", $1000, LB_PEND-$1000')
    open(os.path.join(OUT, f'level{n}.asm'), 'w').write('\n'.join(B) + '\n')
print('generated')
