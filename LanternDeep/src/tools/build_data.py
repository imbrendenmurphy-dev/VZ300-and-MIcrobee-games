"""Compile the world into Z80 data.

Outputs
  build/GFX.BNK    16K: PCG library for the game, 16 banks x 128 glyphs x 8 rows
  build/WORLD.BNK  room maps (FLAGS/TILE/STAT, 24x128 each) + 4 torch trees
  src/gen/tables.asm   tile descriptors, light ramps, animation list, zone
                       reveal lists, spawn list, sprite glyph ids, constants
"""
import math
from pathlib import Path
import numpy as np

import art
import world as W

ROOT = Path(__file__).resolve().parent.parent
GEN = ROOT / 'src' / 'gen'
BUILD = ROOT / 'build'
GEN.mkdir(parents=True, exist_ok=True)
BUILD.mkdir(exist_ok=True)

# ---------------------------------------------------------------- memory map (must match src/layout.inc)
STRIDE = 128
ARR = 0x0C00
FLAGS_BASE = 0xC000
TREEBUF = 0xCD00          # torch tree work buffer (upper memory)
TREEMAX = 0x0F00
WORLD_BANK_TREES = 0x2400  # offset of trees inside WORLD.BNK
SPECIAL_REGION = 0x7000    # 3K of $FF in the WORLD bank (cast markers)
SPECIAL_OFS = (SPECIAL_REGION - 0xC000) & 0xFFFF
F_OPAQUE, F_EDGE, F_FACE, F_SOLID, F_CYCLE, F_QUEUED, F_REVEAL, F_SEEN = (1 << i for i in range(8))

SPRITE_BANK = 14
FONT_BANK = 15


def cellptr(base, x, y):
    return base + (y + 1) * STRIDE + (x + 1)


class PCG:
    def __init__(self):
        self.banks = [[None] * 128 for _ in range(16)]
        self.index = [dict() for _ in range(16)]
        self.next = [0] * 16

    def put(self, bank, g, unique=False):
        if not unique and g in self.index[bank]:
            return self.index[bank][g]
        s = self.next[bank]
        assert s < 128, 'PCG bank %d full' % bank
        self.banks[bank][s] = g
        self.next[bank] += 1
        if not unique:
            self.index[bank][g] = s
        return s

    def free(self, bank):
        return 128 - self.next[bank]

    def blob(self):
        out = bytearray()
        for b in range(16):
            for s in range(128):
                out += bytes(self.banks[b][s] or art.EMPTY)
        return out


def asm_bytes(label, data, per=16):
    lines = [label + ':'] if label else []
    for i in range(0, len(data), per):
        lines.append('    DB ' + ','.join('$%02X' % b for b in data[i:i + per]))
    return '\n'.join(lines)


def asm_words(label, data, per=8):
    lines = [label + ':'] if label else []
    for i in range(0, len(data), per):
        lines.append('    DW ' + ','.join('$%04X' % (w & 0xFFFF) for w in data[i:i + per]))
    return '\n'.join(lines)


def main():
    room = W.build_showcase()
    ts, tm = W.build_tiles(room)
    pcg = PCG()
    out = []
    eq = []

    # ---------------- font + HUD (bank 15)
    for i in range(64):
        ch = chr(0x20 + i)
        g = art.font_glyph(ch) if ch in art.FONT_ROWS else art.EMPTY
        pcg.put(FONT_BANK, g, unique=True)
    hud_ids = {}
    for name, g in art.HUD.items():
        hud_ids[name] = pcg.put(FONT_BANK, g, unique=True)
    for name, s in hud_ids.items():
        eq.append('G_%s EQU $%02X' % (name.upper(), 0x80 | s))

    # ---------------- sprites (bank 14)
    spr = {}
    for name, g in art.PLAYER.items():
        spr['P_' + name] = pcg.put(SPRITE_BANK, g, unique=True)
    for i, g in enumerate(art.BAT):
        spr['BAT%d' % i] = pcg.put(SPRITE_BANK, g, unique=True)
    for i, g in enumerate(art.BEETLE):
        spr['BEETLE%d' % i] = pcg.put(SPRITE_BANK, g, unique=True)
    for i, g in enumerate(art.SKELETON):
        spr['SKEL%d' % i] = pcg.put(SPRITE_BANK, g, unique=True)
    for k in ('h', 'v'):
        for i, g in enumerate(art.SLASH[k]):
            spr['SL%s%d' % (k.upper(), i)] = pcg.put(SPRITE_BANK, g, unique=True)
            # mirrored arcs for left / up
            gm = art.g_flip_h(g) if k == 'h' else art.g_flip_v(g)
            spr['SL%sM%d' % (k.upper(), i)] = pcg.put(SPRITE_BANK, gm, unique=True)
    for name, g in art.FX.items():
        spr['FX_' + name.upper()] = pcg.put(SPRITE_BANK, g, unique=True)
    for name, s in spr.items():
        eq.append('S_%s EQU $%02X' % (name.upper(), 0x80 | s))
    eq.append('SPRITE_BANK EQU %d' % SPRITE_BANK)
    eq.append('FONT_BANK EQU %d' % FONT_BANK)

    # ---------------- tiles: 4 light variants per tile in one bank
    tiles = ts.tiles
    assert len(tiles) <= 255, len(tiles)
    td_chr = [[0x80] * 256 for _ in range(4)]
    td_bank = [FONT_BANK] * 256
    td_ramp = [0] * 256
    anims = []          # (bank, slot, [frames...], period)
    bank = 0
    for ti, t in enumerate(tiles):
        t.index = ti
        need = 4 if t.frames else len({art.variant(t.glyph, v) for v in range(4)} - set(pcg.index[bank]))
        if pcg.free(bank) < need:
            bank += 1
            assert bank < SPRITE_BANK, 'out of tile banks'
        for v in range(4):
            if t.frames:
                s = pcg.put(bank, art.variant(t.frames[0], v), unique=True)
                period = {'water': 8, 'crystal': 10, 'flame': 4, 'puddle': 9}[[k for k in ('water', 'crystal', 'flame', 'puddle') if t.name.startswith(k)][0]]
                anims.append((bank, s, [art.variant(f, v) for f in t.frames], period))
            else:
                s = pcg.put(bank, art.variant(t.glyph, v))
            td_chr[v][ti] = 0x80 | s
        td_bank[ti] = bank
        td_ramp[ti] = W.RAMP_IDS[t.ramp]
    eq.append('TILE_BANKS_USED EQU %d' % (bank + 1))
    print('tiles %d, tile banks %d, free in last %d' % (len(tiles), bank + 1, pcg.free(bank)))

    # ---------------- ramps: (ramp*4+tint)*8+level -> (variant, colour)
    ramptab = bytearray(1024)
    for name, rid in W.RAMP_IDS.items():
        for ti, tint in enumerate(W.TINTS):
            for lv in range(8):
                var, fg, bg = W.RAMPS[name][tint][lv]
                o = ((rid * 4 + ti) * 8 + lv) * 2
                ramptab[o] = var
                ramptab[o + 1] = fg | (bg << 4)
    # colour-cycle table (runes): 8 phases
    cyc = W.CYCLE['rune'] + W.CYCLE['rune'][:2]
    cyctab = bytearray()
    for var, fg, bg in cyc[:8]:
        cyctab += bytes([var, fg | (bg << 4)])

    # ---------------- room maps
    flags = np.zeros((24, STRIDE), dtype=np.uint8)
    tilem = np.zeros((24, STRIDE), dtype=np.uint8)
    stat = np.zeros((24, STRIDE), dtype=np.uint8)
    flags[:, :] = F_EDGE | F_OPAQUE | F_SOLID
    tilem[:, :] = 0xFF
    slv, stint = W.static_light(room, tm)
    cyclers = []
    for y in range(W.ROWS):
        for x in range(W.COLS):
            t = tm[y][x]
            f = 0
            if t.opaque:
                f |= F_OPAQUE
            if t.solid:
                f |= F_SOLID
            if t.face_lo:
                f |= F_FACE
            if t.cycle:
                f |= F_CYCLE
                cyclers.append(cellptr(FLAGS_BASE, x, y))
            flags[y + 1, x + 1] = f
            tilem[y + 1, x + 1] = t.index
            stat[y + 1, x + 1] = (slv[y, x] & 7) | ((stint[y, x] & 3) << 3) | ((room.zone[y, x] & 7) << 5)
    roomblob = flags.tobytes() + tilem.tobytes() + stat.tobytes()
    assert len(roomblob) == 3 * ARR

    # ---------------- ray-trees, cast in place from the WORLD bank (lower window)
    view = W.View(room, ts, tm)
    omni = W.LightTree(W.static_intensity(6, 3.4), 7, 4)
    trees = bytearray()
    tree_offs = []
    max_cells = 0
    for name, tr in (('up', view.trees['up']), ('down', view.trees['down']), ('left', view.trees['left']),
                     ('right', view.trees['right']), ('omni', omni)):
        base = WORLD_BANK_TREES + len(trees)
        nodes = tr.nodes
        # Node = DW offset, DW skip pointer, DB 0, DB $80|level (read with
        # POP HL / POP DE / POP AF). A timing checkpoint every 40 nodes and
        # the end marker are nodes whose offset lands in the all-$FF region
        # of the WORLD bank: they take the (rare) edge path, where the engine
        # tells them apart. Checkpoint: skip = next node. End: skip = 0.
        seq = []
        newidx = {}
        for i, nd in enumerate(nodes):
            if i and i % 40 == 0:
                seq.append(None)
            newidx[i] = len(seq)
            seq.append(nd)
        newidx[len(nodes)] = len(seq)
        blob = bytearray()
        for k, nd in enumerate(seq):
            if nd is None:
                blob += (SPECIAL_OFS).to_bytes(2, 'little') + (base + (k + 1) * 6).to_bytes(2, 'little') + bytes([0, 0x80])
                continue
            dx, dy, lv, fl, skip = nd
            off = dy * STRIDE + dx
            blob += (off & 0xFFFF).to_bytes(2, 'little')
            blob += (base + newidx[skip] * 6).to_bytes(2, 'little')
            blob += bytes([0, 0x80 | lv])
        blob += (SPECIAL_OFS).to_bytes(2, 'little') + bytes([0, 0, 0, 0x80])
        tree_offs.append((name, base, len(blob)))
        trees += blob
        max_cells = max(max_cells, len({(n[0], n[1]) for n in nodes}))
    print('max unique cells in a tree', max_cells)
    assert max_cells + 120 < 760
    worldblob = roomblob + bytes(WORLD_BANK_TREES - len(roomblob)) + trees
    assert len(worldblob) <= SPECIAL_REGION
    worldblob += bytes(SPECIAL_REGION - len(worldblob)) + b'\xFF' * 0x0C00
    (BUILD / 'WORLD.BNK').write_bytes(worldblob)

    # ---------------- zone reveal lists (cells with static light, sorted from the entrance)
    entries = {1: (2, 10), 2: (36, 10)}
    zone_lists = {}
    for z, (ex, ey) in entries.items():
        cells = [(x, y) for y in range(W.ROWS) for x in range(W.COLS) if room.zone[y, x] == z and slv[y, x] > 0]
        cells.sort(key=lambda c: math.hypot((c[0] - ex) * W.ASPECT, c[1] - ey))
        zone_lists[z] = [cellptr(FLAGS_BASE, x, y) for (x, y) in cells]

    # ---------------- animation list: DB bank, slot, nframes, period ; DW frames
    anim_lines = ['ANIM_LIST:']
    frame_lines = []
    for i, (b, s, frames, period) in enumerate(anims):
        anim_lines.append('    DB %d,$%02X,%d,%d\n    DW anim_f%d' % (b, s, len(frames), period, i))
        frame_lines.append(asm_bytes('anim_f%d' % i, b''.join(bytes(f) for f in frames)))
    anim_lines.append('    DB $FF')

    # ---------------- groups (multi-cell opaque pieces lit as one)
    group_lines = ['GROUP_LIST:']
    for cells in room.groups:
        group_lines.append('    DB %d' % len(cells))
        group_lines.append('    DW ' + ','.join('$%04X' % cellptr(FLAGS_BASE, x, y) for (x, y) in cells))
    group_lines.append('    DB 0')

    # ---------------- write tables.asm
    tab = ['; generated by tools/build_data.py - do not edit', '']
    tab += eq
    tab.append('ROOM_BYTES EQU $%04X' % len(roomblob))
    tab.append('SPECIAL_H EQU $%02X' % (SPECIAL_REGION >> 8))
    for (name, o, n) in tree_offs:
        tab.append('TREE_%s EQU $%04X' % (name.upper(), o))
    tab.append('N_ANIMS EQU %d' % len(anims))
    tab.append('')
    tab.append('    ALIGN 256')
    for v in range(4):
        tab.append(asm_bytes('TD_CHR%d' % v, bytes(td_chr[v])))
    tab.append(asm_bytes('TD_BANK', bytes(td_bank)))
    tab.append(asm_bytes('TD_RAMP', bytes(td_ramp)))
    # ramp entry for tile t, light key k: RAMPTAB + ramp*64 + k*2 =
    # (TD_RH[t] << 8) | (TD_RL[t] + k*2)
    tab.append(asm_bytes('TD_RL', bytes(((r & 3) << 6) for r in td_ramp)))
    tab.append('TD_RH:')
    tab.append('    DB ' + '\n    DB '.join(','.join('RAMPTAB/256+%d' % (r >> 2) for r in td_ramp[i:i + 16]) for i in range(0, 256, 16)))
    tab.append(asm_bytes('RAMPTAB', ramptab))
    tab.append(asm_bytes('CYCTAB', cyctab))
    tab.append('')
    tab += anim_lines
    tab += frame_lines
    tab += group_lines
    tab.append(asm_words('CYCLER_LIST', cyclers + [0]))
    for z, lst in zone_lists.items():
        tab.append(asm_words('ZONE%d_LIST' % z, lst + [0]))
    tab.append('ZONE_LISTS: DW 0,ZONE1_LIST,ZONE2_LIST,0,0,0,0,0')
    (GEN / 'tables.asm').write_text('\n'.join(tab) + '\n')
    (BUILD / 'GFX.BNK').write_bytes(pcg.blob())

    # spawn & room constants for the engine
    sp = ['; generated - room 0 spawn data']
    sp.append('START_CELL EQU $%04X' % cellptr(FLAGS_BASE, 2, 10))
    objs = {k: (x, y) for (k, x, y) in room.objects if k in ('chest', 'tablet')}
    sp.append('CHEST_CELL EQU $%04X' % cellptr(FLAGS_BASE, *objs['chest']))
    sp.append('TABLET_CELL EQU $%04X' % cellptr(FLAGS_BASE, *objs['tablet']))
    sp.append('T_CHEST_OPEN EQU %d' % room.chest_open.index)
    cr = [t.index for t in tiles if t.name.startswith('crystal')]
    sp.append('T_CRYSTAL_LO EQU %d\nT_CRYSTAL_HI EQU %d' % (min(cr), max(cr)))
    water = [cellptr(FLAGS_BASE, x, y) for y in range(W.ROWS) for x in range(W.COLS) if room.sem[y][x] == '~']
    sp.append(asm_words('WATER_LIST', water))
    sp.append('N_WATER EQU %d' % len(water))
    flames = [cellptr(FLAGS_BASE, x, y) for y in range(W.ROWS) for x in range(W.COLS) if tm[y][x].name == 'flame']
    sp.append(asm_words('FLAME_LIST', flames + [0]))
    # enemies: type, cell
    spawns = [(2, 50, 8), (2, 68, 9), (3, 62, 19), (11, 12, 9), (11, 29, 11)]
    sp.append('SPAWN_LIST:')
    for (t, x, y) in spawns:
        sp.append('    DB %d\n    DW $%04X\n    DB %d,%d' % (t, cellptr(FLAGS_BASE, x, y), x, y))
    sp.append('    DB 0')
    (GEN / 'room.asm').write_text('\n'.join(sp) + '\n')
    print('anims %d, groups %d, zone lists %s, trees %s' % (len(anims), len(room.groups),
          {z: len(v) for z, v in zone_lists.items()}, tree_offs))
    print('pcg used per bank', pcg.next)
    return room, ts, tm


if __name__ == '__main__':
    main()
