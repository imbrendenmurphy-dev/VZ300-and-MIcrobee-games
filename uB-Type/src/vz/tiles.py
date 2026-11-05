# VZ-TYPE tile sets (all original). 64 tiles x 4x4 px per theme.
# chars: ' ' = space colour (logical 0), 'a','b','c' = logical 1..3
import random, math

# ---- tile ids
EMPTY=0; FULL=1            # 1..16 : (x&3)+(y&3)*4 + 1  -> 16x16 px texture
FTOP=17                    # 17,18 : floor top edge (x&1)
CBOT=19                    # 19,20 : ceiling bottom edge (x&1)
FSU=21; FSD=22; CSD=23; CSU=24
BTL=25; BTR=26; BBL=27; BBR=28; BT=29; BB=30; BL=31; BR=32
F0=33; F1=34               # solid features (pillar segment, surface feature)
# ship / special solid tiles 35..47
WIN=35; VENT=36; ENG=37; ARM=38; MAST=39; BEACON=40; PIPEH=41; PIPEV=42; GRATE=43; HATCH=44; DARK=45; NOSEU=46; NOSED=47
SOLID_MAX=47
DEC0=48                    # 48..51 near-star / speck decor (non-solid)
FLAME=52                   # engine exhaust (non-solid)
SOCKET=53                  # reactor-node socket in the dreadnought hull (non-solid)

def grid(n=16): return [[' ']*n for _ in range(n)]

def tex_hull():
    # staggered riveted plates, 8x8 each, offset every other plate row
    g=grid()
    for y in range(16):
        for x in range(16):
            px=(x+(4 if (y//8)%2 else 0))%8; py=y%8
            c='c'
            if py==0 or px==0: c='a'          # lit edge
            elif py==7 or px==7: c='b'        # shadow edge
            elif (px,py) in ((2,2),(5,2),(2,5),(5,5)): c='a'   # rivets
            elif py in (3,4) and 2<px<6 and (y//8+x//8)%2==0: c=' ' if px%2 else 'b'   # vent slot
            g[y][x]=c
    return g
def tex_flesh():
    # organic tissue: base b, meandering veins c with lit upper edge a, a few pores
    R=random.Random(7); g=grid()
    for y in range(16):
        for x in range(16): g[y][x]='b'
    for (y0,ph) in ((2,0.0),(10,2.1)):
        for x in range(16):
            y=int(round(y0+1.6*math.sin(x/16*2*math.pi+ph)+0.8*math.sin(x/16*4*math.pi+ph*2)))
            g[y%16][x]='c'; g[(y+1)%16][x]='c'; g[(y-1)%16][x]='a' if x%4 else 'c'
    for x0 in (4,12):              # cross veins
        x=x0
        for y in range(16):
            if g[y][x%16]=='b': g[y][x%16]='c'
            if R.random()<0.3: x+=R.choice((-1,1))
    for (x,y) in ((2,6),(9,5),(14,13),(6,14)):
        g[y][x]=' '; g[y][(x+1)%16]='a'
    for y in range(16):
        for x in range(16):
            if g[y][x]=='b' and (x+y)%2==0 and (g[(y-1)%16][x]=='c' or g[(y+1)%16][x]=='c'): g[y][x]='c'
    return g
def tex_rock():
    # staggered rounded boulders: lit upper-left, shaded lower-right, dark crevices
    g=grid()
    for y in range(16):
        for x in range(16):
            ox=4 if (y//8)%2 else 0
            lx=(x+ox)%8; ly=y%8
            dx=lx-3.5; dy=ly-3.5; d=(dx*dx+dy*dy)**0.5
            if d>4.3: c='b'
            elif d>3.6: c='b' if (x+y)%2 else 'c'
            elif dx+dy<-2.5: c='a' if (x+y)%2==0 else 'c'
            elif dx+dy>2.5: c='b' if (x+y)%2==0 else 'c'
            else: c='c'
            g[y][x]=c
    for (x,y) in ((2,1),(10,9),(13,3),(5,12)): g[y][x]='a'
    return g
def tex_cryst():
    g=grid()
    for y in range(16):
        for x in range(16):
            u=(x+y)%16; v=(x-y)%16
            if u==0 or v==0: c='a'                      # bright facet edges
            elif u==15 or v==15: c='b'                  # dark facet edges
            elif u<8 and v<8: c='c'
            elif u>=8 and v>=8: c='c' if (x+y)%2 else 'b'
            else: c='c' if (x//2+y)%2 else 'a' if (x+y)%4==0 else 'c'
            g[y][x]=c
    return g
def tex_ship():
    # long horizontal hull plates 16x4 with seams, rivet lines, panel lights
    g=grid()
    for y in range(16):
        for x in range(16):
            py=y%4; sx=(x+(y//4)*5)%16
            c='c'
            if py==0: c='a' if sx%4 else 'b'
            elif py==3: c='b'
            elif sx==0: c='b'
            elif py==1 and sx%4==2: c='a'
            g[y][x]=c
    return g
TEX={'hull':tex_hull(),'flesh':tex_flesh(),'rock':tex_rock(),'cryst':tex_cryst(),'ship':tex_ship()}
EDGE={'hull':('a','b'),'flesh':('a','c'),'rock':('a','b'),'cryst':('a','b'),'ship':('a','b')}

def sub(theme,tx,ty):
    t=TEX[theme]; return [''.join(t[(ty*4+y)%16][(tx*4+x)%16] for x in range(4)) for y in range(4)]
def mk(theme,maskfn,tx,ty,edgefn=None):
    hi,sh=EDGE[theme]; base=sub(theme,tx,ty); rows=[]
    for y in range(4):
        r=''
        for x in range(4):
            if not maskfn(x,y): r+=' '; continue
            c=base[y][x]
            if edgefn:
                e=edgefn(x,y,hi,sh); c=e if e else c
            r+=c
        rows.append(r)
    return rows

FEAT={
 'hull': [["bccb","cbbc","cbbc","bccb"], ["aaab","acbb","acbb","bbbb"]],
 'flesh':[["bccb","caac","caac","bccb"], ["b ab","acca","acca","b ab"]],
 'rock': [["cbcc","bcab","cacb","cbcc"], ["aaaa","cbcb","bcbc","cccc"]],
 'cryst':[["a  a"," aa "," aa ","a  a"], ["acca","caac","caac","acca"]],
 'ship': [["bccb","baab","baab","bccb"], ["aaaa","abba","abba","bbbb"]],
}
DECOR={  # 4 near-star / speck variants
 'hull': [["    "," a  ","    ","    "],["    ","    ","  c ","    "],["    ","  a ","    ","    "],["    ","    ","    "," c  "]],
 'flesh':[["    "," b  ","    ","    "],["    ","    ","  c ","    "],["    "," cc ","    ","    "],["    ","    ","  a ","    "]],
 'rock': [["    "," c  ","    ","    "],["    ","    ","  b ","    "],["    ","  a ","    ","    "],["    ","    ","    "," c  "]],
 'cryst':[["    "," a  ","    ","    "],["    ","    ","  c ","    "],["  a "," aaa","  a ","    "],["    ","    ","    "," b  "]],
 'ship': [["    "," a  ","    ","    "],["    ","    ","  c ","    "],["    ","  a ","    ","    "],["    ","    ","    "," b  "]],
}
SHIPT={
 WIN:   ["cccc","aaba","aaba","bbbb"],
 VENT:  ["bbbb","c c ","bbbb","c c "],
 ENG:   ["bccb","caac","caac","bccb"],
 ARM:   ["bbbb","bcbc","cbcb","bbbb"],
 MAST:  [" bc "," bc "," bc "," bc "],
 BEACON:[" aa ","abba"," bc "," bc "],
 PIPEH: ["bbbb","aaaa","cccc","bbbb"],
 PIPEV: ["bacb","bacb","bacb","bacb"],
 GRATE: ["bcbc","c c ","bcbc","c c "],
 HATCH: ["bbbb","baab","baab","bbbb"],
 DARK:  ["bbbb","bcbb","bbbc","bbbb"],
 NOSEU: ["   a","  ac"," acc","accc"],
 NOSED: ["bccc"," bcc","  bc","   b"],
}
FLAMET=["  ab"," abb","  ab","   a"]

def tileset(theme):
    T=[["    "]*4 for _ in range(64)]
    full=lambda x,y:True
    for k in range(16): T[FULL+k]=mk(theme,full,k&3,k>>2)
    for k in range(2):
        T[FTOP+k]=mk(theme,full,k,0,lambda x,y,h,s: h if y==0 else None)
        T[CBOT+k]=mk(theme,full,k,3,lambda x,y,h,s: s if y==3 else None)
    T[FSU]=mk(theme,lambda x,y: x>=3-y,0,0,lambda x,y,h,s: h if x==3-y else None)
    T[FSD]=mk(theme,lambda x,y: x<=y,1,0,lambda x,y,h,s: h if x==y else None)
    T[CSD]=mk(theme,lambda x,y: x>=y,0,3,lambda x,y,h,s: s if x==y else None)
    T[CSU]=mk(theme,lambda x,y: x<=3-y,1,3,lambda x,y,h,s: s if x==3-y else None)
    rnd=lambda cx,cy: (lambda x,y: (x+0.5-cx)**2+(y+0.5-cy)**2<=16.5)
    T[BTL]=mk(theme,rnd(4,4),0,0,lambda x,y,h,s: h if (x+0.5-4)**2+(y+0.5-4)**2>9 else None)
    T[BTR]=mk(theme,rnd(0,4),1,0,lambda x,y,h,s: h if (x+0.5)**2+(y+0.5-4)**2>9 else None)
    T[BBL]=mk(theme,rnd(4,0),0,1,lambda x,y,h,s: s if (x+0.5-4)**2+(y+0.5)**2>9 else None)
    T[BBR]=mk(theme,rnd(0,0),1,1,lambda x,y,h,s: s if (x+0.5)**2+(y+0.5)**2>9 else None)
    T[BT]=mk(theme,full,2,0,lambda x,y,h,s: h if y==0 else None)
    T[BB]=mk(theme,full,1,1,lambda x,y,h,s: s if y==3 else None)
    T[BL]=mk(theme,full,0,1,lambda x,y,h,s: h if x==0 else None)
    T[BR]=mk(theme,full,3,2,lambda x,y,h,s: s if x==3 else None)
    T[F0],T[F1]=FEAT[theme]
    for k,t in SHIPT.items(): T[k]=t
    for k in range(4): T[DEC0+k]=DECOR[theme][k]
    T[FLAME]=FLAMET
    T[SOCKET]=["b  b","    ","    ","b  b"]
    return T

# ---- far parallax band: 64 x 8 px logical, dithered silhouettes (distant = half density)
import math
def farband(theme,seed=5):
    R=random.Random(seed); W,H=64,8
    hgt=[0]*W
    if theme in ('hull','ship'):          # distant station skyline: towers + masts
        x=0
        while x<W:
            w=R.randint(3,7); h=R.randint(2,7)
            for k in range(w):
                if x+k<W: hgt[x+k]=h
            if R.random()<0.4 and x+w//2<W: hgt[x+w//2]=8
            x+=w+R.randint(1,4)
    elif theme=='flesh':                  # tendrils and bulbs
        for x in range(W): hgt[x]=int(3+2*math.sin(x/64*2*math.pi*3)+1.5*math.sin(x/64*2*math.pi*7+1))
    elif theme=='rock':                   # jagged ridge line
        h=4
        for x in range(W):
            h=max(1,min(7,h+R.choice((-1,0,0,1)))); hgt[x]=h
    else:                                 # crystal spires
        for x in range(W):
            d=min((x%13),13-(x%13)); hgt[x]=max(1,min(8,d+(2 if (x//13)%2 else 0)))
    rows=[]
    for y in range(H):
        r=''
        for x in range(W):
            on = (H-y)<=hgt[x]
            if not on: r+=' '; continue
            top = (H-y)==hgt[x]
            # distant: dithered body, solid rim highlight
            if top: r+='a' if theme!='flesh' else 'c'
            else: r+=('c' if theme!='flesh' else 'b') if (x+y)%2==0 else ' '
        rows.append(r)
    # wrap smoothly
    return rows
