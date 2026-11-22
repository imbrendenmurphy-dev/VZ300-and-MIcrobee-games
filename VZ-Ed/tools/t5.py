import sys, random; sys.path.insert(0,'.')
from harness import *
dos=open('VZDOS.VZ','rb').read(); ed=open('../out/VZED.VZ','rb').read()
sym={l.split()[1]:int(l.split()[0],16) for l in open('../out/vzed.sym')}
class Model:
    def __init__(s,text,rows): s.t=list(text); s.c=0; s.goal=None; s.ins=True; s.rows=rows
    def ls(s):
        i=s.c
        while i>0 and s.t[i-1]!='\n': i-=1
        return i
    def le(s):
        i=s.c
        while i<len(s.t) and s.t[i]!='\n': i+=1
        return i
    def col(s): return s.c-s.ls()
    def sg(s):
        if s.goal is None: s.goal=s.col()
    def up(s):
        a=s.ls()
        if a==0: return False
        b=a-1
        while b>0 and s.t[b-1]!='\n': b-=1
        s.c=b+min(s.goal,a-1-b); return True
    def down(s):
        e=s.le()
        if e>=len(s.t): return False
        a=e+1; s.c=a
        s.c=a+min(s.goal,s.le()-a); return True
    def key(s,k):
        if len(k)==1 and k not in '\n':
            if not s.ins and s.c<len(s.t) and s.t[s.c]!='\n': del s.t[s.c]
            s.t.insert(s.c,k); s.c+=1; s.goal=None
        elif k=='\n': s.t.insert(s.c,'\n'); s.c+=1; s.goal=None
        elif k=='LT': s.c=max(0,s.c-1); s.goal=None
        elif k=='RT': s.c=min(len(s.t),s.c+1); s.goal=None
        elif k=='UP': s.sg(); s.up()
        elif k=='DN': s.sg(); s.down()
        elif k=='PU':
            s.sg()
            for i in range(s.rows-1): s.up()
        elif k=='PD':
            s.sg()
            for i in range(s.rows-1): s.down()
        elif k=='HOME': s.c=s.ls(); s.goal=None
        elif k=='END': s.c=s.le(); s.goal=None
        elif k=='BS':
            if s.c>0: del s.t[s.c-1]; s.c-=1
            s.goal=None
        elif k=='DEL':
            if s.c<len(s.t): del s.t[s.c]
            s.goal=None
        elif k=='TOP': s.c=0; s.goal=None
        elif k=='BOT': s.c=len(s.t); s.goal=None
        elif k=='INS': s.ins=not s.ins
    def line(s): return s.t[:s.c].count('\n')+1
KEY={'\n':'RET','LT':('CTRL','M'),'RT':('CTRL',','),'UP':('CTRL','.'),'DN':('CTRL','SPACE'),'PU':('CTRL','R'),'PD':('CTRL','C'),
     'HOME':('CTRL','Z'),'END':('CTRL','X'),'BS':('CTRL',':'),'DEL':('CTRL',';'),'TOP':('CTRL','T'),'BOT':('CTRL','B'),'INS':('CTRL','L')}
def buffer(m):
    mem=m.z.mem; w=lambda a: mem[a]|mem[a+1]<<8
    gs,ge=w(sym['gs']),w(sym['ge']); B=sym['BUFS']
    return bytes(mem[B:gs]+mem[ge:0xF600]).decode('latin1'), gs-B, w(sym['curln'])
random.seed(int(sys.argv[1]) if len(sys.argv)>1 else 7)
start='Line one here\nsecond\n\nfourth line is quite a bit longer than the screen is wide\nfive\nsix\nseven\neight\nnine\nten\neleven\ntwelve\nthirteen\nfourteen\nfifteen\nsixteen\nseventeen end'
c=Card(spc=8); c.addfile(2,'VZDOS.VZ',dos); c.addfile(2,'SHELL.VZ',ed); c.addfile(2,'T.TXT',start.encode()); c.finish()
m=VZ(dos[24:],c,maxlba=max(c.sec)+5000); m.run(0x4004,frames=160)
m.type_keys([('CTRL','O'),('WAIT',20),'SPACE','RET',('WAIT',30)]); m.run_script(extra=10)
md=Model(start,15)
bad=0
for step in range(12):
    seq=[random.choice(['a','b','Q','.','\n','LT','RT','UP','DN','UP','DN','HOME','END','BS','DEL','PU','PD','TOP','BOT','INS','x','y']) for _ in range(12)]
    for k in seq:
        md.key(k)
        m.type_keys([KEY.get(k) or (('SHIFT',k) if k.isupper() else (k.upper() if k.isalpha() else k))])
        if k in ('TOP','BOT','PU','PD'): m.type_keys([('WAIT',10)])
    m.run_script(extra=20)
    t,cur,ln=buffer(m)
    ok = t==''.join(md.t) and cur==md.c and ln==md.line()
    if not ok:
        bad+=1; print('step',step,seq); print(' emu',repr(t[:80]),cur,ln); print(' mdl',repr(''.join(md.t)[:80]),md.c,md.line()); break
print('steps ok' if not bad else 'FAILED', 'final len',len(md.t),'line',md.line())
print(m.text())
