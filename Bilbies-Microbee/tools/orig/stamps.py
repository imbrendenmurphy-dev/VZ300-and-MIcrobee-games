"""BILBIES! scenery stamps: small pictures placed behind the action.
G green, Y yellow, R red, '.' see-through (the sky shows).  VZ pixels are
tall (2 dots x 3 lines), so things are drawn squat.  Widths are multiples of 4."""

S = {}

S['windmill'] = [          # an outback windpump on its lattice tower
 "..Y.R.Y.........",
 "...YRY..........",
 ".RRRYRRR........",
 "...YRY.RRRRYY...",
 "..Y.R.Y....YY...",
 "....R...........",
 "...R.R..........",
 "...RRR..........",
 "...R.R..........",
 "..R.R.R.........",
 "..RR.RR.........",
 "..R.R.R.........",
 ".R..R..R........",
 ".RR.R.RR........",
 ".R..R..R........",
 "R...R...R.......",
 "RRRRRRRRR.......",
]

S['tank'] = [              # corrugated water tank on a timber stand
 "..YYYYYYYY..",
 ".YRYRYRYRYY.",
 ".YRYRYRYRYY.",
 ".YRYRYRYRYY.",
 ".YRYRYRYRYY.",
 ".RRRRRRRRRR.",
 ".R.R....R.R.",
 ".R..R..R..R.",
 ".R...RR...R.",
 ".R..R..R..R.",
]

S['shed'] = [              # a tin shed with a lean-to
 "......YYYYYYYYYY....",
 "....YYYYYYYYYYYYYY..",
 "..YYYYYYYYYYYYYYYYYY",
 "..RYRYRYRYRYRYRYRYR.",
 "..RYRYRYRRRRRYRYRYR.",
 "..RYRYRYR...RYRYRYR.",
 "..RYRYRYR...RYRYRYR.",
 "..RYRYRYR...RYRYRYR.",
]

S['grasstree'] = [         # a grass tree: spiky crown, black-ish trunk, flower spike
 "...Y....",
 "...Y....",
 "...Y....",
 "...Y....",
 ".G.R.G..",
 "G.GRG.G.",
 ".GGGGG..",
 "G.GRG.G.",
 "...R....",
 "...R....",
 "..RRR...",
]

S['roo'] = [               # a kangaroo, side on
 "......R.",
 ".....RRR",
 "....RRR.",
 "...RRR..",
 "..RRRR..",
 ".RRRRR..",
 "RR.RR...",
 "R..R.R..",
 "..RR.RR.",
]

S['emu'] = [               # an emu
 "...RR...",
 "...RY...",
 "...R....",
 "...R....",
 "..RRR...",
 ".RRRRR..",
 "RRRRRRR.",
 ".RRRRR..",
 "..R.R...",
 "..R.R...",
 ".RR.RR..",
]

S['galahs'] = [            # birds flying over
 "R.R.........",
 ".R.....Y.Y..",
 "........Y...",
 "....R.R.....",
 ".....R......",
]

S['wattle'] = [            # a wattle bush in flower
 "...GYGG.....",
 ".GYGGYGYG...",
 "GYGGYGGGYG..",
 ".GGYGGYGGYG.",
 "..GG.R.GGG..",
 ".....R......",
]

S['banksia'] = [           # a banksia shrub with its cones
 "..G.G.G.....",
 ".GGYGGGG....",
 "GGYYGGYGG...",
 ".GYGGGYYG...",
 "..GGRGGG....",
 "....R.......",
]

S['boab'] = [              # a boab: fat bottle trunk, little crown
 "..G.G..G.G......",
 ".GRGG.GGRG......",
 "..GR.G.R.G......",
 "....RRR.........",
 "...RRYRR........",
 "..RRYRRRR.......",
 "..RYRRRRR.......",
 "..RRRRYRR.......",
 "..RRRRRRR.......",
 "...RRRRR........",
]

S['sign'] = [              # BILBY CROSSING: a yellow diamond with a bilby
 "....Y...",
 "...YYY..",
 "..YRYRY.",
 ".YYRRRYY",
 "..YRRRY.",
 "...YYY..",
 "....R...",
 "....R...",
 "....R...",
]

S['mailbox'] = [           # a drum letterbox on a post
 ".RRRR...",
 "RYYYYR..",
 "RYYYYR..",
 ".RRRR...",
 "..R.....",
 "..R.....",
 "..R.....",
]

S['fence'] = [             # posts and wire
 "R.......R.......",
 "RYYYYYYYRYYYYYYY",
 "R.......R.......",
 "RYYYYYYYRYYYYYYY",
 "R.......R.......",
]

S['hoist'] = [             # a rotary clothes line with the washing out
 "RRRRRRRRRRRR",
 "..R..R..R...",
 ".YY..G..YRR.",
 ".YY..G..YRR.",
 ".....R......",
 ".....R......",
 ".....R......",
 "....RRR.....",
]

S['moon'] = [
 ".YYY....",
 "YY......",
 "YY......",
 ".YYY....",
]

S['cross'] = [             # the Southern Cross and the pointers
 "......Y.........",
 "................",
 "..Y.............",
 ".........Y......",
 ".......Y........",
 "................",
 "......Y.........",
 "................",
 "...............Y",
 "............Y...",
]

S['mound'] = [             # a little termite mound
 "..R.....",
 "..RR....",
 ".RRYR...",
 ".RRRR...",
 "RRYRRR..",
 "RRRRRR..",
]

S['chimney'] = [           # the stone chimney of a ruined homestead
 "..YRY...",
 "..RYR...",
 "..YRY...",
 "..RYR...",
 ".YRYRY..",
 ".RYRYR..",
 "YRYRYRY.",
 "RY...YR.",
 "YR...RY.",
 "RYRYRYR.",
]

S['campfire'] = [          # a campfire with the billy on
 "..Y.....",
 ".RYR.Y..",
 ".RRR.RY.",
 "RYRYRYR.",
 "RRRRRRR.",
]

S['tent'] = [              # a swag tent
 "....R.......",
 "...RYR......",
 "..RYYYR.....",
 ".RYYRYYR....",
 "RYYYRYYYR...",
]

S['prop'] = [              # goldfields mine timbers
 "RRRRRRRRRRRR",
 "RRRRRRRRRRRR",
 ".R........R.",
 ".R.R....R.R.",
 ".RR......RR.",
 ".R........R.",
 ".R........R.",
 ".R........R.",
 ".R........R.",
 ".R........R.",
 ".R........R.",
 ".R........R.",
]

S['cart'] = [              # an ore cart on its rails
 ".RRRRRRR....",
 ".RYRYRYR....",
 ".RRRRRRR....",
 "..Y...Y.....",
 "YRYRYRYRYRYR",
]

S['lantern'] = [           # a miner's lamp on a hook
 "..R.....",
 ".RRR....",
 ".YYY....",
 ".YYY....",
 ".RRR....",
]

S['pick'] = [              # pick and shovel leant on the wall
 "RRRR....",
 "R..RY...",
 "...RY...",
 "...RY...",
 "...RYY..",
 "...R....",
]

S['nugget'] = [            # a glint of gold in the rock
 "..Y.....",
 ".YYY....",
 "YYYYY...",
 ".YYY....",
 "..Y.....",
]

S['bats'] = [              # bats asleep upside down
 "R...R...R...",
 "RR..RR..RR..",
 "RR..RR..RR..",
 ".R...R...R..",
]

S['heron'] = [             # a heron in the reeds
 "..RR....",
 "...R....",
 "...R....",
 "..RRR...",
 ".RRRRR..",
 "...R....",
 "...R....",
 "..R.R...",
]

NAMES = list(S)

def check():
    for n, rows in S.items():
        w = len(rows[0])
        assert w % 4 == 0, n
        assert all(len(r) == w for r in rows), n
        assert w // 4 * len(rows) <= 256, n

# ---- big set pieces (up to 256 bytes each: the builder's buffer) ------------

def _blank(w, h):
    return [['.'] * w for _ in range(h)]

def _uluru():
    """the great red rock on the horizon: long flat dome, steep ends,
    lit along the top, gullies down its face"""
    w, h = 80, 12
    g = _blank(w, h)
    prof = []
    for x in range(w):
        if x < 3 or x > 76: prof.append(h); continue
        d = min(x - 3, 76 - x)
        top = h - 1 - d if d < 9 else 2
        if d >= 9 and 24 < x < 52: top = 1
        if 34 < x < 44: top = 0
        prof.append(max(0, top))
    for x in range(w):
        for y in range(prof[x], h):
            g[y][x] = 'R'
        if prof[x] < h:
            g[prof[x]][x] = 'Y'
    for x in (13, 20, 28, 35, 42, 49, 57, 64):
        for y in range(prof[x] + 2, h - 1, 2):
            g[y][x] = 'Y'
    for x in range(w):
        if x % 3 == 0: g[h - 1][x] = 'G'
    return [''.join(r) for r in g]

def _harbour_house():
    """the sails of the opera house on its podium, seen across the water"""
    w, h = 48, 14
    g = _blank(w, h)
    base = 10
    # (left foot, apex x, apex row, right foot): sails lean to the right
    sails = [(4, 10, 3, 13), (10, 16, 1, 19), (16, 21, 4, 23),
             (24, 29, 4, 32), (30, 35, 2, 38), (36, 39, 6, 41)]
    for x0, ax, ay, x1 in sails:
        for y in range(ay, base):
            t = (y - ay) / (base - ay)
            l = round(ax + (x0 - ax) * t)
            r = round(ax + (x1 - ax) * (t ** 0.6))
            for x in range(l, r + 1):
                g[y][x] = 'R' if x in (l, r) or y == ay else 'Y'
    for x in range(2, 44):
        g[base][x] = 'R'
        g[base + 1][x] = 'Y' if x % 4 else 'R'
    for x in range(0, 46):
        g[base + 2][x] = 'R'
        g[base + 3][x] = 'R' if (x // 2) % 2 else 'Y'
    return [''.join(r) for r in g]

S['uluru'] = _uluru()
S['harbour'] = _harbour_house()

S['homestead'] = [         # a station homestead: iron roof, verandah all round
 "............RR..........................",
 "............RR..........................",
 "........YYYYRRYYYYYYYYYYYYYYYYYY........",
 "......YRYRYRYRYRYRYRYRYRYRYRYRYRYY......",
 "....YRYRYRYRYRYRYRYRYRYRYRYRYRYRYRYY....",
 "..YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY..",
 "..R.....R.......R..........R.......R....",
 "..R.YYYYR.RRRRR.R..YYYYYY..R..RRRR.R....",
 "..R.YRYYR.RYRYR.R..YRRRRY..R..RYRY.R....",
 "..R.YYYYR.RYRYR.R..YRRRRY..R..RYRY.R....",
 "..R.YYYYR.RRRRR.R..YRRRRY..R..RRRR.R....",
 "..RYYYYYRYYYYYYYRYYYYYYYYYYRYYYYYYYR....",
 "..RRRRRRRRRRRRRRRRRRRYYRRRRRRRRRRRRR....",
 "..R...............RYYYYR..........R.....",
]

S['pine'] = [              # a Norfolk pine on the foreshore
 ".....G......",
 "....GGG.....",
 "...G.R.G....",
 ".....G......",
 "..GGGRGGG...",
 ".G...R...G..",
 "....GRG.....",
 ".GGGGRGGGG..",
 "G....R....G.",
 "...GGRGG....",
 "GGGG.R.GGGG.",
 ".....R......",
 ".....R......",
 "....RRR.....",
]

S['flags'] = [             # swim between the flags
 "RRR.....",
 "YYYR....",
 "...R....",
 "...R....",
 "...R....",
 "..RRR...",
]

S['umbrella'] = [          # a beach umbrella and towel
 "...RYRYR....",
 ".RYRYRYRYR..",
 "R....R....R.",
 ".....R......",
 ".....R......",
 "..YRYRYRY...",
]

S['surfboards'] = [        # boards stood up in the sand
 ".Y..R...",
 "YRY.RY..",
 "YRY.RY..",
 "YRY.RY..",
 "YRY.RY..",
 ".Y..R...",
]

S['tower'] = [             # the lifesavers' tower
 "RRRRRRRR....",
 "RYYYYYYR....",
 "RY.RR.YR....",
 "RYYYYYYR....",
 ".R.R.R.R....",
 ".RR...RR....",
 ".R.R.R.R....",
 ".R..R..R....",
 ".R.R.R.R....",
 ".RR...RR....",
]

NAMES = list(S)

# ---- more set pieces ----------------------------------------------------------

def _arch_bridge():
    """a big steel arch bridge with stone pylons at each end"""
    w, h = 64, 14
    g = _blank(w, h)
    deck = 9
    for x in range(8, 56):
        t = (x - 31.5) / 24.0
        top = round(1 + 7 * t * t)          # upper chord
        bot = round(4 + 5 * t * t)          # lower chord
        g[top][x] = 'R'
        if bot < deck: g[bot][x] = 'R'
        if x % 3 == 0:
            for y in range(top, min(bot, deck) + 1): g[y][x] = 'R'
        if x % 4 == 0 and bot < deck:
            for y in range(bot, deck): g[y][x] = 'R'
    for x in range(0, w):
        g[deck][x] = 'Y'
        g[deck + 1][x] = 'R'
    for x0 in (3, 56):                      # pylons
        for y in range(3, h):
            for x in range(x0, x0 + 5):
                g[y][x] = 'Y' if (x + y) % 4 else 'R'
        for x in range(x0, x0 + 5): g[3][x] = 'R'
    for y in range(deck + 2, h):
        for x in (12, 20, 44, 52): g[y][x] = 'R'
    return [''.join(r) for r in g]

S['bridge'] = _arch_bridge()

S['lighthouse'] = [        # a lighthouse on the headland
 "....YYY.....",
 "...RYYYR....",
 "...RRRRR....",
 "....YYY.....",
 "....RRR.....",
 "....YYY.....",
 "....RRR.....",
 "...YYYYY....",
 "...RRRRR....",
 "...YYYYY....",
 "...RRRRR....",
 "..YYYYYYY...",
 "..RRRRRRR...",
 ".RRRRRRRRR..",
]

S['pub'] = [               # a two-storey country pub with iron lace verandahs
 "......RRRRRRRRRRRRRRRRRRRRRRRRRRRR......",
 "......RYYYYYYYYYYYYYYYYYYYYYYYYYYR......",
 "....RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR....",
 "....RYRY.YRY.YRY.YRY.YRY.YRY.YRY.YR....",
 "....R.R..RR..RR..RR..RR..RR..RR..R.R....",
 "....RYYRYYYYRYYYYRYYYYRYYYYRYYYYRYYR....",
 "....RYYRYRRYRYYYYRYRRYRYYYYRYRRYRYYR....",
 "....RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR....",
 "....RYRY.YRY.YRY.YRY.YRY.YRY.YRY.YR....",
 "....R.R..RR..RR..RR..RR..RR..RR..R.R....",
 "....RYYRYYYYRYRRRRRRYYYYRYYYYRYYYYYR....",
 "....RYYRYRRYRYR..RRRYRRYRYRRYRYYYYYR....",
 "....RYYRYRRYRYR..RRRYRRYRYRRYRYYYYYR....",
 "....RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR....",
]

S['headframe'] = [         # a goldfields poppet head with its winding wheel
 "......RRRR..........",
 ".....R.YY.R.........",
 ".....RY..YR.........",
 ".....R.YY.R.........",
 "......RRRR..........",
 "......R..R..........",
 ".....R.RR.R.........",
 ".....RR..RR.R.......",
 ".....R.RR.R..R......",
 "....R..RR..R..R.....",
 "....RRR..RRR...R....",
 "....R..RR..R....R...",
 "...R...RR...R....R..",
 "...RRRRRRRRRR.....R.",
 "..RYYYYYYYYYYR......",
 "..RYRRYYYYRRYR......",
 "..RYRRYYYYRRYR......",
 "..RRRRRRRRRRRR......",
]

S['roadtrain'] = [         # a road train: prime mover and three trailers
 "..........YYYYYYYY.YYYYYYYY.YYYYYYYY....",
 "...RRRR...YRYRYRYY.YRYRYRYY.YRYRYRYY....",
 "..RYYRR...YRYRYRYY.YRYRYRYY.YRYRYRYY....",
 ".RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR...",
 ".RRRRRRR...YYYYYYY..YYYYYYY..YYYYYYY....",
 "..R.R.R.....R.R..R...R.R..R...R.R..R....",
]

S['steamer'] = [           # a paddle steamer on the river
 "........RR......................",
 "........RR......R...............",
 "........YY......R...............",
 "...RRRRRRRRRRRRRRRRRRRRRRRR.....",
 "...RY.Y.Y.Y.Y.Y.Y.Y.Y.Y.YR......",
 "..RRRRRRRRRRRRRRRRRRRRRRRRRR....",
 "..RYYYYYYYYYYYYYYYYRRRRYYYYYRR..",
 ".RYYYYYYYYYYYYYYYYRYRYRYYYYYYYR.",
 "..RRRRRRRRRRRRRRRRRRRRRRRRRRRR..",
]

S['waverock'] = [          # a great granite wave, streaked down its face
 "........RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR..",
 "....RRRRYRYYRYYRYYRYYRYYRYYRYYRYYRYYRYYRYYRYYRR.",
 "..RRYYRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRYRRR",
 ".RYR..RYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRRR",
 ".RR....RYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRR",
 "........RYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRRRR",
 ".........RYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRRR",
 "........RRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRYRRRR",
 "......RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR",
 "....RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR",
]

S['stacks'] = [            # limestone sea stacks off the cliffs
 "....YYY.........................",
 "...YRYYY..............YY........",
 "...YYRYY.............YRYY.......",
 "...YRYYY.....YYY.....YYRY.......",
 "..YYYRYY....YRYYY....YRYY.......",
 "..YRYYYY....YYRYY...YYYRY.......",
 "..YYRYYY....YRYYY...YRYYYY......",
 ".YYYYRYY...YYYRYY...YYRYYY......",
 ".YRYYYYYY..YRYYYY..YYYRYYY.YY...",
 "YYYRYYRYYY.YYRYYYY.YRYYYRYYRYY..",
]

S['dunny'] = [             # the outback dunny, moon on the door
 ".RRRRRR.",
 "RRRRRRRR",
 ".RYYYYR.",
 ".RYRYYR.",
 ".RYYYYR.",
 ".RYYYYR.",
 ".RYYYRR.",
 ".RYYYYR.",
 ".RRRRRR.",
]

S['croc'] = [              # a saltie, just the eyes and the back showing
 "........RR.R.R.R.R.R....",
 ".RRYY..RRRRRRRRRRRRRRR..",
 "RRRRRRRRRRRRRRRRRRRRRRRR",
]

S['woolshed'] = [          # a shearing shed with its sheep yards
 ".........RRRRRRRRRRRRRRRRRRRR...........",
 ".......RRYRYRYRYRYRYRYRYRYRYRRR.........",
 ".....RRYRYRYRYRYRYRYRYRYRYRYRYRRR.......",
 "...RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR.....",
 "....RYRYRYRYRYRYRYRYRYRYRYRYRYRYRY......",
 "....RYRYRYRRRRRYRYRYRYRYRRRRRYRYRY......",
 "....RYRYRYR...RYRYRYRYRYR...RYRYRYYYYYYY",
 "....RYRYRYR...RYRYRYRYRYR...RYRYRYR.R.R.",
 "....RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRYYYYY",
 "...................................R.R.R",
]

S['silos'] = [             # grain silos by the railway
 "..YYYY..YYYY..YYYY......",
 ".YRRRRY.YRRRRY.YRRRRY...",
 ".YRYYRY.YRYYRY.YRYYRY...",
 ".YRYYRY.YRYYRY.YRYYRY...",
 ".YRYYRY.YRYYRY.YRYYRY...",
 ".YRYYRY.YRYYRY.YRYYRY...",
 ".YRYYRY.YRYYRY.YRYYRY...",
 ".YRYYRY.YRYYRY.YRYYRY...",
 ".YRYYRY.YRYYRY.YRYYRY...",
 ".YRRRRY.YRRRRY.YRRRRY...",
 "..R..R...R..R...R..R....",
 "YRYRYRYRYRYRYRYRYRYRYRYR",
]

S['church'] = [            # a little bush church, now a ruin
 "..........Y.............",
 ".........RYR............",
 "..........R.............",
 ".........RRR............",
 "........RYYYR...........",
 ".......RYYYYYR..........",
 "......RRRRRRRRR.........",
 "......RY.Y.Y.YR.R..R....",
 "......RY.R.R.YR.RR.RR...",
 "......RYYYYYYYRYYRYYR...",
 "......RYRRYYRRYYRYRYR...",
 "......RYR.YYR.YYRYYYR...",
 "......RRRRRRRRRRRRRRRR..",
]

S['camels'] = [            # a camel string in the heat haze
 "...RR...........RR..............",
 "..RRR..RR......RRR..RR..........",
 ".RR...RRRR....RR...RRRR.........",
 ".R...RRRRRR...R...RRRRRR........",
 ".RRRRRRRRRR...RRRRRRRRRR........",
 "..RRRRRRRR.....RRRRRRRR.........",
 "..R..R.R.R.....R..R.R.R.........",
 "..R..R.R.R.....R..R.R.R.........",
]

S['ute'] = [               # the farm ute
 "...RRRR.........",
 "..RYYRR.........",
 ".RRRRRRRRRRRRRR.",
 ".RRRRRRRRRRRRRR.",
 "..YY.......YY...",
]

NAMES = list(S)

for _n, _rows in S.items():
    _w = max(len(r) for r in _rows)
    _w = (_w + 3) // 4 * 4
    S[_n] = [r.ljust(_w, '.') for r in _rows]
NAMES = list(S)
check()
