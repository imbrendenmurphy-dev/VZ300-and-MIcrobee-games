"""ZEPHYR ZONE artwork - original designs in the chunky, bold-outlined MZ-700 arcade spirit.
Grids: '.' transparent, 'g' 0 (ground light: green / buff), 'y' 1 (yellow / cyan),
'b' 2 (blue / magenta), 'r' 3 (red / orange; outlines & accents).
Each world remaps the colour indices of the sprites at load time when it wants to."""
C = {'.': -1, 'g': 0, 'y': 1, 'b': 2, 'r': 3}

def grid(s):
    rows = [r for r in s.strip('\n').split('\n')]
    rows = [r.strip() for r in rows if r.strip()]
    w = max(len(r) for r in rows)
    return [[C[ch] for ch in r.ljust(w, '.')] for r in rows]

def mirror(g): return [list(reversed(r)) for r in g]

# ---------------------------------------------------------------- the hero: ZEPHYR
# seen from behind, flying away from us: round helmet with goggle strap, red scarf
# streaming, blue jet-pack with twin nozzles, yellow flight suit, red boots.
HERO_FLY = grid("""
.....rrrr.....
...rrbbbbrr...
..rbbbybbbbr..
..rbbbbbbbbr..
..rrrrrrrrrr..
..rrbbbbbbrr..
.rrrrrbbrrrrr.
ryyrbbbbbbryyr
ryyrbyybbbryyr
ryyrbbbbbbryyr
ryrrbbbbbbrryr
rrr.rbbbbr.rrr
....rbrrbr....
....ryrryr....
...ryyrryyr...
...ryyr.ryyr..
...ryyr..ryr..
..ryyr...ryr..
..rrrr...rrr..
""")
