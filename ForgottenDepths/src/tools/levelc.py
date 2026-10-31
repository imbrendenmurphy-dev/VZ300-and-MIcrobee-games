"""Level compiler: ASCII screens -> tile map (128x60), entities, messages."""
import random
from tiles import TILES, DEFS

W, H = 128, 45
SW, SH = 32, 15

ENT_CHARS = {'@': 'player', 'K': 'skeleton', 'B': 'bat', 's': 'slime', 'G': 'ghost',
             'e': 'eel', 'z': 'drowned', 'i': 'imp', 'q': 'magma', 'x': 'spider',
             'f': 'staff', 'k': 'key', 'g': 'gem', 'p': 'potion', 'h': 'heart',
             'n': 'boots', 'j': 'sunstone', 'y': 'ring', 'a': 'blade', 'M': 'mana', '&': 'boss'}
WATERISH = {'e'}          # entities that stand in water
WALLISH = set('# HTECDQO|')


def noise(x, y, s=0):
    return random.Random(x * 7919 + y * 104729 + s * 31).random()


REGION = {
    'temple': dict(floors=['floor0', 'floor2'], fw=[22, 78], rims=['rim1', 'rim2'], faces=['face1', 'face2', 'face3'],
                   motes='mote'),
    'crypt': dict(floors=['floor0', 'floor2'], fw=[22, 78], rims=['krim1', 'krim2'], faces=['kface1', 'kface2', 'kface3'],
                  motes='mote'),
    'library': dict(floors=['floor0', 'floor2'], fw=[22, 78], rims=['rim1', 'rim2'], faces=['face2', 'face1', 'face3'],
                    motes='mote'),
    'city': dict(floors=['floor0', 'moss2'], fw=[22, 78],
                 rims=['yrim1', 'yrim2'], faces=['yface1', 'yface2', 'yface3'], motes='mote'),
    'volcano': dict(floors=['floor0', 'floor2'], fw=[22, 78], rims=['vrim1', 'vrim2'], faces=['vface1', 'vface2', 'vface3'],
                    motes='mote'),
    'cave': dict(floors=['floor0', 'moss2'], fw=[22, 78],
                 rims=['crim1', 'crim2', 'crim3'], faces=['cface1', 'cface2', 'cface3'], motes='mote'),
}


def compile_level(mod):
    grid = [['#'] * W for _ in range(H)]
    region = [[None] * W for _ in range(H)]
    for (sx, sy), scr in mod.SCREENS.items():
        rows = scr['rows']
        assert len(rows) == SH, (sx, sy, len(rows))
        for y, r in enumerate(rows):
            assert len(r) == SW, f'screen {sx},{sy} row {y} len {len(r)}: {r!r}'
            for x, ch in enumerate(r):
                grid[sy * SH + y][sx * SW + x] = ch
                region[sy * SH + y][sx * SW + x] = scr['region']
    tiles = [[TILES['rock']] * W for _ in range(H)]
    ents = []
    portals = []
    runes = []

    def ch(x, y):
        if 0 <= x < W and 0 <= y < H:
            return grid[y][x]
        return '#'

    def wallish(x, y):
        return ch(x, y) in WALLISH or ch(x, y) == '#'

    for y in range(H):
        for x in range(W):
            c = grid[y][x]
            rg = REGION[region[y][x] or 'temple']
            if c in ENT_CHARS:
                ents.append((ENT_CHARS[c], x, y))
                c = 'w' if c in WATERISH else '.'
            n = noise(x, y)

            def floor():
                acc = 0
                tot = sum(rg['fw'])
                v = n * tot
                for f, w in zip(rg['floors'], rg['fw']):
                    acc += w
                    if v < acc:
                        return TILES[f]
                return TILES[rg['floors'][0]]

            if c in '# ':
                below = ch(x, y + 1)
                near = any(not wallish(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                if not wallish(x, y + 1) and below != '#':
                    k = rg['faces']
                    t = k[0] if x % 2 == 0 else k[1]
                    if noise(x, y, 3) < 0.18:
                        t = k[2]
                    tiles[y][x] = TILES[t]
                elif near:
                    tiles[y][x] = TILES[rg['rims'][int(noise(x, y, 5) * len(rg['rims']))]]
                else:
                    tiles[y][x] = TILES['rock']
            elif c == '.':
                tiles[y][x] = floor()
            elif c == '~':
                tiles[y][x] = TILES[rg['motes']] + int(noise(x, y, 9) * 4)
            elif c == 'T':
                tiles[y][x] = TILES['torch'] + (x + y) % 4
            elif c == 'E':
                tiles[y][x] = TILES['brazier'] + (x * 3 + y) % 4
            elif c == 'C':
                tiles[y][x] = TILES['crystal'] + (x + 2 * y) % 4
            elif c == 'c':
                tiles[y][x] = TILES['candle'] + (x * 5 + y) % 4
            elif c == 'u':
                tiles[y][x] = TILES['shroom'] + (x + y) % 4
            elif c == '%':
                tiles[y][x] = TILES['portal'] + (x + y) % 4
                portals.append((x, y))
            elif c == '^':
                tiles[y][x] = TILES['plate']
            elif c == '|':
                tiles[y][x] = TILES['gate']
            elif c == 'L':
                tiles[y][x] = TILES['lava'] + (x * 2 + y) % 4
            elif c == 'Y':
                tiles[y][x] = TILES['seal'] + (x + y) % 4
            elif c == 'V':
                tiles[y][x] = TILES['ember'] + (x + y) % 4
            elif c == 'Q':
                tiles[y][x] = TILES[['shelf1', 'shelf2', 'shelf3'][(x * 7 + y * 3) % 3]]
            elif c == 'O':
                tiles[y][x] = TILES['gear'] + (x + y) % 4
            elif c == '_':
                tiles[y][x] = TILES['bridge']
            elif c == 'w':
                tiles[y][x] = TILES['water'] + (x + y) % 4
            elif c == 'l':
                tiles[y][x] = TILES['pool'] + (x * 3 + y * 2) % 4
            elif c == 'X':
                tiles[y][x] = TILES['rune'] + (x + y) % 4
                runes.append((x, y))
            elif c == 'P':
                up, dn = ch(x, y - 1) == 'P', ch(x, y + 1) == 'P'
                tiles[y][x] = TILES['pillar_t' if not up else ('pillar_b' if not dn else 'pillar_m')]
            elif c == 'S':
                tiles[y][x] = TILES['statue_t' if ch(x, y - 1) != 'S' else 'statue_b']
            elif c in 'At':
                p = 'altar' if c == 'A' else 'tomb'
                l, r = ch(x - 1, y) == c, ch(x + 1, y) == c
                tiles[y][x] = TILES[p + ('_l' if not l else ('_r' if not r else '_m'))]
            elif c == 'm':
                tiles[y][x] = TILES['mosaic1' if (y + x) % 2 == 0 else 'mosaic2']
            elif c == 'b':
                tiles[y][x] = TILES['bones']
            elif c == 'r':
                tiles[y][x] = TILES['rubble']
            elif c == '"':
                tiles[y][x] = TILES['debris']
            elif c == 'o':
                tiles[y][x] = TILES['boulder']
            elif c == 'd':
                tiles[y][x] = TILES['doorway']
            elif c == '<':
                tiles[y][x] = TILES['stairup']
            elif c == '>':
                tiles[y][x] = TILES['stairdn']
            elif c == 'D':
                tiles[y][x] = TILES['door']
            elif c == 'H':
                tiles[y][x] = TILES[{'cave': 'hidden', 'city': 'hid_y', 'volcano': 'hid_v'}.get(region[y][x], 'hid_t')]
            else:
                raise ValueError(f'unknown map char {c!r} at {x},{y}')
    # messages: runes in row-major order per screen definition order
    msgs = []
    for (sx, sy), scr in mod.SCREENS.items():
        rs = [(x, y) for (x, y) in runes if x // SW == sx and y // SH == sy]
        rs.sort(key=lambda p: (p[1], p[0]))
        assert len(rs) == len(scr['msgs']), (sx, sy, rs, scr['msgs'])
        for p, m in zip(rs, scr['msgs']):
            assert len(m) <= 32, m
            msgs.append((p, m))
    assert len(portals) in (0, 2, 4), portals
    return dict(tiles=tiles, ents=ents, msgs=msgs, screens=mod.SCREENS, portals=portals)
