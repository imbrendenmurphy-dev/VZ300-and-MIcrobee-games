"""STORMBELL: build everything into build/ (VIBED BY BPM 2026).

    python3 tools/build.py

1. font, HUD glyphs and the seven pictures -> GFX0.BNK, GFX1.BNK
2. the six fighters, sixteen frames each   -> F0.BNK .. F5.BNK, src/ftab.inc
3. music and sound tables                  -> src/snd.inc
4. the program (src/main.asm)              -> STORM.BIN
5. the CP/M loader (src/loader.asm)        -> STORM.COM
6. the disk                                -> STORM.DS8
"""
import os
import sys
import subprocess
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
BUILD = ROOT / 'build'
SRC = ROOT / 'src'
sys.path.insert(0, str(HERE))
BUILD.mkdir(exist_ok=True)

import art
import fighters as F
import music

BLK_FIGHT = 4            # fighters: blocks 4..9
BLK_GFX = 10             # font + pictures 0..5; block 11: picture 6
HERO_BANK = 5            # PCG banks 5..8  (512 glyphs)
FOE_BANK = 9             # PCG banks 9..15 (896 glyphs)
PIC_SLOT = 0x1C00
FR_BASE = 0x0100         # frame records
GL_BASE = 0x4000         # glyph records: 8 pattern bytes + 8 mask bytes


def dilate8(m):
    o = F.dilate(m)
    o[1:, 1:] |= m[:-1, :-1]
    o[1:, :-1] |= m[:-1, 1:]
    o[:-1, 1:] |= m[1:, :-1]
    o[:-1, :-1] |= m[1:, 1:]
    return o


def rowbytes(cell):
    return bytes(int(sum(128 >> x for x in range(8) if cell[y, x])) for y in range(8))


def pack_fighter(idx, f):
    mirror = idx > 0
    bank0 = FOE_BANK if mirror else HERO_BANK
    limit = (16 - FOE_BANK if mirror else FOE_BANK - HERO_BANK) * 128
    frs = F.frames(f, mirror)
    glyphs = {}
    recs = []
    info = {}
    anchor = F.CW - 1 - F.AC if mirror else F.AC
    for name, ink, col, jt in frs:
        mask = dilate8(ink)
        cc = F.cellcol(ink, col)
        cells = ink.reshape(F.CH, 8, F.CW, 8).any(axis=(1, 3))
        ys, xs = np.where(cells)
        x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
        w, h = x1 - x0 + 1, y1 - y0 + 1
        rec = bytearray([w, h, anchor - x0, y0])
        for cy in range(y0, y1 + 1):
            for cx in range(x0, x1 + 1):
                if not cells[cy, cx]:
                    rec += bytes([0, 0, 0])
                    continue
                key = rowbytes(ink[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8]) + rowbytes(mask[cy * 8:cy * 8 + 8, cx * 8:cx * 8 + 8])
                if key not in glyphs:
                    glyphs[key] = len(glyphs)
                g = glyphs[key]
                rec += bytes([0x80 | (g & 127), bank0 + (g >> 7), int(cc[cy, cx])])
        recs.append(bytes(rec))
        # how far this frame reaches towards the opponent, from the anchor cell's centre
        px = np.where(ink.any(axis=0))[0]
        ax = anchor * 8 + 4
        info[name] = (ax - px.min()) if mirror else (px.max() + 1 - ax)
    assert len(glyphs) <= limit, '%s: %d glyphs, room for %d' % (f.key, len(glyphs), limit)
    # the front of the body: the standing frame, from the hips up
    name, ink, col, jt = frs[F.NAMES.index('stand')]
    top = np.where(ink.any(axis=1))[0].min()
    body = ink[top:top + 36]
    px = np.where(body.any(axis=0))[0]
    ax = anchor * 8 + 4
    front = (ax - px.min()) if mirror else (px.max() + 1 - ax)
    blk = bytearray(0x8000)
    blk[0:2] = len(glyphs).to_bytes(2, 'little')
    blk[2] = info['punch']
    blk[3] = info['kick']
    blk[4] = front
    off = FR_BASE
    for i, r in enumerate(recs):
        blk[0x10 + i * 2:0x12 + i * 2] = off.to_bytes(2, 'little')
        blk[off:off + len(r)] = r
        off += len(r)
    assert off <= GL_BASE
    for key, g in glyphs.items():
        blk[GL_BASE + g * 16:GL_BASE + g * 16 + 16] = key
    used = GL_BASE + len(glyphs) * 16
    print('  %-8s %4d glyphs (room %d), frames %5d bytes, punch %2d px, kick %2d px, body %2d px' % (
        f.key, len(glyphs), limit, off - FR_BASE, info['punch'], info['kick'], front))
    return bytes(blk[:used]), dict(punch=info['punch'], kick=info['kick'], body=front)


def build_fighters():
    stats = []
    for i, f in enumerate(F.FIGHTERS):
        data, st = pack_fighter(i, f)
        (BUILD / ('F%d.BNK' % i)).write_bytes(data)
        stats.append(st)
    return stats


def build_gfx():
    """GFX0.BNK: the font (400h) then pictures 0..3; GFX1.BNK: 400h spare,
    then pictures 4..6. A picture slot: codes, banks, colours (1000 each),
    the glyph count, then 512 x 8 bytes of glyphs."""
    blks = [bytearray(art.font_bytes()), bytearray(0x400)]
    for i, (name, fn) in enumerate(art.PICS):
        codes, banks, cols, gl, n = fn().pack(name)
        rec = codes + banks + cols + bytes([n & 255, n >> 8]) + bytes(6) + gl
        assert len(rec) <= PIC_SLOT
        rec += bytes(PIC_SLOT - len(rec))
        blks[i // 4] += rec
        print('  picture %-7s %3d glyphs' % (name, n))
    for k, b in enumerate(blks):
        assert len(b) <= 0x8000
        (BUILD / ('GFX%d.BNK' % k)).write_bytes(bytes(b))


def tables(stats):
    """names, hints and ranges for the game (src/ftab.inc)"""
    L = ['; generated by tools/build.py', 'F_FRAMES equ %d' % len(F.POSES)]
    for i, n in enumerate(F.NAMES):
        L.append('FR_%s equ %d' % (n.upper(), i))
    hero = stats[0]
    L.append('; ranges in cells: an attack lands when the fighters are this close')
    L.append('rangetab:')
    for i, st in enumerate(stats[1:], 1):
        # hero's punch and kick against this body; this foe's against the hero's
        hp = (hero['punch'] + st['body'] + 3) // 8
        hk = (hero['kick'] + st['body'] + 3) // 8
        fp = (st['punch'] + hero['body'] + 3) // 8
        fk = (st['kick'] + hero['body'] + 3) // 8
        L.append('\tdb %d,%d,%d,%d\t; %s' % (hp, hk, fp, fk, F.FIGHTERS[i].key))
        print('  ranges vs %-8s hero punch %d kick %d, foe punch %d kick %d' % (F.FIGHTERS[i].key, hp, hk, fp, fk))
    L.append('nametab:')
    for i, f in enumerate(F.FIGHTERS):
        L.append('\tdw name%d' % i)
    for i, f in enumerate(F.FIGHTERS):
        L.append('name%d:\tdb "%s",0' % (i, f.name))
    L.append('hinttab:')
    for i, f in enumerate(F.FIGHTERS[1:], 1):
        L.append('\tdw hint%da,hint%db' % (i, i))
    for i, f in enumerate(F.FIGHTERS[1:], 1):
        L.append('hint%da:\tdb "%s",0' % (i, f.hint[0]))
        L.append('hint%db:\tdb "%s",0' % (i, f.hint[1]))
    L.append('stagetab:')
    for i, n in enumerate(art.STAGE_NAMES):
        L.append('\tdw stage%d' % i)
    for i, n in enumerate(art.STAGE_NAMES):
        L.append('stage%d:\tdb "%s",0' % (i, n))
    (SRC / 'ftab.inc').write_text('\n'.join(L) + '\n')


def loadfiles():
    names = [('STG_PROG', 0, 'STORM', 'BIN')]
    for i in range(len(F.FIGHTERS)):
        names.append((BLK_FIGHT + i, 0, 'F%d' % i, 'BNK'))
    names.append((BLK_GFX, 0, 'GFX0', 'BNK'))
    names.append((BLK_GFX + 1, 0, 'GFX1', 'BNK'))
    for b, o, n, e in names:
        assert b == 'STG_PROG' or 4 <= b <= 22, b      # the blocks proven safe while CP/M is alive
    lines = ['\tDB %s, $%02X, "%-8s%s"' % (b, o, n, e) for b, o, n, e in names]
    (SRC / 'loadfiles.inc').write_text('\n'.join(lines) + '\n')
    return names


def assemble():
    zasm = str(HERE / 'zasm.py')
    subprocess.check_call([sys.executable, zasm, 'main.asm', '--sym=../build/main.sym'], cwd=SRC)
    sz = (BUILD / 'STORM.BIN').stat().st_size
    plen = (sz + 255) // 256 * 256
    (SRC / 'proglen.inc').write_text('PROG_LEN    EQU $%04X\n' % plen)
    print('STORM.BIN %d bytes (8000h-%04Xh)' % (sz, 0x8000 + sz))
    subprocess.check_call([sys.executable, zasm, 'loader.asm', '--sym=../build/loader.sym'], cwd=SRC)


def disk(names):
    import build_disk as BD
    sysdisk = (ROOT / 'resources' / 'boot_tracks.bin').read_bytes()
    files = {'STORM.COM': (BUILD / 'STORM.COM').read_bytes()}
    for b, o, n, e in names:
        files['%s.%s' % (n, e)] = (BUILD / ('%s.%s' % (n, e))).read_bytes()
    files['CCP.SYS'] = (ROOT / 'resources' / 'CCP.SYS').read_bytes()
    readme = ROOT / 'docs' / 'DISK_README.TXT'
    files['README.TXT'] = readme.read_text().replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii') + b'\x1a'
    used = BD.build_disk(sysdisk, files, BUILD / 'STORM.DS8')
    # read the image back and check every file
    back = BD.read_dir(BD.unskew((BUILD / 'STORM.DS8').read_bytes()))
    for n, d in files.items():
        assert back[n][:len(d)] == d, n
    print('STORM.DS8: %d of 196 blocks used, %d files, read back and checked' % (used, len(files)))


if __name__ == '__main__':
    print('pictures')
    build_gfx()
    print('fighters')
    stats = build_fighters()
    tables(stats)
    music.build(SRC / 'snd.inc')
    names = loadfiles()
    if '--art' not in sys.argv:
        assemble()
        disk(names)
