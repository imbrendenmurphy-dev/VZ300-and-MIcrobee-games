# Ghost Hunter 3 maze designs.  Each maze is given as its LEFT half plus the
# centre column (14 chars per row); the right half is mirrored.  27 cells wide.
# legend:
#   #  wall              .  pellet           o  energiser (power pill)
#   (space) empty floor  G  ghost house      -  house door
#   T  tunnel mouth      X  teleporter       P  player start (empty)
#   $  pellet + spot where treasures / power-ups may appear
# Rules (checked by check()): fully connected, no dead ends, no 2x2 open
# squares, house = row of 5 G under a 3-wide door, centred.

MAZES = {}

MAZES['CRYPT'] = dict(style=0, rows="""
##############
#o..........##
#.###.#.###.##
#.....#...#...
#.###.###.#.##
#...#.....#...
###.#.#####.#.
T.....#.......
#.###.#.###.##
#.#...........
#.#.###.#.##--
#...#...#.#GGG
###.#.###.####
#.....#.$....P
#.###.#.#.###.
#.#.....#.....
#.#.###.###.##
#...#.........
###.#.#.###.##
T.....#...#...
#.###.###.#.#.
#.#.........#.
#.#.#.###.#.#.
#o..#...#.#...
###.###.#.###.
#.....$.......
#.###.#.#####.
#...#.#.......
#.#.#.#.#.#.##
#.......#....$
##############
""")

MAZES['HALLS'] = dict(style=1, rows="""
##############
#o...#........
#.##.#.####.#.
#.#....#....#.
#.#.##.#.##.#.
#...#......$..
###.#.##.#####
T.....#.......
#.###.#.##.##.
#.#...........
#.#.###.#.##--
#.....#.#.#GGG
#####.#.#.####
#$....#.....P.
#.###.#####.#.
#...#.......#.
###.#.###.###.
T...#.#.......
#.###.#.#####.
#.#.....#...#.
#.#.###.#.#.#.
#o..#.....#...
#.###.###.###.
#.....$.......
#.###.#.#####.
#...#.#.#...#.
###.#.#.#.#.#.
#.....#...#...
#.#####.#####.
#.............
##############
""")

MAZES['GRAVEYARD'] = dict(style=2, rows="""
##############
#o.......#....
#.##.###.#.##.
#.#........#..
#.#.##.###.#.#
#....#...#....
####.#.#.#.##.
T....#.#......
#.##.#.#.####.
#.#..........$
#.#.##.##.##--
#...#.....#GGG
###.#.###.####
#.......#...P.
#.#####.#.###.
#.#...#.....#.
#.#.#.#.###.#.
#...#.....#...
#.###.###.#.##
#o#.....#.....
#.#.###.#.###.
#...#.......#.
###.#.#####.#.
T...#.....#...
#.###.###.#.##
#.....#$......
#.###.#.#####.
#.#...#.....#.
#.#.#####.#.#.
#o............
##############
""")

MAZES['CATACOMBS'] = dict(style=3, rows="""
##############
#X....#.......
#.###.#.#####.
#.#.....#...#.
#.#.###.#.#.#.
#.....#...#...
#####.#.###.##
T.....#.......
#.###.#.#####.
#.#........$..
#.#.###.#.##--
#...#...#.#GGG
###.#.###.####
#o..#.......P.
#.#.#.#.#####.
#.#...#.......
#.#####.#.###.
#.......#.#...
#.#.###.#.#.##
#.#.#.....#...
#.#.#.###.###.
#$..#...#.....
###.###.#.###.
T.......#.#...
#.#####.#.#.##
#.#.....#.....
#.#.#.#####.#.
#o..#.....#.#.
#.###.#.#.#.#.
#X......#.....
##############
""")

MAZES['BELFRY'] = dict(style=1, rows="""
##############
#o......#.....
#.#####.#.###.
#.#...........
#.#.#.###.##.#
#...#...#.#...
###.###.#.#.##
T.....#.....##
#.###.#.###.##
#.#...........
#.#.##.##.##--
#....#....#GGG
####.#.#.#####
#....#.$....P.
#.##.#.######.
#.#.......#...
#.#.#####.#.#.
#.#.....#...#.
#.#####.#.###.
#$....#.#.....
#.###.#.#.###.
#.#.......#...
#.#.#####.#.##
#o#.....#.#...
#.#####.#.#.#.
#.......#...#.
#.#.###.#####.
T.#.#.........
#.#.#.###.###.
#...#...#.#...
#.#.###.#.#.##
#.#.....$.....
#.#.#.###.#.##
#o..#.....#...
##############
""")

MAZES['MANOR'] = dict(style=2, rows="""
##############
#o..#.........
#.#.#.#.#####.
#.#...#.....#.
#.###.#####.#.
#.....#$......
#.###.#.#####.
T...#.#.......
###.#.#.#.###.
#.....#.#.....
#.###.#.#.##--
#.#.......#GGG
#.#.#####.####
#...#.......P.
###.#.#####.#.
#o..#.....#.#.
#.#.###.#.#...
#.#.....#.#.##
#.#####.#.#...
#.....#.#...#.
#####.#.#####.
T.....#.......
#.###.#.#####.
#.#...#.#$....
#.#.###.#.##.#
#.#.......#...
#.#.#####.#.#.
#...#.....#.#.
###.#.#####.#.
#X....#.......
#.#####.#####.
#o............
##############
""")

# bonus maze for PELLET PANIC: smaller, open, quick to clear
MAZES['PANIC'] = dict(style=3, rows="""
##############
#o............
#.###.#.#####.
#.#...#.....#.
#.#.#####.#.#.
T.....#...#...
#.###.#.#.##--
#.#.....#.#GGG
#.#.###.#.####
#.....#.....P.
#.###.#.#####.
#.#.........#.
#.#.#.#####.#.
#o..#.....$...
##############
""")


def build(name):
    rows = [r for r in MAZES[name]['rows'].strip('\n').split('\n')]
    full = []
    for r in rows:
        assert len(r) == 14, (name, r, len(r))
        if r[12] == 'P':
            r = r[:12] + '.P'
        full.append(list(r[:13] + r[13] + r[12::-1]))
    # only one player start: the mirrored copy of P in the centre column is itself
    return full


PATH = set(".o $TXP")


def check(name, verbose=True):
    g = build(name)
    H = len(g); W = len(g[0])
    ok = True
    def path(x, y):
        return 0 <= y < H and g[y][x % W] in PATH
    start = [(x, y) for y in range(H) for x in range(W) if g[y][x] == 'P']
    assert len(start) == 1, (name, start)
    seen = {start[0]}; st = [start[0]]
    while st:
        x, y = st.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = (x + dx) % W, y + dy
            if path(nx, ny) and (nx, ny) not in seen:
                seen.add((nx, ny)); st.append((nx, ny))
    allp = {(x, y) for y in range(H) for x in range(W) if path(x, y)}
    miss = allp - seen
    dead = []
    for (x, y) in allp:
        n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if path((x + dx) % W, y + dy))
        if n < 2:
            dead.append((x, y))
    sq = []
    for y in range(H - 1):
        for x in range(W - 1):
            if path(x, y) and path(x + 1, y) and path(x, y + 1) and path(x + 1, y + 1):
                sq.append((x, y))
    # tunnels: T cells must be at the edges and the row must be open across
    for y in range(H):
        for x in range(W):
            if g[y][x] == 'T' and x not in (0, W - 1):
                print(name, "T not at edge", x, y); ok = False
    # edge cells (col 0/W-1) must be wall or T
    for y in range(H):
        for x in (0, W - 1):
            if g[y][x] not in "#T":
                print(name, "open edge", x, y); ok = False
    if g[0].count('#') != W or g[H - 1].count('#') != W:
        print(name, "top/bottom not closed"); ok = False
    if miss:
        print(name, "UNREACHABLE", sorted(miss)); ok = False
    if dead:
        print(name, "DEAD ENDS", sorted(dead)); ok = False
    if sq:
        print(name, "2x2 OPEN", sorted(sq)); ok = False
    # house
    hs = [(x, y) for y in range(H) for x in range(W) if g[y][x] == 'G']
    hy = hs[0][1]
    assert [x for x, y in hs] == [11, 12, 13, 14, 15] and all(y == hy for x, y in hs), (name, hs)
    assert g[hy - 1][12:15] == ['-'] * 3, (name, "door")
    assert g[hy - 2][13] in PATH, (name, "exit")
    assert g[hy + 1][10:17] == ['#'] * 7, (name, "house floor")
    assert g[hy][10] == '#' and g[hy][16] == '#'
    if verbose:
        npel = sum(r.count('.') + r.count('$') for r in g)
        print("%-10s %dx%d pellets %d energisers %d  %s" % (name, W, H, npel, sum(r.count('o') for r in g), "OK" if ok else "**BAD**"))
    return ok


if __name__ == "__main__":
    import sys
    for n in MAZES:
        check(n)
        if len(sys.argv) > 1 and sys.argv[1] in (n, 'all'):
            for r in build(n):
                print("   " + "".join(r))
