# BIX asset pipeline (v0.2): builds the bank-3 world archive, overlay data,
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
L11m, L11e = level1.build()
st11 = [e for e in level1.ents if e[2] == level1.E_START][0][:2]
if os.environ.get('BIX_START'): st11 = (int(os.environ['BIX_START']), 7)
LV = []
def mirror_of(L, idx):
    M = dict(L); M['mirror'] = 1; M['src'] = idx
    M['start'] = (L['W'] - 1 - L['start'][0], L['start'][1])
    if os.environ.get('BIX_MSTART'): M['start'] = (int(os.environ['BIX_MSTART']), 7)
    return M
def add_world(normal, boss):
    LV.append(normal); LV.append(mirror_of(normal, len(LV) - 1)); LV.append(boss)
add_world(dict(world=1, boss=0, W=level1.W, map=L11m, ents=L11e, start=st11, song='gully'),
          dict(world=1, boss=1, W=16, **dict(zip(('map', 'ents'), levels2.level_1_2().build(TID))), start=levels2.level_1_2().start(), song='boss'))
l21 = levels2.level_2_1(); m, e = l21.build(TID)
st21 = l21.start()
if os.environ.get('BIX_START2'): st21 = (int(os.environ['BIX_START2']), 7)
l22 = levels2.level_2_2(); m2, e2 = l22.build(TID)
add_world(dict(world=2, boss=0, W=l21.W, map=m, ents=e, start=st21, song='caves'),
          dict(world=2, boss=2, W=16, map=m2, ents=e2, start=l22.start(), song='golem'))
l31 = levels2.level_3_1(); m, e = l31.build(TID)
st31 = l31.start()
if os.environ.get('BIX_START3'): st31 = (int(os.environ['BIX_START3']), 7)
l32 = levels2.level_3_2(); m2, e2 = l32.build(TID)
add_world(dict(world=3, boss=0, W=l31.W, map=m, ents=e, start=st31, song='factory'),
          dict(world=3, boss=3, W=16, map=m2, ents=e2, start=l32.start(), song='robot'))
l41 = levels2.level_4_1(); m, e = l41.build(TID)
st41 = l41.start()
if os.environ.get('BIX_START4'): st41 = (int(os.environ['BIX_START4']), 7)
l42 = levels2.level_4_2(); m2, e2 = l42.build(TID)
add_world(dict(world=4, boss=0, W=l41.W, map=m, ents=e, start=st41, song='sky'),
          dict(world=4, boss=4, W=16, map=m2, ents=e2, start=l42.start(), song='hawk'))
l51 = levels2.level_5_1(); m, e = l51.build(TID)
st51 = l51.start()
if os.environ.get('BIX_START5'): st51 = (int(os.environ['BIX_START5']), 7)
l52 = levels2.level_5_2(); m2, e2 = l52.build(TID)
add_world(dict(world=5, boss=0, W=l51.W, map=m, ents=e, start=st51, song='peaks'),
          dict(world=5, boss=5, W=16, map=m2, ents=e2, start=l52.start(), song='dragon'))
if os.environ.get('BIX_LEVEL'):          # test builds: start at another level
    pass

# ---------------------------------------------------------------- bank archives
# Every asset is placed first-fit into bank 3 or bank 5; level records carry a
# bank number next to each pointer.  The level table sits at the start of bank 3.
B5BASE = 0xB800 + 0x1700        # upper bank: after the packed overlay (<= 5.75K)
LIMIT = {3: 0x67F0, 5: 0xFFF0}  # bank 3 is the 10K $4000-$67FF bank
LVSIZE = 40
blobs = {3: bytearray(), 5: bytearray()}
bases = {3: 0x4000, 5: B5BASE}
tab = 0x4000
blobs[3].extend(bytes(LVSIZE * len(LV)))     # reserve the table
def put(b, bank=None):
    for bk in ([bank] if bank else (3, 5)):
        a = bases[bk] + len(blobs[bk])
        if a + len(b) <= LIMIT[bk]:
            blobs[bk].extend(b); return (bk, a)
    raise SystemExit(f'archive full: need {len(b)} bytes (bank3 {len(blobs[3])}, bank5 {len(blobs[5])})')
player_raw = put(lz.compress(b''.join(pack(art.BIX[n]) for n in art.BIX_ORDER)), 3)[1]
plat_raw = put(pack(art.PLATFORM), 3)[1]
SONGS = music.songs()
songaddr = {k: put(lz.compress(v)) for k, v in SONGS.items()}
worlds = {}
for w in (1, 2, 3, 4, 5):
    worlds[w] = dict(tiles=put(lz.compress(tileset(w))), attrs=put(ATTRS), en=put(lz.compress(enemies(w))))
BOSSART = {1: (art2.BOSS1, art2.BOSS_ORDER), 2: (art2.BOSS2, art2.BOSS2_ORDER), 3: (art2.BOSS3, art2.BOSS3_ORDER),
           4: (art2.BOSS4, art2.BOSS4_ORDER), 5: (art2.BOSS5, art2.BOSS5_ORDER)}
bossraw = {k: put(lz.compress(b''.join(pack(d[n]) for n in o))) for k, (d, o) in BOSSART.items()}
mapcache = {}
for i, L in enumerate(LV):
    key = L.get('src', i)
    if key not in mapcache:
        rm = lz.compress(rowmajor(L['map'], L['W']))
        L['rle'] = len(rm)
        mapcache[key] = (put(rm), put(L['ents']))
    else:
        L['rle'] = 0
    L['mapp'], L['entp'] = mapcache[key]
for i, L in enumerate(LV):
    W = worlds[L['world']]
    sb = SONGS[L['song']]
    flags = (1 if L['boss'] else 0) | (2 if L.get('mirror') else 0)
    rec = struct.pack('<BBHHBB', L['world'], flags, L['W'], L['start'][0], L['start'][1], L['boss'])
    rec += struct.pack('<BH', *L['mapp'])
    rec += struct.pack('<BHH', *L['entp'], len(L['ents']))
    rec += struct.pack('<BHH', *songaddr[L['song']], len(sb))
    rec += struct.pack('<BH', *W['tiles'])
    rec += struct.pack('<BH', *W['attrs'])
    rec += struct.pack('<BH', *W['en'])
    rec += struct.pack('<BH', *bossraw.get(L['boss'], bossraw[1]))
    assert len(rec) <= LVSIZE, len(rec)
    rec += bytes(LVSIZE - len(rec))
    blobs[3][i * LVSIZE:(i + 1) * LVSIZE] = rec
blob = blobs[3]
open(os.path.join(OUT, 'bank3.bin'), 'wb').write(blobs[3])
open(os.path.join(OUT, 'bank5x.bin'), 'wb').write(blobs[5])

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
    f.write(f'LVTAB equ {tab:#06x}\nLVSIZE equ {LVSIZE}\nNLEVELS equ {len(LV)}\n')
    f.write(f'PLAYER_RAW equ {player_raw:#06x}\nPLAT_RAW equ {plat_raw:#06x}\n')
    f.write(f'BANK3_SIZE equ {len(blobs[3])}\nBANK5X_SIZE equ {len(blobs[5])}\nB5BASE equ {B5BASE:#06x}\n')
print('bank3', len(blobs[3]), 'of', 0x27F0, 'upper', len(blobs[5]), 'of', 0xFFF0-B5BASE, 'bytes;', ', '.join(f"L{i}: W={L['W']} rle={L['rle']}" for i, L in enumerate(LV)))

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
