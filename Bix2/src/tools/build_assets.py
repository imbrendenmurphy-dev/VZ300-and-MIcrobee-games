# BIX 2 asset pipeline: builds the SD stage packs, overlay data,
# resident fonts and the asm include of constants.
import os, struct
import art, art2, level1, levels2, music, lz
OUT = os.path.join(os.path.dirname(__file__), '..', 'build')
os.makedirs(OUT, exist_ok=True)
CV = {'.': 0, 'g': 0, 'y': 1, 'b': 2, 'r': 3}

def pack_row(row):
    out = []
    for i in range(0, len(row), 4):
        v = 0
        for c in row[i:i + 4]: v = (v << 2) | CV[c]
        out.append(v)
    return out
def pack(rows):
    b = bytearray()
    for r in rows: b += bytes(pack_row(r))
    return b

SLOTS = [n for n, _, _ in art.TILES]
ATTRS = bytes(a for _, _, a in art.TILES)
TID = {n: i for i, n in enumerate(SLOTS)}

def tilerows(world, n, rows):
    if world == 2: return art2.W2_TILES[n]
    if world == 3: return art2.W3_TILES[n]
    if world == 4: return art2.W4_TILES[n]
    if world == 5: return art2.W5_TILES[n]
    return rows
def tileset(world):
    b = bytearray()
    for n, rows, _ in art.TILES:
        b += pack(tilerows(world, n, rows))
    return b

def enemies(world):
    src = {1: art2.w1_enemies(), 2: art2.W2_ENEMY, 3: art2.W3_ENEMY, 4: art2.W4_ENEMY, 5: art2.W5_ENEMY}[world]
    b = bytearray()
    for n in art2.ENEMY_ORDER: b += pack(src[n])
    return b

def rle(data):   # c<$80: c+1 literals ; c>=$80: run of (c-$80+3)
    out = bytearray(); i = 0; lit = bytearray()
    def flush():
        nonlocal lit
        while lit:
            ch = lit[:128]; out.append(len(ch) - 1); out.extend(ch); lit = lit[128:]
    while i < len(data):
        j = i
        while j < len(data) and data[j] == data[i] and j - i < 130: j += 1
        if j - i >= 3:
            flush(); out.append(0x80 + (j - i - 3)); out.append(data[i]); i = j
        else:
            lit.append(data[i]); i += 1
    flush()
    return out

def rowmajor(colmajor, W):
    return bytes(colmajor[x * 12 + y] for y in range(12) for x in range(W))

# ---------------------------------------------------------------- levels
# Bix 2: five worlds x (three acts + a boss) = 20 stages, one SD pack each.
import levels3
LV = []
def lvl(world, L, song, boss=0, W=None):
    m, e = L.build(TID) if hasattr(L, 'build') else L
    return dict(world=world, boss=boss, W=W or L.W, map=m, ents=e, start=L.start(), song=song)
class _L11:                     # 1-1 is built by level1.py
    W = level1.W
    def build(self, tid): return level1.build()
    def start(self):
        st = [e for e in level1.ents if e[2] == level1.E_START][0][:2]
        return st
WORLDS = [
    (1, _L11(), 'gully', levels3.level_1_2(), 'gully2', levels3.level_1_3(), 'gully3', levels2.level_1_2(), 'boss'),
    (2, levels2.level_2_1(), 'caves', levels3.level_2_2(), 'caves2', levels3.level_2_3(), 'caves3', levels2.level_2_2(), 'golem'),
    (3, levels2.level_3_1(), 'factory', levels3.level_3_2(), 'factory2', levels3.level_3_3(), 'factory3', levels2.level_3_2(), 'robot'),
    (4, levels2.level_4_1(), 'sky', levels3.level_4_2(), 'sky2', levels3.level_4_3(), 'sky3', levels2.level_4_2(), 'hawk'),
    (5, levels2.level_5_1(), 'peaks', levels3.level_5_2(), 'peaks2', levels3.level_5_3(), 'peaks3', levels2.level_5_2(), 'dragon'),
]
for w, a1, s1, a2, s2, a3, s3, bo, sb in WORLDS:
    LV.append(lvl(w, a1, s1)); LV.append(lvl(w, a2, s2)); LV.append(lvl(w, a3, s3)); LV.append(lvl(w, bo, sb, boss=w))
if os.environ.get('BIX_START'):          # test builds: start position in the START_LEVEL stage
    k = int(os.environ.get('BIX_LEVEL', '0'))
    LV[k]['start'] = (int(os.environ['BIX_START']), 7)

# ---------------------------------------------------------------- SD stage packs
# BIX2Lnn.DAT, loaded into upper bank 0 at PACK.  Header: "B2", level, build
# id, file length, then the level record (pointers are absolute in the pack),
# then the LZ blobs.
PACK = 0xD200
PACK_MAX = 0xE000 - PACK
LVSIZE = 40
SONGS = music.songs()
BOSSART = {1: (art2.BOSS1, art2.BOSS_ORDER), 2: (art2.BOSS2, art2.BOSS2_ORDER), 3: (art2.BOSS3, art2.BOSS3_ORDER),
           4: (art2.BOSS4, art2.BOSS4_ORDER), 5: (art2.BOSS5, art2.BOSS5_ORDER)}
player_lz = lz.compress(b''.join(pack(art.BIX[n]) for n in art.BIX_ORDER))
plat_raw = bytes(pack(art.PLATFORM))
packs = []
for i, L in enumerate(LV):
    assert L['W'] <= 296, ('level too wide for the loader scratch', i, L['W'])
    assert len(L['ents']) <= 256, ('too many spawn records', i, len(L['ents']) // 5)
    w = L['world']
    body = bytearray()
    def put(b):
        a = PACK + 8 + LVSIZE + len(body); body.extend(b); return a
    rm = lz.compress(rowmajor(L['map'], L['W']))
    assert len(rm) <= 2200, ('packed map too big for LANDING', i, len(rm))
    mapp = put(rm); entp = put(L['ents'])
    sb = SONGS[L['song']]; songp = put(lz.compress(sb))
    tilp = put(lz.compress(tileset(w))); attp = put(ATTRS); enp = put(lz.compress(enemies(w)))
    d, o = BOSSART[L['boss'] or w]
    bossp = put(lz.compress(b''.join(pack(d[n]) for n in o)))
    plp = put(player_lz); platp = put(plat_raw)
    flags = 1 if L['boss'] else 0
    rec = struct.pack('<BBHHBB', w, flags, L['W'], L['start'][0], L['start'][1], L['boss'])
    rec += struct.pack('<BH', 3, mapp)
    rec += struct.pack('<BHH', 3, entp, len(L['ents']))
    rec += struct.pack('<BHH', 3, songp, len(sb))
    rec += struct.pack('<BH', 3, tilp) + struct.pack('<BH', 3, attp) + struct.pack('<BH', 3, enp) + struct.pack('<BH', 3, bossp)
    rec += struct.pack('<HH', plp, platp)
    assert len(rec) <= LVSIZE, len(rec)
    rec += bytes(LVSIZE - len(rec))
    packs.append((rec, body))
import zlib
BUILD_ID = zlib.crc32(b''.join(r + b for r, b in packs)) & 0xFFFF
os.makedirs(os.path.join(OUT, 'sd'), exist_ok=True)
for i, (rec, body) in enumerate(packs):
    total = 8 + LVSIZE + len(body)
    assert total <= PACK_MAX, ('stage pack too big', i, total)
    f = b'B2' + bytes([i]) + struct.pack('<HH', BUILD_ID, total) + b'\0' + rec + body
    open(os.path.join(OUT, 'sd', f'BIX2L{i + 1:02d}.DAT'), 'wb').write(f)

# ---------------------------------------------------------------- fonts / overlay data
def font_bytes(fg, bg):
    b = bytearray()
    for ch in range(32, 96):
        rows = art.FONT.get(chr(ch), art.FONT[' '])
        for r in rows:
            v = 0
            for p in r + '.': v = (v << 2) | (fg if p != '.' else bg)
            b.append(v)
    return b
open(os.path.join(OUT, 'font_hud.bin'), 'wb').write(font_bytes(1, 3))
open(os.path.join(OUT, 'font_sky.bin'), 'wb').write(font_bytes(1, 2))
bb = bytearray()
for n in ['idle', 'blink', 'twitch', 'cheer']: bb += pack(art.BIX[n])
open(os.path.join(OUT, 'bigbix.bin'), 'wb').write(bb)
open(os.path.join(OUT, 'bigboss.bin'), 'wb').write(pack(art2.BOSS1['sit1']))

with open(os.path.join(OUT, 'assets.inc'), 'w') as f:
    f.write('; generated by build_assets.py\n')
    for i, n in enumerate(SLOTS): f.write(f'T_{n.upper()} equ {i}\n')
    for n in ['SOLID', 'ONEWAY', 'DIG', 'HAZ', 'STAR', 'SPRING', 'BREAK', 'SPECIAL']:
        f.write(f'A_{n} equ {getattr(art, n)}\n')
    for i, n in enumerate(art.BIX_ORDER): f.write(f'PF_{n.upper()} equ {i}\n')
    f.write(f'NPFRAMES equ {len(art.BIX_ORDER)}\n')
    for i, n in enumerate(art2.ENEMY_ORDER): f.write(f'EF_{n.upper()} equ {i}\n')
    f.write(f'NEFRAMES equ {len(art2.ENEMY_ORDER)}\nNEFLIP equ {art2.NFLIP}\n')
    f.write(f'NTILES equ {len(SLOTS)}\n')
    f.write(f"START_LEVEL equ {int(os.environ.get('BIX_LEVEL', '0'))}\n")
    f.write(f'LVSIZE equ {LVSIZE}\nNLEVELS equ {len(LV)}\n')
    f.write(f'BUILD_ID equ {BUILD_ID:#06x}\nPACK_PY equ {PACK:#06x}\n')
print('packs:', ' '.join(f"{i+1}:{8+LVSIZE+len(b)}" for i, (r, b) in enumerate(packs)), 'id', hex(BUILD_ID))

# ---------------------------------------------------------------- previews
from PIL import Image
PAL1 = [(0x30, 0xd0, 0x30), (0xf0, 0xf0, 0x50), (0x30, 0x40, 0xd8), (0xd8, 0x30, 0x30)]
PAL2 = [(0xe8, 0xe8, 0xd0), (0x40, 0xd0, 0xd0), (0xd0, 0x40, 0xd0), (0xf0, 0x90, 0x30)]
for i, L in enumerate(LV):
    pal = PAL2 if L['world'] in (2, 4) else PAL1
    ts = [tilerows(L['world'], n, rows) for n, rows, _ in art.TILES]
    img = Image.new('RGB', (L['W'] * 8, 96)); px = img.load()
    for x in range(L['W']):
        for y in range(12):
            rows = ts[L['map'][x * 12 + y]]
            for j in range(8):
                for k in range(8): px[x * 8 + k, y * 8 + j] = pal[CV[rows[j][k]]]
    img.save(os.path.join(OUT, f'level{i}_map.png'))
