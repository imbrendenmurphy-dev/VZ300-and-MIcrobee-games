# VZ-TYPE tiles and level layouts (all original)
import random
from tiles import *

ROWS=14
class Lvl:
    def __init__(s,n): s.n=n; s.c=[0]*n; s.f=[0]*n; s.blocks=[]; s.feat=[]; s.dec=[]; s.spawns=[]; s.xobjs=[]
def build_grid(L,theme):
    N=len(L.c); G=[[EMPTY]*ROWS for _ in range(N)]
    for x in range(N):
        c=L.c[x]; f=L.f[x]
        for y in range(ROWS):
            if y<c: G[x][y]=FULL+(x&3)+(y&3)*4
            elif y>=ROWS-f: G[x][y]=FULL+(x&3)+(y&3)*4
        if c>0: G[x][c-1]=CBOT+(x&1)
        if f>0: G[x][ROWS-f]=FTOP+(x&1)
    # slopes: floor
    for x in range(1,N):
        a,b=L.f[x-1],L.f[x]
        if b==a+1 and b>0: G[x][ROWS-b]=FSU
        if b==a-1 and a>0: G[x-1][ROWS-a]=FSD
        a,b=L.c[x-1],L.c[x]
        if b==a+1: G[x][b-1]=CSD
        if b==a-1 and a>0: G[x-1][a-1]=CSU
    for (bx,by,bw,bh) in L.blocks:
        for x in range(bx,bx+bw):
            for y in range(by,by+bh):
                if x>=N or y>=ROWS: continue
                t=FULL+(x&3)+(y&3)*4
                top=y==by; bot=y==by+bh-1; lf=x==bx; rt=x==bx+bw-1
                if top and lf: t=BTL
                elif top and rt: t=BTR
                elif bot and lf: t=BBL
                elif bot and rt: t=BBR
                elif top: t=BT
                elif bot: t=BB
                elif lf: t=BL
                elif rt: t=BR
                G[x][y]=t
    for (ox,oy,ow,oh,k) in sorted(L.xobjs):
        for x in range(ox,min(N,ox+ow)):
            for y in range(oy,oy+oh): G[x][y]=k
    for (fx,fy,t) in L.feat:
        if fx<N: G[fx][fy]=t
    for (fx,fy,t) in L.dec:
        if fx<N and G[fx][fy]==EMPTY: G[fx][fy]=t
    return G

# ---- enemy types
SWIM,DART,TURF,TURC,HOP,CARR,SPIN,GUNS,SPORE=1,2,3,4,5,6,7,8,9
SNAKE=15; BOSS=13; CORE=19
def ramp(L,x0,x1,arr,v0,v1):
    for x in range(x0,min(x1,L.n)):
        t=(x-x0)/max(1,(x1-x0)); arr[x]=round(v0+(v1-v0)*t)
def smooth(arr):
    # limit changes to 1 tile per column for slope tiles
    for x in range(1,len(arr)):
        if arr[x]>arr[x-1]+1: arr[x]=arr[x-1]+1
        if arr[x]<arr[x-1]-1: arr[x]=arr[x-1]-1
    return arr
def profile(L,arr,points):
    for (x0,v0),(x1,v1) in zip(points,points[1:]): ramp(L,x0,x1+1,arr,v0,v1)
    smooth(arr)

def spawn(L,col,typ,y,p=0): L.spawns.append((col,typ,y,p))
def wave_swim(L,col,y,n=5,amp=0): spawn(L,col,SWIM,y,n|(amp<<4))
def turrets(L,cols,ceil=False,floor=True):
    for x in cols:
        if floor and L.f[x]>0 and L.f[x-1]==L.f[x]==L.f[x+1]: spawn(L,x,TURF,0)
        if ceil and L.c[x]>0 and L.c[x-1]==L.c[x]==L.c[x+1]: spawn(L,x,TURC,0)

# ---- STAGE 5: the DREADNOUGHT - fly round a giant enemy battleship (original design)
def dreadnought(L,R,li):
    n=L.n
    L.c=[0]*n; L.f=[0]*n
    HT,HB=5,8                       # hull occupies tile rows 5..8 (lanes above and below)
    x=36
    # nose: a stepped wedge leading into the first section
    L.xobjs+=[(x,6,1,1,NOSEU),(x,7,1,1,NOSED),(x+1,5,1,1,NOSEU),(x+1,8,1,1,NOSED),(x+1,6,1,2,ARM)]
    x+=2
    sec=0
    while x<n-70:
        seg=R.randint(22,40)
        if x+seg>n-66: seg=n-66-x
        if seg<14: break
        L.blocks.append((x,HT,seg,HB-HT+1))
        L.xobjs.append((x+2,6,seg-4,1,WIN))
        band=R.choice((ARM,VENT,GRATE,PIPEH))
        L.xobjs.append((x+2,7,seg-4,1,band))
        for k in range(x+3,x+seg-3,R.randint(5,8)): L.xobjs.append((k,8,1,1,HATCH))
        # command tower with a beacon mast
        if R.random()<0.65 and seg>=26:
            tw=R.randint(4,7); tx=x+R.randint(4,seg-tw-4)
            th=R.randint(2,3)
            L.blocks.append((tx,HT-th,tw,th))
            L.xobjs.append((tx+1,HT-th+1,tw-2,1,WIN))
            L.xobjs.append((tx+tw//2,HT-th-1,1,1,BEACON))
            if th==3 and R.random()<0.5: L.xobjs.append((tx+1,HT-th-1,1,1,MAST))
        # keel fin
        if R.random()<0.5 and seg>=24:
            kw=R.randint(4,8); kx=x+R.randint(3,seg-kw-3)
            L.blocks.append((kx,HB+1,kw,R.randint(1,2)))
        # reactor nodes to pick off (sockets in the window band)
        for k in range(R.randint(1,2)):
            cx=x+R.randint(4,seg-6)
            L.xobjs.append((cx,6,2,2,SOCKET))
            spawn(L,cx,CORE,6*4)
        # turrets on both hull surfaces
        for k in range(x+4,x+seg-4,R.randint(7,11)):
            if R.random()<0.6: spawn(L,k,TURF,HT*4-5)
            else: spawn(L,k,TURC,(HB+1)*4)
        # traffic in the lanes
        r=R.random(); lane=R.choice((8,44))
        if r<0.35: wave_swim(L,x+seg//2,lane,R.randint(3,5),1)
        elif r<0.55: spawn(L,x+seg//2,DART,lane)
        elif r<0.70 and sec>1: spawn(L,x+seg//2,GUNS,lane-4 if lane>20 else lane)
        gap=R.randint(3,6)
        if sec%3!=2: L.xobjs.append((x+seg,6,gap,2,PIPEH))     # spine joins the sections
        x+=seg+gap
        sec+=1
    # stern: engine block with exhaust plumes
    L.blocks.append((x,4,6,6))
    L.xobjs.append((x+5,5,1,4,ENG))
    L.xobjs.append((x+6,5,2,4,FLAME))
    for (cx,ct) in [(20,0),(150,1),(260,2),(360,1)]:
        spawn(L,cx,CARR,R.choice((10,46)),ct)
    spawn(L,n-34,BOSS,0,li)
    L.spawns.sort()
    L.bandy=40

def make_levels():
    R=random.Random(1987)
    levels=[]
    themes=['hull','flesh','rock','cryst','ship','flesh','rock','cryst']
    for li in range(8):
        n=512+li*8
        L=Lvl(n); th=themes[li]
        if th=='ship':
            dreadnought(L,R,li); L.theme=th; L.grid=build_grid(L,th); levels.append(L); continue
        # ---- terrain profile: segments of differing character
        ptsC=[(0,1)]; ptsF=[(0,2)]
        x=0
        while x<n-70:
            seg=R.choice(['open','narrow','wave','cave','high','low'])
            ln=R.randint(24,48)
            if seg=='open': c,f=R.randint(0,1),R.randint(1,2)
            elif seg=='narrow': c,f=R.randint(3,4),R.randint(3,4)
            elif seg=='wave': c,f=R.randint(1,3),R.randint(1,3)
            elif seg=='cave': c,f=R.randint(2,4),R.randint(2,3)
            elif seg=='high': c,f=1,R.randint(4,5)
            else: c,f=R.randint(4,5),1
            if c+f>9: f=9-c
            x+=ln; ptsC.append((x,c)); ptsF.append((x,f))
            if seg=='wave':
                pass
        ptsC.append((n-60,1)); ptsF.append((n-60,1)); ptsC.append((n-1,1)); ptsF.append((n-1,1))
        profile(L,L.c,ptsC); profile(L,L.f,ptsF)
        # gentle undulation
        for x in range(n):
            pass
        # ---- obstacles
        x=40
        while x<n-75:
            kind=R.choice(['block','block','pillar','none','rocks'])
            gap_top=L.c[x]; gap_bot=ROWS-L.f[x]
            if kind=='block' and gap_bot-gap_top>=8:
                bw=R.randint(2,5); bh=R.randint(2,3)
                by=R.randint(gap_top+2,gap_bot-2-bh)
                L.blocks.append((x,by,bw,bh))
            elif kind=='pillar' and gap_bot-gap_top>=8:
                # pillar from floor or ceiling of feature tiles
                if R.random()<0.5:
                    for y in range(gap_bot-R.randint(2,3),gap_bot): L.feat.append((x,y,F0))
                else:
                    for y in range(gap_top,gap_top+R.randint(2,3)): L.feat.append((x,y,F0))
            elif kind=='rocks' and gap_bot-gap_top>=7:
                for k in range(3):
                    L.blocks.append((x+k*4,R.randint(gap_top+1,gap_bot-3),2,2))
            x+=R.randint(14,26)
        # decor (non-solid background)
        for x in range(0,n,3):
            y=R.randint(0,ROWS-1)
            if R.random()<0.35: L.dec.append((x,y,DEC0+R.randrange(4)))
        # solid features dotted along surfaces
        for x in range(8,n-8,R.randint(9,13)):
            if L.f[x]>=2 and L.f[x-1]==L.f[x]==L.f[x+1]: L.feat.append((x,ROWS-L.f[x]+1,F1))
        # ---- enemy waves (difficulty grows with level)
        d=li
        x=30
        while x<n-50:
            r=R.random()
            gt=L.c[x]*4+6; gb=(ROWS-L.f[x])*4-8
            y=R.randint(gt,max(gt,gb))
            if r<0.30: wave_swim(L,x,y,R.randint(3,5+min(d,2)),R.randint(0,3))
            elif r<0.42: spawn(L,x,DART,y)
            elif r<0.55: turrets(L,[x,x+6,x+12],ceil=(d>=1),floor=True)
            elif r<0.63: spawn(L,x,HOP,0)
            elif r<0.72: spawn(L,x,SPIN,y)
            elif r<0.78 and d>=1: spawn(L,x,GUNS,y)
            elif r<0.86: spawn(L,x,SPORE,y)
            else: spawn(L,x,SWIM,y,3)
            x+=R.randint(10,18)-min(d,4)
        # power-up carriers at fixed points
        for cx,ct in [(20,0),(140,1),(240,2),(340,0),(430,1)]:
            gt=L.c[cx]*4+8; gb=(ROWS-L.f[cx])*4-10
            spawn(L,cx,CARR,(gt+gb)//2,ct)
        spawn(L,n-34,BOSS,0,li)
        L.spawns.sort()
        fl=sorted(L.f)[len(L.f)//2]
        L.bandy=max(8,min(44,(ROWS-fl)*4-6))
        L.theme=th; L.grid=build_grid(L,th)
        levels.append(L)
    return levels
