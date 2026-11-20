import sys; sys.path.insert(0,'.')
from harness import *
dos=open('VZDOS.VZ','rb').read(); ed=open('../out/VZED.VZ','rb').read()
sym={l.split()[1]:int(l.split()[0],16) for l in open('../out/vzed.sym')}
lines=''.join('Line %d of a longer test document with words.\r\n'%i for i in range(250)).encode()
c=Card(spc=8); c.addfile(2,'VZDOS.VZ',dos); c.addfile(2,'SHELL.VZ',ed); c.addfile(2,'DOC.TXT',lines); c.finish()
m=VZ(dos[24:],c,maxlba=max(c.sec)+5000); m.run(0x4004,frames=120)
t0=m.z.t; m.type_keys([('CTRL','O'),('WAIT',20),'RET']); m.run_script(extra=5)
# time load: run until status shows doc name
z=m.z
def measure(keys,label):
    m.type_keys(keys); 
    # find the frame the key event is dispatched and when we're back waiting
    disp=sym['dispatch']; edlp=sym['ed_lp']; start=None; res=[]
    f0=m.frame
    while (m.script or start is not None) and m.frame-f0<3000:
        if z.pc<0x4000: m.trap(); continue
        if z.pc==disp: start=z.t
        if z.pc==edlp and start is not None: res.append(z.t-start); start=None
        z.step()
    print('%-28s %s T-states  (= %.2f frames)'%(label, max(res) if res else None, (max(res) if res else 0)/70630))
for style in range(3):
    measure(['A'],'style %d: type a letter'%style)
    measure([('CTRL','C')],'style %d: page down'%style)
    measure([('CTRL','SPACE')],'style %d: cursor down'%style)
    measure([('CTRL','B')],'style %d: end of file'%style)
    measure([('CTRL','T')],'style %d: top of file'%style)
    m.type_keys([('CTRL','D'),('WAIT',5)]); m.run_script(extra=3)
