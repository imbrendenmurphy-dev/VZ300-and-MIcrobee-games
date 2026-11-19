from mzemu import MZ
import sys
d=open('MZRAY.MZT','rb').read()
sym={l.split()[0]:int(l.split()[1],16) for l in open('mzray.sym')}
m=MZ(0x1200,d[128:],0x1200)
m.run_until(sym['wait_mode'],2_000_000_000)
m.held={'4'}; m.run_until(sym['wk_l']); m.held=set()
def frame(): 
    m.run_until(sym['wk_h']); m.cpu.step()
def setp(x,y,a):
    m.mem[sym['px']:sym['px']+2]=int(x*256).to_bytes(2,'little')
    m.mem[sym['py']:sym['py']+2]=int(y*256).to_bytes(2,'little')
    m.mem[sym['pang']]=a
shots=[(8.5,8.5,0),(8.5,8.5,64),(8.5,8.5,128),(8.5,8.5,192),(3.5,4.0,192),(11.0,12.5,128)]
for i,(x,y,a) in enumerate(shots):
    setp(x,y,a); frame(); frame()
    m.shot('walk%d.png'%i,2)
print('ok')
setp(8.5,8.5,0)
m.held={'up'}
for i in range(10): frame()
px=int.from_bytes(m.mem[sym['px']:sym['px']+2],'little')/256
m.held={'left'}
for i in range(4): frame()
print('px after fwd',px,'pang after left',m.mem[sym['pang']])
m.held={'up'}
for i in range(40): frame()
print('pos after long walk',int.from_bytes(m.mem[sym['px']:sym['px']+2],'little')/256,int.from_bytes(m.mem[sym['py']:sym['py']+2],'little')/256)
m.held={'2'}; frame(); m.held=set(); frame(); print('mode',m.mem[sym['curmode']])
for i in range(20): frame()
m.shot('walk_fps.png',2)
m.held={"B"}; print("restart reached", m.run_until(sym["restart"],10**7))
