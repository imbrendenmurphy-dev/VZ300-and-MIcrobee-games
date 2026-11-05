#!/usr/bin/env python3
"""Automated play-test: start a world, pick valid build sites, drive the game,
then report state and screenshots."""
import subprocess, sys
import os
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','build'))
EMU='../tools/beeemu'; COM='EMPIRES.COM'
sym={l.split()[1]:int(l.split()[0],16) for l in open('empires.sym')}
W=112
PRE=["frames 60","key 3 1","frames 6","key 3 0","frames %d"%int(os.environ.get("TW","300")),"key 33 1","frames 6","key 33 0","frames 1500"]
def run(lines):
    r=subprocess.run([EMU,COM,'banked'],input='\n'.join(lines)+'\n',capture_output=True,text=True)
    return r.stderr
run(PRE+["mem pt0.bin","blk 8 pm8.bin","blk 9 pm9.bin"])
m=open('pt0.bin','rb').read()
MB=[open('pm8.bin','rb').read(),open('pm9.bin','rb').read()]
def t(x,y): return MB[y>>6][(y&63)*256+x]&31
def expl(x,y): return MB[y>>6][(y&63)*256+x]&128
sx=m[sym['startxy']]; sy=m[sym['startxy']+1]
print('start',sx,sy)
GRASS=(4,5)
used=set([(sx,sy),(sx+1,sy),(sx,sy+1),(sx+1,sy+1)])
def near(x,y,types,r=2):
    return sum(1 for dy in range(-r,r+1) for dx in range(-r,r+1) if 0<=x+dx<W and 0<=y+dy<W and t(x+dx,y+dy) in types)
def find(pred,maxr=5):
    best=None
    for r in range(1,maxr+1):
        for dy in range(-r,r+1):
            for dx in range(-r,r+1):
                x,y=sx+dx,sy+dy
                if (x,y) in used or not expl(x,y): continue
                if pred(x,y): return (x,y)
    return None
sites=[]
# woodcutter
w=find(lambda x,y: t(x,y) in GRASS and near(x,y,(6,7))>=3)
if w: used.add(w); sites.append(('wood',4,w))
for i in range(4):
    f=find(lambda x,y: t(x,y) in GRASS and near(x,y,GRASS,1)>=6)
    if f:
        used.add(f); sites.append(('hut',2,f))
f=find(lambda x,y: t(x,y) in GRASS and near(x,y,GRASS,1)>=7)
if f:
    for dy in (-1,0,1):
        for dx in (-1,0,1): used.add((f[0]+dx,f[1]+dy))
    sites.insert(0,('farm',3,f))
wl=find(lambda x,y: t(x,y) in GRASS)
if wl: used.add(wl); sites.append(('well',6,wl))
print(sites)
KEY={'up':23,'left':1,'down':19,'right':4,'space':55}
L=list(PRE)
cx,cy=sx,sy
def tap(k,n=1,hold=6):
    for i in range(n): L.extend(["key %d 1"%k,"frames %d"%hold,"key %d 0"%k,"frames 5"])
def goto(x,y):
    global cx,cy
    if x>cx: tap(KEY['right'],x-cx)
    if x<cx: tap(KEY['left'],cx-x)
    if y>cy: tap(KEY['down'],y-cy)
    if y<cy: tap(KEY['up'],cy-y)
    cx,cy=x,y
for name,toolkey,(x,y) in sites:
    tap(32+toolkey if toolkey<10 else 32,1,4)
    goto(x,y)
    tap(KEY['space'],1,4)
    L.append("frames 30")
# roads beside huts: road east of each hut
tap(33,1,4)
for name,tk,(x,y) in sites:
    if name=='hut' and t(x,y+1) in GRASS and (x,y+1) not in used:
        goto(x,y+1); tap(KEY['space'],1,4); L.append("frames 10")
L+=["frames 20","shot d_pt1.bin"]
tap(46,1,4); tap(46,1,4)        # faster
L+=["frames %d"%int(sys.argv[1]) if len(sys.argv)>1 else "frames 4000","shot d_pt2.bin","mem pt1.bin","key 3 1","frames 8","key 3 0","frames 30","shot d_pt3.bin","regs"]
out=run(L)
print(out.strip().split('\n')[-2:])
m=open('pt1.bin','rb').read()
def w16(n): return m[sym[n]]|m[sym[n]+1]<<8
print({k:w16(k) for k in ['food','wood','stone','gold','pop','year']},'happy',m[sym['happy']],'season',m[sym['season']])
n=m[sym['nbld']]; b=sym['blist']
print('buildings',[tuple(m[b+i*4:b+i*4+4]) for i in range(n)])
