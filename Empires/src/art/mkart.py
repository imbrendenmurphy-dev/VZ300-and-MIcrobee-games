#!/usr/bin/env python3
"""mkart.py - generates all PCG artwork + tables for EMPIRES (src/art.inc).

Each PCG character is 8x11 pixels (80x24 mode, 11 scanlines per row).
A map tile is 2 characters wide (16x11).  Every character carries default
fg/bg colours; the monochrome set is derived by luminance (the brighter
colour becomes the lit pixel), with explicit overrides where needed.

Global char index G: bank = G>>7, screen code = 0x80|(G&127).
Colour set lives in banks 0-7, mono set in banks 8-15 (same G + 1024).
"""
import random, os, json

# Premium palette (MAME premium_palette): 0-6 at C0, 8 dark grey, 9-15 at FF
PAL = []
for i in range(16):
    if i == 8: PAL.append((96,96,96)); continue
    lv = 0xFF if i >= 8 else 0xC0
    PAL.append(((lv if i&1 else 0),(lv if i&2 else 0),(lv if i&4 else 0)))
PAL[7] = (0xC0,0xC0,0xC0)
def lum(c): r,g,b = PAL[c]; return 0.3*r+0.59*g+0.11*b

BLACK,RED,GREEN,YELLOW,BLUE,MAGENTA,CYAN,GREY,DGREY,BRED,BGREEN,BYELLOW,BBLUE,BMAGENTA,BCYAN,WHITE = range(16)
def C(fg,bg): return (bg<<4)|fg

chars = []          # list of dicts: rows(11 ints), fg, bg, mono(rows or None)
names = {}

def rows_from(strs, w=8, on='#X@*o+'):
    out=[]
    for s in strs:
        s=s.ljust(w,'.')
        v=0
        for i in range(w):
            v=(v<<1)|(1 if s[i] in on else 0)
        out.append(v)
    assert len(out)==11, (len(out), strs)
    return out

def add(name, rows, fg, bg, mono=None, monoinv=None):
    g=len(chars)
    chars.append(dict(name=name,rows=rows,fg=fg,bg=bg,mono=mono,monoinv=monoinv))
    names[name]=g
    return g

def add_tile(name, strs16, fg, bg, fg2=None, bg2=None, mono16=None, monoinv=None):
    """16-wide x 11-high tile -> two chars name.L, name.R"""
    assert len(strs16)==11, name
    L=[s.ljust(16,'.')[:8] for s in strs16]
    R=[s.ljust(16,'.')[8:16] for s in strs16]
    mL=mR=None
    if mono16:
        mL=rows_from([s.ljust(16,'.')[:8] for s in mono16])
        mR=rows_from([s.ljust(16,'.')[8:16] for s in mono16])
    a=add(name+'.L',rows_from(L),fg,bg,mL,monoinv)
    add(name+'.R',rows_from(R),fg2 if fg2 is not None else fg,bg2 if bg2 is not None else bg,mR,monoinv)
    return a

def pad_to(g):
    while len(chars)<g: add('pad%d'%len(chars),[0]*11,WHITE,BLACK)

rnd=random.Random(1987)

def texture(density, seed, shapes=None, w=16):
    r=random.Random(seed)
    grid=[['.']*w for _ in range(11)]
    for y in range(11):
        for x in range(w):
            if r.random()<density: grid[y][x]='#'
    return [''.join(r_) for r_ in grid]

def stamp(grid, shape, x, y):
    g=[list(r) for r in grid]
    for dy,row in enumerate(shape):
        for dx,ch in enumerate(row):
            yy,xx=y+dy,x+dx
            if 0<=yy<11 and 0<=xx<len(g[0]) and ch!=' ':
                g[yy][xx]='#' if ch=='#' else '.'
    return [''.join(r) for r in g]

def blank(w=16): return ['.'*w for _ in range(11)]

# ---------------------------------------------------------------- terrain
# Terrain ids (must match src/defs.inc)
T_DEEP,T_SHALLOW,T_RIVER,T_BEACH,T_GRASS,T_MEADOW,T_FOREST,T_DENSE,T_HILLS,T_MOUNT,T_SNOW,T_DESERT,T_MARSH,T_FIELD,T_ROCK,T_RUINS = range(16)
TERR_NAMES=['DEEP SEA','SHALLOWS','RIVER','BEACH','GRASSLAND','MEADOW','FOREST','WOODLAND','HILLS','MOUNTAINS','SNOWFIELD','DESERT','MARSH','FARMLAND','ROCKS','RUINS']

terr_first={}   # terrain -> (firstG, nvariants)

BLADE=['#','#']
def grass_tile(seed, flowers=False):
    r=random.Random(seed)
    g=blank()
    for i in range(9 if not flowers else 6):
        x=r.randrange(0,15); y=r.randrange(1,10)
        g=stamp(g,['# #',' # '] if r.random()<0.5 else ['#',' #'],x,y) if False else g
        g=stamp(g,['#.#'.replace('.',' '),' # '] if r.random()<0.4 else ['# ','# '],x,y)
    if flowers:
        for i in range(4):
            x=r.randrange(1,14); y=r.randrange(1,9)
            g=stamp(g,[' # ','###',' # '],x,y)
    return g

def tree(): return [' ## ','####','####',' ## ',' ## ' ]
CONIFER=['  #  ',' ### ',' ### ','#####','#####','  #  ']
DECID=[' ### ','#####','#####','#####',' ### ','  #  ']

def forest_tile(seed, dense=False):
    r=random.Random(seed)
    g=blank()
    pos=[(0,0),(6,4),(11,0),(2,5),(10,5)] if not dense else [(0,-1),(5,0),(10,-1),(-1,4),(4,5),(9,5),(13,4)]
    for (x,y) in pos:
        x+=r.randrange(-1,2); y+=r.randrange(0,2)
        g=stamp(g, CONIFER if r.random()<(0.6 if dense else 0.4) else DECID, x,y)
    return g

def hills_tile(seed):
    r=random.Random(seed)
    g=blank()
    MOUND=['   ###   ','  #   #  ',' #     # ','#       #']
    g=stamp(g,MOUND,r.randrange(0,3),r.randrange(1,3))
    g=stamp(g,MOUND,r.randrange(7,9),r.randrange(5,7))
    for i in range(4):
        g=stamp(g,['#'],r.randrange(0,16),r.randrange(0,11))
    return g

def mountain_tile(seed):
    r=random.Random(seed)
    PEAK=['    #    ','   ###   ','  ## ##  ',' ##   ## ','##  #  ##','#  # #  #']
    g=blank()
    g=stamp(g,PEAK,r.randrange(-1,2),r.randrange(0,2))
    g=stamp(g,PEAK,r.randrange(7,9),r.randrange(4,6))
    return g

def snow_tile(seed):
    r=random.Random(seed)
    g=blank()
    PEAK=['    #    ','   # #   ','  #   #  ',' #     # ','#       #']
    g=stamp(g,PEAK,r.randrange(0,3),r.randrange(1,3))
    for i in range(5): g=stamp(g,['#'],r.randrange(0,16),r.randrange(0,11))
    return g

def desert_tile(seed):
    r=random.Random(seed)
    g=blank()
    DUNE=['  ####  ',' #    # ','#       ']
    g=stamp(g,DUNE,r.randrange(0,4),r.randrange(1,3))
    g=stamp(g,DUNE,r.randrange(7,9),r.randrange(6,8))
    for i in range(6): g=stamp(g,['#'],r.randrange(0,16),r.randrange(0,11))
    return g

def beach_tile(seed):
    r=random.Random(seed)
    g=blank()
    for i in range(14): g=stamp(g,['#'],r.randrange(0,16),r.randrange(0,11))
    g=stamp(g,['##'],r.randrange(2,12),r.randrange(2,9))
    return g

def marsh_tile(seed):
    r=random.Random(seed)
    g=blank()
    REED=['# #','# #','###',' # ']
    for i in range(4): g=stamp(g,REED,r.randrange(0,14),r.randrange(0,7))
    g=stamp(g,['  ####  ','########'],r.randrange(0,8),9)
    return g

def field_tile(seed):
    g=[]
    for y in range(11):
        if y%3==1: g.append('#.##.##.#.##.##.')
        elif y%3==2: g.append('.#..#..#..#..#..')
        else: g.append('................')
    return g

def rock_tile(seed):
    r=random.Random(seed)
    g=blank()
    ROCK=[' ## ','####','### ']
    for i in range(3): g=stamp(g,ROCK,r.randrange(0,13),r.randrange(0,8))
    return g

def ruins_tile(seed):
    return ['................',
            '..#.......##....',
            '..#.......##....',
            '.###..#...##.#..',
            '.#.#..#..###.#..',
            '.#.#.###.#.#.#..',
            '.#.#.#.#.#.#.##.',
            '##############..',
            '.#..#..#.#..#...',
            '................',
            '................']

def reg_terrain(t, maker, nvar, fg, bg, seedbase):
    first=len(chars)
    for v in range(nvar):
        add_tile('T%d_%d'%(t,v), maker(seedbase+v*31), fg, bg)
    terr_first[t]=(first,nvar)

# Bank 0 (G 0-127): water (animated) first so animation addresses are compact.
# ---- water: deep (4 chars: 2 variants) + shore/shallow 16 chars (8 L, 8 R)
WAVES = [
 ['................','..##........##..','................','.......##.......','................','.##..........##.','................','........##......','................','...##......##...','................'],
]
def wave_frame(frame, density=1, seed=0):
    r=random.Random(seed)
    g=[['.']*16 for _ in range(11)]
    for y in range(0,11,2 if density==2 else 3):
        x0=(r.randrange(16)+frame*1)%16
        L=3 if density==1 else 2
        for k in range(L): g[y][(x0+k)%16]='#'
        x1=(x0+8+r.randrange(-2,3))%16
        for k in range(L): g[y][(x1+k)%16]='#'
    return [''.join(r_) for r_ in g]

ANIMF=4
water_frames={}   # G -> list of frames (rows)
def add_water_char(name, framesrows, fg, bg):
    g=add(name, framesrows[0], fg, bg)
    water_frames[g]=framesrows
    return g

# deep water: 2 variants (4 chars)
deep_first=len(chars)
for v in range(2):
    fr=[wave_frame(f,1,100+v) for f in range(ANIMF)]
    add_water_char('DEEP%d.L'%v,[rows_from([s[:8] for s in f]) for f in fr],BLUE if False else BBLUE,BLUE)
    add_water_char('DEEP%d.R'%v,[rows_from([s[8:] for s in f]) for f in fr],BBLUE,BLUE)
terr_first[T_DEEP]=(deep_first,2)

# shallow/shore: index = base + side*8 + n*4 + s*2 + e   where e = land on outer side
# For L char outer side = west, for R char outer side = east.
shore_first=len(chars)
for side in range(2):
    for n in range(2):
        for s in range(2):
            for e in range(2):
                frames=[]
                for f in range(ANIMF):
                    base=wave_frame(f,2,200+side*8+n*4+s*2+e)
                    half=[row[:8] if side==0 else row[8:] for row in base]
                    gr=[list(r) for r in half]
                    if n:
                        for x in range(8): gr[0][x]='#'
                        for x in range(8):
                            if (x+f)%3==0: gr[1][x]='#'
                    if s:
                        for x in range(8): gr[10][x]='#'
                        for x in range(8):
                            if (x+f)%3==1: gr[9][x]='#'
                    if e:
                        col=0 if side==0 else 7
                        col2=1 if side==0 else 6
                        for y in range(11):
                            gr[y][col]='#'
                            if (y+f)%3==0: gr[y][col2]='#'
                    frames.append(rows_from([''.join(r) for r in gr]))
                add_water_char('SH%d%d%d%d'%(side,n,s,e),frames,BCYAN,BBLUE)
terr_first[T_SHALLOW]=(shore_first,0)
terr_first[T_RIVER]=(shore_first,0)

# ---- land terrain variants
reg_terrain(T_GRASS, grass_tile, 3, BGREEN, GREEN, 10)
reg_terrain(T_MEADOW, lambda s: grass_tile(s,True), 2, BYELLOW, GREEN, 20)
reg_terrain(T_FOREST, forest_tile, 2, BLACK, GREEN, 30)
reg_terrain(T_DENSE, lambda s: forest_tile(s,True), 2, BLACK, GREEN, 40)
reg_terrain(T_HILLS, hills_tile, 2, YELLOW, GREEN, 50)
reg_terrain(T_MOUNT, mountain_tile, 2, WHITE, DGREY, 60)
reg_terrain(T_SNOW, snow_tile, 2, GREY, WHITE, 70)
reg_terrain(T_DESERT, desert_tile, 2, BYELLOW, YELLOW, 80)
reg_terrain(T_BEACH, beach_tile, 2, YELLOW, BYELLOW, 90)
reg_terrain(T_MARSH, marsh_tile, 2, BCYAN, GREEN, 100)
reg_terrain(T_FIELD, field_tile, 1, BYELLOW, YELLOW, 110)
reg_terrain(T_ROCK, rock_tile, 1, GREY, DGREY, 120)
reg_terrain(T_RUINS, ruins_tile, 1, GREY, GREEN, 130)

# fog (unexplored)
FOG=['#...............','........#.......','................','....#.......#...','................','..........#.....','.#..............','......#.........','..............#.','...#............','.........#......']
fog_g=add_tile('FOG',FOG,DGREY,BLACK,mono16=['................','................','....#...........','................','................','................','................','............#...','................','................','................'])
# explored-but-unknown edge? keep simple.

# ---- roads: index = base + side*8 + n*4 + s*2 + e(arm toward outer side)
road_first=len(chars)
for side in range(2):
    for n in range(2):
        for s in range(2):
            for e in range(2):
                g=[['.']*8 for _ in range(11)]
                # road surface drawn as fg (dirt colour); bg grass
                inner = 7 if side==0 else 0     # column touching the other half
                def hband(y0,y1,x0,x1):
                    for y in range(y0,y1+1):
                        for x in range(x0,x1+1): g[y][x]='#'
                # central hub occupies inner columns of both halves around rows 3..7
                if side==0: hub=(5,7)
                else: hub=(0,2)
                hband(3,7,hub[0],hub[1])
                if n: hband(0,3,hub[0],hub[1])
                if s: hband(7,10,hub[0],hub[1])
                if e:
                    if side==0: hband(3,7,0,5)
                    else: hband(3,7,2,7)
                # ruts
                for y in range(11):
                    for x in range(8):
                        if g[y][x]=='#' and (x+y*3)%7==0: g[y][x]='.'
                add('RD%d%d%d%d'%(side,n,s,e), rows_from([''.join(r) for r in g]), BYELLOW, GREEN)
# bridges (horizontal pair, vertical pair)
BRIDGE_H=['................','................','################','#..#..#..#..#..#','################','................','################','#..#..#..#..#..#','################','................','................']
BRIDGE_V=['....#......#....','....##....##....','....#.#..#.#....','....##....##....','....#.#..#.#....','....##....##....','....#.#..#.#....','....##....##....','....#.#..#.#....','....##....##....','....#......#....']
bridge_h=add_tile('BRH',BRIDGE_H,BYELLOW,BBLUE)
bridge_v=add_tile('BRV',BRIDGE_V,BYELLOW,BBLUE)

# ---- buildings (1 tile = 2 chars unless noted)
B={}
def bld(name, strs16, fg, bg, fg2=None, bg2=None, mono16=None):
    B[name]=add_tile(name, strs16, fg, bg, fg2, bg2, mono16)
    return B[name]

bld('HUT',['................','......####......','.....######.....','....###..###....','...###....###...','..####....####..','....#......#....','....#..##..#....','....#..##..#....','....########....','................'], YELLOW, GREEN)
bld('HOUSE',['.........##.....','....######......','...########.....','..##########....','.############...','..#........#....','..#.##..##.#....','..#.##..##.#....','..#....##..#....','..#....##..#....','..##########....'], BRED, YELLOW)
bld('MANOR',['..##........##..','.####......####.','################','#..............#','#.##.##.##.##..#','#.##.##.##.##..#','#..............#','#.##.##..##.##.#','#.##.##..##.##.#','#......##......#','################'], BRED, WHITE)
bld('FARM',['...#............','..###...######..','.#####.########.','..#.#..#......#.','..###..#.####.#.','.......#.#..#.#.','#.#.#..#.#..#.#.','.......########.','#.#.#...........','................','################'], BRED, BYELLOW, BRED, BYELLOW)
bld('WOOD',['..#.............','.###......####..','#####....######.','.###.....#....#.','#####....#.##.#.','..#......#.##.#.','..#......######.','...............','.=====..######..','.=====..#.#.#.#.','.=====..######..'.replace('=','#')], BLACK, GREEN, YELLOW, GREEN)
bld('QUARRY',['................','.####......##...','######....####..','##..##...######.','#....#..##..###.','#.##.#..#.##..#.','#....#..#....##.','######...#####..','.......#.......#','..#.#..##..##..#','.#############..'], GREY, DGREY)
bld('WELL',['................','.....######.....','....#......#....','....########....','.....#....#.....','.....#....#.....','...##########...','...#.######.#...','...#.#....#.#...','...##########...','................'], WHITE, GREEN)
bld('MARKET',['#..............#','################','#.#.#.#.#.#.#.##','################','.#............#.','.#..##....##..#.','.#.####..####.#.','.#.####..####.#.','.#............#.','.##############.','................'], BRED, BYELLOW, BMAGENTA, BYELLOW)
bld('TOWER',['.....#.##.#.....','.....######.....','.....#....#.....','.....#.##.#.....','.....#.##.#.....','.....#....#.....','.....#.##.#.....','.....#.##.#.....','....#......#....','....#..##..#....','...##########...'], WHITE, GREEN, WHITE, GREEN)
bld('SCAFF',['................','..#..#..#..#....','..############..','..#..#..#..#....','..#..#..#..#....','..############..','..#..#..#..#....','..#..#..#..#....','..############..','.##############.','................'], BYELLOW, GREEN)
# windmill: 3 animation frames of sails in left char, body in right? -> sails span tile; animate both chars
WM_FRAMES=[
 ['....#.....#.....','.....#...#......','......#.#.......','.......#........','......#.#.......','.....#...#......','....#.#.#.#.....','......#.#.......','......###.......','.....#####......','.....#####......'],
 ['.......#........','.......#........','.......#........','...#########....','.......#........','.......#........','......###.......','......###.......','......###.......','.....#####......','.....#####......'],
]
wm_first=len(chars)
B['WINDMILL']=wm_first
for f,(fr) in enumerate([WM_FRAMES[0]]):
    pass
add_tile('WINDMILL',WM_FRAMES[0],WHITE,GREEN)
mill_frames={}
mill_frames[wm_first]=[rows_from([s[:8] for s in fr]) for fr in WM_FRAMES]
mill_frames[wm_first+1]=[rows_from([s[8:] for s in fr]) for fr in WM_FRAMES]

# Town centre 2x2 tiles (4 tiles, 8 chars): TL TR BL BR
TC=[
 '.......#........................',
 '.......##.......................',
 '.......###..........#...........',
 '.......#...........###..........',
 '.......#..........#####.........',
 '......###........#######........',
 '.....#####......#########.......',
 '....#######....###########......',
 '...#########..#############.....',
 '..###########..#.........#......',
 '.#############.#.##...##.#......',
 '..#.........#..#.##...##.#......',
 '..#.##...##.#..#.........#......',
 '..#.##...##.#..#....#....#......',
 '..#.........#..#...###...#......',
 '..#....#....#..#...###...#......',
 '..#...###...#..#...###...#......',
 '..#...###...#..###########......',
 '..###########...................',
 '................................',
 '................................',
 '................................',
]
tcq=[]
for (r0,c0,nm) in [(0,0,'TC_TL'),(0,16,'TC_TR'),(11,0,'TC_BL'),(11,16,'TC_BR')]:
    tile=[TC[r0+y][c0:c0+16] for y in range(11)]
    B[nm]=add_tile(nm,tile,WHITE,GREEN)
# Recolour: town centre walls white on red roof feel: use fg=YELLOW? keep simple
flag_frames={}
tl=B['TC_TL']
f2=[TC[y][0:8] for y in range(11)]
f2b=[r for r in f2]; f2b[1]='.......#'; f2b[2]='.......##'[:8]
flag_frames[tl]=[rows_from(f2), rows_from(['.......#','.......#','.......##','.......#']+f2[4:])]

# house smoke: frames for HOUSE.L
house_l=B['HOUSE']
H0=['.........##.....','....######......','...########.....','..##########....','.############...','..#........#....','..#.##..##.#....','..#.##..##.#....','..#....##..#....','..#....##..#....','..##########....']
SM=[['...#....','....#...'],['....#...','...#....'],['..#.....','...#....']]
smoke_frames={}
smoke_frames[house_l+1]=[]
for f in range(3):
    tile=[r for r in H0]
    a=list(tile[0]);
    tile2=[list(r) for r in tile]
    # smoke rises from chimney at x=9..10 above row 0: draw in row 0 only (tile-limited)
    for x in range(8,16): tile2[0][x]='.'
    tile2[0][9+ (f%2)]='#'
    smoke_frames[house_l+1].append(rows_from([''.join(r)[8:16] for r in tile2]))

assert len(chars)<=256, len(chars)

# ---- buildings unlocked by research ----
MINE=['................','......####......','....########....','...###....###...','..###..##..###..','..##..####..##..','.###..#..#..###.','.##...#..#...##.','.##...#..#...##.','################','#.#.#.#.#.#.#.#.']
SCHOOL=['......#.........','.....###........','.....#.#........','..##########....','.############...','..#........#....','..#.##..##.#..#.','..#.##..##.#.###','..#........#..#.','..#...##...#..#.','..##########....']
HARBOUR=['......#.........','......##........','......###.......','......####......','......#.........','...##########...','....########....','................','################','#..#..#..#..#..#','#..#..#..#..#..#']
HOSPITAL=['................','..############..','..#....##....#..','..#..######..#..','..#....##....#..','..############..','..#..........#..','..#.##.##.##.#..','..#.##.##.##.#..','..#....##....#..','..############..']
TEMPLE=['.......##.......','.....######.....','...##########...','.##############.','................','.#.##.##.##.##.#','.#.##.##.##.##.#','.#.##.##.##.##.#','.#.##.##.##.##.#','################','################']
UNIV=['.......##.......','.....######.....','....########....','.##############.','.#............#.','.#.##.####.##.#.','.#.##.#..#.##.#.','.#....#..#....#.','.##############.','################','................']
bld('MINE',MINE, GREY, GREEN)
bld('SCHOOL',SCHOOL, BRED, YELLOW)
bld('HARBOUR',HARBOUR, WHITE, BBLUE, BYELLOW, BBLUE)
bld('HOSPITAL',HOSPITAL, BRED, WHITE)
bld('TEMPLE',TEMPLE, WHITE, GREEN)
bld('UNIV',UNIV, BYELLOW, GREEN)
# the Grand Forum: a colosseum, 2x2 tiles
FORUM=[
 '....##########################..',
 '..##..........................##',
 '.#..###..###..###..###..###....#',
 '#..#...##...##...##...##...#...#',
 '#..#...##...##...##...##...#...#',
 '#..#...##...##...##...##...#...#',
 '#..############################.',
 '#..#...##...##...##...##...#...#',
 '#..#...##...##...##...##...#...#',
 '#..#...##...##...##...##...#...#',
 '#..#...##...##...##...##...#...#',
 '#..############################.',
 '#..#.#.##.#.##.#.##.#.##.#.#...#',
 '#..#.#.##.#.##.#.##.#.##.#.#...#',
 '#..#.#.##.#.##.#.##.#.##.#.#...#',
 '#..#.#.##.#.##.#.##.#.##.#.#...#',
 '.#.############################.',
 '..##..........................##',
 '....##########################..',
 '................................',
 '################################',
 '................................',
]
for (r0,c0,nm) in [(0,0,'FORUM_TL'),(0,16,'FORUM_TR'),(11,0,'FORUM_BL'),(11,16,'FORUM_BR')]:
    tile=[FORUM[r0+y][c0:c0+16] for y in range(11)]
    B[nm]=add_tile(nm,tile,WHITE,YELLOW)

cursor_g=add('CURSOR_L',[0]*11,WHITE,BLACK)
add('CURSOR_R',[0]*11,WHITE,BLACK)
MAP_END=len(chars)

# ---------------------------------------------------------------- bank 2: UI
pad_to(256)
ui_first=len(chars)
# overview chars (1 char per class)
OV={}
def ov(name, strs, fg, bg):
    OV[name]=add('OV_'+name, rows_from(strs), fg, bg)
ov('DEEP',['........','..##....','........','.....##.','........','.##.....','........','....##..','........','.##.....','........'],BBLUE,BLUE)
ov('SHAL',['........','.##..##.','........','..##..##','........','.##..##.','........','..##..##','........','.##..##.','........'],BCYAN,BBLUE)
ov('GRASS',['........','.#...#..','........','...#...#','........','.#...#..','........','...#...#','........','.#...#..','........'],BGREEN,GREEN)
ov('FOREST',['.#...#..','###.###.','###.###.','.#...#..','...#...#','..###.##','..###.##','...#...#','.#...#..','###.###.','.#...#..'],BLACK,GREEN)
ov('HILLS',['........','..##....','.#..#...','#....#..','......##','.....#..','...##...','..#..#..','.#....#.','........','........'],YELLOW,GREEN)
ov('MOUNT',['...#....','..###...','.##.##..','##...##.','#..#..#.','..###...','.##.##..','##...##.','#.....#.','........','........'],WHITE,DGREY)
ov('SNOW',['........','..#.....','.#.#....','#...#...','........','....#...','...#.#..','..#...#.','........','........','........'],GREY,WHITE)
ov('DESERT',['........','.###....','#...#...','......#.','.....#..','........','..#.....','...###..','..#...#.','........','........'],BYELLOW,YELLOW)
ov('BEACH',['#...#...','..#...#.','#...#...','..#...#.','#...#...','..#...#.','#...#...','..#...#.','#...#...','..#...#.','#...#...'],YELLOW,BYELLOW)
ov('MARSH',['#.#.....','#.#..#.#','###..#.#','.#...###','......#.','.#.#....','.#.#.#.#','.###.#.#','..#..###','......#.','........'],BCYAN,GREEN)
ov('FIELD',['########','........','########','........','########','........','########','........','########','........','########'],BYELLOW,YELLOW)
ov('TOWN',['...#....','..###...','.#####..','#######.','.#...#..','.#.#.#..','.#...#..','.#####..','........','........','........'],WHITE,BRED)
ov('RIVAL',['...#....','..###...','.#####..','#######.','.#...#..','.#.#.#..','.#...#..','.#####..','........','........','........'],WHITE,MAGENTA)
ov('ROAD',['........','........','........','........','########','########','........','........','........','........','........'],BYELLOW,GREEN)
ov('FOG',['........','........','..#.....','........','........','.....#..','........','........','.#......','........','........'],DGREY,BLACK)
chars[-1]['mono']=[0]*11
# panel frame chars
FR={}
def fr(name,strs,fg=BYELLOW,bg=BLUE): FR[name]=add('FR_'+name,rows_from(strs),fg,bg)
fr('TL',['........','........','........','........','........','.....###','....####','....##..','....##..','....##..','....##..'])
fr('TR',['........','........','........','........','........','###.....','####....','..##....','..##....','..##....','..##....'])
fr('BL',['....##..','....##..','....##..','....####','.....###','........','........','........','........','........','........'])
fr('BR',['..##....','..##....','..##....','####....','###.....','........','........','........','........','........','........'])
fr('H',['........','........','........','........','........','########','########','........','........','........','........'])
fr('HB',['........','........','........','........','########','########','........','........','........','........','........'])
fr('V',['....##..','....##..','....##..','....##..','....##..','....##..','....##..','....##..','....##..','....##..','....##..'])
fr('VR',['..##....','..##....','..##....','..##....','..##....','..##....','..##....','..##....','..##....','..##....','..##....'])
fr('BAR',['########']*11)
fr('HALF',['........']*3+['########']*5+['........']*3)

# resource mini icons
RI={}
def ri(name,strs,fg,bg=BLACK): RI[name]=add('RI_'+name,rows_from(strs),fg,bg)
ri('FOOD',['...#....','..#.#...','...#.#..','..#.#...','...#.#..','..#.#...','...##...','....#...','....#...','....#...','........'],BYELLOW)
ri('WOOD',['........','........','.######.','#..#...#','#.#.#..#','#..#...#','.######.','.#...#..','........','........','........'],YELLOW)
ri('STONE',['........','........','..###...','.#####..','###.###.','########','.######.','........','........','........','........'],GREY)
ri('GOLD',['........','..####..','.#....#.','#..##..#','#.#....#','#..##..#','#....#.#','#..##..#','.#....#.','..####..','........'],BYELLOW)
ri('POP',['...##...','..####..','...##...','..####..','.######.','#.####.#','..####..','..#..#..','..#..#..','.##..##.','........'],BCYAN)
ri('HAPPY',['..####..','.#....#.','#.#..#.#','#......#','#.#..#.#','#..##..#','.#....#.','..####..','........','........','........'],BGREEN)
ri('SAD',['..####..','.#....#.','#.#..#.#','#......#','#..##..#','#.#..#.#','.#....#.','..####..','........','........','........'],BRED)
ri('CAL',['########','#......#','########','#.#.#.##','########','#.#.#.##','########','#.#.#.##','########','........','........'],WHITE)
ri('PAUSE',['........','.##..##.','.##..##.','.##..##.','.##..##.','.##..##.','.##..##.','.##..##.','........','........','........'],BYELLOW)
ri('PLAY',['........','.##.....','.####...','.######.','.#######','.######.','.####...','.##.....','........','........','........'],BGREEN)
ri('FAST',['........','#...#...','##..##..','###.###.','########','###.###.','##..##..','#...#...','........','........','........'],BGREEN)
ri('ARROW',['#.......','##......','###.....','####....','#####...','######..','###.....','#.##....','...##...','........','........'],WHITE)

# tool icons (2 chars each, 16x11) on a dark panel
TI={}
def ti(name,strs,fg,bg=BLUE,fg2=None): TI[name]=add_tile('TI_'+name,strs,fg,bg,fg2)
ti('ROAD',['................','.....######.....','....########....','...##########...','..#####..#####..','.######..######.','################','#######..#######','#######..#######','################','................'],BYELLOW)
ti('HUT',['................','.......##.......','......####......','.....######.....','....########....','...##########...','....#......#....','....#..##..#....','....#..##..#....','....########....','................'],BYELLOW)
ti('FARM',['................','.#.#.#..........','..#.#.#..#####..','.#.#.#..#######.','..#.#.#.#.....#.','.#.#.#..#.###.#.','..#.#.#.#.#.#.#.','.#.#.#..#######.','................','################','................'],BYELLOW,BLUE,BRED)
ti('WOOD',['................','...#.....#......','..###...###.....','.#####.#####....','..###...###.....','.#####.#####....','...#.....#......','..........#####.','.........######.','........#######.','................'],BGREEN,BLUE,BYELLOW)
ti('QUARRY',['................','..##............','.####......#....','######....###...','##..##...#####..','#....#..##.####.','#.##.#..#######.','######..........','..........#.#...','.#############..','................'],WHITE)
ti('WELL',['................','.....######.....','....#......#....','....########....','.....#....#.....','.....#....#.....','...##########...','...#.######.#...','...#.#....#.#...','...##########...','................'],BCYAN)
ti('MARKET',['................','################','#.#.#.#.#.#.#.##','################','.#............#.','.#..##....##..#.','.#.####..####.#.','.#.####..####.#.','.#............#.','.##############.','................'],BYELLOW,BLUE,BMAGENTA)
ti('MILL',['....#.....#.....','.....#...#......','......#.#.......','.......#........','......#.#.......','.....#...#......','....#.###.#.....','......###.......','......###.......','.....#####......','.....#####......'],WHITE)
ti('TOWER',['.....#.##.#.....','.....######.....','.....#....#.....','.....#.##.#.....','.....#....#.....','.....#.##.#.....','.....#....#.....','.....#.##.#.....','....#......#....','....#..##..#....','...##########...'],WHITE)
ti('CLEAR',['................','..........##....','.........####...','........####....','.......####.....','......##.#......','.....##.........','....##..........','...##...........','..##............','................'],BRED)
ti('INFO',['................','.......##.......','.......##.......','................','......###.......','.......##.......','.......##.......','.......##.......','......####......','................','................'],BCYAN)
ti('MAP',['................','.##############.','.#....##......#.','.#..######....#.','.#.########...#.','.#..######..#.#.','.#....##...###..','.#..........#..#','.##############.','................','................'],BGREEN)

OV_FIRST=min(OV.values()); OV_LAST=max(OV.values())
TI_FIRST=min(TI.values()); TI_LAST=max(TI.values())+1
inv_src=[]
OVI_FIRST=len(chars)
for g in range(OV_FIRST,OV_LAST+1):
    c=chars[g]; add('INV_'+c['name'],[(~r)&255 for r in c['rows']],c['fg'],c['bg']); inv_src.append((len(chars)-1,g))
TII_FIRST=len(chars)
for g in range(TI_FIRST,TI_LAST+1):
    c=chars[g]; add('INV_'+c['name'],[(~r)&255 for r in c['rows']],c['fg'],c['bg']); inv_src.append((len(chars)-1,g))
UI_END=len(chars)
assert UI_END<=384, UI_END

# ---------------------------------------------------------------- bank 3: title letters
pad_to(384)
title_first=len(chars)
import sys as _sys, os as _os
_sys.path.insert(0,_os.path.dirname(_os.path.abspath(__file__)))
from romantitle import letter_bitmap, marble
from romanfont import glyph_rows
# Roman capitals carved in marble: 32 x 33 px per letter (4 chars x 3 rows)
title_glyph={}
for li,letter in enumerate('EMPIRS'):
    big=marble(letter_bitmap(letter), li*7+3)
    cells=[]
    for cy in range(3):
        for cx in range(4):
            rows=[]
            for yy in range(11):
                v=0
                for xx in range(8): v=(v<<1)|big[cy*11+yy][cx*8+xx]
                rows.append(v)
            cells.append(add('BIG_%s_%d_%d'%(letter,cy,cx),rows,WHITE,DGREY))
    title_glyph[letter]=cells[0]
# stone tablet edges (fg = tablet stone, bg = black); mono: a 1px outline
def tab(name, filled, outline):
    add('TAB_'+name, rows_from(filled), DGREY, BLACK, mono=rows_from(outline))
F8='########'; Z8='........'
tab('T',  [Z8]*5+['########']*6,           [Z8]*5+['########']+[Z8]*5)
tab('B',  ['########']*5+[Z8]*6,           [Z8]*4+['########']+[Z8]*6)
tab('L',  ['.....###']*11,                 ['.....#..']*11)
tab('R',  ['###.....']*11,                 ['..#.....']*11)
tab('TL', [Z8]*5+['.......#','......##','.....###','.....###','.....###','.....###'], [Z8]*5+['.......#','......#.','.....#..','.....#..','.....#..','.....#..'])
tab('TR', [Z8]*5+['#.......','##......','###.....','###.....','###.....','###.....'], [Z8]*5+['#.......','.#......','..#.....','..#.....','..#.....','..#.....'])
tab('BL', ['.....###','.....###','.....###','......##','.......#']+[Z8]*6, ['.....#..','.....#..','.....#..','......#.','.......#']+[Z8]*6)
tab('BR', ['###.....','###.....','###.....','##......','#.......']+[Z8]*6, ['..#.....','..#.....','..#.....','.#......','#.......']+[Z8]*6)
TITLE_END=len(chars)
assert TITLE_END<=512
# ---------------------------------------------------------------- bank 4: Roman text font (G = 512 + ASCII)
pad_to(512)
font_first=len(chars)
for code in range(128):
    add('FONT_%d'%code, glyph_rows(chr(code)), WHITE, BLACK)
FONT_END=len(chars)

# ---------------------------------------------------------------- bank 5: tool icons, page 2
pad_to(640)
TI2_FIRST=len(chars)
def ti2(name,strs,fg,bg=BLUE,fg2=None): TI[name]=add_tile('TI_'+name,strs,fg,bg,fg2)
ti2('MINE',MINE,WHITE)
ti2('SCHOOL',SCHOOL,BYELLOW)
ti2('HARBOUR',HARBOUR,WHITE,BLUE,BYELLOW)
ti2('HOSPITAL',HOSPITAL,BRED)
ti2('TEMPLE',TEMPLE,WHITE)
ti2('UNIV',UNIV,BYELLOW)
ti2('FORUM',['................','..############..','.#.##.##.##.##..','.#.##.##.##.##..','.############...','.#.##.##.##.##..','.#.##.##.##.##..','.############...','................','################','................'],WHITE)
ti2('LOCK',['................','.....######.....','....##....##....','....#......#....','...##########...','...####..####...','...###....###...','...####..####...','...##########...','................','................'],GREY)
ti2('BLANK',['................']*11,BLUE)
TI2_LAST=len(chars)
_inv=TII_FIRST-TI_FIRST
pad_to(TI2_FIRST+_inv)
for g in range(TI2_FIRST,TI2_LAST):
    c=chars[g]; add('INV_'+c['name'],[(~r)&255 for r in c['rows']],c['fg'],c['bg']); inv_src.append((len(chars)-1,g))
assert len(chars)<=768
NCH=len(chars)

# ---------------------------------------------------------------- mono derivation
def mono_rows(c):
    if c.get('inv_mono') is not None: return c['inv_mono']
    if c['mono'] is not None: return c['mono']
    inv = c['monoinv']
    if inv is None: inv = lum(c['bg']) > lum(c['fg'])
    return [(~r)&255 for r in c['rows']] if inv else c['rows']

# mono overrides: deep water darker pattern; fog stays sparse
for g,frames in water_frames.items():
    pass

def mono_frames(g,frames):
    c=chars[g]; inv=c['monoinv']
    if inv is None: inv = lum(c['bg'])>lum(c['fg'])
    return [[(~r)&255 for r in f] if inv else f for f in frames]

for d,src in inv_src: chars[d]['inv_mono']=[(~r)&255 for r in mono_rows(chars[src])]
# ---------------------------------------------------------------- emit
out=[]
def emit(s): out.append(s)
emit('; ---- generated by art/mkart.py - do not edit ----')
emit('NCHARS equ %d'%NCH)
for k,v in sorted(names.items(), key=lambda x:x[1]):
    pass
def gsym(n): return n.replace('.','_')
for n,g in names.items():
    if n.startswith('pad'): continue
    emit('G_%s equ %d'%(gsym(n),g))
emit('G_FOGTILE equ %d'%fog_g)
emit('G_ROADS equ %d'%road_first)
emit('G_SHORE equ %d'%shore_first)
emit('G_DEEP equ %d'%deep_first)
emit('G_BRIDGEH equ %d'%bridge_h)
emit('G_BRIDGEV equ %d'%bridge_v)
emit('G_UI equ %d'%ui_first)
emit('G_CURSOR equ %d'%cursor_g)
emit('OV_INV equ %d'%(OVI_FIRST-OV_FIRST))
emit('TI_INV equ %d'%(TII_FIRST-TI_FIRST))
emit('G_TITLE equ %d'%title_first)
emit('FONT_BANK equ %d'%(font_first>>7))
for k,v in title_glyph.items(): emit('G_BIG_%s equ %d'%(k,v))

def dbrows(lst):
    return 'db '+','.join('%d'%x for x in lst)

# pattern data: chars packed 11 bytes each, colour then mono
pcg=['; ---- generated: boot-time PCG patterns (overwritten by maps later) ----','pcg_colour:']
for c in chars: pcg.append(' '+dbrows(c['rows']))
pcg.append('pcg_mono:')
for c in chars: pcg.append(' '+dbrows(mono_rows(c)))
pcg.append('pcg_end:')
open('src/art_pcg.inc','w').write('\n'.join(pcg)+'\n')

# default colour per char (used for UI glyphs)
emit('char_col:')
for i in range(0,NCH,16):
    emit(' db '+','.join('%d'%C(c['fg'],c['bg']) for c in chars[i:i+16]))

# terrain table: firstG, nvar, per terrain
emit('terr_tab:')
for t in range(16):
    f,n=terr_first.get(t,(0,0))
    emit(' db %d,%d   ; %s'%(f,n,TERR_NAMES[t]))
# terrain colours per season (spring, summer, autumn, winter), 16 bytes each
SEASON={
 T_GRASS:[C(BGREEN,GREEN),C(BYELLOW,GREEN),C(BYELLOW,YELLOW),C(GREY,WHITE)],
 T_MEADOW:[C(BYELLOW,GREEN),C(BRED,GREEN),C(BRED,YELLOW),C(GREY,WHITE)],
 T_FOREST:[C(BLACK,GREEN),C(BLACK,GREEN),C(BRED,YELLOW),C(GREEN,WHITE)],
 T_DENSE:[C(BLACK,GREEN),C(BLACK,GREEN),C(RED,YELLOW),C(GREEN,WHITE)],
 T_HILLS:[C(YELLOW,GREEN),C(YELLOW,GREEN),C(RED,YELLOW),C(GREY,WHITE)],
 T_FIELD:[C(BGREEN,YELLOW),C(BGREEN,YELLOW),C(BYELLOW,YELLOW),C(GREY,WHITE)],
 T_MARSH:[C(BCYAN,GREEN),C(BCYAN,GREEN),C(BCYAN,YELLOW),C(BCYAN,WHITE)],
 T_RUINS:[C(GREY,GREEN),C(GREY,GREEN),C(GREY,YELLOW),C(DGREY,WHITE)],
}
emit('terr_col:')
for s in range(4):
    row=[]
    for t in range(16):
        if t in SEASON: row.append(SEASON[t][s])
        else:
            f,n=terr_first.get(t,(0,0))
            c=chars[f]; row.append(C(c['fg'],c['bg']))
    emit(' db '+','.join(map(str,row)))
# season background colour used under buildings/roads (grass bg)
emit('season_grass_bg:')
emit(' db %d,%d,%d,%d'%(GREEN,GREEN,YELLOW,WHITE))

# animation frames: list of (G, frames...) for water, mills, smoke, flag
anim=[]
for g,fr in water_frames.items(): anim.append((g,fr,ANIMF))
emit('ANIM_WATER_N equ %d'%len(water_frames))
ab=[]
ab.append('anim_water:   ; G, then %d frames x 11 bytes colour, then same for mono'%ANIMF)
for g,fr in water_frames.items():
    ab.append(' db %d'%g)
    for f in fr: ab.append(' '+dbrows(f))
    for f in mono_frames(g,fr): ab.append(' '+dbrows(f))
others=[]
for d in (mill_frames,smoke_frames,flag_frames):
    for g,fr in d.items(): others.append((g,fr))
emit('ANIM_OTHER_N equ %d'%len(others))
ab.append('anim_other:   ; G, nframes, frames colour, frames mono')
for g,fr in others:
    ab.append(' db %d,%d'%(g,len(fr)))
    for f in fr: ab.append(' '+dbrows(f))
    for f in mono_frames(g,fr): ab.append(' '+dbrows(f))

open('src/art_anim.inc','w').write('\n'.join(['; ---- generated: animation frames (art bank) ----']+ab)+'\n')
# terrain names
emit('terr_names:')
for t in range(16): emit(' db "%s",0'%TERR_NAMES[t])

os.makedirs('src',exist_ok=True)
open('src/art.inc','w').write('\n'.join(out)+'\n')
json.dump({'chars':[dict(name=c['name'],rows=c['rows'],mono=mono_rows(c),fg=c['fg'],bg=c['bg']) for c in chars],'pal':PAL},open('build/art.json','w'))
print('chars:',NCH,' map:',MAP_END,' ui:',ui_first,'-',UI_END,' title:',title_first,'-',TITLE_END)
