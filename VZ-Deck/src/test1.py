import sys,time
from vz import *
from mtest import A
from asm import assemble
def mkimg():
    im=FatImg()
    dos=open('out/VZDOS.VZ','rb').read(); sh=open('out/SHELL.VZ','rb').read()
    def vz(name,typ,addr,code): return b'VZF0'+name.encode().ljust(17,b'\0')+bytes([typ,addr&255,addr>>8])+code
    g1,_=assemble(" LD A,0x42\n LD (0x7000),A\n HALT",0x8000)
    g2,_=assemble(" LD A,0x43\n LD (0x7001),A\n RET",0xA000)
    im.addraw(2,bytes([0x41])+b'L\0o\0n\0g\0 \0'+bytes([0x0F,0,0x11])+b'n\0a\0m\0e\0.\0v\0'+b'\0\0'+b'z\0\0\0')   # LFN entry
    im.addfile(2,'VZDOS.VZ',dos)
    im.addfile(2,'SHELL.VZ',sh)
    sv=im.mkdir(2,'SYSTEM~1'); im.dirs[2][-1]=im.dirs[2][-1][:11]+bytes([0x16])+im.dirs[2][-1][12:]
    games=im.mkdir(2,'GAMES',date=(2026,11,5))
    im.addfile(2,'ZEBRA.VZ',vz('Zebra Crossing',0xF1,0x8000,g1))
    im.addraw(2,b'\xE5ELETED TXT'+bytes(21))
    im.addfile(2,'README.TXT',b'hello'*30,date=(1994,3,2))
    im.addfile(2,'EMPTY.VZ',b'')
    im.addfile(2,'BIG.DAT',b'x'*150000)
    im.addfile(2,'TUNE.MOD',b'm'*5000,date=None)
    arc=im.mkdir(games,'ARCADE'); 
    im.addfile(games,'ROBOGEDN.VZ',vz('ROBOGEDDON 2085',0xF1,0xA000,g2))
    im.addfile(games,'ROBOGEDN.DAT',b'd'*98304)
    im.addfile(games,'BAS.VZ',vz('BASIC PROG',0xF0,0x7AE9,b'\0'*40))
    many=im.mkdir(2,'MANY')
    for i in range(200): im.addfile(many,'F%03d.VZ'%(199-i),vz('F%d'%i,0xF1,0x8000,g1))
    exact=im.mkdir(2,'EXACT')
    for i in range(126): im.addfile(exact,'E%03d.DAT'%i,b'e')
    deep=arc
    for i in range(3): deep=im.mkdir(deep,'LEVEL%d'%i)
    im.finish(); return im
if __name__=='__main__':
    im=mkimg()
    flash=open(A+'VZDOS.VZ','rb').read()[24:]
    m=VZ(b'',flash,im,maxlba=max(im.sec)+100); m.ramsel=0
    def go(script,extra=30,maxsteps=6000000):
        m.script=list(script); f0=[None]
        def until(s):
            if not s.script:
                if f0[0] is None: f0[0]=s.frames
                return s.frames>f0[0]+extra
            return False
        r=m.run(m.z.pc,maxsteps,until); return r
    m.z.pc=0x4004
    t=time.time(); r=go([(None,5)]); print('boot:',r,'%.1fs'%(time.time()-t),'hung' if m.sd.hung else ''); print(m.con[-200:]); print(m.screen())
    sys.modules['__main__'].m=m; sys.modules['__main__'].go=go
