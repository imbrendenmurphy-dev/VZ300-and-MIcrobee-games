import math, sys
from zasm import assemble

VIEWH=22
PROJ=20/math.tan(math.radians(30))
COL={'K':0,'B':1,'R':2,'M':3,'G':4,'C':5,'Y':6,'W':7}

MAP=["2222222222222222",
     "2......2.......2",
     "2..3...2..6..6.2",
     "2......5.......2",
     "2..3...2..6..6.2",
     "2......2.......2",
     "2222522222.22222",
     "1..............1",
     "1..4......4....1",
     "1..............1",
     "1111511111.11111",
     "3......3.......3",
     "3..6...5...4...3",
     "3......3.......3",
     "3......3.......3",
     "3333333333333333"]

def sub(t,a,b): return [r.replace(a,b) for r in t]
brick=["KKKKKKKK","RRRRKRRR","RRRRKRRR","RRRRKRRR","KKKKKKKK","RKRRRRRR","RKRRRRRR","RKRRRRRR"]
stone=["CCCCCCCC","WWWCWWWW","WWWCWWWW","WWWCWWWW","CCCCCCCC","WWWWWWCW","WWWWWWCW","WWWWWWCW"]
tech =["GGGGGGGG","GKKKKKKG","GKYGGYKG","GKGGGGKG","GKGGGGKG","GKYGGYKG","GKKKKKKG","GGGGGGGG"]
wood =["YYRYYYRY","YYRYYYRY","YYRYRYRY","YYRYYYRY","YYRYYYRY","YRRYYYRY","YYRYYYRY","YYRYYYRY"]
door =["WWWWWWWW","WCCCCCCW","WCWWWWCW","WCCCCCCW","WCCCCYCW","WCCCCCCW","WCCCCCCW","WWWWWWWW"]
tile =["MMWWMMWW","MMWWMMWW","WWMMWWMM","WWMMWWMM","MMWWMMWW","MMWWMMWW","WWMMWWMM","WWMMWWMM"]
TEXS=[brick, sub(brick,'R','M'),
      stone, sub(sub(stone,'C','K'),'W','C'),
      tech,  sub(sub(sub(tech,'G','x'),'K','G'),'x','K'),
      wood,  sub(sub(sub(wood,'Y','x'),'R','Y'),'x','R'),
      door,  sub(sub(sub(door,'W','x'),'C','W'),'x','C'),
      tile,  sub(tile,'W','K')]

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

src=open('mzray.asm').read()
tabs=[]
def tpage(name,vals): tabs.append(' align 256\n%s:\n%s'%(name,page(vals)))
tpage('SGN',SGN)
tpage('DDXL',[v&0xFF for v in DDX]); tpage('DDXH',[v>>8 for v in DDX])
tpage('DDYL',[v&0xFF for v in DDY]); tpage('DDYH',[v>>8 for v in DDY])
tpage('SINM',SINM); tpage('COSM',COSM); tpage('COS8',COS8); tpage('SIN8',SIN8)
tpage('MAP',[int(ch) if ch!='.' else 0 for r in MAP for ch in r])
tpage('HGT',HGT[:256]); tpage('HGT2',HGT[256:])
tpage('TOPS',TOPS); tpage('ROWS',ROWS); tpage('FLRS',FLRS); tpage('VINIT',VINIT); tpage('VSTEP',VSTEP)
tabs.append(' align 256\nTEX:')
tpage('VTAB',[0]*256)  # placeholder replaced below
tabs.pop()
for k in range(8):
    row=[0]*256
    for ti,t in enumerate(TEXS):
        for u in range(8):
            c=COL[t[k][u]]; row[ti*8+u]=c<<4|c
    tabs.append((' align 256\n' if k else '')+page(row))
tabs.append(' align 256\nVTAB:\n'+'\n'.join(' db '+','.join('(TEX>>8)+%d'%(v>>5) for v in range(i,i+16)) for i in range(0,256,16)))
small='''
colang40: db %s
cosoff40: db %s
colang20: db %s
cosoff20: db %s
'''%(','.join(map(str,CA40)),','.join(map(str,CO40)),','.join(map(str,CA20)),','.join(map(str,CO20)))
src=src.replace(';@@SMALLTABLES@@',small).replace(';@@TABLES@@','\n'.join(tabs))
src=src.replace(';@@LDI40@@','\n'.join([' ldi']*40))
open('mzray_full.asm','w').write(src)
lo,data,sym=assemble(src)
exe=sym['start']
name=b'MZRAY BENCH'
hdr=bytearray(128); hdr[0]=1
fn=name+b'\x0d'; hdr[1:1+len(fn)]=fn
for i in range(1+len(fn),18): hdr[i]=0x0d
hdr[18:20]=len(data).to_bytes(2,'little'); hdr[20:22]=lo.to_bytes(2,'little'); hdr[22:24]=exe.to_bytes(2,'little')
open('MZRAY.MZT','wb').write(bytes(hdr)+data)
open('mzray.sym','w').write('\n'.join('%-14s %04X'%(k,v) for k,v in sorted(sym.items(),key=lambda x:x[1])))
print('load %04X size %d end %04X exec %04X'%(lo,len(data),lo+len(data)-1,exe))
