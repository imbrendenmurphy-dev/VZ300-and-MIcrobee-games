"""RUNEDEEP levels: four depths of 16 x 16.

Map legend
  #  wall        %  wall (second look)    .  floor     D  door
  G  gate        V  sealed door (3 sigils) I  illusion (walk through)
  H  hidden wall (opened by an action)     1 2 3  bronze/silver/gold door
  >  stairs down <  stairs up   O  pit   _  pressure plate   *  portal
  @  spinner (unseen)            S  start (floor)

Sides: 0 N 1 E 2 S 3 W = the way a wall face looks (the face you see
from the floor square on that side of the wall).
"""

N, E, S, W = 0, 1, 2, 3

# item numbers (see game.asm pickup_tab)
GOLD, POTION, KEY1, KEY2, KEY3, SWORD, ARMOUR, SCROLL, TOME, SIGIL, GEM, RING, VIAL, BONES = range(1, 15)

# monster types (combat.asm mon_tab)
RAT, SKELETON, SPIDER, FUNGOID, GHOUL, WISP, IMP, HOUND, KING, TRADER = range(10)
MON_SPRITE = ['rat', 'skeleton', 'spider', 'fungoid', 'ghoul', 'wisp', 'imp', 'hound', 'king', 'trader']

# decoration kinds (game.asm)
D_LEVER, D_BUTTON, D_RUNE, D_TORCH, D_FOUNT, D_TABLET, D_ALCOVE = range(1, 8)

LEVELS = []

# ---------------------------------------------------------------------
L1 = dict(
    name='The Gatehouse', theme=0, start=(1, 1, E),
    map=[
        "################",
        "#S..#.........##",
        "#.#.#.#######..#",
        "#.#...#.....#.##",
        "#.#####.###.#..#",
        "#.....D.#.#.##.#",
        "#####.###.#....#",
        "#...#.#...####.#",
        "#.#.#.#.#......#",
        "#.#...#.#.######",
        "#.#####.#.G...%#",
        "#.......#.#.%.%#",
        "###H#####.#.%.%#",
        "#...#...#.#.%%%#",
        "#.#...#...#1..>#",
        "################",
    ],
    items=[(13, 11, SIGIL), (13, 12, GOLD), (2, 13, SWORD), (1, 14, POTION), (11, 3, KEY1), (14, 4, GOLD),
           (3, 7, POTION), (5, 11, GOLD), (13, 1, GEM), (7, 14, BONES), (3, 9, GOLD)],
    mons=[(9, 3, RAT), (5, 7, RAT), (7, 11, RAT), (12, 8, SKELETON), (10, 3, SKELETON), (13, 14, SKELETON),
          (3, 13, RAT)],
    decor=[
        # x, y (the wall square), side, kind, sprite, param, extra
        (1, 0, S, D_TABLET, 'tablet', 1, 0),
        (3, 0, S, D_TORCH, 'torch', 0, 0),
        (0, 5, E, D_TORCH, 'torch', 0, 0),
        (6, 9, E, D_LEVER, 'lever_up', 0, 0),          # opens the gate at (10,10)
        (5, 4, S, D_FOUNT, 'fountain', 0, 0),
        (2, 12, N, D_TABLET, 'tablet', 2, 0),           # a hint at the hidden wall
        (0, 11, E, D_BUTTON, 'button', 1, 0),           # opens the hidden wall (3,12)
        (15, 6, W, D_TORCH, 'torch', 0, 0),
        (10, 9, W, D_TORCH, 'torch', 0, 0),
        (12, 13, S, D_TABLET, 'tablet', 3, 0),
    ],
    actions=[
        [('toggle', 10, 10)],
        [('open', 3, 12), ('msg', 4)],
    ],
    triggers=[],
    texts=['The Gatehouse',
           'Carved: WARDEN, SEEK THE THREE SIGILS. THE HOLLOW KING WAITS BELOW.',
           'Carved: WHAT THE WALL HIDES, THE BUTTON WAKES.',
           'Carved: DOWN TO THE GROTTO.',
           'Stone grinds: a wall slides away!'],
)

L2 = dict(
    name='Fungal Grotto', theme=1, start=(14, 14, N),
    map=[
        "################",
        "#.....#....#...#",
        "#.###.#.##.#.#.#",
        "#.#...I.#..#.#.#",
        "#.#.###.#.##.#.#",
        "#.#.#...#.#..#.#",
        "#...#.###.#.##.#",
        "###.#.#...I....#",
        "#...#.#.########",
        "#.###.#.....#.>#",
        "#.#...###O#.#2##",
        "#.#.#.....#.#..#",
        "###.#####.#.##.#",
        "#.H.#...G.#....#",
        "#.#.#.#.#.##.#<#",
        "################",
    ],
    items=[(1, 14, SIGIL), (3, 1, KEY2), (1, 1, TOME), (5, 5, POTION), (12, 1, GOLD), (14, 11, GOLD),
           (9, 7, ARMOUR), (7, 14, VIAL), (3, 11, GEM), (10, 1, POTION), (5, 9, BONES)],
    mons=[(7, 3, SPIDER), (9, 11, FUNGOID), (3, 7, SPIDER), (12, 5, FUNGOID), (5, 13, SPIDER), (1, 6, FUNGOID),
          (13, 1, SPIDER), (12, 7, TRADER)],
    decor=[
        (14, 15, N, D_TABLET, 'tablet', 1, 0),
        (6, 1, E, D_TORCH, 'torch', 0, 0),
        (9, 2, S, D_FOUNT, 'fountain', 0, 0),
        (10, 13, W, D_BUTTON, 'button', 0, 0),         # opens the gate (8,13)
        (0, 9, E, D_TABLET, 'tablet', 2, 0),
        (6, 14, N, D_LEVER, 'lever_up', 1, 0),         # behind the gate: opens H (2,13)
        (15, 13, W, D_TORCH, 'torch', 0, 0),
    ],
    actions=[
        [('toggle', 8, 13), ('msg', 3)],
        [('open', 2, 13), ('msg', 4)],
    ],
    triggers=[],
    texts=['Fungal Grotto',
           'Scratched: BEWARE THE SOFT FLOOR. SOME WALLS ARE ONLY SHADOW.',
           'Scratched: THE SIGIL SLEEPS WEST, BEHIND A WALL THAT A LEVER OPENS.',
           'Somewhere a gate rattles.',
           'Stone grinds: a wall slides away!'],
)

L3 = dict(
    name='Drowned Archive', theme=2, start=(1, 1, S),
    map=[
        "################",
        "#<..%%.%%%.....#",
        "#.#.....%..###.#",
        "#.#.%%%.%.##*#.#",
        "#.#.....%......#",
        "#.#####.%%%.####",
        "#...@...%...#..#",
        "###.###.%.#.#3##",
        "#*..#...%.#....#",
        "#####.#%%.######",
        "#.....#...#....#",
        "#.###.#.#.#.#..#",
        "#.#*..#.#...#..#",
        "#.#####.###V##.#",
        "#.........#...>#",
        "################",
    ],
    items=[(13, 14, SIGIL), (14, 6, ARMOUR), (1, 12, KEY3), (6, 2, SCROLL), (3, 10, POTION), (9, 10, GEM),
           (14, 4, POTION), (11, 6, GOLD), (5, 4, RING), (14, 1, GOLD), (8, 14, VIAL)],
    mons=[(6, 4, GHOUL), (3, 6, WISP), (10, 2, GHOUL), (9, 12, WISP), (5, 14, GHOUL), (13, 10, WISP),
          (13, 11, GHOUL), (14, 8, TRADER)],
    decor=[
        (1, 0, S, D_TABLET, 'tablet', 1, 0),
        (3, 0, S, D_RUNE, 'rune1', 1, 0),              # wave  (2nd)
        (9, 5, S, D_RUNE, 'rune3', 3, 0),              # star  (4th: completes)
        (0, 10, E, D_RUNE, 'rune0', 0, 0),             # flame (1st)
        (7, 15, N, D_RUNE, 'rune2', 2, 0),             # stone (3rd)
        (15, 4, W, D_FOUNT, 'fountain', 0, 0),
        (10, 0, S, D_TORCH, 'torch', 0, 0),
        (3, 5, S, D_TABLET, 'tablet', 2, 0),
        (12, 15, N, D_TORCH, 'torch', 0, 0),
    ],
    rune_action=0,
    actions=[
        [('open', 11, 13), ('msg', 3)],
    ],
    triggers=[(1, 8, ('tele', 14, 2, S)), (12, 3, ('tele', 3, 12, E)), (3, 12, ('tele', 1, 8, E))],
    texts=['Drowned Archive',
           'Inked: THE VAULT OPENS TO FLAME, THEN WAVE, THEN STONE, THEN STAR.',
           'Inked: THE FLOOR HERE TURNS THE UNWARY. MIND YOUR COMPASS.',
           'The runes blaze: the vault door sinks into the floor!'],
)

L4 = dict(
    name='The Ember Throne', theme=3, start=(1, 14, N),
    map=[
        "################",
        "#......#.......#",
        "#.####.#.#####.#",
        "#.#..#...#...#.#",
        "#.#..#####.#.#.#",
        "#.#........#...#",
        "#.######V#######",
        "#.#....#.#.....#",
        "#.#.##.#.#.###.#",
        "#...#..#.....#.#",
        "###.#.####.#.#.#",
        "#...#....#.#...#",
        "#.######.#.###.#",
        "#.#......#...#.#",
        "#<#.######.#...#",
        "################",
    ],
    items=[(3, 4, POTION), (4, 3, GEM), (14, 13, POTION), (6, 9, GOLD), (11, 3, POTION), (5, 13, VIAL),
           (8, 9, RING)],
    mons=[(1, 9, IMP), (6, 11, HOUND), (12, 7, IMP), (14, 9, HOUND), (11, 13, IMP), (6, 5, HOUND),
          (3, 1, IMP), (11, 1, KING)],
    decor=[
        (1, 15, N, D_TABLET, 'tablet', 1, 0),
        (7, 7, E, D_TORCH, 'torch', 0, 0),
        (9, 7, W, D_TORCH, 'torch', 0, 0),
        (14, 6, S, D_FOUNT, 'fountain', 0, 0),
        (7, 6, E, D_TABLET, 'tablet', 2, 0),
        (5, 0, S, D_TORCH, 'torch', 0, 0),
        (10, 0, S, D_TORCH, 'torch', 0, 0),
    ],
    actions=[],
    triggers=[],
    texts=['The Ember Throne',
           'Burnt: THE THRONE LIES BEYOND THE SEALED DOOR. THREE SIGILS BREAK THE SEAL.',
           'Burnt: HERE THE HOLLOW KING SLEEPS. WAKE HIM AND END HIM.'],
)

LEVELS = [L1, L2, L3, L4]

TYPES = {'#': 1, '%': 2, '.': 0, 'S': 0, 'D': 3, 'G': 4, 'V': 5, 'I': 6, 'H': 7, '1': 8, '2': 9, '3': 10,
         '>': 16, '<': 17, 'O': 18, '_': 19, '*': 20, '@': 21}


def off(x, y):
    return (y + 8) * 32 + x + 8


def check(L, n):
    m = L['map']
    assert len(m) == 16 and all(len(r) == 16 for r in m), (n, [len(r) for r in m])
    for y in range(16):
        for x in range(16):
            if x in (0, 15) or y in (0, 15):
                assert m[y][x] in '#%', ('border', n, x, y, m[y][x])
    for x, y, *_ in L['items'] + L['mons']:
        assert m[y][x] in '.S<>@_*O', ('blocked', n, x, y, m[y][x])
    for d in L['decor']:
        x, y, side = d[:3]
        assert m[y][x] in '#%HV', ('decor not on a wall', n, d)
        dx, dy = [(0, -1), (1, 0), (0, 1), (-1, 0)][side]
        assert m[y + dy][x + dx] not in '#%', ('decor faces a wall', n, d)
