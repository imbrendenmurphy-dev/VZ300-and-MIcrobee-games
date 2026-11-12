import sys
exec(open('test1.py').read().split("if __name__")[0])
im=mkimg()
flash=open(A+'VZDOS.VZ','rb').read()[24:]
def new(nojoy=False):
    m=VZ(b'',flash,im,maxlba=max(im.sec)+100); m.ramsel=0; m.z.pc=0x4004; m.nojoyhw=nojoy; return m
def go(m,script,extra=30,maxsteps=8000000):
    m.script=list(script); f0=[None]
    def until(s):
        if not s.script:
            if f0[0] is None: f0[0]=s.frames
            return s.frames>f0[0]+extra
        return False
    return m.run(m.z.pc,maxsteps,until)
tap=lambda k,n=1:[(k,2),(None,2)]*n
def show(m,title,rows=None):
    print('=====',title,'| hung' if m.sd.hung else ''); s=m.screen().split('\n'); print('\n'.join(s if rows is None else [s[i] for i in rows]))
m=new(); go(m,[(None,5)]); show(m,'root')
go(m,tap('DOWN',2)+tap('RET')); show(m,'MANY',[1,2,3,4,13,14])
import time; t=m.z.cyc
go(m,[('DOWN',700),(None,3)],maxsteps=40000000); show(m,'MANY end',[1,2,12,13,14])
go(m,tap('LEFT',20)+tap('RET')); show(m,'back to root: cursor on MANY?',[1,2,3,4,14])
go(m,tap('UP')+tap('RET')+tap('DOWN')+tap('RET')+tap('DOWN')+tap('RET')+tap('DOWN')+tap('RET')+tap('DOWN')+tap('RET')); show(m,'deep',[1,2,3])
go(m,tap('RET',2)); show(m,'up2: on LEVEL0?',[1,2,3,4])
go(m,tap('UP')+tap('RET')); show(m,'GAMES: cursor on ARCADE?',[1,2,3,4,5,6,14])
go(m,tap('JDOWN',3)); show(m,'joy down x3',[1,5,6,14])
r=go(m,tap('JFIRE'),extra=60); print('joy fire launch ->',r,repr(m.con[-70:])); show(m,'after game RET',[0,1,2])
go(m,tap('JRIGHT')); show(m,'joy pgdn',[1,13])
m=new(); go(m,[(None,5)]); go(m,tap('DOWN')+tap('RET')+tap('DOWN',2)); m.con=''; r=go(m,tap('RET'),extra=40); print('BASIC launch ->',r,repr(m.con), '78A4=%04X 78F9=%04X'%(m.z.rd16(0x78A4),m.z.rd16(0x78F9)))
m=new(); go(m,[(None,5)]); m.con=''; go(m,tap('DOWN',11)+tap('RET'),extra=5); print('ZEBRA: halted',m.z.halted,'marker',hex(m.z.mem[0x7000]),repr(m.con))
m=new(nojoy=True); go(m,[(None,5)]); go(m,tap('DOWN',2)); show(m,'floating-low joystick ports: keyboard still ok',[1,2,3,4]); print('joyon',m.z.mem[0x8000+0:0].hex())
m=new(); go(m,[(None,5)]); m.con=''; r=go(m,tap('Q'),extra=120,maxsteps=20000000); print('Q ->',r,m.con.count('[RESET]')); show(m,'after quit',[0,1,2])
