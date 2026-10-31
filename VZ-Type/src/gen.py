# VZ-TYPE data generator -> data.inc
import sys, math, random
sys.path.insert(0,'.')
from art import SPR
import levels as LV
from levels import *

R=random.Random(4242)
RNDT=list(range(256)); R.shuffle(RNDT)

def decode_column(L,x):
    n=L.n; C,F=L.c,L.f
    c,f=C[x],F[x]
    cp=C[x-1] if x>0 else c; fp=F[x-1] if x>0 else f
    cn=C[x+1] if x<n-1 else c; fn=F[x+1] if x<n-1 else f
    col=[0]*ROWS
    for y in range(ROWS):
        if y<c or y>=ROWS-f: col[y]=FULL+(x&3)+(y&3)*4
    if c>0: col[c-1]=CBOT+(x&1)
    if f>0: col[ROWS-f]=FTOP+(x&1)
    if f>0 and f==fp+1: col[ROWS-f]=FSU
    if f>0 and fn==f-1: col[ROWS-f]=FSD
    if c>0 and c==cp+1: col[c-1]=CSD
    if c>0 and cn==c-1: col[c-1]=CSU
    for (ox,oy,ow,oh,kind) in L.objs:
        if not (ox<=x<ox+ow): continue
        for y in range(oy,oy+oh):
            if kind==1: col[y]=F0; continue
            if kind>1: col[y]=kind; continue
            t=FULL+(x&3)+(y&3)*4
            top=y==oy; bot=y==oy+oh-1; lf=x==ox; rt=x==ox+ow-1
            if top and lf: t=BTL
            elif top and rt: t=BTR
            elif bot and lf: t=BBL
            elif bot and rt: t=BBR
            elif top: t=BT
            elif bot: t=BB
            elif lf: t=BL
            elif rt: t=BR
            col[y]=t
    if (RNDT[(x+7)&255]&15)==0 and f>=2 and fp==f==fn: col[ROWS-f+1]=F1
    h=RNDT[x&255]
    if (h&7)==0:
        r=RNDT[(x+1)&255]&15
        if r<ROWS and col[r]==0: col[r]=DEC0+(h>>6)
    return col

def prep_levels():
    Ls=LV.make_levels()
    for L in Ls:
        objs=[(bx,by,bw,bh,0) for (bx,by,bw,bh) in L.blocks]
        objs+= [(fx,fy,1,1,1) for (fx,fy,t) in L.feat if t==F0]
        objs+= list(L.xobjs)
        # merge vertical pillar cells
        objs.sort()
        L.objs=objs
    return Ls

# ---------------- output helpers
out=[]
def emit(s): out.append(s)
def db(lst,per=16):
    for i in range(0,len(lst),per): emit('\tdb '+','.join('$%02x'%(v&255) for v in lst[i:i+per]))
def dw(lst,per=8):
    for i in range(0,len(lst),per): emit('\tdw '+','.join('$%04x'%(v&0xffff) for v in lst[i:i+per]))

def pack_rows(rows,w):
    # logical sprite rows -> bytes (4 px/byte, MSB = leftmost)
    bs=[]
    for r in rows:
        r=r.ljust(w*4,'.')
        for b in range(w):
            v=0
            for k in range(4):
                ch=r[b*4+k]; v=(v<<2)|(0 if ch=='.' else int(ch))
            bs.append(v)
    return bs

def make_bossblob(li):
    import bossart as BA
    if li not in BA.BYLEVEL:
        # armoured serpent: no big body; segments are sprites
        return [0,0,30,5,30,1,2,1,3,0,0]
    b=BA.BOSSES[BA.BYLEVEL[li]]
    wb=(b['w']+3)//4; h=b['h']
    bs=[wb,h,b['hp'],b['move'],b['interval']]+list(b['attacks'])+[b['orbs'],len(b['parts'])]
    for (k,dx,dy,hp,p) in b['parts']: bs+=[k,dx,dy,hp,p]
    cm={'.':0,'1':1,'2':2,'3':3}
    for r in b['rows']:
        e=next((x for x,ch in enumerate(r) if ch!='.'),255)
        bs.append(e)
    for r in b['rows']:
        r=r.ljust(wb*4,'.')
        for x in range(wb):
            v=0
            for k in range(4): v=(v<<2)|cm[r[x*4+k]]
            bs.append(v)
    return bs
SPRUSE={19:['core'],1:['swim'],2:['dart'],3:['turf'],4:['turc'],5:['hop'],6:['carr'],7:['spin'],8:['guns'],9:['spore','frag'],15:['snakeh','snakes']}
ALWAYS=['ship','sat','pod','shot','sprd','lance','cross','beam','ebul','expl','capw','caps','caph','life','frag']
def sprmask(li,L,names):
    import bossart as BA
    pre=list(ALWAYS)
    for (col,typ,y,p) in L.spawns: pre+=SPRUSE.get(typ,[])
    if li not in BA.BYLEVEL: pre+=['serph','serpa','serpb','serpt']
    else:
        b=BA.BOSSES[BA.BYLEVEL[li]]
        pre+=['core','bgun','hatch']
        for a in b['attacks']: pre+={4:['swim'],5:['dart'],6:['spore','frag']}.get(a,[])
        for (k,dx,dy,hp,p) in b['parts']:
            if k==3: pre+={1:['swim'],2:['dart'],3:['spore','frag']}.get(p,[])
        if b['orbs']: pre+=['borb']
    m=[0]*8; used=[]
    for i,n in enumerate(names):
        if any(n.startswith(p) for p in pre): m[i>>3]|=1<<(i&7); used.append(n)
    return m,used
def bigmax():
    import bossart as BA
    return max(((b['w']+3)//4)*b['h']*2 for b in BA.BOSSES)

def gen():
    # ---- sprites
    names=list(SPR.keys())
    emit('; sprite ids')
    for i,n in enumerate(names): emit('SP_%s equ %d'%(n.upper(),i))
    emit('NSPR equ %d'%len(names))
    csz=0; bmax=0
    for n in names:
        rows=SPR[n]; w=(max(len(r) for r in rows)+3)//4; c=(w+1)*len(rows)*2*4
        csz+=c
    KEEP4=('ship','exh','pod','sat','turf','turc','hop','core','carr','life','glyph')
    two=[0]*8
    for i,n in enumerate(names):
        if not n.startswith(KEEP4): two[i>>3]|=1<<(i&7)
    emit('spr2s:'); db(two)
    FE=('ship','exh','pod','sat','cap','shot','beam','swim','dart','expl')
    fm=[0]*8
    for i,n in enumerate(names):
        if n.startswith(FE): fm[i>>3]|=1<<(i&7)
    emit('femask:'); db(fm)
    emit('FECSZ equ %d'%sum(((max(len(r) for r in SPR[n])+3)//4+1)*len(SPR[n])*2*(4 if n.startswith(KEEP4) else 2) for n in names if n.startswith(FE)))
    SPRCSZ={n:((max(len(r) for r in SPR[n])+3)//4+1)*len(SPR[n])*2*(4 if n.startswith(KEEP4) else 2) for n in names}
    gen.SPRCSZ=SPRCSZ; gen.NAMES=names
    emit('spr_tab:')
    for n in names:
        rows=SPR[n]; w=(max(len(r) for r in rows)+3)//4; h=len(rows)
        emit('\tdb %d,%d\n\tdw spr_%s'%(w,h,n))
    for n in names:
        rows=SPR[n]; w=(max(len(r) for r in rows)+3)//4
        emit('spr_%s:'%n); db(pack_rows(rows,w))
    # sprite pixel sizes for hitboxes
    emit('spr_px:')
    for n in names:
        rows=SPR[n]; emit('\tdb %d,%d'%(max(len(r) for r in rows),len(rows)))
    # ---- levels: one packed blob each (header, tiles, profile, objects, spawns, far band, boss)
    import lz
    cm={' ':0,'a':1,'b':2,'c':3}
    def tilebytes(th):
        bs=[]
        for t in tileset(th):
            for r in range(4):
                row=t[r] if r<len(t) else '    '
                v=0
                for k in range(4): v=(v<<2)|cm[row[k]]
                bs.append(v)
        return bs
    def rowbytes(rows,wb):
        bs=[]
        for r in rows:
            r=r.ljust(wb*4)
            for b in range(wb):
                v=0
                for k in range(4): v=(v<<2)|cm.get(r[b*4+k],0)
                bs.append(v)
        return bs
    THEMES=['hull','flesh','rock','cryst','ship']
    emit('theme_tab:')
    for th in THEMES: emit('\tdw thpak_%s'%th)
    import lzb as _lzb
    tp=0
    for k,th in enumerate(THEMES):
        raw=bytes(v&255 for v in tilebytes(th)+rowbytes(farband(th,seed=k+3),16))
        pk=_lzb.pack(raw); assert _lzb.unpack(pk)==raw; tp+=len(pk)
        emit('thpak_%s:'%th); db(list(pk))
    print('themes packed',tp)
    Ls=prep_levels()
    pal=[(0,2,1,3,0),(1,2,1,3,0)]
    names_lv=['OUTER HULL','THE HIVE','ROCK BELT','CRYSTAL VEIN','DREADNOUGHT','GUT CAVERNS','DEEP FIELD','THE CORE']
    emit('level_tab:')
    for i,L in enumerate(Ls): emit('\tdw lvlpak%d'%i)
    emit('name_tab:')
    for i,L in enumerate(Ls): emit('\tdw lvl%d_name'%i)
    for i,L in enumerate(Ls): emit('lvl%d_name: db "%s",0'%(i,names_lv[i]))
    lvmax=0; tot=0; lvneed=0
    for i,L in enumerate(Ls):
        css,T,a,b,c=getattr(L,'pal',pal[i&1])
        body=bytearray(); ptr={}
        HDR=32
        def put(name,bs):
            ptr[name]=HDR+len(body); body.extend(bytes(v&255 for v in bs))
        vals=[(L.c[x]<<4)|L.f[x] for x in range(L.n)]
        rle=[]; x=0
        while x<len(vals):
            k=1
            while x+k<len(vals) and vals[x+k]==vals[x] and k<255: k+=1
            rle+= [k,vals[x]]; x+=k
        rle.append(0)
        put('prof',rle)
        ob=[]
        for (ox,oy,ow,oh,kind) in L.objs: ob+=[ox&255,ox>>8,oy,ow,oh,kind]
        put('obj',ob+[255,255])
        sp=[]
        for (col,typ,y,p) in L.spawns: sp+=[col&255,col>>8,typ,y,p]
        put('spn',sp+[255,255])
        bossblob=make_bossblob(i)
        if bossblob: put('boss',bossblob)
        h=bytearray(HDR)
        def w16(o,v): h[o]=v&255; h[o+1]=(v>>8)&255
        h[0]=THEMES.index(L.theme); h[1]=0; h[2:7]=bytes([css,T,a,b,c]); w16(7,L.n)
        w16(9,ptr['prof']); w16(11,ptr['obj']); w16(13,ptr['spn']); w16(15,0)
        h[17]=getattr(L,'bandy',30); h[18]=getattr(L,'starcol',1)
        w16(19,ptr.get('boss',0))
        bloblen=HDR+len(body); w16(21,bloblen)
        msk,used=sprmask(i,L,gen.NAMES); h[23:31]=bytes(msk)
        ncache=sum(gen.SPRCSZ[n] for n in used)
        if bossblob and bossblob[0]:
            wb,bh=bossblob[0],bossblob[1]; base=bloblen-wb*bh+2*wb*bh
        else: base=bloblen
        need=base+ncache; lvneed=max(lvneed,need)
        print('level',i,'cache',ncache,'need',need)
        blob=bytes(h)+bytes(body)
        import lzb
        pk=lzb.pack(blob); assert lzb.unpack(pk)==blob
        lvmax=max(lvmax,len(blob)); tot+=len(pk)
        emit('lvlpak%d:'%i); db(list(pk))
        print('level',i,'blob',len(blob),'packed',len(pk))
    emit('LVMAX equ %d'%lvmax)
    emit('LVNEED equ %d'%lvneed)
    print('levels packed total',tot,'max unpacked',lvmax)
    # ---- tables
    emit('\talign 256\nrndt:'); db(RNDT)
    sint=[int(round(127*math.sin(2*math.pi*i/256))) for i in range(256)]
    emit('sint:'); db(sint)
    # 16 aim directions, speed 24/16 px
    emit('dirtab:')
    d=[]
    for k in range(16):
        a=2*math.pi*k/16
        d+=[int(round(24*math.cos(a))),int(round(24*math.sin(a)))]
    db(d)
    # HUD digits 3x5 logical colour 1 (bits in left 3 pixels)
    DIG=["111","101","101","101","111", ".1.","11.",".1.",".1.","111", "111","..1","111","1..","111", "111","..1",".11","..1","111",
         "1.1","1.1","111","..1","..1", "111","1..","111","..1","111", "111","1..","111","1.1","111", "111","..1",".1.",".1.",".1.",
         "111","1.1","111","1.1","111", "111","1.1","111","..1","111",
         "111","1..","111","..1","111", "1..","1..","1..","1..","111", "111","1..","1..","1..","111",
         "...","...","111","...","...", "1.1","1.1","111","1.1","1.1",
         "...","...","...","...","..."]
    bs=[]
    for r in DIG:
        v=0
        for ch in r+'.': v=(v<<2)|(1 if ch=='1' else 0)
        bs.append(v)
    emit('hudfont:'); db(bs)
    # ---- data.inc
    open('./data.inc','w').write('\n'.join(out)+'\n')
    return Ls
if __name__=='__main__':
    Ls=gen()
    # verify grid equivalence & stats
    import os
    print('data.inc lines',len(out))
