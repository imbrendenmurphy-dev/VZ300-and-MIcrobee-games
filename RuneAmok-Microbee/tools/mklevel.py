"""RUNE AMOK level blocks (used by mkdata.py): tiles, sprites, the level
definition, actions and texts, and a check that each level can be
finished."""
import struct
import views as V
import walls as W
import tiles as T
import sprites as S
import levels as LV
from mkdata import KINDS, SPRITE_BASE, colsets


def off(x, y):
    return (y + 8) * 32 + x + 8


def sprite_ids_for(L):
    ids = set()
    used = set(''.join(L['map']))
    for ch, nm in (('>', 'F_stairs'), ('<', 'F_upstair'), ('O', 'F_pit'), ('_', 'F_plate'), ('*', 'F_portal')):
        if ch in used:
            ids.add(S.IDS[nm])
    for it in {i[2] for i in L['items']} | {LV.GOLD}:
        ids.add(S.IDS['I_' + S.ITEMS[it - 1][0]])
    for d in L['decor']:
        nm = d[4]
        ids.add(S.IDS['D_' + nm])
        if nm.startswith('lever'):
            ids |= {S.IDS['D_lever_up'], S.IDS['D_lever_dn']}
        if nm.startswith('rune'):
            ids.add(S.IDS['D_' + nm] + 1)
        if nm == 'button':
            ids.add(S.IDS['D_button_in'])
    for m in {m[2] for m in L['mons']}:
        nm = LV.MON_SPRITE[m]
        ids.add(S.IDS['M_' + nm])
        if m != LV.TRADER:
            ids.add(S.IDS['A_' + nm])
    ids.add(S.IDS['X_fireball'])
    ids.add(S.IDS['X_slash'])
    # every decoration also on the side walls
    ids |= {S.IDS['S_' + S.CAT[i][0][2:]] for i in list(ids) if S.CAT[i][1] == 'decor'}
    return ids


NB = ((0, -1), (1, 0), (0, 1), (-1, 0))


def solve(L, n):
    """can the level be finished? keys, levers, buttons, runes, portals"""
    m = [list(r) for r in L['map']]
    for (x, y, t) in L['mons']:
        if t == LV.TRADER:
            m[y][x] = '#'          # the trader never moves
    if n == 0:
        pos = L['start'][:2]
    else:
        pos = [(x, y) for y in range(16) for x in range(16) if m[y][x] == '<'][0]
    keys = [0, 0, 0]
    sig = 0
    done_items, done_dec = set(), set()
    acts = list(L['actions'])
    tele = {(x, y): (t[1], t[2]) for (x, y, t) in L['triggers'] if not isinstance(t, list) and t[0] == 'tele'}
    runes = 0
    seen = set()
    for _ in range(80):
        seen = {pos}
        st = [pos]
        while st:
            x, y = st.pop()
            if (x, y) in tele and tele[(x, y)] not in seen:
                seen.add(tele[(x, y)])
                st.append(tele[(x, y)])
            for dx, dy in NB:
                nx, ny = x + dx, y + dy
                if (nx, ny) in seen:
                    continue
                if m[ny][nx] in '.S<>_*@ID':
                    seen.add((nx, ny))
                    st.append((nx, ny))
        changed = False
        for (x, y, it) in L['items']:
            if (x, y) in seen and (x, y) not in done_items:
                done_items.add((x, y))
                changed = True
                if it in (LV.KEY1, LV.KEY2, LV.KEY3):
                    keys[it - LV.KEY1] += 1
                if it == LV.SIGIL:
                    sig += 1
        for y in range(16):
            for x in range(16):
                ch = m[y][x]
                near = any((x + dx, y + dy) in seen for dx, dy in NB)
                if ch in '123' and keys[int(ch) - 1] > 0 and near:
                    keys[int(ch) - 1] -= 1
                    m[y][x] = '.'
                    changed = True
                if ch == 'V' and n == 3 and near:
                    m[y][x] = '.'
                    changed = True
        for k, d in enumerate(L['decor']):
            x, y, side, kind, nm, param, extra = d
            dx, dy = NB[side]
            if (x + dx, y + dy) in seen and k not in done_dec:
                if kind in (LV.D_LEVER, LV.D_BUTTON):
                    done_dec.add(k)
                    for op in acts[param]:
                        if op[0] in ('open', 'toggle'):
                            m[op[2]][op[1]] = '.'
                    changed = True
                if kind == LV.D_RUNE:
                    done_dec.add(k)
                    runes += 1
                    if runes == 4:
                        for op in acts[L['rune_action']]:
                            if op[0] == 'open':
                                m[op[2]][op[1]] = '.'
                    changed = True
        if not changed:
            break
    ok = True
    if n < 3:
        gx = [(x, y) for y in range(16) for x in range(16) if L['map'][y][x] == '>']
        if not all(g in seen for g in gx):
            print('  level %d: stairs down NOT reachable' % (n + 1))
            ok = False
        if sig < 1:
            print('  level %d: sigil NOT reachable' % (n + 1))
            ok = False
    else:
        k = [(x, y) for (x, y, t) in L['mons'] if t == LV.KING][0]
        if k not in seen:
            print('  level 4: the king NOT reachable')
            ok = False
        # ...and only through the seal
        m2 = [list(r) for r in L['map']]
        st = [pos]
        seen2 = {pos}
        while st:
            x, y = st.pop()
            for dx, dy in NB:
                q = (x + dx, y + dy)
                if q not in seen2 and m2[q[1]][q[0]] in '.S<>_*@I':
                    seen2.add(q)
                    st.append(q)
        if k in seen2:
            print('  level 4: the king can be reached WITHOUT breaking the seal')
            ok = False
    lost = [(x, y, t) for (x, y, t) in L['items'] if (x, y) not in seen]
    if lost:
        print('  level %d: unreachable items %s' % (n + 1, lost))
    lostm = [(x, y, t) for (x, y, t) in L['mons'] if (x, y) not in seen]
    if lostm:
        print('  level %d: unreachable monsters %s' % (n + 1, lostm))
    return ok


def build_level(n, L):
    theme = W.THEMES[L['theme']]
    D = T.Dict()
    A = T.Blob()
    B = T.Blob()
    B.put(bytes(16))                     # header
    used = set(''.join(L['map']))
    kinds_used = 'AB' + ('D' if used & set('D123') else '') + ('G' if 'G' in used else '') + ('V' if 'V' in used else '')
    walltab = {}
    fl = W.floor_cells(theme)
    for k in KINDS:
        if k in kinds_used:
            walltab[k] = colsets(D, theme, k, B, fl)
    nwall = len(D.pats)
    # the backdrop as 24 full-height columns (for columns no wall fills)
    bdd = bytearray()
    for c in range(V.VW):
        tl = [D.tile(*fl.get((c, r), (bytes(10), 0))) for r in range(V.VH)]
        bdd += bytes([0, V.VH]) + bytes(t[0] for t in tl) + bytes(t[1] for t in tl) + bytes(t[2] for t in tl)
    bd = B.put(bytes(bdd))
    wt = B.here()
    for k in KINDS:
        for si, s in enumerate(V.SLOTS):
            p = walltab.get(k, walltab['A'])[si]
            if p is None:
                p = walltab['A'][si]
            B.put(struct.pack('<H', p))
    # sprites
    ids = sprite_ids_for(L)
    nbefore = len(D.pats)
    sprdata = {}
    for sid in sorted(ids):
        for dz in ((1, 3) if S.CAT[sid][1] == 'sdecor' else (1, 2, 3)):
            cells = S.render_sprite(S.CAT[sid], dz)
            if not cells:
                continue
            rec = bytearray([len(cells)])
            for (c, r, pat, col) in cells:
                t = D.tile(pat, col)
                rec += bytes([c, r, t[0], t[1], t[2]])
            sprdata[(sid, dz)] = bytes(rec)
    A.put(D.blob())
    assert A.here() <= SPRITE_BASE, 'glyphs overrun the sprite index'
    A.data += bytes(SPRITE_BASE - A.here())
    A.put(bytes(len(S.CAT) * 8))
    for (sid, dz), rec in sorted(sprdata.items()):
        a = A.put(rec)
        A.poke_w(SPRITE_BASE + sid * 8 + dz * 2, a)
    # the level definition
    ld = bytearray()
    sx, sy, sf = L['start']
    ld += bytes([sx, sy, sf])
    for row in L['map']:
        ld += bytes(LV.TYPES[ch] for ch in row)
    ld.append(len(L['items']))
    for x, y, it in L['items']:
        ld += struct.pack('<HB', off(x, y), it)
    ld.append(len(L['mons']))
    for x, y, t in L['mons']:
        ld += struct.pack('<HB', off(x, y), t)
    ld.append(len(L['decor']))
    acts = [list(a) for a in L['actions']]
    for (x, y, side, kind, nm, param, extra) in L['decor']:
        if kind == LV.D_RUNE:
            extra = L['rune_action']
        ld += struct.pack('<HBBBBBB', off(x, y), side, S.IDS['D_' + nm], kind, param, 0, extra)
    trig = []
    for (x, y, t) in L['triggers']:
        acts.append(list(t) if isinstance(t, list) else [t])
        trig.append((x, y, len(acts) - 1))
    ld.append(len(trig))
    for x, y, a in trig:
        ld += struct.pack('<HB', off(x, y), a)
    ldp = B.put(bytes(ld))
    # actions
    ab = bytearray()
    aptr = []
    for a in acts:
        aptr.append(len(ab))
        for op in a:
            if op[0] == 'open':
                ab += struct.pack('<BH', 1, off(op[1], op[2]))
            elif op[0] == 'toggle':
                ab += struct.pack('<BH', 2, off(op[1], op[2]))
            elif op[0] == 'msg':
                ab += bytes([3, op[1]])
            elif op[0] == 'tele':
                ab += struct.pack('<BHB', 4, off(op[1], op[2]), op[3])
            elif op[0] == 'hide':
                ab += struct.pack('<BH', 5, off(op[1], op[2]))
            elif op[0] == 'once':
                ab += bytes([6])
            elif op[0] == 'spawn':
                ab += struct.pack('<BHB', 7, off(op[1], op[2]), op[3])
        ab.append(0)
    abase = B.here() + 2 * max(1, len(acts))
    tab = b''.join(struct.pack('<H', abase + p) for p in aptr) or b'\0\0'
    atp = B.put(tab)
    B.put(bytes(ab))
    # texts
    tt = [t.encode('ascii') + b'\0' for t in L['texts']]
    tptr = []
    a = B.here() + 2 * len(tt)
    for t in tt:
        tptr.append(a)
        a += len(t)
        assert len(t) <= 128, t
    ttp = B.put(b''.join(struct.pack('<H', x) for x in tptr))
    B.put(b''.join(tt))
    B.poke_w(0, bd)
    B.poke_w(2, wt)
    B.poke_w(4, ldp)
    B.poke_w(6, len(D.pats))
    B.poke_w(8, atp)
    B.poke_w(10, ttp)
    print('level %d (%s): %d glyphs (walls+floor %d, sprites %d), A %d bytes, B %d bytes' % (
        n + 1, theme.name, len(D.pats), nwall, len(D.pats) - nbefore, A.here(), B.here()))
    assert len(D.pats) <= T.MAXG, 'too many glyphs'
    return A, B


def sprite_inc():
    L = ['; sprite ids (tools/sprites.py)']
    for nm, i in S.IDS.items():
        L.append('SP_%s EQU %d' % (nm.upper(), i))
    L.append('SP_STAIRS EQU %d' % S.IDS['F_stairs'])
    L.append('SP_UPSTAIR EQU %d' % S.IDS['F_upstair'])
    L.append('SP_PIT EQU %d' % S.IDS['F_pit'])
    L.append('SP_PLATE EQU %d' % S.IDS['F_plate'])
    L.append('SP_PORTAL EQU %d' % S.IDS['F_portal'])
    L.append('SP_ITEM1 EQU %d' % S.IDS['I_gold'])
    L.append('mon_spr:\t; idle sprite of each monster type (attack = +1)')
    L.append('\tdb ' + ','.join(str(S.IDS['M_' + nm]) for nm in LV.MON_SPRITE))
    assert S.IDS['D_lever_up'] % 2 == 0
    L.append('SDECOR EQU %d' % (S.IDS['S_lever_up'] - S.IDS['D_lever_up']))   # side-wall sprite = decor sprite + SDECOR
    return L
