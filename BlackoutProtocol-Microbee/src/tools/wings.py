"""The five generated wings of the Halcyon Array (wing 0, Docking, is hand-built in gen.py).

Each room: a floor plan from the wing's set, platforms broken by gaps, lift pads,
furniture and wall fittings from the wing's theme, a sign or two, robots, the
wing's own mechanic, and a door at each end.  Every room must pass reachlib.check
(or a new layout is tried).  Deterministic: the same seed builds the same station.
"""
import random
import reachlib

NAMES = {
    1: ["GREENHOUSE 1", "SEED VAULT", "IRRIGATION", "SPORE LAB", "GREENHOUSE 2", "ORCHARD DOME", "NURSERY", "AGRI CONTROL"],
    2: ["CRYO BAY 1", "SAMPLE VAULT", "FREEZER ROW", "ICE CORE DRILL", "CRYO BAY 2", "COOLANT PUMPS", "FROST LAB", "CRYO CONTROL"],
    3: ["TURBINE HALL", "COOLING TOWER", "FUEL STORE", "STEAM PLANT", "PIPEWORKS", "HEAT SINK", "CORE MONITOR", "REACTOR LAB"],
    4: ["STAR DECK", "TELESCOPE", "ORBIT LAB", "DARK ROOM", "GRAVITY TEST", "STAR ARCHIVE", "SENSOR ARRAY", "NAV CONTROL"],
    5: ["DATA VAULT", "LOGIC HALL", "MEMORY BANKS", "ANTECHAMBER"],
}
SPLICE_NAME = {1: "AGRI CONTROL", 2: "CRYO CONTROL", 3: "REACTOR LAB", 4: "NAV CONTROL", 5: "ANTECHAMBER"}

def themes(C):
    return {
        1: dict(style='glass', pal=(C['BGREEN'], C['GREEN'], C['BCYAN'], C['GREEN']), floor=('floor', C['BGREEN']),
                furn=[('plantt', 'plantb', None), ('plantt', 'plantb', None), ('tankt', 'tankb', C['BCYAN']), ('lockt', 'lockb', C['GREEN'])],
                decor=[('window', C['BCYAN']), ('valve', C['YELLOW']), ('leds', C['BGREEN']), ('fan', C['GREEN'])], lamp=C['BGREEN'],
                signs=["GROW BAY", "SECTOR 2", "HUMIDITY", "SPORES"], robots=[0, 0, 2]),
        2: dict(style='ice', pal=(C['WHITE'], C['BBLUE'], C['BCYAN'], C['BBLUE']), floor=('grate', C['BCYAN']),
                furn=[('tankt', 'tankb', C['WHITE']), ('lockt', 'lockb', C['BCYAN']), ('scrtop', 'scrbot', C['BCYAN'])],
                decor=[('gauge', C['WHITE']), ('window', C['BCYAN']), ('wave', C['BCYAN']), ('leds', C['WHITE'])], lamp=C['WHITE'],
                signs=["MINUS 120", "KEEP SEALED", "SAMPLES", "COLD STORE"], robots=[0, 1, 1]),
        3: dict(style='pipes', pal=(C['YELLOW'], C['RED'], C['BRED'], C['RED']), floor=('hazard', None),
                furn=[('tankt', 'tankb', C['YELLOW']), ('rackt', 'rackb', C['BRED']), ('lockt', 'lockb', C['YELLOW'])],
                decor=[('valve', C['YELLOW']), ('gauge', C['YELLOW']), ('fan', C['BRED']), ('beacon', C['YELLOW'])], lamp=C['BRED'],
                signs=["DANGER", "HIGH TEMP", "STEAM", "TURBINE 4"], robots=[0, 3, 2]),
        4: dict(style='space', pal=(C['BMAG'], C['BLUE'], C['WHITE'], C['BLUE']), floor=('floor', C['WHITE']),
                furn=[('scrtop', 'scrbot', C['BMAG']), ('rackt', 'rackb', C['BCYAN']), ('bedt', 'bedb', C['WHITE'])],
                decor=[('window', C['WHITE']), ('dish', C['BCYAN']), ('wave', C['BMAG']), ('beacon', C['BCYAN'])], lamp=C['WHITE'],
                signs=["ORBIT", "ZERO G", "STARS", "DOCK 9"], robots=[1, 2, 0]),
        5: dict(style='circuit', pal=(C['BRED'], C['MAG'], C['BMAG'], C['MAG']), floor=('grate', C['BMAG']),
                furn=[('rackt', 'rackb', C['BMAG']), ('scrtop', 'scrbot', C['BRED']), ('lockt', 'lockb', C['MAG'])],
                decor=[('coret', C['BRED']), ('fan', C['BMAG']), ('leds', C['BRED']), ('wave', C['BMAG'])], lamp=C['BRED'],
                signs=["MERIDIAN", "LOGIC", "MEMORY", "NO ENTRY"], robots=[1, 2, 3, 0]),
    }

FLOOR_SETS = [[7, 14, 21], [6, 13, 21], [8, 14, 21], [7, 13, 21], [10, 21], [12, 21]]

def segments(rng, f, left, right):
    segs = []
    c = 2 if (left == f or rng.random() < 0.6) else rng.randint(3, 6)
    while c <= 39:
        e = min(39, c + rng.randint(7, 15) - 1)
        if 39 - e < 4: e = 39
        segs.append((c, e))
        c = e + rng.randint(3, 6) + 1
    if right == f and segs[-1][1] != 39: segs[-1] = (segs[-1][0], 39)
    return segs

def build_room(G, wing, name, rng, splice, solid_tiles):
    C = G; Room = G['Room']; th = themes(C)[wing]
    vault = 13 if wing == 4 else 9
    for attempt in range(400):
        floors = rng.choice(FLOOR_SETS)
        left, right = rng.choice(floors), rng.choice(floors)
        r = Room(name, *th['pal'], th['style'])
        r.frame(left, right)
        kind, ink = th['floor']
        segs = {floors[-1]: [(2, 39)]}
        for f in floors[:-1]: segs[f] = segments(rng, f, left, right)
        for f, sl in segs.items():
            for c0, c1 in sl: r.floor(f, c0, c1, kind, ink)
        # the wing's floors: ice (cryo)
        if wing == 2:
            for f, sl in segs.items():
                for c0, c1 in sl:
                    if c1 - c0 >= 8 and rng.random() < 0.6:
                        a = rng.randint(c0 + 1, c1 - 6); r.floor(f, a, min(c1, a + rng.randint(5, 9)), 'ice', C['WHITE'])
        npad = 1 if len(floors) == 2 else rng.choice([1, 1, 2])
        pad_cols = []
        for _ in range(npad):
            c0 = rng.randint(5, 33)
            if any(abs(c0 - p) < 6 for p in pad_cols): continue
            pad_cols.append(c0); r.pad(c0, list(floors))
        r.walls(floors, rng)
        # furniture
        avoid = set()
        for p in pad_cols: avoid |= set(range(p - 1, p + 4))
        def free_cols(f, c0, c1):
            cols = [c for c in range(c0 + 1, c1) if c not in avoid]
            if left == f: cols = [c for c in cols if c > 5]
            if right == f: cols = [c for c in cols if c < 36]
            return cols
        used = set()
        if splice:                 # always: two free columns on the bottom floor, near the middle
            spots = sorted((c for c in range(8, 33) if c not in avoid and c + 1 not in avoid), key=lambda c: abs(c - 20))
            if not spots: continue
            c = spots[0]
            for k in (0, 1): r.furn(floors[-1], c + k, 'splt', 'splb', C['BMAG']); used.add((floors[-1], c + k))
        if rng.random() < 0.35:
            fc = [c for c in free_cols(floors[-1], 2, 39) if (floors[-1], c) not in used]
            if fc: c = rng.choice(fc); r.furn(floors[-1], c, 'termt', 'termb'); used.add((floors[-1], c))
        for f, sl in segs.items():
            for c0, c1 in sl:
                cols = free_cols(f, c0, c1)
                n = max(0, (c1 - c0) // 6 + rng.randint(-1, 1))
                for _ in range(n):
                    cand = [c for c in cols if (f, c) not in used and (f, c - 1) not in used]
                    if not cand: break
                    c = rng.choice(cand)
                    top, bot, ink2 = rng.choice(th['furn'])
                    width = rng.choice([1, 1, 2])
                    for k in range(width):
                        if (c + k) in cols and (f, c + k) not in used:
                            r.furn(f, c + k, top, bot, ink2); used.add((f, c + k))
        # signs first (different words, clear of each other), then lamps and fittings round them
        lamps = list(range(4, 38, rng.randint(7, 10)))
        flick = rng.choice(lamps) if rng.random() < 0.5 else None      # now and then a failing lamp
        for c in lamps: r.decor(1, c, 'lampb' if c == flick else 'lamp', th['lamp'])
        zones = [(p + 2, f - 4) for p, f in zip([0] + floors, floors) if f - 4 >= p + 2]
        taken = set()
        words = rng.sample(th['signs'] + [name], 2)
        for text in words[:rng.randint(1, 2)]:
            if not zones: break
            for _ in range(20):
                zr = rng.choice(zones); row = rng.randint(zr[0], zr[1])
                col = rng.randint(3, max(3, 38 - len(text)))
                cells = {(row, c) for c in range(col - 1, col + len(text) + 1)}
                if not cells & taken:
                    taken |= {(rr, c) for (rr, c) in cells for rr in (row - 1, row, row + 1)}
                    r.sign(row, col, text, th['pal'][2] if rng.random() < 0.5 else C['WHITE'])
                    break
        prev = 0
        for f in floors:
            z0, z1 = prev + 1, f - 3
            if z1 - z0 >= 2:
                for _ in range(rng.randint(2, 4)):
                    nm, ink2 = rng.choice(th['decor'])
                    rr, cc = rng.randint(z0 + 1, z1 - 1), rng.randint(4, 37)
                    if (rr, cc) not in taken: r.decor(rr, cc, nm, ink2); taken.add((rr, cc))
            prev = f
        # the wing's mechanic and its guards
        n_bots = 0
        long_segs = [(f, c0, c1) for f, sl in segs.items() for c0, c1 in sl if c1 - c0 >= 9]
        if wing == 1:            # spore mist over the walkways
            for f, c0, c1 in long_segs[:2]:
                a = rng.randint(c0, max(c0, c1 - 8)); b_ = min(c1, a + rng.randint(6, 11))
                for rr in (f - 2, f - 1):
                    for c in range(a, b_ + 1):
                        if r.t[rr][c] == 'empty': r.put(rr, c, 'mist', 0, C['GREEN'])
        if wing == 3:            # steam vents in the floor
            for f, c0, c1 in rng.sample(long_segs, min(2, len(long_segs))):
                c = rng.randint(c0 + 2, c1 - 2)
                if c in avoid or (f, c) in used: continue
                if (left == f and c < 10) or (right == f and c > 31): continue
                r.put(f, c, 'ventf')
                r.robot(4, f, c - 1, c + 1, c - 1, rng.randint(0, 60)); n_bots += 1
        if wing == 5:            # laser gates across the walkways
            for f, c0, c1 in rng.sample(long_segs, min(2, len(long_segs))):
                c = rng.randint(c0 + 3, c1 - 3)
                if c in avoid: continue
                if (left == f and c < 10) or (right == f and c > 31): continue
                r.put(f - 3, c, 'lasem', C['BRED'])
                r.robot(5, f, c - 1, c + 1, c - 1, rng.randint(0, 60)); n_bots += 1
        # robots: a steady climb through the wings (1, 1-2, 1 + vents, 2, 2 + lasers);
        # never more than one hunter a room; splice rooms stay gentle
        want = {1: 1, 2: rng.choice([1, 2]), 3: 1, 4: 2, 5: 2}[wing]
        if splice: want = min(want, 1) if rng.random() < 0.5 else 0
        hunters = 0
        for attempt_ in range(30):
            if want <= 0 or n_bots >= 4: break
            segs_ok = [(f, c0, c1) for f, sl in segs.items() for c0, c1 in sl if c1 - c0 >= 7]
            if not segs_ok: break
            f, c0, c1 = rng.choice(segs_ok)
            k = rng.choice(th['robots'])
            if k == 2 and hunters: k = 0
            if f in (left, right) and k in (1, 3): k = 0
            if left == f: c0 = max(c0, 13)
            if right == f: c1 = min(c1, 28)
            if c1 - c0 < 6: continue
            if k == 3:
                c = rng.randint(c0 + 1, c1 - 3); r.robot(3, f, c, c + 2, c)
            else:
                r.robot(k, f, c0, c1, rng.randint(c0, c1 - 2))
            hunters += k == 2; n_bots += 1; want -= 1
        if want > 0 and not splice: continue          # a room needs its guard: try another layout
        r.finish()
        if splice and not any(r.t[rr][cc] == 'splb' for rr in range(22) for cc in range(42)): continue
        if not reachlib.check(r, solid_tiles, vault) and r.searchables():
            r.wing = wing
            return r
    raise SystemExit(f"couldn't build a reachable {name}")

def make(G, rooms, solid_tiles, seed=2091):
    """Append the generated rooms; returns [(room index, gap, level)]."""
    rng = random.Random(seed)
    placed = []
    for gap in range(2, 11):
        wing = gap // 2
        for level in range(4):
            name = NAMES[wing].pop(0)
            rm = build_room(G, wing, name, rng, name == SPLICE_NAME[wing], solid_tiles)
            rooms.append(rm)
            placed.append((len(rooms) - 1, gap, level))
    return placed
