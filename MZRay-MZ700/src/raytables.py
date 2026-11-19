# Shared MZRAY raycaster tables and source filling, used by build.py (benchmark) and build_game.py.
import math

VIEWH=22
PROJ=20/math.tan(math.radians(30))
COL={'K':0,'B':1,'R':2,'M':3,'G':4,'C':5,'Y':6,'W':7}

def page(vals):
    assert len(vals)==256
    return '\n'.join(' db '+','.join(str(v&0xFF) for v in vals[i:i+16]) for i in range(0,256,16))

ang=[a*2*math.pi/256 for a in range(256)]
def dd(f):
    out=[]
    for t in ang:
        v=abs(f(t))
        out.append(0x7FFF if v<1e-9 else min(0x7FFF,round(256/v)))
    return out
DDX=dd(math.cos); DDY=dd(math.sin)
SGN=[(1 if math.cos(t)<-1e-9 else 0)|(2 if math.sin(t)<-1e-9 else 0) for t in ang]
SINM=[min(255,round(abs(math.sin(t))*256)) for t in ang]
COSM=[min(255,round(abs(math.cos(t))*256)) for t in ang]
COS8=[round(math.cos(t)*127) for t in ang]
SIN8=[round(math.sin(t)*127) for t in ang]
HGT=[]
for i in range(512):
    d=(i+0.5)/32
    HGT.append(max(1,min(255,round(PROJ/d))))
TOPS=[];ROWS=[];FLRS=[];VINIT=[];VSTEP=[]
for h in range(256):
    hh=max(h,1)
    if hh>=VIEWH: top=0; rows=VIEWH; skip=(hh-VIEWH)/2
    else: top=(VIEWH-hh)//2; rows=hh; skip=0
    step=256/hh; vs=min(255,round(step))
    v0=(skip+0.5)*step
    TOPS.append(top); ROWS.append(rows); FLRS.append(VIEWH-top-rows)
    VSTEP.append(vs); VINIT.append((round(v0)-vs)&0xFF)
def colang(n,w):
    A=[];Cs=[]
    for i in range(n):
        x=((i*w+w/2)-20)/20*math.tan(math.radians(30))
        a=round(math.atan(x)*256/(2*math.pi))
        A.append(a&0xFF); Cs.append(min(255,round(math.cos(a*2*math.pi/256)*256)))
    return A,Cs
CA40,CO40=colang(40,1); CA20,CO20=colang(20,2)

def texrows(texs):
    """texs: list of 8x8 colour-letter textures (up to 32). Returns 8 page lists, page k = texture row k."""
    rows=[]
    for k in range(8):
        row=[0]*256
        for ti,t in enumerate(texs):
            for u in range(8):
                c=COL[t[k][u]]; row[ti*8+u]=c<<4|c
        rows.append(row)
    return rows

def fill(src,mapvals,texs,sprhook=''):
    """Insert the raycaster core, tables, column tables and the unrolled copy into src.
    sprhook: code run after each column is drawn (the game's per-column sprite drawer); empty for the benchmark."""
    tabs=[]
    def tpage(name,vals): tabs.append(' align 256\n%s:\n%s'%(name,page(vals)))
    tpage('SGN',SGN)
    tpage('DDXL',[v&0xFF for v in DDX]); tpage('DDXH',[v>>8 for v in DDX])
    tpage('DDYL',[v&0xFF for v in DDY]); tpage('DDYH',[v>>8 for v in DDY])
    tpage('SINM',SINM); tpage('COSM',COSM); tpage('COS8',COS8); tpage('SIN8',SIN8)
    tpage('MAP',mapvals)
    tpage('HGT',HGT[:256]); tpage('HGT2',HGT[256:])
    tpage('TOPS',TOPS); tpage('ROWS',ROWS); tpage('FLRS',FLRS); tpage('VINIT',VINIT); tpage('VSTEP',VSTEP)
    tabs.append(' align 256\nTEX:')
    for k,row in enumerate(texrows(texs)):
        tabs.append((' align 256\n' if k else '')+page(row))
    tabs.append(' align 256\nVTAB:\n'+'\n'.join(' db '+','.join('(TEX>>8)+%d'%(v>>5) for v in range(i,i+16)) for i in range(0,256,16)))
    small='''
colang40: db %s
cosoff40: db %s
colang20: db %s
cosoff20: db %s
'''%(','.join(map(str,CA40)),','.join(map(str,CO40)),','.join(map(str,CA20)),','.join(map(str,CO20)))
    src=src.replace(';@@RAYCORE@@',open('raycore.asm').read().replace(';@@SPRHOOK@@',sprhook))
    src=src.replace(';@@SMALLTABLES@@',small).replace(';@@TABLES@@','\n'.join(tabs))
    src=src.replace(';@@LDI40@@','\n'.join([' ldi']*40))
    return src

def mzt(name,lo,data,exe):
    hdr=bytearray(128); hdr[0]=1
    fn=name+b'\x0d'; hdr[1:1+len(fn)]=fn
    for i in range(1+len(fn),18): hdr[i]=0x0d
    hdr[18:20]=len(data).to_bytes(2,'little'); hdr[20:22]=lo.to_bytes(2,'little'); hdr[22:24]=exe.to_bytes(2,'little')
    return bytes(hdr)+data
