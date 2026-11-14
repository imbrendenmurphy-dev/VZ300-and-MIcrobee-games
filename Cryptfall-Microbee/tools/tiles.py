"""The one list of CRYPTFALL's cave tiles: numbers, map characters, pictures,
rules.  The game (src/tiles.inc, generated), the cave compiler and the test
bot all take it from here.

A cave is painted from these.  Scenery comes in several looks that behave
alike (four earths, three walls, three stone blocks, two kinds of steel),
each coloured per cave, so a cave can draw a picture.  A cave may use up to
31 different pictures at once; the compiler works out which.
"""
F_ROUND, F_HARD, F_ENEMY, F_SOFT, F_PICKUP, F_GEM, F_SOLID = 1, 2, 4, 8, 16, 32, 64

# (name, map character, picture, flags)
TILES = [
    ('SPACE', ' ', None, F_SOFT),
    ('DIRT1', '.', 'DIRT1', F_SOFT), ('DIRT2', ',', 'DIRT2', F_SOFT), ('DIRT3', ':', 'DIRT3', F_SOFT), ('DIRT4', ';', 'DIRT4', F_SOFT),
    ('WALL1', 'W', 'WALL1', F_ROUND | F_SOLID), ('WALL2', 'V', 'WALL2', F_ROUND | F_SOLID), ('WALL3', 'A', 'WALL3', F_ROUND | F_SOLID),
    ('BLOCK1', 'B', 'BLOCK1', F_SOLID), ('BLOCK2', 'N', 'BLOCK2', F_SOLID), ('BLOCK3', 'H', 'BLOCK3', F_SOLID),
    ('STEEL1', '#', 'STEEL1', F_HARD | F_SOLID), ('STEEL2', '%', 'STEEL2', F_HARD | F_SOLID),
    ('EXITC', 'X', 'EXITC', F_HARD | F_SOLID), ('EXITO', None, 'EXITO', F_HARD),
    ('CRACKED', 'c', 'CRACKED', F_ROUND | F_SOLID), ('MAGIC', 'm', 'MAGIC', F_SOLID), ('DOOR', 'D', 'DOOR', F_SOLID),
    ('KEY', 'y', 'KEY', F_PICKUP), ('CHALICE', '$', 'CHALICE', F_PICKUP), ('CROWN', 'C', 'CROWN', F_PICKUP),
    ('WARD', '+', 'WARD', F_PICKUP), ('HOURGLASS', 'h', 'HOURGLASS', F_PICKUP), ('HEART', 'v', 'HEART', F_PICKUP),
    # --- from here on the cave scan visits the tile
    ('BOULDER', 'o', 'BOULDER', F_ROUND), ('BOULDERF', None, 'BOULDER', 0),
    ('SLAB', 'q', 'SLAB', 0), ('SLABF', None, 'SLAB', 0),
    ('URN', 'u', 'URN', F_ROUND), ('URNF', None, 'URN', 0),
    ('KEG', 'T', 'KEG', F_ROUND), ('KEGF', None, 'KEG', 0), ('KEGLIT', None, 'KEG', 0),
    ('GEM', '*', 'GEM', F_ROUND | F_PICKUP | F_GEM), ('GEMF', None, 'GEM', F_PICKUP | F_GEM),
    ('RUBY', 'r', 'RUBY', F_ROUND | F_PICKUP | F_GEM), ('RUBYF', None, 'RUBY', F_PICKUP | F_GEM),
    ('EMERALD', 'e', 'EMERALD', F_ROUND | F_PICKUP | F_GEM), ('EMERALDF', None, 'EMERALD', F_PICKUP | F_GEM),
    ('PLAYER', None, 'PLAYER', 0),
    ('GHOST', None, 'GHOST', F_ENEMY), ('GHOST1', None, 'GHOST', F_ENEMY), ('GHOST2', None, 'GHOST', F_ENEMY), ('GHOST3', 'g', 'GHOST', F_ENEMY),
    ('BAT', None, 'BAT', F_ENEMY), ('BAT1', None, 'BAT', F_ENEMY), ('BAT2', 'b', 'BAT', F_ENEMY), ('BAT3', None, 'BAT', F_ENEMY),
    ('KNIGHT', None, 'KNIGHT', F_ENEMY), ('KNIGHT1', 'k', 'KNIGHT', F_ENEMY), ('KNIGHT2', 'K', 'KNIGHT', F_ENEMY), ('KNIGHT3', None, 'KNIGHT', F_ENEMY),
    ('SKULL', 'z', 'SKULL', F_ENEMY),
    ('EXPL1', None, 'EXPL1', 0), ('EXPL2', None, 'EXPL2', 0), ('EXPL3', None, 'EXPL2', 0),
    ('GEXPL1', None, 'EXPL1', 0), ('GEXPL2', None, 'EXPL2', 0), ('GEXPL3', None, 'EXPL2', 0),
    ('SLIME', 's', 'SLIME', 0),
    ('INBOX', 'P', 'PLAYER', F_HARD),
    ('COVER', None, 'COVER', 0),
]
assert len(TILES) <= 64
T = {n: i for i, (n, c, a, f) in enumerate(TILES)}
CH = {c: i for i, (n, c, a, f) in enumerate(TILES) if c}
NAME = {i: n for n, i in T.items()}
T_ACTIVE = T['BOULDER']

# colour overrides (the 4 cells) where a tile does not wear its picture's own
COLOURS = {'KEGLIT': [15] * 4, 'EXPL3': [9] * 4, 'GEXPL1': [15] * 4, 'GEXPL2': [14] * 4, 'GEXPL3': [13] * 4}

# every picture, in library order
ARTS = ['DIRT1', 'DIRT2', 'DIRT3', 'DIRT4', 'WALL1', 'WALL2', 'WALL3', 'BLOCK1', 'BLOCK2', 'BLOCK3', 'STEEL1', 'STEEL2',
        'EXITC', 'EXITO', 'CRACKED', 'MAGIC', 'DOOR', 'KEY', 'CHALICE', 'CROWN', 'WARD', 'HOURGLASS', 'HEART',
        'BOULDER', 'SLAB', 'URN', 'KEG', 'GEM', 'RUBY', 'EMERALD', 'PLAYER', 'GHOST', 'BAT', 'KNIGHT', 'SKULL',
        'EXPL1', 'EXPL2', 'SLIME', 'COVER']
ART = {n: i for i, n in enumerate(ARTS)}
# pictures every cave needs
ALWAYS = ['PLAYER', 'COVER', 'EXPL1', 'EXPL2', 'EXITC', 'EXITO', 'STEEL1', 'GEM']
MAX_SLOTS = 31
# what the title and the help pages show
FE_SLOTS = ['DIRT1', 'WALL1', 'BOULDER', 'GEM', 'RUBY', 'EMERALD', 'PLAYER', 'GHOST', 'BAT', 'KNIGHT', 'SKULL', 'KEG',
            'CRACKED', 'SLIME', 'MAGIC', 'CHALICE', 'CROWN', 'WARD', 'HOURGLASS', 'HEART', 'KEY', 'DOOR', 'EXITO',
            'SLAB', 'URN', 'DIRT2', 'EXPL1', 'EXPL2', 'COVER', 'STEEL1', 'EXITC']
assert len(FE_SLOTS) <= MAX_SLOTS

# names a cave file may use in its theme: line
THEME = {'dirt1': 'DIRT1', 'dirt2': 'DIRT2', 'dirt3': 'DIRT3', 'dirt4': 'DIRT4', 'wall1': 'WALL1', 'wall2': 'WALL2',
         'wall3': 'WALL3', 'block1': 'BLOCK1', 'block2': 'BLOCK2', 'block3': 'BLOCK3', 'steel1': 'STEEL1',
         'steel2': 'STEEL2', 'boulder': 'BOULDER', 'slab': 'SLAB', 'cracked': 'CRACKED', 'grate': 'MAGIC', 'door': 'DOOR',
         'urn': 'URN', 'gate': 'EXITC'}
# tiles that wear the same colours as another when themed
THEME_ALSO = {'BOULDER': ['BOULDERF'], 'SLAB': ['SLABF'], 'URN': ['URNF'], 'STEEL1': ['COVER']}
