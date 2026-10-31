# VZ-TYPE huge bosses - all original designs, drawn procedurally.
# logical colours: 0 transparent, 1 = a (bright), 2 = b (hot), 3 = c (body)
import math

class Cv:
    def __init__(s,w,h): s.w=w; s.h=h; s.p=[[0]*w for _ in range(h)]
    def put(s,x,y,c):
        x=int(x); y=int(y)
        if 0<=x<s.w and 0<=y<s.h: s.p[y][x]=c
    def get(s,x,y): return s.p[y][x] if 0<=x<s.w and 0<=y<s.h else 0
    def ell(s,cx,cy,rx,ry,c,dith=None):
        for y in range(s.h):
            for x in range(s.w):
                if ((x+0.5-cx)/rx)**2+((y+0.5-cy)/ry)**2<=1:
                    if dith is None or (x+y)%2==dith: s.p[y][x]=c
    def ring(s,cx,cy,rx,ry,c,t=1.0):
        for y in range(s.h):
            for x in range(s.w):
                d=((x+0.5-cx)/rx)**2+((y+0.5-cy)/ry)**2
                if 1-t*2/max(rx,ry)<=d<=1: s.p[y][x]=c
    def rect(s,x0,y0,x1,y1,c,dith=None):
        for y in range(int(y0),int(y1)):
            for x in range(int(x0),int(x1)):
                if dith is None or (x+y)%2==dith: s.put(x,y,c)
    def poly(s,pts,c,dith=None):
        n=len(pts)
        for y in range(s.h):
            yy=y+0.5; xs=[]
            for i in range(n):
                (x0,y0),(x1,y1)=pts[i],pts[(i+1)%n]
                if (y0<=yy<y1) or (y1<=yy<y0): xs.append(x0+(yy-y0)*(x1-x0)/(y1-y0))
            xs.sort()
            for a,b in zip(xs[0::2],xs[1::2]):
                for x in range(int(math.ceil(a-0.5)),int(math.floor(b-0.5))+1):
                    if dith is None or (x+y)%2==dith: s.put(x,y,c)
    def outline(s,c,inner=3):
        # recolour boundary pixels of the silhouette
        q=[r[:] for r in s.p]
        for y in range(s.h):
            for x in range(s.w):
                if s.p[y][x] and s.p[y][x]==inner:
                    if any(s.get(x+dx,y+dy)==0 for dx,dy in ((1,0),(-1,0),(0,1),(0,-1))): q[y][x]=c
        s.p=q
    def shade(s,c_from,c_to,fn):
        for y in range(s.h):
            for x in range(s.w):
                if s.p[y][x]==c_from and fn(x,y): s.p[y][x]=c_to
    def mirror_v(s):
        for y in range(s.h//2): s.p[s.h-1-y]=s.p[y][:]
    def rows(s): return [''.join('.123'[v] for v in r) for r in s.p]

def lit(cx,cy,r):   # dither highlight on the upper-left of a round form
    return lambda x,y: ((x-cx)+(y-cy))<-r*0.6 and (x+y)%2==0
def dark(cx,cy,r):
    return lambda x,y: ((x-cx)+(y-cy))>r*0.55 and (x+y)%2==0

BOSSES=[]
def boss(name,cv,hp,move,interval,attacks,parts,orbs=0):
    BOSSES.append(dict(name=name,rows=cv.rows(),w=cv.w,h=cv.h,hp=hp,move=move,interval=interval,
                       attacks=attacks,parts=parts,orbs=orbs))

# part kinds: 1 core (weak point, opens/closes), 2 gun (aimed), 3 hatch (spawns), 4 fan gun
CORE,GUN,HATCH,FAN=1,2,3,4

# ---- 1  BULWARK: armoured fortress disc with forward-swept armour wedges
c=Cv(40,48)
c.ell(26,24,15,15,3)
c.poly([(4,2),(30,2),(36,10),(22,16),(10,12)],3)
c.shade(3,1,lit(26,24,15)); c.shade(3,2,dark(26,24,15))
c.ring(26,24,15,15,2,1.2); c.ring(26,24,10,10,1,1.0); c.ring(26,24,6,6,2,1.0)
for k in range(5): c.rect(8+k*5,4,10+k*5,6,2)
c.rect(30,20,40,28,3); c.rect(32,21,40,27,2,0)
c.outline(1)
c.mirror_v()
boss('BULWARK',c,40,0,46,[1,2,1,3],[(CORE,18,21,40,0),(GUN,6,5,8,0),(GUN,6,37,8,0),(FAN,30,22,10,0)])

# ---- 2  BROODMOTHER: lumpy organic sac with ribs and spawning pores
c=Cv(44,48)
for y in range(48):
    for x in range(44):
        a=math.atan2(y-24,x-26); r=20+2.2*math.sin(5*a)+1.2*math.sin(9*a+1)
        if math.hypot((x-26)*1.05,(y-24)*0.98)<r: c.p[y][x]=3
for x0 in (12,18,24,30,36):
    for y in range(48):
        dx=int(round(2*math.sin(y/48*math.pi*2+x0)))
        if c.get(x0+dx,y)==3: c.put(x0+dx,y,2)
c.shade(3,1,lit(26,24,20)); c.shade(3,2,dark(26,24,20))
c.ell(20,24,7,8,2); c.ell(20,24,4,5,1,0)
c.outline(1)
boss('BROODMOTHER',c,50,2,52,[4,1,6,1],[(CORE,16,20,50,0),(HATCH,6,9,10,1),(HATCH,6,33,10,1),(HATCH,9,21,10,2)])

# ---- 4  PRISM COLOSSUS: radiating crystal shards round a gem heart
c=Cv(44,52)
for k,(ang,ln,wd) in enumerate([(180,27,7),(155,26,7),(205,26,7),(130,24,7),(230,24,7),(105,24,6),(255,24,6),(80,24,6),(280,24,6),(55,18,6),(305,18,6),(25,14,5),(335,14,5),(0,12,5)]):
    a=math.radians(ang); cx,cy=29,26
    tip=(cx+ln*math.cos(a),cy-ln*math.sin(a)); n=(-math.sin(a)*wd,-math.cos(a)*wd)
    c.poly([(cx+n[0],cy+n[1]),tip,(cx-n[0],cy-n[1]),(cx+4*math.cos(a+math.pi),cy-4*math.sin(a+math.pi))],3 if k%2 else 1)
c.shade(3,2,lambda x,y:(x+y)%3==0); c.shade(1,3,lambda x,y:(x-y)%4==0)
c.ell(29,26,8,8,2); c.ell(29,26,5,5,3)
c.outline(1)
boss('PRISM COLOSSUS',c,55,0,40,[2,1,3,1],[(CORE,22,22,55,0),(FAN,4,22,12,0),(FAN,14,6,10,0),(FAN,14,40,10,0)])

# ---- 5  BRIDGE TOWER: stern superstructure of the dreadnought with reactor ring
c=Cv(40,48)
c.rect(8,13,40,38,3); c.rect(14,4,34,13,3); c.rect(18,0,22,4,2); c.rect(26,0,28,4,1)
c.rect(14,38,34,46,3); c.rect(4,21,8,31,3)
for y in range(15,38,4): c.rect(9,y,40,y+1,2)
for x in range(16,32,4): c.rect(x,6,x+2,8,1)
c.ell(22,25,9,9,2); c.ring(22,25,9,9,1,1.0); c.ell(22,25,5,5,3)
c.rect(30,40,40,44,2,0)
c.shade(3,1,lambda x,y:y%4==1 and x%2==0)
c.outline(1)
boss('BRIDGE TOWER',c,60,1,36,[1,2,5,3],[(CORE,18,21,60,0),(GUN,10,7,10,0),(GUN,10,39,10,0),(FAN,0,22,10,0),(HATCH,30,41,10,2)])

# ---- 6  MAW: horned head with heavy jaws; the core sits in the throat
c=Cv(44,48)
c.ell(30,24,14,20,3)
c.poly([(2,10),(24,4),(34,14),(16,20)],3)        # upper jaw
c.shade(3,1,lit(30,24,16)); c.shade(3,2,dark(30,24,16))
for x in range(4,22,4): c.poly([(x,14),(x+3,14),(x+1.5,18)],1)   # teeth
c.poly([(30,4),(40,0),(36,8)],2)                  # horn
c.ell(26,24,6,4,0)                                # throat cavity
c.outline(1)
c.mirror_v()
boss('MAW',c,60,2,40,[6,1,2,1],[(CORE,20,20,60,0),(HATCH,34,20,12,3),(GUN,30,6,10,0),(GUN,30,38,10,0)])

# ---- 7  LEVIATHAN: long armoured space-creature, plated back and fins
c=Cv(56,40)
c.ell(30,20,26,12,3)
for k in range(6):
    x=12+k*7; c.poly([(x,9),(x+6,9),(x+3,2)],2)    # dorsal plates
c.poly([(40,26),(52,38),(46,26)],3)               # ventral fin
c.poly([(50,20),(56,12),(56,28)],3)               # tail
c.shade(3,1,lit(30,20,14)); c.shade(3,2,dark(30,20,14))
for k in range(5): c.rect(14+k*7,13,15+k*7,27,2)
c.ell(10,19,4,3,2)
c.outline(1)
boss('LEVIATHAN',c,70,0,34,[1,2,3,6],[(CORE,6,16,70,0),(GUN,20,4,10,0),(GUN,34,4,10,0),(FAN,26,30,12,0)],orbs=2)

# ---- 8  OVERMIND: shelled sphere with segmented armour bands and a central eye
c=Cv(48,48)
c.ell(26,24,21,21,3)
c.shade(3,1,lit(26,24,21)); c.shade(3,2,dark(26,24,21))
for r in (19,14,8): c.ring(26,24,r,r,2,1.0)
for y in range(48):
    for x in range(48):
        a=math.degrees(math.atan2(y-24,x-26))%45
        d=math.hypot(x-26,y-24)
        if 9<d<19 and a<3: c.put(x,y,0 if d>15 else 2)
c.ell(26,24,7,7,1); c.ell(26,24,4,4,3)
c.outline(1)
boss('OVERMIND',c,90,1,30,[3,1,2,4],[(CORE,22,20,90,0),(GUN,6,9,12,0),(GUN,6,34,12,0),(FAN,2,22,12,0),(GUN,36,3,10,0),(GUN,36,40,10,0)],orbs=4)

BYLEVEL={0:0,1:1,3:2,4:3,5:4,6:5,7:6}   # level index -> BOSSES index (level 2 = serpent)

if __name__=='__main__':
    from PIL import Image
    C0=[None,(0xe0,0xe0,0x40),(0xd0,0x30,0x30),(0x30,0xd0,0x30)]
    C1=[None,(0x40,0xd0,0xd0),(0xf0,0x90,0x20),(0xe0,0xe0,0xd0)]
    W=sum(b['w']+6 for b in BOSSES); H=max(b['h'] for b in BOSSES)
    im=Image.new('RGB',(W,H*2+6),(0,0,0)); px=im.load()
    for half,(pal,bg) in enumerate(((C0,(0x30,0x30,0xd0)),(C1,(0xd0,0x40,0xd0)))):
        x0=0
        for b in BOSSES:
            for y in range(H):
                for x in range(b['w']+6): px[x0+x,half*(H+6)+y]=bg
            for y,r in enumerate(b['rows']):
                for x,ch in enumerate(r):
                    if ch!='.': px[x0+3+x,half*(H+6)+y]=pal[int(ch)]
            x0+=b['w']+6
    im.resize((im.size[0]*3,im.size[1]*4),Image.NEAREST).save('bosses.png')
    for b in BOSSES: print(b['name'],b['w'],b['h'])
