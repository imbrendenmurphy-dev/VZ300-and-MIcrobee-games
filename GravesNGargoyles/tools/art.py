# GRAVES 'N' GARGOYLES - pixel art definitions (mode 1, 128x64, CSS0: g=green y=yellow b=blue r=red)
# '.' = transparent in sprites. Tiles are 8x8, sprites as listed.

TILES = {}
def tile(name, rows):
    assert len(rows) == 8 and all(len(r) == 8 for r in rows), name
    TILES[name] = rows

tile('sky', ['bbbbbbbb']*8)
tile('star1', ['bbbbbbbb','bbbbbbbb','bbbybbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbyb','bbbbbbbb'])
tile('star2', ['bbbbbbbb','byybbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbybb','bbbbbbbb','bbbbbbbb'])
# distant hills: dithered silhouettes
tile('hill_t', ['bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbgb','bbbbgbgg','bbgbgggg','gbgggggg'])
tile('hill_m', ['gbgggggg','bgggbggg','gggggggb','ggbggggg','gggggbgg','gbgggggg','ggggbggg','gggggggg'])
tile('hill_l', ['bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bgbbbbbb','ggbgbbbb','ggggbgbb','gggggggb'])
tile('hill_r', ['bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb'])
# castle silhouette (distant, on the hill) - red
tile('cast_a', ['bbbbbbbb','bbrbbrbb','bbrrrrbb','bbrrrrbb','bbryrrbb','rbrrrrbr','rrrrrrrr','rrrrrrrr'])
tile('cast_b', ['bbbrbbbb','bbrrrbbb','bbbrbbbb','brbrbrbb','brrrrrbb','brryrrbb','brrrrrbr','rrrrrrrr'])
# ground
tile('grass', ['gbgbgggb','gggggggg','gyggrggg','rgrgrgrg','grgrgrgr','rbrrrbrr','rrbrrrrb','brrrbrrr'])
tile('dirt',  ['rrbrrrbr','rbrrrrrr','rrrrbrrb','brrrrrrr','rrrbrrbr','rrrrrrrr','rbrrbrrr','rrrrrrbr'])
tile('dirt_bone', ['rrbrrrbr','rggrrrgr','rrrgggrb','brrrrrgr','rrrbrrbr','rrrrrrrr','rbrrbrrr','rrrrrrbr'])
tile('dirt_skull',['rrbrrrbr','rrrggrrr','rrggggrb','rrgbgbrr','rrggggrr','rrrgbrrr','rbrrbrrr','rrrrrrbr'])
tile('grass_l', ['bbbbgbgg','bbgggggg','bggygggg','rgrgrgrg','grgrgrgr','rbrrrbrr','rrbrrrrb','brrrbrrr'])
tile('grass_r', ['gbgbbbbb','ggggggbb','gyggrggb','rgrgrgrg','grgrgrgr','rbrrrbrr','rrbrrrrb','brrrbrrr'])
# stone blocks (crypt / walls)
tile('stone', ['ggggggbg','gyyyygbg','gyggggbg','gggggggg','bbgbbbbb','ggggbggg','yggggbgy','ggggggbg'])
tile('stone_top',['ygyygyyg','gggggggg','gyggggbg','gggggggg','bbgbbbbb','ggggbggg','yggggbgy','ggggggbg'])
# gravestones (solid)
tile('grave_t', ['bbyyyybb','byybbyyb','ybbyybbr','ybyyyybr','ybbyybbr','ybbyybbr','ybbbbbbr','ybbbbbbr'])   # stone outline, dark face
tile('grave_b', ['ybbbbbbr','ybrbbrbr','ybbbbbbr','ybbbbbbr','yrrrrrrr','yrrrrrrr','gyggyggg','gggggggg'])
tile('cross_t', ['bbbggbbb','bbbgybbb','bgggggbb','bgyyygbb','bbbggbbb','bbbgybbb','bbbggbbb','bbbggbbb'])
tile('cross_b', ['bbbggbbb','bbbgybbb','bbbggbbb','bbbggbbb','bbggggbb','bggyyggb','gggggggg','rgrgrgrg'])
# dead tree (background, not solid)
tile('tree_top',['bbbbbbbb','brbbbbrb','bbrbbrbb','bbbrrbbb','bbbrrbrb','rbbrrrbb','brbrrbbb','bbrrrbbb'])
tile('tree_mid',['bbbrrbbb','bbbrrbbb','brrrrbbb','bbbrrbbb','bbbrrrrb','bbbrrbbb','bbbrrbbb','bbrrrbbb'])
tile('tree_bot',['bbbrrbbb','bbbrrbbb','bbbrrbbb','bbrrrrbb','bbrrrrbb','brrbrrrb','gbgbgggb','gggggggg'])
# iron fence (background)
tile('fence', ['bybbbybb','byybbyyb','bybbbybb','yyyyyyyy','bybbbybb','bybbbybb','yyyyyyyy','bybbbybb'])
# crypt
tile('roof_l', ['bbbbbbbr','bbbbbrrr','bbbrrrrr','brrryrrr','rrrrrrrr','yyyyyyyy','gggggggg','ggbggggg'])
tile('roof_m', ['bbbyybbb','bbryyrbb','rrryyrrr','rrrrrrrr','rrrrrrrr','yyyyyyyy','gggggggg','ggggbggg'])
tile('roof_r', ['rbbbbbbb','rrrbbbbb','rrrrrbbb','rrryrrrb','rrrrrrrr','yyyyyyyy','gggggggg','gggggbgg'])
tile('door_t', ['gbbbbbbg','bbbbbbbb','bbbbbbbb','bbbybbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb'])
tile('door_b', ['bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbyb','bbbbbbbb','bbbbbbbb','bbbbbbbb','gbbbbbbg'])
tile('column', ['bgyyyygb','bggggggb','bgybbygb','bgybbygb','bgybbygb','bgybbygb','bggggggb','bgyyyygb'])
tile('pillar', ['gyybbyyg','gggggggg','gybbbbyg','gybbbbyg','gybbbbyg','gybbbbyg','gggggggg','gyybbyyg'])
# wooden platform (one way)
tile('plank', ['yyyyyyyy','rryrrryr','rrrrrrrr','brbbbbrb','bbbbbbbb','bbbbbbbb','bbbbbbbb','bbbbbbbb'])
tile('plank_post',['yyyyyyyy','rryrrryr','rrrrrrrr','bbbrrbbb','bbbrrbbb','bbbrrbbb','bbbrrbbb','bbbrrbbb'])
# bog (hazard)
tile('bog', ['bbbbbbbb','bbybbbbb','rgrbbrgr','grgrgrgr','rrgrrryr','grrrgrrr','rrrgrrrr','rgrrrrgr'])
tile('bog2',['bbbbbbbb','bbbbbyb'+'b','grrbgrrb','rgrgrgrg','rryrrrgr','rrrgrrrr','grrrrrgr','rrrrgrrr'])
# spikes (hazard)
tile('spikes',['bbbbbbbb','bbbbbbbb','bybbbybb','bybbbybb','yyybyyyb','yyyyyyyy','gggggggg','rgrgrgrg'])

# tile attributes: 0 none, 1 solid, 2 one-way platform, 3 hazard
TILE_ORDER = ['sky','star1','star2','hill_t','hill_m','hill_l','hill_r','cast_a','cast_b',
  'grass','dirt','dirt_bone','dirt_skull','grass_l','grass_r','stone','stone_top',
  'grave_t','grave_b','cross_t','cross_b','tree_top','tree_mid','tree_bot','fence',
  'roof_l','roof_m','roof_r','door_t','door_b','pillar','column','plank','plank_post','bog','bog2','spikes']
SOLID = {'grass','dirt','dirt_bone','dirt_skull','grass_l','grass_r','stone','stone_top',
         'grave_t','grave_b','roof_l','roof_m','roof_r','pillar'}
ONEWAY = {'plank','plank_post','cross_t'}
HAZARD = {'bog','bog2','spikes'}

# ---------------------------------------------------------------------------
# HERO: layered class art. body grid (12x16) + armour grid (12x16).
# body classes:  . none  S skin  r hair  e eye  U undies  y undie-heart
# armour classes: . none H helm h helm-trim v visor C chest c chest-trim
#   G leg (auto from legs)  g leg trim  O pauldron o pauldron-trim  P plume  Q crest
#   K cape  W wings
HEAD = [
 ('............', '...QPPP..WW.'),
 ('....rrrr....', '..QPHHHHHWW.'),
 ('...rrrSSS...', '...hHHHHHH..'),
 ('...rrSSeS...', '...HHHHvvH..'),
 ('...rSSSSS...', '...hHHHHHH..'),
 ('....SSSS....', '....hHHHh...'),
]
TORSO = {
 'down': [
 ('...SSSSSSS..', '..OOCCCCCOO.'),
 ('..SSSSSSSSS.', 'K.OoCCcCCoO.'),
 ('..SS.SSS.SS.', 'KKCC.CcC.CC.'),
 ('..SS.SSS.SS.', 'KKCC.CcC.CC.'),
 ('..SS.UUU.SS.', 'KK...cCc....'),
 ('....UUyUU...', 'KK..GGGGG...'),
 ],
 'swing': [
 ('...SSSSSSS..', '..OOCCCCCOO.'),
 ('..SSSSSSSSS.', 'K.OoCCcCCoO.'),
 ('.SS..SSS..SS', 'KCC..CcC..CC'),
 ('SS...SSS...S', 'CC...CcC...C'),
 ('S....UUU....', 'K....cCc....'),
 ('....UUyUU...', 'KK..GGGGG...'),
 ],
 'fwd': [
 ('...SSSSSSS..', '..OOCCCCCOO.'),
 ('..SSSSSSSSSS', 'K.OoCCcCCCCC'),
 ('..SS.SSS....', 'KKCC.CcC....'),
 ('..SS.SSS....', 'KKCC.CcC....'),
 ('..SS.UUU....', 'KK...cCc....'),
 ('....UUyUU...', 'KK..GGGGG...'),
 ],
 'up': [
 ('.S.SSSSSSS.S', '.C.OCCCCCO.C'),
 ('..SSSSSSSSS.', 'K.OoCCcCCoO.'),
 ('.....SSS....', 'KK...CcC....'),
 ('.....SSS....', 'KK...CcC....'),
 ('.....UUU....', 'KK...cCc....'),
 ('....UUyUU...', 'KK..GGGGG...'),
 ],
}
LEGS = {
 'stand': ['....SS.SS...','....SS.SS...','....SS.SS...','...SSS.SSS..'],
 'run1':  ['...SS..SS...','..SS....SS..','..SS.....SS.','.SSS......SS'],
 'run2':  ['....SSSS....','....SSS.....','.....SS.....','.....SSS....'],
 'jump':  ['...SS..SS...','..SS...SS...','..SSS..SSS..','............'],
}
def legrow(l):
    return (l, ''.join('G' if c == 'S' else '.' for c in l))
def hero_frame(torso, legs, dy=0, dx=0):
    rows = list(HEAD) + list(TORSO[torso]) + [legrow(l) for l in LEGS[legs]]
    b, a = rows[13]; rows[13] = (b, a.replace('G', 'g'))
    if dy:
        rows = [('.'*12, '.'*12)]*dy + rows[:16-dy]
    if dx:
        rows = [(b[dx:]+'.'*dx, a[dx:]+'.'*dx) for b, a in rows]
    assert len(rows) == 16 and all(len(b) == 12 and len(a) == 12 for b, a in rows)
    return rows

def crouch():
    rows = [('.'*12, '.'*12)]*3 + list(HEAD) + list(TORSO['down'][:4])
    for l in ['...SSSSSS...', '..SS....SS..', '.SSS....SSS.']:
        rows.append(legrow(l))
    assert len(rows) == 16
    return rows

HERO_FRAMES = [
 hero_frame('down', 'stand'),          # 0 stand
 hero_frame('swing', 'run1'),          # 1 run a
 hero_frame('down', 'run2'),           # 2 run b
 hero_frame('swing', 'run1', dy=1),    # 3 run c (bob)
 hero_frame('up', 'jump'),             # 4 jump
 hero_frame('fwd', 'stand'),           # 5 throw
 crouch(),                             # 6 crouch
 hero_frame('up', 'jump', dx=1),       # 7 hurt (knocked back)
]

BODY_COL = {'.': None, 'S': 'y', 'r': 'r', 'e': 'b', 'U': 'r', 'y': 'y'}
ARMOUR_CLASSES = '.HhvCcGgOoPQKW'
# armour level -> class -> colour (None = not worn)
def lvl(main, trim, pauld=False, crest=False, cape=False, wings=False):
    d = {'H': main, 'h': trim, 'v': 'b', 'C': main, 'c': trim, 'G': main, 'g': trim, 'P': 'r'}
    d['O'] = main if pauld else None
    d['o'] = trim if pauld else None
    d['Q'] = 'r' if crest else None
    d['K'] = 'r' if cape else None
    d['W'] = 'y' if wings else None
    return d
ARMOUR_LEVELS = [
 {},                                              # 0 undies
 lvl('y', 'b'),                                   # 1 tin: dull, battered
 lvl('y', 'g', pauld=True),                       # 2 steel
 lvl('y', 'r', pauld=True),                       # 3 enchanted (+sparkles)
 lvl('y', 'r', pauld=True, crest=True, cape=True),# 4 royal
 lvl('y', 'r', pauld=True, crest=True, cape=True, wings=True),  # 5 legendary
]
ARMOUR_NAMES = ['UNDIES', 'TIN', 'STEEL', 'ENCHANTED', 'ROYAL', 'LEGENDARY']

# ---------------------------------------------------------------------------
SPRITES = {}
def spr(name, *frames):
    fs = []
    for f in frames:
        w = len(f[0])
        assert all(len(r) == w for r in f), (name, [len(r) for r in f])
        fs.append(f)
    SPRITES[name] = fs

spr('zombie',
 ['....ggg.....','...ggggg....','...ggyggy...','...ggggg....','....gbg.....','...rrrrggggg',
  '..rrrrrr....','..rrgrrr....','..rrrrrr....','...rrrrr....','...rr.rr....','...gg.gg....','...gg..gg...','..ggg..ggg..'],
 ['....ggg.....','...ggggg....','...ggyggy...','...ggggg....','....gbg.....','...rrrrr....',
  '..rrrrrrgggg','..rrgrrr....','..rrrrrr....','...rrrrr....','...rr.rr....','...gg.gg....','..gg...gg...','.ggg...ggg..'],
)
spr('skel',
 ['....yyy.....','...yyyyy....','...ybyby....','...yyyyy....','....yry.....','.....y......',
  '..yyyyyyy...','..y.yyy.y...','..y.y.y.y...','....yyy.....','.....y......','....yyy.....','....y.y.....','....y.y.....','....y.y.....','...yy.yy....'],
 ['....yyy.....','...yyyyy....','...ybyby....','...yyyyy....','....yry.....','.....y......',
  '..yyyyyyy...','.y..yyy..y..','.y..y.y..y..','....yyy.....','.....y......','....yyy.....','...y...y....','..y.....y...','..y.....y...','.yy.....yy..'],
 # headless
 ['............','............','............','............','.....r......','.....y......',
  '..yyyyyyy...','..y.yyy.y...','..y.y.y.y...','....yyy.....','.....y......','....yyy.....','....y.y.....','....y.y.....','....y.y.....','...yy.yy....'],
 ['............','............','............','............','.....r......','.....y......',
  '..yyyyyyy...','.y..yyy..y..','.y..y.y..y..','....yyy.....','.....y......','....yyy.....','...y...y....','..y.....y...','..y.....y...','.yy.....yy..'],
)
spr('skull', ['.yyy....','yyyyy...','ybyby...','yyyyy...','.yry....','........'])
spr('bat',
 ['r..........r','rr..rrr...rr','rrrrryrrrrr.','.rrrrrrrrr..','...r...r....','............'],
 ['............','....rrr.....','..rrryrrr...','.rrrrrrrrr..','rr.r...r.rr.','r.........r.'],
)
spr('ghost',
 ['....yyyy....','...yyyyyy...','..yybyybyy..','..yybyybyy..','..yyyyyyyy..','..yyybbyyy..','..yyyyyyyy..','..yyyyyyyy..','..yyyyyyyy..','..yy.yy.yy..','..y..y..y...','............'],
 ['....yyyy....','...yyyyyy...','..yybyybyy..','..yybyybyy..','..yyyyyyyy..','..yyyyyyyy..','..yyybbyyy..','..yyyyyyyy..','..yyyyyyyy..','...yy.yy.yy.','....y..y..y.','............'],
)
spr('imp',
 ['.r........r.','.rr.rrrr.rr.','..rrryyrrr..','r.rrrrrrrr.r','rr.rrrrrr.rr','rrrrrgrrrrrr','.rrrrrrrrrr.','...rrrrrr...','...r....r...','..yy....yy..'],
 ['............','.r..rrrr..r.','.rrrryyrrrr.','rrrrrrrrrrrr','r..rrrrrr..r','...rrgrrr...','...rrrrrr...','...rrrrrr...','....r..r....','...yy..yy...'],
)
spr('crow',
 ['........','..rrr...','.rryrrr.','rrrrr...','..rrrr..','...yy...'],
 ['r......r','rr.rr.rr','.rryrrr.','..rrr...','...rr...','........'],
)
spr('plant',
 ['..rrrr....','.ryyyyr...','.r.yy.rr..','.ryyyyr...','..rrrr....','...gg.....','.gggg.....','..gg.gg...','...gg.....','..gggg....'],
 ['...rrrr...','..r....r..','.r.yyyy.r.','..ryyyyr..','...rrrr...','...gg.....','.gggg.....','..gg.gg...','...gg.....','..gggg....'],
)
# weapons
spr('lance',   ['.........y..','yyyyyyyyyyyy','.........y..'])
spr('lance2',  ['r..r.....yy.','ryyyyyyyyyyy','r..r.....yy.'])
spr('dagger',  ['....y...','yyyyyyy.','....y...'])
spr('dagger2', ['rr..yy..','ryyyyyyy','rr..yy..'])
spr('axe',
 ['..yy....','.yyyy...','yyrr....','...rr...','....rr..','.....r..','........','........'],
 ['........','..r.....','..rr....','...rr.yy','....yyyy','....yyy.','.....yy.','........'],
)
spr('torch', ['..yr....','.yrry...','..rr....','..yy....','..yy....','...y....'],
             ['..r.....','.yrry...','..ry....','...yy...','...yy...','....y...'])
spr('flame', ['..r..r..','.rr.ry..','.ryrry..','rryyyrr.','ryyyyyr.','.yyyyy..'],
             ['...r....','..rr.r..','.rryrr..','.ryyyrr.','rryyyyr.','.yyyyy..'])
spr('fireball', ['.rr.','ryyr','ryyr','.rr.'])
spr('spark', ['..y..','.yyy.','yyyyy','.yyy.','..y..'])
# pickups (8x8)
spr('coin', ['..yyy...','.yyyyy..','yyryryy.','yyyyyyy.','yyryryy.','.yyyyy..','..yyy...','........'],
            ['...y....','..yyy...','..yry...','..yyy...','..yry...','..yyy...','...y....','........'])
spr('jewel',['...r....','..rrr...','.rryrr..','rrryrrr.','.rrrrr..','..rrr...','...r....','........'])
spr('armour',['..ggg...','.gyyyg..','.gbbbg..','.ggggg..','gyyyyyg.','gyggg yg'.replace(' ','g'),'.ggggg..','.g...g..'])
spr('potion',['...yy...','...gg...','..rrrr..','.rryyrr.','.rrrrrr.','.rrrrrr.','..rrrr..','........'])
spr('wlance',['........','.......y','.yyyyyyy','.......y','........','.rrrrrr.','.r....r.','.rrrrrr.'])
spr('wdagger',['........','....y...','yyyyyyy.','....y...','........','.rrrrrr.','.r....r.','.rrrrrr.'])
spr('waxe',  ['..yy....','.yyyy...','.yrrr...','...rr...','....r...','.rrrrrr.','.r....r.','.rrrrrr.'])
spr('wtorch',['...r....','..ryr...','...y....','...y....','........','.rrrrrr.','.r....r.','.rrrrrr.'])
spr('heart', ['.rr.rr..','ryyrrrr.','ryrrrrr.','.rrrrr..','..rrr...','...r....','........','........'])
spr('chest',
 ['............','.rrrrrrrrrr.','ryyyyyyyyyyr','rrrrryrrrrrr','ryyyyyyyyyyr','rrrrryyrrrrr','rrrrrrrrrrrr','ryyyyyyyyyyr','rrrrrrrrrrrr','............'],
 ['.rrrrrrrrrr.','r..........r','.r.yy.yy.r..','r.yyyyyyy..r','ryyyyyyyyyyr','rrrrrrrrrrrr','rrrrrrrrrrrr','ryyyyyyyyyyr','rrrrrrrrrrrr','............'],
)
spr('checkpt',
 ['...yy...','..yrry..','...yy...','...rr...','...rr...','...rr...','..rrrr..','.gggggg.'],
 ['...yy...','..yyyy..','...yy...','...rr...','...rr...','...rr...','..rrrr..','.gggggg.'],
)
spr('moon', ['....yyyy....','..yyyyyyyy..','.yyyyyyygyy.','.yygyyyyyyy.','yyyyyyyyyyyy','yyyyygyyyyyy','yygyyyyyygyy','.yyyyyyyyyy.','.yyyyygyyyy.','..yyyyyyyy..','....yyyy....'])
spr('sunstone',
 ['.....yy.....','..y..yy..y..','...yyyyyy...','..yyrrrryy..','yyyrryyrryyy','yyyryyyyryyy','..yyrrrryy..','...yyyyyy...','..y..yy..y..','.....yy.....'],
 ['............','.....yy.....','...yyyyyy...','..yyrrrryy..','.yyrryyrryy.','.yyryyyyryy.','..yyrrrryy..','...yyyyyy...','.....yy.....','............'],
)
spr('pieces', ['gg..','gyg.','.gg.','....'], ['.g..','ggg.','.yg.','....'])
spr('bolt', ['..yy','.yy.','yyy.','.yy.','yy..','.y..','yy..','y...'])

# BOSS: GRAVEMAW - a giant skull with a separate jaw (32 x 20 + jaw 28 x 8)
BOSS_SKULL = [
 '..........yyyyyyyyyyyy..........',
 '.......yyyyyyyyyyyyyyyyyy.......',
 '.....yyyyyyyyyyyyyyyyyyyyyy.....',
 '....yyyyyyygyyyyyyyyyyyyyyyy....',
 '...yyyyyygyyyyyyyyyyyygyyyyyy...',
 '..yyyyyyyyyyyyyyyyyyyygyyyyyyy..',
 '..yyyyyyyyyyyyyyyyyyyyyyyyyyyy..',
 '.yyyyybbbbbbyyyyyyybbbbbbyyyyyy.',
 '.yyyybbbbbbbbyyyyybbbbbbbbyyyyy.',
 '.yyyybbbrrbbbyyyyybbbrrbbbyyyyy.',
 '.yyyybbrrrrbbyyyyybbrrrrbbyyyyy.',
 '.yyyybbbrrbbbyyyyybbbrrbbbyyyyy.',
 '.yyyyybbbbbbyyygyyybbbbbbyyyyyy.',
 '..yyyyyyyyyyyybbyyyyyyyyyyyyyy..',
 '..yyygyyyyyyybbbbyyyyyyyyygyyy..',
 '...yyyyyyyyyybbbbyyyyyyyyyyyy...',
 '....yyyyyyyyyyyyyyyyyyyyyyyy....',
 '.....ygygygygygygygygygygyg.....',
 '.....yyyyyyyyyyyyyyyyyyyyyy.....',
 '......y.y.y.y.y.y.y.y.y.y.......',
]
BOSS_JAW = [
 '......y.y.y.y.y.y.y.y.y.y.......',
 '.....yyyyyyyyyyyyyyyyyyyyyy.....',
 '.....ygygygygygygygygygygyg.....',
 '......yyyyyyyyyyyyyyyyyyyy......',
 '.......yyyyyyyyyyyyyyyyyy.......',
 '........yyyyyyyyyyyyyyyy........',
 '..........yyyyyyyyyyyy..........',
 '................................',
]
SPRITES['bskull'] = [BOSS_SKULL]
SPRITES['bjaw'] = [BOSS_JAW]

# 3x5 font in 4px cells. Characters: space 0-9 A-Z and punctuation
FONT = {
 ' ':['...','...','...','...','...'],
 '0':['###','#.#','#.#','#.#','###'], '1':['.#.','##.','.#.','.#.','###'],
 '2':['###','..#','###','#..','###'], '3':['###','..#','.##','..#','###'],
 '4':['#.#','#.#','###','..#','..#'], '5':['###','#..','###','..#','###'],
 '6':['###','#..','###','#.#','###'], '7':['###','..#','.#.','.#.','.#.'],
 '8':['###','#.#','###','#.#','###'], '9':['###','#.#','###','..#','###'],
 'A':['.#.','#.#','###','#.#','#.#'], 'B':['##.','#.#','##.','#.#','##.'],
 'C':['.##','#..','#..','#..','.##'], 'D':['##.','#.#','#.#','#.#','##.'],
 'E':['###','#..','##.','#..','###'], 'F':['###','#..','##.','#..','#..'],
 'G':['.##','#..','#.#','#.#','.##'], 'H':['#.#','#.#','###','#.#','#.#'],
 'I':['###','.#.','.#.','.#.','###'], 'J':['..#','..#','..#','#.#','.#.'],
 'K':['#.#','#.#','##.','#.#','#.#'], 'L':['#..','#..','#..','#..','###'],
 'M':['#.#','###','###','#.#','#.#'], 'N':['##.','#.#','#.#','#.#','#.#'],
 'O':['.#.','#.#','#.#','#.#','.#.'], 'P':['##.','#.#','##.','#..','#..'],
 'Q':['.#.','#.#','#.#','##.','.##'], 'R':['##.','#.#','##.','#.#','#.#'],
 'S':['.##','#..','.#.','..#','##.'], 'T':['###','.#.','.#.','.#.','.#.'],
 'U':['#.#','#.#','#.#','#.#','###'], 'V':['#.#','#.#','#.#','#.#','.#.'],
 'W':['#.#','#.#','###','###','#.#'], 'X':['#.#','#.#','.#.','#.#','#.#'],
 'Y':['#.#','#.#','.#.','.#.','.#.'], 'Z':['###','..#','.#.','#..','###'],
 '.':['...','...','...','...','.#.'], ',':['...','...','...','.#.','#..'],
 '!':['.#.','.#.','.#.','...','.#.'], '?':['##.','..#','.#.','...','.#.'],
 '-':['...','...','###','...','...'], ':':['...','.#.','...','.#.','...'],
 "'":['.#.','.#.','...','...','...'], '/':['..#','..#','.#.','#..','#..'],
 '(':['.#.','#..','#..','#..','.#.'], ')':['.#.','..#','..#','..#','.#.'],
 '*':['...','#.#','.#.','#.#','...'], '@':['###','#.#','#.#','#..','###'],  # @ = (c)
 '<':['..#','.#.','#..','.#.','..#'], '>':['#..','.#.','..#','.#.','#..'],
 '+':['...','.#.','###','.#.','...'], '=':['...','###','...','###','...'],
 '#':['###','###','###','###','###'], '%':['#.#','..#','.#.','#..','#.#'],
}
FONT_CHARS = ' 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ.,!?-:\'/()*@<>+=#%'
