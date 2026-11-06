# maps.py - castle maps, events and exits for the vertical slice
# Cell byte: bits0-2 type (0 floor,1 wallA,2 wallB,3 door,4 secret,5 exit), bits3-7 param
from collections import deque

# event types
EV_SIGN, EV_CHEST, EV_NPC, EV_SCRIPT, EV_SHRINE, EV_STEP, EV_BOSS, EV_ITEM, EV_PLAQUE, EV_SHOP = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
# items
IT_POTION, IT_HOLY, IT_IRONKEY, IT_DAGGER, IT_FIRE, IT_CRYPTKEY, IT_ELIXIR, IT_SWORD, IT_CLOAK, IT_TOWERKEY = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10

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
    css=0, song='GROUNDS', encounters=[1, 1, 2], rate=22, intro='INTRO0',
    wall_text='HEDGE', secret_text='HEDGEX', bbg=0,
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
           'U': dict(area=2, x=8, y=14, dir=0, decor=1, kind=2, lock=0),
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
    css=0, song='HALL', encounters=[3, 1, 3], rate=20, intro='INTRO1',
    wall_text='WALL', secret_text='SECRET', bbg=1,
)

# --------------------------------------------------------------------------
# AREA 2 : THE LIBRARY
#   decors: 1 door, 2 candles, 3 stairs
#   objects: 1 lectern, 2 chest, 3 chest_open, 4 angel, 5 vesper, 6 eye-orb, 7 bookseller
# --------------------------------------------------------------------------
AREA_MAPS[2] = dict(
    name='THE LIBRARY',
    rows=[
        "################",
        "#%%%%%%%%%%%%Z%#",
        "#%c.gS......%..#",
        "#%%%%%.####.%a.#",
        "#......#..#.%T.#",
        "#.##.#.#..#....#",
        "#.##.#.#n.#.##.#",
        "#.##.#.##.#.#..#",
        "#.......l.....h#",
        "#%%.%T%...%T%.%#",
        "#e..%p.....q%.%#",
        "#%%.%.......%.%#",
        "#%..%r.v...u%m%#",
        "#%%.%.......%%%#",
        "#%%.%%T%.%T%%%%#",
        "########Y#######",
    ],
    legend={'#': (1, 0), '%': (2, 0), '.': (0, 0), 'T': (2, 2), 'S': ('secret', 0)},
    door_decor=1, door_kind=2,
    exits={'Y': dict(area=1, x=8, y=2, dir=2, decor=1, kind=2, lock=0),
           'Z': dict(area=3, x=1, y=1, dir=2, decor=3, kind=2, lock=IT_CRYPTKEY)},
    events={
        'c': dict(obj=2, type=EV_CHEST, args=[IT_ELIXIR, 1, 0, 0]),
        'g': dict(obj=6, type=EV_BOSS, args=[5, 0, IT_CRYPTKEY, 'GRELLTX']),
        'a': dict(obj=4, type=EV_SHRINE, args=[0, 0, 0, 0]),
        'n': dict(obj=2, type=EV_CHEST, args=[IT_HOLY, 2, 0, 0]),
        'l': dict(obj=5, type=EV_NPC, args=['VESPER1', 0, 0, 'VESPER2']),
        'h': dict(obj=2, type=EV_CHEST, args=[IT_POTION, 2, 0, 0]),
        'p': dict(obj=1, type=EV_SIGN, args=['BOOK1', 0, 0, 0]),
        'q': dict(obj=1, type=EV_SIGN, args=['BOOK2', 0, 0, 0]),
        'r': dict(obj=1, type=EV_SIGN, args=['BOOK3', 0, 0, 0]),
        'u': dict(obj=1, type=EV_SIGN, args=['BOOK4', 0, 0, 0]),
        'v': dict(obj=1, type=EV_SIGN, args=['BOOKJOKE', 0, 0, 0]),
        'e': dict(obj=2, type=EV_CHEST, args=[IT_POTION, 1, 0, 0]),
        'm': dict(obj=7, type=EV_SHOP, args=['SHOP2', IT_POTION, IT_HOLY, IT_ELIXIR]),
    },
    start=(8, 14, 0),
    css=0, song='LIBRARY', encounters=[3, 1, 3], rate=20, intro='INTRO2',
    wall_text='SHELF', secret_text='SHELFX', bbg=2,
)

# --------------------------------------------------------------------------
# AREA 3 : THE DUNGEONS & CATACOMBS
#   decors: 1 door, 2 torch, 3 stairs
#   objects: 1 bones, 2 chest, 3 chest_open, 4 angel, 5 kaspar, 6 ghoul throne
# --------------------------------------------------------------------------
AREA_MAPS[3] = dict(
    name='DUNGEONS',
    rows=[
        "#U##############",
        "#..............#",
        "#.#c#r######a#.#",
        "#.##########=#.#",
        "#.#####=######.#",
        "#.##=#=m==#=##.#",
        "#..............#",
        "#.Tx##=#=#S#=#.#",
        "#.#...##.....#.#",
        "#.###.##=....#.#",
        "#.#T#.##....k#.#",
        "#.e##.########.#",
        "#.....########f#",
        "#...........g..#",
        "#############d.#",
        "##############V#",
    ],
    legend={'#': (1, 0), '=': (2, 0), '.': (0, 0), 'T': (1, 2), 'S': ('secret', 0)},
    door_decor=1, door_kind=1,
    exits={'U': dict(area=2, x=13, y=2, dir=2, decor=3, kind=1, lock=0),
           'V': dict(area=98, x=0, y=0, dir=0, decor=3, kind=1, lock=IT_TOWERKEY)},
    events={
        'c': dict(obj=2, type=EV_CHEST, args=[IT_HOLY, 2, 0, 0]),
        'r': dict(obj=1, type=EV_SIGN, args=['TALLY', 0, 0, 0]),
        'a': dict(obj=4, type=EV_SHRINE, args=[0, 0, 0, 0]),
        'm': dict(obj=5, type=EV_SHOP, args=['KASPAR', IT_POTION, IT_HOLY, IT_CLOAK]),
        'x': dict(obj=1, type=EV_SCRIPT, args=[2, 1, IT_POTION, 'BONES3']),
        'k': dict(obj=2, type=EV_CHEST, args=[IT_SWORD, 1, 0, 0]),
        'e': dict(obj=2, type=EV_CHEST, args=[IT_ELIXIR, 1, 0, 0]),
        'f': dict(obj=2, type=EV_CHEST, args=[IT_POTION, 2, 0, 0]),
        'g': dict(obj=6, type=EV_BOSS, args=[8, 0, IT_TOWERKEY, 'GHOULTX']),
        'd': dict(obj=1, type=EV_SIGN, args=['TOWERSIGN', 0, 0, 0]),
    },
    start=(1, 1, 2),
    css=0, song='DUNGEON', encounters=[6, 7, 2], rate=18, intro='INTRO3',
    wall_text='DSTONE', secret_text='DSECRET', bbg=3,
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

AREA_RAM = 0xE400
AREA_MAX = 0x600

def all_flags():
    """event flag numbers are global: areas in order, events in order"""
    fl = {}; n = 0
    for ai in sorted(AREA_MAPS):
        _, events, _ = compile_area(ai)
        for k in range(len(events)): fl[(ai, k)] = n; n += 1
    assert n <= 256
    return fl

def pack(ai):
    """the area pack: everything about an area except its graphics, built for AREA_RAM"""
    from texts import text_id, AT, encode
    from lz2 import compress_opt as lz_compress
    import music
    A = AREA_MAPS[ai]; flags = all_flags()
    cells, events, exits = compile_area(ai)
    tid = lambda n: text_id(n, ai)
    hdr = 27
    body = bytearray(); fix = {}
    def put(label, data): fix[label] = AREA_RAM + hdr + len(body); body.extend(data)
    put('map', lz_compress(cells))
    ev = bytearray()
    for k, e in enumerate(events):
        args = [tid(a) if isinstance(a, str) else a for a in e['args']]
        ev += bytes([e['obj'], e['type'], args[0], args[1], args[2], args[3], flags[(ai, k)], 0])
    put('events', ev)
    ex = bytearray()
    for e in exits: ex += bytes([e['area'], e['x'], e['y'], e['dir'], e['decor'], e['kind'], e['lock'], 0])
    put('exits', ex)
    put('name', A['name'].encode() + b'\0')
    local = list(AT.get(ai, {}))
    tt_at = AREA_RAM + hdr + len(body)
    tdata = [encode(AT[ai][n]) for n in local]
    addr = tt_at + 2 * len(local); tt = bytearray()
    for d in tdata: tt += bytes([addr & 255, addr >> 8]); addr += len(d)
    put('texts', tt + b''.join(tdata))
    song = A.get('song')
    if song: put('song', music.song_bytes(song, AREA_RAM + hdr + len(body)))
    sx, sy, sd = A['start']; enc = A['encounters']
    w = lambda v: bytes([v & 255, v >> 8])
    head = (w(fix['map']) + w(fix['events']) + w(fix['exits']) + w(fix['name']) +
            bytes([A['door_decor'], A['door_kind'], A['css'], 0x80 if song else A['music'], sx, sy, sd, A['rate'],
                   enc[0], enc[1], enc[2], tid(A['intro'])]) +
            w(fix['texts']) + w(fix.get('song', 0)) +
            bytes([tid(A.get('wall_text', 'WALL')), tid(A.get('secret_text', 'SECRET')), A.get('bbg', 0)]))
    assert len(head) == hdr
    out = head + bytes(body)
    assert len(out) <= AREA_MAX, ('pack too big', ai, len(out))
    return out

def asm():
    secrets = sum(sum(r.count(ch) for r in A['rows']) for A in AREA_MAPS.values()
                  for ch, v in A['legend'].items() if v[0] == 'secret')
    chests = sum(1 for A in AREA_MAPS.values() for e in A['events'].values() if e['type'] == EV_CHEST)
    return ('NUM_FLAGS equ %d\nNUM_AREAS equ %d\nstr_of2: db " OF %d",0\nstr_of5: db "/%d",0\n'
            % (len(all_flags()), len(AREA_MAPS), secrets, chests))
