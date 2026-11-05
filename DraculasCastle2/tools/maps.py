# maps.py - castle maps, events and exits for the vertical slice
# Cell byte: bits0-2 type (0 floor,1 wallA,2 wallB,3 door,4 secret,5 exit), bits3-7 param
from collections import deque

# event types
EV_SIGN, EV_CHEST, EV_NPC, EV_SCRIPT, EV_SHRINE, EV_STEP, EV_BOSS, EV_ITEM, EV_PLAQUE = 1, 2, 3, 4, 5, 6, 7, 8, 9
# items
IT_POTION, IT_HOLY, IT_IRONKEY, IT_DAGGER, IT_FIRE, IT_CRYPTKEY, IT_ELIXIR, IT_SWORD, IT_CLOAK = 1, 2, 3, 4, 5, 6, 7, 8, 9

AREA_MAPS = {}

# --------------------------------------------------------------------------
# AREA 0 : THE CASTLE GROUNDS (hedge maze, graveyard, courtyard)
#   decors (area.py): 1 gate, 2 door, 3 stairs, 4 torch
#   objects: 1 bones, 2 grave, 3 keeper, 4 chest, 5 chest_open, 6 angel
# --------------------------------------------------------------------------
AREA_MAPS[0] = dict(
    name='THE GROUNDS',
    rows=[
        "%%%%%%%%%%%%%%%%",
        "%%%%%%T%X%T%%%%%",
        "%%.............%",
        "%%.%%%%%.%####.%",
        "%%.%a.c%.%#....%",
        "%%.%...%.%#.##.%",
        "%%.%d..%.%#.b#.%",
        "%%.%%%.%.%####.%",
        "%%.....%.......%",
        "%%%%%%.%.%#S####",
        "%%g....%.%#.####",
        "%%%%%%%..%#e####",
        "%%%%%%%.f.%%%%%%",
        "%%%%%%%...%%%%%%",
        "%%%%%%%%.%%%%%%%",
        "%%%%%%%%G%%%%%%%",
    ],
    legend={'#': (1, 0), '%': (2, 0), '.': (0, 0), 'T': (2, 3), 'G': (2, 1), 'S': ('secret', 0)},
    door_decor=2, door_kind=2,
    exits={'X': dict(area=1, x=8, y=13, dir=0, decor=2, kind=2, lock=IT_IRONKEY)},
    events={
        'a': dict(obj=1, type=EV_SCRIPT, args=[2, 1, IT_IRONKEY, 'BONES']),      # skeleton rises -> iron key
        'b': dict(obj=4, type=EV_CHEST, args=[IT_POTION, 2, 0, 0]),
        'c': dict(obj=2, type=EV_SIGN, args=['GRAVE1', 0, 0, 0]),                # grave of Wilhelm
        'd': dict(obj=2, type=EV_SIGN, args=['GRAVE2', 0, 0, 0]),                # grave (joke)
        'e': dict(obj=6, type=EV_SHRINE, args=[0, 0, 0, 0]),              # stone angel save point (secret garden)
        'f': dict(obj=3, type=EV_NPC, args=['GRIGOR1', IT_POTION, 2, 'GRIGOR2']),         # groundskeeper Grigor
        'g': dict(obj=4, type=EV_CHEST, args=[IT_HOLY, 2, 0, 0]),
    },
    start=(8, 14, 0),
    css=0, music=1, encounters=[1, 1, 2], rate=22, intro='INTRO0',
)

# --------------------------------------------------------------------------
# AREA 1 : THE ENTRANCE HALL
#   decors: 1 door, 2 torch, 3 portrait, 4 window, 5 stairs, 6 plaque
#   objects: 1 armour, 2 chest, 3 chest_open, 4 angel, 5 bones
# --------------------------------------------------------------------------
AREA_MAPS[1] = dict(
    name='GREAT HALL',
    rows=[
        "################",
        "#%%%%%%%U%%MP%%#",
        "#%%P%%%T.T%..%%#",
        "#W.h.%%RiR%%Q.%#",
        "#%.%%%R...R%%.W#",
        "#%.%j.P...P%%.%#",
        "#%.e%.R...Rg%.%#",
        "#%....T...T...W#",
        "#%.P%%R...R%%.%#",
        "#W.%%%P...W%%.%#",
        "#%.%%%R...R%%.W#",
        "#%....D...D...%#",
        "#%%%%%Ra.aR%%%%#",
        "#%%%%%%T.T%%%%%#",
        "#%%%%%%%Y%%%%%%#",
        "################",
    ],
    legend={'#': (1, 0), '%': (1, 0), 'R': (2, 0), '.': (0, 0), 'T': (2, 2), 't': (1, 2), 'P': (2, 3), 'W': (1, 4), 'Q': ('secret', 0)},
    door_decor=1, door_kind=1,
    exits={'Y': dict(area=0, x=8, y=2, dir=2, decor=1, kind=2, lock=0),
           'U': dict(area=98, x=0, y=0, dir=0, decor=1, kind=2, lock=0),
           'M': dict(area=99, x=0, y=0, dir=0, decor=5, kind=2, lock=0)},
    events={
        'a': dict(obj=1, type=EV_SIGN, args=['ARMOUR1', 0, 0, 0]),                  # suits of armour
        'g': dict(obj=1, type=EV_SIGN, args=['ARMOUR2', 0, 0, 0]),
        'h': dict(obj=2, type=EV_CHEST, args=[IT_FIRE, 1, 0, 0]),           # FIRE scroll
        'j': dict(obj=2, type=EV_CHEST, args=[IT_DAGGER, 1, 0, 0]),         # silver dagger
        'i': dict(obj=6, type=EV_BOSS, args=[4, 2, 0, 'GARGOYLE']),                  # gargoyle boss
        'e': dict(obj=4, type=EV_SHRINE, args=[0, 0, 0, 0]),
    },
    start=(8, 13, 0),
    css=0, music=2, encounters=[3, 1, 3], rate=20, intro='INTRO1',
)

CHARS = {}
def compile_area(ai):
    A = AREA_MAPS[ai]
    rows = A['rows']; assert len(rows) == 16 and all(len(r) == 16 for r in rows), [len(r) for r in rows]
    cells = bytearray(256)
    events = []; evmap = {}
    exits = []; exmap = {}
    for y in range(16):
        for x in range(16):
            ch = rows[y][x]
            if ch in A['legend']:
                t, p = A['legend'][ch]
                if t == 'secret': cells[y * 16 + x] = 4 | (p << 3)
                else: cells[y * 16 + x] = t | (p << 3)
            elif ch == 'D': cells[y * 16 + x] = 3
            elif ch == 'K': cells[y * 16 + x] = 3 | (IT_IRONKEY << 3)
            elif ch in A['exits']:
                if ch not in exmap:
                    exmap[ch] = len(exits); exits.append(A['exits'][ch])
                cells[y * 16 + x] = 5 | (exmap[ch] << 3)
            elif ch in A['events']:
                if ch not in evmap:
                    evmap[ch] = len(events) + 1; events.append(A['events'][ch])
                cells[y * 16 + x] = 0 | (evmap[ch] << 3)
            else:
                raise ValueError('area %d: unknown map char %r at %d,%d' % (ai, ch, x, y))
    return cells, events, exits

def check(ai):
    cells, events, exits = compile_area(ai)
    A = AREA_MAPS[ai]
    sx, sy, sd = A['start']
    seen = set(); q = deque([(sx, sy)])
    while q:
        x, y = q.popleft()
        if (x, y) in seen: continue
        seen.add((x, y))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < 16 and 0 <= ny < 16): continue
            c = cells[ny * 16 + nx]; t = c & 7
            if t == 0 and (c >> 3) == 0: q.append((nx, ny))
            elif t in (3, 4): q.append((nx, ny))
            elif t == 0:
                ev = events[(c >> 3) - 1]
                if ev['type'] in (EV_STEP, EV_BOSS, EV_PLAQUE): q.append((nx, ny))
    return seen

if __name__ == '__main__':
    for ai in AREA_MAPS:
        seen = check(ai)
        cells, ev, ex = compile_area(ai)
        A = AREA_MAPS[ai]
        print(A['name'], 'reachable', len(seen), 'events', len(ev), 'exits', len(ex))
        for y in range(16):
            print(''.join(('@' if (x, y) == A['start'][:2] else ('o' if (x, y) in seen else A['rows'][y][x])) for x in range(16)))

def asm():
    from texts import TEXT_IDS
    from lz2 import compress_opt as lz_compress
    out = ['; generated maps']
    flag = 0
    for ai in sorted(AREA_MAPS):
        A = AREA_MAPS[ai]
        cells, events, exits = compile_area(ai)
        out.append('map%d_lz: db %s' % (ai, ','.join(map(str, lz_compress(cells)))))
        out.append('events%d:' % ai)
        for ev in events:
            args = [TEXT_IDS[a] if isinstance(a, str) else a for a in ev['args']]
            out.append('            db %d,%d,%d,%d,%d,%d,%d,0' % (ev['obj'], ev['type'], args[0], args[1], args[2], args[3], flag))
            flag += 1
        out.append('exits%d:' % ai)
        for ex in exits:
            out.append('            db %d,%d,%d,%d,%d,%d,%d,0' % (ex['area'], ex['x'], ex['y'], ex['dir'], ex['decor'], ex['kind'], ex['lock']))
        out.append('aname%d: db "%s",0' % (ai, A['name']))
    out.append('area_info:')
    for ai in sorted(AREA_MAPS):
        A = AREA_MAPS[ai]
        enc = A['encounters']
        sx, sy, sd = A['start']
        out.append('            dw map%d_lz,events%d,exits%d,aname%d' % (ai, ai, ai, ai))
        out.append('            db %d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d' % (A['door_decor'], A['door_kind'], A['css'], A['music'], sx, sy, sd, A['rate'], enc[0], enc[1], enc[2], TEXT_IDS[A['intro']]))
    out.append('AREA_INFO_SIZE equ 20')
    out.append('NUM_FLAGS equ %d' % flag)
    return '\n'.join(out) + '\n'
